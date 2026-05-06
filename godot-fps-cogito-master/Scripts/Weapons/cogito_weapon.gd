extends CogitoWieldable
class_name CogitoFirearm
## Thin orchestrator bridging Weapon_Resource types into Cogito's wieldable system.
## Delegates fire logic, post-fire visuals, anim transitions, and reset to
## weapon_data virtuals; motion to helper RefCounted objects.
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
## Mutually-exclusive action states. CYCLING covers both bolt-action and pump
## (no weapon is both). VENTING is the LMG heat-vent path (formerly _is_venting
## with _is_reloading held true alongside).
enum WeaponState { IDLE, CYCLING, RELOADING, VENTING }
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
@onready var bullet_point: Marker3D = get_node_or_null("%Bullet_Point") as Marker3D
## Muzzle flash scene to spawn on each shot (first-person view).
## Use any muzzle_flash_0N.tscn or short_flash_0N.tscn from Scene/VFX/MuzzleFlash.
@export var muzzle_flash_scene: PackedScene
@export var muzzle_flash_scale: float = 1.0

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
## Bolt-cycle animation while ADS (leave empty to fall back to boltCycleAnimation).
@export var bolt_cycle_animation_ads: String = "bolt_cycle_ads"

@export_group("Bolt Tween")
## Assign the bolt handle mesh node (e.g. Cylinder_001). When set, bolt cycle uses tweens.
## Tween parameters (positions, rotations, durations) live in BoltAction_Resource.
@export var bolt_part_node: NodePath

@export_group("Pistol Parts")
## Node mesh của hammer. Khi set + weapon_data là Pistol_Resource → chạy hammer tween khi bắn.
@export var hammer_part_node: NodePath

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

var _state: WeaponState = WeaponState.IDLE
var _trigger_held: bool = false
var _fire_cooldown: float = 0.0
var _current_heat: float = 0.0
var _sprint_blocked_press: bool = false
var _item_ref: WieldableItemPD
var _rest_rotation_degrees: Vector3 = Vector3.ZERO
var _post_fire_cycle_tween: Tween = null
var _bolt_part: Node3D = null
var _bolt_cycle_tween: Tween = null
var _bolt_root_tween: Tween = null
var _bolt_pre_cycle_rest_rot: Vector3 = Vector3.ZERO
var _hammer_part: Node3D = null
var _hammer_tween: Tween = null
var _audio_reload: AudioStreamPlayer3D


# ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	if wieldable_mesh:
		wieldable_mesh.hide()
	animation_player.animation_finished.connect(_on_anim_finished)
	_audio_reload = AudioStreamPlayer3D.new()
	_audio_reload.bus = audio_stream_player_3d.bus if audio_stream_player_3d else "Master"
	add_child(_audio_reload)

	_trigger = TriggerAnimator.new(self)
	_ads = ADSController.new(self)
	_shoot_motion = ShootMotionController.new(self)
	_shoot_motion.shoot_visual_finished.connect(_on_shoot_visual_finished)
	_ammo = AmmoManager.new(null)
	_sync_shoot_motion_config()
	_capture_rest_state()
	if bolt_part_node != NodePath(""):
		_bolt_part = get_node_or_null(bolt_part_node) as Node3D
	if hammer_part_node != NodePath(""):
		_hammer_part = get_node_or_null(hammer_part_node) as Node3D


func _physics_process(delta: float) -> void:
	if weapon_data == null:
		return

	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)

	# Auto-fire loop — only when state is IDLE (not reloading/venting/cycling).
	if _trigger_held and _state == WeaponState.IDLE and _fire_cooldown <= 0.0:
		if _is_player_sprinting():
			_trigger_held = false
		elif _item_ref and _item_ref.charge_current > 0:
			_try_fire()
		else:
			_trigger_held = false

	# Per-type per-frame work (e.g. LMG heat decay).
	weapon_data.tick(self, delta)


# ── CogitoWieldable interface ────────────────────────────────────────────────

func equip(_player_interaction_component: PlayerInteractionComponent) -> void:
	player_interaction_component = _player_interaction_component
	_item_ref = item_reference
	_ammo.set_pic(player_interaction_component)
	if bullet_point == null:
		push_error("cogito_weapon: %%Bullet_Point Marker3D missing on weapon scene %s" % name)
	_reset_state()
	_shoot_motion.cancel(false)
	animation_player.play(anim_equip)
	_configure_recoil()


func unequip() -> void:
	if _bolt_cycle_tween:
		_bolt_cycle_tween.kill()
		_bolt_cycle_tween = null
	if _bolt_root_tween:
		_bolt_root_tween.kill()
		_bolt_root_tween = null
	if _hammer_tween:
		_hammer_tween.kill()
		_hammer_tween = null
	if _post_fire_cycle_tween:
		_post_fire_cycle_tween.kill()
		_post_fire_cycle_tween = null
	_shoot_motion.cancel(true)
	_apply_rest_pose()
	_trigger_held = false
	_state = WeaponState.IDLE
	_sprint_blocked_press = false
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
		_trigger_held = false
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
		_trigger_held = true
		_try_fire()
		return

	# All other modes: single shot on press
	_try_fire()


func action_secondary(_is_released: bool) -> void:
	if _is_released:
		if _bolt_root_tween:
			_bolt_root_tween.kill()
			_bolt_root_tween = null
			rotation_degrees = _bolt_pre_cycle_rest_rot
		_ads.exit(weapon_data, ads_fov, ads_time, default_position,
				block_ads_during_shot_tween, _shoot_motion.is_active, false,
				player_interaction_component)
	else:
		if _is_player_sprinting():
			return
		if _bolt_root_tween:
			_bolt_root_tween.kill()
			_bolt_root_tween = null
			rotation_degrees = _bolt_pre_cycle_rest_rot
		_ads.enter(weapon_data, ads_fov, ads_time, ads_position, default_position,
				block_ads_during_shot_tween, _shoot_motion.is_active,
				animation_player, player_interaction_component)


func reload() -> void:
	if weapon_data == null or _state != WeaponState.IDLE or animation_player.is_playing():
		return
	if _item_ref == null:
		return

	# Let resource handle special reload (LMG vent)
	var reload_ctx := {"current_heat": _current_heat}
	if weapon_data.on_reload(reload_ctx):
		_shoot_motion.cancel(true)
		_apply_rest_pose()
		if reload_ctx.get("start_venting", false):
			_state = WeaponState.VENTING
			var vent_anim: String = reload_ctx.get("vent_animation", "")
			if vent_anim != "":
				animation_player.play(vent_anim)
			_play_reload_sound()
		return

	var ammo_needed: int = ceili(_item_ref.charge_max - _item_ref.charge_current)
	if ammo_needed <= 0 or _ammo.get_available_ammo(_item_ref) <= 0:
		return

	_shoot_motion.cancel(true)
	_apply_rest_pose()
	_state = WeaponState.RELOADING
	animation_player.play(_get_reload_animation_name())
	_play_reload_sound()


func cancel_ads_for_sprint() -> void:
	if _ads == null or weapon_data == null:
		return
	if _ads.is_aiming:
		if _bolt_root_tween:
			_bolt_root_tween.kill()
			_bolt_root_tween = null
			rotation_degrees = _bolt_pre_cycle_rest_rot
		_ads.exit(weapon_data, ads_fov, ads_time, default_position,
				block_ads_during_shot_tween, _shoot_motion.is_active, true,
				player_interaction_component)


func is_ads_active() -> bool:
	return _ads != null and _ads.is_aiming


func should_suspend_container_motion() -> bool:
	return animation_player.is_playing() \
		or _state != WeaponState.IDLE \
		or _trigger_held \
		or (_shoot_motion != null and _shoot_motion.is_active)


# ── Fire logic ───────────────────────────────────────────────────────────────

func _try_fire() -> void:
	if _is_player_sprinting():
		_trigger_held = false
		return
	# State gate replaces the old _is_reloading + _bolt_is_cycled + _pump_ready
	# guard chain: any non-IDLE state blocks fire.
	if weapon_data == null or _state != WeaponState.IDLE or _fire_cooldown > 0.0:
		return
	if _item_ref == null or _item_ref.charge_current <= 0:
		if _item_ref:
			_item_ref.send_empty_hint()
		_trigger_held = false
		return

	var mode := weapon_data.get_fire_mode()

	var fire_state := {"current_heat": _current_heat}
	if not weapon_data.can_fire(fire_state):
		_trigger_held = false
		return

	if _uses_animation_shoot_motion() and mode != Weapon_Resource.FireMode.AUTO and _is_shoot_animation_playing():
		return

	# ── Execute shot ─────────────────────────────────────────────────────────

	# Visual
	_play_shoot_visual()

	# Sound
	if sound_shoot:
		audio_stream_player_3d.stream = sound_shoot
		audio_stream_player_3d.play()

	# Muzzle flash (first-person view)
	_spawn_muzzle_flash_fpv()

	# Consume ammo
	_item_ref.subtract(1)

	# Delegate fire to resource (polymorphic dispatch)
	var ctx := _build_fire_context()
	weapon_data.fire(ctx)
	# Broadcast remote firing effects to all other clients.
	_emit_remote_fire_fx()
	if shell_eject_timing == ShellEjectTiming.ON_FIRE and not weapon_data.handles_own_shell_eject(self):
		_spawn_shell_casing()

	# Recoil
	_apply_recoil()

	# Cooldown (polymorphic)
	_fire_cooldown = weapon_data.get_fire_cooldown()

	# Type-specific post-fire visuals + state (bolt cycle, pump, hammer, slide-lock,
	# LMG heat).  Each Weapon_Resource subclass overrides play_post_fire_visual.
	weapon_data.play_post_fire_visual(self)


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
## Schedule a post-fire callback after a delay (e.g. shoot-tween duration).
## Resources call this to start their bolt/pump cycle when shoot motion finishes.
func _schedule_post_fire_cycle(delay: float, on_cycle: Callable) -> void:
	if _post_fire_cycle_tween:
		_post_fire_cycle_tween.kill()
	_post_fire_cycle_tween = create_tween()
	if delay > 0.0:
		_post_fire_cycle_tween.tween_interval(delay)
	_post_fire_cycle_tween.finished.connect(on_cycle)


## Wait `delay` seconds, then call `on_done`.  Used by resources whose cycle
## animation is missing (fallback to a timed completion).
func _complete_cycle_after_delay(delay: float, on_done: Callable) -> void:
	if delay <= 0.0:
		on_done.call()
		return
	_post_fire_cycle_tween = create_tween()
	_post_fire_cycle_tween.tween_interval(delay)
	_post_fire_cycle_tween.finished.connect(on_done)


# ── Animation callbacks ──────────────────────────────────────────────────────

func _on_anim_finished(anim_name: StringName) -> void:
	# Reload finished — restock magazine and clear state.
	if _is_reload_animation(anim_name):
		_ammo.finish_reload(_item_ref)
		_state = WeaponState.IDLE
		_capture_rest_state()

	# Per-type anim transitions (bolt cycle, pump cycle, vent finished,
	# slide-lock release, etc.).  Subclasses of Weapon_Resource handle their own.
	if weapon_data:
		weapon_data.on_anim_finished(self, anim_name)

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


func _run_bolt_tween() -> void:
	var bolt_res := weapon_data as BoltAction_Resource
	if _bolt_cycle_tween:
		_bolt_cycle_tween.kill()
	if _bolt_root_tween:
		_bolt_root_tween.kill()

	# Capture rest transform now — works from any position (hip or ADS)
	var base_pos := position
	var base_rot := rotation

	# Save the authoritative rest rotation before any tweening.
	# Restored explicitly before _capture_rest_state() to prevent drift.
	_bolt_pre_cycle_rest_rot = _rest_rotation_degrees

	# Root viewmodel motion — eases to offset as bolt pulls back, returns as it closes
	_bolt_root_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_bolt_root_tween.tween_property(self, "position",
		base_pos + bolt_res.bolt_root_position_offset, bolt_res.bolt_root_out_duration)
	_bolt_root_tween.parallel().tween_property(self, "rotation",
		base_rot + bolt_res.bolt_root_rotation_offset, bolt_res.bolt_root_out_duration)
	_bolt_root_tween.tween_property(self, "position", base_pos, bolt_res.bolt_root_return_duration)
	_bolt_root_tween.parallel().tween_property(self, "rotation", base_rot, bolt_res.bolt_root_return_duration)

	# Shell ejection timed to bolt pull-back moment — always handled here for bolt tween.
	var shell_timer := create_tween()
	shell_timer.tween_interval(bolt_res.shell_eject_delay)
	shell_timer.tween_callback(_spawn_shell_casing)

	# Bolt handle sequential tween
	_bolt_cycle_tween = create_tween().set_trans(Tween.TRANS_SINE)
	# 1. Unlock: rotate handle up
	_bolt_cycle_tween.tween_property(_bolt_part, "rotation",
		bolt_res.bolt_unlocked_rotation, bolt_res.bolt_unlock_duration)
	# 2. Pause before pulling
	_bolt_cycle_tween.tween_interval(0.067)
	# 3. Pull bolt back
	_bolt_cycle_tween.tween_property(_bolt_part, "position",
		bolt_res.bolt_position_back, bolt_res.bolt_pull_duration)
	# 4. Hold
	_bolt_cycle_tween.tween_interval(bolt_res.bolt_hold_duration)
	# 5. Push bolt forward
	_bolt_cycle_tween.tween_property(_bolt_part, "position",
		bolt_res.bolt_position_forward, bolt_res.bolt_push_duration)
	# 6. Pause before locking
	_bolt_cycle_tween.tween_interval(0.1)
	# 7. Lock: rotate handle down
	_bolt_cycle_tween.tween_property(_bolt_part, "rotation",
		bolt_res.bolt_locked_rotation, bolt_res.bolt_lock_duration)
	_bolt_cycle_tween.finished.connect(func():
		_bolt_cycle_tween = null
		if _bolt_root_tween:
			_bolt_root_tween.kill()
			_bolt_root_tween = null
		# Restore rotation to pre-cycle rest value before _capture_rest_state() reads it
		rotation_degrees = _bolt_pre_cycle_rest_rot
		_state = WeaponState.IDLE
		_capture_rest_state()
	)


func _run_pistol_parts_tween() -> void:
	var p_res := weapon_data as Pistol_Resource
	if _hammer_part != null:
		if _hammer_tween:
			_hammer_tween.kill()
		_hammer_tween = create_tween().set_trans(Tween.TRANS_SINE)
		_hammer_tween.tween_property(_hammer_part, "rotation",
			p_res.hammer_cocked_rotation, p_res.hammer_cock_duration)
		_hammer_tween.tween_property(_hammer_part, "rotation",
			p_res.hammer_rest_rotation, p_res.hammer_return_duration)
		_hammer_tween.finished.connect(func(): _hammer_tween = null)


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
	if _shoot_motion.fire_part and not _shoot_motion.fire_part_locked:
		_shoot_motion.fire_part.position = _shoot_motion.fire_part_rest_position


func _reset_state() -> void:
	_state = WeaponState.IDLE
	_fire_cooldown = 0.0
	_current_heat = 0.0
	_trigger_held = false
	_sprint_blocked_press = false
	_ads.is_aiming = false
	if _bolt_cycle_tween:
		_bolt_cycle_tween.kill()
		_bolt_cycle_tween = null
	if _bolt_root_tween:
		_bolt_root_tween.kill()
		_bolt_root_tween = null
	if _hammer_tween:
		_hammer_tween.kill()
		_hammer_tween = null
	# Per-type rest snap (bolt forward+locked, hammer rest, etc.).
	if weapon_data:
		weapon_data.on_reset(self)
	_shoot_motion.fire_part_locked = false
	_capture_rest_state()

func _play_reload_sound() -> void:
	if not sound_reload:
		return
	_audio_reload.stream = sound_reload
	_audio_reload.play()


func _spawn_muzzle_flash_fpv() -> void:
	if muzzle_flash_scene == null or bullet_point == null:
		return
	var flash := muzzle_flash_scene.instantiate() as Node3D
	if flash == null:
		return
	flash.scale = Vector3.ONE * muzzle_flash_scale
	# Parent under the muzzle marker so the flash follows the gun.
	bullet_point.add_child(flash)
	flash.transform = Transform3D.IDENTITY
	# ~7 frames at 60 fps — long enough for GPUParticles3D to emit + render a visible burst,
	# short enough to avoid catching VFXController's second loop cycle (stale particles).
	# weakref prevents "lambda capture freed" error if weapon is unequipped before timeout.
	var flash_ref: WeakRef = weakref(flash)
	get_tree().create_timer(0.05, false).timeout.connect(func():
		var f: Object = flash_ref.get_ref()
		if f != null:
			f.call("queue_free")
	)


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
		shell_instance.player_node = player

	var world_root := get_tree().current_scene
	if world_root == null:
		return

	world_root.add_child(shell_instance)
	shell_instance.global_transform = shell_eject_point.global_transform

	var active_shells := get_tree().get_nodes_in_group("shell_casings")
	if active_shells.size() > max_shell_casings:
		active_shells[0].queue_free()


## Multiplayer: tell all peers to play remote fire FX on this shooter's TPP weapon mesh.
## No-op in single-player (no peers) or when not the local authority.
func _emit_remote_fire_fx() -> void:
	if not player_interaction_component:
		return
	if multiplayer.get_peers().is_empty():
		return
	var player := player_interaction_component.get_parent()
	if not player or not player.is_multiplayer_authority():
		return
	if player.has_method("rpc_play_remote_fire_fx"):
		player.rpc_play_remote_fire_fx.rpc()
