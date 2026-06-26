extends Weapon_Resource

class_name LMG_Resource

@export_group("LMG")
## Rounds per minute.
@export var fireRate: float = 600.0
## Heat added per shot (0.0-1.0 scale; 1.0 = fully overheated).
@export var heatPerShot: float = 0.05
## Heat dissipated per second while trigger is released (passive cooling).
@export var cooldownRate: float = 0.1
## Heat dissipated per second while actively venting (hold Reload).
@export var ventRate: float = 0.4
## Animation to play while venting heat.
@export var ventAnimation: String = "vent_heat"

func get_fire_mode() -> FireMode:
	return FireMode.AUTO

func get_fire_cooldown() -> float:
	return 60.0 / fireRate

func can_fire(state: Dictionary) -> bool:
	return state.get("current_heat", 0.0) < 1.0

func on_reload(ctx: Dictionary) -> bool:
	var current_heat: float = ctx.get("current_heat", 0.0)
	if current_heat <= 0.0:
		return false
	# LMG reload = vent heat, not ammo swap
	ctx["start_venting"] = true
	ctx["vent_animation"] = ventAnimation
	return true


func tick(weapon: Node, delta: float) -> void:
	var firearm := weapon as CogitoFirearm
	var venting := firearm._state == CogitoFirearm.WeaponState.VENTING
	# Passive cooling while trigger released and not actively venting.
	if not firearm._trigger_held and not venting:
		firearm._current_heat = maxf(0.0, firearm._current_heat - cooldownRate * delta)
	# Active venting (Reload-held).
	if venting:
		firearm._current_heat = maxf(0.0, firearm._current_heat - ventRate * delta)
		if firearm._current_heat <= 0.0:
			firearm._state = CogitoFirearm.WeaponState.IDLE


func play_post_fire_visual(weapon: Node) -> void:
	# Heat accumulation runs after every shot.  No tween required.
	var firearm := weapon as CogitoFirearm
	firearm._current_heat = minf(1.0, firearm._current_heat + heatPerShot)
	if firearm._current_heat >= 1.0:
		firearm._trigger_held = false


func on_anim_finished(weapon: Node, anim_name: StringName) -> void:
	if anim_name != ventAnimation:
		return
	var firearm := weapon as CogitoFirearm
	firearm._state = CogitoFirearm.WeaponState.IDLE
	firearm._capture_rest_state()
