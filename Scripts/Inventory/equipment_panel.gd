extends HBoxContainer

## Layout-only companion to EquipmentPanel.tscn. Applies EquipmentSlotUI's
## centralized theme constants to the parts of this scene that aren't
## EquipmentSlotUI instances (the two wrapper panels, the POCKETS header) so
## no color/size value is duplicated outside equipment_slot_ui.gd. All data
## wiring (equipment_slots_ui population, reparenting the pockets/external
## inventory UI) is done by inventory_interface.gd, not here.

@onready var left_panel: PanelContainer = $LeftPanel
@onready var right_panel: PanelContainer = $RightPanel
@onready var pockets_header: Label = $RightPanel/RightMargin/RightVBox/PocketsHeader
@onready var pockets_slot: Control = $RightPanel/RightMargin/RightVBox/PocketsSlot


func _ready() -> void:
	var wrapper_style := StyleBoxFlat.new()
	wrapper_style.bg_color = EquipmentSlotUI.COLOR_PANEL_WRAPPER
	wrapper_style.border_color = EquipmentSlotUI.COLOR_BORDER
	wrapper_style.set_border_width_all(EquipmentSlotUI.BORDER_WIDTH)
	wrapper_style.set_corner_radius_all(EquipmentSlotUI.CORNER_RADIUS)
	left_panel.add_theme_stylebox_override("panel", wrapper_style)
	right_panel.add_theme_stylebox_override("panel", wrapper_style)

	pockets_header.text = "POCKETS"
	pockets_header.add_theme_font_size_override("font_size", EquipmentSlotUI.HEADER_FONT_SIZE)
	pockets_header.add_theme_color_override("font_color", EquipmentSlotUI.COLOR_HEADER_TEXT)


## Placeholder container that should receive the pre-existing player_inv_tab
## children (pockets grid + external container area).
func get_pockets_slot() -> Control:
	return pockets_slot


## Every EquipmentSlotUI in this panel, keyed by slot_id.
func collect_equipment_slots() -> Dictionary:
	var result: Dictionary = {}
	for node in find_children("*", "EquipmentSlotUI", true, false):
		var slot := node as EquipmentSlotUI
		if slot:
			result[slot.slot_id] = slot
	return result
