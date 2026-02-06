# Extend All Mode - All 3 monitors extended
# Layout: TV (left) | Primary (center) | Ultrawide (right)
# Positions: TV @ -3840,0 | Primary @ 0,0 | Ultrawide @ 2560,0

param([switch]$Silent)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\MonitorConfig.ps1"

if (-not $Silent) {
    Write-Host ""
    Write-Host "========================================================" -ForegroundColor Magenta
    Write-Host "          SWITCHING TO EXTEND ALL MODE                  " -ForegroundColor Magenta
    Write-Host "         TV <- Primary <- Ultrawide (all extended)      " -ForegroundColor Magenta
    Write-Host "========================================================" -ForegroundColor Magenta
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

# Step 1: Enable all monitors (with unique source IDs for extend mode)
if (-not $Silent) { Write-Host "`nStep 1: Enable all monitors" -ForegroundColor White }
Enable-Monitor -Pattern "VG27A" -X 0 -Y 0
Enable-Monitor -Pattern "LC34G55T" -X 2560 -Y 0
Enable-Monitor -Pattern "V4K43M" -X -3840 -Y 0

# Step 2: Wait for displays to settle
if (-not $Silent) { Write-Host "`nStep 2: Waiting for displays..." -ForegroundColor White }
Start-Sleep -Seconds 2

# Step 3: Set precise positions
if (-not $Silent) { Write-Host "`nStep 3: Configure layout" -ForegroundColor White }
Set-MonitorPositions `
    -Primary @{ X = 0; Y = 0 } `
    -Ultrawide @{ X = 2560; Y = 0 } `
    -TV @{ X = -3840; Y = -720 }  # Bottom-aligned (1440 - 2160 = -720)

# Step 4: Refresh desktop to fix wallpaper/taskbar overlap
if (-not $Silent) { Write-Host "`nStep 4: Refresh desktop" -ForegroundColor White }
Start-Sleep -Seconds 1
Refresh-Desktop

# Final status
if (-not $Silent) {
    Write-Host ""
    Write-Host "========================================================" -ForegroundColor Magenta
    Write-Host "  [OK] EXTEND ALL MODE ACTIVE" -ForegroundColor Magenta
    Write-Host "    Layout: [TV 4K] -> [Primary 1440p] -> [Ultrawide 1440p]" -ForegroundColor Gray
    Write-Host "========================================================" -ForegroundColor Magenta
    Show-MonitorStatus
}

@{ mode = "extend-all" } | ConvertTo-Json | Set-Content "$PSScriptRoot\current-mode.json" -Force
exit 0
