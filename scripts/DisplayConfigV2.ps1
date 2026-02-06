# Windows Display Configuration API Wrapper V2
# Full control: enable, disable, position, clone, extend

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Collections.Generic;
using System.Linq;

public class DisplayConfigV2
{
    // Query flags
    public const uint QDC_ALL_PATHS = 0x00000001;
    public const uint QDC_ONLY_ACTIVE_PATHS = 0x00000002;
    public const uint QDC_DATABASE_CURRENT = 0x00000004;
    
    // Set flags
    public const uint SDC_APPLY = 0x00000080;
    public const uint SDC_TOPOLOGY_CLONE = 0x00000002;
    public const uint SDC_TOPOLOGY_EXTEND = 0x00000004;
    public const uint SDC_USE_SUPPLIED_DISPLAY_CONFIG = 0x00000020;
    public const uint SDC_SAVE_TO_DATABASE = 0x00000200;
    public const uint SDC_ALLOW_CHANGES = 0x00000400;
    public const uint SDC_ALLOW_PATH_ORDER_CHANGES = 0x00001000;
    
    public const uint DISPLAYCONFIG_PATH_ACTIVE = 0x00000001;
    
    // Mode info types
    public const uint DISPLAYCONFIG_MODE_INFO_TYPE_SOURCE = 1;
    public const uint DISPLAYCONFIG_MODE_INFO_TYPE_TARGET = 2;
    
    public const uint DISPLAYCONFIG_DEVICE_INFO_GET_TARGET_NAME = 2;

    [StructLayout(LayoutKind.Sequential)]
    public struct LUID
    {
        public uint LowPart;
        public int HighPart;
        
        public bool Equals(LUID other)
        {
            return LowPart == other.LowPart && HighPart == other.HighPart;
        }
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct POINTL
    {
        public int x;
        public int y;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct DISPLAYCONFIG_RATIONAL
    {
        public uint Numerator;
        public uint Denominator;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct DISPLAYCONFIG_PATH_SOURCE_INFO
    {
        public LUID adapterId;
        public uint id;
        public uint modeInfoIdx;
        public uint statusFlags;
    }

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

    [StructLayout(LayoutKind.Sequential)]
    public struct DISPLAYCONFIG_PATH_INFO
    {
        public DISPLAYCONFIG_PATH_SOURCE_INFO sourceInfo;
        public DISPLAYCONFIG_PATH_TARGET_INFO targetInfo;
        public uint flags;
    }

    // Use raw bytes for mode info to handle the union correctly
    [StructLayout(LayoutKind.Sequential)]
    public struct DISPLAYCONFIG_MODE_INFO_RAW
    {
        public uint infoType;
        public uint id;
        public LUID adapterId;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 48)]
        public byte[] modeData;  // Union: targetMode, sourceMode, or desktopImageInfo
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
    public static extern int QueryDisplayConfig(uint flags, ref uint numPathArrayElements, 
        [In, Out] DISPLAYCONFIG_PATH_INFO[] pathArray,
        ref uint numModeInfoArrayElements, [In, Out] DISPLAYCONFIG_MODE_INFO_RAW[] modeInfoArray, 
        IntPtr currentTopologyId);

    [DllImport("user32.dll")]
    public static extern int SetDisplayConfig(uint numPathArrayElements, 
        [In] DISPLAYCONFIG_PATH_INFO[] pathArray,
        uint numModeInfoArrayElements, [In] DISPLAYCONFIG_MODE_INFO_RAW[] modeInfoArray, 
        uint flags);

    [DllImport("user32.dll")]
    public static extern int DisplayConfigGetDeviceInfo(ref DISPLAYCONFIG_TARGET_DEVICE_NAME deviceName);

    // Helper: Read source mode position from modeData bytes
    // DISPLAYCONFIG_SOURCE_MODE layout:
    //   uint width (4), uint height (4), uint pixelFormat (4), POINTL position (8)
    public static void GetSourceModePosition(byte[] modeData, out int x, out int y, out uint width, out uint height)
    {
        width = BitConverter.ToUInt32(modeData, 0);
        height = BitConverter.ToUInt32(modeData, 4);
        // pixelFormat at offset 8
        x = BitConverter.ToInt32(modeData, 12);
        y = BitConverter.ToInt32(modeData, 16);
    }

    // Helper: Set source mode position in modeData bytes
    public static void SetSourceModePosition(byte[] modeData, int x, int y)
    {
        byte[] xBytes = BitConverter.GetBytes(x);
        byte[] yBytes = BitConverter.GetBytes(y);
        Array.Copy(xBytes, 0, modeData, 12, 4);
        Array.Copy(yBytes, 0, modeData, 16, 4);
    }

    // Get friendly name for a target
    public static string GetTargetName(LUID adapterId, uint targetId)
    {
        var deviceName = new DISPLAYCONFIG_TARGET_DEVICE_NAME();
        deviceName.header.type = DISPLAYCONFIG_DEVICE_INFO_GET_TARGET_NAME;
        deviceName.header.size = (uint)Marshal.SizeOf(typeof(DISPLAYCONFIG_TARGET_DEVICE_NAME));
        deviceName.header.adapterId = adapterId;
        deviceName.header.id = targetId;
        
        int result = DisplayConfigGetDeviceInfo(ref deviceName);
        if (result == 0)
            return deviceName.monitorFriendlyDeviceName ?? "";
        return "";
    }

    // Get current active display configuration
    public static int GetActiveConfig(out DISPLAYCONFIG_PATH_INFO[] paths, out DISPLAYCONFIG_MODE_INFO_RAW[] modes)
    {
        paths = null;
        modes = null;
        
        uint pathCount, modeCount;
        int result = GetDisplayConfigBufferSizes(QDC_ONLY_ACTIVE_PATHS, out pathCount, out modeCount);
        if (result != 0) return result;

        paths = new DISPLAYCONFIG_PATH_INFO[pathCount];
        modes = new DISPLAYCONFIG_MODE_INFO_RAW[modeCount];
        
        // Initialize modeData arrays
        for (int i = 0; i < modeCount; i++)
        {
            modes[i].modeData = new byte[48];
        }

        result = QueryDisplayConfig(QDC_ONLY_ACTIVE_PATHS, ref pathCount, paths, ref modeCount, modes, IntPtr.Zero);
        
        if (result == 0)
        {
            Array.Resize(ref paths, (int)pathCount);
            Array.Resize(ref modes, (int)modeCount);
        }
        
        return result;
    }

    // Set positions for all monitors at once
    public static int SetAllPositions(string[] monitorPatterns, int[] xPositions, int[] yPositions)
    {
        DISPLAYCONFIG_PATH_INFO[] paths;
        DISPLAYCONFIG_MODE_INFO_RAW[] modes;
        
        int result = GetActiveConfig(out paths, out modes);
        if (result != 0) return result;

        for (int i = 0; i < paths.Length; i++)
        {
            string name = GetTargetName(paths[i].targetInfo.adapterId, paths[i].targetInfo.id);
            
            for (int j = 0; j < monitorPatterns.Length; j++)
            {
                if (name.IndexOf(monitorPatterns[j], StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    uint modeIdx = paths[i].sourceInfo.modeInfoIdx;
                    if (modeIdx < modes.Length && modes[modeIdx].infoType == DISPLAYCONFIG_MODE_INFO_TYPE_SOURCE)
                    {
                        SetSourceModePosition(modes[modeIdx].modeData, xPositions[j], yPositions[j]);
                    }
                    break;
                }
            }
        }

        result = SetDisplayConfig((uint)paths.Length, paths, (uint)modes.Length, modes,
            SDC_APPLY | SDC_USE_SUPPLIED_DISPLAY_CONFIG | SDC_ALLOW_CHANGES | SDC_SAVE_TO_DATABASE);

        return result;
    }

    // Disable a monitor by name pattern
    public static int DisableMonitor(string monitorNamePattern)
    {
        DISPLAYCONFIG_PATH_INFO[] paths;
        DISPLAYCONFIG_MODE_INFO_RAW[] modes;
        
        int result = GetActiveConfig(out paths, out modes);
        if (result != 0) return result;

        var newPaths = new List<DISPLAYCONFIG_PATH_INFO>();
        
        for (int i = 0; i < paths.Length; i++)
        {
            string name = GetTargetName(paths[i].targetInfo.adapterId, paths[i].targetInfo.id);
            if (name.IndexOf(monitorNamePattern, StringComparison.OrdinalIgnoreCase) < 0)
            {
                newPaths.Add(paths[i]);
            }
        }

        if (newPaths.Count == paths.Length) return -2; // Not found
        if (newPaths.Count == 0) return -1; // Can't disable all

        result = SetDisplayConfig((uint)newPaths.Count, newPaths.ToArray(), (uint)modes.Length, modes,
            SDC_APPLY | SDC_USE_SUPPLIED_DISPLAY_CONFIG | SDC_ALLOW_CHANGES | SDC_SAVE_TO_DATABASE);

        return result;
    }

    // Enable a monitor by name pattern - ensures unique source ID for extend mode
    public static int EnableMonitor(string monitorNamePattern, int x, int y)
    {
        uint pathCount, modeCount;
        int result = GetDisplayConfigBufferSizes(QDC_ALL_PATHS, out pathCount, out modeCount);
        if (result != 0) return result;

        var allPaths = new DISPLAYCONFIG_PATH_INFO[pathCount];
        var allModes = new DISPLAYCONFIG_MODE_INFO_RAW[modeCount];
        for (int i = 0; i < modeCount; i++) allModes[i].modeData = new byte[48];
        
        result = QueryDisplayConfig(QDC_ALL_PATHS, ref pathCount, allPaths, ref modeCount, allModes, IntPtr.Zero);
        if (result != 0) return result;

        DISPLAYCONFIG_PATH_INFO[] activePaths;
        DISPLAYCONFIG_MODE_INFO_RAW[] activeModes;
        result = GetActiveConfig(out activePaths, out activeModes);
        if (result != 0) return result;

        // Find used source IDs to avoid cloning
        var usedSourceIds = new HashSet<uint>();
        foreach (var ap in activePaths)
        {
            usedSourceIds.Add(ap.sourceInfo.id);
        }

        // Check if already active
        foreach (var ap in activePaths)
        {
            string name = GetTargetName(ap.targetInfo.adapterId, ap.targetInfo.id);
            if (name.IndexOf(monitorNamePattern, StringComparison.OrdinalIgnoreCase) >= 0)
            {
                return 0; // Already active, success
            }
        }

        // Find a path for the target with an UNUSED source ID
        int targetPathIndex = -1;
        for (int i = 0; i < pathCount; i++)
        {
            if (!allPaths[i].targetInfo.targetAvailable) continue;
            
            string name = GetTargetName(allPaths[i].targetInfo.adapterId, allPaths[i].targetInfo.id);
            if (name.IndexOf(monitorNamePattern, StringComparison.OrdinalIgnoreCase) >= 0 &&
                !usedSourceIds.Contains(allPaths[i].sourceInfo.id))
            {
                targetPathIndex = i;
                break;
            }
        }

        // Fallback: use any path for this target
        if (targetPathIndex < 0)
        {
            for (int i = 0; i < pathCount; i++)
            {
                if (!allPaths[i].targetInfo.targetAvailable) continue;
                
                string name = GetTargetName(allPaths[i].targetInfo.adapterId, allPaths[i].targetInfo.id);
                if (name.IndexOf(monitorNamePattern, StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    targetPathIndex = i;
                    break;
                }
            }
        }

        if (targetPathIndex < 0) return -2; // Not found

        // Modify the path in place to mark it active
        allPaths[targetPathIndex].flags = DISPLAYCONFIG_PATH_ACTIVE;

        // Build new paths array: current active + new one
        var newPaths = new DISPLAYCONFIG_PATH_INFO[activePaths.Length + 1];
        for (int i = 0; i < activePaths.Length; i++)
        {
            newPaths[i] = activePaths[i];
        }
        newPaths[activePaths.Length] = allPaths[targetPathIndex];

        result = SetDisplayConfig((uint)newPaths.Length, newPaths, modeCount, allModes,
            SDC_APPLY | SDC_USE_SUPPLIED_DISPLAY_CONFIG | SDC_ALLOW_CHANGES);

        return result;
    }

    // Clone all currently active displays by making them share source ID 0
    public static int CloneActiveDisplays()
    {
        DISPLAYCONFIG_PATH_INFO[] paths;
        DISPLAYCONFIG_MODE_INFO_RAW[] modes;
        
        int result = GetActiveConfig(out paths, out modes);
        if (result != 0) return result;

        if (paths.Length < 2) return -1; // Need at least 2 displays to clone

        // Make all paths use source ID 0 (clone them)
        uint sharedSourceId = paths[0].sourceInfo.id;
        uint sharedModeIdx = paths[0].sourceInfo.modeInfoIdx;
        
        for (int i = 1; i < paths.Length; i++)
        {
            paths[i].sourceInfo.id = sharedSourceId;
            paths[i].sourceInfo.modeInfoIdx = sharedModeIdx;
        }

        result = SetDisplayConfig((uint)paths.Length, paths, (uint)modes.Length, modes,
            SDC_APPLY | SDC_USE_SUPPLIED_DISPLAY_CONFIG | SDC_ALLOW_CHANGES | SDC_SAVE_TO_DATABASE);

        return result;
    }

    // Un-clone displays by giving each a unique source ID (extend mode)
    public static int ExtendActiveDisplays()
    {
        // Get ALL paths to find paths with different source IDs for same targets
        uint pathCount, modeCount;
        int result = GetDisplayConfigBufferSizes(QDC_ALL_PATHS, out pathCount, out modeCount);
        if (result != 0) return result;

        var allPaths = new DISPLAYCONFIG_PATH_INFO[pathCount];
        var allModes = new DISPLAYCONFIG_MODE_INFO_RAW[modeCount];
        for (int i = 0; i < modeCount; i++) allModes[i].modeData = new byte[48];
        
        result = QueryDisplayConfig(QDC_ALL_PATHS, ref pathCount, allPaths, ref modeCount, allModes, IntPtr.Zero);
        if (result != 0) return result;

        // Get current active
        DISPLAYCONFIG_PATH_INFO[] activePaths;
        DISPLAYCONFIG_MODE_INFO_RAW[] activeModes;
        result = GetActiveConfig(out activePaths, out activeModes);
        if (result != 0) return result;

        // Build new paths with unique source IDs
        var newPaths = new List<DISPLAYCONFIG_PATH_INFO>();
        var usedSourceIds = new HashSet<uint>();

        foreach (var activePath in activePaths)
        {
            // Find a path for this target with an unused source ID
            DISPLAYCONFIG_PATH_INFO? bestPath = null;
            
            for (int i = 0; i < pathCount; i++)
            {
                if (allPaths[i].targetInfo.id == activePath.targetInfo.id &&
                    allPaths[i].targetInfo.adapterId.Equals(activePath.targetInfo.adapterId) &&
                    allPaths[i].targetInfo.targetAvailable &&
                    !usedSourceIds.Contains(allPaths[i].sourceInfo.id))
                {
                    var p = allPaths[i];
                    p.flags = DISPLAYCONFIG_PATH_ACTIVE;
                    bestPath = p;
                    break;
                }
            }

            if (bestPath.HasValue)
            {
                newPaths.Add(bestPath.Value);
                usedSourceIds.Add(bestPath.Value.sourceInfo.id);
            }
            else
            {
                // Fallback to original (will stay cloned)
                newPaths.Add(activePath);
                usedSourceIds.Add(activePath.sourceInfo.id);
            }
        }

        result = SetDisplayConfig((uint)newPaths.Count, newPaths.ToArray(), modeCount, allModes,
            SDC_APPLY | SDC_USE_SUPPLIED_DISPLAY_CONFIG | SDC_ALLOW_CHANGES | SDC_ALLOW_PATH_ORDER_CHANGES);

        return result;
    }

    // Get list of active monitors with positions
    public static List<MonitorInfo> GetActiveMonitors()
    {
        var monitors = new List<MonitorInfo>();
        
        DISPLAYCONFIG_PATH_INFO[] paths;
        DISPLAYCONFIG_MODE_INFO_RAW[] modes;
        
        int result = GetActiveConfig(out paths, out modes);
        if (result != 0) return monitors;

        foreach (var path in paths)
        {
            string name = GetTargetName(path.targetInfo.adapterId, path.targetInfo.id);
            
            int x = 0, y = 0;
            uint width = 0, height = 0;
            
            uint modeIdx = path.sourceInfo.modeInfoIdx;
            if (modeIdx < modes.Length && modes[modeIdx].infoType == DISPLAYCONFIG_MODE_INFO_TYPE_SOURCE)
            {
                GetSourceModePosition(modes[modeIdx].modeData, out x, out y, out width, out height);
            }

            monitors.Add(new MonitorInfo
            {
                Name = name,
                SourceId = path.sourceInfo.id,
                TargetId = path.targetInfo.id,
                X = x,
                Y = y,
                Width = width,
                Height = height
            });
        }

        return monitors;
    }
}

public class MonitorInfo
{
    public string Name { get; set; }
    public uint SourceId { get; set; }
    public uint TargetId { get; set; }
    public int X { get; set; }
    public int Y { get; set; }
    public uint Width { get; set; }
    public uint Height { get; set; }
}
"@

Write-Host "DisplayConfigV2 loaded." -ForegroundColor DarkGray
