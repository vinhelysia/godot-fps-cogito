extends Node

## Run: godot --headless --path . res://tests/gun_locker_door_regression.tscn
## (Must run as a SCENE, not with -s: cogito_door.gd needs the CogitoGlobals autoload.)
##
## GunLocker.tscn is an unpacked copy of the Blender export (meshes are sub_resources, so it does
## NOT re-import from Assets/Blender/GunLocker.glb on its own). The door is a CogitoDoor only
## because GunLocker_door_hinge was hand-promoted from the exported Node3D to an AnimatableBody3D
## and given the script, a collider, audio and a BasicInteraction.
##
## So: editing the model in Blender is safe, but REGENERATING this scene from the .glb throws all
## of that away — with no error and no warning. The door just quietly stops being interactable.
## This suite is the alarm for that.

const LOCKER := "res://Scene/Object/Deco/Locker/GunLocker.tscn"
const DOOR_PATH := "GunLocker3/GunLocker/GunLocker_door_hinge"
## Blender's door_open ends on quaternion (0, 0.6755903, 0, 0.7372773) = 85 deg about +Y.
const OPEN_YAW := 85.0

## Deliberately typed Node3D, not CogitoDoor: the script's base IS Node3D, so a CogitoDoor-typed
## var makes the compiler reject `is AnimatableBody3D` as impossible — which is the very thing this
## suite has to assert (the node is an AnimatableBody3D wearing a Node3D-based script).
var _door: Node3D


func _ready() -> void:
	var locker: Node = (load(LOCKER) as PackedScene).instantiate()
	add_child(locker)
	_door = locker.get_node(DOOR_PATH) as Node3D

	test_locker_door_is_a_wired_cogito_door()
	await test_locker_door_open_swings_to_the_blender_open_angle()
	await test_locker_door_reopens_from_a_save_taken_while_open()

	print("Gun locker door regression: PASS")
	get_tree().quit()


func test_locker_door_is_a_wired_cogito_door() -> void:
	# Assert — the promotion from the raw Blender Node3D survived.
	assert(_door != null, "%s is missing — was the Blender model re-imported?" % DOOR_PATH)
	assert(_door is CogitoDoor,
		"%s lost its cogito_door.gd script — was the Blender model re-imported?" % DOOR_PATH)
	assert(_door is AnimatableBody3D,
		"the door must be an AnimatableBody3D: the interaction raycast needs a collider it can hit, "
		+ "and a StaticBody3D would not carry the player when it swings")
	# Layer 1 (Environment) + 2 (Interactables). Layer 2 is what the interaction raycast reads;
	# layer 1 is what the weapon obstruction box and the lean wall probe read.
	assert(_door.collision_layer == 3,
		"door collision_layer must be 3 (Environment + Interactables), got %d" % _door.collision_layer)
	assert(_door.is_in_group("interactable"), "door never joined the interactable group")
	assert(_door.get_node_or_null("CollisionShape3D") != null,
		"the collider must be a DIRECT child of the body, or Godot never registers it")
	assert(_door.get_node_or_null("AudioStreamPlayer3D") != null,
		"cogito_door.gd does @onready $AudioStreamPlayer3D and will crash without it")
	assert(_door.interaction_nodes.size() >= 1, "no InteractionComponent — nothing to interact with")
	# The prompt reads this through the po files; a missing key would show the raw "DOOR_Open".
	assert(tr(_door.interaction_text) == "Open",
		"closed door should prompt 'Open', got '%s'" % tr(_door.interaction_text))


## Reuses the door_open curve Blender exported rather than re-deriving the swing in code.
func test_locker_door_open_swings_to_the_blender_open_angle() -> void:
	# Arrange
	assert(_door.door_type == CogitoDoor.DoorType.ANIMATED, "door should be ANIMATED")
	assert(_door.anim_player != null, "animation_player NodePath did not resolve")
	assert(_door.anim_player.has_animation(_door.opening_animation),
		"AnimationPlayer has no '%s' animation" % _door.opening_animation)

	# Act
	_door.open_door(null)
	await _settle()

	# Assert
	assert(_door.is_open)
	assert(is_equal_approx(snappedf(_door.rotation_degrees.y, 0.1), OPEN_YAW),
		"open door should sit at %.0f deg yaw, got %.1f" % [OPEN_YAW, _door.rotation_degrees.y])
	assert(tr(_door.interaction_text) == "Close")

	# Act
	_door.close_door(null)
	await _settle()

	# Assert
	assert(not _door.is_open)
	assert(is_zero_approx(snappedf(_door.rotation_degrees.y, 0.1)),
		"closed door should return to 0 deg, got %.1f" % _door.rotation_degrees.y)


## set_state() restores a door by ASSIGNING open_rotation, never by replaying the animation — so
## an ANIMATED door whose open_rotation is left at the default (0,0,0) loads back shut no matter
## what the save said. open_rotation is hidden from the inspector for ANIMATED doors, which is
## exactly why this is easy to drop and worth pinning.
func test_locker_door_reopens_from_a_save_taken_while_open() -> void:
	# Arrange
	_door.is_open = true

	# Act
	_door.set_state()
	await _settle()

	# Assert
	assert(is_equal_approx(snappedf(_door.rotation_degrees.y, 0.1), OPEN_YAW),
		"a door saved open must load open (open_rotation must be set), got %.1f deg"
			% _door.rotation_degrees.y)
	assert(tr(_door.interaction_text) == "Close")

	# Cleanup
	_door.is_open = false
	_door.set_state()
	await _settle()


## The door is an AnimatableBody3D with sync_to_physics on, so its transform only lands after a
## physics step — reading it in the same frame you move it reports the stale pose.
func _settle() -> void:
	for i in 90:
		await get_tree().process_frame
		await get_tree().physics_frame
