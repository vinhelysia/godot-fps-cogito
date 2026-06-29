# Dev Log

> Quay về [[🎯 Project Index]]

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
