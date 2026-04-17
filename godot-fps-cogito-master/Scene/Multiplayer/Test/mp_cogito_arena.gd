extends Node3D

@onready var _players: Node3D = $Players
@onready var _spawn_points: Node3D = $SpawnPoints
@onready var _pickups: Node3D = $Pickups
@onready var _weapon_spawner: MultiplayerSpawner = $WeaponSpawner

const PLAYER_SCENE := preload("res://addons/cogito/PackedScenes/cogito_player.tscn")
const PICKUP_USP  := preload("res://Scene/Weapom/Firearms/Pistol/USP/pickup_usp.tscn")
const PICKUP_AK47 := preload("res://Scene/Weapom/Firearms/AR/AK47/pickup_ak47.tscn")

# [PackedScene, spawn position]
var _weapon_spawn_table: Array = []

func _ready() -> void:
	# Register spawn points for cogito_player respawn.
	for sp in _spawn_points.get_children():
		sp.add_to_group("mp_spawn_points")

	# Use a custom spawn function so position is baked into the spawn data
	# and applied on ALL peers before the node enters the tree.
	_weapon_spawner.spawn_function = _weapon_spawn_func

	_weapon_spawn_table = [
		[PICKUP_AK47, Vector3(  0, 1,   0)],  # Centre — AK47
		[PICKUP_USP,  Vector3( 12, 1,   0)],  # East
		[PICKUP_USP,  Vector3(-12, 1,   0)],  # West
		[PICKUP_USP,  Vector3(  0, 1,  12)],  # North
		[PICKUP_USP,  Vector3(  0, 1, -12)],  # South
	]

	if not multiplayer.is_server():
		return

	_spawn_weapons()
	_spawn_player(multiplayer.get_unique_id())
	MPNetworkManager.player_connected.connect(_spawn_player)
	MPNetworkManager.player_disconnected.connect(_despawn_player)


# Called on EVERY peer when spawner instantiates a weapon — position is in the data.
func _weapon_spawn_func(data: Dictionary) -> Node:
	var scenes: Array = [PICKUP_USP, PICKUP_AK47]
	var pickup: Node = scenes[data.scene_index].instantiate()
	pickup.name = data.node_name
	pickup.position = data.position   # Set before entering tree → same on all peers.
	if pickup is RigidBody3D:
		pickup.freeze = true           # Stay at spawn position; no physics drift.
	return pickup


func _spawn_weapons() -> void:
	for i in _weapon_spawn_table.size():
		var entry: Array = _weapon_spawn_table[i]
		var scene_index: int = 1 if entry[0] == PICKUP_AK47 else 0
		_weapon_spawner.spawn({
			"scene_index": scene_index,
			"node_name": "Pickup_%d" % i,
			"position": entry[1],
		})


func _spawn_player(peer_id: int) -> void:
	var player: Node = PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	_players.add_child(player, true)
	player.global_position = _get_random_spawn()


func _despawn_player(peer_id: int) -> void:
	var player := _players.get_node_or_null(str(peer_id))
	if player:
		player.queue_free()


func _get_random_spawn() -> Vector3:
	var points := _spawn_points.get_children()
	if points.is_empty():
		return Vector3(0, 2, 0)
	return (points.pick_random() as Node3D).global_position
