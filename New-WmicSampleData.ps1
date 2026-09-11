#Requires -Version 5.1
#==============================================================================
#  New-WmicSampleData.ps1
#------------------------------------------------------------------------------
#  Projekt   : lucent-job-wmicFinder
#  Zweck     : Erzeugt einen Testbaum mit bekannten wmic-Fundstellen und gibt
#              die Soll-Werte aus, gegen die Find-WmicUsage.ps1 zu pruefen ist.
#  Autor     : tobias philipp <tobias@philipp.team>
#  Repository: github.com/monoeagle/lucent-job-wmicFinder
#  Version   : 1.0.0
#  Stand     : 2026-09-11
#  Benoetigt : Windows PowerShell 5.1 oder PowerShell 7+
#------------------------------------------------------------------------------
#  NUR ENTWICKLER-WERKZEUG -- GEHOERT NICHT AUF ZIELSYSTEME
#  Dieses Skript legt absichtlich .bat-, .cmd-, .vbs-, .reg- und .ps1-Dateien
#  mit wmic-Kommandozeilen an, erzeugt eine Binaerdatei mit NUL-Bytes und kann
#  ein Verzeichnis rekursiv leeren. Das ist als Testdatensatz gewollt, sieht
#  fuer eine Verhaltensanalyse aber wie ein Dropper aus -- Virenschutz und
#  Anwendungs-Isolation (z. B. HP Sure Click) schlagen hier erwartbar an.
#  Deshalb liegt der Generator in einer eigenen Datei: Find-WmicUsage.ps1
#  enthaelt davon nichts und bleibt frei von wmic-Literalen.
#------------------------------------------------------------------------------
#  AUFBAU
#    param ................... Zielverzeichnis, -Force
#    Write-SampleFile ........ schreibt eine Sample-Datei in der gewuenschten
#                              Kodierung (utf8/utf16le/latin1/binaer/gross/leer)
#    New-SampleTree .......... Definitionstabelle + Erzeugung + Soll-Ausgabe
#------------------------------------------------------------------------------
#  HINWEISE FUER AENDERUNGEN
#    - Dateiinhalt UND Soll-Trefferzahl stehen in derselben Tabelle ($samples).
#      Wer den Inhalt aendert, zieht dort Active/Comment mit nach -- sonst luegt
#      die Soll-Ausgabe.
#    - Der Quelltext bleibt reines ASCII. Umlaute in Sample-Pfaden und -Inhalten
#      werden ueber [char]0xNN gebaut: Windows PowerShell 5.1 liest eine .ps1
#      ohne BOM als ANSI und wuerde UTF-8-Literale verstuemmeln.
#------------------------------------------------------------------------------
#  AENDERUNGEN
#    1.0.0  2026-09-11  Aus Find-WmicUsage.ps1 1.1.0 herausgeloest
#------------------------------------------------------------------------------
#  ACHTUNG: Die Leerzeile zwischen diesem Banner und dem <# .SYNOPSIS #>-Block
#  muss bleiben. Steht eine #-Zeile unmittelbar davor, liest PowerShell beides
#  als EINEN Kommentarblock -- Get-Help findet dann keine Hilfe mehr.
#==============================================================================

<#
.SYNOPSIS
    Erzeugt Testdaten fuer Find-WmicUsage.ps1 und gibt die Soll-Werte aus.

.DESCRIPTION
    Legt unter dem angegebenen Pfad einen Testbaum mit bekannten wmic-Fundstellen
    an: Erkennungsfaelle je Dateityp und Kodierung sowie die Randfaelle, die sonst
    ungeprueft bleiben (Datei ueber dem Groessenlimit, erlaubte Endung mit
    NUL-Bytes, ausgeschlossener Unterbaum, leere Datei, Umlaut und Leerzeichen im
    Pfad, sehr lange Zeile).

    Dateiinhalt und erwartete Trefferzahl stehen in derselben Tabelle, damit sie
    nicht auseinanderdriften koennen. Die Soll-Ausgabe wird daraus abgeleitet.

    NUR fuer Entwicklung und Test. Das Skript schreibt ausfuehrbare Dateitypen
    mit wmic-Kommandozeilen und gehoert nicht auf Zielsysteme.

.PARAMETER Path
    Zielverzeichnis fuer den Testbaum.

.PARAMETER Force
    Loescht den Inhalt eines bereits erzeugten Sampledaten-Verzeichnisses und legt
    ihn neu an. Ein nicht leeres Verzeichnis ohne die Markierungsdatei
    .wmic-sampledata wird auch mit -Force nicht angetastet.

.EXAMPLE
    .\New-WmicSampleData.ps1 -Path C:\Temp\wmic-test
    .\Find-WmicUsage.ps1 -Path C:\Temp\wmic-test

    Zwei Laeufe: erst Testdaten erzeugen, dann dagegen scannen. Lauf 1 gibt die
    Soll-Werte aus, Lauf 2 muss sie treffen.

.EXAMPLE
    .\New-WmicSampleData.ps1 -Path C:\Temp\wmic-test -Force

.NOTES
    Getestet mit PowerShell 7. Bewusst 5.1-kompatibel geschrieben.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Path,

    [switch]$Force
)

Set-StrictMode -Version 2.0

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

New-SampleTree -Target $Path -Force:$Force
