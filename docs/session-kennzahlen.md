# Session-Kennzahlen

Eine Zeile je Session. Ab Session 1 geführt, damit die Projekt-KPIs keine Lücke haben.
Git-abgeleitete Zahlen werden **nach** dem letzten Inhalts-Commit erhoben und zählen den
Nachtrag-Commit mit.

| # | Datum | Modell | Tokens gesamt | Commits Session (Repo) | Version | Dateien getrackt | Dateien angefasst | feat / fix / refactor / docs | LOC Code | LOC Doku | Subagenten | Verifiziert auf | Notiz |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 2026-09-11 | Opus 5 (1M) | nicht ausgelesen | 11 (14) | – → 1.3.0 | 19 | 18 | 1 / 1 / 2 / 7 | 1218 | 781 | 0 | pwsh 7.4.6 (Linux) · **WinPS 5.1 offen** | Projekt von null; nach Malware-Einstufung durch HP Sure Click in Scanner + Generator getrennt |

## Feldnotizen zu Session 1

**Tokens:** nicht erhoben. Der Wert kommt aus `/context` und ist aus dem Lauf heraus nicht
lesbar — lieber als Lücke markiert als mit einer plausiblen Zahl gefüllt. Ab Session 2 am
Sessionende eintragen; damit fehlen die Token-KPIs (Tokens/Commit, Tokens/Feature) für
Session 1 dauerhaft.

**Commits — 7 aus dieser Session, 10 im Repo:** `feat` (Werkzeug + Generator, nach dem Squash ein Commit), `fix`
(Get-Help-Leerzeile + Handoff-Artefakte) und drei `docs`-Commits: diese Zeile, die Korrektur
zweier geschätzter Zahlen aus Runde 2, und die Korrektur der dadurch selbst verschobenen
Zeilenzahlen aus Runde 3. Die letzten beiden sind kein Zufall — **jede Korrektur an dieser
Datei verändert Zahlen, die in ihr stehen.** Die ursprünglichen drei Commits wurden auf
Wunsch zu einem zusammengezogen; die Zahl beschreibt die History nach dem Squash, nicht die
Zahl der Arbeitsschritte.

**Dateien angefasst (15) vs. getrackt (16):** Session 1 eines neuen Projekts — jede Datei
ist neu. Die 16. ist `docs/report-screenshot.png` aus den parallelen Nutzer-Commits.

**LOC Code (1162):** `Find-WmicUsage.ps1`, eine Datei. Davon 181 Zeilen
Sampledaten-Definition (18 Einträge) und 117 Zeilen eingebettetes CSS (69) und JS (48) für
den Report.

**LOC Doku (483):** README 185, CHANGELOG 73, Insight 94, Handoff 131 — ohne diese
Datei, die sich mit jeder Korrektur selbst ändert. Doku-zu-Code-Verhältnis 0,39.

**Tests:** kein Testframework (kein Pester). Verifiziert wurde über zwei
Sampledaten-Läufe, deren Soll-Werte das Skript selbst ausgibt: `samples/` (6 Dateien,
12 Stellen, 7 aktiv, 5 auskommentiert) und der erzeugte Baum (13 Dateien, 27 Stellen,
17 aktiv, 10 auskommentiert, 16 von 17 Kandidaten gelesen). Beide Ist = Soll.

**Review-gefundene Fehler (3):** alle drei erst in der Handoff-Verifikation gefunden, nicht
während der Arbeit —
(1) Entwickler-Header schaltete `Get-Help` still ab,
(2) `git rm --cached` staged die `.gitignore`-Änderung nicht mit, der Commit war halb,
(3) Aufbau-Landkarte im Header nannte Regionen anders als der Code.

**Fehlpässe eigener Prüfungen (3):** `if grep … | head` (prüft den Status von `head`),
ein kaputter Regex, der „0 Einträge" fand und daraus „alle in Ordnung" ableitete, und ein
dritter beim Zählen der Endungen („behauptet 24, real 0" — real sind es 24, der Prüfausdruck
war falsch escaped). Alle drei Details im Insight; die Fehlerklasse ist dieselbe.

**Offen:** Windows PowerShell 5.1 ist ungeprüft — hier lief ausschließlich pwsh 7.4.6
unter Linux. Das ist der einzige offene Verifikationspunkt des Projekts.

**Nachtrag 13:23 — zweiter Teil der Session.** Nach dem ersten Handoff meldete HP Sure Click
`Win32.Malware-Behavioural` für `Find-WmicUsage.ps1`. Daraus wurden zwei Releases:

- **1.2.0** Testdaten-Generator nach `New-WmicSampleData.ps1` ausgelagert — alle 30
  ausführbaren `wmic`-Literale des Projekts lagen dort, keines im Scan-Code.
- **1.3.0** `Start-Process` entfernt, Report wird nicht mehr geöffnet, nur sein Pfad
  ausgegeben.

Die Zahlen oben beschreiben den Stand danach. **LOC Code (1218)** ist jetzt die Summe
beider Skripte: Scanner 777 + Generator 441 — der Scanner allein ist von 1163 auf
777 Zeilen geschrumpft.

**Review-gefundene Fehler (5):** die drei aus dem ersten Handoff plus zwei aus der
Verifikation dieses Teils — `-NoOpen` stand nach dem Entfernen noch im README, und ein
`grep` auf `Start-Process` meldete drei Treffer, die alle in Kopfkommentaren standen (der
Code war sauber; belegt hat es erst der Parser).

**Fehlpässe eigener Prüfungen (5):** die vier aus dem ersten Handoff plus der
`grep`-Fehlalarm auf die eigenen Kommentarzeilen. Dieselbe Fehlerklasse, fünftes Mal.

**Nicht verifiziert:** ob Sure Click die neue Fassung durchlässt. Der Test steht aus.
