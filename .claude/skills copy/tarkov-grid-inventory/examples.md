# Examples: Expected UX (Tarkov-style)

## Basic drag/drop

- Click item: pick up
- Move cursor: preview highlights target cells
- Click again: drop (place if valid, otherwise revert)

## Rotate while held

- Press R:
  - held item rotates
  - grabbed cell stays under cursor as much as possible
  - preview updates instantly

## Swap

- Drag item A onto item B:
  - if B can fit into A's original location, swap
  - else revert

## Stacking

- Drag stackable ammo onto same ammo:
  - merge up to max stack
  - if leftover, continue holding leftover stack

## Nested containers

- Backpack item has its own grid
- Opening backpack shows contained grid view
- Items inside persist when backpack moved between inventories

## Recommended input actions

- inv_pickup_drop (mouse left)
- inv_rotate (R)
- inv_split_stack (Shift)
- inv_context (Right click)
