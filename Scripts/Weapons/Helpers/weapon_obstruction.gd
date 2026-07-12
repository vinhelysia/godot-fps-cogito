## Wall obstruction: gun rotates around fixed %Grip_Point when blocked.
## Probe is a box swept along the barrel (%Grip_Point -> %Bullet_Point), driven through a
## ShapeCast3D that lives under Head — the same node lean/pitch/recoil move, and the same
## node Wieldables hangs off. So the probe follows the gun through lean and pitch for free,
## with no special-casing (an earlier version fanned rays from the camera on a yaw-only basis
## and had to suppress itself while leaning, which is the exploit this replaces).
## Dead bodies / ragdolls / corpse loot are ignored (Environment walls only).
class_name WeaponObstruction
extends RefCounted

## Layer 1 only — Environment. Skips Corpse / CorpseBones / Player by mask.
const ENV_MASK: int = 1 << 0
const DEAD_ZONE: float = 0.06
## Ignore nearly-horizontal surfaces (floor/ground) — aiming down is not a wall jam.
const FLOOR_NORMAL_DOT: float = 0.65
## Box depth along the barrel. The sweep supplies the length; this is just the swept face.
const BOX_DEPTH: float = 0.02
## The muzzle always swings SCREEN-LEFT (-1), never right, regardless of which side the wall
## is on. A right-handed shooter pivots the rifle around the grip in their right hand, so the
## barrel can only come back across the body — leftward. Canting right would mean pushing the
## muzzle *away* from the body, which no one does. Flip to +1.0 for a left-handed viewmodel.
## (This used to be probe-driven: the wall normal picked a side, so a wall on your left canted
## the gun right, which read as a wrist no human has.)
const CANT_SIDE: float = -1.0

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
		cast: ShapeCast3D,
		wieldables: Node3D,
		firearm: Node,
		player: Node3D
) -> bool:
	var enabled: Variant = null
	if firearm:
		enabled = firearm.get("enable_obstruction")
	if cast == null or wieldables == null or firearm == null or enabled != true:
		_decay(delta, _smooth_speed(firearm))
		return false

	# While firing (trigger held / shot tween / anim) the probe gets false positives
	# from muzzle-flash-rate camera jitter, so stop probing — but HOLD the current
	# pose, do not decay it. Decaying here (it used to run at smooth_speed * 3) swung
	# a wall-canted gun ~obstruction_yaw_deg back to neutral within a few frames the
	# instant the trigger went down, and back out again on release: the spray "snap".
	# Holding is also what the barrel is physically doing — it is still against the wall.
	if firearm.has_method("should_suspend_container_motion") \
			and bool(firearm.should_suspend_container_motion()):
		strength = _smoothed_t
		grip_local = _grip_in_wieldables_space(firearm)
		_apply_pose(firearm, strength)
		_was_breaking_ads = false
		return false

	if not _fit_cast(cast, wieldables, firearm):
		_decay(delta, _smooth_speed(firearm))
		return false

	var raw_t := _probe(cast, _build_exclude(player, cast.get_tree()))
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


## Park the cast on the volume the gun occupies at REST.
##
## Markers are measured in Wieldables-space because sway, sprint pose, bob and the
## obstruction offset itself all move the *Wieldables node* — never the gun inside it.
## So a marker's position relative to Wieldables is pure rest geometry, and feeding it to a
## cast parented to Head (Wieldables' rest transform there is identity) means the cast asks
## "where would the gun be if nothing pushed it" — which is why _apply_pose pushing Wieldables
## cannot feed back into the probe. ADS moves the gun *within* Wieldables, so it is tracked.
func _fit_cast(cast: ShapeCast3D, wieldables: Node3D, firearm: Node) -> bool:
	var grip_n := firearm.get("grip_point") as Node3D
	var muzzle_n := firearm.get("bullet_point") as Node3D
	if grip_n == null or muzzle_n == null:
		return false
	var box := cast.shape as BoxShape3D
	if box == null:
		return false

	var w_inv := wieldables.global_transform.affine_inverse()
	var grip: Vector3 = w_inv * grip_n.global_position
	var muzzle: Vector3 = w_inv * muzzle_n.global_position
	var axis := muzzle - grip
	var barrel_len := axis.length()
	if barrel_len < 0.05:
		return false

	var size: Vector2 = firearm.get("obstruction_box_size")
	box.size = Vector3(maxf(size.x, 0.01), maxf(size.y, 0.01), BOX_DEPTH)
	var dir := axis / barrel_len
	# looking_at() is degenerate when the barrel is parallel to its up vector. In
	# Wieldables-space the barrel is ~forward for every weapon we ship (aim pitch lives on
	# Head, above this frame), so this only guards a weapon authored pointing straight up.
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.BACK
	cast.position = grip
	cast.basis = Basis.looking_at(dir, up)
	# looking_at puts the barrel on -Z, which is also the direction target_position sweeps.
	cast.target_position = Vector3(0.0, 0.0, -barrel_len)
	cast.collision_mask = ENV_MASK
	cast.collide_with_areas = false
	return true


## 1 - safe_fraction: 0 = barrel clear, 1 = blocked at the grip. Already the graded 0..1 that
## _apply_pose wants, so no distance falloff curve is needed.
func _probe(cast: ShapeCast3D, exclude: Array) -> float:
	cast.clear_exceptions()
	for rid: RID in exclude:
		cast.add_exception_rid(rid)
	cast.force_shapecast_update()
	if not cast.is_colliding():
		return 0.0

	# Floors/ramps are not a wall jam. If EVERY hit is floor-like, treat the barrel as clear.
	var hit_wall := false
	for i in cast.get_collision_count():
		var n: Vector3 = cast.get_collision_normal(i)
		if n.length_squared() > 0.0001 and n.normalized().dot(Vector3.UP) <= FLOOR_NORMAL_DOT:
			hit_wall = true
			break
	if not hit_wall:
		return 0.0

	return clampf(1.0 - cast.get_closest_collision_safe_fraction(), 0.0, 1.0)


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

	# Gentler than t*1.75 — partial/flicker hits no longer hard-snap to 90°.
	var e := clampf(t, 0.0, 1.0)
	e = e * e * (3.0 - 2.0 * e)

	pos_offset = Vector3(side_amp * e * CANT_SIDE, 0.0, pull * e)
	rot_offset_deg = Vector3(-pitch_max * e, -yaw_max * e * CANT_SIDE, roll_max * e * CANT_SIDE)


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


func _grip_in_wieldables_space(firearm: Node) -> Vector3:
	var grip_in_gun := Vector3(0.0, -0.06, 0.05)
	if firearm.has_method("get_grip_local_position"):
		grip_in_gun = firearm.get_grip_local_position()
	elif firearm.get("grip_point") is Node3D:
		grip_in_gun = (firearm.get("grip_point") as Node3D).position
	if firearm is Node3D:
		return (firearm as Node3D).transform * grip_in_gun
	return grip_in_gun


func _smooth_speed(firearm: Node) -> float:
	if firearm == null:
		return 16.0
	return maxf(float(firearm.get("obstruction_smooth_speed")), 1.0)


static func _smoothing_weight(speed: float, delta: float) -> float:
	return 1.0 - exp(-maxf(speed, 0.0) * maxf(delta, 0.0))
