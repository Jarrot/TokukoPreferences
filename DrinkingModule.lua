-- DrinkingModule.lua
-- Announces in chat when you start drinking/eating

local ADDON_NAME = ...
local TokukoP = TokukoP

local DrinkingModule = {}
TokukoP.modules.Drinking = DrinkingModule

-- ===============================
-- Module Defaults
-- ===============================
DrinkingModule.DEFAULTS = {
  enabled = true,
  message = "eating nam nam",
  completeMessage = "nam nam done!",
  announceComplete = true,
  onlyInGroup = true,
}

-- ===============================
-- State
-- ===============================

local isDrinking = false
local drinkStartTime = 0
local drinkAuraInstanceID = nil  -- track which specific aura instance is our drink buff

-- ===============================
-- Helper Functions
-- ===============================

local DRINK_NAME_PATTERNS = { "food", "drink", "refreshment", "eating", "drinking" }
local WELLFED_PATTERN = "well fed"

local function IsDrinkAura(auraData)
  if not auraData then return false, false end

  local instanceID = auraData.auraInstanceID
  local isSecret = instanceID and C_Secrets and
                   C_Secrets.ShouldUnitAuraInstanceBeSecret("player", instanceID)
  if isSecret then return false, false end

  -- spellId is always safe
  local spellId = auraData.spellId

  -- name requires pcall
  local ok, nameLower = pcall(function()
    return auraData.name and auraData.name:lower() or nil
  end)

  if ok and nameLower then
    if nameLower:find(WELLFED_PATTERN) then
      return false, true  -- well fed, not actively eating
    end
    for _, pattern in ipairs(DRINK_NAME_PATTERNS) do
      if nameLower:find(pattern) then
        return true, false
      end
    end
  end

  return false, false
end

local function InGroupContext()
  if IsInRaid() or IsInGroup() then return true end
  if LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return true end
  return false
end

local function SendToChat(message)
  if IsInRaid() then
    SendChatMessage(message, "RAID")
  elseif LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
    SendChatMessage(message, "INSTANCE_CHAT")
  elseif IsInGroup() then
    SendChatMessage(message, "PARTY")
  else
    print("[TokukoP] " .. message)
  end
end

-- ===============================
-- Aura Event Handlers
-- ===============================

local function OnAurasAdded(addedAuras)
  if isDrinking then return end  -- already tracking a drink, ignore new adds

  local db = TokukoPDB.Drinking
  for _, auraData in ipairs(addedAuras) do
    local isDrink, _ = IsDrinkAura(auraData)
    if isDrink then
      isDrinking = true
      drinkStartTime = GetTime()
      drinkAuraInstanceID = auraData.auraInstanceID

      if db.enabled and (not db.onlyInGroup or InGroupContext()) then
        SendToChat(db.message or DrinkingModule.DEFAULTS.message)
      end
      return  -- only need to find one drink buff
    end
  end
end

local function OnAurasRemoved(removedAuraInstanceIDs)
  if not isDrinking then return end  -- not drinking, nothing to check

  local db = TokukoPDB.Drinking
  for _, instanceID in ipairs(removedAuraInstanceIDs) do
    if instanceID == drinkAuraInstanceID then
      -- Our specific drink buff was removed
      local timeElapsed = GetTime() - drinkStartTime

      if db.enabled and db.announceComplete and (not db.onlyInGroup or InGroupContext()) then
        if timeElapsed >= 8 then
          SendToChat(db.completeMessage or DrinkingModule.DEFAULTS.completeMessage)
        end
      end

      isDrinking = false
      drinkStartTime = 0
      drinkAuraInstanceID = nil
      return
    end
  end
end

-- ===============================
-- Module Interface
-- ===============================

function DrinkingModule.Initialize()
  TokukoPDB.Drinking = TokukoPDB.Drinking or {}
  TokukoP.MergeDefaults(TokukoPDB.Drinking, DrinkingModule.DEFAULTS)
end

function DrinkingModule.RegisterEvents(frame)
  frame:RegisterUnitEvent("UNIT_AURA", "player")
end

function DrinkingModule.OnEvent(event, ...)
  if event == "UNIT_AURA" then
    -- Ignore all aura events in combat - you can't eat/drink in combat
    if InCombatLockdown() then return end

    local unit, updateInfo = ...
    if unit ~= "player" or not updateInfo then return end

    -- Only process adds if not already drinking
    if not isDrinking and updateInfo.addedAuras then
      OnAurasAdded(updateInfo.addedAuras)
    end

    -- Only process removes if we are tracking a drink buff
    if isDrinking and updateInfo.removedAuraInstanceIDs then
      OnAurasRemoved(updateInfo.removedAuraInstanceIDs)
    end
  end
end
