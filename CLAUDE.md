# TokukoPreferences

A modular WoW addon for **Midnight 12.x** built around ElvUI. Written in Lua.

## Project Structure

```
Core.lua           — namespace (TokukoP), SavedVariables (TokukoPDB), PLAYER_LOGIN init
DrinkingModule.lua — eating/drinking announcements to group chat
TooltipModule.lua  — ElvUI tooltip cursor anchor switching
EmbedModule.lua    — Details! embed into ElvUI right chat panel (main module)
Settings.lua       — ElvUI AceConfig panel (/ec → Plugins → TokukoPreferences)
DebugModule.lua    — optional debug commands, commented out in TOC by default
```

## Key Globals

- `TokukoP` — addon namespace, `TokukoP.modules` holds all module references
- `TokukoPDB` — SavedVariables, sub-tables: `Drinking`, `Embed`, `Tooltip`
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
- `EmbedModule.Toggle()` — embed/unembed
- `EmbedModule.IsEmbedded()` — returns embedded state
- `EmbedModule.PrintDebug()` — called by DebugModule for /tpdebug

## Settings (AceConfig via LibElvUIPlugin-1.0)

Registers under `E.Options.args.TokukoPreferences` — appears in `/ec` sidebar under Plugins.
Flat single-page layout with section headers. Green `|cff00ff00Enable|r` toggle per module.
Falls back to `BuildFallbackWindow()` if ElvUI not loaded (opened via `/tp`).

## ElvUI Skinning

Uses `E:GetModule("Skins")` — methods: `S:HandleButton()`, `S:HandleCheckBox()`, `S:HandleEditBox()`, `S:HandleCloseButton()`
Frame backdrop: `frame:SetTemplate("Default")`

## Slash Commands

- `/tpembed` — toggle embed on/off
- `/tp` / `/tokukop` — open settings
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

## Git Branches

- `main` — stable
- `dev` — work in progress

Always work on `dev`, merge to `main` when done.
