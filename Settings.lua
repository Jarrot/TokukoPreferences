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
  -- Drinking Module Settings
  -- ===============================
  
  -- Enabled checkbox
  do
    local variable = "TokukoPref_Drinking_enabled"
    local variableKey = "enabled"
    local name = "Enable Drinking Announcements"
    local defaultValue = true
    
    local setting = Settings.RegisterAddOnSetting(
      category,
      variable,
      variableKey,
      TokukoPDB.Drinking,
      type(defaultValue),
      name,
      defaultValue
    )
    
    Settings.CreateCheckbox(category, setting, "Toggle drinking announcements on/off.")
  end
  
  -- Only in Group checkbox
  do
    local variable = "TokukoPref_Drinking_onlyInGroup"
    local variableKey = "onlyInGroup"
    local name = "Only in Group/Instance"
    local defaultValue = true
    
    local setting = Settings.RegisterAddOnSetting(
      category,
      variable,
      variableKey,
      TokukoPDB.Drinking,
      type(defaultValue),
      name,
      defaultValue
    )
    
    Settings.CreateCheckbox(category, setting, "Only announce when you are in a party, raid, or instance group.")
  end
  
  -- Announce Complete checkbox
  do
    local variable = "TokukoPref_Drinking_announceComplete"
    local variableKey = "announceComplete"
    local name = "Announce When Done"
    local defaultValue = true
    
    local setting = Settings.RegisterAddOnSetting(
      category,
      variable,
      variableKey,
      TokukoPDB.Drinking,
      type(defaultValue),
      name,
      defaultValue
    )
    
    Settings.CreateCheckbox(category, setting, "Announce when you finish eating/drinking (after 8+ seconds).")
  end
  
  -- Helper function to create text input
  local function CreateTextInput(labelText, settingKey, defaultValue, tooltip)
    local container = CreateFrame("Frame", nil, SettingsPanel.Container)
    container:SetSize(500, 60)
    
    -- Label
    local label = container:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", 10, -10)
    label:SetText(labelText)
    
    -- EditBox
    local editBox = CreateFrame("EditBox", nil, container, "InputBoxTemplate")
    editBox:SetSize(400, 20)
    editBox:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 5, -5)
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(100)
    
    -- Set current value
    editBox:SetText(TokukoPDB.Drinking[settingKey] or defaultValue)
    
    -- Save on Enter or focus loss
    editBox:SetScript("OnEnterPressed", function(self)
      TokukoPDB.Drinking[settingKey] = self:GetText()
      self:ClearFocus()
    end)
    
    editBox:SetScript("OnEditFocusLost", function(self)
      TokukoPDB.Drinking[settingKey] = self:GetText()
    end)
    
    -- Tooltip
    if tooltip then
      editBox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(tooltip)
        GameTooltip:Show()
      end)
      editBox:SetScript("OnLeave", function()
        GameTooltip:Hide()
      end)
    end
    
    -- Add to layout
    local initializer = CreateFromMixins(SettingsListElementInitializer)
    initializer:Init(container)
    layout:AddInitializer(initializer)
  end
  
  -- Start message input
  CreateTextInput(
    "Start Message:",
    "message",
    "eating nam nam",
    "Message announced when you start drinking/eating"
  )
  
  -- Complete message input
  CreateTextInput(
    "Complete Message:",
    "completeMessage",
    "nam nam done!",
    "Message announced when you finish drinking/eating"
  )
  
  Settings.RegisterAddOnCategory(category)
  return category, layout
end
