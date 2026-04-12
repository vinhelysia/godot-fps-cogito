extends CogitoWieldable
## Thin orchestrator bridging Weapon_Resource types into Cogito's wieldable system.
## Delegates fire logic to weapon_data virtuals and motion to helper objects.
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
enum ShellEjectTiming { ON_FIRE, ON_CYCLE }
# ── EXPORTS (names preserved for .tscn compatibility) ────────────────────────

@export_group("Weapon Configuration")
## The Weapon_Resource that defines fire mode, recoil, and type-specific data.
@export var weapon_data: Weapon_Resource
@export_group("Shell Ejection")
@export var shell_casing_scene: PackedScene
@export_enum("On Fire", "On Cycle") var shell_eject_timing: int = ShellEjectTiming.ON_FIRE
@export var max_shell_casings: int = 10
@onready var shell_eject_point: Marker3D = get_node_or_null("%shell_eject_point") as Marker3D
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
## Reload animation when magazine is completely empty while ADSing.
@export var anim_reload_empty_ads: String = "reload_empty_ads"
## Reload animation while ADSing.
@export var anim_reload_ads: String = "reload_ads"

@export_group("Trigger Animation")
## Z-rotation (degrees) the trigger mesh rotates to when the mouse is held.
@export var trigger_pull_rotation: float = -20.0
## Minimum time (seconds) the trigger stays pulled.
@export var trigger_min_hold_time: float = 0.1

# ── Constants ────────────────────────────────────────────────────────────────

const ADS_RECOIL_SCALE: float = 0.4
const RECOIL_THRESHOLD: float = 0.001

# ── HELPERS (instantiated in _ready, not scene nodes) ────────────────────────

var _shoot_motion: ShootMotionController
var _trigger: TriggerAnimator
var _ads: ADSController
var _ammo: AmmoManager

# ── INTERNAL STATE ───────────────────────────────────────────────────────────

var _is_firing: bool = false
var _fire_cooldown: float = 0.0
var _is_reloading: bool = false
var _bolt_is_cycled: bool = true
var _pump_ready: bool = true
var _current_heat: float = 0.0
var _is_venting: bool = false
var _sprint_blocked_press: bool = false
var _item_ref: WieldableItemPD
var _rest_rotation_degrees: Vector3 = Vector3.ZERO
var _post_fire_cycle_tween: Tween = null


# ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	if wieldable_mesh:
		wieldable_mesh.hide()
	animation_player.animation_finished.connect(_on_anim_finished)

	_trigger = TriggerAnimator.new(self)
	_ads = ADSController.new(self)
	_shoot_motion = ShootMotionController.new(self)
	_shoot_motion.shoot_visual_finished.connect(_on_shoot_visual_finished)
	_sync_shoot_motion_config()
	_capture_rest_state()


func _physics_process(delta: float) -> void:
	if weapon_data == null:
		return

	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)

	# Auto-fire loop
	if _is_firing and not _is_reloading and _fire_cooldown <= 0.0:
		if _is_player_sprinting():
			_is_firing = false
		elif _item_ref and _item_ref.charge_current > 0:
			_try_fire()
		else:
			_is_firing = false

	# LMG passive heat cooldown
	if weapon_data is LMG_Resource:
		var lmg := weapon_data as LMG_Resource
		if not _is_firing and not _is_venting:
			_current_heat = maxf(0.0, _current_heat - lmg.cooldownRate * delta)
		if _is_venting:
			_current_heat = maxf(0.0, _current_heat - lmg.ventRate * delta)
			if _current_heat <= 0.0:
				_is_venting = false
				_is_reloading = false


# ── CogitoWieldable interface ────────────────────────────────────────────────

func equip(_player_interaction_component: PlayerInteractionComponent) -> void:
	player_interaction_component = _player_interaction_component
	_item_ref = item_reference
	_ammo = AmmoManager.new(player_interaction_component)
	_reset_state()
	_shoot_motion.cancel(false)
	animation_player.play(anim_equip)
	_configure_recoil()


func unequip() -> void:
	_shoot_motion.cancel(true)
	_apply_rest_pose()
	_is_firing = false
	if _ads.is_aiming:
		_ads.exit(weapon_data, ads_fov, ads_time, default_position,
				block_ads_during_shot_tween, _shoot_motion.is_active, true,
				player_interaction_component)
	else:
		_ads.cancel_tweens_and_snap(weapon_data, ads_fov, default_position, ads_position)
	animation_player.play(anim_unequip)


func action_primary(_passed_item_reference: InventoryItemPD, _is_released: bool) -> void:
	_item_ref = _passed_item_reference as WieldableItemPD
	if weapon_data == null:
		return

	if _is_released:
		_is_firing = false
		if not _sprint_blocked_press:
			var elapsed: float = Time.get_ticks_msec() / 1000.0 - _trigger.press_time
			var delay: float = maxf(0.0, trigger_min_hold_time - elapsed)
			_trigger.release_delayed(0.0, delay)
		_sprint_blocked_press = false
		return

	if _is_player_sprinting():
		_sprint_blocked_press = true
		return

	_sprint_blocked_press = false
	_trigger.press_time = Time.get_ticks_msec() / 1000.0
	_trigger.pull(trigger_pull_rotation)

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
		_ads.exit(weapon_data, ads_fov, ads_time, default_position,
				block_ads_during_shot_tween, _shoot_motion.is_active, false,
				player_interaction_component)
	else:
		if _is_player_sprinting():
			return
		_ads.enter(weapon_data, ads_fov, ads_time, ads_position, default_position,
				block_ads_during_shot_tween, _shoot_motion.is_active,
				animation_player, player_interaction_component)


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

	# Let resource handle special reload (LMG vent)
	var reload_ctx := {"current_heat": _current_heat}
	if weapon_data.on_reload(reload_ctx):
		_shoot_motion.cancel(true)
		_apply_rest_pose()
		if reload_ctx.get("start_venting", false):
			_is_venting = true
			_is_reloading = true
			var vent_anim: String = reload_ctx.get("vent_animation", "")
			if vent_anim != "":
				animation_player.play(vent_anim)
			if sound_reload:
				audio_stream_player_3d.stream = sound_reload
				audio_stream_player_3d.play()
		return

	var ammo_needed: int = ceili(_item_ref.charge_max - _item_ref.charge_current)
	if ammo_needed <= 0 or _ammo.get_available_ammo(_item_ref) <= 0:
		return

	_shoot_motion.cancel(true)
	_apply_rest_pose()
	_is_reloading = true
	animation_player.play(_get_reload_animation_name())
	if sound_reload:
		audio_stream_player_3d.stream = sound_reload
		audio_stream_player_3d.play()


func cancel_ads_for_sprint() -> void:
	if _ads == null or weapon_data == null:
		return
	if _ads.is_aiming:
		_ads.exit(weapon_data, ads_fov, ads_time, default_position,
				block_ads_during_shot_tween, _shoot_motion.is_active, true,
				player_interaction_component)


func is_ads_active() -> bool:
	return _ads != null and _ads.is_aiming


func should_suspend_container_motion() -> bool:
	return animation_player.is_playing() \
		or _is_reloading \
		or _is_firing \
		or (_shoot_motion != null and _shoot_motion.is_active)


# ── Fire logic ───────────────────────────────────────────────────────────────

func _try_fire() -> void:
	if _is_player_sprinting():
		_is_firing = false
		return
	if weapon_data == null or _is_reloading or _fire_cooldown > 0.0:
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

	var fire_state := {"current_heat": _current_heat}
	if not weapon_data.can_fire(fire_state):
		_is_firing = false
		return

	if _uses_animation_shoot_motion() and mode != Weapon_Resource.FireMode.AUTO and _is_shoot_animation_playing():
		return

	# ── Execute shot ─────────────────────────────────────────────────────────

	# Visual
	var used_animation_shot: bool = _play_shoot_visual()

	# Sound
	if sound_shoot:
		audio_stream_player_3d.stream = sound_shoot
		audio_stream_player_3d.play()

	# Consume ammo
	_item_ref.subtract(1)

	# Delegate fire to resource (polymorphic dispatch)
	var ctx := _build_fire_context()
	weapon_data.fire(ctx)
	if shell_eject_timing == ShellEjectTiming.ON_FIRE:
		_spawn_shell_casing()

	# Recoil
	_apply_recoil()

	# Cooldown (polymorphic)
	_fire_cooldown = weapon_data.get_fire_cooldown()

	# Post-fire (bolt cycle, pump — polymorphic)
	var post_ctx := {"used_animation_shot": used_animation_shot}
	if weapon_data.on_post_fire(post_ctx):
		if post_ctx.get("needs_bolt_cycle", false):
			_bolt_is_cycled = false
			if not used_animation_shot:
				_schedule_post_fire_cycle(_get_shoot_visual_duration(), "bolt")
		if post_ctx.get("needs_pump_cycle", false):
			_pump_ready = false
			if not used_animation_shot:
				_schedule_post_fire_cycle(_get_shoot_visual_duration(), "pump")

	# LMG heat accumulation
	if weapon_data is LMG_Resource:
		var lmg := weapon_data as LMG_Resource
		_current_heat = minf(1.0, _current_heat + lmg.heatPerShot)
		if _current_heat >= 1.0:
			_is_firing = false


func _build_fire_context() -> Dictionary:
	return {
		"bullet_point": bullet_point,
		"camera_collision": player_interaction_component.Get_Camera_Collision(),
		"is_aiming": _ads.is_aiming,
		"item_ref": _item_ref,
		"player_interaction_component": player_interaction_component,
		"world_3d": get_world_3d(),
		"viewport": get_viewport(),
		"scene_tree": get_tree(),
	}


# ── Shoot visual ─────────────────────────────────────────────────────────────

func _play_shoot_visual() -> bool:
	if _uses_animation_shoot_motion():
		animation_player.play(_get_shoot_animation_name())
		return true
	var rest_pos := _ads.get_rest_position(weapon_data, ads_position, default_position)
	_shoot_motion.play(rest_pos, _rest_rotation_degrees, _ads.is_aiming)
	return false


func _on_shoot_visual_finished() -> void:
	_apply_rest_pose()


func _get_shoot_visual_duration() -> float:
	return _shoot_motion.get_duration()


# ── Post-fire cycling ────────────────────────────────────────────────────────

func _schedule_post_fire_cycle(delay: float, cycle_type: String) -> void:
	if _post_fire_cycle_tween:
		_post_fire_cycle_tween.kill()
	_post_fire_cycle_tween = create_tween()
	if delay > 0.0:
		_post_fire_cycle_tween.tween_interval(delay)
	_post_fire_cycle_tween.finished.connect(_start_post_fire_cycle.bind(cycle_type))


func _start_post_fire_cycle(cycle_type: String) -> void:
	_post_fire_cycle_tween = null
	if weapon_data == null:
		return
	if shell_eject_timing == ShellEjectTiming.ON_CYCLE and (cycle_type == "bolt" or cycle_type == "pump"):
		_spawn_shell_casing()

	if cycle_type == "bolt" and weapon_data is BoltAction_Resource:
		var bolt_res := weapon_data as BoltAction_Resource
		if bolt_res.boltCycleAnimation != "" and animation_player.has_animation(bolt_res.boltCycleAnimation):
			animation_player.play(bolt_res.boltCycleAnimation)
		else:
			_complete_cycle_after_delay("bolt", bolt_res.boltCycleDuration)
	elif cycle_type == "pump" and weapon_data is Shotgun_Resource and (weapon_data as Shotgun_Resource).isPump:
		var sg := weapon_data as Shotgun_Resource
		if sg.pumpAnimation != "" and animation_player.has_animation(sg.pumpAnimation):
			animation_player.play(sg.pumpAnimation)
		else:
			_complete_cycle_after_delay("pump", sg.pumpDuration)


func _complete_cycle_after_delay(cycle_type: String, delay: float) -> void:
	if delay <= 0.0:
		_finalize_cycle(cycle_type)
		return
	_post_fire_cycle_tween = create_tween()
	_post_fire_cycle_tween.tween_interval(delay)
	_post_fire_cycle_tween.finished.connect(func():
		_post_fire_cycle_tween = null
		_finalize_cycle(cycle_type)
	)


func _finalize_cycle(cycle_type: String) -> void:
	if cycle_type == "bolt":
		_bolt_is_cycled = true
	elif cycle_type == "pump":
		_pump_ready = true
	_capture_rest_state()


# ── Animation callbacks ──────────────────────────────────────────────────────

func _on_anim_finished(anim_name: StringName) -> void:
	# Reload finished
	if _is_reload_animation(anim_name):
		_ammo.finish_reload(_item_ref)
		_is_reloading = false
		_capture_rest_state()

	# Shoot animation finished — chain bolt/pump cycle
	if _uses_animation_shoot_motion() and _is_shoot_animation_name(anim_name):
		if weapon_data is BoltAction_Resource:
			var bolt_anim: String = (weapon_data as BoltAction_Resource).boltCycleAnimation
			if bolt_anim != "" and animation_player.has_animation(bolt_anim):
				animation_player.play(bolt_anim)
		if weapon_data is Shotgun_Resource and (weapon_data as Shotgun_Resource).isPump:
			var pump_anim: String = (weapon_data as Shotgun_Resource).pumpAnimation
			if pump_anim != "" and animation_player.has_animation(pump_anim):
				animation_player.play(pump_anim)

	# Bolt/pump cycle animations finished
	if weapon_data is BoltAction_Resource and anim_name == (weapon_data as BoltAction_Resource).boltCycleAnimation:
		_bolt_is_cycled = true
		_capture_rest_state()
	if weapon_data is Shotgun_Resource and anim_name == (weapon_data as Shotgun_Resource).pumpAnimation:
		_pump_ready = true
		_capture_rest_state()

	# LMG vent finished
	if weapon_data is LMG_Resource and anim_name == (weapon_data as LMG_Resource).ventAnimation:
		_is_venting = false
		_is_reloading = false
		_capture_rest_state()

	# Equip finished
	if anim_name == anim_equip:
		_capture_rest_state()


# ── Helpers ──────────────────────────────────────────────────────────────────

func _configure_recoil() -> void:
	var rn := _get_recoil_node()
	if rn and weapon_data:
		var hip := Vector3(weapon_data.recoilVertical, weapon_data.recoilHorizontal, 0.0)
		rn.setRecoil(hip)
		var aim := aim_recoil_values if aim_recoil_values.length() > RECOIL_THRESHOLD else hip * ADS_RECOIL_SCALE
		if rn.has_method("setAimRecoil"):
			rn.setAimRecoil(aim)


func _apply_recoil() -> void:
	var rn := _get_recoil_node()
	if rn:
		rn.recoilFire(_ads.is_aiming)


func _get_recoil_node() -> Node3D:
	if not player_interaction_component:
		return null
	var player := player_interaction_component.get_parent()
	if not player:
		return null
	return player.find_child("CameraRecoil", true, false) as Node3D


func _is_player_sprinting() -> bool:
	if not player_interaction_component:
		return false
	var player := player_interaction_component.get_parent()
	return player != null and player.get("is_sprinting") == true


func _get_reload_animation_name() -> String:
	var is_empty := _item_ref != null and _item_ref.charge_current <= 0
	if _ads.is_aiming:
		if is_empty and anim_reload_empty_ads != "":
			return anim_reload_empty_ads
		if anim_reload_ads != "":
			return anim_reload_ads
		if is_empty and anim_reload_empty != "":
			return anim_reload_empty
	if is_empty and anim_reload_empty != "":
		return anim_reload_empty
	return anim_reload


func _is_reload_animation(anim_name: StringName) -> bool:
	return anim_name == anim_reload \
		or anim_name == anim_reload_empty \
		or (anim_reload_ads != "" and anim_name == anim_reload_ads) \
		or (anim_reload_empty_ads != "" and anim_name == anim_reload_empty_ads)


func _uses_animation_shoot_motion() -> bool:
	if shoot_motion_mode != ShootMotionMode.ANIMATION:
		return false
	var shoot_anim := _get_shoot_animation_name()
	return shoot_anim != "" and animation_player.has_animation(shoot_anim)


func _get_shoot_animation_name() -> String:
	if _ads.is_aiming and anim_shoot_ads != "" and animation_player.has_animation(anim_shoot_ads):
		return anim_shoot_ads
	return anim_action_primary


func _is_shoot_animation_name(anim_name: StringName) -> bool:
	return anim_name == anim_action_primary or (anim_shoot_ads != "" and anim_name == anim_shoot_ads)


func _is_shoot_animation_playing() -> bool:
	return animation_player.is_playing() and _is_shoot_animation_name(animation_player.current_animation)


func _sync_shoot_motion_config() -> void:
	_shoot_motion.hip_shot_position_offset = hip_shot_position_offset
	_shoot_motion.hip_shot_rotation_deg = hip_shot_rotation_deg
	_shoot_motion.ads_shot_position_offset = ads_shot_position_offset
	_shoot_motion.ads_shot_rotation_deg = ads_shot_rotation_deg
	_shoot_motion.shoot_kick_out_time = shoot_kick_out_time
	_shoot_motion.shoot_return_time = shoot_return_time
	_shoot_motion.fire_part_position_offset = fire_part_position_offset
	_shoot_motion.fire_part_out_time = fire_part_out_time
	_shoot_motion.fire_part_return_time = fire_part_return_time
	_resolve_fire_part()


func _resolve_fire_part() -> void:
	_shoot_motion.fire_part = null
	if fire_part_node != NodePath(""):
		_shoot_motion.fire_part = get_node_or_null(fire_part_node) as Node3D
	if _shoot_motion.fire_part:
		_shoot_motion.fire_part_rest_position = _shoot_motion.fire_part.position


func _capture_rest_state() -> void:
	_rest_rotation_degrees = rotation_degrees
	_resolve_fire_part()


func _apply_rest_pose() -> void:
	position = _ads.get_rest_position(weapon_data, ads_position, default_position)
	rotation_degrees = _rest_rotation_degrees
	if _shoot_motion.fire_part:
		_shoot_motion.fire_part.position = _shoot_motion.fire_part_rest_position


func _reset_state() -> void:
	_fire_cooldown = 0.0
	_bolt_is_cycled = true
	_pump_ready = true
	_current_heat = 0.0
	_is_venting = false
	_is_reloading = false
	_is_firing = false
	_sprint_blocked_press = false
	_ads.is_aiming = false
	_capture_rest_state()

func _spawn_shell_casing() -> void:
	if shell_casing_scene == null or shell_eject_point == null:
		return

	var shell_instance := shell_casing_scene.instantiate() as ShellCasingFx
	if shell_instance == null:
		push_warning("shell_casing_scene root must be ShellCasingFx.")
		return

	if player_interaction_component:
		var player := player_interaction_component.get_parent()
		if "main_velocity" in player:
			shell_instance.player_velocity = player.main_velocity

	var world_root := get_tree().current_scene
	if world_root == null:
		return

	world_root.add_child(shell_instance)
	shell_instance.global_transform = shell_eject_point.global_transform

	var active_shells := get_tree().get_nodes_in_group("shell_casings")
	if active_shells.size() > max_shell_casings:
		active_shells[0].queue_free()
