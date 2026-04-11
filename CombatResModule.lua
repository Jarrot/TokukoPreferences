-- CombatResModule.lua
-- Two icons: Druid Rebirth (battle res charges + regen timer) and
-- Shaman Reincarnation (personal cooldown timer).
-- Movable, no background. Timers shown MM:SS centered on each icon.
-- Charge count badge shown bottom-right of Rebirth icon.

local ADDON_NAME = ...
local TokukoP = TokukoP

local CombatResModule = {}
TokukoP.modules.CombatRes = CombatResModule

-- ===============================
-- Constants
-- ===============================

local REBIRTH_ID       = 20484   -- Druid Rebirth (battle res)
local REINCARNATION_ID = 20608   -- Shaman Reincarnation

local ICON_SIZE = 40
local ICON_GAP  = 4

local DEFAULTS = {
  enabled       = false,
  locked        = false,
  font          = "Fonts\\FRIZQT__.TTF",
  timerFontSize = 14,
  countFontSize = 12,
  x             = 0,
  y             = 200,
}

local FONT_DEFS_FALLBACK = {
  { key = "Fonts\\ARIALN.TTF",   label = "Arial Narrow" },
  { key = "Fonts\\FRIZQT__.TTF", label = "Default"      },
  { key = "Fonts\\MORPHEUS.TTF", label = "Morpheus"     },
  { key = "Fonts\\SKURRI.TTF",   label = "Skurri"       },
}

CombatResModule.FONT_VALUES  = {}
CombatResModule.FONT_SORTING = {}
for _, fd in ipairs(FONT_DEFS_FALLBACK) do
  CombatResModule.FONT_VALUES[fd.key] = fd.label
  table.insert(CombatResModule.FONT_SORTING, fd.key)
end

-- ===============================
-- State
-- ===============================

local container    = nil
local rebirthIcon  = nil
local reincarIcon  = nil
local db           = nil
local tickerHandle = nil

-- ===============================
-- Helpers
-- ===============================

local function GetFont()
  local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
  local path = LSM and LSM:Fetch("font", db.font)
  if path and path ~= "" then return path end
  -- db.font may already be a file path (fallback keys)
  return db.font or "Fonts\\FRIZQT__.TTF"
end

local function FormatTime(secs)
  if secs <= 0 then return "" end
  local m = math.floor(secs / 60)
  local s = math.floor(secs % 60)
  return string.format("%d:%02d", m, s)
end

-- ===============================
-- Cooldown Queries
-- ===============================

-- Returns currentCharges, maxCharges, chargeStart, chargeDuration
local function GetRebirthChargeInfo()
  local ok, info = pcall(C_Spell.GetSpellCharges, REBIRTH_ID)
  if ok and info then
    return info.currentCharges, info.maxCharges,
           info.cooldownStartTime, info.cooldownDuration
  end
  return nil, nil, 0, 0
end

-- Returns startTime, duration
local function GetReincarCDInfo()
  local ok, info = pcall(C_Spell.GetSpellCooldown, REINCARNATION_ID)
  if ok and info then
    return info.startTime, info.duration
  end
  return 0, 0
end

-- ===============================
-- UI Update
-- ===============================

local function UpdateDisplay()
  if not container or not container:IsShown() then return end

  -- ── Rebirth ──────────────────────────────────────────────────────
  local cur, max, chargeStart, chargeDur = GetRebirthChargeInfo()

  local countLabel = rebirthIcon._countLabel
  if cur ~= nil and max ~= nil and max > 0 then
    countLabel:SetText(tostring(cur))
    countLabel:Show()
  else
    countLabel:Hide()
  end

  local rebirthTimer = rebirthIcon._timerLabel
  if cur ~= nil and max ~= nil and cur < max and chargeDur and chargeDur > 0 then
    local rem = chargeStart + chargeDur - GetTime()
    if rem > 0 then
      rebirthTimer:SetText(FormatTime(rem))
      rebirthTimer:Show()
    else
      rebirthTimer:Hide()
    end
  else
    rebirthTimer:Hide()
  end

  -- ── Reincarnation ────────────────────────────────────────────────
  local start, dur = GetReincarCDInfo()
  local reincarTimer = reincarIcon._timerLabel
  -- dur > 1.5 distinguishes real CD from GCD blip
  if dur and dur > 1.5 then
    local rem = start + dur - GetTime()
    if rem > 0 then
      reincarTimer:SetText(FormatTime(rem))
      reincarTimer:Show()
    else
      reincarTimer:Hide()
    end
  else
    reincarTimer:Hide()
  end
end

local function SyncSweeps()
  if not container then return end

  local cur, max, chargeStart, chargeDur = GetRebirthChargeInfo()
  if cur ~= nil and max ~= nil and cur < max and chargeDur and chargeDur > 0 then
    rebirthIcon._cooldown:SetCooldown(chargeStart, chargeDur)
  else
    rebirthIcon._cooldown:Clear()
  end

  local start, dur = GetReincarCDInfo()
  if dur and dur > 1.5 then
    reincarIcon._cooldown:SetCooldown(start, dur)
  else
    reincarIcon._cooldown:Clear()
  end
end

local function StartTicker()
  if tickerHandle then return end
  tickerHandle = C_Timer.NewTicker(0.2, function()
    if not db.enabled or not container or not container:IsShown() then
      tickerHandle:Cancel()
      tickerHandle = nil
      return
    end
    UpdateDisplay()
  end)
end

local function StopTicker()
  if tickerHandle then
    tickerHandle:Cancel()
    tickerHandle = nil
  end
end

-- ===============================
-- Icon Frame Builder
-- ===============================

local function BuildIconFrame(parent, spellID, withCountBadge)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(ICON_SIZE, ICON_SIZE)

  -- Icon texture with standard WoW border crop
  local tex = f:CreateTexture(nil, "BACKGROUND")
  tex:SetAllPoints(f)
  local iconPath = C_Spell.GetSpellTexture(spellID)
  if iconPath then
    tex:SetTexture(iconPath)
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  end

  -- Cooldown sweep
  local cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
  cd:SetAllPoints(f)
  cd:SetDrawEdge(false)
  cd:SetDrawSwipe(true)
  cd:SetHideCountdownNumbers(true)
  f._cooldown = cd

  -- Centered timer label
  local timerLabel = f:CreateFontString(nil, "OVERLAY")
  timerLabel:SetPoint("CENTER", f, "CENTER", 0, 0)
  timerLabel:SetShadowOffset(1, -1)
  timerLabel:SetShadowColor(0, 0, 0, 1)
  timerLabel:Hide()
  f._timerLabel = timerLabel

  -- Charge count badge (bottom-right), Rebirth only
  if withCountBadge then
    local countLabel = f:CreateFontString(nil, "OVERLAY")
    countLabel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 1, -1)
    countLabel:SetShadowOffset(1, -1)
    countLabel:SetShadowColor(0, 0, 0, 1)
    countLabel:Hide()
    f._countLabel = countLabel
  end

  return f
end

-- ===============================
-- Container Build
-- ===============================

local function BuildContainer()
  if container then return end

  container = CreateFrame("Frame", "TokukoPCombatResFrame", UIParent)
  container:SetSize(ICON_SIZE * 2 + ICON_GAP, ICON_SIZE)
  container:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)
  container:SetClampedToScreen(true)
  container:SetMovable(true)
  container:EnableMouse(true)
  container:RegisterForDrag("LeftButton")
  container:SetScript("OnDragStart", function(self)
    if not db.locked then self:StartMoving() end
  end)
  container:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local _, _, _, x, y = self:GetPoint()
    db.x = x
    db.y = y
  end)

  rebirthIcon = BuildIconFrame(container, REBIRTH_ID, true)
  rebirthIcon:SetPoint("LEFT", container, "LEFT", 0, 0)

  reincarIcon = BuildIconFrame(container, REINCARNATION_ID, false)
  reincarIcon:SetPoint("LEFT", rebirthIcon, "RIGHT", ICON_GAP, 0)

  CombatResModule.RefreshFonts()
  container:Hide()
end

-- ===============================
-- Public API
-- ===============================

function CombatResModule.RefreshFonts()
  if not container then return end
  local fontPath = GetFont()
  rebirthIcon._timerLabel:SetFont(fontPath, db.timerFontSize, "OUTLINE")
  reincarIcon._timerLabel:SetFont(fontPath, db.timerFontSize, "OUTLINE")
  if rebirthIcon._countLabel then
    rebirthIcon._countLabel:SetFont(fontPath, db.countFontSize, "OUTLINE")
  end
end

function CombatResModule.RefreshDisplay()
  if not db then return end
  if db.enabled then
    if not container then BuildContainer() end
    container:Show()
    SyncSweeps()
    UpdateDisplay()
    StartTicker()
  else
    StopTicker()
    if container then container:Hide() end
  end
end

function CombatResModule.SetLocked(v)
  db.locked = v
end

-- ===============================
-- Module Init / Events
-- ===============================

function CombatResModule.Initialize()
  TokukoPDB.CombatRes = TokukoPDB.CombatRes or {}
  TokukoP.MergeDefaults(TokukoPDB.CombatRes, DEFAULTS)
  db = TokukoPDB.CombatRes

  -- Populate FONT_VALUES from LSM if available (same pattern as HealerManaModule)
  local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
  if LSM then
    local fonts = LSM:HashTable("font")
    CombatResModule.FONT_VALUES  = {}
    CombatResModule.FONT_SORTING = {}
    local names = {}
    for name in pairs(fonts) do table.insert(names, name) end
    table.sort(names)
    for _, name in ipairs(names) do
      CombatResModule.FONT_VALUES[name] = name
      table.insert(CombatResModule.FONT_SORTING, name)
    end
  end

  if db.enabled then
    BuildContainer()
    container:Show()
    SyncSweeps()
    UpdateDisplay()
    StartTicker()
  end
end

function CombatResModule.RegisterEvents(frame)
  frame:RegisterEvent("SPELL_UPDATE_CHARGES")   -- battle res charge gained/spent
  frame:RegisterEvent("SPELL_UPDATE_COOLDOWN")  -- Reincarnation CD changes
  frame:RegisterEvent("PLAYER_ENTERING_WORLD")
end

function CombatResModule.OnEvent(event, ...)
  if not db then return end

  if event == "PLAYER_ENTERING_WORLD" then
    CombatResModule.RefreshDisplay()

  elseif db.enabled then
    if event == "SPELL_UPDATE_CHARGES" or event == "SPELL_UPDATE_COOLDOWN" then
      SyncSweeps()
      UpdateDisplay()
      StartTicker()
    end
  end
end
