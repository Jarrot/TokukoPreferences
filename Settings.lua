-- Settings.lua
-- Handles the settings panel UI

local ADDON_NAME = ...
local TokukoP = TokukoP

-- ===============================
-- Settings Panel Creation
-- ===============================
function TokukoP.CreateSettingsPanel()
  local category = Settings.RegisterVerticalLayoutCategory("TokukoPreferences")
  
  -- ===============================
  -- Mana Module Settings
  -- ===============================
  local function CreateManaSettings()
    -- Helper to add checkbox
    local function AddCheckbox(varKey, label, tooltip, defaultValue)
      local settingVar = "TokukoPref_Mana_" .. varKey
      
      local setting = Settings.RegisterAddOnSetting(
        category,
        settingVar,
        varKey,
        TokukoPDB.Mana,
        type(defaultValue),
        defaultValue
      )
      setting:SetName(label)
      
      local initializer = Settings.CreateCheckbox(category, setting, tooltip)
      initializer:SetParentInitializer(category)
    end
    
    -- Helper to add slider
    local function AddSlider(varKey, label, tooltip, min, max, step, defaultValue)
      local settingVar = "TokukoPref_Mana_" .. varKey
      
      local setting = Settings.RegisterAddOnSetting(
        category,
        settingVar,
        varKey,
        TokukoPDB.Mana,
        type(defaultValue),
        defaultValue
      )
      setting:SetName(label)
      
      local options = Settings.CreateSliderOptions(min, max, step)
      options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(v)
        return string.format("%d%%", v)
      end)
      
      local initializer = Settings.CreateSlider(category, setting, options, tooltip)
      initializer:SetParentInitializer(category)
    end
    
    -- Mana section header
    Settings.CreateSectionHeader(category, "Mana Management")
    
    -- Add settings
    AddCheckbox(
      "enabled",
      "Enable Mana Alerts",
      "Toggle mana alerts on/off.",
      TokukoP.modules.Mana.DEFAULTS.enabled
    )
    
    AddCheckbox(
      "onlyInGroup",
      "Only in Group/Instance",
      "Only perform /oom when you are in a party, raid, or instance group.",
      TokukoP.modules.Mana.DEFAULTS.onlyInGroup
    )
    
    AddSlider(
      "threshold",
      "Mana Threshold",
      "Trigger /oom when mana is below this percent after leaving combat.",
      1,
      100,
      1,
      TokukoP.modules.Mana.DEFAULTS.threshold
    )
  end
  
  -- Create all module settings
  CreateManaSettings()
  
  -- Footer
  Settings.CreateSectionHeader(category, "About")
  
  return category
end
