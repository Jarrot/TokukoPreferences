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

local function ClassifyAura(auraData)
  -- Returns: "drink", "wellfed", or nil
  if not auraData then return nil end

  local instanceID = auraData.auraInstanceID
  local isSecret = instanceID and C_Secrets and
                   C_Secrets.ShouldUnitAuraInstanceBeSecret("player", instanceID)
  if isSecret then return nil end

  local ok, nameLower = pcall(function()
    return auraData.name and auraData.name:lower() or nil
  end)

  if ok and nameLower then
    if nameLower:find(WELLFED_PATTERN) then
      return "wellfed"
    end
    for _, pattern in ipairs(DRINK_NAME_PATTERNS) do
      if nameLower:find(pattern) then
        return "drink"
      end
    end
  end

  return nil
end

-- LE_PARTY_CATEGORY_INSTANCE was removed in WoW 12.0. Use the raw enum value (2) directly.
-- IsInGroup(2) checks for instance/LFG groups. IsInGroup() alone checks normal groups.
local INSTANCE_GROUP = 2

local function InGroupContext()
  if IsInRaid() or IsInGroup() or IsInGroup(INSTANCE_GROUP) then return true end
  return false
end

local function SendToChat(message)
  if IsInRaid() then
    SendChatMessage(message, "RAID")
  elseif IsInGroup(INSTANCE_GROUP) then
    SendChatMessage(message, "INSTANCE_CHAT")
  elseif IsInGroup() then
    SendChatMessage(message, "PARTY")
  else
    print("[TokukoP] " .. message)
  end
end

local function AnnounceComplete()
  local db = TokukoPDB.Drinking
  if db.enabled and db.announceComplete and (not db.onlyInGroup or InGroupContext()) then
    SendToChat(db.completeMessage or DrinkingModule.DEFAULTS.completeMessage)
  end
  isDrinking = false
  drinkStartTime = 0
  drinkAuraInstanceID = nil
end

-- ===============================
-- Aura Event Handlers
-- ===============================

local function OnAurasAdded(addedAuras)
  local db = TokukoPDB.Drinking

  for _, auraData in ipairs(addedAuras) do
    local kind = ClassifyAura(auraData)

    if kind == "drink" and not isDrinking then
      -- Started eating/drinking
      isDrinking = true
      drinkStartTime = GetTime()
      drinkAuraInstanceID = auraData.auraInstanceID

      if db.enabled and (not db.onlyInGroup or InGroupContext()) then
        SendToChat(db.message or DrinkingModule.DEFAULTS.message)
      end

    elseif kind == "wellfed" and isDrinking then
      -- Well Fed applied while we were drinking = completed successfully
      AnnounceComplete()
      return
    end
  end
end

local function OnAurasRemoved(removedAuraInstanceIDs)
  if not isDrinking then return end

  for _, instanceID in ipairs(removedAuraInstanceIDs) do
    if instanceID == drinkAuraInstanceID then
      -- Our drink buff ended without Well Fed being applied
      local timeElapsed = GetTime() - drinkStartTime
      if timeElapsed >= 8 then
        AnnounceComplete()
      else
        -- Cancelled too early, just reset silently
        isDrinking = false
        drinkStartTime = 0
        drinkAuraInstanceID = nil
      end
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
    if InCombatLockdown() then return end

    local unit, updateInfo = ...
    if unit ~= "player" or not updateInfo then return end

    -- isFullUpdate means neither addedAuras nor removedAuraInstanceIDs is provided.
    -- Blizzard sends this when the aura state was bulk-reset (e.g. zone change).
    -- Safest response: if we were tracking a drink, silently cancel it.
    if updateInfo.isFullUpdate then
      isDrinking = false
      drinkStartTime = 0
      drinkAuraInstanceID = nil
      return
    end

    -- Check adds for both drink start and well fed completion
    if updateInfo.addedAuras then
      OnAurasAdded(updateInfo.addedAuras)
    end

    -- Check removes only if we're tracking a drink buff
    if isDrinking and updateInfo.removedAuraInstanceIDs then
      OnAurasRemoved(updateInfo.removedAuraInstanceIDs)
    end
  end
end
