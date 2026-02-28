# Changelog

## [1.1.0] - 2026-02-27

### Changed
- Edit Mode panel now only appears when "Tracked Buffs" frame is selected (was: appeared on any Edit Mode entry)
- Edit Mode panel anchors below Blizzard's settings dialog instead of floating independently
- Growth direction setting changed from toggle button to dropdown select

### Technical
- Replaced `EnterEditMode`/`ExitEditMode` hooks with `SelectSystem`/`ClearSelectedSystem`/`ExitEditMode`
- Added `ShowAuraRowsPanel()` and `HideAuraRowsPanel()` helper functions
- Panel no longer movable/draggable — position is dynamic based on Blizzard dialog

## [1.0.0] - 2026-02-27

### Added
- Multi-row grid layout for BuffIconCooldownViewer (Tracked Buffs)
- Configurable icons per row (1–40) via `/ar rows <n>`
- Growth direction (UP/DOWN) via `/ar grow <direction>`
- Edit Mode floating settings panel with slider and toggle
- Combat safety — defers layout during InCombatLockdown, flushes on PLAYER_REGEN_ENABLED
- Debounced layout via C_Timer.After(0) to run after Blizzard's layout pass
- Per-frame SetPoint hook to prevent Blizzard from overriding grid positions
- Viewer recreation detection across loading screens
- Scoped CooldownViewerItemDataMixin hooks (only trigger for BuffIconCooldownViewer children)
