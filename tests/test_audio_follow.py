"""Routing rules of scripts/audio-follow.py. Standard library only: run on any OS with

    python3 -m unittest discover -s tests -v

The Windows modules are mocked, and only the SoundVolumeView call, the audio device
list and the window positions are faked, so the script's own routing code runs for real.
Every file the script writes is pointed at a temp folder: the real ones may belong to
a running daemon.
"""
import importlib.util
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest import mock

SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "audio-follow.py"
WINDOWS_MODULES = ("psutil", "win32api", "win32con", "win32gui", "win32process", "pycaw", "pycaw.pycaw")

TV_DEVICE = "Vizio (NVIDIA High Definition Audio)"
DESK_DEVICE = "Game (RØDECaster)"
TV_SVV = "NVIDIA High Definition Audio\\Device\\Vizio\\Render"
DESK_SVV = "RØDECaster\\Device\\Game\\Render"
TV_RECT = (3840, 0, 7680, 2160)
DESK_RECT = (0, 0, 2560, 1440)


def load_script():
    fakes = {name: mock.MagicMock() for name in WINDOWS_MODULES}
    with mock.patch.dict(sys.modules, fakes):
        spec = importlib.util.spec_from_file_location("audio_follow", SCRIPT)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
    return module


af = load_script()


class AudioFollowTest(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.tmp = Path(tmp.name)
        self.svv = self.tmp / "SoundVolumeView.exe"
        self.calls = []
        self.failing = set()  # apps whose SoundVolumeView call returns non-zero

        patches = [
            mock.patch.object(af, "SVV", self.svv),
            mock.patch.object(af, "STATE_FILE", self.tmp / "audio-follow.state"),
            mock.patch.object(af, "ROUTED_FILE", self.tmp / "audio-follow.routed.json"),
            mock.patch.object(af, "LOG_FILE", self.tmp / "audio-follow.log"),
            mock.patch.object(af, "PID_FILE", self.tmp / "audio-follow.pid"),
            mock.patch.object(af, "AudioUtilities", mock.MagicMock()),
            mock.patch.object(af, "tv_monitor_rect", return_value=TV_RECT),
            mock.patch.object(af, "exe_window_monitors", return_value={}),
            mock.patch.object(af.subprocess, "run", side_effect=self.fake_svv),
            mock.patch("sys.stdout", io.StringIO()),
        ]
        for p in patches:
            p.start()
            self.addCleanup(p.stop)
        af.AudioUtilities.GetSpeakers.return_value = SimpleNamespace(id="desk")
        self.set_devices(tv_state="Active")

    def fake_svv(self, cmd, **_kwargs):
        self.calls.append(cmd)
        return SimpleNamespace(returncode=1 if cmd[-1] in self.failing else 0)

    def set_devices(self, tv_state):
        devices = [SimpleNamespace(id="desk", FriendlyName=DESK_DEVICE, state="AudioDeviceState.Active")]
        if tv_state is not None:
            devices.append(SimpleNamespace(id="tv", FriendlyName=TV_DEVICE, state=f"AudioDeviceState.{tv_state}"))
        af.AudioUtilities.GetAllDevices.return_value = devices

    def set_world(self, routed=(), audio=(), windows=None):
        af.ROUTED_FILE.write_text(json.dumps(sorted(routed)))
        af.AudioUtilities.GetAllSessions.return_value = [
            SimpleNamespace(Process=SimpleNamespace(name=lambda exe=exe: exe)) for exe in audio
        ]
        af.exe_window_monitors.return_value = windows or {}
        self.calls.clear()

    def svv_call(self, device, exe):
        return [str(self.svv), "/SetAppDefault", device, "all", exe]

    def routed_after(self):
        return json.loads(af.ROUTED_FILE.read_text())

    def test_a_audio_app_on_tv_goes_to_tv_and_joins_list(self):
        self.set_world(audio=["chrome.exe"], windows={"chrome.exe": TV_RECT})
        af.one_pass(False)
        self.assertEqual(self.calls, [self.svv_call(TV_SVV, "chrome.exe")])
        self.assertEqual(self.routed_after(), ["chrome.exe"])

    def test_b_routed_app_on_other_display_goes_to_default_and_leaves_list(self):
        self.set_world(routed=["chrome.exe"], audio=["chrome.exe"], windows={"chrome.exe": DESK_RECT})
        af.one_pass(False)
        self.assertEqual(self.calls, [self.svv_call(DESK_SVV, "chrome.exe")])
        self.assertEqual(self.routed_after(), [])

    def test_c_routed_app_with_no_visible_window_is_left_alone(self):
        self.set_world(routed=["chrome.exe"], audio=["chrome.exe"], windows={})
        af.one_pass(False)
        self.assertEqual(self.calls, [])
        self.assertEqual(self.routed_after(), ["chrome.exe"])

    def test_d_tv_audio_device_gone_sends_all_routed_apps_to_default(self):
        for tv_state in (None, "NotPresent"):  # not listed at all, or listed but not active
            with self.subTest(tv_state=tv_state):
                self.set_devices(tv_state=tv_state)
                self.set_world(
                    routed=["chrome.exe", "vlc.exe"],
                    audio=["chrome.exe", "vlc.exe"],
                    windows={"chrome.exe": TV_RECT, "vlc.exe": TV_RECT},
                )
                af.one_pass(False)
                self.assertCountEqual(
                    self.calls,
                    [self.svv_call(DESK_SVV, "chrome.exe"), self.svv_call(DESK_SVV, "vlc.exe")],
                )
                self.assertEqual(self.routed_after(), [])

    def test_e_tv_display_gone_with_audio_device_present_sends_all_routed_apps_to_default(self):
        af.tv_monitor_rect.return_value = None
        self.set_world(
            routed=["chrome.exe", "vlc.exe"],
            audio=["chrome.exe", "vlc.exe"],
            windows={"chrome.exe": DESK_RECT, "vlc.exe": DESK_RECT},
        )
        af.one_pass(False)
        self.assertCountEqual(
            self.calls,
            [self.svv_call(DESK_SVV, "chrome.exe"), self.svv_call(DESK_SVV, "vlc.exe")],
        )
        self.assertEqual(self.routed_after(), [])

    def test_f_failed_svv_call_leaves_that_apps_list_entry_unchanged(self):
        self.failing = {"chrome.exe"}

        with self.subTest("to the TV: stays off the list"):
            self.set_world(audio=["chrome.exe"], windows={"chrome.exe": TV_RECT})
            af.one_pass(False)
            self.assertEqual(self.calls, [self.svv_call(TV_SVV, "chrome.exe")])
            self.assertEqual(self.routed_after(), [])

        with self.subTest("back to default: stays on the list"):
            self.set_world(routed=["chrome.exe"], audio=["chrome.exe"], windows={"chrome.exe": DESK_RECT})
            af.one_pass(False)
            self.assertEqual(self.calls, [self.svv_call(DESK_SVV, "chrome.exe")])
            self.assertEqual(self.routed_after(), ["chrome.exe"])

        with self.subTest("TV gone: only the failed app stays on the list"):
            self.set_devices(tv_state=None)
            self.set_world(routed=["chrome.exe", "vlc.exe"])
            af.one_pass(False)
            self.assertCountEqual(
                self.calls,
                [self.svv_call(DESK_SVV, "chrome.exe"), self.svv_call(DESK_SVV, "vlc.exe")],
            )
            self.assertEqual(self.routed_after(), ["chrome.exe"])

    def test_g_svv_name_maps_friendly_names(self):
        self.assertEqual(af.svv_name(TV_DEVICE), TV_SVV)
        self.assertEqual(af.svv_name(DESK_DEVICE), DESK_SVV)
        self.assertEqual(af.svv_name("Plain Name"), "Plain Name")

    def test_toggle_with_soundvolumeview_missing_logs_and_changes_nothing(self):
        for state in ("off", None):  # a state file as it was, or none at all
            with self.subTest(state=state):
                af.LOG_FILE.unlink(missing_ok=True)
                af.STATE_FILE.unlink(missing_ok=True)
                if state is not None:
                    af.STATE_FILE.write_text(state)

                with mock.patch.object(sys, "argv", ["audio-follow.py", "--toggle"]), \
                        mock.patch.object(af.subprocess, "Popen") as popen, \
                        self.assertRaises(SystemExit) as stopped:
                    af.main()

                self.assertNotIn(stopped.exception.code, (0, None))
                log = af.LOG_FILE.read_text(encoding="utf-8")
                self.assertIn("missing", log)
                self.assertIn(str(self.svv), log)
                self.assertEqual(af.STATE_FILE.read_text() if af.STATE_FILE.exists() else None, state)
                popen.assert_not_called()
                self.assertEqual(self.calls, [])


if __name__ == "__main__":
    unittest.main()
