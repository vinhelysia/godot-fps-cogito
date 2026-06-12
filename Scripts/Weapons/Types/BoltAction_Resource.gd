extends Weapon_Resource

class_name BoltAction_Resource

@export_group("Bolt Action")
## Animation name for the bolt cycling action played after each shot.
@export var boltCycleAnimation: String = "bolt_cycle"
## Duration of the bolt cycle in seconds (used as fallback if no animation).
@export var boltCycleDuration: float = 0.8

@export_group("Bolt Tween")
## Bolt handle rotation when locked/closed (radians). Match the rest keyframe in your AnimationPlayer.
@export var bolt_locked_rotation: Vector3 = Vector3(-0.39269873, 0.0, -1.570796)
## Bolt handle rotation when unlocked/open.
@export var bolt_unlocked_rotation: Vector3 = Vector3(-1.2234758, 0.0017453292, -1.5742869)
## Bolt position when fully forward (chambered).
@export var bolt_position_forward: Vector3 = Vector3(0.05584554, 0.059166227, 0.0)
## Bolt position when fully back (ejected).
@export var bolt_position_back: Vector3 = Vector3(-0.1278401, 0.059375823, -0.0010124445)
## Duration in seconds for each bolt phase.
@export var bolt_unlock_duration: float = 0.2
@export var bolt_pull_duration: float = 0.233
@export var bolt_hold_duration: float = 0.2
@export var bolt_push_duration: float = 0.167
@export var bolt_lock_duration: float = 0.233
## Root viewmodel position offset at peak of bolt cycle (applied relative to current position).
@export var bolt_root_position_offset: Vector3 = Vector3(-0.137, -0.032, 0.032)
## Root viewmodel rotation offset at peak of bolt cycle (radians, applied relative to current rotation).
@export var bolt_root_rotation_offset: Vector3 = Vector3(-0.2617994, 0.0174532, 0.034906585)
## Time to ease the viewmodel out to the bolt-cycle peak offset.
@export var bolt_root_out_duration: float = 0.5
## Time to ease the viewmodel back to its rest pose after the bolt closes.
@export var bolt_root_return_duration: float = 0.7

@export_group("Shell Ejection Timing")
## Seconds after bolt cycle starts before the shell casing is ejected.
## Default matches the moment the bolt finishes unlocking and starts pulling back.
## Only used when the weapon's Shell Eject Timing is set to On Cycle and bolt tween is active.
@export var shell_eject_delay: float = 0.267

func get_fire_mode() -> FireMode:
	return FireMode.BOLT_ACTION


func handles_own_shell_eject(weapon: Node) -> bool:
	# Bolt-action always handles its own eject — either through the bolt-tween
	# shell_eject_delay path or through the cycle animation. The orchestrator's
	# ON_FIRE eject would fire too early.
	return (weapon as CogitoFirearm)._bolt_part != null


func play_post_fire_visual(weapon: Node) -> void:
	var firearm := weapon as CogitoFirearm
	firearm._state = CogitoFirearm.WeaponState.CYCLING
	# Animation-shoot-motion mode chains the cycle in on_anim_finished instead.
	if firearm._uses_animation_shoot_motion():
		return
	firearm._schedule_post_fire_cycle(firearm._get_shoot_visual_duration(),
			_start_cycle.bind(firearm))


func on_anim_finished(weapon: Node, anim_name: StringName) -> void:
	var firearm := weapon as CogitoFirearm
	# Shoot animation finished → kick off the bolt cycle (animation shoot mode).
	if firearm._uses_animation_shoot_motion() and firearm._is_shoot_animation_name(anim_name):
		_start_cycle(firearm)
		return
	# Bolt-cycle animation finished → ready for next shot.
	if _is_bolt_cycle_anim(firearm, anim_name):
		firearm._state = CogitoFirearm.WeaponState.IDLE
		firearm._capture_rest_state()


func on_reset(weapon: Node) -> void:
	var firearm := weapon as CogitoFirearm
	if firearm._bolt_part != null:
		firearm._bolt_part.position = bolt_position_forward
		firearm._bolt_part.rotation = bolt_locked_rotation


# ── Internal ─────────────────────────────────────────────────────────────────

func _start_cycle(firearm: CogitoFirearm) -> void:
	firearm._post_fire_cycle_tween = null
	if firearm._bolt_part != null:
		firearm._run_bolt_tween()
		return
	if firearm.shell_eject_timing == CogitoFirearm.ShellEjectTiming.ON_CYCLE:
		firearm._spawn_shell_casing()
	var anim := _get_cycle_anim_name(firearm)
	if anim != "" and firearm.animation_player.has_animation(anim):
		firearm.animation_player.play(anim)
	else:
		firearm._complete_cycle_after_delay(boltCycleDuration,
				_finish_cycle.bind(firearm))


func _finish_cycle(firearm: CogitoFirearm) -> void:
	firearm._post_fire_cycle_tween = null
	firearm._state = CogitoFirearm.WeaponState.IDLE
	firearm._capture_rest_state()


func _get_cycle_anim_name(firearm: CogitoFirearm) -> String:
	if firearm._ads.is_aiming and firearm.bolt_cycle_animation_ads != "" \
			and firearm.animation_player.has_animation(firearm.bolt_cycle_animation_ads):
		return firearm.bolt_cycle_animation_ads
	return boltCycleAnimation


func _is_bolt_cycle_anim(firearm: CogitoFirearm, anim_name: StringName) -> bool:
	return anim_name == boltCycleAnimation \
		or (firearm.bolt_cycle_animation_ads != "" and anim_name == firearm.bolt_cycle_animation_ads)
