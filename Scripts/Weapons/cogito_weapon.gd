extends CogitoWieldable
## Adapter that bridges Weapon_Resource types into Cogito's wieldable system.
##
## Usage:
## 1. Create a wieldable scene (Node3D root with AnimationPlayer + AudioStreamPlayer3D + mesh).
## 2. Attach this script to the root.
## 3. Assign a Weapon_Resource (or subclass) to weapon_data.
## 4. Create a WieldableItemPD inventory item:
##    - charge_max = magazine size
##    - charge_current = starting ammo in magazine
##    - wieldable_damage = damage per hit/pellet
##    - wieldable_range = hitscan/camera ray distance
##    - wieldable_scene = this weapon scene
##    - ammo_item_name = name of the AmmoItemPD in inventory
## 5. Add a Marker3D named "Bullet_Point" (unique name) as the muzzle origin.

enum ShootMotionMode { ANIMATION, TWEEN }

@export_group("Weapon Configuration")
## The Weapon_Resource that defines fire mode, recoil, and type-specific data.
@export var weapon_data: Weapon_Resource

@export_group("Muzzle")
## Marker3D where bullets/projectiles spawn. Set via unique name %Bullet_Point.
@onready var bullet_point: Marker3D = %Bullet_Point

@export_group("Audio")
@export var sound_shoot: AudioStream
@export var sound_reload: AudioStream

@export_group("ADS Settings")
## Camera FOV when aiming down sights.
@export var ads_fov: float = 65.0
## Default local position of the weapon (hip-fire). Used to tween back from ADS.
@export var default_position: Vector3
## ADS position offset. X is always forced to 0 (centered). Adjust Y and Z only.
@export var ads_position: Vector3 = Vector3(0, 0, 0)
## Recoil vector while aiming. If zero, uses hip recoil scaled by 0.4.
@export var aim_recoil_values: Vector3 = Vector3.ZERO

@export_group("Shoot Motion")
@export_enum("Animation", "Tween") var shoot_motion_mode: int = ShootMotionMode.TWEEN
@export var hip_shot_position_offset: Vector3 = Vector3.ZERO
@export var hip_shot_rotation_deg: Vector3 = Vector3.ZERO
@export var ads_shot_position_offset: Vector3 = Vector3.ZERO
@export var ads_shot_rotation_deg: Vector3 = Vector3.ZERO
@export var shoot_kick_out_time: float = 0.03
@export var shoot_return_time: float = 0.06
@export var block_ads_during_shot_tween: bool = true

@export_group("Fire Part Motion")
@export var fire_part_node: NodePath
@export var fire_part_position_offset: Vector3 = Vector3.ZERO
@export var fire_part_out_time: float = 0.03
@export var fire_part_return_time: float = 0.06

@export_group("Extra Animations")
## Shoot animation while ADS (leave empty to reuse primary).
@export var anim_shoot_ads: String = "action_primary_ads"
## Reload animation when magazine is completely empty.
@export var anim_reload_empty: String = "reload_empty"
## Reload animation when magazine is completely empty while ADSing
@export var anim_reload_empty_ads: String = "reload_empty_ads"
## Reload animation while ADSing
@export var anim_reload_ads: String = "reload_ads"

# ── Trigger mesh ──────────────────────────────────────────────────────────────
## Optional child Node3D named "trigger". If present its Z-rotation is tweened
## to trigger_pull_rotation on mouse-press and back to 0° on mouse-release.
@export_group("Trigger Animation")
## Z-rotation (degrees) the trigger mesh rotates to when the mouse is held.
@export var trigger_pull_rotation: float = -20.0
## Minimum time (seconds) the trigger stays pulled. Fast clicks shorter than
## this will hold the pulled position for the remainder before springing back.
@export var trigger_min_hold_time: float = 0.1
var _trigger_mesh: Node3D = null
var _trigger_tween: Tween = null
var _trigger_press_time: float = -1.0

# ── Internal state ────────────────────────────────────────────────────────────
var _is_firing: bool = false
var _is_aiming: bool = false
var _fire_cooldown: float = 0.0
var _is_reloading: bool = false
var _is_shoot_tween_active: bool = false

# Bolt / Pump
var _bolt_is_cycled: bool = true
var _pump_ready: bool = true

# LMG heat
var _current_heat: float = 0.0
var _is_venting: bool = false

var _item_ref: WieldableItemPD
var _fire_part: Node3D = null
var _rest_rotation_degrees: Vector3 = Vector3.ZERO
var _fire_part_rest_position: Vector3 = Vector3.ZERO
var _shoot_tween: Tween = null
var _fire_part_tween: Tween = null
var _shoot_state_tween: Tween = null
var _post_fire_cycle_tween: Tween = null
var _ads_camera_tween: Tween = null
var _ads_weapon_tween: Tween = null


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	if wieldable_mesh:
		wieldable_mesh.hide()
	animation_player.animation_finished.connect(_on_anim_finished)
	_trigger_mesh = get_node_or_null("trigger") as Node3D
	_resolve_fire_part()
	_capture_rest_state()


func _physics_process(delta: float) -> void:
	if weapon_data == null:
		return

	_fire_cooldown = max(0.0, _fire_cooldown - delta)

	# Auto-fire loop
	if _is_firing and not _is_reloading and _fire_cooldown <= 0.0:
		if _item_ref and _item_ref.charge_current > 0:
			_try_fire()
		else:
			_is_firing = false

	# LMG passive heat cooldown
	if weapon_data is LMG_Resource:
		if not _is_firing and not _is_venting:
			_current_heat = max(0.0, _current_heat - (weapon_data as LMG_Resource).cooldownRate * delta)
		if _is_venting:
			_current_heat = max(0.0, _current_heat - (weapon_data as LMG_Resource).ventRate * delta)
			if _current_heat <= 0.0:
				_is_venting = false
				_is_reloading = false


# ── CogitoWieldable interface ─────────────────────────────────────────────────

func equip(_player_interaction_component: PlayerInteractionComponent) -> void:
	player_interaction_component = _player_interaction_component
	_item_ref = item_reference
	_reset_state()
	_cancel_all_motion_tweens(false)
	animation_player.play(anim_equip)

	# Configure recoil on the player's CameraRecoil node
	var rn := _get_recoil_node()
	if rn and weapon_data:
		var hip := Vector3(weapon_data.recoilVertical, weapon_data.recoilHorizontal, 0.0)
		rn.setRecoil(hip)
		var aim := aim_recoil_values if aim_recoil_values.length() > 0.001 else hip * 0.4
		if rn.has_method("setAimRecoil"):
			rn.setAimRecoil(aim)


func unequip() -> void:
	_cancel_shoot_motion(true)
	_is_firing = false
	if _is_aiming:
		_exit_ads(true)
	else:
		_cancel_ads_motion(true)
	animation_player.play(anim_unequip)


func action_primary(_passed_item_reference: InventoryItemPD, _is_released: bool) -> void:
	_item_ref = _passed_item_reference as WieldableItemPD
	if weapon_data == null:
		return

	if _is_released:
		_is_firing = false
		var elapsed: float = Time.get_ticks_msec() / 1000.0 - _trigger_press_time
		var delay: float = max(0.0, trigger_min_hold_time - elapsed)
		_tween_trigger_delayed(0.0, delay)
		return

	_trigger_press_time = Time.get_ticks_msec() / 1000.0
	_tween_trigger(trigger_pull_rotation)

	var mode := weapon_data.get_fire_mode()

	# AUTO weapons: flag continuous fire, attempt first shot immediately
	if mode == Weapon_Resource.FireMode.AUTO:
		if _item_ref and _item_ref.charge_current <= 0:
			_item_ref.send_empty_hint()
			return
		_is_firing = true
		_try_fire()
		return

	# All other modes: single shot on press
	_try_fire()


func action_secondary(_is_released: bool) -> void:
	if _is_released:
		_exit_ads()
	else:
		_enter_ads()


func reload() -> void:
	if weapon_data == null or _is_reloading or animation_player.is_playing():
		return
	if _item_ref == null:
		return

	var mode := weapon_data.get_fire_mode()
	if mode == Weapon_Resource.FireMode.BOLT_ACTION and not _bolt_is_cycled:
		return
	if mode == Weapon_Resource.FireMode.PUMP and not _pump_ready:
		return

	if weapon_data is LMG_Resource and _current_heat > 0.0 and not _is_venting:
		_cancel_shoot_motion(true)
		_is_venting = true
		_is_reloading = true
		var vent_anim: String = (weapon_data as LMG_Resource).ventAnimation
		if vent_anim != "":
			animation_player.play(vent_anim)
		if sound_reload:
			audio_stream_player_3d.stream = sound_reload
			audio_stream_player_3d.play()
		return

	var ammo_needed: int = ceili(_item_ref.charge_max - _item_ref.charge_current)
	if ammo_needed <= 0:
		return
	if _get_available_reload_amount() <= 0:
		return

	_cancel_shoot_motion(true)
	_is_reloading = true
	animation_player.play(_get_reload_animation_name())

	if sound_reload:
		audio_stream_player_3d.stream = sound_reload
		audio_stream_player_3d.play()


func _get_reload_animation_name() -> String:
	var is_empty_mag := _item_ref != null and _item_ref.charge_current <= 0

	if _is_aiming:
		if is_empty_mag and anim_reload_empty_ads != "":
			return anim_reload_empty_ads
		if anim_reload_ads != "":
			return anim_reload_ads
		if is_empty_mag and anim_reload_empty != "":
			return anim_reload_empty

	if is_empty_mag and anim_reload_empty != "":
		return anim_reload_empty

	return anim_reload


# ── Fire logic ────────────────────────────────────────────────────────────────

func _try_fire() -> void:
	if weapon_data == null or _is_reloading:
		return
	if _fire_cooldown > 0.0:
		return
	if _item_ref == null or _item_ref.charge_current <= 0:
		if _item_ref:
			_item_ref.send_empty_hint()
		_is_firing = false
		return

	var mode := weapon_data.get_fire_mode()

	# Type-specific guards
	if mode == Weapon_Resource.FireMode.BOLT_ACTION and not _bolt_is_cycled:
		return
	if mode == Weapon_Resource.FireMode.PUMP and not _pump_ready:
		return
	if weapon_data is LMG_Resource and _current_heat >= 1.0:
		_is_firing = false
		return
	if _uses_animation_shoot_motion() and mode != Weapon_Resource.FireMode.AUTO and _is_shoot_animation_playing():
		return

	# ── Execute shot ──────────────────────────────────────────────────────────
	var used_animation_shot: bool = _play_shoot_visual()

	# Sound
	if sound_shoot:
		audio_stream_player_3d.stream = sound_shoot
		audio_stream_player_3d.play()

	# Consume ammo via Cogito's system
	_item_ref.subtract(1)

	# Fire dispatch
	if weapon_data is Shotgun_Resource:
		_fire_shotgun()
	elif weapon_data is GrenadeLauncher_Resource:
		_fire_grenade()
	else:
		var cam_col: Vector3 = player_interaction_component.Get_Camera_Collision()
		match weapon_data.Type:
			1: # HITSCAN
				_hitscan_fire(cam_col)
			2: # PROJECTILE
				_fire_projectile(cam_col)

	# Recoil
	var rn := _get_recoil_node()
	if rn:
		rn.recoilFire(_is_aiming)

	# Set fire cooldown
	if weapon_data is AssaultRifle_Resource:
		_fire_cooldown = 60.0 / (weapon_data as AssaultRifle_Resource).fireRate
	elif weapon_data is LMG_Resource:
		_fire_cooldown = 60.0 / (weapon_data as LMG_Resource).fireRate
	elif weapon_data is Pistol_Resource:
		_fire_cooldown = (weapon_data as Pistol_Resource).triggerResetTime
	else:
		_fire_cooldown = 0.1

	# Post-fire state
	if mode == Weapon_Resource.FireMode.BOLT_ACTION:
		_bolt_is_cycled = false
		if not used_animation_shot:
			_schedule_post_fire_cycle(_get_shoot_visual_duration())

	if mode == Weapon_Resource.FireMode.PUMP:
		_pump_ready = false
		if not used_animation_shot:
			_schedule_post_fire_cycle(_get_shoot_visual_duration())

	if weapon_data is LMG_Resource:
		var lmg := weapon_data as LMG_Resource
		_current_heat = min(1.0, _current_heat + lmg.heatPerShot)
		if _current_heat >= 1.0:
			_is_firing = false


func _play_shoot_visual() -> bool:
	if _uses_animation_shoot_motion():
		var shoot_anim := _get_shoot_animation_name()
		animation_player.play(shoot_anim)
		return true

	_play_shoot_tween()
	return false


func _play_shoot_tween() -> void:
	var rest_position := _get_rest_position()
	var rest_rotation := _rest_rotation_degrees
	var kick_position := rest_position + _get_shot_position_offset()
	var kick_rotation := rest_rotation + _get_shot_rotation_offset_deg()

	_cancel_shoot_motion(true)
	_is_shoot_tween_active = true

	_shoot_tween = create_tween()
	_shoot_tween.tween_property(self, "position", kick_position, shoot_kick_out_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_shoot_tween.parallel().tween_property(self, "rotation_degrees", kick_rotation, shoot_kick_out_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_shoot_tween.tween_property(self, "position", rest_position, shoot_return_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_shoot_tween.parallel().tween_property(self, "rotation_degrees", rest_rotation, shoot_return_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	if _fire_part and fire_part_position_offset.length() > 0.0:
		_fire_part_tween = create_tween()
		_fire_part_tween.tween_property(_fire_part, "position", _fire_part_rest_position + fire_part_position_offset, fire_part_out_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		_fire_part_tween.tween_property(_fire_part, "position", _fire_part_rest_position, fire_part_return_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	_shoot_state_tween = create_tween()
	_shoot_state_tween.tween_interval(_get_shoot_visual_duration())
	_shoot_state_tween.finished.connect(_on_shoot_visual_finished)


func _on_shoot_visual_finished() -> void:
	_is_shoot_tween_active = false
	_apply_rest_pose()


func _schedule_post_fire_cycle(delay: float) -> void:
	if _post_fire_cycle_tween:
		_post_fire_cycle_tween.kill()

	_post_fire_cycle_tween = create_tween()
	if delay > 0.0:
		_post_fire_cycle_tween.tween_interval(delay)
	_post_fire_cycle_tween.finished.connect(_start_post_fire_cycle)


func _start_post_fire_cycle() -> void:
	_post_fire_cycle_tween = null
	if weapon_data == null:
		return

	var mode := weapon_data.get_fire_mode()
	if mode == Weapon_Resource.FireMode.BOLT_ACTION and weapon_data is BoltAction_Resource:
		var bolt_res := weapon_data as BoltAction_Resource
		if bolt_res.boltCycleAnimation != "" and animation_player.has_animation(bolt_res.boltCycleAnimation):
			animation_player.play(bolt_res.boltCycleAnimation)
		else:
			_schedule_bolt_cycle_completion(bolt_res.boltCycleDuration)
	elif mode == Weapon_Resource.FireMode.PUMP and weapon_data is Shotgun_Resource and (weapon_data as Shotgun_Resource).isPump:
		var shotgun_res := weapon_data as Shotgun_Resource
		if shotgun_res.pumpAnimation != "" and animation_player.has_animation(shotgun_res.pumpAnimation):
			animation_player.play(shotgun_res.pumpAnimation)
		else:
			_schedule_pump_cycle_completion(shotgun_res.pumpDuration)


func _schedule_bolt_cycle_completion(delay: float) -> void:
	if delay <= 0.0:
		_complete_bolt_cycle()
		return

	_post_fire_cycle_tween = create_tween()
	_post_fire_cycle_tween.tween_interval(delay)
	_post_fire_cycle_tween.finished.connect(_on_bolt_cycle_fallback_finished)


func _schedule_pump_cycle_completion(delay: float) -> void:
	if delay <= 0.0:
		_complete_pump_cycle()
		return

	_post_fire_cycle_tween = create_tween()
	_post_fire_cycle_tween.tween_interval(delay)
	_post_fire_cycle_tween.finished.connect(_on_pump_cycle_fallback_finished)


func _on_bolt_cycle_fallback_finished() -> void:
	_post_fire_cycle_tween = null
	_complete_bolt_cycle()


func _on_pump_cycle_fallback_finished() -> void:
	_post_fire_cycle_tween = null
	_complete_pump_cycle()


# ── Fire implementations ─────────────────────────────────────────────────────

func _hitscan_fire(collision_point: Vector3) -> void:
	var origin := bullet_point.global_position
	var direction := (collision_point - origin).normalized()
	var query := PhysicsRayQueryParameters3D.create(
		origin, collision_point + direction * 2.0
	)
	if player_interaction_component.player_rid:
		query.exclude = [player_interaction_component.player_rid]
	query.collision_mask = 0b111

	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result:
		_deal_damage(result.collider, direction, result.position)


func _fire_shotgun() -> void:
	var res := weapon_data as Shotgun_Resource
	var spread: float = res.adsSpreadAngle if _is_aiming else res.spreadAngle
	var camera := get_viewport().get_camera_3d()
	var vp: Vector2 = Vector2(get_viewport().get_size())
	var center: Vector2 = vp / 2.0

	for i in res.pelletCount:
		var offset: Vector2 = Vector2(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0)
		).normalized() * tan(deg_to_rad(spread))
		var spread_point: Vector2 = center + offset * vp.x * 0.1
		var ray_origin := camera.project_ray_origin(spread_point)
		var ray_end := ray_origin + camera.project_ray_normal(spread_point) * _item_ref.wieldable_range

		var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		if player_interaction_component.player_rid:
			query.exclude = [player_interaction_component.player_rid]
		query.collision_mask = 0b111

		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit:
			_deal_damage(hit.collider, (hit.position - ray_origin).normalized(), hit.position)


func _fire_grenade() -> void:
	var res := weapon_data as GrenadeLauncher_Resource
	if res.grenadeScene == null:
		return
	var camera := get_viewport().get_camera_3d()
	var forward := -camera.global_transform.basis.z
	var launch_dir := (forward + Vector3.UP * tan(deg_to_rad(res.launchAngle))).normalized()

	var grenade := res.grenadeScene.instantiate()
	get_tree().current_scene.add_child(grenade)
	grenade.global_position = bullet_point.global_position
	if grenade.has_method("set_linear_velocity"):
		grenade.set_linear_velocity(launch_dir * res.launchVelocity)
	if "damage_amount" in grenade:
		grenade.damage_amount = _item_ref.wieldable_damage
	if "fuse_duration" in grenade:
		grenade.fuse_duration = res.fuseDuration
	if "blast_radius" in grenade:
		grenade.blast_radius = res.blastRadius


func _fire_projectile(target_point: Vector3) -> void:
	if weapon_data.bulletProjectileToLoad == null:
		return
	var direction := (target_point - bullet_point.global_position).normalized()
	var proj := weapon_data.bulletProjectileToLoad.instantiate()
	get_tree().current_scene.add_child(proj)
	proj.global_position = bullet_point.global_position
	if "damage_amount" in proj:
		proj.damage_amount = _item_ref.wieldable_damage
	if proj.has_method("set_linear_velocity"):
		proj.set_linear_velocity(direction * weapon_data.weaponVelocity)
	if "Direction" in proj:
		proj.Direction = direction


func _deal_damage(collider: Node, direction: Vector3, hit_position: Vector3) -> void:
	if collider.has_signal("damage_received"):
		collider.damage_received.emit(_item_ref.wieldable_damage, direction, hit_position)


# ── ADS ───────────────────────────────────────────────────────────────────────

func _enter_ads() -> void:
	if _is_aiming:
		return
	if animation_player.is_playing():
		return
	if block_ads_during_shot_tween and _is_shoot_tween_active:
		return

	_is_aiming = true
	_cancel_ads_motion(false)
	_play_ads_transition()
	if player_interaction_component:
		player_interaction_component.update_crosshair.emit(false)


func _exit_ads(immediate: bool = false) -> void:
	if not _is_aiming and not immediate:
		return
	if not immediate and block_ads_during_shot_tween and _is_shoot_tween_active:
		return

	_is_aiming = false
	_cancel_ads_motion(false)
	_play_ads_transition(immediate)
	if player_interaction_component:
		player_interaction_component.update_crosshair.emit(true)


func _play_ads_transition(immediate: bool = false) -> void:
	var camera := get_viewport().get_camera_3d()
	var is_marksman := weapon_data is MarksmanRifle_Resource
	var target_fov := 75.0
	var duration := ads_time

	if _is_aiming:
		target_fov = ads_fov
		if is_marksman:
			var marksman_res := weapon_data as MarksmanRifle_Resource
			target_fov = marksman_res.scopedFOV
			duration = marksman_res.scopeInTime
	else:
		if is_marksman:
			duration = (weapon_data as MarksmanRifle_Resource).scopeInTime

	if camera:
		if immediate:
			camera.fov = target_fov
		else:
			_ads_camera_tween = create_tween()
			_ads_camera_tween.tween_property(camera, "fov", target_fov, duration)

	if is_marksman:
		return

	var target_position := _get_rest_position()
	if immediate:
		position = target_position
	else:
		_ads_weapon_tween = create_tween()
		_ads_weapon_tween.tween_property(self, "position", target_position, duration)


# ── Animation callbacks ──────────────────────────────────────────────────────

func _on_anim_finished(anim_name: StringName) -> void:
	var is_reload_anim := anim_name == anim_reload \
		or anim_name == anim_reload_empty \
		or (anim_reload_ads != "" and anim_name == anim_reload_ads) \
		or (anim_reload_empty_ads != "" and anim_name == anim_reload_empty_ads)

	if is_reload_anim:
		_finish_reload_from_inventory()
		_is_reloading = false
		_capture_rest_state()

	var used_animation_shoot := _uses_animation_shoot_motion()
	if used_animation_shoot and _is_shoot_animation_name(anim_name):
		if weapon_data is BoltAction_Resource:
			var bolt_anim: String = (weapon_data as BoltAction_Resource).boltCycleAnimation
			if bolt_anim != "" and animation_player.has_animation(bolt_anim):
				animation_player.play(bolt_anim)

		if weapon_data is Shotgun_Resource and (weapon_data as Shotgun_Resource).isPump:
			var pump_anim: String = (weapon_data as Shotgun_Resource).pumpAnimation
			if pump_anim != "" and animation_player.has_animation(pump_anim):
				animation_player.play(pump_anim)

	if weapon_data is BoltAction_Resource:
		if anim_name == (weapon_data as BoltAction_Resource).boltCycleAnimation:
			_complete_bolt_cycle()

	if weapon_data is Shotgun_Resource:
		if anim_name == (weapon_data as Shotgun_Resource).pumpAnimation:
			_complete_pump_cycle()

	if weapon_data is LMG_Resource:
		if anim_name == (weapon_data as LMG_Resource).ventAnimation:
			_is_venting = false
			_is_reloading = false
			_capture_rest_state()

	if anim_name == anim_equip:
		_capture_rest_state()


# ── Helpers ───────────────────────────────────────────────────────────────────

func _get_recoil_node() -> Node3D:
	if not player_interaction_component:
		return null
	return player_interaction_component.get_parent().get_node_or_null("Body/Neck/Head/CameraRecoil") as Node3D


func _get_inventory() -> CogitoInventory:
	if player_interaction_component == null:
		return null
	return player_interaction_component.get_parent().inventory_data as CogitoInventory


func _get_available_reload_amount() -> int:
	var inventory: CogitoInventory = _get_inventory()
	if inventory == null or _item_ref == null:
		return 0

	var total: int = 0
	for slot: InventorySlotPD in inventory.inventory_slots:
		if slot == null or slot.inventory_item == null:
			continue
		if slot.inventory_item.name != _item_ref.ammo_item_name:
			continue

		var ammo_item := slot.inventory_item as AmmoItemPD
		if ammo_item == null:
			continue

		total += ammo_item.reload_amount * slot.quantity

	return total


func _consume_inventory_ammo(ammo_needed: int) -> int:
	var inventory: CogitoInventory = _get_inventory()
	if inventory == null:
		return 0

	var ammo_loaded: int = 0
	var inventory_changed: bool = false

	for slot: InventorySlotPD in inventory.inventory_slots:
		if ammo_needed <= 0:
			break
		if slot == null or slot.inventory_item == null:
			continue
		if slot.inventory_item.name != _item_ref.ammo_item_name:
			continue

		var ammo_item := slot.inventory_item as AmmoItemPD
		if ammo_item == null:
			continue

		var quantity_needed: int = ceili(float(ammo_needed) / float(ammo_item.reload_amount))
		var quantity_used: int = mini(slot.quantity, quantity_needed)
		var ammo_used: int = ammo_item.reload_amount * quantity_used

		if quantity_used >= slot.quantity:
			inventory.remove_slot_data(slot)
		else:
			slot.quantity -= quantity_used

		ammo_loaded += ammo_used
		ammo_needed -= ammo_used
		inventory_changed = true

	if inventory_changed:
		inventory.inventory_updated.emit(inventory)

	return ammo_loaded


func _finish_reload_from_inventory() -> void:
	if _item_ref == null:
		return

	var ammo_needed: int = ceili(_item_ref.charge_max - _item_ref.charge_current)
	if ammo_needed <= 0:
		return

	var ammo_loaded: int = _consume_inventory_ammo(ammo_needed)
	if ammo_loaded > 0:
		_item_ref.add(ammo_loaded)


func _tween_trigger(target_z_deg: float) -> void:
	if _trigger_mesh == null:
		return
	if _trigger_tween and _trigger_tween.is_running():
		_trigger_tween.kill()
	_trigger_tween = create_tween()
	_trigger_tween.tween_property(
		_trigger_mesh,
		"rotation_degrees:z",
		target_z_deg,
		0.06
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _tween_trigger_delayed(target_z_deg: float, delay: float) -> void:
	if _trigger_mesh == null:
		return
	if _trigger_tween and _trigger_tween.is_running():
		_trigger_tween.kill()
	_trigger_tween = create_tween()
	if delay > 0.0:
		_trigger_tween.tween_interval(delay)
	_trigger_tween.tween_property(
		_trigger_mesh,
		"rotation_degrees:z",
		target_z_deg,
		0.06
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _reset_state() -> void:
	_fire_cooldown = 0.0
	_bolt_is_cycled = true
	_pump_ready = true
	_current_heat = 0.0
	_is_venting = false
	_is_reloading = false
	_is_firing = false
	_is_aiming = false
	_is_shoot_tween_active = false
	_capture_rest_state()


func _resolve_fire_part() -> void:
	_fire_part = null
	if fire_part_node != NodePath(""):
		_fire_part = get_node_or_null(fire_part_node) as Node3D
	if _fire_part:
		_fire_part_rest_position = _fire_part.position


func _capture_rest_state() -> void:
	_rest_rotation_degrees = rotation_degrees
	_resolve_fire_part()


func _get_rest_position() -> Vector3:
	if _is_aiming and not (weapon_data is MarksmanRifle_Resource):
		return Vector3(0, ads_position.y, ads_position.z)
	return default_position


func _apply_rest_pose() -> void:
	position = _get_rest_position()
	rotation_degrees = _rest_rotation_degrees
	if _fire_part:
		_fire_part.position = _fire_part_rest_position


func _cancel_all_motion_tweens(restore_rest: bool) -> void:
	_cancel_shoot_motion(restore_rest)
	_cancel_ads_motion(false)


func _cancel_shoot_motion(restore_rest: bool) -> void:
	if _shoot_tween:
		_shoot_tween.kill()
		_shoot_tween = null
	if _fire_part_tween:
		_fire_part_tween.kill()
		_fire_part_tween = null
	if _shoot_state_tween:
		_shoot_state_tween.kill()
		_shoot_state_tween = null
	if _post_fire_cycle_tween:
		_post_fire_cycle_tween.kill()
		_post_fire_cycle_tween = null
	_is_shoot_tween_active = false
	if restore_rest:
		_apply_rest_pose()


func _cancel_ads_motion(apply_target_pose: bool) -> void:
	if _ads_camera_tween:
		_ads_camera_tween.kill()
		_ads_camera_tween = null
	if _ads_weapon_tween:
		_ads_weapon_tween.kill()
		_ads_weapon_tween = null

	if not apply_target_pose:
		return

	var camera := get_viewport().get_camera_3d()
	var target_fov := 75.0
	if _is_aiming:
		if weapon_data is MarksmanRifle_Resource:
			target_fov = (weapon_data as MarksmanRifle_Resource).scopedFOV
		else:
			target_fov = ads_fov
	if camera:
		camera.fov = target_fov
	if not (weapon_data is MarksmanRifle_Resource):
		position = _get_rest_position()


func _get_shoot_animation_name() -> String:
	if _is_aiming and anim_shoot_ads != "" and animation_player.has_animation(anim_shoot_ads):
		return anim_shoot_ads
	return anim_action_primary


func _uses_animation_shoot_motion() -> bool:
	if shoot_motion_mode != ShootMotionMode.ANIMATION:
		return false
	var shoot_anim := _get_shoot_animation_name()
	return shoot_anim != "" and animation_player.has_animation(shoot_anim)


func _is_shoot_animation_name(anim_name: StringName) -> bool:
	if anim_name == anim_action_primary:
		return true
	return anim_shoot_ads != "" and anim_name == anim_shoot_ads


func _is_shoot_animation_playing() -> bool:
	if not animation_player.is_playing():
		return false
	return _is_shoot_animation_name(animation_player.current_animation)


func _get_shot_position_offset() -> Vector3:
	return ads_shot_position_offset if _is_aiming else hip_shot_position_offset


func _get_shot_rotation_offset_deg() -> Vector3:
	return ads_shot_rotation_deg if _is_aiming else hip_shot_rotation_deg


func _get_shoot_visual_duration() -> float:
	var root_duration: float = max(0.0, shoot_kick_out_time) + max(0.0, shoot_return_time)
	var fire_part_duration: float = 0.0
	if _fire_part and fire_part_position_offset.length() > 0.0:
		fire_part_duration = max(0.0, fire_part_out_time) + max(0.0, fire_part_return_time)
	return max(root_duration, fire_part_duration)


func _complete_bolt_cycle() -> void:
	_bolt_is_cycled = true
	_capture_rest_state()


func _complete_pump_cycle() -> void:
	_pump_ready = true
	_capture_rest_state()
