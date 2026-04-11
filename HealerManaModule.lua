-- HealerManaModule.lua
-- Displays a movable overlay with each healer's name and mana percentage.
-- Sorted lowest mana first. Hides automatically when no healers are present.

local ADDON_NAME = ...
local TokukoP = TokukoP

local HealerManaModule = {}
TokukoP.modules.HealerMana = HealerManaModule

-- ===============================
-- Defaults
-- ===============================

HealerManaModule.DEFAULTS = {
  enabled       = false,
  locked        = false,
  growUp        = false,
  font          = "Fonts\\ARIALN.TTF",
  fontSize      = 13,
  useClassColor = true,
  color         = { r = 1, g = 1, b = 1 },
  bgAlpha       = 0.8,
  textAlpha     = 1.0,
  posX          = 0,
  posY          = 200,
  width         = 200,
  displayMode   = "percent",  -- "percent", "value", "both"
}

-- ===============================
-- Constants
-- ===============================

local LINE_PAD    = 2    -- px between lines
local FRAME_PAD   = 6    -- px of padding inside frame border
local MAX_HEALERS = 16   -- pre-allocated FontString pool
local TICK_RATE   = 1.0  -- seconds between updates

-- Fallback fonts used when LibSharedMedia is not available.
local FONT_DEFS_FALLBACK = {
  { key = "Fonts\\ARIALN.TTF",   label = "Arial Narrow" },
  { key = "Fonts\\FRIZQT__.TTF", label = "Default"      },
  { key = "Fonts\\MORPHEUS.TTF", label = "Morpheus"     },
  { key = "Fonts\\SKURRI.TTF",   label = "Skurri"       },
}

-- Populated in Initialize() from LibSharedMedia (same source as ElvUI font dropdowns).
-- Falls back to FONT_DEFS_FALLBACK if LSM is not available.
-- key = font path, value = display name (AceConfig select format).
HealerManaModule.FONT_VALUES  = {}
HealerManaModule.FONT_SORTING = {}
for _, fd in ipairs(FONT_DEFS_FALLBACK) do
  HealerManaModule.FONT_VALUES[fd.key] = fd.label
  table.insert(HealerManaModule.FONT_SORTING, fd.key)
end

-- ===============================
-- State
-- ===============================

local container   = nil
local nameLines   = {}   -- left-aligned name FontString pool
local pctLines    = {}   -- right-aligned percentage FontString pool
local lastCount   = 0    -- most recent healer count; used by OnSizeChanged
local LayoutLines        -- forward declaration (defined after BuildContainer)
local previewMode = false
local bgR, bgG, bgB         = 0, 0, 0      -- set in BuildContainer; used by RefreshBgAlpha
local borderR, borderG, borderB = 0.35, 0.35, 0.35

local FAKE_HEALERS = {
  { name = "Tokukheal",  mana = 12, manaVal =  5750, class = "PRIEST"  },
  { name = "Jarrotdruid",mana = 45, manaVal = 21600, class = "DRUID"   },
  { name = "Holypala",   mana = 67, manaVal = 32160, class = "PALADIN" },
  { name = "Mistweave",  mana = 81, manaVal = 38880, class = "MONK"    },
  { name = "Restosham",  mana = 93, manaVal = 44640, class = "SHAMAN"  },
}

-- ===============================
-- Helpers
-- ===============================

local function GetClassColor(classFilename)
  if C_ClassColor and C_ClassColor.GetClassColor then
    local c = C_ClassColor.GetClassColor(classFilename)
    if c then return c.r, c.g, c.b end
  end
  local rc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFilename]
  if rc then return rc.r, rc.g, rc.b end
  return 1, 1, 1
end

-- CurveConstants.ScaleTo100: pass as last arg to UnitPowerPercent/UnitHealthPercent
-- so the API scales the result to 0-100 inside Blizzard's secure C code.
-- We never need to multiply by 100 ourselves — avoids all arithmetic on secrets.
-- Technique confirmed from oUF/ElvUI tags.lua.
local ScaleTo100 = CurveConstants and CurveConstants.ScaleTo100

local warnedMissingAPI = false

-- Returns pixel width for the right (mana) column based on display mode and font size.
-- Uses ~0.65×fontSize per character; different fonts vary, but the frame is resizable.
local function GetPctWidth(mode, fontSize)
  -- Tight fit: just enough for worst-case text so names get maximum room.
  -- Frame is resizable if more space is needed.
  local cw = fontSize * 0.65
  if mode == "percent" then
    return math.ceil(cw * 4.2)   -- "100%"
  elseif mode == "value" then
    return math.ceil(cw * 5.5)   -- "999.9k"
  else  -- both: "44.6k  100%"
    return math.ceil(cw * 9.0)
  end
end

-- Format an absolute mana number as a short string: "45.2k", "999", "1.2M".
local function FormatManaValue(n)
  if not n then return "?" end
  n = math.floor(n)
  if n >= 1000000 then return string.format("%.1fM", n / 1000000) end
  if n >= 1000    then return string.format("%.1fk", n / 1000)    end
  return tostring(n)
end

-- Returns sortVal (0-100), pctDisplay ("93%").
-- Uses CurveConstants.ScaleTo100 so UnitPowerPercent returns 0-100 inside
-- Blizzard's secure C code — no addon-side multiplication needed.
-- Technique taken from oUF/ElvUI tags.lua (pcall + format('%d')).
local function GetManaPct(unit)
  if not UnitPowerPercent then
    if not warnedMissingAPI then
      warnedMissingAPI = true
      print("|cffffcc00TokukoP:|r UnitPowerPercent not found — healer mana display unavailable.")
    end
    return 0, "?%"
  end

  local ok, pct = pcall(UnitPowerPercent, unit, 0, true, ScaleTo100)
  if not ok or pct == nil then return 0, "?%" end

  -- For "player" the result is a real float (e.g. 93.0) — arithmetic is safe.
  local arithOk, n = pcall(math.floor, pct)
  if arithOk then
    return n, n .. "%"
  end

  -- Secret value (raid/party in 12.x): format('%d', secret) produces a
  -- tainted but displayable integer string without any addon arithmetic.
  local display = string.format("%d%%", pct)
  -- Pass pct as sortVal too; table.sort comparison is already pcall'd so if
  -- secret comparison is blocked the sort simply won't run.
  return pct, display
end

-- Returns the mana value as a display string (e.g. "45.2k") or nil if unavailable.
-- UnitPower for non-player units is secret in 12.x — arithmetic is blocked, but
-- format("%d") produces a tainted displayable integer string (no abbreviation).
local function GetManaAbsoluteStr(unit)
  local rawCur = UnitPower(unit, 0)
  if rawCur == nil then return nil end
  -- Direct arithmetic works for player / non-restricted contexts.
  local ok, v = pcall(function() return rawCur + 0 end)
  if ok then return FormatManaValue(v) end  -- "45.2k"
  -- Secret: show raw integer (can't divide for abbreviation).
  local s = nil
  pcall(function() s = string.format("%d", rawCur) end)
  return s  -- "45230" tainted-but-displayable, or nil on failure
end

-- Returns sortVal, displayStr formatted according to db.displayMode.
-- "both" shows absolute first, then percent: "44.6k 93%"
-- Falls back to percent-only if absolute value is unavailable.
local function GetManaInfo(unit)
  local sortVal, pctStr = GetManaPct(unit)
  local mode = TokukoPDB.HealerMana.displayMode or "percent"
  if mode == "percent" then
    return sortVal, pctStr
  elseif mode == "value" then
    local valStr = GetManaAbsoluteStr(unit)
    return sortVal, valStr or pctStr  -- fallback to % if absolute unavailable
  else  -- "both": absolute first so the more-informative number leads
    local valStr = GetManaAbsoluteStr(unit)
    if valStr then
      return sortVal, valStr .. "  " .. pctStr
    end
    return sortVal, pctStr  -- fallback to % only
  end
end

-- ===============================
-- Frame Construction
-- ===============================

local function BuildContainer()
  local db = TokukoPDB.HealerMana
  local f  = CreateFrame("Frame", "TokukoPHealerManaFrame", UIParent, "BackdropTemplate")
  f:SetFrameStrata("MEDIUM")
  f:SetSize(db.width, 20)
  f:SetMovable(true)
  f:SetResizable(true)
  f:SetResizeBounds(100, 20)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetClampedToScreen(true)

  -- Use ElvUI's own skin if available — SetTemplate("Default") is added to the Frame
  -- metatable by ElvUI and picks up whatever backdrop/border the user has configured.
  -- We read back the RGB it applied, then reapply with our own bgAlpha.
  local elvuiSkinOk = false
  if ElvUI then
    elvuiSkinOk = pcall(function() f:SetTemplate("Default") end)
  end

  if elvuiSkinOk then
    bgR, bgG, bgB             = f:GetBackdropColor()
    borderR, borderG, borderB = f:GetBackdropBorderColor()
    bgR, bgG, bgB             = bgR or 0.06, bgG or 0.06, bgB or 0.06
    borderR, borderG, borderB = borderR or 0.25, borderG or 0.25, borderB or 0.25
  else
    bgR, bgG, bgB           = 0, 0, 0
    borderR, borderG, borderB = 0.35, 0.35, 0.35
    f:SetBackdrop({
      bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 8, edgeSize = 8,
      insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
  end
  f:SetBackdropColor(bgR, bgG, bgB, db.bgAlpha)
  f:SetBackdropBorderColor(borderR, borderG, borderB, db.bgAlpha)

  f:SetScript("OnDragStart", function(self)
    if not TokukoPDB.HealerMana.locked then self:StartMoving() end
  end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local db     = TokukoPDB.HealerMana
    local ux, uy = UIParent:GetCenter()
    db.posX = self:GetLeft() - ux
    db.posY = db.growUp and (self:GetBottom() - uy) or (self:GetTop() - uy)
  end)
  f:HookScript("OnSizeChanged", function(self)
    TokukoPDB.HealerMana.width = self:GetWidth()
    if lastCount > 0 then LayoutLines(lastCount) end
  end)

  -- Resize handle — right edge drag, hidden when locked.
  -- Visual is a thin vertical bar (↔ hint) rather than a corner-resize icon.
  local handle = CreateFrame("Frame", nil, f)
  handle:SetSize(6, f:GetHeight())
  handle:SetPoint("RIGHT", f, "RIGHT", 0, 0)
  handle:EnableMouse(true)
  handle:SetScript("OnMouseDown", function()
    if not TokukoPDB.HealerMana.locked then f:StartSizing("RIGHT") end
  end)
  handle:SetScript("OnMouseUp", function()
    f:StopMovingOrSizing()
  end)
  local htex = handle:CreateTexture(nil, "OVERLAY")
  htex:SetColorTexture(0.8, 0.8, 0.8, 0.5)  -- thin semi-transparent vertical bar
  htex:SetSize(2, 14)
  htex:SetPoint("CENTER")
  handle:SetShown(not db.locked)
  f._resizeHandle = handle

  -- Pre-allocate FontString pairs (name left, percentage right)
  for i = 1, MAX_HEALERS do
    local ns = f:CreateFontString(nil, "OVERLAY")
    ns:SetFont(db.font, db.fontSize, "OUTLINE")
    ns:SetJustifyH("LEFT")
    ns:SetWordWrap(false)  -- clip at pixel boundary rather than wrapping
    ns:Hide()
    nameLines[i] = ns

    local ps = f:CreateFontString(nil, "OVERLAY")
    ps:SetFont(db.font, db.fontSize, "OUTLINE")
    ps:SetJustifyH("RIGHT")
    ps:SetWordWrap(false)
    ps:Hide()
    pctLines[i] = ps
  end

  f:Hide()
  return f
end

local function ApplyBgAlpha()
  if not container then return end
  local a = TokukoPDB.HealerMana.bgAlpha
  container:SetBackdropColor(bgR, bgG, bgB, a)
  container:SetBackdropBorderColor(borderR, borderG, borderB, a)
end

local function ApplyFont()
  local db = TokukoPDB.HealerMana
  for i = 1, MAX_HEALERS do
    nameLines[i]:SetFont(db.font, db.fontSize, "OUTLINE")
    pctLines[i]:SetFont(db.font, db.fontSize, "OUTLINE")
  end
end

LayoutLines = function(count)
  lastCount = count
  local db     = TokukoPDB.HealerMana
  local lineH  = db.fontSize + LINE_PAD
  local totalH = FRAME_PAD * 2 + count * lineH - LINE_PAD
  container:SetHeight(math.max(totalH, 20))

  local pctW  = GetPctWidth(db.displayMode or "percent", db.fontSize)
  local nameW = container:GetWidth() - FRAME_PAD * 2 - pctW
  for i = 1, MAX_HEALERS do
    nameLines[i]:ClearAllPoints()
    pctLines[i]:ClearAllPoints()
    if i <= count then
      local yOff = -(FRAME_PAD + (i - 1) * lineH)
      nameLines[i]:SetPoint("TOPLEFT", container, "TOPLEFT", FRAME_PAD, yOff)
      nameLines[i]:SetWidth(nameW)
      nameLines[i]:Show()
      pctLines[i]:SetPoint("TOPRIGHT", container, "TOPRIGHT", -FRAME_PAD, yOff)
      pctLines[i]:SetWidth(pctW)
      pctLines[i]:Show()
    else
      nameLines[i]:Hide()
      pctLines[i]:Hide()
    end
  end
end

-- ===============================
-- Update Logic
-- ===============================

local function UpdateDisplay()
  if not container then return end
  local db = TokukoPDB.HealerMana
  if not db.enabled and not previewMode then
    container:Hide()
    return
  end

  if previewMode then
    local mode = db.displayMode or "percent"
    LayoutLines(#FAKE_HEALERS)
    for i, h in ipairs(FAKE_HEALERS) do
      local r, g, b
      if db.useClassColor and h.class then
        r, g, b = GetClassColor(h.class)
      else
        r, g, b = db.color.r, db.color.g, db.color.b
      end
      nameLines[i]:SetTextColor(r, g, b, db.textAlpha)
      nameLines[i]:SetText(h.name)
      pctLines[i]:SetTextColor(r, g, b, db.textAlpha)
      local pctStr = h.mana .. "%"
      local valStr = FormatManaValue(h.manaVal)
      if mode == "percent" then
        pctLines[i]:SetText(pctStr)
      elseif mode == "value" then
        pctLines[i]:SetText(valStr)
      else  -- both: absolute first, then percent
        pctLines[i]:SetText(valStr .. "  " .. pctStr)
      end
    end
    container:Show()
    return
  end

  local healers = {}

  local function CheckUnit(unit)
    if not UnitExists(unit) then return end
    if UnitGroupRolesAssigned(unit) ~= "HEALER" then return end
    local name = UnitName(unit)
    if not name then return end
    local _, classFilename = UnitClass(unit)
    local sortVal, display = GetManaInfo(unit)
    table.insert(healers, { name = name, mana = sortVal, display = display, class = classFilename })
  end

  if IsInRaid() then
    for i = 1, GetNumGroupMembers() do
      CheckUnit("raid" .. i)
    end
  elseif IsInGroup() then
    CheckUnit("player")
    for i = 1, GetNumSubgroupMembers() do
      CheckUnit("party" .. i)
    end
  else
    -- Solo: only show if the player themselves is a healer
    CheckUnit("player")
  end

  if #healers == 0 then
    container:Hide()
    return
  end

  -- Lowest mana first — most urgent healer at the top.
  -- Comparison on secret values may fail; skip sort if so.
  pcall(function() table.sort(healers, function(a, b) return a.mana < b.mana end) end)

  LayoutLines(#healers)

  for i, h in ipairs(healers) do
    local r, g, b
    if db.useClassColor and h.class then
      r, g, b = GetClassColor(h.class)
    else
      r, g, b = db.color.r, db.color.g, db.color.b
    end
    nameLines[i]:SetTextColor(r, g, b, db.textAlpha)
    nameLines[i]:SetText(h.name)
    pctLines[i]:SetTextColor(r, g, b, db.textAlpha)
    pctLines[i]:SetText(h.display)
  end

  container:Show()
end

-- ===============================
-- Public API (called from Settings)
-- ===============================

function HealerManaModule.RefreshFont()
  ApplyFont()
  UpdateDisplay()
end

function HealerManaModule.RefreshDisplay()
  UpdateDisplay()
end

function HealerManaModule.IsPreview()
  return previewMode
end

function HealerManaModule.TogglePreview()
  previewMode = not previewMode
  UpdateDisplay()
end

function HealerManaModule.RefreshBgAlpha()
  ApplyBgAlpha()
end

local function IsOffScreen()
  if not container then return false end
  local left, right = container:GetLeft(), container:GetRight()
  local top, bottom = container:GetTop(), container:GetBottom()
  local sw, sh = UIParent:GetRight(), UIParent:GetTop()
  return right < 0 or left > sw or top < 0 or bottom > sh
end

function HealerManaModule.ResetPosition()
  if not container then return end
  local db = TokukoPDB.HealerMana
  db.posX, db.posY = 0, 200
  local anchor = db.growUp and "BOTTOMLEFT" or "TOPLEFT"
  container:ClearAllPoints()
  container:SetPoint(anchor, UIParent, "CENTER", db.posX, db.posY)
end

function HealerManaModule.SetLocked(v)
  TokukoPDB.HealerMana.locked = v
  if container and container._resizeHandle then
    container._resizeHandle:SetShown(not v)
  end
  if not v and IsOffScreen() then
    HealerManaModule.ResetPosition()
  end
end

function HealerManaModule.RefreshGrowDirection()
  if not container then return end
  local db     = TokukoPDB.HealerMana
  local anchor = db.growUp and "BOTTOMLEFT" or "TOPLEFT"
  container:ClearAllPoints()
  container:SetPoint(anchor, UIParent, "CENTER", db.posX, db.posY)
end

-- ===============================
-- Module Interface
-- ===============================

function HealerManaModule.Initialize()
  TokukoPDB.HealerMana = TokukoPDB.HealerMana or {}
  TokukoP.MergeDefaults(TokukoPDB.HealerMana, HealerManaModule.DEFAULTS)

  -- Rebuild font list from LibSharedMedia if available (same source as ElvUI dropdowns).
  local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
  if lsm then
    local fonts = lsm:HashTable("font")
    local names = {}
    for name in pairs(fonts) do table.insert(names, name) end
    table.sort(names)
    HealerManaModule.FONT_VALUES  = {}
    HealerManaModule.FONT_SORTING = {}
    for _, name in ipairs(names) do
      local path = fonts[name]
      HealerManaModule.FONT_VALUES[path]  = name
      table.insert(HealerManaModule.FONT_SORTING, path)
    end
  end

  container = BuildContainer()

  local db = TokukoPDB.HealerMana
  local anchor = db.growUp and "BOTTOMLEFT" or "TOPLEFT"
  container:SetPoint(anchor, UIParent, "CENTER", db.posX, db.posY)

  C_Timer.NewTicker(TICK_RATE, UpdateDisplay)

  UpdateDisplay()
end

function HealerManaModule.RegisterEvents(frame)
  frame:RegisterEvent("GROUP_ROSTER_UPDATE")
  frame:RegisterEvent("PLAYER_ENTERING_WORLD")
end

function HealerManaModule.OnEvent(event, ...)
  if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
    UpdateDisplay()
  end
end
