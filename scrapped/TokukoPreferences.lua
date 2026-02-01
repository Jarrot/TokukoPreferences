-- TokukoPreferences
-- Performs /oom when leaving combat if mana < threshold.
-- Settings panel includes: Enable, Threshold %, Only in Group/Instance.

local ADDON_NAME = ...

-- ===============================
-- SavedVariables & Defaults
-- ===============================
TokukoPreferencesDB = TokukoPreferencesDB or {}

local DEFAULTS = {
  enabled = true,
  threshold = 20,     -- percent
  onlyInGroup = true, -- only trigger when grouped (party/raid/instance)
}

local function MergeDefaults(db, defs)
  for k, v in pairs(defs) do
    if type(v) == "table" then
      db[k] = db[k] or {}
      MergeDefaults(db[k], v)
    elseif db[k] == nil then
      db[k] = v
    end
  end
end

local function Clamp(val, min, max)
  if val < min then return min end
  if val > max then return max end
  return val
end

-- ===============================
-- Core Logic
-- ===============================
local function IsManaUser()
  -- Power type 0 is mana
  local powerType = UnitPowerType("player")
  return powerType == 0
end

local function GetManaPercent()
  local cur = UnitPower("player", 0)
  local max = UnitPowerMax("player", 0)
  if not max or max == 0 then return 100 end
  return (cur / max) * 100
end

-- Group/instance context check
local function InGroupContext()
  -- Party or raid
  if IsInRaid() or IsInGroup() then
    return true
  end
  -- Instance group (LFG)
  if IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
    return true
  end
  return false
end

-- Debounce to avoid rapid double-fires
local lastTrigger = 0
local function ShouldTrigger()
  local t = GetTime()
  if (t - lastTrigger) < 1.0 then return false end
  lastTrigger = t
  return true
end

local function TryEmote()
  if not TokukoPreferencesDB.enabled then return end
  if TokukoPreferencesDB.onlyInGroup and not InGroupContext() then return end
  if not IsManaUser() then return end
  if UnitIsDeadOrGhost("player") or UnitInVehicle("player") then return end

  local mp = GetManaPercent()
  if mp < (TokukoPreferencesDB.threshold or DEFAULTS.threshold) then
    -- Built-in /oom emote (localized)
    DoEmote("OOM")
  end
end

-- Event bootstrap
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self, event)
  if event == "PLAYER_LOGIN" then
    -- Initialize DB
    TokukoPreferencesDB = TokukoPreferencesDB or {}
    MergeDefaults(TokukoPreferencesDB, DEFAULTS)
    TokukoPreferencesDB.threshold = Clamp(tonumber(TokukoPreferencesDB.threshold) or DEFAULTS.threshold, 1, 100)
    if type(TokukoPreferencesDB.onlyInGroup) ~= "boolean" then
      TokukoPreferencesDB.onlyInGroup = DEFAULTS.onlyInGroup
    end

    -- Register combat-exit listener
    self:RegisterEvent("PLAYER_REGEN_ENABLED")

    -- Create settings UI (Dragonflight/TWW)
    if Settings and Settings.RegisterAddOnCategory then
      local category = CreateTokukoPreferencesOptions()
      Settings.RegisterAddOnCategory(category)
    end

    -- Swap to runtime handler
    self:SetScript("OnEvent", function(_, ev)
      if ev == "PLAYER_REGEN_ENABLED" then
        if ShouldTrigger() then
          TryEmote()
        end
      end
    end)
  end
end)

-- ===============================
-- Settings Panel (Dragonflight/TWW)
-- ===============================
function CreateTokukoPreferencesOptions()
  local category = Settings.RegisterVerticalLayoutCategory("TokukoPreferences")

  -- Helper to bind boolean checkbox to SavedVariables
  local function AddCheckbox(varKey, label, tooltip, defaultOn)
    local variable = "TokukoPreferences_" .. varKey
    local default = defaultOn and true or false
    
    -- Register setting with the correct API signature
    local setting = Settings.RegisterAddOnSetting(category, variable, varKey, TokukoPreferencesDB, type(default), default)
    
    -- Create checkbox control
    local initializer = Settings.CreateCheckbox(category, setting, tooltip)
    initializer:SetParentInitializer(category)
  end

  -- Helper to add threshold slider (1–100)
  local function AddThresholdSlider()
    local variable = "TokukoPreferences_Threshold"
    local default = DEFAULTS.threshold
    
    -- Register setting with the correct API signature
    local setting = Settings.RegisterAddOnSetting(category, variable, "threshold", TokukoPreferencesDB, type(default), default)
    
    local options = Settings.CreateSliderOptions(1, 100, 1)
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(v)
      return string.format("%d%%", v)
    end)

    local initializer = Settings.CreateSlider(category, setting, options, "Trigger /oom when mana is below this percent on exiting combat.")
    initializer:SetParentInitializer(category)
  end

  -- 1) Enabled checkbox
  AddCheckbox("enabled", "Enabled", "Toggle the addon on/off.", DEFAULTS.enabled)

  -- 2) Only in Group/Instance checkbox
  AddCheckbox(
    "onlyInGroup",
    "Only in Group/Instance",
    "Only perform /oom when you are in a party, raid, or instance group (prevents solo emotes).",
    DEFAULTS.onlyInGroup
  )

  -- 3) Threshold slider
  AddThresholdSlider()

  return category
end
