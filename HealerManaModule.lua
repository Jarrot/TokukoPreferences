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
  { name = "Tokukheal",  mana = 12, class = "PRIEST"  },
  { name = "Jarrotdruid",mana = 45, class = "DRUID"   },
  { name = "Holypala",   mana = 67, class = "PALADIN" },
  { name = "Mistweave",  mana = 81, class = "MONK"    },
  { name = "Restosham",  mana = 93, class = "SHAMAN"  },
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

-- UnitPowerPercent is the safe percentage API in Midnight (Secret Values system).
-- Arithmetic on UnitPower/UnitPowerMax is NOT a safe fallback — those values may
-- be secret, and doing math on secrets produces errors or garbage.
local warnedMissingAPI = false
local function GetManaPct(unit)
  if not UnitPowerPercent then
    if not warnedMissingAPI then
      warnedMissingAPI = true
      print("|cffffcc00TokukoP:|r UnitPowerPercent not found — healer mana display unavailable.")
    end
    return 0
  end
  return UnitPowerPercent(unit, 0) or 0  -- 0 = Mana
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

  -- Resize handle — right edge drag, hidden when locked
  local handle = CreateFrame("Frame", nil, f)
  handle:SetSize(12, 30)
  handle:SetPoint("RIGHT", f, "RIGHT", 0, 0)
  handle:EnableMouse(true)
  handle:SetScript("OnMouseDown", function()
    if not TokukoPDB.HealerMana.locked then f:StartSizing("RIGHT") end
  end)
  handle:SetScript("OnMouseUp", function()
    f:StopMovingOrSizing()
  end)
  local htex = handle:CreateTexture(nil, "OVERLAY")
  htex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  htex:SetSize(12, 12)
  htex:SetPoint("CENTER")

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

local PCT_WIDTH = 38  -- px reserved on the right for "100%" at default font size

LayoutLines = function(count)
  lastCount = count
  local db     = TokukoPDB.HealerMana
  local lineH  = db.fontSize + LINE_PAD
  local totalH = FRAME_PAD * 2 + count * lineH - LINE_PAD
  container:SetHeight(math.max(totalH, 20))

  local nameW = container:GetWidth() - FRAME_PAD * 2 - PCT_WIDTH
  for i = 1, MAX_HEALERS do
    nameLines[i]:ClearAllPoints()
    pctLines[i]:ClearAllPoints()
    if i <= count then
      local yOff = -(FRAME_PAD + (i - 1) * lineH)
      nameLines[i]:SetPoint("TOPLEFT", container, "TOPLEFT", FRAME_PAD, yOff)
      nameLines[i]:SetWidth(nameW)
      nameLines[i]:Show()
      pctLines[i]:SetPoint("TOPRIGHT", container, "TOPRIGHT", -FRAME_PAD, yOff)
      pctLines[i]:SetWidth(PCT_WIDTH)
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
      pctLines[i]:SetText(h.mana .. "%")
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
    local mana = GetManaPct(unit)
    table.insert(healers, { name = name, mana = mana, class = classFilename })
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

  -- Lowest mana first — most urgent healer at the top
  table.sort(healers, function(a, b) return a.mana < b.mana end)

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
    pctLines[i]:SetText(math.floor(h.mana) .. "%")
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
