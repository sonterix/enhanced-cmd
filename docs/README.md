# AuraRows

Multi-row layout for the Cooldown Manager aura tracker in World of Warcraft (Midnight expansion).

Blizzard's Cooldown Manager displays tracked buffs/debuffs via `BuffIconCooldownViewer` as a single horizontal row. AuraRows repositions those icons into a configurable grid with multiple rows.

## Features

- **Multiple rows** for the aura tracker (Tracked Buffs) instead of one long horizontal line
- **Configurable icons per row** (1–40)
- **Growth direction** — rows grow downward or upward from the anchor point
- **Edit Mode integration** — settings panel appears when "Tracked Buffs" is selected in Edit Mode, anchored to Blizzard's settings dialog
- **Slash commands** — `/ar` or `/aurarows` for quick configuration from chat
- **Combat safe** — defers layout changes during combat, applies them when combat ends
- **Zero dependencies** — no Ace3, no external libraries

## Installation

Copy the `AuraRows` folder into your WoW AddOns directory:

```
World of Warcraft/_retail_/Interface/AddOns/AuraRows/
```

## Usage

### Slash Commands

| Command | Description |
|---|---|
| `/ar` | Show current settings |
| `/ar rows <1-40>` | Set the number of icons per row |
| `/ar grow <UP\|DOWN>` | Set which direction new rows grow |

### Edit Mode

1. Open Edit Mode (Escape > Edit Mode)
2. Click on the **Tracked Buffs** frame
3. The AuraRows settings panel appears below Blizzard's settings dialog
4. Adjust the **Per Row** slider and **Growth Direction** dropdown
5. Changes apply live

## Saved Variables

Settings are stored in `AuraRowsDB` and persist across sessions:

| Key | Type | Default | Description |
|---|---|---|---|
| `maxPerRow` | number | `8` | Maximum icons before wrapping to a new row |
| `growDirection` | string | `"DOWN"` | `"DOWN"` = rows grow downward, `"UP"` = rows grow upward |

---

## Technical Reference

### How It Works

AuraRows hooks into Blizzard's Cooldown Manager lifecycle to reposition aura icon frames into a grid layout. The addon does **not** create its own frames — it repositions Blizzard's existing `BuffIconCooldownViewer` children.

### Architecture Overview

```
ADDON_LOADED
  ├── Initialize SavedVariables (AuraRowsDB)
  └── Register slash commands

PLAYER_ENTERING_WORLD
  └── TryInit()
        ├── Find BuffIconCooldownViewer (poll up to 10s if not ready)
        ├── InstallHooks() — hook CDM lifecycle events
        ├── SetupEditMode() — hook Edit Mode selection
        └── ApplyLayout() — initial grid positioning

CDM Event (aura gained/lost/changed)
  └── ScheduleLayout() — debounced C_Timer.After(0)
        └── ApplyLayout() — reposition all visible icons into grid

Blizzard repositions a frame
  └── SetPoint hook on each frame — overrides with our grid position

PLAYER_REGEN_ENABLED
  └── Flush any layout deferred during combat
```

### Key Design Decisions

#### Debounced Layout via `C_Timer.After(0)`

All CDM hooks schedule layout through `ScheduleLayout()` which uses `C_Timer.NewTimer(0, ...)`. This ensures our repositioning runs **after** Blizzard's layout pass completes in the same frame. The timer is debounced — multiple CDM events in the same frame result in a single layout pass.

#### SetPoint Hook (Not ClearAllPoints)

Each aura icon frame gets a `hooksecurefunc` on `SetPoint`. When Blizzard repositions a frame, our hook fires **after** the original `SetPoint` call and overrides it with our grid position. We hook `SetPoint` instead of `ClearAllPoints` because `hooksecurefunc` fires after the original — hooking `ClearAllPoints` would set our position first, then Blizzard's `SetPoint` would overwrite it.

#### Guard Flags to Prevent Recursion

Each frame stores `_arSettingPos` (boolean guard) and `_arTargetX` / `_arTargetY` (cached grid position). When our code calls `SetPoint`, the guard flag prevents the hook from re-entering. This avoids infinite recursion since our `SetPoint` call triggers our own hook.

#### No Frame Re-parenting

Unlike ArcUI's CDMGroups system which re-parents frames to custom containers, AuraRows keeps all frames as children of `BuffIconCooldownViewer`. This is simpler and avoids potential issues with CDM's internal frame tracking.

#### Scoped Mixin Hooks

`CooldownViewerItemDataMixin.SetCooldownID` and `ClearCooldownID` fire for **all** CooldownViewer instances (Essential Cooldowns, Utility Cooldowns, Tracked Buffs). Our hooks check `GetParent() == viewer` to only trigger layout for the aura tracker, avoiding unnecessary work when spell cooldowns change.

#### Viewer Recreation Handling

`TryInit()` detects if `BuffIconCooldownViewer` has been replaced (e.g., after a UI reload or zone transition) by comparing the new reference against the cached one. If different, it resets hooks and re-installs everything.

### Combat Safety

`ApplyLayout()` checks `InCombatLockdown()` at the top. If true, it sets `pendingLayout = true` and returns. When combat ends (`PLAYER_REGEN_ENABLED`), the pending layout is flushed. The `BuffIconCooldownViewer` children are likely not protected frames, so this is a safety net rather than a strict requirement.

### Edit Mode Integration

The addon hooks `EditModeManagerFrame:SelectSystem(systemFrame)` to detect when the user clicks on the Tracked Buffs frame in Edit Mode. The settings panel appears only for this frame and hides when another frame is selected, when the selection is cleared, or when Edit Mode is exited. The panel anchors below Blizzard's `EditModeSystemSettingsDialog` if available, falling back to anchoring above the viewer frame.

### Blizzard API Dependencies

| API | Usage |
|---|---|
| `_G["BuffIconCooldownViewer"]` | Access the aura tracker frame |
| `CooldownViewerMixin.OnAcquireItemFrame` | Detect new icon frames |
| `CooldownViewerItemDataMixin.SetCooldownID` | Detect aura assignment |
| `CooldownViewerItemDataMixin.ClearCooldownID` | Detect aura removal |
| `CooldownViewerSettings:GetLayoutManager()` | Detect CDM layout changes |
| `EventRegistry "CooldownViewerSettings.OnDataChanged"` | Detect CDM data changes |
| `EditModeManagerFrame:SelectSystem` | Detect Edit Mode frame selection |
| `EditModeManagerFrame:ClearSelectedSystem` | Detect Edit Mode deselection |
| `EditModeManagerFrame:ExitEditMode` | Detect Edit Mode exit |
| `C_Timer.NewTimer` / `C_Timer.NewTicker` | Debouncing and deferred init |

### Known Limitations

- **Addon conflicts** — Other addons that reposition CDM frames (ArcUI CDMGroups, EnhanceQoL CooldownPanels) will conflict. Disable their aura positioning features when using AuraRows.
- **Frame ordering** — Icons appear in frame creation order, not necessarily the order Blizzard displays them. A future version may sort by `cooldownID`.
- **Patch fragility** — Hooking Blizzard frames directly means WoW patches can break things. All hooks have existence checks and the Edit Mode integration is wrapped in `pcall` for graceful degradation.
- **OptionsSliderTemplate** — May be deprecated in a future Midnight patch. The slider would need updating to a newer template if this happens.

## File Structure

```
AuraRows/
  AuraRows.toc       -- Addon metadata, Interface version, SavedVariables
  AuraRows.lua        -- Entire addon implementation (~420 lines)
  docs/
    README.md         -- This file
    CHANGELOG.md      -- Version history
```
