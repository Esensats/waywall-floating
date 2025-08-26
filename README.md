# Floating Module

The **floating** module helps managing the visibility of floating windows with [waywall](https://github.com/tesselslate/waywall)  
(e.g. Ninjabrain Bot) during Minecraft speedrunning.

It provides a single abstraction point around `waywall.show_floating`, handling:

- Persistent overrides (pin floating windows ON or OFF).
- Temporary shows that auto-hide after a delay.
- Correct handling of repeated triggers (prevents stale-timer bugs).

This makes it easier to bind actions like "toggle floating permanently" or `F3+C` (temporarily show Ninjabrain Bot when copying coordinates) without directly calling `show_floating` in multiple places.

---

## Context

- **waywall** is a Wayland compositor running nested under another one.  
  It is tailored for Minecraft speedrunning on Linux/Wayland.
- Runners often need external tools during runs:
  - **Ninjabrain Bot** (calculator for stronghold triangulation).
  - **Paceman** and other utilities.
- These tools run in separate windows that should float _above_ Minecraft.
- `waywall.show_floating(true/false)` is the compositor API for showing or hiding all floating windows.

### Why this module?

Consider pressing **F3+C** in Minecraft:

- Minecraft copies the player’s coordinates to clipboard.
- Ninjabrain Bot reads the clipboard and shows its state.
- You want floating windows to appear for a few seconds, then hide automatically.

Naive implementations (calling `show_floating` directly) suffer from:

- **Stale timer bug**: multiple presses of F3+C cause earlier timers to still hide the window, even if a newer one should keep it visible.
- **Override conflict**: toggling floating windows ON explicitly can be undone unexpectedly by a stale timeout.

The floating module fixes this by:

- Tracking an **override state** (persistent ON/OFF).
- Tracking temporary show requests with a **resettable timeout**.
- Guaranteeing that newer timers cancel older ones.

---

## API

The module is created by passing a backend that implements the compositor operations:

```lua
--- @class FloatingBackend
--- @field show_floating fun(state: boolean)  -- show/hide floating windows
--- @field sleep fun(ms: integer)             -- blocking sleep
```

### Creating the module

```lua
-- ~/.config/waywall/init.lua
local waywall = require("waywall")

local create_floating = require("floating")

local floating = create_floating({
  show_floating = waywall.show_floating,
  sleep = waywall.sleep,
})
```

### Functions

```lua
floating.show()              -- show once (does NOT set override)
floating.hide()              -- hide once (does NOT set override)

floating.override_on()       -- force override ON (floating always visible)
floating.override_off()      -- force override OFF (floating always hidden)
floating.override_toggle()   -- toggle override, returns new state
floating.is_overridden()     -- check if override is active

floating.hide_after_timeout(ms) -- hide after `ms` milliseconds, unless override is ON
```

---

## Example

```lua
-- Toggle floating windows persistently
config.actions["*-B"] = function()
  floating.override_toggle()
end

-- F3+C: copy Minecraft coordinates and temporarily show ninjabrain bot for 10s
config.actions["*-C"] = function()
  if waywall.get_key("F3") then
    waywall.press_key("C")
    floating.show()
    floating.hide_after_timeout(10000)
  else
    return false
  end
end
```

Behavior:

- Pressing **B** pins floating ON/OFF (persistent).
- Pressing **F3+C** shows floating for 10s, unless pinned OFF.
  Multiple presses reset the timer (no stale hide bug).

---

## Testing without waywall

You can inject a mock backend to test the logic without a compositor:

```lua
local floating = create_floating({
  show_floating = function(state) print("Floating:", state) end,
  sleep = function(ms) print("Sleep", ms, "ms") end,
})
```
