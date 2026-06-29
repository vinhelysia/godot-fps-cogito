extends Node3D
class_name ScavPerception

## Perception sensor for Scav enemy. Gathers vision and hearing data,
## accumulates awareness, and writes directly to the LimboAI Blackboard.

@export_group("Vision")
## Max distance the NPC can see (metres).
@export var sight_range: float = 25.0
## Total horizontal field-of-view cone (degrees).
@export_range(10.0, 360.0, 1.0, "suffix:°") var fov_degrees: float = 120.0
## Eye height above the NPC origin — ray origin for LOS.
@export var eye_height: float = 1.6
## Seconds the target must stay visible at close range before being fully spotted.
@export var time_to_notice: float = 1.5
## Rate at which awareness decays when the player is not seen.
@export var awareness_decay_speed: float = 0.15
## Group name of things this NPC hunts.
@export var target_group: StringName = &"Player"

@export_group("Line of Sight")
## Physics layers LOS rays test against (world + target).
@export_flags_3d_physics var los_mask: int = 3

@export_group("Hearing")
## Max distance the NPC can hear sounds (metres).
@export var hearing_range: float = 30.0

enum AlertState { CALM = 0, SUSPICIOUS = 1, ALERT = 2, COMBAT = 3 }

var _host: CogitoNPC
var _bt_player: Node
var _target: Node3D = null

# Local awareness accumulator (0.0 to 1.0)
var _awareness: float = 0.0

func _ready() -> void:
	_host = get_parent() as CogitoNPC
	if _host == null:
		push_error("ScavPerception must be a child of a CogitoNPC.")
		set_physics_process(false)
		return
	
	_bt_player = _host.get_node_or_null("BTPlayer")
	
	# Connect to the SoundEvents autoload
	var sound_events = get_node_or_null("/root/SoundEvents")
	if sound_events:
		sound_events.sound_emitted.connect(_on_sound_emitted)


func _physics_process(delta: float) -> void:
	if _bt_player == null:
		# Try to find BTPlayer if it wasn't ready yet
		_bt_player = _host.get_node_or_null("BTPlayer")
		if _bt_player == null:
			return

	var target := _find_target()
	var can_see := target != null and _can_see(target)

	if can_see:
		_target = target
		
		# Calculate awareness gain rate based on distance and player pose
		var dist = global_position.distance_to(target.global_position)
		var distance_factor = clamp(1.0 - (dist / sight_range), 0.1, 1.0)
		
		var pose_factor = 1.0
		if target.is_in_group("Player"):
			if target.get("is_sprinting") == true:
				pose_factor = 1.5
			elif target.get("is_crouching") == true:
				pose_factor = 0.5
		
		var gain = (1.0 / time_to_notice) * distance_factor * pose_factor
		_awareness = clamp(_awareness + gain * delta, 0.0, 1.0)
		
		# Update blackboard target and positions
		_bt_player.blackboard.set_var(&"target", target)
		_bt_player.blackboard.set_var(&"last_known_position", target.global_position)
		_bt_player.blackboard.set_var(&"has_last_known", true)
	else:
		# Decay awareness
		_awareness = clamp(_awareness - awareness_decay_speed * delta, 0.0, 1.0)
		if _awareness <= 0.0:
			_bt_player.blackboard.set_var(&"target", null)

	# Map awareness to alert state
	var alert = AlertState.CALM
	if _awareness == 1.0:
		alert = AlertState.COMBAT
	elif _awareness >= 0.5:
		alert = AlertState.ALERT
	elif _awareness > 0.0:
		alert = AlertState.SUSPICIOUS

	# Write to blackboard
	_bt_player.blackboard.set_var(&"awareness", _awareness)
	_bt_player.blackboard.set_var(&"alert_state", int(alert))


func _find_target() -> Node3D:
	var nodes := get_tree().get_nodes_in_group(target_group)
	if nodes.is_empty():
		return null
	return nodes[0] as Node3D


func _can_see(target: Node3D) -> bool:
	var eye := global_position + Vector3.UP * eye_height
	var to_target := target.global_position - eye
	if to_target.length() > sight_range:
		return false

	# FOV cone — measured horizontally against NPC forward (-Z).
	var forward := -_host.global_transform.basis.z
	var flat_to := Vector3(to_target.x, 0.0, to_target.z)
	if flat_to.length() > 0.01:
		var angle := rad_to_deg(forward.angle_to(flat_to.normalized()))
		if angle > fov_degrees * 0.5:
			return false

	# Multi-point LOS — head, chest, pelvis
	return _los_clear(eye, _aim_point(target, 1.6)) or \
		   _los_clear(eye, _aim_point(target, 1.0)) or \
		   _los_clear(eye, _aim_point(target, 0.4))


func _aim_point(target: Node3D, height: float) -> Vector3:
	if height >= 1.5:
		var head_val: Variant = target.get("head")
		if head_val is Node3D and is_instance_valid(head_val):
			return (head_val as Node3D).global_position
	return target.global_position + Vector3.UP * height


func _los_clear(from: Vector3, to: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var params := PhysicsRayQueryParameters3D.create(from, to)
	params.collision_mask = los_mask
	params.exclude = [_host.get_rid()]
	var hit := space.intersect_ray(params)
	if hit.is_empty():
		return true
	var collider: Object = hit["collider"]
	return collider == _target or (collider is Node and (collider as Node).is_in_group(target_group))


func _on_sound_emitted(pos: Vector3, loudness: float, _kind: StringName, emitter: Node) -> void:
	# Self-hearing prevention: ignore if emitter is the host or a child of the host
	if emitter == _host or (emitter != null and _host.is_ancestor_of(emitter)):
		return

	if _bt_player == null:
		return

	var dist = global_position.distance_to(pos)
	# Sound propagation: check if within hearing radius (loudness scales hearing range)
	var effective_hearing_range = hearing_range * (loudness / 15.0)
	if dist <= effective_hearing_range:
		# Record heard position
		_bt_player.blackboard.set_var(&"heard_position", pos)
		_bt_player.blackboard.set_var(&"last_known_position", pos)
		_bt_player.blackboard.set_var(&"has_last_known", true)
		
		# Bump awareness to at least ALERT (0.5) to trigger investigation
		if _awareness < 0.5:
			_awareness = 0.5
			_bt_player.blackboard.set_var(&"awareness", _awareness)
			_bt_player.blackboard.set_var(&"alert_state", int(AlertState.ALERT))
