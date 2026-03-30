extends Weapon_Resource

class_name GrenadeLauncher_Resource

@export_group("Grenade Launcher")
## Grenade projectile scene. Always fires as a projectile, ignoring the Type flag.
@export var grenadeScene: PackedScene
## Upward launch angle in degrees added to the camera forward vector.
@export var launchAngle: float = 25.0
## Initial projectile speed in m/s.
@export var launchVelocity: float = 20.0
## Fuse duration in seconds before detonation (0 = impact detonation only).
@export var fuseDuration: float = 3.0
## Explosion radius in metres.
@export var blastRadius: float = 5.0
## Optional explosion VFX scene spawned on detonation.
@export var explosionScene: PackedScene

func get_fire_mode() -> FireMode:
	return FireMode.SEMI
