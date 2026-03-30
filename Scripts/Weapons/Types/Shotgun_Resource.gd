extends Weapon_Resource

class_name Shotgun_Resource

@export_group("Shotgun")
## Number of pellets fired per shot.
@export var pelletCount: int = 8
## Spread cone half-angle in degrees when hip-firing.
@export var spreadAngle: float = 4.0
## Spread cone half-angle in degrees when aiming down sights (tighter).
@export var adsSpreadAngle: float = 2.0
## If true, requires a pump animation between shots.
@export var isPump: bool = true
## Animation name for the pump action.
@export var pumpAnimation: String = "pump"
## Duration of the pump cycle in seconds (fallback if animation length differs).
@export var pumpDuration: float = 0.5
## If true, reloads one shell at a time into a tube magazine.
@export var tubeReload: bool = true
## If true, the player can interrupt a tube reload to fire immediately.
@export var canInterruptReload: bool = true

func get_fire_mode() -> FireMode:
	return FireMode.PUMP if isPump else FireMode.SEMI
