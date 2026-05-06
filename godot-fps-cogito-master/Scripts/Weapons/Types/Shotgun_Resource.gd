extends Weapon_Resource

class_name Shotgun_Resource

@export_group("Shotgun")
## Number of pellets fired per shot.
@export var pelletCount: int = 8
## Spread cone half-angle in degrees when hip-firing.
@export var spreadAngle: float = 4.0
## Spread cone half-angle in degrees when aiming down sights (tighter).
@export var adsSpreadAngle: float = 2.0
## If true, requires a pump animation between shots.
@export var isPump: bool = true
## Animation name for the pump action.
@export var pumpAnimation: String = "pump"
## Duration of the pump cycle in seconds (fallback if animation length differs).
@export var pumpDuration: float = 0.5
## If true, reloads one shell at a time into a tube magazine.
@export var tubeReload: bool = true
## If true, the player can interrupt a tube reload to fire immediately.
@export var canInterruptReload: bool = true

func get_fire_mode() -> FireMode:
	return FireMode.PUMP if isPump else FireMode.SEMI

func fire(ctx: Dictionary) -> void:
	var is_aiming: bool = ctx["is_aiming"]
	var spread: float = adsSpreadAngle if is_aiming else spreadAngle
	var viewport: Viewport = ctx["viewport"]
	var camera: Camera3D = viewport.get_camera_3d()
	var item_ref: WieldableItemPD = ctx["item_ref"]
	var pic: PlayerInteractionComponent = ctx["player_interaction_component"]
	var world: World3D = ctx["world_3d"]
	var vp_size := Vector2(viewport.get_size())
	var center := vp_size / 2.0

	for i in pelletCount:
		var offset := Vector2(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0)
		).normalized() * tan(deg_to_rad(spread))
		var spread_point := center + offset * vp_size.x * 0.1
		var ray_origin := camera.project_ray_origin(spread_point)
		var ray_end := ray_origin + camera.project_ray_normal(spread_point) * item_ref.wieldable_range
		var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		if pic.player_rid:
			query.exclude = [pic.player_rid]
		query.collision_mask = COLLISION_MASK_DAMAGE
		var hit := world.direct_space_state.intersect_ray(query)
		if hit:
			_deal_damage(hit.collider, (hit.position - ray_origin).normalized(), hit.position, item_ref)

func play_post_fire_visual(weapon: Node) -> void:
	if not isPump:
		return
	var firearm := weapon as CogitoFirearm
	firearm._pump_ready = false
	# Animation-shoot-motion mode chains pump in on_anim_finished instead.
	if firearm._uses_animation_shoot_motion():
		return
	firearm._schedule_post_fire_cycle(firearm._get_shoot_visual_duration(),
			_start_pump.bind(firearm))


func on_anim_finished(weapon: Node, anim_name: StringName) -> void:
	if not isPump:
		return
	var firearm := weapon as CogitoFirearm
	# Shoot animation finished → start pump (animation shoot mode).
	if firearm._uses_animation_shoot_motion() and firearm._is_shoot_animation_name(anim_name):
		_start_pump(firearm)
		return
	# Pump animation finished → ready for next shot.
	if pumpAnimation != "" and anim_name == pumpAnimation:
		firearm._pump_ready = true
		firearm._capture_rest_state()


# ── Internal ─────────────────────────────────────────────────────────────────

func _start_pump(firearm: CogitoFirearm) -> void:
	firearm._post_fire_cycle_tween = null
	if pumpAnimation != "" and firearm.animation_player.has_animation(pumpAnimation):
		firearm.animation_player.play(pumpAnimation)
	else:
		firearm._complete_cycle_after_delay(pumpDuration,
				_finish_pump.bind(firearm))


func _finish_pump(firearm: CogitoFirearm) -> void:
	firearm._post_fire_cycle_tween = null
	firearm._pump_ready = true
	firearm._capture_rest_state()
