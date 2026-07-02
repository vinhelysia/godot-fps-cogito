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


func _ready() -> void:
	super._ready()
	add_to_group("loot_bag")
	add_to_group("Persist")
	call_deferred("_set_up_references")


## Deferred (like LootDropContainer._set_up_references()) so this doesn't run
## while the scene tree is still mid-setup for whatever spawned this corpse.
func _set_up_references() -> void:
	var player := get_tree().get_first_node_in_group("Player")
	if player == null:
		return
	var player_hud: CogitoPlayerHudManager = player.find_child("Player_HUD", true, true)
	if player_hud == null:
		return
	if not toggle_inventory.is_connected(player_hud.toggle_inventory_interface):
		toggle_inventory.connect(player_hud.toggle_inventory_interface)


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
