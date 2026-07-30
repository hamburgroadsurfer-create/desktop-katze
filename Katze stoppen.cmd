@echo off
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$me = $PID; Get-CimInstance Win32_Process -Filter \"Name='powershell.exe'\" | Where-Object { $_.CommandLine -like '*katze.ps1*' -and $_.ProcessId -ne $me } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }; Write-Host 'Katze(n) gestoppt.'"
timeout /t 2 /nobreak >nul
