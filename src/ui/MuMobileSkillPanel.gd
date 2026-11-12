extends Control
class_name MuMobileSkillPanel

## Bảng Phím Điều Khiển Kỹ Năng Bên Phải (Mobile Skill Controls)
## Dành riêng cho màn hình cảm ứng điện thoại (Android / iOS / Web Mobile) & hỗ trợ cả chuột trên PC
## Nút Kỹ Năng Chính to tròn mạ vàng MU, cùng Vòng Tròn Kỹ Năng (Radial Skill Wheel)
## bung tỏa quanh nút khi chạm để chọn toàn bộ các kỹ năng hiện có của nhân vật.

signal skill_cast(skill_id: String)
signal skill_selected(skill_id: String)

@export var player: MuPlayer = null

# Cấu hình kích thước & vị trí
var main_btn_pos: Vector2 = Vector2(175, 175)
var main_btn_radius: float = 44.0

var wheel_btn_pos: Vector2 = Vector2(105, 110)
var wheel_btn_radius: float = 22.0

var attack_btn_pos: Vector2 = Vector2(95, 180)
var attack_btn_radius: float = 24.0

var hp_btn_pos: Vector2 = Vector2(180, 90)
var hp_btn_radius: float = 20.0

var mp_btn_pos: Vector2 = Vector2(125, 50)
var mp_btn_radius: float = 20.0

var target_btn_pos: Vector2 = Vector2(55, 130)
var target_btn_radius: float = 18.0

# Vòng Tròn Kỹ Năng (Radial Skill Ring)
var is_ring_open: bool = false
var ring_anim_progress: float = 0.0 # 0.0 -> 1.0 (Tween bung ra / thu vào)
var ring_radius: float = 108.0
var ring_slot_radius: float = 25.0
var ring_rotation_angle: float = 0.0
var ring_page: int = 0
const SKILLS_PER_PAGE: int = 6

# Bộ đếm hồi chiêu (Cooldowns)
var cooldown_timers: Dictionary = {}
var main_btn_pressed: bool = false
var main_btn_scale: float = 1.0

# Texture cache
var loaded_textures: Dictionary = {}

func _ready() -> void:
	custom_minimum_size = Vector2(250, 250)
	size = Vector2(250, 250)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_preload_textures()
	queue_redraw()

func setup(p_player: MuPlayer) -> void:
	player = p_player
	if player:
		if not player.skills_updated.is_connected(_on_player_skills_updated):
			player.skills_updated.connect(_on_player_skills_updated)
		if not player.active_skill_changed.is_connected(_on_player_active_skill_changed):
			player.active_skill_changed.connect(_on_player_active_skill_changed)
	queue_redraw()

func _preload_textures() -> void:
	var paths = [
		"res://assets/textures/ui/skills/skill_0.png",
		"res://assets/textures/ui/skills/skill_41.png",
		"res://assets/textures/ui/skills/skill_4.png",
		"res://assets/textures/ui/skills/skill_24.png",
		"res://assets/textures/ui/skills/skill_55.png",
		"res://assets/textures/ui/skills/skill_61.png",
		"res://assets/textures/ui/skills/skill_215.png",
		"res://assets/textures/ui/skills/skill_260.png",
		"res://assets/textures/ui/btn_skill_twisting.png",
		"res://assets/textures/ui/btn_skill_fireball.png",
		"res://assets/textures/ui/mobile_skills/skill_attack.png",
		"res://assets/textures/ui/mobile_skills/skill_teleport.png",
		"res://assets/textures/ui/mobile_skills/skill_buff.png",
		"res://assets/textures/ui/mobile_skills/potion_hp.png",
		"res://assets/textures/ui/mobile_skills/potion_mp.png",
		"res://assets/textures/ui/mobile_skills/skill_wheel_btn.png"
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
			var itex := ImageTexture.create_from_image(img)
			loaded_textures[path] = itex
			return itex
	return null

func _process(delta: float) -> void:
	var need_redraw = false
	
	# Cập nhật thời gian hồi chiêu
	var keys = cooldown_timers.keys()
	for k in keys:
		cooldown_timers[k] -= delta
		if cooldown_timers[k] <= 0.0:
			cooldown_timers.erase(k)
		need_redraw = true

	if player and not player.skill_delays.is_empty():
		need_redraw = true
		
	# Xoay nhẹ vòng ma thuật khi mở
	if is_ring_open:
		ring_rotation_angle += delta * 0.4
		need_redraw = true

	if need_redraw or is_ring_open:
		queue_redraw()

func _on_player_skills_updated() -> void:
	queue_redraw()

func _on_player_active_skill_changed(_skill_id: String) -> void:
	queue_redraw()

## Bật/Tắt Vòng Tròn Kỹ Năng (Radial Skill Wheel)
func toggle_skill_ring() -> void:
	var hud = get_tree().get_first_node_in_group("HUD")
	if hud and hud.has_method("toggle_skill_window"):
		hud.toggle_skill_window()
		return
	if is_ring_open:
		close_skill_ring()
	else:
		open_skill_ring()

func open_skill_ring() -> void:
	if is_ring_open:
		return
	is_ring_open = true
	if MuAudioManager:
		MuAudioManager.play_ui_window()
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "ring_anim_progress", 1.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "ring_rotation_angle", 0.35, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func close_skill_ring() -> void:
	if not is_ring_open and ring_anim_progress <= 0.0:
		return
	var tween = create_tween()
	tween.tween_property(self, "ring_anim_progress", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		is_ring_open = false
		ring_rotation_angle = 0.0
		queue_redraw()
	)

## Chọn kỹ năng từ Vòng Tròn
func select_skill(skill_dict: Dictionary) -> void:
	var s_id = skill_dict.get("id", "")
	if player and s_id != "":
		player.set_active_skill(s_id)
		emit_signal("skill_selected", s_id)
		if MuAudioManager:
			MuAudioManager.play_ui_click()
	close_skill_ring()

## Thi triển kỹ năng chính đang chọn
func execute_main_skill() -> void:
	if not player:
		return
	var act_skill = player.get_active_skill()
	var s_id = act_skill.get("id", "sk_41")
	var sk_num = int(act_skill.get("skill", -1))
	
	# Kiểm tra cooldown chuẩn MU gốc
	if player.has_method("check_skill_delay") and not player.check_skill_delay(sk_num):
		return
	if cooldown_timers.has(s_id) and cooldown_timers[s_id] > 0.0:
		return
		
	var cd = float(act_skill.get("cooldown", 0.0))
	if cd > 0.0:
		cooldown_timers[s_id] = cd
	
	# Hiệu ứng nảy nút (Punch Tween)
	main_btn_scale = 0.88
	var tween = create_tween()
	tween.tween_property(self, "main_btn_scale", 1.08, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "main_btn_scale", 1.0, 0.08)
	
	# Thi triển trên player
	player.cast_active_skill()
	emit_signal("skill_cast", s_id)
	queue_redraw()

## Xử lý sự kiện Cảm ứng (Touch) và Chuột (Mouse)
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_handle_touch_down(event.position)
		else:
			_handle_touch_up(event.position)
		accept_event()
		
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			if is_ring_open:
				_prev_ring_page()
				accept_event()
				return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			if is_ring_open:
				_next_ring_page()
				accept_event()
				return
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_handle_touch_down(event.position)
			else:
				_handle_touch_up(event.position)
			accept_event()

func _handle_touch_down(pos: Vector2) -> void:
	# 1. Nếu Vòng Kỹ Năng đang mở, kiểm tra nhấp vào các Slot kỹ năng trên vòng tròn
	if is_ring_open and ring_anim_progress > 0.5:
		var slot_hit = _get_ring_slot_at_pos(pos)
		if slot_hit != null and not slot_hit.is_empty():
			if slot_hit.get("is_page_btn", false):
				_next_ring_page()
				return
			select_skill(slot_hit)
			return
		# Nếu nhấp ra ngoài các slot kỹ năng, đóng vòng tròn
		if pos.distance_to(main_btn_pos) > main_btn_radius * 1.2:
			close_skill_ring()
			return

	# 2. Nhấp vào Nút Kỹ Năng Chính
	if pos.distance_to(main_btn_pos) <= main_btn_radius:
		main_btn_pressed = true
		execute_main_skill()
		return

	# 3. Nhấp vào Nút Bật/Tắt Danh Sách Kỹ Năng (Modal Window)
	if pos.distance_to(wheel_btn_pos) <= wheel_btn_radius:
		var hud = get_tree().get_first_node_in_group("HUD")
		if hud and hud.has_method("toggle_skill_window"):
			hud.toggle_skill_window()
		else:
			toggle_skill_ring()
		return

	# 4. Nhấp vào Nút Đánh Thường
	if pos.distance_to(attack_btn_pos) <= attack_btn_radius:
		if player:
			player.attack_nearest()
		return

	# 5. Nhấp vào Nút Bình Máu (HP)
	if pos.distance_to(hp_btn_pos) <= hp_btn_radius:
		if player:
			player.use_hp_potion()
		return

	# 6. Nhấp vào Nút Bình Mana (MP)
	if pos.distance_to(mp_btn_pos) <= mp_btn_radius:
		if player:
			player.use_mp_potion()
		return

	# 7. Nhấp vào Nút Khóa Mục Tiêu
	if pos.distance_to(target_btn_pos) <= target_btn_radius:
		if player:
			player.acquire_nearest_target()
		return

func _handle_touch_up(_pos: Vector2) -> void:
	main_btn_pressed = false
	queue_redraw()

## Lấy thông tin vị trí các Slot trên Vòng Kỹ Năng (Hỗ trợ phân trang mượt mà cho GM khi có nhiều skill)
func _get_ring_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	if not player:
		return slots
	var skills = player.get_available_skills()
	var count = skills.size()
	if count == 0:
		return slots

	var start_deg = 95.0
	var end_deg = 240.0
	var current_r = ring_radius * ring_anim_progress

	if count <= 7:
		for i in range(count):
			var t = float(i) / float(max(1, count - 1)) if count > 1 else 0.5
			var deg = lerpf(start_deg, end_deg, t)
			var rad = deg_to_rad(deg) + (ring_rotation_angle * (1.0 - ring_anim_progress))
			var offset = Vector2(cos(rad), -sin(rad)) * current_r
			var slot_center = main_btn_pos + offset
			slots.append({
				"skill": skills[i],
				"center": slot_center,
				"radius": ring_slot_radius
			})
	else:
		# Phân trang: 6 skill mỗi trang + 1 nút đổi trang
		var total_pages = int(ceil(float(count) / float(SKILLS_PER_PAGE)))
		ring_page = clampi(ring_page, 0, total_pages - 1)
		var start_idx = ring_page * SKILLS_PER_PAGE
		var end_idx = mini(count, start_idx + SKILLS_PER_PAGE)
		var page_count = (end_idx - start_idx) + 1 # +1 cho nút đổi trang
		
		for i in range(end_idx - start_idx):
			var t = float(i) / float(max(1, page_count - 1))
			var deg = lerpf(start_deg, end_deg, t)
			var rad = deg_to_rad(deg) + (ring_rotation_angle * (1.0 - ring_anim_progress))
			var offset = Vector2(cos(rad), -sin(rad)) * current_r
			var slot_center = main_btn_pos + offset
			slots.append({
				"skill": skills[start_idx + i],
				"center": slot_center,
				"radius": ring_slot_radius
			})
		
		# Nút đổi trang ở vị trí cuối vòng
		var rad_page = deg_to_rad(end_deg) + (ring_rotation_angle * (1.0 - ring_anim_progress))
		var page_center = main_btn_pos + Vector2(cos(rad_page), -sin(rad_page)) * current_r
		slots.append({
			"is_page_btn": true,
			"center": page_center,
			"radius": ring_slot_radius,
			"page_text": "%d/%d ⏩" % [ring_page + 1, total_pages]
		})
	return slots

func _get_ring_slot_at_pos(pos: Vector2) -> Dictionary:
	var slots = _get_ring_slots()
	for s in slots:
		if pos.distance_to(s["center"]) <= s["radius"] * 1.2:
			if s.get("is_page_btn", false):
				return {"is_page_btn": true}
			return s.get("skill", {})
	return {}

func _next_ring_page() -> void:
	if not player:
		return
	var count = player.get_available_skills().size()
	if count <= 7:
		return
	var total_pages = int(ceil(float(count) / float(SKILLS_PER_PAGE)))
	ring_page = (ring_page + 1) % total_pages
	if MuAudioManager:
		MuAudioManager.play_ui_click()
	queue_redraw()

func _prev_ring_page() -> void:
	if not player:
		return
	var count = player.get_available_skills().size()
	if count <= 7:
		return
	var total_pages = int(ceil(float(count) / float(SKILLS_PER_PAGE)))
	ring_page = (ring_page - 1 + total_pages) % total_pages
	if MuAudioManager:
		MuAudioManager.play_ui_click()
	queue_redraw()

# ==============================================================================
# HỆ THỐNG VẼ GIAO DIỆN (CUSTOM 2D DRAWING - PHONG CÁCH MU ONLINE)
# ==============================================================================
func _draw() -> void:
	# 1. Vẽ Vòng Tròn Kỹ Năng (Nếu đang bung mở)
	if ring_anim_progress > 0.01:
		_draw_skill_ring()

	# 2. Vẽ Nút Khóa Mục Tiêu
	_draw_sub_button(target_btn_pos, target_btn_radius, Color(0.2, 0.4, 0.5, 0.85), Color(0.4, 0.8, 1.0), "🎯")

	# 3. Vẽ Nút Bơm Máu Nhanh (HP)
	_draw_potion_button(hp_btn_pos, hp_btn_radius, "res://assets/textures/ui/mobile_skills/potion_hp.png", Color(0.85, 0.2, 0.2), "HP")

	# 4. Vẽ Nút Bơm Mana Nhanh (MP)
	_draw_potion_button(mp_btn_pos, mp_btn_radius, "res://assets/textures/ui/mobile_skills/potion_mp.png", Color(0.2, 0.5, 0.95), "MP")

	# 5. Vẽ Nút Đánh Thường (Normal Melee Attack)
	_draw_icon_button(attack_btn_pos, attack_btn_radius, "res://assets/textures/ui/skills/skill_0.png", Color(0.85, 0.7, 0.3), "Chém")

	# 6. Vẽ Nút Vòng Kỹ Năng (Radial Skill Wheel Button)
	_draw_wheel_toggle_button()

	# 7. Vẽ Nút Kỹ Năng Chính (Main Skill Button)
	_draw_main_skill_button()

## Vẽ Vòng Tròn Kỹ Năng Bung Tỏa (Radial Wheel Ring)
func _draw_skill_ring() -> void:
	var alpha = clampf(ring_anim_progress, 0.0, 1.0)
	var current_r = ring_radius * ring_anim_progress
	
	# Vẽ vòng cung quỹ đạo phát sáng (Magic Orbit Arc)
	var arc_color = Color(0.95, 0.82, 0.35, 0.65 * alpha)
	var glow_color = Color(0.85, 0.7, 0.2, 0.25 * alpha)
	draw_arc(main_btn_pos, current_r, deg_to_rad(90), deg_to_rad(245), 48, glow_color, 8.0)
	draw_arc(main_btn_pos, current_r, deg_to_rad(90), deg_to_rad(245), 48, arc_color, 2.0)
	
	# Vòng tròn ma trận trang trí bên trong
	if current_r > 30.0:
		draw_arc(main_btn_pos, current_r * 0.7, deg_to_rad(95), deg_to_rad(240), 32, Color(0.6, 0.7, 0.9, 0.2 * alpha), 1.5)

	# Lấy danh sách slot các kỹ năng
	var slots = _get_ring_slots()
	var act_skill_id = player.active_skill_id if player else ""

	for s in slots:
		var c: Vector2 = s["center"]
		var r: float = s["radius"] * ring_anim_progress

		# Đường nối tia năng lượng từ tâm nút chính tới từng slot
		draw_line(main_btn_pos, c, Color(0.9, 0.8, 0.4, 0.25 * alpha), 1.5)

		if s.get("is_page_btn", false):
			# Nút đổi trang
			draw_circle(c, r, Color(0.1, 0.15, 0.22, 0.95 * alpha))
			draw_arc(c, r, 0, TAU, 36, Color(0.3, 0.85, 1.0, 0.95 * alpha), 2.5)
			var ptext: String = s.get("page_text", "⏩")
			draw_string(ThemeDB.fallback_font, c + Vector2(-r, 5), ptext, HORIZONTAL_ALIGNMENT_CENTER, int(r * 2.0), 11, Color(0.4, 1.0, 0.9, alpha))
			draw_string(ThemeDB.fallback_font, c + Vector2(-r * 1.2, r + 13), "Đổi Trang", HORIZONTAL_ALIGNMENT_CENTER, int(r * 2.4), 10, Color(0.7, 0.9, 1.0, alpha))
			continue

		var sk: Dictionary = s["skill"]
		var is_active = (sk.get("id") == act_skill_id)

		# Nền slot kỹ năng (Đá đen MU)
		var bg_color = Color(0.08, 0.1, 0.14, 0.92 * alpha)
		draw_circle(c, r, bg_color)

		# Viền slot: Nếu đang chọn thì viền Vàng Neon lấp lánh, bình thường thì viền đồng kim loại
		var border_color = Color(1.0, 0.9, 0.3, 0.95 * alpha) if is_active else Color(0.65, 0.6, 0.5, 0.8 * alpha)
		var border_width = 3.5 if is_active else 2.0
		draw_arc(c, r, 0, TAU, 36, border_color, border_width)

		if is_active:
			# Vầng hào quang bổ sung cho skill đang kích hoạt
			draw_arc(c, r + 4.0, 0, TAU, 36, Color(1.0, 0.85, 0.2, 0.4 * alpha), 2.0)

		# Vẽ Texture Icon Kỹ Năng
		var icon_path = sk.get("icon_path", "")
		var tex = _get_texture(icon_path)
		if tex:
			var icon_size = Vector2(r * 1.3, r * 1.3)
			var icon_rect = Rect2(c - icon_size * 0.5, icon_size)
			draw_texture_rect(tex, icon_rect, false, Color(1, 1, 1, alpha))

		# Nhãn tên kỹ năng nhỏ phía trên/dưới
		var name_str = sk.get("name", "")
		var mp_str = "%d MP" % sk.get("mana_cost", 0) if sk.get("mana_cost", 0) > 0 else "0 MP"
		
		# Cooldown overlay cho slot kỹ năng trong vòng xoay
		var sk_n := int(sk.get("skill", -1))
		if player and player.has_method("get_skill_cooldown_fraction"):
			var sl_frac := player.get_skill_cooldown_fraction(sk_n)
			if sl_frac > 0.0:
				draw_arc(c, r * 0.5, -PI*0.5, -PI*0.5 + TAU * sl_frac, 28, Color(0.05, 0.05, 0.05, 0.82 * alpha), r)

		# Nhãn tên
		draw_string(ThemeDB.fallback_font, c + Vector2(-r * 1.2, -r - 4), name_str, HORIZONTAL_ALIGNMENT_CENTER, int(r * 2.4), 11, Color(1.0, 0.95, 0.8, alpha))
		# Nhãn MP
		draw_string(ThemeDB.fallback_font, c + Vector2(-r * 1.2, r + 13), mp_str, HORIZONTAL_ALIGNMENT_CENTER, int(r * 2.4), 10, Color(0.3, 0.85, 1.0, alpha))

## Vẽ Nút Kỹ Năng Chính (Main Action / Skill Button)
func _draw_main_skill_button() -> void:
	var r = main_btn_radius * main_btn_scale
	var c = main_btn_pos
	
	# Hào quang viền ngoài cùng
	draw_arc(c, r + 5.0, 0, TAU, 48, Color(0.9, 0.75, 0.2, 0.35), 3.0)
	
	# Nền tròn đá đen
	var base_col = Color(0.12, 0.14, 0.18, 0.92) if not main_btn_pressed else Color(0.2, 0.22, 0.28, 0.95)
	draw_circle(c, r, base_col)
	
	# Viền hoa văn kim loại mạ vàng MU
	var rim_col = Color(0.96, 0.82, 0.32, 0.95)
	draw_arc(c, r, 0, TAU, 48, rim_col, 4.0)
	draw_arc(c, r - 5.0, 0, TAU, 48, Color(0.5, 0.42, 0.18, 0.7), 1.5)
	
	# Icon Kỹ năng đang chọn
	var act_skill = player.get_active_skill() if player else {}
	var icon_path = act_skill.get("icon_path", "res://assets/textures/ui/skills/skill_41.png")
	var tex = _get_texture(icon_path)
	if tex:
		var isize = Vector2(r * 1.25, r * 1.25)
		draw_texture_rect(tex, Rect2(c - isize * 0.5, isize), false)
		
	# Cooldown Sweep Overlay (Hình cánh quạt tối dần)
	var s_id = act_skill.get("id", "sk_41")
	var sk_num = int(act_skill.get("skill", -1))
	var fraction: float = 0.0
	var cd_left: float = 0.0
	if player and player.has_method("get_skill_cooldown_fraction"):
		fraction = player.get_skill_cooldown_fraction(sk_num)
		cd_left = player.get_skill_cooldown_remaining(sk_num)
	elif cooldown_timers.has(s_id) and cooldown_timers[s_id] > 0.0:
		cd_left = cooldown_timers[s_id]
		var total_cd = float(act_skill.get("cooldown", 0.0))
		fraction = clampf(cd_left / maxf(0.01, total_cd), 0.0, 1.0)

	if fraction > 0.0:
		# Quạt mờ phủ bóng đen
		draw_arc(c, r * 0.5, -PI*0.5, -PI*0.5 + TAU * fraction, 36, Color(0.05, 0.05, 0.05, 0.75), r)
		# Số giây đếm ngược nếu cd >= 0.5s
		if cd_left >= 0.5:
			var sec_str = "%.1f" % cd_left
			draw_string(ThemeDB.fallback_font, c + Vector2(-20, 5), sec_str, HORIZONTAL_ALIGNMENT_CENTER, 40, 16, Color(1, 1, 0.3, 1.0))

	# Tên kỹ năng viết nhỏ phía dưới nút
	var skill_title = act_skill.get("name", "Xoay Kiếm")
	draw_string(ThemeDB.fallback_font, c + Vector2(-45, r + 15), skill_title, HORIZONTAL_ALIGNMENT_CENTER, 90, 12, Color(1.0, 0.88, 0.4))

## Vẽ Nút Mở Vòng Kỹ Năng (Radial Skill Wheel Toggle Button)
func _draw_wheel_toggle_button() -> void:
	var c = wheel_btn_pos
	var r = wheel_btn_radius
	
	# Vòng xoay ma trận ma thuật nhỏ
	draw_circle(c, r, Color(0.14, 0.12, 0.22, 0.92))
	var ring_col = Color(1.0, 0.85, 0.3, 0.9) if not is_ring_open else Color(0.3, 0.9, 1.0, 1.0)
	draw_arc(c, r, 0, TAU, 32, ring_col, 2.5)
	
	# Vẽ Icon Rune Wheel
	var tex = _get_texture("res://assets/textures/ui/mobile_skills/skill_wheel_btn.png")
	if tex:
		var isize = Vector2(r * 1.5, r * 1.5)
		draw_texture_rect(tex, Rect2(c - isize * 0.5, isize), false)
	else:
		draw_arc(c, r * 0.6, 0, TAU, 24, Color(1, 1, 1, 0.8), 2.0)
		draw_line(c - Vector2(r*0.4, 0), c + Vector2(r*0.4, 0), Color(1, 1, 1, 0.8), 2.0)
		draw_line(c - Vector2(0, r*0.4), c + Vector2(0, r*0.4), Color(1, 1, 1, 0.8), 2.0)
		
	# Nhãn hướng dẫn nhỏ
	var label_text = "Đóng" if is_ring_open else "Chiêu"
	draw_string(ThemeDB.fallback_font, c + Vector2(-25, -r - 4), label_text, HORIZONTAL_ALIGNMENT_CENTER, 50, 10, Color(0.9, 0.85, 0.6))

## Vẽ nút phụ có Icon
func _draw_icon_button(c: Vector2, r: float, icon_path: String, border_color: Color, text_label: String = "") -> void:
	draw_circle(c, r, Color(0.12, 0.14, 0.18, 0.88))
	draw_arc(c, r, 0, TAU, 32, border_color, 2.0)
	
	var tex = _get_texture(icon_path)
	if tex:
		var isize = Vector2(r * 1.35, r * 1.35)
		draw_texture_rect(tex, Rect2(c - isize * 0.5, isize), false)
		
	if text_label != "":
		draw_string(ThemeDB.fallback_font, c + Vector2(-25, r + 13), text_label, HORIZONTAL_ALIGNMENT_CENTER, 50, 10, Color(0.85, 0.85, 0.85))

## Vẽ nút Potion
func _draw_potion_button(c: Vector2, r: float, icon_path: String, border_color: Color, text_label: String) -> void:
	draw_circle(c, r, Color(0.1, 0.12, 0.15, 0.88))
	draw_arc(c, r, 0, TAU, 28, border_color, 2.2)
	
	var tex = _get_texture(icon_path)
	if tex:
		var isize = Vector2(r * 1.4, r * 1.4)
		draw_texture_rect(tex, Rect2(c - isize * 0.5, isize), false)
		
	draw_string(ThemeDB.fallback_font, c + Vector2(-20, r + 11), text_label, HORIZONTAL_ALIGNMENT_CENTER, 40, 10, border_color)

## Vẽ nút phụ chung
func _draw_sub_button(c: Vector2, r: float, bg_col: Color, border_col: Color, label: String) -> void:
	draw_circle(c, r, bg_col)
	draw_arc(c, r, 0, TAU, 24, border_col, 2.0)
	draw_string(ThemeDB.fallback_font, c + Vector2(-12, 5), label, HORIZONTAL_ALIGNMENT_CENTER, 24, 14, Color.WHITE)
