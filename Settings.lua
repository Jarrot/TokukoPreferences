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
          TokukoP.modules.Embed.SetEnabled(v)
        end,
      },
      embedDual = {
        order = 12, type = "toggle",
        name = "Dual Window (left + right)",
        desc = "Embed two Details! windows side by side.",
        get  = function() return db.Embed.dualEmbed end,
        set  = function(_, v)
          db.Embed.dualEmbed = v
          TokukoP.modules.Embed.Reapply()
        end,
      },
      embedCombatOnly = {
        order = 13, type = "toggle",
        name = "Hide Out of Combat",
        desc = "Hides the meter windows when out of combat, shows them in combat. Meters stay embedded.",
        get  = function() return db.Embed.combatOnly end,
        set  = function(_, v) TokukoP.modules.Embed.SetCombatOnly(v) end,
      },
      embedWindowBreak = {
        order = 14, type = "description", name = "", width = "full",
      },
      embedSplitRatio = {
        order = 15, type = "range",
        name = "Split Ratio (left %)",
        min = 20, max = 80, step = 1,
        get  = function() return math.floor((db.Embed.splitRatio or 0.5) * 100) end,
        set  = function(_, v)
          db.Embed.splitRatio = v / 100
          TokukoP.modules.Embed.Reposition()
        end,
      },
      embedWindow1 = {
        order = 16, type = "range",
        name = "Window #1  (left / single)",
        min = 1, max = 5, step = 1,
        get  = function() return db.Embed.window1 or 1 end,
        set  = function(_, v)
          db.Embed.window1 = v
          TokukoP.modules.Embed.Reapply()
        end,
      },
      embedWindow2 = {
        order = 17, type = "range",
        name = "Window #2  (right)",
        min = 1, max = 5, step = 1,
        get  = function() return db.Embed.window2 or 2 end,
        set  = function(_, v)
          db.Embed.window2 = v
          TokukoP.modules.Embed.Reapply()
        end,
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
      combatResContentOnly = {
        order = 49, type = "toggle",
        name  = "Show in Content Only",
        desc  = "Only show during instanced content (dungeons, raids, M+, delves).\nHides automatically when in the open world or capital cities.",
        get   = function() return db.CombatRes.contentOnly end,
        set   = function(_, v)
          db.CombatRes.contentOnly = v
          TokukoP.modules.CombatRes.RefreshDisplay()
        end,
      },
      combatResGrowLeft = {
        order = 50, type = "toggle",
        name  = "Grow Left",
        desc  = "When disabled (default): Rebirth icon is on the left, Reincarnation extends to the right.\nWhen enabled: Rebirth icon is on the right, Reincarnation extends to the left.\nThe anchored icon stays fixed when switching between characters.",
        get   = function() return db.CombatRes.growLeft end,
        set   = function(_, v)
          db.CombatRes.growLeft = v
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
        desc  = "None: plain static text.\nPulse: alpha fade in/out.\nShake: rapid position jitter.\nBounce: smooth up/down float.\nScale Pulse: text grows and shrinks.\nColor Flash: alternates between your colour and bright yellow.",
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
      petReminderSound = {
        order = 70, type = "select",
        name  = "Sound on Pet Death",
        desc  = "Sound to play when your pet dies in combat.\nNone: no sound.",
        values  = TokukoP.modules.PetReminder.SOUND_VALUES,
        sorting = TokukoP.modules.PetReminder.SOUND_SORTING,
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

      -- ── Soulstone Reminder ────────────────────────────────
      soulstoneHeader = {
        order = 80, type = "header", name = "Soulstone Reminder",
      },
      soulstoneEnabled = {
        order = 81, type = "toggle",
        name = "|cff00ff00Enable|r",
        desc = "When a pull countdown starts (DBM or /countdown) and nobody in the group has a Soulstone, whisper the player below.",
        get  = function() return db.SoulstoneReminder.enabled end,
        set  = function(_, v) db.SoulstoneReminder.enabled = v end,
      },
      soulstoneOnlyRaid = {
        order = 82, type = "toggle",
        name = "Raid Groups Only",
        desc = "Ignore countdowns in 5-man parties.",
        get  = function() return db.SoulstoneReminder.onlyInRaid end,
        set  = function(_, v) db.SoulstoneReminder.onlyInRaid = v end,
      },
      soulstoneBreak = {
        order = 83, type = "description", name = "", width = "full",
      },
      soulstoneTarget = {
        order = 84, type = "input", width = "full",
        name = "Player to Whisper",
        desc = "Character name (realm optional). Only whispered if they are in the group.",
        get  = function() return db.SoulstoneReminder.targetName end,
        set  = function(_, v) db.SoulstoneReminder.targetName = v end,
      },
      soulstoneMessage = {
        order = 85, type = "input", width = "full",
        name = "Whisper Message",
        get  = function() return db.SoulstoneReminder.message end,
        set  = function(_, v) db.SoulstoneReminder.message = v end,
      },
      soulstoneTest = {
        order = 86, type = "execute",
        name = "Test Now",
        desc = "Dry run: prints to chat what the check would do right now (no whisper is sent). Same as /tpss.",
        func = function() TokukoP.modules.SoulstoneReminder.Check(true) end,
      },

      -- ── Tooltip ───────────────────────────────────────────
      tooltipHeader = {
        order = 50, type = "header", name = "Tooltip",
      },
      tooltipEnabled = {
        order = 21, type = "toggle",
        name = "|cff00ff00Enable|r",
        desc = "Tooltip follows cursor when out of combat.\nSnaps to the fixed anchor position in combat.",
        get  = function() return db.Tooltip and db.Tooltip.enabled end,
        set  = function(_, v)
          db.Tooltip.enabled = v
          if v then TokukoP.modules.Tooltip.ApplyNow() end
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
  line:SetSize(348, 1)  -- fits inside the scrolling content area
  line:SetPoint("TOPLEFT", 14, yOffset)
  return line
end

-- Slider. Plain CreateFrame("Slider") rather than a named template: the frame
-- type is stable (Details, DBM and Baganator all build sliders this way on
-- 12.x) while template names are not.
local function MakeSlider(parent, label, tooltip, minV, maxV, step, getValue, setValue, yOffset, fmt)
  fmt = fmt or "%.0f"
  local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  lbl:SetPoint("TOPLEFT", 20, yOffset)

  local sl = CreateFrame("Slider", nil, parent)
  sl:SetPoint("TOPLEFT", 24, yOffset - 18)
  sl:SetSize(230, 16)
  sl:SetOrientation("HORIZONTAL")
  sl:SetMinMaxValues(minV, maxV)
  sl:SetValueStep(step)
  sl:SetObeyStepOnDrag(true)
  sl:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")

  local track = sl:CreateTexture(nil, "BACKGROUND")
  track:SetColorTexture(0, 0, 0, 0.5)
  track:SetHeight(5)
  track:SetPoint("LEFT", 2, 0)
  track:SetPoint("RIGHT", -2, 0)

  local function Relabel(v) lbl:SetText(label .. ": |cffffffff" .. fmt:format(v) .. "|r") end

  sl:SetValue(getValue())
  Relabel(getValue())
  sl:SetScript("OnValueChanged", function(self, v)
    Relabel(v)
    setValue(v)
  end)
  if tooltip then
    sl:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(tooltip, nil, nil, nil, nil, true)
      GameTooltip:Show()
    end)
    sl:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  return sl
end

-- Dropdown built on the modern menu system (MenuUtil + rootDescription), the
-- same API EllesmereUI and DBM use on 12.x. UIDropDownMenu is legacy.
local function MakeDropdown(parent, label, tooltip, values, sorting, getValue, setValue, yOffset, onChanged)
  local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  lbl:SetPoint("TOPLEFT", 20, yOffset)
  lbl:SetText(label .. ":")

  local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  btn:SetPoint("TOPLEFT", 24, yOffset - 18)
  btn:SetSize(230, 22)
  SkinBtn(btn)

  local function CurrentText()
    local key = getValue()
    return (key ~= nil and values[key]) or "—"
  end
  btn:SetText(CurrentText())

  btn:SetScript("OnClick", function(self)
    MenuUtil.CreateContextMenu(self, function(_, rootDescription)
      -- The font lists come from LibSharedMedia and run to 100+ entries, which
      -- without this renders as a single full-screen column. Cap the height and
      -- let the menu scroll; a short list under the cap is unaffected.
      if rootDescription.SetScrollMode then rootDescription:SetScrollMode(380) end

      local order = sorting
      if not order then
        order = {}
        for k in pairs(values) do table.insert(order, k) end
        table.sort(order, function(a, b) return tostring(values[a]) < tostring(values[b]) end)
      end
      for _, key in ipairs(order) do
        rootDescription:CreateRadio(
          values[key],
          function() return getValue() == key end,
          function()
            setValue(key)
            btn:SetText(CurrentText())
            if onChanged then onChanged() end
          end)
      end
    end)
  end)

  if tooltip then
    btn:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(tooltip, nil, nil, nil, nil, true)
      GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  return btn
end

-- Colour swatch -> ColorPickerFrame:SetupColorPickerAndShow (the 10.2.5+ API;
-- the old ColorPickerFrame.func globals are gone).
local function MakeColorSwatch(parent, label, tooltip, getValue, setValue, yOffset)
  local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  lbl:SetPoint("TOPLEFT", 44, yOffset + 2)
  lbl:SetText(label)

  local btn = CreateFrame("Button", nil, parent)
  btn:SetPoint("TOPLEFT", 20, yOffset)
  btn:SetSize(18, 18)

  local border = btn:CreateTexture(nil, "BORDER")
  border:SetColorTexture(0.35, 0.35, 0.35, 1)
  border:SetAllPoints()

  local swatch = btn:CreateTexture(nil, "ARTWORK")
  swatch:SetPoint("TOPLEFT", 1, -1)
  swatch:SetPoint("BOTTOMRIGHT", -1, 1)

  local function Refresh()
    local c = getValue() or {}
    swatch:SetColorTexture(c.r or 1, c.g or 1, c.b or 1, 1)
  end
  Refresh()

  btn:SetScript("OnClick", function()
    local c = getValue() or {}
    local orig = { r = c.r or 1, g = c.g or 1, b = c.b or 1 }
    local function apply()
      local r, g, b = ColorPickerFrame:GetColorRGB()
      setValue(r, g, b)
      Refresh()
    end
    ColorPickerFrame:SetupColorPickerAndShow({
      r = orig.r, g = orig.g, b = orig.b,
      hasOpacity = false,
      swatchFunc = apply,
      cancelFunc = function()
        setValue(orig.r, orig.g, orig.b)
        Refresh()
      end,
    })
  end)

  if tooltip then
    btn:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(tooltip, nil, nil, nil, nil, true)
      GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  return btn
end

local settingsFrame = nil

local function BuildFallbackWindow()
  local f = CreateFrame("Frame", "TokukoPSettingsFrame", UIParent, "BasicFrameTemplateWithInset")
  f:SetSize(420, 560)
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

  -- Every module's options together are far taller than the window, so the
  -- rows live on a scrolling child rather than on the frame itself.
  local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 8, -30)
  scroll:SetPoint("BOTTOMRIGHT", -30, 8)

  local c = CreateFrame("Frame", nil, scroll)
  c:SetSize(376, 1)
  scroll:SetScrollChild(c)

  local active = TokukoP.activeModules or {}
  local y = -4

  MakeHeader(c, "Drinking Announcements", y); y = y - 26
  MakeCheckbox(c, "Enable Drinking Announcements", nil,
    function() return TokukoPDB.Drinking.enabled end,
    function(v) TokukoPDB.Drinking.enabled = v end, y); y = y - 28
  MakeCheckbox(c, "Only in Group / Instance", nil,
    function() return TokukoPDB.Drinking.onlyInGroup end,
    function(v) TokukoPDB.Drinking.onlyInGroup = v end, y); y = y - 28
  MakeCheckbox(c, "Announce When Done", nil,
    function() return TokukoPDB.Drinking.announceComplete end,
    function(v) TokukoPDB.Drinking.announceComplete = v end, y); y = y - 30
  MakeEditBox(c, "Start Message:", nil,
    function() return TokukoPDB.Drinking.message end,
    function(v) TokukoPDB.Drinking.message = v end, y); y = y - 52
  MakeEditBox(c, "Complete Message:", nil,
    function() return TokukoPDB.Drinking.completeMessage end,
    function(v) TokukoPDB.Drinking.completeMessage = v end, y); y = y - 44

  -- Every section below is gated on the module actually being active for this
  -- host: an inactive module never ran Initialize, so its TokukoPDB sub-table
  -- does not exist and the first getValue would error.
  if active.Embed then
    MakeDivider(c, y); y = y - 14
    MakeHeader(c, "Damage Meter Embed", y); y = y - 26
    MakeCheckbox(c, "Enable Embed", nil,
      function() return TokukoPDB.Embed.enabled end,
      function(v)
        TokukoPDB.Embed.enabled = v
        if v and not TokukoP.modules.Embed.IsEmbedded() then TokukoP.modules.Embed.Toggle()
        elseif not v and TokukoP.modules.Embed.IsEmbedded() then TokukoP.modules.Embed.Toggle() end
      end, y); y = y - 28
    MakeCheckbox(c, "Dual Window Embed", nil,
      function() return TokukoPDB.Embed.dualEmbed end,
      function(v) TokukoPDB.Embed.dualEmbed = v end, y); y = y - 28
    MakeCheckbox(c, "Hide Out of Combat", nil,
      function() return TokukoPDB.Embed.combatOnly end,
      function(v) TokukoPDB.Embed.combatOnly = v end, y); y = y - 28
  end

  if active.HealerMana then
    local HM = TokukoP.modules.HealerMana
    MakeDivider(c, y); y = y - 14
    MakeHeader(c, "Healer Mana Display", y); y = y - 26
    MakeCheckbox(c, "Enable", nil,
      function() return TokukoPDB.HealerMana.enabled end,
      function(v) TokukoPDB.HealerMana.enabled = v; HM.RefreshDisplay() end, y); y = y - 28
    MakeDropdown(c, "Display",
      "What to show in the mana column.\nPercent: 93%\nAbsolute: 44.5k\nBoth: 93% 44.5k",
      { percent = "Percent (%)", value = "Absolute (k)", both = "Both" },
      { "percent", "value", "both" },
      function() return TokukoPDB.HealerMana.displayMode or "percent" end,
      function(v) TokukoPDB.HealerMana.displayMode = v end, y,
      function() HM.RefreshDisplay() end); y = y - 44
    MakeDropdown(c, "Font", nil, HM.FONT_VALUES, HM.FONT_SORTING,
      function() return TokukoPDB.HealerMana.font end,
      function(v) TokukoPDB.HealerMana.font = v end, y, function() HM.RefreshFont() end); y = y - 44
    MakeSlider(c, "Font Size", nil, 8, 32, 1,
      function() return TokukoPDB.HealerMana.fontSize end,
      function(v) TokukoPDB.HealerMana.fontSize = v; HM.RefreshFont() end, y); y = y - 42
    MakeCheckbox(c, "Use Class Colour", nil,
      function() return TokukoPDB.HealerMana.useClassColor end,
      function(v) TokukoPDB.HealerMana.useClassColor = v; HM.RefreshDisplay() end, y); y = y - 28
    MakeColorSwatch(c, "Text Colour", nil,
      function() return TokukoPDB.HealerMana.color end,
      function(r, g, b)
        local col = TokukoPDB.HealerMana.color
        col.r, col.g, col.b = r, g, b
        HM.RefreshDisplay()
      end, y); y = y - 28
    MakeSlider(c, "Text Alpha", nil, 0, 1, 0.05,
      function() return TokukoPDB.HealerMana.textAlpha end,
      function(v) TokukoPDB.HealerMana.textAlpha = v; HM.RefreshDisplay() end, y, "%.2f"); y = y - 42
    MakeSlider(c, "Background Alpha", nil, 0, 1, 0.05,
      function() return TokukoPDB.HealerMana.bgAlpha end,
      function(v) TokukoPDB.HealerMana.bgAlpha = v; HM.RefreshBgAlpha() end, y, "%.2f"); y = y - 42
    MakeCheckbox(c, "Locked", nil,
      function() return TokukoPDB.HealerMana.locked end,
      function(v) HM.SetLocked(v) end, y); y = y - 28
    MakeCheckbox(c, "Grow Upwards", nil,
      function() return TokukoPDB.HealerMana.growUp end,
      function(v) TokukoPDB.HealerMana.growUp = v; HM.RefreshGrowDirection() end, y); y = y - 28
  end

  if active.CombatRes then
    local CR = TokukoP.modules.CombatRes
    MakeDivider(c, y); y = y - 14
    MakeHeader(c, "Combat Res & Reincarnation", y); y = y - 26
    MakeCheckbox(c, "Enable", nil,
      function() return TokukoPDB.CombatRes.enabled end,
      function(v) TokukoPDB.CombatRes.enabled = v; CR.RefreshDisplay() end, y); y = y - 28
    MakeCheckbox(c, "Locked", nil,
      function() return TokukoPDB.CombatRes.locked end,
      function(v) CR.SetLocked(v) end, y); y = y - 28
    MakeDropdown(c, "Font", nil, CR.FONT_VALUES, CR.FONT_SORTING,
      function() return TokukoPDB.CombatRes.font end,
      function(v) TokukoPDB.CombatRes.font = v end, y, function() CR.RefreshFonts() end); y = y - 44
    MakeSlider(c, "Timer Font Size", nil, 8, 32, 1,
      function() return TokukoPDB.CombatRes.timerFontSize end,
      function(v) TokukoPDB.CombatRes.timerFontSize = v; CR.RefreshFonts() end, y); y = y - 42
    MakeSlider(c, "Count Font Size", nil, 8, 32, 1,
      function() return TokukoPDB.CombatRes.countFontSize end,
      function(v) TokukoPDB.CombatRes.countFontSize = v; CR.RefreshFonts() end, y); y = y - 42
    -- ElvUI's icon skin only exists on ElvUI; the module already falls back to
    -- a plain crop elsewhere, so do not offer a dead toggle on other hosts.
    if TokukoP.host == TokukoP.HOST_ELVUI then
      MakeCheckbox(c, "ElvUI Icon Style", nil,
        function() return TokukoPDB.CombatRes.elvuiIcons end,
        function(v) TokukoPDB.CombatRes.elvuiIcons = v; CR.RebuildAndRefresh() end, y); y = y - 28
    end
    MakeCheckbox(c, "Content Only", nil,
      function() return TokukoPDB.CombatRes.contentOnly end,
      function(v) TokukoPDB.CombatRes.contentOnly = v; CR.RefreshDisplay() end, y); y = y - 28
    MakeCheckbox(c, "Grow Left", nil,
      function() return TokukoPDB.CombatRes.growLeft end,
      function(v) TokukoPDB.CombatRes.growLeft = v; CR.RebuildAndRefresh() end, y); y = y - 28
  end

  if active.PetReminder then
    local PR = TokukoP.modules.PetReminder
    MakeDivider(c, y); y = y - 14
    MakeHeader(c, "Pet Reminder", y); y = y - 26
    MakeCheckbox(c, "Enable", nil,
      function() return TokukoPDB.PetReminder.enabled end,
      function(v) TokukoPDB.PetReminder.enabled = v; PR.RefreshDisplay() end, y); y = y - 30
    MakeEditBox(c, "Message:", nil,
      function() return TokukoPDB.PetReminder.message end,
      function(v) TokukoPDB.PetReminder.message = v; PR.RefreshLabel() end, y); y = y - 52
    MakeCheckbox(c, "Separate Combat Message", nil,
      function() return TokukoPDB.PetReminder.combatMessageEnabled end,
      function(v) TokukoPDB.PetReminder.combatMessageEnabled = v; PR.RefreshLabel() end, y); y = y - 30
    MakeEditBox(c, "Combat Message:", nil,
      function() return TokukoPDB.PetReminder.combatMessage end,
      function(v) TokukoPDB.PetReminder.combatMessage = v; PR.RefreshLabel() end, y); y = y - 52
    MakeDropdown(c, "Font", nil, PR.FONT_VALUES, PR.FONT_SORTING,
      function() return TokukoPDB.PetReminder.font end,
      function(v) TokukoPDB.PetReminder.font = v end, y, function() PR.RefreshLabel() end); y = y - 44
    MakeSlider(c, "Font Size", nil, 12, 72, 1,
      function() return TokukoPDB.PetReminder.fontSize end,
      function(v) TokukoPDB.PetReminder.fontSize = v; PR.RefreshLabel() end, y); y = y - 42
    MakeDropdown(c, "Effect", nil, PR.EFFECT_VALUES, PR.EFFECT_SORTING,
      function() return TokukoPDB.PetReminder.effect end,
      function(v) TokukoPDB.PetReminder.effect = v end, y); y = y - 44
    MakeSlider(c, "Flash Rate", nil, 0.5, 5, 0.1,
      function() return TokukoPDB.PetReminder.flashRate end,
      function(v) TokukoPDB.PetReminder.flashRate = v end, y, "%.1f"); y = y - 42
    MakeColorSwatch(c, "Text Colour", nil,
      function() return TokukoPDB.PetReminder.color end,
      function(r, g, b)
        local col = TokukoPDB.PetReminder.color
        col.r, col.g, col.b = r, g, b
        PR.RefreshLabel()
      end, y); y = y - 28
    MakeDropdown(c, "Sound on Pet Death", "None: no sound.", PR.SOUND_VALUES, PR.SOUND_SORTING,
      function() return TokukoPDB.PetReminder.sound end,
      function(v) TokukoPDB.PetReminder.sound = v end, y, function() PR.PreviewSound() end); y = y - 44
    MakeCheckbox(c, "Locked", nil,
      function() return TokukoPDB.PetReminder.locked end,
      function(v) PR.SetLocked(v) end, y); y = y - 28
  end

  if active.SoulstoneReminder then
    MakeDivider(c, y); y = y - 14
    MakeHeader(c, "Soulstone Reminder", y); y = y - 26
    MakeCheckbox(c, "Enable", "Whisper the player below when a pull countdown starts and nobody in the group has a Soulstone.",
      function() return TokukoPDB.SoulstoneReminder.enabled end,
      function(v) TokukoPDB.SoulstoneReminder.enabled = v end, y); y = y - 28
    MakeCheckbox(c, "Raid Groups Only", "Ignore countdowns in 5-man parties.",
      function() return TokukoPDB.SoulstoneReminder.onlyInRaid end,
      function(v) TokukoPDB.SoulstoneReminder.onlyInRaid = v end, y); y = y - 30
    MakeEditBox(c, "Player to Whisper:", "Character name (realm optional). Only whispered if they are in the group.",
      function() return TokukoPDB.SoulstoneReminder.targetName end,
      function(v) TokukoPDB.SoulstoneReminder.targetName = v end, y); y = y - 52
    MakeEditBox(c, "Whisper Message:", nil,
      function() return TokukoPDB.SoulstoneReminder.message end,
      function(v) TokukoPDB.SoulstoneReminder.message = v end, y); y = y - 44
  end

  if active.EditBox then
    MakeDivider(c, y); y = y - 14
    MakeHeader(c, "Chat Edit Box", y); y = y - 26
    MakeCheckbox(c, "Hide Data Bars Under Edit Box", "While typing in chat, fade out any EllesmereUI data bar the edit box overlaps (like ElvUI's edit box covering its datatext panel).",
      function() return TokukoPDB.EditBox.enabled end,
      function(v) TokukoP.modules.EditBox.SetEnabled(v) end, y); y = y - 28
  end

  if active.Tooltip then
    MakeDivider(c, y); y = y - 14
    MakeHeader(c, "Tooltip", y); y = y - 26
    -- Under EllesmereUI this drives EUI's own "Anchor to Cursor" flag, so
    -- spell out which EUI settings it takes over and which still apply.
    local tooltipHelp
    if TokukoP.host == TokukoP.HOST_ELLESMERE then
      tooltipHelp = "Tooltip follows the cursor out of combat and moves to its fixed position in combat.\n\n"
        .. "|cffffd100Works through EllesmereUI's tooltip settings|r (Blizz UI Enhanced > Tooltips, Menus & Popups):\n"
        .. "|cffff6060Anchor to Cursor|r - controlled by this option; changes there get overwritten at the next combat change.\n"
        .. "|cff60ff60Cursor position / offsets|r (arrows icon) - used out of combat.\n"
        .. "|cff60ff60Fixed position|r (drag the Tooltip box in Unlock Mode) - used in combat.\n"
        .. "|cffff6060Reskin Tooltip|r - must be ON, otherwise this does nothing.\n"
        .. "|cffaaaaaaShow Tooltips|r - set to Out of Combat or Never and there is no in-combat tooltip to move."
    else
      tooltipHelp = "Tooltip follows the cursor out of combat and moves to its fixed anchor position in combat."
    end
    MakeCheckbox(c, "Cursor Anchor Out of Combat", tooltipHelp,
      function() return TokukoPDB.Tooltip and TokukoPDB.Tooltip.enabled end,
      function(v)
        TokukoPDB.Tooltip.enabled = v
        if v then TokukoP.modules.Tooltip.ApplyNow() end
      end, y); y = y - 28
  end

  -- y is negative and grows downward; the scroll child must be that tall for
  -- the scrollbar to have anything to travel over.
  c:SetHeight(math.max(1, -y + 10))

  return f
end

-- ===============================
-- Settings Preview
-- ===============================

local settingsPreviewActive = false

function TokukoP.ToggleSettingsPreview()
  settingsPreviewActive = not settingsPreviewActive
  for _, mod in pairs(TokukoP.modules) do
    if settingsPreviewActive then
      if mod.EnterPreview then mod.EnterPreview() end
    else
      if mod.ExitPreview then mod.ExitPreview() end
    end
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
    return
  end
  -- Fallback: standalone window
  if settingsFrame then settingsFrame:Hide(); settingsFrame = nil end
  settingsFrame = BuildFallbackWindow()
  settingsFrame:HookScript("OnHide", TokukoP.ExitSettingsPreview)
  settingsFrame:Show()
  if not settingsPreviewActive then TokukoP.ToggleSettingsPreview() end
end

function TokukoP.CreateSettingsPanel()
  local E = GetE()
  if not E then return end
  -- Register with LibElvUIPlugin so our section appears in /ec
  local EP = LibStub and LibStub("LibElvUIPlugin-1.0", true)
  if EP then
    EP:RegisterPlugin(ADDON_NAME, InsertElvUIOptions)
  else
    C_Timer.After(1, function()
      if E.Options then InsertElvUIOptions() end
    end)
  end

  -- Exit preview whenever /ec closes. Every close path (ESC, X button,
  -- /ec command, game menu) eventually hides the ACD frame, which fires
  -- E.Config_WindowClosed via ElvUI's own OnHide hook. Hooking that
  -- function is the single reliable signal that covers all paths.
  if E.Config_WindowClosed then
    hooksecurefunc(E, "Config_WindowClosed", function()
      if settingsPreviewActive then TokukoP.ToggleSettingsPreview() end
    end)
  end

  -- Auto-enter preview when TokukoPreferences is selected in the sidebar,
  -- and exit preview when navigating to any other section.
  -- E.Config_UpdateLeftButtons fires on every sidebar navigation via
  -- hooksecurefunc(AceConfigRegistry, 'NotifyChange', ...) inside ElvUI.
  if E.Config_UpdateLeftButtons then
    hooksecurefunc(E, "Config_UpdateLeftButtons", function()
      if not E.Config_GetWindow then return end
      local frame = E:Config_GetWindow()
      if not frame or not frame.obj then return end
      local status = frame.obj.status
      local selected = status and status.groups and status.groups.selected
      if selected == "TokukoPreferences" then
        if not settingsPreviewActive then TokukoP.ToggleSettingsPreview() end
      else
        if settingsPreviewActive then TokukoP.ToggleSettingsPreview() end
      end
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
