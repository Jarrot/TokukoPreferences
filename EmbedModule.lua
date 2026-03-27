-- EmbedModule.lua
-- Embeds Details! damage/healing meter windows into ElvUI's right chat panel.
-- Toggle via /tpembed or right-click the ElvUI panel toggle button (">").

local ADDON_NAME = ...
local TokukoP = TokukoP

local EmbedModule = {}
TokukoP.modules.Embed = EmbedModule

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

local function PositionFrames()
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
    -- Shift frame UP by titleBar height so hidden title is above panel top
    -- and bar content starts flush with the tab strip
    local titleH1 = (meterFrame1.titleBar and meterFrame1.titleBar:GetHeight()) or 0
    ForceDetailsSize(meterFrame1, w1, ph + titleH1)
    meterFrame1:ClearAllPoints()
    meterFrame1:SetPoint("TOPLEFT",    panelFrame,     "TOPLEFT",        0, yOff + titleH1)
    meterFrame1:SetPoint("BOTTOMLEFT", botAnchorFrame, botAnchorPoint,   0, botOffset)
    meterFrame1:SetWidth(w1)
    if meterFrame1.floatingframe then meterFrame1.floatingframe:Hide() end
    -- Lock the window so users can't accidentally drag it out
    if meterFrame1.isLocked ~= nil then meterFrame1.isLocked = true end
  end

  if db.dualEmbed and meterFrame2 then
    local w1 = math.floor(pw * TokukoP.Clamp(db.splitRatio, 0.2, 0.8))
    local w2 = pw - w1 - 1
    local titleH2 = (meterFrame2.titleBar and meterFrame2.titleBar:GetHeight()) or 0
    ForceDetailsSize(meterFrame2, w2, ph + titleH2)
    meterFrame2:ClearAllPoints()
    meterFrame2:SetPoint("TOPRIGHT",    panelFrame,     "TOPRIGHT",        -1, yOff + titleH2)
    meterFrame2:SetPoint("BOTTOMRIGHT", botAnchorFrame, botAnchorPointR,   -1, botOffset)
    meterFrame2:SetWidth(w2)
    if meterFrame2.floatingframe then meterFrame2.floatingframe:Hide() end
    if meterFrame2.isLocked ~= nil then meterFrame2.isLocked = true end
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

-- ===============================
-- Chrome (title bar) hiding
-- ===============================

local function TryHideChrome(frame)
  if not frame then return end
  -- Title bar
  if frame.titleBar and frame.titleBar.Hide then frame.titleBar:Hide() end
  -- Border frame (creates rounded corners, extends outside frame bounds)
  if frame.border and frame.border.Hide then frame.border:Hide() end
  -- Skada / generic fallback
  local name = frame:GetName()
  local bar = frame.title or frame.TitleBar
              or (name and _G[name .. "TitleBar"])
  if bar and bar.Hide then bar:Hide() end
end

local function TryShowChrome(frame)
  if not frame then return end
  if frame.titleBar and frame.titleBar.Show then frame.titleBar:Show() end
  if frame.border  and frame.border.Show  then frame.border:Show()  end
  local name = frame:GetName()
  local bar = frame.title or frame.TitleBar
              or (name and _G[name .. "TitleBar"])
  if bar and bar.Show then bar:Show() end
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
  if meterFrame1 then
    if show then meterFrame1:Show() else meterFrame1:Hide() end
  end
  if meterFrame2 then
    if show then meterFrame2:Show() else meterFrame2:Hide() end
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

  panelFrame = panelFrame or GetElvUIRightPanel()
  if not panelFrame then
    print("|cffff6600TokukoP Embed:|r Could not find ElvUI right chat panel. Is ElvUI loaded?")
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
  meterFrame1:SetParent(panelFrame)
  meterFrame1:SetFrameStrata("LOW")
  meterFrame1:SetClampedToScreen(false)
  TryHideChrome(meterFrame1)
  meterFrame1:Show()

  if db.dualEmbed then
    local frame2 = GetDetailsFrame(db.window2)
    if frame2 and frame2 ~= meterFrame1 then
      meterFrame2 = frame2
      SaveOriginalPosition(meterFrame2, 2)
      meterFrame2:SetParent(panelFrame)
      meterFrame2:SetFrameStrata("LOW")
      meterFrame2:SetClampedToScreen(false)
      TryHideChrome(meterFrame2)
      meterFrame2:Show()
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
  PositionFrames()
  StartRepositionTimer()
  print("|cff00ff00TokukoP Embed:|r Meter embedded. Right-click \">\" to hide/show. /tpembed to detach.")
end

local function DoUnembed()
  if not embedded then return end
  embedded = false
  if repositionTimer then repositionTimer:Cancel(); repositionTimer = nil end

  if meterFrame1 then
    TryShowChrome(meterFrame1)
    if meterFrame1.floatingframe then meterFrame1.floatingframe:Show() end
    if meterFrame1.isLocked ~= nil then meterFrame1.isLocked = false end
    RestoreOriginalPosition(meterFrame1, 1)
  end
  if meterFrame2 then
    TryShowChrome(meterFrame2)
    if meterFrame2.floatingframe then meterFrame2.floatingframe:Show() end
    if meterFrame2.isLocked ~= nil then meterFrame2.isLocked = false end
    RestoreOriginalPosition(meterFrame2, 2)
    meterFrame2 = nil
  end
  meterFrame1 = nil
  print("|cff00ff00TokukoP Embed:|r Meter detached.")
end

-- ===============================
-- Public API
-- ===============================

function EmbedModule.Toggle()
  if not TokukoPDB.Embed or not TokukoPDB.Embed.enabled then
    print("|cffff6600TokukoP Embed:|r Embed is disabled. Enable it in /tp settings first.")
    return
  end
  if embedded then
    DoUnembed()
    embedPending = false
  else
    DoEmbed()
  end
end

function EmbedModule.IsEmbedded() return embedded end

-- ===============================
-- Combat Visibility
-- ===============================

local function HandleCombatState(inCombat)
  local db = TokukoPDB.Embed
  if not db or not db.enabled then return end
  if not inCombat then
    if embedPending then embedPending = false; DoEmbed(); return end
    if db.combatOnly and embedded then DoUnembed() end
  else
    if db.combatOnly and not embedded then DoEmbed() end
  end
end

-- ===============================
-- Module Interface
-- ===============================

function EmbedModule.Initialize()
  TokukoPDB.Embed = TokukoPDB.Embed or {}
  TokukoP.MergeDefaults(TokukoPDB.Embed, EmbedModule.DEFAULTS)
  panelFrame = GetElvUIRightPanel()
end

function EmbedModule.RegisterEvents(frame)
  frame:RegisterEvent("PLAYER_REGEN_DISABLED")
  frame:RegisterEvent("PLAYER_REGEN_ENABLED")
  frame:RegisterEvent("PLAYER_ENTERING_WORLD")
end

function EmbedModule.OnEvent(event, ...)
  if event == "PLAYER_ENTERING_WORLD" then
    if not panelFrame then panelFrame = GetElvUIRightPanel() end
    -- Hook toggle button as early as possible
    C_Timer.After(1, function() HookToggleButton() end)
    local db = TokukoPDB.Embed
    if db and db.enabled and not db.combatOnly and not embedded then
      -- 6s defer: ElvUI ~1s, Details ~3-4s to fully restore windows
      C_Timer.After(6, function()
        if db.enabled and not embedded and not InCombatLockdown() then
          DoEmbed()
        end
      end)
    end
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
