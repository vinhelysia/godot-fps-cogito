---
name: tarkov-ammo-magazines-lite
description: Implement caliber-based ammo + magazines + loading/unloading + reload wiring for a Tarkov-like inventory in Godot 4.6 (C#-first, single-player).
argument-hint: "[plan|data|model|ui|demo|save|all] [notes: ...]"
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Edit, Bash(godot*), Bash(dotnet*), Bash(msbuild*), Bash(pwsh*), Bash(sh*), Bash(cmd*)
---

# Tarkov Ammo + Magazines (Lite) — Godot 4.6, C#-first

ultrathink

## Purpose
When invoked, implement or refactor the project so it supports:
- Ammo items by **caliber** (e.g., 5.56x45, 7.62x39, 9x19).
- Magazines as inventory items with **capacity** and **loaded count**.
- Loading ammo stacks into magazines via inventory UI (drag/drop and/or context menu).
- Unloading magazines back into ammo stacks.
- Basic reload wiring to weapon runtime (minimal; no penetration, no ballistic sim).

**Out of scope (do NOT implement unless explicitly requested):**
- Ammo subtypes (M855 vs M193), penetration, armor math, fragmentation.
- Multiplayer networking.
- Complex weapon chamber simulation beyond “mag loaded count” (keep simple).

## Ground rules (non-negotiables)
1) Core rules live in the **model layer**, not UI.
2) All operations must be deterministic and serialization-friendly (for future co-op).
3) Wrong-caliber loads must be rejected cleanly.
4) No per-frame allocations in hot loops (loading/placement).
5) Any new data format must be versioned for future migrations.

## Operating modes
- `plan`: inspect repo and output a file-by-file plan + checklist before editing.
- `data`: implement `Resource` definitions for Ammo/Mag/Weapon (or extend existing item defs).
- `model`: implement runtime state + operations (load/unload/merge/split).
- `ui`: implement inventory UI interactions (drag ammo -> mag, unload mag).
- `demo`: add a demo scene to validate manually.
- `save`: ensure save/load persists magazine loaded count and ammo stacks.
- `all` (default): run plan → data → model → ui → demo → save → tests.

If $ARGUMENTS is empty, treat as `all`.

---

# Step 0 — Repo discovery (always do first)
Use `Glob`/`Grep` to locate:
- Existing inventory model classes (grid, item instance, item definition).
- Existing item data system (Resources? JSON? Scriptable objects?).
- Existing weapon runtime (even a stub).
- Existing inventory UI (Control nodes, drag/drop, custom hold logic).
- Save system (JSON? ConfigFile? custom).

Write down:
- Current folders and key files.
- What you will extend vs what you will create new.
- Any naming conventions you must follow.

**If existing item definitions already exist:**
Prefer extending them with ammo/mag fields instead of creating parallel systems.

---

# Target architecture (preferred)
Keep this structure (adapt if repo already has a pattern):
- `res://Game/Items/Defs/` (Resources: AmmoDef, MagazineDef, WeaponDef OR unified ItemDef)
- `res://Game/Items/Runtime/` (runtime state: ItemInstance extensions, MagazineState, WeaponState)
- `res://Game/Items/Systems/` (operations: AmmoMagService, ReloadService)
- `res://Game/UI/Inventory/` (Controls and UI glue)
- `res://Game/Tests/AmmoMag/` (headless tests)
- `res://Game/Demo/AmmoMagDemo/` (demo scene)

---

# Data design (Lite, caliber-first)
## Option A (preferred if you already have a single ItemDef):
Extend your existing `ItemDef` Resource with:
- `ItemKind` enum: Generic, Ammo, Magazine, Weapon, Container
- `string CaliberId` (for Ammo + Magazine + Weapon)
- `int MaxStack` (Ammo)
- `int MagazineCapacity` (Magazine)
- (optional) `string[] AllowedCalibers` (Weapon; for now usually 1)

## Option B (preferred if you don’t have ItemDef yet OR you like clean editor UX):
Create separate Resource types:
- `AmmoDef : Resource` (Id, DisplayName, Icon, CaliberId, MaxStack)
- `MagazineDef : Resource` (Id, DisplayName, Icon, CaliberId, Capacity, SizeCells, CanRotate)
- `WeaponDef : Resource` (Id, DisplayName, Icon, AllowedCaliberIds[], optional MagTypeIds[])

For C# Resources, use `[GlobalClass]` and `[Export]` so they show up in Create Resource and Inspector. (See reference.md.) 

---

# Runtime state requirements
## Ammo item instance
- `defId` points to ammo definition
- `stackCount` current amount

## Magazine item instance
Must persist:
- `loadedCount` (0..capacity)
- `loadedAmmoDefId` (string; for now it will equal the caliber’s ammo def id)
Rules:
- If `loadedCount == 0`, `loadedAmmoDefId` may be empty.
- If `loadedCount > 0`, `loadedAmmoDefId` must be set and must match mag caliber.

## Weapon runtime
Minimal integration:
- Weapon has `InsertedMagazineInstanceId` (or null).
- Firing decrements mag loadedCount.
- Reload swaps inserted mag with another compatible mag from inventory (simple heuristic).

---

# Core operations (MODEL) — must implement
Create a service class (name it to match project style), e.g. `AmmoMagService`.

### 1) CanLoadAmmoIntoMag(ammoInstance, magInstance) -> result
Return:
- ok / not-ok + reason string (for UI)
Rules:
- ammo is Ammo kind
- mag is Magazine kind
- ammo caliber matches mag caliber
- if mag has `loadedCount > 0`, ammo must match `loadedAmmoDefId` (no mixing)

### 2) LoadAmmoIntoMag(ammoInstanceId, magInstanceId, requestedAmountOrAll) -> TransferResult
Transfers from ammo stack to mag:
- `need = capacity - loadedCount`
- `take = min(need, ammoStackCount, requested)`
- decrement ammo stack by take
- increment mag loadedCount by take
- if mag was empty, set loadedAmmoDefId
- if ammo stack becomes 0, remove the ammo item instance from inventory

Return TransferResult:
- takenAmount
- remainingInAmmo
- magLoadedAfter
- didRemoveAmmoItem

### 3) CanUnloadMag(magInstance) -> result
- ok only if loadedCount > 0

### 4) UnloadMagToAmmoStack(magInstanceId, requestedAmountOrAll) -> result
Moves rounds from mag into an ammo stack:
- Prefer merging into an existing ammo stack of same ammo def with room.
- Otherwise create a new ammo stack item instance in inventory (find first fit / any available slot).
- Decrement mag loadedCount.
- If mag becomes 0, clear loadedAmmoDefId.

Return:
- unloadedAmount
- createdNewStack (bool)
- affectedAmmoInstanceId (id)
- magLoadedAfter

### 5) SplitAmmoStack(ammoInstanceId, splitAmount) -> newAmmoInstanceId or failure
- splitAmount must be 1..stackCount-1
- create new ammo instance with splitAmount
- decrement original stack
- place new instance into inventory (first-fit)

### 6) Reload heuristic (minimal)
Implement `ReloadService.TryReloadWeapon(playerWeapon, sourceInventory)`:
- Identify weapon’s allowed caliber(s).
- Search for a compatible magazine with `loadedCount > 0`.
- If found:
  - If weapon already has a mag inserted, swap mags (old mag returns to inventory).
  - Insert new mag.
- If none found, return failure with reason.
Keep this deterministic:
- Sort candidate mags by (highest loadedCount) then by stable instanceId.

**Do not** implement complex animations; just state changes + signals.

---

# UI integration requirements
You can implement drag-and-drop using Godot Control APIs:
- `_get_drag_data`
- `_can_drop_data`
- `_drop_data`
These are standard on `Control`. (See reference.md.) 

UI behaviors to implement:
1) Drag ammo stack onto magazine:
   - If CanLoad ok, load (all by default).
   - If Shift held, prompt/choose partial load (optional; if skipping prompt, load a fixed small amount like 5/10 is acceptable).
2) Right-click magazine:
   - “Unload” (all).
   - Optional: “Unload 1/5/10”.
3) Visual feedback:
   - Magazine tooltip shows `loadedCount/capacity` and caliber.
   - On invalid drop, show red highlight and a brief reason.

UI MUST NOT duplicate rule checks; it must call the model/service.

---

# Save/Load requirements
- Ensure magazine `loadedCount` and `loadedAmmoDefId` persist.
- Ensure ammo stack count persists.
- Version your save DTO: `formatVersion`.
- If project already has save data, add a migration path or keep backward-compatible defaults.

---

# Tests + Demo (must ship with the implementation)
## Headless tests (minimum)
Create a headless runnable test runner that verifies:
- Wrong caliber load fails.
- Load respects capacity.
- Load respects ammo stack count.
- No mixing ammo types inside a mag.
- Unload merges into existing stack when possible.
- Unload creates new stack if none available.
- Split works and preserves totals.
- Reload picks the correct magazine deterministically.

## Demo scene (minimum)
Create a demo scene that spawns:
- 3 ammo stacks: 5.56x45, 7.62x39, 9x19
- 2 magazines: one 5.56 mag (30), one 9mm mag (17)
- 1 weapon compatible with 5.56
And allows:
- Loading ammo into mag via UI
- Inserting mag into weapon slot (or pressing a button)
- Firing decreases mag count
- Reload swaps to another mag if present
- Save/load roundtrip for magazine counts

---

# Output format (always)
At end, print:
- Files added/changed
- How to open demo scene
- Exact command to run headless tests
- Known limitations/TODOs

---

# Guardrails to prevent “big Tarkov scope”
- Only caliber-based ammo now (one ammo def per caliber).
- Keep magazine state as (loadedCount + loadedAmmoDefId).
- Keep reload deterministic and simple.
- Keep UI minimal and functional.