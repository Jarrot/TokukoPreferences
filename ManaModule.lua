-- ManaModule.lua
-- Performs /oom when leaving combat if mana < threshold

local ADDON_NAME = ...
local TokukoP = TokukoP

-- Create module
local ManaModule = {}
TokukoP.modules.Mana = ManaModule

-- ===============================
-- Module Defaults
-- ===============================
ManaModule.DEFAULTS = {
  enabled = true,
  threshold = 20,
  onlyInGroup = true,
}

-- ===============================
-- Helper Functions
-- ===============================
local function IsManaUser()
  local powerType = UnitPowerType("player")
  return powerType == 0 -- 0 = mana
end

local function GetManaPercent()
  local cur = UnitPower("player", 0)
  local max = UnitPowerMax("player", 0)
  if not max or max == 0 then return 100 end
  return (cur / max) * 100
end

local function InGroupContext()
  if IsInRaid() or IsInGroup() then
    return true
  end
  if IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
    return true
  end
  return false
end

-- Debounce
local lastTrigger = 0
local function ShouldTrigger()
  local t = GetTime()
  if (t - lastTrigger) < 1.0 then return false end
  lastTrigger = t
  return true
end

local function TryEmote()
  local db = TokukoPDB.Mana
  
  print("|cff00ff00[TokukoP Debug]|r Checking mana after combat...")
  print("  Enabled:", db and db.enabled or "nil")
  print("  OnlyInGroup:", db and db.onlyInGroup or "nil")
  print("  InGroup:", InGroupContext())
  
  if not db or not db.enabled then 
    print("  Result: Disabled")
    return 
  end
  
  if db.onlyInGroup and not InGroupContext() then 
    print("  Result: Not in group (required)")
    return 
  end
  
  if not IsManaUser() then 
    print("  Result: Not a mana user")
    return 
  end
  
  if UnitIsDeadOrGhost("player") or UnitInVehicle("player") then 
    print("  Result: Dead or in vehicle")
    return 
  end
  
  local mp = GetManaPercent()
  local threshold = db.threshold or ManaModule.DEFAULTS.threshold
  print("  Mana:", string.format("%.1f%%", mp), "/ Threshold:", threshold .. "%")
  
  if mp < threshold then
    print("  Result: |cffff0000Triggering /oom!|r")
    DoEmote("OOM")
  else
    print("  Result: Mana above threshold")
  end
end

-- ===============================
-- Module Interface
-- ===============================
function ManaModule.Initialize()
  -- Initialize module settings
  TokukoPDB.Mana = TokukoPDB.Mana or {}
  TokukoP.MergeDefaults(TokukoPDB.Mana, ManaModule.DEFAULTS)
  
  -- Validate settings
  TokukoPDB.Mana.threshold = TokukoP.Clamp(
    tonumber(TokukoPDB.Mana.threshold) or ManaModule.DEFAULTS.threshold,
    1,
    100
  )
  
  if type(TokukoPDB.Mana.onlyInGroup) ~= "boolean" then
    TokukoPDB.Mana.onlyInGroup = ManaModule.DEFAULTS.onlyInGroup
  end
end

function ManaModule.RegisterEvents(frame)
  frame:RegisterEvent("PLAYER_REGEN_ENABLED")
end

function ManaModule.OnEvent(event, ...)
  if event == "PLAYER_REGEN_ENABLED" then
    if ShouldTrigger() then
      TryEmote()
    end
  end
end
