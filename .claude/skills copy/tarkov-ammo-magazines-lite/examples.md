# Examples (expected behaviors)

## Load ammo by dragging

- Drag “5.56x45 ammo (stack 60)” onto “STANAG mag (0/30)”
- Result: ammo stack decreases by 30, mag becomes 30/30

## Wrong caliber reject

- Drag “9x19 ammo” onto “STANAG (5.56)” mag
- Result: reject + UI shows “Wrong caliber” (no state change)

## Partial load (optional)

- Shift-drag ammo onto mag
- Load 10 rounds (or show small chooser)

## Unload mag

- Right click mag → Unload
- Move rounds back into existing ammo stack if possible, else create new stack.

## Reload (minimal)

- Weapon is 5.56-compatible
- Inserted mag empty, another loaded mag exists in inventory
- Press reload → swaps to loaded mag deterministically (highest loadedCount, then lowest instanceId)
