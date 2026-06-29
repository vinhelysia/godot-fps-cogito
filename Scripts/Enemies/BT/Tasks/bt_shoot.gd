extends BTAction

## BTAction that handles the Scav shooting at the target.

@export var fire_rate: float = 0.8
@export var damage: float = 8.0
@export var accuracy: float = 0.12
@export var burst_count: int = 5
@export var los_timeout: float = 3.0
@export var shoot_sound: AudioStream
@export var muzzle_flash_scene: PackedScene

var _fire_timer: float = 0.0
var _los_lost_timer: float = 0.0
var _reaction_timer: float = 0.0
var _has_reacted: bool = false

func _enter() -> void:
	# Initialize ammo on blackboard if not set
	if not blackboard.has_var(&"ammo"):
		blackboard.set_var(&"ammo", burst_count)
	
	_fire_timer = fire_rate * 0.5 # First shot slightly faster
	_los_lost_timer = 0.0
	_reaction_timer = 0.3 # 0.3s reaction delay before first shot
	_has_reacted = false


func _tick(delta: float) -> Status:
	var target = blackboard.get_var(&"target", null, false)
	if not is_instance_valid(target) or not target is Node3D:
		return FAILURE

	var npc: CogitoNPC = agent as CogitoNPC
	if npc == null:
		return FAILURE

	# Face target and brake
	npc.face_direction(target.global_position)
	_brake(npc, delta)

	# Check range
	var dist = npc.global_position.distance_to(target.global_position)
	var engage_range = blackboard.get_var(&"engage_range", 15.0, false)
	if dist > engage_range:
		return FAILURE

	# Check ammo
	var ammo = blackboard.get_var(&"ammo", burst_count, false)
	if ammo <= 0:
		return FAILURE

	# Check LOS
	var muzzle_pos = _get_muzzle_pos(npc)
	var target_aim_pos = target.global_position + Vector3(0.0, 1.0, 0.0) # Aim at chest
	var los_result = _cast_ray(npc, muzzle_pos, target_aim_pos)
	var has_los = _result_hits_target(los_result, target)

	if not has_los:
		_los_lost_timer += delta
		if _los_lost_timer >= los_timeout:
			return FAILURE
		return RUNNING
	
	_los_lost_timer = 0.0

	# Reaction delay before first shot
	if not _has_reacted:
		_reaction_timer -= delta
		if _reaction_timer <= 0.0:
			_has_reacted = true
		return RUNNING

	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = fire_rate
		_shoot(npc, target, muzzle_pos)
		
		# Decrement ammo
		ammo -= 1
		blackboard.set_var(&"ammo", ammo)
		if ammo <= 0:
			return FAILURE

	return RUNNING


func _brake(npc: CogitoNPC, delta: float) -> void:
	var rate: float = delta * npc.sprint_speed * 6.0
	npc.velocity.x = move_toward(npc.velocity.x, 0.0, rate)
	npc.velocity.z = move_toward(npc.velocity.z, 0.0, rate)
	if not npc.is_on_floor():
		npc.velocity += npc.get_gravity() * delta
	npc.move_and_slide()


func _get_muzzle_pos(npc: CogitoNPC) -> Vector3:
	var muzzle: Node3D = npc.get_node_or_null("Muzzle")
	if is_instance_valid(muzzle):
		return muzzle.global_position
	return npc.global_position + Vector3(0.0, 1.4, 0.0)


func _cast_ray(npc: CogitoNPC, from: Vector3, to: Vector3) -> Dictionary:
	var space: PhysicsDirectSpaceState3D = npc.get_world_3d().direct_space_state
	var params := PhysicsRayQueryParameters3D.create(from, to)
	params.exclude = [npc.get_rid()]
	params.collision_mask = 3 # layer 1 (world) + layer 2 (player)
	return space.intersect_ray(params)


func _result_hits_target(result: Dictionary, target: Node3D) -> bool:
	if result.is_empty():
		return true # nothing in the way
	var hit = result["collider"]
	return hit == target or hit.is_in_group("Player")


func _shoot(npc: CogitoNPC, target: Node3D, muzzle_pos: Vector3) -> void:
	var target_aim_pos = target.global_position + Vector3(0.0, 1.0, 0.0)
	var aim_dir = (target_aim_pos - muzzle_pos).normalized()

	# Spread: random deviation on local X/Y axes
	var right = aim_dir.cross(Vector3.UP).normalized()
	var up = right.cross(aim_dir).normalized()
	var spread = right * randf_range(-accuracy, accuracy) \
				+ up * randf_range(-accuracy * 0.5, accuracy * 0.5)
	var fire_dir = (aim_dir + spread).normalized()
	var fire_end = muzzle_pos + fire_dir * 30.0 # Engage range max

	# Play shoot sound
	if shoot_sound and is_instance_valid(Audio):
		Audio.play_sound_3d(shoot_sound, false).global_position = muzzle_pos

	# Emit gunshot sound event to the SoundEvents bus
	var sound_events = npc.get_node_or_null("/root/SoundEvents")
	if sound_events:
		sound_events.sound_emitted.emit(muzzle_pos, 80.0, &"gunshot", npc)

	# Play muzzle flash VFX
	if muzzle_flash_scene:
		var flash = muzzle_flash_scene.instantiate() as Node3D
		npc.get_tree().current_scene.add_child(flash)
		flash.global_position = muzzle_pos
		# Align flash with fire direction
		if fire_dir != Vector3.ZERO:
			flash.look_at(muzzle_pos + fire_dir)

	# Cast bullet ray
	var result = _cast_ray(npc, muzzle_pos, fire_end)
	if not result.is_empty() and _result_hits_target(result, target):
		var hit_collider = result["collider"]
		if hit_collider.has_method("decrease_attribute"):
			hit_collider.decrease_attribute("health", damage)
		elif hit_collider.has_method("take_damage"):
			hit_collider.take_damage(damage)
		elif hit_collider.has_signal("damage_received"):
			var dir = (target.global_position - npc.global_position).normalized()
			hit_collider.damage_received.emit(damage, dir, target.global_position)
