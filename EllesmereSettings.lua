-- EllesmereSettings.lua
-- Settings pages inside the EllesmereUI options panel, via EUI's public
-- Plugin API (EllesmereUI/PLUGINS_API.md). We get our own sidebar section
-- with one row per active module, built with EUI's own widget factory so the
-- pages look native and are indexed by EUI's global search.
--
-- Rules from the API guide that shape this file:
--   * buildPage may run during the search "pre-build" pass with a stub widget
--     factory -- no side effects (preview, timers) while IsSearchPrebuild().
--   * EllesmereUI.Widgets only exists inside buildPage (options load on demand).
--   * Only public API here: RegisterPlugin / OpenPlugin / IsPluginRegistered /
--     GetPluginModuleKey / GetActiveModule / IsShown / RefreshPage.

local ADDON_NAME = ...
local TokukoP = TokukoP

local PLUGIN_ID = "TokukoPreferences"   -- API: use the addon folder name
local PAGE      = "Settings"            -- every module is a single page

-- ===============================
-- Row helpers
-- ===============================
-- Each returns a DualRow slot config. Rows are paired two per line below.

-- Long multi-line help: EUI's widget tooltip defaults to 250px centred.
local WIDE_TIP = { justify = "LEFT", width = 340 }

local function Toggle(text, tooltip, get, set, tooltipOpts)
  return { type = "toggle", text = text, tooltip = tooltip, tooltipOpts = tooltipOpts,
           getValue = get, setValue = set }
end

local function Slider(text, tooltip, min, max, step, get, set)
  return { type = "slider", text = text, tooltip = tooltip, min = min, max = max, step = step,
           getValue = get, setValue = set }
end

-- 0-1 DB value shown as a 0-100 percentage slider.
local function PercentSlider(text, tooltip, get, set, disabled)
  local s = Slider(text, tooltip, 0, 100, 5,
    function() return math.floor((get() or 0) * 100 + 0.5) end,
    function(v) set(v / 100) end)
  s.disabled = disabled
  return s
end

local function Dropdown(text, tooltip, values, order, get, set)
  return { type = "dropdown", text = text, tooltip = tooltip, values = values, order = order,
           getValue = get, setValue = set }
end

-- DB colour tables are { r, g, b }.
local function Color(text, tooltip, getTbl, onSet, disabled)
  return { type = "colorpicker", text = text, tooltip = tooltip, disabled = disabled,
           getValue = function() local c = getTbl(); return c.r, c.g, c.b end,
           setValue = function(r, g, b)
             local c = getTbl()
             c.r, c.g, c.b = r, g, b
             if onSet then onSet() end
           end }
end

-- Free text: full-width row (pass as a lone slot) with a wide box.
local function Input(text, tooltip, get, set)
  return { type = "input", text = text, tooltip = tooltip, inputStyle = "popup", inputWidth = 320,
           getValue = get, setValue = set }
end

-- Lays out { header = "...", rows = { slot, slot, ... } } sections. Slots are
-- paired left/right; an Input always gets a row of its own.
local function BuildSections(parent, yOffset, sections)
  local W = EllesmereUI.Widgets
  local y = yOffset
  local _, h
  for _, sec in ipairs(sections) do
    _, h = W:SectionHeader(parent, sec.header, y); y = y - h
    local pending
    local function flush()
      if pending then
        _, h = W:DualRow(parent, y, pending, nil); y = y - h
        pending = nil
      end
    end
    for _, slot in ipairs(sec.rows) do
      if slot.type == "input" then
        flush()
        _, h = W:DualRow(parent, y, slot, nil); y = y - h
      elseif pending then
        _, h = W:DualRow(parent, y, pending, slot); y = y - h
        pending = nil
      else
        pending = slot
      end
    end
    flush()
  end
  return math.abs(y)
end

-- Some rows' disabled state depends on another row (e.g. Text Colour vs Use
-- Class Colour); RefreshPage re-runs every widget's refresh.
local function Refresh()
  if EllesmereUI.RefreshPage then EllesmereUI:RefreshPage() end
end

-- ===============================
-- Settings preview
-- ===============================
-- Same preview the ElvUI panel shows (dummy HealerMana / CombatRes frames so
-- they can be positioned). Entered when any of our pages is shown; a light
-- ticker exits it once the panel closes or moves to a non-Tokuko module,
-- using only public panel state -- no hooks into EUI.

local previewTicker

local function OnOurModule()
  if not (EllesmereUI:IsShown() and EllesmereUI.GetActiveModule) then return false end
  local active = EllesmereUI:GetActiveModule()
  return type(active) == "string" and active:find("^plugin:" .. PLUGIN_ID .. ":") ~= nil
end

local function StopPreview()
  if previewTicker then previewTicker:Cancel(); previewTicker = nil end
  TokukoP.ExitSettingsPreview()
end

local function StartPreview()
  if EllesmereUI.IsSearchPrebuild and EllesmereUI.IsSearchPrebuild() then return end
  TokukoP.EnterSettingsPreview()
  if previewTicker then return end
  previewTicker = C_Timer.NewTicker(0.5, function()
    if not OnOurModule() then StopPreview() end
  end)
end

-- ===============================
-- Per-module pages
-- ===============================

local function DrinkingPage()
  local db = TokukoPDB.Drinking
  return {
    { header = "ANNOUNCEMENTS", rows = {
      Toggle("Enable", "Announce in group chat when you start eating or drinking.",
        function() return db.enabled end, function(v) db.enabled = v end),
      Toggle("Only in Group / Instance", nil,
        function() return db.onlyInGroup end, function(v) db.onlyInGroup = v end),
      Toggle("Announce When Done", nil,
        function() return db.announceComplete end, function(v) db.announceComplete = v end),
      Input("Start Message", nil,
        function() return db.message end, function(v) db.message = v end),
      Input("Complete Message", nil,
        function() return db.completeMessage end, function(v) db.completeMessage = v end),
    } },
  }
end

local function HealerManaPage()
  local db, HM = TokukoPDB.HealerMana, TokukoP.modules.HealerMana
  return {
    { header = "DISPLAY", rows = {
      Toggle("Enable", nil,
        function() return db.enabled end, function(v) db.enabled = v; HM.RefreshDisplay() end),
      Dropdown("Mana Display", "What to show in the mana column.\nPercent: 93%\nAbsolute: 44.5k\nBoth: 93% 44.5k",
        { percent = "Percent (%)", value = "Absolute (k)", both = "Both" }, { "percent", "value", "both" },
        function() return db.displayMode or "percent" end,
        function(v) db.displayMode = v; HM.RefreshDisplay() end),
      Toggle("Locked", "Unlock to drag the frame.",
        function() return db.locked end, function(v) HM.SetLocked(v) end),
      Toggle("Grow Upwards", nil,
        function() return db.growUp end, function(v) db.growUp = v; HM.RefreshGrowDirection() end),
    } },
    { header = "TEXT", rows = {
      Dropdown("Font", nil, HM.FONT_VALUES, HM.FONT_SORTING,
        function() return db.font end, function(v) db.font = v; HM.RefreshFont() end),
      Slider("Font Size", nil, 8, 32, 1,
        function() return db.fontSize end, function(v) db.fontSize = v; HM.RefreshFont() end),
      Toggle("Use Class Colour", nil,
        function() return db.useClassColor end,
        function(v) db.useClassColor = v; HM.RefreshDisplay(); Refresh() end),
      Color("Text Colour", nil, function() return db.color end, HM.RefreshDisplay,
        function() return db.useClassColor end),
      PercentSlider("Text Opacity", nil,
        function() return db.textAlpha end, function(v) db.textAlpha = v; HM.RefreshDisplay() end),
      PercentSlider("Background Opacity", nil,
        function() return db.bgAlpha end, function(v) db.bgAlpha = v; HM.RefreshBgAlpha() end),
    } },
  }
end

local function CombatResPage()
  local db, CR = TokukoPDB.CombatRes, TokukoP.modules.CombatRes
  local rows = {
    Toggle("Enable", nil,
      function() return db.enabled end, function(v) db.enabled = v; CR.RefreshDisplay() end),
    Toggle("Locked", "Unlock to drag the icons.",
      function() return db.locked end, function(v) CR.SetLocked(v) end),
    Toggle("Content Only", "Only show in dungeons and raids.",
      function() return db.contentOnly end, function(v) db.contentOnly = v; CR.RefreshDisplay() end),
    Toggle("Grow Left", nil,
      function() return db.growLeft end, function(v) db.growLeft = v; CR.RebuildAndRefresh() end),
  }
  return {
    { header = "DISPLAY", rows = rows },
    { header = "TEXT", rows = {
      Dropdown("Font", nil, CR.FONT_VALUES, CR.FONT_SORTING,
        function() return db.font end, function(v) db.font = v; CR.RefreshFonts() end),
      Slider("Timer Font Size", nil, 8, 32, 1,
        function() return db.timerFontSize end, function(v) db.timerFontSize = v; CR.RefreshFonts() end),
      Slider("Count Font Size", nil, 8, 32, 1,
        function() return db.countFontSize end, function(v) db.countFontSize = v; CR.RefreshFonts() end),
    } },
  }
end

local function SoulstonePage()
  local db = TokukoPDB.SoulstoneReminder
  return {
    { header = "PULL COUNTDOWN CHECK", rows = {
      Toggle("Enable", "Whisper the player below when a pull countdown starts and nobody in the group has a Soulstone.\n\n/tpss runs a dry check without whispering.",
        function() return db.enabled end, function(v) db.enabled = v end),
      Toggle("Raid Groups Only", "Ignore countdowns in 5-man parties.",
        function() return db.onlyInRaid end, function(v) db.onlyInRaid = v end),
      Input("Player to Whisper", "Character name (realm optional). Only whispered if they are in the group.",
        function() return db.targetName end, function(v) db.targetName = v end),
      Input("Whisper Message", nil,
        function() return db.message end, function(v) db.message = v end),
    } },
  }
end

local function EditBoxPage()
  local db, EB = TokukoPDB.EditBox, TokukoP.modules.EditBox
  local function notCover() return not db.enabled or db.mode ~= "cover" end
  return {
    { header = "CHAT EDIT BOX", rows = {
      Toggle("Edit Box Over Data Bars", TokukoP.EditBoxHelpText(),
        function() return db.enabled end,
        function(v) EB.SetEnabled(v); Refresh() end, WIDE_TIP),
      Dropdown("Mode", nil, EB.MODE_VALUES, EB.MODE_SORTING,
        function() return db.mode end, function(v) EB.SetMode(v); Refresh() end),
      Color("Background Colour", "Cover mode only.", function() return db.bgColor end,
        EB.RefreshCover, notCover),
      PercentSlider("Background Opacity", "Cover mode only.",
        function() return db.bgAlpha end, function(v) db.bgAlpha = v; EB.RefreshCover() end, notCover),
    } },
  }
end

local function Button(text, buttonText, tooltip, onClick)
  return { type = "button", text = text, buttonText = buttonText, tooltip = tooltip, onClick = onClick }
end

local function ChatWindowPage()
  local db, CW = TokukoPDB.ChatWindow, TokukoP.modules.ChatWindow
  local screenW = math.floor(UIParent:GetWidth())
  local screenH = math.floor(UIParent:GetHeight())
  local function apply() CW.Apply() end
  -- Buttons rewrite the values behind the sliders; RefreshPage redraws them.
  local function then_refresh(fn) return function() fn(); C_Timer.After(0.1, Refresh) end end
  return {
    { header = "WINDOW", rows = {
      -- Tooltip as a function: the status line is re-evaluated on every hover.
      Toggle("Enable", TokukoP.ChatWindowHelpText,
        function() return db.enabled end, function(v) db.enabled = v; apply() end, WIDE_TIP),
      Input("Chat Window Name", "Tab name of the undocked chat window to size and place.",
        function() return db.windowName end, function(v) db.windowName = v; apply() end),
    } },
    { header = "SIZE & POSITION", rows = {
      Slider("Width", nil, 100, screenW, 1,
        function() return db.width end, function(v) db.width = v; apply() end),
      Slider("Height", nil, 50, screenH, 1,
        function() return db.height end, function(v) db.height = v; apply() end),
      Slider("X (from right edge)", nil, 0, screenW, 1,
        function() return db.x end, function(v) db.x = v; apply() end),
      Slider("Y (from bottom edge)", nil, 0, screenH, 1,
        function() return db.y end, function(v) db.y = v; apply() end),
    } },
    { header = "SHORTCUTS", rows = {
      Button("Main Chat Size", "Match", "Copy the main chat window's width and height.",
        then_refresh(CW.MatchMainSize)),
      Button("Mirror Main Chat", "Mirror", "Same height from the bottom as the main chat, and the same distance from the right edge as the main chat has from the left.",
        then_refresh(CW.MirrorMain)),
      Button("Current Position", "Use Current", "Read the window's current position and size, after dragging or resizing it by hand.",
        then_refresh(CW.UseCurrent)),
    } },
  }
end

local function TooltipPage()
  local db = TokukoPDB.Tooltip
  return {
    { header = "COMBAT ANCHOR", rows = {
      Toggle("Cursor Anchor Out of Combat", TokukoP.TooltipHelpText(),
        function() return db.enabled end,
        function(v) db.enabled = v; if v then TokukoP.modules.Tooltip.ApplyNow() end end,
        WIDE_TIP),
    } },
  }
end

-- Sidebar order. `module` = key in TokukoP.activeModules; inactive ones are
-- skipped (their TokukoPDB sub-table does not exist).
local PAGES = {
  { module = "HealerMana",        title = "Healer Mana",        build = HealerManaPage,
    description = "Movable list of group healers sorted by mana, lowest first." },
  { module = "CombatRes",         title = "Combat Res",         build = CombatResPage,
    description = "Battle-res charges and Shaman Reincarnation cooldown." },
  { module = "SoulstoneReminder", title = "Soulstone Reminder", build = SoulstonePage,
    description = "Whisper a player on pull countdown when nobody has a Soulstone." },
  { module = "Drinking",          title = "Drinking",           build = DrinkingPage,
    description = "Group chat announcements when you eat or drink." },
  { module = "ChatWindow",        title = "Second Chat Window", build = ChatWindowPage,
    description = "Exact size and position for a free-floating chat window (Details host)." },
  { module = "EditBox",           title = "Chat Edit Box",      build = EditBoxPage,
    description = "Let the chat edit box sit on top of a data bar." },
  { module = "Tooltip",           title = "Tooltip",            build = TooltipPage,
    description = "Tooltip on the cursor out of combat, fixed position in combat." },
}

-- ===============================
-- Registration
-- ===============================

function TokukoP.RegisterEllesmerePlugin()
  if not (EllesmereUI and EllesmereUI.RegisterPlugin) then return false end
  if EllesmereUI.IsPluginRegistered and EllesmereUI.IsPluginRegistered(PLUGIN_ID) then return true end

  local active = TokukoP.activeModules or {}
  local modules = {}
  for _, p in ipairs(PAGES) do
    if active[p.module] then
      modules[#modules + 1] = {
        key         = p.module,
        title       = p.title,
        description = p.description,
        pages       = { PAGE },
        buildPage   = function(_, parent, yOffset)
          StartPreview()
          return BuildSections(parent, yOffset, p.build())
        end,
        onPageCacheRestore = StartPreview,
      }
    end
  end
  if #modules == 0 then return false end

  return EllesmereUI.RegisterPlugin(PLUGIN_ID, {
    label   = "Tokuko Preferences",
    modules = modules,
  }) and true or false
end

-- Opens our section; false when not registered (caller falls back).
function TokukoP.OpenEllesmereSettings()
  if not (EllesmereUI and EllesmereUI.IsPluginRegistered
          and EllesmereUI.IsPluginRegistered(PLUGIN_ID)) then
    return false
  end
  EllesmereUI.OpenPlugin(PLUGIN_ID)  -- prints EUI's own "not in combat" error
  return true
end
