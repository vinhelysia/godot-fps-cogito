---
name: tarkov-physical-mags-ammo
description: Implement Tarkov-style physical magazines + caliber ammo stacks + mag loading/unloading + weapon insert/swap/reload in Godot 4.6 (C#-first).
argument-hint: "[plan|data|model|ui|demo|save|all] [notes]"
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Edit, Bash(godot*), Bash(dotnet*), Bash(msbuild*), Bash(pwsh*), Bash(sh*), Bash(cmd*)
---

# Tarkov Physical Magazines + Ammo (Caliber-only) — Godot 4.6, C#-first

ultrathink

## Core premise

**Magazines are always physical items.**

- The weapon NEVER stores “ammo count” directly (except optional chamber later).
- Ammo exists as stack items in inventory.
- Mags exist as items in inventory with (capacity, loadedCount, loadedAmmoDefId).
- Weapon fires ONLY by consuming rounds from the inserted magazine instance.

This is the minimum Tarkov loop:
**Loot ammo + mags → load mags → insert mag → shoot → swap mags → unload/repair later**

## Out of scope (don’t do unless explicitly asked)

- Penetration/armor math, ammo subtypes (M855 vs M193), ballistic simulation.
- Complex chamber simulation (keep as mag-only unless the user asks).
- Multiplayer networking.

---

# Operating modes

- `plan`: inspect repo + print a concrete file-by-file plan + TODO checklist.
- `data`: implement/extend Resource defs for Ammo/Mag/Weapon.
- `model`: implement runtime state + deterministic operations (load/unload/insert/swap/fire).
- `ui`: implement inventory UI interactions (drag ammo->mag, mag->weapon slot, unload).
- `save`: persist ammo stacks, mag state, and weapon inserted-mag references.
- `demo`: create a demo scene for manual QA.
- `all` (default): plan → data → model → ui → save → demo → tests.

If $ARGUMENTS is empty, treat as `all`.

---

# Step 0 — Repo discovery (always do first)

Use `Glob` + `Grep` to locate:

- inventory grid model + UI
- item definitions (Resource or custom data)
- any weapon runtime scripts
- any save/load system
- input map actions

Document:

- Existing paths and namespaces.
- What will be extended vs newly created.
- Naming conventions, folder layout, and how items are represented today.

If inventory already has ItemDef + ItemInstance:

- Prefer extending them rather than creating parallel systems.

---

# Target folder structure (preferred)

Adapt if repo already has structure:

- `res://Game/Items/Defs/`
- `res://Game/Items/Runtime/`
- `res://Game/Items/Systems/`
- `res://Game/UI/Inventory/`
- `res://Game/Weapons/`
- `res://Game/Save/`
- `res://Game/Tests/AmmoMag/`
- `res://Game/Demo/AmmoMagDemo/`

---

# Data design (caliber-only)

## Ammo: stackable item

Ammo definition must include:

- `AmmoDef.Id` (stable)
- `AmmoDef.CaliberId` (e.g. "556x45", "762x39", "9x19")
- `AmmoDef.MaxStack` (e.g. 60)

## Magazine: physical item

Magazine definition must include:

- `MagazineDef.Id` (stable)
- `MagazineDef.CaliberId`
- `MagazineDef.Capacity`
- Inventory geometry (size cells, rotate allowed) if you use grid tetris
- Optional: `MagazineDef.TypeId` for future compatibility rules

## Weapon: accepts mags of certain caliber/type

Weapon definition must include:

- Allowed caliber(s) (usually exactly 1 at this stage)
- Optional allowed magazine types list (future-proof)
- Weapon never stores ammo; only holds reference to inserted magazine instance

### Choose implementation style

**Option A (recommended if you already have a single ItemDef):**
Extend `ItemDef` with:

- `ItemKind` enum: Generic, Ammo, Magazine, Weapon, Container
- `string CaliberId`
- `int MaxStack` (Ammo)
- `int MagazineCapacity` (Magazine)
- `string[] AllowedCalibers` (Weapon)
- Optional: `string[] AllowedMagazineTypeIds` (Weapon)

**Option B (recommended if you have no unified def yet):**
Create `AmmoDef : Resource`, `MagazineDef : Resource`, `WeaponDef : Resource`.

Use `[GlobalClass]` + `[Export]` in C# so Resources are editor-friendly.

---

# Runtime state requirements

## Ammo instance

- `defId`
- `stackCount`

## Magazine instance

Persisted fields:

- `defId`
- `loadedCount` (0..capacity)
- `loadedAmmoDefId` ("" if empty; else must match caliber)
  Rules:
- No mixing: if loadedCount > 0, incoming ammo must match loadedAmmoDefId.
- If mag becomes empty after unload, clear loadedAmmoDefId.

## Weapon runtime state (physical mag only)

Weapon runtime must store:

- `insertedMagInstanceId` (int? or 0 meaning none)
  Rules:
- Weapon can fire ONLY if insertedMagInstanceId points to a valid mag with loadedCount > 0.
- Reload means swapping inserted mag with another mag item instance from inventory.
- Weapon itself is not “a container for ammo stacks”.

---

# Model operations — MUST implement

Create service(s) in `res://Game/Items/Systems/`:

- `AmmoMagService` (load/unload/split/merge rules)
- `WeaponMagService` (insert/remove/swap/reload/fire consumption)

These MUST operate on the inventory model, not UI.

## AmmoMagService operations

### 1) CanLoadAmmoIntoMag(ammoId, magId) -> (bool ok, string reason)

Conditions:

- ammo instance exists, is ammo
- mag instance exists, is mag
- ammo caliber == mag caliber
- mag has room
- if mag has loadedCount > 0, ammo def must equal loadedAmmoDefId

### 2) LoadAmmoIntoMag(ammoId, magId, amount = ALL) -> TransferResult

Rules:

- need = capacity - loadedCount
- take = min(need, ammo.stackCount, requested)
- ammo.stackCount -= take
- mag.loadedCount += take
- if mag was empty and take>0: mag.loadedAmmoDefId = ammo.defId
- if ammo.stackCount == 0: remove ammo instance from inventory
  Return:
- takenAmount
- ammoRemaining
- magLoadedAfter
- removedAmmo (bool)

### 3) CanUnloadMag(magId) -> (ok, reason)

- ok only if mag.loadedCount > 0

### 4) UnloadMag(magId, amount = ALL) -> UnloadResult

Rules:

- unload = min(requested, mag.loadedCount)
- move rounds into ammo stacks:
  - first try to merge into existing stacks of same ammo def with available room
  - if remaining > 0, create new ammo stack instance(s) (respect MaxStack)
  - placement: use inventory's "first fit" / "find available slot" deterministically
- mag.loadedCount -= unloaded
- if mag.loadedCount == 0: mag.loadedAmmoDefId = ""
  Return:
- unloadedTotal
- list of affected ammo instance ids (created/merged)
- magLoadedAfter
- failures if no space (must be reported deterministically)

### 5) SplitAmmoStack(ammoId, splitAmount) -> (ok, newAmmoId, reason)

- splitAmount 1..stackCount-1
- create new ammo instance with splitAmount
- subtract from original
- place new instance in inventory (first fit)
- if no fit: revert and fail

### 6) MergeAmmoStacks(sourceAmmoId, targetAmmoId) -> MergeResult

- only if same ammo def
- moves as much as possible up to target MaxStack
- removes emptied source

Determinism:

- when choosing merge targets, sort by instanceId.

---

## WeaponMagService operations (physical mags only)

### 1) CanInsertMag(weaponState, magId) -> (ok, reason)

- mag exists
- mag caliber is allowed by weapon
- optional mag type restrictions
- (optional) weapon has slot free OR can swap

### 2) InsertMag(weaponState, magId, fromInventory) -> InsertResult

Rules:

- mag must be removed from inventory location if your game treats it as equipped
  - simplest: weapon holds instanceId reference but the mag item is "equipped" (not in grid)
  - OR keep mag in a dedicated equipment slot inventory
    Pick one approach and be consistent:
- Recommended: treat inserted mag as being in an equipment slot container.

Return:

- oldMagId (if swapped)
- insertedMagId
- where old mag went (back to inventory / equipment slot)

### 3) EjectMag(weaponState) -> (ok, magId, reason)

- removes inserted mag reference
- mag becomes an item you can place back into inventory (or drops to ground)

### 4) TryReload(weaponState, inventory) -> (ok, reason, swappedOldMagId, insertedNewMagId)

Deterministic selection:

- candidate mags:
  - compatible caliber
  - loadedCount > 0 (prioritize loaded)
- sort by:
  1. highest loadedCount
  2. lowest instanceId
     Then:
- if weapon has mag inserted:
  - swap: put old mag back into inventory (first fit) OR to a "rig slot"
- insert new mag

If no space to store old mag:

- fail reload (or drop old mag if user asked that behavior; default should be FAIL for safety)

### 5) TryFire(weaponState) -> FireResult

Rules:

- if no inserted mag: fail "NO_MAG"
- if inserted mag loadedCount == 0: fail "EMPTY_MAG"
- else:
  - decrement mag.loadedCount by 1
  - if mag.loadedCount becomes 0, keep loadedAmmoDefId or clear? (recommended: keep until unload sets it empty; either is fine but must be consistent)
    Return:
- fired (bool)
- failure reason
- magLoadedAfter

---

# UI requirements (must integrate with existing grid inventory UI)

UI must call services; it must not re-implement rules.

## Inventory interactions

1. Drag ammo stack onto magazine item:
   - attempt LoadAmmoIntoMag(all)
   - if Shift held: load 5/10 (configurable) OR show tiny picker (optional)
2. Right-click magazine:
   - Unload all
   - optional Unload 1/5/10
3. Magazine tooltip/overlay:
   - show `loadedCount/capacity` and caliber

## Weapon interactions (physical mags)

Pick ONE minimal UX for now:

- A dedicated “weapon mag slot” panel showing inserted mag item.
- Drag a mag item onto that slot to insert.
- Drag from that slot back to inventory to remove.
- Press reload key:
  - triggers TryReload (find best mag in inventory) and swaps.

## Feedback

- invalid action shows short reason (wrong caliber, mag full, no space, etc.)
- highlight drop targets in green/red

---

# Save/Load requirements

Persist:

- ammo stack counts
- magazine loadedCount + loadedAmmoDefId
- weapon insertedMagInstanceId
- any equipment-slot inventories used for inserted mags

Use DTO + JSON with:

- `formatVersion`
- stable item instance IDs
- deterministic serialization order (sort by instanceId)

If the project already has save files:

- Add versioning/migration or default values so old saves don't crash.

---

# Tests (headless) — REQUIRED

Create a headless test runner verifying:

1. Wrong caliber load rejects
2. Load respects capacity + stack
3. Mag does not allow mixing ammo type
4. Unload merges to existing stack first
5. Unload creates new stacks respecting MaxStack
6. Split preserves totals
7. Reload chooses best mag deterministically
8. Fire fails without mag; fails with empty mag; succeeds consumes 1
9. Reload fails if no space to store old mag (unless configured to drop)

---

# Demo scene — REQUIRED

Create `AmmoMagDemo.tscn` showing:

- A stash grid with:
  - ammo stacks: 5.56, 7.62x39, 9x19
  - mags: 5.56 30rd, 9mm 17rd, maybe a second 5.56 mag partly loaded
- A weapon panel with a mag slot
- Buttons:
  - Fire (or click to fire)
  - Reload
  - Save/Load

Manual QA checklist must match acceptance-tests.md.

---

# Output requirements

At the end of the run, print:

- Files added/changed
- How to open demo scene
- How to run tests (exact command)
- Known limitations/TODOs (explicit)

---

# Guardrails (keep budget scope)

- Caliber-only ammo now: one ammo def per caliber.
- Weapon consumes from inserted mag only.
- Keep deterministic behavior for future co-op.
- Avoid fancy animation/state machines here; just correct state changes + signals.
