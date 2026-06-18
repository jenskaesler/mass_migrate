<#
.SYNOPSIS
    Liest Skript-Dateien aus einem Ordner (rekursiv) und erzeugt eine
    VS-Code-Snippets-JSON-Datei, die sich in massCode importieren lässt.

.DESCRIPTION
    massCode unterstuetzt nativ den Import von "VS Code snippets JSON".
    Dieses Skript baut genau dieses Format aus deinen bestehenden Dateien.

    Wichtig: Das VS-Code-Snippet-Format verwendet "$" fuer Tabstops/Variablen
    (z.B. $1, ${1:name}). Da PowerShell-Skripte voller "$"-Variablen sind,
    werden alle "$" automatisch zu "\$" escaped, damit dein Code unverändert
    als reiner Text importiert wird und nicht als Snippet-Platzhalter
    interpretiert wird.

.PARAMETER SourceFolder
    Ordner, der deine bestehenden Skripte enthaelt (wird rekursiv durchsucht).

.PARAMETER OutputFile
    Pfad der JSON-Datei, die anschliessend in massCode importiert wird.

.PARAMETER Extensions
    Dateiendungen, die beruecksichtigt werden sollen.

.EXAMPLE
    .\Export-ScriptsToMassCode.ps1 -SourceFolder "D:\Scripts" -OutputFile "D:\masscode-import.json"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SourceFolder,

    [Parameter(Mandatory = $true)]
    [string]$OutputFile,

    [string[]]$Extensions = @(
        '.ps1', '.psm1', '.psd1',
        '.py',
        '.yaml', '.yml',
        '.json',
        '.sh',
        '.bat', '.cmd',
        '.sql',
        '.md',
        '.js', '.ts',
        '.html', '.css',
        '.xml',
        '.vbs', '.vba',
        '.reg',
        '.bds'
    )
)

# Mapping Dateiendung -> VS Code Language-ID (steuert die Syntax-Hervorhebung in massCode)
$ExtensionToScope = @{
    '.ps1'  = 'powershell'
    '.psm1' = 'powershell'
    '.psd1' = 'powershell'
    '.py'   = 'python'
    '.yaml' = 'yaml'
    '.yml'  = 'yaml'
    '.json' = 'json'
    '.sh'   = 'shellscript'
    '.bat'  = 'bat'
    '.cmd'  = 'bat'
    '.sql'  = 'sql'
    '.md'   = 'markdown'
    '.js'   = 'javascript'
    '.ts'   = 'typescript'
    '.html' = 'html'
    '.css'  = 'css'
    '.xml'  = 'xml'
    '.vbs'  = 'vbscript'
    '.vba'  = 'vb'
    '.reg'  = 'reg'
    # '.bds' bewusst ohne Mapping - Format unklar, landet als Plain Text
}

# Liest eine Datei robust ein: erkennt BOM (UTF-8/UTF-16) automatisch.
# Ist kein BOM vorhanden, wird zunaechst strikt UTF-8 versucht; schlaegt das
# fehl (ungueltige Bytefolge), wird nach Windows-1252 (ANSI) zurueckgefallen.
# Das deckt den haeufigsten Fall ab: alte Skripte, die unter Windows ohne
# explizites UTF-8 gespeichert wurden und Umlaute/Sonderzeichen enthalten.
function Get-SmartFileLines {
    param([Parameter(Mandatory)][string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)

    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $text         = [System.Text.Encoding]::UTF8.GetString($bytes, 3, $bytes.Length - 3)
        $encodingUsed = 'UTF-8 (BOM)'
    }
    elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
        $text         = [System.Text.Encoding]::Unicode.GetString($bytes, 2, $bytes.Length - 2)
        $encodingUsed = 'UTF-16 LE (BOM)'
    }
    elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
        $text         = [System.Text.Encoding]::BigEndianUnicode.GetString($bytes, 2, $bytes.Length - 2)
        $encodingUsed = 'UTF-16 BE (BOM)'
    }
    else {
        try {
            # throwOnInvalidBytes = $true -> wirft Exception bei ungueltiger UTF-8-Sequenz
            $strictUtf8   = New-Object System.Text.UTF8Encoding($false, $true)
            $text         = $strictUtf8.GetString($bytes)
            $encodingUsed = 'UTF-8 (ohne BOM)'
        }
        catch {
            $ansi         = [System.Text.Encoding]::GetEncoding(1252)
            $text         = $ansi.GetString($bytes)
            $encodingUsed = 'Windows-1252 / ANSI (Fallback)'
        }
    }

    $lines = $text -split "`r`n|`r|`n"

    return [PSCustomObject]@{
        Lines    = $lines
        Encoding = $encodingUsed
    }
}

if (-not (Test-Path -LiteralPath $SourceFolder)) {
    throw "Ordner nicht gefunden: $SourceFolder"
}

$SourceFolder = (Resolve-Path -LiteralPath $SourceFolder).Path
$files = Get-ChildItem -LiteralPath $SourceFolder -Recurse -File |
    Where-Object { $Extensions -contains $_.Extension.ToLower() }

if ($files.Count -eq 0) {
    Write-Warning "Keine passenden Dateien gefunden in $SourceFolder"
    return
}

$snippets    = @{}
$counter     = 0
$encodingLog = New-Object System.Collections.Generic.List[object]

foreach ($file in $files) {
    $relativePath = $file.FullName.Substring($SourceFolder.Length).TrimStart('\', '/')
    $relativePath = $relativePath -replace '\\', '/'

    $fileContent = Get-SmartFileLines -Path $file.FullName
    $rawLines    = $fileContent.Lines
    if ($null -eq $rawLines) { $rawLines = @() }
    if ($rawLines -isnot [array]) { $rawLines = @($rawLines) }

    $encodingLog.Add([PSCustomObject]@{ Datei = $relativePath; Encoding = $fileContent.Encoding })

    # "$" escapen, damit VS-Code-Snippet-Syntax (Tabstops/Variablen) nicht greift
    $escapedLines = $rawLines | ForEach-Object { $_ -replace '\$', '\$' }

    $ext   = $file.Extension.ToLower()
    $scope = $ExtensionToScope[$ext]

    # Eindeutigen Key sicherstellen (Pfad ist i.d.R. schon eindeutig)
    $key = $relativePath
    $suffix = 1
    while ($snippets.ContainsKey($key)) {
        $key = "$relativePath ($suffix)"
        $suffix++
    }

    $entry = @{
        prefix      = ($file.BaseName -replace '\s+', '-').ToLower()
        body        = @($escapedLines)
        description = "Importiert aus: $relativePath"
    }
    if ($scope) {
        $entry.scope = $scope
    }

    $snippets[$key] = $entry
    $counter++
}

$json = $snippets | ConvertTo-Json -Depth 6

# Ohne BOM speichern
[System.IO.File]::WriteAllText($OutputFile, $json, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "Fertig: $counter Skripte exportiert nach $OutputFile" -ForegroundColor Green
Write-Host ""
Write-Host "Erkannte Encodings (zur Kontrolle):" -ForegroundColor Cyan
$encodingLog | Group-Object Encoding | Sort-Object Count -Descending |
    ForEach-Object { Write-Host ("  {0,-32} {1,4} Datei(en)" -f $_.Name, $_.Count) }

$fallbackFiles = $encodingLog | Where-Object { $_.Encoding -eq 'Windows-1252 / ANSI (Fallback)' }
if ($fallbackFiles.Count -gt 0) {
    Write-Host ""
    Write-Host "Diese Dateien wurden per ANSI-Fallback gelesen - bitte nach dem Import" -ForegroundColor Yellow
    Write-Host "stichprobenartig auf korrekte Umlaute/Sonderzeichen pruefen:" -ForegroundColor Yellow
    $fallbackFiles | ForEach-Object { Write-Host "  - $($_.Datei)" }
}
