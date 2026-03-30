@tool
extends Node3D

## Chạy scene trong editor (Play Scene) hoặc nhấn nút bên dưới để lưu icon.
## Sau khi lưu, đặt file PNG vào trường "icon" của .tres

@export_category("Icon Capture Settings")

## Đường dẫn và tên file muốn lưu (VD: res://Scenes/Items/Icons/item_icon.png)
@export var save_path: String = "res://icon_output.png"

## Kéo thả SubViewport vào đây. Nếu để trống, script sẽ tự tìm node con tên "SubViewport"
@export var target_viewport: SubViewport

## Nhấn vào đây để chụp ngay lập tức trong Editor
@export var capture_now: bool = false:
	set(value):
		capture_now = false # Reset thành false ngay lập tức để tạo hiệu ứng nút bấm
		if value and Engine.is_editor_hint():
			_save_icon()

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# Khi play scene thật (không phải editor), đợi 1 frame rồi lưu
	await get_tree().process_frame
	await get_tree().process_frame
	_save_icon()
	get_tree().quit()

func _save_icon() -> void:
	# Fallback an toàn nếu bạn quên gán target_viewport trong Inspector
	if target_viewport == null:
		target_viewport = get_node_or_null("SubViewport")
		if target_viewport == null:
			push_error("Không tìm thấy SubViewport. Vui lòng gán target_viewport trong Inspector.")
			return

	# Đợi viewport render xong
	await RenderingServer.frame_post_draw
	
	var img: Image = target_viewport.get_texture().get_image()
	if img == null or img.is_empty():
		push_error("Viewport texture rỗng — kiểm tra Camera3D bên trong SubViewport")
		return
		
	# Đảm bảo đuôi file luôn là .png
	if not save_path.ends_with(".png"):
		save_path += ".png"

	var err := img.save_png(ProjectSettings.globalize_path(save_path))
	if err == OK:
		print("Icon đã lưu thành công tại: ", save_path)
	else:
		push_error("Lỗi khi lưu hình ảnh: " + str(err))
