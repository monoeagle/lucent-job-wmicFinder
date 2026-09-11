# Ein Kommentar-Banner kann `Get-Help` stillschweigend abschalten

**2026-09-11 · lucent-job-wmicFinder · Session 1**

## Der Fund

Der gewünschte Entwickler-Header wurde als `#`-Kommentarblock zwischen `#Requires` und
den vorhandenen `<# .SYNOPSIS … #>`-Block gesetzt. Das Skript lief danach unverändert,
alle Funktionstests blieben grün — aber `Get-Help .\Find-WmicUsage.ps1` lieferte keine
Hilfe mehr, sondern nur noch die Syntaxzeile.

Aufgefallen ist das erst, weil der Handoff verlangt, **Startbefehle auszuführen statt zu
lesen**. `Get-Help` stand im Verifikationsblock — sonst wäre die Hilfe verschwunden
geblieben und niemand hätte es gemerkt, weil das Skript selbst tadellos funktioniert.

## Die Ursache, eingegrenzt statt vermutet

Erste Vermutung: „der Banner ist zu lang" oder „`#Requires` stört". Beides falsch. Eine
Minimalfassung ohne Banner scheiterte zunächst genauso — was die Vermutung widerlegte und
zur eigentlichen Regel führte:

| Variante | `Get-Help` |
|---|---|
| `<#…#>` ganz oben, `param` direkt danach | funktioniert |
| `#Requires`, Leerzeile, `<#…#>` | funktioniert |
| `#Requires`, `# Banner`, `<#…#>` | **keine Hilfe** |
| `# Banner`, `<#…#>` (ohne `#Requires`) | **keine Hilfe** |
| `#Requires`, `# Banner`, **Leerzeile**, `<#…#>` | funktioniert |
| `# Banner`, **Leerzeile**, `<#…#>` | funktioniert |

**Regel:** Steht eine `#`-Kommentarzeile *unmittelbar* vor dem `<#…#>`-Block, liest
PowerShell beides als einen zusammenhängenden Kommentarblock und erkennt die
Comment-Based-Help nicht mehr. Eine einzige Leerzeile dazwischen genügt. `#Requires` ist
unbeteiligt.

**Woran man es früher gemerkt hätte:** an gar nichts — außer durch den Aufruf. Parser,
Syntaxprüfung und jeder Funktionstest des Skripts bleiben grün. Die Hilfe ist die einzige
Fläche, die kaputtgeht, und sie wird nie beiläufig benutzt.

**Absicherung:** Der Hinweis steht jetzt *im* Banner (nicht darunter — dort wäre er
wieder die auslösende `#`-Zeile), und `Get-Help` gehört in den Funktionstest jedes
Handoffs.

## Zwei Selbstprüfungen, die nicht fehlschlagen konnten

Beide fielen in derselben Session auf und gehören zur selben Fehlerklasse: **eine Prüfung,
die nicht rot werden kann, ist schlimmer als keine** — sie erzeugt Zuversicht ohne Deckung.

1. **`if grep … | head -5; then`** — der Exit-Status einer Pipeline ist der des *letzten*
   Glieds. `head` gelingt immer, also war der Zweig immer wahr. Die Prüfung meldete
   „Nicht-ASCII gefunden" bei einer Datei, die reines ASCII war.
2. **Ein kaputter Regex in einer Zählprüfung** meldete „0 Einträge im Code" und direkt
   darunter „alle im README genannt" — weil die Schleife über null Elemente lief. Ein
   Fehlpass, der wie ein Beleg aussah.

**Lehre:** Jede Prüfung, deren Ergebnis „alles in Ordnung" lautet, einmal absichtlich
kaputtmachen und sehen, ob sie rot wird. Bei Zählprüfungen die Zählung selbst ausgeben —
eine 0 fällt auf, ein stilles „alle in Ordnung" nicht.

## `git rm --cached` staged nur die halbe Absicht

`git rm -r --cached .claude` nimmt den Ordner aus dem Index — die dazugehörige
`.gitignore`-Zeile bleibt aber **unstaged**, wenn man sie im selben Zug editiert. Der
Commit enthielt dadurch die Löschung ohne die Ignore-Regel; der nächste `git add -A`
hätte den Ordner direkt wieder eingesammelt. Fiel nur auf, weil `git status -sb` nach dem
Push noch ` M .gitignore` zeigte.

**Lehre:** Nach `git rm --cached` immer `git status` lesen, bevor committet wird — die
Operation sieht abgeschlossen aus, ist es aber nur zur Hälfte.

## Was sich bewährt hat

**Soll-Werte und Testdaten aus einer Quelle.** Der Sampledaten-Generator hält Dateiinhalt
und erwartete Trefferzahl in derselben Tabelle. Die Soll-Ausgabe wird daraus abgeleitet,
nichts ist fest verdrahtet. Eine im README gepflegte Zahl wäre nach der zweiten Änderung
falsch gewesen — hier kann sie gar nicht erst driften.

**Randfälle als Sampledaten statt als Prosa.** Größenlimit, Binärerkennung und
Ausschluss-Unterbaum sind die Pfade, die still danebenliegen und die niemand prüft. Als
Datei im Testbaum (`riesig.txt`, `getarnt.txt`, `node_modules/skip.js`) werden sie bei
jedem Lauf mitgeprüft, und ihr Fehlverhalten ist sichtbar: Taucht die Datei im Report auf,
hat der Mechanismus versagt.
