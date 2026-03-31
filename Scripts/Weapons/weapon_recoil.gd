extends Node3D
## Weapon recoil node. Place as a child of Body/Neck/Head in the player scene.
## Applies rotation delta to the parent (Head) node each frame, creating smooth
## camera kick on fire with automatic recovery.
##
## Pair with a CameraShake sibling node for positional screen-shake on fire.

# Internal rotation tracking
var currentRotation: Vector3
var targetRotation: Vector3
var _prevRotation := Vector3.ZERO

# Per-weapon recoil vectors (set via setRecoil / setAimRecoil on equip)
@export var recoil: Vector3
@export var aimRecoil: Vector3

# Tuning
@export var snappiness: float = 10.0
@export var returnSpeed: float = 5.0

# Burst / ramp-up settings
## Number of shots before recoil reaches peak multiplier.
@export var recoil_ramp_shots: int = 4
## Maximum recoil multiplier reached after ramping up.
@export var recoil_ramp_max: float = 1.8
## Seconds without firing before shot counter resets (trigger gap).
@export var burst_reset_time: float = 0.4
## Extra horizontal drift added per shot during sustained fire (radians).
@export var burst_drift_per_shot: float = 0.003

# Burst state
var _shot_count: int = 0
var _burst_drift: float = 0.0
var _time_since_last_shot: float = 0.0

# Optional sibling CameraShake node
var _camera_shake: Node = null


func _ready() -> void:
	_camera_shake = get_parent().get_node_or_null("CameraShake")


func _process(delta: float) -> void:
	_time_since_last_shot += delta

	# Reset burst state when trigger is released long enough
	if _time_since_last_shot >= burst_reset_time:
		_shot_count = 0
		_burst_drift = 0.0

	targetRotation = lerp(targetRotation, Vector3.ZERO, returnSpeed * delta)
	currentRotation = lerp(currentRotation, targetRotation, snappiness * delta)

	var delta_rot := currentRotation - _prevRotation
	_prevRotation = currentRotation

	if get_parent() and delta_rot.length() > 0.0001:
		get_parent().rotate_object_local(Vector3.RIGHT, delta_rot.x)
		get_parent().rotate_object_local(Vector3.UP, delta_rot.y)
		# Prevent unintended z-axis tilt when recoil.z is unused
		if recoil.z == 0.0 and aimRecoil.z == 0.0:
			get_parent().global_rotation.z = 0.0


func recoilFire(isAiming: bool = false) -> void:
	_time_since_last_shot = 0.0
	_shot_count += 1

	# Ramp-up: interpolate from 1.0 to max over ramp_shots
	var ramp: float = clampf(float(_shot_count - 1) / float(maxi(recoil_ramp_shots - 1, 1)), 0.0, 1.0)
	var multiplier: float = lerpf(1.0, recoil_ramp_max, ramp)

	# Accumulate leftward horizontal drift on sustained fire, capped at base.y
	_burst_drift = minf(_burst_drift + burst_drift_per_shot, recoil.y * 0.6)

	var base := aimRecoil if isAiming else recoil

	targetRotation += Vector3(
		base.x * multiplier,
		randf_range(-base.y, base.y) + _burst_drift,
		randf_range(-base.z, base.z)
	)

	# Notify sibling CameraShake if present
	if _camera_shake and _camera_shake.has_method("add_trauma"):
		var trauma := 0.25 if not isAiming else 0.1
		_camera_shake.add_trauma(trauma)


func setRecoil(newRecoil: Vector3) -> void:
	recoil = newRecoil


func setAimRecoil(newRecoil: Vector3) -> void:
	aimRecoil = newRecoil
