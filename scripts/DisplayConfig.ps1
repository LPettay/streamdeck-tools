# Windows Display Configuration API Wrapper
# Uses SetDisplayConfig to enable/disable specific monitors

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Collections.Generic;

public class DisplayConfig
{
    // Constants
    public const uint QDC_ALL_PATHS = 0x00000001;
    public const uint QDC_ONLY_ACTIVE_PATHS = 0x00000002;
    public const uint QDC_DATABASE_CURRENT = 0x00000004;
    public const uint SDC_APPLY = 0x00000080;
    public const uint SDC_TOPOLOGY_CLONE = 0x00000002;
    public const uint SDC_TOPOLOGY_EXTEND = 0x00000004;
    public const uint SDC_TOPOLOGY_INTERNAL = 0x00000001;
    public const uint SDC_TOPOLOGY_EXTERNAL = 0x00000008;
    public const uint SDC_TOPOLOGY_SUPPLIED = 0x00000010;
    public const uint SDC_USE_SUPPLIED_DISPLAY_CONFIG = 0x00000020;
    public const uint SDC_SAVE_TO_DATABASE = 0x00000200;
    public const uint SDC_ALLOW_CHANGES = 0x00000400;
    public const uint SDC_PATH_PERSIST_IF_REQUIRED = 0x00000800;

    public const uint DISPLAYCONFIG_PATH_ACTIVE = 0x00000001;
    
    public const uint DISPLAYCONFIG_DEVICE_INFO_GET_TARGET_NAME = 2;
    public const uint DISPLAYCONFIG_DEVICE_INFO_GET_SOURCE_NAME = 1;

    [Serializable]
    [StructLayout(LayoutKind.Sequential)]
    public struct LUID
    {
        public uint LowPart;
        public int HighPart;
    }

    [Serializable]
    [StructLayout(LayoutKind.Sequential)]
    public struct DISPLAYCONFIG_PATH_SOURCE_INFO
    {
        public LUID adapterId;
        public uint id;
        public uint modeInfoIdx;
        public uint statusFlags;
    }

    [Serializable]
    [StructLayout(LayoutKind.Sequential)]
    public struct DISPLAYCONFIG_PATH_TARGET_INFO
    {
        public LUID adapterId;
        public uint id;
        public uint modeInfoIdx;
        public uint outputTechnology;
        public uint rotation;
        public uint scaling;
        public DISPLAYCONFIG_RATIONAL refreshRate;
        public uint scanLineOrdering;
        public bool targetAvailable;
        public uint statusFlags;
    }

    [Serializable]
    [StructLayout(LayoutKind.Sequential)]
    public struct DISPLAYCONFIG_RATIONAL
    {
        public uint Numerator;
        public uint Denominator;
    }

    [Serializable]
    [StructLayout(LayoutKind.Sequential)]
    public struct DISPLAYCONFIG_PATH_INFO
    {
        public DISPLAYCONFIG_PATH_SOURCE_INFO sourceInfo;
        public DISPLAYCONFIG_PATH_TARGET_INFO targetInfo;
        public uint flags;
    }

    [Serializable]
    [StructLayout(LayoutKind.Sequential)]
    public struct DISPLAYCONFIG_MODE_INFO
    {
        public uint infoType;
        public uint id;
        public LUID adapterId;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 64)]
        public byte[] modeData;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct DISPLAYCONFIG_TARGET_DEVICE_NAME
    {
        public DISPLAYCONFIG_DEVICE_INFO_HEADER header;
        public uint flags;
        public uint outputTechnology;
        public ushort edidManufactureId;
        public ushort edidProductCodeId;
        public uint connectorInstance;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 64)]
        public string monitorFriendlyDeviceName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
        public string monitorDevicePath;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct DISPLAYCONFIG_SOURCE_DEVICE_NAME
    {
        public DISPLAYCONFIG_DEVICE_INFO_HEADER header;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string viewGdiDeviceName;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct DISPLAYCONFIG_DEVICE_INFO_HEADER
    {
        public uint type;
        public uint size;
        public LUID adapterId;
        public uint id;
    }

    [DllImport("user32.dll")]
    public static extern int GetDisplayConfigBufferSizes(uint flags, out uint numPathArrayElements, out uint numModeInfoArrayElements);

    [DllImport("user32.dll")]
    public static extern int QueryDisplayConfig(uint flags, ref uint numPathArrayElements, [Out] DISPLAYCONFIG_PATH_INFO[] pathArray,
        ref uint numModeInfoArrayElements, [Out] DISPLAYCONFIG_MODE_INFO[] modeInfoArray, IntPtr currentTopologyId);

    [DllImport("user32.dll")]
    public static extern int SetDisplayConfig(uint numPathArrayElements, DISPLAYCONFIG_PATH_INFO[] pathArray,
        uint numModeInfoArrayElements, DISPLAYCONFIG_MODE_INFO[] modeInfoArray, uint flags);

    [DllImport("user32.dll")]
    public static extern int DisplayConfigGetDeviceInfo(ref DISPLAYCONFIG_TARGET_DEVICE_NAME deviceName);

    [DllImport("user32.dll")]
    public static extern int DisplayConfigGetDeviceInfo(ref DISPLAYCONFIG_SOURCE_DEVICE_NAME deviceName);

    public static List<DisplayInfo> GetDisplays()
    {
        var displays = new List<DisplayInfo>();
        uint pathCount, modeCount;
        
        int result = GetDisplayConfigBufferSizes(QDC_ALL_PATHS, out pathCount, out modeCount);
        if (result != 0) return displays;

        var paths = new DISPLAYCONFIG_PATH_INFO[pathCount];
        var modes = new DISPLAYCONFIG_MODE_INFO[modeCount];

        result = QueryDisplayConfig(QDC_ALL_PATHS, ref pathCount, paths, ref modeCount, modes, IntPtr.Zero);
        if (result != 0) return displays;

        for (int i = 0; i < pathCount; i++)
        {
            var path = paths[i];
            
            // Get target (monitor) name
            var targetName = new DISPLAYCONFIG_TARGET_DEVICE_NAME();
            targetName.header.type = DISPLAYCONFIG_DEVICE_INFO_GET_TARGET_NAME;
            targetName.header.size = (uint)Marshal.SizeOf(typeof(DISPLAYCONFIG_TARGET_DEVICE_NAME));
            targetName.header.adapterId = path.targetInfo.adapterId;
            targetName.header.id = path.targetInfo.id;
            DisplayConfigGetDeviceInfo(ref targetName);

            // Get source (display) name
            var sourceName = new DISPLAYCONFIG_SOURCE_DEVICE_NAME();
            sourceName.header.type = DISPLAYCONFIG_DEVICE_INFO_GET_SOURCE_NAME;
            sourceName.header.size = (uint)Marshal.SizeOf(typeof(DISPLAYCONFIG_SOURCE_DEVICE_NAME));
            sourceName.header.adapterId = path.sourceInfo.adapterId;
            sourceName.header.id = path.sourceInfo.id;
            DisplayConfigGetDeviceInfo(ref sourceName);

            bool isActive = (path.flags & DISPLAYCONFIG_PATH_ACTIVE) != 0;
            
            var info = new DisplayInfo
            {
                PathIndex = i,
                SourceId = path.sourceInfo.id,
                TargetId = path.targetInfo.id,
                DisplayName = sourceName.viewGdiDeviceName,
                MonitorName = targetName.monitorFriendlyDeviceName,
                IsActive = isActive,
                TargetAvailable = path.targetInfo.targetAvailable
            };
            
            displays.Add(info);
        }

        return displays;
    }

    public static int SetDisplaysActive(uint[] activeSourceIds)
    {
        uint pathCount, modeCount;
        
        // Get only currently active paths first
        int result = GetDisplayConfigBufferSizes(QDC_ONLY_ACTIVE_PATHS, out pathCount, out modeCount);
        if (result != 0) return result;

        var activePaths = new DISPLAYCONFIG_PATH_INFO[pathCount];
        var activeModes = new DISPLAYCONFIG_MODE_INFO[modeCount];

        result = QueryDisplayConfig(QDC_ONLY_ACTIVE_PATHS, ref pathCount, activePaths, ref modeCount, activeModes, IntPtr.Zero);
        if (result != 0) return result;

        // Build new path array with only the displays we want
        var newPaths = new List<DISPLAYCONFIG_PATH_INFO>();
        var usedModeIndices = new HashSet<uint>();
        
        for (int i = 0; i < pathCount; i++)
        {
            bool shouldBeActive = Array.Exists(activeSourceIds, id => id == activePaths[i].sourceInfo.id);
            if (shouldBeActive)
            {
                newPaths.Add(activePaths[i]);
                usedModeIndices.Add(activePaths[i].sourceInfo.modeInfoIdx);
                usedModeIndices.Add(activePaths[i].targetInfo.modeInfoIdx);
            }
        }

        if (newPaths.Count == 0)
        {
            return -1; // Can't disable all displays
        }

        // Apply with only the active paths
        result = SetDisplayConfig((uint)newPaths.Count, newPaths.ToArray(), modeCount, activeModes,
            SDC_APPLY | SDC_USE_SUPPLIED_DISPLAY_CONFIG | SDC_ALLOW_CHANGES | SDC_SAVE_TO_DATABASE);

        return result;
    }
    
    public static int DisableDisplay(uint sourceIdToDisable)
    {
        uint pathCount, modeCount;
        
        int result = GetDisplayConfigBufferSizes(QDC_ONLY_ACTIVE_PATHS, out pathCount, out modeCount);
        if (result != 0) return result;

        var paths = new DISPLAYCONFIG_PATH_INFO[pathCount];
        var modes = new DISPLAYCONFIG_MODE_INFO[modeCount];

        result = QueryDisplayConfig(QDC_ONLY_ACTIVE_PATHS, ref pathCount, paths, ref modeCount, modes, IntPtr.Zero);
        if (result != 0) return result;

        // Remove the path for the display we want to disable
        var newPaths = new List<DISPLAYCONFIG_PATH_INFO>();
        for (int i = 0; i < pathCount; i++)
        {
            if (paths[i].sourceInfo.id != sourceIdToDisable)
            {
                newPaths.Add(paths[i]);
            }
        }

        if (newPaths.Count == 0)
        {
            return -1; // Can't disable the last display
        }

        result = SetDisplayConfig((uint)newPaths.Count, newPaths.ToArray(), modeCount, modes,
            SDC_APPLY | SDC_USE_SUPPLIED_DISPLAY_CONFIG | SDC_ALLOW_CHANGES | SDC_SAVE_TO_DATABASE);

        return result;
    }

    public static int ApplyTopology(uint topology)
    {
        return SetDisplayConfig(0, null, 0, null, SDC_APPLY | topology);
    }
    
    // Store configs in memory for the session - file-based approach will use raw bytes
    private static Dictionary<string, Tuple<DISPLAYCONFIG_PATH_INFO[], DISPLAYCONFIG_MODE_INFO[], uint, uint>> savedConfigs 
        = new Dictionary<string, Tuple<DISPLAYCONFIG_PATH_INFO[], DISPLAYCONFIG_MODE_INFO[], uint, uint>>();
    
    public static bool SaveConfigToMemory(string name)
    {
        uint pathCount, modeCount;
        
        int result = GetDisplayConfigBufferSizes(QDC_ONLY_ACTIVE_PATHS, out pathCount, out modeCount);
        if (result != 0) return false;

        var paths = new DISPLAYCONFIG_PATH_INFO[pathCount];
        var modes = new DISPLAYCONFIG_MODE_INFO[modeCount];

        result = QueryDisplayConfig(QDC_ONLY_ACTIVE_PATHS, ref pathCount, paths, ref modeCount, modes, IntPtr.Zero);
        if (result != 0) return false;

        savedConfigs[name] = Tuple.Create(paths, modes, pathCount, modeCount);
        return true;
    }
    
    public static int RestoreConfigFromMemory(string name)
    {
        if (!savedConfigs.ContainsKey(name)) return -404;
        
        var config = savedConfigs[name];
        return SetDisplayConfig(config.Item3, config.Item1, config.Item4, config.Item2,
            SDC_APPLY | SDC_USE_SUPPLIED_DISPLAY_CONFIG | SDC_ALLOW_CHANGES | SDC_SAVE_TO_DATABASE);
    }
    
    public static string[] GetSavedConfigNames()
    {
        var names = new string[savedConfigs.Count];
        savedConfigs.Keys.CopyTo(names, 0);
        return names;
    }
    
    public static bool HasConfig(string name)
    {
        return savedConfigs.ContainsKey(name);
    }
    
    // Try to restore from Windows' internal database (last known config with all monitors)
    public static int RestoreFromDatabase()
    {
        uint pathCount, modeCount;
        
        int result = GetDisplayConfigBufferSizes(QDC_DATABASE_CURRENT, out pathCount, out modeCount);
        if (result != 0) return result;

        var paths = new DISPLAYCONFIG_PATH_INFO[pathCount];
        var modes = new DISPLAYCONFIG_MODE_INFO[modeCount];

        result = QueryDisplayConfig(QDC_DATABASE_CURRENT, ref pathCount, paths, ref modeCount, modes, IntPtr.Zero);
        if (result != 0) return result;

        // Apply the database configuration
        return SetDisplayConfig(pathCount, paths, modeCount, modes,
            SDC_APPLY | SDC_USE_SUPPLIED_DISPLAY_CONFIG | SDC_ALLOW_CHANGES | SDC_SAVE_TO_DATABASE);
    }
    
    // Try to force extend mode with all available displays
    public static int ForceExtendAll()
    {
        uint pathCount, modeCount;
        
        // Query ALL paths (including inactive but available)
        int result = GetDisplayConfigBufferSizes(QDC_ALL_PATHS, out pathCount, out modeCount);
        if (result != 0) return result;

        var allPaths = new DISPLAYCONFIG_PATH_INFO[pathCount];
        var allModes = new DISPLAYCONFIG_MODE_INFO[modeCount];

        result = QueryDisplayConfig(QDC_ALL_PATHS, ref pathCount, allPaths, ref modeCount, allModes, IntPtr.Zero);
        if (result != 0) return result;

        // Find unique available targets and mark one path per target as active
        var seenTargets = new HashSet<uint>();
        var pathsToActivate = new List<DISPLAYCONFIG_PATH_INFO>();
        
        for (int i = 0; i < pathCount; i++)
        {
            if (allPaths[i].targetInfo.targetAvailable && !seenTargets.Contains(allPaths[i].targetInfo.id))
            {
                seenTargets.Add(allPaths[i].targetInfo.id);
                var p = allPaths[i];
                p.flags |= DISPLAYCONFIG_PATH_ACTIVE;
                pathsToActivate.Add(p);
            }
        }

        // Apply with SDC_ALLOW_PATH_ORDER_CHANGES to let Windows figure out the layout
        result = SetDisplayConfig((uint)pathsToActivate.Count, pathsToActivate.ToArray(), modeCount, allModes,
            SDC_APPLY | SDC_TOPOLOGY_SUPPLIED | SDC_ALLOW_CHANGES | SDC_ALLOW_PATH_ORDER_CHANGES);

        return result;
    }
    
    public const uint SDC_ALLOW_PATH_ORDER_CHANGES = 0x00001000;
    
    // Enable a specific monitor by adding it to the current active config
    public static int EnableMonitorByName(string monitorName)
    {
        // Get current active config
        uint activePathCount, activeModeCount;
        int result = GetDisplayConfigBufferSizes(QDC_ONLY_ACTIVE_PATHS, out activePathCount, out activeModeCount);
        if (result != 0) return result;

        var activePaths = new DISPLAYCONFIG_PATH_INFO[activePathCount];
        var activeModes = new DISPLAYCONFIG_MODE_INFO[activeModeCount];
        result = QueryDisplayConfig(QDC_ONLY_ACTIVE_PATHS, ref activePathCount, activePaths, ref activeModeCount, activeModes, IntPtr.Zero);
        if (result != 0) return result;

        // Get all paths to find the target monitor
        uint allPathCount, allModeCount;
        result = GetDisplayConfigBufferSizes(QDC_ALL_PATHS, out allPathCount, out allModeCount);
        if (result != 0) return result;

        var allPaths = new DISPLAYCONFIG_PATH_INFO[allPathCount];
        var allModes = new DISPLAYCONFIG_MODE_INFO[allModeCount];
        result = QueryDisplayConfig(QDC_ALL_PATHS, ref allPathCount, allPaths, ref allModeCount, allModes, IntPtr.Zero);
        if (result != 0) return result;

        // Find the target monitor path
        DISPLAYCONFIG_PATH_INFO? targetPath = null;
        for (int i = 0; i < allPathCount; i++)
        {
            if (!allPaths[i].targetInfo.targetAvailable) continue;
            
            var targetName = new DISPLAYCONFIG_TARGET_DEVICE_NAME();
            targetName.header.type = DISPLAYCONFIG_DEVICE_INFO_GET_TARGET_NAME;
            targetName.header.size = (uint)Marshal.SizeOf(typeof(DISPLAYCONFIG_TARGET_DEVICE_NAME));
            targetName.header.adapterId = allPaths[i].targetInfo.adapterId;
            targetName.header.id = allPaths[i].targetInfo.id;
            DisplayConfigGetDeviceInfo(ref targetName);
            
            if (targetName.monitorFriendlyDeviceName != null && 
                targetName.monitorFriendlyDeviceName.Contains(monitorName))
            {
                // Check if not already active
                bool alreadyActive = false;
                for (int j = 0; j < activePathCount; j++)
                {
                    if (activePaths[j].targetInfo.id == allPaths[i].targetInfo.id)
                    {
                        alreadyActive = true;
                        break;
                    }
                }
                
                if (!alreadyActive)
                {
                    // Find an unused source ID for extend mode
                    var usedSourceIds = new HashSet<uint>();
                    for (int j = 0; j < activePathCount; j++)
                    {
                        usedSourceIds.Add(activePaths[j].sourceInfo.id);
                    }
                    
                    // Store the target ID we want
                    uint targetIdToEnable = allPaths[i].targetInfo.id;
                    
                    // Look for a path with this specific target ID and an unused source ID
                    for (int k = 0; k < allPathCount; k++)
                    {
                        if (allPaths[k].targetInfo.id == targetIdToEnable &&
                            allPaths[k].targetInfo.targetAvailable &&
                            !usedSourceIds.Contains(allPaths[k].sourceInfo.id))
                        {
                            var p = allPaths[k];
                            p.flags = DISPLAYCONFIG_PATH_ACTIVE;
                            targetPath = p;
                            break;
                        }
                    }
                    
                    // Fallback to original if no unused source found
                    if (!targetPath.HasValue)
                    {
                        var p = allPaths[i];
                        p.flags = DISPLAYCONFIG_PATH_ACTIVE;
                        targetPath = p;
                    }
                    
                    // Found what we need, exit the outer loop
                    break;
                }
            }
        }

        if (!targetPath.HasValue)
        {
            return -2; // Not found or already active
        }

        // Create new path array with the added monitor
        var newPaths = new List<DISPLAYCONFIG_PATH_INFO>(activePaths);
        newPaths.Add(targetPath.Value);

        // Combine all modes  
        var allModesList = new List<DISPLAYCONFIG_MODE_INFO>(activeModes);
        for (int i = 0; i < allModeCount; i++)
        {
            bool exists = false;
            for (int j = 0; j < activeModeCount; j++)
            {
                if (allModes[i].id == activeModes[j].id && 
                    allModes[i].adapterId.LowPart == activeModes[j].adapterId.LowPart)
                {
                    exists = true;
                    break;
                }
            }
            if (!exists)
            {
                allModesList.Add(allModes[i]);
            }
        }

        // Try to apply with various flag combinations
        var flagCombos = new uint[] {
            SDC_APPLY | SDC_USE_SUPPLIED_DISPLAY_CONFIG | SDC_ALLOW_CHANGES | SDC_ALLOW_PATH_ORDER_CHANGES,
            SDC_APPLY | SDC_TOPOLOGY_EXTEND | SDC_ALLOW_CHANGES,
            SDC_APPLY | SDC_USE_SUPPLIED_DISPLAY_CONFIG | SDC_ALLOW_CHANGES
        };

        foreach (var flags in flagCombos)
        {
            result = SetDisplayConfig((uint)newPaths.Count, newPaths.ToArray(), 
                (uint)allModesList.Count, allModesList.ToArray(), flags);
            if (result == 0) return 0;
        }

        return result;
    }
    
    public static int EnableDisplay(uint sourceIdToEnable)
    {
        uint pathCount, modeCount;
        
        // Get ALL paths (including inactive)
        int result = GetDisplayConfigBufferSizes(QDC_ALL_PATHS, out pathCount, out modeCount);
        if (result != 0) return result;

        var allPaths = new DISPLAYCONFIG_PATH_INFO[pathCount];
        var allModes = new DISPLAYCONFIG_MODE_INFO[modeCount];

        result = QueryDisplayConfig(QDC_ALL_PATHS, ref pathCount, allPaths, ref modeCount, allModes, IntPtr.Zero);
        if (result != 0) return result;

        // Get currently active paths
        uint activePathCount, activeModeCount;
        result = GetDisplayConfigBufferSizes(QDC_ONLY_ACTIVE_PATHS, out activePathCount, out activeModeCount);
        if (result != 0) return result;

        var activePaths = new DISPLAYCONFIG_PATH_INFO[activePathCount];
        var activeModes = new DISPLAYCONFIG_MODE_INFO[activeModeCount];

        result = QueryDisplayConfig(QDC_ONLY_ACTIVE_PATHS, ref activePathCount, activePaths, ref activeModeCount, activeModes, IntPtr.Zero);
        if (result != 0) return result;

        // Find the path to enable from all paths
        DISPLAYCONFIG_PATH_INFO? pathToAdd = null;
        for (int i = 0; i < pathCount; i++)
        {
            if (allPaths[i].sourceInfo.id == sourceIdToEnable && allPaths[i].targetInfo.targetAvailable)
            {
                var p = allPaths[i];
                p.flags |= DISPLAYCONFIG_PATH_ACTIVE;
                pathToAdd = p;
                break;
            }
        }

        if (!pathToAdd.HasValue)
        {
            return -2; // Display not found
        }

        // Combine active paths with the new one
        var newPaths = new List<DISPLAYCONFIG_PATH_INFO>();
        for (int i = 0; i < activePathCount; i++)
        {
            newPaths.Add(activePaths[i]);
        }
        newPaths.Add(pathToAdd.Value);

        // Use combined modes array
        result = SetDisplayConfig((uint)newPaths.Count, newPaths.ToArray(), activeModeCount, activeModes,
            SDC_APPLY | SDC_USE_SUPPLIED_DISPLAY_CONFIG | SDC_ALLOW_CHANGES | SDC_SAVE_TO_DATABASE);

        return result;
    }
}

public class DisplayInfo
{
    public int PathIndex { get; set; }
    public uint SourceId { get; set; }
    public uint TargetId { get; set; }
    public string DisplayName { get; set; }
    public string MonitorName { get; set; }
    public bool IsActive { get; set; }
    public bool TargetAvailable { get; set; }
    
    public override string ToString()
    {
        return string.Format("{0} | {1} | Active: {2} | Available: {3}", 
            DisplayName, MonitorName, IsActive, TargetAvailable);
    }
}
"@

function Get-Displays {
    [DisplayConfig]::GetDisplays() | Where-Object { $_.TargetAvailable -or $_.IsActive }
}

function Show-Displays {
    Write-Host "`n=== AVAILABLE DISPLAYS ===" -ForegroundColor Cyan
    $displays = Get-Displays
    $grouped = $displays | Group-Object DisplayName
    
    foreach ($group in $grouped) {
        $active = $group.Group | Where-Object { $_.IsActive } | Select-Object -First 1
        $available = $group.Group | Where-Object { $_.TargetAvailable } | Select-Object -First 1
        $display = if ($active) { $active } else { $available }
        
        $status = if ($display.IsActive) { "[ON] " } else { "[OFF]" }
        $color = if ($display.IsActive) { "Green" } else { "DarkGray" }
        
        Write-Host "$status $($display.DisplayName) - $($display.MonitorName)" -ForegroundColor $color
    }
    Write-Host ""
}

function Set-DisplaysActive {
    param(
        [string[]]$DisplayNames  # e.g., "\\.\DISPLAY1", "\\.\DISPLAY2"
    )
    
    $displays = Get-Displays
    $sourceIds = @()
    
    foreach ($name in $DisplayNames) {
        $match = $displays | Where-Object { $_.DisplayName -like "*$name*" } | Select-Object -First 1
        if ($match) {
            $sourceIds += $match.SourceId
        }
    }
    
    $result = [DisplayConfig]::SetDisplaysActive([uint32[]]$sourceIds)
    
    if ($result -eq 0) {
        Write-Host "Display configuration applied successfully!" -ForegroundColor Green
    } else {
        Write-Host "Failed to apply configuration. Error code: $result" -ForegroundColor Red
    }
    
    return $result
}

function Enable-Display {
    param(
        [string]$MonitorName  # e.g., "VG27A" or "V4K43M"
    )
    
    # Get all paths (including inactive)
    $allDisplays = [DisplayConfig]::GetDisplays()
    $match = $allDisplays | Where-Object { $_.MonitorName -like "*$MonitorName*" -and -not $_.IsActive -and $_.TargetAvailable } | Select-Object -First 1
    
    if (-not $match) {
        Write-Host "Display $MonitorName not found or already active." -ForegroundColor Yellow
        # Maybe already active?
        $activeMatch = $allDisplays | Where-Object { $_.MonitorName -like "*$MonitorName*" -and $_.IsActive } | Select-Object -First 1
        if ($activeMatch) {
            Write-Host "$MonitorName is already active." -ForegroundColor Green
            return 0
        }
        return -1
    }
    
    Write-Host "Enabling $($match.DisplayName) ($($match.MonitorName))..." -ForegroundColor Yellow
    $result = [DisplayConfig]::EnableDisplay($match.SourceId)
    
    if ($result -eq 0) {
        Write-Host "Display enabled!" -ForegroundColor Green
    } else {
        Write-Host "Failed. Error code: $result" -ForegroundColor Red
    }
    
    return $result
}

function Enable-AllDisplays {
    Write-Host "Enabling all displays (extend mode)..." -ForegroundColor Yellow
    $result = [DisplayConfig]::ApplyTopology([DisplayConfig]::SDC_TOPOLOGY_EXTEND)
    
    if ($result -eq 0) {
        Write-Host "All displays enabled!" -ForegroundColor Green
    } else {
        Write-Host "Failed. Error code: $result" -ForegroundColor Red
    }
    
    return $result
}

function Disable-Display {
    param(
        [string]$DisplayName  # e.g., "DISPLAY2", "\\.\DISPLAY2", or monitor name like "VG27A"
    )
    
    $displays = Get-Displays
    
    # Try matching by display name first, then by monitor name
    $match = $displays | Where-Object { $_.DisplayName -like "*$DisplayName*" -and $_.IsActive } | Select-Object -First 1
    
    if (-not $match) {
        $match = $displays | Where-Object { $_.MonitorName -like "*$DisplayName*" -and $_.IsActive } | Select-Object -First 1
    }
    
    if (-not $match) {
        Write-Host "Display $DisplayName not found or not active." -ForegroundColor Yellow
        return -1
    }
    
    Write-Host "Disabling $($match.DisplayName) ($($match.MonitorName))..." -ForegroundColor Yellow
    $result = [DisplayConfig]::DisableDisplay($match.SourceId)
    
    if ($result -eq 0) {
        Write-Host "Display disabled successfully!" -ForegroundColor Green
    } else {
        Write-Host "Failed to disable. Error code: $result" -ForegroundColor Red
    }
    
    return $result
}

function Save-DisplayConfig {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name  # e.g., "extend-all", "pc-only", "tv-only"
    )
    
    $result = [DisplayConfig]::SaveConfigToMemory($Name)
    if ($result) {
        Write-Host "Saved display config: $Name" -ForegroundColor Green
        Show-Displays
        return $true
    } else {
        Write-Host "Failed to save config" -ForegroundColor Red
        return $false
    }
}

function Restore-DisplayConfig {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name
    )
    
    if (-not [DisplayConfig]::HasConfig($Name)) {
        Write-Host "Config not found: $Name" -ForegroundColor Red
        Write-Host "Available configs: $([DisplayConfig]::GetSavedConfigNames() -join ', ')" -ForegroundColor Yellow
        return $false
    }
    
    $result = [DisplayConfig]::RestoreConfigFromMemory($Name)
    
    if ($result -eq 0) {
        Write-Host "Restored display config: $Name" -ForegroundColor Green
        return $true
    } else {
        Write-Host "Failed to restore config. Error: $result" -ForegroundColor Red
        return $false
    }
}

function Get-SavedConfigs {
    [DisplayConfig]::GetSavedConfigNames()
}

Write-Host "DisplayConfig module loaded." -ForegroundColor Green

