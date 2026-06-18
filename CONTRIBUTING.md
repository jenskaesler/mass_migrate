# 🤝 Contributing to MassMigrate

Erstmal danke, dass du dir die Zeit nimmst, zum Projekt beizutragen! Hier steht alles, was du wissen musst, bevor du loslegst.

---

## 🚀 Schnelleinstieg

- 🍴 Repo forken
- 🌿 Feature-Branch erstellen: `git checkout -b feat/mein-feature`
- ✏️ Änderungen machen (siehe Hinweise unten!)
- ✅ Testen (siehe unten)
- 📬 Pull Request gegen `main` öffnen

---

## ⚠️ Kritisch: UTF-8-BOM nicht entfernen!

`Export-ScriptsToMassCode.ps1` enthält Emojis und **muss zwingend mit UTF-8-BOM gespeichert werden**. Ohne BOM liest Windows PowerShell 5.1 die Datei über die System-ANSI-Codepage – die Emojis zerfallen in ungültige Zeichen und der Parser bricht mit `ParseException` ab.

Bitte sicherstellen, dass dein Editor das BOM beim Speichern beibehält:

- 🟦 **VS Code**: unten rechts in der Statusleiste auf die Kodierung klicken → **"UTF-8 with BOM"** wählen
- 🟧 **Notepad++**: Menü **Kodierung** → **"UTF-8-BOM"**
- 🟨 **PowerShell ISE**: speichert standardmäßig mit BOM – hier ist alles gut
- ❌ Reines `UTF-8` (ohne BOM) führt zu genau diesem Bug, auch wenn der Inhalt technisch identisch ist

> 💡 Schnellcheck: `Format-Hex .\Export-ScriptsToMassCode.ps1 | Select-Object -First 1` – die ersten drei Bytes müssen `EF BB BF` sein.

---

## 🧪 Testen vor dem PR

Da das Skript destruktive Schritte enthält (Umbenennen, Löschen), bitte immer gegen eine **Kopie** eines Testordners testen – nie gegen echte Produktivdaten.

Empfohlene Schnelltests:

- 🔍 **Dry-Run** – kein Löschen, aber Tagging und ZIP finden statt:
  ```powershell
  .\Export-ScriptsToMassCode.ps1 -SourceFolder "C:\TestScripts" -OutputFile "C:\Temp\test.json" -ZipPath "C:\Temp\test.zip" -WhatIf
  ```

- 🔄 **Encoding-Mix** – Testordner mit Dateien in verschiedenen Encodings anlegen (UTF-8 mit/ohne BOM, Windows-1252) und prüfen, ob Umlaute im erzeugten JSON korrekt ankommen

- 🛡️ **Binärdatei-Schutz** – eine Datei mit NUL-Bytes in den Testordner legen und sicherstellen, dass sie weder getaggt noch ins ZIP wandert und explizit in der Ausgabe gelistet wird

- 🔁 **Wiederholter Lauf** – Skript zweimal mit gleichem `-ZipPath` ausführen und alle drei ZIP-Konflikt-Optionen (Überschreiben/Erweitern/Abbrechen) durchspielen

- ↩️ **Abbruch-Verhalten** – beim ZIP-Konflikt "Abbrechen" wählen und prüfen, dass keine `_massmigrated`-Tags im Quellordner zurückbleiben

---

## 🌿 Branch-Konventionen

- `feat/...` – neue Features
- `fix/...` – Bugfixes
- `docs/...` – nur Dokumentation
- `chore/...` – Wartung, Abhängigkeiten, CI

---

## 📝 Commit-Stil

Wir folgen [Conventional Commits](https://www.conventionalcommits.org/de/):

- `feat: kurze Beschreibung` – neues Feature
- `fix: kurze Beschreibung` – Bugfix
- `docs: kurze Beschreibung` – Dokumentation
- `chore: kurze Beschreibung` – Wartung
- `feat!:` oder `fix!:` – Breaking Change

Commit-Nachrichten auf Deutsch oder Englisch – Hauptsache konsistent innerhalb eines PRs.

---

## 🌐 Sprach-Mappings ergänzen

Das ist der häufigste und einfachste Beitrag! So geht's:

- In `$ExtensionToScope` einen neuen Eintrag hinzufügen:
  ```powershell
  '.ahk' = 'autohotkey'
  ```
- Die Endung auch in `$Extensions` ergänzen
- Im PR kurz erklären, was das Format ist und woher das Language-ID-Mapping kommt (Referenz: [VS Code Language Identifiers](https://code.visualstudio.com/docs/languages/identifiers))

---

## 🐛 Bugs melden

Bitte ein [Issue](https://github.com/jenskaesler/mass_migrate/issues) öffnen mit:

- 🖥️ PowerShell-Version (`$PSVersionTable.PSVersion`)
- 🪟 Windows-Version
- 📋 Der vollständige Fehlertext
- 📁 Dateiendungen und ggf. Encoding der betroffenen Dateien (soweit bekannt)
- 🔁 Schritte zur Reproduktion

---

## 📜 Lizenz

Mit einem Pull Request stimmst du zu, dass dein Beitrag unter der [MIT-Lizenz](LICENSE) dieses Projekts veröffentlicht wird.
