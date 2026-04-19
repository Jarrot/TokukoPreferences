-- PetReminderModule.lua
-- Shows a flashing on-screen warning when a Hunter, Warlock, or Unholy DK
-- has no active pet. Supports multiple visual effects and an optional combat sound.

local ADDON_NAME = ...
local TokukoP = TokukoP

local PetReminderModule = {}
TokukoP.modules.PetReminder = PetReminderModule

-- ===============================
-- Constants
-- ===============================

-- Classes that can ever trigger the warning (gate for event registration).
-- Spec-specific filtering is done in ShouldWarn() at runtime.
local ELIGIBLE_CLASSES = { HUNTER = true, WARLOCK = true, DEATHKNIGHT = true }

-- Lone Wolf (Hunter no-pet talent) was removed in patch 11.1.0.
-- All Hunter specs in 12.x want an active pet.

-- Unholy DK (spec 3) has a ghoul via Raise Dead — manual cast, can die.
-- Blood (1) and Frost (2) do not use a pet.
local UNHOLY_DK_SPEC = 3

local FONT_DEFS_FALLBACK = {
  { key = "Fonts\\ARIALN.TTF",   label = "Arial Narrow" },
  { key = "Fonts\\FRIZQT__.TTF", label = "Default"      },
  { key = "Fonts\\MORPHEUS.TTF", label = "Morpheus"     },
  { key = "Fonts\\SKURRI.TTF",   label = "Skurri"       },
}

local DEFAULTS = {
  enabled              = false,
  locked               = false,
  message              = "PET IS MISSING",
  combatMessageEnabled = false,
  combatMessage        = "SUMMON YOUR PET",
  font                 = "Fonts\\FRIZQT__.TTF",
  fontSize             = 32,
  effect               = "none",   -- none | pulse | shake | bounce | scale | colorflash
  flashRate            = 2.0,      -- pulses/bounces per second
  color                = { r = 1, g = 0.15, b = 0.15 },
  sound                = "none",   -- none | raid_warning | alarm | ui_error | pvp_alert
  x                    = 0,
  y                    = 120,
}

-- ===============================
-- Module-level tables for Settings dropdowns
-- (defined here so Settings.lua can read them at load time)
-- ===============================

PetReminderModule.FONT_VALUES  = {}
PetReminderModule.FONT_SORTING = {}
for _, fd in ipairs(FONT_DEFS_FALLBACK) do
  PetReminderModule.FONT_VALUES[fd.key] = fd.label
  table.insert(PetReminderModule.FONT_SORTING, fd.key)
end

PetReminderModule.EFFECT_VALUES  = {
  none       = "None",
  pulse      = "Pulse (alpha)",
  shake      = "Shake",
  bounce     = "Bounce",
  scale      = "Scale Pulse",
  colorflash = "Color Flash",
}
PetReminderModule.EFFECT_SORTING = { "none", "pulse", "shake", "bounce", "scale", "colorflash" }

PetReminderModule.SOUND_VALUES  = {
  none         = "None",
  raid_warning = "Raid Warning",
  alarm        = "Alarm Clock",
  ui_error     = "UI Error",
  pvp_alert    = "PvP Alert",
}
PetReminderModule.SOUND_SORTING = { "none", "raid_warning", "alarm", "ui_error", "pvp_alert" }

-- ===============================
-- State
-- ===============================

local container       = nil
local label           = nil
local tickerHandle    = nil
local loginPollHandle = nil
local isEligibleClass = false
local isDragging      = false
local db              = nil
local previewMode     = false

-- ===============================
-- Sound
-- ===============================

local function PlayWarningSound()
  if not db then return end
  local s = db.sound or "none"
  if s == "none" then return end
  if s == "raid_warning" then
    pcall(PlaySound, SOUNDKIT.RAID_WARNING,                 "Master")
  elseif s == "alarm" then
    pcall(PlaySound, SOUNDKIT.ALARM_CLOCK_WARNING_3,        "Master")
  elseif s == "ui_error" then
    pcall(PlaySound, SOUNDKIT.UI_ERROR_MESSAGE,             "Master")
  elseif s == "pvp_alert" then
    pcall(PlaySound, SOUNDKIT.PVP_THROUGH_QUEUE_BUTTON_FLASH, "Master")
  end
end

-- ===============================
-- Helpers
-- ===============================

local function HasPet()
  return UnitExists("pet") and not UnitIsDeadOrGhost("pet")
end

local function ShouldWarn()
  if not db or not db.enabled then return false end
  local _, classFile = UnitClass("player")
  if classFile == "HUNTER" or classFile == "WARLOCK" then return true end
  if classFile == "DEATHKNIGHT" then
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

local function GetCurrentMessage()
  if db.combatMessageEnabled and db.combatMessage ~= "" and InCombatLockdown() then
    return db.combatMessage
  end
  return db.message
end

-- ===============================
-- Effects
-- ===============================

local function ResetEffects()
  if not container then return end
  container:SetAlpha(1)
  container:SetScale(1)
  if label then label:SetTextColor(db.color.r, db.color.g, db.color.b, 1) end
  container:ClearAllPoints()
  container:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)
end

local function StopEffect()
  if tickerHandle then
    tickerHandle:Cancel()
    tickerHandle = nil
  end
  ResetEffects()
end

local function StartEffect()
  if (db.effect or "none") == "none" then
    ResetEffects()
    return
  end
  if tickerHandle then return end
  tickerHandle = C_Timer.NewTicker(0.05, function()
    if not container or not container:IsShown() then
      tickerHandle:Cancel()
      tickerHandle = nil
      return
    end

    local t      = GetTime()
    local rate   = db.flashRate or 2.0
    local effect = db.effect or "pulse"

    if effect == "pulse" then
      -- Smooth alpha sine wave between 0.3 and 1.0
      container:SetAlpha(0.3 + 0.7 * math.abs(math.sin(t * rate * math.pi)))

    elseif effect == "shake" then
      -- Random position jitter — grabs attention for urgent warnings
      container:SetAlpha(1)
      if not isDragging then
        local ox = (math.random() - 0.5) * 10
        local oy = (math.random() - 0.5) * 10
        container:ClearAllPoints()
        container:SetPoint("CENTER", UIParent, "CENTER", db.x + ox, db.y + oy)
      end

    elseif effect == "bounce" then
      -- Smooth vertical sine bounce
      container:SetAlpha(1)
      if not isDragging then
        local oy = 12 * math.sin(t * rate * math.pi)
        container:ClearAllPoints()
        container:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y + oy)
      end

    elseif effect == "scale" then
      -- Text grows and shrinks rhythmically
      container:SetAlpha(1)
      container:SetScale(0.8 + 0.4 * math.abs(math.sin(t * rate * math.pi)))

    elseif effect == "colorflash" then
      -- Alternates between configured colour and white on each half-period
      container:SetAlpha(1)
      local phase = math.floor(t * rate * 2) % 2
      if phase == 0 then
        label:SetTextColor(db.color.r, db.color.g, db.color.b, 1)
      else
        label:SetTextColor(1, 1, 0.2, 1)  -- bright yellow flash
      end
    end
  end)
end

-- ===============================
-- Display
-- ===============================

local function UpdateLabelText()
  if label then label:SetText(GetCurrentMessage()) end
end

local function RefreshDisplay()
  if not previewMode and (not ShouldWarn() or IsMounted()) then
    if container then container:Hide() end
    StopEffect()
    return
  end
  UpdateLabelText()
  if not previewMode and HasPet() then
    container:Hide()
    StopEffect()
  else
    container:Show()
    StartEffect()
  end
end

-- ===============================
-- Login Poll
-- ===============================

-- After a loading screen, pet unit data becomes available at an unpredictable
-- time. Poll every 0.5s for up to 15s, refreshing the display each tick.
-- Stops early once the pet is confirmed present.
local function StartLoginPoll()
  if loginPollHandle then loginPollHandle:Cancel(); loginPollHandle = nil end
  local elapsed = 0
  loginPollHandle = C_Timer.NewTicker(0.5, function()
    elapsed = elapsed + 0.5
    RefreshDisplay()
    if HasPet() or elapsed >= 15 then
      loginPollHandle:Cancel()
      loginPollHandle = nil
    end
  end)
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
    if not db.locked then
      isDragging = true
      self:StartMoving()
    end
  end)
  f:SetScript("OnDragStop", function(self)
    isDragging = false
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
  label:SetText(GetCurrentMessage())
  label:SetTextColor(db.color.r, db.color.g, db.color.b, 1)
end

function PetReminderModule.RefreshDisplay()
  RefreshDisplay()
end

function PetReminderModule.SetLocked(v)
  db.locked = v
end

function PetReminderModule.PreviewSound()
  PlayWarningSound()
end

function PetReminderModule.EnterPreview()
  previewMode = true
  if not container then
    BuildContainer()
    PetReminderModule.RefreshLabel()
  end
  RefreshDisplay()
end

function PetReminderModule.ExitPreview()
  previewMode = false
  RefreshDisplay()
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

  -- Rebuild font list from LSM if available
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
  -- Do NOT call RefreshDisplay here: pet unit data is not available at
  -- PLAYER_LOGIN. The frame starts hidden; PLAYER_ENTERING_WORLD drives
  -- the first real check via the login poll.
end

function PetReminderModule.RegisterEvents(frame)
  if not isEligibleClass then return end
  frame:RegisterUnitEvent("UNIT_DIED", "pet")        -- pet death → play sound
  frame:RegisterEvent("UNIT_PET")                    -- pet summoned or dismissed
  frame:RegisterEvent("PLAYER_ENTERING_WORLD")
  frame:RegisterEvent("LOADING_SCREEN_DISABLED")     -- world fully visible; safe to query pet unit
  frame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED") -- suppress warning while mounted; re-check on land
  frame:RegisterEvent("PLAYER_REGEN_DISABLED")       -- swap to combat message text
  frame:RegisterEvent("PLAYER_REGEN_ENABLED")        -- pet may have died; swap text back
  frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
end

function PetReminderModule.OnEvent(event, ...)
  if not db then return end

  if event == "UNIT_DIED" then
    -- Fired only for "pet" via RegisterUnitEvent — our pet just died
    PlayWarningSound()
    RefreshDisplay()  -- show the warning immediately

  elseif event == "UNIT_PET" then
    local unitID = ...
    if unitID ~= "player" then return end
    -- Delay so UnitExists("pet") reflects the final state before we check.
    -- UNIT_PET can fire while the pet unit still exists during transitions.
    C_Timer.After(0.2, RefreshDisplay)

  elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
    local unitID = ...
    if unitID ~= "player" then return end
    RefreshDisplay()

  elseif event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
    -- Fires on mount and dismount. While mounted the IsMounted() check in
    -- RefreshDisplay suppresses the warning. On landing, re-check so the
    -- warning shows immediately if the pet didn't return.
    RefreshDisplay()

  elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
    -- Update combat/normal message text if warning is currently shown,
    -- then re-evaluate (post-combat: pet may have died)
    UpdateLabelText()
    RefreshDisplay()

  elseif event == "LOADING_SCREEN_DISABLED" then
    -- Additional trigger for normal login/reload/zone transitions.
    StartLoginPoll()

  elseif event == "PLAYER_ENTERING_WORLD" then
    -- Always start the poll here. New characters may skip the normal loading
    -- screen flow (intro cinematics, phased starter zones) so
    -- LOADING_SCREEN_DISABLED may never fire. PLAYER_ENTERING_WORLD always
    -- fires regardless of how the character enters the world.
    StartLoginPoll()
  end
end
