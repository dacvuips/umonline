extends Control
class_name ChatWindow

# nạp trực tiếp (không phụ thuộc bộ nhớ đệm class_name của editor)
const MuCatalogRes = preload("res://src/mu/MuCatalog.gd")

## Hệ thống Khung Chat Chuẩn 100% Theo Ảnh 2 (Mobile MU Origin Style)
## - Hàng trên: Nút chọn kênh [Chat ▸], Nút thu phóng [▲ Enter để gửi]
## - Hàng dưới: Ô nhập tin nhắn [Nhập tin nhắn...] và Nút [Gửi] viền kim loại vàng
## - Hỗ trợ đầy đủ lệnh GM (/map, /zen, /level, /point, /allskills, /god...)

@onready var chat_history: RichTextLabel = $VBoxContainer/ChatHistory
@onready var chat_input: LineEdit = $VBoxContainer/InputPanel/VBoxInput/InputRow/ChatInput if has_node("VBoxContainer/InputPanel/VBoxInput/InputRow/ChatInput") else ($VBoxContainer/ChatInput if has_node("VBoxContainer/ChatInput") else null)
@onready var channel_btn: Button = $VBoxContainer/InputPanel/VBoxInput/HeaderRow/ChannelBtn if has_node("VBoxContainer/InputPanel/VBoxInput/HeaderRow/ChannelBtn") else null
@onready var toggle_btn: Button = $VBoxContainer/InputPanel/VBoxInput/HeaderRow/ToggleLabelBtn if has_node("VBoxContainer/InputPanel/VBoxInput/HeaderRow/ToggleLabelBtn") else null
@onready var toggle_arrow: Label = $VBoxContainer/InputPanel/VBoxInput/HeaderRow/ToggleLabelBtn/HBox/ArrowIcon if has_node("VBoxContainer/InputPanel/VBoxInput/HeaderRow/ToggleLabelBtn/HBox/ArrowIcon") else null
@onready var send_btn: Button = $VBoxContainer/InputPanel/VBoxInput/InputRow/SendBtn if has_node("VBoxContainer/InputPanel/VBoxInput/InputRow/SendBtn") else null

var player: MuPlayer = null
var current_channel_idx: int = 0
var channels: Array[String] = ["Chat", "Đội", "Guild", "Mật", "Hệ thống"]

## 4 mức chiều cao linh hoạt (theo yêu cầu người dùng):
## Mức 0: Ban đầu (~156px)
## Mức 1: Nhấp lần 1 (~40% chiều cao màn hình)
## Mức 2: Nhấp lần 2 (~65% chiều cao màn hình)
## Mức 3: Nhấp lần 3 (Chính xác 90% màn hình)
## Nhấp lần 4: Quay về mức 0 (ban đầu)
const DEFAULT_HEIGHT: float = 156.0
var current_height_step: int = 0
var _height_tween: Tween = null
var _history_stylebox: StyleBoxFlat = null

func _ready() -> void:
	add_to_group("ChatWindow")
	_setup_history_styling()
	_setup_scrollbar_styling()

	if chat_input:
		chat_input.text_submitted.connect(_on_text_submitted)

	if send_btn:
		send_btn.pressed.connect(_on_send_pressed)

	if toggle_btn:
		toggle_btn.pressed.connect(_on_toggle_history_pressed)
		toggle_btn.tooltip_text = "Nhấp để mở rộng khung chat (Tối đa 90% màn hình)"

	if channel_btn:
		channel_btn.pressed.connect(_on_channel_pressed)

	add_system_message("[color=gold]Chào mừng Hiệp Sĩ đến với Lục Địa MU Online (Godot Edition)![/color]")
	add_system_message("[color=cyan]Mẹo: Gõ /map (danh sách bản đồ), /map devias, /zen 50000 hoặc /level 10[/color]")

func _setup_history_styling() -> void:
	if not chat_history:
		return
	_history_stylebox = StyleBoxFlat.new()
	_history_stylebox.corner_radius_top_left = 6
	_history_stylebox.corner_radius_top_right = 6
	_history_stylebox.corner_radius_bottom_left = 6
	_history_stylebox.corner_radius_bottom_right = 6
	_history_stylebox.content_margin_left = 8.0
	_history_stylebox.content_margin_top = 8.0
	_history_stylebox.content_margin_right = 8.0
	_history_stylebox.content_margin_bottom = 8.0
	_history_stylebox.border_width_left = 1
	_history_stylebox.border_width_top = 1
	_history_stylebox.border_width_right = 1
	_history_stylebox.border_width_bottom = 1
	_history_stylebox.border_color = Color(0.35, 0.32, 0.28, 0.0)
	_history_stylebox.bg_color = Color(0.08, 0.08, 0.10, 0.0)
	chat_history.add_theme_stylebox_override("normal", _history_stylebox)

func _setup_scrollbar_styling() -> void:
	if not chat_history:
		return
	var v_scroll := chat_history.get_v_scroll_bar()
	if v_scroll:
		var grabber_sb := StyleBoxFlat.new()
		grabber_sb.bg_color = Color(0.72, 0.74, 0.78, 0.75)
		grabber_sb.corner_radius_top_left = 3
		grabber_sb.corner_radius_top_right = 3
		grabber_sb.corner_radius_bottom_left = 3
		grabber_sb.corner_radius_bottom_right = 3
		v_scroll.add_theme_stylebox_override("grabber", grabber_sb)
		v_scroll.add_theme_stylebox_override("grabber_highlight", grabber_sb)
		v_scroll.add_theme_stylebox_override("grabber_pressed", grabber_sb)

		var scroll_bg := StyleBoxFlat.new()
		scroll_bg.bg_color = Color(0.0, 0.0, 0.0, 0.25)
		scroll_bg.corner_radius_top_left = 3
		scroll_bg.corner_radius_top_right = 3
		scroll_bg.corner_radius_bottom_left = 3
		scroll_bg.corner_radius_bottom_right = 3
		v_scroll.add_theme_stylebox_override("scroll", scroll_bg)
		v_scroll.custom_minimum_size.x = 6.0

func setup(p_player: MuPlayer) -> void:
	player = p_player

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			if chat_input:
				if chat_input.has_focus():
					_on_text_submitted(chat_input.text)
				else:
					chat_input.grab_focus()
					get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			if chat_input and chat_input.has_focus():
				chat_input.release_focus()

func _on_send_pressed() -> void:
	if chat_input:
		_on_text_submitted(chat_input.text)

func _on_toggle_history_pressed() -> void:
	# Chuyển đổi vòng lặp: 0 -> 1 -> 2 -> 3 (90% màn hình) -> 0 (về ban đầu)
	current_height_step = (current_height_step + 1) % 4
	_apply_height_step(current_height_step, true)
	if MuAudioManager:
		MuAudioManager.play_ui_click()

func _get_target_height(step: int) -> float:
	var vp_h: float = 720.0
	if is_inside_tree() and get_viewport():
		var root_win := get_tree().root
		if root_win and root_win.content_scale_size.y > 0:
			vp_h = float(root_win.content_scale_size.y)
		else:
			var v_rect = get_viewport_rect().size
			if v_rect.y > 0.0:
				vp_h = v_rect.y
	else:
		vp_h = float(ProjectSettings.get_setting("display/window/size/viewport_height", 720))

	if vp_h <= 0.0:
		vp_h = 720.0

	match step:
		0:
			return DEFAULT_HEIGHT
		1:
			return maxf(DEFAULT_HEIGHT, vp_h * 0.40)
		2:
			return maxf(DEFAULT_HEIGHT, vp_h * 0.65)
		3:
			# Lần 3 là chính xác 90% màn hình
			return vp_h * 0.90
		_:
			return DEFAULT_HEIGHT

func _apply_height_step(step: int, animate: bool = true) -> void:
	current_height_step = step % 4
	var target_h: float = _get_target_height(current_height_step)
	var target_top: float = offset_bottom - target_h

	# Mũi tên: bước 0, 1, 2 hiển thị ▲ để tăng dần; bước 3 hiển thị ▼ để thu về ban đầu
	var arrow_char = "v" if current_height_step == 3 else "^"
	if toggle_arrow:
		toggle_arrow.text = arrow_char
	elif toggle_btn:
		toggle_btn.text = "%s  Enter để gửi" % arrow_char

	# Cập nhật tooltip trực quan
	if toggle_btn:
		match current_height_step:
			0:
				toggle_btn.tooltip_text = "Nhấp để mở rộng khung chat (Mức 1 - 40%)"
			1:
				toggle_btn.tooltip_text = "Nhấp để mở rộng khung chat (Mức 2 - 65%)"
			2:
				toggle_btn.tooltip_text = "Nhấp để mở rộng khung chat (Mức 3 - 90% màn hình)"
			3:
				toggle_btn.tooltip_text = "Nhấp để thu gọn về ban đầu"

	# Nền bảng lịch sử chuyển đổi mờ theo mức mở rộng
	if _history_stylebox:
		match current_height_step:
			0:
				_history_stylebox.bg_color = Color(0.08, 0.08, 0.10, 0.0)
				_history_stylebox.border_color = Color(0.35, 0.32, 0.28, 0.0)
			1:
				_history_stylebox.bg_color = Color(0.08, 0.08, 0.10, 0.55)
				_history_stylebox.border_color = Color(0.35, 0.32, 0.28, 0.45)
			2:
				_history_stylebox.bg_color = Color(0.08, 0.08, 0.10, 0.72)
				_history_stylebox.border_color = Color(0.40, 0.36, 0.30, 0.65)
			3:
				_history_stylebox.bg_color = Color(0.08, 0.08, 0.10, 0.88)
				_history_stylebox.border_color = Color(0.45, 0.40, 0.32, 0.85)

	if _height_tween and _height_tween.is_valid():
		_height_tween.kill()

	if animate:
		_height_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_height_tween.tween_property(self, "offset_top", target_top, 0.22)
		_height_tween.parallel().tween_callback(func():
			if chat_history:
				var v_scroll = chat_history.get_v_scroll_bar()
				if v_scroll:
					v_scroll.value = v_scroll.max_value
		)
	else:
		offset_top = target_top
		if chat_history:
			var v_scroll = chat_history.get_v_scroll_bar()
			if v_scroll:
				v_scroll.value = v_scroll.max_value

func _on_channel_pressed() -> void:
	current_channel_idx = (current_channel_idx + 1) % channels.size()
	if channel_btn:
		channel_btn.text = "%s ›" % channels[current_channel_idx]
	if MuAudioManager:
		MuAudioManager.play_ui_click()

func _on_text_submitted(text: String) -> void:
	var msg = text.strip_edges()
	if chat_input:
		chat_input.clear()
		chat_input.release_focus()

	if msg == "":
		return

	if msg.begins_with("/") or msg.begins_with("$"):
		_handle_command(msg)
	else:
		_send_public_chat(msg)

func _send_public_chat(msg: String) -> void:
	var sender_name = player.character_name if player else "Hero"
	var ch_name = channels[current_channel_idx]
	var prefix = "" if ch_name == "Chat" else "[color=yellow][%s][/color] " % ch_name
	add_system_message("%s[b]%s:[/b] %s" % [prefix, sender_name, msg])
	var mp = get_tree().get_first_node_in_group("MuMultiplayer")
	if mp:
		mp.send_chat(msg)

	if player:
		_show_player_bubble(msg)

func _show_player_bubble(msg: String) -> void:
	if player == null:
		return
	for c in player.get_children():
		if c is ChatBubble:
			c.queue_free()
	var bubble = preload("res://src/ui/ChatBubble.gd").new()
	player.add_child(bubble)
	bubble.show_chat(msg)

## Lệnh Tán gẫu của Command Window: mở ô chat sẵn "/w <tên> "
func start_whisper(target_name: String) -> void:
	if chat_input == null:
		return
	chat_input.text = "/w %s " % target_name
	chat_input.grab_focus()
	chat_input.caret_column = chat_input.text.length()

func add_system_message(text: String) -> void:
	if chat_history:
		chat_history.append_text(text + "\n")

func _maps_index() -> Dictionary:
	var p := "res://assets/mu/maps/maps_index.json"
	if FileAccess.file_exists(p):
		var d = JSON.parse_string(FileAccess.get_file_as_string(p))
		if d is Dictionary:
			return d
	return {}

func _handle_command(cmd_text: String) -> void:
	var parts = cmd_text.split(" ", false)
	var cmd = parts[0].to_lower()

	match cmd:
		"/w", "/whisper", "/thi":
			# Nói thầm: /w <tên> <lời nhắn>
			if parts.size() < 3:
				add_system_message("[color=#FF7060]Cú pháp: /w <tên> <lời nhắn>[/color]")
				return
			var to_name: String = parts[1]
			var body := " ".join(parts.slice(2))
			add_system_message("[color=#FFC6F5]Gửi tới %s: %s[/color]" % [to_name, body])
			var mp2 = get_tree().get_first_node_in_group("MuMultiplayer")
			if mp2 and mp2.is_online():
				mp2.send_whisper(to_name, body)
				return
			for op in get_tree().get_nodes_in_group("OtherPlayer"):
				if str(op.character_name).to_lower() == to_name.to_lower():
					var reply: String = op.whisper_reply()
					get_tree().create_timer(1.5).timeout.connect(func():
						add_system_message("[color=#FFC6F5]%s thì thầm: %s[/color]" % [op.character_name, reply]))
					return
			add_system_message("[color=#FF7060]%s không trực tuyến.[/color]" % to_name)
		"/party", "/guild", "/friend", "/duel", "/follow":
			# Lệnh của Command Window qua chat: /party <tên> ...
			var hud2 = get_tree().get_first_node_in_group("HUD")
			if parts.size() < 2 or hud2 == null:
				add_system_message("[color=#FF7060]Cú pháp: %s <tên nhân vật>[/color]" % cmd)
				return
			var target2 = null
			for op in get_tree().get_nodes_in_group("OtherPlayer"):
				if str(op.character_name).to_lower() == str(parts[1]).to_lower():
					target2 = op
			if target2 == null:
				add_system_message("[color=#FF7060]%s không trực tuyến.[/color]" % parts[1])
				return
			hud2.run_player_command(cmd.substr(1), target2)
		"/leaveparty", "/roito":
			var hud3 = get_tree().get_first_node_in_group("HUD")
			if hud3 and hud3.social:
				hud3.social.leave_party()
		"/trade", "/giaodich", "/xemdo", "/inspect":
			# /trade [tên]: giao dịch với người chơi đứng cạnh (hoặc theo tên) ; /xemdo [tên]: xem trang bị
			var target_name: String = parts[1] if parts.size() > 1 else ""
			var best = null
			var best_d := 1e9
			for p in get_tree().get_nodes_in_group("OtherPlayer"):
				var d: float = p.global_position.distance_to(player.global_position) if player else 0.0
				if target_name != "":
					if str(p.character_name).to_lower() == target_name.to_lower():
						best = p
						break
				elif d < best_d:
					best = p
					best_d = d
			var hud = get_tree().get_first_node_in_group("HUD")
			if best == null or hud == null or (target_name == "" and best_d > 3.0):
				add_system_message("[color=#FF7060]Không có người chơi nào ở gần để %s.[/color]" % ("giao dịch" if cmd in ["/trade", "/giaodich"] else "xem trang bị"))
			elif cmd in ["/trade", "/giaodich"]:
				hud.request_trade_with(best)
			else:
				hud.view_player_equipment(best)
		"/move", "/map":
			var idx := _maps_index()
			if parts.size() < 2:
				var names := PackedStringArray()
				var keys := idx.keys()
				keys.sort_custom(func(a, b): return int(a) < int(b))
				for k in keys:
					names.append("%s:%s" % [k, idx[k].get("name", "")])
				add_system_message("[color=yellow]Bản đồ: 1:Lorencia, %s[/color]" % ", ".join(names))
				add_system_message("[color=yellow]Cú pháp: /map [số|tên]  (vd /map 3, /map devias)[/color]")
				return
			var arg: String = " ".join(parts.slice(1)).to_lower()
			var target := -1
			var spawn := Vector2i(-1, -1)
			if arg.is_valid_int():
				target = arg.to_int()
			elif arg == "lorencia":
				target = 1
			else:
				for k in idx:
					if str(idx[k].get("name", "")).to_lower().begins_with(arg):
						target = int(k)
						break
			if target == 1:
				spawn = Vector2i(140, 119)
			elif idx.has(str(target)):
				var sp: Array = idx[str(target)].get("spawn", [128, 128])
				spawn = Vector2i(int(sp[0]), int(sp[1]))
			var spf := "res://assets/mu/spawns.json"
			if target >= 1 and FileAccess.file_exists(spf):
				var sd = JSON.parse_string(FileAccess.get_file_as_string(spf))
				if sd is Dictionary and sd.has(str(target)) and sd[str(target)].get("spawn_gate") is Dictionary:
					var gte: Dictionary = sd[str(target)]["spawn_gate"]
					spawn = Vector2i(randi_range(int(gte["x1"]), int(gte["x2"])), randi_range(int(gte["y1"]), int(gte["y2"])))
			if target < 1 or not MuTerrain.has_map(target):
				add_system_message("[color=red]Chưa có bản đồ '%s'. Chạy MU Tools > Chuyển bản đồ, rồi gõ /map để xem danh sách.[/color]" % arg)
				return
			add_system_message("[color=green]Đang chuyển sang %s...[/color]" % (idx[str(target)].get("name", "World%d" % target) if idx.has(str(target)) else "Lorencia"))
			MuTerrain.change_world(target, spawn)
			get_tree().call_deferred("reload_current_scene")
		"/toado", "/goto", "/timduong", "/path":
			if parts.size() < 3:
				add_system_message("[color=yellow]Cú pháp: /toado [X] [Y]  (Ví dụ: /toado 150 120)[/color]")
				return
			var gx = parts[1].to_int()
			var gy = parts[2].to_int()
			if gx < 0 or gx > 255 or gy < 0 or gy > 255:
				add_system_message("[color=red]Tọa độ không hợp lệ! Vui lòng nhập số từ 0 đến 255.[/color]")
				return
			if player and MuWorld.current:
				var cur_pos = Vector2i(player.grid_x, player.grid_y)
				var target_pos = Vector2i(gx, gy)
				var path = MuWorld.current.find_path_grid(cur_pos, target_pos)
				if path.size() > 0:
					player.move_to_path(path)
					add_system_message("[color=green]★ Đang tự động tìm đường di chuyển tới tọa độ (%d, %d)...[/color]" % [gx, gy])
				else:
					add_system_message("[color=red]Không tìm thấy đường tới tọa độ (%d, %d) (địa hình bị chặn)![/color]" % [gx, gy])
		"/market", "/cho", "/shoponline":
			var hud = get_tree().get_first_node_in_group("HUD")
			if hud and hud.has_method("toggle_market_window"):
				hud.toggle_market_window()
		"/zen":
			if parts.size() < 2:
				add_system_message("[color=red]Cú pháp: /zen [số_lượng][/color]")
				return
			var amount = parts[1].to_int()
			if player and amount > 0:
				player.zen += amount
				add_system_message("[color=yellow]Đã nhận thêm %d Zen thành công![/color]" % amount)
		"/level", "/cap", "/setlevel", "/bufflevel":
			if parts.size() < 2:
				add_system_message("[color=red]Cú pháp: /level [cấp_độ]  (vd: /level 400)[/color]")
				return
			var lvl = parts[1].to_int()
			if player and lvl > 0:
				if player.has_method("set_level"):
					player.set_level(lvl, true)
				else:
					player.level = lvl
					player.update_max_hp_mp()
				add_system_message("[color=gold]⚡ GM: Đã buff cấp độ lên Lv. %d thành công![/color]" % lvl)
				var stats_win = get_tree().get_first_node_in_group("CharacterStatsWindow")
				if stats_win and stats_win.has_method("update_stats"):
					stats_win.update_stats()
		"/reset", "/relife", "/chuyensinh", "/buffreset":
			if not player:
				return
			if parts.size() >= 2 and parts[1].is_valid_int():
				var r_cnt = parts[1].to_int()
				if player.has_method("set_resets"):
					player.set_resets(r_cnt, 500)
				else:
					player.resets = r_cnt
				add_system_message("[color=gold]👑 GM: Đã đặt số lần Reset thành: %d lần (+Point tương ứng)![/color]" % r_cnt)
			else:
				if player.has_method("perform_reset"):
					player.perform_reset(500, 1, false)
				else:
					player.resets += 1
					player.level = 1
					player.stat_points += 500
				add_system_message("[color=gold]🔄 GM: Đã thực hiện 1 lần Reset! Cấp về 1, Đạt %d lần Reset (+500 Point)![/color]" % player.resets)
			var stats_win = get_tree().get_first_node_in_group("CharacterStatsWindow")
			if stats_win and stats_win.has_method("update_stats"):
				stats_win.update_stats()
		"/class":
			# /class dw|dk|elf|mg|dl|sum|rf
			var names := {"dw": 0, "dk": 1, "elf": 2, "mg": 3, "dl": 4, "sum": 5, "rf": 6}
			if parts.size() < 2 or not names.has(parts[1].to_lower()):
				add_system_message("[color=red]Cú pháp: /class dw|dk|elf|mg|dl|sum|rf[/color]")
				return
			if player:
				player.set_class(names[parts[1].to_lower()])
				add_system_message("[color=green]Đã đổi lớp nhân vật: %s[/color]" % parts[1].to_upper())
		"/set":
			# /set <số bộ> <cấp> [exc]  — mặc trọn bộ giáp (nhóm 7..11), vd: /set 1 13 exc
			if parts.size() < 2:
				add_system_message("[color=red]Cú pháp: /set [số_bộ|off] [cấp 0-15] [exc][/color]")
				return
			if player:
				var off: bool = parts[1].to_lower() == "off"
				var num := -1 if off else parts[1].to_int()
				var lv := parts[2].to_int() if parts.size() > 2 else 0
				var exc: bool = parts.size() > 3 and parts[3].to_lower().begins_with("exc")
				var gi := 7
				for slot in ["helm", "armor", "pants", "gloves", "boots"]:
					if num < 0:
						player.equipment.erase(slot)
					else:
						player.equipment[slot] = {"group": gi, "number": num, "level": lv, "excellent": exc}
					gi += 1
				player.rebuild_model()
				add_system_message("[color=green]Đã mặc bộ %s +%d%s[/color]" % [MuCatalogRes.item_name(8, num) if num >= 0 else "mặc định", lv, " Excellent" if exc else ""])
		"/weapon", "/left":
			# /weapon <nhóm> <số> [cấp] [exc]  vd: /weapon 0 19 13 exc ; /weapon off
			var hand: String = "right" if cmd == "/weapon" else "left"
			if parts.size() >= 2 and parts[1].to_lower() == "off":
				if player:
					player.equip(hand, 0, -1)
				return
			if parts.size() < 3:
				add_system_message("[color=red]Cú pháp: %s [nhóm 0-6] [số] [cấp] [exc]  |  %s off[/color]" % [cmd, cmd])
				return
			if player:
				var g := parts[1].to_int()
				var n := parts[2].to_int()
				var lv := parts[3].to_int() if parts.size() > 3 else 0
				var exc: bool = parts.size() > 4 and parts[4].to_lower().begins_with("exc")
				player.equip(hand, g, n, lv, exc)
				add_system_message("[color=green]Cầm: %s +%d[/color]" % [MuCatalogRes.item_name(g, n), lv])
		"/wing":
			# /wing <số> [cấp]  vd: /wing 5 ; /wing off
			if parts.size() < 2:
				add_system_message("[color=red]Cú pháp: /wing [số|off] [cấp][/color]")
				return
			if player:
				if parts[1].to_lower() == "off":
					player.equip("wings", 12, -1)
				else:
					var n := parts[1].to_int()
					player.equip("wings", 12, n, parts[2].to_int() if parts.size() > 2 else 0)
					add_system_message("[color=green]Đeo cánh: %s (ra khỏi thành để bay)[/color]" % MuCatalogRes.item_name(12, n))
		"/gm", "/gmpanel", "/banggm", "/buff":
			var hud = get_tree().get_first_node_in_group("HUD")
			if hud and hud.has_method("toggle_gm_panel"):
				hud.toggle_gm_panel()
				add_system_message("[color=gold]👑 GM: Đã mở Bảng Quản Trị GM (Buff Cấp & Reset)! Phím tắt: G hoặc F10.[/color]")
		"/item", "/items", "/laydo", "/box":
			var hud = get_tree().get_first_node_in_group("HUD")
			if hud and hud.has_method("toggle_item_picker"):
				hud.toggle_item_picker()
				add_system_message("[color=green]Đã mở Bảng Lấy Đồ (GM Item Box)![/color]")
		"/allskills", "/skills", "/allskill", "/skill", "/clearskills":
			if not player:
				add_system_message("[color=red]Lỗi: Không tìm thấy player![/color]")
				return
			var sub := parts[1].to_lower() if parts.size() > 1 else ""
			if cmd == "/clearskills" or sub == "clear" or sub == "reset":
				player.clear_learned_skills()
				add_system_message("[color=yellow]Đã đặt lại danh sách kỹ năng về mặc định![/color]")
			elif sub == "all" or sub == "full" or sub == "tatca":
				var n := player.learn_all_skills(true)
				add_system_message("[color=gold]⚡ GM: Đã cấp TOÀN BỘ %d kỹ năng của TẤT CẢ Class vào danh sách![/color]" % player.learned_skills.size())
			elif sub.is_valid_int():
				var sid := sub.to_int()
				var sk = MuCatalogRes.skill(sid)
				if sk.is_empty():
					add_system_message("[color=red]Không tìm thấy Skill ID %d![/color]" % sid)
				else:
					if not sid in player.learned_skills:
						player.learned_skills.append(sid)
						player._init_skills()
					player.set_active_skill("sk_%d" % sid)
					add_system_message("[color=lime]⚡ GM: Đã học & chọn Skill [%d] %s![/color]" % [sid, sk.get("name", "")])
			else:
				var class_names := ["Phù Thủy (DW)", "Chiến Binh (DK)", "Tiên Nữ (Elf)", "Đấu Sĩ (MG)", "Chúa Tể (DL)", "Thuật Sĩ (SUM)", "Thiết Binh (RF)"]
				var cname: String = class_names[player.char_class] if player.char_class >= 0 and player.char_class < class_names.size() else "Class %d" % player.char_class
				var n := player.learn_all_skills(false)
				add_system_message("[color=gold]⚡ GM: Đã mở khóa %d kỹ năng cho lớp %s![/color]" % [player.learned_skills.size(), cname])
				add_system_message("[color=cyan]Mẹo: Gõ /allskills all để học toàn bộ class, /skill <id> để học skill cụ thể, /clearskills để reset.[/color]")
		"/god", "/godmode", "/battu", "/infhp", "/infmana":
			if player:
				var active = player.toggle_god_mode()
				if active:
					add_system_message("[color=lime]🛡️ GM Bất Tử: ĐÃ BẬT (Không bao giờ hết Máu và Mana)![/color]")
				else:
					add_system_message("[color=yellow]🛡️ GM Bất Tử: ĐÃ TẮT.[/color]")
				var stats_win = get_tree().get_first_node_in_group("CharacterStatsWindow")
				if stats_win and stats_win.has_method("update_stats"):
					stats_win.update_stats()
		"/point", "/diem", "/addpoint":
			if parts.size() < 2:
				add_system_message("[color=red]Cú pháp: /point [số_điểm]  (vd: /point 1000)[/color]")
				return
			var amt = parts[1].to_int()
			if player and amt > 0:
				player.gm_add_points(amt)
				add_system_message("[color=gold]✨ GM: Đã cộng +%d Điểm Point nâng chỉ số (Hiện có: %d)![/color]" % [amt, player.stat_points])
				var stats_win = get_tree().get_first_node_in_group("CharacterStatsWindow")
				if stats_win and stats_win.has_method("update_stats"):
					stats_win.update_stats()
		"/addstr", "/str":
			if parts.size() < 2:
				add_system_message("[color=red]Cú pháp: /addstr [số_điểm]  (vd: /addstr 100)[/color]")
				return
			var amt = parts[1].to_int()
			if player and amt > 0:
				if player.add_stat_point("str", amt):
					add_system_message("[color=green]💪 Đã tăng +%d Sức Mạnh! (Hiện tại: %d, Còn lại: %d point)[/color]" % [amt, player.stat_str, player.stat_points])
					var stats_win = get_tree().get_first_node_in_group("CharacterStatsWindow")
					if stats_win and stats_win.has_method("update_stats"):
						stats_win.update_stats()
				else:
					add_system_message("[color=red]Không đủ điểm point (Hiện có: %d)! Gõ /point %d để nhận thêm.[/color]" % [player.stat_points, amt])
		"/addagi", "/agi":
			if parts.size() < 2:
				add_system_message("[color=red]Cú pháp: /addagi [số_điểm]  (vd: /addagi 100)[/color]")
				return
			var amt = parts[1].to_int()
			if player and amt > 0:
				if player.add_stat_point("agi", amt):
					add_system_message("[color=green]⚡ Đã tăng +%d Nhanh Nhẹn! (Hiện tại: %d, Còn lại: %d point)[/color]" % [amt, player.stat_agi, player.stat_points])
					var stats_win = get_tree().get_first_node_in_group("CharacterStatsWindow")
					if stats_win and stats_win.has_method("update_stats"):
						stats_win.update_stats()
				else:
					add_system_message("[color=red]Không đủ điểm point (Hiện có: %d)! Gõ /point %d để nhận thêm.[/color]" % [player.stat_points, amt])
		"/addvit", "/vit":
			if parts.size() < 2:
				add_system_message("[color=red]Cú pháp: /addvit [số_điểm]  (vd: /addvit 100)[/color]")
				return
			var amt = parts[1].to_int()
			if player and amt > 0:
				if player.add_stat_point("vit", amt):
					add_system_message("[color=green]❤️ Đã tăng +%d Thể Lực! (Hiện tại: %d, Còn lại: %d point)[/color]" % [amt, player.stat_vit, player.stat_points])
					var stats_win = get_tree().get_first_node_in_group("CharacterStatsWindow")
					if stats_win and stats_win.has_method("update_stats"):
						stats_win.update_stats()
				else:
					add_system_message("[color=red]Không đủ điểm point (Hiện có: %d)! Gõ /point %d để nhận thêm.[/color]" % [player.stat_points, amt])
		"/addene", "/ene":
			if parts.size() < 2:
				add_system_message("[color=red]Cú pháp: /addene [số_điểm]  (vd: /addene 100)[/color]")
				return
			var amt = parts[1].to_int()
			if player and amt > 0:
				if player.add_stat_point("ene", amt):
					add_system_message("[color=green]🔮 Đã tăng +%d Năng Lượng! (Hiện tại: %d, Còn lại: %d point)[/color]" % [amt, player.stat_ene, player.stat_points])
					var stats_win = get_tree().get_first_node_in_group("CharacterStatsWindow")
					if stats_win and stats_win.has_method("update_stats"):
						stats_win.update_stats()
				else:
					add_system_message("[color=red]Không đủ điểm point (Hiện có: %d)! Gõ /point %d để nhận thêm.[/color]" % [player.stat_points, amt])
		"/resetstats", "/taydiem":
			if player:
				player.reset_stat_points()
				add_system_message("[color=yellow]🔄 Đã tẩy điểm toàn bộ chỉ số! Hoàn lại %d điểm point.[/color]" % player.stat_points)
				var stats_win = get_tree().get_first_node_in_group("CharacterStatsWindow")
				if stats_win and stats_win.has_method("update_stats"):
					stats_win.update_stats()
		"/event", "/events", "/sukien", "/lich", "/time":
			var hud = get_tree().get_first_node_in_group("HUD")
			if hud and hud.has_method("toggle_event_schedule"):
				hud.toggle_event_schedule()
				add_system_message("[color=gold]📅 Đã mở Bảng Lịch Trình Sự Kiện (Events Schedule).[/color]")
			else:
				var dt := Time.get_datetime_dict_from_system()
				add_system_message("[color=gold]🕒 Giờ hệ thống hiện tại: %02d:%02d:%02d[/color]" % [int(dt.hour), int(dt.minute), int(dt.second)])
		"/startevent", "/sk", "/kichhoat":
			var mgr = get_tree().get_first_node_in_group("MuEventManager") if get_tree() else null
			if not mgr:
				add_system_message("[color=red]Chưa tìm thấy hệ thống MuEventManager.[/color]")
				return
			if parts.size() < 2:
				add_system_message("[color=yellow]Cú pháp: /startevent [bc | ds | cc | golden | white | skull | dragon | crywolf | kanturu][/color]")
				return
			var target_ev = parts[1].to_lower()
			var map_names := {
				"bc": "blood_castle",
				"blood": "blood_castle",
				"ds": "devil_square",
				"devil": "devil_square",
				"cc": "chaos_castle",
				"chaos": "chaos_castle",
				"golden": "golden_invasion",
				"rongvang": "golden_invasion",
				"white": "white_wizard",
				"phuthuy": "white_wizard",
				"skull": "skeleton_king",
				"xuong": "skeleton_king",
				"dragon": "red_dragon",
				"rongdo": "red_dragon",
				"crywolf": "crywolf",
				"kanturu": "kanturu"
			}
			var eid: String = map_names.get(target_ev, target_ev)
			if mgr.has_method("force_start_event") and mgr.force_start_event(eid, 300):
				add_system_message("[color=gold]⚡ GM: Đã kích hoạt khẩn cấp sự kiện '%s' thành công (mở cổng 5 phút)![/color]" % eid)
			else:
				add_system_message("[color=red]Không tìm thấy sự kiện '%s'. Các mã hợp lệ: bc, ds, cc, golden, white, skull, dragon, crywolf, kanturu[/color]" % target_ev)
		"/help":
			add_system_message("[color=yellow]Lệnh Game: /event (Bảng Lịch Sự Kiện), /startevent [bc|ds|cc|golden...] (Kích hoạt test sự kiện), /gm, /level [cấp], /reset [số_lần], /god, /point [số], /addstr, /addagi, /addvit, /addene, /resetstats, /allskills, /item, /map [id], /zen, /help[/color]")
		_:
			add_system_message("[color=red]Lệnh không xác định: %s. Gõ /help để xem hướng dẫn.[/color]" % cmd)
