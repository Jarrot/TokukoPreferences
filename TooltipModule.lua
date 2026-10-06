-- TooltipModule.lua
-- Switches the tooltip anchor between cursor (out of combat) and fixed position
-- (in combat). Supported on both ElvUI and EllesmereUI -- each exposes its own
-- cursor-anchor flag, so only the apply step differs.

local ADDON_NAME = ...
local TokukoP = TokukoP

-- Create module
local TooltipModule = {}
TokukoP.modules.Tooltip = TooltipModule

-- Both suites expose a cursor-anchor toggle; neither switches it on combat,
-- which is the behaviour this module adds on top.
TooltipModule.HOSTS = { elvui = true, ellesmere = true }

-- ===============================
-- Module Defaults
-- ===============================
TooltipModule.DEFAULTS = {
  enabled = true,
}

-- ===============================
-- Core Logic
-- ===============================
local function ApplyElvUIAnchor(cursor)
  if not ElvUI then return end
  local E = unpack(ElvUI)
  if not E or not E.db or not E.db.tooltip then return end
  E.db.tooltip.cursorAnchor = cursor
end

-- Only EUI's own "Anchor to Cursor" setting is touched -- no `_` internals
-- (EUI's plugin guide asks addons not to use them). This works because:
--   * EUI's GameTooltip_SetDefaultAnchor hook re-reads tooltipAnchorCursor
--     for every tooltip, so flipping the flag switches behaviour on the next
--     tooltip; its fixed-anchor hook steps in whenever the flag is off and
--     positions itself per tooltip.
--   * The cursor hook is only INSTALLED by EUI's PLAYER_LOGIN handler when the
--     flag is on at that moment -- see PreseedEllesmere below.
local function ApplyEllesmereAnchor(cursor)
  if not _G.EllesmereUI or not EllesmereUIDB then return end
  EllesmereUIDB.tooltipAnchorCursor = cursor
end

-- Runs at our ADDON_LOADED, i.e. before PLAYER_LOGIN (## OptionalDeps makes
-- EllesmereUI load, SavedVariables included, before us). Turning the flag on
-- here means EUI's own login handler installs its cursor hook; our
-- Initialize then sets the real value for the current combat state. Covers a
-- /reload in combat, which would otherwise have saved the flag off and left
-- the hook uninstalled for the session.
local function PreseedEllesmere()
  if _G.ElvUI or not _G.EllesmereUI or not EllesmereUIDB then return end
  local saved = TokukoPDB and TokukoPDB.Tooltip
  if saved and saved.enabled == false then return end
  EllesmereUIDB.tooltipAnchorCursor = true
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _, name)
  if name ~= ADDON_NAME then return end
  self:UnregisterEvent("ADDON_LOADED")
  PreseedEllesmere()
end)

-- cursor = true  -> tooltip follows the mouse (out of combat)
-- cursor = false -> tooltip returns to its fixed anchor (in combat)
local function ApplyTooltipAnchor(inCombat)
  local cursor = not inCombat

  if TokukoP.host == TokukoP.HOST_ELLESMERE then
    ApplyEllesmereAnchor(cursor)
  else
    ApplyElvUIAnchor(cursor)
  end
end

-- ===============================
-- Module Interface
-- ===============================
function TooltipModule.Initialize()
  TokukoPDB.Tooltip = TokukoPDB.Tooltip or {}
  TokukoP.MergeDefaults(TokukoPDB.Tooltip, TooltipModule.DEFAULTS)

  -- Set correct state immediately on login
  if TokukoPDB.Tooltip.enabled then
    ApplyTooltipAnchor(InCombatLockdown())
  end
end

-- Re-assert the anchor for the current combat state on whichever host is
-- active. Called by Settings when the option is toggled, so the change is
-- visible immediately instead of at the next combat transition.
function TooltipModule.ApplyNow()
  if not TokukoPDB.Tooltip or not TokukoPDB.Tooltip.enabled then return end
  ApplyTooltipAnchor(InCombatLockdown())
end

function TooltipModule.RegisterEvents(frame)
  frame:RegisterEvent("PLAYER_REGEN_DISABLED")  -- entering combat
  frame:RegisterEvent("PLAYER_REGEN_ENABLED")   -- leaving combat
end

function TooltipModule.OnEvent(event, ...)
  if not TokukoPDB.Tooltip or not TokukoPDB.Tooltip.enabled then return end

  if event == "PLAYER_REGEN_DISABLED" then
    ApplyTooltipAnchor(true)
  elseif event == "PLAYER_REGEN_ENABLED" then
    ApplyTooltipAnchor(false)
  end
end
