extends Weapon_Resource

class_name Revolver_Resource

@export_group("Revolver")
## Number of chambers (typically 6).
@export var cylinderCapacity: int = 6
## If true, reload loads individual rounds one at a time (gate loading).
## If false, full cylinder swap via speed loader uses standard reload animation.
@export var gateLoad: bool = false
## Time per single round during gate-load reload.
@export var singleRoundLoadTime: float = 0.5
## Animation to play for each individual round loaded.
@export var singleRoundAnimation: String = "load_single"

func get_fire_mode() -> FireMode:
	return FireMode.REVOLVER
