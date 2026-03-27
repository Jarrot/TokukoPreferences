-- Settings.lua
-- Custom settings window opened via /tp (or /tokukop)

local ADDON_NAME = ...
local TokukoP = TokukoP

-- ===============================
-- ElvUI Skinning Helper
-- ===============================

-- Returns the ElvUI engine (E) if available, nil otherwise.
local function GetElvUI()
  if not ElvUI then return nil end
  local ok, E = pcall(function() return unpack(ElvUI) end)
  return ok and E or nil
end

-- Apply ElvUI backdrop/border template to a frame.
-- Falls back silently if ElvUI not loaded.
local function SkinFrame(frame)
  local E = GetElvUI()
  if not E or not frame.SetTemplate then return end
  frame:SetTemplate("Default")
end

local function SkinButton(btn)
  local E = GetElvUI()
  if E and E.SkinButton then E:SkinButton(btn) end
end

local function SkinCheckBox(cb)
  local E = GetElvUI()
  if E and E.SkinCheckBox then E:SkinCheckBox(cb) end
end

local function SkinEditBox(eb)
  local E = GetElvUI()
  if E and E.SkinEditBox then E:SkinEditBox(eb) end
end

local function SkinCloseButton(btn, parent)
  local E = GetElvUI()
  if E and E.SkinCloseButton then E:SkinCloseButton(btn, parent) end
end

-- ===============================
-- UI Helpers
-- ===============================

local function MakeCheckbox(parent, label, tooltip, getValue, setValue, yOffset)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetPoint("TOPLEFT", 20, yOffset)
  cb:SetChecked(getValue())
  cb:SetScript("OnClick", function(self) setValue(self:GetChecked()) end)
  SkinCheckBox(cb)

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
  SkinEditBox(eb)

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
  local E = GetElvUI()
  -- Use ElvUI accent color if available, else gold
  local color = (E and E.media and E.media.hexvaluecolor) and
                ("|cff" .. E.media.hexvaluecolor) or "|cffffcc00"
  local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  header:SetPoint("TOPLEFT", 14, yOffset)
  header:SetText(color .. text .. "|r")
  return header
end

local function MakeDivider(parent, yOffset)
  local line = parent:CreateTexture(nil, "ARTWORK")
  local E = GetElvUI()
  local r, g, b = 0.4, 0.4, 0.4
  if E and E.media and E.media.bordercolor then
    r, g, b = unpack(E.media.bordercolor)
  end
  line:SetColorTexture(r, g, b, 0.8)
  line:SetSize(380, 1)
  line:SetPoint("TOPLEFT", 14, yOffset)
  return line
end

-- ===============================
-- Window Creation
-- ===============================

local settingsFrame = nil

local function BuildSettingsWindow()
  local E = GetElvUI()

  -- Use plain Frame + ElvUI skin if available, else fall back to Blizzard template
  local f
  if E then
    f = CreateFrame("Frame", "TokukoPSettingsFrame", UIParent, "BackdropTemplate")
    f:SetTemplate("Default")

    -- Title bar
    local titleBar = CreateFrame("Frame", nil, f, "BackdropTemplate")
    titleBar:SetHeight(24)
    titleBar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    titleBar:SetTemplate("Default")

    local titleText = titleBar:CreateFontString(nil, "OVERLAY")
    titleText:SetFontObject("GameFontNormal")
    titleText:SetPoint("CENTER", titleBar, "CENTER")
    titleText:SetText("TokukoPreferences")
    if E.media and E.media.hexvaluecolor then
      titleText:SetTextColor(E:ColorGradient(1, 1, 1))
    end
    f.TitleText = titleText

    -- Close button
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", 2, 2)
    closeBtn:SetScript("OnClick", function() f:Hide() end)
    SkinCloseButton(closeBtn, f)
    f.CloseButton = closeBtn

    -- Drag via title bar
    f:SetMovable(true)
    f:EnableMouse(true)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() f:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
  else
    f = CreateFrame("Frame", "TokukoPSettingsFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f.TitleText:SetText("TokukoPreferences")
  end

  f:SetSize(420, 720)
  f:SetPoint("CENTER")
  f:SetClampedToScreen(true)
  f:Hide()

  local y = E and -30 or -34

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
    -- Details is the only fully supported embed addon for 12.0
    -- (Skada removed: unmaintained in 12.0; Blizzard meter: not resizable)
    TokukoPDB.Embed.meterAddon = "Details"
    self:SetText("Details")
  end)
  SkinButton(addonBtn)
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
  SkinEditBox(splitEB)
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
  SkinEditBox(w1EB)

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
  SkinEditBox(w2EB)
  y = y - 34

  local embedToggleBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  embedToggleBtn:SetSize(160, 24)
  embedToggleBtn:SetPoint("TOPLEFT", 20, y)
  embedToggleBtn:SetText("Toggle Embed Now")
  embedToggleBtn:SetScript("OnClick", function()
    TokukoP.modules.Embed.Toggle()
  end)
  SkinButton(embedToggleBtn)
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
