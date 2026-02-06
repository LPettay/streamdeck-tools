# TV Extend Mode - Primary (VG27A) + TV (Vizio) extended, Ultrawide disabled
# Layout: TV (left) | Primary (right)
# Positions: TV @ -3840,-720 | Primary @ 0,0

param([switch]$Silent)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\MonitorConfig.ps1"

if (-not $Silent) {
    Write-Host ""
    Write-Host "========================================================" -ForegroundColor DarkCyan
    Write-Host "          SWITCHING TO TV EXTEND MODE                   " -ForegroundColor DarkCyan
    Write-Host "       Primary + TV extended (Ultrawide off)            " -ForegroundColor DarkCyan
    Write-Host "========================================================" -ForegroundColor DarkCyan
    Write-Host ""
}

# Step 0: If coming from clone mode, break it first by disabling non-primary displays
# This ensures we get unique source IDs when re-enabling
if (-not $Silent) { Write-Host "Step 0: Reset from possible clone mode" -ForegroundColor White }

# Check if we're in clone mode (multiple monitors at same position)
$monitors = Get-MonitorStatus
$positions = $monitors | ForEach-Object { "$($_.X),$($_.Y)" }
$uniquePositions = $positions | Select-Object -Unique
if ($monitors.Count -gt 1 -and $uniquePositions.Count -eq 1) {
    Write-Host "  Detected clone mode, breaking it..." -ForegroundColor Yellow
    # Disable TV and Ultrawide to break clone, keep Primary
    Disable-Monitor -Pattern "V4K43M" 2>$null
    Disable-Monitor -Pattern "LC34G55T" 2>$null
    Start-Sleep -Seconds 2
}

# Step 1: Disable Ultrawide
if (-not $Silent) { Write-Host "`nStep 1: Disable Ultrawide" -ForegroundColor White }
Disable-Monitor -Pattern "LC34G55T"

# Step 2: Enable Primary and TV
if (-not $Silent) { Write-Host "`nStep 2: Enable Primary and TV" -ForegroundColor White }
Enable-Monitor -Pattern "VG27A" -X 0 -Y 0
Enable-Monitor -Pattern "V4K43M" -X -3840 -Y 0

# Step 3: Wait for displays to settle
if (-not $Silent) { Write-Host "`nStep 3: Waiting for displays..." -ForegroundColor White }
Start-Sleep -Seconds 2

# Step 4: Set precise positions
if (-not $Silent) { Write-Host "`nStep 4: Configure layout" -ForegroundColor White }
Set-MonitorPositions `
    -Primary @{ X = 0; Y = 0 } `
    -TV @{ X = -3840; Y = -720 }

# Step 5: Refresh desktop to fix wallpaper/taskbar
if (-not $Silent) { Write-Host "`nStep 5: Refresh desktop" -ForegroundColor White }
Start-Sleep -Seconds 1
Refresh-Desktop

# Final status
if (-not $Silent) {
    Write-Host ""
    Write-Host "========================================================" -ForegroundColor DarkCyan
    Write-Host "  [OK] TV EXTEND MODE ACTIVE" -ForegroundColor DarkCyan
    Write-Host "    Layout: [TV 4K] -> [Primary 1440p]" -ForegroundColor Gray
    Write-Host "========================================================" -ForegroundColor DarkCyan
    Show-MonitorStatus
}

@{ mode = "tv-extend" } | ConvertTo-Json | Set-Content "$PSScriptRoot\current-mode.json" -Force
exit 0
