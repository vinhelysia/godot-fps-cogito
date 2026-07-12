extends SceneTree

## Run: godot --headless --path . -s tests/player_lean_transform_regression.gd
## Catches absolute Head writes that would erase recoil/trauma contributions, and camera
## clipping: leaning used to push the camera through walls because the collision box only
## follows a fraction of the lean.

const PlayerLean = preload("res://Scripts/Player/player_lean.gd")

## Full right lean: lateral_amount 0.38 * right_lateral_scale 1.2.
const FULL_RIGHT_CAM_X: float = 0.456
const NEAR_PLANE: float = 0.05


## CharacterBody3D + Body/Neck/Head, with a wall placed a given distance to the player's right.
class Rig:
	extends Node3D
	var player: CharacterBody3D
	var head: Node3D
	var lean: Node

	func _init(wall_at_x: float) -> void:
		if not is_inf(wall_at_x):
			var wall := StaticBody3D.new()
			wall.collision_layer = 1
			wall.position = Vector3(wall_at_x, 0.0, 0.0)
			var cs := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(0.2, 12.0, 12.0)
			cs.shape = box
			wall.add_child(cs)
			add_child(wall)

		player = CharacterBody3D.new()
		player.collision_layer = 1 << 4
		add_child(player)
		var body := Node3D.new()
		body.name = "Body"
		player.add_child(body)
		var neck := Node3D.new()
		neck.name = "Neck"
		neck.position = Vector3(0.0, 0.7, 0.0)
		body.add_child(neck)
		head = Node3D.new()
		head.name = "Head"
		neck.add_child(head)

		lean = Node.new()
		lean.name = "PlayerLean"
		lean.set_script(PlayerLean)
		# _compute_target() reads Input, so drive _wall_clearance() directly instead.
		lean.set("enabled", false)
		player.add_child(lean)


var _frames: int = 0


func _initialize() -> void:
	test_lean_source_never_absolute_writes_head()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 3:
		return false

	test_lean_wall_clearance_open_air_allows_full_lean()
	test_lean_wall_clearance_wall_beside_player_keeps_camera_out_of_wall()

	print("Player lean transform regression: PASS")
	return true


# ── Camera clipping (physics) ────────────────────────────────────────────────────────────

func test_lean_wall_clearance_open_air_allows_full_lean() -> void:
	# Arrange — no wall anywhere.
	var rig := Rig.new(INF)
	root.add_child(rig)

	# Act
	var clearance: float = rig.lean.call("_wall_clearance", FULL_RIGHT_CAM_X)

	# Assert
	assert(is_equal_approx(clearance, 1.0),
		"open air must allow a full lean — got clearance %f" % clearance)
	rig.free()


## THE regression. The player box is 0.6 wide (half 0.3) and only follows 0.38 of the lean, so
## at full right lean the camera sat 17 mm inside the box's own face — less than the near plane.
## A wall flush against the player's right must now cut the lean, not be leaned through.
func test_lean_wall_clearance_wall_beside_player_keeps_camera_out_of_wall() -> void:
	# Arrange — wall face at x = 0.4 (box spans 0.4..0.6), i.e. inside a full 0.456 lean.
	var wall_face_x := 0.4
	var rig := Rig.new(wall_face_x + 0.1)
	root.add_child(rig)
	var radius: float = rig.lean.get("wall_probe_radius")

	# Act
	var clearance: float = rig.lean.call("_wall_clearance", FULL_RIGHT_CAM_X)
	var camera_x := FULL_RIGHT_CAM_X * clearance

	# Assert — the lean must be cut, and the camera must stop short of the wall by more than
	# the near plane, or it renders through it.
	assert(clearance < 1.0,
		"a wall inside the lean arc must cut the lean — got clearance %f" % clearance)
	assert(camera_x < wall_face_x - NEAR_PLANE,
		"camera at x=%f must stay clear of the wall face at x=%f by more than the near plane"
			% [camera_x, wall_face_x])
	# And the probe must not be so eager it blocks the lean entirely from a wall it can clear.
	assert(camera_x >= wall_face_x - radius - 0.05,
		"the lean was cut further than the probe radius justifies (camera_x=%f)" % camera_x)
	rig.free()


# ── Transform ownership (source contract) ────────────────────────────────────────────────

func test_lean_source_never_absolute_writes_head() -> void:
	# Arrange
	var path := "res://Scripts/Player/player_lean.gd"
	var source := FileAccess.get_file_as_string(path)
	assert(not source.is_empty(), "Could not read " + path)

	# Assert — must track and apply only lean's own contribution.
	_assert_contains(source, "var _applied_pos_x: float")
	_assert_contains(source, "var _applied_rot_z: float")
	_assert_contains(source, "_head.position.x += dx")
	_assert_contains(source, "_head.rotation.z += drz")

	# Absolute assignment of the lean channels is forbidden (would wipe shake/recoil).
	# Allow base collision x assignment; only Head absolute writes are the bug.
	assert(not source.contains("_head.position.x ="),
		path + " must not absolute-assign Head.position.x")
	assert(not source.contains("_head.rotation.z ="),
		path + " must not absolute-assign Head.rotation.z")
	assert(not source.contains("_head.rotation_degrees.z ="),
		path + " must not absolute-assign Head.rotation_degrees.z")

	# Recoil still uses subtract-previous / add-current for trauma on Head.
	var recoil_src := FileAccess.get_file_as_string("res://Scripts/Weapons/weapon_recoil.gd")
	_assert_contains(recoil_src, "parent.position -= _shake_offset")
	_assert_contains(recoil_src, "parent.position += _shake_offset")


func _assert_contains(source: String, expected: String) -> void:
	assert(source.contains(expected), "Missing required pattern: " + expected)
