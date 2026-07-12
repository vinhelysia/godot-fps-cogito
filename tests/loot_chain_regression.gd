extends Node3D

## Run: godot --headless --path . tests/loot_chain_regression.tscn
##
## Regression for "I can't loot anything / no loot icons".
##
## Root cause was NOT in the loot code: a deleted mesh
## (Assets/Blender/pbs1_762x39_visual.glb -> Scene/Attachment/Muzzle/suppressor.tscn)
## made suppressor_item.tres unparseable, which made scav_loadout.tres unparseable
## (ONE dead ext_resource kills the WHOLE .tres), which left Scav.tscn's `loadout`
## null. HostileNPC._ready() then quietly skipped _apply_loadout(), so `equipment`
## and `pockets` were never built and every corpse was empty.
##
## Two guards:
##  1. no dangling res:// reference anywhere in the content the game actually loads
##  2. the scav loadout chain resolves end-to-end and rolls a real weapon

const SCAV_LOADOUT := "res://Scene/Enemies/Loadouts/scav_loadout.tres"
const SCAV_SCENE := "res://Scene/Enemies/Scav.tscn"

## Scene/VFX is excluded on purpose: it still holds orphaned BinbunVFX muzzle-flash
## variants pointing at a lowercase res://assets/... tree that no longer exists. They
## are referenced by nothing, so they never load and never error at runtime — dead
## files, not a live break. Delete them (or repoint them) and this list can go.
const SCANNED_DIRS: Array[String] = [
	"res://Scene/Enemies",
	"res://Scene/Items",
	"res://Scene/Weapons",
	"res://Scene/Attachment",
	"res://Scene/Object",
]
const SCANNED_FILES: Array[String] = [
	"res://Scene/Town.tscn",
]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_content_has_no_dangling_resource_references()
	_test_scav_loadout_chain_resolves_and_rolls_a_weapon()
	_test_scav_scene_carries_a_loadout()
	print("Loot chain regression: PASS")
	get_tree().quit()


## One deleted asset anywhere in a loot chain silently empties every corpse, so the
## cheapest guard is: nothing the game loads may point at a file that isn't there.
func _test_content_has_no_dangling_resource_references() -> void:
	# Arrange
	var files: Array[String] = SCANNED_FILES.duplicate()
	for dir: String in SCANNED_DIRS:
		_collect_resource_files(dir, files)
	assert(files.size() > 10, "content scan found almost nothing — the paths are probably wrong")

	# Act
	var dangling: Array[String] = []
	for file: String in files:
		for referenced: String in _referenced_paths(file):
			if not ResourceLoader.exists(referenced) and not FileAccess.file_exists(referenced):
				dangling.append("%s -> %s" % [file, referenced])

	# Assert
	assert(dangling.is_empty(),
		"dangling resource reference(s) — a single one kills the whole .tres/.tscn that names it:\n  %s"
			% "\n  ".join(dangling))


func _test_scav_loadout_chain_resolves_and_rolls_a_weapon() -> void:
	# Arrange
	var loadout := ResourceLoader.load(SCAV_LOADOUT) as NPCLoadout

	# Assert — a broken ext_resource anywhere below this returns null, not a partial resource.
	assert(loadout != null, "scav_loadout.tres failed to load — its resource chain is broken")
	assert(not loadout.weapon_options.is_empty(), "scav loadout has no weapon options")
	assert(loadout.pocket_loot_table != null, "scav loadout lost its pocket loot table — corpses would carry no loot")

	for option: NPCWeaponOption in loadout.weapon_options:
		assert(option != null, "a weapon option came back null (broken sub-resource)")
		assert(option.wieldable != null and option.weapon_data != null and option.ammo_item != null,
			"weapon option is missing wieldable / weapon_data / ammo_item")
		for attachment: AttachmentItemPD in option.attachment_options:
			assert(attachment != null,
				"an attachment option came back null — that alone nulls the whole loadout resource")

	# Act
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var result: Dictionary = loadout.roll(rng)

	# Assert
	assert(result.get("weapon_option") != null, "loadout.roll() produced no weapon — NPC would spawn unarmed")


func _test_scav_scene_carries_a_loadout() -> void:
	# Arrange / Act
	var scav := (ResourceLoader.load(SCAV_SCENE) as PackedScene).instantiate() as HostileNPC

	# Assert — null here is exactly what emptied every corpse.
	assert(scav.loadout != null,
		"Scav.tscn has no loadout — HostileNPC._ready() skips _apply_loadout(), so equipment/pockets stay null and the corpse is empty")
	scav.queue_free()


func _collect_resource_files(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := dir_path.path_join(entry)
		if dir.current_is_dir():
			_collect_resource_files(full, out)
		elif entry.ends_with(".tscn") or entry.ends_with(".tres"):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()


## Pull every `path="res://..."` out of a text scene/resource. Reading the raw text
## (rather than load()ing) is the point: load() returns null on a broken chain and
## tells us nothing about WHICH reference died.
func _referenced_paths(file_path: String) -> Array[String]:
	var text := FileAccess.get_file_as_string(file_path)
	var paths: Array[String] = []
	var regex := RegEx.new()
	regex.compile('path="(res://[^"]+)"')
	for m: RegExMatch in regex.search_all(text):
		paths.append(m.get_string(1))
	return paths
