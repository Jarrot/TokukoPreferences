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
- `frame.titleBar:Hide()` — hides title bar
- `frame.border:Hide()` — hides rounded corner border (extends outside frame bounds)
- `frame.floatingframe:Hide()` — hides extra chrome
- `frame.isLocked = true` — locks window
- `frame.BoxBarrasAltura` — internal bar container height
- `frame._instance.db.width/height` — saved dimensions

### Combat handling
- `embedPending` — if embed attempted in combat, retries on `PLAYER_REGEN_ENABLED`
- `combatOnly` — hides/shows meters via `SetMetersVisible()`, does NOT unembed/re-embed
- Right-click `>` button — calls `SetMetersVisible()` to hide/show, not detach

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

## Git Branches

- `main` — stable
- `dev` — work in progress

Always work on `dev`, merge to `main` when done.
