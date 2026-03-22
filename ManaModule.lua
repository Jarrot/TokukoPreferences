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
  threshold = 20,    -- announce at or below this % mana
  onlyInGroup = true,
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
  -- UnitPowerMax is non-secret for player in 12.0, but UnitPower (current) is still secret.
  -- Use pcall around the arithmetic to avoid taint crashes.
  local max = UnitPowerMax("player", Enum.PowerType.Mana)
  if not max or max == 0 then return 100 end

  local ok, pct = pcall(function()
    local current = UnitPower("player", Enum.PowerType.Mana)
    return (current / max) * 100
  end)

  if ok then return pct end
  return 100  -- If we can't read it, assume full mana (safe default, won't false-trigger)
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

  if not PlayerUsesMana() then return end

  local pct = GetManaPercent()
  local threshold = db.threshold or ManaModule.DEFAULTS.threshold
  local inValidContext = not db.onlyInGroup or InGroupContext()

  if pct <= threshold and not isOOM then
    isOOM = true
    if inValidContext then
      DoEmote("oom")
    end
  elseif pct > threshold and isOOM then
    isOOM = false
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
