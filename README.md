# TokukoPreferences

A modular quality-of-life addon for World of Warcraft Midnight (12.x). Works with **ElvUI** or **EllesmereUI** — it detects which one is loaded and turns modules on or off to match (ElvUI wins if both are loaded).

> **This addon is 100% written and maintained using [Claude Code](https://claude.com/claude-code) by Anthropic.**
> The author (Jarrot) does not write any code. Every feature, bug fix, and architectural decision is implemented through conversation with Claude. This is an ongoing real-world example of AI-assisted addon development.

## Features

### Drinking Announcements
Announces to group/raid chat when you start eating or drinking, and optionally when you finish. Configurable messages.

### Damage Meter Embed
Puts Details! damage meter windows into the right-hand chat area.

**ElvUI:** embeds into ElvUI's right chat panel, replacing the chat area with live meter data.

- Supports single or dual window embed (side by side)
- Right-click the `>` collapse button to hide/show meters without detaching
- `/tpembed` to manually toggle embed on/off
- "Hide Out of Combat" mode: meters hide when leaving combat and reappear on combat start
- Windows are locked and chrome-stripped when embedded, restored on detach
- Chrome is automatically rehidden after loading screens, resurrections, and spec changes

**EllesmereUI:** fits Details into the **Second Chat Window** (below). Only size and position are changed — Details' own look, layering and show/hide stay as set in Details.

- The fit runs when a setting changes (or **Fit Now**); Details then saves it as its own position and restores it at every login — nothing is re-applied afterwards, so lock the windows in Details as usual
- Leaves room for Details' title bar / toolbar / status bar inside the window, with Top/Bottom Space Adjust for skins
- Single or dual window with an adjustable split
- Turning it off leaves the windows where they are

**Requirements:** Details! with at least 1 (or 2 for dual) open windows; ElvUI, or EllesmereUI with the Second Chat Window set up

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

### Pet Reminder (ElvUI / no UI suite)
Flashing on-screen warning when a Hunter, Warlock, or Unholy Death Knight has no active pet. Off under EllesmereUI, whose own "Missing Pet" reminder (click to summon) covers it.

- Only active for eligible classes/specs (Hunters, Warlocks, Unholy DKs) — silent for everyone else
- Movable message (drag to reposition) with configurable font, size, and colour
- Visual effects: pulse, shake, bounce, scale, or colour flash
- Optional warning sound, and a separate combat-only message (e.g. "SUMMON YOUR PET")
- Automatically hides while mounted or when a pet is present

### Soulstone Reminder
Whispers a chosen player when a pull countdown starts and nobody in the raid has a Soulstone.

- Triggers on DBM pull timers, BigWigs pull timers and the native `/countdown` (all use the same Blizzard countdown event)
- Only fires if the configured player is actually in the group; configurable name and message
- "Raid Groups Only" toggle (default on) ignores 5-man countdowns
- Stays silent if aura data can't be read reliably — never whispers on bad data
- `/tpss` dry run prints what the check would do right now without whispering

### Second Chat Window (EllesmereUI only)
EllesmereUI styles every chat window the same but has no size/position settings — this adds them for one free-floating (undocked) chat window, the EllesmereUI counterpart of ElvUI's right chat panel and the host for the Details embed.

- **Setup (once, by hand):** right-click the General tab → New Window (e.g. `Details`), drag its tab off to undock it, and untick all its messages/channels
- Exact Width / Height / X (from the right edge) / Y (from the bottom edge), plus **Match** (copy the main chat's size), **Mirror** (mirror the main chat's position) and **Use Current** (read a hand-dragged position)
- Movable and resizable in EllesmereUI's Unlock Mode as **Second Chat**
- Applied only when a setting changes, and saved into Blizzard's own chat-window store, so Blizzard restores it at every login — nothing re-applied or checked afterwards
- Never resizes the chat frame directly and never creates/docks windows (both taint chat in encounters); sizing uses two corner anchors, the same technique EllesmereUI uses for the main chat

### Chat Edit Box (EllesmereUI only)
Lets the chat edit box sit on top of a data bar, like ElvUI's edit box covering its datatext panel.

- **Cover** (default): while you type, each data bar under the edit box gets a background laid exactly over it (colour + opacity configurable), with the edit box on top. The edit box itself is never moved or resized
- **Fade**: while you type, any EllesmereUI data bar the edit box overlaps fades out, and its own Visibility setting is re-applied on close. Relies on EllesmereUI internals, so an EUI update could break it
- Doesn't touch chat sending, so no taint in encounter/M+ chat lockdown

### Movement Speed (data bar)
A LibDataBroker item, **TokukoP: Speed**, showing your current max movement speed as a percentage (100% = normal run speed) — for whatever you're doing right now: running, swimming or flying (skyriding counts as flying). Checked once a second. Add it to an EllesmereUI data bar (LDB block) or any LDB display.

### Tooltip
Anchors the tooltip to your cursor when out of combat, snapping to the fixed anchor position during combat. Neither UI suite switches on combat by itself.

- **ElvUI:** flips ElvUI's tooltip cursor-anchor setting
- **EllesmereUI:** flips EllesmereUI's own "Anchor to Cursor" (so leave that checkbox to this option); your cursor position/offsets and the Unlock Mode fixed position are used as set. Needs EllesmereUI's **Reskin Tooltip** on

## Settings

- **ElvUI:** `/ec` → **Plugins** → **TokukoPreferences**
- **EllesmereUI:** `/tp` opens a **Tokuko Preferences** section in EllesmereUI's own options panel (via its Plugin API), with two pages: **General** (Healer Mana, Combat Res, Soulstone Reminder, Drinking, Tooltip) and **Chat** (Second Chat Window, Details Embed, Chat Edit Box)
- `/tp window` — the standalone settings window (also the fallback with no UI suite)

## Installation

1. Extract `TokukoPreferences` folder into `World of Warcraft/_retail_/Interface/AddOns/`
2. Reload or restart the game
3. Open Details! and ensure at least 1 window is visible (2 for dual embed)
4. Enable the modules you want in `/tp` (EllesmereUI) or `/ec` → Plugins → TokukoPreferences (ElvUI)

## Debug (optional)

To enable debug commands, open `TokukoPreferences.toc` and uncomment `# DebugModule.lua`.

Available commands:
- `/tpdebug` — print embed state, panel dimensions, frame sizes
- `/tpscan` — find Details! frame globals
- `/tpgap` — measure gap between meter frames and data bar
- `/tpcrstats` — combat res event fire rate counter

## Slash Commands

- `/tpembed` — toggle embed on/off (detach/reattach)
- `/tp` or `/tokukop` — open settings (ElvUI: `/ec`; EllesmereUI: its options panel)
- `/tp window` — standalone settings window
- `/tpss` — Soulstone Reminder dry run

## Compatibility

- WoW Midnight 12.x (TOC 120000, 120001, 120005)
- ElvUI 15.x **or** EllesmereUI 9.x (client 12.1+); runs with neither, minus the suite-specific modules
- Bundles LibStub, CallbackHandler-1.0 and LibDataBroker-1.1
- Requires Details! damage meter (for embed feature)
- Skada: not supported (unmaintained in 12.0)

## Author

Jarrot — developed entirely through conversation with [Claude Code](https://claude.com/claude-code)
