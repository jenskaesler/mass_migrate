# 📝 Changelog

Alle nennenswerten Änderungen an diesem Projekt werden hier dokumentiert.

Format angelehnt an [Keep a Changelog](https://keepachangelog.com/de/1.0.0/),
Versionierung nach [Semantic Versioning](https://semver.org/lang/de/).

---

## [1.1.1] – 2026-06-18

### 🐛 Behoben
- 🚨 **Bug**: Existierte unter `-ZipPath` bereits ein Archiv, wurde es bisher stillschweigend gelöscht und neu angelegt. Jetzt fragt das Skript interaktiv nach: **Überschreiben**, **Erweitern** oder **Abbrechen**
- 🔁 Neuer Parameter `-IfZipExists` (`Ask` / `Overwrite` / `Extend`) für nicht-interaktive Steuerung in automatisierten Läufen
- ➕ Im Erweitern-Modus werden vorhandene Einträge mit gleichem relativem Pfad aktualisiert statt dupliziert; alle übrigen Einträge des bestehenden Archivs bleiben unangetastet
- 🛡️ ZIP-Verifikation korrigiert: prüft jetzt, ob jede migrierte Datei im Archiv vorhanden ist, statt nur die Gesamtanzahl der Einträge zu vergleichen (Letzteres wäre beim Erweitern eines bereits gefüllten Archivs immer fehlgeschlagen)
- ↩️ Beim Abbrechen wird das zuvor gesetzte `_massmigrated`-Tagging automatisch zurückgenommen, sodass der Quellordner wirklich unverändert bleibt

---

## [1.1.0] – 2026-06-18

### ✨ Hinzugefügt
- 🧯 Natives `-WhatIf` / `-Confirm` über `SupportsShouldProcess` statt handgestrickter `Read-Host`-Abfrage
- 📊 `Write-Progress`-Fortschrittsanzeige während des Einlesens
- 🎨 Banner & farbige Abschnitts-Header für eine aufgeräumtere Konsolenausgabe
- 🗂️ Code in `#region`-Blöcke gegliedert (Helpers / Banner / Phase 1–5)

### 🔄 Geändert
- Der bisherige `-Force`-Switch entfällt zugunsten des PowerShell-Standards `-Confirm:$false`
- Tagging und ZIP-Erstellung laufen weiterhin immer real (explizit `-WhatIf:$false`) – nur der finale Löschschritt ist "WhatIf-fähig", damit eine Vorschau nicht in einem inkonsistenten Zwischenzustand endet

---

## [1.0.0] – 2026-06-18

### ✨ Hinzugefügt
- 🏷️ Tagging aller erfolgreich migrierten Dateien im Dateinamen (`_massmigrated`)
- 📦 ZIP-Archiv mit exakt erhaltener Ordnerstruktur, das ausschließlich getaggte Dateien enthält
- ✅ ZIP-Verifikation (Anzahl Einträge ↔ Anzahl migrierter Dateien) vor jedem Löschvorgang
- 🧹 Cleanup-Phase: Entfernen der migrierten Dateien sowie dadurch leer gewordener Ordner
- 🙈 Alles, was nicht migriert werden konnte, bleibt absichtlich liegen – das macht auf einen Blick sichtbar, was noch händisch zu prüfen ist

> ⚠️ Breaking Change: Aus dem reinen Export-Skript wird ein vollwertiges (destruktives!) Migrations-Werkzeug.

---

## [0.4.0] – 2026-06-18

### ✨ Hinzugefügt
- 🛡️ Binärdatei-Erkennung über eine NUL-Byte-Heuristik – Dateien, die kein reiner Text sind (z. B. proprietäre Formate wie `.bds`), werden automatisch vom Export ausgeschlossen statt als Datenmüll importiert zu werden

---

## [0.3.0] – 2026-06-18

### ✨ Hinzugefügt
- 🌐 Unterstützung für `.vbs`, `.vba`, `.reg` und `.bds`
- 🎨 Sprach-Mapping für VBScript, VBA und Windows-Registry-Dateien

---

## [0.2.0] – 2026-06-18

### 🐛 Behoben
- 🔎 Automatische, robuste Encoding-Erkennung pro Datei (UTF-8 mit/ohne BOM, UTF-16 LE/BE, Windows-1252-Fallback) – verhindert zerschossene Umlaute/Sonderzeichen bei alten, unter Windows ohne explizites UTF-8 gespeicherten Skripten
- 📋 Zusammenfassung der erkannten Encodings am Skriptende inkl. Liste der Fallback-Fälle zur stichprobenartigen Kontrolle

---

## [0.1.0] – 2026-06-18

### ✨ Hinzugefügt
- 🎉 Initiale Version: Export loser Skriptdateien als VS-Code-Snippets-JSON für den nativen massCode-Import
- `$`-Escaping, damit PowerShell-Variablen nicht versehentlich als Snippet-Tabstops interpretiert werden
