-- SpeedModule.lua
-- LibDataBroker data source "TokukoP: Speed": the character's current MAX
-- movement speed for its current state (ground / swimming / flying /
-- skyriding forward speed) as a plain percentage, 100% = normal run speed --
-- not the speed it is moving at right now.
-- Add it to an EllesmereUI data bar (LDB block) or any LDB display / ElvUI
-- datatext.
--
-- 12.x: GetUnitSpeed can return SECRET values (LiteMount guards it with
-- issecretvalue; ElvUI formats it via AbbreviateNumbers instead of doing
-- math). LibDataBroker compares old and new attribute values with `==`, and
-- comparing a secret throws -- so a secret reading is never pushed: the last
-- readable value stays shown. Max speed rarely changes mid-fight anyway.

local ADDON_NAME = ...
local TokukoP = TokukoP

local SpeedModule = {}
TokukoP.modules.Speed = SpeedModule

-- ===============================
-- Constants
-- ===============================

local LDB_NAME = "TokukoP: Speed"
local TICK     = 0.25   -- swim / fly / glide transitions have no event of their own
local BASE     = BASE_MOVEMENT_SPEED or 7  -- yards per second at 100%
local ICON     = "Interface\\Icons\\Ability_Rogue_Sprint"

-- ===============================
-- State
-- ===============================

local obj     = nil
local lastPct = nil    -- last value pushed to LDB (plain number)

local IsSecret = issecretvalue or function() return false end

-- ===============================
-- Reading
-- ===============================

-- Gliding (skyriding): forward speed is all there is -- a skyriding mount has
-- no fixed max. Returns isGliding, forwardSpeed (either may be nil).
local function GlideInfo()
  if not (C_PlayerInfo and C_PlayerInfo.GetGlidingInfo) then return false, nil end
  local isGliding, _, forwardSpeed = C_PlayerInfo.GetGlidingInfo()
  if IsSecret(isGliding) then isGliding = false end
  return isGliding == true, forwardSpeed
end

-- Max speed for the current state in yards/s; nil when unreadable (secret).
local function ReadMaxSpeed()
  local _, runSpeed, flightSpeed, swimSpeed = GetUnitSpeed("player")
  local isGliding, forwardSpeed = GlideInfo()
  local speed
  if IsSwimming() then
    speed = swimSpeed
  elseif isGliding then
    speed = forwardSpeed
  elseif IsFlying() then
    speed = flightSpeed
  else
    speed = runSpeed
  end
  -- Secret check FIRST: even `== nil` on a secret value throws.
  if IsSecret(speed) or speed == nil then return nil end
  return speed
end

local function Update()
  if not obj then return end
  local speed = ReadMaxSpeed()
  if not speed then return end  -- secret: keep the last readable value
  local pct = math.floor(speed / BASE * 100 + 0.5)
  if pct ~= lastPct then
    lastPct = pct
    obj.text = pct .. "%"
  end
end

-- ===============================
-- Lifecycle
-- ===============================

function SpeedModule.Initialize()
  local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
  if not LDB then return end
  obj = LDB:NewDataObject(LDB_NAME, {
    type          = "data source",
    label         = "Speed",
    icon          = ICON,
    text          = "-",
  })
  if not obj then return end
  Update()
  C_Timer.NewTicker(TICK, Update)
end
