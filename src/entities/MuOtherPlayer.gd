extends CharacterBody3D
class_name MuOtherPlayer

## Người chơi khác trong thế giới (KIND_PLAYER, c != Hero trong Source).
## Client đang chạy chế độ offline nên đây là người chơi mô phỏng: đi lại quanh thành, mặc đồ thật
## (dựng bằng MuCharacterModel.build_player như Hero), có túi đồ để giao dịch và tự phản hồi giao dịch
## theo đúng luồng của server (Trade Request -> Accept -> thêm / bớt đồ -> bấm xác nhận -> trao đổi).

const MuCharModelRes = preload("res://src/mu/MuCharacterModel.gd")
const MuItemsRes = preload("res://src/mu/MuItems.gd")

signal equipment_changed

@export var character_name: String = "Player"
@export_range(0, 6) var char_class: int = 1
@export var level: int = 50
@export var class_tier: int = 1
@export var guild_name: String = ""
## Chủ guild (G_MASTER): nhận lệnh Guild / Liên minh / Thù địch
@export var guild_master: bool = false
## slot -> item (cùng định dạng MuPlayer.equipment)
@export var equipment: Dictionary = {}
## Đồ trong túi của người chơi này (sẽ đem ra giao dịch)
var inventory: Array = []
var zen: int = 0
## Kế hoạch giao dịch: danh sách đồ (lấy từ inventory) + số Zen sẽ đặt vào khung giao dịch
var trade_offer_zen: int = 0
var trade_offer_count: int = 2
## Người chơi "gian lận": sau khi bạn bấm xác nhận sẽ đổi một món sang bản cấp thấp hơn (kiểm tra cảnh báo của CTrade)
var trade_swindler: bool = false
## Tỉ lệ từ chối lời mời giao dịch
var decline_rate: float = 0.1

var grid_x: int = 130
var grid_y: int = 125
var home := Vector2i(-1, -1)
var wander_radius := 4
var model = null
## Người chơi THẬT từ client khác (qua Gateway): không đi lang thang, chỉ đi theo gói tin vị trí
var remote := false
var _speed_mul := 1.0
var busy := false        # đang giao dịch / được xem đồ: đứng yên quay mặt về Hero

# ---- máu (thẻ tổ đội / quyết đấu)
var max_hp := 300
var current_hp := 300
# ---- tổ đội: tên trưởng nhóm ("" = không có) ; đi theo trưởng nhóm
var party_name := ""
var follow_node: Node3D = null
# ---- quyết đấu: đối thủ (đuổi theo và đánh)
var duel_target: Node3D = null
## Chưa có guild và muốn xin vào guild của Hero (khi Hero là chủ guild)
var wants_guild := false
var _repath := 0.0

var _path: Array[Vector2i] = []
var _wait := 0.0
var _name_label: Label3D
var _guild_label: Label3D
var _moving := false

const SPEED := 12.0 * 25.0 / 100.0   # CharacterMoveSpeed đi bộ: 12 đơn vị / tick

func _ready() -> void:
	add_to_group("OtherPlayer")
	if home.x < 0:
		home = Vector2i(grid_x, grid_y)
	global_position = MuWorld.grid_to_world(grid_x, grid_y)
	rotation.y = randf() * TAU
	_wait = randf_range(1.0, 5.0)
	if not remote:
		max_hp = 200 + level * 9
		current_hp = max_hp
	rebuild_model()
	_setup_labels()
	_setup_collision()

func rebuild_model() -> void:
	if model == null:
		model = MuCharModelRes.new()
		model.name = "MuModel"
		add_child(model)
	if model.build_player(char_class, equipment):
		model.play_idle(is_in_safe_zone())
	equipment_changed.emit()

func is_in_safe_zone() -> bool:
	return (MuTerrain.attribute_at(grid_x, grid_y) & 1) != 0

func get_class_display_name() -> String:
	const CLASS_NAMES = {
		0: ["Dark Wizard", "Soul Master", "Grand Master"],
		1: ["Dark Knight", "Blade Knight", "Blade Master"],
		2: ["Fairy Elf", "Muse Elf", "High Elf"],
		3: ["Magic Gladiator", "Magic Gladiator", "Duel Master"],
		4: ["Dark Lord", "Dark Lord", "Lord Emperor"],
		5: ["Summoner", "Bloody Summoner", "Dimension Master"],
		6: ["Rage Fighter", "Rage Fighter", "Fist Master"]
	}
	return CLASS_NAMES.get(char_class, ["?", "?", "?"])[clampi(class_tier - 1, 0, 2)]

# ------------------------------------------------------------------ hiển thị tên (tên người chơi trắng, guild phía trên như MU)
func _setup_labels() -> void:
	_name_label = Label3D.new()
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.no_depth_test = true
	_name_label.text = character_name
	_name_label.font_size = 22
	_name_label.outline_size = 6
	_name_label.outline_modulate = Color.BLACK
	_name_label.modulate = Color(1, 1, 1)
	_name_label.position = Vector3(0, 2.25, 0)
	add_child(_name_label)
	_guild_label = Label3D.new()
	_guild_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_guild_label.no_depth_test = true
	_guild_label.font_size = 18
	_guild_label.outline_size = 5
	_guild_label.outline_modulate = Color.BLACK
	_guild_label.position = Vector3(0, 2.5, 0)
	add_child(_guild_label)
	refresh_labels()

## Màu guild theo quan hệ với guild của Hero: cùng guild xanh lá, liên minh xanh lam, thù địch đỏ
func refresh_labels() -> void:
	if _guild_label == null:
		return
	_guild_label.visible = guild_name != ""
	_guild_label.text = "[%s]" % guild_name
	var col := Color(0.85, 0.85, 0.85)
	var social = get_tree().get_first_node_in_group("MuSocial") if is_inside_tree() else null
	if social and social.in_guild():
		if social.guild["name"] == guild_name:
			col = Color(0.4, 1.0, 0.4)
		elif social.guild["union"].has(guild_name):
			col = Color(0.45, 0.75, 1.0)
		elif social.guild["rival"] == guild_name:
			col = Color(1.0, 0.35, 0.3)
	_guild_label.modulate = col

func _setup_collision() -> void:
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.6
	shape.height = 2.0
	col.shape = shape
	col.position = Vector3(0, 1.0, 0)
	add_child(col)

# ------------------------------------------------------------------ chuột: chọn người chơi -> menu lệnh
func _input_event(_camera: Camera3D, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var item_ui = tree.get_first_node_in_group("MuItemUi")
	if item_ui and not item_ui.held.is_empty():
		return
	var pressed: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if pressed:
		get_viewport().set_input_as_handled()
		var hud = tree.get_first_node_in_group("HUD")
		if hud and hud.has_method("open_player_menu"):
			hud.open_player_menu(self, get_viewport().get_mouse_position())

# ------------------------------------------------------------------ đi lại
func _process(delta: float) -> void:
	if current_hp < max_hp and duel_target == null:
		current_hp = mini(max_hp, current_hp + int(maxf(1.0, max_hp * 0.02 * delta)))
	var chase: Node3D = duel_target if duel_target and is_instance_valid(duel_target) else follow_node
	if chase and is_instance_valid(chase) and not busy:
		_repath -= delta
		var dist := global_position.distance_to(chase.global_position)
		var keep := 1.5 if chase == duel_target else 2.5
		if dist > keep and _repath <= 0.0:
			_repath = 0.5
			var w = MuWorld.current
			if w:
				var p: Array[Vector2i] = w.find_path_grid(tile(), MuWorld.world_to_grid(chase.global_position))
				if p.size() > 1:
					p.remove_at(0)
					if p.size() > 1:
						p.remove_at(p.size() - 1)
					_path = p
		elif dist <= keep:
			_path.clear()
			var d0: Vector3 = chase.global_position - global_position
			if d0.length() > 0.05:
				rotation.y = lerp_angle(rotation.y, atan2(d0.x, d0.z), clampf(8.0 * delta, 0.0, 1.0))
		if _path.is_empty():
			_update_anim()
			return
		_step_path(delta)
		return
	if busy:
		_moving = false
		_path.clear()
		var hero = get_tree().get_first_node_in_group("Player")
		if hero:
			var d: Vector3 = hero.global_position - global_position
			d.y = 0
			if d.length() > 0.05:
				rotation.y = lerp_angle(rotation.y, atan2(d.x, d.z), clampf(8.0 * delta, 0.0, 1.0))
		_update_anim()
		return
	if _path.is_empty():
		if remote:
			_update_anim()
			return
		_wait -= delta
		if _wait <= 0.0:
			_wait = randf_range(4.0, 10.0)
			_pick_wander()
		_update_anim()
		return
	_step_path(delta)

func _step_path(delta: float) -> void:
	var tgt: Vector3 = MuWorld.grid_to_world(_path[0].x, _path[0].y)
	var here := global_position
	var flat := Vector3(tgt.x - here.x, 0, tgt.z - here.z)
	var dist := flat.length()
	var step := SPEED * _speed_mul * delta
	if dist <= step:
		global_position = tgt
		grid_x = _path[0].x
		grid_y = _path[0].y
		_path.remove_at(0)
	else:
		var dir := flat / dist
		var np := here + dir * step
		np.y = MuWorld.ground_height(np)
		global_position = np
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), clampf(12.0 * delta, 0.0, 1.0))
	_update_anim()

## Đi tới ô do client thật gửi lên; đi xa quá thì dịch chuyển thẳng
func remote_walk_to(t: Vector2i) -> void:
	var here := Vector2i(grid_x, grid_y)
	if t == here:
		return
	var w = MuWorld.current
	if here.distance_to(t) > 14.0 or w == null or not w.has_method("find_path_grid"):
		_path.clear()
		grid_x = t.x
		grid_y = t.y
		global_position = MuWorld.grid_to_world(t.x, t.y)
		return
	var p: Array[Vector2i] = w.find_path_grid(here, t)
	if p.size() > 1:
		p.remove_at(0)
		_path = p
		_speed_mul = clampf(1.0 + 0.12 * p.size(), 1.0, 2.5)   # đi trễ thì bước nhanh hơn để bắt kịp
	else:
		_path.clear()
		grid_x = t.x
		grid_y = t.y
		global_position = MuWorld.grid_to_world(t.x, t.y)

func _pick_wander() -> void:
	var w = MuWorld.current
	if w == null or not w.has_method("find_path_grid"):
		return
	var tgt := home + Vector2i(randi_range(-wander_radius, wander_radius), randi_range(-wander_radius, wander_radius))
	var p: Array[Vector2i] = w.find_path_grid(Vector2i(grid_x, grid_y), tgt)
	if p.size() > 1 and p.size() < wander_radius * 4:
		p.remove_at(0)
		_path = p

func _update_anim() -> void:
	if model == null:
		return
	var mv := not _path.is_empty()
	if mv != _moving:
		_moving = mv
		if mv:
			model.play_move(false, is_in_safe_zone())
		else:
			model.play_idle(is_in_safe_zone())

## Đòn đánh trong quyết đấu
func play_attack_at(target: Node3D) -> void:
	var d := target.global_position - global_position
	rotation.y = atan2(d.x, d.z)
	if model and model.anim:
		model.play_attack(20)
	if MuAudioManager:
		MuAudioManager.play_weapon_swing(global_position)
	_moving = false

## Nhận sát thương trong quyết đấu; trả về true khi bị hạ (đối thủ ghi điểm, hồi đầy máu)
func take_duel_damage(dmg: int) -> bool:
	var def := 20 + level / 2
	dmg = maxi(maxi(1, dmg / 10), dmg - def)
	current_hp -= dmg
	var lbl = DamageNumber3D.new()
	get_parent().add_child(lbl)
	lbl.setup(dmg, DamageNumber3D.DamageType.NORMAL, global_position)
	if MuAudioManager:
		MuAudioManager.play_melee_hit(global_position)
	if current_hp <= 0:
		current_hp = max_hp
		return true
	if model and model.has_method("play_shock"):
		model.play_shock()
	return false

func stop_and_face_hero() -> void:
	_path.clear()

func tile() -> Vector2i:
	return Vector2i(grid_x, grid_y)

# ------------------------------------------------------------------ "server" giao dịch phía người chơi này
## Trả về true nếu chấp nhận lời mời giao dịch
func answer_trade_request(hero_level: int) -> bool:
	if busy:
		return false
	return randf() >= decline_rate and hero_level >= 6

## Chọn đồ sẽ đặt lên khung giao dịch (lấy ra khỏi túi khi giao dịch hoàn tất)
func pick_trade_offer() -> Array:
	var pool := inventory.duplicate()
	pool.shuffle()
	if trade_swindler:
		# kẻ gian luôn chào món đắt nhất trước
		pool.sort_custom(func(a, b): return int(a.get("level", 0)) > int(b.get("level", 0)))
	return pool.slice(0, mini(trade_offer_count, pool.size()))

func inv_remove(it: Dictionary) -> void:
	var i := inventory.find(it)
	if i >= 0:
		inventory.remove_at(i)

func inv_add(it: Dictionary) -> void:
	inventory.append(it.duplicate())

func _exit_tree() -> void:
	if model and model.has_method("cleanup_materials"):
		model.cleanup_materials()

# ------------------------------------------------------------------ tạo sẵn vài người chơi quanh thành Lorencia
static func it(g: int, n: int, lv: int = 0, extra: Dictionary = {}) -> Dictionary:
	return MuItemsRes.make(g, n, lv, extra)

static func set_of(set_no: int, lv: int, exc: bool = false) -> Dictionary:
	var e := {"excellent": exc, "luck": lv >= 7, "opt": 1 if lv >= 9 else 0}
	return {"helm": it(7, set_no, lv, e), "armor": it(8, set_no, lv, e), "pants": it(9, set_no, lv, e),
		"gloves": it(10, set_no, lv, e), "boots": it(11, set_no, lv, e)}

static func presets() -> Array:
	var list: Array = []
	# 1. Dark Knight mặc Dragon +9, kiếm Lighting, cánh Satan
	var eq1 := set_of(1, 9)
	eq1["right"] = it(0, 14, 9, {"skill": true, "luck": true, "opt": 2})
	eq1["wings"] = it(12, 2, 5)
	eq1["helper"] = it(13, 0)
	list.append({"name": "KnightVN", "class": 1, "level": 186, "tier": 2, "guild": "VietMU", "eq": eq1, "tile": Vector2i(136, 124),
		"inv": [it(14, 13), it(14, 14), it(0, 10, 7, {"skill": true, "excellent": true}), it(8, 6, 6, {"luck": true})],
		"zen": 2500000, "offer_zen": 150000, "offer": 2, "master": true})
	# 2. Fairy Elf mặc Vine, cung Silver, cánh Elf
	var eq2 := set_of(10, 7)
	eq2["right"] = it(4, 5, 6, {"skill": true})
	eq2["wings"] = it(12, 0, 3)
	list.append({"name": "ElfXinhDep", "class": 2, "level": 92, "tier": 1, "guild": "", "eq": eq2, "tile": Vector2i(128, 129),
		"inv": [it(14, 16), it(12, 15), it(13, 1), it(7, 11, 5, {"luck": true})],
		"zen": 480000, "offer_zen": 0, "offer": 2, "wants_guild": true})
	# 3. Dark Wizard Legendary +11 (người chơi "gian lận" để kiểm tra cảnh báo giao dịch)
	var eq3 := set_of(3, 11, true)
	eq3["right"] = it(5, 5, 11, {"skill": true, "luck": true, "opt": 3})
	eq3["wings"] = it(12, 1, 7)
	list.append({"name": "PhapSuLua", "class": 0, "level": 247, "tier": 2, "guild": "Hacker", "eq": eq3, "tile": Vector2i(142, 128),
		"inv": [it(0, 11, 9, {"skill": true, "luck": true, "opt": 3}), it(14, 13), it(14, 14)],
		"zen": 9000000, "offer_zen": 50000, "offer": 1, "swindler": true, "master": true})
	# 4. Magic Gladiator Storm Crow, kiếm + khiên
	var eq4 := set_of(15, 4)
	eq4["right"] = it(0, 9, 4, {"skill": true})
	eq4["left"] = it(6, 9, 4)
	list.append({"name": "DauSiMG", "class": 3, "level": 64, "tier": 1, "guild": "VietMU", "eq": eq4, "tile": Vector2i(133, 117),
		"inv": [it(14, 3), it(14, 3), it(14, 6), it(6, 13, 3)],
		"zen": 120000, "offer_zen": 20000, "offer": 3})
	return list

static func spawn_presets(parent: Node) -> void:
	var w = MuWorld.current
	for p in presets():
		var op := MuOtherPlayer.new()
		op.name = "OtherPlayer_" + str(p["name"])
		op.character_name = p["name"]
		op.char_class = int(p["class"])
		op.level = int(p["level"])
		op.class_tier = int(p["tier"])
		op.guild_name = p["guild"]
		op.equipment = p["eq"]
		op.inventory = p["inv"]
		op.zen = int(p["zen"])
		op.trade_offer_zen = int(p["offer_zen"])
		op.trade_offer_count = int(p["offer"])
		op.trade_swindler = bool(p.get("swindler", false))
		op.guild_master = bool(p.get("master", false))
		op.wants_guild = bool(p.get("wants_guild", false))
		var t: Vector2i = p["tile"]
		if w and w.has_method("find_path_grid"):
			var pp: Array[Vector2i] = w.find_path_grid(t, t)
			if pp.size() > 0:
				t = pp[0]
		op.grid_x = t.x
		op.grid_y = t.y
		op.home = t
		op.position = MuWorld.grid_to_world(t.x, t.y)
		parent.add_child.call_deferred(op)

## Trả lời tin nhắn nói thầm
func whisper_reply() -> String:
	var lines := ["Chào bạn!", "Mình đang bận săn quái, lát nói nhé.", "Bạn cần mua gì không?", "OK", "Muốn giao dịch thì bấm Giao dịch nhé."]
	return lines[randi() % lines.size()]
