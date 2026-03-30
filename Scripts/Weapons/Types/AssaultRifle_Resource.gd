extends Weapon_Resource

class_name AssaultRifle_Resource

@export_group("Assault Rifle")
## Rounds per minute. WeaponManager converts this to a per-shot fire interval.
@export var fireRate: float = 700.0

func get_fire_mode() -> FireMode:
	return FireMode.AUTO
