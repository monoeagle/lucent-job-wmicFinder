#Requires -Version 5.1
#==============================================================================
#  Find-WmicUsage.ps1
#------------------------------------------------------------------------------
#  Projekt   : lucent-job-wmicFinder
#  Zweck     : Findet wmic-Aufrufe in Quellordnern (lokal/UNC) und schreibt
#              einen eigenstaendigen HTML-Report.
#  Autor     : tobias philipp <tobias@philipp.team>
#  Repository: github.com/monoeagle/lucent-job-wmicFinder
#  Version   : 1.1.0
#  Stand     : 2026-09-11
#  Benoetigt : Windows PowerShell 5.1 oder PowerShell 7+
#------------------------------------------------------------------------------
#  AUFBAU
#    param / Parametersaetze ... Scan | CreateSample (schliessen sich aus)
#    region Sampledaten ........ Definitionstabelle + Erzeugung des Testbaums
#    region Konstanten ......... Suchregex, Kommentarmarker je Dateityp
#    region Hilfsfunktionen .... Kodierung, Zeilenindex, Einstufung, HTML
#    region Kandidaten einsammeln  Verzeichnis-Walker mit Unterbaum-Schnitt
#    region Dateien durchsuchen .. Treffer je Datei ermitteln
#    region Report bauen ....... HTML bauen, schreiben und oeffnen
#------------------------------------------------------------------------------
#  HINWEISE FUER AENDERUNGEN
#    - Sampledaten: Dateiinhalt UND Soll-Trefferzahl stehen in derselben
#      Tabelle ($samples in New-SampleTree). Wer den Inhalt aendert, zieht dort
#      Active/Comment mit nach -- sonst luegt die Soll-Ausgabe von Lauf 1.
#    - Der Quelltext dieser Datei bleibt bewusst reines ASCII. Umlaute in
#      Sample-Pfaden und -Inhalten werden ueber [char]0xNN gebaut: Windows
#      PowerShell 5.1 liest .ps1 ohne BOM als ANSI und wuerde UTF-8-Literale
#      verstuemmeln.
#    - Kodierung beim Lesen: Get-Content ist bewusst nicht im Einsatz. 5.1
#      schreibt .ps1 per Default als UTF-16; ohne eigene BOM-Erkennung faellt
#      jede so gespeicherte Datei durchs Raster.
#    - Einstufung: im Zweifel "Aktiv". Ein falsches "Kommentar" versteckt einen
#      echten Fund, ein falsches "Aktiv" kostet nur einen Blick.
#------------------------------------------------------------------------------
#  AENDERUNGEN
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

.PARAMETER NoOpen
    Unterdrueckt das automatische Oeffnen des Reports im Browser. Ohne diesen
    Schalter wird der Report nach dem Scan geoeffnet.

.PARAMETER PassThru
    Gibt die Fundstellen zusaetzlich als Objekte auf die Pipeline aus.

.PARAMETER CreateSampleData
    Legt unter dem angegebenen Pfad einen Testbaum mit bekannten wmic-Fundstellen
    an und gibt die Soll-Werte aus, gegen die der anschliessende Scan zu pruefen
    ist. Schliesst alle Scan-Parameter aus.

.PARAMETER Force
    Nur mit -CreateSampleData: loescht den Inhalt eines bereits erzeugten
    Sampledaten-Verzeichnisses und legt ihn neu an. Ein Verzeichnis ohne die
    Markierungsdatei .wmic-sampledata wird auch mit -Force nicht angetastet.

.EXAMPLE
    .\Find-WmicUsage.ps1 -Path C:\Projekte

    Scannt und oeffnet den Report anschliessend im Browser.

.EXAMPLE
    .\Find-WmicUsage.ps1 -CreateSampleData C:\Temp\wmic-test
    .\Find-WmicUsage.ps1 -Path C:\Temp\wmic-test

    Zwei Laeufe: erst Testdaten erzeugen, dann dagegen scannen. Lauf 1 gibt die
    Soll-Werte aus, Lauf 2 muss sie treffen.

.EXAMPLE
    .\Find-WmicUsage.ps1 -Path \\fs01\skripte$, D:\Tools -OutputPath C:\Temp\wmic.html

.EXAMPLE
    .\Find-WmicUsage.ps1 -Path C:\Projekte -Extension ps1,bat,cmd -PassThru -NoOpen |
        Export-Csv .\wmic.csv -NoTypeInformation -Encoding UTF8

.NOTES
    Getestet mit PowerShell 7. Bewusst 5.1-kompatibel geschrieben.
#>
[CmdletBinding(DefaultParameterSetName = 'Scan')]
param(
    [Parameter(ParameterSetName = 'Scan', Mandatory = $true, Position = 0,
        ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [Alias('FullName', 'PSPath')]
    [string[]]$Path,

    [Parameter(ParameterSetName = 'Scan')]
    [string]$OutputPath,

    [Parameter(ParameterSetName = 'Scan')]
    [string[]]$Extension = @(
        'ps1', 'psm1', 'psd1', 'bat', 'cmd', 'vbs', 'vbe', 'wsf', 'js', 'py',
        'cs', 'vb', 'xml', 'config', 'json', 'yml', 'yaml', 'sql', 'txt', 'md',
        'ini', 'inf', 'reg', 'sh'
    ),

    [Parameter(ParameterSetName = 'Scan')]
    [string[]]$ExcludeDirectory = @('.git', '.svn', '.hg', 'node_modules', 'bin', 'obj', '_deps', '.archiv'),

    [Parameter(ParameterSetName = 'Scan')]
    [ValidateRange(1, 2048)]
    [int]$MaxFileSizeMB = 10,

    [Parameter(ParameterSetName = 'Scan')]
    [switch]$NoOpen,

    [Parameter(ParameterSetName = 'Scan')]
    [switch]$PassThru,

    [Parameter(ParameterSetName = 'CreateSample', Mandatory = $true)]
    [string]$CreateSampleData,

    [Parameter(ParameterSetName = 'CreateSample')]
    [switch]$Force
)

begin {
    Set-StrictMode -Version 2.0
    $collectedPaths = New-Object System.Collections.Generic.List[string]
}

process {
    if ($PSCmdlet.ParameterSetName -ne 'Scan') { return }
    foreach ($p in $Path) {
        if (-not [string]::IsNullOrWhiteSpace($p)) { $collectedPaths.Add($p) }
    }
}

end {

    #region Sampledaten ------------------------------------------------------

    function Write-SampleFile {
        param(
            [string]$FullPath,
            [string[]]$Lines,
            [string]$Kind,
            [long]$MinBytes
        )

        $dir = [System.IO.Path]::GetDirectoryName($FullPath)
        if ($dir -and -not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }

        $text = ''
        if ($Lines -and $Lines.Count -gt 0) { $text = ($Lines -join "`r`n") + "`r`n" }

        switch ($Kind) {
            'leer' {
                [System.IO.File]::WriteAllText($FullPath, '', (New-Object System.Text.UTF8Encoding($false)))
            }
            'utf8' {
                [System.IO.File]::WriteAllText($FullPath, $text, (New-Object System.Text.UTF8Encoding($false)))
            }
            'utf16le' {
                # So schreibt Windows PowerShell 5.1 per Default -- genau der Fall, in
                # dem eine Suche ohne Kodierungserkennung stillschweigend nichts findet.
                [System.IO.File]::WriteAllText($FullPath, $text, (New-Object System.Text.UnicodeEncoding($false, $true)))
            }
            'latin1' {
                [System.IO.File]::WriteAllText($FullPath, $text, [System.Text.Encoding]::GetEncoding(28591))
            }
            'binaer' {
                # Whitelisted Endung, aber NUL-Bytes: muss als binaer erkannt und
                # NICHT als Treffer gezaehlt werden.
                $bytes = New-Object System.Collections.Generic.List[byte]
                $bytes.AddRange([System.Text.Encoding]::ASCII.GetBytes('BIN'))
                $bytes.AddRange([byte[]](0, 0, 0, 1, 2))
                $bytes.AddRange([System.Text.Encoding]::ASCII.GetBytes('wmic os get name'))
                $bytes.AddRange([byte[]](0, 255, 0))
                $bytes.AddRange([System.Text.Encoding]::ASCII.GetBytes('Fuellbytes ohne Bedeutung'))
                [System.IO.File]::WriteAllBytes($FullPath, $bytes.ToArray())
            }
            'gross' {
                # Muss am Groessenlimit scheitern. Enthaelt absichtlich einen echten
                # Aufruf: taucht er im Report auf, hat das Limit nicht gegriffen.
                $filler = 'Protokollzeile ohne Bedeutung, nur zum Aufblaehen der Datei bis ueber das Groessenlimit.'
                $needed = [int][Math]::Ceiling($MinBytes / ($filler.Length + 2))
                $sw = New-Object System.IO.StreamWriter($FullPath, $false, (New-Object System.Text.UTF8Encoding($false)))
                try {
                    foreach ($l in $Lines) { $sw.WriteLine($l) }
                    for ($i = 0; $i -lt $needed; $i++) { $sw.WriteLine($filler) }
                } finally { $sw.Dispose() }
            }
            default { throw ('Unbekannte Sample-Art: {0}' -f $Kind) }
        }
    }

    function New-SampleTree {
        <#
            Legt den Testbaum an und gibt die Soll-Werte aus.

            Inhalt und erwartete Trefferzahl stehen absichtlich in EINER Tabelle:
            wer eine Datei aendert, sieht die zugehoerige Erwartung daneben. Eine
            im README gepflegte Zahl waere nach der zweiten Aenderung falsch.

            Umlaute werden ueber [char]0xNN gebaut, damit der Quelltext dieser
            Datei reines ASCII bleibt (siehe Kopf).
        #>
        [CmdletBinding()]
        param([string]$Target, [switch]$Force)

        $sep = [System.IO.Path]::DirectorySeparatorChar
        $ae = [char]0xE4
        $oe = [char]0xF6
        $ue = [char]0xFC
        $sz = [char]0xDF

        $tief = 'Skripte/Pr' + $ue + 'fung/Tief'
        $markerName = '.wmic-sampledata'

        $samples = @(
            @{
                Rel = 'Deploy.ps1'; Kind = 'utf8'; Expect = 'treffer'
                Active = 2; Comment = 1; MinBytes = 0
                Note = 'PowerShell: #-Kommentar, wmic.exe, Nicht-Treffer wmiclass'
                Lines = @(
                    '# Deploy-Skript'
                    '$os = wmic os get Caption /value'
                    '# wmic cpu get name'
                    '$cim = Get-CimInstance Win32_OperatingSystem'
                    '$typ = "wmiclass"'
                    '& wmic.exe product get name'
                )
            },
            @{
                Rel = 'legacy.cmd'; Kind = 'utf8'; Expect = 'treffer'
                Active = 3; Comment = 2; MinBytes = 0
                Note = 'CMD: REM, ::, FOR /F um wmic, /node: mit /format:csv'
                Lines = @(
                    '@echo off'
                    'REM Altbestand -- laeuft ab Windows 11 25H2 ins Leere'
                    'REM wmic bios get serialnumber'
                    'wmic csproduct get uuid'
                    ':: wmic path win32_service get name'
                    'for /f "skip=1 tokens=2 delims==" %%i in (''wmic os get version /value'') do set OSVER=%%i'
                    'wmic /node:"%REMOTE%" logicaldisk get freespace,size /format:csv > "%TEMP%\disk.csv"'
                    'echo OS=%OSVER%'
                )
            },
            @{
                Rel = $tief + '/collect.bat'; Kind = 'utf8'; Expect = 'treffer'
                Active = 2; Comment = 1; MinBytes = 0
                Note = 'BAT tief im Baum: rem klein, FOR /F, /format:list'
                Lines = @(
                    '@echo off'
                    'setlocal'
                    'rem wmic nic get macaddress'
                    'for /f "skip=1 tokens=2 delims==" %%a in (''wmic qfe get hotfixid /value'') do echo %%a'
                    'wmic process get name,processid /format:list'
                    'endlocal'
                )
            },
            @{
                Rel = 'query.vbs'; Kind = 'utf8'; Expect = 'treffer'
                Active = 1; Comment = 1; MinBytes = 0
                Note = 'VBScript: Hochkomma als Kommentar, Aufruf via WScript.Shell'
                Lines = @(
                    ''' wmic hier deaktiviert'
                    'Set o = CreateObject("WScript.Shell")'
                    'o.Run "wmic process list brief"'
                )
            },
            @{
                Rel = 'notes.md'; Kind = 'utf8'; Expect = 'treffer'
                Active = 1; Comment = 0; MinBytes = 0
                Note = 'Markdown ohne Kommentarmarker; wmiclass/swmic bleiben stumm'
                Lines = @(
                    'Migration: wmiclass ist kein Treffer, swmic auch nicht.'
                    'Aber wmic hier ist einer.'
                )
            },
            @{
                Rel = 'Inventory-utf16.ps1'; Kind = 'utf16le'; Expect = 'treffer'
                Active = 1; Comment = 0; MinBytes = 0
                Note = 'UTF-16 LE mit BOM -- Default von Windows PowerShell 5.1'
                Lines = @(
                    '# Inventory, gespeichert wie 5.1 es per Default tut'
                    '$disks = wmic logicaldisk get size,freespace'
                )
            },
            @{
                Rel = 'ANSI-Umlaute.ps1'; Kind = 'latin1'; Expect = 'treffer'
                Active = 1; Comment = 0; MinBytes = 0
                Note = 'Latin-1 mit Umlauten -- prueft den Rueckfall der Kodierungserkennung'
                Lines = @(
                    ('# Gr' + $oe + $sz + 'enpr' + $ue + 'fung f' + $ue + 'r Datentr' + $ae + 'ger')
                    '$x = wmic diskdrive get model,size'
                )
            },
            @{
                Rel = 'leer.ps1'; Kind = 'leer'; Expect = 'leer'
                Active = 0; Comment = 0; MinBytes = 0
                Note = 'Leere Datei -- darf nicht stolpern'
                Lines = @()
            },
            @{
                Rel = 'Konfiguration alt/config.xml'; Kind = 'utf8'; Expect = 'treffer'
                Active = 1; Comment = 1; MinBytes = 0
                Note = 'Leerzeichen im Ordnernamen; XML-Blockkommentar ueber Zeilen'
                Lines = @(
                    '<config>'
                    '  <!-- Alte Abfrage:'
                    '       wmic nicconfig get ipaddress'
                    '  -->'
                    '  <command>wmic os get version</command>'
                    '</config>'
                )
            },
            @{
                Rel = 'Konfiguration alt/setup.ini'; Kind = 'utf8'; Expect = 'treffer'
                Active = 1; Comment = 1; MinBytes = 0
                Note = 'INI: Semikolon-Kommentar gegen Wert hinter Gleichheitszeichen'
                Lines = @(
                    '[Inventar]'
                    '; wmic baseboard get product'
                    'Befehl=wmic computersystem get model'
                )
            },
            @{
                Rel = $tief + '/inventory.sql'; Kind = 'utf8'; Expect = 'treffer'
                Active = 1; Comment = 1; MinBytes = 0
                Note = 'SQL: doppelter Bindestrich als Kommentar'
                Lines = @(
                    '-- wmic diskdrive get status'
                    'INSERT INTO befehle (text) VALUES (''wmic os get name'');'
                )
            },
            @{
                Rel = $tief + '/collect.py'; Kind = 'utf8'; Expect = 'treffer'
                Active = 1; Comment = 1; MinBytes = 0
                Note = 'Python: #-Kommentar gegen subprocess-Aufruf'
                Lines = @(
                    'import subprocess'
                    '# subprocess.run("wmic os get caption")'
                    'subprocess.run(["wmic", "computersystem", "get", "name"])'
                )
            },
            @{
                Rel = $tief + '/export.reg'; Kind = 'utf8'; Expect = 'treffer'
                Active = 1; Comment = 0; MinBytes = 0
                Note = 'Registry-Export: Wert in Anfuehrungszeichen, kein Kommentar'
                Lines = @(
                    'Windows Registry Editor Version 5.00'
                    ''
                    '[HKEY_LOCAL_MACHINE\SOFTWARE\Lucent\Inventar]'
                    '"Befehl"="wmic os get version"'
                )
            },
            @{
                Rel = 'Gross/minified.js'; Kind = 'utf8'; Expect = 'treffer'
                Active = 1; Comment = 1; MinBytes = 0
                Note = 'Sehr lange Zeile -- prueft die Zeilenkuerzung im Report'
                Lines = @(
                    '// wmic veraltet, Ersatz siehe cim.js'
                    ('var pad=[' + ('0,' * 200).TrimEnd(',') + '];function run(){return exec("wmic os get name");}var tail=[' + ('1,' * 200).TrimEnd(',') + '];')
                )
            },
            @{
                Rel = 'Gross/riesig.txt'; Kind = 'gross'; Expect = 'gross'
                Active = 0; Comment = 0; MinBytes = 11MB
                Note = 'Ueber dem Groessenlimit -- der Treffer darin darf NICHT auftauchen'
                Lines = @(
                    'Protokollauszug. Enthaelt absichtlich einen Aufruf:'
                    'wmic os get caption'
                )
            },
            @{
                Rel = 'Binaer/getarnt.txt'; Kind = 'binaer'; Expect = 'binaer'
                Active = 0; Comment = 0; MinBytes = 0
                Note = 'Whitelisted Endung, aber NUL-Bytes -- muss als binaer gelten'
                Lines = @()
            },
            @{
                Rel = 'node_modules/skip.js'; Kind = 'utf8'; Expect = 'ausgeschlossen'
                Active = 0; Comment = 0; MinBytes = 0
                Note = 'Ausgeschlossener Unterbaum -- darf gar nicht gelesen werden'
                Lines = @(
                    '// wmic'
                    'exec("wmic os get name")'
                )
            },
            @{
                Rel = 'sub/nohit.ps1'; Kind = 'utf8'; Expect = 'ohne'
                Active = 0; Comment = 0; MinBytes = 0
                Note = 'Bereits migriert -- kein Treffer, zaehlt aber als durchsucht'
                Lines = @(
                    'Get-CimInstance -ClassName Win32_BIOS | Select-Object SerialNumber'
                )
            }
        )

        # ---- Zielverzeichnis pruefen ----------------------------------------
        $full = [System.IO.Path]::GetFullPath($Target)

        if (Test-Path -LiteralPath $full -PathType Leaf) {
            throw ('"{0}" ist eine Datei, kein Verzeichnis.' -f $full)
        }

        if (Test-Path -LiteralPath $full -PathType Container) {
            $existing = @([System.IO.Directory]::GetFileSystemEntries($full))
            if ($existing.Count -gt 0) {
                # Ohne Markierung wird nichts geloescht: ein Tippfehler im Zielpfad
                # darf kein echtes Verzeichnis ausraeumen -- auch nicht mit -Force.
                if (-not (Test-Path -LiteralPath (Join-Path $full $markerName) -PathType Leaf)) {
                    throw ('"{0}" ist nicht leer und traegt keine Sampledaten-Markierung ({1}). Zur Sicherheit wird hier nichts geloescht -- bitte ein anderes Zielverzeichnis waehlen.' -f $full, $markerName)
                }
                if (-not $Force) {
                    throw ('"{0}" enthaelt bereits Sampledaten. Mit -Force wird der Inhalt geloescht und neu erzeugt.' -f $full)
                }
                Get-ChildItem -LiteralPath $full -Force | Remove-Item -Recurse -Force
            }
        } else {
            New-Item -ItemType Directory -Path $full -Force | Out-Null
        }

        # ---- schreiben -------------------------------------------------------
        [System.IO.File]::WriteAllText(
            (Join-Path $full $markerName),
            ('Markierung fuer Find-WmicUsage.ps1 -CreateSampleData.' + [Environment]::NewLine +
                'Erzeugt: ' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') + [Environment]::NewLine +
                'Nur ein Verzeichnis mit dieser Datei wird von -Force geleert.' + [Environment]::NewLine),
            (New-Object System.Text.UTF8Encoding($false)))

        foreach ($smp in $samples) {
            Write-SampleFile -FullPath (Join-Path $full $smp.Rel.Replace('/', $sep)) `
                -Lines $smp.Lines -Kind $smp.Kind -MinBytes $smp.MinBytes
        }

        # ---- Soll-Werte ausgeben ---------------------------------------------
        # Alles aus derselben Tabelle abgeleitet, nichts fest verdrahtet.
        $hits = @($samples | Where-Object { $_.Expect -eq 'treffer' })
        $grossCount = @($samples | Where-Object { $_.Expect -eq 'gross' }).Count
        $binaerCount = @($samples | Where-Object { $_.Expect -eq 'binaer' }).Count
        $candidates = @($samples | Where-Object { $_.Expect -ne 'ausgeschlossen' }).Count
        $scannedExpected = $candidates - $grossCount

        $sumActive = 0
        $sumComment = 0
        foreach ($smp in $hits) { $sumActive += $smp.Active; $sumComment += $smp.Comment }

        $width = 0
        foreach ($smp in $samples) {
            $l = $smp.Rel.Replace('/', $sep).Length
            if ($l -gt $width) { $width = $l }
        }
        $line = '  {0}  -----  -----  {1}' -f ('-' * $width), ('-' * 58)

        Write-Host ''
        Write-Host ('  Sampledaten erzeugt: {0}' -f $full)
        Write-Host ''
        Write-Host ('  {0}  aktiv  Komm.  prueft' -f 'Datei'.PadRight($width))
        Write-Host $line
        foreach ($smp in $samples) {
            $rel = $smp.Rel.Replace('/', $sep)
            if ($smp.Expect -eq 'treffer') {
                $a = '{0,5}' -f $smp.Active
                $c = '{0,5}' -f $smp.Comment
            } else {
                $a = '    .'
                $c = '    .'
            }
            Write-Host ('  {0}  {1}  {2}  {3}' -f $rel.PadRight($width), $a, $c, $smp.Note)
        }
        Write-Host $line
        Write-Host ''
        Write-Host '  SOLL fuer einen Scan mit Standardparametern:'
        Write-Host ('    Dateien mit Treffern : {0}' -f $hits.Count)
        Write-Host ('    Stellen gesamt       : {0}  (aktiv: {1}, auskommentiert: {2})' -f ($sumActive + $sumComment), $sumActive, $sumComment)
        Write-Host ('    Dateien durchsucht   : {0} von {1} Kandidaten' -f $scannedExpected, $candidates)
        Write-Host ('    ueber Groessenlimit  : {0}' -f $grossCount)
        Write-Host ('    als binaer erkannt   : {0}' -f $binaerCount)
        Write-Host  '    nicht lesbar         : 0'
        Write-Host ''
        Write-Host '  Lauf 2 -- dagegen scannen:'
        Write-Host ('    .{0}Find-WmicUsage.ps1 -Path "{1}"' -f $sep, $full)
        Write-Host ''
    }

    #endregion

    if ($PSCmdlet.ParameterSetName -eq 'CreateSample') {
        New-SampleTree -Target $CreateSampleData -Force:$Force
        return
    }

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

    function Open-Report {
        <#
            Oeffnet den Report im Standardbrowser.

            Invoke-Item reicht dafuer nicht plattformuebergreifend, und
            $IsLinux/$IsMacOS existieren in Windows PowerShell 5.1 gar nicht --
            deshalb die Abfrage ueber Get-Variable statt direkt.
        #>
        param([string]$FullPath)

        $platform = 'Windows'
        $v = Get-Variable -Name 'IsLinux' -ErrorAction SilentlyContinue
        if ($v -and $v.Value) { $platform = 'Linux' }
        $v = Get-Variable -Name 'IsMacOS' -ErrorAction SilentlyContinue
        if ($v -and $v.Value) { $platform = 'MacOS' }

        try {
            switch ($platform) {
                'Linux' { Start-Process -FilePath 'xdg-open' -ArgumentList $FullPath | Out-Null }
                'MacOS' { Start-Process -FilePath 'open' -ArgumentList $FullPath | Out-Null }
                default { Start-Process -FilePath $FullPath | Out-Null }
            }
        } catch {
            Write-Warning ('Report konnte nicht geoeffnet werden ({0}). Bitte manuell oeffnen: {1}' -f $_.Exception.Message, $FullPath)
        }
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
    Write-Host ('  Report               : {0}' -f $OutputPath)
    Write-Host ''

    if (-not $NoOpen) { Open-Report -FullPath $OutputPath }

    if ($PassThru) { $findings }
}
