-- EmbedModule.lua
-- Embeds Details! damage/healing meter windows into ElvUI's right chat panel,
-- or under EllesmereUI into the Second Chat Window (ChatWindowModule).
-- Toggle via /tpembed or right-click the ElvUI panel toggle button (">").

local ADDON_NAME = ...
local TokukoP = TokukoP

local EmbedModule = {}
TokukoP.modules.Embed = EmbedModule

-- ElvUI: embeds into RightChatPanel (unchanged original path).
-- EllesmereUI: there is no right panel -- EUI paints a backdrop behind each
-- Blizzard chat window -- so the host is an invisible frame of OURS laid
-- numerically over the Second Chat Window's rect (see "EllesmereUI host").
-- Everything downstream (positioning, split, chrome, lock) works unchanged
-- against that frame; the ElvUI-only bits (chat-tab height, RightChatDataPanel,
-- the ">" toggle) find nothing under EUI and drop out.
EmbedModule.HOSTS = { elvui = true, ellesmere = true }

-- ===============================
-- Module Defaults
-- ===============================
EmbedModule.DEFAULTS = {
  enabled     = false,
  dualEmbed   = false,
  window1     = 1,
  window2     = 2,
  combatOnly  = false,
  splitRatio  = 0.5,
}

-- ===============================
-- State
-- ===============================
local embedded        = false
local embedPending    = false
local panelFrame      = nil
local origParent1, origPoint1 = nil, {}
local origParent2, origPoint2 = nil, {}
local meterFrame1, meterFrame2 = nil, nil
local sizeHookActive  = false
local repositionTimer = nil
local toggleButtonHooked = false

-- ===============================
-- Frame Finders
-- ===============================

local function GetDetailsFrame(index)
  if not Details then return nil end
  -- Primary: registered global DetailsBaseFrame1, DetailsBaseFrame2, etc.
  local f = _G["DetailsBaseFrame" .. index]
  if f and f.IsObjectType and f:IsObjectType("Frame") then return f end
  -- Fallback: Details:GetInstance(n).baseframe
  local ok, inst = pcall(function() return Details:GetInstance(index) end)
  if ok and inst and inst.baseframe then return inst.baseframe end
  return nil
end

local function GetElvUIRightPanel()
  local panel = _G["RightChatPanel"]
  if panel and panel.IsObjectType and panel:IsObjectType("Frame") then
    return panel
  end
  if ElvUI then
    local ok, E = pcall(function() return unpack(ElvUI) end)
    if ok and E then
      local chat = E:GetModule("Chat", true)
      if chat and chat.RightChatPanel then return chat.RightChatPanel end
      local layout = E:GetModule("Layout", true)
      if layout and layout.RightChatPanel then return layout.RightChatPanel end
    end
  end
  return nil
end

-- ===============================
-- EllesmereUI host
-- ===============================
-- NEVER SetParent an addon frame to a chat frame, and never anchor ours into
-- its rect chain: EllesmereUIChat documents that an insecure frame parented
-- to a Blizzard chat frame taints chat "from structure" (whispers/sends
-- break in encounter lockdown). EUI places its own chat panel NUMERICALLY
-- from the chat frame's rect for the same reason; so do we. A light ticker
-- keeps the host on the window (moves, resizes, Unlock Mode, show/hide) and
-- re-asserts the embed after Details' own ShowWindow (e.g. a Details data-bar
-- toggle) resets its geometry and chrome.

local IsEUI = function() return TokukoP.host == TokukoP.HOST_ELLESMERE end

local euiHost        = nil
local euiTicker      = nil
local lastRect       = nil   -- "l,b,w,h" cache so we only re-place on change
local PositionFrames -- forward declaration (defined under Positioning)
local TryHideChrome  -- forward declaration (defined under Chrome hiding)

local function GetEUIHost()
  if not euiHost then
    euiHost = CreateFrame("Frame", "TokukoPEmbedHost", UIParent)
    euiHost:SetSize(1, 1)
    euiHost:SetPoint("CENTER")
    euiHost:Hide()
  end
  return euiHost
end

local function SecretRect(...)
  local issecret = issecretvalue
  if not issecret then return false end
  for i = 1, select("#", ...) do
    if issecret((select(i, ...))) then return true end
  end
  return false
end

-- Lay the host over the chat window's text rect. Returns true when placed.
local function SyncEUIHost()
  local host = GetEUIHost()
  local CW = TokukoP.modules.ChatWindow
  local cf = CW and CW.FindWindow and CW.FindWindow()
  if not cf or cf == ChatFrame1 or cf.isDocked then
    host:Hide(); lastRect = nil
    return false
  end
  local l, b, w, h = cf:GetRect()
  if not (l and b and w and h) or SecretRect(l, b, w, h) then return false end
  local s = cf:GetEffectiveScale() / UIParent:GetEffectiveScale()
  l, b, w, h = l * s, b * s, w * s, h * s
  local key = string.format("%.1f,%.1f,%.1f,%.1f", l, b, w, h)
  if key ~= lastRect then
    lastRect = key
    host:ClearAllPoints()
    host:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l, b)
    host:SetSize(w, h)
  end
  host:SetShown(cf:IsShown())
  return true
end

-- Details re-shown by something else (its own toggle, a data-bar broker)
-- resets parent/anchors and chrome; put it back. Cheap checks only.
local function ReassertMeter(frame)
  if not frame then return end
  local inst = frame._instance or frame.instance
  if inst and inst.ativa == false then return end  -- hidden on purpose
  local _, rel = frame:GetPoint(1)
  if frame:GetParent() ~= euiHost or rel ~= euiHost then
    frame:SetParent(euiHost)
    PositionFrames()
  end
  if frame.titleBar and frame.titleBar.IsShown and frame.titleBar:IsShown() then
    TryHideChrome(frame)
  end
end

local function StartEUITicker(meters)
  if euiTicker then return end
  euiTicker = C_Timer.NewTicker(0.2, function()
    SyncEUIHost()
    local m1, m2 = meters()
    ReassertMeter(m1)
    ReassertMeter(m2)
  end)
end

local function StopEUITicker()
  if euiTicker then euiTicker:Cancel(); euiTicker = nil end
end

-- The panel the embed lives in for the current host.
local function GetHostPanel()
  if IsEUI() then
    SyncEUIHost()
    return GetEUIHost()
  end
  return GetElvUIRightPanel()
end

-- ===============================
-- Geometry
-- ===============================

local function GetTabHeight(panel)
  local tabH = 0
  for i = 1, 10 do
    local tab = _G["ChatFrame" .. i .. "Tab"]
    if tab and tab:IsShown() then
      local p = tab:GetParent()
      if p == panel or (p and p:GetParent() == panel) then
        tabH = math.max(tabH, tab:GetHeight())
      end
    end
  end
  return tabH
end

local function GetDataBarHeight()
  local bar = _G["RightChatDataPanel"]
  return (bar and bar:IsShown()) and bar:GetHeight() or 0
end

local function GetEmbedRect(panel)
  local tabH  = GetTabHeight(panel)
  local barH  = GetDataBarHeight()
  local pw    = panel:GetWidth()
  local ph    = panel:GetHeight()
  local embedH = ph - tabH - barH
  return -tabH, pw, math.max(embedH, 20)
end

-- ===============================
-- Save/Restore Original Position
-- ===============================

local function SaveOriginalPosition(frame, slot)
  if not frame then return end
  local ok, pt, rel, relPt, x, y = pcall(function() return frame:GetPoint(1) end)
  local data = {
    w = frame:GetWidth(), h = frame:GetHeight(),
    point      = ok and pt    or "CENTER",
    relativeTo = ok and rel   or UIParent,
    relPoint   = ok and relPt or "CENTER",
    x          = ok and x     or 0,
    y          = ok and y     or 0,
  }
  if slot == 1 then origParent1, origPoint1 = frame:GetParent(), data
  else              origParent2, origPoint2 = frame:GetParent(), data end
end

local function RestoreOriginalPosition(frame, slot)
  if not frame then return end
  local orig       = slot == 1 and origPoint1 or origPoint2
  local origParent = slot == 1 and origParent1 or origParent2
  if not orig or not orig.point then return end
  frame:SetParent(origParent or UIParent)
  frame:SetFrameStrata("MEDIUM")
  frame:ClearAllPoints()
  frame:SetPoint(orig.point, orig.relativeTo or UIParent,
                 orig.relPoint or orig.point, orig.x or 0, orig.y or 0)
  frame:SetSize(orig.w or 300, orig.h or 200)
  if frame.BoxBarrasAltura ~= nil then
    frame.BoxBarrasAltura = orig.h or 200
  end
  frame:SetClampedToScreen(true)
  frame:Show()
end

-- ===============================
-- Sizing
-- ===============================

local function ForceDetailsSize(frame, w, h)
  if not frame then return end
  frame:SetSize(w, h)
  if frame.BoxBarrasAltura ~= nil then frame.BoxBarrasAltura = h end
  local inst = frame._instance or frame.instance
  if inst then
    pcall(function()
      if inst.db then inst.db.width = w; inst.db.height = h end
      if inst.width  ~= nil then inst.width  = w end
      if inst.height ~= nil then inst.height = h end
    end)
  end
end

-- ===============================
-- Positioning
-- ===============================

function PositionFrames()
  if not panelFrame or not embedded then return end
  local db          = TokukoPDB.Embed
  local yOff, pw, ph = GetEmbedRect(panelFrame)
  local dataBar     = _G["RightChatDataPanel"]
  local botAnchorFrame  = dataBar or panelFrame
  local botAnchorPoint  = dataBar and "TOPLEFT"  or "BOTTOMLEFT"
  local botAnchorPointR = dataBar and "TOPRIGHT" or "BOTTOMRIGHT"
  local botOffset       = dataBar and 0 or GetDataBarHeight()

  if meterFrame1 then
    local w1 = (db.dualEmbed and meterFrame2)
               and math.floor(pw * TokukoP.Clamp(db.splitRatio, 0.2, 0.8))
               or (pw - 1)
    ForceDetailsSize(meterFrame1, w1, ph)
    meterFrame1:ClearAllPoints()
    meterFrame1:SetPoint("TOPLEFT",    panelFrame,     "TOPLEFT",        0, yOff)
    meterFrame1:SetPoint("BOTTOMLEFT", botAnchorFrame, botAnchorPoint,   0, botOffset)
    meterFrame1:SetWidth(w1)
    if meterFrame1.floatingframe then meterFrame1.floatingframe:Hide() end
  end

  if db.dualEmbed and meterFrame2 then
    local w1 = math.floor(pw * TokukoP.Clamp(db.splitRatio, 0.2, 0.8))
    local w2 = pw - w1 - 1
    ForceDetailsSize(meterFrame2, w2, ph)
    meterFrame2:ClearAllPoints()
    meterFrame2:SetPoint("TOPRIGHT",    panelFrame,     "TOPRIGHT",        -1, yOff)
    meterFrame2:SetPoint("BOTTOMRIGHT", botAnchorFrame, botAnchorPointR,   -1, botOffset)
    meterFrame2:SetWidth(w2)
    if meterFrame2.floatingframe then meterFrame2.floatingframe:Hide() end
  end
end

local function HookPanelResize()
  if sizeHookActive or not panelFrame then return end
  sizeHookActive = true
  panelFrame:HookScript("OnSizeChanged", function()
    if embedded then PositionFrames() end
  end)
end

-- Run PositionFrames repeatedly for 8s after embed so we win against
-- Details' own post-load position restoration.
local function StartRepositionTimer()
  if repositionTimer then repositionTimer:Cancel() end
  local ticks = 0
  repositionTimer = C_Timer.NewTicker(0.25, function()
    ticks = ticks + 1
    if embedded then PositionFrames() end
    if ticks >= 32 then -- 8 seconds
      repositionTimer:Cancel()
      repositionTimer = nil
    end
  end)
end

-- Recursively enable/disable mouse on a frame and all its descendants.
-- GetChildren() is only one level deep; Details_GumpFrame1 (windowBackgroundDisplay)
-- is a grandchild of DetailsBaseFrame and has OnEnter/OnLeave scripts that intercept
-- clicks even when invisible.
local function SetMouseRecursive(frame, enabled)
  if not frame then return end
  if frame.EnableMouse then frame:EnableMouse(enabled) end
  local kids = {frame:GetChildren()}
  for _, c in ipairs(kids) do
    SetMouseRecursive(c, enabled)
  end
end

-- ===============================
-- Chrome hiding
-- ===============================

function TryHideChrome(frame)
  if not frame then return end
  if frame.titleBar and frame.titleBar.Hide then frame.titleBar:Hide() end
  if frame.border  and frame.border.Hide  then frame.border:Hide()  end
  -- Hide toolbar button containers that appear on mouseover (DetailsUpFrameInstance*, DetailsUpFrameLeftPart*)
  local kids = {frame:GetChildren()}
  for _, c in ipairs(kids) do
    local n = c:GetName() or ""
    if n:find("UpFrame") then c:Hide() end
  end
end

local function TryShowChrome(frame)
  if not frame then return end
  if frame.titleBar and frame.titleBar.Show then frame.titleBar:Show() end
  if frame.border  and frame.border.Show  then frame.border:Show()  end
  local kids = {frame:GetChildren()}
  for _, c in ipairs(kids) do
    local n = c:GetName() or ""
    if n:find("UpFrame") then c:Show() end
  end
end

-- Hook the Details base frame's OnEnter so that whenever Details re-shows its
-- toolbar on mouseover, we immediately hide it again.  HookScript appends after
-- the original script, so Details' own OnEnter fires first (shows UpFrame), then
-- ours fires and hides it.  The flag prevents double-hooking across re-embeds.
local function HookChromeHide(frame)
  if not frame or frame.__tpChromeHooked then return end
  frame.__tpChromeHooked = true
  frame:HookScript("OnEnter", function(self) TryHideChrome(self) end)
end

-- ===============================
-- Toggle Button Hook
-- ===============================
-- Right-click ElvUI's ">" panel toggle button to show/hide the meter windows.
-- Left-click still works normally (collapses the right chat panel).
-- This is different from /tpembed which fully detaches the meters.

local metersVisible = true

local function SetMetersVisible(show)
  metersVisible = show
  local function applyTo(frame)
    if not frame then return end
    local inst = frame._instance or frame.instance
    if inst then
      pcall(function()
        if show then
          inst:ShowWindow()
          TryHideChrome(frame)   -- ShowWindow restores chrome; hide it again
          HookChromeHide(frame)  -- ensure hover suppression is wired (idempotent)
        else
          inst:HideWindow()     -- properly sets ativa=false; Details won't re-show on combat
        end
      end)
    end
  end
  applyTo(meterFrame1)
  applyTo(meterFrame2)
  if show then
    -- Re-embed after ShowWindow resets geometry
    PositionFrames()
    StartRepositionTimer()
  end
end

local function HookToggleButton()
  if toggleButtonHooked then return end
  local btn = _G["RightChatToggleButton"]
  if not btn then return end
  btn:HookScript("OnMouseUp", function(self, button)
    if button == "RightButton" and embedded then
      SetMetersVisible(not metersVisible)
    end
  end)
  toggleButtonHooked = true
end

-- ===============================
-- Embed / Un-embed
-- ===============================

local function DoEmbed()
  local db = TokukoPDB.Embed
  if embedded then return end

  if InCombatLockdown() then
    print("|cffff6600TokukoP Embed:|r Cannot embed in combat. Will retry on combat end.")
    embedPending = true
    return
  end

  panelFrame = panelFrame or GetHostPanel()
  if not panelFrame then
    print("|cffff6600TokukoP Embed:|r Could not find ElvUI right chat panel. Is ElvUI loaded?")
    return
  end
  if IsEUI() and not SyncEUIHost() then
    print("|cffff6600TokukoP Embed:|r Second Chat Window not found or docked. "
          .. "Set it up under Chat > Second Window first.")
    return
  end

  local frame1 = GetDetailsFrame(db.window1)
  if not frame1 then
    print("|cffff6600TokukoP Embed:|r Could not find Details window " .. tostring(db.window1)
          .. ". Is Details installed and are its windows open?")
    return
  end

  meterFrame1 = frame1
  SaveOriginalPosition(meterFrame1, 1)
  pcall(function()
    local inst1 = meterFrame1._instance or meterFrame1.instance
    -- If Details was hidden via /details hide, ativa=false. ShowWindow resets
    -- internal state so the window is in a clean visible state before we embed.
    if inst1 and inst1.ativa == false then inst1:ShowWindow() end
  end)
  meterFrame1:SetParent(panelFrame)
  meterFrame1:SetFrameStrata("LOW")
  meterFrame1:SetAlpha(1)
  meterFrame1:SetClampedToScreen(false)
  TryHideChrome(meterFrame1)
  HookChromeHide(meterFrame1)
  meterFrame1:Show()
  pcall(function()
    local inst1 = meterFrame1._instance or meterFrame1.instance
    if inst1 then
      if inst1.rowframe then inst1.rowframe:SetFrameStrata("MEDIUM") end
      inst1:LockInstance(true)  -- uses Details' own lock; properly updates button/resizers
    end
  end)

  if db.dualEmbed then
    local frame2 = GetDetailsFrame(db.window2)
    if frame2 and frame2 ~= meterFrame1 then
      meterFrame2 = frame2
      SaveOriginalPosition(meterFrame2, 2)
      pcall(function()
        local inst2 = meterFrame2._instance or meterFrame2.instance
        if inst2 and inst2.ativa == false then inst2:ShowWindow() end
      end)
      meterFrame2:SetParent(panelFrame)
      meterFrame2:SetFrameStrata("LOW")
      meterFrame2:SetAlpha(1)
      meterFrame2:SetClampedToScreen(false)
      TryHideChrome(meterFrame2)
      HookChromeHide(meterFrame2)
      meterFrame2:Show()
      pcall(function()
        local inst2 = meterFrame2._instance or meterFrame2.instance
        if inst2 then
          if inst2.rowframe then inst2.rowframe:SetFrameStrata("MEDIUM") end
          inst2:LockInstance(true)
        end
      end)
    else
      meterFrame2 = nil
      print("|cffff6600TokukoP Embed:|r Could not find Details window "
            .. tostring(db.window2) .. ". Single embed only.")
    end
  end

  HookPanelResize()
  HookToggleButton()
  embedded = true
  metersVisible = true
  if IsEUI() then
    -- EUI's chat panel sits at the chat frame's strata; LOW Details frames
    -- could land under it. MEDIUM keeps the meters above the panel paint.
    if meterFrame1 then meterFrame1:SetFrameStrata("MEDIUM") end
    if meterFrame2 then meterFrame2:SetFrameStrata("MEDIUM") end
    StartEUITicker(function() return meterFrame1, meterFrame2 end)
  end
  PositionFrames()
  StartRepositionTimer()
end

local function DoUnembed()
  if not embedded then return end
  embedded = false
  StopEUITicker()
  if repositionTimer then repositionTimer:Cancel(); repositionTimer = nil end

  local function unembedFrame(frame)
    if not frame then return end
    local inst = frame._instance or frame.instance
    if inst then
      pcall(function()
        inst:LockInstance(false)  -- properly restores lock button and resize handles
        -- If HideWindow was called (meters were hidden), restore active state without
        -- calling ShowWindow (which would reposition before RestoreOriginalPosition runs)
        if inst.ativa == false then
          inst.ativa = true
          frame:Show()
          frame:SetAlpha(1)
          SetMouseRecursive(frame, true)
        end
        if inst.rowframe then
          inst.rowframe:SetAlpha(1)
          inst.rowframe:Show()
          inst.rowframe:SetFrameStrata("LOW")
        end
      end)
    else
      frame:SetAlpha(1)
      SetMouseRecursive(frame, true)
    end
  end

  if meterFrame1 then
    unembedFrame(meterFrame1)
    TryShowChrome(meterFrame1)
    if meterFrame1.floatingframe then meterFrame1.floatingframe:Show() end
    RestoreOriginalPosition(meterFrame1, 1)
  end
  if meterFrame2 then
    unembedFrame(meterFrame2)
    TryShowChrome(meterFrame2)
    if meterFrame2.floatingframe then meterFrame2.floatingframe:Show() end
    RestoreOriginalPosition(meterFrame2, 2)
    meterFrame2 = nil
  end
  meterFrame1 = nil
end

-- ===============================
-- Public API
-- ===============================

function EmbedModule.Toggle()
  if not TokukoPDB.Embed or not TokukoPDB.Embed.enabled then return end
  if embedded then
    DoUnembed()
    embedPending = false
  else
    DoEmbed()
  end
end

function EmbedModule.IsEmbedded() return embedded end

-- Enable/disable the whole feature. Called by the options-panel toggle.
-- Unlike Toggle() (guarded by the enabled flag so /tpembed is a no-op when the
-- module is off), this drives embed state directly, so the options toggle
-- applies live instead of needing a /reload.
function EmbedModule.SetEnabled(v)
  TokukoPDB.Embed.enabled = v
  if v then
    if not embedded then DoEmbed() end
    -- Respect "Hide Out of Combat" so enabling out of combat doesn't flash the meters.
    if embedded and TokukoPDB.Embed.combatOnly and not InCombatLockdown() then
      SetMetersVisible(false)
    end
  else
    if embedded then DoUnembed() end
    embedPending = false
  end
end

-- Re-embed with the current window/dual settings. Called when those options
-- change so they apply live. No-op if not currently embedded.
function EmbedModule.Reapply()
  if not embedded then return end
  DoUnembed()
  DoEmbed()
  if embedded and TokukoPDB.Embed.combatOnly and not InCombatLockdown() then
    SetMetersVisible(false)
  end
end

-- Re-run positioning only (e.g. the split-ratio slider). No re-embed needed.
function EmbedModule.Reposition()
  if embedded then PositionFrames() end
end

-- Apply the "Hide Out of Combat" toggle live.
function EmbedModule.SetCombatOnly(v)
  TokukoPDB.Embed.combatOnly = v
  if not embedded then return end
  if v then
    if not InCombatLockdown() then SetMetersVisible(false) end
  else
    SetMetersVisible(true)
  end
end

-- ===============================
-- Combat Visibility
-- ===============================

local function HandleCombatState(inCombat)
  local db = TokukoPDB.Embed
  if not db or not db.enabled then return end

  -- embedPending: tried to embed during combat, retry now
  if not inCombat and embedPending then
    embedPending = false
    DoEmbed()
    return
  end

  -- combatOnly: hide/show the already-embedded meters, don't unembed
  if db.combatOnly and embedded then
    SetMetersVisible(inCombat)
  end
end

-- ===============================
-- Module Interface
-- ===============================

function EmbedModule.Initialize()
  TokukoPDB.Embed = TokukoPDB.Embed or {}
  TokukoP.MergeDefaults(TokukoPDB.Embed, EmbedModule.DEFAULTS)
  -- EUI host is created lazily at embed time (the chat window may not be
  -- set up yet at login).
  if not IsEUI() then panelFrame = GetElvUIRightPanel() end
end

-- Re-hide chrome and reposition after Details restores its own state.
-- delay: seconds to wait before acting (loading screen needs more time than in-place res).
local function RehideEmbedded(delay)
  C_Timer.After(delay, function()
    if not embedded then return end
    local function rehideFrame(frame)
      if not frame then return end
      TryHideChrome(frame)
      pcall(function()
        local inst = frame._instance or frame.instance
        if inst then
          if inst.rowframe then inst.rowframe:SetFrameStrata("MEDIUM") end
          inst:LockInstance(true)
        end
      end)
    end
    rehideFrame(meterFrame1)
    rehideFrame(meterFrame2)
    PositionFrames()
    StartRepositionTimer()
  end)
end

function EmbedModule.RegisterEvents(frame)
  frame:RegisterEvent("PLAYER_REGEN_DISABLED")
  frame:RegisterEvent("PLAYER_REGEN_ENABLED")
  frame:RegisterEvent("PLAYER_ENTERING_WORLD")
  frame:RegisterEvent("PLAYER_ALIVE")  -- in-place res (battle res, Soulstone, Ankh)
end

function EmbedModule.OnEvent(event, ...)
  if event == "PLAYER_ENTERING_WORLD" then
    if not panelFrame and not IsEUI() then panelFrame = GetElvUIRightPanel() end
    C_Timer.After(1, function() HookToggleButton() end)
    local db = TokukoPDB.Embed
    if db and db.enabled then
      if embedded then
        -- Loading screen: wait for Details to finish its own post-load restore.
        RehideEmbedded(4)
      elseif not db.combatOnly then
        -- Initial login / UI reload: ElvUI ~1s, Details ~3-4s to fully restore.
        C_Timer.After(6, function()
          if db.enabled and not embedded and not InCombatLockdown() then
            DoEmbed()
          end
        end)
      end
    end

  elseif event == "PLAYER_ALIVE" then
    -- In-place resurrection (battle res, Soulstone, Ankh) — no loading screen,
    -- but Details may restore its chrome. Shorter delay than loading screen path.
    if embedded then RehideEmbedded(1.5) end

  elseif event == "PLAYER_REGEN_DISABLED" then
    HandleCombatState(true)
  elseif event == "PLAYER_REGEN_ENABLED" then
    HandleCombatState(false)
  end
end

-- ===============================
-- Slash Commands
-- ===============================

SLASH_TPEMBED1 = "/tpembed"
SlashCmdList["TPEMBED"] = function()
  EmbedModule.Toggle()
end

-- ===============================
-- Public debug function (called by DebugModule if loaded)
-- ===============================
function EmbedModule.PrintDebug()
  local db = TokukoPDB.Embed or {}
  print("|cff00ccffTokukoP Debug:|r")
  print("  embedded=" .. tostring(embedded)
        .. "  pending=" .. tostring(embedPending)
        .. "  enabled=" .. tostring(db.enabled))
  print("  dual=" .. tostring(db.dualEmbed)
        .. "  w1=" .. tostring(db.window1)
        .. "  w2=" .. tostring(db.window2))
  local panel = panelFrame or GetElvUIRightPanel()
  print("  panelFrame cached=" .. (panelFrame and "yes" or "nil"))
  print("  _G[RightChatPanel]=" .. (_G["RightChatPanel"] and "EXISTS" or "nil"))
  if panel then
    local tabH = GetTabHeight(panel)
    local barH = GetDataBarHeight()
    local yOff, epw, eph = GetEmbedRect(panel)
    print("  Panel=" .. string.format("%.1f", panel:GetWidth())
          .. "x" .. string.format("%.1f", panel:GetHeight()))
    print("  tabH=" .. string.format("%.1f", tabH)
          .. "  barH=" .. string.format("%.1f", barH)
          .. "  yOff=" .. string.format("%.1f", yOff)
          .. "  embedH=" .. string.format("%.1f", eph))
    if meterFrame1 then
      print("  meterFrame1 size=" .. string.format("%.1f", meterFrame1:GetWidth())
            .. "x" .. string.format("%.1f", meterFrame1:GetHeight()))
    end
  else
    print("  Panel NOT FOUND")
  end
  print("  Details=" .. (Details and "loaded" or "NOT LOADED"))
  if Details then
    local f1 = GetDetailsFrame(db.window1 or 1)
    local f2 = GetDetailsFrame(db.window2 or 2)
    print("  DetailsBaseFrame" .. tostring(db.window1) .. "="
          .. (_G["DetailsBaseFrame" .. tostring(db.window1)] and "EXISTS" or "nil"))
    print("  DetailsBaseFrame" .. tostring(db.window2) .. "="
          .. (_G["DetailsBaseFrame" .. tostring(db.window2)] and "EXISTS" or "nil"))
    print("  window1=" .. (f1 and (f1:GetName() or "found") or "NIL"))
    print("  window2=" .. (f2 and (f2:GetName() or "found") or "NIL"))
  end
  local btn = _G["RightChatToggleButton"]
  print("  ToggleButton=" .. (btn and "found" or "nil")
        .. "  hooked=" .. tostring(toggleButtonHooked))
  print("  InCombatLockdown=" .. tostring(InCombatLockdown()))
end
