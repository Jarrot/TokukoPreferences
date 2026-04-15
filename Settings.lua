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
      drinkingMessageBreak = {
        order = 5, type = "description", name = "", width = "full",
      },
      drinkingMessage = {
        order = 6, type = "input", width = "full",
        name = "Start Message",
        get  = function() return db.Drinking.message end,
        set  = function(_, v) db.Drinking.message = v end,
      },
      drinkingCompleteMessage = {
        order = 7, type = "input", width = "full",
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
      embedWindowBreak = {
        order = 14, type = "description", name = "", width = "full",
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
        name = "Window #1  (left / single)",
        min = 1, max = 5, step = 1,
        get  = function() return db.Embed.window1 or 1 end,
        set  = function(_, v) db.Embed.window1 = v end,
      },
      embedWindow2 = {
        order = 17, type = "range",
        name = "Window #2  (right)",
        min = 1, max = 5, step = 1,
        get  = function() return db.Embed.window2 or 2 end,
        set  = function(_, v) db.Embed.window2 = v end,
      },

      -- ── Healer Mana ───────────────────────────────────────
      healerManaHeader = {
        order = 30, type = "header", name = "Healer Mana Display",
      },
      healerManaEnabled = {
        order = 31, type = "toggle",
        name = "|cff00ff00Enable|r",
        desc = "Show a movable overlay with each healer's name and mana percentage.\nLowest mana at the top. Drag the frame to reposition.",
        get  = function() return db.HealerMana.enabled end,
        set  = function(_, v)
          db.HealerMana.enabled = v
          TokukoP.modules.HealerMana.RefreshDisplay()
        end,
      },
      healerManaDisplayMode = {
        order = 33, type = "select",
        name  = "Display",
        desc  = "What to show in the mana column.\nPercent: 93%\nAbsolute: 44.5k\nBoth: 93% 44.5k",
        values = { percent = "Percent (%)", value = "Absolute (k)", both = "Both" },
        get  = function() return db.HealerMana.displayMode or "percent" end,
        set  = function(_, v)
          db.HealerMana.displayMode = v
          TokukoP.modules.HealerMana.RefreshDisplay()
        end,
      },
      healerManaFont = {
        order = 34, type = "select",
        name  = "Font",
        values  = TokukoP.modules.HealerMana.FONT_VALUES,
        sorting = TokukoP.modules.HealerMana.FONT_SORTING,
        get  = function() return db.HealerMana.font end,
        set  = function(_, v)
          db.HealerMana.font = v
          TokukoP.modules.HealerMana.RefreshFont()
        end,
      },
      healerManaFontSize = {
        order = 35, type = "range",
        name  = "Font Size",
        min = 8, max = 24, step = 1,
        get  = function() return db.HealerMana.fontSize end,
        set  = function(_, v)
          db.HealerMana.fontSize = v
          TokukoP.modules.HealerMana.RefreshFont()
        end,
      },
      healerManaUseClassColor = {
        order = 36, type = "toggle",
        name = "Class Color",
        desc = "Color each healer's name by their class color.",
        get  = function() return db.HealerMana.useClassColor end,
        set  = function(_, v)
          db.HealerMana.useClassColor = v
          TokukoP.modules.HealerMana.RefreshDisplay()
        end,
      },
      healerManaColor = {
        order = 37, type = "color",
        name  = "Text Color",
        desc  = "Uniform text color (used when Class Color is off).",
        hasAlpha = false,
        disabled = function() return db.HealerMana.useClassColor end,
        get  = function()
          local c = db.HealerMana.color
          return c.r, c.g, c.b
        end,
        set  = function(_, r, g, b)
          db.HealerMana.color = { r = r, g = g, b = b }
          TokukoP.modules.HealerMana.RefreshDisplay()
        end,
      },
      healerManaTextAlpha = {
        order = 38, type = "range",
        name  = "Text Opacity",
        min = 0, max = 1, step = 0.05, isPercent = true,
        get  = function() return db.HealerMana.textAlpha end,
        set  = function(_, v)
          db.HealerMana.textAlpha = v
          TokukoP.modules.HealerMana.RefreshDisplay()
        end,
      },
      healerManaBgAlpha = {
        order = 39, type = "range",
        name  = "Background Opacity",
        min = 0, max = 1, step = 0.05, isPercent = true,
        get  = function() return db.HealerMana.bgAlpha end,
        set  = function(_, v)
          db.HealerMana.bgAlpha = v
          TokukoP.modules.HealerMana.RefreshBgAlpha()
        end,
      },
      healerManaLocked = {
        order = 40, type = "toggle",
        name = "Lock Position",
        desc = "Prevent the frame from being dragged or resized.\nUnlocking will reset the position if the frame is off-screen.",
        get  = function() return db.HealerMana.locked end,
        set  = function(_, v) TokukoP.modules.HealerMana.SetLocked(v) end,
      },
      healerManaGrowUp = {
        order = 41, type = "toggle",
        name = "Grow Upward",
        desc = "Frame expands upward as healers are added. The bottom edge stays fixed.\nDisabled: expands downward, top edge stays fixed.",
        get  = function() return db.HealerMana.growUp end,
        set  = function(_, v)
          db.HealerMana.growUp = v
          TokukoP.modules.HealerMana.RefreshGrowDirection()
        end,
      },

      -- ── Combat Res ────────────────────────────────────────
      combatResHeader = {
        order = 42, type = "header", name = "Combat Res & Reincarnation",
      },
      combatResEnabled = {
        order = 43, type = "toggle",
        name = "|cff00ff00Enable|r",
        desc = "Show two icons: Druid Rebirth (battle res charges + regen timer) and Shaman Reincarnation (personal cooldown).\nDrag the frame to reposition.",
        get  = function() return db.CombatRes.enabled end,
        set  = function(_, v)
          db.CombatRes.enabled = v
          TokukoP.modules.CombatRes.RefreshDisplay()
        end,
      },
      combatResLocked = {
        order = 44, type = "toggle",
        name = "Lock Position",
        get  = function() return db.CombatRes.locked end,
        set  = function(_, v) TokukoP.modules.CombatRes.SetLocked(v) end,
      },
      combatResFont = {
        order = 45, type = "select",
        name  = "Font",
        values  = TokukoP.modules.CombatRes.FONT_VALUES,
        sorting = TokukoP.modules.CombatRes.FONT_SORTING,
        get  = function() return db.CombatRes.font end,
        set  = function(_, v)
          db.CombatRes.font = v
          TokukoP.modules.CombatRes.RefreshFonts()
        end,
      },
      combatResTimerFontSize = {
        order = 46, type = "range",
        name  = "Timer Font Size",
        desc  = "Size of the MM:SS cooldown timers shown centered on each icon.",
        min = 8, max = 24, step = 1,
        get  = function() return db.CombatRes.timerFontSize end,
        set  = function(_, v)
          db.CombatRes.timerFontSize = v
          TokukoP.modules.CombatRes.RefreshFonts()
        end,
      },
      combatResCountFontSize = {
        order = 47, type = "range",
        name  = "Charge Badge Font Size",
        desc  = "Size of the battle res charge count badge (bottom-right of Rebirth icon).",
        min = 8, max = 24, step = 1,
        get  = function() return db.CombatRes.countFontSize end,
        set  = function(_, v)
          db.CombatRes.countFontSize = v
          TokukoP.modules.CombatRes.RefreshFonts()
        end,
      },
      combatResElvuiIcons = {
        order = 48, type = "toggle",
        name  = "ElvUI Icon Style",
        desc  = "Apply ElvUI's icon crop and backdrop border to the Rebirth/Reincarnation icons.\nGives a cleaner look matching the rest of ElvUI's UI.",
        get   = function() return db.CombatRes.elvuiIcons end,
        set   = function(_, v)
          db.CombatRes.elvuiIcons = v
          TokukoP.modules.CombatRes.RebuildAndRefresh()
        end,
      },

      -- ── Pet Reminder ──────────────────────────────────────
      petReminderHeader = {
        order = 60, type = "header", name = "Pet Reminder (Hunter / Warlock / Unholy DK)",
      },
      petReminderEnabled = {
        order = 61, type = "toggle",
        name  = "|cff00ff00Enable|r",
        desc  = "Show a flashing on-screen warning when you have no active pet.\nHunter: all specs (Lone Wolf removed in 11.1).\nWarlock: all specs.\nDeath Knight: Unholy only (ghoul via Raise Dead). Auto-hides when swapping to Blood or Frost.",
        get   = function() return db.PetReminder.enabled end,
        set   = function(_, v)
          db.PetReminder.enabled = v
          TokukoP.modules.PetReminder.RefreshDisplay()
        end,
      },
      petReminderMessage = {
        order = 62, type = "input", width = "full",
        name  = "Warning Message",
        desc  = "Text displayed when your pet is missing or dead (out of combat).",
        get   = function() return db.PetReminder.message end,
        set   = function(_, v)
          db.PetReminder.message = v
          TokukoP.modules.PetReminder.RefreshLabel()
        end,
      },
      petReminderCombatMessageEnabled = {
        order = 63, type = "toggle",
        name  = "Different Text In Combat",
        desc  = "Show a separate message while in combat (e.g. more urgent).",
        get   = function() return db.PetReminder.combatMessageEnabled end,
        set   = function(_, v)
          db.PetReminder.combatMessageEnabled = v
          TokukoP.modules.PetReminder.RefreshLabel()
        end,
      },
      petReminderCombatMessage = {
        order = 64, type = "input", width = "full",
        name  = "Combat Message",
        desc  = "Text shown while in combat. Leave blank to use the same message as out of combat.",
        disabled = function() return not db.PetReminder.combatMessageEnabled end,
        get   = function() return db.PetReminder.combatMessage end,
        set   = function(_, v)
          db.PetReminder.combatMessage = v
          TokukoP.modules.PetReminder.RefreshLabel()
        end,
      },
      petReminderFont = {
        order = 65, type = "select",
        name  = "Font",
        values  = TokukoP.modules.PetReminder.FONT_VALUES,
        sorting = TokukoP.modules.PetReminder.FONT_SORTING,
        get  = function() return db.PetReminder.font end,
        set  = function(_, v)
          db.PetReminder.font = v
          TokukoP.modules.PetReminder.RefreshLabel()
        end,
      },
      petReminderFontSize = {
        order = 66, type = "range",
        name  = "Font Size",
        min = 12, max = 64, step = 1,
        get  = function() return db.PetReminder.fontSize end,
        set  = function(_, v)
          db.PetReminder.fontSize = v
          TokukoP.modules.PetReminder.RefreshLabel()
        end,
      },
      petReminderEffect = {
        order = 67, type = "select",
        name  = "Effect",
        desc  = "Pulse: alpha fade in/out.\nShake: rapid position jitter.\nBounce: smooth up/down float.\nScale Pulse: text grows and shrinks.\nColor Flash: alternates between your colour and bright yellow.",
        values  = TokukoP.modules.PetReminder.EFFECT_VALUES,
        sorting = TokukoP.modules.PetReminder.EFFECT_SORTING,
        get  = function() return db.PetReminder.effect end,
        set  = function(_, v) db.PetReminder.effect = v end,
      },
      petReminderFlashRate = {
        order = 68, type = "range",
        name  = "Effect Speed",
        desc  = "Speed of the selected effect. Higher = faster.",
        min = 0.5, max = 5.0, step = 0.5,
        get  = function() return db.PetReminder.flashRate end,
        set  = function(_, v) db.PetReminder.flashRate = v end,
      },
      petReminderColor = {
        order = 69, type = "color",
        name  = "Color",
        desc  = "Text color. Also used as the primary color for Color Flash.",
        hasAlpha = false,
        get  = function()
          local c = db.PetReminder.color
          return c.r, c.g, c.b
        end,
        set  = function(_, r, g, b)
          db.PetReminder.color = { r = r, g = g, b = b }
          TokukoP.modules.PetReminder.RefreshLabel()
        end,
      },
      petReminderSoundEnabled = {
        order = 70, type = "toggle",
        name  = "Play Sound on Pet Death",
        desc  = "Plays a sound when your pet dies in combat.",
        get   = function() return db.PetReminder.soundEnabled end,
        set   = function(_, v) db.PetReminder.soundEnabled = v end,
      },
      petReminderSound = {
        order = 71, type = "select",
        name  = "Sound",
        values  = TokukoP.modules.PetReminder.SOUND_VALUES,
        sorting = TokukoP.modules.PetReminder.SOUND_SORTING,
        disabled = function() return not db.PetReminder.soundEnabled end,
        get  = function() return db.PetReminder.sound end,
        set  = function(_, v)
          db.PetReminder.sound = v
          TokukoP.modules.PetReminder.PreviewSound()
        end,
      },
      petReminderLocked = {
        order = 72, type = "toggle",
        name  = "Lock Position",
        desc  = "Prevent the warning frame from being dragged.",
        get   = function() return db.PetReminder.locked end,
        set   = function(_, v) TokukoP.modules.PetReminder.SetLocked(v) end,
      },

      -- ── Tooltip ───────────────────────────────────────────
      tooltipHeader = {
        order = 50, type = "header", name = "Tooltip",
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
-- Settings Preview
-- ===============================

local settingsPreviewActive = false

function TokukoP.EnterSettingsPreview()
  if settingsPreviewActive then return end
  settingsPreviewActive = true
  for _, mod in pairs(TokukoP.modules) do
    if mod.EnterPreview then mod.EnterPreview() end
  end
end

function TokukoP.ExitSettingsPreview()
  if not settingsPreviewActive then return end
  settingsPreviewActive = false
  for _, mod in pairs(TokukoP.modules) do
    if mod.ExitPreview then mod.ExitPreview() end
  end
end

-- ===============================
-- Public API
-- ===============================

function TokukoP.OpenSettings()
  local E = GetE()
  if E then
    if not E.Options then
      print("|cffffcc00TokukoP:|r ElvUI options not loaded yet. Try again in a moment.")
      return
    end
    E:ToggleOptions()
    -- Preview is managed by the hooksecurefunc in CreateSettingsPanel
    return
  end
  -- Fallback: standalone window
  TokukoP.EnterSettingsPreview()
  if settingsFrame then settingsFrame:Hide(); settingsFrame = nil end
  settingsFrame = BuildFallbackWindow()
  settingsFrame:HookScript("OnHide", TokukoP.ExitSettingsPreview)
  settingsFrame:Show()
end

local function HookACDFrame()
  local ACD = LibStub and LibStub("AceConfigDialog-3.0", true)
  if not (ACD and ACD.OpenFrames) then return end
  -- Try "ElvUI" key first, then any visible open frame
  local frameObj = ACD.OpenFrames["ElvUI"]
  if not frameObj then
    for _, obj in pairs(ACD.OpenFrames) do
      if obj.frame and obj.frame:IsShown() then frameObj = obj; break end
    end
  end
  if not (frameObj and frameObj.frame) then return end
  local f = frameObj.frame
  if not f._tpPreviewHooked then
    f._tpPreviewHooked = true
    f:HookScript("OnShow", TokukoP.EnterSettingsPreview)
    f:HookScript("OnHide", TokukoP.ExitSettingsPreview)
  end
  -- Frame is already visible — enter preview now (OnShow already fired)
  if f:IsShown() then
    TokukoP.EnterSettingsPreview()
  else
    TokukoP.ExitSettingsPreview()
  end
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
  -- Hook E:ToggleOptions so preview activates regardless of how /ec is opened
  if E.ToggleOptions then
    hooksecurefunc(E, "ToggleOptions", function()
      C_Timer.After(0.05, HookACDFrame)
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
