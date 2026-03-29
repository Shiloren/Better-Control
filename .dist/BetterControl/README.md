# Better Control

Controller-first vendor surfaces for World of Warcraft Retail 11.x, built around the handheld ergonomics of the ROG Xbox Ally X.

## Hardware target

The addon assumes the ROG Xbox Ally X is the primary target and treats it like a native Xbox-style handheld surface:

- `A/B/X/Y`
- `D-pad`
- `LB/RB`
- `LT/RT`
- `View/Menu`
- `M1/M2` rear buttons as optional remapped addon shortcuts
- Touchscreen and joystick cursor as parallel input paths

Buttons that belong to the device shell stay reserved:

- `Xbox` stays reserved for the system overlay and Game Bar
- `Command Center` stays reserved for ASUS / shell controls
- `Library` stays reserved for the aggregated handheld library

## Default handheld mapping

- `A`: primary action
- `B`: cancel / close merchant
- `X`: quick action
- `Y`: maximum action
- `LB/RB`: previous / next tab
- `LT/RT`: page or large-step adjustment
- `View`: toggle mode / toggle selection
- `Menu`: commit grouped action

Optional Armoury Crate mapping:

- Map `M1` to a spare keyboard key and set `BetterControlDB.vendor.allyBackLeftKey` to that key name
- Map `M2` to a spare keyboard key and set `BetterControlDB.vendor.allyBackRightKey` to that key name

Recommended use:

- `M1` -> mode/select action
- `M2` -> commit grouped action

The addon also exposes WoW keybindings for the vendor surface:

- Confirm / Start
- Cancel / Close
- Quick action
- Max action
- Mode / Select toggle
- Commit grouped action
- Previous / next tab
- Up / down
- Large step down / up

## Vendor v1 goals

- Custom merchant frame with Blizzard-like styling and independent logic
- Consumables-first list layout instead of the stock mosaic vendor rows
- Smart purchase target with batch queueing and adaptive backoff
- Sell, buyback, and repair flows with controller-native actions
- Large hit areas for touch and joystick cursor use on a 7-inch screen

## Research notes

The implementation is based on official device and platform materials current as of March 28, 2026:

- Xbox announced the handhelds on June 8, 2025 and described the Xbox full-screen experience, aggregated library, and base hardware profile.
- Xbox listed the ROG Xbox Ally X with `24GB LPDDR5X-8000`, `1TB SSD`, `80Wh` battery, `7-inch 1080p 120Hz FreeSync Premium` display, and `Wi-Fi 6E + Bluetooth 5.4`.
- ASUS’ published spec sheet lists `A/B/X/Y`, left and right sticks, D-pad, `Xbox`, `View`, `Menu`, `Command Center`, `Library`, `M1`, `M2`, bumpers, triggers, plus accelerometer and gyro.
- Xbox’s getting-started guide states that long-pressing `Command Center` opens the Gaming Copilot widget in Game Bar and the dedicated `Library` button opens the handheld library, which is why the addon deliberately does not hijack those buttons.
