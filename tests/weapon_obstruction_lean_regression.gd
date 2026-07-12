extends SceneTree

## Run: godot --headless --path . -s tests/weapon_obstruction_lean_regression.gd
##
## Regression for the lean exploit: leaning let you point the barrel through a wall with no
## obstruction at all. The old probe fanned rays from the camera on a yaw-only basis, so it
## could not see where the barrel actually was while leaned — and rather than fix that, the
## code multiplied strength by _lean_dampen() (1.0 - lean * 1.35), which is exactly 0.0 at
## full lean. The probe is now a box swept along %Grip_Point -> %Bullet_Point through a
## ShapeCast3D under Head, so lean and pitch move it with the gun and no dampening exists.
##
## The lean test below builds a real physics world and would fail on the old code (strength 0).

const WeaponObstruction = preload("res://Scripts/Weapons/Helpers/weapon_obstruction.gd")

const WALL_Z: float = -1.0
const GRIP_Z: float = -0.3
const MUZZLE_Z: float = -1.6
## player_lean.gd at full lean: lateral 0.38 * right_lateral_scale 1.2, roll 12 deg.
const FULL_LEAN_X: float = 0.456
const FULL_LEAN_ROLL_DEG: float = -12.0


class FakeFirearm:
	extends Node3D
	var enable_obstruction: bool = true
	var obstruction_smooth_speed: float = 10.0
	var obstruction_box_size: Vector2 = Vector2(0.14, 0.10)
	var obstruction_pull_back: float = 0.22
	var obstruction_side: float = 0.12
	var obstruction_yaw_deg: float = 35.0
	var obstruction_roll_deg: float = 22.0
	var obstruction_pitch_deg: float = 0.0
	var obstruction_ads_break_threshold: float = 0.9
	var grip_point: Node3D
	var bullet_point: Node3D
	var suspended: bool = false

	func _init() -> void:
		grip_point = Node3D.new()
		grip_point.position = Vector3(0.2, -0.2, GRIP_Z)
		add_child(grip_point)
		bullet_point = Node3D.new()
		bullet_point.position = Vector3(0.2, -0.2, MUZZLE_Z)
		add_child(bullet_point)

	func should_suspend_container_motion() -> bool:
		return suspended

	func get_grip_local_position() -> Vector3:
		return grip_point.position


## Head -> {WeaponObstructionCast, Wieldables -> FakeFirearm}, plus a wall the barrel crosses.
## Mirrors the real rig: the cast is a SIBLING of Wieldables under Head, never a child of it.
class Rig:
	extends Node3D
	var player: CharacterBody3D
	var head: Node3D
	var cast: ShapeCast3D
	var wieldables: Node3D
	var firearm: FakeFirearm

	func _init() -> void:
		var wall := StaticBody3D.new()
		wall.collision_layer = 1
		wall.position = Vector3(0.0, 0.0, WALL_Z)
		var wall_shape := CollisionShape3D.new()
		var wall_box := BoxShape3D.new()
		wall_box.size = Vector3(12.0, 12.0, 0.2)
		wall_shape.shape = wall_box
		wall.add_child(wall_shape)
		add_child(wall)

		player = CharacterBody3D.new()
		player.collision_layer = 1 << 4
		add_child(player)

		head = Node3D.new()
		player.add_child(head)

		cast = ShapeCast3D.new()
		cast.shape = BoxShape3D.new()
		cast.enabled = false
		cast.collision_mask = 1
		head.add_child(cast)

		wieldables = Node3D.new()
		head.add_child(wieldables)

		firearm = FakeFirearm.new()
		wieldables.add_child(firearm)

	## Pose Head the way player_lean.gd does: lateral offset + roll on Head itself.
	func lean(full: bool) -> void:
		head.position.x = FULL_LEAN_X if full else 0.0
		head.rotation.z = deg_to_rad(FULL_LEAN_ROLL_DEG) if full else 0.0


var _frames: int = 0


func _initialize() -> void:
	# Physics-free unit tests can run immediately.
	test_obstruction_firing_suspension_holds_pose()
	test_obstruction_cant_always_swings_muzzle_left()
	test_obstruction_source_has_no_lean_dampening_and_no_side_picking()


func _process(_delta: float) -> bool:
	# Bodies only register with the physics space after a step, so wait before shape-casting.
	_frames += 1
	if _frames < 3:
		return false

	test_obstruction_barrel_in_wall_upright_obstructs()
	test_obstruction_barrel_in_wall_while_leaned_still_obstructs()
	test_obstruction_barrel_clear_of_wall_does_not_obstruct()

	print("Weapon obstruction lean regression: PASS")
	return true


# ── Physics tests ────────────────────────────────────────────────────────────────────────

## Baseline: the box sweep must detect a wall the barrel crosses. If this fails, the lean
## test below proves nothing.
func test_obstruction_barrel_in_wall_upright_obstructs() -> void:
	# Arrange
	var rig := Rig.new()
	root.add_child(rig)
	rig.lean(false)
	var obs = WeaponObstruction.new()

	# Act — delta 1.0 makes the exp smoothing settle in one tick (deterministic).
	obs.tick(1.0, rig.cast, rig.wieldables, rig.firearm, rig.player)

	# Assert — barrel spans z -0.3..-1.6 through a wall at z -1.0.
	assert(obs.strength > 0.0,
		"a barrel crossing a wall must obstruct — got strength %f" % obs.strength)
	assert(obs.rot_offset_deg.length() > 0.0,
		"obstruction strength must produce a cant on the gun")
	rig.free()


## THE regression. Old code: _lean_dampen() returned 0.0 at full lean, so strength was
## exactly 0 and the gun poked through the wall untouched.
func test_obstruction_barrel_in_wall_while_leaned_still_obstructs() -> void:
	# Arrange — same wall, same barrel, but Head posed as player_lean.gd poses it at full lean.
	var rig := Rig.new()
	root.add_child(rig)
	rig.lean(true)
	# The old code read lean_amount off a PlayerLean child; give it one so this test would
	# have actually exercised the dampening path it is guarding against.
	var lean_node := Node.new()
	lean_node.name = "PlayerLean"
	lean_node.set_script(null)
	rig.player.add_child(lean_node)
	var obs = WeaponObstruction.new()

	# Act
	obs.tick(1.0, rig.cast, rig.wieldables, rig.firearm, rig.player)

	# Assert
	assert(obs.strength > 0.0,
		"leaning must NOT switch obstruction off — the barrel is still in the wall (strength %f)"
			% obs.strength)
	rig.free()


## The floor/clear path: no wall in front of the barrel means no cant.
func test_obstruction_barrel_clear_of_wall_does_not_obstruct() -> void:
	# Arrange — walk the whole rig far enough back that the barrel stops short of the wall.
	var rig := Rig.new()
	root.add_child(rig)
	rig.lean(false)
	rig.player.position.z = 2.0
	var obs = WeaponObstruction.new()

	# Act
	obs.tick(1.0, rig.cast, rig.wieldables, rig.firearm, rig.player)

	# Assert
	assert(obs.strength == 0.0,
		"a barrel clear of geometry must not obstruct — got strength %f" % obs.strength)
	assert(obs.rot_offset_deg == Vector3.ZERO, "no obstruction means no cant")
	rig.free()


# ── Unit tests (no physics) ──────────────────────────────────────────────────────────────

## Starting a spray must not fast-decay an already-canted weapon. The probe is suspended
## while firing, so hold the last pose and resume probing on release.
func test_obstruction_firing_suspension_holds_pose() -> void:
	# Arrange
	var obs = WeaponObstruction.new()
	obs._smoothed_t = 0.72
	var firearm := FakeFirearm.new()
	firearm.suspended = true
	var cast := ShapeCast3D.new()
	var wieldables := Node3D.new()
	var player := CharacterBody3D.new()

	# Act
	obs.tick(1.0 / 60.0, cast, wieldables, firearm, player)

	# Assert
	assert(is_equal_approx(obs._smoothed_t, 0.72),
		"firing suspension must hold the current obstruction pose, not snap it toward neutral")
	assert(is_equal_approx(obs.strength, 0.72))
	cast.free()
	wieldables.free()
	firearm.free()
	player.free()


## A right-handed shooter pivots the rifle around the grip in their right hand, so the barrel
## can only come back ACROSS the body — screen-left. The cant used to be probe-driven (the wall
## normal picked a side), so a wall on your left canted the muzzle right: a wrist no one has.
## Godot's +Y rotation takes forward (-Z) toward -X, so a LEFT swing is a POSITIVE yaw.
func test_obstruction_cant_always_swings_muzzle_left() -> void:
	# Arrange
	var obs = WeaponObstruction.new()
	var firearm := FakeFirearm.new()

	# Act
	obs._apply_pose(firearm, 1.0)

	# Assert
	assert(obs.rot_offset_deg.y > 0.0,
		"the muzzle must swing screen-LEFT (positive yaw) for a right-handed grip — got yaw %f"
			% obs.rot_offset_deg.y)
	assert(is_equal_approx(obs.rot_offset_deg.y, firearm.obstruction_yaw_deg),
		"full strength must reach the configured yaw")
	assert(obs.pos_offset.x < 0.0, "the lateral slide must follow the muzzle, leftward")
	firearm.free()


## Source contract: both bugs here were deliberate behaviours someone wrote on purpose.
## Make them hard to reintroduce.
func test_obstruction_source_has_no_lean_dampening_and_no_side_picking() -> void:
	# Arrange
	var path := "res://Scripts/Weapons/Helpers/weapon_obstruction.gd"
	var src := FileAccess.get_file_as_string(path)

	# Assert
	assert(not src.is_empty(), "Could not read " + path)
	assert(not src.contains("_lean_dampen") and not src.contains("lean_amount"),
		"obstruction must not read lean at all — the probe follows the gun through Head instead")
	assert(not src.contains("_side_sign") and not src.contains("_side_target"),
		"the cant side is fixed by the shooter's handedness (CANT_SIDE), never probe-driven")
