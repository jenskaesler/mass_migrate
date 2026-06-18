<#
.SYNOPSIS
    🚀 MassMigrate - migriert bestehende Skript-Sammlungen sicher nach massCode.

.DESCRIPTION
    Liest Skript-Dateien aus einem Ordner (rekursiv), erzeugt eine
    VS-Code-Snippets-JSON-Datei fuer massCode, taggt die erfolgreich
    gelesenen Dateien im Dateinamen, packt sie unter Beibehaltung der
    Ordnerstruktur in ein ZIP-Archiv und entfernt sie anschliessend aus
    dem Quellordner (inkl. dadurch leer gewordener Unterordner).

    Ablauf:
      1. 📖  Dateien im Quellordner (rekursiv, passende Extensions) einlesen.
            Encoding wird je Datei automatisch erkannt (UTF-8/UTF-16 per BOM,
            sonst UTF-8 oder Windows-1252-Fallback). Dateien mit rohen
            NUL-Bytes gelten als "vermutlich Binaerdatei" und werden NICHT
            angefasst (kein Tag, kein ZIP-Eintrag, bleiben unveraendert liegen).
      2. 🧬  VS-Code-Snippets-JSON fuer massCode schreiben.
      3. 🏷️  Alle erfolgreich gelesenen Dateien im Dateinamen mit
            "_massmigrated" taggen (vor der Dateiendung).
      4. 📦  ZIP-Archiv erstellen, das exakt die Ordnerstruktur des
            Quellordners abbildet, aber NUR die getaggten Dateien enthaelt.
      5. ✅  ZIP verifizieren (Anzahl Eintraege vs. Anzahl migrierter Dateien).
            Nur bei Erfolg geht es weiter.
      6. 🧹  Nach Bestaetigung die getaggten Dateien aus dem Quellordner
            loeschen, danach alle dadurch leer gewordenen Ordner entfernen.
            Alles, was NICHT migriert werden konnte, bleibt liegen und zeigt
            damit auf einen Blick, was noch haendisch zu pruefen ist.

    Dieser letzte, destruktive Schritt unterstuetzt die nativen PowerShell-
    Mechanismen -WhatIf (Vorschau ohne Aenderungen) und -Confirm
    (Rueckfrage erzwingen bzw. mit -Confirm:$false unterdruecken).

    Wichtig: Das VS-Code-Snippet-Format verwendet "$" fuer Tabstops/Variablen
    (z.B. $1, ${1:name}). Da PowerShell-Skripte voller "$"-Variablen sind,
    werden alle "$" automatisch zu "\$" escaped, damit dein Code unveraendert
    als reiner Text importiert wird.

.PARAMETER SourceFolder
    Ordner, der deine bestehenden Skripte enthaelt (wird rekursiv durchsucht).

.PARAMETER OutputFile
    Pfad der JSON-Datei, die anschliessend in massCode importiert wird.

.PARAMETER ZipPath
    Pfad des ZIP-Archivs, das die migrierten Dateien (Ordnerstruktur erhalten)
    sichert, bevor sie aus dem Quellordner geloescht werden.

.PARAMETER IfZipExists
    Verhalten, falls unter -ZipPath bereits eine Datei existiert:
    'Ask' (Standard) fragt interaktiv nach (Ueberschreiben/Erweitern/Abbrechen),
    'Overwrite' ersetzt das bestehende Archiv ohne Rueckfrage,
    'Extend' fuegt neue Dateien hinzu und aktualisiert vorhandene Eintraege mit
    gleichem relativem Pfad, der Rest des Archivs bleibt unangetastet.

.PARAMETER Extensions
    Dateiendungen, die beruecksichtigt werden sollen.

.EXAMPLE
    .\Export-ScriptsToMassCode.ps1 -SourceFolder "D:\Scripts" -OutputFile "D:\masscode-import.json" -ZipPath "D:\Scripts_backup.zip"

.EXAMPLE
    # Vorschau ohne jegliche Aenderung am Quellordner (Tagging/ZIP finden trotzdem statt,
    # nur der finale Loeschschritt wird simuliert):
    .\Export-ScriptsToMassCode.ps1 -SourceFolder "D:\Scripts" -OutputFile "D:\masscode-import.json" -ZipPath "D:\Scripts_backup.zip" -WhatIf

.EXAMPLE
    # Fuer automatisierte Laeufe ohne Rueckfrage:
    .\Export-ScriptsToMassCode.ps1 -SourceFolder "D:\Scripts" -OutputFile "D:\masscode-import.json" -ZipPath "D:\Scripts_backup.zip" -Confirm:$false

.EXAMPLE
    # Wiederholter Lauf: bestehendes Backup-ZIP automatisch erweitern statt nachzufragen
    .\Export-ScriptsToMassCode.ps1 -SourceFolder "D:\Scripts" -OutputFile "D:\masscode-import.json" -ZipPath "D:\Scripts_backup.zip" -IfZipExists Extend -Confirm:$false

.LINK
    https://github.com/<dein-user>/MassMigrate
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory = $true)]
    [string]$SourceFolder,

    [Parameter(Mandatory = $true)]
    [string]$OutputFile,

    [Parameter(Mandatory = $true)]
    [string]$ZipPath,

    [ValidateSet('Ask', 'Overwrite', 'Extend')]
    [string]$IfZipExists = 'Ask',

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

#region Helpers

function Write-Section {
    param(
        [string]$Icon,
        [string]$Text,
        [string]$Color = 'Cyan'
    )
    Write-Host ""
    Write-Host "$Icon  $Text" -ForegroundColor $Color
    Write-Host ('-' * ($Text.Length + 4)) -ForegroundColor DarkGray
}

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
    # '.bds' bewusst ohne Mapping - Format unklar (proprietaeres baramundi
    # Deployment Script), landet als Plain Text in massCode.
}

# Liest eine Datei robust ein: erkennt BOM (UTF-8/UTF-16) automatisch.
# Ist kein BOM vorhanden, wird zunaechst strikt UTF-8 versucht; schlaegt das
# fehl (ungueltige Bytefolge), wird nach Windows-1252 (ANSI) zurueckgefallen.
# Rohe NUL-Bytes (ausserhalb eines erkannten BOM) gelten als Indiz fuer eine
# Binaer-/Strukturdatei (z.B. proprietaere Formate wie .bds) und werden
# NICHT als Text behandelt.
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
        if ($bytes -contains [byte]0) {
            $text         = $null
            $encodingUsed = 'Vermutlich Binaerdatei (NUL-Byte gefunden)'
        }
        else {
            try {
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
    }

    if ($null -eq $text) {
        return [PSCustomObject]@{
            Lines    = @()
            Encoding = $encodingUsed
            IsBinary = $true
        }
    }

    $lines = $text -split "`r`n|`r|`n"

    return [PSCustomObject]@{
        Lines    = $lines
        Encoding = $encodingUsed
        IsBinary = $false
    }
}

#endregion Helpers

#region Banner

Write-Host ""
Write-Host "  🚀  MassMigrate" -ForegroundColor Magenta
Write-Host "      Skripte ab in die massCode-Zukunft." -ForegroundColor DarkGray

#endregion Banner

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

$snippets       = @{}
$counter        = 0
$encodingLog    = New-Object System.Collections.Generic.List[object]
$binarySuspects = New-Object System.Collections.Generic.List[object]
$migratedFiles  = New-Object System.Collections.Generic.List[object]

#region Phase 1: Einlesen + JSON-Snippets aufbauen

Write-Section -Icon '📖' -Text 'Lese Skripte ein & baue massCode-Snippets'

$fileIndex = 0
foreach ($file in $files) {
    $fileIndex++
    Write-Progress -Activity 'Lese Skripte ein' -Status $file.Name -PercentComplete (($fileIndex / $files.Count) * 100)

    $relativePath = $file.FullName.Substring($SourceFolder.Length).TrimStart('\', '/')
    $relativePath = $relativePath -replace '\\', '/'

    $fileContent = Get-SmartFileLines -Path $file.FullName

    if ($fileContent.IsBinary) {
        $binarySuspects.Add($relativePath)
        continue
    }

    $rawLines = $fileContent.Lines
    if ($null -eq $rawLines) { $rawLines = @() }
    if ($rawLines -isnot [array]) { $rawLines = @($rawLines) }

    $encodingLog.Add([PSCustomObject]@{ Datei = $relativePath; Encoding = $fileContent.Encoding })

    # "$" escapen, damit VS-Code-Snippet-Syntax (Tabstops/Variablen) nicht greift
    $escapedLines = $rawLines | ForEach-Object { $_ -replace '\$', '\$' }

    $ext   = $file.Extension.ToLower()
    $scope = $ExtensionToScope[$ext]

    # Eindeutigen Key sicherstellen (Pfad ist i.d.R. schon eindeutig)
    $key    = $relativePath
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

    $migratedFiles.Add([PSCustomObject]@{
        OriginalFullName = $file.FullName
        RelativePath     = $relativePath
        BaseName         = $file.BaseName
        Extension        = $file.Extension
    })
}
Write-Progress -Activity 'Lese Skripte ein' -Completed

$json = $snippets | ConvertTo-Json -Depth 6

# Ohne BOM speichern
[System.IO.File]::WriteAllText($OutputFile, $json, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "✅ $counter Skripte exportiert nach $OutputFile" -ForegroundColor Green
Write-Host ""
Write-Host "Erkannte Encodings (zur Kontrolle):" -ForegroundColor Cyan
$encodingLog | Group-Object Encoding | Sort-Object Count -Descending |
    ForEach-Object { Write-Host ("  {0,-32} {1,4} Datei(en)" -f $_.Name, $_.Count) }

$fallbackFiles = $encodingLog | Where-Object { $_.Encoding -eq 'Windows-1252 / ANSI (Fallback)' }
if ($fallbackFiles.Count -gt 0) {
    Write-Host ""
    Write-Host "⚠️  Diese Dateien wurden per ANSI-Fallback gelesen - bitte nach dem Import" -ForegroundColor Yellow
    Write-Host "   stichprobenartig auf korrekte Umlaute/Sonderzeichen pruefen:" -ForegroundColor Yellow
    $fallbackFiles | ForEach-Object { Write-Host "   - $($_.Datei)" }
}

if ($binarySuspects.Count -gt 0) {
    Write-Host ""
    Write-Host "🚫 Diese Dateien enthalten rohe NUL-Bytes und wurden NICHT exportiert," -ForegroundColor Red
    Write-Host "   und werden auch NICHT getaggt/gezippt/geloescht. Bitte manuell pruefen:" -ForegroundColor Red
    $binarySuspects | ForEach-Object { Write-Host "   - $_" }
}

if ($migratedFiles.Count -eq 0) {
    Write-Warning "Keine Datei konnte migriert werden - kein Tagging, kein ZIP, kein Loeschen."
    return
}

#endregion Phase 1

#region Phase 2: Migrierte Dateien im Namen taggen ("_massmigrated")

Write-Section -Icon '🏷️' -Text "Tagge $($migratedFiles.Count) migrierte Datei(en)"

foreach ($item in $migratedFiles) {
    $directory = Split-Path -Path $item.OriginalFullName -Parent

    if ($item.BaseName -like '*_massmigrated') {
        # Bereits getaggt (z.B. erneuter Lauf) - nicht doppelt taggen
        $newFullName = $item.OriginalFullName
    }
    else {
        $newLeaf     = "$($item.BaseName)_massmigrated$($item.Extension)"
        Rename-Item -LiteralPath $item.OriginalFullName -NewName $newLeaf -WhatIf:$false -Confirm:$false
        $newFullName = Join-Path -Path $directory -ChildPath $newLeaf
    }

    $newRelativePath = $newFullName.Substring($SourceFolder.Length).TrimStart('\', '/') -replace '\\', '/'

    $item | Add-Member -NotePropertyName NewFullName     -NotePropertyValue $newFullName
    $item | Add-Member -NotePropertyName NewRelativePath -NotePropertyValue $newRelativePath
}

Write-Host "✅ Tagging abgeschlossen." -ForegroundColor Green

#endregion Phase 2

#region Phase 3: ZIP-Archiv erstellen (nur getaggte Dateien, Ordnerstruktur erhalten)

Write-Section -Icon '📦' -Text "Packe ZIP-Archiv: $ZipPath"

$zipMode = [System.IO.Compression.ZipArchiveMode]::Create

if (Test-Path -LiteralPath $ZipPath) {
    $resolvedAction = $IfZipExists

    if ($resolvedAction -eq 'Ask') {
        Write-Host "⚠️  Es existiert bereits ein ZIP-Archiv unter diesem Pfad:" -ForegroundColor Yellow
        Write-Host "   $ZipPath" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "   [U] Ueberschreiben - bestehendes Archiv wird ersetzt" -ForegroundColor Cyan
        Write-Host "   [E] Erweitern      - neue Dateien werden hinzugefuegt, Rest bleibt erhalten" -ForegroundColor Cyan
        Write-Host "   [A] Abbrechen      - Skript wird beendet, nichts wird veraendert" -ForegroundColor Cyan
        Write-Host ""

        do {
            $choice = Read-Host "Was moechtest du tun? (U/E/A)"
        } while ($choice -notmatch '^[UuEeAa]$')

        $resolvedAction = switch -Regex ($choice) {
            '^[Uu]$' { 'Overwrite' }
            '^[Ee]$' { 'Extend' }
            '^[Aa]$' { 'Abort' }
        }
    }

    switch ($resolvedAction) {
        'Overwrite' {
            Remove-Item -LiteralPath $ZipPath -Force -WhatIf:$false -Confirm:$false
            $zipMode = [System.IO.Compression.ZipArchiveMode]::Create
            Write-Host "🗑️  Bestehendes Archiv wird ersetzt." -ForegroundColor Yellow
        }
        'Extend' {
            $zipMode = [System.IO.Compression.ZipArchiveMode]::Update
            Write-Host "➕ Bestehendes Archiv wird erweitert." -ForegroundColor Yellow
        }
        'Abort' {
            Write-Host "↩️  Abgebrochen - Tagging wird rueckgaengig gemacht, Quellordner bleibt unveraendert." -ForegroundColor Yellow
            foreach ($item in $migratedFiles) {
                if ($item.NewFullName -ne $item.OriginalFullName) {
                    $originalLeaf = Split-Path -Path $item.OriginalFullName -Leaf
                    Rename-Item -LiteralPath $item.NewFullName -NewName $originalLeaf -WhatIf:$false -Confirm:$false
                }
            }
            return
        }
        default {
            throw "Unbekannter Wert fuer -IfZipExists: '$resolvedAction'"
        }
    }
}

$zipDir = Split-Path -Path $ZipPath -Parent
if ($zipDir -and -not (Test-Path -LiteralPath $zipDir)) {
    New-Item -ItemType Directory -Path $zipDir -Force -WhatIf:$false -Confirm:$false | Out-Null
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$fileMode = if ($zipMode -eq [System.IO.Compression.ZipArchiveMode]::Update) {
    [System.IO.FileMode]::Open
}
else {
    [System.IO.FileMode]::Create
}

$zipStream = [System.IO.File]::Open($ZipPath, $fileMode)
try {
    $archive = New-Object System.IO.Compression.ZipArchive($zipStream, $zipMode)
    try {
        foreach ($item in $migratedFiles) {
            if ($zipMode -eq [System.IO.Compression.ZipArchiveMode]::Update) {
                # Falls beim Erweitern bereits ein Eintrag mit demselben relativen
                # Pfad existiert (z.B. erneuter Lauf), zuerst entfernen, damit kein
                # doppelter/veralteter Eintrag im Archiv landet.
                $existingEntry = $archive.GetEntry($item.NewRelativePath)
                if ($existingEntry) {
                    $existingEntry.Delete()
                }
            }

            $entry       = $archive.CreateEntry($item.NewRelativePath, [System.IO.Compression.CompressionLevel]::Optimal)
            $entryStream = $entry.Open()
            try {
                $fileBytes = [System.IO.File]::ReadAllBytes($item.NewFullName)
                $entryStream.Write($fileBytes, 0, $fileBytes.Length)
            }
            finally {
                $entryStream.Dispose()
            }
        }
    }
    finally {
        $archive.Dispose()
    }
}
finally {
    $zipStream.Dispose()
}

Write-Host "✅ ZIP erstellt." -ForegroundColor Green

#endregion Phase 3

#region Phase 4: ZIP verifizieren - erst bei Erfolg geht es weiter

Write-Section -Icon '✅' -Text 'Verifiziere ZIP-Archiv'

$verifyArchive = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
$entryNames    = $verifyArchive.Entries | ForEach-Object { $_.FullName }
$totalEntries  = $verifyArchive.Entries.Count
$verifyArchive.Dispose()

$missing = $migratedFiles | Where-Object { $entryNames -notcontains $_.NewRelativePath }

if ($missing.Count -gt 0) {
    $missingList = ($missing | ForEach-Object { $_.NewRelativePath }) -join ', '
    throw "ZIP-Verifikation fehlgeschlagen: $($missing.Count) migrierte Datei(en) fehlen im Archiv ($missingList). Abbruch - es wird NICHTS geloescht."
}

Write-Host "✅ Alle $($migratedFiles.Count) migrierten Datei(en) im Archiv bestaetigt ($totalEntries Eintraege gesamt)." -ForegroundColor Green

#endregion Phase 4

#region Phase 5: Bestaetigung + Loeschen + leere Ordner entfernen

Write-Section -Icon '🧹' -Text 'Aufraeumen im Quellordner'

$target = "$($migratedFiles.Count) migrierte Datei(en) in '$SourceFolder'"
$action = 'Aus dem Quellordner entfernen (ZIP ist verifiziert vorhanden)'

if ($PSCmdlet.ShouldProcess($target, $action)) {
    foreach ($item in $migratedFiles) {
        Remove-Item -LiteralPath $item.NewFullName -Force -Confirm:$false
    }
    Write-Host "✅ $($migratedFiles.Count) migrierte Datei(en) entfernt." -ForegroundColor Green

    # Leere Ordner entfernen - tiefste Pfade zuerst, damit Kaskaden
    # (Ordner wird durch Entfernen seiner Unterordner selbst leer) korrekt greifen
    $removedDirs = 0
    Get-ChildItem -LiteralPath $SourceFolder -Recurse -Directory |
        Sort-Object { $_.FullName.Length } -Descending |
        ForEach-Object {
            if ((Get-ChildItem -LiteralPath $_.FullName -Force | Measure-Object).Count -eq 0) {
                Remove-Item -LiteralPath $_.FullName -Force -Confirm:$false
                $removedDirs++
            }
        }
    Write-Host "✅ $removedDirs leere(r) Ordner entfernt." -ForegroundColor Green

    $remaining = Get-ChildItem -LiteralPath $SourceFolder -Recurse -File -ErrorAction SilentlyContinue
    Write-Host ""
    if ($remaining.Count -gt 0) {
        Write-Host "👀 Verbleibend im Quellordner (= haendisch pruefen):" -ForegroundColor Yellow
        $remaining | ForEach-Object {
            Write-Host "   - $($_.FullName.Substring($SourceFolder.Length).TrimStart('\','/'))"
        }
    }
    else {
        Write-Host "🎉 Quellordner ist jetzt leer - alles wurde migriert." -ForegroundColor Green
    }
}
else {
    Write-Host "ℹ️  Loeschen uebersprungen (WhatIf bzw. nicht bestaetigt)." -ForegroundColor Yellow
    Write-Host "   Migrierte Dateien liegen weiterhin mit '_massmigrated' im Namen im" -ForegroundColor Yellow
    Write-Host "   Quellordner, das ZIP wurde trotzdem erstellt." -ForegroundColor Yellow
}

#endregion Phase 5

Write-Host ""
Write-Host "🏁 Fertig!" -ForegroundColor Magenta
