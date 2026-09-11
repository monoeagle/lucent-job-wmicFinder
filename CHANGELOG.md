# Changelog

Alle nennenswerten Änderungen an diesem Projekt.

Format nach [Keep a Changelog](https://keepachangelog.com/de/1.1.0/),
Versionierung nach [Semantic Versioning](https://semver.org/lang/de/).

## [Unreleased]

### Behoben

- Die Ausschluss- und Endungsliste in der Report-Fußzeile wird jetzt ordinal sortiert.
  Die kulturabhängige Standardsortierung von `Sort-Object` ordnet Satzzeichen (`.`, `_`)
  zwischen Windows PowerShell 5.1 und PowerShell 7 unterschiedlich, wodurch die Fußzeile
  versionsabhängig driftete. `[Array]::Sort` mit `OrdinalIgnoreCase` erzeugt eine über
  beide Versionen identische Ausgabe und bleibt case-insensitiv.

## [1.3.0] - 2026-09-11

### Geändert

- **Der Report wird nicht mehr automatisch geöffnet.** `Start-Process` ist vollständig aus
  `Find-WmicUsage.ps1` verschwunden, ebenso der Schalter `-NoOpen`. Das Skript nennt am Ende
  nur noch den Pfad des Reports auf der Konsole, in einer eigenen Zeile zum Kopieren.

  Grund ist dieselbe Fehlerklasse wie bei 1.2.0: Ein Skript, das eine Datei schreibt und die
  anschließend startet, ist die Bauform eines Droppers — unabhängig davon, was es tatsächlich
  tut. HP Sure Click meldet **`Win32.Malware-Behavioural`**, also ein Urteil über beobachtetes
  *Verhalten*, nicht über Inhalte.

  Per Parser gegengeprüft: Das Skript ruft nur noch `ConvertTo-HtmlText`, `Format-CodeLine`,
  `Get-Date`, `Get-HitStatus`, `Get-LineIndex`, `Get-Location`, `Group-Object`, `Join-Path`,
  `New-Item`, `New-Object`, `Out-Null`, `Read-SourceText`, `Set-StrictMode`, `Sort-Object`,
  `Test-Path`, `Where-Object`, `Write-Host`, `Write-Progress` und `Write-Warning` auf —
  kein `Start-Process`, `Invoke-Item`, `Invoke-Expression` oder `Start-Job`.

### Hinweis

- Ob HP Sure Click danach schweigt, ist weiterhin **nicht verifiziert**.

## [1.2.0] - 2026-09-11

### Geändert

- **Testdaten-Generator in eine eigene Datei ausgelagert:** `New-WmicSampleData.ps1`.
  `Find-WmicUsage.ps1` verliert dadurch `-CreateSampleData` und `-Force` und hat wieder
  nur einen Parametersatz.

  Anlass war ein Fund von **HP Sure Click**, das die bisherige Einzeldatei als Schadsoftware
  einstufte. Nachvollziehbar: Der Generator legt `.bat`-, `.cmd`-, `.vbs`-, `.reg`- und
  `.ps1`-Dateien mit WMI-Kommandozeilen an, setzt eine Binärdatei aus Rohbytes inklusive
  `0x00` zusammen und kann ein Verzeichnis rekursiv leeren — als Testdatensatz gewollt, für
  eine Verhaltensanalyse von einem Dropper nicht zu unterscheiden. Alle 30 ausführbaren
  `wmic`-Literale des Projekts lagen in dieser Region, keines im Scan-Code.

  `Find-WmicUsage.ps1` enthält jetzt null solcher Literale, keine Byte-Schreiboperationen,
  kein rekursives Löschen und genau einen schreibenden Dateiaufruf: den Report. Beide
  Fassungen liefern nachweislich zeilengleiche Reports.

### Hinweis

- Ob HP Sure Click nach der Trennung schweigt, ist **nicht verifiziert** — geprüft wurde
  nur, dass die auslösenden Konstrukte aus dem Scanner verschwunden sind und das Verhalten
  unverändert ist.

## [1.1.0] - 2026-09-11

### Hinzugefügt

- `-CreateSampleData <Pfad>` als eigener Parametersatz: legt einen Testbaum mit bekannten
  wmic-Fundstellen an und gibt die Soll-Werte aus, gegen die der anschließende Scan zu
  prüfen ist. Dateiinhalt und erwartete Trefferzahl stehen in derselben Tabelle, damit sie
  nicht auseinanderdriften können.
- Der Testbaum deckt zusätzlich zu den Erkennungsfällen die Randfälle ab, die sonst
  ungeprüft bleiben: Datei über dem Größenlimit, erlaubte Endung mit NUL-Bytes,
  ausgeschlossener Unterbaum, leere Datei, Latin-1 mit Umlauten, Umlaut und Leerzeichen im
  Pfad, sehr lange Zeile.
- Deutlich breitere CMD-/BAT-Abdeckung: `REM`, `::`, kleingeschriebenes `rem`, `FOR /F` um
  einen wmic-Aufruf, `/node:` gegen einen Remote-Rechner mit `/format:csv`-Umleitung.
- `-Force` leert ein bereits erzeugtes Sampledaten-Verzeichnis. Ein nicht leeres
  Verzeichnis ohne die Markierung `.wmic-sampledata` wird auch mit `-Force` nicht
  angetastet, damit ein verrutschter Zielpfad kein echtes Verzeichnis ausräumt.
- Entwickler-Header am Dateianfang: Projekt, Zweck, Autor, Repository, Version, Stand,
  Landkarte der Regionen, Hinweise für Änderungen und Änderungshistorie. Zwischen Banner
  und `<# .SYNOPSIS #>`-Block steht zwingend eine Leerzeile — ohne sie liest PowerShell
  beides als einen Kommentarblock und `Get-Help` findet keine Hilfe mehr.

### Geändert

- Der Report öffnet sich nach dem Scan automatisch im Standardbrowser. Der bisherige
  Schalter `-Open` entfällt; `-NoOpen` unterdrückt das Öffnen, etwa für Pipeline-Läufe
  nach `Export-Csv`.
- Das Öffnen läuft plattformabhängig über `Start-Process` beziehungsweise `xdg-open`/`open`
  statt über `Invoke-Item`.
- Der Quelltext des Skripts ist jetzt reines ASCII; Umlaute in Sample-Pfaden und
  -Inhalten werden über `[char]0xNN` gebaut. Windows PowerShell 5.1 liest eine `.ps1` ohne
  BOM als ANSI und würde UTF-8-Literale verstümmeln.

## [1.0.0] - 2026-09-11

### Hinzugefügt

- `Find-WmicUsage.ps1`: rekursive Suche nach `wmic`-Aufrufen in lokalen Pfaden und
  UNC-Freigaben.
- Suchmuster `\bwmic(\.exe)?\b` mit Wortgrenzen, damit `wmiclass` und `swmic` keine
  Fehltreffer erzeugen.
- Einstufung jeder Fundstelle als `aktiv` oder `Kommentar`; Zeilenkommentar-Marker je
  Dateityp (`#`, `//`, `'`, `;`, `--`, `REM`, `::`) und XML-Blockkommentare über
  Zeilengrenzen hinweg.
- Kodierungserkennung über BOM (UTF-8, UTF-16 LE/BE, UTF-32 LE) plus NUL-Heuristik für
  UTF-16 ohne BOM, strikt UTF-8 mit Rückfall auf Latin-1.
- Eigener Verzeichnis-Walker: ausgeschlossene Unterbäume werden abgeschnitten statt
  durchlaufen, Zugriffsfehler werden dem konkreten Verzeichnis zugeordnet und im Report
  als „Nicht gelesen" ausgewiesen.
- Eigenständiger HTML-Report ohne externe Abhängigkeiten: Kachelübersicht, Filter nach
  Pfad und Status, alles auf-/zuklappen, pro Datei ein `<details>`-Block mit
  Zeilennummer, Zeileninhalt und hervorgehobener Fundstelle, Scan-Parameter in der
  Fußzeile, Hell-/Dunkeldarstellung nach Systemeinstellung.
- Parameter `-Path`, `-OutputPath`, `-Extension`, `-ExcludeDirectory`, `-MaxFileSizeMB`,
  `-Open`, `-PassThru`; `-Path` nimmt auch Pipeline-Eingaben.
- `samples/` als Selbsttest über alle Erkennungsfälle.
