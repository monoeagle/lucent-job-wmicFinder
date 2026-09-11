# Deploy-Skript (Beispieldatei fuer den Selbsttest)
$os = wmic os get Caption /value
# wmic cpu get name
$cim = Get-CimInstance Win32_OperatingSystem
$typ = "wmiclass"
& wmic.exe product get name
