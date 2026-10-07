-- ChatWindowModule.lua
-- EllesmereUI only: exact size and position for a free-floating (undocked)
-- chat window -- the EUI equivalent of ElvUI's right chat panel. EUI styles
-- every chat window the same (background, border, tab), so a real undocked
-- window already looks like the main chat; this adds the numbers EUI does
-- not offer. The window is also the host the Details embed will target.
--
-- The player creates the window (right-click a tab > New Window, drag the
-- tab off to undock). We never create, dock or undock chat windows: those
-- write Blizzard's dock state from insecure code, which EllesmereUIChat
-- documents as tainting the secure whisper temp-window chain.
--
-- Sizing follows EllesmereUIChat's own rule for the main chat: NEVER SetSize
-- a chat frame. Pin two corners instead (TOPLEFT + BOTTOMRIGHT); the rect is
-- then anchor-determined, the engine layout pass recomputes it, and the
-- frame's OnSizeChanged dispatches as a fresh SECURE execution. Out of
-- combat only, deferred out of any Blizzard pass with C_Timer.
--
-- Applied ONLY when a setting changes (panel, shortcut buttons, Unlock Mode)
-- -- no login / loading-screen / chat-update handling. Persistence is
-- Blizzard's own: each apply also writes the window's saved position and
-- dimensions (SetChatWindowSavedPosition / SetChatWindowSavedDimensions, the
-- two C calls FCF_SavePositionAndDimensions makes on a drag-stop), and
-- Blizzard's FloatingChatFrame_Update restores undocked windows from that
-- store at login and on every chat-window update (FCF_RestorePositionAndDimensions).

local ADDON_NAME = ...
local TokukoP = TokukoP

local ChatWindowModule = {}
TokukoP.modules.ChatWindow = ChatWindowModule

ChatWindowModule.HOSTS = { ellesmere = true }

-- ===============================
-- Constants
-- ===============================

local DEFAULTS = {
  enabled    = false,      -- off until a window is set up
  windowName = "Details",
  width      = 430,
  height     = 180,
  x          = 40,         -- from the screen's RIGHT edge
  y          = 40,         -- from the screen's BOTTOM edge
  matchBorder = true,      -- copy the main chat's panel border onto the window
}

local MIN_W, MIN_H = 100, 50

-- ===============================
-- State
-- ===============================

local db           = nil
local pendingApply = false   -- an apply was requested in combat
local border       = nil     -- our copy of EUI's chat panel border

-- ===============================
-- Helpers
-- ===============================

-- Edit Mode-managed frames replace SetPoint/ClearAllPoints with Lua overrides;
-- call the saved C methods when present (same as EllesmereUI.SetFramePoint).
-- Undocked chat windows are not Edit Mode systems, so this is the plain call.
local function ClearPoints(f)
  local clear = f.ClearAllPointsBase or f.ClearAllPoints
  clear(f)
end

local function SetPoint(f, ...)
  local set = f.SetPointBase or f.SetPoint
  set(f, ...)
end

-- The chat frame whose tab name matches (case-insensitive). Public API only.
function ChatWindowModule.FindWindow()
  if not db or not db.windowName or db.windowName == "" then return nil end
  local want = db.windowName:lower()
  for i = 1, (NUM_CHAT_WINDOWS or 10) do
    local name = GetChatWindowInfo(i)
    if type(name) == "string" and name:lower() == want then
      local cf = _G["ChatFrame" .. i]
      if cf then return cf, i end
    end
  end
  return nil
end

-- "ok" | "missing" | "docked" | "main" -- for the settings page status line.
function ChatWindowModule.Status()
  local cf = ChatWindowModule.FindWindow()
  if not cf then return "missing" end
  if cf == ChatFrame1 then return "main" end
  if cf.isDocked then return "docked" end
  return "ok"
end

-- ===============================
-- EllesmereUIChat refresh
-- ===============================
-- EUI places its chat panel and the undocked window's tab ghost NUMERICALLY
-- from the chat frame's rect, re-read only while chat is interacted with
-- (hovering a tab / resize grip, Edit or Unlock Mode) -- "NO recurring work at
-- idle". Moving the window from code is invisible to it, so the panel and tab
-- lag until the next hover. There is no public API for this; the one call
-- below reaches EllesmereUIChat's internal namespace (EUI's plugin guide asks
-- addons not to). QueueTabPass is EUI's own deferred, coalesced pass (tab
-- layout + SyncChatFrameState + PositionChatPanelsNow). Guarded: if an EUI
-- update renames it, this silently does nothing and the old lag is back.
local function NudgeEUIChat()
  local ns = EllesmereUI and EllesmereUI._ModuleNS and EllesmereUI._ModuleNS.EllesmereUIChat
  local ECHAT = ns and ns.ECHAT
  if not ECHAT then return end
  -- Let the engine resolve the new anchors first.
  C_Timer.After(0.05, function()
    if ECHAT.QueueTabPass then
      pcall(ECHAT.QueueTabPass)
    elseif ECHAT.PositionChatPanelsNow then
      pcall(ECHAT.PositionChatPanelsNow)
    end
  end)
end

-- ===============================
-- Panel border
-- ===============================
-- EUI's Chat "Border" setting (thickness / colour / texture) frames ONE panel:
-- ns._chatPanelBorder, wrapped around ChatFrame1's background only. Every
-- other chat window gets the background but no border, so the second window
-- needs its own copy. Built the same way as EUI's (EllesmereUIChat.lua,
-- ApplyExtendedBackground): a BackdropTemplate frame pinned to the window's
-- EUI background, styled with the public EllesmereUI.ApplyBorderStyle from
-- the chat profile. Parented to that background, so it shows/hides, fades
-- and follows the panel host with it -- EUI keeps the background in sync.
-- Reads EUI internals (chat profile, per-frame data); guarded, and does
-- nothing if they move. Restyled on our setting changes, at login, and when
-- the EUI settings panel closes (public EllesmereUI:RegisterOnHide) -- the
-- only place EUI's border settings change -- so no reload is needed.

local BORDER_SIZES = { none = 0, thin = 1, normal = 2, heavy = 3, strong = 4 }

local function HideBorder()
  if border then border:Hide() end
end

local function ApplyBorderNow()
  local cf = ChatWindowModule.FindWindow()
  if not (db and db.enabled and db.matchBorder) or not cf or cf == ChatFrame1 or cf.isDocked then
    return HideBorder()
  end
  local EUI = EllesmereUI
  local ns = EUI and EUI._ModuleNS and EUI._ModuleNS.EllesmereUIChat
  local ECHAT = ns and ns.ECHAT
  local bg = EUI and EUI._chatCFD and EUI._chatCFD(cf).bg
  if not (ECHAT and ECHAT.DB and bg and EUI.ApplyBorderStyle) then return HideBorder() end
  -- Stock styles: Blizzard's own chat border is the border (EUI hides its own).
  if ns.ChatStock and ns.ChatStock() then return HideBorder() end
  local cfg = ECHAT.DB()

  if not border then
    border = CreateFrame("Frame", nil, bg, "BackdropTemplate")
    border:EnableMouse(false)
  elseif border:GetParent() ~= bg then
    border:SetParent(bg)
  end
  border:ClearAllPoints()
  border:SetAllPoints(bg)

  -- Same strata / level rules as EUI's panel border.
  local behind = cfg.panelBorderBehind == true
  border:SetFrameStrata(behind and "BACKGROUND" or "MEDIUM")
  local level = behind and 0 or math.max(96, math.min(98, cf:GetFrameLevel() + 20))
  border:SetFrameLevel(level)

  local thicknessKey = cfg.panelBorderThickness or "none"
  local mode = cfg.panelBorderColorMode or "custom"
  local color
  if mode == "accent" and EUI.GetAccentColor then
    local r, g, b = EUI.GetAccentColor()
    color = { r = r, g = g, b = b }
  elseif mode == "class" then
    local _, class = UnitClass("player")
    color = class and RAID_CLASS_COLORS[class] or { r = 1, g = 1, b = 1 }
  else
    color = cfg.panelBorderColor or { r = 1, g = 1, b = 1 }
  end
  local alpha = cfg.panelBorderOpacity
  if alpha == nil then alpha = mode == "custom" and 0.18 or 0.5 end
  local size = BORDER_SIZES[thicknessKey] or 1
  local tex = cfg.panelBorderTexture or "solid"
  local px = EUI.BorderPx and EUI.BorderPx(cfg.panelBorderThicknessPx, size, tex)
  -- Shown first: the textured path does not re-show a frame we hid; a
  -- thickness of "none" hides it again inside ApplyBorderStyle.
  border:Show()
  local ok = pcall(EUI.ApplyBorderStyle, border, size,
    color.r, color.g, color.b, alpha, tex,
    cfg.panelBorderOffsetX, cfg.panelBorderOffsetY,
    cfg.panelBorderShiftX, cfg.panelBorderShiftY, "chat", thicknessKey, nil, px)
  if not ok then return HideBorder() end
  local PP = EUI.PP
  local solid = PP and PP.GetBorders and PP.GetBorders(border)
  if solid then solid:SetFrameLevel(level + (behind and 0 or 1)) end
end

-- After EUI has (re)placed the window's background.
function ChatWindowModule.ApplyBorder()
  C_Timer.After(0.1, ApplyBorderNow)
end

-- ===============================
-- Apply
-- ===============================

local function ApplyNow()
  ChatWindowModule.ApplyBorder()
  if not (db and db.enabled) then return end
  if InCombatLockdown() then pendingApply = true; return end
  local cf = ChatWindowModule.FindWindow()
  -- Never touch the main window (Edit Mode / EUI own it) or a docked one
  -- (the dock owns its geometry).
  if not cf or cf == ChatFrame1 or cf.isDocked then return end

  local w = math.max(MIN_W, db.width)
  local h = math.max(MIN_H, db.height)
  local x, y = db.x, db.y
  ClearPoints(cf)
  SetPoint(cf, "BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -x, y)
  SetPoint(cf, "TOPLEFT", UIParent, "BOTTOMRIGHT", -x - w, y + h)

  -- Blizzard's store, in FCF_SavePositionAndDimensions' format: offsets as
  -- fractions of the screen, restored as SetPoint(point, xOff * GetScreenWidth(),
  -- yOff * GetScreenHeight()). Only C calls -- no Blizzard Lua state written.
  local id = cf:GetID()
  local sw, sh = GetScreenWidth(), GetScreenHeight()
  if id and sw and sh and sw > 0 and sh > 0 then
    SetChatWindowSavedPosition(id, "BOTTOMRIGHT", -x / sw, y / sh)
    SetChatWindowSavedDimensions(id, w, h)
  end
  NudgeEUIChat()
  -- A window setting changed: re-fit the Details embed to it (EUI only;
  -- no-op when the embed is off). After the anchors resolve.
  local EM = TokukoP.modules.Embed
  if EM and EM.Fit and TokukoP.activeModules and TokukoP.activeModules.Embed then
    C_Timer.After(0.15, EM.Fit)
  end
end

-- Deferred one frame: never run inside a Blizzard chat/dock pass.
function ChatWindowModule.Apply()
  C_Timer.After(0, ApplyNow)
end

-- ===============================
-- EllesmereUI Unlock Mode
-- ===============================
-- EUI_UnlockMode.lua: "Elements from any addon register via
-- EllesmereUI:RegisterUnlockElements()". The mover places the frame with ONE
-- anchor point on every drag tick / nudge, which would drop our second corner
-- and fall back to the frame's explicit size -- so onLiveMove re-pins both
-- corners from that single point (EllesmereUIChat's KeepMainChatSizeCorner
-- does the same for ChatFrame1). Resizes come through setWidth/setHeight,
-- which only update the DB and re-anchor: still never SetSize.

local UNLOCK_KEY = "TokukoP_ChatWindow"

-- Re-pin TOPLEFT + BOTTOMRIGHT from whatever single point the mover set.
local function RepinFromSinglePoint()
  local cf = ChatWindowModule.FindWindow()
  if not cf or cf == ChatFrame1 or cf.isDocked or InCombatLockdown() then return end
  if cf:GetNumPoints() ~= 1 then return end
  local point, rel, relPoint, px, py = cf:GetPoint(1)
  if rel ~= UIParent or type(px) ~= "number" or type(py) ~= "number" then return end
  local issecret = issecretvalue
  if issecret and (issecret(px) or issecret(py)) then return end
  relPoint = relPoint or point
  local w, h = math.max(MIN_W, db.width), math.max(MIN_H, db.height)
  -- Offset from the given point to the frame's TOPLEFT corner.
  local dx = point:find("LEFT") and 0 or point:find("RIGHT") and -w or -w / 2
  local dy = point:find("TOP") and 0 or point:find("BOTTOM") and h or h / 2
  local left, top = px + dx, py + dy
  ClearPoints(cf)
  SetPoint(cf, "TOPLEFT", UIParent, relPoint, left, top)
  SetPoint(cf, "BOTTOMRIGHT", UIParent, relPoint, left + w, top - h)
  NudgeEUIChat()
end

-- Unlock Mode stores positions as CENTER/CENTER offsets from UIParent's
-- centre; ours are offsets from the bottom-right corner.
local function CenterFromDB()
  local W, H = UIParent:GetWidth(), UIParent:GetHeight()
  local cx = (W - db.x - db.width / 2) - W / 2
  local cy = (db.y + db.height / 2) - H / 2
  return cx, cy
end

local function DBFromCenter(cx, cy)
  local W, H = UIParent:GetWidth(), UIParent:GetHeight()
  db.x = math.floor(W - (W / 2 + cx + db.width / 2) + 0.5)
  db.y = math.floor((H / 2 + cy - db.height / 2) + 0.5)
end

function ChatWindowModule.RegisterUnlock()
  if not (EllesmereUI and EllesmereUI.RegisterUnlockElements and EllesmereUI.MakeUnlockElement) then
    return
  end
  EllesmereUI:RegisterUnlockElements({
    EllesmereUI.MakeUnlockElement({
      key      = UNLOCK_KEY,
      label    = "Second Chat",
      group    = "Chat",
      order    = 610,  -- right after EUI's own Chat (600)
      subtitle = "TokukoPreferences",
      -- We place the window ourselves (login, settings); anchor links to other
      -- elements would make EUI a second owner of a chat frame. Other
      -- elements may still anchor TO it (e.g. a data bar under it).
      ownsPosition = true,
      noInitHook   = true,
      isHidden = function()
        return not (db and db.enabled and ChatWindowModule.Status() == "ok")
      end,
      getFrame = function() return ChatWindowModule.FindWindow() end,
      getSize  = function() return db.width, db.height end,
      onLiveMove = RepinFromSinglePoint,
      savePos = function(_, point, relPoint, x, y)
        if point == "CENTER" and (relPoint or point) == "CENTER"
           and type(x) == "number" and type(y) == "number" then
          DBFromCenter(x, y)
        else
          ChatWindowModule.UseCurrent()
          return
        end
        ChatWindowModule.Apply()
      end,
      loadPos = function()
        local cx, cy = CenterFromDB()
        return { point = "CENTER", relPoint = "CENTER", x = cx, y = cy }
      end,
      applyPos = function() ChatWindowModule.Apply() end,
      setWidth = function(_, w)
        db.width = math.max(MIN_W, math.floor(w + 0.5))
        ApplyNow()
      end,
      setHeight = function(_, h)
        db.height = math.max(MIN_H, math.floor(h + 0.5))
        ApplyNow()
      end,
    }),
  }, ADDON_NAME)
end

-- ===============================
-- Settings helpers (buttons)
-- ===============================

-- Width/height of the main chat window.
function ChatWindowModule.MatchMainSize()
  local w, h = ChatFrame1:GetSize()
  if not (w and h) then return end
  db.width, db.height = math.floor(w + 0.5), math.floor(h + 0.5)
  ChatWindowModule.Apply()
end

-- Same bottom offset as the main chat, and the same distance from the right
-- edge as the main chat has from the left edge.
function ChatWindowModule.MirrorMain()
  local l, b = ChatFrame1:GetLeft(), ChatFrame1:GetBottom()
  if not (l and b) then return end
  local s = ChatFrame1:GetEffectiveScale() / UIParent:GetEffectiveScale()
  db.x, db.y = math.floor(l * s + 0.5), math.floor(b * s + 0.5)
  ChatWindowModule.Apply()
end

-- Read wherever the window was dragged / resized to.
-- Store the window's live rect (after a hand drag / resize) as our numbers.
local function Capture()
  local cf = ChatWindowModule.FindWindow()
  if not cf or cf == ChatFrame1 or cf.isDocked then return false end
  local r, b = cf:GetRight(), cf:GetBottom()
  local w, h = cf:GetSize()
  if not (r and b and w and h) then return false end
  local issecret = issecretvalue
  if issecret and (issecret(r) or issecret(b) or issecret(w) or issecret(h)) then return false end
  local s = cf:GetEffectiveScale() / UIParent:GetEffectiveScale()
  db.x = math.floor(UIParent:GetWidth() - r * s + 0.5)
  db.y = math.floor(b * s + 0.5)
  db.width, db.height = math.floor(w * s + 0.5), math.floor(h * s + 0.5)
  return true
end

function ChatWindowModule.UseCurrent()
  if Capture() then ChatWindowModule.Apply() end
end

-- ===============================
-- Lifecycle
-- ===============================

function ChatWindowModule.Initialize()
  TokukoPDB.ChatWindow = TokukoPDB.ChatWindow or {}
  TokukoP.MergeDefaults(TokukoPDB.ChatWindow, DEFAULTS)
  db = TokukoPDB.ChatWindow
  -- Registered once; isHidden() keeps the mover away until the window is
  -- enabled and found, and is re-read whenever Unlock Mode opens.
  ChatWindowModule.RegisterUnlock()
  -- EUI border edits happen in its settings panel: re-copy on close.
  if EllesmereUI and EllesmereUI.RegisterOnHide then
    EllesmereUI:RegisterOnHide(ChatWindowModule.ApplyBorder)
  end
end

function ChatWindowModule.RegisterEvents(frame)
  frame:RegisterEvent("PLAYER_REGEN_ENABLED")
  frame:RegisterEvent("PLAYER_ENTERING_WORLD")
end

function ChatWindowModule.OnEvent(event, isInitialLogin, isReloadingUi)
  -- Border only (style, not geometry): EUI skins the chat frames at login,
  -- so give it a moment before reading the window's background.
  if event == "PLAYER_ENTERING_WORLD" and (isInitialLogin or isReloadingUi) then
    C_Timer.After(2, ApplyBorderNow)
  elseif event == "PLAYER_REGEN_ENABLED" and pendingApply then
    pendingApply = false
    ChatWindowModule.Apply()
  end
end
