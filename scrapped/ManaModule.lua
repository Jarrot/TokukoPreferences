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
  -- Try getting from player frame power bar (might not be secret)
  if PlayerFrame and PlayerFrame.manabar then
    local _, max = PlayerFrame.manabar:GetMinMaxValues()
    local cur = PlayerFrame.manabar:GetValue()
    if max and max > 0 and cur then
      return (cur / max) * 100
    end
  end
  
  -- Try the direct API
  local max = UnitPowerMax("player", Enum.PowerType.Mana or 0)
  if not max or max == 0 then return nil end
  
  local cur = UnitPower("player", Enum.PowerType.Mana or 0)
  if not cur then return nil end
  
  -- Try the calculation in a pcall
  local success, result = pcall(function()
    return (cur / max) * 100
  end)
  
  if success then
    return result
  end
  
  return nil  -- Can't calculate
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
  print("  Enabled:", tostring(db and db.enabled))
  print("  OnlyInGroup:", tostring(db and db.onlyInGroup))
  print("  InGroup:", tostring(InGroupContext()))
  
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
  
  if not mp then
    print("  Result: Cannot read mana (secret value restriction)")
    return
  end
  
  local threshold = db.threshold or ManaModule.DEFAULTS.threshold
  
  print("  Raw mp value:", tostring(mp), "type:", type(mp))
  
  -- Convert to string to work with secret values, then parse
  local mpStr = string.format("%.1f", mp)
  print("  After string.format:", mpStr)
  
  local mpNum = tonumber(mpStr)
  print("  After tonumber:", tostring(mpNum), "type:", type(mpNum))
  print("  Threshold:", threshold, "type:", type(threshold))
  
  print("  Mana:", mpStr .. "%", "/ Threshold:", threshold .. "%")
  
  if mpNum and mpNum < threshold then
    print("  Comparison result: BELOW threshold - triggering /oom!")
    DoEmote("OOM")
  else
    print("  Comparison result: above threshold or mpNum is nil")
    print("  mpNum:", tostring(mpNum), "threshold:", tostring(threshold))
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
      -- Small delay to let combat restrictions clear
      C_Timer.After(0.1, function()
        TryEmote()
      end)
    end
  end
end
