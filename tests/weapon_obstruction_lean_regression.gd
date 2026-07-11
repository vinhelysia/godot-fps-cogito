extends SceneTree

## Run: godot --headless --path . -s tests/weapon_obstruction_lean_regression.gd
## Regression for the "snap toward lean side" bug: leaning near a wall while
## obstructed collapsed wall-cant strength in 2-3 frames (several degrees of
## Wieldables rotation in one frame), and reset() re-armed it to full strength
## the instant a spray's fast decay settled to zero while still fully leaned.

const WeaponObstruction = preload("res://Scripts/Weapons/Helpers/weapon_obstruction.gd")

func _init() -> void:
	_test_decay_reset_preserves_lean_mul()
	_test_lean_dampen_speed_is_reasonable()
	_assert_source_contracts()
	print("Weapon obstruction lean regression: PASS")
	quit()


## reset() is called from _decay() every time normal wall-distance decay
## settles to ~0 — which happens routinely mid-spray (should_suspend_
## container_motion branch). It must not also zero _smoothed_lean_mul, or
## a spray that outlasts lean's own decay-to-0 snaps wall-cant back to full
## strength for one frame right as firing ends while still fully leaned.
func _test_decay_reset_preserves_lean_mul() -> void:
	var obs = WeaponObstruction.new()
	obs._smoothed_lean_mul = 0.0
	obs._smoothed_t = 0.01
	obs._decay(1.0, 30.0)
	assert(obs._smoothed_t < 0.001, "large delta should settle _smoothed_t to ~0")
	assert(is_equal_approx(obs._smoothed_lean_mul, 0.0),
		"reset() must not clobber _smoothed_lean_mul back to 1.0 mid-lean")


func _test_lean_dampen_speed_is_reasonable() -> void:
	assert(WeaponObstruction.LEAN_DAMPEN_SPEED > 0.0)
	assert(WeaponObstruction.LEAN_DAMPEN_SPEED <= 10.0,
		"lean dampening must not be faster than default obstruction_smooth_speed (10), or it re-collapses in 2-3 frames")


func _assert_source_contracts() -> void:
	var path := "res://Scripts/Weapons/Helpers/weapon_obstruction.gd"
	var src := FileAccess.get_file_as_string(path)
	assert(not src.is_empty(), "Could not read " + path)

	# Lean dampening must go through its own filter, not a raw multiply.
	assert(src.contains("_smoothed_lean_mul = lerpf(_smoothed_lean_mul"),
		"lean dampening must be smoothed independently, not applied as a raw multiply")
	assert(not src.contains("raw_t *= lean_mul"),
		"raw_t must be dampened by the smoothed filter (_smoothed_lean_mul), not raw lean_mul")

	# Must update before the firing-suspend early-return, or it goes stale mid-spray.
	# (Search inside tick() only — reset()'s comment above also names the branch.)
	var tick_body_start: int = src.find("func tick(")
	assert(tick_body_start != -1)
	var lean_update_i: int = src.find("_smoothed_lean_mul = lerpf", tick_body_start)
	var suspend_branch_i: int = src.find("firearm.has_method(\"should_suspend_container_motion\")", tick_body_start)
	assert(lean_update_i != -1 and suspend_branch_i != -1 and lean_update_i < suspend_branch_i,
		"lean dampening must be advanced before the firing-suspend branch, or it freezes stale mid-spray")

	# reset() must not touch _smoothed_lean_mul.
	var reset_start: int = src.find("func reset() -> void:")
	var tick_start: int = src.find("func tick(")
	assert(reset_start != -1 and tick_start != -1 and reset_start < tick_start)
	var reset_body := src.substr(reset_start, tick_start - reset_start)
	assert(not reset_body.contains("_smoothed_lean_mul ="),
		"reset() must not touch _smoothed_lean_mul (called routinely mid-spray via _decay)")
