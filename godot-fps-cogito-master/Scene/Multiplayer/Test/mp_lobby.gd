extends Control

@onready var _ip_input: LineEdit = %IpInput
@onready var _port_input: LineEdit = %PortInput
@onready var _host_button: Button = %HostButton
@onready var _join_button: Button = %JoinButton
@onready var _status_label: Label = %StatusLabel

const ARENA_SCENE := "res://Scene/Multiplayer/Test/mp_cogito_arena.tscn"

func _ready() -> void:
	_host_button.pressed.connect(_on_host_pressed)
	_join_button.pressed.connect(_on_join_pressed)

func _on_host_pressed() -> void:
	var port := int(_port_input.text)
	_status_label.text = "Hosting on port %d..." % port
	var err := MPNetworkManager.host_game(port)
	if err != OK:
		_status_label.text = "Host failed: %s" % error_string(err)
		return
	get_tree().change_scene_to_file(ARENA_SCENE)

func _on_join_pressed() -> void:
	var ip := _ip_input.text.strip_edges()
	var port := int(_port_input.text)
	_status_label.text = "Joining %s:%d..." % [ip, port]
	var err := MPNetworkManager.join_game(ip, port)
	if err != OK:
		_status_label.text = "Join failed: %s" % error_string(err)
		return
	multiplayer.connected_to_server.connect(_on_connected_to_server, CONNECT_ONE_SHOT)
	_host_button.disabled = true
	_join_button.disabled = true

func _on_connected_to_server() -> void:
	get_tree().change_scene_to_file(ARENA_SCENE)
