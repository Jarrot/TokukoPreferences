# Changelog

All notable changes to TokukoPreferences. Versions follow `MAJOR.MINOR.PATCH`:
**PATCH** = bug fixes, **MINOR** = new features, **MAJOR** = big or breaking changes.

New work is collected under **Unreleased** on `dev` and becomes a version when it is
merged to `main` (see "Releasing" in CLAUDE.md).

## [Unreleased]

### Fixed
- **Second Chat Window**: now gets the same border as the main chat. EllesmereUI draws
  its chat border (Border Thickness / colour / texture) around the main chat only, so
  the second window had none. New **Match Main Chat Border** toggle (on by default).
  Follows EUI border changes after a `/reload`.

### Changed
- **Edit Box** settings: the Mode tooltip now warns that **Fade Data Bars** hooks into
  EllesmereUI's internal data bar code (an EUI update can break it); Cover mode does not.
  The two "Match…" options note that they read EUI internals.

## [1.0.0] - 2026-10-07

First versioned release. TokukoPreferences now works with **ElvUI or EllesmereUI**
(it detects which one is loaded and turns modules on or off to match; ElvUI wins if
both are loaded). Everything that worked under ElvUI keeps working the same way.

### Added
- **EllesmereUI support**, with a *Tokuko Preferences* section in EllesmereUI's own
  options panel (`/tp`): a **General** page (Healer Mana, Combat Res, Soulstone
  Reminder, Drinking, Tooltip) and a **Chat** page (Second Chat Window, Details Embed,
  Chat Edit Box), each module under its own header. `/tp window` opens the standalone
  settings window.
- **Second Chat Window** (EllesmereUI): exact width, height and position for a
  free-floating chat window, with *Match* / *Mirror* the main chat and *Use Current*
  shortcuts. Movable and resizable in EllesmereUI's Unlock Mode as *Second Chat*.
  Saved into Blizzard's own chat-window store, so it stays put across reloads.
- **Details embed for EllesmereUI**: fits Details windows (single or dual, adjustable
  split) into the Second Chat Window, leaving room for Details' title bar. Runs when a
  setting changes or with *Fit Now*; Details then keeps that position itself. Only size
  and position are touched.
- **Chat Edit Box** (EllesmereUI): keeps the chat edit box on top of a data bar while
  typing. *Cover* lays a background over each bar under the box (by default a copy of
  that bar's own look); *Fade* hides the bars instead.
- **Movement Speed** data bar item (*TokukoP: Speed*, LibDataBroker): your current max
  movement speed in %, 100% = normal run speed (ground, swimming or flying).
- **Soulstone Reminder**: whispers a chosen player when a pull countdown starts and
  nobody in the raid has a Soulstone. `/tpss` for a dry run.
- Tooltip combat anchoring now also works with EllesmereUI's tooltips.
- The standalone `/tp` settings window covers every module (sliders, dropdowns,
  colour pickers).

### Changed
- **Pet Reminder** is off under EllesmereUI, whose own *Missing Pet* reminder (click to
  summon) covers it.
- Pet Reminder no longer warns while in a vehicle or on a taxi/transport.
- The addon now bundles LibStub, CallbackHandler-1.0 and LibDataBroker-1.1.

### Fixed
- Long font lists in settings dropdowns now scroll.

[Unreleased]: https://github.com/Jarrot/TokukoPreferences/compare/v1.0.0...dev
[1.0.0]: https://github.com/Jarrot/TokukoPreferences/releases/tag/v1.0.0
