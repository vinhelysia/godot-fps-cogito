extends Weapon_Resource

class_name MarksmanRifle_Resource

@export_group("Marksman Rifle")
## Camera FOV when fully scoped in (zoomed).
@export var scopedFOV: float = 30.0
## Time in seconds to tween into/out of scope.
@export var scopeInTime: float = 0.3
## Whether to emit scope_changed signal so the HUD can show a scope overlay.
@export var useScopeOverlay: bool = true
## Optional scope overlay texture shown on the HUD while scoped.
@export var scopeOverlayTexture: Texture2D

func get_fire_mode() -> FireMode:
	return FireMode.SEMI
