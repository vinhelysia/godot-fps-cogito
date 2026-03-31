extends Node3D
class_name CameraShake
## Trauma-based camera shake node.
## Place as a child of Body/Neck/Head, sibling of CameraRecoil.
##
## How it works:
##   - add_trauma(amount, type) pushes trauma toward 1.0.
##   - Each frame, trauma decays and shake = trauma^2 is computed.
##   - _get_shake_offset() converts shake into per-frame pos/rot offsets.
##   - Offsets are applied directly to camera_target.position / rotation_degrees.
##
## Setup:
##   1. Add this node as child of Head (sibling of CameraRecoil).
##   2. Assign camera_target in the Inspector (drag the Camera3D node).
##      If left empty it falls back to get_viewport().get_camera_3d().

enum ShakeType {
	FIRE,       ## Tight, fast oscillation — gunfire impulse
	HIT,        ## Sharp random burst — receiving damage
	EXPLOSION,  ## Slow rolling shake with strong roll — nearby blast
}

## Camera to apply positional and rotational offsets to.
@export var camera_target: Camera3D

## Trauma decay per second. 2.5 = full trauma gone in ~0.4s.
@export var trauma_decay_rate: float = 2.5

## Maximum position offset (metres) at full trauma (shake = 1.0).
@export var max_pos_offset: Vector3 = Vector3(0.015, 0.015, 0.0)

## Maximum rotation offset (degrees) at full trauma.
@export var max_rot_offset: Vector3 = Vector3(1.2, 1.2, 2.0)

@export_group("Type Magnitudes")
## Trauma multiplier for FIRE shakes. Keep low so it doesn't feel floaty.
@export var fire_magnitude: float = 0.6
## Trauma multiplier for HIT shakes.
@export var hit_magnitude: float = 1.0
## Trauma multiplier for EXPLOSION shakes.
@export var explosion_magnitude: float = 0.9

# Runtime state
var _trauma: float = 0.0
var _time: float = 0.0
var _active_type: ShakeType = ShakeType.FIRE

# Track what we applied last frame so we can undo it cleanly
var _last_pos_offset := Vector3.ZERO
var _last_rot_offset := Vector3.ZERO


func _ready() -> void:
	if not camera_target:
		camera_target = get_viewport().get_camera_3d()


func _process(delta: float) -> void:
	_time += delta
	_trauma = maxf(0.0, _trauma - trauma_decay_rate * delta)

	# Undo previous frame's offset before applying the new one
	if camera_target:
		camera_target.position -= _last_pos_offset
		camera_target.rotation_degrees -= _last_rot_offset

	if _trauma < 0.001:
		_last_pos_offset = Vector3.ZERO
		_last_rot_offset = Vector3.ZERO
		return

	# Squaring trauma gives a snappier onset and a softer tail
	var shake := _trauma * _trauma

	# TODO(human): implement _get_shake_offset(shake) below.
	var offsets: Dictionary = _get_shake_offset(shake)

	_last_pos_offset = offsets.get("pos", Vector3.ZERO)
	_last_rot_offset = offsets.get("rot", Vector3.ZERO)

	if camera_target:
		camera_target.position += _last_pos_offset
		camera_target.rotation_degrees += _last_rot_offset


## Add trauma to the shake system. Multiple callers accumulate correctly.
## [param amount] 0.0–1.0 contribution to add.
## [param type] ShakeType: FIRE, HIT, or EXPLOSION.
func add_trauma(amount: float, type: ShakeType = ShakeType.FIRE) -> void:
	_active_type = type
	var magnitude := fire_magnitude
	match type:
		ShakeType.HIT:
			magnitude = hit_magnitude
		ShakeType.EXPLOSION:
			magnitude = explosion_magnitude
	_trauma = minf(_trauma + amount * magnitude, 1.0)


## Compute per-frame position and rotation offsets from the current shake state.
## [param shake_strength] is trauma^2, range 0–1.
## Returns a Dictionary with keys "pos" (Vector3) and "rot" (Vector3).
##
## TODO(human): implement this function.
## Use _time (seconds elapsed), _active_type, max_pos_offset, and max_rot_offset.
## Hints:
##   ShakeType.FIRE      → tight, fast oscillation: sin(_time * 40.0), cos(_time * 37.0)
##   ShakeType.HIT       → sharp random burst: randf_range(-1.0, 1.0) each axis
##   ShakeType.EXPLOSION → slow rolling: sin(_time * 8.0), heavy rot.z for roll feel
## Scale each axis by shake_strength * max_pos_offset.x (or y/z) for pos,
## and shake_strength * max_rot_offset.x (etc.) for rot.
## Return: {"pos": Vector3(...), "rot": Vector3(...)}
func _get_shake_offset(shake_strength: float) -> Dictionary:
	return {"pos": Vector3.ZERO, "rot": Vector3.ZERO}
