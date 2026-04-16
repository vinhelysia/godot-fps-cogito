# Reference (Godot 4.6, C#)

## C# Resources in Godot

Use `[GlobalClass]` so your Resource shows up in “Create Resource” and the editor can treat it like a named script. :contentReference[oaicite:1]{index=1}  
Use `[Export]` so fields are editable in the Inspector and saved with the resource. :contentReference[oaicite:2]{index=2}

Practical tips:

- File name must match the class name exactly for global classes.
- Keep resource IDs stable (string Id) and never rename lightly.

## UI drag-and-drop

For Control-based inventory UI, Godot provides:

- `_get_drag_data(at_position)`
- `_can_drop_data(at_position, data)`
- `_drop_data(at_position, data)`
  Plus `set_drag_preview()` for a ghost. :contentReference[oaicite:3]{index=3}

Even if you use a custom “held item” approach, keep the same model operations.

## Determinism for future co-op

- Prefer stable instance IDs in model.
- Avoid relying on Node paths for identity.
- Any search order must be deterministic (sort by instanceId).

## Suggested DTO fields (save)

Ammo item:

- instanceId
- defId
- stackCount

Magazine item:

- instanceId
- defId
- loadedCount
- loadedAmmoDefId

Weapon runtime (if saved):

- insertedMagazineInstanceId (or null)ds
