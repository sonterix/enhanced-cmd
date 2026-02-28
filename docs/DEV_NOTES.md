# DEV_NOTES.md — Enhanced CDM Dev Notes

> Known bugs, addon conflicts, and migration status.
> Reference this file manually when debugging or planning a release — not needed on every task.

---

## Known Blizzard Bugs (12.0)

| Location | Error | Notes |
|---|---|---|
| `CooldownViewer.lua:947` | `"attempt to compare local 'charges' (a secret value)"` in `CacheChargeValues` | Triggered when charge values become Secret during restricted play. Enhanced CDM doesn't call this directly but icon frame state may be affected. |
| `CooldownViewerSettingsDataStoreSerialization.lua:381` | `"All keys must be numbers (found string)"` | Fires when spec IDs return as strings. Not directly caused by Enhanced CDM. |
| `EditModeManager.lua:1373` | `"Couldn't find region named 'LeftChatPanel'"` in `UpdateSystems` | Enhanced CDM already wraps Edit Mode hooks in `pcall` for safety. |

---

## Addon Conflicts

| Addon | Conflict |
|---|---|
| **ArcUI CDMGroups** | Also repositions CDM frames. Incompatible with Enhanced CDM aura positioning. |
| **EnhanceQoL CooldownPanels** | Also repositions CDM frames. Incompatible with Enhanced CDM aura positioning. |

---
