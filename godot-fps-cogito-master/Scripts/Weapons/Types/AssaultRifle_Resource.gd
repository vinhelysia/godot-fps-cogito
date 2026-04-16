extends Weapon_Resource

class_name AssaultRifle_Resource

@export_group("Assault Rifle")
## Rounds per minute. Converted to per-shot interval via get_fire_cooldown().
@export var fireRate: float = 700.0

func get_fire_mode() -> FireMode:
	return FireMode.AUTO

func get_fire_cooldown() -> float:
	return 60.0 / fireRate
