-- DebugModule.lua
-- Optional debug commands for TokukoPreferences.
-- Only loaded if listed in the TOC. Remove from TOC to disable.
-- Commands: /tpdebug, /tpscan, /tpgap

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
-- /tpscan — find Details frame globals
-- ===============================
SLASH_TPSCAN1 = "/tpscan"
SlashCmdList["TPSCAN"] = function()
  print("|cff00ccffTokukoP Scan:|r Looking for Details frames...")
  for i = 1, 5 do
    local f = _G["DetailsBaseFrame" .. i]
    if f and f.IsObjectType and f:IsObjectType("Frame") then
      print("  FOUND: DetailsBaseFrame" .. i
            .. " size=" .. string.format("%.1f", f:GetWidth())
            .. "x" .. string.format("%.1f", f:GetHeight()))
    end
  end
  if Details then
    for i = 1, 5 do
      local ok, inst = pcall(function() return Details:GetInstance(i) end)
      if ok and inst then
        local bf = inst.baseframe
        print("  GetInstance(" .. i .. ").baseframe = "
              .. (bf and (bf:GetName() or "found (unnamed)") or "nil"))
      end
    end
  else
    print("  Details not loaded.")
  end
  print("|cff00ccffTokukoP Scan:|r Done.")
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
