extends Weapon_Resource

class_name GrenadeLauncher_Resource

@export_group("Grenade Launcher")
## Grenade projectile scene. Always fires as a projectile, ignoring the Type flag.
@export var grenadeScene: PackedScene
## Upward launch angle in degrees added to the camera forward vector.
@export var launchAngle: float = 25.0
## Initial projectile speed in m/s.
@export var launchVelocity: float = 20.0
## Fuse duration in seconds before detonation (0 = impact detonation only).
@export var fuseDuration: float = 3.0
## Explosion radius in metres.
@export var blastRadius: float = 5.0
## Optional explosion VFX scene spawned on detonation.
@export var explosionScene: PackedScene

func get_fire_mode() -> FireMode:
	return FireMode.SEMI

func fire(ctx: Dictionary) -> void:
	if grenadeScene == null:
		return
	var viewport: Viewport = ctx["viewport"]
	var camera: Camera3D = viewport.get_camera_3d()
	var bullet_point: Marker3D = ctx["bullet_point"]
	var item_ref: WieldableItemPD = ctx["item_ref"]
	var scene_tree: SceneTree = ctx["scene_tree"]
	var forward := -camera.global_transform.basis.z
	var launch_dir := (forward + Vector3.UP * tan(deg_to_rad(launchAngle))).normalized()
	var grenade := grenadeScene.instantiate()
	scene_tree.current_scene.add_child(grenade)
	grenade.global_position = bullet_point.global_position
	if grenade.has_method("set_linear_velocity"):
		grenade.set_linear_velocity(launch_dir * launchVelocity)
	if "damage_amount" in grenade:
		grenade.damage_amount = item_ref.wieldable_damage
	if "fuse_duration" in grenade:
		grenade.fuse_duration = fuseDuration
	if "blast_radius" in grenade:
		grenade.blast_radius = blastRadius
