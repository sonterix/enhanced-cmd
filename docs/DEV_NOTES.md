# DEV_NOTES.md — AuraRows Dev Notes

> Known bugs, addon conflicts, and migration status.
> Reference this file manually when debugging or planning a release — not needed on every task.

---

## Known Blizzard Bugs (12.0)

| Location | Error | Notes |
|---|---|---|
| `CooldownViewer.lua:947` | `"attempt to compare local 'charges' (a secret value)"` in `CacheChargeValues` | Triggered when charge values become Secret during restricted play. AuraRows doesn't call this directly but icon frame state may be affected. |
| `CooldownViewerSettingsDataStoreSerialization.lua:381` | `"All keys must be numbers (found string)"` | Fires when spec IDs return as strings. Not directly caused by AuraRows. |
| `EditModeManager.lua:1373` | `"Couldn't find region named 'LeftChatPanel'"` in `UpdateSystems` | AuraRows already wraps Edit Mode hooks in `pcall` for safety. |

---

## Addon Conflicts

| Addon | Conflict |
|---|---|
| **ArcUI CDMGroups** | Also repositions CDM frames. Incompatible with AuraRows aura positioning. |
| **EnhanceQoL CooldownPanels** | Also repositions CDM frames. Incompatible with AuraRows aura positioning. |

---
