extends Node3D

## Run: godot --headless --path . tests/interaction_prompt_regression.tscn
##
## Locks in the crosshair-centric interaction prompt:
##   - the crosshair swap IS the "you can interact" signal, so prompt rows carry no
##     key icon (label only)
##   - rows centre themselves (they sit under the crosshair, not off to one side)
##   - the label says the ACTION ("Loot" / "Open"), so an object-name row is redundant
##   - PromptUI must not world-anchor itself to the interactable any more: for a corpse
##     (prompt_pos_mode = ORIGIN) that parked the label down at the body's origin.

const PROMPT := preload("res://addons/cogito/Components/UI/UI_PromptComponent.tscn")
const CORPSE := preload("res://Scene/Enemies/CorpseContainer.tscn")
const HUD := preload("res://addons/cogito/PackedScenes/Player_HUD.tscn")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_prompt_row_is_label_only_and_centred()
	await _test_corpse_interaction_label_reads_loot()
	_test_prompt_ui_is_not_world_anchored()
	print("Interaction prompt regression: PASS")
	get_tree().quit()


func _test_prompt_row_is_label_only_and_centred() -> void:
	# Arrange
	var prompt: UiPromptComponent = PROMPT.instantiate()
	add_child(prompt)
	await get_tree().process_frame

	# Act
	prompt.set_prompt("Loot", "interact")

	# Assert
	assert(not prompt.input_icon_container.visible,
		"prompt must be label-only — the crosshair already signals 'interactable'")
	assert(prompt.interaction_text.text == "Loot", "prompt label must carry the interaction text")
	assert(prompt.interaction_button.action_name == "interact",
		"action_name must stay set even with the icon hidden — _unhandled_input and UiHoldComponent read it")
	assert(prompt.size_flags_horizontal == Control.SIZE_SHRINK_CENTER,
		"prompt rows must centre under the crosshair, not hug the left edge of the VBox")
	prompt.queue_free()


func _test_corpse_interaction_label_reads_loot() -> void:
	# Arrange
	var corpse := CORPSE.instantiate() as CorpseContainer
	corpse.pockets = CogitoInventory.new()

	# Act — CogitoContainer._ready() emits object_state_updated(text_when_closed), and
	# children are ready before their parent, so BasicInteraction is already listening.
	add_child(corpse)
	await get_tree().process_frame

	# Assert
	var interaction: Node = corpse.get_node("BasicInteraction")
	assert(interaction.interaction_text == "Loot",
		"corpse prompt must read 'Loot', got '%s'" % interaction.interaction_text)
	corpse.queue_free()


## use_spatial_prompt drives PromptUI.position from the interactable's 3D origin every
## physics frame, which would drag the label away from the crosshair (and, for a corpse,
## down to the floor).
func _test_prompt_ui_is_not_world_anchored() -> void:
	# Arrange / Act
	var hud: Control = HUD.instantiate()
	var prompt_ui: Control = hud.get_node("PromptUI")

	# Assert
	assert(prompt_ui.use_spatial_prompt == false,
		"PromptUI must stay crosshair-anchored, not follow the interactable in world space")
	var prompt_area: VBoxContainer = prompt_ui.get_node("PromptArea")
	assert(prompt_area.anchor_left == 0.5 and prompt_area.anchor_right == 0.5,
		"the prompt row must be horizontally centred on the crosshair")
	assert(prompt_area.offset_top > 0.0,
		"the prompt row must sit BELOW the crosshair, not on top of it")
	hud.queue_free()
