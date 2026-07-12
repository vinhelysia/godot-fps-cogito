class_name CorpseContainer extends CogitoContainer

## Tarkov-style corpse loot node. Holds the SAME CogitoEquipment/CogitoInventory
## instances the dead NPC actually fought with (handed over by reference from
## NPCLootComponent at death, BEFORE this node enters the tree) — no
## flattening, no duplication.
##
## `pockets`' setter aliases the inherited `inventory_data` (CogitoContainer)
## to the same instance, so every existing call site that expects
## external_inventory_owner.inventory_data (take-all, inventory_button_press
## connect, CogitoContainer._ready()'s own apply_initial_inventory() call)
## keeps working with zero changes and zero null checks — it's just reading
## the NPC's real pockets instead of a container-local one.
##
## Follows the loot_chest.tscn / LootDropContainer interactable pattern
## (interact -> toggle_inventory signal -> player HUD -> inventory_interface
## .set_external_inventory), but only the pieces actually needed here — no
## despawn timers/logic (out of scope for a corpse).

@export var equipment: CogitoEquipment
@export var pockets: CogitoInventory:
	set(value):
		pockets = value
		inventory_data = value

## Group tag set on mannequin_ragdoll.tscn's root — see _find_ragdoll_bones().
const RAGDOLL_GROUP := "corpse_ragdoll"
## Topmost PhysicalBone3D in the rig: there is no "DEF-head" physical bone (the
## skeleton has that bone, the simulator does not), so the head volume rides the neck.
const BONE_HEAD := "DEF-neck"
const BONE_TORSO := "DEF-spine.002"
const BONE_PELVIS := "DEF-hips"
## Bone tracking (Task 2) only runs within this range of the player — matches
## the loot-anywhere-on-body requirement without paying a per-frame cost for
## every corpse in the level.
const TRACK_RADIUS := 5.0

@onready var head_shape: CollisionShape3D = $HeadShape
@onready var torso_shape: CollisionShape3D = $TorsoShape
@onready var pelvis_shape: CollisionShape3D = $PelvisShape

var _player: Node3D
var _bone_head: PhysicalBone3D
var _bone_torso: PhysicalBone3D
var _bone_pelvis: PhysicalBone3D


func _ready() -> void:
	super._ready()
	add_to_group("loot_bag")
	add_to_group("Persist")
	call_deferred("_set_up_references")


## Deferred (like LootDropContainer._set_up_references()) so this doesn't run
## while the scene tree is still mid-setup for whatever spawned this corpse.
func _set_up_references() -> void:
	_player = get_tree().get_first_node_in_group("Player")
	if _player == null:
		return
	var player_hud: CogitoPlayerHudManager = _player.find_child("Player_HUD", true, true)
	if player_hud == null:
		return
	if not toggle_inventory.is_connected(player_hud.toggle_inventory_interface):
		toggle_inventory.connect(player_hud.toggle_inventory_interface)
	_find_ragdoll_bones()


## CogitoHealthAttribute.on_death() (addons/cogito, not whitelisted for this
## task) spawns mannequin_ragdoll.tscn synchronously — before this corpse's
## own (deferred) _ready() even runs — at the exact same death position, but
## hands back no reference. Matching by group + nearest-distance instead of
## touching that spawner is the only way to find it without editing an
## out-of-whitelist file. "claimed" metadata guards the rare case of two
## NPCs dying close together in the same frame.
func _find_ragdoll_bones() -> void:
	var best: Node3D = null
	var best_dist := INF
	for ragdoll in get_tree().get_nodes_in_group(RAGDOLL_GROUP):
		if ragdoll.get_meta("claimed", false):
			continue
		var dist: float = ragdoll.global_position.distance_to(global_position)
		if dist < best_dist:
			best_dist = dist
			best = ragdoll
	if best == null:
		push_warning("CorpseContainer (%s): no unclaimed mannequin_ragdoll found nearby — loot volumes will stay at their default standing pose instead of following the corpse." % name)
		return

	best.set_meta("claimed", true)
	# Track the PhysicalBone3D nodes, NOT Skeleton3D.get_bone_global_pose(): a
	# PhysicalBoneSimulator3D drives the skin, but the skeleton's bone poses keep
	# reporting the *animated* (standing) pose. Tracking those left the three loot
	# volumes standing in an invisible column at the death spot while the body lay
	# on the floor a metre away — the only place an interaction ray still crossed
	# that column was the bottom sphere, so a corpse could only be looted by aiming
	# at its feet. The physical bones ARE the simulation, so they cannot drift.
	var simulator := best.get_node_or_null(
		"Rig/SkeletonRagdoll/PhysicalBoneSimulator3D") as PhysicalBoneSimulator3D
	if simulator == null:
		push_warning("CorpseContainer (%s): matched ragdoll has no PhysicalBoneSimulator3D — loot volumes will not follow the corpse." % name)
		return

	for child in simulator.get_children():
		var bone := child as PhysicalBone3D
		if bone == null:
			continue
		match bone.bone_name:
			BONE_HEAD:
				_bone_head = bone
			BONE_TORSO:
				_bone_torso = bone
			BONE_PELVIS:
				_bone_pelvis = bone

	if _bone_head == null or _bone_torso == null or _bone_pelvis == null:
		push_warning("CorpseContainer (%s): ragdoll is missing one of the tracked physical bones (%s / %s / %s) — that loot volume will not follow the corpse." % [
			name, BONE_HEAD, BONE_TORSO, BONE_PELVIS])

	# Deliberately NOT reparenting onto the ragdoll here (scene-tree-wise this
	# stays a child of current_scene, same as before): CorpseContainer.save()
	# persists get_parent().get_path(), and load_scene_state() (cogito_scene_
	# manager.gd) does get_node(node_data["parent"]).add_child(new_object) —
	# if that parent were the ragdoll (never in the "Persist" group, freshly
	# re-instantiated with a different name every death, never saved), the
	# saved path would resolve to nothing after a reload and the corpse would
	# silently never re-enter the tree. Tracking bone positions every physics
	# frame (below) rides the body just as well without that regression.


func _physics_process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if global_position.distance_to(_player.global_position) > TRACK_RADIUS:
		return
	_track_bone(head_shape, _bone_head)
	_track_bone(torso_shape, _bone_torso)
	_track_bone(pelvis_shape, _bone_pelvis)


## Sphere volumes — position is all that matters, so don't drag the bone's rotation
## (or its scale) onto the shape.
func _track_bone(shape: CollisionShape3D, bone: PhysicalBone3D) -> void:
	if bone == null or not is_instance_valid(bone):
		return
	shape.global_position = bone.global_position


## CogitoContainer.save() (read-only base) has no idea `equipment` exists —
## its returned dict only carries what CogitoContainer itself knows about
## (inventory_data, display_name, transform, etc.), so without this override
## `equipment` would silently vanish on the next save/load cycle even though
## `pockets`/inventory_data survives fine (CogitoSceneState round-trips the
## WHOLE saved dict through Godot's own ResourceSaver/ResourceLoader, which
## natively handles nested Resource graphs like CogitoEquipment/
## InventorySlotPD/InventoryItemPD — the gap is purely "the base save()
## doesn't emit this key", not a serialization limitation). Overriding
## save() to add one extra key — not touching the save system itself — is
## the same pattern LootDropContainer.gd already uses for its own extra
## fields (start_time/end_time/time_left/initial_spawn).
func save() -> Dictionary:
	var node_data: Dictionary = super.save()
	node_data["equipment"] = equipment
	return node_data


## Called (deferred) by CogitoSceneManager.load_scene_state() after restoring
## this node's saved properties. That restore loop does
## new_object.set("inventory_data", ...) directly — bypassing the `pockets`
## setter above — so `pockets` itself would read null post-load even though
## inventory_data (the same data) is correctly restored. Re-sync it here.
## Also verifies the save() fix above actually worked: if `equipment` still
## comes back null (e.g. a save file written before this fix existed), this
## does NOT crash — it just logs once so the gap is visible instead of silent.
func set_state() -> void:
	super.set_state()
	pockets = inventory_data
	if equipment == null:
		push_warning("CorpseContainer (%s): 'equipment' came back null after a save/load cycle — this corpse's equipped weapon/gear did not survive (pockets should still be intact)." % name)
