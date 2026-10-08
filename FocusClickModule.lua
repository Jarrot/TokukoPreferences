-- FocusClickModule.lua
-- Middle-click on the target unit frame sets that unit as focus -- the same
-- thing as "Set Focus" in the frame's right-click menu, on one click.
--
-- Setting focus is protected (FocusUnit), so it can only happen inside a
-- secure click, and the attributes that wire it up can only be written out of
-- combat. 12.0.7+ also gates raw actions on SecureUnitButtons (a "focus" type
-- on the unit frame itself is silently dropped), and 12.1 broke the "click"
-- action. So, exactly like EllesmereUI routes its own right-click menu (see
-- EllesmereUI_Kick.lua, AttachSecureUnitMenu / GetSecureTargetProxy):
--   unit frame   *type3 = "macro", *macrotext3 = "/click TokukoPFocusProxy"
--   proxy        hidden SecureActionButton child, type = "focus",
--                useparent-unit -> focuses the unit the parent frame shows.
-- The wildcard "*type3" means a click-cast binding on middle-click (EUI's
-- engine or Clique writes "type3" / "shift-type3" ...) still wins.

local ADDON_NAME = ...
local TokukoP = TokukoP

local FocusClickModule = {}
TokukoP.modules.FocusClick = FocusClickModule

-- Only hosts whose target frame is an addon-owned secure unit button.
-- Blizzard's own TargetFrame is left alone (writing attributes on it from
-- addon code risks tainting it).
FocusClickModule.HOSTS = { elvui = true, ellesmere = true }

-- ===============================
-- Module Defaults
-- ===============================
FocusClickModule.DEFAULTS = {
  enabled = true,
}

-- ===============================
-- Constants
-- ===============================
local PROXY_NAME = "TokukoPFocusProxy"
local MACRO      = "/click " .. PROXY_NAME

local TARGET_FRAMES = {
  elvui     = "ElvUF_Target",
  ellesmere = "EllesmereUIUnitFrames_Target",  -- only exists when EUI draws the target frame
}

-- ===============================
-- State
-- ===============================
local proxy   = nil
local pending = false   -- an apply was asked for during combat

-- ===============================
-- Core Logic
-- ===============================
local function GetTargetFrame()
  local name = TARGET_FRAMES[TokukoP.host]
  return name and _G[name]
end

local function EnsureProxy(frame)
  if proxy then return proxy end
  proxy = CreateFrame("Button", PROXY_NAME, frame, "SecureActionButtonTemplate")
  proxy:SetSize(1, 1)
  proxy:SetAlpha(0)
  proxy:EnableMouse(false)   -- only ever reached via /click
  proxy:RegisterForClicks("AnyUp")
  -- The action is looked up by button suffix; set every button explicitly.
  proxy:SetAttribute("type", "focus")
  for i = 1, 5 do proxy:SetAttribute("type" .. i, "focus") end
  proxy:SetAttribute("useparent-unit", true)
  -- Act on the up-click whatever the "cast on key down" CVar says (the
  -- /click delegate fires an up).
  proxy:SetAttribute("useOnKeyDown", false)
  return proxy
end

-- Writes (or removes) the middle-click wiring. Out of combat only; in combat
-- it is queued for PLAYER_REGEN_ENABLED.
local function Apply()
  if InCombatLockdown() then pending = true; return end
  pending = false

  local frame = GetTargetFrame()
  if not frame then return end

  if TokukoPDB.FocusClick.enabled then
    EnsureProxy(frame)
    frame:SetAttribute("*type3", "macro")
    frame:SetAttribute("*macrotext3", MACRO)
  elseif frame:GetAttribute("*macrotext3") == MACRO then
    -- Only undo our own wiring, never someone else's middle-click.
    frame:SetAttribute("*type3", nil)
    frame:SetAttribute("*macrotext3", nil)
  end
end

-- ===============================
-- Module Interface
-- ===============================
function FocusClickModule.Initialize()
  TokukoPDB.FocusClick = TokukoPDB.FocusClick or {}
  TokukoP.MergeDefaults(TokukoPDB.FocusClick, FocusClickModule.DEFAULTS)
  Apply()
end

-- Called by Settings when the option is toggled.
function FocusClickModule.ApplyNow()
  Apply()
  if pending then
    print("|cff00b3ffTokukoPreferences|r: middle-click focus change applies when combat ends.")
  end
end

function FocusClickModule.RegisterEvents(frame)
  frame:RegisterEvent("PLAYER_ENTERING_WORLD")  -- host frames may be built after our login handler
  frame:RegisterEvent("PLAYER_REGEN_ENABLED")
end

function FocusClickModule.OnEvent(event)
  if not TokukoPDB.FocusClick then return end
  if event == "PLAYER_ENTERING_WORLD" then
    Apply()
  elseif event == "PLAYER_REGEN_ENABLED" and pending then
    Apply()
  end
end
