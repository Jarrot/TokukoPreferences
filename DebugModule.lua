-- DebugModule.lua
-- Optional debug commands for TokukoPreferences.
-- Only loaded if listed in the TOC. Remove from TOC to disable.
-- Commands: /tpdebug, /tpscan, /tpgap, /tphmtest, /tpcrstats

local ADDON_NAME = ...
local TokukoP = TokukoP

-- ===============================
-- /tpdebug — embed state overview
-- ===============================
SLASH_TPDEBUG1 = "/tpdebug"
SlashCmdList["TPDEBUG"] = function()
  local E = TokukoP.modules.Embed
  if not E then print("TokukoP: EmbedModule not loaded."); return end
  E.PrintDebug()
end

-- ===============================
-- /tpscan — inspect Details frame structure
-- ===============================
SLASH_TPSCAN1 = "/tpscan"
SlashCmdList["TPSCAN"] = function()
  print("|cff00ccffTokukoP Scan:|r Inspecting Details frame structure...")

  local function frameInfo(f, label)
    if not f or not f.IsObjectType or not f:IsObjectType("Frame") then
      print("  " .. label .. " = nil/invalid")
      return
    end
    local name   = f:GetName() or "(unnamed)"
    local shown  = f:IsShown() and "shown" or "hidden"
    local vis    = f:IsVisible() and "visible" or "invisible"
    local strata = f:GetFrameStrata()
    local level  = f:GetFrameLevel()
    local alpha  = string.format("%.2f", f:GetEffectiveAlpha())
    local w      = string.format("%.1f", f:GetWidth())
    local h      = string.format("%.1f", f:GetHeight())
    local par    = f:GetParent()
    local parName = par and (par:GetName() or "(unnamed parent)") or "nil"
    print(string.format("  %s [%s] %sx%s strata=%s lvl=%d alpha=%s %s/%s parent=%s",
          label, name, w, h, strata, level, alpha, shown, vis, parName))
  end

  for i = 1, 2 do
    local f = _G["DetailsBaseFrame" .. i]
    if f then
      frameInfo(f, "DetailsBaseFrame" .. i)
      -- Known chrome children
      frameInfo(f.titleBar,      "  .titleBar")
      frameInfo(f.border,        "  .border")
      frameInfo(f.floatingframe, "  .floatingframe")
      -- All named children
      local kids = { f:GetChildren() }
      if #kids > 0 then
        print("  Children (" .. #kids .. "):")
        for _, c in ipairs(kids) do
          if c and c.IsObjectType and c:IsObjectType("Frame") then
            local cn     = c:GetName() or "(unnamed)"
            local cs     = c:GetFrameStrata()
            local cl     = c:GetFrameLevel()
            local ca     = string.format("%.2f", c:GetEffectiveAlpha())
            local cvis   = c:IsVisible() and "vis" or "hid"
            local cw     = string.format("%.0f", c:GetWidth())
            local ch     = string.format("%.0f", c:GetHeight())
            print(string.format("    [%s] strata=%s lvl=%d alpha=%s %s %sx%s",
                  cn, cs, cl, ca, cvis, cw, ch))
          end
        end
      end
      -- Separate sibling frames and key instance state
      if Details then
        local ok, inst = pcall(function() return Details:GetInstance(i) end)
        if ok and inst then
          print("  Separate sibling frames:")
          frameInfo(inst.rowframe,               "  inst.rowframe")
          frameInfo(inst.windowBackgroundDisplay, "  inst.windowBackgroundDisplay")
          frameInfo(inst.bgframe,                "  inst.bgframe")
          print(string.format("  Key flags: clickthrough_window=%s  titlebar_shown=%s",
                tostring(inst.clickthrough_window), tostring(inst.titlebar_shown)))
          -- All instance methods (sorted, batched to fit chat lines)
          local funcs = {}
          for k, v in pairs(inst) do
            if type(v) == "function" then funcs[#funcs + 1] = tostring(k) end
          end
          table.sort(funcs)
          print("  Methods (" .. #funcs .. "):")
          local line = "   "
          for _, f in ipairs(funcs) do
            local entry = " " .. f
            if #line + #entry > 240 then
              print(line)
              line = "   "
            end
            line = line .. entry
          end
          if #line > 3 then print(line) end
        end
      end
    end
  end

  -- Right panel chat frames (to diagnose strata of covering frames)
  local rcp = _G["RightChatPanel"]
  if rcp then
    print("Right panel (RightChatPanel) chat frame children:")
    for i = 1, 10 do
      local cf = _G["ChatFrame" .. i]
      if cf and cf:GetParent() == rcp then
        frameInfo(cf, "ChatFrame" .. i)
      end
    end
  end

  if not Details then print("  Details not loaded.") end
  print("|cff00ccffTokukoP Scan:|r Done.")
end

-- ===============================
-- /tphmtest — verify healer mana APIs; useful in different contexts
--             (solo, party, raid; in/out of combat; in/out of instances)
-- ===============================
SLASH_TPHMTEST1 = "/tphmtest"
SlashCmdList["TPHMTEST"] = function()
  local ScaleTo100 = CurveConstants and CurveConstants.ScaleTo100
  print("|cff00ccffHealerMana Test:|r CurveConstants.ScaleTo100=" .. tostring(ScaleTo100))
  print("  UnitPowerPercent=" .. tostring(UnitPowerPercent))

  -- Player
  local ok, pct = pcall(UnitPowerPercent, "player", 0, true, ScaleTo100)
  local rawPct   = UnitPowerPercent and UnitPowerPercent("player", 0) or "n/a"
  print("  player: pcall ok=" .. tostring(ok) .. " scaled=" .. tostring(pct)
        .. "  raw=" .. tostring(rawPct))

  local powerOk, power = pcall(UnitPower, "player", 0)
  print("  player UnitPower: ok=" .. tostring(powerOk) .. " val=" .. tostring(power))

  -- Party members
  if IsInRaid() then
    for i = 1, math.min(GetNumGroupMembers(), 5) do
      local unit = "raid" .. i
      if UnitExists(unit) then
        local uok, upct = pcall(UnitPowerPercent, unit, 0, true, ScaleTo100)
        local uname = UnitName(unit) or "?"
        print("  " .. unit .. " (" .. uname .. "): ok=" .. tostring(uok)
              .. " pct=" .. tostring(upct))
      end
    end
  elseif IsInGroup() then
    for i = 1, GetNumSubgroupMembers() do
      local unit = "party" .. i
      if UnitExists(unit) then
        local uok, upct = pcall(UnitPowerPercent, unit, 0, true, ScaleTo100)
        local uname = UnitName(unit) or "?"
        print("  " .. unit .. " (" .. uname .. "): ok=" .. tostring(uok)
              .. " pct=" .. tostring(upct))
      end
    end
  else
    print("  (not in group)")
  end
end

-- ===============================
-- /tpcrstats — CombatRes event fire rate
-- Usage:
--   /tpcrstats         print totals since login
--   /tpcrstats reset   start a timed window; run again to see rate over that period
-- ===============================
local crStatsWindowStart = nil

SLASH_TPCRSTATS1 = "/tpcrstats"
SlashCmdList["TPCRSTATS"] = function(arg)
  local cr = TokukoP.modules.CombatRes
  if not cr or not cr._eventStats then
    print("|cff00ccffTokukoP CombatRes:|r module not loaded.")
    return
  end
  local s = cr._eventStats

  if arg and arg:match("reset") then
    crStatsWindowStart    = GetTime()
    s.windowCharges       = 0
    print("|cff00ccffTokukoP CombatRes:|r Window reset. Run /tpcrstats again to see rate.")
    return
  end

  print("|cff00ccffTokukoP CombatRes Event Stats:|r")
  print(string.format("  SPELL_UPDATE_CHARGES  total: %d", s.totalCharges))
  print(string.format("  SPELL_UPDATE_COOLDOWN total: %d", s.totalCooldown))

  if crStatsWindowStart then
    local elapsed = GetTime() - crStatsWindowStart
    local rate = elapsed > 0 and (s.windowCharges / elapsed) or 0
    print(string.format("  Window: %.1fs  CHARGES fires: %d  (%.2f/sec)",
          elapsed, s.windowCharges, rate))
  else
    print("  Tip: /tpcrstats reset  to start a timed window")
  end
end

-- ===============================
-- /tpgap — measure frame-to-databar gap
-- ===============================
SLASH_TPGAP1 = "/tpgap"
SlashCmdList["TPGAP"] = function()
  local panel = _G["RightChatPanel"]
  local bar   = _G["RightChatDataPanel"]
  if panel then
    local _, _, _, _, py = panel:GetPoint(1)
    print("Panel top Y=" .. string.format("%.2f", py or 0)
          .. "  h=" .. string.format("%.2f", panel:GetHeight()))
  end
  if bar then
    local _, _, _, _, by = bar:GetPoint(1)
    print("DataBar top Y=" .. string.format("%.2f", by or 0)
          .. "  h=" .. string.format("%.2f", bar:GetHeight()))
  end
  for i = 1, 2 do
    local f = _G["DetailsBaseFrame" .. i]
    if f then
      local _, _, _, _, fy = f:GetPoint(1)
      local fh = f:GetHeight()
      local bottom = (fy or 0) - fh
      print("Frame" .. i .. " top Y=" .. string.format("%.2f", fy or 0)
            .. "  h=" .. string.format("%.2f", fh)
            .. "  bottom=" .. string.format("%.2f", bottom))
      if bar then
        local _, _, _, _, by = bar:GetPoint(1)
        print("  Gap to databar: " .. string.format("%.2f", bottom - (by or 0)))
      end
    end
  end
end
