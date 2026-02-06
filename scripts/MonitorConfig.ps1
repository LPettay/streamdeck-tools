# MonitorConfig.ps1 - Shared monitor configuration using Windows API
# NO MultiMonitorTool or displayswitch for positioning/topology

# Load the Windows Display Config API
. "$PSScriptRoot\DisplayConfigV2.ps1"

# Monitor name patterns for matching
$script:MonitorPatterns = @{
    Primary   = "VG27A"
    Ultrawide = "LC34G55T"
    TV        = "V4K43M"
}

function Get-MonitorStatus {
    <#
    .SYNOPSIS
    Gets current monitor status using Windows API
    #>
    return [DisplayConfigV2]::GetActiveMonitors()
}

function Show-MonitorStatus {
    <#
    .SYNOPSIS
    Displays current monitor status
    #>
    Write-Host ""
    Write-Host "+--------------------------------------------------+" -ForegroundColor Cyan
    Write-Host "|           CURRENT MONITOR STATUS                 |" -ForegroundColor Cyan
    Write-Host "+--------------------------------------------------+" -ForegroundColor Cyan
    
    $monitors = Get-MonitorStatus
    
    foreach ($mon in $monitors) {
        $friendlyName = switch -Wildcard ($mon.Name) {
            "*VG27A*"    { "Primary (VG27A)" }
            "*LC34G55T*" { "Ultrawide (Samsung)" }
            "*V4K43M*"   { "TV (Vizio)" }
            default      { $mon.Name }
        }
        
        $position = "@ ($($mon.X), $($mon.Y))"
        $size = "$($mon.Width)x$($mon.Height)"
        
        Write-Host "  [ON]  $friendlyName $position - $size" -ForegroundColor Green
    }
    
    # Check for missing monitors
    $activeNames = $monitors.Name -join " "
    if ($activeNames -notmatch "VG27A") {
        Write-Host "  [OFF] Primary (VG27A)" -ForegroundColor DarkGray
    }
    if ($activeNames -notmatch "LC34G55T") {
        Write-Host "  [OFF] Ultrawide (Samsung)" -ForegroundColor DarkGray
    }
    if ($activeNames -notmatch "V4K43M") {
        Write-Host "  [OFF] TV (Vizio)" -ForegroundColor DarkGray
    }
    
    Write-Host ""
}

function Test-MonitorActive {
    param([string]$Pattern)
    $monitors = Get-MonitorStatus
    return ($monitors | Where-Object { $_.Name -like "*$Pattern*" }).Count -gt 0
}

function Enable-Monitor {
    param(
        [Parameter(Mandatory)]
        [ValidateSet("VG27A", "LC34G55T", "V4K43M")]
        [string]$Pattern,
        
        [int]$X = 0,
        [int]$Y = 0
    )
    
    if (Test-MonitorActive -Pattern $Pattern) {
        Write-Host "  [OK] $Pattern already active" -ForegroundColor DarkGray
        return $true
    }
    
    Write-Host "  --> Enabling $Pattern..." -ForegroundColor Yellow
    
    # Use old DisplayConfig API which works better, with retries for slow monitors
    . "$PSScriptRoot\DisplayConfig.ps1" 2>$null
    
    $maxRetries = 3
    $retryDelay = 3  # seconds between retries
    
    for ($attempt = 1; $attempt -le $maxRetries; $attempt++) {
        $result = [DisplayConfig]::EnableMonitorByName($Pattern)
        
        if ($result -eq -2) {
            # Already active
            Write-Host "  [OK] $Pattern enabled" -ForegroundColor Green
            return $true
        }
        
        # Wait for slow monitors to wake up
        Start-Sleep -Seconds $retryDelay
        
        # Check if actually active now
        if (Test-MonitorActive -Pattern $Pattern) {
            Write-Host "  [OK] $Pattern enabled (attempt $attempt)" -ForegroundColor Green
            return $true
        }
        
        if ($attempt -lt $maxRetries) {
            Write-Host "  [RETRY] Waiting for $Pattern to wake up..." -ForegroundColor Yellow
        }
    }
    
    Write-Host "  [FAIL] Could not enable $Pattern after $maxRetries attempts" -ForegroundColor Red
    return $false
}

function Disable-Monitor {
    param(
        [Parameter(Mandatory)]
        [ValidateSet("VG27A", "LC34G55T", "V4K43M")]
        [string]$Pattern
    )
    
    if (-not (Test-MonitorActive -Pattern $Pattern)) {
        Write-Host "  [OK] $Pattern already disabled" -ForegroundColor DarkGray
        return $true
    }
    
    Write-Host "  --> Disabling $Pattern..." -ForegroundColor Yellow
    $result = [DisplayConfigV2]::DisableMonitor($Pattern)
    Start-Sleep -Seconds 1
    
    if ($result -eq 0) {
        Write-Host "  [OK] $Pattern disabled" -ForegroundColor Green
        return $true
    } else {
        Write-Host "  [FAIL] Disable returned $result" -ForegroundColor Red
        return $false
    }
}

function Set-MonitorPositions {
    param(
        [hashtable]$Primary,   # @{ X=0; Y=0 }
        [hashtable]$Ultrawide, # @{ X=2560; Y=0 }
        [hashtable]$TV         # @{ X=-3840; Y=0 }
    )
    
    $patterns = @()
    $xPos = @()
    $yPos = @()
    
    if ($Primary) {
        $patterns += "VG27A"
        $xPos += $Primary.X
        $yPos += $Primary.Y
    }
    if ($Ultrawide) {
        $patterns += "LC34G55T"
        $xPos += $Ultrawide.X
        $yPos += $Ultrawide.Y
    }
    if ($TV) {
        $patterns += "V4K43M"
        $xPos += $TV.X
        $yPos += $TV.Y
    }
    
    if ($patterns.Count -eq 0) { return }
    
    Write-Host "  --> Setting positions..." -ForegroundColor Yellow
    $result = [DisplayConfigV2]::SetAllPositions($patterns, $xPos, $yPos)
    
    if ($result -eq 0) {
        Write-Host "  [OK] Positions set" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] SetAllPositions returned $result" -ForegroundColor Yellow
    }
    
    Start-Sleep -Milliseconds 500
}

function Apply-CloneTopology {
    <#
    .SYNOPSIS
    Clones currently active displays by sharing source ID
    #>
    Write-Host "  --> Cloning active displays..." -ForegroundColor Yellow
    $result = [DisplayConfigV2]::CloneActiveDisplays()
    Start-Sleep -Seconds 1
    
    if ($result -eq 0) {
        Write-Host "  [OK] Clone applied" -ForegroundColor Green
        return $true
    } else {
        Write-Host "  [WARN] Clone returned $result" -ForegroundColor Yellow
        return $false
    }
}

function Apply-ExtendTopology {
    <#
    .SYNOPSIS
    Applies extend topology via Windows API (extends all active displays)
    #>
    Write-Host "  --> Applying extend topology..." -ForegroundColor Yellow
    $result = [DisplayConfigV2]::ApplyExtend()
    Start-Sleep -Seconds 1
    
    if ($result -eq 0) {
        Write-Host "  [OK] Extend applied" -ForegroundColor Green
        return $true
    } else {
        Write-Host "  [WARN] Extend returned $result" -ForegroundColor Yellow
        return $false
    }
}

function Refresh-Desktop {
    <#
    .SYNOPSIS
    Refreshes the desktop to fix wallpaper/taskbar issues after display changes
    #>
    
    # Method 1: Update desktop wallpaper (forces refresh)
    Add-Type -TypeDefinition @"
    using System;
    using System.Runtime.InteropServices;
    public class DesktopRefresh {
        [DllImport("user32.dll", CharSet = CharSet.Auto)]
        public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
        
        public const int SPI_SETDESKWALLPAPER = 0x0014;
        public const int SPIF_UPDATEINIFILE = 0x01;
        public const int SPIF_SENDCHANGE = 0x02;
        
        public static void Refresh() {
            // Get current wallpaper path
            string wallpaper = Microsoft.Win32.Registry.GetValue(
                @"HKEY_CURRENT_USER\Control Panel\Desktop", "Wallpaper", "") as string;
            
            // Re-apply it (forces desktop refresh)
            if (!string.IsNullOrEmpty(wallpaper)) {
                SystemParametersInfo(SPI_SETDESKWALLPAPER, 0, wallpaper, SPIF_UPDATEINIFILE | SPIF_SENDCHANGE);
            }
        }
    }
"@ -ErrorAction SilentlyContinue

    try {
        [DesktopRefresh]::Refresh()
        Write-Host "  [OK] Desktop refreshed" -ForegroundColor DarkGray
    } catch {
        # Fallback: just toggle taskbar
    }
}

Write-Host "MonitorConfig loaded." -ForegroundColor DarkGray
