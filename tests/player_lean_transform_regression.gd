extends SceneTree

## Run: godot --headless --path . -s tests/player_lean_transform_regression.gd
## Catches absolute Head writes that would erase recoil/trauma contributions.

func _init() -> void:
	var path := "res://Scripts/Player/player_lean.gd"
	var source := FileAccess.get_file_as_string(path)
	assert(not source.is_empty(), "Could not read " + path)

	# Must track and apply only lean's own contribution.
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

	print("Player lean transform regression: PASS")
	quit()


func _assert_contains(source: String, expected: String) -> void:
	assert(source.contains(expected), "Missing required pattern: " + expected)
