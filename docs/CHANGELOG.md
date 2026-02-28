# Changelog

## [0.3.0] - 2026-02-28

### Fixed
- Icon spacing at non-100% Icon Size — SetPoint offsets were double-scaled by child frame scale
- Edit Mode selection border now correctly matches icon grid at all Icon Size values

### Removed
- Dead duplicate `ShouldShowSetting` patch in EditMode (Core.lua patch already covers it)
- Unused `_arOrigLayout` reference (stored but never read)
- Redundant `ScheduleLayout` orphan cleanup loop (already handled by `TryInit` wipe)
- Redundant `CooldownViewerSettings.NotifyListeners` hook (EventRegistry callback covers it)

## [0.2.2] - 2026-02-28

### Fixed
- Icon spacing now uses Blizzard's native `iconPadding` instead of hardcoded value — respects CDM padding slider
- Added `Show`/`Hide` hooks on icon frames for full Blizzard trigger coverage (catches `SetIsActive` → `SetShown` visibility changes from `UNIT_AURA`, `SPELL_UPDATE_COOLDOWN`, `PLAYER_TOTEM_UPDATE` events)
- Replaced `SetSize` hook with `Layout()` override to neutralize Blizzard's GridLayoutFrame engine

## [0.2.1] - 2026-02-27

### Added
- **Align setting** — Left, Center, or Right alignment for incomplete last rows
- `/ar align <left|center|right>` slash command
- Align dropdown in Edit Mode panel

### Changed
- Slider value text now uses `GameFontHighlightSmall` (smaller, yellow/gold — matches Tracked Buffs style)
- Growth and Align dropdowns dynamically match slider width
- "Growth Direction" label shortened to "Growth"
- Panel height increased for proper bottom padding

### Technical
- `DIRECTION_DISPLAY` and `ALIGN_DISPLAY` tables moved before slash commands for correct upvalue capture
- Alignment offset computed per-row in `ApplyLayout()`, baked into `_arTargetX`
- Dropdown widths set dynamically in `ShowAuraRowsPanel()` based on actual panel width

## [0.2.0] - 2026-02-27

### Changed
- Edit Mode panel now only appears when "Tracked Buffs" frame is selected (was: appeared on any Edit Mode entry)
- Edit Mode panel anchors below Blizzard's settings dialog instead of floating independently
- Growth direction setting changed from toggle button to dropdown select

### Technical
- Replaced `EnterEditMode`/`ExitEditMode` hooks with `SelectSystem`/`ClearSelectedSystem`/`ExitEditMode`
- Added `ShowAuraRowsPanel()` and `HideAuraRowsPanel()` helper functions
- Panel no longer movable/draggable — position is dynamic based on Blizzard dialog

## [0.1.0] - 2026-02-27

### Added
- Multi-row grid layout for BuffIconCooldownViewer (Tracked Buffs)
- Configurable icons per row (1–40) via `/ar rows <n>`
- Growth direction (UP/DOWN) via `/ar grow <direction>`
- Edit Mode floating settings panel with slider and toggle
- Combat safety — defers layout during InCombatLockdown, flushes on PLAYER_REGEN_ENABLED
- Debounced layout via `C_Timer.NewTimer(0, ...)` to run after Blizzard's layout pass
- Per-frame SetPoint hook to prevent Blizzard from overriding grid positions
- Viewer recreation detection across loading screens
- Scoped CooldownViewerItemDataMixin hooks (only trigger for BuffIconCooldownViewer children)
