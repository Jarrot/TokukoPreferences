-- PetReminderModule.lua
-- Shows a pulsing on-screen warning when a Hunter or Warlock has no active pet.
-- Auto-detects pet class on login; no-op for all other classes.

local ADDON_NAME = ...
local TokukoP = TokukoP

local PetReminderModule = {}
TokukoP.modules.PetReminder = PetReminderModule

-- ===============================
-- Constants
-- ===============================

-- Classes that can ever need the warning (gate for event registration).
-- Spec-specific logic is handled in ShouldWarn() at runtime.
local ELIGIBLE_CLASSES = { HUNTER = true, WARLOCK = true, DEATHKNIGHT = true }

-- Lone Wolf (Hunter no-pet talent) was removed in patch 11.1.0.
-- All Hunter specs in 12.x want an active pet.

-- Unholy DK (spec index 3) has a ghoul via Raise Dead — manual cast, can die.
-- Blood (1) and Frost (2) do not use a pet.
local UNHOLY_DK_SPEC = 3

local FONT_DEFS_FALLBACK = {
  { key = "Fonts\\ARIALN.TTF",   label = "Arial Narrow" },
  { key = "Fonts\\FRIZQT__.TTF", label = "Default"      },
  { key = "Fonts\\MORPHEUS.TTF", label = "Morpheus"     },
  { key = "Fonts\\SKURRI.TTF",   label = "Skurri"       },
}

local DEFAULTS = {
  enabled   = false,
  locked    = false,
  message   = "PET IS MISSING",
  font      = "Fonts\\FRIZQT__.TTF",
  fontSize  = 32,
  flashRate = 2.0,   -- pulses per second
  color     = { r = 1, g = 0.15, b = 0.15 },
  x         = 0,
  y         = 120,
}

-- ===============================
-- State
-- ===============================

PetReminderModule.FONT_VALUES  = {}
PetReminderModule.FONT_SORTING = {}
for _, fd in ipairs(FONT_DEFS_FALLBACK) do
  PetReminderModule.FONT_VALUES[fd.key] = fd.label
  table.insert(PetReminderModule.FONT_SORTING, fd.key)
end

local container       = nil
local label           = nil
local tickerHandle    = nil
local isEligibleClass = false   -- true if class can ever need the warning
local db              = nil

-- ===============================
-- Helpers
-- ===============================

local function HasPet()
  return UnitExists("pet") and not UnitIsDeadOrGhost("pet")
end

-- Returns true if the warning should be active for the current class/spec.
-- Re-evaluated at runtime so spec swaps are handled without a reload.
local function ShouldWarn()
  if not db or not db.enabled then return false end
  local _, classFile = UnitClass("player")
  if classFile == "HUNTER" or classFile == "WARLOCK" then
    return true
  end
  if classFile == "DEATHKNIGHT" then
    -- Only Unholy spec uses a ghoul; Blood and Frost do not.
    local specIndex = GetSpecialization and GetSpecialization()
    return specIndex == UNHOLY_DK_SPEC
  end
  return false
end

local function GetFont()
  local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
  local path = LSM and LSM:Fetch("font", db.font)
  if path and path ~= "" then return path end
  return db.font or "Fonts\\FRIZQT__.TTF"
end

-- ===============================
-- Flash Ticker
-- ===============================

local function StartFlash()
  if tickerHandle then return end
  tickerHandle = C_Timer.NewTicker(0.05, function()
    if not container or not container:IsShown() then
      tickerHandle:Cancel()
      tickerHandle = nil
      return
    end
    -- Smooth sine pulse: alpha oscillates between 0.3 and 1.0
    local alpha = 0.3 + 0.7 * math.abs(math.sin(GetTime() * db.flashRate * math.pi))
    container:SetAlpha(alpha)
  end)
end

local function StopFlash()
  if tickerHandle then
    tickerHandle:Cancel()
    tickerHandle = nil
  end
end

-- ===============================
-- Display
-- ===============================

local function RefreshDisplay()
  if not ShouldWarn() then
    if container then container:Hide() end
    StopFlash()
    return
  end
  if HasPet() then
    container:Hide()
    StopFlash()
  else
    container:Show()
    StartFlash()
  end
end

-- ===============================
-- Frame Construction
-- ===============================

local function BuildContainer()
  if container then return end

  local f = CreateFrame("Frame", "TokukoPPetReminderFrame", UIParent)
  f:SetFrameStrata("HIGH")
  f:SetSize(500, 80)
  f:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self)
    if not db.locked then self:StartMoving() end
  end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local ux, uy = UIParent:GetCenter()
    db.x = self:GetLeft() - ux + self:GetWidth()  / 2
    db.y = self:GetTop()  - uy - self:GetHeight() / 2
  end)

  label = f:CreateFontString(nil, "OVERLAY")
  label:SetAllPoints(f)
  label:SetJustifyH("CENTER")
  label:SetJustifyV("MIDDLE")
  label:SetShadowOffset(2, -2)
  label:SetShadowColor(0, 0, 0, 1)

  container = f
  container:Hide()
end

-- ===============================
-- Public API
-- ===============================

function PetReminderModule.RefreshLabel()
  if not label or not db then return end
  label:SetFont(GetFont(), db.fontSize, "OUTLINE")
  label:SetText(db.message)
  label:SetTextColor(db.color.r, db.color.g, db.color.b, 1)
end

function PetReminderModule.RefreshDisplay()
  RefreshDisplay()
end

function PetReminderModule.SetLocked(v)
  db.locked = v
end

-- ===============================
-- Module Interface
-- ===============================

function PetReminderModule.Initialize()
  TokukoPDB.PetReminder = TokukoPDB.PetReminder or {}
  TokukoP.MergeDefaults(TokukoPDB.PetReminder, DEFAULTS)
  db = TokukoPDB.PetReminder

  local _, classFile = UnitClass("player")
  isEligibleClass = ELIGIBLE_CLASSES[classFile] == true

  -- Populate FONT_VALUES from LSM if available
  local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
  if LSM then
    local fonts = LSM:HashTable("font")
    PetReminderModule.FONT_VALUES  = {}
    PetReminderModule.FONT_SORTING = {}
    local names = {}
    for name in pairs(fonts) do table.insert(names, name) end
    table.sort(names)
    for _, name in ipairs(names) do
      PetReminderModule.FONT_VALUES[name] = name
      table.insert(PetReminderModule.FONT_SORTING, name)
    end
  end

  if not isEligibleClass then return end

  BuildContainer()
  PetReminderModule.RefreshLabel()
  RefreshDisplay()
end

function PetReminderModule.RegisterEvents(frame)
  if not isEligibleClass then return end
  frame:RegisterEvent("UNIT_PET")                    -- pet summoned or dismissed
  frame:RegisterEvent("PLAYER_ENTERING_WORLD")
  frame:RegisterEvent("PLAYER_REGEN_ENABLED")        -- after combat: pet may have died
  frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED") -- DK spec swap (Unholy <-> other)
end

function PetReminderModule.OnEvent(event, ...)
  if not db then return end
  if event == "UNIT_PET" then
    local unitID = ...
    if unitID ~= "player" then return end
    RefreshDisplay()
  elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
    local unitID = ...
    if unitID ~= "player" then return end
    RefreshDisplay()
  elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_ENABLED" then
    RefreshDisplay()
  end
end
