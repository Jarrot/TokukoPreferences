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
  font          = "Fonts\\ARIALN.TTF",
  fontSize      = 13,
  useClassColor = true,
  color         = { r = 1, g = 1, b = 1 },
  posX          = 0,
  posY          = 200,
}

-- ===============================
-- Constants
-- ===============================

local LINE_PAD    = 2    -- px between lines
local FRAME_PAD   = 6    -- px of padding inside frame border
local MAX_HEALERS = 16   -- pre-allocated FontString pool
local TICK_RATE   = 0.5  -- seconds between updates

-- Font list — key is the actual font path, label is what shows in the dropdown
local FONT_DEFS = {
  { key = "Fonts\\ARIALN.TTF",   label = "Arial Narrow" },
  { key = "Fonts\\FRIZQT__.TTF", label = "Default"      },
  { key = "Fonts\\MORPHEUS.TTF", label = "Morpheus"     },
  { key = "Fonts\\SKURRI.TTF",   label = "Skurri"       },
}

-- Built once; referenced by Settings.lua via TokukoP.modules.HealerMana
HealerManaModule.FONT_VALUES  = {}
HealerManaModule.FONT_SORTING = {}
for _, fd in ipairs(FONT_DEFS) do
  HealerManaModule.FONT_VALUES[fd.key] = fd.label
  table.insert(HealerManaModule.FONT_SORTING, fd.key)
end

-- ===============================
-- State
-- ===============================

local container   = nil
local lines       = {}   -- FontString pool
local previewMode = false

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
  f:SetSize(180, 20)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetClampedToScreen(true)

  f:SetBackdrop({
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  f:SetBackdropColor(0, 0, 0, 0.55)
  f:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.9)

  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local x, y   = self:GetCenter()
    local ux, uy = UIParent:GetCenter()
    TokukoPDB.HealerMana.posX = x - ux
    TokukoPDB.HealerMana.posY = y - uy
  end)

  -- Pre-allocate FontStrings
  for i = 1, MAX_HEALERS do
    local fs = f:CreateFontString(nil, "OVERLAY")
    fs:SetFont(db.font, db.fontSize, "OUTLINE")
    fs:SetJustifyH("LEFT")
    fs:Hide()
    lines[i] = fs
  end

  f:Hide()
  return f
end

local function ApplyFont()
  local db = TokukoPDB.HealerMana
  for _, fs in ipairs(lines) do
    fs:SetFont(db.font, db.fontSize, "OUTLINE")
  end
end

local function LayoutLines(count)
  local db     = TokukoPDB.HealerMana
  local lineH  = db.fontSize + LINE_PAD
  local totalH = FRAME_PAD * 2 + count * lineH - LINE_PAD
  container:SetHeight(math.max(totalH, 20))

  for i, fs in ipairs(lines) do
    fs:ClearAllPoints()
    if i <= count then
      fs:SetPoint("TOPLEFT", FRAME_PAD, -(FRAME_PAD + (i - 1) * lineH))
      fs:SetWidth(container:GetWidth() - FRAME_PAD * 2)
      fs:Show()
    else
      fs:Hide()
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
      lines[i]:SetTextColor(r, g, b)
      lines[i]:SetText(string.format("%s: %d%%", h.name, h.mana))
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
    lines[i]:SetTextColor(r, g, b)
    lines[i]:SetText(string.format("%s: %d%%", h.name, math.floor(h.mana)))
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

-- ===============================
-- Module Interface
-- ===============================

function HealerManaModule.Initialize()
  TokukoPDB.HealerMana = TokukoPDB.HealerMana or {}
  TokukoP.MergeDefaults(TokukoPDB.HealerMana, HealerManaModule.DEFAULTS)

  container = BuildContainer()

  local db = TokukoPDB.HealerMana
  container:SetPoint("CENTER", UIParent, "CENTER", db.posX, db.posY)

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
