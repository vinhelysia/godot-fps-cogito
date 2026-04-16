extends Node3D

const DAMAGE: int = 25
const RANGE: float = 100.0
const FIRE_COOLDOWN: float = 0.2

var _cooldown: float = 0.0


func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)


# Called by mp_player.gd on the server side.
func server_fire() -> void:
	if not multiplayer.is_server():
		return
	if _cooldown > 0.0:
		return
	_cooldown = FIRE_COOLDOWN

	var cam: Camera3D = get_parent() as Camera3D
	if cam == null:
		push_error("mp_weapon must be child of Camera3D")
		return

	var player_body: CharacterBody3D = _get_player_body()
	if player_body == null:
		return

	var origin: Vector3 = cam.global_position
	var forward: Vector3 = -cam.global_transform.basis.z

	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		origin, origin + forward * RANGE
	)
	query.exclude = [player_body.get_rid()]
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return

	var collider: Object = hit.collider
	if collider == null:
		return

	if collider.has_method("apply_damage"):
		collider.apply_damage.rpc(DAMAGE)
		print("[Weapon] Server hit ", collider.name, " for ", DAMAGE)


func _get_player_body() -> CharacterBody3D:
	var node: Node = self
	while node:
		if node is CharacterBody3D:
			return node
		node = node.get_parent()
	return null
