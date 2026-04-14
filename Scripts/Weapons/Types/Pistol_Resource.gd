extends Weapon_Resource

class_name Pistol_Resource

@export_group("Pistol")
## Minimum time in seconds between trigger pulls (prevents holding fire).
@export var triggerResetTime: float = 0.15

@export_group("Pistol - Hammer Tween")
## Rotation (radians) của hammer ở trạng thái nghỉ.
@export var hammer_rest_rotation: Vector3 = Vector3(0.0, 0.0, 0.0)
## Rotation (radians) của hammer khi đã cocked (giật ra sau khi bắn).
@export var hammer_cocked_rotation: Vector3 = Vector3(-1.0471975, 0.0, 0.0)
## Thời gian (giây) hammer quay ra sau.
@export var hammer_cock_duration: float = 0.05
## Thời gian (giây) hammer trở về nghỉ.
@export var hammer_return_duration: float = 0.12

func get_fire_mode() -> FireMode:
	return FireMode.SEMI

func get_fire_cooldown() -> float:
	return triggerResetTime
