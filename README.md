# TokukoPreferences

A modular WoW addon for various quality-of-life preferences and alerts.

## Structure

```
TokukoPreferences/
├── TokukoPreferences.toc  # Load order definition
├── Core.lua               # Namespace & event handling
├── ManaModule.lua         # Mana/OOM alerts
├── Settings.lua           # Settings UI
└── README.md             # This file
```

## Current Features

### Mana Module
- Automatically performs `/oom` emote when leaving combat with low mana
- Configurable threshold (1-100%)
- Option to only trigger when in group/instance
- Smart debouncing to prevent spam

## Adding New Modules

To add a new module:

1. Create `NewModule.lua` with this structure:
```lua
local TokukoP = TokukoP
local NewModule = {}
TokukoP.modules.NewModule = NewModule

-- Define defaults
NewModule.DEFAULTS = {
  setting1 = true,
}

-- Initialize module
function NewModule.Initialize()
  TokukoPDB.NewModule = TokukoPDB.NewModule or {}
  TokukoP.MergeDefaults(TokukoPDB.NewModule, NewModule.DEFAULTS)
end

-- Register events (optional)
function NewModule.RegisterEvents(frame)
  frame:RegisterEvent("SOME_EVENT")
end

-- Handle events (optional)
function NewModule.OnEvent(event, ...)
  if event == "SOME_EVENT" then
    -- Do something
  end
end
```

2. Add it to `TokukoPreferences.toc` after Core.lua but before Settings.lua

3. Add settings in `Settings.lua` following the Mana module pattern

## Commands

- `/tokukop` - Open settings panel

## SavedVariables

Settings are stored in `TokukoPDB` (TokukoPreferences Database), organized by module:
- `TokukoPDB.Mana` - Mana module settings
- `TokukoPDB.NewModule` - Future module settings

## Development

The addon uses a namespace pattern to avoid conflicts:
- Global namespace: `TokukoP`
- SavedVariables: `TokukoPDB`
- Setting identifiers: `TokukoPref_ModuleName_settingKey`
