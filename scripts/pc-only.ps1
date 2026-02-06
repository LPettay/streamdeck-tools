# PC Only Mode - Primary (VG27A) + Ultrawide (Samsung), TV disabled
# Layout: Primary @ 0,0 | Ultrawide @ 2560,0

param([switch]$Silent)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\MonitorConfig.ps1"

if (-not $Silent) {
    Write-Host ""
    Write-Host "========================================================" -ForegroundColor Cyan
    Write-Host "          SWITCHING TO PC ONLY MODE                     " -ForegroundColor Cyan  
    Write-Host "       Primary + Ultrawide (TV disabled)                " -ForegroundColor Cyan
    Write-Host "========================================================" -ForegroundColor Cyan
    Write-Host ""
}

# Step 1: Disable TV
if (-not $Silent) { Write-Host "Step 1: Disable TV" -ForegroundColor White }
Disable-Monitor -Pattern "V4K43M"

# Step 2: Ensure Primary and Ultrawide are enabled
if (-not $Silent) { Write-Host "`nStep 2: Enable PC monitors" -ForegroundColor White }
Enable-Monitor -Pattern "VG27A" -X 0 -Y 0
Enable-Monitor -Pattern "LC34G55T" -X 2560 -Y 0

# Step 3: Wait for displays to settle
Start-Sleep -Seconds 1

# Step 4: Set precise positions
if (-not $Silent) { Write-Host "`nStep 3: Configure layout" -ForegroundColor White }
Set-MonitorPositions `
    -Primary @{ X = 0; Y = 0 } `
    -Ultrawide @{ X = 2560; Y = 0 }

# Refresh desktop to fix wallpaper/taskbar
Start-Sleep -Seconds 1
Refresh-Desktop

# Final status
if (-not $Silent) {
    Write-Host ""
    Write-Host "========================================================" -ForegroundColor Green
    Write-Host "  [OK] PC ONLY MODE ACTIVE" -ForegroundColor Green
    Write-Host "    Layout: [Primary 2560x1440] -> [Ultrawide 3440x1440]" -ForegroundColor Gray
    Write-Host "========================================================" -ForegroundColor Green
    Show-MonitorStatus
}

@{ mode = "pc-only" } | ConvertTo-Json | Set-Content "$PSScriptRoot\current-mode.json" -Force
exit 0
