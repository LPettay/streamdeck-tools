# streamdeck-tools

Stream Deck multi-monitor mode switching for Windows. One-button switching between display configurations with visual state feedback.

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
- **On poll:** Reads `current-mode.json` via `get-mode.ps1` to update button icons
- **Active mode** shows a bright colored icon; inactive modes show dimmed gray icons

### Icons

Custom icons in `icons/` — active (bright) and inactive (dimmed) variants per mode.

## Scripts

### Mode Scripts
Each mode has a `.bat` launcher (silent, no window) and a `.ps1` implementation.

### Library
- `MonitorConfig.ps1` — Shared functions (enable/disable/position monitors, clone, extend)
- `DisplayConfig.ps1` — Windows Display Config API (legacy)
- `DisplayConfigV2.ps1` — Windows Display Config API v2

### Utilities
- `get-mode.ps1` — Returns current mode as JSON (for Stream Deck polling)
- `status.bat` / `status.ps1` — Show current monitor status
