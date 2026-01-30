-- Settings.lua
-- Handles the settings panel UI

local ADDON_NAME = ...
local TokukoP = TokukoP

-- ===============================
-- Settings Panel Creation
-- ===============================
function TokukoP.CreateSettingsPanel()
  local category, layout = Settings.RegisterVerticalLayoutCategory("TokukoPreferences")
  
  -- ===============================
  -- Mana Module Settings
  -- ===============================
  
  -- Enabled checkbox
  do
    local variable = "TokukoPref_Mana_enabled"
    local variableKey = "enabled"
    local name = "Enable Mana Alerts"
    local defaultValue = true
    
    local setting = Settings.RegisterAddOnSetting(
      category,
      variable,
      variableKey,
      TokukoPDB.Mana,
      type(defaultValue),
      name,
      defaultValue
    )
    
    Settings.CreateCheckbox(category, setting, "Toggle mana alerts on/off.")
  end
  
  -- Only in Group checkbox
  do
    local variable = "TokukoPref_Mana_onlyInGroup"
    local variableKey = "onlyInGroup"
    local name = "Only in Group/Instance"
    local defaultValue = true
    
    local setting = Settings.RegisterAddOnSetting(
      category,
      variable,
      variableKey,
      TokukoPDB.Mana,
      type(defaultValue),
      name,
      defaultValue
    )
    
    Settings.CreateCheckbox(category, setting, "Only perform /oom when you are in a party, raid, or instance group.")
  end
  
  -- Threshold slider
  do
    local variable = "TokukoPref_Mana_threshold"
    local variableKey = "threshold"
    local name = "Mana Threshold for /oom"
    local defaultValue = 20
    
    local setting = Settings.RegisterAddOnSetting(
      category,
      variable,
      variableKey,
      TokukoPDB.Mana,
      type(defaultValue),
      name,
      defaultValue
    )
    
    local options = Settings.CreateSliderOptions(1, 100, 1)
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(v)
      return string.format("%d%%", v)
    end)
    
    Settings.CreateSlider(category, setting, options, "Trigger /oom when mana is below this percent after leaving combat.")
  end
  
  Settings.RegisterAddOnCategory(category)
  return category, layout
end
