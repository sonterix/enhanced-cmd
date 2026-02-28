# CLAUDE.md — AuraRows Developer Guide

> **Keep this file lean.** Only rules, architecture, and pitfalls belong here — things Claude needs on every task.
> For Blizzard API reference, see `docs/API_REFERENCE.md`.
> For known bugs, conflicts, and migration status, see `docs/DEV_NOTES.md`.

## Project Overview

**AuraRows** is a World of Warcraft addon (Midnight expansion, Interface 120000+) that repositions the Cooldown Manager's `BuffIconCooldownViewer` (Tracked Buffs) icons into a configurable multi-row grid. It hooks and repositions Blizzard's existing frames — it does **not** create its own icon frames.

- **Author:** Sonterix
- **Files:** `Config.lua`, `Core.lua`, `EditMode.lua`
- **No external dependencies**
- **SavedVariables:** `AuraRowsDB` (`maxPerRow`, `growDirection`, `align`)

## File Structure

```
AuraRows/
  CLAUDE.md             ← This file (keep lean)
  AuraRows.toc          ← Addon metadata, Interface version, SavedVariables
  Config.lua            ← Constants, defaults, display maps
  Core.lua              ← Layout engine, hooks, init, slash commands, events
  EditMode.lua          ← Edit Mode settings panel
  docs/
    README.md           ← User-facing docs + technical reference
    CHANGELOG.md        ← Version history (Keep A Changelog format)
    API_REFERENCE.md    ← Blizzard API details, deprecated templates, enums
    DEV_NOTES.md        ← Known bugs, addon conflicts, migration checklist
```

## Architecture

### Namespace (`ns`)

All files share a `ns` table via `local _, ns = ...`. No addon globals except `AuraRowsDB`.

| Key | Set by | Used by | Description |
|---|---|---|---|
| `ns.DEFAULTS` | Config | Core | Default SavedVariable values |
| `ns.DIRECTION_DISPLAY` | Config | Core, EditMode | `"DOWN"→"Down"` display map |
| `ns.ALIGN_DISPLAY` | Config | Core, EditMode | `"LEFT"→"Left"` display map |
| `ns.db` | Core | EditMode | Reference to `AuraRowsDB` |
| `ns.viewer` | Core | EditMode | Reference to `BuffIconCooldownViewer` |
| `ns.ApplyLayout` | Core | EditMode | Layout function |
| `ns.SetupEditMode` | EditMode | Core | Edit Mode hook installer |

**TOC load order:** `Config.lua` → `Core.lua` → `EditMode.lua`

### Init Flow

```
ADDON_LOADED (Core)
  → merge ns.DEFAULTS into AuraRowsDB, set ns.db, register slash commands
PLAYER_ENTERING_WORLD (Core)
  → TryInit() polls for BuffIconCooldownViewer (up to 10s)
    → InstallHooks() + ns.SetupEditMode() + ApplyLayout()
```

### Key Components

- **`ApplyLayout()`** — iterates visible icon children, positions them in a grid. Debounced via `ScheduleLayout()` → `C_Timer.NewTimer(0, ...)`.
- **SetPoint hook** — each icon gets `hooksecurefunc("SetPoint", ...)` overriding Blizzard's positioning with cached `_arTargetX` / `_arTargetY`. Guard flag `_arSettingPos` prevents recursion.
- **Edit Mode panel** — hooks `EditModeManagerFrame:SelectSystem`. Panel anchors below `EditModeSystemSettingsDialog`.
- **Combat safety** — `ApplyLayout()` checks `InCombatLockdown()` and defers; `PLAYER_REGEN_ENABLED` flushes pending layout.

---

## Rules

### Code Style

- Pure Lua only — no XML frames
- Local variables at file top; functions as `local function`
- Cross-file sharing via `ns` only — never create addon globals besides `AuraRowsDB`
- Only expose on `ns` what another file actually needs
- WoW naming: PascalCase for frame methods, camelCase for local vars
- Always use `hooksecurefunc` — never replace original Blizzard functions

### Adding a New Setting

Every new setting must touch **all** of these:

1. `ns.DEFAULTS` in `Config.lua`
2. Slash command handler in `Core.lua`
3. `ApplyLayout()` in `Core.lua`
4. Edit Mode panel in `EditMode.lua`
5. Saved Variables table in `docs/README.md`
6. Version bump in `AuraRows.toc` + entry in `docs/CHANGELOG.md`

### Versioning

- Bump `## Version` in `AuraRows.toc` on every release
- Add a `docs/CHANGELOG.md` entry following Keep A Changelog format

---

## Pitfalls

### SetPoint Recursion ⚠️
Always set `frame._arSettingPos = true` before calling `SetPoint` from our code, then reset to `false`. Missing this causes infinite recursion and a stack overflow.

### Hook Scope ⚠️
`CooldownViewerItemDataMixin` hooks fire for **all** CooldownViewer instances (spell cooldowns too). Always guard with `GetParent() == viewer`.

### Combat Lockdown
Never call `SetPoint` on frames during `InCombatLockdown()`. Treat CDM children as protected for safety.

### Debounce Timing
Use `C_Timer.NewTimer(0, ...)` for debounced layout — not `C_Timer.After(0)`. They are not interchangeable.

### Viewer Recreation
`BuffIconCooldownViewer` can be replaced across loading screens. `TryInit()` compares against the cached reference and re-installs hooks if it changes.

### Edit Mode Anchoring
`EditModeSystemSettingsDialog` may not exist. Always check before anchoring.

### Cross-file `ns` Calls
Nil-guard all cross-file `ns` calls:
```lua
if ns.SetupEditMode then ns.SetupEditMode() end
```

### Secret Values (12.0)
AuraRows is mostly low-risk (we only reposition frames). But:
- Do NOT read `cooldownID` values during restricted gameplay
- `SetPoint` / `ClearAllPoints` remain usable on CDM children

---

## Testing

No automated tests — manually test in-game.

**Required test scenarios:**
- Add / remove buffs
- Change `maxPerRow` mid-combat
- Enter / exit Edit Mode
- `/reload`
- Zone transitions
- Verify with other CDM addons disabled

**Secret Values CVars for testing:**
```
secretAurasForced
secretCooldownsForced
secretUnitIdentityForced
```
