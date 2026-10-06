-- EditBoxModule.lua
-- EllesmereUI only: lets the chat edit box sit on top of a data bar while you
-- type (Enter pressed, until Esc / send), like ElvUI's edit box covering its
-- datatext panel. Two modes:
--
--   "cover" (default) -- while active, every visible EllesmereUI data bar the
--     edit box overlaps gets an opaque backdrop frame of ours pinned to it
--     (exact fit, whatever the bar's size), and the edit box is raised above
--     that. The edit box's size/position are NOT touched -- EllesmereUIChat
--     owns them as part of the chat window. Bars are found by their public
--     frame names, so no EUI internals.
--   "fade" -- fades out every EllesmereUI data bar the edit box overlaps.
--     Hides the whole bar even if it is bigger than the box, but has to reach
--     EUI internals (_ModuleNS, a post-hook on the DataBars visibility pass),
--     which EUI's plugin guide asks addons not to do -- may break on an EUI
--     update.
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

-- Layering while typing: bar (EUI default MEDIUM, level 10) < our backdrop
-- (HIGH, high level) < edit box (DIALOG). A bar set to DIALOG strata or
-- above in EUI would win -- unusual for a data bar.
local BACKDROP_STRATA = "HIGH"
local BACKDROP_LEVEL  = 500
local EDITBOX_STRATA  = "DIALOG"

-- Bar ids are monotonic and never reused (EllesmereUIDataBars.lua), so deleted
-- bars leave gaps; probe this many names. A _G lookup each, once per Enter.
local MAX_BAR_ID = 200

EditBoxModule.MODE_VALUES  = { cover = "Cover Bars with Background", fade = "Fade Data Bars" }
EditBoxModule.MODE_SORTING = { "cover", "fade" }

local DEFAULTS = {
  enabled = true,
  mode    = "cover",
  -- EllesmereUIChat's default panel colour, made opaque so the bar does not
  -- show through. Pick the bar's own colour to make it blend in.
  bgColor = { r = 0.03, g = 0.045, b = 0.05 },
  bgAlpha = 1,
}

-- ===============================
-- State
-- ===============================

local db        = nil
local hidden    = {}     -- fade: bar frame -> true while we hold it at alpha 0
local raised    = {}     -- cover: edit box -> its original strata
local backdrops = {}     -- cover: bar frame -> our backdrop frame
local typing    = false  -- a permanent chat edit box is active
local hooked    = false
local fadeHooked = false

-- ===============================
-- Helpers
-- ===============================

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

-- ===============================
-- Shared: finding bars
-- ===============================

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

-- ===============================
-- Cover mode
-- ===============================

local function ApplyBackdropColor(bd)
  local c = db.bgColor
  bd.tex:SetColorTexture(c.r, c.g, c.b, db.bgAlpha)
end

local function GetBackdrop(bar)
  local bd = backdrops[bar]
  if not bd then
    bd = CreateFrame("Frame", nil, UIParent)
    bd:SetFrameStrata(BACKDROP_STRATA)
    bd:SetFrameLevel(BACKDROP_LEVEL)
    bd:SetAllPoints(bar)          -- exact fit; follows the bar if it moves
    bd:EnableMouse(true)          -- swallow clicks meant for the hidden bar
    bd.tex = bd:CreateTexture(nil, "BACKGROUND")
    bd.tex:SetAllPoints()
    bd:Hide()
    backdrops[bar] = bd
  end
  return bd
end

-- Visible = shown and not faded out by the bar's own Visibility setting
-- (EUI hides bars by alpha). A hidden bar needs no cover.
local function BarVisible(f)
  return f:IsVisible() and f:GetEffectiveAlpha() > 0
end

local function CoverOn(eb)
  for id = 1, MAX_BAR_ID do
    local bar = _G[BAR_FRAME_PREFIX .. id]
    if bar and BarVisible(bar) and Overlaps(eb, bar) then
      local bd = GetBackdrop(bar)
      ApplyBackdropColor(bd)
      bd:Show()
    end
  end
  if not raised[eb] then
    raised[eb] = eb:GetFrameStrata()
    eb:SetFrameStrata(EDITBOX_STRATA)
  end
end

local function CoverOff(eb)
  if raised[eb] then
    eb:SetFrameStrata(raised[eb])
    raised[eb] = nil
  end
end

local function CoverOffAll()
  for eb in pairs(raised) do CoverOff(eb) end
  for _, bd in pairs(backdrops) do bd:Hide() end
end

-- ===============================
-- Fade mode (EUI internals)
-- ===============================

local function DataBarsNS()
  return EllesmereUI and EllesmereUI._ModuleNS and EllesmereUI._ModuleNS[DATABARS_ADDON]
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

-- EllesmereUI re-runs its visibility pass on combat, group and mount changes,
-- which would fade the bar back in mid-sentence. Re-assert after it.
local function AfterVisibilityPass()
  if not typing then return end
  for f in pairs(hidden) do f:SetAlpha(0) end
end

-- Only installed once fade mode is actually used, so cover-mode users never
-- hook anything of EUI's. ns.UpdateAllBarVisibility is called through the
-- table (OnVisEvent), so a post-hook on the field catches every pass.
local function EnsureFadeHook()
  if fadeHooked then return end
  local ns = DataBarsNS()
  if ns and ns.UpdateAllBarVisibility then
    hooksecurefunc(ns, "UpdateAllBarVisibility", AfterVisibilityPass)
    fadeHooked = true
  end
end

-- Alpha only. EllesmereUI's own visibility engine is alpha-only for the same
-- reason: a bar hosting a secure block (micromenu, hearth) is implicitly
-- protected, so Show/Hide on it in combat is ADDON_ACTION_BLOCKED. SetAlpha
-- is combat-legal.
local function FadeOverlapping(eb)
  EnsureFadeHook()
  ForEachBarFrame(function(f)
    if Overlaps(eb, f) then
      hidden[f] = true
      f:SetAlpha(0)
    end
  end)
end

-- Hand the bars back to EllesmereUI rather than forcing alpha 1, so bars set
-- to mouseover / combat-only / never still get their own state.
local function FadeRestore()
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

local function RestoreAll()
  typing = false
  CoverOffAll()
  FadeRestore()
end

-- EventRegistry, NOT HookScript on the edit box: EllesmereUIChat documents
-- that hooking edit box scripts taints the chat-type attribute, and inside a
-- chat lockdown (encounter, M+, PvP) the tainted send is silently swallowed.
-- TriggerEvent runs registrants through securecallfunction, so our taint
-- stops at our own closure.
local function OnEditBoxActive(_, eb)
  if not (db and db.enabled) or not IsPermanentEditBox(eb) then return end
  typing = true
  if db.mode == "fade" then
    FadeOverlapping(eb)
  else
    CoverOn(eb)
  end
end

local function OnEditBoxInactive(_, eb)
  if not IsPermanentEditBox(eb) then return end
  CoverOff(eb)
  if AnyPermanentEditBoxActive(eb) then return end
  typing = false
  for _, bd in pairs(backdrops) do bd:Hide() end
  FadeRestore()
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
end

-- ===============================
-- Public API
-- ===============================

-- Settings toggle: turning off while typing gives the bar back immediately.
function EditBoxModule.SetEnabled(v)
  db.enabled = v
  if not v then RestoreAll() end
end

-- Switching mode mid-typing: undo the old mode; the new one applies on the
-- next Enter.
function EditBoxModule.SetMode(v)
  db.mode = v
  RestoreAll()
end

-- Colour / opacity change: repaint the backdrops.
function EditBoxModule.RefreshCover()
  for _, bd in pairs(backdrops) do ApplyBackdropColor(bd) end
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
