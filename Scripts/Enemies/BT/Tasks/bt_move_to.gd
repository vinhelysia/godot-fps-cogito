extends BTAction

## BTAction that moves the NPC to a destination stored in the Blackboard.

@export var position_var: StringName = &"last_known_position"
@export var speed_var: StringName = &"" # If set, uses this speed. Otherwise uses agent.move_speed.
@export var tolerance: float = 1.0

func _tick(delta: float) -> Status:
	var dest = blackboard.get_var(position_var, null, false)
	if not dest is Vector3:
		return FAILURE

	var npc: CogitoNPC = agent as CogitoNPC
	if npc == null:
		return FAILURE

	var nav_agent: NavigationAgent3D = npc.navigation_agent_3d
	nav_agent.target_position = dest

	if nav_agent.is_navigation_finished() or npc.global_position.distance_to(dest) <= tolerance:
		npc.velocity = Vector3.ZERO
		npc.update_animations(delta)
		return SUCCESS

	if not nav_agent.is_target_reachable():
		npc.velocity = Vector3.ZERO
		npc.update_animations(delta)
		return FAILURE

	var next_position = nav_agent.get_next_path_position()
	
	# Apply gravity
	if not npc.is_on_floor():
		npc.velocity += npc.get_gravity() * delta

	var direction = npc.global_position.direction_to(next_position)
	var face_direction = Vector3(npc.global_position.x + npc.velocity.x, npc.global_position.y, npc.global_position.z + npc.velocity.z)

	var speed = npc.move_speed
	if speed_var != &"":
		speed = blackboard.get_var(speed_var, npc.move_speed, false)

	if direction:
		npc.face_direction(face_direction)
		npc.velocity.x = direction.x * speed
		npc.velocity.z = direction.z * speed
	else:
		npc.velocity.x = move_toward(npc.velocity.x, 0, speed)
		npc.velocity.z = move_toward(npc.velocity.z, 0, speed)
	
	npc.move_and_slide()
	npc.update_animations(delta)

	return RUNNING
