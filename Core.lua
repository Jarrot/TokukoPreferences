-- Core.lua
-- Creates the addon namespace and handles initialization

local ADDON_NAME = ...

-- Create global namespace for the addon
TokukoP = TokukoP or {}
TokukoP.modules = {}

-- SavedVariables
TokukoPDB = TokukoPDB or {}

-- ===============================
-- Utility Functions
-- ===============================
function TokukoP.MergeDefaults(db, defaults)
  for k, v in pairs(defaults) do
    if type(v) == "table" then
      db[k] = db[k] or {}
      TokukoP.MergeDefaults(db[k], v)
    elseif db[k] == nil then
      db[k] = v
    end
  end
end

function TokukoP.Clamp(val, min, max)
  if val < min then return min end
  if val > max then return max end
  return val
end

-- ===============================
-- Event Handler
-- ===============================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(self, event, ...)
  if event == "PLAYER_LOGIN" then
    -- Initialize database
    TokukoPDB = TokukoPDB or {}

    -- Initialize all modules
    for name, module in pairs(TokukoP.modules) do
      if module.Initialize then
        module.Initialize()
      end
    end

    -- Create settings UI (may return nil if custom window approach is used)
    if TokukoP.CreateSettingsPanel then
      TokukoP.CreateSettingsPanel()
    end

    -- Let modules register their events
    for name, module in pairs(TokukoP.modules) do
      if module.RegisterEvents then
        module.RegisterEvents(self)
      end
    end

    -- Switch to runtime event handler
    self:SetScript("OnEvent", function(_, evt, ...)
      for name, module in pairs(TokukoP.modules) do
        if module.OnEvent then
          module.OnEvent(evt, ...)
        end
      end
    end)

    print("|cff00b3ffTokukoPreferences|r: Settings via |cffffffff/ec|r -> Plugins -> TokukoPreferences")
  end
end)
