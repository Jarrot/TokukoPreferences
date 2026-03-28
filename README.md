# TokukoPreferences

A modular quality-of-life addon for World of Warcraft Midnight (12.x), built around ElvUI.

## Features

### Drinking Announcements
Announces to group/raid chat when you start eating or drinking, and optionally when you finish. Configurable messages.

### Damage Meter Embed
Embeds Details! damage meter windows directly into ElvUI's right chat panel, replacing the chat area with live meter data.

- Supports single or dual window embed (side by side)
- Right-click the `>` collapse button to hide/show meters without detaching
- `/tpembed` to manually toggle embed on/off
- "Hide Out of Combat" mode: meters hide when leaving combat and reappear on combat start
- Windows are locked and chrome-stripped when embedded, restored on detach

**Requirements:** ElvUI + Details! with at least 1 (or 2 for dual) open windows

### Tooltip
Anchors the tooltip to your cursor when out of combat, snapping to the fixed ElvUI anchor position during combat.

## Settings

Open ElvUI config with `/ec` → **Plugins** → **TokukoPreferences**

## Installation

1. Extract `TokukoPreferences` folder into `World of Warcraft/_retail_/Interface/AddOns/`
2. Reload or restart the game
3. Open Details! and ensure at least 1 window is visible (2 for dual embed)
4. Enable Embed in `/ec` → Plugins → TokukoPreferences

## Debug (optional)

To enable debug commands, open `TokukoPreferences.toc` and uncomment `# DebugModule.lua`.

Available commands:
- `/tpdebug` — print embed state, panel dimensions, frame sizes
- `/tpscan` — find Details! frame globals
- `/tpgap` — measure gap between meter frames and data bar

## Slash Commands

- `/tpembed` — toggle embed on/off (detach/reattach)
- `/tp` or `/tokukop` — open settings (redirects to `/ec` when ElvUI is loaded)

## Compatibility

- WoW Midnight 12.x (TOC 120000, 120001, 120005)
- Requires ElvUI 15.x
- Requires Details! damage meter
- Skada: not supported (unmaintained in 12.0)

## Author

Jarrot
