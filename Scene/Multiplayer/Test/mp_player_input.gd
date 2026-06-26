extends MultiplayerSynchronizer

# Synced input state (client authority → server reads).
# These are set via @export so MultiplayerSynchronizer replicates them.
@export var direction: Vector2 = Vector2.ZERO
@export var look_yaw: float = 0.0
@export var look_pitch: float = 0.0

# Edge-triggered flags. Server reads, acts, resets.
var jumping: bool = false
var firing: bool = false


func _ready() -> void:
	# Capture mouse only for the local player (authority peer).
	if is_multiplayer_authority():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _process(_delta: float) -> void:
	if not is_multiplayer_authority():
		return
	direction = Input.get_vector("left", "right", "forward", "back")
	if Input.is_action_just_pressed("jump"):
		jump.rpc()
	if Input.is_action_just_pressed("mp_test_fire"):
		fire.rpc()


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return

	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		look_yaw -= mm.relative.x * 0.002
		look_pitch -= mm.relative.y * 0.002
		look_pitch = clamp(look_pitch, -PI / 2.0 + 0.01, PI / 2.0 - 0.01)

	if event.is_action_pressed("ui_cancel"):
		var mode: int = Input.get_mouse_mode()
		if mode == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


# Edge-triggered actions via RPC — "call_local" so the client predicts too.
@rpc("call_local", "reliable")
func jump() -> void:
	jumping = true


@rpc("call_local", "reliable")
func fire() -> void:
	firing = true
