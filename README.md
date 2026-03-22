# TokukoPreferences

A modular WoW addon for various quality-of-life preferences and alerts.

## Structure

```
TokukoPreferences/
├── TokukoPreferences.toc  # Load order definition
├── Core.lua               # Namespace & event handling
├── DrinkingModule.lua     # Eating/drinking announcements
├── TooltipModule.lua      # ElvUI tooltip anchor switching
├── Settings.lua           # Settings UI (/tp or /tokukop)
└── README.md              # This file
```

## Current Features

- **Drinking Announcements** — announces to group chat when you start/finish eating or drinking
- **ElvUI Tooltip Anchor** — tooltip follows cursor out of combat, snaps to fixed ElvUI position in combat

## Commands

- `/tp` — Open settings panel
- `/tokukop` — Open settings panel (alias)

## SavedVariables

Settings are stored in `TokukoPDB`, organized by module:
- `TokukoPDB.Drinking` — Drinking module settings
- `TokukoPDB.Tooltip` — Tooltip module settings

---

## Adding New Modules

### 1. Create `NewModule.lua`

Use this as your starting template. It includes all the safety patterns required for WoW 12.0+.

```lua
-- NewModule.lua
local ADDON_NAME = ...
local TokukoP = TokukoP

local NewModule = {}
TokukoP.modules.NewModule = NewModule

-- ===============================
-- Module Defaults
-- ===============================
NewModule.DEFAULTS = {
  enabled = true,
  -- add more defaults here
}

-- ===============================
-- Helper Functions
-- ===============================

-- SAFE AURA READING (WoW 12.0+)
-- Always use this pattern when reading aura data.
-- Never read aura fields in combat - they may be secret/tainted.
-- Never index a value without checking it's not secret first.
local function SafeReadAuras()
  if InCombatLockdown() then return end  -- Can't be affected by most auras in combat anyway

  local i = 1
  while true do
    local auraData = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
    if not auraData then break end

    -- Check secret status using auraInstanceID (always safe to read)
    local instanceID = auraData.auraInstanceID
    local isSecret = instanceID and C_Secrets and
                     C_Secrets.ShouldUnitAuraInstanceBeSecret("player", instanceID)

    if not isSecret then
      -- Safe to read aura fields now, but still use pcall for name string access
      local ok, nameLower = pcall(function()
        return auraData.name and auraData.name:lower() or nil
      end)

      local spellId = auraData.spellId  -- spell IDs are never secret

      if ok and nameLower then
        -- use nameLower here
      end
      if spellId then
        -- use spellId here
      end
    end

    i = i + 1
  end
end

-- ===============================
-- Module Interface
-- ===============================
function NewModule.Initialize()
  TokukoPDB.NewModule = TokukoPDB.NewModule or {}
  TokukoP.MergeDefaults(TokukoPDB.NewModule, NewModule.DEFAULTS)
end

function NewModule.RegisterEvents(frame)
  -- Register events here, e.g:
  -- frame:RegisterEvent("SOME_EVENT")
  -- frame:RegisterUnitEvent("UNIT_AURA", "player")
end

function NewModule.OnEvent(event, ...)
  if event == "SOME_EVENT" then
    -- handle event
  end
end
```

### 2. Add to `TokukoPreferences.toc`

Add the new file after `Core.lua` but before `Settings.lua`:

```
Core.lua
DrinkingModule.lua
TooltipModule.lua
NewModule.lua   ← add here
Settings.lua
```

### 3. Add settings in `Settings.lua`

Follow the existing Drinking or Tooltip section pattern using `Settings.RegisterAddOnSetting` for checkboxes and `Settings.RegisterProxySetting` for strings/numbers. Or just add them to the custom `/tp` window using `MakeCheckbox` / `MakeEditBox`.

---

## WoW 12.0+ Development Rules

Always check https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes before using any API that touches auras, combat, or unit data. These rules apply to every module:

### Aura Safety
- **Never use `GetBuffDataByIndex`** — removed in 12.0, use `C_UnitAuras.GetAuraDataByIndex(unit, index, "HELPFUL")`
- **Always check `InCombatLockdown()` first** — if you don't need to run in combat, bail out early
- **Always check `C_Secrets.ShouldUnitAuraInstanceBeSecret(unit, instanceID)`** before reading any aura field other than `auraInstanceID`
- **Always use `pcall`** when calling string methods (`:lower()`, `:find()` etc.) on aura name fields — secret strings crash on indexed access
- **`spellId` and `auraInstanceID` are never secret** — safe to read without checks
- **`auraData.name` and other fields may be secret** — always guard them

### Combat Safety
- **Never automate combat actions** — Blizzard's addon restrictions block this and it's ban-worthy
- **Use `PLAYER_REGEN_DISABLED` / `PLAYER_REGEN_ENABLED`** for entering/leaving combat detection — these events are stable and unchanged in 12.0
- **`InCombatLockdown()`** is always safe to call and is your best guard for skipping logic that shouldn't run in combat

### General API
- **Always check the 12.0 API changes page** before using any API you're not 100% sure is current
- **Prefer spellID over name matching** where possible — spell IDs are stable and never secret
- **Use `pcall` defensively** around any string operations on data sourced from the game engine
- **`C_Secrets` may not exist on all clients** — always guard with `C_Secrets and C_Secrets.SomeFunction()` before calling it

---

## Reference Links

- [WoW 12.0 API Changes](https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes) — **check this first**
- [World of Warcraft API](https://warcraft.wiki.gg/wiki/World_of_Warcraft_API)
- [ElvUI Plugin Development](https://github.com/tukui-org/ElvUI/wiki/plugin-installer-template)
- [ElvUI Source](https://github.com/tukui-org/ElvUI)
