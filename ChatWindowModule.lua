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
}

local MIN_W, MIN_H = 100, 50

-- ===============================
-- State
-- ===============================

local db           = nil
local pendingApply = false   -- an apply was requested in combat

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
-- Apply
-- ===============================

local function ApplyNow()
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
end

-- Deferred one frame: never run inside a Blizzard chat/dock pass.
function ChatWindowModule.Apply()
  C_Timer.After(0, ApplyNow)
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
function ChatWindowModule.UseCurrent()
  local cf = ChatWindowModule.FindWindow()
  if not cf then return end
  local r, b = cf:GetRight(), cf:GetBottom()
  local w, h = cf:GetSize()
  if not (r and b and w and h) then return end
  local s = cf:GetEffectiveScale() / UIParent:GetEffectiveScale()
  db.x = math.floor(UIParent:GetWidth() - r * s + 0.5)
  db.y = math.floor(b * s + 0.5)
  db.width, db.height = math.floor(w * s + 0.5), math.floor(h * s + 0.5)
  ChatWindowModule.Apply()
end

-- ===============================
-- Lifecycle
-- ===============================

function ChatWindowModule.Initialize()
  TokukoPDB.ChatWindow = TokukoPDB.ChatWindow or {}
  TokukoP.MergeDefaults(TokukoPDB.ChatWindow, DEFAULTS)
  db = TokukoPDB.ChatWindow
end

function ChatWindowModule.RegisterEvents(frame)
  frame:RegisterEvent("PLAYER_ENTERING_WORLD")
  frame:RegisterEvent("UPDATE_CHAT_WINDOWS")
  frame:RegisterEvent("PLAYER_REGEN_ENABLED")
end

function ChatWindowModule.OnEvent(event)
  if event == "PLAYER_ENTERING_WORLD" then
    -- Blizzard restores saved chat positions/sizes around login and loading
    -- screens; land after it.
    C_Timer.After(1, ApplyNow)
  elseif event == "UPDATE_CHAT_WINDOWS" then
    ChatWindowModule.Apply()
  elseif event == "PLAYER_REGEN_ENABLED" then
    if pendingApply then
      pendingApply = false
      ChatWindowModule.Apply()
    end
  end
end
