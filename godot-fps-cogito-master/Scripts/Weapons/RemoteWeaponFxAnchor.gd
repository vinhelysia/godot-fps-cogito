extends Node3D
class_name RemoteWeaponFxAnchor

## Handles remote firing effects (muzzle flash, audio, shell casings) on TPP weapon instances.
## Add as a child node named "RemoteWeaponFxAnchor" inside each weapon drop scene used as
## tpp_weapon_scene.  Socket exports are auto-wired from sibling Marker3Ds in _ready() if
## left null — just name them "Bullet_Point" and "shell_eject_point" in the drop scene.

@export_group("Sockets")
## Marker3D at the muzzle tip. Auto-wired from sibling named "Bullet_Point" if null.
@export var muzzle_socket: Marker3D
## Marker3D at the shell ejection port. Auto-wired from "shell_eject_point" if null.
## Leave null (no sibling) for weapons that don't eject shells.
@export var shell_socket: Marker3D

@export_group("Visual FX")
## Scene to spawn at the muzzle on each shot. Typically muzzle_flash_proxy.tscn.
@export var muzzle_flash_scene: PackedScene
@export var muzzle_flash_scale: float = 1.0

@export_group("Audio")
@export var shot_sound: AudioStream
@export var shot_volume_db: float = 0.0

@export_group("Shell Casing")
@export var shell_casing_scene: PackedScene
## Seconds to wait before spawning shell (use bolt_eject_delay for bolt-action).
@export var shell_eject_delay: float = 0.0
@export var max_shell_casings: int = 10

var _audio_player: AudioStreamPlayer3D


func _ready() -> void:
	# Auto-wire sockets from sibling Marker3Ds if not assigned via Inspector.
	var parent := get_parent()
	if parent:
		if muzzle_socket == null:
			muzzle_socket = parent.find_child("Bullet_Point", true, false) as Marker3D
		if shell_socket == null:
			shell_socket = parent.find_child("shell_eject_point", true, false) as Marker3D

	_audio_player = AudioStreamPlayer3D.new()
	_audio_player.max_distance = 40.0
	_audio_player.unit_size = 2.0
	_audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	add_child(_audio_player)


## Called via rpc_play_remote_fire_fx() on the CogitoPlayer when authority fires.
func play_remote_fire_fx() -> void:
	_spawn_muzzle_flash()
	_play_shot_audio()
	if shell_socket != null:
		if shell_eject_delay > 0.0:
			get_tree().create_timer(shell_eject_delay, false).timeout.connect(_spawn_shell_casing)
		else:
			_spawn_shell_casing()


func _spawn_muzzle_flash() -> void:
	if muzzle_flash_scene == null or muzzle_socket == null:
		return
	var flash := muzzle_flash_scene.instantiate() as Node3D
	if flash == null:
		return
	# Spawn in world (current_scene), same as shell casing.  The TPP weapon subtree
	# may be hidden or on a non-rendering layer, so children of it won't be visible.
	# Snapshot the muzzle transform at the moment of fire — 0.12 s lifetime means
	# the player can't rotate far enough for the flash to look detached.
	get_tree().current_scene.add_child(flash)
	flash.global_transform = muzzle_socket.global_transform
	flash.scale = Vector3.ONE * muzzle_flash_scale
	var flash_ref: WeakRef = weakref(flash)
	get_tree().create_timer(0.12, false).timeout.connect(func():
		var f: Object = flash_ref.get_ref()
		if f != null:
			f.call("queue_free")
	)


func _play_shot_audio() -> void:
	if shot_sound == null or muzzle_socket == null:
		return
	# Spawn a fresh AudioStreamPlayer3D in current_scene at the muzzle's world position.
	# Same pattern as the flash — works regardless of whether the TPP weapon subtree is
	# visible or on a special layer.  Auto-frees when the stream finishes.
	var sfx := AudioStreamPlayer3D.new()
	sfx.stream = shot_sound
	sfx.volume_db = shot_volume_db
	sfx.max_distance = 50.0
	sfx.unit_size = 4.0
	sfx.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	get_tree().current_scene.add_child(sfx)
	sfx.global_position = muzzle_socket.global_position
	sfx.play()
	sfx.finished.connect(sfx.queue_free)


func _spawn_shell_casing() -> void:
	if shell_casing_scene == null or shell_socket == null:
		return
	# Respect global shell casing limit.
	var active := get_tree().get_nodes_in_group("shell_casings")
	if active.size() > max_shell_casings:
		active[0].queue_free()
	var shell := shell_casing_scene.instantiate()
	get_tree().current_scene.add_child(shell)
	shell.global_transform = shell_socket.global_transform
