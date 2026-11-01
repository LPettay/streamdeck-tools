Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Collections.Generic;

public class ProjWin {
    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumCB cb, IntPtr lp);
    [DllImport("user32.dll")]
    public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")]
    public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr h);

    public delegate bool EnumCB(IntPtr h, IntPtr l);

    public static List<IntPtr> Find() {
        var found = new List<IntPtr>();
        EnumWindows((h, l) => {
            var sb = new StringBuilder(256);
            GetWindowText(h, sb, 256);
            if (sb.ToString().Contains("Projector") && IsWindowVisible(h))
                found.Add(h);
            return true;
        }, IntPtr.Zero);
        return found;
    }
}
"@

$action = $args[0]  # "check", "close", "focus"

$windows = [ProjWin]::Find()

switch ($action) {
    "check" {
        if ($windows.Count -gt 0) {
            Write-Output '{"projector":"on"}'
        } else {
            Write-Output '{"projector":"off"}'
        }
    }
    "close" {
        foreach ($h in $windows) {
            [ProjWin]::PostMessage($h, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
        }
        if ($windows.Count -gt 0) { Write-Output "closed" } else { Write-Output "none" }
    }
    "focus" {
        foreach ($h in $windows) {
            [ProjWin]::SetForegroundWindow($h) | Out-Null
        }
    }
}
