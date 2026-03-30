extends Weapon_Resource

class_name BoltAction_Resource

@export_group("Bolt Action")
## Animation name for the bolt cycling action played after each shot.
@export var boltCycleAnimation: String = "bolt_cycle"
## Duration of the bolt cycle in seconds (used as fallback if no animation).
@export var boltCycleDuration: float = 0.8

func get_fire_mode() -> FireMode:
	return FireMode.BOLT_ACTION
