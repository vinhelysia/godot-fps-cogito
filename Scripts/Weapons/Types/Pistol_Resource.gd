extends Weapon_Resource

class_name Pistol_Resource

@export_group("Pistol")
## Minimum time in seconds between trigger pulls (prevents holding fire).
@export var triggerResetTime: float = 0.15

func get_fire_mode() -> FireMode:
	return FireMode.SEMI

func get_fire_cooldown() -> float:
	return triggerResetTime
