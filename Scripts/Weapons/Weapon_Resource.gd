extends Resource

class_name Weapon_Resource


@export var weaponName: String
@export_group("Recoil")
@export var recoilVertical: float
@export var recoilHorizontal: float
@export var recoilRecovery: float
	


@export_flags("Hitscan", "Projectile") var Type
@export var bulletProjectileToLoad: PackedScene
@export var weaponVelocity: int

# ── Fire Mode ──────────────────────────────────────────────────────────────────
enum FireMode { SEMI, AUTO, BOLT_ACTION, PUMP, REVOLVER }
func get_fire_mode() -> FireMode:
	return FireMode.SEMI
