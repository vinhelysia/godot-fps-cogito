---
name: tarkov-grid-inventory
description: Build or refactor a Tarkov/EFT-style grid inventory in Godot 4.6 (multi-cell items, rotation, stacking, swapping, nested containers) with a C# core and Godot UI Controls.
argument-hint: "[plan|core|ui|save|all] [optional: notes]"
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Edit, Bash(godot*), Bash(dotnet*), Bash(msbuild*), Bash(pwsh*), Bash(sh*), Bash(cmd*)
---

# Tarkov Grid Inventory Skill (Godot 4.6, C#-first)

ultrathink

When the user runs `/tarkov-grid-inventory $ARGUMENTS`, implement (or refactor towards) a production-ready “inventory tetris” system inspired by Escape from Tarkov:

- Items have cell sizes (w,h), can rotate 90°.
- Placement checks bounds + overlap.
- Drag/hold item with ghost preview (valid/invalid highlight).
- Supports stacking rules (max stack, merge, split).
- Supports swapping/moving with conflict resolution.
- Supports nested containers (rig/backpack/pouch grids) and equipment slots.
- Save/load inventory state to JSON (or Godot Variant dictionaries) with stable IDs.

This skill is C#-first:

- Core rules/data model in C# for maintainability + tooling.
- UI in C# `Control` (recommended), but may keep UI in GDScript if project already does it.
- Never put gameplay rules in the UI layer.

## Read these supporting docs when needed

- Architecture + APIs: [reference.md](reference.md)
- UX behaviors + interaction examples: [examples.md](examples.md)

## Operating Mode (choose based on $ARGUMENTS)

- `plan`: output a concrete file-by-file plan + acceptance tests before editing.
- `core`: implement model/rules + unit-ish tests (headless runnable).
- `ui`: implement UI Control(s) for grid + drag/drop + rotate.
- `save`: implement serialization + versioning.
- `all` (default): do `plan`, then implement core → ui → save → tests → demo scene.

## Non-negotiables (definition of done)

1. Multi-cell items place correctly and never overlap.
2. Rotation while held preserves the “grabbed cell” under cursor as much as possible.
3. Drop preview shows green/red and prevents invalid placement.
4. Swap/move behavior is deterministic:
   - If dropping onto occupied area, attempt swap if the displaced item can fit at the original location (or a configured fallback).
5. Stacking:
   - If same item type and stackable, merge up to max; leftover remains held.
   - Allow split (e.g. Shift+drag or context menu) if requested by the user.
6. Nested containers:
   - Container items expose a sub-grid definition (e.g. backpack 5x6).
   - Opening a container shows its internal grid; items inside persist on save.
7. Save/load:
   - Stable item instance IDs.
   - File format versioned for future migrations.
8. Performance:
   - No per-frame allocations in tight loops (placement checks).
   - UI redraws only when needed (on model changed, during drag).

## Workflow (always follow)

### Step 0 — Identify existing code and constraints

- Use `Glob`/`Grep` to find current inventory code, item data, UI, input actions.
- Determine whether project is C# (.csproj exists) and Godot version target.
- List what exists vs what needs refactor.

### Step 1 — Establish the target folder structure (prefer)

Create or refactor into:

- `res://Game/Inventory/Model/` (pure rules, minimal Godot types)
- `res://Game/Inventory/UI/` (Controls, visuals, input)
- `res://Game/Inventory/Data/` (Resources: ItemDef, ContainerDef, etc.)
- `res://Game/Inventory/Tests/` (headless runnable tests)
- `res://Game/Inventory/Demo/` (a demo scene to validate behavior)

### Step 2 — Implement the C# core (Model)

Implement these concepts (see reference.md for suggested APIs):

- `ItemDef : Resource` (id, name, icon, size, canRotate, maxStack, etc.)
- `ItemInstance` (instanceId, def, stack, rotated, containerLink, runtime state)
- `GridInventory` (width,height, occupancy array of instanceIds, dictionary of instances)
- `PlacementResult` enum + details (ok, out-of-bounds, overlap, etc.)
- Operations:
  - `CanPlace(instance, origin, rotated, ignoreId)`
  - `PlaceNew(def, origin, rotated, stack)`
  - `PickUpAt(cell)` returns held payload (id + old origin + old rotation)
  - `TryPlaceExisting(id, origin, rotated)` + conflict resolution strategy
  - `TryRotateHeldPreserveGrab(held, grabCell)`
  - `TryMergeStack(targetId, heldId)` / split support if requested
  - Optional: `FindFirstFit(def)` for auto-loot

### Step 3 — Implement UI Control (GridInventoryView)

Use a `Control`:

- Draw grid background + item rects + icons.
- Track held item state:
  - held instanceId
  - grabCell (which cell inside the item was grabbed)
  - previewOrigin + previewOk
- Input:
  - Left mouse: pick up / drop
  - `R`: rotate held (configurable action)
  - Optional: right click context menu (split/inspect)
- During drag, continuously recompute preview and request redraw.

### Step 4 — Serialization (Save/Load)

Implement:

- `ToDto()` / `FromDto()` producing plain data (no textures).
- JSON save file in `user://` (or user-defined).
- Include `formatVersion`.
- Nested containers: serialize recursively by instanceId.

### Step 5 — Tests + Demo

- Add a minimal test runner that can be executed headless.
- Must test:
  - bounds, overlap, rotation size swap
  - grab-cell rotation mapping
  - swap success/failure
  - stacking merge and leftover
  - nested container persistence
- Add a demo scene that spawns a stash grid with 5–10 sample items for manual QA.

## Output Requirements (for every run)

At the end of the run, print:

- What files were added/changed (with paths)
- How to open the demo scene and test key behaviors
- How to run the headless tests (exact command)
- Any known limitations or TODOs

## Safety / Don’t break the project

- Avoid renaming public scene paths unless also updating references.
- If refactoring an existing repo, keep old scripts temporarily and migrate incrementally:
  - Introduce new model + UI
  - Add adapter layer if needed
  - Remove old code only when demo + tests pass
