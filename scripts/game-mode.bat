@echo off
rem Toggle the WSL AI stack on/off to free the GPU for gaming. Wired to a Stream Deck Executor button.
wsl.exe -d Ubuntu-22.04 -- bash -lc "/home/lance/.local/bin/game-mode toggle"
