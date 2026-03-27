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
- **Damage Meter Embed** — embeds Details!, Skada, or Blizzard's native meter into ElvUI's right chat panel; supports dual-window (damage + healing split left/right), combat-only mode, and keybind toggle

## Commands

- `/tp` — Open settings panel
- `/tokukop` — Open settings panel (alias)
- `/tpembed` — Toggle damage meter embed on/off

## SavedVariables

Settings are stored in `TokukoPDB`, organized by module:
- `TokukoPDB.Drinking` — Drinking module settings
- `TokukoPDB.Tooltip` — Tooltip module settings
- `TokukoPDB.Embed` — Embed module settings

---

## Not Possible in 12.0

### Mana / OOM Alert
Reading player mana via `UnitPower` is permanently blocked in 12.0 — it returns a secret value
that crashes any addon attempting arithmetic on it. Blizzard explicitly stated that primary
resources (mana, health) will remain secret indefinitely to prevent combat automation.
`UnitPowerMax` is readable but `UnitPower` (current value) is not, making a percentage
calculation impossible. This module has been dropped until Blizzard provides a safe API.

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
local function SafeReadAuras()
  if InCombatLockdown() then return end

  local i = 1
  while true do
    local auraData = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
    if not auraData then break end

    local instanceID = auraData.auraInstanceID
    local isSecret = instanceID and C_Secrets and
                     C_Secrets.ShouldUnitAuraInstanceBeSecret("player", instanceID)

    if not isSecret then
      -- spellId is always safe to read
      local spellId = auraData.spellId

      -- name requires pcall since it may be a secret string
      local ok, nameLower = pcall(function()
        return auraData.name and auraData.name:lower() or nil
      end)

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

Follow the existing Drinking or Tooltip section pattern using `MakeCheckbox` / `MakeEditBox`
in the `/tp` window.

---

## WoW 12.0+ Development Rules

Always check https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes before using any API
that touches auras, unit data, or resources. These rules apply to every module:

### Secret Values — What Is and Isn't Readable
| Data | Secret? | Safe approach |
|---|---|---|
| `UnitPower` (current mana/health) | ✅ Always secret | Not possible — drop the feature |
| `UnitPowerMax` | ❌ Safe for player | Read directly |
| `auraData.auraInstanceID` | ❌ Always safe | Read directly |
| `auraData.spellId` | ❌ Always safe | Read directly |
| `auraData.name` | ✅ May be secret | `pcall` around `:lower()` / `:find()` |
| Other aura fields | ✅ May be secret | Check `C_Secrets` first, then `pcall` |

### Removed in 12.0 — Do Not Use
| Old API | Replacement |
|---|---|
| `LE_PARTY_CATEGORY_INSTANCE` global | Use raw value `2` — `IsInGroup(2)`, `IsInGroup(LE_PARTY_CATEGORY_INSTANCE)` crashes |
| `COMBAT_LOG_EVENT_UNFILTERED` (for enemy data) | Gone. Use Blizzard's native boss timers |
| `UnitAura()` by name | Use `C_UnitAuras.GetAuraDataByIndex()` |

### Aura Safety
- **Never use `GetBuffDataByIndex`** — removed in 12.0, use `C_UnitAuras.GetAuraDataByIndex(unit, index, "HELPFUL")`
- **Always check `InCombatLockdown()` first** — bail out early if you don't need to run in combat
- **Always check `C_Secrets.ShouldUnitAuraInstanceBeSecret(unit, instanceID)`** before reading any aura field other than `auraInstanceID` and `spellId`
- **Always `pcall` string methods** on aura name fields — secret strings crash on `:lower()`, `:find()` etc.
- **Always handle `updateInfo.isFullUpdate`** in `UNIT_AURA` handlers — when true, `addedAuras` and `removedAuraInstanceIDs` are absent; reset tracked state safely

### Frame / UI Safety
- **Never call `SetParent`, `ClearAllPoints`, or `SetPoint` during `InCombatLockdown()`** — this causes taint on non-secure frames and can produce Lua errors mid-pull. Queue the operation and execute on `PLAYER_REGEN_ENABLED`
- **`C_Timer.After` is safe** — unaffected by 12.0 restrictions
- **`HookScript` is safe** — pure UI, not blocked

### Combat Safety
- **Never automate combat actions** — blocked by Blizzard and ban-worthy
- **Use `PLAYER_REGEN_DISABLED` / `PLAYER_REGEN_ENABLED`** for combat state detection — stable and unchanged in 12.0
- **`InCombatLockdown()`** is always safe and is your best guard

### General
- **Always check the 12.0 API changes page first** before using any API you're unsure about
- **`C_Secrets` may not exist on all clients** — always guard: `C_Secrets and C_Secrets.SomeFunction()`
- **Emote tokens must be uppercase** — `DoEmote("OOM")` not `DoEmote("oom")`
- **`pcall` defensively** around any string or arithmetic operations on engine-sourced data

---

## Reference Links

- [WoW 12.0 API Changes](https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes) — **check this first**
- [World of Warcraft API](https://warcraft.wiki.gg/wiki/World_of_Warcraft_API)
- [ElvUI Plugin Development](https://github.com/tukui-org/ElvUI/wiki/plugin-installer-template)
- [ElvUI Source](https://github.com/tukui-org/ElvUI)
