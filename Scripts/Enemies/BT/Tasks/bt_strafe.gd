extends BTAction

## BTAction that makes the NPC strafe/reposition to a random nearby location.

@export var min_distance: float = 3.0
@export var max_distance: float = 5.0
@export var tolerance: float = 0.5

var _target_pos: Vector3
var _reached: bool = false
var _timeout: float = 0.0
var _failed: bool = false

func _enter() -> void:
	_reached = false
	_failed = false
	_timeout = 2.5 # 2.5 seconds max to complete strafe
	
	var npc: CogitoNPC = agent as CogitoNPC
	if npc == null:
		return

	# Cooldown and chance check
	var last_strafe = blackboard.get_var(&"last_strafe_time", 0.0, false)
	var now = Time.get_ticks_msec() / 1000.0
	if now - last_strafe < 5.0:
		_failed = true
		return
		
	if randf() > 0.25: # 25% chance
		_failed = true
		return
		
	blackboard.set_var(&"last_strafe_time", now)

	# Try to find a valid random point
	var found = false
	for i in range(5):
		var angle = randf_range(0.0, 2.0 * PI)
		var dist = randf_range(min_distance, max_distance)
		var offset = Vector3(cos(angle), 0.0, sin(angle)) * dist
		var test_pos = npc.global_position + offset
		
		# Set target on nav agent to test reachability
		npc.navigation_agent_3d.target_position = test_pos
		if npc.navigation_agent_3d.is_target_reachable():
			_target_pos = test_pos
			found = true
			break
	
	if not found:
		_target_pos = npc.global_position
		_reached = true


func _tick(delta: float) -> Status:
	if _failed:
		return FAILURE
	if _reached:
		return SUCCESS

	var npc: CogitoNPC = agent as CogitoNPC
	if npc == null:
		return FAILURE

	_timeout -= delta
	if _timeout <= 0.0:
		npc.velocity = Vector3.ZERO
		return SUCCESS

	var nav_agent: NavigationAgent3D = npc.navigation_agent_3d
	nav_agent.target_position = _target_pos

	if nav_agent.is_navigation_finished() or npc.global_position.distance_to(_target_pos) <= tolerance:
		npc.velocity = Vector3.ZERO
		npc.update_animations(delta)
		return SUCCESS

	var next_position = nav_agent.get_next_path_position()
	
	# Apply gravity
	if not npc.is_on_floor():
		npc.velocity += npc.get_gravity() * delta

	var direction = npc.global_position.direction_to(next_position)
	
	# Face the player while strafing! Crucial for combat.
	var target = blackboard.get_var(&"target", null, false)
	if is_instance_valid(target) and target is Node3D:
		npc.face_direction(target.global_position)
	elif direction:
		var face_direction = Vector3(npc.global_position.x + npc.velocity.x, npc.global_position.y, npc.global_position.z + npc.velocity.z)
		npc.face_direction(face_direction)

	if direction:
		npc.velocity.x = direction.x * npc.sprint_speed
		npc.velocity.z = direction.z * npc.sprint_speed
	else:
		npc.velocity.x = move_toward(npc.velocity.x, 0.0, npc.sprint_speed)
		npc.velocity.z = move_toward(npc.velocity.z, 0.0, npc.sprint_speed)
	
	npc.move_and_slide()
	npc.update_animations(delta)

	return RUNNING
