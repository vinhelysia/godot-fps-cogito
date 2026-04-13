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

func get_fire_mode() -> FireMode:
	return FireMode.BOLT_ACTION

func on_post_fire(ctx: Dictionary) -> bool:
	ctx["needs_bolt_cycle"] = true
	ctx["bolt_cycle_animation"] = boltCycleAnimation
	ctx["bolt_cycle_duration"] = boltCycleDuration
	return true
