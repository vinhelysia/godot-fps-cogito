extends BTAction

## BTAction that handles reloading.

@export var reload_time: float = 2.5
@export var reload_sound: AudioStream

var _timer: float = 0.0
var _failed: bool = false

func _enter() -> void:
	_failed = false
	var ammo = blackboard.get_var(&"ammo", 5, false)
	var reloading = blackboard.get_var(&"reloading", false, false)
	if ammo > 0 and not reloading:
		_failed = true
		return

	blackboard.set_var(&"reloading", true)
	_timer = reload_time
	
	# Play reload sound
	var npc: CogitoNPC = agent as CogitoNPC
	if npc and reload_sound and is_instance_valid(Audio):
		Audio.play_sound_3d(reload_sound, false).global_position = npc.global_position


func _tick(_delta: float) -> Status:
	if _failed:
		return FAILURE

	_timer -= _delta
	if _timer <= 0.0:
		var burst_count = 5
		# We can read burst_count from the shoot task if needed, but a default of 5 is fine.
		# Or we can check if the blackboard has a burst_count variable.
		blackboard.set_var(&"ammo", burst_count)
		blackboard.set_var(&"reloading", false)
		return SUCCESS

	var npc: CogitoNPC = agent as CogitoNPC
	if npc:
		# Apply braking while reloading
		var rate: float = _delta * npc.sprint_speed * 6.0
		npc.velocity.x = move_toward(npc.velocity.x, 0.0, rate)
		npc.velocity.z = move_toward(npc.velocity.z, 0.0, rate)
		if not npc.is_on_floor():
			npc.velocity += npc.get_gravity() * _delta
		npc.move_and_slide()

	return RUNNING
