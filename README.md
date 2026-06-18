# 🚀 MassMigrate

> Bring deine über Jahre gewachsene Skript-Sammlung sicher und sauber nach [massCode](https://masscode.io/) – ohne Copy-Paste-Marathon, ohne zerschossene Umlaute, ohne Datenverlust.

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B%20%7C%207%2B-5391FE?logo=powershell&logoColor=white)
![Platform](https://img.shields.io/badge/Plattform-Windows-0078D6?logo=windows&logoColor=white)
![License](https://img.shields.io/badge/Lizenz-MIT-green)
![Status](https://img.shields.io/badge/Status-aktiv%20genutzt-success)

---

## 🤔 Warum gibt es das?

[massCode](https://masscode.io/) ist ein großartiger, lokaler Snippet-Manager – aber es gibt **keinen** "Importiere einfach meinen ganzen Skript-Ordner"-Knopf. Wer über Jahre PowerShell-, Python-, VBScript- oder Batch-Skripte in verschachtelten Ordnern angesammelt hat, steht vor stundenlangem Copy-Paste.

**MassMigrate** automatisiert genau das – inklusive aller Stolperfallen, die einem dabei in der echten Welt begegnen:

- 🧟 Uralte `.ps1`-Dateien aus der PowerShell ISE, die heimlich in Windows-1252 statt UTF-8 gespeichert sind
- 🧨 Proprietäre Formate wie `.bds` (baramundi Deploy Script), bei denen man vorher gar nicht weiß, ob es reiner Text ist
- 📁 Tief verschachtelte Ordnerstrukturen, die irgendwie erhalten bleiben sollen
- 🙈 Die bange Frage "was habe ich eigentlich noch nicht migriert?"

---

## ✨ Features

- 🔎 **Automatische Encoding-Erkennung** je Datei (UTF-8 mit/ohne BOM, UTF-16 LE/BE, Windows-1252-Fallback) – keine zerschossenen Umlaute mehr
- 🛡️ **Binärdatei-Schutz**: Dateien mit rohen NUL-Bytes (z. B. undokumentierte proprietäre Formate) werden automatisch erkannt und **nicht** angefasst
- 🧬 **Natives massCode-Importformat**: erzeugt direkt eine "VS Code Snippets JSON", die massCode nativ versteht
- 🔂 Auch beim JSON-Export wird bei einer bereits bestehenden Datei nachgefragt (Überschreiben/Abbrechen, steuerbar über `-IfJsonExists`)
- 🏷️ **Tagging** aller erfolgreich migrierten Dateien im Dateinamen (`_massmigrated`)
- 📦 **ZIP-Backup** mit exakt erhaltener Ordnerstruktur – nur die migrierten Dateien
- 🔁 **Schlauer Umgang mit bestehenden Backups**: existiert unter `-ZipPath` bereits ein Archiv, fragt das Skript nach (Überschreiben / Erweitern / Abbrechen) – auch nicht-interaktiv steuerbar über `-IfZipExists`
- ✅ **ZIP-Verifikation** vor jedem Löschvorgang – im Zweifel passiert lieber gar nichts
- 🧹 **Aufräumen** des Quellordners (inkl. leer gewordener Unterordner) – alles, was übrig bleibt, muss händisch geprüft werden
- 🧯 **Natives `-WhatIf` / `-Confirm`**: erst eine echte Vorschau, dann erst löschen
- 🌍 Unterstützt von Haus aus: `.ps1` `.psm1` `.psd1` `.py` `.yaml` `.yml` `.json` `.sh` `.bat` `.cmd` `.sql` `.md` `.js` `.ts` `.html` `.css` `.xml` `.vbs` `.vba` `.reg` `.bds` – und beliebig erweiterbar

---

## 📋 Voraussetzungen

- 🪟 Windows (primär dafür entwickelt und getestet)
- 💻 PowerShell 5.1 oder PowerShell 7+
- 📥 [massCode](https://masscode.io/) 5.x (Markdown-Vault-Storage)

---

## ⚡ Schnellstart

```powershell
.\Export-ScriptsToMassCode.ps1 `
  -SourceFolder "D:\Scripts" `
  -OutputFile   "D:\masscode-import.json" `
  -ZipPath      "D:\Scripts_backup.zip"
```

Danach in massCode:

1. 📂 **Code**-Bereich öffnen
2. ⌨️ Sidebar-Aktionen oder Befehlspalette → **"Import snippets"**
3. 🎯 Quelle **"VS Code snippets JSON"** wählen
4. 📄 Die erzeugte `masscode-import.json` auswählen
5. 👀 Vorschau prüfen (Anzahl, Sprache, Warnungen)
6. ✅ **Import** klicken

---

## 🛟 Sicher unterwegs: `-WhatIf` und `-Confirm`

Der einzige *wirklich* destruktive Schritt ist das Löschen aus dem Quellordner – und genau dafür unterstützt das Skript die nativen PowerShell-Mechanismen:

```powershell
# 🔍 Nur anschauen, nichts wird geloescht (Tagging + ZIP finden trotzdem statt)
.\Export-ScriptsToMassCode.ps1 -SourceFolder "D:\Scripts" -OutputFile "D:\import.json" -ZipPath "D:\backup.zip" -WhatIf

# 🤖 Fuer automatisierte Laeufe ohne Rueckfrage
.\Export-ScriptsToMassCode.ps1 -SourceFolder "D:\Scripts" -OutputFile "D:\import.json" -ZipPath "D:\backup.zip" -Confirm:$false

# 🔁 Wiederholter Lauf: bestehendes Backup-ZIP automatisch erweitern statt nachzufragen
.\Export-ScriptsToMassCode.ps1 -SourceFolder "D:\Scripts" -OutputFile "D:\import.json" -ZipPath "D:\backup.zip" -IfZipExists Extend -Confirm:$false
```

> 💡 **Tipp:** Lass das Skript einmal gegen eine **Kopie** deines Skript-Ordners laufen, bevor du es auf die Originale ansetzt. Die ZIP-Verifikation schützt vor offensichtlichem Datenverlust, ersetzt aber kein Backup.

---

## 🧭 Wie es unter der Haube funktioniert

1. 📖 **Einlesen** – alle Dateien mit passender Endung rekursiv einsammeln, Encoding je Datei automatisch erkennen
2. 🧬 **JSON-Export** – jede Datei wird zu einem massCode-Snippet (inkl. Sprach-Mapping für Syntax-Highlighting)
3. 🏷️ **Tagging** – erfolgreich gelesene Dateien werden im Namen mit `_massmigrated` markiert
4. 📦 **ZIP-Backup** – exakt die Ordnerstruktur des Quellordners, aber nur die getaggten Dateien
5. ✅ **Verifikation** – Anzahl Einträge im ZIP muss exakt der Anzahl migrierter Dateien entsprechen
6. 🧹 **Cleanup** – getaggte Dateien + leer gewordene Ordner entfernen; alles andere bleibt bewusst liegen

Was am Ende im Quellordner übrig bleibt, ist dein **"das muss ich mir noch anschauen"**-Stapel – z. B. Dateien in einem unklaren Binärformat oder Endungen, die (noch) nicht konfiguriert sind.

---

## 🧩 Eigene Dateitypen ergänzen

Sprach-Mapping liegt als einfaches Hashtable im Skript (`$ExtensionToScope`) – einfach erweitern:

```powershell
'.ahk' = 'autohotkey'
```

Und die Endung zur `-Extensions`-Liste hinzufügen (oder beim Aufruf per Parameter überschreiben):

```powershell
.\Export-ScriptsToMassCode.ps1 -SourceFolder "D:\Scripts" -OutputFile "D:\import.json" -ZipPath "D:\backup.zip" -Extensions @('.ps1', '.ahk')
```

---

## 🐛 Bekannte Grenzen

- 📁 Das VS-Code-Snippets-JSON-Format kennt keine Ordnerstruktur – nach dem Import in massCode landet zunächst alles in einem Ordner (meist "Inbox"). Jedes Snippet trägt aber den ursprünglichen Pfad in der Beschreibung, damit du gezielt nachsortieren kannst.
- 🤷 Bei unklaren/proprietären Formaten ohne NUL-Bytes (also "sieht aus wie Text, ist aber eigentlich was anderes") greift die Binär-Erkennung nicht – im Zweifel die betroffene Endung einfach aus `-Extensions` herausnehmen.

---

## ⚠️ Wichtig für Mitwirkende: UTF-8-BOM nicht entfernen!

`Export-ScriptsToMassCode.ps1` enthält Emojis und muss daher mit **UTF-8-BOM** gespeichert sein. Ohne BOM liest **Windows PowerShell 5.1** (`powershell.exe`, nicht zu verwechseln mit `pwsh.exe`/PowerShell 7) die Datei über die System-ANSI-Codepage statt UTF-8 – die Mehrbyte-Emojis zerfallen dabei in ungültige Zeichen und der Parser bricht ab ("Die Zeichenfolge hat kein Abschlusszeichen").

Beim Bearbeiten bitte sicherstellen, dass dein Editor das BOM beibehält:

- 🟦 **VS Code**: unten rechts in der Statusleiste auf die Kodierung klicken → **"UTF-8 with BOM"** wählen
- 🟧 **Notepad++**: Menü **Kodierung** → **"UTF-8-BOM"**
- ❌ Reines `UTF-8` (ohne BOM) oder ANSI/Windows-1252 führt zu genau diesem Bug

---

## 🤝 Mitmachen

Issues, Pull Requests und Erfahrungsberichte sind herzlich willkommen! Besonders spannend:

- 🌐 Weitere Sprach-Mappings für `$ExtensionToScope`
- 🧪 Tests gegen reale, "historisch gewachsene" Skript-Ordner
- 💡 Ideen für die Behandlung von Formaten ohne klare Text/Binär-Grenze

---

## 📜 Lizenz

[MIT](LICENSE) – mach damit, was du willst, aber ohne Garantie. 🙂

---

## 🙏 Entstehungsgeschichte

Entstanden in einer ganz normalen Feierabend-IT-Automatisierungs-Session – Schritt für Schritt von "ich brauche nur einen JSON-Export" zu "okay, das soll jetzt wirklich rund laufen" gewachsen. Die komplette Entwicklung lässt sich 1:1 in der [Commit-Historie](../../commits/main) nachvollziehen. 📜✨
