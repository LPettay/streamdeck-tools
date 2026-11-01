@echo off
rem Toggle per-display audio routing (TV window -> TV speakers). Wired to a Stream Deck Executor button.
rem Poll scripts\audio-follow.state ("on"/"off"). Needs Windows Python with pycaw, psutil, pywin32.
"%LOCALAPPDATA%\Programs\Python\Python313\python.exe" "%~dp0audio-follow.py" --toggle
