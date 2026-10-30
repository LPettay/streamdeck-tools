# streamdeck-tools

Stream Deck scripts for Windows: multi-monitor mode switching, ATEM Mini Pro input switching, an OBS projector toggle, and a game-mode toggle for the WSL AI stack. Each button shows live state.

This is the single source for every script the Stream Deck runs. It lives on the Windows side because display switching, window handling, and the Stream Deck app itself are Windows-native.

## Monitors

| Name | Model | Resolution | Role |
|------|-------|-----------|------|
| Primary | ASUS VG27A | 2560x1440 | Main desk monitor |
| Ultrawide | Samsung LC34G55T | 3440x1440 | Secondary desk monitor |
| TV | Vizio V4K43M | 3840x2160 | Living room TV |

## Modes

| Mode | Script | Monitors | Layout |
|------|--------|----------|--------|
| PC Only | `pc-only.bat` | Primary + Ultrawide | Desk work |
| TV Mode | `tv-mode.bat` | Primary + TV (cloned) | Couch gaming |
| TV Extend | `tv-extend.bat` | Primary + TV (extended) | TV as second screen |
| Extend All | `extend-all.bat` | All 3 | Everything on |

## Stream Deck Integration

Uses the [Stateful Executor](https://marketplace.elgato.com/product/stateful-executor-e9612a4f-b8d7-44f8-a5ed-9ad9f9ae3064) plugin for dynamic button state. Each mode button:

- **On click:** Writes state to `current-mode.json`, launches mode switch in background
- **On poll:** Reads `current-mode.json` to update button icons
- **Active mode** shows a bright colored icon; inactive modes show dimmed gray icons

**If every button goes dead, restart Stream Deck** (use the Restart Stream Deck button if the deck still responds; it runs `restart-streamdeck.ps1` detached from Stream Deck's process tree so the restart survives the kill, reaps orphaned plugin processes, and relaunches). When the plugin process crashes repeatedly (for example, an uncaught `ENOSPC` while logging on a full disk), Stream Deck marks it unstable and disables it. Every Stateful Executor button stops working until the app restarts. Failed polls don't crash the plugin, but each one writes a stack trace to its log (`%APPDATA%\Elgato\StreamDeck\Plugins\com.vlad-gramuzov.stream-deck-stateful-executor.sdPlugin\logs`). So state polls read plain files, and HTTP status endpoints return 200 even when the backing device is unreachable.

### Buttons

| Button | Action | Poll |
|--------|--------|------|
| Monitor modes | `scripts/<mode>.ps1` | `scripts/current-mode.json` |
| ATEM inputs 1–4 | `scripts/atem/atem-switch.js cut N` | `scripts/atem/state.json` |
| ATEM output | `scripts/atem/atem-output.js toggle` | `scripts/atem/state.json` |
| OBS projector | `scripts/atem/obs-projector.js 0` | `scripts/atem/projector-toggle.ps1 check` |
| Game mode | `scripts/game-mode.bat` (runs `game-mode toggle` in WSL) | `scripts/game-mode.state` |
| Restart Stream Deck | `scripts/restart-streamdeck.bat` | none |
| Dreo fan | HTTP `localhost:8401` (served from WSL by `~/Genesis/apps/dreo`) | `GET /status` |

### Icons

Custom icons in `icons/` — active (bright) and inactive (dimmed) variants per mode. `scripts/atem/generate-output-icons.py` regenerates the ATEM output icons.

## Scripts

### Mode Scripts
Each mode has a `.bat` launcher (silent, no window) and a `.ps1` implementation.

### Library
- `MonitorConfig.ps1` — Shared functions (enable/disable/position monitors, clone, extend)
- `DisplayConfig.ps1` — Windows Display Config API (legacy)
- `DisplayConfigV2.ps1` — Windows Display Config API v2

### ATEM / OBS (`scripts/atem/`)
Node scripts using `atem-connection` and `obs-websocket-js`. Run `npm install` in `scripts/atem/` with Windows Node.

OBS WebSocket credentials go in `scripts/atem/obs.local.json` (gitignored):

```json
{ "url": "ws://localhost:4455", "password": "..." }
```

The remaining `atem-*.js` files (`dump`, `info`, `sniff`, `firmware`, `brightness`, `videohub-brightness`) are diagnostics, not wired to buttons.

### Utilities
- `get-mode.ps1` — Returns current mode as JSON
- `status.bat` / `status.ps1` — Show current monitor status
