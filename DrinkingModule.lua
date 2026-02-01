-- DrinkingModule.lua
-- Announces in chat when you start drinking/eating

local ADDON_NAME = ...
local TokukoP = TokukoP

-- Create module
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

-- Track if we're currently drinking to avoid re-announcing
local isDrinking = false
local drinkStartTime = 0

-- Check if player has a drink/food buff
local function HasDrinkBuff()
  -- Check for Food/Drink buffs - look for the restoration effect
  for i = 1, 40 do
    -- WoW 12.0+ uses C_UnitAuras.GetBuffDataByIndex
    local auraData = C_UnitAuras.GetBuffDataByIndex("player", i)
    if not auraData then break end
    
    local name = auraData.name
    local spellId = auraData.spellId
    
    if not name then break end
    
    -- Match common drink/food buff patterns
    local nameLower = name:lower()
    if nameLower:find("food") or 
       nameLower:find("drink") or
       nameLower:find("refreshment") or
       nameLower:find("eating") or
       nameLower:find("drinking") then
      return true, false  -- Has buff, not "Well Fed"
    end
    
    -- Check for "Well Fed" completion buff
    if nameLower:find("well fed") then
      return false, true  -- No active eating, but has Well Fed
    end
    
    -- Also check by spell ID for common food/drink spells
    if spellId and (
       spellId == 430 or   -- Drink
       spellId == 433 or   -- Food
       spellId == 1137 or  -- Drink (higher level)
       spellId == 192002 or -- Food & Drink
       spellId == 167152 or -- Refreshment
       spellId == 193397    -- Refreshment (alternate)
    ) then
      return true, false
    end
  end
  
  return false, false
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

local function SendToChat(message)
  -- Send to appropriate chat channel (SAY/YELL blocked by Blizzard since 8.2.5)
  if IsInRaid() then
    SendChatMessage(message, "RAID")
  elseif IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
    SendChatMessage(message, "INSTANCE_CHAT")
  elseif IsInGroup() then
    SendChatMessage(message, "PARTY")
  else
    -- Solo, just print locally
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
  
  -- Check if in valid context for announcement
  local inValidContext = not db.onlyInGroup or InGroupContext()
  
  -- Only announce when we START drinking (transition from not drinking to drinking)
  if hasDrinkBuff and not isDrinking then
    if inValidContext then
      local message = db.message or DrinkingModule.DEFAULTS.message
      SendToChat(message)
    end
    
    isDrinking = true
    drinkStartTime = GetTime()
    
  elseif not hasDrinkBuff and isDrinking then
    -- Buff is gone, we stopped drinking
    local timeElapsed = GetTime() - drinkStartTime
    
    -- If we drank for at least 8 seconds or have Well Fed buff, announce completion
    if db.announceComplete and inValidContext then
      if timeElapsed >= 8 or hasWellFed then
        local message = db.completeMessage or DrinkingModule.DEFAULTS.completeMessage
        SendToChat(message)
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
  -- Initialize module settings
  TokukoPDB.Drinking = TokukoPDB.Drinking or {}
  TokukoP.MergeDefaults(TokukoPDB.Drinking, DrinkingModule.DEFAULTS)
  
  if type(TokukoPDB.Drinking.onlyInGroup) ~= "boolean" then
    TokukoPDB.Drinking.onlyInGroup = DrinkingModule.DEFAULTS.onlyInGroup
  end
  
  if type(TokukoPDB.Drinking.announceComplete) ~= "boolean" then
    TokukoPDB.Drinking.announceComplete = DrinkingModule.DEFAULTS.announceComplete
  end
  
  if type(TokukoPDB.Drinking.message) ~= "string" then
    TokukoPDB.Drinking.message = DrinkingModule.DEFAULTS.message
  end
  
  if type(TokukoPDB.Drinking.completeMessage) ~= "string" then
    TokukoPDB.Drinking.completeMessage = DrinkingModule.DEFAULTS.completeMessage
  end
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
