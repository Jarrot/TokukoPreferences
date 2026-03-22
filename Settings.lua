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
    local setting = Settings.RegisterAddOnSetting(
      category,
      "TokukoPref_Drinking_enabled",
      "enabled",
      TokukoPDB.Drinking,
      Settings.VarType.Boolean,
      "Enable Drinking Announcements",
      true
    )
    Settings.CreateCheckbox(category, setting, "Toggle drinking announcements on/off.")
  end

  -- Only in Group checkbox
  do
    local setting = Settings.RegisterAddOnSetting(
      category,
      "TokukoPref_Drinking_onlyInGroup",
      "onlyInGroup",
      TokukoPDB.Drinking,
      Settings.VarType.Boolean,
      "Only in Group/Instance",
      true
    )
    Settings.CreateCheckbox(category, setting, "Only announce when you are in a party, raid, or instance group.")
  end

  -- Announce Complete checkbox
  do
    local setting = Settings.RegisterAddOnSetting(
      category,
      "TokukoPref_Drinking_announceComplete",
      "announceComplete",
      TokukoPDB.Drinking,
      Settings.VarType.Boolean,
      "Announce When Done",
      true
    )
    Settings.CreateCheckbox(category, setting, "Announce when you finish eating/drinking (after 8+ seconds).")
  end

  -- Start message text input
  do
    local defaultValue = "eating nam nam"
    local setting = Settings.RegisterProxySetting(
      category,
      "TokukoPref_Drinking_message",
      Settings.VarType.String,
      "Start Message",
      defaultValue,
      function() return TokukoPDB.Drinking.message or defaultValue end,
      function(value) TokukoPDB.Drinking.message = value end
    )
    Settings.CreateEditBox(category, setting, "Message announced when you start eating or drinking.")
  end

  -- Complete message text input
  do
    local defaultValue = "nam nam done!"
    local setting = Settings.RegisterProxySetting(
      category,
      "TokukoPref_Drinking_completeMessage",
      Settings.VarType.String,
      "Complete Message",
      defaultValue,
      function() return TokukoPDB.Drinking.completeMessage or defaultValue end,
      function(value) TokukoPDB.Drinking.completeMessage = value end
    )
    Settings.CreateEditBox(category, setting, "Message announced when you finish eating or drinking.")
  end

  -- ===============================
  -- Tooltip Module Settings
  -- ===============================
  do
    local setting = Settings.RegisterAddOnSetting(
      category,
      "TokukoPref_Tooltip_enabled",
      "enabled",
      TokukoPDB.Tooltip,
      Settings.VarType.Boolean,
      "ElvUI: Tooltip Follows Cursor Out of Combat",
      true
    )

    setting:SetValueChangedCallback(function(_, value)
      TokukoPDB.Tooltip.enabled = value
      if value and ElvUI then
        local E = unpack(ElvUI)
        if E and E.db and E.db.tooltip then
          E.db.tooltip.cursorAnchor = not InCombatLockdown()
        end
      end
    end)

    Settings.CreateCheckbox(
      category,
      setting,
      "Requires ElvUI. Tooltip follows your mouse cursor when out of combat, and uses your fixed ElvUI anchor position when in combat."
    )
  end

  Settings.RegisterAddOnCategory(category)
  return category, layout
end
