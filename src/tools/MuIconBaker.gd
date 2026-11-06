extends Control

## Nướng ảnh TẤT CẢ đồ ra assets/mu/icons/GG_NNN.png. Mở scene này rồi bấm F6 (Run Current Scene).

const IconRes = preload("res://src/ui/MuItemIcon.gd")
var _label: Label

func _ready() -> void:
	_label = Label.new()
	_label.position = Vector2(20, 20)
	_label.add_theme_font_size_override("font_size", 22)
	add_child(_label)
	_label.text = "Đang nướng ảnh đồ..."
	await get_tree().process_frame
	var n: int = await IconRes.bake_all(get_tree(), _progress)
	_label.text = "Xong! Đã lưu %d ảnh vào assets/mu/icons.\nĐóng cửa sổ này, quay lại Godot (đợi nó import ảnh)." % n
	print("[MuIconBaker] đã lưu %d ảnh" % n)

func _progress(done: int, total: int) -> void:
	_label.text = "Đang nướng ảnh đồ... %d / %d" % [done, total]
