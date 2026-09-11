# wmicFinder

Findet verbliebene `wmic`-Aufrufe in Quellordnern und schreibt sie in einen
eigenständigen HTML-Report.

`wmic` (WMI Command-line Utility) ist ab **Windows 11 25H2** nicht mehr Bestandteil des
Betriebssystems. Skripte, die es aufrufen, laufen dort ins Leere. Dieses Werkzeug macht
sichtbar, wo überall noch aufgeräumt werden muss.

## Anforderungen

- Windows PowerShell 5.1 **oder** PowerShell 7+
- Lesezugriff auf die Quellordner (lokal oder UNC)

## Aufruf

```powershell
# Ordner scannen -- der Report öffnet sich anschließend im Browser
.\Find-WmicUsage.ps1 -Path C:\Projekte

# Mehrere Quellen, davon eine Netzwerkfreigabe
.\Find-WmicUsage.ps1 -Path \\fs01\skripte$, D:\Tools -OutputPath C:\Temp\wmic.html

# Nur Skriptdateien, Ergebnis als CSV, ohne Browser
.\Find-WmicUsage.ps1 -Path C:\Projekte -Extension ps1,bat,cmd,vbs -NoOpen -PassThru |
    Export-Csv .\wmic.csv -NoTypeInformation -Encoding UTF8

# Quellen über die Pipeline
Get-ChildItem D:\Repos -Directory | .\Find-WmicUsage.ps1
```

> Beim Aufruf über `pwsh -File` wird eine Liste wie `-Path a,b` als **eine** Zeichenkette
> übergeben — das ist eine Eigenheit von `-File`, nicht des Skripts. Für mehrere Pfade
> `pwsh -Command "& .\Find-WmicUsage.ps1 -Path 'a','b'"` verwenden.

## Testdaten erzeugen und dagegen prüfen

Zwei Läufe: erst einen Testbaum anlegen, dann dagegen scannen.

```powershell
# Lauf 1 -- Testdaten anlegen, gibt die Soll-Werte aus
.\Find-WmicUsage.ps1 -CreateSampleData C:\Temp\wmic-test

# Lauf 2 -- dagegen scannen, muss die Soll-Werte treffen
.\Find-WmicUsage.ps1 -Path C:\Temp\wmic-test
```

Lauf 1 gibt eine Tabelle aus, die pro Datei nennt, wie viele aktive und wie viele
auskommentierte Fundstellen zu erwarten sind und welchen Fall die Datei abdeckt. Am Ende
steht der fertige Befehl für Lauf 2.

**Dateiinhalt und erwartete Trefferzahl stehen im Skript in derselben Tabelle.** Wer eine
Sample-Datei ändert, sieht die zugehörige Erwartung direkt daneben — eine im README
gepflegte Zahl wäre nach der zweiten Änderung falsch.

Der erzeugte Baum deckt ab:

| Datei | prüft |
|---|---|
| `Deploy.ps1` | `#`-Kommentar, `wmic.exe`, Nicht-Treffer `wmiclass` |
| `legacy.cmd` | `REM`, `::`, `FOR /F` um `wmic`, `/node:` mit `/format:csv` |
| `Skripte\Prüfung\Tief\collect.bat` | `.bat` tief im Baum, kleines `rem`, `FOR /F`, `/format:list` |
| `query.vbs` | Hochkomma als Kommentar, Aufruf über `WScript.Shell` |
| `notes.md` | kein Kommentarmarker; `wmiclass`/`swmic` bleiben stumm |
| `Inventory-utf16.ps1` | UTF-16 LE mit BOM — der Default von Windows PowerShell 5.1 |
| `ANSI-Umlaute.ps1` | Latin-1 mit Umlauten — Rückfall der Kodierungserkennung |
| `leer.ps1` | leere Datei |
| `Konfiguration alt\config.xml` | Leerzeichen im Ordnernamen, XML-Blockkommentar über Zeilen |
| `Konfiguration alt\setup.ini` | `;`-Kommentar gegen Wert hinter `=` |
| `Skripte\Prüfung\Tief\inventory.sql` | `--`-Kommentar |
| `Skripte\Prüfung\Tief\collect.py` | `#`-Kommentar gegen `subprocess`-Aufruf |
| `Skripte\Prüfung\Tief\export.reg` | Wert in Anführungszeichen |
| `Gross\minified.js` | sehr lange Zeile → Zeilenkürzung im Report |
| `Gross\riesig.txt` | ~11 MB mit Treffer → **muss** am Größenlimit scheitern |
| `Binaer\getarnt.txt` | erlaubte Endung, aber NUL-Bytes → **muss** als binär gelten |
| `node_modules\skip.js` | ausgeschlossener Unterbaum → darf nicht gelesen werden |
| `sub\nohit.ps1` | bereits migriert, zählt aber als durchsucht |

Die letzten vier sind die wertvollen: Größenlimit, Binärerkennung und Ausschluss sind
genau die Pfade, die man sonst nie prüft und die still danebenliegen können.

**Schutz vor Tippfehlern im Zielpfad:** Der Generator legt im Zielordner die Markierung
`.wmic-sampledata` ab. Ein vorhandener, nicht leerer Ordner **ohne** diese Markierung wird
auch mit `-Force` nicht angetastet — ein verrutschter Pfad räumt kein echtes Verzeichnis
aus. Ein markierter Ordner wird nur mit `-Force` geleert und neu befüllt.

## Parameter

### Scannen

| Parameter | Standard | Bedeutung |
|---|---|---|
| `-Path` | *(Pflicht)* | Ein oder mehrere Quellordner, lokal oder UNC. Nimmt auch Pipeline-Eingaben. |
| `-OutputPath` | `.\wmic-report_<yyyyMMdd-HHmmss>.html` | Zieldatei des Reports. Fehlende Ordner werden angelegt. |
| `-Extension` | 24 Skript-/Code-/Konfig-Endungen (siehe Report-Fußzeile) | Zu durchsuchende Dateiendungen, ohne Punkt. |
| `-ExcludeDirectory` | `.git .svn .hg node_modules bin obj _deps .archiv` | Verzeichnisnamen, deren Unterbaum gar nicht erst betreten wird. |
| `-MaxFileSizeMB` | `10` | Größere Dateien werden übersprungen und in der Fußzeile gezählt. |
| `-NoOpen` | *(aus)* | Unterdrückt das automatische Öffnen des Reports im Browser. |
| `-PassThru` | *(aus)* | Fundstellen zusätzlich als Objekte auf die Pipeline geben. |

### Testdaten erzeugen

| Parameter | Bedeutung |
|---|---|
| `-CreateSampleData <Pfad>` | Legt den Testbaum an und gibt die Soll-Werte aus. Schließt alle Scan-Parameter aus. |
| `-Force` | Leert ein bereits erzeugtes Sampledaten-Verzeichnis und legt es neu an. |

## Wie erkannt wird

**Suchmuster:** `\bwmic(\.exe)?\b`, Groß-/Kleinschreibung egal. Die Wortgrenzen sorgen
dafür, dass `wmiclass` oder `swmic` keine Fehltreffer erzeugen, `wmic.exe` dagegen
vollständig markiert wird.

**Einstufung je Fundstelle:**

| Status | Wann |
|---|---|
| `aktiv` | Die Stelle steht in ausführbarem Code. |
| `Kommentar` | Vor der Stelle steht ein Zeilenkommentar-Marker des jeweiligen Dateityps (`#`, `//`, `'`, `;`, `--`, `REM`, `::`) oder sie liegt in einem offenen XML-Blockkommentar `<!-- … -->`. |

Im Zweifel lautet die Einstufung `aktiv` — lieber eine harmlose Stelle zu viel prüfen als
eine echte übersehen.

**Kodierung:** BOM hat Vorrang (UTF-8, UTF-16 LE/BE, UTF-32 LE). Ohne BOM entscheidet eine
NUL-Heuristik über UTF-16, danach wird strikt als UTF-8 gelesen, mit Rückfall auf
Latin-1. Das ist notwendig, weil Windows PowerShell 5.1 standardmäßig UTF-16 schreibt —
ohne diese Erkennung fiele jede so gespeicherte `.ps1` durchs Raster.

**Nicht lesbare Pfade** (Zugriff verweigert, zu lange Pfade, gesperrte Dateien) werden
gesammelt und im Report in einem eigenen Abschnitt ausgewiesen. Sie sind ausdrücklich
*nicht* „ohne Treffer", sondern ungeprüft.

## Der Report

Eine einzelne HTML-Datei, alles inline — kein CDN, keine externen Requests, funktioniert
offline und auf abgeschotteten Rechnern. Nach dem Scan öffnet er sich automatisch im
Standardbrowser; `-NoOpen` unterdrückt das.

- **Kacheln im Kopf:** Dateien mit Treffern · Stellen gesamt · davon aktiv ·
  auskommentiert · Dateien durchsucht · nicht lesbar · Laufzeit
- **Filterleiste:** Freitextsuche über Pfade, Umschalter „nur aktive Treffer",
  alles auf-/zuklappen
- **Trefferliste:** pro Datei ein aufklappbarer Block; aufgeklappt eine Tabelle aus
  Zeilennummer, Zeileninhalt (Fundstelle hervorgehoben) und Status
- **Fußzeile:** alle Scan-Parameter zur Nachvollziehbarkeit
- Hell/Dunkel nach Systemeinstellung; die Aufklappblöcke sind natives `<details>` und
  funktionieren auch ohne JavaScript — JavaScript macht nur Filter und Zähler

## Grenzen

- Blockkommentare werden nur für XML-artige Dateien (`.xml`, `.config`, `.wsf`) über
  Zeilengrenzen hinweg verfolgt. `<# … #>` in PowerShell und `/* … */` in C#/JS gelten
  als `aktiv`.
- `wmic` innerhalb einer Zeichenkette ist nicht von einem echten Aufruf unterscheidbar
  und zählt als `aktiv`.
- Nur Textdateien mit den konfigurierten Endungen. Kompilierte Aufrufe in `.exe`/`.dll`
  werden nicht gefunden.
- Dateien mit reinen CR-Zeilenenden (klassisches Mac-Format) werden als eine Zeile
  gewertet.
- Getestet mit PowerShell 7.4. Das Skript ist bewusst 5.1-kompatibel geschrieben, unter
  Windows PowerShell 5.1 aber **nicht verifiziert**.
- Unter Windows PowerShell 5.1 können Pfade über 260 Zeichen nicht gelesen werden; sie
  landen dann im Abschnitt „Nicht gelesen".

## Mitgelieferte Samples

`samples/` enthält eine kleine, versionierte Fassung des Testbaums, damit ein Klon ohne
Generatorlauf sofort prüfbar ist:

```powershell
.\Find-WmicUsage.ps1 -Path .\samples -NoOpen
```

Erwartet:

```
  Dateien mit Treffern : 6
  Stellen gesamt       : 12  (aktiv: 7, auskommentiert: 5)
  Dateien durchsucht   : 7 von 7 Kandidaten
```

Der vollständige Baum inklusive Größenlimit-, Binär- und Umlaut-Fällen entsteht über
`-CreateSampleData`.
