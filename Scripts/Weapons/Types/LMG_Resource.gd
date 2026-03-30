extends Weapon_Resource

class_name LMG_Resource

@export_group("LMG")
## Rounds per minute.
@export var fireRate: float = 600.0
## Heat added per shot (0.0–1.0 scale; 1.0 = fully overheated).
@export var heatPerShot: float = 0.05
## Heat dissipated per second while trigger is released (passive cooling).
@export var cooldownRate: float = 0.1
## Heat dissipated per second while actively venting (hold Reload).
@export var ventRate: float = 0.4
## Animation to play while venting heat.
@export var ventAnimation: String = "vent_heat"

func get_fire_mode() -> FireMode:
	return FireMode.AUTO
