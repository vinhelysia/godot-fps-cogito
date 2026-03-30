extends Node3D
## Weapon recoil node. Place as a child of Body/Neck/Head in the player scene.
## Applies rotation delta to the parent (Head) node each frame, creating smooth
## camera kick on fire with automatic recovery.

# Internal rotation tracking
var currentRotation: Vector3
var targetRotation: Vector3
var _prevRotation := Vector3.ZERO

# Per-weapon recoil vectors (set via setRecoil / setAimRecoil on equip)
@export var recoil: Vector3
@export var aimRecoil: Vector3

# Tuning
@export var snappiness: float = 10.0
@export var returnSpeed: float = 5.0


func _process(delta: float) -> void:
	targetRotation = lerp(targetRotation, Vector3.ZERO, returnSpeed * delta)
	currentRotation = lerp(currentRotation, targetRotation, snappiness * delta)

	var delta_rot := currentRotation - _prevRotation
	_prevRotation = currentRotation

	if get_parent() and delta_rot.length() > 0.0001:
		get_parent().rotate_object_local(Vector3.RIGHT, delta_rot.x)
		get_parent().rotate_object_local(Vector3.UP, delta_rot.y)
		# Prevent unintended z-axis tilt when recoil.z is unused
		if recoil.z == 0.0 and aimRecoil.z == 0.0:
			get_parent().global_rotation.z = 0.0


func recoilFire(isAiming: bool = false) -> void:
	if isAiming:
		targetRotation += Vector3(
			aimRecoil.x,
			randf_range(-aimRecoil.y, aimRecoil.y),
			randf_range(-aimRecoil.z, aimRecoil.z)
		)
	else:
		targetRotation += Vector3(
			recoil.x,
			randf_range(-recoil.y, recoil.y),
			randf_range(-recoil.z, recoil.z)
		)


func setRecoil(newRecoil: Vector3) -> void:
	recoil = newRecoil


func setAimRecoil(newRecoil: Vector3) -> void:
	aimRecoil = newRecoil
