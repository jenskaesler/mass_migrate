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
        '.xml'
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

$snippets = @{}
$counter  = 0

foreach ($file in $files) {
    $relativePath = $file.FullName.Substring($SourceFolder.Length).TrimStart('\', '/')
    $relativePath = $relativePath -replace '\\', '/'

    $rawLines = Get-Content -LiteralPath $file.FullName -ErrorAction SilentlyContinue
    if ($null -eq $rawLines) { $rawLines = @() }
    if ($rawLines -isnot [array]) { $rawLines = @($rawLines) }

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
