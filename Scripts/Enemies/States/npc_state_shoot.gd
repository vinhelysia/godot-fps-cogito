extends Node
## Ranged shoot state — entered from "chase" when within target_action_distance.
## Returns to "chase" if target is out of range or LOS is lost too long.

# Injected by NPC_State_Machine.setup()
var Host: CogitoNPC
var States: Node

## Seconds between shots.
@export var fire_rate: float = 0.9
## HP damage per hit.
@export var damage: float = 8.0
## Spread radius in each axis — 0 = perfect, 0.15 ≈ ±8° cone.
@export var accuracy: float = 0.12
## Return to chase if closer than this.
@export var min_engage_range: float = 3.0
## Return to chase if farther than this.
@export var max_engage_range: float = 18.0
## Pause duration between bursts.
@export var reload_time: float = 2.5
## Shots per burst before reload pause.
@export var burst_count: int = 5
## Seconds without LOS before returning to chase.
@export var los_timeout: float = 3.0

var _target: Node3D = null
var _fire_timer: float = 0.0
var _shots_fired: int = 0
var _reloading: bool = false
var _reload_timer: float = 0.0
var _los_lost_timer: float = 0.0


func _state_enter(_args = null) -> void:
	_target = Host.attention_target
	if not is_instance_valid(_target):
		States.load_previous_state("patrol_on_path")
		return
	_fire_timer = fire_rate * 0.5   # first shot slightly faster
	_shots_fired = 0
	_reloading = false
	_reload_timer = 0.0
	_los_lost_timer = 0.0


func _state_exit() -> void:
	_target = null


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_target):
		States.load_previous_state("patrol_on_path")
		return

	_brake(delta)
	Host.face_direction(_target.global_position)
	Host.update_animations(delta)

	var dist: float = Host.global_position.distance_to(_target.global_position)
	# Only break engagement when too FAR. The old "or dist < min_engage_range -> chase"
	# branch thrashed: chase (target_action_distance 12) re-enters shoot immediately at
	# close range -> chase<->shoot oscillation. Scav now just shoots at any range <= max.
	if dist > max_engage_range:
		States.goto("chase")
		return

	if _reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_reloading = false
			_shots_fired = 0
		return

	# LOS check (cheap, no spread)
	var los_result: Dictionary = _cast_ray(_get_muzzle_pos(), _target.global_position + Vector3(0.0, 1.0, 0.0))
	var has_los: bool = _result_hits_target(los_result)
	if not has_los:
		_los_lost_timer += delta
		if _los_lost_timer >= los_timeout:
			States.goto("chase")
		return
	_los_lost_timer = 0.0

	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = fire_rate
		_shoot()


func _brake(delta: float) -> void:
	var rate: float = delta * Host.sprint_speed * 6.0
	Host.velocity.x = move_toward(Host.velocity.x, 0.0, rate)
	Host.velocity.z = move_toward(Host.velocity.z, 0.0, rate)
	if not Host.is_on_floor():
		Host.velocity += Host.get_gravity() * delta
	Host.move_and_slide()


func _get_muzzle_pos() -> Vector3:
	var muzzle: Node3D = Host.get_node_or_null("Muzzle")
	if is_instance_valid(muzzle):
		return muzzle.global_position
	return Host.global_position + Vector3(0.0, 1.4, 0.0)


func _cast_ray(from: Vector3, to: Vector3) -> Dictionary:
	var space: PhysicsDirectSpaceState3D = Host.get_world_3d().direct_space_state
	var params := PhysicsRayQueryParameters3D.create(from, to)
	params.exclude = [Host.get_rid()]
	params.collision_mask = 3   # layer 1 (world) + layer 2 (player)
	return space.intersect_ray(params)


func _result_hits_target(result: Dictionary) -> bool:
	if result.is_empty():
		return true   # nothing in the way
	var hit = result["collider"]
	return hit == _target or hit.is_in_group("Player")


func _shoot() -> void:
	var muzzle_pos: Vector3 = _get_muzzle_pos()
	var aim_at: Vector3 = _target.global_position + Vector3(0.0, 1.0, 0.0)
	var aim_dir: Vector3 = (aim_at - muzzle_pos).normalized()

	# Spread: random deviation on local X/Y axes
	var right: Vector3 = aim_dir.cross(Vector3.UP).normalized()
	var up: Vector3 = right.cross(aim_dir).normalized()
	var spread: Vector3 = right * randf_range(-accuracy, accuracy) \
						+ up * randf_range(-accuracy * 0.5, accuracy * 0.5)
	var fire_dir: Vector3 = (aim_dir + spread).normalized()
	var fire_end: Vector3 = muzzle_pos + fire_dir * max_engage_range

	var result: Dictionary = _cast_ray(muzzle_pos, fire_end)
	if _result_hits_target(result):
		_apply_damage()

	_shots_fired += 1
	if _shots_fired >= burst_count:
		_reloading = true
		_reload_timer = reload_time


func _apply_damage() -> void:
	if _target is CogitoPlayer:
		(_target as CogitoPlayer).decrease_attribute("health", damage)
	elif _target.has_signal("damage_received"):
		var dir: Vector3 = (_target.global_position - Host.global_position).normalized()
		_target.damage_received.emit(damage, dir, _target.global_position)
