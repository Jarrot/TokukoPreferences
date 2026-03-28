-- Settings.lua
-- When ElvUI is present: registers a TokukoPreferences panel inside /ec
-- When ElvUI is absent: falls back to a standalone /tp window

local ADDON_NAME = ...
local TokukoP = TokukoP

-- ===============================
-- Helpers
-- ===============================

local function GetE()
  if not ElvUI then return nil end
  local ok, E = pcall(function() return unpack(ElvUI) end)
  return ok and E or nil
end

local function GetS()
  local E = GetE()
  return E and E:GetModule("Skins", true) or nil
end

-- ===============================
-- ElvUI AceConfig Panel
-- ===============================

local function InsertElvUIOptions()
  local E = GetE()
  if not E or not E.Options then return end

  local db = TokukoPDB

  E.Options.args.TokukoPreferences = {
    order = 100,
    type  = "group",
    name  = "|cffffcc00Tokuko|rPreferences",
    args  = {

      -- ── Drinking ─────────────────────────────────────────
      drinkingHeader = {
        order = 1, type = "header", name = "Drinking Announcements",
      },
      drinkingEnabled = {
        order = 2, type = "toggle",
        name = "|cff00ff00Enable|r",
        desc = "Announce to group chat when you start or finish eating/drinking.",
        get  = function() return db.Drinking.enabled end,
        set  = function(_, v) db.Drinking.enabled = v end,
      },
      drinkingOnlyGroup = {
        order = 3, type = "toggle",
        name = "Only in Group / Instance",
        get  = function() return db.Drinking.onlyInGroup end,
        set  = function(_, v) db.Drinking.onlyInGroup = v end,
      },
      drinkingAnnounceComplete = {
        order = 4, type = "toggle",
        name = "Announce When Done",
        get  = function() return db.Drinking.announceComplete end,
        set  = function(_, v) db.Drinking.announceComplete = v end,
      },
      drinkingMessage = {
        order = 5, type = "input", width = "half",
        name = "Start Message",
        get  = function() return db.Drinking.message end,
        set  = function(_, v) db.Drinking.message = v end,
      },
      drinkingCompleteMessage = {
        order = 6, type = "input", width = "half",
        name = "Complete Message",
        get  = function() return db.Drinking.completeMessage end,
        set  = function(_, v) db.Drinking.completeMessage = v end,
      },

      -- ── Embed ─────────────────────────────────────────────
      embedHeader = {
        order = 10, type = "header", name = "Damage Meter Embed",
      },
      embedEnabled = {
        order = 11, type = "toggle",
        name = "|cff00ff00Enable|r",
        desc = "Embed Details! into ElvUI's right chat panel.\n/tpembed to toggle. Right-click > to hide/show.",
        get  = function() return db.Embed.enabled end,
        set  = function(_, v)
          db.Embed.enabled = v
          if v and not TokukoP.modules.Embed.IsEmbedded() then
            TokukoP.modules.Embed.Toggle()
          elseif not v and TokukoP.modules.Embed.IsEmbedded() then
            TokukoP.modules.Embed.Toggle()
          end
        end,
      },
      embedDual = {
        order = 12, type = "toggle",
        name = "Dual Window (left + right)",
        desc = "Embed two Details! windows side by side.",
        get  = function() return db.Embed.dualEmbed end,
        set  = function(_, v) db.Embed.dualEmbed = v end,
      },
      embedCombatOnly = {
        order = 13, type = "toggle",
        name = "Hide Out of Combat",
        desc = "Hides the meter windows when out of combat, shows them in combat. Meters stay embedded.",
        get  = function() return db.Embed.combatOnly end,
        set  = function(_, v) db.Embed.combatOnly = v end,
      },
      embedSplitRatio = {
        order = 15, type = "range",
        name = "Split Ratio (left %)",
        min = 20, max = 80, step = 1,
        get  = function() return math.floor((db.Embed.splitRatio or 0.5) * 100) end,
        set  = function(_, v) db.Embed.splitRatio = v / 100 end,
      },
      embedWindow1 = {
        order = 16, type = "range",
        name = "Window 1  (left / single)",
        min = 1, max = 5, step = 1,
        get  = function() return db.Embed.window1 or 1 end,
        set  = function(_, v) db.Embed.window1 = v end,
      },
      embedWindow2 = {
        order = 17, type = "range",
        name = "Window 2  (right)",
        min = 1, max = 5, step = 1,
        get  = function() return db.Embed.window2 or 2 end,
        set  = function(_, v) db.Embed.window2 = v end,
      },

      -- ── Tooltip ───────────────────────────────────────────
      tooltipHeader = {
        order = 20, type = "header", name = "Tooltip",
      },
      tooltipEnabled = {
        order = 21, type = "toggle",
        name = "|cff00ff00Enable|r",
        desc = "Tooltip follows cursor when out of combat.\nSnaps to fixed ElvUI anchor position in combat.",
        get  = function() return db.Tooltip and db.Tooltip.enabled end,
        set  = function(_, v)
          db.Tooltip.enabled = v
          if v and ElvUI then
            local E2 = GetE()
            if E2 and E2.db and E2.db.tooltip then
              E2.db.tooltip.cursorAnchor = not InCombatLockdown()
            end
          end
        end,
      },
      tooltipDesc = {
        order = 22, type = "description", fontSize = "small",
        name = "Cursor anchored tooltip out of combat, fixed anchor in combat.",
      },
    },
  }
end

-- ===============================
-- Fallback Standalone Window
-- (used when ElvUI is not loaded)
-- ===============================

local function SkinBtn(btn)
  local S = GetS()
  if S and S.HandleButton then pcall(function() S:HandleButton(btn) end) end
end
local function SkinCB(cb)
  local S = GetS()
  if S and S.HandleCheckBox then pcall(function() S:HandleCheckBox(cb) end) end
end
local function SkinEB(eb)
  local S = GetS()
  if S and S.HandleEditBox then pcall(function() S:HandleEditBox(eb) end) end
end

local function MakeCheckbox(parent, label, tooltip, getValue, setValue, yOffset)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetPoint("TOPLEFT", 20, yOffset)
  cb:SetChecked(getValue())
  cb:SetScript("OnClick", function(self) setValue(self:GetChecked()) end)
  SkinCB(cb)
  cb:SetSize(20, 20)
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
  SkinEB(eb)
  local function Save(self) setValue(self:GetText()); self:ClearFocus() end
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

local function MakeHeader(parent, text, yOffset)
  local h = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  h:SetPoint("TOPLEFT", 14, yOffset)
  h:SetText("|cffffcc00" .. text .. "|r")
  return h
end

local function MakeDivider(parent, yOffset)
  local line = parent:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(0.4, 0.4, 0.4, 0.8)
  line:SetSize(380, 1)
  line:SetPoint("TOPLEFT", 14, yOffset)
  return line
end

local settingsFrame = nil

local function BuildFallbackWindow()
  local f = CreateFrame("Frame", "TokukoPSettingsFrame", UIParent, "BasicFrameTemplateWithInset")
  f:SetSize(420, 480)
  f:SetPoint("CENTER")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetClampedToScreen(true)
  f:Hide()
  f.TitleText:SetText("TokukoPreferences")
  f:SetScript("OnKeyDown", function(self, key)
    if key == "ESCAPE" then self:Hide() end
  end)
  f:SetPropagateKeyboardInput(true)

  local y = -34

  MakeHeader(f, "Drinking Announcements", y); y = y - 26
  MakeCheckbox(f, "Enable Drinking Announcements", nil,
    function() return TokukoPDB.Drinking.enabled end,
    function(v) TokukoPDB.Drinking.enabled = v end, y); y = y - 28
  MakeCheckbox(f, "Only in Group / Instance", nil,
    function() return TokukoPDB.Drinking.onlyInGroup end,
    function(v) TokukoPDB.Drinking.onlyInGroup = v end, y); y = y - 28
  MakeCheckbox(f, "Announce When Done", nil,
    function() return TokukoPDB.Drinking.announceComplete end,
    function(v) TokukoPDB.Drinking.announceComplete = v end, y); y = y - 30
  MakeEditBox(f, "Start Message:", nil,
    function() return TokukoPDB.Drinking.message end,
    function(v) TokukoPDB.Drinking.message = v end, y); y = y - 52
  MakeEditBox(f, "Complete Message:", nil,
    function() return TokukoPDB.Drinking.completeMessage end,
    function(v) TokukoPDB.Drinking.completeMessage = v end, y); y = y - 44

  MakeDivider(f, y); y = y - 14
  MakeHeader(f, "Damage Meter Embed", y); y = y - 26
  MakeCheckbox(f, "Enable Embed", nil,
    function() return TokukoPDB.Embed.enabled end,
    function(v)
      TokukoPDB.Embed.enabled = v
      if v and not TokukoP.modules.Embed.IsEmbedded() then TokukoP.modules.Embed.Toggle()
      elseif not v and TokukoP.modules.Embed.IsEmbedded() then TokukoP.modules.Embed.Toggle() end
    end, y); y = y - 28
  MakeCheckbox(f, "Dual Window Embed", nil,
    function() return TokukoPDB.Embed.dualEmbed end,
    function(v) TokukoPDB.Embed.dualEmbed = v end, y); y = y - 28
  MakeCheckbox(f, "Hide Out of Combat", nil,
    function() return TokukoPDB.Embed.combatOnly end,
    function(v) TokukoPDB.Embed.combatOnly = v end, y); y = y - 28

  MakeDivider(f, y); y = y - 14
  MakeHeader(f, "Tooltip", y); y = y - 26
  MakeCheckbox(f, "Cursor Anchor Out of Combat", nil,
    function() return TokukoPDB.Tooltip and TokukoPDB.Tooltip.enabled end,
    function(v)
      TokukoPDB.Tooltip.enabled = v
      if v and ElvUI then
        local E = GetE()
        if E and E.db and E.db.tooltip then
          E.db.tooltip.cursorAnchor = not InCombatLockdown()
        end
      end
    end, y)

  return f
end

-- ===============================
-- Public API
-- ===============================

function TokukoP.OpenSettings()
  local E = GetE()
  if E then
    -- Open ElvUI config panel directly on our section
    if not E.Options then
      print("|cffffcc00TokukoP:|r ElvUI options not loaded yet. Try again in a moment.")
      return
    end
    -- Use LibElvUIPlugin or open /ec directly
    local EP = LibStub and LibStub("LibElvUIPlugin-1.0", true)
    if EP then
      E:ToggleOptions()
    else
      E:ToggleOptions()
    end
    return
  end
  -- Fallback: standalone window
  if settingsFrame then settingsFrame:Hide(); settingsFrame = nil end
  settingsFrame = BuildFallbackWindow()
  settingsFrame:Show()
end

function TokukoP.CreateSettingsPanel()
  local E = GetE()
  if not E then return end
  -- Register with LibElvUIPlugin so our section appears in /ec
  local EP = LibStub and LibStub("LibElvUIPlugin-1.0", true)
  if EP then
    EP:RegisterPlugin(ADDON_NAME, InsertElvUIOptions)
  else
    -- Fallback: insert directly if ElvUI_Options is already loaded
    C_Timer.After(1, function()
      if E.Options then InsertElvUIOptions() end
    end)
  end
end

-- ===============================
-- Slash Commands
-- ===============================
SLASH_TOKUKOP1 = "/tokukop"
SLASH_TOKUKOP2 = "/tp"
SlashCmdList["TOKUKOP"] = function()
  TokukoP.OpenSettings()
end
