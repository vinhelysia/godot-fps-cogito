## Wall obstruction: gun rotates around fixed %Grip_Point when blocked.
## Probe covers hip-weapon volume (center + right/down). Strong cant response.
## Dead bodies / ragdolls / corpse loot are ignored (Environment walls only).
class_name WeaponObstruction
extends RefCounted

## Layer 1 only — Environment. Skips Corpse / CorpseBones / Player by mask.
const ENV_MASK: int = 1 << 0
const DEAD_ZONE: float = 0.02
const DEFAULT_REACH: float = 1.4
## When clearance falls below this fraction of reach, strength is already 1.0.
const FULL_STRENGTH_FRAC: float = 0.55
const CORPSE_SKIP_MAX: int = 6

var pos_offset: Vector3 = Vector3.ZERO
var rot_offset_deg: Vector3 = Vector3.ZERO
var grip_local: Vector3 = Vector3.ZERO
var strength: float = 0.0

var _smoothed_t: float = 0.0
var _was_breaking_ads: bool = false


func reset() -> void:
	_smoothed_t = 0.0
	_was_breaking_ads = false
	pos_offset = Vector3.ZERO
	rot_offset_deg = Vector3.ZERO
	grip_local = Vector3.ZERO
	strength = 0.0


func tick(
		delta: float,
		camera: Camera3D,
		firearm: Node,
		player: Node3D
) -> bool:
	var enabled: Variant = null
	if firearm:
		enabled = firearm.get("enable_obstruction")
	if camera == null or firearm == null or enabled != true:
		_decay(delta, _smooth_speed(firearm))
		return false

	var world := camera.get_world_3d()
	if world == null or world.direct_space_state == null:
		_decay(delta, _smooth_speed(firearm))
		return false

	var free_len := _resolve_reach(firearm)
	var exclude: Array = _build_exclude(player, camera.get_tree())

	var raw_t := _probe_weapon_volume(world.direct_space_state, camera, free_len, exclude)
	if raw_t < DEAD_ZONE:
		raw_t = 0.0

	var w := _smoothing_weight(_smooth_speed(firearm), delta)
	_smoothed_t = lerpf(_smoothed_t, raw_t, w)
	if _smoothed_t < 0.001:
		_smoothed_t = 0.0

	strength = _smoothed_t
	grip_local = _grip_in_wieldables_space(firearm)
	_apply_pose(firearm, strength)

	var break_threshold: float = float(firearm.get("obstruction_ads_break_threshold"))
	var should_break := strength >= maxf(break_threshold, 0.75)
	var edge := should_break and not _was_breaking_ads
	_was_breaking_ads = should_break
	return edge


func _decay(delta: float, smooth_speed: float) -> void:
	var w := _smoothing_weight(maxf(smooth_speed, 1.0), delta)
	_smoothed_t = lerpf(_smoothed_t, 0.0, w)
	if _smoothed_t < 0.001:
		reset()
		return
	strength = _smoothed_t
	pos_offset = pos_offset.lerp(Vector3.ZERO, w)
	rot_offset_deg = rot_offset_deg.lerp(Vector3.ZERO, w)


func _apply_pose(firearm: Node, t: float) -> void:
	if t <= 0.0:
		pos_offset = Vector3.ZERO
		rot_offset_deg = Vector3.ZERO
		return

	var pull: float = float(firearm.get("obstruction_pull_back"))
	var side_amp: float = float(firearm.get("obstruction_side"))
	var yaw_max: float = float(firearm.get("obstruction_yaw_deg"))
	var roll_max: float = float(firearm.get("obstruction_roll_deg"))
	var pitch_max: float = float(firearm.get("obstruction_pitch_deg"))

	# Aggressive remap: partial blocks still reach strong cant.
	var e := clampf(t * 1.75, 0.0, 1.0)
	e = e * e * (3.0 - 2.0 * e)

	pos_offset = Vector3(-side_amp * e, 0.0, pull * e)
	rot_offset_deg = Vector3(-pitch_max * e, yaw_max * e, -roll_max * e)


func _build_exclude(player: Node3D, tree: SceneTree) -> Array:
	var exclude: Array = []
	if player:
		exclude.append(player.get_rid())
		for n in player.find_children("*", "CollisionObject3D", true, false):
			if n is CollisionObject3D:
				exclude.append((n as CollisionObject3D).get_rid())

	if tree == null:
		return exclude

	for ragdoll in tree.get_nodes_in_group("corpse_ragdoll"):
		_exclude_collision_tree(ragdoll, exclude)
	for node in tree.get_nodes_in_group("hostile_npc"):
		if node is CollisionObject3D:
			var co := node as CollisionObject3D
			if co.collision_layer == 0 and co.collision_mask == 0:
				_exclude_collision_tree(node, exclude)
			elif node is Node and int(node.get("process_mode")) == int(Node.PROCESS_MODE_DISABLED):
				_exclude_collision_tree(node, exclude)

	if tree.current_scene:
		for n in tree.current_scene.find_children("*", "StaticBody3D", true, false):
			if _is_corpse_like(n):
				_exclude_collision_tree(n, exclude)
	return exclude


func _exclude_collision_tree(root: Node, exclude: Array) -> void:
	if root is CollisionObject3D:
		exclude.append((root as CollisionObject3D).get_rid())
	for n in root.find_children("*", "CollisionObject3D", true, false):
		if n is CollisionObject3D:
			exclude.append((n as CollisionObject3D).get_rid())


func _is_corpse_like(node: Node) -> bool:
	if node.is_in_group("corpse_ragdoll"):
		return true
	var scr: Script = node.get_script() as Script
	if scr != null and str(scr.resource_path).contains("corpse_container"):
		return true
	var n: String = str(node.name).to_lower()
	if n.contains("corpse") or n.contains("ragdoll") or n.contains("mannequin"):
		return true
	return false


func _is_corpse_collider(collider: Object) -> bool:
	if collider == null:
		return false
	if collider is Node:
		var n := collider as Node
		if _is_corpse_like(n):
			return true
		var p := n.get_parent()
		var hops := 0
		while p and hops < 8:
			if _is_corpse_like(p):
				return true
			p = p.get_parent()
			hops += 1
	return false


func _grip_in_wieldables_space(firearm: Node) -> Vector3:
	var grip_in_gun := Vector3(0.0, -0.06, 0.05)
	if firearm.has_method("get_grip_local_position"):
		grip_in_gun = firearm.get_grip_local_position()
	elif firearm.get("grip_point") is Node3D:
		grip_in_gun = (firearm.get("grip_point") as Node3D).position
	if firearm is Node3D:
		return (firearm as Node3D).transform * grip_in_gun
	return grip_in_gun


func _resolve_reach(firearm: Node) -> float:
	var configured: float = float(firearm.get("obstruction_reach"))
	if configured > 0.0:
		return configured
	return DEFAULT_REACH


func _smooth_speed(firearm: Node) -> float:
	if firearm == null:
		return 16.0
	return maxf(float(firearm.get("obstruction_smooth_speed")), 1.0)


func _probe_weapon_volume(
		space: PhysicsDirectSpaceState3D,
		camera: Camera3D,
		free_len: float,
		exclude: Array
) -> float:
	var origin := camera.global_position
	var f := -camera.global_transform.basis.z
	var r := camera.global_transform.basis.x
	var u := camera.global_transform.basis.y
	var start := origin - f * 0.3

	var dirs: Array[Vector3] = [
		f,
		(f + r * 0.5).normalized(),
		(f + r * 0.75).normalized(),
		(f + r * 0.55 - u * 0.2).normalized(),
		(f + r * 0.7 - u * 0.35).normalized(),
		(f + r * 0.4 - u * 0.45).normalized(),
		(f - u * 0.3).normalized(),
		(f + r * 0.9).normalized(),
	]

	var t_max := 0.0
	var ray_len := free_len + 0.35
	for d: Vector3 in dirs:
		var t := _ray_t(space, start, start + d * ray_len, origin, free_len, exclude)
		if t > t_max:
			t_max = t
	return t_max


func _ray_t(
		space: PhysicsDirectSpaceState3D,
		from: Vector3,
		to: Vector3,
		camera_pos: Vector3,
		free_len: float,
		exclude: Array
) -> float:
	var local_exclude: Array = exclude.duplicate()
	for _i in CORPSE_SKIP_MAX:
		var params := PhysicsRayQueryParameters3D.create(from, to)
		params.exclude = local_exclude
		params.collision_mask = ENV_MASK
		params.collide_with_areas = false
		var hit := space.intersect_ray(params)
		if hit.is_empty():
			return 0.0
		var collider: Object = hit.get("collider")
		if _is_corpse_collider(collider):
			if collider is CollisionObject3D:
				local_exclude.append((collider as CollisionObject3D).get_rid())
			if collider is Node:
				_exclude_collision_tree(collider as Node, local_exclude)
			continue
		var dist: float = camera_pos.distance_to(hit["position"])
		var full_at := free_len * FULL_STRENGTH_FRAC
		if dist <= full_at:
			return 1.0
		return clampf(1.0 - (dist - full_at) / maxf(free_len - full_at, 0.01), 0.0, 1.0)
	return 0.0


static func _smoothing_weight(speed: float, delta: float) -> float:
	return 1.0 - exp(-maxf(speed, 0.0) * maxf(delta, 0.0))
