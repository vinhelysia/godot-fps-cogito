extends SceneTree

const SCOPE_SCENE := preload("res://Scene/Attachment/Scope/TAC30_1-4x24_riflescope/TAC30_1-4x24_riflescope.tscn")
const PROJECTILE_SCENES := [
	"res://Scene/Weapons/ProjectilesAndShells/7.62x39/7.62x39 projectile.tscn",
	"res://Scene/Weapons/ProjectilesAndShells/7.62x51/7.62x51 projectile.tscn",
	"res://Scene/Weapons/ProjectilesAndShells/45. ACP/45acp projectile.tscn",
]
const DEAD_SUBVIEWPORT_SCENES := [
	"res://Scene/Weapons/Firearms/Bolt-action/M700/m700.tscn",
	"res://Scene/Weapons/Firearms/AR/AK47/AK47.tscn",
	"res://Scene/Weapons/Firearms/Pistol/USP/USP.tscn",
	"res://Scene/Weapons/Firearms/Pistol/USP/USP_drop.tscn",
	"res://Scene/Items/Bullets/45. ACP/45.ACP_Item.tscn",
]


func _init() -> void:
	_test_projectile_collision_layers()
	_test_scope_packed_scene_property()
	_assert_source_contracts()
	# Scope lifecycle needs one frame for _enter_tree/_ready.
	call_deferred("_run_scope_lifecycle_and_quit")


func _run_scope_lifecycle_and_quit() -> void:
	await _test_scope_render_lifecycle()


func _test_projectile_collision_layers() -> void:
	# Source-only: instantiating CogitoProjectile needs full autoloads and is
	# unnecessary — RigidBody3D defaults are layer=1/mask=1 when omitted.
	for scene_path: String in PROJECTILE_SCENES:
		var source := FileAccess.get_file_as_string(scene_path)
		assert(not source.is_empty(), "Could not read " + scene_path)
		assert(source.contains("type=\"RigidBody3D\""), scene_path + " root must be RigidBody3D")
		assert(not source.contains("collision_mask = 8"), scene_path + " must not collide with CorpseBones")
		assert(not source.contains("collision_mask = 4"), scene_path + " must not collide with Corpse loot volumes")
		assert(not source.contains("collision_layer = 8"), scene_path + " must not live on CorpseBones layer")
		# Explicit non-default layer/mask would be written; absence = Godot default 1/1.
		if source.contains("collision_layer"):
			assert(source.contains("collision_layer = 1"), scene_path + " collision_layer must be Environment (1)")
		if source.contains("collision_mask"):
			assert(source.contains("collision_mask = 1"), scene_path + " collision_mask must be Environment (1)")

	var ragdoll_source := FileAccess.get_file_as_string("res://addons/cogito/CogitoNPC/mannequin_ragdoll.tscn")
	assert(ragdoll_source.split("collision_layer = 8").size() - 1 == 40, "Every mannequin PhysicalBone3D must stay on CorpseBones layer")
	assert(not ragdoll_source.contains("collision_layer = 1"), "Ragdoll bones must not share the projectile collision layer")


func _test_scope_packed_scene_property() -> void:
	## Ensure the .tscn actually stores render_target_update_mode (no # comment
	## swallowing the property name — Godot .tscn does not treat # as comments).
	var packed: PackedScene = load("res://Scene/Attachment/Scope/TAC30_1-4x24_riflescope/TAC30_1-4x24_riflescope.tscn")
	var state := packed.get_state()
	var found := false
	for i: int in state.get_node_count():
		if str(state.get_node_type(i)) != "SubViewport":
			continue
		for p: int in state.get_node_property_count(i):
			if str(state.get_node_property_name(i, p)) == "render_target_update_mode":
				found = true
				assert(int(state.get_node_property_value(i, p)) == 0,
						"TAC30 Scope SubViewport packed property must be UPDATE_DISABLED (0)")
	assert(found, "TAC30 Scope SubViewport must pack render_target_update_mode")

	var scope := SCOPE_SCENE.instantiate() as ScopeController
	var viewport := scope.get_node("Scope") as SubViewport
	assert(viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED,
			"Instantiated TAC30 Scope must start UPDATE_DISABLED (before tree entry)")
	scope.free()


func _test_scope_render_lifecycle() -> void:
	var scope := SCOPE_SCENE.instantiate() as ScopeController
	root.add_child(scope)
	await process_frame
	var viewport := scope.get_node("Scope") as SubViewport
	assert(viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Scope viewport must be disabled outside ADS")
	scope.set_rendering_enabled(true)
	assert(viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "Scope viewport must render during ADS")
	scope.set_rendering_enabled(false)
	assert(viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Scope viewport must stop after ADS")
	scope.free()
	print("Projectile and scope regression checks: PASS")
	quit()


func _assert_source_contracts() -> void:
	_assert_not_contains("res://Scripts/Weapons/Weapon_Resource.gd", "_except_corpses")
	_assert_contains("res://Scripts/Weapons/Helpers/ads_controller.gd", "_set_scope_rendering(true)")
	_assert_contains("res://Scripts/Weapons/Helpers/ads_controller.gd", "_set_scope_rendering(false)")
	_assert_contains("res://Scripts/Weapons/scope_controller.gd", "SubViewport.UPDATE_ALWAYS if enabled else SubViewport.UPDATE_DISABLED")
	_assert_contains("res://Scripts/Weapons/scope_controller.gd", "func _enter_tree()")
	_assert_contains("res://Scene/Attachment/Scope/TAC30_1-4x24_riflescope/TAC30_1-4x24_riflescope.tscn", "render_target_update_mode = 0")
	_assert_not_contains("res://Scene/Attachment/Scope/TAC30_1-4x24_riflescope/TAC30_1-4x24_riflescope.tscn", "# UPDATE_DISABLED")
	for scene_path: String in DEAD_SUBVIEWPORT_SCENES:
		_assert_not_contains(scene_path, "[node name=\"SubViewport\" type=\"SubViewport\" parent=\".\"")


func _assert_contains(path: String, expected: String) -> void:
	var source := FileAccess.get_file_as_string(path)
	assert(not source.is_empty(), "Could not read " + path)
	assert(source.contains(expected), path + " is missing: " + expected)


func _assert_not_contains(path: String, unexpected: String) -> void:
	var source := FileAccess.get_file_as_string(path)
	assert(not source.is_empty(), "Could not read " + path)
	assert(not source.contains(unexpected), path + " still contains: " + unexpected)
