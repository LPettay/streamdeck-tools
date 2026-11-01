# Restart the Stream Deck app cleanly.
# Run via restart-streamdeck.bat, which detaches this script from Stream Deck's process tree
# (killing Stream Deck would otherwise kill the button's own child process mid-restart).

$ErrorActionPreference = "Stop"
$exe = "C:\Program Files\Elgato\StreamDeck\StreamDeck.exe"
$pluginRoot = "$env:APPDATA\Elgato\StreamDeck\Plugins"

# Let the button press finish its own bookkeeping before we pull the rug
Start-Sleep -Seconds 1

# 1. Stop the app and wait for it to actually exit
Get-Process StreamDeck -ErrorAction SilentlyContinue | Stop-Process -Force
$deadline = (Get-Date).AddSeconds(15)
while ((Get-Process StreamDeck -ErrorAction SilentlyContinue) -and (Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 250
}
if (Get-Process StreamDeck -ErrorAction SilentlyContinue) { throw "StreamDeck did not exit" }

# 2. Reap orphaned plugin processes (they live under the Plugins folder) so none hold stale sockets
Get-CimInstance Win32_Process |
    Where-Object { $_.ExecutablePath -and $_.ExecutablePath.StartsWith($pluginRoot, [StringComparison]::OrdinalIgnoreCase) } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

# 3. Relaunch
Start-Sleep -Seconds 2
Start-Process $exe
