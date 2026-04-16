extends Node3D

@onready var _players: Node3D = $Players
@onready var _spawn_points: Node3D = $SpawnPoints

const PLAYER_SCENE := preload("uid://cnlx7usiidnnk")

func _ready() -> void:
	# Register spawn points in group so mp_player.gd respawn can find them
	for sp in _spawn_points.get_children():
		sp.add_to_group("mp_spawn_points")

	if not multiplayer.is_server():
		return

	# Spawn the host player immediately
	_spawn_player(multiplayer.get_unique_id())

	# Spawn / despawn players as they connect
	MPNetworkManager.player_connected.connect(_spawn_player)
	MPNetworkManager.player_disconnected.connect(_despawn_player)

func _spawn_player(peer_id: int) -> void:
	var player: Node = PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	player.set("player", peer_id)  # export var — name label + included in spawn packet
	# Authority is set in MPPlayer._enter_tree(), not here
	_players.add_child(player, true)
	player.global_position = _get_random_spawn()

func _despawn_player(peer_id: int) -> void:
	var player := _players.get_node_or_null(str(peer_id))
	if player:
		player.queue_free()

func _get_random_spawn() -> Vector3:
	var points := _spawn_points.get_children()
	if points.is_empty():
		return Vector3(0, 1, 0)
	return (points.pick_random() as Node3D).global_position
