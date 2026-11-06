extends Control
class_name ChatWindow

# nạp trực tiếp (không phụ thuộc bộ nhớ đệm class_name của editor)
const MuCatalogRes = preload("res://src/mu/MuCatalog.gd")

## Hệ thống Khung Chat & Lệnh GM/Di chuyển (Chat & Command Console) chuẩn 100% MU Online
## Tích hợp thanh chuyển kênh (Normal, Party, Guild, Whisper, System) và khung viền kim loại

@onready var chat_history: RichTextLabel = $VBoxContainer/ChatHistory
@onready var chat_input: LineEdit = $VBoxContainer/InputContainer/ChatInput if has_node("VBoxContainer/InputContainer/ChatInput") else ($VBoxContainer/ChatInput if has_node("VBoxContainer/ChatInput") else null)

var player: MuPlayer = null

func _ready() -> void:
	add_to_group("ChatWindow")   # người chơi gửi thông báo hệ thống (học skill...)
	if chat_input:
		chat_input.text_submitted.connect(_on_text_submitted)

	add_system_message("[color=gold]Chào mừng Hiệp Sĩ đến với Lục Địa MU Online (Godot Edition)![/color]")
	add_system_message("[color=cyan]Mẹo: Gõ /map (danh sách bản đồ), /map devias, /zen 50000 hoặc /level 10[/color]")

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
	var sender_name = player.character_name if player else "testgmDk"
	add_system_message("[b]%s:[/b] %s" % [sender_name, msg])

	if player:
		_show_player_bubble(msg)

func _show_player_bubble(msg: String) -> void:
	var bubble = preload("res://src/ui/ChatBubble.gd").new()
	player.add_child(bubble)
	bubble.show_chat(msg)

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
		"/move", "/map":
			# /map            -> danh sách bản đồ đã chuyển
			# /map 3 | devias -> sang bản đồ (WorldN của client gốc)
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
		"/zen":
			if parts.size() < 2:
				add_system_message("[color=red]Cú pháp: /zen [số_lượng][/color]")
				return
			var amount = parts[1].to_int()
			if player and amount > 0:
				player.zen += amount
				add_system_message("[color=yellow]Đã nhận thêm %d Zen thành công![/color]" % amount)
		"/level":
			if parts.size() < 2:
				add_system_message("[color=red]Cú pháp: /level [cấp_độ][/color]")
				return
			var lvl = parts[1].to_int()
			if player and lvl > 0:
				player.level = lvl
				player.max_hp = 100 + player.level * 15
				player.current_hp = player.max_hp
				player.hp_changed.emit(player.current_hp, player.max_hp)
				add_system_message("[color=yellow]Đã thiết lập cấp độ thành: Lv. %d![/color]" % lvl)
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
		"/item", "/items", "/laydo", "/box", "/gm":
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
		"/help":
			add_system_message("[color=yellow]Danh sách lệnh: /god (bất tử HP/MP), /point [số] (nhận point), /addstr, /addagi, /addvit, /addene, /resetstats (tẩy điểm), /allskills [all|clear|<id>], /clearskills, /item (kho lấy đồ), /map [số|tên], /zen [số], /level [cấp], /class [dw|dk|elf|mg|dl|sum|rf], /set [số] [cấp] [exc], /weapon ..., /wing [số], /help[/color]")
		_:
			add_system_message("[color=red]Lệnh không xác định: %s. Gõ /help để xem hướng dẫn.[/color]" % cmd)
