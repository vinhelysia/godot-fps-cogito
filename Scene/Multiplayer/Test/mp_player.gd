extends CharacterBody3D

const SPEED: float = 5.0
const JUMP_VELOCITY: float = 4.5
const MAX_HEALTH: int = 100

# Set by the authority, synchronized on spawn.
# When assigned, gives PlayerInput multiplayer authority to the peer.
@export var player: int = 1:
	set(id):
		player = id
		var input_node: Node = get_node_or_null("PlayerInput")
		if input_node:
			input_node.set_multiplayer_authority(id)

@export var health: int = MAX_HEALTH

@onready var input: MultiplayerSynchronizer = $PlayerInput
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var weapon: Node3D = $Head/Camera3D/Weapon
@onready var name_label: Label3D = $NameLabel


func _enter_tree() -> void:
	# Set authority before child synchronizers register their network IDs (top-down order).
	var peer_id := str(name).to_int()
	# Non-recursive: only this CharacterBody3D gets client authority.
	set_multiplayer_authority(peer_id, false)
	# Body MultiplayerSynchronizer → server authority (1).
	# Server runs move_and_slide() and sends global_position to clients.
	var body_sync := get_node_or_null("MultiplayerSynchronizer")
	if body_sync:
		body_sync.set_multiplayer_authority(1)
	# PlayerInput → client authority (peer_id).
	# Client reads WASD/mouse and sends direction/look to server.
	var input_node := get_node_or_null("PlayerInput")
	if input_node:
		input_node.set_multiplayer_authority(peer_id)


func _ready() -> void:
	# Only the local player activates their camera.
	if is_multiplayer_authority():
		camera.current = true
	name_label.text = "Peer %d" % player


func _physics_process(delta: float) -> void:
	# Rotate body/head from synced input so the visual is correct on ALL peers.
	rotation.y = input.look_yaw
	head.rotation.x = input.look_pitch

	# Only the server applies physics and resolves fire/jump actions.
	if not multiplayer.is_server():
		return

	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Jump (edge-triggered from PlayerInput)
	if input.jumping and is_on_floor():
		velocity.y = JUMP_VELOCITY
	input.jumping = false

	# Fire (edge-triggered from PlayerInput)
	if input.firing:
		input.firing = false
		if weapon and weapon.has_method("server_fire"):
			weapon.server_fire()

	# Horizontal movement from synced direction vector
	var move_dir: Vector3 = (transform.basis * Vector3(input.direction.x, 0.0, input.direction.y)).normalized()
	if move_dir.length() > 0.0:
		velocity.x = move_dir.x * SPEED
		velocity.z = move_dir.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)
		velocity.z = move_toward(velocity.z, 0.0, SPEED)

	move_and_slide()


# Called directly by mp_weapon.gd on the server only.
# health is synced to all clients via MultiplayerSynchronizer (ON_CHANGE).
func apply_damage(amount: int) -> void:
	if not multiplayer.is_server():
		return
	health -= amount
	print("[Player %d] HP=%d (-%d)" % [player, health, amount])
	if health <= 0:
		_server_respawn()


func _server_respawn() -> void:
	if not multiplayer.is_server():
		return
	health = MAX_HEALTH
	var spawns: Array[Node] = get_tree().get_nodes_in_group("mp_spawn_points")
	if spawns.size() > 0:
		var spawn: Node3D = spawns.pick_random() as Node3D
		global_position = spawn.global_position
	print("[Player %d] respawned" % player)
