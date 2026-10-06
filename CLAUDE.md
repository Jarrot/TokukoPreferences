# TokukoPreferences

A modular WoW addon for **Midnight 12.x** built around ElvUI. Written in Lua.

## Project Structure

```
Core.lua              — namespace (TokukoP), SavedVariables (TokukoPDB), PLAYER_LOGIN init
DrinkingModule.lua    — eating/drinking announcements to group chat
TooltipModule.lua     — ElvUI tooltip cursor anchor switching
EmbedModule.lua       — Details! embed into ElvUI right chat panel, or under EllesmereUI into the Second Chat Window
HealerManaModule.lua  — movable overlay listing group/raid healers sorted by mana (lowest first)
CombatResModule.lua   — movable icons for battle-res charges + Shaman Reincarnation cooldown
PetReminderModule.lua — flashing warning when a Hunter/Warlock/Unholy DK has no active pet
SoulstoneReminderModule.lua — whispers a configured player on pull countdown if nobody in the group has a Soulstone
EditBoxModule.lua     — EllesmereUI only: keeps the active chat edit box on top of EUI data bars (cover/fade)
ChatWindowModule.lua  — EllesmereUI only: exact size/position for an undocked chat window (Details host)
SpeedModule.lua       — LibDataBroker source "TokukoP: Speed": current max movement speed in %, 100% = run speed
Libs/                 — bundled LibStub, CallbackHandler-1.0, LibDataBroker-1.1 (EUI does not ship LDB)
Settings.lua          — ElvUI AceConfig panel (/ec → Plugins → TokukoPreferences) + standalone /tp window
EllesmereSettings.lua — EllesmereUI options-panel section via EUI's Plugin API
DebugModule.lua       — optional debug commands, commented out in TOC by default
```

## Key Globals

- `TokukoP` — addon namespace, `TokukoP.modules` holds all module references
- `TokukoPDB` — SavedVariables, sub-tables: `Drinking`, `Embed`, `Tooltip`, `HealerMana`, `CombatRes`, `PetReminder`, `SoulstoneReminder`, `EditBox`, `ChatWindow`
- `RightChatPanel` — ElvUI's right chat panel frame (confirmed global name)
- `RightChatDataPanel` — ElvUI's data bar at bottom of right panel
- `DetailsBaseFrame1/2` — Details! window frames

## TOC

```
Interface: 120000, 120001, 120005
SavedVariables: TokukoPDB
Load order: Core → DrinkingModule → TooltipModule → EmbedModule → Settings
# DebugModule.lua  ← uncomment to enable debug commands
```

## EmbedModule Architecture

### EllesmereUI path (added 2026-10-06)
- `HOSTS = { elvui, ellesmere }`. Under EUI the embed is a **one-shot FIT run only on setting changes** (Jarrot's rule, same as ChatWindowModule): Details tab settings, Fit Now, or a ChatWindow apply (`ChatWindowModule.ApplyNow` → `EmbedModule.Fit` after 0.15s). Nothing at login/loading screens/PLAYER_ALIVE, no ticker.
- Fit = `PositionFrames()` against **`TokukoPEmbedHost`** (invisible UIParent child laid NUMERICALLY over the Second Chat Window's rect via `SyncEUIHost`), then after 0.1s `inst:SaveMainWindowPosition()` + `inst:RestoreMainWindowPosition()` (`DetailsAdopt`): Details saves the fitted rect as its own position (posicao + LibWindow) and re-anchors itself from it, so nothing of ours stays attached and Details restores it every login. User locks windows in Details.
- **Size + position only:** NO SetParent, strata, chrome hiding, LockInstance, alpha, clamp, floatingframe or show/hide. `combatOnly` ignored + hidden from settings. Turning the embed off leaves the windows where they are.
- NEVER parent/anchor anything of ours to a chat frame — EllesmereUIChat documents that insecure children of chat frames taint chat structurally.
- **Fit:** Details' title bar / toolbar / status bar sit OUTSIDE its base frame (title bar anchored bottom-to-top of it). Under ElvUI they fit because the embed starts below the right panel's tab strip (`yOff = -tabH`). The EUI host is only the chat frame's text rect, so `ChromeInsets()` keeps room inside it: top = max(20 toolbar, titlebar_height if shown) when `toolbar_side == 1`; bottom += 20 if `toolbar_side == 2`, += 14 if `show_statusbar` (Details' own clamp math), plus `topAdjust`/`bottomAdjust`. Jarrot chose "whole window inside" over "title bar over the tab strip" (2026-10-06).
- Refuses when the window is missing/docked/ChatFrame1. Settings: EUI Chat row → "Details" tab.

### ElvUI path

Embeds Details! windows into `RightChatPanel`. Key geometry:
- `tabH` — chat tab strip height (~21px), detected via `ChatFrameNTab` parent check
- `barH` — `RightChatDataPanel` height (~24px)
- `embedH` — panel height - tabH - barH
- Frames anchor `TOPLEFT` at `yOff = -tabH`, `BOTTOMLEFT` pinned to `RightChatDataPanel TOPLEFT`
- Dual embed: left window `TOPLEFT`, right window `TOPRIGHT` with -1px x-offset
- `StartRepositionTimer()` — ticks every 0.25s for 8s after embed to win against Details' own position restoration

### Details! internals patched on embed
- `frame.titleBar:Hide()` — hides title bar chrome
- `frame.border:Hide()` — hides rounded corner border (extends outside frame bounds)
- `frame.floatingframe:Hide()` — hides extra chrome; called in `PositionFrames()` if the field exists
- `inst:LockInstance(true/false)` — locks/unlocks via Details' own API; properly updates the lock button and resize handles (do NOT set `frame.isLocked` directly)
- `frame.BoxBarrasAltura` — internal bar container height
- `frame._instance.db.width/height` — saved dimensions

### Chrome suppression
`TryHideChrome(frame)` hides `titleBar`, `border`, and any child named `*UpFrame*` (the toolbar button containers that appear on mouseover). Called on embed and after `ShowWindow()` (which restores chrome).

`HookChromeHide(frame)` appends an `OnEnter` hook so whenever Details re-shows its `UpFrame` toolbar on hover, it is immediately hidden again. Idempotent via `frame.__tpChromeHooked`. Wire this after every `ShowWindow()` call.

`SetMouseRecursive(frame, enabled)` — recursively enables/disables mouse on a frame and all its descendants via `GetChildren()`. Needed because `Details_GumpFrame1` (windowBackgroundDisplay) is a grandchild of DetailsBaseFrame and has `OnEnter`/`OnLeave` scripts that intercept clicks even when the frame is invisible.

### Details! frame architecture (confirmed via /tpscan)
`DetailsBaseFrame1` is the chrome container (32 direct children, all LOW strata). The actual visible content is in **separate sibling frames** that Details! positions independently:
- `inst.rowframe` = `DetailsRowFrame1` — the bar rows (bars)
- `inst.windowBackgroundDisplay` = `Details_GumpFrame1` — window background
- `inst.bgframe` = `Details_WindowFrame1` — IS a child of DetailsBaseFrame1
- `frame.floatingframe` = nil on the frame; `inst.floatingframe` = `DetailsInstance1BorderHolder` (0x0, just an anchor)

For hide/show of the embedded meters (combatOnly mode, right-click toggle): use `inst:HideWindow()` / `inst:ShowWindow()` — Details' own API that properly manages `inst.ativa` so Details won't re-show on combat events. After `ShowWindow()`, re-call `TryHideChrome()` and `PositionFrames()` since `ShowWindow()` resets geometry and chrome. `SetAlpha` is only used during unembed restoration.

### Combat handling
- `embedPending` — if embed attempted in combat, retries on `PLAYER_REGEN_ENABLED`
- `combatOnly` — hides/shows meters via `SetMetersVisible()`, does NOT unembed/re-embed
- Right-click `>` button — calls `SetMetersVisible()` to hide/show, not detach

### Post-load / resurrection rehide
`RehideEmbedded(delay)` — schedules a `C_Timer.After` to re-hide chrome and reposition after Details restores its own state. Two paths:
- `PLAYER_ENTERING_WORLD` (loading screen): 4s delay — Details needs time to fully restore after a load screen
- `PLAYER_ALIVE` (in-place res: battle res, Soulstone, Ankh): 1.5s delay — no loading screen, but Details may still restore its chrome

### Public API
- `EmbedModule.Toggle()` — embed/unembed (guarded by `enabled`; used by `/tpembed`)
- `EmbedModule.SetEnabled(v)` — enable/disable the feature live; drives embed state directly (used by the options toggle, so no `/reload` needed). Do NOT route the options toggle through `Toggle()` — setting `enabled=false` first makes `Toggle()` early-return before it can unembed.
- `EmbedModule.Reapply()` — re-embed with current window/dual settings (used when those options change)
- `EmbedModule.Reposition()` — re-run `PositionFrames()` only (used by the split-ratio slider)
- `EmbedModule.SetCombatOnly(v)` — apply "Hide Out of Combat" live
- `EmbedModule.IsEmbedded()` — returns embedded state
- `EmbedModule.PrintDebug()` — called by DebugModule for /tpdebug

## Settings (AceConfig via LibElvUIPlugin-1.0)

Registers under `E.Options.args.TokukoPreferences` — appears in `/ec` sidebar under Plugins.
Flat single-page layout with section headers. Green `|cff00ff00Enable|r` toggle per module.
Falls back to `BuildFallbackWindow()` if ElvUI not loaded (opened via `/tp`).

## Settings under EllesmereUI (EllesmereSettings.lua)

- Uses EUI's public **Plugin API** — guide at `Interface/AddOns/EllesmereUI/PLUGINS_API.md`. `EllesmereUI.RegisterPlugin("TokukoPreferences", { label, modules })` gives us our OWN sidebar section (plugins can never add rows to EUI's sections). Sidebar rows come from the `ROWS` table in EllesmereSettings.lua: each row = one EUI module with 1+ pages, each page listing Tokuko modules (inactive ones dropped, empty pages/rows too). Two rows, one page each (Jarrot, 2026-10-06): **General** = Healer Mana, **Group Tools** (Combat Res + Soulstone Reminder + Drinking merged under one header via a `parts` entry; their "Enable" rows renamed per module; a `{type="break"}` slot starts each module on a fresh row), Tooltip; **Chat** = Second Chat Window, Details Embed, Chat Edit Box. Each module = ONE `SectionHeader` with all its rows under it (its builder's sub-sections are merged — EUI has a single header style), `W:Spacer` between modules. Page entries list `modules`; inactive modules are skipped. Keep row `key`s stable (EUI remembers last page per key).
- Registered from `CreateSettingsPanel()` at PLAYER_LOGIN (needs `activeModules`). `/tp` → `EllesmereUI.OpenPlugin`.
- Pages built with `EllesmereUI.Widgets` (only exists inside `buildPage`): `W:SectionHeader(parent, text, y)`, `W:DualRow(parent, y, leftCfg, rightCfg)` with cfg `{ type = toggle|slider|dropdown|colorpicker|input, text, tooltip, getValue, setValue, disabled, min/max/step, values/order, inputStyle/inputWidth }`. Each returns `frame, height`; buildPage returns total height.
- `buildPage` also runs in EUI's search pre-build with a stub factory — no side effects while `EllesmereUI.IsSearchPrebuild()`.
- Preview: entered on any of our pages; a 0.5s ticker exits it when `EllesmereUI:IsShown()` is false or `GetActiveModule()` is no longer `plugin:TokukoPreferences:*`. No hooks into EUI.
- API guide asks plugins not to read `_`-prefixed EUI fields or hook EUI functions. Exceptions: EditBox **fade** mode (opt-in), and ChatWindow's `NudgeEUIChat` (calls EllesmereUIChat's `ECHAT.QueueTabPass` via `_ModuleNS` — no public way to tell EUI a chat frame moved; guarded/pcall'd). Tooltip no longer does — see TooltipModule notes in Known Decisions.
- Long help text: pass `tooltipOpts = { justify = "LEFT", width = 340 }` on the slot — EUI's widget tooltip defaults to 250px centred. EUI's tooltip font has no bullet glyph.
- Preview/exit iterate `activeModules`, never `modules` — a host-gated module has no db.

## ElvUI Skinning

Uses `E:GetModule("Skins")` — methods: `S:HandleButton()`, `S:HandleCheckBox()`, `S:HandleEditBox()`, `S:HandleCloseButton()`
Frame backdrop: `frame:SetTemplate("Default")`

## Slash Commands

- `/tpembed` — toggle embed on/off
- `/tp` / `/tokukop` — open settings (ElvUI `/ec`, EllesmereUI plugin section, else standalone window)
- `/tp window` — force the standalone window
- `/tpss` — Soulstone reminder dry run: prints what the countdown check would do now, sends nothing
- `/tpdebug` — state dump (DebugModule)
- `/tpscan` — find Details frame globals (DebugModule)
- `/tpgap` — measure frame-to-databar gap (DebugModule)

## Known Decisions

- Skada removed — unmaintained in 12.0
- Blizzard native meter excluded — Edit Mode controlled, SetSize ignored
- `SetMovable(false)` removed — causes taint in Details scheduled functions
- combatOnly = hide/show meters only, never embed/unembed
- Right-click > = hide/show meters, not detach
- `LE_PARTY_CATEGORY_INSTANCE` removed in 12.0 — use raw `2`
- `UnitPowerPercent` returns **0–1** in 12.x (not 0–100) — multiply by 100 before displaying
- For non-player units, `UnitPowerPercent` returns a **secret value** — arithmetic blocked. `tonumber(tostring(secret))` does NOT work (tainted string blocks tonumber too). Correct workaround: `tonumber(string.format("%.4f", raw))` — `string.format` accepts secrets and produces an untainted string
- `UNIT_DIED`'s unit arg is a **secret string** in 12.x — comparing it (`unitID ~= "pet"`) taints execution and errors. Can't `RegisterUnitEvent("UNIT_DIED", ...)` either. So don't identify the dead unit: on `UNIT_DIED` just re-check your own state (PetReminder re-runs `RefreshDisplay`, which plays the pet-lost sound on a `petWasPresent → not HasPet()` transition). Note `UNIT_PET`/`PLAYER_SPECIALIZATION_CHANGED` unit args are `"player"` and NOT secret, so those comparisons are fine.
- Tooltip under EllesmereUI only writes EUI's account-wide `EllesmereUIDB.tooltipAnchorCursor` (EUI's hooks re-read it per tooltip; fixed anchor positions itself). EUI only INSTALLS its cursor hook at its PLAYER_LOGIN if the flag is on then, so `TooltipModule` pre-seeds it to true at our `ADDON_LOADED` (`## OptionalDeps: ElvUI, EllesmereUI` guarantees EUI's SavedVariables are loaded first). Requires EUI's Reskin Tooltip ON.
- PetReminder is gated `HOSTS = { elvui, none }` — off under EllesmereUI, whose AuraBuffReminders "Missing Pet" (click-to-summon) covers it

## SoulstoneReminder Notes

- DBM's pull timer (`/pull`, `/dbm pull`) is just `C_PartyInfo.DoCountdown()` (see `DBM-Core/modules/UserTimers.lua: CreatePullTimer`), so the single Blizzard event `START_PLAYER_COUNTDOWN` covers DBM, BigWigs and `/countdown`. No DBM callback needed.
- `START_PLAYER_COUNTDOWN` args (initiator GUID, seconds) can be **secret values** in 12.x — DBM guards them with `hasanysecretvalues`. The module never reads them.
- Soulstone buff = spell 20707 on the soulstoned unit. Scan uses `C_UnitAuras.GetUnitAuraBySpellID(unit, 20707)` (2-arg form, as EllesmereUIAuraBuffReminders uses it), falling back to a `GetAuraDataByIndex` HELPFUL walk. Group auras are readable **out of combat**; `C_Secrets.ShouldAurasBeSecret()` flips in combat in instanced content. A countdown is OOC by definition (DBM also ignores it in combat), so this is safe — but any secret/erroring result makes the check return **nil = don't whisper**, never a false accusation.
- Whisper target is `GetUnitName(unit, true)` (`Name-Realm` cross-realm, `Name` same realm). Configured name is matched case-insensitively with any realm suffix stripped.
- 20s repeat cooldown: countdowns get cancelled/re-sent.

## EditBoxModule Notes (EllesmereUI)

- Two modes (`TokukoPDB.EditBox.mode`):
  - **cover** (default): on focus, each *visible* (`IsVisible` + effective alpha > 0) `EllesmereUIDataBarsBar<id>` overlapping the box gets a backdrop frame of ours, `SetAllPoints(bar)` (exact fit), strata HIGH level 500, mouse-enabled to swallow bar clicks; the edit box is raised to DIALOG. Undone on focus lost. Bars found by probing global names 1..200 (ids are monotonic with gaps) — **no EUI internals**. The edit box's size/position are never touched (EllesmereUIChat owns them as part of the chat window — Jarrot's call). Default colour = EllesmereUIChat's panel default (0.03, 0.045, 0.05) at alpha 1; pick the bar's colour to blend.
  - **fade**: fades every `EllesmereUIDataBarsBar<id>` overlapping the box (ids via `EllesmereUI._ModuleNS.EllesmereUIDataBars.BarsInOrder()`), SetAlpha only (bars with secure blocks are protected; Show/Hide in combat is blocked). Restores via DataBars `ns.UpdateAllBarVisibility()` and post-hooks it to re-fade while typing — hook installed lazily, only once fade is used. **Uses EUI internals** — EUI's plugin guide asks addons not to; opt-in, may break on EUI updates. Gaps: mouseover bars reappear on hover; faded bar still clickable.
- Never `HookScript` a chat edit box: it taints the chat-type attribute and sends get silently swallowed in encounter/M+/PvP chat lockdown (documented in EllesmereUIChat). Use `EventRegistry` callbacks `ChatFrame.OnEditBoxFocusGained/FocusLost` (+ `OnEditBoxHide` as a fallback) — they run through `securecallfunction`. Key on focus, not Show/Hide: with `chatStyle` "im" the box stays shown while inactive. Filter to ChatFrame1-10 boxes (temp whisper windows carry secret BN tell targets).

## ChatWindowModule Notes (EllesmereUI)

- EUI has no chat panel of its own: it paints a background behind each Blizzard chat window (incl. undocked ones, which also get its tab ghost + resize grip). So the "right chat panel" under EUI = a real **undocked** chat window the player creates (New Window, drag tab off). We never create/dock/undock windows — writing Blizzard dock state from insecure code taints the secure whisper temp-window chain (EllesmereUIChat comments).
- Found by tab name via `GetChatWindowInfo(i)`. Refuses ChatFrame1 and docked windows.
- **Never `SetSize` a chat frame.** Size = two corner anchors (BOTTOMRIGHT + TOPLEFT relative to UIParent BOTTOMRIGHT), the same lane EllesmereUIChat uses for ChatFrame1: the rect is anchor-determined and OnSizeChanged dispatches secure. Uses `SetPointBase`/`ClearAllPointsBase` when present (Edit Mode overrides). Deferred `C_Timer.After(0)`, out of combat only (queued to REGEN_ENABLED).
- **Applied ONLY on setting changes** (panel, shortcut buttons, Unlock Mode) — Jarrot's call, no login/loading-screen/chat-update handling or move checks. Persistence = Blizzard's own store: each apply also calls `SetChatWindowSavedPosition(id, "BOTTOMRIGHT", -x/GetScreenWidth(), y/GetScreenHeight())` + `SetChatWindowSavedDimensions(id, w, h)` (the two C calls `FCF_SavePositionAndDimensions` makes — verified against wow-ui-source; it writes no Lua state). Blizzard's `FloatingChatFrame_Update` runs `FCF_RestorePositionAndDimensions` for undocked windows at login AND on chat-window updates, so without writing the store our anchors got overwritten (this is what moved the window/Details/data bar on reload). Hand drags/resizes save to the same store via Blizzard's drag-stop; our sliders only catch up via "Use Current".
- ElvUI by contrast owns Left/RightChatPanel frames sized by `panelWidth/Height(Right)` and calls `chat:SetSize` inside them — the panel-first model; we get the same numbers without SetSize.
- Values are the chat frame's own rect; EUI's painted panel extends ~10px each side plus the tab band.
- After moving the window, `NudgeEUIChat()` calls EllesmereUIChat's `ECHAT.QueueTabPass` (internal, guarded): EUI re-reads chat rects only while chat is hovered / Edit / Unlock Mode, so a code-driven move left its panel + tab ghost stale until the next tab hover (Jarrot hit this 2026-10-06).
- **EUI Unlock Mode element** `TokukoP_ChatWindow` (group "Chat", order 610) via `EllesmereUI:RegisterUnlockElements` + `EllesmereUI.MakeUnlockElement` — EUI_UnlockMode.lua's header says any addon may register (no caller check, not `_`). Movers place the frame with ONE point per drag tick → `onLiveMove` re-pins TOPLEFT+BOTTOMRIGHT from that point using the DB size (same as EllesmereUIChat's `KeepMainChatSizeCorner`). Positions arrive as CENTER/CENTER offsets → converted to our bottom-right x/y. Resize arrives via `setWidth/setHeight` → DB + re-anchor (still never SetSize). `ownsPosition` (no anchor links FROM it; others may anchor TO it), `noInitHook` (we position it ourselves). `isHidden` until enabled + window found undocked.

## SpeedModule Notes

- LDB data source `TokukoP: Speed` (add via an EUI data bar's LDB block, or any LDB display / ElvUI datatext). Text is just `NNN%`: the max speed for the current state — swim / skyriding forward speed / flight / run — over `BASE_MOVEMENT_SPEED` (7). Value only, no tooltip (Jarrot).
- `GetUnitSpeed` can be **secret** in 12.x (LiteMount guards it; ElvUI's datatext uses AbbreviateNumbers instead of math). LibDataBroker's `__newindex` compares old/new with `==`, which throws on a secret — so secret readings are skipped (last value stays) and the secret check runs BEFORE any `== nil`. `GetGlidingInfo`'s isGliding is secret-checked too.
- 0.25s ticker (swim/fly/glide transitions have no event); pushes to LDB only when the % changes.
- No HOSTS gate, no settings.

## Git Branches

- `main` — stable
- `dev` — work in progress

Always work on `dev`, merge to `main` when done.
