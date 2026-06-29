extends BTAction

## BTAction that makes the NPC look left and right to search the area.

@export var look_time: float = 4.0

var _timer: float = 0.0
var _phase_timer: float = 0.0
var _look_left: bool = true

func _enter() -> void:
	_timer = look_time
	_phase_timer = 0.0
	_look_left = true


func _tick(_delta: float) -> Status:
	var npc: CogitoNPC = agent as CogitoNPC
	if npc == null:
		return FAILURE

	_timer -= _delta
	if _timer <= 0.0:
		# Search finished, clear investigation targets
		blackboard.set_var(&"heard_position", null)
		blackboard.set_var(&"has_last_known", false)
		return SUCCESS

	# Alternate looking left and right every 1.5 seconds
	_phase_timer -= _delta
	if _phase_timer <= 0.0:
		_phase_timer = 1.5
		_look_left = !_look_left

	# Calculate a point to look at
	var forward = -npc.global_transform.basis.z
	var angle = 45.0 if _look_left else -45.0
	var look_dir = forward.rotated(Vector3.UP, deg_to_rad(angle)).normalized()
	var look_target = npc.global_position + look_dir * 5.0

	npc.face_direction(look_target)
	
	# Apply braking
	var rate: float = _delta * npc.sprint_speed * 6.0
	npc.velocity.x = move_toward(npc.velocity.x, 0.0, rate)
	npc.velocity.z = move_toward(npc.velocity.z, 0.0, rate)
	if not npc.is_on_floor():
		npc.velocity += npc.get_gravity() * _delta
	npc.move_and_slide()
	npc.update_animations(_delta)

	return RUNNING
