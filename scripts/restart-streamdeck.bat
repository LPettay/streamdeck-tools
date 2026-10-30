@echo off
rem Restart Stream Deck. Wired to a Stream Deck Executor button.
rem Win32_Process.Create starts the worker outside Stream Deck's process tree so it survives the kill.
powershell.exe -NoProfile -WindowStyle Hidden -Command "Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"%~dp0restart-streamdeck.ps1\"' } | Out-Null"
