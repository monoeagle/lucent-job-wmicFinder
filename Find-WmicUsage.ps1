#Requires -Version 5.1
#==============================================================================
#  Find-WmicUsage.ps1
#------------------------------------------------------------------------------
#  Projekt   : lucent-job-wmicFinder
#  Zweck     : Findet wmic-Aufrufe in Quellordnern (lokal/UNC) und schreibt
#              einen eigenstaendigen HTML-Report.
#  Autor     : tobias philipp <tobias@philipp.team>
#  Repository: github.com/monoeagle/lucent-job-wmicFinder
#  Version   : 1.3.0
#  Stand     : 2026-09-11
#  Benoetigt : Windows PowerShell 5.1 oder PowerShell 7+
#------------------------------------------------------------------------------
#  NUR LESEND. Schreibt genau eine Datei -- den HTML-Report -- und startet
#  keinen Prozess. Enthaelt weder ausfuehrbare wmic-Kommandozeilen noch
#  Start-Process/Invoke-Item. Der Report wird NICHT geoeffnet; das Skript nennt
#  nur seinen Pfad auf der Konsole.
#
#  Hintergrund: HP Sure Click stufte eine fruehere Fassung als Schadsoftware
#  ein. Zwei Bauformen darin sind von Schadsoftware nicht zu unterscheiden --
#  Dateien mit WMI-Kommandozeilen auf die Platte schreiben (jetzt in
#  New-WmicSampleData.ps1) und aus dem Skript heraus einen Prozess starten
#  (jetzt entfernt).
#------------------------------------------------------------------------------
#  AUFBAU
#    param ..................... Quellpfade, Filter, Ausgabe
#    region Konstanten ......... Suchregex, Kommentarmarker je Dateityp
#    region Hilfsfunktionen .... Kodierung, Zeilenindex, Einstufung, HTML
#    region Kandidaten einsammeln  Verzeichnis-Walker mit Unterbaum-Schnitt
#    region Dateien durchsuchen .. Treffer je Datei ermitteln
#    region Report bauen ....... HTML bauen, schreiben und oeffnen
#------------------------------------------------------------------------------
#  HINWEISE FUER AENDERUNGEN
#    - Keine ausfuehrbaren wmic-Kommandozeilen in diese Datei aufnehmen -- auch
#      nicht als Beispiel im Kommentar. Genau daran ist die Vorgaengerfassung
#      bei HP Sure Click haengengeblieben. Testdaten gehoeren in
#      New-WmicSampleData.ps1.
#    - Kein Start-Process, Invoke-Item oder & auf eine erzeugte Datei. Ein
#      Skript, das schreibt und das Geschriebene dann startet, ist die Bauform
#      eines Droppers -- unabhaengig davon, was es tatsaechlich tut.
#    - Der Quelltext dieser Datei bleibt bewusst reines ASCII.
#    - Kodierung beim Lesen: Get-Content ist bewusst nicht im Einsatz. 5.1
#      schreibt .ps1 per Default als UTF-16; ohne eigene BOM-Erkennung faellt
#      jede so gespeicherte Datei durchs Raster.
#    - Einstufung: im Zweifel "Aktiv". Ein falsches "Kommentar" versteckt einen
#      echten Fund, ein falsches "Aktiv" kostet nur einen Blick.
#------------------------------------------------------------------------------
#  AENDERUNGEN
#    1.3.0  2026-09-11  Report wird nicht mehr geoeffnet; -NoOpen entfaellt,
#                       Start-Process ist aus der Datei verschwunden. Der Pfad
#                       steht am Ende auf der Konsole
#    1.2.0  2026-09-11  Testdaten-Generator nach New-WmicSampleData.ps1
#                       ausgelagert; -CreateSampleData und -Force entfallen.
#                       Damit enthaelt diese Datei keine wmic-Literale mehr
#                       und schreibt nur noch den Report
#    1.1.0  2026-09-11  Sampledaten-Generator (-CreateSampleData); Report wird
#                       nach dem Scan automatisch geoeffnet (-NoOpen unterdrueckt)
#    1.0.0  2026-09-11  Erste Fassung
#------------------------------------------------------------------------------
#  ACHTUNG: Die Leerzeile zwischen diesem Banner und dem <# .SYNOPSIS #>-Block
#  muss bleiben. Steht eine #-Zeile unmittelbar davor, liest PowerShell beides
#  als EINEN Kommentarblock -- Get-Help findet dann keine Hilfe mehr und gibt
#  nur noch die Syntax aus. Faellt ohne Funktionstest nicht auf.
#==============================================================================

<#
.SYNOPSIS
    Durchsucht Quellordner rekursiv nach Verwendungen von wmic und erstellt einen HTML-Report.

.DESCRIPTION
    wmic (WMI Command-line Utility) ist ab Windows 11 25H2 nicht mehr Bestandteil des
    Betriebssystems. Dieses Skript findet alle verbliebenen Aufrufe in Skript- und
    Quelldateien, damit sie auf CIM-Cmdlets bzw. WMI-APIs migriert werden koennen.

    Durchsucht werden lokale Pfade und UNC-Pfade. Gesucht wird nach dem Wort "wmic"
    bzw. "wmic.exe" (Wortgrenzen, Gross-/Kleinschreibung egal), sodass Bezeichner wie
    "wmiclass" keine Fehltreffer erzeugen. Jede Fundstelle wird als "Aktiv" oder
    "Kommentar" eingestuft; im Zweifel lautet die Einstufung "Aktiv", damit nichts
    faelschlich als harmlos untergeht.

    Zugriffsfehler (typisch bei UNC-Freigaben oder zu langen Pfaden) werden gesammelt
    und im Report ausgewiesen - eine nicht lesbare Stelle sieht damit nicht wie
    "kein Treffer" aus.

.PARAMETER Path
    Ein oder mehrere Quellordner. Lokal (C:\Projekte) oder UNC (\\server\share\code).

.PARAMETER OutputPath
    Zieldatei des HTML-Reports. Standard: .\wmic-report_<yyyyMMdd-HHmmss>.html

.PARAMETER Extension
    Zu durchsuchende Dateiendungen (ohne Punkt).

.PARAMETER ExcludeDirectory
    Verzeichnisnamen, die samt Unterbaum uebersprungen werden.

.PARAMETER MaxFileSizeMB
    Dateien oberhalb dieser Groesse werden uebersprungen und gezaehlt.

.PARAMETER PassThru
    Gibt die Fundstellen zusaetzlich als Objekte auf die Pipeline aus.

.EXAMPLE
    .\Find-WmicUsage.ps1 -Path C:\Projekte

    Scannt und nennt am Ende den Pfad des Reports. Geoeffnet wird er nicht --
    den Pfad aus der Konsole kopieren und selbst oeffnen.

.EXAMPLE
    .\New-WmicSampleData.ps1 -Path C:\Temp\wmic-test
    .\Find-WmicUsage.ps1 -Path C:\Temp\wmic-test

    Zwei Laeufe: erst Testdaten erzeugen, dann dagegen scannen. Der Generator
    liegt bewusst in einer eigenen Datei (siehe .NOTES).

.EXAMPLE
    .\Find-WmicUsage.ps1 -Path \\fs01\skripte$, D:\Tools -OutputPath C:\Temp\wmic.html

.EXAMPLE
    .\Find-WmicUsage.ps1 -Path C:\Projekte -Extension ps1,bat,cmd -PassThru |
        Export-Csv .\wmic.csv -NoTypeInformation -Encoding UTF8

.NOTES
    Getestet mit PowerShell 7. Bewusst 5.1-kompatibel geschrieben.

    Dieses Skript liest nur und schreibt genau eine Datei: den Report. Es enthaelt
    keine ausfuehrbaren wmic-Kommandozeilen. Der Testdaten-Generator liegt in
    New-WmicSampleData.ps1, weil er ausfuehrbare Dateien anlegt und damit fuer eine
    Verhaltensanalyse wie ein Dropper aussieht.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0,
        ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [Alias('FullName', 'PSPath')]
    [string[]]$Path,

    [string]$OutputPath,

    [string[]]$Extension = @(
        'ps1', 'psm1', 'psd1', 'bat', 'cmd', 'vbs', 'vbe', 'wsf', 'js', 'py',
        'cs', 'vb', 'xml', 'config', 'json', 'yml', 'yaml', 'sql', 'txt', 'md',
        'ini', 'inf', 'reg', 'sh'
    ),

    [string[]]$ExcludeDirectory = @('.git', '.svn', '.hg', 'node_modules', 'bin', 'obj', '_deps', '.archiv'),

    [ValidateRange(1, 2048)]
    [int]$MaxFileSizeMB = 10,

    [switch]$PassThru
)

begin {
    Set-StrictMode -Version 2.0
    $collectedPaths = New-Object System.Collections.Generic.List[string]
}

process {
    foreach ($p in $Path) {
        if (-not [string]::IsNullOrWhiteSpace($p)) { $collectedPaths.Add($p) }
    }
}

end {

    #region Konstanten -------------------------------------------------------

    # \b vor und hinter dem Treffer: "wmiclass" oder "swmic" erzeugen keinen Treffer,
    # "wmic.exe" schon (die Alternative wird zuerst probiert und greift damit voll).
    $wmicRegex = New-Object System.Text.RegularExpressions.Regex(
        '\bwmic(\.exe)?\b',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )

    # Zeilenkommentar-Marker je Dateityp. Geprueft wird nur der Text VOR der Fundstelle.
    $commentPattern = @{
        'ps1' = '^\s*#'; 'psm1' = '^\s*#'; 'psd1' = '^\s*#'
        'py'  = '^\s*#'; 'sh' = '^\s*#'; 'yml' = '^\s*#'; 'yaml' = '^\s*#'
        'ini' = '^\s*[;#]'; 'inf' = '^\s*;'; 'reg' = '^\s*;'
        'bat' = '^\s*(@?rem\b|::)'; 'cmd' = '^\s*(@?rem\b|::)'
        'vbs' = "^\s*('|rem\b)"; 'vbe' = "^\s*('|rem\b)"; 'vb' = "^\s*('|rem\b)"
        'js'  = '^\s*//'; 'cs' = '^\s*//'; 'json' = '^\s*//'
        'sql' = '^\s*--'
    }
    $xmlLike = @{ 'xml' = $true; 'config' = $true; 'wsf' = $true }

    $maxBytes = [long]$MaxFileSizeMB * 1MB
    $maxDisplayChars = 500

    #endregion

    #region Hilfsfunktionen --------------------------------------------------

    function ConvertTo-HtmlText {
        param([string]$Text)
        if ([string]::IsNullOrEmpty($Text)) { return '' }
        $Text.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace('"', '&quot;').Replace("'", '&#39;')
    }

    function Read-SourceText {
        <#
            Liest eine Datei als Text und meldet die erkannte Kodierung mit.
            BOM hat Vorrang; ohne BOM entscheidet eine NUL-Heuristik ueber UTF-16,
            danach strikt UTF-8 mit Rueckfall auf Latin-1 (schlaegt nie fehl).
            Ohne diese Erkennung faellt jede UTF-16-PS1-Datei durchs Raster.
        #>
        param([string]$FullName)

        $bytes = [System.IO.File]::ReadAllBytes($FullName)
        if ($bytes.Length -eq 0) { return @{ Text = ''; Encoding = 'leer' } }

        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
            return @{ Text = [System.Text.Encoding]::UTF8.GetString($bytes, 3, $bytes.Length - 3); Encoding = 'UTF-8 (BOM)' }
        }
        if ($bytes.Length -ge 4 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE -and $bytes[2] -eq 0 -and $bytes[3] -eq 0) {
            return @{ Text = [System.Text.Encoding]::UTF32.GetString($bytes, 4, $bytes.Length - 4); Encoding = 'UTF-32 LE (BOM)' }
        }
        if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
            return @{ Text = [System.Text.Encoding]::Unicode.GetString($bytes, 2, $bytes.Length - 2); Encoding = 'UTF-16 LE (BOM)' }
        }
        if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
            return @{ Text = [System.Text.Encoding]::BigEndianUnicode.GetString($bytes, 2, $bytes.Length - 2); Encoding = 'UTF-16 BE (BOM)' }
        }

        # Kein BOM: NUL-Muster in der Kopfprobe deutet auf UTF-16 ohne BOM hin.
        $probe = [Math]::Min(512, $bytes.Length)
        $nulEven = 0; $nulOdd = 0
        for ($i = 0; $i -lt $probe; $i++) {
            if ($bytes[$i] -eq 0) { if ($i % 2 -eq 0) { $nulEven++ } else { $nulOdd++ } }
        }
        $half = [Math]::Max(1, [int]($probe / 2))
        if ($nulOdd -ge $half * 0.6 -and $nulEven -eq 0) {
            return @{ Text = [System.Text.Encoding]::Unicode.GetString($bytes); Encoding = 'UTF-16 LE' }
        }
        if ($nulEven -ge $half * 0.6 -and $nulOdd -eq 0) {
            return @{ Text = [System.Text.Encoding]::BigEndianUnicode.GetString($bytes); Encoding = 'UTF-16 BE' }
        }

        try {
            $strict = New-Object System.Text.UTF8Encoding($false, $true)
            return @{ Text = $strict.GetString($bytes); Encoding = 'UTF-8' }
        } catch {
            return @{ Text = [System.Text.Encoding]::GetEncoding(28591).GetString($bytes); Encoding = 'ANSI/Latin-1' }
        }
    }

    function Get-LineIndex {
        <#
            Baut Start-/Endoffsets aller Zeilen. IndexOf statt Zeichenschleife,
            sonst dauert eine grosse Datei spuerbar lange.
            Erkennt LF und CRLF; ein reines CR-Dateiformat bleibt eine Zeile.
        #>
        param([string]$Text)
        $starts = New-Object System.Collections.Generic.List[int]
        $ends = New-Object System.Collections.Generic.List[int]
        $pos = 0
        while ($true) {
            $nl = $Text.IndexOf([char]10, $pos)
            if ($nl -lt 0) { $starts.Add($pos); $ends.Add($Text.Length); break }
            $e = $nl
            if ($e -gt $pos -and $Text[$e - 1] -eq [char]13) { $e-- }
            $starts.Add($pos); $ends.Add($e)
            $pos = $nl + 1
        }
        @{ Starts = $starts; Ends = $ends }
    }

    function Get-HitStatus {
        param([string]$Text, [int]$Offset, [string]$LinePrefix, [string]$Ext)

        if ($xmlLike.ContainsKey($Ext)) {
            # XML-Blockkommentare reichen ueber Zeilengrenzen, deshalb ueber den
            # ganzen Text bis zur Fundstelle geprueft statt nur ueber die Zeile.
            $o = $Text.LastIndexOf('<!--', $Offset, [System.StringComparison]::Ordinal)
            $c = $Text.LastIndexOf('-->', $Offset, [System.StringComparison]::Ordinal)
            if ($o -ge 0 -and $o -gt $c) { return 'Kommentar' }
            return 'Aktiv'
        }
        if ($commentPattern.ContainsKey($Ext)) {
            if ($LinePrefix -match $commentPattern[$Ext]) { return 'Kommentar' }
        }
        'Aktiv'
    }

    function Format-CodeLine {
        <#
            Escaped die Zeile und markiert die Fundstellen. Sehr lange Zeilen
            (minifizierte Dateien) werden auf ein Fenster um die erste Fundstelle
            gekuerzt, damit der Report lesbar bleibt.
        #>
        param([string]$Line, [object[]]$Hits)

        $text = $Line
        $offset = 0
        $cutStart = $false
        $cutEnd = $false

        if ($text.Length -gt $maxDisplayChars) {
            $first = $Hits[0].Index
            $offset = [Math]::Max(0, $first - 120)
            $len = [Math]::Min($maxDisplayChars, $text.Length - $offset)
            $cutStart = $offset -gt 0
            $cutEnd = ($offset + $len) -lt $text.Length
            $text = $text.Substring($offset, $len)
        }

        $sb = New-Object System.Text.StringBuilder
        if ($cutStart) { [void]$sb.Append('<span class="cut">&hellip;</span>') }
        $pos = 0
        foreach ($h in $Hits) {
            $i = $h.Index - $offset
            if ($i -lt 0 -or ($i + $h.Length) -gt $text.Length) { continue }
            [void]$sb.Append((ConvertTo-HtmlText $text.Substring($pos, $i - $pos)))
            [void]$sb.Append('<mark>').Append((ConvertTo-HtmlText $text.Substring($i, $h.Length))).Append('</mark>')
            $pos = $i + $h.Length
        }
        [void]$sb.Append((ConvertTo-HtmlText $text.Substring($pos)))
        if ($cutEnd) { [void]$sb.Append('<span class="cut">&hellip;</span>') }
        $sb.ToString()
    }

    #endregion

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    #region Kandidaten einsammeln --------------------------------------------

    $extSet = @{}
    foreach ($e in $Extension) { $extSet[$e.TrimStart('.').ToLowerInvariant()] = $true }
    $excludeSet = @{}
    foreach ($d in $ExcludeDirectory) { $excludeSet[$d.ToLowerInvariant()] = $true }

    $problems = New-Object System.Collections.Generic.List[object]
    $candidates = New-Object System.Collections.Generic.List[string]
    $roots = New-Object System.Collections.Generic.List[string]
    $skippedTooLarge = 0
    $skippedBinary = 0

    foreach ($root in $collectedPaths) {
        $full = $null
        try { $full = [System.IO.Path]::GetFullPath($root) } catch { $full = $root }

        if (-not (Test-Path -LiteralPath $full -PathType Container)) {
            $msg = 'Kein erreichbarer Ordner'
            if (Test-Path -LiteralPath $full) { $msg = 'Ist eine Datei, kein Ordner' }
            Write-Warning ("{0}: {1}" -f $full, $msg)
            $problems.Add([pscustomobject]@{ Path = $full; Reason = $msg })
            continue
        }
        $roots.Add($full)

        # Eigener Stack-Walker statt Get-ChildItem -Recurse: nur so laesst sich ein
        # ausgeschlossener Unterbaum wirklich abschneiden (statt ihn erst zu
        # durchlaufen und danach wegzufiltern) und jeder Zugriffsfehler dem
        # konkreten Verzeichnis zuordnen.
        $stack = New-Object System.Collections.Stack
        $stack.Push($full)
        while ($stack.Count -gt 0) {
            $dir = $stack.Pop()

            try {
                foreach ($sub in [System.IO.Directory]::GetDirectories($dir)) {
                    $name = [System.IO.Path]::GetFileName($sub)
                    if ($excludeSet.ContainsKey($name.ToLowerInvariant())) { continue }
                    $stack.Push($sub)
                }
            } catch {
                $problems.Add([pscustomobject]@{ Path = $dir; Reason = 'Unterordner nicht lesbar: ' + $_.Exception.Message })
            }

            try {
                foreach ($file in [System.IO.Directory]::GetFiles($dir)) {
                    $ext = [System.IO.Path]::GetExtension($file)
                    if ([string]::IsNullOrEmpty($ext)) { continue }
                    if (-not $extSet.ContainsKey($ext.TrimStart('.').ToLowerInvariant())) { continue }
                    $candidates.Add($file)
                }
            } catch {
                $problems.Add([pscustomobject]@{ Path = $dir; Reason = 'Dateien nicht lesbar: ' + $_.Exception.Message })
            }
        }
    }

    if ($roots.Count -eq 0) {
        throw 'Kein einziger gueltiger Quellordner angegeben - Abbruch.'
    }

    #endregion

    #region Dateien durchsuchen ----------------------------------------------

    $findings = New-Object System.Collections.Generic.List[object]
    $fileInfos = New-Object System.Collections.Generic.List[object]
    $scanned = 0
    $total = $candidates.Count
    $progressStep = [Math]::Max(1, [int]($total / 100))

    for ($idx = 0; $idx -lt $total; $idx++) {
        $file = $candidates[$idx]

        if ($idx % $progressStep -eq 0) {
            Write-Progress -Activity 'Suche nach wmic' -Status ("{0} / {1}" -f ($idx + 1), $total) `
                -PercentComplete ([Math]::Min(100, ($idx + 1) * 100 / $total))
        }

        try {
            $info = New-Object System.IO.FileInfo($file)
            if ($info.Length -gt $maxBytes) { $skippedTooLarge++; continue }
        } catch {
            $problems.Add([pscustomobject]@{ Path = $file; Reason = 'Eigenschaften nicht lesbar: ' + $_.Exception.Message })
            continue
        }

        try {
            $read = Read-SourceText -FullName $file
        } catch {
            $problems.Add([pscustomobject]@{ Path = $file; Reason = 'Nicht lesbar: ' + $_.Exception.Message })
            continue
        }

        $text = $read.Text
        $scanned++

        if ($text.Length -eq 0) { continue }
        if ($text.IndexOf([char]0) -ge 0) { $skippedBinary++; continue }

        $matchList = $wmicRegex.Matches($text)
        if ($matchList.Count -eq 0) { continue }

        $ext = [System.IO.Path]::GetExtension($file).TrimStart('.').ToLowerInvariant()
        $index = Get-LineIndex -Text $text
        $starts = $index.Starts
        $ends = $index.Ends
        $li = 0
        $lastLine = $ends.Count - 1

        # Fundstellen kommen sortiert, deshalb laeuft der Zeilenzeiger nur vorwaerts.
        foreach ($m in $matchList) {
            while ($li -lt $lastLine -and $ends[$li] -le $m.Index) { $li++ }
            $lineStart = $starts[$li]
            $lineText = $text.Substring($lineStart, $ends[$li] - $lineStart)
            $column = $m.Index - $lineStart
            $status = Get-HitStatus -Text $text -Offset $m.Index -LinePrefix $lineText.Substring(0, $column) -Ext $ext

            $findings.Add([pscustomobject]@{
                    Path       = $file
                    Directory  = [System.IO.Path]::GetDirectoryName($file)
                    FileName   = [System.IO.Path]::GetFileName($file)
                    Extension  = $ext
                    Encoding   = $read.Encoding
                    LineNumber = $li + 1
                    Column     = $column + 1
                    Line       = $lineText
                    Match      = $m.Value
                    Status     = $status
                })
        }

        $active = 0
        foreach ($f in $findings) { if ($f.Path -eq $file -and $f.Status -eq 'Aktiv') { $active++ } }
        $fileInfos.Add([pscustomobject]@{
                Path     = $file
                Encoding = $read.Encoding
                Size     = $info.Length
                Total    = $matchList.Count
                Active   = $active
            })
    }
    Write-Progress -Activity 'Suche nach wmic' -Completed

    #endregion

    #region Report bauen -----------------------------------------------------

    $stopwatch.Stop()
    $created = Get-Date

    if ([string]::IsNullOrWhiteSpace($OutputPath)) {
        $OutputPath = Join-Path (Get-Location).Path ('wmic-report_{0}.html' -f $created.ToString('yyyyMMdd-HHmmss'))
    }
    $OutputPath = [System.IO.Path]::GetFullPath($OutputPath)

    $totalHits = $findings.Count
    $activeHits = 0
    foreach ($f in $findings) { if ($f.Status -eq 'Aktiv') { $activeHits++ } }
    $commentHits = $totalHits - $activeHits
    $hitFiles = $fileInfos.Count

    $duration = '{0:N1} s' -f $stopwatch.Elapsed.TotalSeconds
    if ($stopwatch.Elapsed.TotalSeconds -ge 60) {
        $duration = '{0:mm\:ss} min' -f $stopwatch.Elapsed
    }

    $sb = New-Object System.Text.StringBuilder

    [void]$sb.AppendLine('<!DOCTYPE html>')
    [void]$sb.AppendLine('<html lang="de">')
    [void]$sb.AppendLine('<head>')
    [void]$sb.AppendLine('<meta charset="utf-8">')
    [void]$sb.AppendLine('<meta name="viewport" content="width=device-width, initial-scale=1">')
    [void]$sb.AppendLine('<title>WMIC-Fundstellen</title>')
    [void]$sb.AppendLine('<style>')
    [void]$sb.AppendLine(@'
:root{
  --bg:#f6f7f9; --panel:#ffffff; --ink:#15181d; --muted:#5d6570; --line:#e2e5ea;
  --accent:#2f6fd0; --active:#c2410c; --active-bg:#fff1e7; --comment:#4b7a4f; --comment-bg:#eef6ef;
  --mark:#ffe08a; --code:#f2f4f7; --shadow:0 1px 2px rgba(15,24,40,.06),0 4px 12px rgba(15,24,40,.05);
}
@media (prefers-color-scheme:dark){
  :root{
    --bg:#14171c; --panel:#1b1f26; --ink:#e8ebef; --muted:#98a2b0; --line:#2c323c;
    --accent:#6fa8ff; --active:#ff9a62; --active-bg:#38220f; --comment:#8fd39a; --comment-bg:#16271a;
    --mark:#8a6d1f; --code:#161a20; --shadow:none;
  }
}
*{box-sizing:border-box}
[hidden]{display:none!important}
body{margin:0;padding:0;background:var(--bg);color:var(--ink);
  font:14px/1.55 system-ui,-apple-system,"Segoe UI",Roboto,"Helvetica Neue",Arial,sans-serif}
.wrap{max-width:1200px;margin:0 auto;padding:24px 16px 64px}
header h1{margin:0 0 4px;font-size:1.6rem;letter-spacing:-.01em}
header .sub{margin:0 0 20px;color:var(--muted);font-size:.85rem}
.tiles{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:12px;margin-bottom:24px}
.tile{background:var(--panel);border:1px solid var(--line);border-radius:10px;padding:14px 16px;box-shadow:var(--shadow)}
.tile .n{display:block;font-size:1.9rem;font-weight:600;line-height:1.1;letter-spacing:-.02em}
.tile .l{display:block;margin-top:4px;color:var(--muted);font-size:.78rem;text-transform:uppercase;letter-spacing:.05em}
.tile.is-active .n{color:var(--active)}
.tile.is-comment .n{color:var(--comment)}
.tile.is-warn .n{color:var(--active)}
.toolbar{display:flex;flex-wrap:wrap;gap:10px;align-items:center;background:var(--panel);
  border:1px solid var(--line);border-radius:10px;padding:12px;margin-bottom:16px;box-shadow:var(--shadow)}
.toolbar input[type=search]{flex:1 1 240px;min-width:0;padding:7px 10px;border:1px solid var(--line);
  border-radius:7px;background:var(--bg);color:var(--ink);font:inherit}
.toolbar label{display:inline-flex;align-items:center;gap:6px;color:var(--muted);white-space:nowrap}
.toolbar button{padding:7px 12px;border:1px solid var(--line);border-radius:7px;background:var(--bg);
  color:var(--ink);font:inherit;cursor:pointer}
.toolbar button:hover{border-color:var(--accent);color:var(--accent)}
.toolbar .status{margin-left:auto;color:var(--muted);font-size:.82rem;white-space:nowrap}
details.file{background:var(--panel);border:1px solid var(--line);border-radius:10px;margin-bottom:10px;
  box-shadow:var(--shadow);overflow:hidden}
details.file>summary{cursor:pointer;padding:11px 14px;display:flex;flex-wrap:wrap;gap:8px;align-items:center;
  list-style:none}
details.file>summary::-webkit-details-marker{display:none}
details.file>summary::before{content:"\25B8";color:var(--muted);transition:transform .12s ease;display:inline-block}
details.file[open]>summary::before{transform:rotate(90deg)}
.fname{font-weight:600}
.fdir{color:var(--muted);font-size:.82rem;word-break:break-all}
.badges{margin-left:auto;display:flex;gap:6px;flex-wrap:wrap}
.badge{font-size:.74rem;padding:2px 8px;border-radius:999px;border:1px solid var(--line);color:var(--muted);white-space:nowrap}
.badge.a{color:var(--active);background:var(--active-bg);border-color:transparent}
.badge.c{color:var(--comment);background:var(--comment-bg);border-color:transparent}
.tblwrap{overflow-x:auto;border-top:1px solid var(--line)}
table{width:100%;border-collapse:collapse;font-size:.84rem}
th{text-align:left;color:var(--muted);font-weight:500;font-size:.74rem;text-transform:uppercase;
  letter-spacing:.05em;padding:7px 14px;border-bottom:1px solid var(--line)}
td{padding:5px 14px;border-bottom:1px solid var(--line);vertical-align:top}
tr:last-child td{border-bottom:none}
td.ln{text-align:right;color:var(--muted);font-variant-numeric:tabular-nums;width:1%;white-space:nowrap;
  font-family:ui-monospace,"Cascadia Mono",Consolas,"DejaVu Sans Mono",monospace}
td.code{font-family:ui-monospace,"Cascadia Mono",Consolas,"DejaVu Sans Mono",monospace;
  white-space:pre;tab-size:4;background:var(--code)}
td.st{width:1%;white-space:nowrap}
mark{background:var(--mark);color:inherit;border-radius:3px;padding:0 2px;font-weight:600}
.cut{color:var(--muted)}
.note{color:var(--muted);padding:14px;margin:0}
section.problems{margin-top:28px}
section.problems h2{font-size:1rem;margin:0 0 10px}
section.problems li{color:var(--muted);word-break:break-all;margin-bottom:4px}
footer{margin-top:36px;padding-top:16px;border-top:1px solid var(--line);color:var(--muted);font-size:.8rem}
footer dl{display:grid;grid-template-columns:max-content 1fr;gap:4px 14px;margin:8px 0 0}
footer dt{font-weight:600}
footer dd{margin:0;word-break:break-all}
'@)
    [void]$sb.AppendLine('</style>')
    [void]$sb.AppendLine('</head>')
    [void]$sb.AppendLine('<body>')
    [void]$sb.AppendLine('<div class="wrap">')

    [void]$sb.AppendLine('<header>')
    [void]$sb.AppendLine('<h1>WMIC-Fundstellen</h1>')
    [void]$sb.AppendFormat('<p class="sub">Erstellt am {0} &middot; {1} &middot; Suchmuster <code>\bwmic(\.exe)?\b</code></p>',
        (ConvertTo-HtmlText $created.ToString('dd.MM.yyyy HH:mm:ss')),
        (ConvertTo-HtmlText (($roots.ToArray()) -join ' &middot; '))).AppendLine()

    [void]$sb.AppendLine('<div class="tiles">')
    $tiles = @(
        @{ n = $hitFiles; l = 'Dateien mit Treffern'; c = '' },
        @{ n = $totalHits; l = 'Stellen gesamt'; c = '' },
        @{ n = $activeHits; l = 'davon aktiv'; c = ' is-active' },
        @{ n = $commentHits; l = 'auskommentiert'; c = ' is-comment' },
        @{ n = $scanned; l = 'Dateien durchsucht'; c = '' },
        @{ n = $problems.Count; l = 'nicht lesbar'; c = $(if ($problems.Count -gt 0) { ' is-warn' } else { '' }) },
        @{ n = $duration; l = 'Laufzeit'; c = '' }
    )
    foreach ($t in $tiles) {
        [void]$sb.AppendFormat('<div class="tile{0}"><span class="n">{1}</span><span class="l">{2}</span></div>',
            $t.c, (ConvertTo-HtmlText ([string]$t.n)), (ConvertTo-HtmlText $t.l)).AppendLine()
    }
    [void]$sb.AppendLine('</div>')
    [void]$sb.AppendLine('</header>')

    [void]$sb.AppendLine('<main>')

    if ($totalHits -eq 0) {
        [void]$sb.AppendLine('<p class="note">Keine Verwendung von <code>wmic</code> gefunden.</p>')
    } else {
        [void]$sb.AppendLine('<div class="toolbar">')
        [void]$sb.AppendLine('<input type="search" id="q" placeholder="Datei oder Pfad filtern &hellip;" aria-label="Datei oder Pfad filtern">')
        [void]$sb.AppendLine('<label><input type="checkbox" id="onlyActive"> nur aktive Treffer</label>')
        [void]$sb.AppendLine('<button type="button" id="expand">Alle aufklappen</button>')
        [void]$sb.AppendLine('<button type="button" id="collapse">Alle zuklappen</button>')
        [void]$sb.AppendLine('<span class="status" id="status"></span>')
        [void]$sb.AppendLine('</div>')

        [void]$sb.AppendLine('<div id="files">')

        foreach ($fi in ($fileInfos | Sort-Object -Property @{ Expression = 'Active'; Descending = $true }, @{ Expression = 'Total'; Descending = $true }, 'Path')) {
            $fileHits = @($findings | Where-Object { $_.Path -eq $fi.Path })
            $comment = $fi.Total - $fi.Active

            [void]$sb.AppendFormat('<details class="file" data-path="{0}" data-active="{1}">',
                (ConvertTo-HtmlText $fi.Path.ToLowerInvariant()), $fi.Active).AppendLine()
            [void]$sb.Append('<summary>')
            [void]$sb.AppendFormat('<span class="fname">{0}</span>', (ConvertTo-HtmlText ([System.IO.Path]::GetFileName($fi.Path))))
            [void]$sb.AppendFormat('<span class="fdir">{0}</span>', (ConvertTo-HtmlText ([System.IO.Path]::GetDirectoryName($fi.Path))))
            [void]$sb.Append('<span class="badges">')
            if ($fi.Active -gt 0) {
                [void]$sb.AppendFormat('<span class="badge a">{0} aktiv</span>', $fi.Active)
            }
            if ($comment -gt 0) {
                [void]$sb.AppendFormat('<span class="badge c">{0} Kommentar</span>', $comment)
            }
            [void]$sb.AppendFormat('<span class="badge"><span class="shown">{0}</span> von {0} sichtbar</span>', $fi.Total)
            [void]$sb.AppendFormat('<span class="badge">{0}</span>', (ConvertTo-HtmlText $fi.Encoding))
            [void]$sb.AppendLine('</span></summary>')

            [void]$sb.AppendLine('<div class="tblwrap"><table>')
            [void]$sb.AppendLine('<thead><tr><th>Zeile</th><th>Inhalt</th><th>Status</th></tr></thead><tbody>')

            foreach ($grp in ($fileHits | Group-Object LineNumber | Sort-Object { [int]$_.Name })) {
                $hits = @($grp.Group | Sort-Object Column)
                $lineText = $hits[0].Line
                $spans = @()
                foreach ($h in $hits) {
                    $spans += [pscustomobject]@{ Index = $h.Column - 1; Length = $h.Match.Length }
                }
                $isActive = $false
                foreach ($h in $hits) { if ($h.Status -eq 'Aktiv') { $isActive = $true } }
                $status = if ($isActive) { 'aktiv' } else { 'kommentar' }
                $label = if ($isActive) { '<span class="badge a">aktiv</span>' } else { '<span class="badge c">Kommentar</span>' }

                [void]$sb.AppendFormat('<tr class="hit" data-status="{0}"><td class="ln">{1}</td><td class="code">{2}</td><td class="st">{3}</td></tr>',
                    $status, $grp.Name, (Format-CodeLine -Line $lineText -Hits $spans), $label).AppendLine()
            }

            [void]$sb.AppendLine('</tbody></table></div>')
            [void]$sb.AppendLine('</details>')
        }

        [void]$sb.AppendLine('</div>')
        [void]$sb.AppendLine('<p class="note" id="empty" hidden>Keine Datei entspricht dem Filter.</p>')
    }

    if ($problems.Count -gt 0) {
        [void]$sb.AppendLine('<section class="problems">')
        [void]$sb.AppendFormat('<h2>Nicht gelesen ({0})</h2>', $problems.Count).AppendLine()
        [void]$sb.AppendLine('<p class="note">Diese Stellen konnten nicht geprueft werden. Sie sind nicht &bdquo;ohne Treffer&ldquo;, sondern ungeprueft.</p>')
        [void]$sb.AppendLine('<ul>')
        foreach ($p in $problems) {
            [void]$sb.AppendFormat('<li><strong>{0}</strong><br>{1}</li>',
                (ConvertTo-HtmlText $p.Path), (ConvertTo-HtmlText $p.Reason)).AppendLine()
        }
        [void]$sb.AppendLine('</ul></section>')
    }

    [void]$sb.AppendLine('</main>')

    [void]$sb.AppendLine('<footer>')
    [void]$sb.AppendLine('<strong>Scan-Parameter</strong>')
    [void]$sb.AppendLine('<dl>')
    # Ordinal statt Sort-Object sortieren: die kulturabhaengige Standardsortierung
    # ordnet Satzzeichen (. _) zwischen 5.1 und 7 unterschiedlich, wodurch der Report
    # sonst versionsabhaengig driftet. OrdinalIgnoreCase bleibt case-insensitiv wie zuvor.
    $extSorted = [string[]]$Extension;        [System.Array]::Sort($extSorted, [System.StringComparer]::OrdinalIgnoreCase)
    $exSorted  = [string[]]$ExcludeDirectory; [System.Array]::Sort($exSorted,  [System.StringComparer]::OrdinalIgnoreCase)
    [void]$sb.AppendFormat('<dt>Quellordner</dt><dd>{0}</dd>', (ConvertTo-HtmlText (($roots.ToArray()) -join '; '))).AppendLine()
    [void]$sb.AppendFormat('<dt>Endungen</dt><dd>{0}</dd>', (ConvertTo-HtmlText ($extSorted -join ', '))).AppendLine()
    [void]$sb.AppendFormat('<dt>Ausgeschlossen</dt><dd>{0}</dd>', (ConvertTo-HtmlText ($exSorted -join ', '))).AppendLine()
    [void]$sb.AppendFormat('<dt>Groessenlimit</dt><dd>{0} MB &middot; {1} Datei(en) uebersprungen</dd>', $MaxFileSizeMB, $skippedTooLarge).AppendLine()
    [void]$sb.AppendFormat('<dt>Als binaer erkannt</dt><dd>{0} Datei(en)</dd>', $skippedBinary).AppendLine()
    [void]$sb.AppendFormat('<dt>Kandidaten</dt><dd>{0} gefunden &middot; {1} gelesen</dd>', $total, $scanned).AppendLine()
    [void]$sb.AppendLine('</dl>')
    [void]$sb.AppendLine('</footer>')

    [void]$sb.AppendLine('</div>')
    [void]$sb.AppendLine('<script>')
    [void]$sb.AppendLine(@'
(function(){
  var q=document.getElementById("q");
  if(!q){return;}
  var only=document.getElementById("onlyActive");
  var empty=document.getElementById("empty");
  var status=document.getElementById("status");
  var files=Array.prototype.slice.call(document.querySelectorAll("details.file"));

  function apply(){
    var term=q.value.trim().toLowerCase();
    var onlyActive=only.checked;
    var visibleFiles=0, visibleHits=0;

    files.forEach(function(f){
      var rows=f.querySelectorAll("tr.hit");
      var shown=0;
      Array.prototype.forEach.call(rows,function(r){
        var hide=onlyActive && r.getAttribute("data-status")!=="aktiv";
        r.hidden=hide;
        if(!hide){shown++;}
      });
      var pathMatch = term==="" || f.getAttribute("data-path").indexOf(term)>-1;
      var visible = pathMatch && shown>0;
      f.hidden=!visible;
      if(visible){visibleFiles++; visibleHits+=shown;}
      var counter=f.querySelector(".shown");
      if(counter){
        counter.textContent=shown;
        // Zaehler nur zeigen, wenn ein Filter tatsaechlich etwas ausblendet.
        counter.parentNode.hidden = (shown === rows.length);
      }
    });

    empty.hidden = visibleFiles>0;
    status.textContent = visibleFiles+" Datei(en) \u00b7 "+visibleHits+" Stelle(n) sichtbar";
  }

  q.addEventListener("input",apply);
  only.addEventListener("change",apply);
  document.getElementById("expand").addEventListener("click",function(){
    files.forEach(function(f){ if(!f.hidden){f.open=true;} });
  });
  document.getElementById("collapse").addEventListener("click",function(){
    files.forEach(function(f){ f.open=false; });
  });

  apply();
})();
'@)
    [void]$sb.AppendLine('</script>')
    [void]$sb.AppendLine('</body>')
    [void]$sb.AppendLine('</html>')

    $dir = [System.IO.Path]::GetDirectoryName($OutputPath)
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($OutputPath, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))

    #endregion

    Write-Host ''
    Write-Host ('  Dateien mit Treffern : {0}' -f $hitFiles)
    Write-Host ('  Stellen gesamt       : {0}  (aktiv: {1}, auskommentiert: {2})' -f $totalHits, $activeHits, $commentHits)
    Write-Host ('  Dateien durchsucht   : {0} von {1} Kandidaten' -f $scanned, $total)
    if ($problems.Count -gt 0) {
        Write-Warning ('{0} Pfad(e) konnten nicht gelesen werden - siehe Report.' -f $problems.Count)
    }

    # Das Skript oeffnet den Report bewusst NICHT selbst -- siehe Kopf.
    # Der Pfad steht deshalb allein und unveraendert in einer eigenen Zeile,
    # damit er sich aus der Konsole kopieren laesst.
    Write-Host ''
    Write-Host '  Report abgelegt unter:'
    Write-Host ('    {0}' -f $OutputPath)
    Write-Host ''

    if ($PassThru) { $findings }
}
