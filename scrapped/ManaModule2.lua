-- ManaModule.lua
-- Announces /oom when player mana drops below a configurable threshold

local ADDON_NAME = ...
local TokukoP = TokukoP

local ManaModule = {}
TokukoP.modules.Mana = ManaModule

-- ===============================
-- Module Defaults
-- ===============================
ManaModule.DEFAULTS = {
  enabled = true,
  threshold = 20,
  onlyInGroup = true,
  debug = true,  -- set to false once working
}

-- ===============================
-- Helper Functions
-- ===============================

local isOOM = false

local function PlayerUsesMana()
  local powerType = UnitPowerType("player")
  return powerType == Enum.PowerType.Mana
end

local function GetManaPercent()
  local max = UnitPowerMax("player", Enum.PowerType.Mana)
  if not max or max == 0 then return nil, "max is zero or nil" end

  local ok, result = pcall(function()
    local current = UnitPower("player", Enum.PowerType.Mana)
    return (current / max) * 100
  end)

  if ok then return result, nil end
  return nil, "UnitPower is secret"
end

local function InGroupContext()
  if IsInRaid() or IsInGroup() then return true end
  if LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return true end
  return false
end

local function CheckMana()
  local db = TokukoPDB.Mana
  if not db or not db.enabled then
    isOOM = false
    return
  end

  if not PlayerUsesMana() then
    if db.debug then print("[TokukoP Mana] Player does not use mana, skipping.") end
    return
  end

  local pct, err = GetManaPercent()

  if db.debug then
    if err then
      print("[TokukoP Mana] Could not read mana: " .. err)
    else
      print(string.format("[TokukoP Mana] Mana: %.1f%% (threshold: %d%%, isOOM: %s)",
        pct, db.threshold, tostring(isOOM)))
    end
  end

  if not pct then return end  -- couldn't read mana safely, bail

  local threshold = db.threshold or ManaModule.DEFAULTS.threshold
  local inValidContext = not db.onlyInGroup or InGroupContext()

  if pct <= threshold and not isOOM then
    isOOM = true
    if db.debug then print("[TokukoP Mana] Triggering OOM emote!") end
    if inValidContext then
      DoEmote("OOM")  -- must be uppercase
    end
  elseif pct > threshold and isOOM then
    isOOM = false
    if db.debug then print("[TokukoP Mana] Recovered from OOM.") end
  end
end

-- ===============================
-- Module Interface
-- ===============================
function ManaModule.Initialize()
  TokukoPDB.Mana = TokukoPDB.Mana or {}
  TokukoP.MergeDefaults(TokukoPDB.Mana, ManaModule.DEFAULTS)
end

function ManaModule.RegisterEvents(frame)
  frame:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
end

function ManaModule.OnEvent(event, ...)
  if event == "UNIT_POWER_UPDATE" then
    local unit, powerType = ...
    if unit == "player" and powerType == "MANA" then
      CheckMana()
    end
  end
end
