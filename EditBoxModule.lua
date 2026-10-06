-- EditBoxModule.lua
-- EllesmereUI only: while a chat edit box is active (Enter pressed, until
-- Esc / send), fade out any EllesmereUI data bar it overlaps, so the edit box
-- can sit on top of a data bar. ElvUI gets the same look by giving its edit
-- box a solid backdrop SetAllPoints'd over LeftChatDataPanel; EllesmereUI's
-- edit box has no backdrop, so the bar has to go instead.
--
-- Keyed on edit box FOCUS, not Show/Hide: with chatStyle "classic" (default)
-- the box is hidden whenever inactive, but with "im" it stays shown at half
-- alpha, so Show/Hide would never give the bar back.

local ADDON_NAME = ...
local TokukoP = TokukoP

local EditBoxModule = {}
TokukoP.modules.EditBox = EditBoxModule

-- ElvUI already does this natively; with no suite there are no data bars.
EditBoxModule.HOSTS = { ellesmere = true }

-- ===============================
-- Constants
-- ===============================

local DATABARS_ADDON = "EllesmereUIDataBars"
local BAR_FRAME_PREFIX = "EllesmereUIDataBarsBar"  -- .. bar id (EllesmereUIDataBars.lua)

local DEFAULTS = {
  enabled = true,
}

-- ===============================
-- State
-- ===============================

local db      = nil
local hidden  = {}     -- bar frame -> true while we hold it at alpha 0
local typing  = false  -- a permanent chat edit box is shown
local hooked  = false

-- ===============================
-- Helpers
-- ===============================

local function DataBarsNS()
  return EllesmereUI and EllesmereUI._ModuleNS and EllesmereUI._ModuleNS[DATABARS_ADDON]
end

-- Same filter EllesmereUIChat applies (PermanentEditBox): only ChatFrame1-10.
-- Temp whisper windows (11+) carry secret BN tell targets; leave them alone.
local function IsPermanentEditBox(eb)
  if not eb or type(eb.GetName) ~= "function" then return false end
  local n = eb:GetName()
  local i = n and tonumber(n:match("^ChatFrame(%d+)EditBox$"))
  return i ~= nil and i <= 10
end

-- `except`: the box whose focus-lost callback is running, in case HasFocus
-- still reports true from inside its own OnEditFocusLost.
local function AnyPermanentEditBoxActive(except)
  for i = 1, 10 do
    local eb = _G["ChatFrame" .. i .. "EditBox"]
    if eb and eb ~= except and eb:IsShown() and eb:HasFocus() then return true end
  end
  return false
end

-- Screen-space rect (frames can sit under different effective scales).
local function ScreenRect(f)
  local l, b, w, h = f:GetRect()
  if not l then return nil end
  local s = f:GetEffectiveScale()
  return l * s, b * s, (l + w) * s, (b + h) * s
end

local function Overlaps(a, b)
  local al, ab, ar, at = ScreenRect(a)
  local bl, bb, br, bt = ScreenRect(b)
  if not (al and bl) then return false end
  return al < br and bl < ar and ab < bt and bb < at
end

-- Every live EllesmereUI data bar frame, via the module's own bar list.
local function ForEachBarFrame(fn)
  local ns = DataBarsNS()
  if not (ns and ns.BarsInOrder) then return end
  local bars = ns.BarsInOrder()
  if not bars then return end
  for i = 1, #bars do
    local f = _G[BAR_FRAME_PREFIX .. bars[i].id]
    if f then fn(f) end
  end
end

-- Alpha only. EllesmereUI's own visibility engine is alpha-only for the same
-- reason: a bar hosting a secure block (micromenu, hearth) is implicitly
-- protected, so Show/Hide on it in combat is ADDON_ACTION_BLOCKED. SetAlpha
-- is combat-legal.
local function HideOverlapping(eb)
  ForEachBarFrame(function(f)
    if Overlaps(eb, f) then
      hidden[f] = true
      f:SetAlpha(0)
    end
  end)
end

-- Hand the bars back to EllesmereUI rather than forcing alpha 1, so bars set
-- to mouseover / combat-only / never still get their own state.
local function Restore()
  if not next(hidden) then return end
  wipe(hidden)
  local ns = DataBarsNS()
  if ns and ns.UpdateAllBarVisibility then
    ns.UpdateAllBarVisibility()
  end
end

-- ===============================
-- Edit box callbacks
-- ===============================

-- EventRegistry, NOT HookScript on the edit box: EllesmereUIChat documents
-- that hooking edit box scripts taints the chat-type attribute, and inside a
-- chat lockdown (encounter, M+, PvP) the tainted send is silently swallowed.
-- TriggerEvent runs registrants through securecallfunction, so our taint
-- stops at our own closure.
local function OnEditBoxActive(_, eb)
  if not (db and db.enabled) or not IsPermanentEditBox(eb) then return end
  typing = true
  HideOverlapping(eb)
end

local function OnEditBoxInactive(_, eb)
  if not IsPermanentEditBox(eb) then return end
  if AnyPermanentEditBoxActive(eb) then return end
  typing = false
  Restore()
end

-- EllesmereUI re-runs its visibility pass on combat, group and mount changes,
-- which would fade the bar back in mid-sentence. Re-assert after it.
local function AfterVisibilityPass()
  if not typing then return end
  for f in pairs(hidden) do f:SetAlpha(0) end
end

local function InstallHooks()
  if hooked or not (EventRegistry and EventRegistry.RegisterCallback) then return end
  hooked = true
  -- Constant owner strings: re-registration replaces rather than stacks.
  EventRegistry:RegisterCallback("ChatFrame.OnEditBoxFocusGained", OnEditBoxActive, "TokukoP_EditBoxFocus")
  EventRegistry:RegisterCallback("ChatFrame.OnEditBoxFocusLost", OnEditBoxInactive, "TokukoP_EditBoxBlur")
  -- Belt-and-braces: a box hidden without a focus-lost (UI hidden, frame
  -- closed) must still give the bar back.
  EventRegistry:RegisterCallback("ChatFrame.OnEditBoxHide", OnEditBoxInactive, "TokukoP_EditBoxHide")

  -- ns.UpdateAllBarVisibility is called through the table (OnVisEvent), so a
  -- post-hook on the table field catches every pass.
  local ns = DataBarsNS()
  if ns and ns.UpdateAllBarVisibility then
    hooksecurefunc(ns, "UpdateAllBarVisibility", AfterVisibilityPass)
  end
end

-- ===============================
-- Public API
-- ===============================

-- Settings toggle: turning off while typing gives the bar back immediately.
function EditBoxModule.SetEnabled(v)
  db.enabled = v
  if not v then
    typing = false
    Restore()
  end
end

-- ===============================
-- Lifecycle
-- ===============================

function EditBoxModule.Initialize()
  TokukoPDB.EditBox = TokukoPDB.EditBox or {}
  TokukoP.MergeDefaults(TokukoPDB.EditBox, DEFAULTS)
  db = TokukoPDB.EditBox
  InstallHooks()
end
