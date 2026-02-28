# API_REFERENCE.md — AuraRows Blizzard API Reference

> Reference for Midnight (12.0) WoW APIs used by or relevant to AuraRows.
> This file is **not** loaded by Claude Code automatically — reference it manually when doing API-specific work.

---

## TOC Interface Version

Addons **must** declare `## Interface: 120000` (or higher). There is no player override — strictly enforced in 12.0.

---

## Cooldown Manager System (`Blizzard_CooldownViewer`)

Source: `Interface/AddOns/Blizzard_CooldownViewer/`

Three viewer instances: Essential Cooldowns, Utility Cooldowns, Tracked Buffs (`BuffIconCooldownViewer`).

### CooldownViewerMixin

| Method | Notes |
|---|---|
| `OnAcquireItemFrame(frame)` | Called when a new icon is acquired. Primary hook point. |
| `RefreshData()` | Refreshes all displayed data. |
| `CacheChargeValues()` | ⚠️ Known 12.0 bug — crashes with Secret charge values. |

### CooldownViewerItemDataMixin

| Method | Notes |
|---|---|
| `SetCooldownID(cooldownID)` | Assigns a spell/aura to an icon. |
| `ClearCooldownID()` | Clears the tracked spell. |
| `SpellIDMatchesAnyAssociatedSpellIDs()` | Checks if a spell ID matches associated spells. |
| `GetAuraData()` | Retrieves aura data. |

### Icon Frame Child Properties

```lua
child.cooldownID     -- tracked spell ID
child.spellID        -- spell ID
child.layoutIndex    -- layout ordering index
child.Cooldown       -- cooldown overlay frame
child.Icon           -- icon texture
child.ChargeCount    -- charge count FontString
child.CooldownFlash  -- flash overlay
child.OutOfRange     -- out-of-range overlay
```

### CooldownViewerSettings

```lua
CooldownViewerSettings:GetLayoutManager()
EventRegistry "CooldownViewerSettings.OnDataChanged"  -- fires on CDM settings change
```

### Enums (12.0)

```lua
Enum.CooldownViewerBarContent
Enum.CooldownViewerCategory       -- Essential, Utility, Hidden by Default
Enum.CooldownViewerIconDirection
Enum.CooldownViewerOrientation
Enum.CooldownViewerVisibleSetting
```

---

## Edit Mode API

```lua
EditModeManagerFrame:SelectSystem(systemFrame)
EditModeManagerFrame:ClearSelectedSystem()
EditModeManagerFrame:ExitEditMode()

-- Hook points (all via hooksecurefunc):
hooksecurefunc(EditModeManagerFrame, "SelectSystem", function(self, systemFrame) end)
hooksecurefunc(EditModeManagerFrame, "ClearSelectedSystem", function(self) end)
hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function(self) end)
```

**`EditModeSystemSettingsDialog`** — global frame for Blizzard's settings panel. AuraRows anchors below it. Always check existence via `_G["EditModeSystemSettingsDialog"]`.

```lua
C_EditMode.GetLayouts()
C_EditMode.SaveLayouts()
C_EditMode.SetActiveLayout()
-- Event: EDIT_MODE_LAYOUTS_UPDATED
```

---

## C_Timer API

```lua
C_Timer.After(seconds, callback)                      -- one-shot, no cancel handle
C_Timer.NewTimer(seconds, callback) -> handle         -- one-shot with cancel handle ← use this
C_Timer.NewTicker(seconds, callback [, iterations])   -- repeating with cancel handle

handle:Cancel()
handle:IsCancelled()
```

`C_Timer.NewTimer(0, fn)` fires next frame, after Blizzard's layout pass. AuraRows uses this for debounced layout. Do **not** swap with `C_Timer.After`.

---

## Frame API

### SetPoint / ClearAllPoints

```lua
frame:SetPoint(point [, relativeTo [, relativePoint]] [, offsetX, offsetY])
frame:ClearAllPoints()
```

**12.0 Secret Anchors:** Frames anchored to objects with Secret Aspects get Secret Anchors that propagate down the chain, blocking position access. Should not affect CDM children in normal usage.

### hooksecurefunc

```lua
hooksecurefunc([tbl,] functionName, hookfunc)
```

- Cannot be unhooked — only a UI reload removes hooks
- Multiple hooks stack
- Hook return values are discarded
- **11.0+ restriction:** Cannot hook 22 core Lua functions (`getmetatable`, `setmetatable`, `pairs`, `type`, `pcall`, `xpcall`, `select`, `next`, `unpack`, `wipe`, `rawget`, `rawset`, etc.)
- All AuraRows hooks are on mixin/frame methods — not affected

---

## EventRegistry

```lua
EventRegistry:RegisterCallback("EventName", callbackFunc [, owner])
EventRegistry:UnregisterCallback("EventName", owner)
EventRegistry:RegisterFrameEventAndCallback("FRAME_EVENT", callbackFunc [, owner], ...)
EventRegistry:TriggerEvent("EventName", ...)
```

---

## Deprecated Templates — Migration Required

### OptionsSliderTemplate → MinimalSliderWithSteppersTemplate

`OptionsSliderTemplate` deprecated in 10.0.0. Replacement:

```lua
local slider = CreateFrame("Frame", nil, parent, "MinimalSliderWithSteppersTemplate")
slider:SetWidth(250)
slider:Init(initialValue, minValue, maxValue, steps, formatters)
slider:RegisterCallback("OnValueChanged", function(self, value) end, slider)
```

Note: Uses **callback system** (`RegisterCallback`), not `SetScript("OnValueChanged")`.

### UIDropDownMenuTemplate → WowStyle1DropdownTemplate

`UIDropDownMenuTemplate` deprecated in 11.0.0. `EasyMenu` and related utilities **removed**. Replacement:

```lua
local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
dropdown:SetDefaultText("Select...")
dropdown:SetupMenu(function(owner, rootDescription)
    rootDescription:CreateRadio("Option A", isSelectedFunc, setSelectedFunc, "A")
    rootDescription:CreateRadio("Option B", isSelectedFunc, setSelectedFunc, "B")
end)
-- Helpers: MenuUtil.CreateRadioMenu(), MenuUtil.CreateCheckboxMenu(), MenuUtil.CreateEnumRadioMenu()
```

---

## New 12.0 APIs (relevant subset)

```lua
C_Secrets                          -- 26+ Secret value management functions
C_RestrictedActions                -- query restriction states
C_StringUtil                       -- string utilities that work with Secrets
Region:SetAlphaFromBoolean(bool)
FrameScriptObject:HasSecretAspect()
FrameScriptObject:HasAnySecretAspect()
FrameScriptObject:HasSecretValues()
Cooldown:SetCooldownFromExpirationTime(...)
Cooldown:SetPaused(...)
Cooldown:GetCountdownFontString()
```

---

## Documentation Sources

| Resource | URL |
|---|---|
| WoW API | https://warcraft.wiki.gg/wiki/World_of_Warcraft_API |
| Patch 12.0.0 API changes | https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes |
| Patch 12.0.1 API changes | https://warcraft.wiki.gg/wiki/Patch_12.0.1/API_changes |
| Cooldown Manager | https://warcraft.wiki.gg/wiki/Cooldown_Manager |
| Edit Mode | https://warcraft.wiki.gg/wiki/Edit_Mode |
| EventRegistry | https://warcraft.wiki.gg/wiki/EventRegistry |
| hooksecurefunc | https://warcraft.wiki.gg/wiki/API_hooksecurefunc |
| C_Timer.NewTimer | https://warcraft.wiki.gg/wiki/API_C_Timer.NewTimer |
| Blizzard Menu guide | https://warcraft.wiki.gg/wiki/Blizzard_Menu_implementation_guide |
| WoW UI Source | https://github.com/gethe/wow-ui-source |
| LibEditMode | https://github.com/p3lim-wow/LibEditMode |
| Addon Changes for Midnight | https://www.wowhead.com/news/majority-of-addon-changes-finalized-for-midnight-pre-patch-whitelisted-spells-379738 |
