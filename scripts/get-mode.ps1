# get-mode.ps1 - Returns current monitor mode as JSON for Stream Deck polling
$stateFile = "$PSScriptRoot\current-mode.json"
if (Test-Path $stateFile) {
    Get-Content $stateFile -Raw
} else {
    @{ mode = "unknown" } | ConvertTo-Json
}
