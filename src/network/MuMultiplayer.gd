extends Node
class_name MuMultiplayer

## Nhiều người chơi cùng thế giới.
## Tài khoản / nhân vật lưu cục bộ trong từng client nên không có trong OpenMU; Gateway (gateway/presence.py)
## chuyển tiếp khung văn bản JSON giữa các client ở CÙNG MAP. Node này gửi trạng thái của Hero và dựng
## MuOtherPlayer cho người chơi thật (remote = true).

const MuOtherPlayerRes = preload("res://src/entities/MuOtherPlayer.gd")

const POS_INTERVAL := 0.2
const EQ_INTERVAL := 2.0
const RECONNECT_DELAY := 3.0

var socket := WebSocketPeer.new()
var _open := false
var _joined := false
var _player: MuPlayer = null
var _remotes: Dictionary = {}          # tên -> MuOtherPlayer
var _pending_pos := Vector2i(-1, -1)
var _sent_pos := Vector2i(-1, -1)
var _pos_timer := 0.0
var _eq_timer := 0.0
var _eq_hash := 0
var _reconnect := 0.0
var _chat: Node = null

func _ready() -> void:
	add_to_group("MuMultiplayer")
	_player = get_tree().get_first_node_in_group("Player") as MuPlayer
	if _player == null:
		await get_tree().process_frame
		_player = get_tree().get_first_node_in_group("Player") as MuPlayer
	if _player == null:
		set_process(false)
		return
	_player.position_changed.connect(_on_hero_moved)
	_player.hp_changed.connect(_on_hero_hp)
	_connect()

func is_online() -> bool:
	return _open and _joined

func _url() -> String:
	return MuAccountSession.server_gateway_url.strip_edges()

func _connect() -> void:
	var url := _url()
	if url == "":
		set_process(false)   # chế độ offline hoàn toàn
		return
	socket = WebSocketPeer.new()
	_open = false
	_joined = false
	if socket.connect_to_url(url) != OK:
		_reconnect = RECONNECT_DELAY

func _exit_tree() -> void:
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.close(1000, "scene change")

# ------------------------------------------------------------------ vòng lặp
func _process(delta: float) -> void:
	socket.poll()
	match socket.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not _open:
				_open = true
				_send_join()
			while socket.get_available_packet_count() > 0:
				var pkt := socket.get_packet()
				if socket.was_string_packet():
					_on_message(pkt.get_string_from_utf8())
		WebSocketPeer.STATE_CLOSED:
			if _open or _reconnect <= 0.0:
				_open = false
				_joined = false
				_clear_remotes()
				_reconnect = RECONNECT_DELAY
			_reconnect -= delta
			if _reconnect <= 0.0:
				_connect()
	if not is_online():
		return
	_pos_timer += delta
	if _pos_timer >= POS_INTERVAL:
		_pos_timer = 0.0
		if _pending_pos != _sent_pos and _pending_pos.x >= 0:
			_sent_pos = _pending_pos
			_send({"t": "move", "x": _sent_pos.x, "y": _sent_pos.y, "run": _player.is_running()})
	_eq_timer += delta
	if _eq_timer >= EQ_INTERVAL:
		_eq_timer = 0.0
		var h := _equipment_hash()
		if h != _eq_hash:
			_eq_hash = h
			_send({"t": "eq", "eq": _clean(_player.equipment), "lvl": _player.level,
				"cls": _player.char_class, "tier": _player.class_tier})

# ------------------------------------------------------------------ gửi
func _send(d: Dictionary) -> void:
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.send_text(JSON.stringify(d))

func _equipment_hash() -> int:
	return hash(JSON.stringify(_clean(_player.equipment)) + str(_player.level) + str(_player.class_tier))

## JSON không phân biệt int/float: đưa về dạng JSON được (bỏ Object, ép số nguyên)
static func _clean(v):
	match typeof(v):
		TYPE_DICTIONARY:
			var o := {}
			for k in v:
				o[str(k)] = _clean(v[k])
			return o
		TYPE_ARRAY:
			var a := []
			for e in v:
				a.append(_clean(e))
			return a
		TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_BOOL, TYPE_NIL:
			return v
		_:
			return str(v)

## Sau JSON.parse mọi số là float; model đồ cần int
static func _restore(v):
	match typeof(v):
		TYPE_DICTIONARY:
			var o := {}
			for k in v:
				o[k] = _restore(v[k])
			return o
		TYPE_ARRAY:
			var a := []
			for e in v:
				a.append(_restore(e))
			return a
		TYPE_FLOAT:
			return int(v) if is_equal_approx(v, round(v)) else v
		_:
			return v

func _send_join() -> void:
	_eq_hash = _equipment_hash()
	_sent_pos = Vector2i(_player.grid_x, _player.grid_y)
	_pending_pos = _sent_pos
	_send({"t": "join", "token": MuAccountSession.session_token, "name": _player.character_name, "cls": _player.char_class, "lvl": _player.level,
		"tier": _player.class_tier, "guild": _player.guild_name, "eq": _clean(_player.equipment),
		"map": MuTerrain.world_id, "x": _sent_pos.x, "y": _sent_pos.y,
		"hp": _player.current_hp, "mhp": _player.max_hp})
	_joined = true

func _on_hero_moved(gx: int, gy: int) -> void:
	_pending_pos = Vector2i(gx, gy)

var _hp_cd := 0.0
func _on_hero_hp(cur: int, mx: int) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if is_online() and now - _hp_cd > 0.5:
		_hp_cd = now
		_send({"t": "hp", "hp": cur, "mhp": mx})

func send_chat(msg: String) -> void:
	if is_online():
		_send({"t": "chat", "msg": msg})

func send_whisper(to: String, msg: String) -> void:
	if is_online():
		_send({"t": "whisper", "to": to, "msg": msg})

func send_attack(tile: Vector2i, _world_pos: Vector3, target: Node3D) -> void:
	if not is_online():
		return
	var t := tile
	if target and is_instance_valid(target):
		t = MuWorld.world_to_grid(target.global_position)
	else:
		# không có mục tiêu: nhìn theo hướng nhân vật đang quay
		var f := Vector3(sin(_player.rotation.y), 0, cos(_player.rotation.y))
		t = MuWorld.world_to_grid(_player.global_position + f * 2.0)
	_send({"t": "atk", "x": t.x, "y": t.y})

# ------------------------------------------------------------------ nhận
func _on_message(text: String) -> void:
	var m = JSON.parse_string(text)
	if not (m is Dictionary):
		return
	match str(m.get("t", "")):
		"spawn":
			_spawn_remote(m.get("p", {}))
		"despawn":
			_despawn_remote(str(m.get("n", "")))
		"move":
			var op := _remotes.get(str(m.get("n", ""))) as MuOtherPlayer
			if op and is_instance_valid(op):
				op.remote_walk_to(Vector2i(int(m.get("x", 0)), int(m.get("y", 0))))
		"eq":
			var op2 := _remotes.get(str(m.get("n", ""))) as MuOtherPlayer
			if op2 and is_instance_valid(op2):
				op2.equipment = _restore(m.get("eq", {}))
				op2.level = int(m.get("lvl", op2.level))
				op2.class_tier = int(m.get("tier", op2.class_tier))
				if int(m.get("cls", op2.char_class)) != op2.char_class:
					op2.char_class = int(m.get("cls"))
				op2.rebuild_model()
		"atk":
			var op3 := _remotes.get(str(m.get("n", ""))) as MuOtherPlayer
			if op3 and is_instance_valid(op3) and op3.model and op3.model.anim:
				var tg := MuWorld.grid_to_world(int(m.get("x", 0)), int(m.get("y", 0)))
				var d := tg - op3.global_position
				if d.length() > 0.05:
					op3.rotation.y = atan2(d.x, d.z)
				op3.model.play_attack(20)
		"hp":
			var op4 := _remotes.get(str(m.get("n", ""))) as MuOtherPlayer
			if op4 and is_instance_valid(op4):
				op4.max_hp = maxi(1, int(m.get("mhp", op4.max_hp)))
				op4.current_hp = clampi(int(m.get("hp", op4.current_hp)), 0, op4.max_hp)
		"chat":
			var who := str(m.get("n", ""))
			var msg := str(m.get("msg", ""))
			_chat_line("[b]%s:[/b] %s" % [who, msg])
			var op5 := _remotes.get(who) as MuOtherPlayer
			if op5 and is_instance_valid(op5):
				for c in op5.get_children():
					if c is ChatBubble:
						c.queue_free()
				var b = preload("res://src/ui/ChatBubble.gd").new()
				op5.add_child(b)
				b.show_chat(msg)
		"whisper":
			_chat_line("[color=#FFC6F5]%s thì thầm: %s[/color]" % [str(m.get("n", "")), str(m.get("msg", ""))])
		"sys":
			_chat_line("[color=#FF7060]%s[/color]" % str(m.get("msg", "")))

func _chat_line(bb: String) -> void:
	if _chat == null or not is_instance_valid(_chat):
		var found := get_tree().root.find_children("*", "ChatWindow", true, false)
		_chat = found[0] if found.size() > 0 else null
	if _chat:
		_chat.add_system_message(bb)

# ------------------------------------------------------------------ người chơi thật
func _spawn_remote(p: Dictionary) -> void:
	var nm := str(p.get("name", ""))
	if nm == "" or nm == _player.character_name:
		return
	_despawn_remote(nm)
	var op := MuOtherPlayerRes.new() as MuOtherPlayer
	op.name = "Remote_" + nm
	op.remote = true
	op.character_name = nm
	op.char_class = clampi(int(p.get("cls", 1)), 0, 6)
	op.level = int(p.get("lvl", 1))
	op.class_tier = int(p.get("tier", 1))
	op.guild_name = str(p.get("guild", "") if p.get("guild") != null else "")
	op.equipment = _restore(p.get("eq", {})) if p.get("eq") is Dictionary else {}
	op.max_hp = maxi(1, int(p.get("mhp", 100)))
	op.current_hp = clampi(int(p.get("hp", op.max_hp)), 0, op.max_hp)
	op.grid_x = int(p.get("x", 130))
	op.grid_y = int(p.get("y", 125))
	op.home = Vector2i(op.grid_x, op.grid_y)
	op.position = MuWorld.grid_to_world(op.grid_x, op.grid_y)
	get_parent().add_child(op)
	_remotes[nm] = op
	_chat_line("[color=#9CF]%s đã vào khu vực.[/color]" % nm)

func _despawn_remote(nm: String) -> void:
	var op = _remotes.get(nm)
	_remotes.erase(nm)
	if op and is_instance_valid(op):
		op.queue_free()

func _clear_remotes() -> void:
	for nm in _remotes.keys():
		_despawn_remote(nm)
