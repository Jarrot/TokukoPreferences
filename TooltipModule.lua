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

local function ApplyEllesmereAnchor(cursor)
  local EUI = _G.EllesmereUI
  if not EUI or not EllesmereUIDB then return end

  EllesmereUIDB.tooltipAnchorCursor = cursor

  -- _applyTooltipCursorAnchor installs its GameTooltip hook on first enable
  -- (guarded by an internal `hooked` flag, so calling it every combat
  -- transition is safe) and hides the cursor tracking frame on disable. The
  -- hook itself re-reads tooltipAnchorCursor per tooltip, so the flag above
  -- is what actually switches behaviour.
  if EUI._applyTooltipCursorAnchor then EUI._applyTooltipCursorAnchor() end

  -- Mirror EllesmereUI's own options panel: re-park the fixed anchor when
  -- leaving cursor mode so the fixed position resumes cleanly (and gets its
  -- one-time seed if this profile has never had one).
  if not cursor and EUI._applyTooltipFixedAnchor then
    EUI._applyTooltipFixedAnchor()
  end
end

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
