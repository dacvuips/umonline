extends Control
class_name MuBottomRightCombatWidget

## Cụm Phím Chiến Đấu & Kỹ Năng Chuẩn 100% Theo Ảnh (Mobile MU Origin Combat Wheel)
## - Nút KỸ NĂNG ở phía trên: bấm để mở bảng danh sách kỹ năng, kéo thả vào ô để sử dụng
## - Nút Đánh Chính (ATK) viền bạc ở tâm (kích thước mở rộng rõ ràng)
## - Vòng tròn quỹ đạo (Orbit Ring) liên kết 7 nút xung quanh
## - 4 Ô Kỹ Năng (Slots 1, 2, 3, 4 trên Trang 1; Slots 5, 6, 7, 8 trên Trang 2):
##     + Có kỹ năng: hiển thị icon kỹ năng ĐƯỢC CẮT TRÒN HOÀN TOÀN không bị over ra ngoài viền trắng
##     + Hỗ trợ Drag & Drop (kéo thả) kỹ năng trực tiếp từ bảng danh sách vào từng ô
##     + Hỗ trợ kéo hoán đổi kỹ năng giữa các ô trong vòng xoay
##     + Ô trống (+) chạm vào để mở bảng chọn gán kỹ năng
## - 3 Nút Chức Năng Bổ Trợ: Đổi trang (1/2), Khóa Mục Tiêu (🎯), Chế Độ Đánh (⚔)

signal skill_slot_clicked(slot_index: int, skill_data: Dictionary)
signal empty_slot_clicked(slot_index: int)

@export var player: MuPlayer = null

# Tâm vòng tròn và bán kính quỹ đạo (Mở rộng to hơn một xíu)
var center_atk: Vector2 = Vector2(178, 196)
var r_orbit: float = 125.0
var r_atk: float = 38.0
var r_skill: float = 38.0
var r_page: float = 26.0
var r_target: float = 27.0
var r_sword: float = 26.0

# Góc cơ sở và bước góc 8 vị trí (360° / 8 = 45°)
const BASE_ANGLE_DEG: float = -5.0
const STEP_ANGLE_DEG: float = 45.0

# Trạng thái trang (1 hoặc 2)
var current_page: int = 1

# Danh sách kỹ năng trang bị (Trang 1: 0..4, Trang 2: 5..9)
# null nghĩa là ô trống (+)
var equipped_skills: Array = [null, null, null, null, null, null, null, null, null, null]

# Bộ đếm hồi chiêu cho 10 ô kỹ năng
var slot_cooldowns: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var slot_max_cooldowns: Array[float] = [2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0]
var slot_scales: Array[float] = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]

# Hiệu ứng nảy nút ATK
var is_atk_pressed: bool = false
var atk_scale: float = 1.0

# Kéo thả (Drag & Drop)
var drag_hover_slot: int = -1
var pending_assign_slot: int = -1

# Texture cache
var loaded_textures: Dictionary = {}

func _ready() -> void:
	custom_minimum_size = Vector2(350, 360)
	size = Vector2(350, 360)
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_to_group("MuBottomRightCombatWidget")
	
	_preload_textures()
	_init_default_equipped_skills()
	queue_redraw()

func _preload_textures() -> void:
	var paths = [
		"res://assets/textures/ui/mobile_origin/skill_sword_custom.png",
		"res://assets/textures/ui/mobile_origin/skill_spear_custom.png",
		"res://assets/textures/ui/mobile_origin/ref_sword_skill.png",
		"res://assets/textures/ui/mobile_origin/ref_spear_skill.png",
		"res://assets/textures/ui/mobile_origin/skill_twisting.png",
		"res://assets/textures/ui/mobile_origin/skill_fire.png",
		"res://assets/textures/ui/mobile_origin/skill_buff.png",
		"res://assets/textures/ui/skills/skill_0.png",
		"res://assets/textures/ui/skills/skill_41.png",
		"res://assets/textures/ui/skills/skill_22.png",
		"res://assets/textures/ui/skills/skill_20.png",
		"res://assets/textures/ui/skills/skill_19.png",
		"res://assets/textures/ui/skills/skill_43.png",
		"res://assets/textures/ui/newui_skillbox2.png"
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
	if path.begins_with("res://") and FileAccess.file_exists(path):
		var abs_p := ProjectSettings.globalize_path(path)
		var img := Image.load_from_file(abs_p)
		if img:
			var tex = ImageTexture.create_from_image(img)
			loaded_textures[path] = tex
			return tex
	return null

func setup(p_player: MuPlayer) -> void:
	player = p_player
	if player:
		if player.has_signal("skills_updated") and not player.skills_updated.is_connected(_on_player_skills_updated):
			player.skills_updated.connect(_on_player_skills_updated)
		if player.has_signal("active_skill_changed") and not player.active_skill_changed.is_connected(_on_player_active_skill_changed):
			player.active_skill_changed.connect(_on_player_active_skill_changed)
	_sync_skills_from_player()
	queue_redraw()

func _on_player_active_skill_changed(_skill_id: String) -> void:
	queue_redraw()

func _on_player_skills_updated() -> void:
	_sync_skills_from_player()
	queue_redraw()

## Không tự gắn skill cho người chơi: toàn bộ ô bắt đầu trống (+), người chơi tự gắn skill thật của nhân vật.
func _init_default_equipped_skills() -> void:
	for i in range(equipped_skills.size()):
		equipped_skills[i] = null

## Khi người chơi học kỹ năng mới: KHÔNG tự động gắn vào ô. Chỉ gỡ khỏi ô những skill nhân vật không còn sở hữu.
func _sync_skills_from_player() -> void:
	if not player or not ("available_skills" in player):
		return
	var owned_ids := {}
	for s in player.available_skills:
		owned_ids[str(s.get("id", ""))] = true
	for i in range(equipped_skills.size()):
		var eq = equipped_skills[i]
		if eq != null and not owned_ids.has(str(eq.get("id", ""))):
			equipped_skills[i] = null

func _process(delta: float) -> void:
	var need_redraw = false
	for i in range(slot_cooldowns.size()):
		if slot_cooldowns[i] > 0.0:
			slot_cooldowns[i] = maxf(0.0, slot_cooldowns[i] - delta)
			need_redraw = true

	# Kiểm tra cooldown của active skill để cập nhật hiệu ứng quét hồi chiêu ô tâm (Slot 6)
	if player and player.has_method("get_active_skill"):
		var act = player.get_active_skill()
		var sk_n = int(act.get("skill", -1))
		if sk_n >= 0 and player.has_method("get_skill_cooldown_fraction") and player.get_skill_cooldown_fraction(sk_n) > 0.0:
			need_redraw = true

	if is_atk_pressed and player:
		player.cast_active_skill()

	if need_redraw:
		queue_redraw()

func _draw() -> void:
	# 1. Vẽ Vòng Tròn Quỹ Đạo (Thin Orbit Ring) mờ mảnh liên kết các nút
	draw_arc(center_atk, r_orbit, 0, TAU, 72, Color(0.65, 0.7, 0.8, 0.28), 1.4)

	# 2. Vẽ 8 Nút Xung Quanh (theo công thức 8 vị trí 45 độ)
	# i = 0: Nút Kiếm (Sword mode)
	var pos_sword = _get_orbit_pos(0)
	_draw_sword_mode_button(pos_sword)

	# i = 1: Ô Kỹ Năng 1 (Góc trên phải)
	var pos_s1 = _get_orbit_pos(1)
	var idx1 = 0 if current_page == 1 else 5
	_draw_skill_slot(pos_s1, idx1)

	# i = 2: Ô Kỹ Năng 2 (Góc trên đỉnh)
	var pos_s2 = _get_orbit_pos(2)
	var idx2 = 1 if current_page == 1 else 6
	_draw_skill_slot(pos_s2, idx2)

	# i = 3: Ô Kỹ Năng 3 (Góc trên trái)
	var pos_s3 = _get_orbit_pos(3)
	var idx3 = 2 if current_page == 1 else 7
	_draw_skill_slot(pos_s3, idx3)

	# i = 4: Ô Kỹ Năng 4 (Góc bên trái)
	var pos_s4 = _get_orbit_pos(4)
	var idx4 = 3 if current_page == 1 else 8
	_draw_skill_slot(pos_s4, idx4)

	# i = 5: Ô Kỹ Năng 5 (Góc dưới trái)
	var pos_s5 = _get_orbit_pos(5)
	var idx5 = 4 if current_page == 1 else 9
	_draw_skill_slot(pos_s5, idx5)

	# i = 6: Nút Đổi Trang Kỹ Năng (1/2) (Góc dưới)
	var pos_page = _get_orbit_pos(6)
	_draw_page_button(pos_page)

	# i = 7: Nút Khóa Mục Tiêu (Target 🎯) (Góc dưới phải)
	var pos_target = _get_orbit_pos(7)
	_draw_target_button(pos_target)

	# 3. Vẽ Nút Đánh Chính (ATK) ở tâm
	_draw_atk_center_button()

## Tính toạ độ trên vòng tròn quỹ đạo cho vị trí i (0..6)
func _get_orbit_pos(i: int) -> Vector2:
	var deg = BASE_ANGLE_DEG - float(i) * STEP_ANGLE_DEG
	var rad = deg_to_rad(deg)
	return center_atk + Vector2(cos(rad), sin(rad)) * r_orbit

# --- VẼ CÁC THÀNH PHẦN CHI TIẾT ---

## Nút Kỹ Năng Kích Hoạt Chính ở tâm (Slot 6 chuẩn source gốc MU Online - newui_skillbox2)
func _draw_atk_center_button() -> void:
	var cur_r = r_atk * atk_scale

	# 1. Nền tròn đá đen tối cổ điển
	draw_circle(center_atk, cur_r, Color(0.04, 0.05, 0.07, 0.96))

	# 2. Lấy thông tin Kỹ Năng Hiện Tại (Slot 6 chuẩn source gốc Hero->CurrentSkill)
	var active_skill: Dictionary = {}
	if player and player.has_method("get_active_skill"):
		active_skill = player.get_active_skill()

	var cur_act_id := str(player.active_skill_id) if (player and "active_skill_id" in player) else "twisting"

	var icon_path := ""
	var skill_num := -1
	var skill_name := "ATK"

	if not active_skill.is_empty():
		icon_path = str(active_skill.get("icon_path", ""))
		skill_num = int(active_skill.get("skill", -1))
		skill_name = str(active_skill.get("name", "ATK"))

	# Nếu chưa có icon, tìm trong equipped_skills
	if icon_path == "":
		for eq in equipped_skills:
			if eq != null and not eq.is_empty():
				var sid = str(eq.get("id", ""))
				var sk_n = int(eq.get("skill", -1))
				if sid == cur_act_id or ("sk_%d" % sk_n) == cur_act_id or (cur_act_id == "twisting" and sk_n == 41):
					icon_path = str(eq.get("icon_path", ""))
					skill_num = sk_n
					skill_name = str(eq.get("name", "ATK"))
					break

	# Nếu vẫn chưa có icon và là attack/sk_0
	if icon_path == "" and (cur_act_id == "attack" or cur_act_id == "sk_0" or skill_num == 0):
		icon_path = "res://assets/textures/ui/skills/skill_0.png"
		skill_name = "Đánh"
	elif icon_path == "" and skill_num > 0:
		icon_path = "res://assets/textures/ui/skills/skill_%d.png" % skill_num

	# 3. Vẽ Icon Kỹ Năng Hiện Tại (Cắt tròn chuẩn)
	var tex = _get_texture(icon_path) if icon_path != "" else null
	if tex:
		_draw_circular_texture(center_atk, cur_r - 1.5, tex)
	else:
		var font = ThemeDB.fallback_font
		var font_size = 18
		var text = "ATK" if (cur_act_id == "attack" or cur_act_id == "sk_0") else skill_name.substr(0, 4)
		var str_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos = center_atk + Vector2(-str_size.x * 0.5, str_size.y * 0.32)
		draw_string_outline(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, 3, Color(0, 0, 0, 0.9))
		draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0.96, 0.97, 0.99))

	# 4. Quét hồi chiêu (Cooldown Radial Wipe chuẩn CSkillList / Slot 6 source gốc)
	var cd_fraction := 0.0
	var cd_remaining := 0.0
	if player:
		if skill_num >= 0 and player.has_method("get_skill_cooldown_fraction"):
			cd_fraction = player.get_skill_cooldown_fraction(skill_num)
			cd_remaining = player.get_skill_cooldown_remaining(skill_num)
		elif cur_act_id.begins_with("sk_"):
			var n = cur_act_id.substr(3).to_int()
			if player.has_method("get_skill_cooldown_fraction"):
				cd_fraction = player.get_skill_cooldown_fraction(n)
				cd_remaining = player.get_skill_cooldown_remaining(n)

	if cd_fraction > 0.0:
		var start_ang = -PI * 0.5
		var end_ang = start_ang + TAU * cd_fraction
		var pts = [center_atk]
		var steps = int(32 * cd_fraction) + 2
		for step_i in range(steps):
			var a = lerpf(start_ang, end_ang, float(step_i) / float(steps - 1))
			pts.append(center_atk + Vector2(cos(a), sin(a)) * (cur_r - 1.5))
		draw_colored_polygon(PackedVector2Array(pts), Color(0.02, 0.03, 0.05, 0.76))

		if cd_remaining >= 0.1:
			var font = ThemeDB.fallback_font
			var font_size = 16
			var cd_str = "%.1f" % cd_remaining if cd_remaining < 10.0 else "%d" % int(cd_remaining)
			var sz = font.get_string_size(cd_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			var t_pos = center_atk + Vector2(-sz.x * 0.5, sz.y * 0.32)
			draw_string_outline(font, t_pos, cd_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, 3, Color(0, 0, 0, 0.95))
			draw_string(font, t_pos, cd_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(1.0, 0.9, 0.3))

	# 5. Viền XANH LÁ DẠ QUANG ĐẶC TRƯNG CỦA Ô THỨ 6 MU ONLINE (newui_skillbox2.jpg):
	# Viền hào quang phát sáng bên ngoài
	draw_arc(center_atk, cur_r + 3.0, 0, TAU, 56, Color(0.2, 0.95, 0.35, 0.45), 3.2)
	# Khung viền xanh lá dạ quang rực sáng
	draw_arc(center_atk, cur_r, 0, TAU, 56, Color(0.28, 1.0, 0.45, 0.98), 2.8)
	# Chỉ viền kim loại ánh xanh bên trong
	draw_arc(center_atk, cur_r - 2.5, 0, TAU, 48, Color(0.7, 1.0, 0.8, 0.55), 1.2)

# Hệ số phóng to nhẹ ảnh kỹ năng để loại bỏ dải nền đen 2 bên của icon gốc MU
const SKILL_ICON_ZOOM: float = 1.36

## Vẽ ảnh kỹ năng CẮT TRÒN TUYỆT ĐỐI không bị lem hay over ra khỏi vòng tròn trắng
## Phóng to (1.36x) để tràn kín viền tròn và loại bỏ hoàn toàn viền/nền đen 2 bên
func _draw_circular_texture(center: Vector2, radius: float, tex: Texture2D) -> void:
	if not tex:
		return
	var segments: int = 40
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	pts.resize(segments)
	uvs.resize(segments)
	
	var tex_w: float = float(tex.get_width())
	var tex_h: float = float(tex.get_height())
	var scale_u: float = 0.5 / SKILL_ICON_ZOOM
	var scale_v: float = 0.5 / SKILL_ICON_ZOOM
	if tex_w > 0.0 and tex_h > 0.0:
		if tex_w > tex_h:
			scale_u = (0.5 * (tex_h / tex_w)) / SKILL_ICON_ZOOM
		elif tex_h > tex_w:
			scale_v = (0.5 * (tex_w / tex_h)) / SKILL_ICON_ZOOM
	
	for k in range(segments):
		var ang: float = float(k) / float(segments) * TAU
		var ca: float = cos(ang)
		var sa: float = sin(ang)
		pts[k] = center + Vector2(ca, sa) * radius
		uvs[k] = Vector2(0.5 + ca * scale_u, 0.5 + sa * scale_v)
	
	draw_colored_polygon(pts, Color.WHITE, uvs, tex)

## Ô Kỹ Năng (Có kỹ năng -> vẽ icon cắt tròn chuẩn; Không có kỹ năng -> hiển thị số phím mờ to chuẩn MU)
func _draw_skill_slot(pos: Vector2, slot_idx: int) -> void:
	var skill = equipped_skills[slot_idx] if slot_idx < equipped_skills.size() else null
	var cur_scale: float = slot_scales[slot_idx] if slot_idx < slot_scales.size() else 1.0
	var cur_r: float = r_skill * cur_scale

	# Số hiệu của ô (Slot 1, 2, 3, 4, 5)
	var slot_num: int = (slot_idx % 5) + 1
	var num_str := str(slot_num)

	# Kiểm tra xem đây có phải là Kỹ năng đang chọn làm Chiêu Chính (Active Skill) không
	var is_active_skill := false
	if skill != null and not skill.is_empty() and player:
		var cur_act = player.active_skill_id
		var sid = str(skill.get("id", ""))
		var sk_n = int(skill.get("skill", -1))
		if sid != "" and (sid == cur_act or cur_act == "sk_%d" % sk_n or (cur_act == "twisting" and (sk_n == 41 or sid == "twisting"))):
			is_active_skill = true

	# Hiệu ứng sáng viền nếu đang kéo chuột qua ô này (Drag & Drop Hover)
	var is_hovered = (drag_hover_slot == slot_idx)
	if is_hovered:
		draw_circle(pos, cur_r + 5.0, Color(0.2, 0.85, 0.4, 0.3))
		draw_arc(pos, cur_r + 5.0, 0, TAU, 48, Color(0.4, 1.0, 0.6, 0.95), 3.0)

	var font = ThemeDB.fallback_font

	if skill == null or skill.is_empty():
		# TRƯỜNG HỢP Ô TRỐNG (Ảnh 1 chuẩn MU):
		# 1. Nền tròn đá đen tối cổ điển
		draw_circle(pos, cur_r, Color(0.06, 0.07, 0.09, 0.92))
		# Vòng lõm chạm khắc bên trong
		draw_arc(pos, cur_r - 3.0, 0, TAU, 40, Color(0.02, 0.02, 0.03, 0.85), 2.0)
		# Viền tròn kim loại bạc
		draw_arc(pos, cur_r, 0, TAU, 48, Color(0.65, 0.72, 0.82, 0.85), 2.0)

		# 2. ĐÁNH SỐ TRẮNG ĐẬM MỜ TO (Chuẩn như ảnh 1 game gốc)
		var font_size = 36
		var str_sz = font.get_string_size(num_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos = pos + Vector2(-str_sz.x * 0.5, str_sz.y * 0.34)

		# Viền bóng đổ đen sâu (khắc chìm trên đá)
		draw_string_outline(font, text_pos, num_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, 4, Color(0.0, 0.0, 0.0, 0.7))
		# Số trắng mờ to
		draw_string(font, text_pos, num_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(1.0, 1.0, 1.0, 0.45))
	else:
		# TRƯỜNG HỢP CÓ KỸ NĂNG:
		# 1. Nền tròn lót phía sau
		draw_circle(pos, cur_r, Color(0.06, 0.07, 0.09, 0.95))

		# 2. Vẽ texture kỹ năng được CẮT THEO HÌNH TRÒN (bán kính cur_r - 1.0)
		var icon_path = str(skill.get("icon_path", ""))
		var tex = _get_texture(icon_path)
		if tex:
			_draw_circular_texture(pos, cur_r - 1.0, tex)
		else:
			# Fallback vẽ tên kỹ năng
			var sname = str(skill.get("name", "SKILL")).substr(0, 5)
			draw_string(font, pos + Vector2(-18, 4), sname, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(1, 1, 1))

		# 3. Quét hồi chiêu (Cooldown Radial Sweep)
		var cd = slot_cooldowns[slot_idx]
		var max_cd = slot_max_cooldowns[slot_idx]
		if cd > 0.0 and max_cd > 0.0:
			var t = cd / max_cd
			var start_ang = -PI * 0.5
			var end_ang = start_ang + TAU * t
			var pts = [pos]
			var steps = int(28 * t) + 2
			for step_i in range(steps):
				var a = lerpf(start_ang, end_ang, float(step_i) / float(steps - 1))
				pts.append(pos + Vector2(cos(a), sin(a)) * (cur_r - 1.0))
			draw_colored_polygon(PackedVector2Array(pts), Color(0.03, 0.04, 0.06, 0.75))

		# 4. Viền kỹ năng chuẩn MU gốc:
		# Nếu là Kỹ Năng Đang Chọn (Active Skill) -> Viền XANH LÁ RỰC RỠ (Green Border như Ảnh 1)
		# Nếu là kỹ năng thường -> Viền tròn bạc/trắng thanh thoát
		if is_active_skill:
			draw_arc(pos, cur_r + 3.0, 0, TAU, 48, Color(0.2, 0.95, 0.35, 0.45), 3.0)
			draw_arc(pos, cur_r, 0, TAU, 48, Color(0.3, 1.0, 0.45, 0.98), 2.8)
		else:
			var ring_color = Color(0.4, 1.0, 0.6, 1.0) if is_hovered else Color(0.88, 0.92, 0.98, 0.92)
			draw_arc(pos, cur_r, 0, TAU, 48, ring_color, 2.2)

		# 5. ĐÁNH SỐ TRẮNG ĐẬM MỜ TO TRÊN SLOT (Số 1, 2, 3, 4 chuẩn MU)
		var font_size = 28
		var str_sz = font.get_string_size(num_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos = pos + Vector2(-str_sz.x * 0.5, str_sz.y * 0.34)

		# Viền chữ đen đậm sắc nét để số nổi bật trên mọi icon skill
		draw_string_outline(font, text_pos, num_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, 4, Color(0.0, 0.0, 0.0, 0.88))

		# Màu số: Trắng đậm mờ (semi-transparent white), nếu là active skill thì hơi pha vàng nhẹ
		var num_color = Color(1.0, 1.0, 1.0, 0.72)
		if is_active_skill:
			num_color = Color(1.0, 1.0, 0.85, 0.88)
		draw_string(font, text_pos, num_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, num_color)

		# 6. Nếu đang hồi chiêu, vẽ số giây đếm ngược phía dưới
		if cd > 0.0:
			var cd_str = "%.1f" % cd if cd < 2.0 else "%d" % int(ceil(cd))
			var cd_sz = font.get_string_size(cd_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 13)
			var cd_pos = pos + Vector2(-cd_sz.x * 0.5, cur_r - 8.0)
			draw_string_outline(font, cd_pos, cd_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 13, 3, Color(0, 0, 0, 0.95))
			draw_string(font, cd_pos, cd_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color(1.0, 0.92, 0.3, 0.95))

## Nút Đổi Trang Kỹ Năng (1/2)
func _draw_page_button(pos: Vector2) -> void:
	draw_circle(pos, r_page, Color(0.05, 0.06, 0.08, 0.95))
	draw_arc(pos, r_page, 0, TAU, 36, Color(0.6, 0.68, 0.78, 0.8), 2.0)

	var text = "%d/2" % current_page
	var font = ThemeDB.fallback_font
	var font_size = 13
	var str_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	draw_string(font, pos + Vector2(-str_size.x * 0.5, str_size.y * 0.32), text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0.95, 0.96, 0.98))

## Nút Khóa Mục Tiêu (Target Crosshair Reticle Vàng 🎯)
func _draw_target_button(pos: Vector2) -> void:
	draw_circle(pos, r_target, Color(0.05, 0.06, 0.08, 0.95))
	draw_arc(pos, r_target, 0, TAU, 36, Color(0.6, 0.68, 0.78, 0.8), 2.0)

	# Tâm ngắm màu vàng ánh kim
	var reticle_col = Color(0.94, 0.8, 0.45, 1.0)
	draw_arc(pos, 16.0, 0, TAU, 32, reticle_col, 1.8)
	draw_arc(pos, 8.0, 0, TAU, 24, reticle_col, 1.8)
	draw_circle(pos, 2.2, reticle_col)
	draw_line(pos + Vector2(0, -20), pos + Vector2(0, -13), reticle_col, 2.0)
	draw_line(pos + Vector2(0, 13), pos + Vector2(0, 20), reticle_col, 2.0)
	draw_line(pos + Vector2(-20, 0), pos + Vector2(-13, 0), reticle_col, 2.0)
	draw_line(pos + Vector2(13, 0), pos + Vector2(20, 0), reticle_col, 2.0)

## Nút Chế Độ Đánh / Vũ Khí (Sword ⚔)
func _draw_sword_mode_button(pos: Vector2) -> void:
	draw_circle(pos, r_sword, Color(0.05, 0.06, 0.08, 0.95))
	draw_arc(pos, r_sword, 0, TAU, 36, Color(0.6, 0.68, 0.78, 0.8), 2.0)

	# Vẽ thanh kiếm trắng nghiêng 45 độ chuẩn theo ảnh
	var sword_col = Color(1.0, 1.0, 1.0, 0.95)
	var tip = pos + Vector2(10.5, -10.5)
	var hilt = pos + Vector2(-10.5, 10.5)
	draw_line(hilt, tip, sword_col, 2.8)

	var guard_p1 = pos + Vector2(-5, 2.5)
	var guard_p2 = pos + Vector2(-2.5, 5)
	draw_line(guard_p1, guard_p2, sword_col, 3.4)

# --- XỬ LÝ KÉO THẢ (DRAG & DROP) KỸ NĂNG VÀO SLOT ---

func _get_slot_index_at(pos: Vector2) -> int:
	for i in range(1, 6):
		var p = _get_orbit_pos(i)
		if pos.distance_to(p) <= r_skill * 1.3:
			return (i - 1) if current_page == 1 else (i - 1 + 5)
	return -1

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if typeof(data) == TYPE_DICTIONARY and data.get("type", "") == "mu_skill":
		var s_idx = _get_slot_index_at(at_position)
		if s_idx != -1:
			if drag_hover_slot != s_idx:
				drag_hover_slot = s_idx
				queue_redraw()
			return true
	if drag_hover_slot != -1:
		drag_hover_slot = -1
		queue_redraw()
	return false

func _drop_data(at_position: Vector2, data: Variant) -> void:
	var s_idx = _get_slot_index_at(at_position)
	drag_hover_slot = -1
	if s_idx != -1 and typeof(data) == TYPE_DICTIONARY and data.get("type", "") == "mu_skill":
		var sk: Dictionary = data.get("skill", {})
		if data.has("from_slot"):
			# Đang kéo từ slot này sang slot khác trong chính vòng xoay -> hoán đổi (swap)
			var from_s: int = int(data["from_slot"])
			if from_s >= 0 and from_s < equipped_skills.size():
				var tmp = equipped_skills[s_idx]
				equipped_skills[s_idx] = equipped_skills[from_s]
				equipped_skills[from_s] = tmp
				if MuAudioManager:
					MuAudioManager.play_ui_click()
				queue_redraw()
				return
		assign_skill_to_slot(s_idx, sk)
	queue_redraw()

func _get_drag_data(at_position: Vector2) -> Variant:
	var s_idx = _get_slot_index_at(at_position)
	if s_idx != -1 and equipped_skills[s_idx] != null:
		var sk = equipped_skills[s_idx]
		var icon_path = str(sk.get("icon_path", ""))
		var tex = _get_texture(icon_path)
		var preview = _create_drag_preview(sk, tex)
		set_drag_preview(preview)
		return {
			"type": "mu_skill",
			"skill": sk,
			"from_slot": s_idx
		}
	return null

func _create_drag_preview(sk: Dictionary, tex: Texture2D) -> Control:
	var preview := Control.new()
	var bg := ColorRect.new()
	bg.size = Vector2(46, 46)
	bg.position = Vector2(-23, -23)
	bg.color = Color(0.08, 0.1, 0.14, 0.9)
	preview.add_child(bg)
	
	var border := ReferenceRect.new()
	border.size = Vector2(46, 46)
	border.position = Vector2(-23, -23)
	border.border_color = Color(1.0, 0.85, 0.35, 0.95)
	border.border_width = 2.0
	border.editor_only = false
	preview.add_child(border)
	
	if tex:
		var icon := TextureRect.new()
		icon.size = Vector2(38, 38)
		icon.position = Vector2(-19, -19)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = tex
		preview.add_child(icon)
		
	var lbl := Label.new()
	lbl.text = str(sk.get("name", ""))
	lbl.position = Vector2(-40, 25)
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	preview.add_child(lbl)
	return preview

func assign_skill_to_slot(slot_idx: int, sk: Dictionary) -> void:
	if slot_idx < 0 or slot_idx >= equipped_skills.size():
		return
	# Tránh bị trùng cùng 1 skill trên cùng 1 trang
	var page_start = 0 if slot_idx < 5 else 5
	for i in range(page_start, page_start + 5):
		if i != slot_idx and equipped_skills[i] != null:
			if str(equipped_skills[i].get("id", "")) == str(sk.get("id", "")):
				equipped_skills[i] = null
				break
	equipped_skills[slot_idx] = sk
	var s_name = str(sk.get("name", "Kỹ Năng"))
	var tree = get_tree() if is_inside_tree() else null
	var hud = tree.get_first_node_in_group("HUD") if tree else null
	if hud and hud.has_method("show_pickup_notification"):
		hud.show_pickup_notification("Đã gán [%s] vào Ô Phím %d!" % [s_name, (slot_idx % 5) + 1], Color(0.4, 0.95, 0.5))
	if MuAudioManager:
		MuAudioManager.play_ui_click()
	queue_redraw()

func assign_to_first_empty_or_selected(sk: Dictionary) -> void:
	var target_slot := -1
	if pending_assign_slot >= 0 and pending_assign_slot < equipped_skills.size():
		target_slot = pending_assign_slot
		pending_assign_slot = -1
	else:
		var page_start = 0 if current_page == 1 else 5
		for i in range(page_start, page_start + 5):
			if equipped_skills[i] == null:
				target_slot = i
				break
	if target_slot != -1:
		assign_skill_to_slot(target_slot, sk)
	else:
		var fallback_slot = 0 if current_page == 1 else 5
		assign_skill_to_slot(fallback_slot, sk)

# --- XỬ LÝ TƯƠNG TÁC CHẠM & CLICK CHUỘT ---

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_handle_touch_down(event.position)
		else:
			_handle_touch_up(event.position)
		accept_event()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_handle_touch_down(event.position)
			else:
				_handle_touch_up(event.position)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# Chuột phải vào Ô Kỹ Năng Hiện Tại (Slot 6): Mở danh sách kỹ năng chuẩn CSkillList::OnCurrentSkillClick()
			if event.position.distance_to(center_atk) <= r_atk:
				var tree = get_tree() if is_inside_tree() else null
				var hud = tree.get_first_node_in_group("HUD") if tree else null
				if hud and hud.has_method("toggle_skill_window"):
					hud.toggle_skill_window()
				if MuAudioManager:
					MuAudioManager.play_ui_click()
				accept_event()

func _handle_touch_down(pos: Vector2) -> void:
	# 1. Nút Slot 6 (Current Active Skill) ở tâm
	if pos.distance_to(center_atk) <= r_atk:
		is_atk_pressed = true
		atk_scale = 0.92
		var tw = create_tween()
		tw.tween_property(self, "atk_scale", 1.06, 0.08)
		tw.tween_property(self, "atk_scale", 1.0, 0.06)
		if player:
			player.cast_active_skill()
		if MuAudioManager:
			MuAudioManager.play_ui_click()
		queue_redraw()
		return

	# 2. Ô Kỹ Năng 1 (i = 1)
	var p_s1 = _get_orbit_pos(1)
	if pos.distance_to(p_s1) <= r_skill:
		var idx = 0 if current_page == 1 else 5
		_on_skill_slot_touched(idx)
		return

	# 3. Ô Kỹ Năng 2 (i = 2)
	var p_s2 = _get_orbit_pos(2)
	if pos.distance_to(p_s2) <= r_skill:
		var idx = 1 if current_page == 1 else 6
		_on_skill_slot_touched(idx)
		return

	# 4. Ô Kỹ Năng 3 (i = 3)
	var p_s3 = _get_orbit_pos(3)
	if pos.distance_to(p_s3) <= r_skill:
		var idx = 2 if current_page == 1 else 7
		_on_skill_slot_touched(idx)
		return

	# 5. Ô Kỹ Năng 4 (i = 4)
	var p_s4 = _get_orbit_pos(4)
	if pos.distance_to(p_s4) <= r_skill:
		var idx = 3 if current_page == 1 else 8
		_on_skill_slot_touched(idx)
		return

	# 6. Ô Kỹ Năng 5 (i = 5)
	var p_s5 = _get_orbit_pos(5)
	if pos.distance_to(p_s5) <= r_skill:
		var idx = 4 if current_page == 1 else 9
		_on_skill_slot_touched(idx)
		return

	# 7. Nút Đổi Trang Kỹ Năng (1/2) (i = 6)
	var p_page = _get_orbit_pos(6)
	if pos.distance_to(p_page) <= r_page:
		current_page = 2 if current_page == 1 else 1
		if MuAudioManager:
			MuAudioManager.play_ui_click()
		queue_redraw()
		return

	# 8. Nút Khóa Mục Tiêu (Target 🎯) (i = 7)
	var p_target = _get_orbit_pos(7)
	if pos.distance_to(p_target) <= r_target:
		if player:
			player.acquire_nearest_target()
		if MuAudioManager:
			MuAudioManager.play_ui_click()
		return

	# 9. Nút Chế Độ Đánh (Sword ⚔) (i = 0)
	var p_sword = _get_orbit_pos(0)
	if pos.distance_to(p_sword) <= r_sword:
		var hud = get_tree().get_first_node_in_group("HUD")
		if hud and hud.has_method("show_pickup_notification"):
			hud.show_pickup_notification("Chuyển chế độ: Đánh Tự Do / Hòa Bình (PK)", Color(1.0, 0.75, 0.4))
		if MuAudioManager:
			MuAudioManager.play_ui_click()
		return

func _handle_touch_up(_pos: Vector2) -> void:
	is_atk_pressed = false
	atk_scale = 1.0
	queue_redraw()

## Xử lý khi chạm hoặc bấm phím tắt vào một ô kỹ năng (idx: 0..7)
func _on_skill_slot_touched(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= equipped_skills.size():
		return

	# Hiệu ứng nảy nút (Punch scale)
	var tw = create_tween()
	tw.tween_method(func(val: float):
		if slot_idx < slot_scales.size():
			slot_scales[slot_idx] = val
			queue_redraw()
	, 0.88, 1.0, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var skill = equipped_skills[slot_idx]

	if skill == null or skill.is_empty():
		# Ô ĐANG TRỐNG: Mở bảng chọn kỹ năng để gán vào ô
		emit_signal("empty_slot_clicked", slot_idx)
		_prompt_assign_skill(slot_idx)
	else:
		# Ô ĐÃ CÓ KỸ NĂNG:
		# 1. Chọn làm kỹ năng chính đang kích hoạt (Active Skill) chuẩn MU gốc
		var sid = str(skill.get("id", ""))
		if player and sid != "":
			player.set_active_skill(sid)
		emit_signal("skill_slot_clicked", slot_idx, skill)
		# 2. Thi triển chiêu thức
		_cast_slot_skill(slot_idx, skill)

## Gán hoặc mở bảng kỹ năng khi ấn vào ô (+)
func _prompt_assign_skill(slot_idx: int) -> void:
	pending_assign_slot = slot_idx
	var tree = get_tree() if is_inside_tree() else null
	var hud = tree.get_first_node_in_group("HUD") if tree else null
	if hud and hud.has_method("toggle_skill_window"):
		if not (hud.skill_window and hud.skill_window.visible):
			hud.toggle_skill_window()
	if hud and hud.has_method("show_pickup_notification"):
		hud.show_pickup_notification("Chọn hoặc kéo thả kỹ năng vào Ô %d!" % [(slot_idx % 5) + 1], Color(1.0, 0.85, 0.4))
	if MuAudioManager:
		MuAudioManager.play_ui_click()
	queue_redraw()

## Thi triển kỹ năng trong ô
func _cast_slot_skill(slot_idx: int, skill: Dictionary) -> void:
	var sk_num := int(skill.get("skill", -1))
	if player and player.has_method("check_skill_delay") and not player.check_skill_delay(sk_num):
		return
	if slot_cooldowns[slot_idx] > 0.0:
		return

	var cd = float(skill.get("cooldown", 1.8))
	slot_cooldowns[slot_idx] = maxf(1.0, cd)
	slot_max_cooldowns[slot_idx] = slot_cooldowns[slot_idx]

	if player:
		var sid = str(skill.get("id", ""))
		if player.has_method("set_active_skill"):
			player.set_active_skill(sid)
		player.cast_active_skill()
		if MuAudioManager:
			MuAudioManager.play_ui_click()

	queue_redraw()

## Phím tắt bàn phím chuẩn 1, 2, 3, 4 kích hoạt trực tiếp các Ô Kỹ Năng
func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var focus_owner = get_viewport().gui_get_focus_owner()
		if focus_owner is LineEdit or focus_owner is TextEdit:
			return

		var slot_to_trigger := -1
		match event.keycode:
			KEY_1:
				slot_to_trigger = 0 if current_page == 1 else 5
			KEY_2:
				slot_to_trigger = 1 if current_page == 1 else 6
			KEY_3:
				slot_to_trigger = 2 if current_page == 1 else 7
			KEY_4:
				slot_to_trigger = 3 if current_page == 1 else 8
			KEY_5:
				slot_to_trigger = 4 if current_page == 1 else 9
			KEY_TAB, KEY_QUOTELEFT:
				current_page = 2 if current_page == 1 else 1
				if MuAudioManager:
					MuAudioManager.play_ui_click()
				queue_redraw()
				get_viewport().set_input_as_handled()
				return
			KEY_SPACE:
				if player:
					player.cast_active_skill()
					is_atk_pressed = true
					var tw = create_tween()
					tw.tween_property(self, "atk_scale", 1.06, 0.08)
					tw.tween_property(self, "atk_scale", 1.0, 0.06)
				get_viewport().set_input_as_handled()
				return

		if slot_to_trigger != -1:
			_on_skill_slot_touched(slot_to_trigger)
			get_viewport().set_input_as_handled()
