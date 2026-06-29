extends CogitoNPC
class_name Scav

## Project-local Scav enemy using LimboAI.

@onready var bt_player: Node = $BTPlayer

func _ready() -> void:
	super._ready()
	
	# Connect to death signal of CogitoHealthAttribute
	var health = get_node_or_null("CogitoHealthAttribute")
	if health:
		health.death.connect(_on_death)


func _on_death() -> void:
	if is_instance_valid(bt_player):
		bt_player.active = false
	
	# Disable collision with player (layer 2) but keep world collision (layer 1)
	collision_layer = 0
	collision_mask = 1 # Layer 1 is world
