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
-- Helper Functions
-- ===============================

local isDrinking = false
local drinkStartTime = 0

-- Name patterns for food/drink detection (only checked when aura is safe)
local DRINK_NAME_PATTERNS = { "food", "drink", "refreshment", "eating", "drinking" }
local WELLFED_PATTERN = "well fed"

local function TryReadName(auraData)
  -- Use pcall as a last-resort safety net against secret string access
  local ok, nameLower = pcall(function()
    return auraData.name and auraData.name:lower() or nil
  end)
  if ok then return nameLower end
  return nil
end

local function HasDrinkBuff()
  -- Never read aura fields in combat - they may be secret/tainted
  -- You can't drink in combat anyway so this is safe to skip
  if InCombatLockdown() then return false, false end

  local hasDrink = false
  local hasWellFed = false
  local i = 1

  while true do
    local auraData = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
    if not auraData then break end

    -- Check if this aura's fields are secret before touching them
    local instanceID = auraData.auraInstanceID
    local isSecret = instanceID and C_Secrets and
                     C_Secrets.ShouldUnitAuraInstanceBeSecret("player", instanceID)

    if not isSecret then
      local nameLower = TryReadName(auraData)
      if nameLower then
        if nameLower:find(WELLFED_PATTERN) then
          hasWellFed = true
        else
          for _, pattern in ipairs(DRINK_NAME_PATTERNS) do
            if nameLower:find(pattern) then
              hasDrink = true
              break
            end
          end
        end
      end
    end

    if hasDrink then break end
    i = i + 1
  end

  return hasDrink, hasWellFed
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

local function AnnounceIfDrinking()
  local db = TokukoPDB.Drinking
  if not db or not db.enabled then
    isDrinking = false
    return
  end

  local hasDrinkBuff, hasWellFed = HasDrinkBuff()
  local inValidContext = not db.onlyInGroup or InGroupContext()

  if hasDrinkBuff and not isDrinking then
    if inValidContext then
      SendToChat(db.message or DrinkingModule.DEFAULTS.message)
    end
    isDrinking = true
    drinkStartTime = GetTime()

  elseif not hasDrinkBuff and isDrinking then
    local timeElapsed = GetTime() - drinkStartTime
    if db.announceComplete and inValidContext then
      if timeElapsed >= 8 or hasWellFed then
        SendToChat(db.completeMessage or DrinkingModule.DEFAULTS.completeMessage)
      end
    end
    isDrinking = false
    drinkStartTime = 0
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
    local unit = ...
    if unit == "player" then
      AnnounceIfDrinking()
    end
  end
end
