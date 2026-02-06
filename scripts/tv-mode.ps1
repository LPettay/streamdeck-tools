# TV Mode - Primary (VG27A) + TV (Vizio) duplicated, Ultrawide disabled
# Clone Primary onto TV for couch gaming

param([switch]$Silent)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\MonitorConfig.ps1"

if (-not $Silent) {
    Write-Host ""
    Write-Host "========================================================" -ForegroundColor Yellow
    Write-Host "            SWITCHING TO TV MODE                        " -ForegroundColor Yellow
    Write-Host "       Primary + TV duplicated (Ultrawide off)          " -ForegroundColor Yellow
    Write-Host "========================================================" -ForegroundColor Yellow
    Write-Host ""
}

# Step 1: Disable Ultrawide FIRST (before applying clone)
if (-not $Silent) { Write-Host "Step 1: Disable Ultrawide" -ForegroundColor White }
Disable-Monitor -Pattern "LC34G55T"

# Step 2: Ensure Primary and TV are enabled
if (-not $Silent) { Write-Host "`nStep 2: Enable Primary and TV" -ForegroundColor White }
Enable-Monitor -Pattern "VG27A" -X 0 -Y 0
Enable-Monitor -Pattern "V4K43M" -X 0 -Y 0

# Step 3: Wait for displays to settle
if (-not $Silent) { Write-Host "`nStep 3: Waiting for displays..." -ForegroundColor White }
Start-Sleep -Seconds 2

# Step 4: Verify only 2 monitors active
$monitors = Get-MonitorStatus
$activeCount = $monitors.Count
if (-not $Silent) { Write-Host "  Active monitors: $activeCount" -ForegroundColor Cyan }

# Step 5: Apply clone topology
if (-not $Silent) { Write-Host "`nStep 4: Apply clone" -ForegroundColor White }
if ($activeCount -eq 2) {
    Apply-CloneTopology
} else {
    Write-Host "  [WARN] Expected 2 monitors, found $activeCount" -ForegroundColor Yellow
}

# Refresh desktop to fix wallpaper/taskbar
Start-Sleep -Seconds 1
Refresh-Desktop

# Final status
if (-not $Silent) {
    Write-Host ""
    Write-Host "========================================================" -ForegroundColor Yellow
    Write-Host "  [OK] TV MODE ACTIVE" -ForegroundColor Yellow
    Write-Host "    Clone: Primary <-> TV" -ForegroundColor Gray
    Write-Host "========================================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  TIP: Resolution will match the smaller display." -ForegroundColor DarkGray
    Show-MonitorStatus
}

@{ mode = "tv-mode" } | ConvertTo-Json | Set-Content "$PSScriptRoot\current-mode.json" -Force
exit 0
