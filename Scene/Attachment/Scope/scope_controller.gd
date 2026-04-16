## scope_controller.gd
## Script điều khiển scope: magnification, reticle type, shader params.
##
## Cách dùng:
##   - Attach script này vào root node "Tac3014x24Riflescope" (Node3D)
##   - Chỉnh magnification, reticle_type và các param từ Inspector
##   - Gọi set_magnification() từ script khác để zoom programmatically
##
## ReticleType.PROCEDURAL:
##   Reticle được vẽ trực tiếp bằng GDShader trên QuadMesh lens.
##   Chỉnh các param nhóm "Procedural Reticle" từ Inspector.
##
## ReticleType.SUBVIEWPORT_2D:
##   Reticle dùng CanvasLayer bên trong Scope SubViewport.
##   Gán một PackedScene 2D vào reticle_2d_scene.
##   Background trong suốt, 2D nodes vẽ đè lên ảnh camera 3D.
##   Procedural reticle của shader sẽ bị ẩn tự động.

@tool
class_name ScopeController
extends Node3D

# ---------------------------------------------------------------------------
# Enums
# ---------------------------------------------------------------------------

enum ReticleType {
	PROCEDURAL,       ## Shader vẽ reticle (mặc định, không cần scene phụ)
	SUBVIEWPORT_2D,   ## CanvasLayer 2D bên trong Scope SubViewport
}

# ---------------------------------------------------------------------------
# Exports — Magnification
# ---------------------------------------------------------------------------

@export_group("Magnification")

## Độ phóng đại hiện tại (đơn vị: x). VD: 4.0 = 4x, 5.5 = 5.5x
## Giá trị này điều khiển trực tiếp FOV của Camera3D trong Scope SubViewport.
@export_range(1.0, 32.0, 0.5, "suffix:x") var magnification: float = 4.0:
	set(value):
		magnification = clampf(value, 1.0, 32.0)
		_apply_magnification()

## FOV (field of view) tương ứng với 1x (không phóng đại).
## Mặc định 60°. Thay đổi nếu player camera dùng FOV khác.
@export_range(30.0, 120.0, 1.0, "suffix:°") var base_fov_at_1x: float = 60.0:
	set(value):
		base_fov_at_1x = value
		_apply_magnification()

# ---------------------------------------------------------------------------
# Exports — Reticle Type
# ---------------------------------------------------------------------------

@export_group("Reticle")

## Chọn loại reticle: shader procedural hoặc CanvasLayer 2D
@export var reticle_type: ReticleType = ReticleType.PROCEDURAL:
	set(value):
		reticle_type = value
		_apply_reticle_type()

## [Chỉ dùng khi reticle_type = SUBVIEWPORT_2D]
## Gán PackedScene chứa các 2D node vẽ reticle (Node2D root, transparent bg)
@export var reticle_2d_scene: PackedScene:
	set(value):
		reticle_2d_scene = value
		if reticle_type == ReticleType.SUBVIEWPORT_2D:
			_rebuild_reticle_layer()

# ---------------------------------------------------------------------------
# Exports — Procedural Reticle (ánh xạ 1:1 lên shader params)
# ---------------------------------------------------------------------------

@export_group("Procedural Reticle / Color")

@export var reticle_color: Color = Color(0.89, 0.15, 0.21, 1.0):
	set(v): reticle_color = v; _set_shader("reticle_color", v)

@export_range(0.0, 1.0, 0.01) var reticle_opacity: float = 1.0:
	set(v): reticle_opacity = v
	# Opacity chỉ apply lên shader khi đang dùng PROCEDURAL
	# SUBVIEWPORT_2D sẽ tự force về 0 trong _apply_reticle_type()
	; _set_shader("reticle_opacity", v if reticle_type == ReticleType.PROCEDURAL else 0.0)

@export_range(0.0, 0.01, 0.0001) var reticle_aa: float = 0.003:
	set(v): reticle_aa = v; _set_shader("reticle_aa", v)

@export_group("Procedural Reticle / Crosshair")

@export_range(0.0, 0.25, 0.001) var cross_length: float = 0.085:
	set(v): cross_length = v; _set_shader("cross_length", v)

@export_range(0.001, 0.02, 0.0005) var cross_thickness: float = 0.004:
	set(v): cross_thickness = v; _set_shader("cross_thickness", v)

@export_range(0.0, 0.1, 0.001) var cross_gap: float = 0.025:
	set(v): cross_gap = v; _set_shader("cross_gap", v)

@export_range(0.0, 0.02, 0.0005) var center_dot_radius: float = 0.007:
	set(v): center_dot_radius = v; _set_shader("center_dot_radius", v)

@export_group("Procedural Reticle / Ring")

@export_range(0.0, 0.5, 0.001) var ring_radius: float = 0.18:
	set(v): ring_radius = v; _set_shader("ring_radius", v)

@export_range(0.0, 0.1, 0.001) var ring_thickness: float = 0.025:
	set(v): ring_thickness = v; _set_shader("ring_thickness", v)

@export_range(0.0, 0.01, 0.0005) var ring_dot_radius: float = 0.005:
	set(v): ring_dot_radius = v; _set_shader("ring_dot_radius", v)

@export_group("Procedural Reticle / BDC Stadia")

@export_range(0, 10) var bdc_dot_count: int = 3:
	set(v): bdc_dot_count = v; _set_shader("bdc_dot_count", v)

@export_range(0.0, 0.02, 0.0005) var bdc_dot_radius: float = 0.006:
	set(v): bdc_dot_radius = v; _set_shader("bdc_dot_radius", v)

@export_range(0.0, 0.1, 0.001) var bdc_dot_spacing: float = 0.025:
	set(v): bdc_dot_spacing = v; _set_shader("bdc_dot_spacing", v)

@export_range(0.0, 0.15, 0.001) var bdc_dot_start: float = 0.04:
	set(v): bdc_dot_start = v; _set_shader("bdc_dot_start", v)

@export_range(0.0, 0.05, 0.0005) var stadia_length: float = 0.015:
	set(v): stadia_length = v; _set_shader("stadia_length", v)

@export_range(0.001, 0.01, 0.0005) var stadia_thickness: float = 0.003:
	set(v): stadia_thickness = v; _set_shader("stadia_thickness", v)

# ---------------------------------------------------------------------------
# Exports — Optics
# ---------------------------------------------------------------------------

@export_group("Optics")

@export_range(0.0, 0.2, 0.001) var barrel_distortion: float = 0.04:
	set(v): barrel_distortion = v; _set_shader("barrel_distortion", v)

@export_range(0.0, 0.05, 0.001) var chromatic_aberration: float = 0.0:
	set(v): chromatic_aberration = v; _set_shader("chromatic_aberration", v)

@export_range(0.5, 1.5, 0.01) var scope_contrast: float = 0.98:
	set(v): scope_contrast = v; _set_shader("scope_contrast", v)

@export_range(0.1, 2.0, 0.01) var scope_exposure: float = 0.7:
	set(v): scope_exposure = v; _set_shader("scope_exposure", v)

@export_range(0.5, 2.0, 0.01) var scope_gamma: float = 1.1:
	set(v): scope_gamma = v; _set_shader("scope_gamma", v)

@export_range(0.0, 2.0, 0.01) var scope_saturation: float = 1.0:
	set(v): scope_saturation = v; _set_shader("scope_saturation", v)

@export_range(0.0, 0.5, 0.001) var scope_radius: float = 0.048:
	set(v): scope_radius = v; _set_shader("scope_radius", v)

@export_range(0.0, 1.0, 0.01) var vignette_strength: float = 0.0:
	set(v): vignette_strength = v; _set_shader("vignette_strength", v)

@export_group("Optics / Eyebox")

@export_range(0.0, 1.0, 0.01) var eyebox_position: float = 0.2:
	set(v): eyebox_position = v; _set_shader("eyebox_position", v)

@export_range(0.0, 0.05, 0.001) var eyebox_fade_distance: float = 0.05:
	set(v): eyebox_fade_distance = v; _set_shader("eyebox_fade_distance", v)

@export_range(0.0, 0.02, 0.0005) var eyebox_tolerance: float = 0.005:
	set(v): eyebox_tolerance = v; _set_shader("eyebox_tolerance", v)

@export_range(0.0, 1.0, 0.01) var shadow_inner_radius: float = 0.8:
	set(v): shadow_inner_radius = v; _set_shader("shadow_inner_radius", v)

@export_range(0.0, 1.0, 0.01) var shadow_fade_factor: float = 0.3:
	set(v): shadow_fade_factor = v; _set_shader("shadow_fade_factor", v)

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

@onready var _scope_vp: SubViewport = $Scope
@onready var _scope_cam: Camera3D = $Scope/Camera3D
@onready var _lens_mesh: MeshInstance3D = $MeshInstance3D

var _shader_mat: ShaderMaterial = null
var _reticle_layer: CanvasLayer = null  # Chỉ tồn tại khi dùng SUBVIEWPORT_2D

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_shader_mat = _lens_mesh.material_override as ShaderMaterial
	if _shader_mat == null:
		push_error("ScopeController: MeshInstance3D không có ShaderMaterial override!")
		return
	_apply_magnification()
	_apply_reticle_type()

# ---------------------------------------------------------------------------
# Public API — gọi từ script khác (ví dụ: player input handler)
# ---------------------------------------------------------------------------

## Đặt magnification mới. Giá trị sẽ bị clamp trong khoảng [1, 32].
## Ví dụ: scope.set_magnification(5.5)
func set_magnification(value: float) -> void:
	magnification = value  # setter tự gọi _apply_magnification()

## Trả về FOV thực tế đang dùng trên scope camera.
func get_scope_fov() -> float:
	if _scope_cam:
		return _scope_cam.fov
	return base_fov_at_1x / magnification

## Chuyển đổi reticle type. Ví dụ: scope.switch_reticle(ScopeController.ReticleType.SUBVIEWPORT_2D)
func switch_reticle(type: ReticleType) -> void:
	reticle_type = type  # setter tự gọi _apply_reticle_type()

# ---------------------------------------------------------------------------
# Private — Magnification
# ---------------------------------------------------------------------------

func _apply_magnification() -> void:
	if not is_node_ready():
		return
	# FOV giảm khi magnification tăng: fov = base / mag
	# 1x → 60°, 4x → 15°, 5.5x → ~10.9°
	_scope_cam.fov = base_fov_at_1x / magnification

# ---------------------------------------------------------------------------
# Private — Reticle
# ---------------------------------------------------------------------------

func _apply_reticle_type() -> void:
	if not is_node_ready():
		return
	match reticle_type:
		ReticleType.PROCEDURAL:
			# Hiện procedural reticle trong shader
			_set_shader("reticle_opacity", reticle_opacity)
			# Xóa CanvasLayer 2D nếu đang tồn tại
			_remove_reticle_layer()
		ReticleType.SUBVIEWPORT_2D:
			# Ẩn procedural reticle trong shader (opacity = 0)
			_set_shader("reticle_opacity", 0.0)
			# Tạo CanvasLayer bên trong Scope SubViewport
			_setup_reticle_layer()

func _setup_reticle_layer() -> void:
	# Nếu đã tồn tại rồi thì không tạo lại
	if is_instance_valid(_reticle_layer):
		return
	_reticle_layer = CanvasLayer.new()
	_reticle_layer.name = "ReticleLayer"
	# Layer 10 để đảm bảo vẽ trên ảnh 3D của camera
	_reticle_layer.layer = 10
	_scope_vp.add_child(_reticle_layer)
	_load_reticle_scene()

func _load_reticle_scene() -> void:
	if not is_instance_valid(_reticle_layer):
		return
	# Xóa instance cũ nếu có
	for child in _reticle_layer.get_children():
		child.queue_free()
	if reticle_2d_scene == null:
		push_warning("ScopeController: reticle_2d_scene chưa được gán!")
		return
	var instance: Node = reticle_2d_scene.instantiate()
	_reticle_layer.add_child(instance)

func _rebuild_reticle_layer() -> void:
	_remove_reticle_layer()
	_setup_reticle_layer()

func _remove_reticle_layer() -> void:
	if is_instance_valid(_reticle_layer):
		_reticle_layer.queue_free()
		_reticle_layer = null

# ---------------------------------------------------------------------------
# Private — Shader helper
# ---------------------------------------------------------------------------

func _set_shader(param: String, value: Variant) -> void:
	if _shader_mat == null:
		return
	_shader_mat.set_shader_parameter(param, value)
