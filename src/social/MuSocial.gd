extends Node
class_name MuSocial

## Hệ thống xã hội phía client: Tổ đội, Guild (liên minh / thù địch), Bạn bè, Quyết đấu, Cửa hàng cá nhân.
## Luật lấy từ Source gốc (UI/HUD/CommandWindow.cpp, UI/Party, Guild/GuildInfoWindow.cpp, UI/Combat/DuelWindow.cpp)
## và server OpenMU (DuelRoom.cs: thắng khi đạt 10 điểm). Vì client chạy offline, "server" ở đây là
## các người chơi mô phỏng (MuOtherPlayer) tự trả lời lời mời.
## Guild + bạn bè lưu vào user://mu_social_<tên nhân vật>.json ; tổ đội / quyết đấu chỉ trong phiên (như game gốc).

signal party_changed
signal guild_changed
signal friends_changed
signal duel_changed

const MAX_PARTY := 5
const DUEL_LEVEL := 30
const DUEL_MAX_SCORE := 10
const GUILD_CREATE_LEVEL := 100

var hero: MuPlayer = null

# ---- tổ đội: tên thành viên, phần tử 0 là trưởng nhóm
var party: Array = []

# ---- guild của Hero ({} nếu chưa có)
## {name, master, mark[64], created, score, notice, members:[{name, pos}], union:[tên guild], rival}
var guild: Dictionary = {}

# ---- bạn bè: [{name}] ; chặn chat
var friends: Array = []
var reject_chat := false

# ---- quyết đấu
var duel_enemy: MuOtherPlayer = null
var duel_score_hero := 0
var duel_score_enemy := 0
var duel_attacking := false
var _duel_hero_timer := 0.0
var _duel_enemy_timer := 0.0
var _duel_pending: MuOtherPlayer = null

## Guild của người chơi mô phỏng
const BOT_GUILDS := {
	"VietMU": {"master": "KnightVN", "members": ["KnightVN", "DauSiMG"], "created": "2026-03-14", "score": 1250,
		"notice": "Guild VietMU tuyển thành viên cấp 50+. Săn boss tối thứ 7!", "mark_seed": 7},
	"Hacker": {"master": "PhapSuLua", "members": ["PhapSuLua"], "created": "2026-08-02", "score": 320,
		"notice": "Không nhận người lạ.", "mark_seed": 13},
}

func _ready() -> void:
	add_to_group("MuSocial")

func setup(p: MuPlayer) -> void:
	hero = p
	load_data()

# ================================================================== tiện ích
func find_player(nm: String) -> MuOtherPlayer:
	for p in get_tree().get_nodes_in_group("OtherPlayer"):
		if str(p.character_name).to_lower() == nm.to_lower():
			return p
	return null

func msg(text: String, col: Color = Color(1.0, 0.45, 0.35)) -> void:
	var hud = get_tree().get_first_node_in_group("HUD")
	if hud == null:
		return
	if hud.chat_window and hud.chat_window.has_method("add_system_message"):
		hud.chat_window.add_system_message("[color=#%s]%s[/color]" % [col.to_html(false), text])
	hud.show_pickup_notification(text, col)

func later(sec: float, cb: Callable) -> void:
	get_tree().create_timer(sec).timeout.connect(cb)

func _hero_name() -> String:
	return hero.character_name if hero else "Hero"

# ================================================================== TỔ ĐỘI (CommandParty / PartyInfoWindow / PartyListWindow)
func in_party() -> bool:
	return party.size() > 1

func is_leader() -> bool:
	return in_party() and party[0] == _hero_name()

func invite_party(p: MuOtherPlayer) -> void:
	# CommandParty: đã ở trong tổ đội mà không phải trưởng nhóm -> không mời được
	if in_party() and not is_leader():
		msg("Bạn đã ở trong một tổ đội.")
		return
	if party.has(p.character_name):
		msg("%s đã ở trong tổ đội." % p.character_name)
		return
	if party.size() >= MAX_PARTY:
		msg("Tổ đội đã đủ %d người." % MAX_PARTY)
		return
	if p.party_name != "":
		msg("%s đã ở trong tổ đội khác." % p.character_name)
		return
	msg("Đã gửi lời mời tổ đội tới %s." % p.character_name, Color.WHITE)
	later(1.2, _on_party_answer.bind(p))

func _on_party_answer(p: MuOtherPlayer) -> void:
	if not is_instance_valid(p):
		return
	if p.busy or randf() < 0.15:
		msg("%s đã từ chối lời mời tổ đội." % p.character_name)
		return
	if party.is_empty():
		party.append(_hero_name())
	party.append(p.character_name)
	p.party_name = _hero_name()
	p.follow_node = hero
	msg("%s đã tham gia tổ đội." % p.character_name, Color(0.45, 1.0, 0.5))
	party_changed.emit()

## Trưởng nhóm trục xuất thành viên (nút X trong cửa sổ Tổ đội)
func kick_member(nm: String) -> void:
	if not is_leader() or nm == _hero_name():
		return
	_remove_member(nm)
	msg("%s đã bị trục xuất khỏi tổ đội." % nm)

## Rời tổ đội (nút X trên thẻ tổ đội của mình) — tổ đội còn 1 người thì giải tán
func leave_party() -> void:
	if not in_party():
		return
	for nm in party.duplicate():
		if nm != _hero_name():
			_release_bot(nm)
	party.clear()
	msg("Bạn đã rời tổ đội.", Color.WHITE)
	party_changed.emit()

func _remove_member(nm: String) -> void:
	party.erase(nm)
	_release_bot(nm)
	if party.size() <= 1:
		party.clear()
		msg("Tổ đội đã giải tán.", Color.WHITE)
	party_changed.emit()

func _release_bot(nm: String) -> void:
	var p := find_player(nm)
	if p:
		p.party_name = ""
		p.follow_node = null

## Thông tin một thành viên cho cửa sổ tổ đội: {name, leader, hp, max_hp, map, x, y, near}
func member_info(nm: String) -> Dictionary:
	var info := {"name": nm, "leader": not party.is_empty() and party[0] == nm, "hp": 0, "max_hp": 1,
		"map": "Lorencia", "x": 0, "y": 0, "near": true}
	if nm == _hero_name() and hero:
		info["hp"] = hero.current_hp
		info["max_hp"] = hero.max_hp
		var t: Vector2i = MuWorld.world_to_grid(hero.global_position)
		info["x"] = t.x
		info["y"] = t.y
		return info
	var p := find_player(nm)
	if p == null:
		info["near"] = false
		return info
	info["hp"] = p.current_hp
	info["max_hp"] = p.max_hp
	var t2 := p.tile()
	info["x"] = t2.x
	info["y"] = t2.y
	info["near"] = hero == null or hero.global_position.distance_to(p.global_position) < 20.0
	return info

# ================================================================== GUILD (CommandGuild / GuildUnion / GuildRival / GuildInfoWindow)
func in_guild() -> bool:
	return not guild.is_empty()

func is_guild_master() -> bool:
	return in_guild() and str(guild.get("master", "")) == _hero_name()

static func make_mark(seed: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var c1 := rng.randi_range(4, 15)
	var c2 := rng.randi_range(2, 15)
	var m: Array = []
	for y in 8:
		for x in 4:
			var v := 0
			var r := rng.randf()
			if r < 0.45:
				v = c1
			elif r < 0.7:
				v = c2
			m.append(v)
		# đối xứng trái - phải
		for x in 4:
			m.append(m[y * 8 + 3 - x])
	return m

func guild_info_of(gname: String) -> Dictionary:
	if in_guild() and guild["name"] == gname:
		return guild
	if BOT_GUILDS.has(gname):
		var b: Dictionary = BOT_GUILDS[gname]
		var members: Array = []
		for nm in b["members"]:
			members.append({"name": nm, "pos": "Master" if nm == b["master"] else "Member"})
		return {"name": gname, "master": b["master"], "mark": make_mark(int(b["mark_seed"])), "created": b["created"],
			"score": b["score"], "notice": b["notice"], "members": members, "union": [], "rival": ""}
	return {}

## Tạo guild (NPC Guild Master của game gốc: cấp 100 trở lên, tên tối đa 8 ký tự)
func create_guild(gname: String) -> bool:
	gname = gname.strip_edges()
	if in_guild():
		msg("Bạn đã ở trong một guild.")
		return false
	if hero.level < GUILD_CREATE_LEVEL:
		msg("Cần đạt cấp %d trở lên để lập guild." % GUILD_CREATE_LEVEL)
		return false
	if gname.length() < 2 or gname.length() > 8:
		msg("Tên guild phải từ 2 đến 8 ký tự.")
		return false
	if BOT_GUILDS.has(gname):
		msg("Tên guild đã tồn tại.")
		return false
	guild = {"name": gname, "master": _hero_name(), "mark": make_mark(gname.hash()),
		"created": Time.get_date_string_from_system(), "score": 0, "notice": "",
		"members": [{"name": _hero_name(), "pos": "Master"}], "union": [], "rival": ""}
	hero.guild_name = gname
	msg("Đã lập guild %s." % gname, Color(0.45, 1.0, 0.5))
	_save_and_emit_guild()
	return true

## Lệnh Guild: xin gia nhập guild của người được chọn (phải là chủ guild)
func request_join_guild(p: MuOtherPlayer) -> void:
	if in_guild():
		msg("Bạn đã ở trong một guild.")
		return
	if p.guild_name == "" or not p.guild_master:
		msg("Người chơi này không phải chủ guild.")
		return
	msg("Đã gửi yêu cầu gia nhập guild %s tới %s." % [p.guild_name, p.character_name], Color.WHITE)
	later(1.5, func():
		if in_guild() or not is_instance_valid(p):
			return
		if randf() < 0.15:
			msg("%s đã từ chối yêu cầu gia nhập guild." % p.character_name)
			return
		guild = guild_info_of(p.guild_name).duplicate(true)
		guild["members"].append({"name": _hero_name(), "pos": "Member"})
		hero.guild_name = guild["name"]
		msg("Bạn đã gia nhập guild %s." % guild["name"], Color(0.45, 1.0, 0.5))
		_save_and_emit_guild())

## Người chơi chưa có guild xin vào guild của Hero (Hero là chủ guild)
func accept_guild_member(p: MuOtherPlayer) -> void:
	if not is_guild_master() or p.guild_name != "":
		return
	guild["members"].append({"name": p.character_name, "pos": "Member"})
	p.guild_name = guild["name"]
	p.refresh_labels()
	msg("%s đã gia nhập guild." % p.character_name, Color(0.45, 1.0, 0.5))
	_save_and_emit_guild()

## Chủ guild: bổ nhiệm / bãi nhiệm chức vụ (Assist M / Battle M) và trục xuất
func set_member_position(nm: String, pos: String) -> void:
	if not is_guild_master():
		msg("Bạn không phải là chủ guild.")
		return
	for m in guild["members"]:
		if m["name"] == nm and m["pos"] != "Master":
			m["pos"] = pos
	_save_and_emit_guild()

func kick_guild_member(nm: String) -> void:
	if not is_guild_master() or nm == _hero_name():
		return
	for m in guild["members"].duplicate():
		if m["name"] == nm:
			guild["members"].erase(m)
	var p := find_player(nm)
	if p and p.guild_name == guild["name"]:
		p.guild_name = ""
		p.refresh_labels()
	msg("%s đã bị trục xuất khỏi guild." % nm)
	_save_and_emit_guild()

## Rời guild (thành viên) / giải tán guild (chủ guild)
func leave_guild() -> void:
	if not in_guild():
		return
	if is_guild_master():
		for m in guild["members"]:
			var p := find_player(m["name"])
			if p and p.guild_name == guild["name"]:
				p.guild_name = ""
				p.refresh_labels()
		msg("Guild %s đã giải tán." % guild["name"], Color.WHITE)
	else:
		msg("Bạn đã rời guild %s." % guild["name"], Color.WHITE)
	guild = {}
	hero.guild_name = ""
	_save_and_emit_guild()

## Liên minh / Thù địch / Hủy thù địch — cả hai bên phải là chủ guild
func guild_relation(p: MuOtherPlayer, kind: String) -> void:
	if not is_guild_master():
		msg("Bạn không phải là chủ guild.")
		return
	if p.guild_name == "":
		msg("Người chơi này không thuộc guild nào.")
		return
	if not p.guild_master:
		msg("Người chơi này không phải chủ guild.")
		return
	var g: String = p.guild_name
	match kind:
		"alliance":
			if guild["union"].has(g):
				msg("Guild %s đã ở trong liên minh." % g)
				return
			if guild["rival"] == g:
				msg("Không thể liên minh với guild thù địch.")
				return
			msg("Đã gửi yêu cầu liên minh tới guild %s." % g, Color.WHITE)
			later(1.5, func():
				guild["union"].append(g)
				msg("Guild %s đã tham gia liên minh." % g, Color(0.45, 1.0, 0.5))
				_save_and_emit_guild())
		"rival":
			if guild["union"].has(g):
				msg("Không thể thù địch với guild trong liên minh.")
				return
			if guild["rival"] != "":
				msg("Guild đã có guild thù địch: %s." % guild["rival"])
				return
			msg("Đã tuyên bố thù địch với guild %s." % g, Color.WHITE)
			later(1.2, func():
				guild["rival"] = g
				msg("Guild %s giờ là guild thù địch." % g, Color(1.0, 0.5, 0.3))
				_save_and_emit_guild())
		"rival_off":
			if guild["rival"] != g:
				msg("Guild %s không phải guild thù địch." % g)
				return
			guild["rival"] = ""
			msg("Đã hủy thù địch với guild %s." % g, Color(0.45, 1.0, 0.5))
			_save_and_emit_guild()

func leave_union(g: String) -> void:
	if is_guild_master() and guild["union"].has(g):
		guild["union"].erase(g)
		msg("Guild %s đã rời liên minh." % g, Color.WHITE)
		_save_and_emit_guild()

func set_guild_notice(text: String) -> void:
	if is_guild_master():
		guild["notice"] = text.left(60)
		_save_and_emit_guild()

func _save_and_emit_guild() -> void:
	save_data()
	guild_changed.emit()
	for p in get_tree().get_nodes_in_group("OtherPlayer"):
		p.refresh_labels()

# ================================================================== BẠN BÈ (CommandAddFriend / FriendWindow)
func has_friend(nm: String) -> bool:
	for f in friends:
		if str(f["name"]).to_lower() == nm.to_lower():
			return true
	return false

func add_friend(nm: String) -> void:
	nm = nm.strip_edges()
	if nm == "" or nm == _hero_name():
		return
	if has_friend(nm):
		msg("%s đã có trong danh sách bạn bè." % nm)
		return
	var p := find_player(nm)
	if p == null:
		msg("Không tìm thấy nhân vật %s." % nm)
		return
	msg("Đã gửi lời mời kết bạn tới %s." % p.character_name, Color.WHITE)
	later(1.3, func():
		if has_friend(nm) or not is_instance_valid(p):
			return
		friends.append({"name": p.character_name})
		msg("%s đã đồng ý kết bạn." % p.character_name, Color(0.45, 1.0, 0.5))
		save_data()
		friends_changed.emit())

func delete_friend(nm: String) -> void:
	for f in friends.duplicate():
		if f["name"] == nm:
			friends.erase(f)
	msg("Đã xóa %s khỏi danh sách bạn bè." % nm, Color.WHITE)
	save_data()
	friends_changed.emit()

func is_online(nm: String) -> bool:
	return find_player(nm) != null

# ================================================================== QUYẾT ĐẤU (CommandDual / DuelWindow / DuelRoom)
func in_duel() -> bool:
	return duel_enemy != null and is_instance_valid(duel_enemy)

func request_duel(p: MuOtherPlayer) -> void:
	if hero.level < DUEL_LEVEL:
		msg("Chỉ mở cho nhân vật từ cấp %d trở lên." % DUEL_LEVEL)
		return
	if in_duel():
		if duel_enemy == p:
			# Đang đấu với chính người này -> SendDuelStopRequest
			end_duel("Bạn đã hủy trận quyết đấu.")
		else:
			msg("Không thể thách đấu: bạn đang trong một trận quyết đấu.")
		return
	if p.level < DUEL_LEVEL:
		msg("%s chưa đủ cấp %d để quyết đấu." % [p.character_name, DUEL_LEVEL])
		return
	if _duel_pending != null:
		return
	_duel_pending = p
	msg("Đã gửi lời mời quyết đấu tới %s." % p.character_name, Color.WHITE)
	later(2.0, func():
		_duel_pending = null
		if not is_instance_valid(p) or p.busy:
			msg("Lời mời quyết đấu đã bị hủy.")
			return
		if randf() < 0.2:
			msg("%s đã từ chối quyết đấu." % p.character_name)
			return
		_start_duel(p))

func _start_duel(p: MuOtherPlayer) -> void:
	duel_enemy = p
	duel_score_hero = 0
	duel_score_enemy = 0
	duel_attacking = false
	p.current_hp = p.max_hp
	p.duel_target = hero
	msg("Bắt đầu quyết đấu với %s! Hãy ra khỏi khu vực an toàn để chiến đấu." % p.character_name, Color(1.0, 0.85, 0.3))
	if MuAudioManager:
		MuAudioManager.play_event_start()
	duel_changed.emit()

func end_duel(text: String) -> void:
	if duel_enemy and is_instance_valid(duel_enemy):
		duel_enemy.duel_target = null
		duel_enemy.current_hp = duel_enemy.max_hp
	duel_enemy = null
	duel_attacking = false
	msg(text, Color(1.0, 0.85, 0.3))
	duel_changed.emit()

## Chạm vào đối thủ trong lúc quyết đấu -> đánh
func attack_duel_enemy() -> void:
	if in_duel():
		duel_attacking = true

func _point(hero_scored: bool) -> void:
	if hero_scored:
		duel_score_hero += 1
	else:
		duel_score_enemy += 1
	duel_changed.emit()
	if duel_score_hero >= DUEL_MAX_SCORE or duel_score_enemy >= DUEL_MAX_SCORE:
		var winner := _hero_name() if duel_score_hero > duel_score_enemy else duel_enemy.character_name
		end_duel("%s đã chiến thắng trận quyết đấu (%d : %d)." % [winner, duel_score_hero, duel_score_enemy])
		if hero_scored and MuAudioManager:
			MuAudioManager.play_level_up()

func _process(delta: float) -> void:
	if not in_duel() or hero == null:
		if duel_enemy != null:
			end_duel("Trận quyết đấu đã kết thúc.")
		return
	var e := duel_enemy
	var dist := hero.global_position.distance_to(e.global_position)
	if dist > 25.0:
		end_duel("Đối thủ ở quá xa, trận quyết đấu bị hủy.")
		return
	var hero_safe := hero.is_in_safe_zone()
	var enemy_safe := e.is_in_safe_zone()
	# --- Hero đánh (chạm vào đối thủ để bắt đầu)
	_duel_hero_timer -= delta
	if duel_attacking:
		if dist > hero.attack_range:
			if not hero.is_moving and _duel_hero_timer <= 0.0:
				var w = MuWorld.current
				if w:
					var path: Array[Vector2i] = w.find_path_grid(MuWorld.world_to_grid(hero.global_position), e.tile())
					if path.size() > 1:
						path.remove_at(path.size() - 1)
						hero.move_to_path(path)
				_duel_hero_timer = 0.3
		elif _duel_hero_timer <= 0.0:
			_duel_hero_timer = hero.attack_cooldown
			var d := e.global_position - hero.global_position
			hero.rotation.y = atan2(d.x, d.z)
			if hero.model and hero.model.anim:
				hero.model.play_attack(hero.stat_agi)
				hero._lock_action(hero.attack_cooldown)
			if MuAudioManager:
				MuAudioManager.play_weapon_swing(hero.global_position)
			if hero_safe or enemy_safe:
				_float_text(e, "Khu vực an toàn", Color(0.7, 0.9, 1.0))
			else:
				var dmg: int = hero._skill_damage({"damage": 0})
				if e.take_duel_damage(dmg):
					_point(true)
	# --- Đối thủ đánh lại
	_duel_enemy_timer -= delta
	if dist <= 2.2 and _duel_enemy_timer <= 0.0 and not hero_safe and not enemy_safe:
		_duel_enemy_timer = 1.1
		e.play_attack_at(hero)
		var raw := int(e.level * 1.1 + randi_range(20, 60))
		var est := maxi(maxi(1, raw / 10), raw - hero.defense_value())
		if est >= hero.current_hp:
			# chết trong quyết đấu: đối thủ ghi điểm, Hero hồi đầy máu (không mất kinh nghiệm)
			hero.current_hp = hero.max_hp
			hero.hp_changed.emit(hero.current_hp, hero.max_hp)
			_float_text(hero, "Bị hạ gục!", Color(1, 0.3, 0.3))
			_point(false)
		else:
			hero.take_damage(raw, e)

func _float_text(n: Node3D, t: String, col: Color) -> void:
	var l := Label3D.new()
	l.text = t
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 20
	l.outline_size = 5
	l.modulate = col
	l.position = n.global_position + Vector3(0, 2.6, 0)
	n.get_parent().add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y + 0.8, 0.9)
	tw.tween_callback(l.queue_free)

# ================================================================== lưu / nạp
func _save_path() -> String:
	return "user://mu_social_%s.json" % _hero_name().validate_filename()

func save_data() -> void:
	var f := FileAccess.open(_save_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"guild": guild, "friends": friends, "reject_chat": reject_chat}, "\t"))

func load_data() -> void:
	if not FileAccess.file_exists(_save_path()):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(_save_path()))
	if not (d is Dictionary):
		return
	guild = d.get("guild", {}) if d.get("guild") is Dictionary else {}
	friends = d.get("friends", []) if d.get("friends") is Array else []
	reject_chat = bool(d.get("reject_chat", false))
	if hero and in_guild():
		hero.guild_name = str(guild["name"])
