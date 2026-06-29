extends Node3D
## Weapon recoil node. Place as a child of Body/Neck/Head in the player scene.
## Applies rotation delta to the parent (Head) node each frame, creating smooth
## camera kick on fire with automatic recovery.
##
## Built-in trauma-based positional shake — no sibling CameraShake node needed.

# ── Constants ────────────────────────────────────────────────────────────────

const BURST_DRIFT_CAP_RATIO: float = 0.6
const FIRE_TRAUMA_HIP: float = 0.25
const FIRE_TRAUMA_ADS: float = 0.1

# ── Internal rotation tracking ───────────────────────────────────────────────

var current_rotation: Vector3
var target_rotation: Vector3
var _prev_rotation := Vector3.ZERO

# ── Per-weapon recoil vectors (set via set_recoil / set_aim_recoil on equip) ─

@export var recoil: Vector3
@export var aim_recoil: Vector3

# ── Tuning ───────────────────────────────────────────────────────────────────

@export var snappiness: float = 10.0
@export var return_speed: float = 5.0

# ── Burst / ramp-up settings ────────────────────────────────────────────────

## Number of shots before recoil reaches peak multiplier.
@export var recoil_ramp_shots: int = 4
## Maximum recoil multiplier reached after ramping up.
@export var recoil_ramp_max: float = 1.8
## Seconds without firing before shot counter resets (trigger gap).
@export var burst_reset_time: float = 0.4
## Extra horizontal drift added per shot during sustained fire (radians).
@export var burst_drift_per_shot: float = 0.003

# ── Burst state ──────────────────────────────────────────────────────────────

var _shot_count: int = 0
var _burst_drift: float = 0.0
var _time_since_last_shot: float = 0.0

# ── Built-in camera shake ────────────────────────────────────────────────────

## Maximum positional shake offset (metres) applied to the parent Head node.
@export var shake_max_offset: Vector3 = Vector3(0.015, 0.02, 0.0)
## Maximum roll shake in degrees.
@export var shake_max_roll_deg: float = 1.5
## How fast trauma decays per second (higher = snappier recovery).
@export var shake_trauma_decay: float = 1.8
## Trauma is raised to this power before sampling — higher = more contrast.
@export var shake_trauma_power: float = 2.0
## Noise oscillation speed — higher = faster shake.
@export var shake_noise_frequency: float = 20.0
## Prevent unintended z-axis tilt during recoil calculation (opt-out if using lean systems).
@export var prevent_z_tilt: bool = true

var _trauma: float = 0.0
var _shake_time: float = 0.0
var _shake_noise: FastNoiseLite
var _shake_offset: Vector3 = Vector3.ZERO
var _shake_roll: float = 0.0  # Track shake roll (in degrees) to apply additively

var _head_node: Node3D


func _ready() -> void:
	_head_node = get_parent() as Node3D
	_shake_noise = FastNoiseLite.new()
	_shake_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_shake_noise.seed = randi()


func _process(delta: float) -> void:
	_time_since_last_shot += delta

	# Reset burst state when trigger is released long enough
	if _time_since_last_shot >= burst_reset_time:
		_shot_count = 0
		_burst_drift = 0.0

	target_rotation = lerp(target_rotation, Vector3.ZERO, return_speed * delta)
	current_rotation = lerp(current_rotation, target_rotation, snappiness * delta)

	var delta_rot := current_rotation - _prev_rotation
	_prev_rotation = current_rotation

	if _head_node and delta_rot.length() > 0.0001:
		var prev_z := _head_node.global_rotation.z
		_head_node.rotate_object_local(Vector3.RIGHT, delta_rot.x)
		_head_node.rotate_object_local(Vector3.UP, delta_rot.y)
		# Prevent unintended z-axis tilt when recoil.z is unused
		if prevent_z_tilt and recoil.z == 0.0 and aim_recoil.z == 0.0:
			_head_node.global_rotation.z = prev_z

	# Positional shake
	_trauma = maxf(0.0, _trauma - shake_trauma_decay * delta)
	_shake_time += delta
	_apply_shake()


# ── Public API (snake_case — canonical) ──────────────────────────────────────

func recoil_fire(is_aiming: bool = false) -> void:
	_time_since_last_shot = 0.0
	_shot_count += 1

	# Ramp-up: interpolate from 1.0 to max over ramp_shots
	var ramp: float = clampf(float(_shot_count - 1) / float(maxi(recoil_ramp_shots - 1, 1)), 0.0, 1.0)
	var multiplier: float = lerpf(1.0, recoil_ramp_max, ramp)

	# Accumulate leftward horizontal drift on sustained fire, capped
	_burst_drift = minf(_burst_drift + burst_drift_per_shot, recoil.y * BURST_DRIFT_CAP_RATIO)

	var base := aim_recoil if is_aiming else recoil

	target_rotation += Vector3(
		base.x * multiplier,
		randf_range(-base.y, base.y) + _burst_drift,
		randf_range(-base.z, base.z)
	)

	var trauma_amount := FIRE_TRAUMA_ADS if is_aiming else FIRE_TRAUMA_HIP
	add_trauma(trauma_amount)


func set_recoil(new_recoil: Vector3) -> void:
	recoil = new_recoil


func set_aim_recoil(new_recoil: Vector3) -> void:
	aim_recoil = new_recoil


## Inject trauma (0–1). Stacks additively, capped at 1.0.
## Call this externally (e.g. from explosion or melee hit) for extra shake.
func add_trauma(amount: float) -> void:
	_trauma = minf(1.0, _trauma + amount)


func _apply_shake() -> void:
	var parent := _head_node
	if not parent:
		return

	# Remove previous frame's shake offset and roll so we don't accumulate
	parent.position -= _shake_offset
	parent.rotation_degrees.z -= _shake_roll

	if _trauma <= 0.001:
		_shake_offset = Vector3.ZERO
		_shake_roll = 0.0
		return

	var shake: float = pow(_trauma, shake_trauma_power)
	var t: float = _shake_time * shake_noise_frequency
	_shake_offset = Vector3(
		_shake_noise.get_noise_2d(t, 0.0)   * shake_max_offset.x * shake,
		_shake_noise.get_noise_2d(0.0, t)   * shake_max_offset.y * shake,
		0.0
	)
	_shake_roll = _shake_noise.get_noise_2d(t, 100.0) * shake_max_roll_deg * shake
	
	parent.position += _shake_offset
	parent.rotation_degrees.z += _shake_roll


# ── Backwards-compatible aliases (camelCase) ─────────────────────────────────

# DEPRECATED: Use recoil_fire instead.
func recoilFire(is_aiming: bool = false) -> void:
	recoil_fire(is_aiming)

# DEPRECATED: Use set_recoil instead.
func setRecoil(new_recoil: Vector3) -> void:
	set_recoil(new_recoil)

# DEPRECATED: Use set_aim_recoil instead.
func setAimRecoil(new_recoil: Vector3) -> void:
	set_aim_recoil(new_recoil)
