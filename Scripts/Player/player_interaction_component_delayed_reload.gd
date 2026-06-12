extends PlayerInteractionComponent
class_name PlayerInteractionComponentDelayedReload

func attempt_reload() -> void:
	var inventory: CogitoInventory = get_parent().inventory_data
	if inventory == null:
		CogitoGlobals.debug_log(true, "PIC", "Player inventory was null!")
		return

	if equipped_wieldable_node == null or equipped_wieldable_item == null:
		return

	if equipped_wieldable_node.animation_player.is_playing():
		CogitoGlobals.debug_log(true, "PIC", "Can't interrupt current action / animation.")
		return

	if equipped_wieldable_item.no_reload:
		return

	var ammo_needed: int = ceili(equipped_wieldable_item.charge_max - equipped_wieldable_item.charge_current)
	if ammo_needed <= 0:
		CogitoGlobals.debug_log(true, "PIC", "Wieldable is fully charged.")
		return

	if equipped_wieldable_item.get_item_amount_in_inventory(equipped_wieldable_item.ammo_item_name) <= 0:
		CogitoGlobals.debug_log(true, "PIC", "You have no ammo for this wieldable.")
		return

	equipped_wieldable_node.reload()
