## Wall obstruction: gun rotates around fixed %Grip_Point when blocked.
## Probe uses a *level* camera frame (yaw only) so lean roll does not drive
## whiskers into the floor mid-spray. Left/right whiskers pick cant side.
## Dead bodies / ragdolls / corpse loot are ignored (Environment walls only).
class_name WeaponObstruction
extends RefCounted

## Layer 1 only — Environment. Skips Corpse / CorpseBones / Player by mask.
const ENV_MASK: int = 1 << 0
const DEAD_ZONE: float = 0.06
const DEFAULT_REACH: float = 1.4
## When clearance falls below this fraction of reach, strength is already 1.0.
const FULL_STRENGTH_FRAC: float = 0.45
const CORPSE_SKIP_MAX: int = 6
## Prefer previous open-side until the other side is clearly more blocked.
const SIDE_HYSTERESIS: float = 0.12
## Ignore nearly-horizontal surfaces (floor/ground) — spray false positives.
const FLOOR_NORMAL_DOT: float = 0.65
## How fast lean fades wall-cant out/in. Slower than obstruction_smooth_speed
## on purpose: lean_amount already moves fast (player_lean smooth_speed ~12),
## and multiplying its raw value straight into raw_t made a full-strength
## wall-cant collapse within 2-3 frames as lean ramped in — several degrees of
## Wieldables rotation in one frame (the reported "snap toward lean side").
const LEAN_DAMPEN_SPEED: float = 4.0

var pos_offset: Vector3 = Vector3.ZERO
var rot_offset_deg: Vector3 = Vector3.ZERO
var grip_local: Vector3 = Vector3.ZERO
var strength: float = 0.0

var _smoothed_t: float = 0.0
var _was_breaking_ads: bool = false
## -1 = cant muzzle screen-left (default right-shoulder open); +1 = screen-right.
var _side_sign: float = -1.0
## Smoothed separately from _smoothed_t (own slow filter, not the wall-distance
## filter) — see _lean_dampen call site in tick().
var _smoothed_lean_mul: float = 1.0


func reset() -> void:
	_smoothed_t = 0.0
	_was_breaking_ads = false
	_side_sign = -1.0
	# _smoothed_lean_mul deliberately NOT reset here: reset() is called from
	# _decay() every time normal wall-distance decay finishes settling to 0,
	# which happens routinely mid-spray (see should_suspend_container_motion
	# branch in tick()). Snapping it back to 1.0 there re-armed full wall-cant
	# for one frame right as firing ended while still fully leaned — the same
	# snap this file exists to prevent. It's a self-correcting filter chasing
	# _lean_dampen() every tick regardless, so leaving it alone is safe.
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

	# Track lean dampening every tick — including while firing-suspended below —
	# so it never goes stale. If it only updated in the normal path, a spray
	# that outlasts the lean-decay-to-0 would freeze _smoothed_lean_mul at its
	# pre-firing value; once the shot tween ends the normal path resumes and
	# multiplies fresh raw_t by that stale (too-high) value, re-applying wall
	# cant that should have stayed suppressed by the still-held lean.
	var lean_mul := _lean_dampen(player)
	_smoothed_lean_mul = lerpf(_smoothed_lean_mul, lean_mul, _smoothing_weight(LEAN_DAMPEN_SPEED, delta))

	# While firing (trigger held / shot tween / anim) probe false-positives + big
	# yaw cant feel like a weapon "snap". Decay only — no new wall pose.
	if firearm.has_method("should_suspend_container_motion") \
			and bool(firearm.should_suspend_container_motion()):
		_decay(delta, maxf(_smooth_speed(firearm), 8.0) * 3.0)
		strength = _smoothed_t
		grip_local = _grip_in_wieldables_space(firearm)
		_apply_pose(firearm, strength, _side_sign)
		_was_breaking_ads = false
		return false

	var world := camera.get_world_3d()
	if world == null or world.direct_space_state == null:
		_decay(delta, _smooth_speed(firearm))
		return false

	var free_len := _resolve_reach(firearm)
	var exclude: Array = _build_exclude(player, camera.get_tree())

	var probe := _probe_weapon_volume(world.direct_space_state, camera, free_len, exclude)
	var raw_t: float = probe.x
	var raw_side: float = probe.y
	if raw_t < DEAD_ZONE:
		raw_t = 0.0
		raw_side = 0.0

	# Lean already peeks the camera; wall-cant on top reads as lateral snap.
	# _smoothed_lean_mul was already advanced above (every tick, not just here)
	# so it fades in/out gently instead of dragging raw_t down in lockstep with
	# lean_amount.
	raw_t *= _smoothed_lean_mul

	var w := _smoothing_weight(_smooth_speed(firearm), delta)
	_smoothed_t = lerpf(_smoothed_t, raw_t, w)
	if _smoothed_t < 0.001:
		_smoothed_t = 0.0

	if raw_t >= DEAD_ZONE and absf(raw_side) > 0.001 and lean_mul > 0.2:
		# Hysteresis: only flip open-side when the opposite side is clearly stronger.
		if raw_side * _side_sign < 0.0 and absf(raw_side) > SIDE_HYSTERESIS:
			_side_sign = signf(raw_side)
		elif raw_side * _side_sign >= 0.0:
			_side_sign = signf(raw_side)

	strength = _smoothed_t
	grip_local = _grip_in_wieldables_space(firearm)
	_apply_pose(firearm, strength, _side_sign)

	var break_threshold: float = float(firearm.get("obstruction_ads_break_threshold"))
	var should_break := strength >= maxf(break_threshold, 0.75)
	var edge := should_break and not _was_breaking_ads
	_was_breaking_ads = should_break
	return edge


func _lean_dampen(player: Node3D) -> float:
	if player == null:
		return 1.0
	var lean: Node = player.get_node_or_null("PlayerLean")
	if lean == null:
		return 1.0
	var amount: float = absf(float(lean.get("lean_amount")))
	# Full lean → no obstruction cant (0). Partial → smooth scale down.
	return clampf(1.0 - amount * 1.35, 0.0, 1.0)


func _decay(delta: float, smooth_speed: float) -> void:
	var w := _smoothing_weight(maxf(smooth_speed, 1.0), delta)
	_smoothed_t = lerpf(_smoothed_t, 0.0, w)
	if _smoothed_t < 0.001:
		reset()
		return
	strength = _smoothed_t
	pos_offset = pos_offset.lerp(Vector3.ZERO, w)
	rot_offset_deg = rot_offset_deg.lerp(Vector3.ZERO, w)


func _apply_pose(firearm: Node, t: float, side_sign: float) -> void:
	if t <= 0.0:
		pos_offset = Vector3.ZERO
		rot_offset_deg = Vector3.ZERO
		return

	var pull: float = float(firearm.get("obstruction_pull_back"))
	var side_amp: float = float(firearm.get("obstruction_side"))
	var yaw_max: float = float(firearm.get("obstruction_yaw_deg"))
	var roll_max: float = float(firearm.get("obstruction_roll_deg"))
	var pitch_max: float = float(firearm.get("obstruction_pitch_deg"))

	# Gentler than t*1.75 — partial/flicker hits (spray + lean) no longer hard-snap to 90°.
	var e := clampf(t, 0.0, 1.0)
	e = e * e * (3.0 - 2.0 * e)

	var s := side_sign if absf(side_sign) > 0.001 else -1.0
	# side_sign -1: muzzle toward screen-left (open right). +1: screen-right.
	pos_offset = Vector3(side_amp * e * s, 0.0, pull * e)
	rot_offset_deg = Vector3(-pitch_max * e, -yaw_max * e * s, roll_max * e * s)


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


## Level (unrolled) forward/right from camera — lean must not tilt probes into floor.
func _level_basis(camera: Camera3D) -> Dictionary:
	var f := -camera.global_transform.basis.z
	f.y = 0.0
	if f.length_squared() < 0.0001:
		f = -camera.global_transform.basis.z
	else:
		f = f.normalized()
	var r := f.cross(Vector3.UP)
	if r.length_squared() < 0.0001:
		r = camera.global_transform.basis.x
		r.y = 0.0
		r = r.normalized()
	else:
		r = r.normalized()
	var u := Vector3.UP
	return {"f": f, "r": r, "u": u}


## Returns Vector2(t_max, side_hint). side_hint: -1 wall-right→cant left, +1 wall-left→cant right.
func _probe_weapon_volume(
		space: PhysicsDirectSpaceState3D,
		camera: Camera3D,
		free_len: float,
		exclude: Array
) -> Vector2:
	var basis := _level_basis(camera)
	var f: Vector3 = basis["f"]
	var r: Vector3 = basis["r"]
	var u: Vector3 = basis["u"]
	var origin := camera.global_position
	# Start slightly forward of camera (not behind) to cut self/body false hits while leaned.
	var start := origin + f * 0.05

	# Keep whiskers mostly horizontal — strong downward rays hit the ground while spraying.
	var center_dirs: Array[Vector3] = [
		f,
		(f - u * 0.08).normalized(),
	]
	var right_dirs: Array[Vector3] = [
		(f + r * 0.4).normalized(),
		(f + r * 0.65 - u * 0.08).normalized(),
	]
	var left_dirs: Array[Vector3] = [
		(f - r * 0.4).normalized(),
		(f - r * 0.65 - u * 0.08).normalized(),
	]

	var ray_len := free_len + 0.15
	var t_center := _max_ray_t(space, start, center_dirs, ray_len, origin, free_len, exclude)
	var t_right := _max_ray_t(space, start, right_dirs, ray_len, origin, free_len, exclude)
	var t_left := _max_ray_t(space, start, left_dirs, ray_len, origin, free_len, exclude)

	var t_max := maxf(t_center, maxf(t_left, t_right))
	var side_hint := -1.0
	if t_left > t_right + 0.05:
		# Wall stronger on left → open / cant to the right.
		side_hint = 1.0
	elif t_right > t_left + 0.05:
		side_hint = -1.0
	# Head-on only: keep last preferred side (caller hysteresis uses _side_sign).
	return Vector2(t_max, side_hint)


func _max_ray_t(
		space: PhysicsDirectSpaceState3D,
		start: Vector3,
		dirs: Array[Vector3],
		ray_len: float,
		camera_pos: Vector3,
		free_len: float,
		exclude: Array
) -> float:
	var t_max := 0.0
	for d: Vector3 in dirs:
		var t := _ray_t(space, start, start + d * ray_len, camera_pos, free_len, exclude)
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
		# Floor / shallow ground — not a wall jam; skip and keep casting.
		var nrm: Vector3 = hit.get("normal", Vector3.ZERO)
		if nrm.length_squared() > 0.0001 and nrm.normalized().dot(Vector3.UP) > FLOOR_NORMAL_DOT:
			if collider is CollisionObject3D:
				local_exclude.append((collider as CollisionObject3D).get_rid())
			continue
		var dist: float = camera_pos.distance_to(hit["position"])
		var full_at := free_len * FULL_STRENGTH_FRAC
		if dist <= full_at:
			return 1.0
		return clampf(1.0 - (dist - full_at) / maxf(free_len - full_at, 0.01), 0.0, 1.0)
	return 0.0


static func _smoothing_weight(speed: float, delta: float) -> float:
	return 1.0 - exp(-maxf(speed, 0.0) * maxf(delta, 0.0))
