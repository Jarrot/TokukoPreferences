-- SoulstoneReminderModule.lua
-- Whispers a configured player when a pull countdown starts and nobody in the
-- group carries a Soulstone buff. Covers both DBM pull timers and the native
-- /countdown: since 9.x DBM's pull timer is just C_PartyInfo.DoCountdown(),
-- so both surface as the Blizzard START_PLAYER_COUNTDOWN event.

local ADDON_NAME = ...
local TokukoP = TokukoP

local SoulstoneReminderModule = {}
TokukoP.modules.SoulstoneReminder = SoulstoneReminderModule

-- ===============================
-- Constants
-- ===============================

local SOULSTONE_SPELL_ID = 20707  -- the buff placed on the soulstoned unit

-- A countdown can be cancelled and re-sent (or a break timer follow a pull
-- timer); don't nag more than once inside this window.
local REPEAT_COOLDOWN = 20

local DEFAULTS = {
  enabled    = true,
  targetName = "Warlock",
  message    = "GIVE SOMEONE SS PLEASE!",
  onlyInRaid = true,   -- ignore 5-man / party countdowns
}

-- ===============================
-- State
-- ===============================

local db              = nil
local lastWhisperTime = 0

-- 12.x: aura data can come back as secret values; comparing or branching on
-- one taints execution. issecretvalue is absent on older clients.
local IsSecret = issecretvalue or function() return false end

-- C_ChatInfo.SendChatMessage is the current home; keep the global as a fallback.
local SendChat = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage

-- ===============================
-- Helpers
-- ===============================

-- Strip any "-Realm" suffix and lowercase so the configured name matches
-- however the user typed it.
local function NormalizeName(name)
  if not name or name == "" then return nil end
  local short = name:match("^([^%-]+)") or name
  return short:lower()
end

local function GroupUnitPrefix()
  if IsInRaid() then return "raid" end
  return "party"
end

-- Iterate every unit in the group (including the player when in a party,
-- since "party1..4" excludes us).
local function ForEachGroupUnit(fn)
  local prefix = GroupUnitPrefix()
  local n = GetNumGroupMembers()
  if prefix == "raid" then
    for i = 1, n do
      if fn("raid" .. i) then return true end
    end
  else
    if fn("player") then return true end
    for i = 1, n - 1 do
      if fn("party" .. i) then return true end
    end
  end
  return false
end

-- Returns true / false, or nil when the answer can't be trusted (aura data
-- came back secret or the API errored — e.g. combat in instanced content).
local function UnitHasSoulstone(unit)
  if not UnitExists(unit) or not UnitIsConnected(unit) then return false end

  -- Fast path: one call per unit. Out of combat this returns a plain aura
  -- table (or nil when absent) for group members.
  if C_UnitAuras.GetUnitAuraBySpellID then
    local ok, aura = pcall(C_UnitAuras.GetUnitAuraBySpellID, unit, SOULSTONE_SPELL_ID)
    if ok then
      if aura == nil then return false end
      if not IsSecret(aura) then return true end
      return nil
    end
  end

  -- Fallback: walk the HELPFUL auras and match on spellId.
  for i = 1, 255 do
    local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HELPFUL")
    if not ok then return nil end
    if not aura then break end
    local sid = aura.spellId
    if sid and not IsSecret(sid) and sid == SOULSTONE_SPELL_ID then
      return true
    end
  end
  return false
end

-- Returns:
--   true            someone has a Soulstone
--   false           scan completed, nobody has one
--   nil             at least one unit was unreadable and nobody else had it
local function AnyoneHasSoulstone()
  local unreadable = false
  local found = ForEachGroupUnit(function(unit)
    local has = UnitHasSoulstone(unit)
    if has == true then return true end
    if has == nil then unreadable = true end
    return false
  end)
  if found then return true end
  if unreadable then return nil end
  return false
end

-- Full whisper-able name ("Name" or "Name-Realm") of the configured target
-- if they are in the group, else nil.
local function FindTargetInGroup()
  local want = NormalizeName(db.targetName)
  if not want then return nil end
  local result = nil
  ForEachGroupUnit(function(unit)
    if UnitExists(unit) and NormalizeName(UnitName(unit)) == want then
      result = GetUnitName(unit, true)
      return true
    end
    return false
  end)
  return result
end

local function Say(msg)
  print("|cff00b3ffTokukoP|r Soulstone: " .. msg)
end

-- ===============================
-- Core check
-- ===============================

-- dryRun: report what would happen instead of whispering (for /tpss).
local function RunCheck(dryRun)
  if not db then return end
  if not dryRun and not db.enabled then return end

  if InCombatLockdown() then
    if dryRun then Say("skipped — in combat") end
    return
  end

  if not IsInGroup() then
    if dryRun then Say("skipped — not in a group") end
    return
  end
  if db.onlyInRaid and not IsInRaid() then
    if dryRun then Say("skipped — not a raid group (Raid Groups Only is on)") end
    return
  end

  local target = FindTargetInGroup()
  if not target then
    if dryRun then Say("skipped — '" .. tostring(db.targetName) .. "' is not in the group") end
    return
  end

  local has = AnyoneHasSoulstone()
  if has == true then
    if dryRun then Say("someone already has a Soulstone — nothing to do") end
    return
  elseif has == nil then
    -- Can't tell; better to stay quiet than to whisper on bad data.
    if dryRun then Say("skipped — aura data unreadable right now") end
    return
  end

  if dryRun then
    Say("would whisper " .. target .. ": " .. db.message)
    return
  end

  local now = GetTime()
  if now - lastWhisperTime < REPEAT_COOLDOWN then return end
  lastWhisperTime = now

  SendChat(db.message, "WHISPER", nil, target)
  Say("whispered " .. target)
end

-- ===============================
-- Caster report (/tpss) -- groundwork for multi-warlock support
-- ===============================
-- Can we tell WHICH warlock placed each Soulstone? AuraData.sourceUnit names
-- the caster's unit, but in 12.x it can be a secret value for group members'
-- auras even when the aura itself is readable (BliZzi_Interrupts documents
-- this for party auras in M+). Out of combat in a raid is untested, so /tpss
-- prints what it can see: every Soulstone with its caster (or why the caster
-- is unknown), and every warlock in the group with whether theirs is out.
-- Read-only; whispers nothing. Every value is secret-checked BEFORE any
-- compare (comparing a secret taints the branch that uses the result).

-- Plain string from a possibly-secret value, else nil.
local function Plain(v)
  if IsSecret(v) or type(v) ~= "string" or v == "" then return nil end
  return v
end

-- Caster of the Soulstone on `unit`:
--   "none"                      no Soulstone on the unit
--   "unreadable"                aura data secret / API error
--   "secret"                    Soulstone found, caster hidden
--   "gone"                      caster unit given but no longer resolves
--   "ok", name, casterUnit      caster known
local function SoulstoneCaster(unit)
  if not C_UnitAuras.GetUnitAuraBySpellID then return "unreadable" end
  local ok, aura = pcall(C_UnitAuras.GetUnitAuraBySpellID, unit, SOULSTONE_SPELL_ID)
  if not ok then return "unreadable" end
  if aura == nil then return "none" end
  if IsSecret(aura) then return "unreadable" end
  local okSU, src = pcall(function() return aura.sourceUnit end)
  if not okSU then return "secret" end
  src = Plain(src)
  if not src then return "secret" end
  if not UnitExists(src) then return "gone" end
  local name = Plain(GetUnitName(src, true))
  if not name then return "secret" end
  return "ok", name, src
end

local function IsWarlock(unit)
  local okC, _, class = pcall(UnitClass, unit)
  return okC and Plain(class) == "WARLOCK"
end

local function ReportCasters()
  if not IsInGroup() then return end
  if InCombatLockdown() then Say("caster report skipped - in combat"); return end
  local warlocks, placed = {}, {}
  local lines = {}
  ForEachGroupUnit(function(unit)
    if not UnitExists(unit) then return false end
    local who = Plain(GetUnitName(unit, true)) or unit
    if IsWarlock(unit) then warlocks[#warlocks + 1] = who end
    local state, caster = SoulstoneCaster(unit)
    if state == "ok" then
      placed[caster] = true
      lines[#lines + 1] = who .. " has SS from " .. caster
    elseif state == "secret" then
      lines[#lines + 1] = who .. " has SS, caster |cffff7f3fhidden (secret)|r"
    elseif state == "gone" then
      lines[#lines + 1] = who .. " has SS, caster not in group"
    elseif state == "unreadable" then
      lines[#lines + 1] = who .. ": |cffff7f3faura data unreadable|r"
    end
    return false
  end)
  Say("caster report (" .. (IsInRaid() and "raid" or "party") .. ", out of combat)")
  if #lines == 0 then print("   no Soulstones in the group") end
  for _, l in ipairs(lines) do print("   " .. l) end
  if #warlocks == 0 then
    print("   no warlocks in the group")
  else
    for _, w in ipairs(warlocks) do
      print("   warlock " .. w .. ": " .. (placed[w] and "|cff00ff00SS out|r" or "no SS seen"))
    end
  end
end

-- ===============================
-- Public API
-- ===============================

function SoulstoneReminderModule.Check(dryRun)
  RunCheck(dryRun)
end

-- ===============================
-- Module Interface
-- ===============================

function SoulstoneReminderModule.Initialize()
  TokukoPDB.SoulstoneReminder = TokukoPDB.SoulstoneReminder or {}
  TokukoP.MergeDefaults(TokukoPDB.SoulstoneReminder, DEFAULTS)
  db = TokukoPDB.SoulstoneReminder
end

function SoulstoneReminderModule.RegisterEvents(frame)
  frame:RegisterEvent("START_PLAYER_COUNTDOWN")
end

function SoulstoneReminderModule.OnEvent(event, ...)
  if event ~= "START_PLAYER_COUNTDOWN" then return end
  -- The args (initiator GUID, duration) can be secret values in 12.x — DBM
  -- guards them with hasanysecretvalues. We don't need them, so don't read them.
  RunCheck(false)
end

-- ===============================
-- Slash Commands
-- ===============================

-- /tpss — dry run: prints what the countdown check would do right now, then
-- the caster report (who placed each Soulstone).
SLASH_TPSS1 = "/tpss"
SlashCmdList["TPSS"] = function()
  RunCheck(true)
  ReportCasters()
end
