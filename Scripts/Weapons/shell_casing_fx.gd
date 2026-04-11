class_name ShellCasingFx
extends RigidBody3D

@export var eject_speed: float = 3.0
@export var eject_up: float = 0.5
@export var spin_speed: float = 10.0
@export var despawn_delay: float = 3.0

var player_velocity := Vector3.ZERO

func _ready() -> void:
	call_deferred("_eject")
	get_tree().create_timer(despawn_delay).timeout.connect(queue_free)


func _eject() -> void:
	linear_velocity = player_velocity
	# Eject right (+X) and slightly upward in weapon local space.
	var eject_dir := (global_basis.x + global_basis.y * eject_up).normalized()
	apply_impulse(eject_dir * eject_speed)

	# Random tumble spin.
	angular_velocity = Vector3(
		randf_range(-spin_speed, spin_speed),
		randf_range(-spin_speed, spin_speed),
		randf_range(-spin_speed, spin_speed),
	)
