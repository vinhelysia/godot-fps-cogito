extends Node3D

## Run: godot --headless --path . tests/corpse_loot_volume_regression.tscn
## (a scene, not `-s`: CorpseContainer's dependency chain needs the Cogito autoloads)
##
## Regression for "a dead body can only be looted by aiming at its feet".
## CorpseContainer's three loot volumes used to be positioned from
## Skeleton3D.get_bone_global_pose(), which does NOT follow a
## PhysicalBoneSimulator3D ragdoll — it keeps reporting the animated (standing)
## pose. The volumes therefore stood in an invisible column at the death spot
## while the body lay on the floor a metre away, and the only place the player's
## interaction ray still crossed that column was the bottom of the lowest sphere.

const RAGDOLL := preload("res://addons/cogito/CogitoNPC/mannequin_ragdoll.tscn")
const CORPSE := preload("res://Scene/Enemies/CorpseContainer.tscn")

## Ragdoll needs to actually flop over before the volumes mean anything.
const SETTLE_FRAMES := 180
## Shape rides its bone — allow only float / one-physics-frame slack.
const TRACK_TOLERANCE := 0.05


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_loot_volumes_follow_ragdoll_bones_to_the_ground()
	print("Corpse loot volume regression: PASS")
	get_tree().quit()


func _test_loot_volumes_follow_ragdoll_bones_to_the_ground() -> void:
	# ── Arrange ──────────────────────────────────────────────────────────────
	_add_floor()

	var ragdoll := RAGDOLL.instantiate() as Node3D
	add_child(ragdoll)
	ragdoll.global_position = Vector3.ZERO

	var corpse := CORPSE.instantiate() as CorpseContainer
	corpse.pockets = CogitoInventory.new()
	add_child(corpse)
	corpse.global_position = Vector3.ZERO

	# Stand in for the player: _physics_process only tracks within TRACK_RADIUS.
	# (_set_up_references() is skipped — it needs a real Player_HUD to wire the loot
	# UI signal, which has nothing to do with where the volumes end up.)
	var player := Node3D.new()
	player.add_to_group("Player")
	add_child(player)
	player.global_position = Vector3(1.0, 0.0, 0.0)
	corpse._player = player
	corpse._find_ragdoll_bones()

	assert(corpse._bone_head != null and corpse._bone_torso != null and corpse._bone_pelvis != null,
		"CorpseContainer must resolve all three PhysicalBone3D nodes off the ragdoll simulator")

	# ── Act ──────────────────────────────────────────────────────────────────
	for _frame: int in SETTLE_FRAMES:
		await get_tree().physics_frame

	# ── Assert ───────────────────────────────────────────────────────────────
	var pairs := [
		["head", corpse.head_shape, corpse._bone_head],
		["torso", corpse.torso_shape, corpse._bone_torso],
		["pelvis", corpse.pelvis_shape, corpse._bone_pelvis],
	]
	for pair: Array in pairs:
		var label: String = pair[0]
		var shape: CollisionShape3D = pair[1]
		var bone: PhysicalBone3D = pair[2]
		var drift: float = shape.global_position.distance_to(bone.global_position)
		assert(drift <= TRACK_TOLERANCE,
			"%s loot volume must ride its physical bone (drift %.3f m > %.3f m)" % [
				label, drift, TRACK_TOLERANCE])

	# The whole point: the body is on the floor, so the volumes must be too — not
	# left standing at chest height like the old skeleton-pose tracking did.
	var settled_pelvis: float = corpse.pelvis_shape.global_position.y
	assert(settled_pelvis < 0.5,
		"a collapsed ragdoll's pelvis volume must end up near the floor, not standing at %.2f m" % settled_pelvis)


func _add_floor() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(20.0, 1.0, 20.0)
	collision.shape = shape
	body.add_child(collision)
	body.global_position = Vector3(0.0, -0.5, 0.0)
