extends InteractionComponent
class_name PickupComponent

@export var slot_data : InventorySlotPD
@export var display_item_name : bool = false

var player_interaction_component


func _enter_tree() -> void:
	if display_item_name:
		var owner_object : CogitoObject = get_parent()
		owner_object.display_name = slot_data.inventory_item.name


func interact(_player_interaction_component: PlayerInteractionComponent):
	if !is_disabled:
		pick_up(_player_interaction_component)


func pick_up(_player_interaction_component: PlayerInteractionComponent):
	### Currency Item handling
	if slot_data.inventory_item is CurrencyItemPD and slot_data.inventory_item.add_on_pickup:
		if slot_data.inventory_item.use(_player_interaction_component.get_parent()):
			#_player_interaction_component.send_hint(slot_data.inventory_item.hint_icon_on_use, slot_data.inventory_item.hint_text_on_use)
			Audio.play_sound(slot_data.inventory_item.sound_pickup)
			was_interacted_with.emit(interaction_text, input_map_action)
			self.get_parent().queue_free()
			return
		else:
			_player_interaction_component.send_hint(slot_data.inventory_item.icon, tr(slot_data.inventory_item.name) + " " +tr("HINT_cant_pick_up") )
			return
	
	if not _player_interaction_component.get_parent().inventory_data.pick_up_slot_data(slot_data):
		return

	# Update wieldable UI if we have picked up ammo for current wieldable
	if _player_interaction_component.is_wielding:
		var is_ammo: bool = slot_data.inventory_item.has_method("is_ammo_item")
		var is_current_ammo: bool = _player_interaction_component.equipped_wieldable_item.ammo_item_name == slot_data.inventory_item.name
		if is_ammo and is_current_ammo:
			var equipped_wieldable = _player_interaction_component.equipped_wieldable_item
			_player_interaction_component.equipped_wieldable_item.update_wieldable_data(_player_interaction_component)


	_player_interaction_component.send_hint(slot_data.inventory_item.icon, tr(slot_data.inventory_item.name) + " " + tr("INVENTORY_add_item") )
	was_interacted_with.emit(interaction_text, input_map_action)
	Audio.play_sound(slot_data.inventory_item.sound_pickup)

	# Multiplayer: disable immediately to block double-pickup during latency,
	# then have the server queue_free() so WeaponSpawner despawns for all peers.
	if multiplayer.get_peers().size() > 0:
		is_disabled = true
		if multiplayer.is_server():
			get_parent().queue_free()
		else:
			_request_server_despawn.rpc_id(1)
	else:
		self.get_parent().queue_free()


## Multiplayer: server-side despawn — WeaponSpawner propagates removal to all clients.
@rpc("any_peer", "reliable")
func _request_server_despawn() -> void:
	if not multiplayer.is_server():
		return
	var pickup := get_parent()
	if is_instance_valid(pickup):
		pickup.queue_free()
