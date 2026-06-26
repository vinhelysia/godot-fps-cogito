extends Node

const PORT: int = 7777
const PLAYER_SCENE: PackedScene = preload("res://Scene/Multiplayer/Test/mp_player.tscn")
const LEVEL_SCENE: PackedScene = preload("res://Scene/Multiplayer/Test/mp_level.tscn")

@onready var ui: Control = $UI
@onready var level_node: Node = $Level
@onready var players_node: Node3D = $Players
@onready var ip_input: LineEdit = %IpInput
@onready var port_input: LineEdit = %PortInput
@onready var host_button: Button = %HostButton
@onready var join_button: Button = %JoinButton
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	_set_status("Idle.")


func _on_host_pressed() -> void:
	var port: int = _get_port()
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(port)
	if err != OK:
		_set_status("Host failed: %s" % err)
		return
	multiplayer.multiplayer_peer = peer
	_set_status("Hosting on port %d" % port)
	_start_game()


func _on_join_pressed() -> void:
	var ip: String = ip_input.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"
	var port: int = _get_port()
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(ip, port)
	if err != OK:
		_set_status("Join failed: %s" % err)
		return
	multiplayer.multiplayer_peer = peer
	_set_status("Connecting to %s:%d..." % [ip, port])
	_start_game()


func _start_game() -> void:
	ui.hide()
	# Server spawns the level; clients receive it via MultiplayerSpawner auto-replication.
	if multiplayer.is_server():
		change_level.call_deferred(LEVEL_SCENE)
		# Add host's own player.
		_add_player(multiplayer.get_unique_id())


func change_level(scene: PackedScene) -> void:
	# Remove existing level children before adding the new one.
	for c: Node in level_node.get_children():
		level_node.remove_child(c)
		c.queue_free()
	level_node.add_child(scene.instantiate())


func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		_add_player(id)


func _on_peer_disconnected(id: int) -> void:
	if multiplayer.is_server():
		_del_player(id)


func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = null
	ui.show()
	_set_status("Connection failed.")


func _on_server_disconnected() -> void:
	multiplayer.multiplayer_peer = null
	# Clear player list
	for c: Node in players_node.get_children():
		c.queue_free()
	ui.show()
	_set_status("Server disconnected.")


func _add_player(id: int) -> void:
	var character: CharacterBody3D = PLAYER_SCENE.instantiate() as CharacterBody3D
	character.player = id
	character.name = str(id)
	# Random spawn position
	var spawn_points: Array[Node] = get_tree().get_nodes_in_group("mp_spawn_points")
	if spawn_points.size() > 0:
		var spawn: Node3D = spawn_points.pick_random() as Node3D
		character.position = spawn.global_position
	players_node.add_child(character, true)
	print("[Main] Added player ", id)


func _del_player(id: int) -> void:
	if not players_node.has_node(str(id)):
		return
	players_node.get_node(str(id)).queue_free()
	print("[Main] Removed player ", id)


func _get_port() -> int:
	var text: String = port_input.text.strip_edges()
	if text.is_empty():
		return PORT
	return int(text)


func _set_status(msg: String) -> void:
	if status_label:
		status_label.text = msg
	print("[MP Main] ", msg)
