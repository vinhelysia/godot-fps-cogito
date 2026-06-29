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

## NPC / AI system (LimboAI Refactor) — extraction-shooter AI
Hệ thống AI của Scav đã được tái cấu trúc từ State Machine cũ của Cogito sang **LimboAI (Behavior Tree + Blackboard + Perception Sensor)**:

### 1. SENSE (Perception Layer)
- **Vision (Tầm nhìn)**: [scav_perception.gd](file:///C:/Stuff/godot-fps-cogito-master/godot-fps-cogito-master/Scripts/Enemies/scav_perception.gd) thay thế `SecurityCamera` mặc định.
  - Sử dụng FOV 120° để phát hiện Player.
  - Kiểm tra LOS bằng cơ chế multi-point raycast quét qua 3 điểm trên Player (head, chest, pelvis) để tránh bị cản bởi chướng ngại vật nhỏ.
  - Tốc độ tích luỹ độ nghi ngờ (awareness) tỷ lệ nghịch với khoảng cách và phụ thuộc vào tư thế của Player (crouch = 50% speed, stand = 100%, sprint = 150%).
- **Hearing (Thính giác)**:
  - Sử dụng hệ thống bus sự kiện âm thanh toàn cục [sound_events.gd](file:///C:/Stuff/godot-fps-cogito-master/godot-fps-cogito-master/Scripts/Enemies/sound_events.gd) (`SoundEvents`).
  - Lắng nghe các âm thanh phát ra trong thế giới (footsteps, gunshots).
  - Có cơ chế **ngăn tự nghe chính mình** (self-hearing prevention) bằng cách bỏ qua các âm thanh do chính host hoặc các node con của host phát ra.
  - Cập nhật `heard_position` và đẩy trạng thái cảnh giác lên ít nhất là ALERT (0.5) khi nghe thấy âm thanh trong phạm vi hiệu dụng.

### 2. THINK (Behavior Tree & Blackboard)
- **Blackboard (Bảng nhớ)**: Toàn bộ trạng thái của AI được lưu trữ trên Blackboard của `BTPlayer` (được cấu hình trong [Scav.tscn](file:///C:/Stuff/godot-fps-cogito-master/godot-fps-cogito-master/Scene/Enemies/Scav.tscn)):
  - `target` (Node3D): Đối tượng đang bị nhắm tới.
  - `last_known_position` (Vector3) & `has_last_known` (bool): Vị trí cuối cùng nhìn thấy/nghe thấy mục tiêu.
  - `heard_position` (Vector3): Vị trí nghe thấy tiếng động.
  - `awareness` (float): Mức độ cảnh giác (0.0 -> 1.0).
  - `alert_state` (int): Trạng thái cảnh báo (0: CALM, 1: SUSPICIOUS, 2: ALERT, 3: COMBAT).
  - `ammo` (int) & `reloading` (bool): Trạng thái đạn dược của Scav.
  - `engage_range` (float): Khoảng cách chiến đấu (mặc định 15.0m).
- **Behavior Tree**: Cấu hình trong [scav_brain.tres](file:///C:/Stuff/godot-fps-cogito-master/godot-fps-cogito-master/Scene/Enemies/BT/scav_brain.tres) với cấu trúc phân cấp:
  - **Preemption (Ngắt ưu tiên)**: Mỗi nhánh chính (Combat, Investigate, Patrol) bắt đầu bằng một `BTCondition` (ví dụ: `btc_alert_at_least.gd`) đóng vai trò làm guard để đảm bảo preemption lập tức khi trạng thái thay đổi.
  - **Combat Branch**: Thực hiện ngắm bắn mục tiêu, bắn loạt (burst shoot), tự động lùi lại nạp đạn khi hết đạn, di chuyển áp sát nếu mục tiêu ngoài tầm bắn, và thỉnh thoảng di chuyển né tránh (`BTStrafe`).
  - **Investigate Branch**: Di chuyển tới vị trí nghi ngờ cuối cùng, thực hiện quét mắt nhìn quanh tìm kiếm (`BTLookAround`) trong 4 giây trước khi hạ cảnh giác về CALM.
  - **Patrol Branch**: Tuần tra dọc theo [ScavPatrolPath](file:///C:/Stuff/godot-fps-cogito-master/godot-fps-cogito-master/Scene/Town.tscn) (3 điểm tuần tra).

### 3. ACT (Custom BT Tasks)
Các hành động cụ thể của AI được triển khai trong thư mục `Scripts/Enemies/BT/Tasks/`:
- [bt_move_to.gd](file:///C:/Stuff/godot-fps-cogito-master/godot-fps-cogito-master/Scripts/Enemies/BT/Tasks/bt_move_to.gd): Giao tiếp với `NavigationAgent3D` để tìm đường di chuyển.
- [bt_face_target.gd](file:///C:/Stuff/godot-fps-cogito-master/godot-fps-cogito-master/Scripts/Enemies/BT/Tasks/bt_face_target.gd): Quay mặt về phía mục tiêu.
- [bt_shoot.gd](file:///C:/Stuff/godot-fps-cogito-master/godot-fps-cogito-master/Scripts/Enemies/BT/Tasks/bt_shoot.gd): Thực hiện raycast bắn, gây sát thương lên Player, tính toán độ giật/độ lệch đạn (spread).
- [bt_reload.gd](file:///C:/Stuff/godot-fps-cogito-master/godot-fps-cogito-master/Scripts/Enemies/BT/Tasks/bt_reload.gd): Chờ nạp đạn và hồi lại số lượng đạn trên blackboard.
- [bt_strafe.gd](file:///C:/Stuff/godot-fps-cogito-master/godot-fps-cogito-master/Scripts/Enemies/BT/Tasks/bt_strafe.gd): Di chuyển né tránh ngẫu nhiên sang trái/phải trong khi chiến đấu.
- [bt_look_around.gd](file:///C:/Stuff/godot-fps-cogito-master/godot-fps-cogito-master/Scripts/Enemies/BT/Tasks/bt_look_around.gd): Quay trái quay phải để tìm kiếm mục tiêu tại điểm điều tra.
- [bt_patrol.gd](file:///C:/Stuff/godot-fps-cogito-master/godot-fps-cogito-master/Scripts/Enemies/BT/Tasks/bt_patrol.gd): Di chuyển tuần tra qua các điểm được cấu hình trong `patrol_path`.

### 4. Damage & Death Flow
- **Nhận sát thương**: Vẫn sử dụng cơ chế của Cogito thông qua `HitboxComponent` và `CogitoHealthAttribute`. Khi nhận sát thương, Scav sẽ lập tức bị kéo vào trạng thái chiến đấu nếu có kẻ tấn công.
- **Cái chết**: Kết nối tín hiệu `death` từ `CogitoHealthAttribute` của Scav để dừng hoàn toàn `BTPlayer`, giải phóng va chạm vật lý để chuyển sang trạng thái ragdoll và kích hoạt `LootComponent` rơi đồ.
- **Loot**: Rơi đồ từ `scav_loot_table.tres` (đảm bảo rơi đạn 7.62x39mm và tỉ lệ rơi thêm đạn 7.62x51mm).
