extends SceneTree

## Run with: godot --headless --path . -s tests/npc_lifecycle_regression.gd
## Lightweight source contracts for the three lifecycle regressions. They stay
## runnable without introducing a test framework into this project.

func _init() -> void:
	_assert_contains("res://Scripts/Enemies/BT/Tasks/bt_shoot.gd", "const HITSCAN_MASK: int = (1 << 0) | (1 << 4)")
	_assert_contains("res://Scripts/Enemies/BT/Tasks/bt_shoot.gd", "params.collision_mask = HITSCAN_MASK")
	_assert_contains("res://Scripts/Enemies/HostileNPC.gd", "remove_from_group(&\"Persist\")")
	_assert_contains("res://Scripts/Enemies/HostileNPC.gd", "collision_mask = 0")
	_assert_contains("res://Scripts/Enemies/HostileNPC.gd", "perception.call(&\"shutdown\")")
	_assert_contains("res://Scripts/Enemies/HostileNPC.gd", "process_mode = Node.PROCESS_MODE_DISABLED")
	_assert_contains("res://Scripts/Enemies/HostileNPC.gd", "call_deferred(\"queue_free\")")
	_assert_contains("res://Scripts/Enemies/scav_perception.gd", "func shutdown() -> void:")
	_assert_contains("res://Scripts/Enemies/scav_perception.gd", "se.sound_emitted.disconnect(_on_sound_emitted)")
	_assert_contains("res://Scripts/Enemies/corpse_container.gd", "add_to_group(\"Persist\")")
	_assert_contains("res://Scripts/Enemies/npc_loot_component.gd", "corpse.equipment = npc.equipment")
	_assert_contains("res://Scripts/Enemies/npc_loot_component.gd", "corpse.pockets = npc.pockets")
	print("NPC lifecycle regression contracts: PASS")
	quit()


func _assert_contains(path: String, expected: String) -> void:
	var source := FileAccess.get_file_as_string(path)
	assert(not source.is_empty(), "Could not read " + path)
	assert(source.contains(expected), path + " is missing: " + expected)