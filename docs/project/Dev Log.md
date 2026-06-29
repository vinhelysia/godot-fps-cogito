# Dev Log

> Quay về [[🎯 Project Index]]

## 2026-06-29 — Rebuild Scav AI with LimboAI & Fix Navigation Mesh

### Rebuilt Scav AI onto LimboAI
- **Perception (SENSE)**:
  - Created [scav_perception.gd](file:///C:/Stuff/godot-fps-cogito-master/godot-fps-cogito-master/Scripts/Enemies/scav_perception.gd) (replaces old `CogitoPerception`). Implements 120° FOV vision with 3-point raycast LOS (head, chest, pelvis) and a global `SoundEvents` bus listener for hearing.
  - Implements self-hearing prevention (ignores sounds from host or its children) and scales hearing range based on sound loudness.
- **Blackboard / State (THINK)**:
  - Configured `BlackboardPlan` in [Scav.tscn](file:///C:/Stuff/godot-fps-cogito-master/godot-fps-cogito-master/Scene/Enemies/Scav.tscn) with all variables declared (`target`, `last_known_position`, `has_last_known`, `heard_position`, `awareness`, `alert_state`, `ammo`, `reloading`, `engage_range`, `last_strafe_time`) to eliminate runtime "Variable not found" warnings.
  - Built [scav_brain.tres](file:///C:/Stuff/godot-fps-cogito-master/godot-fps-cogito-master/Scene/Enemies/BT/scav_brain.tres) Behavior Tree programmatically in the editor.
  - Uses `BTCondition` nodes at the start of each `BTSelector` branch to ensure immediate preemption when alert states change (e.g. going from patrol to combat).
- **BT Tasks (ACT)**:
  - Created custom tasks in `Scripts/Enemies/BT/Tasks/`:
    - [bt_move_to.gd](file:///C:/Stuff/godot-fps-cogito-master/godot-fps-cogito-master/Scripts/Enemies/BT/Tasks/bt_move_to.gd): Navigates to destination using `NavigationAgent3D`.
    - [bt_face_target.gd](file:///C:/Stuff/godot-fps-cogito-master/godot-fps-cogito-master/Scripts/Enemies/BT/Tasks/bt_face_target.gd): Smoothly rotates the host to face the target.
    - [bt_shoot.gd](file:///C:/Stuff/godot-fps-cogito-master/godot-fps-cogito-master/Scripts/Enemies/BT/Tasks/bt_shoot.gd): Handles burst shooting, recoil/spread, damage, and fire rate.
    - [bt_reload.gd](file:///C:/Stuff/godot-fps-cogito-master/godot-fps-cogito-master/Scripts/Enemies/BT/Tasks/bt_reload.gd): Reloads the weapon and updates the blackboard.
    - [bt_look_around.gd](file:///C:/Stuff/godot-fps-cogito-master/godot-fps-cogito-master/Scripts/Enemies/BT/Tasks/bt_look_around.gd): Rotates left and right to search the area.
    - [bt_strafe.gd](file:///C:/Stuff/godot-fps-cogito-master/godot-fps-cogito-master/Scripts/Enemies/BT/Tasks/bt_strafe.gd): Moves side-to-side during combat to avoid being hit.
    - [bt_patrol.gd](file:///C:/Stuff/godot-fps-cogito-master/godot-fps-cogito-master/Scripts/Enemies/BT/Tasks/bt_patrol.gd): Walks along the `CogitoPatrolPath`.
    - [btc_alert_at_least.gd](file:///C:/Stuff/godot-fps-cogito-master/godot-fps-cogito-master/Scripts/Enemies/BT/Tasks/btc_alert_at_least.gd) & [btc_has_last_known.gd](file:///C:/Stuff/godot-fps-cogito-master/godot-fps-cogito-master/Scripts/Enemies/BT/Tasks/btc_has_last_known.gd): Custom blackboard conditions.

### Navigation Mesh & Spawn Fix in Town.tscn
- **Group-Based Bake**:
  - Switched `Town/NavigationRegion3D` to group-based geometry sourcing (`GROUPS_WITH_CHILDREN`) using group `"navmesh_source"` and geometry type `BOTH` (meshes + static colliders).
  - Added `NavigationRegion3D/Geometry` (floor), `House1` (house obstacle), `Crate` (prop obstacle), and `KSI_counter` (prop obstacle) to the `"navmesh_source"` group.
  - Successfully baked the NavigationMesh with **21 vertices** and **15 polygons**, covering the entire interior of `House1` and carving out obstacles.
- **Spawn Relocation**:
  - Relocated the `Scav` starting position in [Town.tscn](file:///C:/Stuff/godot-fps-cogito-master/godot-fps-cogito-master/Scene/Town.tscn) to `(36, 0.05, -30)` (inside the house at `PatrolA`) to ensure it starts on the baked NavigationMesh rather than outside of it (near the wall).

---

## 2026-06-28 — Scav enemy AI (first hostile enemy)

### Files created
- `Scripts/Enemies/scav.gd` — extends CogitoNPC; fixes Bug #2 (attention_target never cleared); minimal project-local override.
- `Scripts/Enemies/States/npc_state_shoot.gd` — ranged shoot state; PhysicsDirectSpaceState3D LOS + spread; burst/reload cycle; exports: fire_rate, damage, accuracy, min/max_engage_range, reload_time, burst_count, los_timeout.
- `Scene/Enemies/Scav.tscn` — inherited from cogito_npc.tscn; HP=80; "shoot" state added to NPC_State_Machine; chase.action_when_caught="shoot", target_action_distance=12m; Muzzle Marker3D; LootComponent (SPAWN_CONTAINER, 2 items).
- `Scene/Enemies/LootTables/scav_loot_table.tres` — GUARANTEED 5-15× 7.62x39mm + CHANCE 2-6× 7.62x51mm.

### Modified
- `Scene/Town.tscn` — added: NavigationRegion3D (needs NavMesh bake in editor), ScavPatrolPath (3 points near X:36-44, Z:-25 to -37), Scav instance at (36, 1.2, -32).

### Architecture notes
- Bug #1 (detection→chase NOT wired): Architecture.md was WRONG — cogito_npc.tscn already has `object_detected → NPC_State_Machine.goto("chase")` as a scene connection. No fix needed.
- Bug #2 (attention_target never cleared): Fixed in scav.gd via `object_no_longer_detected → _on_detection_lost`.
- Death: handled entirely by CogitoHealthAttribute (destroy_on_death=root, spawn_on_death=ragdoll). LootComponent listens independently and spawns loot_chest at death position.

### ⚠️ Manual step required
**NavigationMesh must be baked in Godot editor:** open Town.tscn → select NavigationRegion3D → click "Bake NavigationMesh". Without this the Scav won't path.

---

## 2026-06-28 — Repo cleanup, audit fixes, inventory rotation

### Repo / branches
- Remote `vinhelysia/godot-fps-cogito` dọn còn **chỉ branch `master`** (xóa `main` + `claude/code-review-improvements-TBIBj`).
- `master` đã **flatten**: game project nâng lên root, bỏ rác wrapper (AI configs, server/output/tmp, jpg trùng, .tmp leftovers).
- ⚠️ Local `main` (layout cũ, code "finishing the usp") **divergent** với remote `master` (flatten + code mới hơn: WeaponAnimationTable). Đưa fix lên master = reconcile thủ công, **chưa làm**.

### Audit → fixes (commit `13d1d11` trên local main)
Tất cả verify static (chưa runtime). Fix:
- **Loot:** `_is_unique_found` / `_count_quest_items` giờ match đúng item (trước: 1 unique sở hữu chặn MỌI unique drop). Cache scene lookup 1 lần/pass.
- **debug_log:** thêm `is_debug_logging()`; guard hot-path security camera (đỡ build string mỗi tick).
- **footstep:** cache material theo `(collider, cell)` + weakref cleanup; giữ đúng material đa-surface.
- **recoil:** non-destructive z (restore prev z) + additive shake roll (không clobber external roll).
- **ammo:** trả ammo dư khi reload (inert vì reload_amount=1, future-proof).
- **godot_mcp:** service tự `queue_free()` ở release build (không lọt vào game ship).
- **cleanup:** xóa `.tmp`, `node_3d.gd` orphan; normalize indentation player.

### Inventory rotation (commit `f85b6e6` trên local main)
- Xoay item grid 0°↔90° bằng **R** (Tarkov-style). State `is_rotated` per-slot trên `InventorySlotPD` + `get_effective_size()`.
- Placement validate footprint xoay qua `is_enough_space()`. Persist qua `@export`.
- ⚠️ **Snap tức thì, chưa có tween mượt** (spec ban đầu muốn tween ~0.12s) — TODO polish.

### Git state hiện tại (local)
```
f85b6e6  Add grid-inventory item rotation   ← rotation
13d1d11  Fix Cogito loot/perf bugs + ...     ← fixes
ea5f3d3  finishing the usp                   ← gốc
```
Branch `fixes/cogito-audit` đã merge vào `main` (redundant, có thể xóa).

### Đang chạy
- **Scav AI** giao Sonnet → [[Scav AI Prompt]].

## TODO ngắn hạn
- [ ] Runtime verify fixes + rotation trong Godot editor (Errors panel sạch + 4 manual test).
- [ ] Thêm tween mượt cho rotation.
- [ ] Reconcile fixes/rotation lên remote `master`.
- [ ] Implement scav (Phase 1 của [[Roadmap]]).
