# Changelog

Alle nennenswerten Änderungen an diesem Projekt.

Format nach [Keep a Changelog](https://keepachangelog.com/de/1.1.0/),
Versionierung nach [Semantic Versioning](https://semver.org/lang/de/).

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
  Landkarte der Regionen, Hinweise für Änderungen und Änderungshistorie.

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
