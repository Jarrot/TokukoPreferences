# TokukoPreferences

A modular quality-of-life addon for World of Warcraft Midnight (12.x), built around ElvUI.

> **This addon is 100% written and maintained using [Claude Code](https://claude.com/claude-code) by Anthropic.**
> The author (Jarrot) does not write any code. Every feature, bug fix, and architectural decision is implemented through conversation with Claude. This is an ongoing real-world example of AI-assisted addon development.

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
- Chrome is automatically rehidden after loading screens, resurrections, and spec changes

**Requirements:** ElvUI + Details! with at least 1 (or 2 for dual) open windows

### Healer Mana Display
Movable overlay showing all healers in your group/raid sorted by mana (lowest first).

- Display modes: percent, absolute (45.2k), or both
- Class-colored names or custom colour
- Configurable font, size, grow direction, background opacity
- Resizable via right-edge drag handle
- Fully compatible with WoW 12.x secret values (uses Blizzard's C-level APIs)

### Combat Res Tracker
Two movable icons showing battle resurrection charges and Shaman Reincarnation cooldown.

- Rebirth icon: current charge count badge + regen timer (MM:SS)
- Reincarnation icon: personal cooldown timer (Shaman only, hidden when ready)
- CooldownFrameTemplate sweep on both icons
- Optional ElvUI icon style (backdrop border + tighter texture crop)

### Tooltip
Anchors the tooltip to your cursor when out of combat, snapping to the fixed ElvUI anchor position during combat.

## Settings

Open ElvUI config with `/ec` → **Plugins** → **TokukoPreferences**

## Installation

1. Extract `TokukoPreferences` folder into `World of Warcraft/_retail_/Interface/AddOns/`
2. Reload or restart the game
3. Open Details! and ensure at least 1 window is visible (2 for dual embed)
4. Enable the modules you want in `/ec` → Plugins → TokukoPreferences

## Debug (optional)

To enable debug commands, open `TokukoPreferences.toc` and uncomment `# DebugModule.lua`.

Available commands:
- `/tpdebug` — print embed state, panel dimensions, frame sizes
- `/tpscan` — find Details! frame globals
- `/tpgap` — measure gap between meter frames and data bar
- `/tpcrstats` — combat res event fire rate counter

## Slash Commands

- `/tpembed` — toggle embed on/off (detach/reattach)
- `/tp` or `/tokukop` — open settings (redirects to `/ec` when ElvUI is loaded)

## Compatibility

- WoW Midnight 12.x (TOC 120000, 120001, 120005)
- Requires ElvUI 15.x
- Requires Details! damage meter (for embed feature)
- Skada: not supported (unmaintained in 12.0)

## Author

Jarrot — developed entirely through conversation with [Claude Code](https://claude.com/claude-code)
