# Better Control Vendor Test Guide

## Install

1. Unzip the package so the final path is `World of Warcraft\_retail_\Interface\AddOns\BetterControl\BetterControl.toc`.
2. Start the game and enable `Better Control` in the addon list.
3. Use `/reload` after copying updates.

## Input model

Primary Ally / Xbox layout:

- `A`: confirm / start action
- `B`: cancel / close merchant
- `X`: quick action
- `Y`: max action
- `LB/RB`: previous / next tab
- `LT/RT`: large-step down / up
- `View`: toggle mode or selection
- `Menu`: commit grouped action

Bind alternative inputs in WoW Keybindings under `Better Control`.

## Vendor flow

When a merchant opens:

1. Blizzard's merchant frame stays alive as backend, but Better Control opens its own frame.
2. `Buy` shows a vertical list instead of the default vendor mosaic.
3. Selecting an item opens the quantity surface on the right.
4. `Purchase` mode buys an explicit amount.
5. `Inventory Target` mode buys only the missing amount needed to reach a target total in your bags.
6. The queue buys in controlled batches and backs off if the server or merchant is busy.

Other tabs:

- `Sell`: bag item selling, stack selling, selected selling, junk cleanup
- `Buyback`: vendor buyback list
- `Repair`: equipped repair, repair all, guild repair if available

## Core tests

### Buy

1. Open a normal vendor and confirm the Better Control frame appears.
2. Move the list with mouse and controller.
3. Buy a small amount of a consumable.
4. Switch to `Inventory Target` and set a total above what you already own.
5. Buy a larger target and confirm progress updates while the queue runs.
6. Cancel a queue in progress.

### Extended cost / limited stock

1. Try a vendor item with alternate cost.
2. Try a limited-stock item.
3. Confirm the queue stops cleanly when stock is depleted or you cannot afford more.

### Sell

1. Open `Sell` with ordinary vendor trash and normal items in bags.
2. Sell one item from a stack.
3. Sell a full stack.
4. Mark multiple items and use grouped sell.
5. Use junk cleanup.

### Buyback

1. Sell an item and move to `Buyback`.
2. Buy it back and verify list/state updates.

### Repair

1. Damage equipped gear.
2. Run equipped repair.
3. Run repair all.
4. If available, run guild repair.

### Input / handheld

1. Test with keyboard and mouse.
2. Test with WoW native gamepad mode.
3. Test with ConsolePort installed.
4. If using Armoury Crate remaps, bind M1/M2 to spare keys and wire them to Better Control actions in WoW Keybindings.

## Troubleshooting

- If the addon does not appear, verify the folder path ends in `BetterControl\BetterControl.toc`.
- If bindings do not react, check WoW Keybindings and confirm the frame is open over a merchant.
- If a system button does not reach the addon, it is likely reserved by the handheld shell and must be remapped before WoW can see it.
