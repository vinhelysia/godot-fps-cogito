extends Node3D
class_name ScavPerception

## SENSOR ONLY — writes blackboard, never calls goto or moves the agent.
## Alert is a pure time-latch: once the player is seen, COMBAT holds for
## ai_profile.combat_hold seconds after the LAST successful sight check. Brief
## FOV/LOS flicker cannot drop alert to PATROL because the latch is time-based.
##
## Vision/hearing/alert TUNING lives on the host's `ai_profile` (AIProfile
## Resource) so different factions feel different without touching this script.

@export_group("Targeting")
@export_flags_3d_physics var los_mask: int = 3
@export var target_group: StringName = &"Player"

@export_group("Debug")
@export var debug_perception: bool = false

enum Alert { RELAXED = 0, SUSPICIOUS = 1, COMBAT = 2 }

# Fallback tuning used only if ai_profile is left unassigned (e.g. mid-setup).
const _DEFAULT_FOV_DEGREES: float = 110.0
const _DEFAULT_SIGHT_RANGE: float = 25.0
const _DEFAULT_EYE_HEIGHT: float = 1.6
const _DEFAULT_HEAR_K: float = 0.6
const _DEFAULT_COMBAT_HEARING_LOUDNESS: float = 30.0
const _DEFAULT_COMBAT_HOLD: float = 4.0

var _host: HostileNPC
var _bb: Blackboard
var _prev_alert: int = -1


func _ready() -> void:
	_host = get_parent() as HostileNPC
	if _host == null:
		push_error("ScavPerception must be a child of a HostileNPC.")
		set_physics_process(false)
		return

	var bt := _host.get_node_or_null("BTPlayer")
	if bt:
		_bb = bt.blackboard

	var se := get_node_or_null("/root/SoundEvents")
	if se:
		se.sound_emitted.connect(_on_sound_emitted)


func _physics_process(_delta: float) -> void:
	if _bb == null:
		var bt := _host.get_node_or_null("BTPlayer")
		if bt == null:
			return
		_bb = bt.blackboard

	# Non-hostile NPCs never escalate past RELAXED — they patrol and never
	# attack. NEUTRAL and FRIENDLY currently behave identically; that split is
	# reserved for future behavior (e.g. retaliation, following).
	if not _is_hostile():
		_bb.set_var(&"alert", Alert.RELAXED)
		_prev_alert = Alert.RELAXED
		return

	var now: float = Time.get_ticks_msec() / 1000.0

	# --- Vision ---
	var t := _find_target()
	var can_see_target: bool = t != null and _can_see(t)

	_bb.set_var(&"target_visible", can_see_target)
	if can_see_target:
		_bb.set_var(&"target", t)
		_bb.set_var(&"last_seen_time", now)
		_bb.set_var(&"last_known_pos", t.global_position)
		_bb.set_var(&"has_last_known", true)

	# --- Alert (time-latch — immune to brief LOS flicker) ---
	var last_seen: float = _bb.get_var(&"last_seen_time", -999.0)
	var has_lk: bool = _bb.get_var(&"has_last_known", false)

	var alert: int
	if (now - last_seen) <= _combat_hold():
		alert = Alert.COMBAT
	elif has_lk:
		alert = Alert.SUSPICIOUS
	else:
		alert = Alert.RELAXED
		_bb.set_var(&"target", null)
		_bb.set_var(&"has_last_known", false)
		_bb.set_var(&"combat_reacted", false)

	_bb.set_var(&"alert", alert)

	if debug_perception and alert != _prev_alert:
		var names: PackedStringArray = ["RELAXED", "SUSPICIOUS", "COMBAT"]
		print("[%s] %s  visible=%s  has_lk=%s  dt_seen=%.1fs" % [
			_host.name, names[alert], can_see_target, has_lk,
			now - last_seen if last_seen > -999.0 else INF,
		])
	_prev_alert = alert


func _find_target() -> Node3D:
	var nodes := get_tree().get_nodes_in_group(target_group)
	if nodes.is_empty():
		return null
	return nodes[0] as Node3D


func _can_see(target: Node3D) -> bool:
	var eye := global_position + Vector3.UP * _eye_height()
	var to_t := target.global_position - eye
	if to_t.length() > _sight_range():
		return false

	var forward := -_host.global_transform.basis.z
	var flat := Vector3(to_t.x, 0.0, to_t.z)
	if flat.length_squared() > 0.0001:
		if rad_to_deg(forward.angle_to(flat.normalized())) > _fov_degrees() * 0.5:
			return false

	# Multi-point LOS: head, chest, pelvis — pass target for hitbox-child check
	return _los_clear(eye, _aim_point(target, 1.6), target) \
		or _los_clear(eye, _aim_point(target, 1.0), target) \
		or _los_clear(eye, _aim_point(target, 0.4), target)


func _aim_point(target: Node3D, height: float) -> Vector3:
	if height >= 1.5:
		var h: Variant = target.get("head")
		if h is Node3D and is_instance_valid(h):
			return (h as Node3D).global_position
	return target.global_position + Vector3.UP * height


func _los_clear(from: Vector3, to: Vector3, target: Node3D) -> bool:
	var space := get_world_3d().direct_space_state
	var params := PhysicsRayQueryParameters3D.create(from, to)
	params.collision_mask = los_mask
	params.exclude = [_host.get_rid()]
	var hit := space.intersect_ray(params)
	if hit.is_empty():
		return true
	var c: Object = hit["collider"]
	# Accept the target itself, any node in target_group, or a child of the target
	# (handles HitboxComponent Area3D children that may lack the group tag).
	if c == target:
		return true
	if c is Node:
		var cn := c as Node
		if cn.is_in_group(target_group):
			return true
		if target.is_ancestor_of(cn):
			return true
	return false


func _on_sound_emitted(pos: Vector3, loudness: float, _kind: StringName, emitter: Node) -> void:
	if emitter == _host or (emitter != null and _host.is_ancestor_of(emitter)):
		return
	if _bb == null:
		return
	if not _is_hostile():
		return

	var alert: int = _bb.get_var(&"alert", Alert.RELAXED)
	if alert == Alert.COMBAT and loudness < _combat_hearing_loudness():
		return

	var hear_k: float = _hear_k()
	var dist: float = global_position.distance_to(pos)
	if dist > loudness * hear_k:
		return

	var now: float = Time.get_ticks_msec() / 1000.0
	_bb.set_var(&"heard_pos", pos)
	_bb.set_var(&"heard_time", now)
	_bb.set_var(&"has_last_known", true)

	# Vision owns last_known_pos in COMBAT; hearing updates it otherwise.
	if alert != Alert.COMBAT:
		_bb.set_var(&"last_known_pos", pos)

	if debug_perception:
		print("[%s] HEARD loudness=%.0f dist=%.1f/%.1fm" % [
			_host.name, loudness, dist, loudness * hear_k,
		])


# ── Profile-driven tuning (with fallbacks if ai_profile is unassigned) ────────

func _fov_degrees() -> float:
	return _host.ai_profile.fov_degrees if _host.ai_profile else _DEFAULT_FOV_DEGREES

func _sight_range() -> float:
	return _host.ai_profile.sight_range if _host.ai_profile else _DEFAULT_SIGHT_RANGE

func _eye_height() -> float:
	return _host.ai_profile.eye_height if _host.ai_profile else _DEFAULT_EYE_HEIGHT

func _hear_k() -> float:
	return _host.ai_profile.hear_k if _host.ai_profile else _DEFAULT_HEAR_K

func _combat_hearing_loudness() -> float:
	return _host.ai_profile.combat_hearing_loudness if _host.ai_profile else _DEFAULT_COMBAT_HEARING_LOUDNESS

func _combat_hold() -> float:
	return _host.ai_profile.combat_hold if _host.ai_profile else _DEFAULT_COMBAT_HOLD

## No profile assigned = default to hostile (matches pre-alignment behavior).
func _is_hostile() -> bool:
	return _host.ai_profile == null or _host.ai_profile.alignment == AIProfile.Alignment.HOSTILE
