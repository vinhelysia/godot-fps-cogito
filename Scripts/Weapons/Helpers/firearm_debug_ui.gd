class_name FirearmDebugUI
extends CanvasLayer

var label: Label


func _ready() -> void:
	# Create a simple PanelContainer
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 20)
	panel.position = Vector2(20, 180) # Position below potential Cogito top UI elements
	panel.custom_minimum_size = Vector2(260, 160)
	
	# Create margin container for padding
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	
	# Add Label
	label = Label.new()
	label.add_theme_color_override("font_color", Color.GREEN)
	label.text = "Firearm Debug Initializing..."
	
	margin.add_child(label)
	panel.add_child(margin)
	add_child(panel)


func update_debug_info(weapon_name: String, state_str: String, mechanics: FirearmMechanicalState) -> void:
	if label == null or mechanics == null:
		return
		
	var text := "=== FIREARM DEBUG ===\n"
	text += "Weapon Name: %s\n" % weapon_name
	text += "Action State: %s\n" % state_str
	text += "---------------------\n"
	text += "Chamber: %d / %d\n" % [mechanics.chamber_rounds, mechanics.chamber_capacity]
	text += "Magazine: %d / %d\n" % [mechanics.magazine_rounds, mechanics.magazine_capacity]
	text += "Total Loaded: %d\n" % mechanics.get_loaded_total()
	text += "Bolt Locked Open: %s\n" % str(mechanics.bolt_locked_open)
	
	label.text = text
