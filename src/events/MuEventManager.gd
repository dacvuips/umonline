extends Node
class_name MuEventManager

## Quản lý Lịch Trình Sự Kiện MU Online (Event Scheduler & Manager) Chuẩn Game Gốc Webzen:
## - Blood Castle (Lâu Đài Máu): Mỗi 2 giờ vào các giờ chẵn (00:00, 02:00, 04:00...)
## - Devil Square (Quảng Trường Quỷ): Mỗi 2 giờ vào các giờ lẻ (01:00, 03:00, 05:00...)
## - Chaos Castle (Hỗn Nguyên Lâu): Mỗi 2 giờ vào các giờ lẻ (01:00, 03:00, 05:00...)
## - Golden Dragon Invasion (Binh Đoàn Hoàng Kim): Các giờ chẵn lúc 00:00
## - White Wizard Invasion (Phù Thủy Trắng & Binh Đoàn Orc): Các giờ lẻ lúc 00:00
## - Skeleton King (Vua Xương Lorencia): Các giờ chẵn lúc :30
## - Red Dragon (Rồng Đỏ Tấn Công): Các giờ lẻ lúc :30
## - Pháo Đài Crywolf: 20:00 hàng ngày
## - Tháp Kanturu (Maya & Nightmare): 04:00, 08:00, 12:00, 16:00, 20:00, 00:00
## - Đền Ảo Ảnh (Illusion Temple): 02:30, 06:30, 10:30, 14:30, 18:30, 22:30
## Tự động tính toán theo đồng hồ thực của hệ thống (OS Local Time) và phát thông báo toàn server!

signal event_state_changed(event_id: String, new_state: String, data: Dictionary)
signal broadcast_notice(title: String, message: String, banner_text: String, alert_color: Color)

static var instance: MuEventManager = null

const EVENTS_CONFIG := {
	"blood_castle": {
		"id": "blood_castle",
		"name": "Blood Castle (Lâu Đài Máu)",
		"short_name": "Blood Castle",
		"icon": "🩸",
		"hours": [0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22],
		"minute": 0,
		"open_mins": 5,
		"duration_mins": 15,
		"level_req": "Cấp 15 ~ 400 (Master)",
		"item_req": "Áo Tàng Hình (Invisibility Cloak +1..+8)",
		"npc": "Linh Mục Thiên Sứ (Church/Devias)",
		"desc": "Vượt Cầu Xương Máu, công phá Cổng Thành, tiêu diệt Phù Thủy và hoàn trả Vũ Khí Tuyệt Mệnh cho Thiên Sứ.",
		"color": Color(1.0, 0.45, 0.45),
		"teleport_target": "devias"
	},
	"devil_square": {
		"id": "devil_square",
		"name": "Devil Square (Quảng Trường Quỷ)",
		"short_name": "Devil Square",
		"icon": "😈",
		"hours": [1, 3, 5, 7, 9, 11, 13, 15, 17, 19, 21, 23],
		"minute": 0,
		"open_mins": 5,
		"duration_mins": 20,
		"level_req": "Cấp 15 ~ 400 (Master)",
		"item_req": "Thiệp Mời Quỷ (Devil's Invitation +1..+7)",
		"npc": "Charon tại Noria (171, 105)",
		"desc": "Đấu trường sinh tử tiêu diệt hàng ngàn quái vật quỷ dữ dồn dập trong 20 phút.",
		"color": Color(1.0, 0.65, 0.3),
		"teleport_target": "noria"
	},
	"chaos_castle": {
		"id": "chaos_castle",
		"name": "Chaos Castle (Hỗn Nguyên Lâu)",
		"short_name": "Chaos Castle",
		"icon": "🏰",
		"hours": [1, 3, 5, 7, 9, 11, 13, 15, 17, 19, 21, 23],
		"minute": 0,
		"open_mins": 5,
		"duration_mins": 10,
		"level_req": "Cấp 15 ~ 400 (Master)",
		"item_req": "Áo Giáp Vệ Binh (Armor of Guardsman +1..+7)",
		"npc": "Chuột phải vào Áo Giáp Vệ Binh khi đến giờ",
		"desc": "Chiến trường sinh tồn không phân biệt đồng đội. Người sống sót duy nhất nhận Đồ Thần Cổ Đại.",
		"color": Color(0.85, 0.65, 1.0),
		"teleport_target": "none"
	},
	"golden_invasion": {
		"id": "golden_invasion",
		"name": "Golden Invasion (Binh Đoàn Hoàng Kim)",
		"short_name": "Rồng Vàng Tấn Công",
		"icon": "🐉",
		"hours": [0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22],
		"minute": 0,
		"open_mins": 0,
		"duration_mins": 20,
		"level_req": "Mọi cấp độ",
		"item_req": "Không yêu cầu",
		"npc": "Lorencia, Noria, Devias, Atlans, Tarkan",
		"desc": "Binh đoàn Rồng Vàng đổ bộ tàn phá lục địa MU, săn lùng để nhặt Hộp May Mắn (Box of Kundun +1..+5).",
		"color": Color(1.0, 0.88, 0.2),
		"teleport_target": "lorencia"
	},
	"white_wizard": {
		"id": "white_wizard",
		"name": "White Wizard (Phù Thủy Trắng & Orc)",
		"short_name": "Phù Thủy Trắng",
		"icon": "🧙",
		"hours": [1, 3, 5, 7, 9, 11, 13, 15, 17, 19, 21, 23],
		"minute": 0,
		"open_mins": 0,
		"duration_mins": 15,
		"level_req": "Mọi cấp độ",
		"item_req": "Không yêu cầu",
		"npc": "Ngoại ô Lorencia, Noria, Devias",
		"desc": "Phù Thủy Trắng dẫn đầu binh đoàn Orc xâm chiếm vùng ngoại thành. Tiêu diệt để nhận Nhẫn Phù Thủy & Ngọc Bless.",
		"color": Color(0.9, 0.95, 1.0),
		"teleport_target": "lorencia"
	},
	"skeleton_king": {
		"id": "skeleton_king",
		"name": "Skeleton King (Vua Xương Lorencia)",
		"short_name": "Vua Xương",
		"icon": "💀",
		"hours": [0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22],
		"minute": 30,
		"open_mins": 0,
		"duration_mins": 15,
		"level_req": "Mọi cấp độ",
		"item_req": "Không yêu cầu",
		"npc": "Ngoại ô Lorencia (Vùng sa mạc)",
		"desc": "Chúa tể xương thức giấc cùng đội quân bộ xương quỷ tấn công Lorencia.",
		"color": Color(0.8, 0.8, 0.8),
		"teleport_target": "lorencia"
	},
	"red_dragon": {
		"id": "red_dragon",
		"name": "Red Dragon Invasion (Rồng Đỏ Tấn Công)",
		"short_name": "Rồng Đỏ",
		"icon": "🔥",
		"hours": [1, 3, 5, 7, 9, 11, 13, 15, 17, 19, 21, 23],
		"minute": 30,
		"open_mins": 0,
		"duration_mins": 15,
		"level_req": "Mọi cấp độ",
		"item_req": "Không yêu cầu",
		"npc": "Lorencia, Noria, Devias",
		"desc": "Bầy Rồng Đỏ bay lượn trên không trung thiêu đốt các làng mạc. Rơi nhiều Ngọc quý và Zen.",
		"color": Color(1.0, 0.35, 0.2),
		"teleport_target": "lorencia"
	},
	"crywolf": {
		"id": "crywolf",
		"name": "Crywolf Fortress (Pháo Đài Sói)",
		"short_name": "Pháo Đài Crywolf",
		"icon": "🐺",
		"hours": [20],
		"minute": 0,
		"open_mins": 5,
		"duration_mins": 25,
		"level_req": "Cấp 350+",
		"item_req": "Hợp Đồng Triệu Hồi Crywolf",
		"npc": "Pháo Đài Crywolf (Tượng Sói Thần)",
		"desc": "Bảo vệ Tượng Sói Thần khỏi Quân Đoàn Balgass. Thắng lợi tăng +10% EXP toàn máy chủ!",
		"color": Color(0.6, 0.95, 0.6),
		"teleport_target": "none"
	},
	"kanturu": {
		"id": "kanturu",
		"name": "Kanturu Event (Tháp Kanturu - Maya)",
		"short_name": "Tháp Kanturu",
		"icon": "🌙",
		"hours": [0, 4, 8, 12, 16, 20],
		"minute": 0,
		"open_mins": 5,
		"duration_mins": 30,
		"level_req": "Cấp 300+",
		"item_req": "Dây Chuyền Mặt Trăng (Moonstone)",
		"npc": "Cửa vào Trụ Sở Maya (Kanturu 3)",
		"desc": "Công phá Căn Cứ Thí Nghiệm Kanturu, đánh bại Bàn Tay Maya và Chúa Tể Ác Mộng Nightmare.",
		"color": Color(0.4, 0.85, 1.0),
		"teleport_target": "none"
	},
	"illusion_temple": {
		"id": "illusion_temple",
		"name": "Illusion Temple (Đền Ảo Ảnh)",
		"short_name": "Đền Ảo Ảnh",
		"icon": "🔮",
		"hours": [2, 6, 10, 14, 18, 22],
		"minute": 30,
		"open_mins": 5,
		"duration_mins": 15,
		"level_req": "Cấp 220+",
		"item_req": "Huyết Kính Ấn (Scroll of Blood +1..+6)",
		"npc": "NPC Mirage tại Lorencia/Devias",
		"desc": "Chiến trường đối kháng 5vs5 tranh đoạt Tượng Thánh giữa Phe Ánh Sáng và Bóng Tối.",
		"color": Color(0.9, 0.6, 1.0),
		"teleport_target": "none"
	}
}

# Lưu vết các mốc thông báo trong chu kỳ hiện tại để tránh spam
var _notified_cycles: Dictionary = {}
var _forced_events: Dictionary = {}
var _update_timer: float = 0.0

func _ready() -> void:
	name = "MuEventManager"
	instance = self
	add_to_group("MuEventManager")
	_suppress_initial_notifications()

## Đánh dấu bỏ qua còi báo động cho các sự kiện đang diễn ra sẵn khi vừa đăng nhập game
func _suppress_initial_notifications() -> void:
	var dt := Time.get_datetime_dict_from_system()
	var cur_h: int = int(dt.get("hour", 0))
	var cur_m: int = int(dt.get("minute", 0))
	var cur_s: int = int(dt.get("second", 0))
	var cur_total_sec := cur_h * 3600 + cur_m * 60 + cur_s

	for eid in EVENTS_CONFIG:
		var cfg: Dictionary = EVENTS_CONFIG[eid]
		var hours: Array = cfg.get("hours", [])
		var target_m: int = int(cfg.get("minute", 0))
		var open_mins: int = int(cfg.get("open_mins", 5))
		var dur_mins: int = int(cfg.get("duration_mins", 15))

		for h in hours:
			var event_start_sec := int(h) * 3600 + target_m * 60
			var open_end_sec := event_start_sec + open_mins * 60
			var event_end_sec := event_start_sec + (open_mins + dur_mins) * 60

			var cycle_key := "%s_%02d_%02d" % [eid, h, target_m]
			if not _notified_cycles.has(cycle_key):
				_notified_cycles[cycle_key] = {}
			var notified: Dictionary = _notified_cycles[cycle_key]

			var diff_to_start := event_start_sec - cur_total_sec
			if int(h) == 0 and target_m == 0 and cur_h == 23:
				diff_to_start = (24 * 3600) - cur_total_sec

			if diff_to_start > 0:
				if diff_to_start <= 300:
					notified["notice_5m"] = true
				if diff_to_start <= 180:
					notified["notice_3m"] = true
				if diff_to_start <= 60:
					notified["notice_1m"] = true

			if open_mins > 0:
				if cur_total_sec >= event_start_sec and cur_total_sec < open_end_sec:
					notified["gate_opened"] = true
				elif cur_total_sec >= open_end_sec and cur_total_sec < event_end_sec:
					notified["gate_opened"] = true
					notified["gate_closed"] = true
				elif cur_total_sec >= event_end_sec and cur_total_sec < event_end_sec + 60:
					notified["event_ended"] = true
			else:
				if cur_total_sec >= event_start_sec and cur_total_sec < event_end_sec:
					notified["invasion_started"] = true
				elif cur_total_sec >= event_end_sec and cur_total_sec < event_end_sec + 60:
					notified["invasion_ended"] = true

func _process(delta: float) -> void:
	_update_timer += delta
	# Kiểm tra logic mỗi giây 1 lần
	if _update_timer >= 1.0:
		_update_timer = 0.0
		_check_all_events()

## Kiểm tra trạng thái và lịch trình của toàn bộ sự kiện theo thời gian thực
func _check_all_events() -> void:
	var dt := Time.get_datetime_dict_from_system()
	var cur_h: int = int(dt.get("hour", 0))
	var cur_m: int = int(dt.get("minute", 0))
	var cur_s: int = int(dt.get("second", 0))

	for eid in EVENTS_CONFIG:
		_evaluate_event(eid, cur_h, cur_m, cur_s)

## Đánh giá một sự kiện cụ thể
func _evaluate_event(eid: String, cur_h: int, cur_m: int, cur_s: int) -> void:
	var cfg: Dictionary = EVENTS_CONFIG[eid]
	var hours: Array = cfg.get("hours", [])
	var target_m: int = int(cfg.get("minute", 0))
	var open_mins: int = int(cfg.get("open_mins", 5))
	var dur_mins: int = int(cfg.get("duration_mins", 15))

	# Kiểm tra nếu đang có chế độ kích hoạt khẩn cấp (Force Start)
	if _forced_events.has(eid):
		var forced: Dictionary = _forced_events[eid]
		forced["remaining_seconds"] -= 1
		if forced["remaining_seconds"] <= 0:
			_forced_events.erase(eid)
			_broadcast_event_ended(cfg)
		return

	# Duyệt qua các mốc giờ để xác định trạng thái hiện tại hoặc mốc gần nhất
	var cur_total_sec := cur_h * 3600 + cur_m * 60 + cur_s

	# 1. Kiểm tra xem sự kiện có ĐANG DIỄN RA ở mốc giờ nào trong ngày không
	for h in hours:
		var event_start_sec := int(h) * 3600 + target_m * 60
		var open_end_sec := event_start_sec + open_mins * 60
		var event_end_sec := event_start_sec + (open_mins + dur_mins) * 60

		var cycle_key := "%s_%02d_%02d" % [eid, h, target_m]
		if not _notified_cycles.has(cycle_key):
			_notified_cycles[cycle_key] = {}

		var notified: Dictionary = _notified_cycles[cycle_key]

		# A. Giai đoạn Báo Trước (5 phút, 3 phút, 1 phút)
		var diff_to_start := event_start_sec - cur_total_sec
		# Xử lý trường hợp cận ngày (mốc 00:00 mà hiện tại là 23:55)
		if int(h) == 0 and target_m == 0 and cur_h == 23:
			diff_to_start = (24 * 3600) - cur_total_sec

		if diff_to_start > 0:
			if diff_to_start <= 300 and diff_to_start > 290 and not notified.get("notice_5m", false):
				notified["notice_5m"] = true
				_broadcast_event_warning(cfg, 5)
			elif diff_to_start <= 180 and diff_to_start > 170 and not notified.get("notice_3m", false):
				notified["notice_3m"] = true
				_broadcast_event_warning(cfg, 3)
			elif diff_to_start <= 60 and diff_to_start > 50 and not notified.get("notice_1m", false):
				notified["notice_1m"] = true
				_broadcast_event_warning(cfg, 1)

		# B. Giai đoạn Mở Cửa (Gate Open) - chỉ với sự kiện có cổng (open_mins > 0)
		if open_mins > 0:
			if cur_total_sec >= event_start_sec and cur_total_sec < open_end_sec:
				if not notified.get("gate_opened", false):
					notified["gate_opened"] = true
					_broadcast_gate_opened(cfg)
				return # Đang trong trạng thái mở
			elif cur_total_sec >= open_end_sec and cur_total_sec < event_end_sec:
				if not notified.get("gate_closed", false):
					notified["gate_closed"] = true
					_broadcast_event_started(cfg)
				return # Đang trong trạng thái chạy
			elif cur_total_sec >= event_end_sec and cur_total_sec < event_end_sec + 20:
				if not notified.get("event_ended", false):
					notified["event_ended"] = true
					_broadcast_event_ended(cfg)
		else:
			# Với sự kiện Invasion (Quái tấn công, không có cổng)
			if cur_total_sec >= event_start_sec and cur_total_sec < event_end_sec:
				if not notified.get("invasion_started", false):
					notified["invasion_started"] = true
					_broadcast_invasion_started(cfg)
				return
			elif cur_total_sec >= event_end_sec and cur_total_sec < event_end_sec + 20:
				if not notified.get("invasion_ended", false):
					notified["invasion_ended"] = true
					_broadcast_event_ended(cfg)

	# Dọn bớt cache chu kỳ cũ khi cache quá lớn
	if _notified_cycles.size() > 500:
		_notified_cycles.clear()

## Lấy thông tin trạng thái chi tiết của tất cả sự kiện (Dùng cho Bảng Lịch Sự Kiện)
func get_all_events_status() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var dt := Time.get_datetime_dict_from_system()
	var cur_h: int = int(dt.get("hour", 0))
	var cur_m: int = int(dt.get("minute", 0))
	var cur_s: int = int(dt.get("second", 0))
	var cur_total_sec := cur_h * 3600 + cur_m * 60 + cur_s

	for eid in EVENTS_CONFIG:
		var cfg: Dictionary = EVENTS_CONFIG[eid]
		var info: Dictionary = _calculate_event_info(cfg, cur_h, cur_m, cur_s, cur_total_sec)
		result.append(info)

	# Sắp xếp: Đang mở (open) lên đầu -> Đang diễn ra (running) -> Sắp mở gần nhất (waiting)
	result.sort_custom(func(a: Dictionary, b: Dictionary):
		var priority_a := 0
		var priority_b := 0
		if a["state"] == "open": priority_a = 3
		elif a["state"] == "running": priority_a = 2
		else: priority_a = 1

		if b["state"] == "open": priority_b = 3
		elif b["state"] == "running": priority_b = 2
		else: priority_b = 1

		if priority_a != priority_b:
			return priority_a > priority_b
		return int(a["seconds_left"]) < int(b["seconds_left"])
	)

	return result

func _calculate_event_info(cfg: Dictionary, cur_h: int, cur_m: int, cur_s: int, cur_total_sec: int) -> Dictionary:
	var eid: String = cfg["id"]
	var hours: Array = cfg.get("hours", [])
	var target_m: int = int(cfg.get("minute", 0))
	var open_mins: int = int(cfg.get("open_mins", 5))
	var dur_mins: int = int(cfg.get("duration_mins", 15))

	# Kiểm tra nếu đang bị kích hoạt khẩn cấp (GM Force)
	if _forced_events.has(eid):
		var rem: int = int(_forced_events[eid].get("remaining_seconds", 300))
		return {
			"id": eid,
			"name": cfg["name"],
			"short_name": cfg["short_name"],
			"icon": cfg["icon"],
			"color": cfg["color"],
			"state": "open",
			"state_label": "🟢 ĐANG MỞ CỬA (GM)",
			"seconds_left": rem,
			"time_str": _format_duration(rem),
			"next_time_str": "NGAY BÂY GIỜ",
			"level_req": cfg["level_req"],
			"item_req": cfg["item_req"],
			"npc": cfg["npc"],
			"desc": cfg["desc"],
			"teleport_target": cfg.get("teleport_target", "none")
		}

	# 1. Kiểm tra xem sự kiện có đang OPEN hoặc RUNNING không
	for h in hours:
		var event_start_sec := int(h) * 3600 + target_m * 60
		var open_end_sec := event_start_sec + open_mins * 60
		var event_end_sec := event_start_sec + (open_mins + dur_mins) * 60

		if open_mins > 0:
			if cur_total_sec >= event_start_sec and cur_total_sec < open_end_sec:
				var rem := open_end_sec - cur_total_sec
				return {
					"id": eid,
					"name": cfg["name"],
					"short_name": cfg["short_name"],
					"icon": cfg["icon"],
					"color": cfg["color"],
					"state": "open",
					"state_label": "🟢 ĐANG MỞ CỔNG",
					"seconds_left": rem,
					"time_str": _format_duration(rem),
					"next_time_str": "%02d:%02d" % [h, target_m],
					"level_req": cfg["level_req"],
					"item_req": cfg["item_req"],
					"npc": cfg["npc"],
					"desc": cfg["desc"],
					"teleport_target": cfg.get("teleport_target", "none")
				}
			elif cur_total_sec >= open_end_sec and cur_total_sec < event_end_sec:
				var rem := event_end_sec - cur_total_sec
				return {
					"id": eid,
					"name": cfg["name"],
					"short_name": cfg["short_name"],
					"icon": cfg["icon"],
					"color": cfg["color"],
					"state": "running",
					"state_label": "🟡 ĐANG DIỄN RA",
					"seconds_left": rem,
					"time_str": _format_duration(rem),
					"next_time_str": "%02d:%02d" % [h, target_m],
					"level_req": cfg["level_req"],
					"item_req": cfg["item_req"],
					"npc": cfg["npc"],
					"desc": cfg["desc"],
					"teleport_target": cfg.get("teleport_target", "none")
				}
		else:
			if cur_total_sec >= event_start_sec and cur_total_sec < event_end_sec:
				var rem := event_end_sec - cur_total_sec
				return {
					"id": eid,
					"name": cfg["name"],
					"short_name": cfg["short_name"],
					"icon": cfg["icon"],
					"color": cfg["color"],
					"state": "running",
					"state_label": "🔥 ĐANG TẤN CÔNG",
					"seconds_left": rem,
					"time_str": _format_duration(rem),
					"next_time_str": "%02d:%02d" % [h, target_m],
					"level_req": cfg["level_req"],
					"item_req": cfg["item_req"],
					"npc": cfg["npc"],
					"desc": cfg["desc"],
					"teleport_target": cfg.get("teleport_target", "none")
				}

	# 2. Tìm mốc diễn ra tiếp theo trong tương lai gần nhất
	var min_diff: int = 9999999
	var next_h: int = -1
	for h in hours:
		var event_start_sec := int(h) * 3600 + target_m * 60
		var diff := event_start_sec - cur_total_sec
		if diff < 0:
			diff += 24 * 3600 # Sang ngày hôm sau
		if diff < min_diff:
			min_diff = diff
			next_h = int(h)

	return {
		"id": eid,
		"name": cfg["name"],
		"short_name": cfg["short_name"],
		"icon": cfg["icon"],
		"color": cfg["color"],
		"state": "waiting",
		"state_label": "⚪ CHỜ MỞ",
		"seconds_left": min_diff,
		"time_str": _format_duration(min_diff),
		"next_time_str": "%02d:%02d" % [next_h, target_m],
		"level_req": cfg["level_req"],
		"item_req": cfg["item_req"],
		"npc": cfg["npc"],
		"desc": cfg["desc"],
		"teleport_target": cfg.get("teleport_target", "none")
	}

func _format_duration(sec: int) -> String:
	var h := sec / 3600
	var m := (sec % 3600) / 60
	var s := sec % 60
	if h > 0:
		return "%02d:%02d:%02d" % [h, m, s]
	return "%02d:%02d" % [m, s]

# ==================== PHÁT THÔNG BÁO HỆ THỐNG (SYSTEM NOTICES) ====================

## Báo trước sự kiện 5 phút, 3 phút hoặc 1 phút
func _broadcast_event_warning(cfg: Dictionary, mins_left: int) -> void:
	var s_name: String = cfg["short_name"]
	var icon: String = cfg["icon"]
	var item_req: String = cfg["item_req"]
	var npc: String = cfg["npc"]

	var chat_msg := "[color=gold][b][HỆ THỐNG][/b][/color] [color=#00FFFF][%s][/color] [color=#FFD700]Còn %d phút nữa Cổng %s sẽ mở! Các chiến binh hãy chuẩn bị: %s.[/color]" % [s_name, mins_left, s_name, item_req]
	var banner_msg := "[color=#FFD700]📢 [THÔNG BÁO] %s Còn %d phút nữa Cổng %s sẽ mở cửa! Các chiến binh hãy chuẩn bị: %s và tới gặp %s![/color]" % [icon, mins_left, s_name, item_req, npc]

	_send_broadcast(chat_msg, banner_msg, Color(1.0, 0.85, 0.3))
	# Đã tắt còi báo động theo yêu cầu người dùng

## Thông báo Cổng Sự Kiện chính thức mở cửa
func _broadcast_gate_opened(cfg: Dictionary) -> void:
	var s_name: String = cfg["short_name"]
	var icon: String = cfg["icon"]
	var open_mins: int = cfg["open_mins"]
	var npc: String = cfg["npc"]

	var chat_msg := "[color=gold][b][HỆ THỐNG][/b][/color] [color=#00FF66][MỞ CỬA][/color] [color=#FFE066]CỔNG %s ĐÃ MỞ! Thời gian vào cửa: %d phút. Hãy nhanh chân đến gặp: %s![/color]" % [s_name.to_upper(), open_mins, npc]
	var banner_msg := "[color=#FFE600]⚡ [MỞ CỔNG] %s CỔNG %s ĐÃ CHÍNH THỨC MỞ CỬA! Thời gian vào cửa: %d phút. Hãy nhanh chân đến gặp: %s![/color]" % [icon, s_name.to_upper(), open_mins, npc]

	_send_broadcast(chat_msg, banner_msg, Color(0.3, 1.0, 0.5))
	emit_signal("event_state_changed", cfg.get("id", ""), "open", cfg)
	# Đã tắt còi báo động theo yêu cầu người dùng

## Thông báo Cổng đóng và Sự kiện bắt đầu chiến đấu
func _broadcast_event_started(cfg: Dictionary) -> void:
	var s_name: String = cfg["short_name"]
	var icon: String = cfg["icon"]
	var dur_mins: int = cfg["duration_mins"]

	var chat_msg := "[color=gold][b][HỆ THỐNG][/b][/color] [color=#FF6666][CHIẾN ĐẤU][/color] [color=#FFCC00]Cổng %s đã đóng! Đấu trường sinh tử chính thức bắt đầu trong %d phút. Chúc các chiến binh may mắn![/color]" % [s_name, dur_mins]
	var banner_msg := "[color=#FFCC00]⚔️ [CHIẾN ĐẤU] %s Cổng %s đã đóng! Đấu trường sinh tử chính thức bắt đầu trong %d phút. Chúc các chiến binh chiến đấu dũng cảm![/color]" % [icon, s_name, dur_mins]

	_send_broadcast(chat_msg, banner_msg, Color(1.0, 0.5, 0.3))
	emit_signal("event_state_changed", cfg.get("id", ""), "running", cfg)

## Thông báo Binh đoàn quái vật xâm lăng (Invasion)
func _broadcast_invasion_started(cfg: Dictionary) -> void:
	var s_name: String = cfg["short_name"]
	var icon: String = cfg["icon"]
	var npc: String = cfg["npc"]

	var chat_msg := "[color=gold][b][HỆ THỐNG][/b][/color] [color=#FF3300][XÂM LĂNG][/color] [color=#FFDD44]%s ĐÃ XUẤT HIỆN TẤN CÔNG LỤC ĐỊA MU! Vị trí: %s. Các dũng sĩ hãy cùng nhau nghênh chiến![/color]" % [s_name.to_upper(), npc]
	var banner_msg := "[color=#FFD700]🔥 [BÁO ĐỘNG] %s %s ĐÃ ĐỔ BỘ TẤN CÔNG LỤC ĐỊA MU! Vị trí xuất hiện: %s. Các chiến binh hãy cùng nhau tiêu diệt quái vật![/color]" % [icon, s_name.to_upper(), npc]

	_send_broadcast(chat_msg, banner_msg, Color(1.0, 0.4, 0.2))
	emit_signal("event_state_changed", cfg.get("id", ""), "running", cfg)
	# Đã tắt còi báo động theo yêu cầu người dùng

## Thông báo sự kiện kết thúc
func _broadcast_event_ended(cfg: Dictionary) -> void:
	var s_name: String = cfg["short_name"]
	var icon: String = cfg["icon"]

	var chat_msg := "[color=gold][b][HỆ THỐNG][/b][/color] [color=#AAAAAA][KẾT THÚC][/color] [color=#DDDDDD]Sự kiện %s đã kết thúc. Cảm ơn các dũng sĩ đã tham gia chiến đấu![/color]" % s_name
	var banner_msg := "[color=#E6D278]🛡️ [KẾT THÚC] %s Sự kiện %s đã kết thúc. Cảm ơn các dũng sĩ đã tham gia chiến đấu![/color]" % [icon, s_name]

	_send_broadcast(chat_msg, banner_msg, Color(0.8, 0.8, 0.8))
	emit_signal("event_state_changed", cfg.get("id", ""), "ended", cfg)
	# Đã tắt còi báo động theo yêu cầu người dùng

## Gửi thông báo đến ChatWindow và Banner trên màn hình
func _send_broadcast(chat_bbcode: String, banner_bbcode: String, color: Color) -> void:
	# 1. Bắn vào khung chat hệ thống
	var chat = get_tree().get_first_node_in_group("ChatWindow") if get_tree() else null
	if chat and chat.has_method("add_system_message"):
		chat.add_system_message(chat_bbcode)

	# 2. Bắn lên Banner viền vàng đỉnh màn hình (Golden Server Notice)
	var hud = get_tree().get_first_node_in_group("HUD") if get_tree() else null
	if hud and hud.has_method("show_golden_notice"):
		hud.show_golden_notice(banner_bbcode)

	emit_signal("broadcast_notice", "Thông Báo Sự Kiện", chat_bbcode, banner_bbcode, color)

## Kiểm tra sự kiện có đang diễn ra hay không (open hoặc running hoặc forced)
func is_event_active(event_id: String) -> bool:
	if _forced_events.has(event_id):
		return true
	var info := get_event_info(event_id)
	return info.get("state", "") in ["open", "running"]

## Lấy thông tin trạng thái một sự kiện cụ thể
func get_event_info(event_id: String) -> Dictionary:
	if not EVENTS_CONFIG.has(event_id):
		return {}
	var dt := Time.get_datetime_dict_from_system()
	var cur_h: int = int(dt.get("hour", 0))
	var cur_m: int = int(dt.get("minute", 0))
	var cur_s: int = int(dt.get("second", 0))
	var cur_total_sec := cur_h * 3600 + cur_m * 60 + cur_s
	return _calculate_event_info(EVENTS_CONFIG[event_id], cur_h, cur_m, cur_s, cur_total_sec)

## Kích hoạt khẩn cấp sự kiện để test ngay lập tức (Lệnh GM / Debug)
func force_start_event(event_id: String, duration_sec: int = 300) -> bool:
	if not EVENTS_CONFIG.has(event_id):
		return false
	var cfg: Dictionary = EVENTS_CONFIG[event_id]
	_forced_events[event_id] = {
		"remaining_seconds": duration_sec
	}
	if int(cfg.get("open_mins", 5)) == 0:
		_broadcast_invasion_started(cfg)
	else:
		_broadcast_gate_opened(cfg)
	return true
