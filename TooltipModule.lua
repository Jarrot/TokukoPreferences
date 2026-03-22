-- TooltipModule.lua
-- Switches ElvUI tooltip anchor between cursor (out of combat) and fixed position (in combat)

local ADDON_NAME = ...
local TokukoP = TokukoP

-- Create module
local TooltipModule = {}
TokukoP.modules.Tooltip = TooltipModule

-- ===============================
-- Module Defaults
-- ===============================
TooltipModule.DEFAULTS = {
  enabled = true,
}

-- ===============================
-- Core Logic
-- ===============================
local function ApplyTooltipAnchor(inCombat)
  -- Only act if ElvUI is loaded and the tooltip db path exists
  if not ElvUI then return end
  local E = unpack(ElvUI)
  if not E or not E.db or not E.db.tooltip then return end

  if inCombat then
    -- In combat: use fixed ElvUI anchor position
    E.db.tooltip.cursorAnchor = false
  else
    -- Out of combat: follow mouse cursor
    E.db.tooltip.cursorAnchor = true
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
