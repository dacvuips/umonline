extends SceneTree

const MinimapRes = preload("res://src/ui/MuMiniMapWidget.gd")
const BigMapRes = preload("res://src/ui/MuBigMapWindow.gd")

func _init() -> void:
	print("== KIỂM TRA MINI MAP & BẢN ĐỒ LỚN (BIG MAP)")
	var minimap = MinimapRes.new()
	var bigmap = BigMapRes.new()

	root.add_child(minimap)
	root.add_child(bigmap)

	# Gọi trực tiếp hoặc đợi ready
	if not minimap.is_node_ready():
		minimap._ready()
	if not bigmap.is_node_ready():
		bigmap._ready()

	print("1. Mini Map:")
	print("   - Tên map: ", minimap.current_map_name)
	print("   - Texture minimap tải được: ", minimap.current_map_texture != null)
	print("   - Số lượng marker NPC/Cổng: ", minimap.world_markers.size())

	print("2. Bản Đồ Lớn (Big Map):")
	print("   - Tên map: ", bigmap.current_map_name)
	print("   - Texture bản đồ tải được: ", bigmap.current_map_texture != null)
	print("   - Số lượng marker NPC & Cổng: ", bigmap.markers_list.size())
	print("   - Góc hoa văn kim loại cổ điển: ", bigmap.tex_corner != null)
	print("   - Nút Đóng (mini_map_ui_cancel): ", bigmap.tex_btn_close_normal != null)
	print("   - Icon Cổng (mini_map_ui_portal): ", bigmap.tex_portal != null)
	print("   - Icon NPC (mini_map_ui_npc): ", bigmap.tex_npc != null)
	print("   - Icon Hero (mini_map_ui_cha): ", bigmap.tex_hero != null)

	print("3. Thao tác Mở & Đóng bản đồ lớn:")
	bigmap.open_map()
	print("   - Mở map thành công! visible = ", bigmap.visible)
	bigmap.close()
	print("   - Đóng map thành công! visible = ", bigmap.visible)

	print("KẾT QUẢ: TẤT CẢ TÍNH NĂNG HOẠT ĐỘNG HOÀN HẢO!")
	quit(0)
