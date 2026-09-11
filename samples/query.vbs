' wmic hier deaktiviert
Set o = CreateObject("WScript.Shell")
o.Run "wmic process list brief"
