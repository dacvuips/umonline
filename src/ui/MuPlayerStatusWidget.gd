extends Control
class_name MuPlayerStatusWidget

## Thanh Thông Tin Nhân Vật & Trạng Thái Góc Trên Bên Trái (MU Online / Mobile Origin Style)
## Thiết kế tinh chỉnh theo yêu cầu:
## - Số chỉ số (HP/MP/AG) to, đậm, rõ nét chính giữa thanh
## - Bỏ hoàn toàn huy hiệu VIP 1
## - Viền vàng (Gold border) mảnh tinh tế (1px)
## - Tên nhân vật đặt sau danh hiệu lớp nhân vật (Ví dụ: [Chiến Binh] Hero)
## - Avatar hỗ trợ tải ảnh thật trực tiếp từ máy tính (PNG, JPG, WEBP) hoặc nhận ảnh người chơi
## - Hiển thị khung thông tin & máu của Thú cưỡi / Thú cưng góc trái màn hình (dưới thanh máu)

const MuItemsRes = preload("res://src/mu/MuItems.gd")

@export var player: MuPlayer = null

# Node references
var avatar_rect: TextureRect
var lbl_name: Label
var lbl_class: Label
var lbl_level: Label
var status_gem: Panel

var hp_bar: ProgressBar
var mp_bar: ProgressBar
var ag_bar: ProgressBar
var sd_bar: ProgressBar
var exp_bar: ProgressBar

var lbl_hp: Label
var lbl_mp: Label
var lbl_ag: Label
var lbl_sd: Label
var lbl_exp: Label

var lbl_pin_fps: Label

# Nút GM duy nhất mở bảng lấy đồ (Item Picker Window)
var btn_gm: Button = null

# Khung thú cưng / thú cưỡi góc trái màn hình (dưới thanh máu)
var pet_box_list: Array[Dictionary] = []
var _pet_check_timer: float = 0.0

var file_dialog: FileDialog = null
var loaded_textures: Dictionary = {}

func _ready() -> void:
	custom_minimum_size = Vector2(560, 146)
	size = Vector2(560, 146)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preload_textures()
	_build_ui()
	if player:
		setup(player)

func _preload_textures() -> void:
	var paths = [
		"res://assets/textures/ui/mobile_origin/avatar_knight.png",
		"res://assets/textures/ui/mobile_origin/menu_char.png",
		"res://assets/textures/ui/mobile_origin/btn_battery.png",
		"res://assets/textures/ui/mobile_origin/btn_chest.png",
		"res://assets/textures/ui/mobile_origin/btn_calendar.png",
		"res://assets/textures/ui/mobile_origin/helper_panel.png",
		"res://assets/textures/ui/newui_Pet_Back.png",
		"res://assets/textures/ui/newui_Pet_HpBar.png",
		"res://assets/mu/Player/tex/darknight_face.jpg"
	]
	for p in paths:
		if ResourceLoader.exists(p):
			loaded_textures[p] = load(p)

func _get_texture(path: String) -> Texture2D:
	if loaded_textures.has(path):
		return loaded_textures[path]
	if ResourceLoader.exists(path):
		var tex = load(path)
		if tex:
			loaded_textures[path] = tex
			return tex
	if FileAccess.file_exists(path):
		var img = Image.load_from_file(ProjectSettings.globalize_path(path))
		if img:
			var itex = ImageTexture.create_from_image(img)
			loaded_textures[path] = itex
			return itex
	return null

func _get_user_avatar() -> Texture2D:
	# 1. Kiểm tra ảnh thật của người chơi đã tải lên
	var custom_paths = [
		"user://player_avatar.png",
		"res://assets/textures/ui/custom_avatar.png"
	]
	for cp in custom_paths:
		var glob = ProjectSettings.globalize_path(cp)
		if FileAccess.file_exists(glob) or FileAccess.file_exists(cp):
			var actual_path = glob if FileAccess.file_exists(glob) else cp
			var img = Image.load_from_file(actual_path)
			if img:
				var tex = ImageTexture.create_from_image(img)
				return tex
	# 2. Fallback sang avatar mặc định
	var tex_avatar = _get_texture("res://assets/textures/ui/mobile_origin/avatar_knight.png")
	if not tex_avatar:
		tex_avatar = _get_texture("res://assets/mu/Player/tex/darknight_face.jpg")
	return tex_avatar

func setup(p_player: MuPlayer) -> void:
	player = p_player
	if not player:
		return
	if not player.hp_changed.is_connected(_on_hp_changed):
		player.hp_changed.connect(_on_hp_changed)
	if not player.mana_changed.is_connected(_on_mp_changed):
		player.mana_changed.connect(_on_mp_changed)
	if player.has_signal("ag_changed") and not player.ag_changed.is_connected(_on_ag_changed):
		player.ag_changed.connect(_on_ag_changed)
	if player.has_signal("sd_changed") and not player.sd_changed.is_connected(_on_sd_changed):
		player.sd_changed.connect(_on_sd_changed)
	if player.has_signal("exp_changed") and not player.exp_changed.is_connected(_on_exp_changed):
		player.exp_changed.connect(_on_exp_changed)
	if player.has_signal("inventory_changed") and not player.inventory_changed.is_connected(_on_inventory_changed):
		player.inventory_changed.connect(_on_inventory_changed)
	update_all()

func update_all() -> void:
	if not player:
		return
	_update_player_info()
	_on_hp_changed(player.current_hp, player.max_hp)
	_on_mp_changed(player.current_mp, player.max_mp)
	_update_ag(player.get("current_ag") if "current_ag" in player else 56, player.get("max_ag") if "max_ag" in player else 56)
	_update_sd(player.get("current_sd") if "current_sd" in player else 100, player.get("max_sd") if "max_sd" in player else 100)
	_on_exp_changed(player.current_exp, player.max_exp, player.level)
	if lbl_level:
		var r_txt = " (R%d)" % player.resets if player.resets > 0 else ""
		lbl_level.text = "Lv.%d%s" % [player.level, r_txt]
	_update_pet_widget()
	_update_gm_button_visibility()

func _update_player_info() -> void:
	if not player:
		return
	if lbl_class:
		var cls_name = player.get_class_display_name() if player.has_method("get_class_display_name") else ""
		if not cls_name.is_empty():
			lbl_class.text = "[%s]" % cls_name
		else:
			var class_names = [
				"Phù Thủy",    # 0 Dark Wizard
				"Chiến Binh",  # 1 Dark Knight
				"Tiên Nữ",     # 2 Fairy Elf
				"Đấu Sĩ",      # 3 Magic Gladiator
				"Chúa Tể",     # 4 Dark Lord
				"Thuật Sĩ",    # 5 Summoner
				"Thiết Binh"   # 6 Rage Fighter
			]
			var c_idx = player.char_class if "char_class" in player else 1
			if c_idx >= 0 and c_idx < class_names.size():
				lbl_class.text = "[%s]" % class_names[c_idx]
	if lbl_name:
		lbl_name.text = player.character_name if player.character_name != "" else "Hero"

func _on_exp_changed(cur_exp: int, max_exp: int, p_level: int) -> void:
	if lbl_level:
		var r_txt = " (R%d)" % player.resets if player and player.resets > 0 else ""
		lbl_level.text = "Lv.%d%s" % [p_level, r_txt]
	if exp_bar:
		exp_bar.max_value = max(1, max_exp)
		exp_bar.value = cur_exp
	if lbl_exp:
		var pct = (float(cur_exp) / float(max(1, max_exp))) * 100.0
		lbl_exp.text = "%d / %d (%.1f%%)" % [cur_exp, max_exp, pct]

func _on_hp_changed(cur: int, max_val: int) -> void:
	if hp_bar:
		hp_bar.max_value = max(1, max_val)
		hp_bar.value = cur
	if lbl_hp:
		lbl_hp.text = "%d / %d" % [cur, max_val]

func _on_mp_changed(cur: int, max_val: int) -> void:
	if mp_bar:
		mp_bar.max_value = max(1, max_val)
		mp_bar.value = cur
	if lbl_mp:
		lbl_mp.text = "%d / %d" % [cur, max_val]

func _on_ag_changed(cur: int, max_val: int) -> void:
	_update_ag(cur, max_val)

func _update_ag(cur: int, max_val: int) -> void:
	if ag_bar:
		ag_bar.max_value = max(1, max_val)
		ag_bar.value = cur
	if lbl_ag:
		lbl_ag.text = "%d / %d" % [cur, max_val]

func _on_sd_changed(cur: int, max_val: int) -> void:
	_update_sd(cur, max_val)

func _update_sd(cur: int, max_val: int) -> void:
	if sd_bar:
		sd_bar.max_value = max(1, max_val)
		sd_bar.value = cur
	if lbl_sd:
		lbl_sd.text = "%d / %d" % [cur, max_val]

func _build_ui() -> void:
	# =========================================================================
	# 1. KHUNG NỀN CHÍNH (Unit Frame Backplate) - Viền vàng thanh mảnh 1px
	# =========================================================================
	var backplate = Panel.new()
	backplate.name = "UnitFrameBackplate"
	backplate.position = Vector2(0, 0)
	backplate.size = Vector2(348, 88)
	
	var sb_plate = StyleBoxFlat.new()
	sb_plate.bg_color = Color(0.04, 0.06, 0.10, 0.35) # Bán trong suốt, thấy rõ cảnh nền game 3D
	sb_plate.border_width_left = 1
	sb_plate.border_width_top = 1
	sb_plate.border_width_right = 1
	sb_plate.border_width_bottom = 1
	sb_plate.border_color = Color(0.72, 0.58, 0.28, 0.75) # Viền vàng mảnh tinh tế
	sb_plate.corner_radius_top_left = 6
	sb_plate.corner_radius_top_right = 12
	sb_plate.corner_radius_bottom_left = 6
	sb_plate.corner_radius_bottom_right = 12
	sb_plate.shadow_color = Color(0, 0, 0, 0.25)
	sb_plate.shadow_size = 3
	sb_plate.shadow_offset = Vector2(0, 1)
	backplate.add_theme_stylebox_override("panel", sb_plate)
	add_child(backplate)

	# =========================================================================
	# 2. KHUNG AVATAR NHÂN VẬT (Avatar Portrait Frame) - Hỗ trợ Upload ảnh thật
	# =========================================================================
	var avatar_frame = Panel.new()
	avatar_frame.name = "AvatarFrame"
	avatar_frame.position = Vector2(6, 8)
	avatar_frame.size = Vector2(72, 72)
	
	var sb_avatar = StyleBoxFlat.new()
	sb_avatar.bg_color = Color(0.06, 0.08, 0.12, 0.4) # Trong suốt
	sb_avatar.border_width_left = 1
	sb_avatar.border_width_top = 1
	sb_avatar.border_width_right = 1
	sb_avatar.border_width_bottom = 1
	sb_avatar.border_color = Color(0.75, 0.62, 0.3, 0.85) # Viền vàng mảnh
	sb_avatar.corner_radius_top_left = 5
	sb_avatar.corner_radius_top_right = 5
	sb_avatar.corner_radius_bottom_left = 5
	sb_avatar.corner_radius_bottom_right = 5
	sb_avatar.shadow_color = Color(0, 0, 0, 0.3)
	sb_avatar.shadow_size = 2
	avatar_frame.add_theme_stylebox_override("panel", sb_avatar)
	backplate.add_child(avatar_frame)

	# Hình ảnh Avatar (Hiển thị ảnh thật của người chơi hoặc mặc định)
	avatar_rect = TextureRect.new()
	avatar_rect.name = "AvatarRect"
	avatar_rect.position = Vector2(2, 2)
	avatar_rect.size = Vector2(68, 68)
	avatar_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	avatar_rect.texture = _get_user_avatar()
	avatar_frame.add_child(avatar_rect)

	# Nút bấm nhấp trực tiếp vào Avatar để Tải lên / Thay đổi ảnh đại diện
	var btn_avatar = Button.new()
	btn_avatar.anchors_preset = Control.PRESET_FULL_RECT
	btn_avatar.flat = true
	btn_avatar.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_avatar.tooltip_text = "Nhấp để tải lên / thay đổi ảnh đại diện (PNG, JPG, WEBP)"
	btn_avatar.pressed.connect(_open_avatar_file_dialog)
	avatar_frame.add_child(btn_avatar)

	# Icon máy ảnh nhỏ góc trên phải - Nhấp vào máy ảnh hoặc nhấp trực tiếp vào Avatar đều mở hộp thoại tải ảnh
	var cam_badge = Panel.new()
	cam_badge.position = Vector2(50, 2)
	cam_badge.size = Vector2(18, 16)
	var sb_cam = StyleBoxFlat.new()
	sb_cam.bg_color = Color(0.1, 0.12, 0.16, 0.85)
	sb_cam.corner_radius_top_left = 3
	sb_cam.corner_radius_top_right = 3
	sb_cam.corner_radius_bottom_left = 3
	sb_cam.corner_radius_bottom_right = 3
	cam_badge.add_theme_stylebox_override("panel", sb_cam)
	avatar_frame.add_child(cam_badge)

	var lbl_cam = Label.new()
	lbl_cam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_cam.anchors_preset = Control.PRESET_FULL_RECT
	lbl_cam.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_cam.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_cam.text = "📷"
	lbl_cam.add_theme_font_size_override("font_size", 9)
	cam_badge.add_child(lbl_cam)

	var btn_cam = Button.new()
	btn_cam.anchors_preset = Control.PRESET_FULL_RECT
	btn_cam.flat = true
	btn_cam.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_cam.tooltip_text = "Tải lên ảnh đại diện thật của bạn (PNG, JPG, WEBP)"
	btn_cam.pressed.connect(_open_avatar_file_dialog)
	cam_badge.add_child(btn_cam)

	# Huy hiệu trạng thái an toàn / hòa bình góc dưới phải
	status_gem = Panel.new()
	status_gem.position = Vector2(52, 51)
	status_gem.size = Vector2(16, 16)
	var sb_gem = StyleBoxFlat.new()
	sb_gem.bg_color = Color(0.12, 0.75, 0.35, 1.0)
	sb_gem.border_width_left = 1
	sb_gem.border_width_top = 1
	sb_gem.border_width_right = 1
	sb_gem.border_width_bottom = 1
	sb_gem.border_color = Color(1.0, 1.0, 1.0, 0.95)
	sb_gem.corner_radius_top_left = 8
	sb_gem.corner_radius_top_right = 8
	sb_gem.corner_radius_bottom_left = 8
	sb_gem.corner_radius_bottom_right = 8
	status_gem.add_theme_stylebox_override("panel", sb_gem)
	avatar_frame.add_child(status_gem)

	# =========================================================================
	# 3. HÀNG TIÊU ĐỀ: [CHIẾN BINH] RỒI ĐẾN TÊN NHÂN VẬT & PIN + FPS
	# =========================================================================
	var header_hbox = HBoxContainer.new()
	header_hbox.position = Vector2(84, 5)
	header_hbox.size = Vector2(256, 16)
	header_hbox.add_theme_constant_override("separation", 6)
	backplate.add_child(header_hbox)

	# 1. Danh hiệu Lớp Nhân Vật đứng trước (Ví dụ: [Chiến Binh])
	lbl_class = Label.new()
	lbl_class.text = "[Chiến Binh]"
	lbl_class.add_theme_font_size_override("font_size", 11)
	lbl_class.add_theme_color_override("font_color", Color(0.48, 0.82, 1.0, 1.0)) # Xanh lam ngọc
	lbl_class.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl_class.add_theme_constant_override("outline_size", 2)
	header_hbox.add_child(lbl_class)

	# 2. Tên Nhân Vật đứng sau (Ví dụ: Hero)
	lbl_name = Label.new()
	lbl_name.text = "Hero"
	lbl_name.add_theme_font_size_override("font_size", 12)
	lbl_name.add_theme_color_override("font_color", Color(1.0, 0.9, 0.52, 1.0)) # Vàng kim rực rỡ
	lbl_name.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl_name.add_theme_constant_override("outline_size", 2)
	header_hbox.add_child(lbl_name)

	# Spacer đẩy Pin & FPS sang phải
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(spacer)

	# 3. Pin & FPS hiển thị phía trên bên phải theo phong cách Mobile chuẩn ảnh
	lbl_pin_fps = Label.new()
	lbl_pin_fps.text = "Pin : 98% FPS : 60"
	lbl_pin_fps.add_theme_font_size_override("font_size", 10)
	lbl_pin_fps.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95, 0.9))
	lbl_pin_fps.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl_pin_fps.add_theme_constant_override("outline_size", 2)
	header_hbox.add_child(lbl_pin_fps)

	# =========================================================================
	# 4. CỘT CÁC THANH CHỈ SỐ: HP, MP, AG|SD (CÂY VÀNG), EXP (CÂY VÀNG XANH)
	# =========================================================================
	var vbox_bars = VBoxContainer.new()
	vbox_bars.position = Vector2(84, 23)
	vbox_bars.size = Vector2(256, 60)
	vbox_bars.add_theme_constant_override("separation", 2)
	backplate.add_child(vbox_bars)

	# 1. HP Bar (Máu Đỏ)
	var hp_res = _create_fancy_bar(
		"HP",
		Color(0.88, 0.14, 0.14),
		Color(0.55, 0.08, 0.08),
		Color(1.0, 0.35, 0.35),
		"110 / 110",
		256.0,
		14.0,
		24.0,
		10
	)
	hp_bar = hp_res["bar"]
	lbl_hp = hp_res["label"]
	vbox_bars.add_child(hp_res["container"])

	# 2. MP Bar (Mana Lam)
	var mp_res = _create_fancy_bar(
		"MP",
		Color(0.12, 0.48, 0.95),
		Color(0.08, 0.25, 0.62),
		Color(0.38, 0.75, 1.0),
		"40 / 40",
		256.0,
		14.0,
		24.0,
		10
	)
	mp_bar = mp_res["bar"]
	lbl_mp = mp_res["label"]
	vbox_bars.add_child(mp_res["container"])

	# 3. Hàng AG (Thể Lực Tím) & SD (Giáp Vàng - Cây Màu Vàng)
	var row_ag_sd = HBoxContainer.new()
	row_ag_sd.custom_minimum_size = Vector2(256, 14)
	row_ag_sd.size = Vector2(256, 14)
	row_ag_sd.add_theme_constant_override("separation", 4)

	# AG (Tím) bên trái
	var ag_res = _create_fancy_bar(
		"AG",
		Color(0.68, 0.22, 0.92),
		Color(0.42, 0.1, 0.6),
		Color(0.85, 0.48, 1.0),
		"56 / 56",
		126.0,
		14.0,
		24.0,
		10
	)
	ag_bar = ag_res["bar"]
	lbl_ag = ag_res["label"]
	row_ag_sd.add_child(ag_res["container"])

	# SD (Cây Màu Vàng) bên phải giống chuẩn hình ảnh người dùng gửi
	var sd_res = _create_fancy_bar(
		"SD",
		Color(0.92, 0.65, 0.12),
		Color(0.55, 0.38, 0.06),
		Color(1.0, 0.85, 0.35),
		"100 / 100",
		126.0,
		14.0,
		24.0,
		10
	)
	sd_bar = sd_res["bar"]
	lbl_sd = sd_res["label"]
	row_ag_sd.add_child(sd_res["container"])

	vbox_bars.add_child(row_ag_sd)

	# 4. EXP Bar (Cây Kinh Nghiệm EXP Màu Vàng Xanh giống hình)
	var exp_res = _create_fancy_bar(
		"EXP",
		Color(0.48, 0.88, 0.28),
		Color(0.14, 0.40, 0.14),
		Color(0.55, 0.95, 0.35),
		"0 / 200 (0.0%)",
		256.0,
		14.0,
		28.0,
		10
	)
	exp_bar = exp_res["bar"]
	lbl_exp = exp_res["label"]
	vbox_bars.add_child(exp_res["container"])

	# =========================================================================
	# 5. NÚT GM LẤY ĐỒ (CHỈ HIỂN THỊ NẾU LÀ GM)
	# =========================================================================
	_build_gm_button(Vector2(354, 28))

	# 6. Khung Hiển Thị Thú Cưỡi / Thú Cưng (Dưới thanh máu, bên góc trái màn hình)
	_build_pet_ui()

## Tạo thanh chỉ số chuẩn MMORPG với chữ số TO & ĐẬM nằm bên phải thanh
func _create_fancy_bar(
	tag_text: String,
	fill_col: Color,
	tag_bg: Color,
	tag_border: Color,
	default_val: String,
	total_width: float = 256.0,
	bar_height: float = 13.0,
	tag_w: float = 22.0,
	font_sz: int = 13
) -> Dictionary:
	var row = HBoxContainer.new()
	row.custom_minimum_size = Vector2(total_width, bar_height)
	row.size = Vector2(total_width, bar_height)
	row.add_theme_constant_override("separation", 3)

	# 1. Tag định danh (HP / MP / AG / SD / EXP)
	var tag_panel = Panel.new()
	tag_panel.custom_minimum_size = Vector2(tag_w, bar_height)
	tag_panel.size = Vector2(tag_w, bar_height)
	var sb_tag = StyleBoxFlat.new()
	sb_tag.bg_color = tag_bg
	sb_tag.border_width_left = 1
	sb_tag.border_width_top = 1
	sb_tag.border_width_right = 1
	sb_tag.border_width_bottom = 1
	sb_tag.border_color = tag_border
	sb_tag.corner_radius_top_left = 2
	sb_tag.corner_radius_top_right = 2
	sb_tag.corner_radius_bottom_left = 2
	sb_tag.corner_radius_bottom_right = 2
	tag_panel.add_theme_stylebox_override("panel", sb_tag)
	row.add_child(tag_panel)

	var lbl_tag = Label.new()
	lbl_tag.text = tag_text
	lbl_tag.add_theme_font_size_override("font_size", 9 if tag_text.length() >= 3 else 10)
	lbl_tag.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	lbl_tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl_tag.add_theme_constant_override("outline_size", 2)
	lbl_tag.add_theme_constant_override("line_spacing", 0)
	lbl_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag_panel.add_child(lbl_tag)
	lbl_tag.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl_tag.offset_left = 2.0
	lbl_tag.offset_right = -1.0
	lbl_tag.offset_top = -1.0
	lbl_tag.offset_bottom = -1.0

	# 2. Thanh ProgressBar chính
	var pbar_w = max(35.0, total_width - tag_w - 3.0)
	var pbar = ProgressBar.new()
	pbar.custom_minimum_size = Vector2(pbar_w, bar_height)
	pbar.size = Vector2(pbar_w, bar_height)
	pbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pbar.show_percentage = false
	pbar.max_value = 100
	pbar.value = 100

	# Nền lõm (Groove background)
	var sb_bg = StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.02, 0.04, 0.07, 0.65) # Bán trong suốt
	sb_bg.border_width_left = 1
	sb_bg.border_width_top = 1
	sb_bg.border_width_right = 1
	sb_bg.border_width_bottom = 1
	sb_bg.border_color = Color(0.24, 0.28, 0.36, 0.7)
	sb_bg.corner_radius_top_left = 2
	sb_bg.corner_radius_top_right = 2
	sb_bg.corner_radius_bottom_left = 2
	sb_bg.corner_radius_bottom_right = 2
	pbar.add_theme_stylebox_override("background", sb_bg)

	# Phần làm đầy (Filled portion)
	var sb_fill = StyleBoxFlat.new()
	sb_fill.bg_color = fill_col
	sb_fill.corner_radius_top_left = 2
	sb_fill.corner_radius_top_right = 2
	sb_fill.corner_radius_bottom_left = 2
	sb_fill.corner_radius_bottom_right = 2
	pbar.add_theme_stylebox_override("fill", sb_fill)
	row.add_child(pbar)

	# 3. Chữ số hiển thị giá trị: Căn giữa theo chiều dọc chuẩn xác
	var lbl_val = Label.new()
	lbl_val.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl_val.offset_left = 4
	lbl_val.offset_top = -1
	lbl_val.offset_right = -5
	lbl_val.offset_bottom = -1
	lbl_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_val.text = default_val
	lbl_val.add_theme_font_size_override("font_size", font_sz)
	lbl_val.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0)) # Trắng tinh
	lbl_val.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1)) # Viền đen rõ nét
	lbl_val.add_theme_constant_override("outline_size", 2)
	lbl_val.add_theme_constant_override("line_spacing", 0)
	pbar.add_child(lbl_val)

	return {"container": row, "bar": pbar, "label": lbl_val}

## Mở hộp thoại chọn ảnh đại diện thật từ máy tính người chơi
func _open_avatar_file_dialog() -> void:
	if MuAudioManager:
		MuAudioManager.play_ui_click()
	if not file_dialog:
		file_dialog = FileDialog.new()
		file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		file_dialog.title = "Chọn ảnh đại diện thật của bạn (PNG, JPG, WEBP)"
		file_dialog.filters = PackedStringArray([
			"*.png, *.jpg, *.jpeg, *.webp ; Ảnh đại diện (Images)"
		])
		file_dialog.use_native_dialog = true
		file_dialog.file_selected.connect(_on_avatar_file_selected)
		add_child(file_dialog)
	file_dialog.popup_centered(Vector2i(750, 500))

func _on_avatar_file_selected(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var img = Image.load_from_file(path)
	if img:
		var tex = ImageTexture.create_from_image(img)
		if avatar_rect:
			avatar_rect.texture = tex
		
		# Lưu bền vững vào user:// và res://
		img.save_png("user://player_avatar.png")
		var proj_path = ProjectSettings.globalize_path("res://assets/textures/ui/custom_avatar.png")
		img.save_png(proj_path)
		
		var hud = get_tree().get_first_node_in_group("HUD")
		if hud and hud.has_method("show_pickup_notification"):
			hud.show_pickup_notification("Đã cập nhật ảnh đại diện người chơi!", Color(0.4, 0.95, 0.5))

func _create_icon_button(icon_path: String, bg_color: Color, fallback_label: String = "") -> TextureButton:
	var btn = TextureButton.new()
	btn.custom_minimum_size = Vector2(26, 26)
	btn.size = Vector2(26, 26)
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	var tex = _get_texture(icon_path)
	if tex:
		btn.texture_normal = tex
	else:
		var p = Panel.new()
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.anchors_preset = Control.PRESET_FULL_RECT
		var sb = StyleBoxFlat.new()
		sb.bg_color = bg_color
		sb.border_width_left = 1
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		sb.border_color = Color(0.75, 0.65, 0.35, 0.8)
		sb.corner_radius_top_left = 13
		sb.corner_radius_top_right = 13
		sb.corner_radius_bottom_left = 13
		sb.corner_radius_bottom_right = 13
		p.add_theme_stylebox_override("panel", sb)
		btn.add_child(p)
		
		if fallback_label != "":
			var lbl = Label.new()
			lbl.anchors_preset = Control.PRESET_FULL_RECT
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lbl.text = fallback_label
			lbl.add_theme_font_size_override("font_size", 8)
			lbl.add_theme_color_override("font_color", Color.WHITE)
			p.add_child(lbl)
	return btn

func _build_gm_button(pos: Vector2) -> void:
	btn_gm = Button.new()
	btn_gm.name = "GmItemPickerButton"
	btn_gm.position = pos
	btn_gm.custom_minimum_size = Vector2(46, 28)
	btn_gm.size = Vector2(46, 28)
	btn_gm.text = "GM"
	btn_gm.tooltip_text = "Nhấp để mở Bảng Lấy Đồ GM (Item Picker)"
	btn_gm.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_gm.add_theme_font_size_override("font_size", 12)
	btn_gm.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	btn_gm.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.75))
	btn_gm.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	btn_gm.add_theme_constant_override("outline_size", 3)

	var sb_normal = StyleBoxFlat.new()
	sb_normal.bg_color = Color(0.12, 0.08, 0.04, 0.88)
	sb_normal.border_width_left = 1
	sb_normal.border_width_top = 1
	sb_normal.border_width_right = 1
	sb_normal.border_width_bottom = 1
	sb_normal.border_color = Color(0.85, 0.72, 0.35, 0.9)
	sb_normal.corner_radius_top_left = 4
	sb_normal.corner_radius_top_right = 4
	sb_normal.corner_radius_bottom_left = 4
	sb_normal.corner_radius_bottom_right = 4
	btn_gm.add_theme_stylebox_override("normal", sb_normal)

	var sb_hover = sb_normal.duplicate()
	sb_hover.bg_color = Color(0.28, 0.18, 0.06, 0.95)
	sb_hover.border_color = Color(1.0, 0.9, 0.45, 1.0)
	btn_gm.add_theme_stylebox_override("hover", sb_hover)

	var sb_pressed = sb_normal.duplicate()
	sb_pressed.bg_color = Color(0.08, 0.05, 0.02, 0.95)
	btn_gm.add_theme_stylebox_override("pressed", sb_pressed)

	btn_gm.pressed.connect(_on_gm_button_pressed)
	add_child(btn_gm)
	_update_gm_button_visibility()

func _is_player_gm() -> bool:
	if not player:
		return true
	if player.has_method("check_is_gm"):
		return player.check_is_gm()
	if "is_gm" in player:
		return bool(player.get("is_gm"))
	return false

func _update_gm_button_visibility() -> void:
	if btn_gm:
		btn_gm.visible = _is_player_gm()

func _on_gm_button_pressed() -> void:
	var hud = get_tree().get_first_node_in_group("HUD")
	if hud and hud.has_method("toggle_item_picker"):
		hud.toggle_item_picker()
	if MuAudioManager:
		MuAudioManager.play_ui_click()

func _on_avatar_pressed() -> void:
	_open_avatar_file_dialog()

func _process(delta: float) -> void:
	if lbl_pin_fps:
		var fps = Engine.get_frames_per_second()
		lbl_pin_fps.text = "Pin : 98% FPS : " + str(fps)

	# Định kỳ kiểm tra & làm mới khung máu thú cưng
	_pet_check_timer -= delta
	if _pet_check_timer <= 0.0:
		_pet_check_timer = 0.25
		_update_pet_widget()

# =============================================================================
# KHUNG HIỂN THỊ THÚ CƯỠI / THÚ CƯNG (MU ONLINE CLASSIC / SEASON 6 STYLE)
# Nằm ở góc trái màn hình, ngay dưới khung và thanh máu của nhân vật
# =============================================================================
func _build_pet_ui() -> void:
	# Khởi tạo 2 khung pet (0: Thú cưỡi / Pet chính ở ô helper; 1: Quạ Tinh Dark Raven ở tay trái)
	for i in range(2):
		var pbox = _create_pet_box(i)
		add_child(pbox["container"])
		pet_box_list.append(pbox)
	_update_pet_widget()

func _create_pet_box(index: int) -> Dictionary:
	var container = Panel.new()
	container.name = "PetBox_%d" % index
	container.position = Vector2(6, 94 + index * 48)
	container.custom_minimum_size = Vector2(114, 46)
	container.size = Vector2(114, 46)
	container.mouse_filter = Control.MOUSE_FILTER_PASS
	container.visible = false
	container.gui_input.connect(_on_pet_box_gui_input)

	# Nền đen bán trong suốt bao trong khung
	var sb_bg = StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.04, 0.06, 0.09, 0.85)
	sb_bg.corner_radius_top_left = 3
	sb_bg.corner_radius_top_right = 3
	sb_bg.corner_radius_bottom_left = 3
	sb_bg.corner_radius_bottom_right = 3
	container.add_theme_stylebox_override("panel", sb_bg)

	# 1. Khung viền kim loại chạm khắc MU Season 6 (newui_Pet_Back)
	var frame_rect = TextureRect.new()
	frame_rect.name = "FrameRect"
	frame_rect.position = Vector2(0, 0)
	frame_rect.size = Vector2(114, 46)
	frame_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame_rect.stretch_mode = TextureRect.STRETCH_SCALE
	frame_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame_rect.texture = _get_texture("res://assets/textures/ui/newui_Pet_Back.png")
	container.add_child(frame_rect)

	# 2. Tên của thú (Ví dụ: Fenrir, Dark Horse, Uniria...)
	var lbl_pet = Label.new()
	lbl_pet.name = "PetNameLabel"
	lbl_pet.position = Vector2(0, 7)
	lbl_pet.size = Vector2(114, 20)
	lbl_pet.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_pet.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_pet.text = "Fenrir"
	lbl_pet.add_theme_font_size_override("font_size", 12)
	lbl_pet.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	lbl_pet.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	lbl_pet.add_theme_constant_override("outline_size", 2)
	lbl_pet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(lbl_pet)

	# 3. Cụm thanh máu đỏ phân đoạn của thú (newui_Pet_HpBar)
	var bar_clip = Control.new()
	bar_clip.name = "BarClip"
	bar_clip.clip_contents = true
	bar_clip.position = Vector2(8, 32)
	bar_clip.size = Vector2(98, 6)
	bar_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(bar_clip)

	var bar_rect = TextureRect.new()
	bar_rect.name = "BarRect"
	bar_rect.position = Vector2(0, 0)
	bar_rect.size = Vector2(98, 6)
	bar_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bar_rect.stretch_mode = TextureRect.STRETCH_SCALE
	bar_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bar_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_rect.texture = _get_texture("res://assets/textures/ui/newui_Pet_HpBar.png")
	bar_clip.add_child(bar_rect)

	return {
		"container": container,
		"frame_rect": frame_rect,
		"lbl_name": lbl_pet,
		"bar_clip": bar_clip,
		"bar_rect": bar_rect
	}

func _on_pet_box_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var hud = get_tree().get_first_node_in_group("HUD")
		if hud and hud.has_method("toggle_inventory"):
			hud.toggle_inventory()
		if MuAudioManager:
			MuAudioManager.play_ui_click()

func _on_inventory_changed() -> void:
	_update_pet_widget()

func _get_pet_name(it: Dictionary) -> String:
	if it.is_empty():
		return ""
	var g := int(it.get("group", 0))
	var n := int(it.get("number", 0))
	if g == 13:
		match n:
			0: return "Guardian Angel"
			1: return "Imp"
			2: return "Uniria"
			3: return "Dinorant"
			4: return "Dark Horse"
			5: return "Dark Raven"
			37:
				var exc = int(it.get("excellent_flags", 0))
				if exc == 1: return "Fenrir (Black)"
				elif exc == 2: return "Fenrir (Blue)"
				elif exc == 4: return "Fenrir (Gold)"
				return "Fenrir"
			64: return "Demon"
			65: return "Guardian"
			67: return "Rudolf"
			80: return "Panda"
			106: return "Unicorn"
			123: return "Skeleton"
	var bn: String = it.get("name", "")
	if bn != "":
		return bn
	return "Pet"

func _update_pet_widget() -> void:
	if not player or pet_box_list.is_empty():
		return

	# Danh sách thú đang trang bị (Helper slot hoặc Dark Raven ở tay trái)
	var active_pets: Array[Dictionary] = []
	if player.equipment is Dictionary:
		var helper_it: Dictionary = player.equipment.get("helper", {}) if player.equipment.get("helper") is Dictionary else {}
		if not helper_it.is_empty() and (MuItemsRes.is_mount(helper_it) or MuItemsRes.is_pet(helper_it) or MuItemsRes.is_helper(helper_it)):
			active_pets.append(helper_it)
		
		# Quạ Tinh Dark Raven ở tay trái
		var left_it: Dictionary = player.equipment.get("left", {}) if player.equipment.get("left") is Dictionary else {}
		if not left_it.is_empty() and int(left_it.get("group", 0)) == 13 and int(left_it.get("number", 0)) == 5:
			active_pets.append(left_it)

	for i in range(pet_box_list.size()):
		var pbox = pet_box_list[i]
		if i < active_pets.size():
			var pet_it = active_pets[i]
			var pet_name = _get_pet_name(pet_it)
			var dur = int(pet_it.get("dur", 255))
			var max_dur = maxi(1, MuItemsRes.max_durability(pet_it))
			if dur > max_dur:
				max_dur = dur
			var pct = clampf(float(dur) / float(max_dur), 0.0, 1.0)
			
			pbox["lbl_name"].text = pet_name
			pbox["bar_clip"].size.x = 98.0 * pct
			pbox["container"].tooltip_text = "%s\nĐộ bền (HP): %d / %d" % [pet_name, dur, max_dur]
			pbox["container"].visible = true
		else:
			pbox["container"].visible = false
