extends SceneTree

const WEAPON_RECOIL = preload("res://Scripts/Weapons/weapon_recoil.gd")

signal inventory_button_press(inventory_data, index: int, action: String)

func _init() -> void:
	_test_bound_inventory_callable()
	_test_recoil_smoothing()
	_assert_source_contracts()
	print("Inventory and recoil regression checks: PASS")
	quit()


func _test_bound_inventory_callable() -> void:
	var marker := Node.new()
	var callback := _on_inventory_button_press.bind(marker)
	inventory_button_press.connect(callback)
	assert(inventory_button_press.is_connected(callback))
	inventory_button_press.disconnect(callback)
	assert(not inventory_button_press.is_connected(callback))


func _test_recoil_smoothing() -> void:
	var slow := WEAPON_RECOIL.smoothing_weight(4.0, 0.1)
	var fast := WEAPON_RECOIL.smoothing_weight(8.0, 0.1)
	var long_frame := WEAPON_RECOIL.smoothing_weight(6.0, 1.0)
	assert(fast > slow)
	assert(long_frame > 0.0 and long_frame < 1.0)
	assert(is_zero_approx(WEAPON_RECOIL.smoothing_weight(0.0, 1.0)))


func _assert_source_contracts() -> void:
	_assert_contains("res://addons/cogito/InventoryPD/UiScenes/inventory_interface.gd", "var _external_inventory_button_press: Callable")
	_assert_contains("res://addons/cogito/InventoryPD/UiScenes/inventory_interface.gd", "inventory_button_press.disconnect(inventory_button_callback)")
	_assert_contains("res://Scripts/Inventory/equipment_slot_ui.gd", "func _disconnect_tracked_inventory() -> void:")
	_assert_contains("res://Scripts/Inventory/equipment_slot_ui.gd", "_disconnect_tracked_inventory()")
	_assert_contains("res://addons/cogito/InventoryPD/UiScenes/InventoryUI.gd", "loaded_inventory_data.inventory_updated.disconnect(populate_item_grid)")
	_assert_contains("res://Scripts/Weapons/cogito_weapon.gd", "rn.return_speed = weapon_data.recoilRecovery")
	_assert_contains("res://Scripts/Weapons/weapon_recoil.gd", "return 1.0 - exp(-maxf(speed, 0.0) * maxf(delta, 0.0))")


func _assert_contains(path: String, expected: String) -> void:
	var source := FileAccess.get_file_as_string(path)
	assert(not source.is_empty(), "Could not read " + path)
	assert(source.contains(expected), path + " is missing: " + expected)


func _on_inventory_button_press(_inventory_data, _index: int, _action: String, _ui: Node) -> void:
	pass