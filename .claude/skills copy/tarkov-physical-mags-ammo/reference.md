# Reference (Godot 4.6, C#)

## Resource authoring in C#

Use:

- `[GlobalClass]` to create Resources from the editor
- `[Export]` for inspector fields

## Control drag & drop

If using Godot Control DnD:

- `_GetDragData(Vector2 atPosition)`
- `_CanDropData(Vector2 atPosition, Variant data)`
- `_DropData(Vector2 atPosition, Variant data)`

Or a custom held-item approach works too; just keep rules in services.

## Determinism for future co-op

- stable instance IDs
- sort candidates by loadedCount desc, then instanceId asc
- never depend on NodePath identity

## Suggested save DTO

Ammo item:

- instanceId, defId, stackCount

Magazine item:

- instanceId, defId, loadedCount, loadedAmmoDefId

Weapon runtime:

- insertedMagInstanceId
