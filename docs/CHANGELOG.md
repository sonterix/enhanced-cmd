# Changelog

## [0.7.0] - 2026-03-03

### Added
- **Shorten Keybinds Text** toggle for Essential and Utility hotkey overlays (independently configurable)
  - When enabled (default), abbreviates key names compactly (e.g. SHIFT-PAGEUP → SPU)
  - When disabled, displays full unabbreviated key names
- Additional key abbreviations: PAGEUP/PAGEDOWN, SPACEBAR, BACKSPACE, CAPSLOCK, INSERT, DELETE, HOME, and arrow keys
- "Shorten Keybinds Text" checkbox in Edit Mode panels for Essential and Utility hotkeys
- `/ecdm essential shorten|noshorten` and `/ecdm utility shorten|noshorten` slash commands
- Tests for all new key abbreviations

### Changed
- Edit Mode hotkey panels use `[checkbox] [label]` layout for Show Keybinds row (Blizzard style)
- Status output now includes text shortening state

## [0.6.2] - 2026-03-03

### Fixed
- Keybinding overlays not appearing on Essential/Utility icons after adding, removing, or reordering cooldowns in Blizzard's CDM settings

## [0.6.1] - 2026-03-02

### Fixed
- Crash in `GetHotkeyText()` when `C_ActionBar` API is unavailable during override spell resolution
- Viewer recreation during polling window now correctly detected and re-hooked

### Changed
- Removed unnecessary `RefreshAllHotkeys()` from CDM settings change callback
- Deduplicated `RefreshAllHotkeys()` calls when multiple hotkey viewers discovered simultaneously
- Extracted shared `HookViewerChild()`, `InstallViewerHooks()`, `SortByLayoutIndex()` helpers in Core
- Extracted shared `AnchorPanelToDialog()`, `HideAllPanels()` helpers and hoisted layout constants in EditMode
- `SetupEditMode` now follows `local function` + `ns` assignment convention
- Removed unused `err` captures from `pcall()` calls

## [0.6.0] - 2026-03-02

### Added
- **Keybinding text overlay** for Essential and Utility cooldown icons
  - Displays the configured hotkey from action bars on each cooldown icon
  - Only shows for abilities placed on action bars with a keybinding assigned
  - Resolves talent overrides and spell replacements via `C_Spell.GetOverrideSpell`
  - Compact format: SHIFT → S, CTRL → C, ALT → A (e.g. "S3", "CF1")
  - Styled like Blizzard's stack count text (Arial Narrow, outline)
- **Separate hotkey settings** for Essential and Utility cooldowns (independently configurable)
  - Show/hide toggle, 9-position anchor, configurable font size (8–20) per viewer
- Separate Edit Mode panels for Essential and Utility cooldowns with checkbox + conditional settings
- `/ecdm essential` and `/ecdm utility` slash command namespaces with `show`, `hide`, `position`, and `fontsize` subcommands
- Auto-refresh on keybinding changes, action bar changes, and specialization changes

## [0.5.0] - 2026-03-02

### Added
- **Tracked Bars support** — configurable layout for the `BuffBarCooldownViewer` (Tracked Bars)
  - **Orientation**: Vertical (single column, default) or Horizontal (multi-row grid)
  - **Layout mode**: Static or Dynamic, same behavior as icon layout
  - **Conditional alignment**: Down/Up in vertical mode, Left/Center/Right in horizontal mode (dynamic only)
  - **Bars per row**: Configurable 1–40, applies in horizontal mode only
- Separate Edit Mode panel for Tracked Bars with conditional row visibility
- `/ecdm bars` slash command namespace with `orientation`, `layout`, `align`, and `perrow` subcommands
- Dual-viewer init polling — finds both icon and bar viewers independently
- `CooldownViewerSettings.OnDataChanged` now triggers relayout for both viewers
- Blizzard's "Icon Direction" setting hidden for both Tracked Buffs and Tracked Bars

### Changed
- Mixin hooks (`OnAcquireItemFrame`, `SetCooldownID`, `ClearCooldownID`) now dispatch to the correct viewer
- `/ecdm` status output now shows both icon and bar settings
- `TryInit()` handles recreation of both viewers across loading screens

## [0.4.0] - 2026-03-01

### Added
- **Layout mode setting** — Static or Dynamic layout via dropdown, slash command, and Edit Mode panel
  - **Static** (default): Icons keep their pre-configured grid positions; inactive icons leave gaps
  - **Dynamic**: Active icons pack tightly with no gaps, re-aligned per alignment setting
- `/ecdm layout <static|dynamic>` slash command
- Layout dropdown in Edit Mode panel

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
- `/ecdm align <left|center|right>` slash command
- Align dropdown in Edit Mode panel

### Changed
- Slider value text now uses `GameFontHighlightSmall` (smaller, yellow/gold — matches Tracked Buffs style)
- Growth and Align dropdowns dynamically match slider width
- "Growth Direction" label shortened to "Growth"
- Panel height increased for proper bottom padding

### Technical
- `DIRECTION_DISPLAY` and `ALIGN_DISPLAY` tables moved before slash commands for correct upvalue capture
- Alignment offset computed per-row in `ApplyLayout()`, baked into `_arTargetX`
- Dropdown widths set dynamically in `ShowEnhancedCDMPanel()` based on actual panel width

## [0.2.0] - 2026-02-27

### Changed
- Edit Mode panel now only appears when "Tracked Buffs" frame is selected (was: appeared on any Edit Mode entry)
- Edit Mode panel anchors below Blizzard's settings dialog instead of floating independently
- Growth direction setting changed from toggle button to dropdown select

### Technical
- Replaced `EnterEditMode`/`ExitEditMode` hooks with `SelectSystem`/`ClearSelectedSystem`/`ExitEditMode`
- Added `ShowEnhancedCDMPanel()` and `HideEnhancedCDMPanel()` helper functions
- Panel no longer movable/draggable — position is dynamic based on Blizzard dialog

## [0.1.0] - 2026-02-27

### Added
- Multi-row grid layout for BuffIconCooldownViewer (Tracked Buffs)
- Configurable icons per row (1–40) via `/ecdm rows <n>`
- Growth direction (UP/DOWN) via `/ecdm grow <direction>`
- Edit Mode floating settings panel with slider and toggle
- Combat safety — defers layout during InCombatLockdown, flushes on PLAYER_REGEN_ENABLED
- Debounced layout via `C_Timer.NewTimer(0, ...)` to run after Blizzard's layout pass
- Per-frame SetPoint hook to prevent Blizzard from overriding grid positions
- Viewer recreation detection across loading screens
- Scoped CooldownViewerItemDataMixin hooks (only trigger for BuffIconCooldownViewer children)
