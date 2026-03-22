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

local isDrinking = false
local drinkStartTime = 0

-- Known food/drink spell IDs (primary detection method - spell IDs are never secret)
local DRINK_SPELL_IDS = {
  [430]    = true,  -- Drink
  [433]    = true,  -- Food
  [1137]   = true,  -- Drink (higher level)
  [192002] = true,  -- Food & Drink
  [167152] = true,  -- Refreshment
  [193397] = true,  -- Refreshment (alternate)
  [430752] = true,  -- Dreambound Refreshment (Dragonflight+)
  [459284] = true,  -- Well-Fed (The War Within)
}

-- Name patterns used only when aura is NOT secret (out of combat, non-instance)
local DRINK_NAME_PATTERNS = { "food", "drink", "refreshment", "eating", "drinking" }
local WELLFED_PATTERN = "well fed"

local function HasDrinkBuff()
  local hasDrink = false
  local hasWellFed = false
  local i = 1

  while true do
    -- GetAuraDataByIndex replaces GetBuffDataByIndex in 12.0
    local auraData = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
    if not auraData then break end

    local instanceID = auraData.auraInstanceID

    -- AuraInstanceIDs are never secret, so we can safely check this
    if instanceID and C_Secrets.ShouldUnitAuraInstanceBeSecret("player", instanceID) then
      -- This aura's fields are secret — skip name/spellId checks on it
      i = i + 1
    else
      local spellId = auraData.spellId

      -- SpellID check first (most reliable, never secret for food/drink)
      if spellId and DRINK_SPELL_IDS[spellId] then
        hasDrink = true
      else
        -- Name check only when safe (aura is not secret)
        local name = auraData.name
        if name and not issecretvalue(name) then
          local nameLower = name:lower()
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

      i = i + 1
    end

    if hasDrink then break end
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
