# Session-Kennzahlen

Eine Zeile je Session. Ab Session 1 geführt, damit die Projekt-KPIs keine Lücke haben.
Git-abgeleitete Zahlen werden **nach** dem letzten Inhalts-Commit erhoben und zählen den
Nachtrag-Commit mit.

| # | Datum | Modell | Tokens gesamt | Commits | Version | Dateien getrackt | Dateien angefasst | feat / fix / docs | LOC Code | LOC Doku | Subagenten | Verifiziert auf | Notiz |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 2026-09-11 | Opus 5 (1M) | nicht ausgelesen | 4 | – → 1.1.0 | 15 | 15 | 1 / 1 / 2 | 1157 | 442 | 0 | pwsh 7.4.6 (Linux) · **WinPS 5.1 offen** | Projekt von null; Repo + privates GitHub-Remote; History auf einen Commit geglättet |

## Feldnotizen zu Session 1

**Tokens:** nicht erhoben. Der Wert kommt aus `/context` und ist aus dem Lauf heraus nicht
lesbar — lieber als Lücke markiert als mit einer plausiblen Zahl gefüllt. Ab Session 2 am
Sessionende eintragen; damit fehlen die Token-KPIs (Tokens/Commit, Tokens/Feature) für
Session 1 dauerhaft.

**Commits (4):** `feat` (Werkzeug + Generator, nach dem Squash ein Commit), `fix`
(Get-Help-Leerzeile + Handoff-Artefakte), `docs` (diese Zeile) und `docs` (Korrektur zweier
Zahlen, die Runde 2 der Handoff-Verifikation in genau dieser Datei gefunden hat). Die
ursprünglichen drei Commits wurden auf Wunsch zu einem zusammengezogen; die Zahl beschreibt
die History nach dem Squash, nicht die Zahl der Arbeitsschritte.

**Dateien angefasst = getrackt (15):** Session 1 eines neuen Projekts — jede Datei ist neu.

**LOC Code (1157):** `Find-WmicUsage.ps1`, eine Datei. Davon 181 Zeilen
Sampledaten-Definition (18 Einträge) und 117 Zeilen eingebettetes CSS (69) und JS (48) für
den Report.

**LOC Doku (442):** README 183, CHANGELOG 63, Insight 82, Handoff 114.
Doku-zu-Code-Verhältnis 0,38.

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
