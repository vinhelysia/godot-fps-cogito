extends BTAction

## Reload. Returns FAILURE immediately if ammo > 0 (nothing to reload).
## This lets the CombatActions selector fall through to Shoot first.

@export var mag_size: int = 5
@export var reload_time: float = 2.5
@export var reload_sound: AudioStream

var _timer: float = 0.0
var _skip: bool = false


func _enter() -> void:
	var ammo: int = blackboard.get_var(&"ammo", mag_size)
	var reloading: bool = blackboard.get_var(&"reloading", false)
	if ammo > 0 and not reloading:
		_skip = true
		return

	_skip = false
	blackboard.set_var(&"reloading", true)
	_timer = reload_time

	var npc: CogitoNPC = agent as CogitoNPC
	if npc and reload_sound and is_instance_valid(Audio):
		Audio.play_sound_3d(reload_sound, false).global_position = npc.global_position


func _tick(delta: float) -> Status:
	if _skip:
		return FAILURE

	_timer -= delta
	if _timer <= 0.0:
		blackboard.set_var(&"ammo", mag_size)
		blackboard.set_var(&"reloading", false)
		return SUCCESS

	var npc: CogitoNPC = agent as CogitoNPC
	if npc:
		var rate: float = delta * npc.sprint_speed * 6.0
		npc.velocity.x = move_toward(npc.velocity.x, 0.0, rate)
		npc.velocity.z = move_toward(npc.velocity.z, 0.0, rate)
		if not npc.is_on_floor():
			npc.velocity += npc.get_gravity() * delta
		npc.move_and_slide()

	return RUNNING
