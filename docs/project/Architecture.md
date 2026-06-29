# Architecture — Cogito FPS

> Quay về [[🎯 Project Index]]

## Project layout (bẫy)
- Godot project root **thật**: `C:/Stuff/godot-fps-cogito-master/godot-fps-cogito-master/` (chỗ có `project.godot`).
- Mọi `res://` map vào đây.
- Folder tên sai chính tả nhưng **đúng**: `Weapom` (không phải Weapon), `BulletProjectil&shelle`.
- Main scene: `res://Scene/Town.tscn`.

## Cogito edit policy
- **Được phép sửa `addons/cogito/`** bất cứ khi nào cần (vd shared AI perception trong CogitoNPC). Không còn restriction project-local.
- Lưu ý: sửa cogito = fork khỏi upstream → giữ thay đổi mạch lạc, ghi cái quan trọng vào [[Dev Log]].

## Weapon system (project-local, mạnh)
Chain mỗi súng: `pickup scene → wieldable .tres → weapon scene .tscn → weapon data .tres → projectile scene`.
- Adapter chính: `Scripts/Weapons/cogito_weapon.gd` (`class_name CogitoFirearm extends CogitoWieldable`).
- Data: `Scripts/Weapons/Weapon_Resource.gd` + `Types/*` (AssaultRifle, BoltAction, Shotgun, Pistol, LMG...).
- Mechanical state (mag/chamber): `Scripts/Weapons/Helpers/firearm_mechanical_state.gd`.
- Ammo: `AmmoItemPD.reload_amount` — **project dùng = 1 cho mọi ammo** (45ACP, 7.62x39, 7.62x51).
- Recoil: `Scripts/Weapons/weapon_recoil.gd` (additive shake, non-destructive z — xem [[Dev Log]]).
- Scope: `Scripts/Weapons/scope_controller.gd` (SubViewport camera + shader reticle).

## Inventory (grid, Tarkov-style)
- `InventoryItemPD.item_size: Vector2(w,h)` = footprint; resource **share chung** mọi instance.
- `InventorySlotPD` = per-placement; chứa `origin_index`, **`is_rotated`** + `get_effective_size()` (rotation feature).
- Placement/fit logic: `cogito_inventory.gd` (`is_enough_space`, `null_out_slots`...) — đã route qua `get_effective_size()`.
- UI: `inventory_interface.gd`, `InventoryUI.gd`, `Slot.gd`. Rotation = phím **R** (action `inventory_rotate_item`).

## NPC / AI system (Cogito) — quan trọng cho [[Scav AI Prompt]]
Base: `addons/cogito/CogitoNPC/cogito_npc.tscn` (`class_name CogitoNPC extends CharacterBody3D`).
- Có sẵn: NavigationAgent3D, AnimationTree, custom **state machine** (`npc_state_machine.gd`), HitboxComponent + CogitoHealthAttribute, **SecurityCamera** (Area3D+RayCast = perception), alert indicator, footsteps, persistence.
- States: `idle`, `patrol_on_path`, `move_to_random_pos`, `chase`, `attack`, `switch_stance`.
- SM API: states là child Node; chỉ state hiện tại được mount để nhận `_physics_process`. Hooks: `_state_enter/_state_exit/_physics_process`. Inject `Host` (NPC) + `States` (SM). Chuyển: `States.goto("name")`, `load_previous_state()`.
- `chase` **tái dùng được**: đọc `Host.attention_target`, nav tới, gần thì `goto(action_when_caught)`.
- `attack` là **MELEE** (RaisedFists, range ≤1.5) → KHÔNG dùng cho scav, cần ranged state mới.

### Damage flow
- **IN (player → NPC):** hitscan `Weapon_Resource._deal_damage` → `collider.damage_received.emit(dmg,dir,pos)` → `HitboxComponent` → `health_attribute.subtract()`. Hoạt động nếu NPC có signal `damage_received` + HitboxComponent + HealthAttribute (demo scene có).
- **OUT (NPC → player):** `CogitoPlayer` (group `"Player"`) có `take_damage(amount)`, `decrease_attribute("health", v)`, `apply_external_force(vec)`. Head = `$Body/Neck/Head`.
- **Death + loot:** `CogitoHealthAttribute` emit `signal death()` ở 0 HP. `Components/LootComponent.gd` nghe `death` → spawn loot (SPAWN_ITEM / SPAWN_CONTAINER) từ `LootTable`. Ragdoll: `mannequin_ragdoll.tscn`.

### ⚠️ CogitoNPC — wiring & bug nền
1. **✅ ĐÍNH CHÍNH (KHÔNG phải bug):** Detection→chase **ĐÃ wire** bằng **scene connection** trong `cogito_npc.tscn`:
   `[connection signal="object_detected" from="SecurityCamera" to="NPC_State_Machine" method="goto" binds=["chase"]]`.
   Grep `.gd` không thấy vì nó nằm trong `.tscn` (dùng `binds`). **Bài học:** wiring/signal kiểu này phải check `[connection]` trong `.tscn`, đừng chỉ grep code GDScript.
2. **THẬT:** `cogito_security_camera.gd::stop_detecting()` dùng `get_parent() == CogitoNPC` (so instance với class → luôn false) → attention_target không tự clear. `Scripts/Enemies/scav.gd` fix bằng connect `object_no_longer_detected` → clear `attention_target`.
3. SecurityCamera emit cả `object_detected` (no-arg) lẫn `send_detected_object(obj)` → connect cái có arg khi cần object node.
