' Startet die Desktop-Katze ohne sichtbares Konsolenfenster
Set sh = CreateObject("WScript.Shell")
p = Left(WScript.ScriptFullName, InStrRev(WScript.ScriptFullName, "\"))
sh.Run "powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -STA -File """ & p & "katze.ps1""", 0, False
