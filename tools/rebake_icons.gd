extends SceneTree
## Nướng lại toàn bộ ảnh đồ (assets/mu/icons) theo ICON_VERSION hiện tại

const ItemIcon = preload("res://src/ui/MuItemIcon.gd")

func _init() -> void:
	await process_frame
	var n: int = await ItemIcon.bake_all(self)
	print("BAKED ", n)
	quit()
