extends InteractionComponent
class_name PickupComponent

const PLAYER_COLLISION_EXCEPTION_RETRY_ATTEMPTS: int = 8
const PLAYER_COLLISION_EXCEPTION_RETRY_DELAY: float = 0.1

@export var slot_data : InventorySlotPD
@export var display_item_name : bool = false
@export var ignore_player_collision: bool = true

var player_interaction_component


func _enter_tree() -> void:
	if display_item_name:
		var owner_object : CogitoObject = get_parent()
		owner_object.display_name = slot_data.inventory_item.name


func _ready() -> void:
	if ignore_player_collision:
		call_deferred("_try_setup_player_collision_exception")


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

	self.get_parent().queue_free()


func _try_setup_player_collision_exception(attempts_remaining: int = PLAYER_COLLISION_EXCEPTION_RETRY_ATTEMPTS) -> void:
	if not is_inside_tree():
		return

	var pickup_body := _find_pickup_physics_body()
	if not pickup_body:
		push_warning("PickupComponent: could not find pickup physics body for collision exception.")
		return

	var player_body := _find_player_body()
	if player_body:
		pickup_body.add_collision_exception_with(player_body)
		return

	if attempts_remaining > 0:
		get_tree().create_timer(PLAYER_COLLISION_EXCEPTION_RETRY_DELAY).timeout.connect(
				_try_setup_player_collision_exception.bind(attempts_remaining - 1),
				CONNECT_ONE_SHOT)
	else:
		push_warning("PickupComponent: could not find player body for collision exception.")


func _find_pickup_physics_body() -> PhysicsBody3D:
	var node: Node = self
	while node:
		if node is PhysicsBody3D:
			return node as PhysicsBody3D
		node = node.get_parent()
	return null


func _find_player_body() -> PhysicsBody3D:
	if is_instance_valid(CogitoSceneManager._current_player_node) and CogitoSceneManager._current_player_node is PhysicsBody3D:
		return CogitoSceneManager._current_player_node as PhysicsBody3D

	for node: Node in get_tree().get_nodes_in_group("Player"):
		if node is PhysicsBody3D:
			return node as PhysicsBody3D
	return null
