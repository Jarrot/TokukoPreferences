-- Settings.lua
-- Custom settings window opened via /tp (or /tokukop)

local ADDON_NAME = ...
local TokukoP = TokukoP

-- ===============================
-- UI Helpers
-- ===============================

local function MakeCheckbox(parent, label, tooltip, getValue, setValue, yOffset)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetPoint("TOPLEFT", 20, yOffset)
  cb:SetChecked(getValue())
  cb:SetScript("OnClick", function(self)
    setValue(self:GetChecked())
  end)

  local text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
  text:SetText(label)

  if tooltip then
    cb:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(tooltip, nil, nil, nil, nil, true)
      GameTooltip:Show()
    end)
    cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end

  return cb
end

local function MakeEditBox(parent, label, tooltip, getValue, setValue, yOffset)
  local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  lbl:SetPoint("TOPLEFT", 20, yOffset)
  lbl:SetText(label)

  local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  eb:SetSize(300, 22)
  eb:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 4, -4)
  eb:SetAutoFocus(false)
  eb:SetMaxLetters(200)
  eb:SetText(getValue())

  local function Save(self)
    setValue(self:GetText())
    self:ClearFocus()
  end
  eb:SetScript("OnEnterPressed", Save)
  eb:SetScript("OnEditFocusLost", Save)

  if tooltip then
    eb:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(tooltip, nil, nil, nil, nil, true)
      GameTooltip:Show()
    end)
    eb:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end

  return lbl, eb
end

local function MakeSectionHeader(parent, text, yOffset)
  local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  header:SetPoint("TOPLEFT", 14, yOffset)
  header:SetText("|cffffcc00" .. text .. "|r")
  return header
end

local function MakeDivider(parent, yOffset)
  local line = parent:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(0.4, 0.4, 0.4, 0.6)
  line:SetSize(340, 1)
  line:SetPoint("TOPLEFT", 14, yOffset)
  return line
end

-- ===============================
-- Window Creation
-- ===============================

local settingsFrame = nil

local function BuildSettingsWindow()
  local f = CreateFrame("Frame", "TokukoPSettingsFrame", UIParent, "BasicFrameTemplateWithInset")
  f:SetSize(420, 720)
  f:SetPoint("CENTER")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetClampedToScreen(true)
  f:Hide()

  f.TitleText:SetText("TokukoPreferences")

  local y = -34

  -- ── Drinking ────────────────────────────────────────────
  MakeSectionHeader(f, "Drinking Announcements", y)
  y = y - 26

  MakeCheckbox(f, "Enable Drinking Announcements",
    "Toggle drinking announcements on/off.",
    function() return TokukoPDB.Drinking.enabled end,
    function(v) TokukoPDB.Drinking.enabled = v end,
    y)
  y = y - 30

  MakeCheckbox(f, "Only in Group / Instance",
    "Only announce when you are in a party, raid, or instance.",
    function() return TokukoPDB.Drinking.onlyInGroup end,
    function(v) TokukoPDB.Drinking.onlyInGroup = v end,
    y)
  y = y - 30

  MakeCheckbox(f, "Announce When Done",
    "Announce when you finish eating/drinking (after 8+ seconds).",
    function() return TokukoPDB.Drinking.announceComplete end,
    function(v) TokukoPDB.Drinking.announceComplete = v end,
    y)
  y = y - 34

  MakeEditBox(f, "Start Message:",
    "Sent to group chat when you start eating or drinking.",
    function() return TokukoPDB.Drinking.message end,
    function(v) TokukoPDB.Drinking.message = v end,
    y)
  y = y - 54

  MakeEditBox(f, "Complete Message:",
    "Sent to group chat when you finish eating or drinking.",
    function() return TokukoPDB.Drinking.completeMessage end,
    function(v) TokukoPDB.Drinking.completeMessage = v end,
    y)
  y = y - 44

  -- ── Divider ─────────────────────────────────────────────
  MakeDivider(f, y)
  y = y - 14

  -- ── Embed ────────────────────────────────────────────────
  MakeSectionHeader(f, "Damage Meter Embed (requires ElvUI)", y)
  y = y - 26

  MakeCheckbox(f, "Enable Embed",
    "Embed meter into ElvUI's right chat panel.\nUse /tpembed to toggle, or bind a key.",
    function() return TokukoPDB.Embed and TokukoPDB.Embed.enabled end,
    function(v)
      TokukoPDB.Embed.enabled = v
      if v and not TokukoP.modules.Embed.IsEmbedded() then
        -- Enabling: trigger the embed immediately
        TokukoP.modules.Embed.Toggle()
      elseif not v and TokukoP.modules.Embed.IsEmbedded() then
        -- Disabling: detach immediately
        TokukoP.modules.Embed.Toggle()
      end
    end,
    y)
  y = y - 30

  local addonLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  addonLabel:SetPoint("TOPLEFT", 20, y)
  addonLabel:SetText("Meter Addon:")

  local addonBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  addonBtn:SetSize(110, 22)
  addonBtn:SetPoint("LEFT", addonLabel, "RIGHT", 8, 0)
  addonBtn:SetText(TokukoPDB.Embed and TokukoPDB.Embed.meterAddon or "Details")
  addonBtn:SetScript("OnClick", function(self)
    local db = TokukoPDB.Embed
    -- Only Details and Skada support full embed (resize + reparent)
    -- Blizzard meter is Edit Mode controlled and cannot be reliably resized
    db.meterAddon = db.meterAddon == "Details" and "Skada" or "Details"
    self:SetText(db.meterAddon)
  end)
  y = y - 30

  MakeCheckbox(f, "Dual Window Embed (left + right)",
    "Embed two meter windows side by side in the panel.\nNot supported with the Blizzard meter (single window only).",
    function() return TokukoPDB.Embed and TokukoPDB.Embed.dualEmbed end,
    function(v) TokukoPDB.Embed.dualEmbed = v end,
    y)
  y = y - 30

  MakeCheckbox(f, "Show Only In Combat",
    "Meter embeds when you enter combat and detaches on leaving combat.",
    function() return TokukoPDB.Embed and TokukoPDB.Embed.combatOnly end,
    function(v) TokukoPDB.Embed.combatOnly = v end,
    y)
  y = y - 34

  local splitLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  splitLabel:SetPoint("TOPLEFT", 20, y)
  splitLabel:SetText("Dual Split Ratio (left % width):")

  local splitEB = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
  splitEB:SetSize(50, 22)
  splitEB:SetPoint("LEFT", splitLabel, "RIGHT", 8, 0)
  splitEB:SetAutoFocus(false)
  splitEB:SetMaxLetters(4)
  splitEB:SetText(tostring(math.floor((TokukoPDB.Embed and TokukoPDB.Embed.splitRatio or 0.5) * 100)))
  local function SaveSplit(self)
    local v = tonumber(self:GetText())
    if v then
      TokukoPDB.Embed.splitRatio = TokukoP.Clamp(v / 100, 0.2, 0.8)
      self:SetText(tostring(math.floor(TokukoPDB.Embed.splitRatio * 100)))
    end
    self:ClearFocus()
  end
  splitEB:SetScript("OnEnterPressed", SaveSplit)
  splitEB:SetScript("OnEditFocusLost", SaveSplit)
  y = y - 30

  local w1Label = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  w1Label:SetPoint("TOPLEFT", 20, y)
  w1Label:SetText("Window 1 index:")
  local w1EB = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
  w1EB:SetSize(40, 22)
  w1EB:SetPoint("LEFT", w1Label, "RIGHT", 8, 0)
  w1EB:SetAutoFocus(false)
  w1EB:SetMaxLetters(2)
  w1EB:SetText(tostring(TokukoPDB.Embed and TokukoPDB.Embed.window1 or 1))
  local function SaveW1(self)
    local v = tonumber(self:GetText())
    if v then TokukoPDB.Embed.window1 = math.max(1, math.floor(v)) end
    self:SetText(tostring(TokukoPDB.Embed.window1))
    self:ClearFocus()
  end
  w1EB:SetScript("OnEnterPressed", SaveW1)
  w1EB:SetScript("OnEditFocusLost", SaveW1)

  local w2Label = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  w2Label:SetPoint("LEFT", w1EB, "RIGHT", 16, 0)
  w2Label:SetText("Window 2 index:")
  local w2EB = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
  w2EB:SetSize(40, 22)
  w2EB:SetPoint("LEFT", w2Label, "RIGHT", 8, 0)
  w2EB:SetAutoFocus(false)
  w2EB:SetMaxLetters(2)
  w2EB:SetText(tostring(TokukoPDB.Embed and TokukoPDB.Embed.window2 or 2))
  local function SaveW2(self)
    local v = tonumber(self:GetText())
    if v then TokukoPDB.Embed.window2 = math.max(1, math.floor(v)) end
    self:SetText(tostring(TokukoPDB.Embed.window2))
    self:ClearFocus()
  end
  w2EB:SetScript("OnEnterPressed", SaveW2)
  w2EB:SetScript("OnEditFocusLost", SaveW2)
  y = y - 34

  local embedToggleBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  embedToggleBtn:SetSize(160, 24)
  embedToggleBtn:SetPoint("TOPLEFT", 20, y)
  embedToggleBtn:SetText("Toggle Embed Now")
  embedToggleBtn:SetScript("OnClick", function()
    TokukoP.modules.Embed.Toggle()
  end)
  y = y - 36

  -- ── Divider ─────────────────────────────────────────────
  MakeDivider(f, y)
  y = y - 14

  -- ── Tooltip ─────────────────────────────────────────────
  MakeSectionHeader(f, "Tooltip (requires ElvUI)", y)
  y = y - 26

  MakeCheckbox(f, "Cursor Anchor Out of Combat",
    "Tooltip follows cursor when out of combat.\nSnaps to your fixed ElvUI anchor position when in combat.",
    function() return TokukoPDB.Tooltip and TokukoPDB.Tooltip.enabled end,
    function(v)
      TokukoPDB.Tooltip.enabled = v
      if v and ElvUI then
        local E = unpack(ElvUI)
        if E and E.db and E.db.tooltip then
          E.db.tooltip.cursorAnchor = not InCombatLockdown()
        end
      end
    end,
    y)

  return f
end

-- ===============================
-- Public API
-- ===============================

function TokukoP.OpenSettings()
  if settingsFrame then
    settingsFrame:Hide()
    settingsFrame = nil
  end
  settingsFrame = BuildSettingsWindow()
  settingsFrame:Show()
end

function TokukoP.CreateSettingsPanel()
  return nil, nil
end

-- ===============================
-- Slash Commands
-- ===============================
SLASH_TOKUKOP1 = "/tokukop"
SLASH_TOKUKOP2 = "/tp"
SlashCmdList["TOKUKOP"] = function()
  TokukoP.OpenSettings()
end
