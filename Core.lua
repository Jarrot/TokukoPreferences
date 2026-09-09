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
-- Host UI Detection
-- ===============================
-- Some modules only make sense on top of a particular UI suite (EmbedModule
-- targets ElvUI's RightChatPanel; TooltipModule drives E.db.tooltip). Detect
-- which suite is loaded so those modules can opt out cleanly instead of
-- no-opping in a dozen places.
--
-- Modules declare support with a HOSTS table, e.g.
--   MyModule.HOSTS = { elvui = true }
-- A module with no HOSTS table runs everywhere.

TokukoP.HOST_ELVUI     = "elvui"
TokukoP.HOST_ELLESMERE = "ellesmere"
TokukoP.HOST_NONE      = "none"

function TokukoP.DetectHost()
  -- ElvUI wins when both are somehow loaded: it is the path this addon was
  -- built and tested against, so an odd double-install keeps working as-is.
  if _G.ElvUI then return TokukoP.HOST_ELVUI end
  if _G.EllesmereUI then return TokukoP.HOST_ELLESMERE end
  return TokukoP.HOST_NONE
end

function TokukoP.IsHost(name)
  return TokukoP.host == name
end

-- True when the module supports the currently detected host.
function TokukoP.ModuleSupportsHost(module)
  if not module.HOSTS then return true end
  return module.HOSTS[TokukoP.host] == true
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

    -- Which UI suite are we sitting on top of? Done here rather than at file
    -- load: the host addon's globals are not guaranteed to exist until login.
    TokukoP.host = TokukoP.DetectHost()

    -- Modules that support this host. Everything below iterates this list, so
    -- an unsupported module is never initialized, never registers events, and
    -- never sees an event dispatch.
    TokukoP.activeModules = {}
    for name, module in pairs(TokukoP.modules) do
      if TokukoP.ModuleSupportsHost(module) then
        TokukoP.activeModules[name] = module
      end
    end

    -- Initialize active modules
    for name, module in pairs(TokukoP.activeModules) do
      if module.Initialize then
        module.Initialize()
      end
    end

    -- Create settings UI (may return nil if custom window approach is used)
    if TokukoP.CreateSettingsPanel then
      TokukoP.CreateSettingsPanel()
    end

    -- Let active modules register their events
    for name, module in pairs(TokukoP.activeModules) do
      if module.RegisterEvents then
        module.RegisterEvents(self)
      end
    end

    -- Switch to runtime event handler
    self:SetScript("OnEvent", function(_, evt, ...)
      for name, module in pairs(TokukoP.activeModules) do
        if module.OnEvent then
          module.OnEvent(evt, ...)
        end
      end
    end)

    if TokukoP.host == TokukoP.HOST_ELVUI then
      print("|cff00b3ffTokukoPreferences|r: Settings via |cffffffff/ec|r -> Plugins -> TokukoPreferences")
    else
      print("|cff00b3ffTokukoPreferences|r: Settings via |cffffffff/tp|r")
    end
  end
end)
