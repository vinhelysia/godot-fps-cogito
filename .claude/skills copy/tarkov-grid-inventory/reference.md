# Reference: Recommended APIs & Behaviors (Godot 4.6)

## C# Data Types

Prefer:

- `Vector2I` for cell coords
- `int` instanceId
- `int[]` occupancy (width\*height)
- `Dictionary<int, ItemInstance>` instances

## Core Classes (suggested)

### ItemDef (Resource)

Fields:

- string Id (stable)
- string DisplayName
- Texture2D Icon
- Vector2I SizeCells
- bool CanRotate
- int MaxStack
- bool IsContainer
- Vector2I ContainerGridSize (if container)

### ItemInstance (plain class)

- int InstanceId
- ItemDef Def
- int Stack
- bool Rotated
- Vector2I Origin (only valid when placed)
- Optional: List<int> Attachments
- Optional: GridInventory ContainerInventory (if IsContainer)

### GridInventory (rules)

- int Width/Height
- int[] Cells (instanceId or 0)
- Dictionary<int, ItemInstance> Items

Operations:

- bool CanPlace(ItemInstance item, Vector2I origin, bool rotated, int ignoreId=0)
- PlaceNew(...)
- PickUpAt(cell) -> returns HeldPayload (id, oldOrigin, oldRotated)
- TryPlaceExisting(id, origin, rotated) -> PlacementResult + details
- TrySwapOrReject(heldId, dropOrigin, rotated, strategy)
- Stack merge helpers

## Rotation mapping (“preserve grabbed cell”)

If size is (w,h) before rotate CW:
grab (x,y) becomes (h-1-y, x)

After rotating, clamp grab to bounds if needed.

## Conflict Resolution Strategy (recommended)

When dropping held item:

1. If empty fit: place.
2. If overlap with exactly one item:
   - try swap: can overlapped item fit at held’s old origin (with its old rotation)?
   - if yes: place held at drop, place displaced at old spot
3. Else reject and return held to old spot.

## Save format (DTO)

Root:

- formatVersion
- rootInventory: { width, height, items[], cells? }

Each item:

- instanceId
- defId
- stack
- rotated
- originX/originY (or null if not placed)
- containerInventory (optional nested)

Keep textures out of save.

## Testing Checklist (core)

- Place in bounds
- Fail out of bounds
- Fail overlap
- Rotate size swap
- Rotate mapping grab-cell
- Swap success/failure
- Merge stacks, leftover handling
- Nested inventory round-trip save/load
