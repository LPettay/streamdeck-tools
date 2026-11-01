"""Route each app's audio to the TV speakers while its window is on the TV display.

Apps whose windows are on any other display use the default audio device. When the
TV's audio endpoint is not active (TV off), every app we routed goes back to the
default device.

Per-app routing uses NirSoft SoundVolumeView (tools/soundvolumeview/), which wraps
the undocumented Windows per-app endpoint API.

Usage (Windows Python):
  audio-follow.py            run the loop
  audio-follow.py --revert   send every routed app back to the default device, exit
  audio-follow.py --dry-run  run the loop, print commands instead of executing them
  audio-follow.py --toggle   start the daemon detached, or stop it and revert (Stream Deck button)
  audio-follow.py --once     one pass, then exit (combine with --dry-run to inspect)
"""
import argparse
import ctypes
import json
import os
import subprocess
import sys
import time
from pathlib import Path

import psutil
import win32api
import win32con
import win32gui
import win32process
from pycaw.pycaw import AudioUtilities

HERE = Path(__file__).resolve().parent
SVV = HERE.parent / "tools" / "soundvolumeview" / "SoundVolumeView.exe"
STATE_FILE = HERE / "audio-follow.state"
ROUTED_FILE = HERE / "audio-follow.routed.json"  # exe -> "tv" for apps we've pinned
LOG_FILE = HERE / "audio-follow.log"
PID_FILE = HERE / "audio-follow.pid"

TV_DEVICE_MATCH = "Vizio"  # substring of the TV endpoint's friendly name
TV_MONITOR_ID = "MONITOR\\VIZ"  # prefix of the TV's PnP monitor ID (resolution varies by mode)
POLL_SECONDS = 2.0

# Never route these (system sounds, the audio engine itself).
SKIP_EXES = {"audiodg.exe", "system", "svchost.exe", "systemsounds"}


def log(msg):
    line = f"{time.strftime('%H:%M:%S')} {msg}"
    print(line, flush=True)
    try:
        if LOG_FILE.exists() and LOG_FILE.stat().st_size > 256_000:
            LOG_FILE.write_text("")
        with LOG_FILE.open("a", encoding="utf-8") as f:
            f.write(line + "\n")
    except OSError:
        pass


def svv_name(friendly):
    """'Vizio (NVIDIA High Definition Audio)' -> 'NVIDIA High Definition Audio\\Device\\Vizio\\Render'."""
    if friendly.endswith(")") and " (" in friendly:
        name, adapter = friendly[:-1].rsplit(" (", 1)
        return f"{adapter}\\Device\\{name}\\Render"
    return friendly


def list_render_devices():
    out = []
    for d in AudioUtilities.GetAllDevices():
        state = str(d.state).split(".")[-1]
        out.append((d.id, d.FriendlyName or "", state))
    return out


def find_tv_device():
    """Friendly name of the active TV endpoint, or None when the TV is off."""
    for _id, name, state in list_render_devices():
        if state == "Active" and TV_DEVICE_MATCH.lower() in name.lower():
            return name
    return None


def find_default_device():
    """Friendly name of the current default render device."""
    spk = AudioUtilities.GetSpeakers()
    dev_id = spk.id if hasattr(spk, "id") else spk.GetId()
    for _id, name, _state in list_render_devices():
        if _id == dev_id:
            return name
    return None


def tv_monitor_rect():
    for hmon, _dc, rect in win32api.EnumDisplayMonitors():
        dev = win32api.GetMonitorInfo(hmon)["Device"]
        try:
            mon_id = win32api.EnumDisplayDevices(dev, 0).DeviceID
        except win32api.error:
            continue
        if mon_id.upper().startswith(TV_MONITOR_ID):
            return rect
    return None


def exe_window_monitors():
    """exe name (lowercase) -> rect of its largest visible window's monitor."""
    best = {}  # exe -> (area, monitor_rect)

    def cb(hwnd, _):
        if not win32gui.IsWindowVisible(hwnd) or win32gui.IsIconic(hwnd):
            return
        if not win32gui.GetWindowText(hwnd):
            return
        if win32gui.GetWindowLong(hwnd, win32con.GWL_EXSTYLE) & win32con.WS_EX_TOOLWINDOW:
            return
        try:
            _tid, pid = win32process.GetWindowThreadProcessId(hwnd)
            exe = psutil.Process(pid).name().lower()
            l, t, r, b = win32gui.GetWindowRect(hwnd)
            area = max(0, r - l) * max(0, b - t)
            hmon = win32api.MonitorFromWindow(hwnd, win32con.MONITOR_DEFAULTTONEAREST)
            mrect = win32api.GetMonitorInfo(hmon)["Monitor"]
        except (psutil.Error, win32api.error):
            return
        if exe not in best or area > best[exe][0]:
            best[exe] = (area, mrect)

    win32gui.EnumWindows(cb, None)
    return {exe: mrect for exe, (_a, mrect) in best.items()}


def audio_exes():
    """Lowercase exe names that currently have an audio session."""
    exes = set()
    for s in AudioUtilities.GetAllSessions():
        p = s.Process
        if p is None:
            continue
        try:
            name = p.name().lower()
        except psutil.Error:
            continue
        if name not in SKIP_EXES:
            exes.add(name)
    return exes


def set_app_device(exe, friendly, dry_run):
    cmd = [str(SVV), "/SetAppDefault", svv_name(friendly), "all", exe]
    if dry_run:
        log("DRY " + " ".join(f'"{c}"' for c in cmd))
        return True
    r = subprocess.run(cmd, capture_output=True, timeout=15, creationflags=0x08000000)
    if r.returncode != 0:
        log(f"SetAppDefault failed for {exe} -> {friendly}: rc={r.returncode}")
        return False
    return True


def load_routed():
    try:
        return set(json.loads(ROUTED_FILE.read_text()))
    except (OSError, ValueError):
        return set()


def save_routed(routed):
    ROUTED_FILE.write_text(json.dumps(sorted(routed)))


def revert_all(dry_run):
    routed = load_routed()
    if not routed:
        return
    default = find_default_device()
    if not default:
        log("revert: no default device found, leaving routes in place")
        return
    still = set()
    for exe in routed:
        if not set_app_device(exe, default, dry_run):
            still.add(exe)
    save_routed(still)
    log(f"reverted {len(routed) - len(still)} app(s) to default device '{default}'")


def one_pass(dry_run):
    routed = load_routed()
    tv_dev = find_tv_device()
    if tv_dev is None:
        if routed:
            log("TV audio endpoint inactive: reverting to default device")
            revert_all(dry_run)
        return
    tv_rect = tv_monitor_rect()
    if tv_rect is None:
        if routed:
            log("TV display not active: reverting to default device")
            revert_all(dry_run)
        return
    windows = exe_window_monitors()
    default = None
    for exe in audio_exes():
        mrect = windows.get(exe)
        if mrect is None:
            continue  # no visible window: leave as is
        on_tv = tuple(mrect) == tuple(tv_rect)
        if on_tv and exe not in routed:
            if set_app_device(exe, tv_dev, dry_run):
                routed.add(exe)
                log(f"{exe} -> TV ({tv_dev})")
        elif not on_tv and exe in routed:
            default = default or find_default_device()
            if default and set_app_device(exe, default, dry_run):
                routed.discard(exe)
                log(f"{exe} -> default ({default})")
    save_routed(routed)


def running_pid():
    try:
        pid = int(PID_FILE.read_text())
        p = psutil.Process(pid)
        if any("audio-follow.py" in a for a in p.cmdline()):
            return pid
    except (OSError, ValueError, psutil.Error):
        pass
    return None


def toggle():
    pid = running_pid()
    if pid:
        psutil.Process(pid).terminate()
        PID_FILE.unlink(missing_ok=True)
        revert_all(False)
        STATE_FILE.write_text("off")
        log("audio-follow stopped")
        return
    pyw = Path(sys.executable).with_name("pythonw.exe")
    exe = str(pyw if pyw.exists() else sys.executable)
    flags = 0x00000008 | 0x00000200 | 0x08000000  # DETACHED | NEW_PROCESS_GROUP | NO_WINDOW
    subprocess.Popen([exe, str(Path(__file__).resolve())], creationflags=flags, close_fds=True)
    STATE_FILE.write_text("on")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--revert", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--once", action="store_true")
    ap.add_argument("--toggle", action="store_true")
    args = ap.parse_args()

    if not args.dry_run and not SVV.exists():
        sys.exit(f"missing {SVV}")

    if args.toggle:
        toggle()
        return

    if args.revert:
        revert_all(args.dry_run)
        STATE_FILE.write_text("off")
        return

    ctypes.windll.user32.SetProcessDPIAware()
    ctypes.windll.ole32.CoInitialize(None)
    if not args.once:
        PID_FILE.write_text(str(os.getpid()))
        STATE_FILE.write_text("on")
    log("audio-follow started" + (" (dry run)" if args.dry_run else ""))
    try:
        while True:
            try:
                one_pass(args.dry_run)
            except Exception as e:  # keep the daemon alive across transient COM errors
                log(f"pass failed: {type(e).__name__}: {e}")
            if args.once:
                return
            time.sleep(POLL_SECONDS)
    finally:
        if not args.once:
            STATE_FILE.write_text("off")
            PID_FILE.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
