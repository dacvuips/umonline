extends Node
## MU Helper (auto ingame) — port logic từ Source/src/source/MUHelper/MuHelper.cpp
##
## Thứ tự mỗi tick (giống CMuHelper::Work): Uống bình máu -> Buff -> Hồi máu (Heal / Drain Life)
## -> Nhặt đồ đang đi tới -> Quay về vị trí gốc (Regroup) -> Chọn đồ nhặt -> Tấn công -> Sửa đồ.
## Giây của Helper tính theo đồng hồ thật (không phụ thuộc FPS).
## Gắn làm con của MuPlayer (xem MuHud._setup_helper).

const MuCatalogRes = preload("res://src/mu/MuCatalog.gd")
const MuItemsRes = preload("res://src/mu/MuItems.gd")

signal state_changed(active: bool)

const CONFIG_PATH := "user://mu_helper.json"
const TICK_INTERVAL := 0.1
const MAX_ACTIONABLE_DISTANCE := 10
const TARGET_RETRY_DELAY := 2.0
const PICKUP_RETRY_DELAY := 1.0
const PICKUP_REQUEST_RETRY_DELAY := 3.0
const MAX_PICKUP_REQUESTS := 3
const NO_ACTION_YIELD := 4
const REPAIR_THRESHOLD := 50

# ESkillActivation* (MuHelperData.h)
const COND_ALWAYS := 0
const COND_TIMER := 1
const COND_CONDITION := 2
const PRE_NEARBY := 0   # ON_MOBS_NEARBY
const PRE_ATTACKING := 1 # ON_MOBS_ATTACKING

const DEFAULT_CONFIG := {
	"stay_in_place": false,            # true: đứng yên, chỉ đánh quái trong tầm đòn; false: tìm quái theo bán kính
	"hunting_range": 6,
	"long_range_counter": false,
	"return_to_origin": false,
	"max_seconds_away": 10,
	"skills": [0, 0, 0],               # [0] = đòn chính, [1],[2] = đòn phụ (0 = Đánh thường / trống)
	"skill_use_timer": [false, false, false],
	"skill_interval": [0, 0, 0],       # giây
	"skill_use_condition": [false, false, false],
	"skill_precon": [0, 0, 0],         # PRE_NEARBY / PRE_ATTACKING
	"skill_subcon": [0, 0, 0],         # số quái tối thiểu (0 = không điều kiện; 2..5)
	"use_combo": false,
	"buffs": [0, 0, 0],
	"buff_duration": false,            # tự buff lại khi hết hạn
	"buff_cast_interval": 0,           # giây giữa 2 đợt buff (0 = tắt)
	"auto_heal": false,
	"heal_threshold": 50,
	"use_heal_potion": true,
	"potion_threshold": 50,            # bơm máu: HP ≤ % thì uống 1 bình mỗi giây (bình nhỏ trước)
	"potion_spam_enabled": true,
	"potion_spam_threshold": 25,       # bơm nhồi: HP ≤ % thì uống liên tục (bình lớn nhất, mỗi 0.3s)
	"use_drain_life": false,
	"repair_item": false,
	"pick_range": 6,
	"pick_all": false,
	"pick_select": true,
	"pick_jewel": true,
	"pick_zen": true,
	"pick_ancient": true,
	"pick_excellent": true,
	"pick_extra": false,
	"extra_items": "",                 # tên vật phẩm, ngăn cách bằng dấu ;
	"self_defense": true,
	"fight_back_players": false,       # bị người chơi khác tấn công (quyết đấu) thì đánh trả
	"fallback_basic_attack": true,
}

var config: Dictionary = {}
var active: bool = false

var _player: MuPlayer = null
var _tick_acc := 0.0
var _now := 0.0                    # giây đồng hồ thật
var _next_second_at := 0.0
var _seconds_elapsed := 0
var _seconds_away := 0
var _origin := Vector2i.ZERO
var _total_cost := 0

var _current_target: MuMonster = null
var _target_retry_at: Dictionary = {}   # instance_id -> time
var _attacking: Dictionary = {}         # instance_id -> true (quái đang đánh người chơi)
var _combo_state := 0
var _rotation_index := 0
var _no_action_count := 0
var _skill_last_cast: Dictionary = {}   # slot -> seconds_elapsed lần dùng cuối
var _skill_due: Dictionary = {}         # slot -> bool (Delay đã đến hạn)
var _condition_yield_until: Dictionary = {} # slot -> time

var _buff_index := 0
var _buff_until: Dictionary = {}        # skill -> time hết hạn
var _next_buff_at := 0
var _timer_buff_ongoing := false
var _buff_refresh_done: Dictionary = {}

var _current_item: MuDropItem = null
var _item_retry_at: Dictionary = {}     # instance_id -> time
var _item_requests: Dictionary = {}     # instance_id -> số lần yêu cầu
var _last_potion_at := -10.0
var _last_repair_at := -10.0

func _ready() -> void:
	add_to_group("MuHelper")
	load_config()
	set_process(true)

func setup(player: MuPlayer) -> void:
	_player = player

# ----------------------------------------------------------------- config
func load_config() -> void:
	config = DEFAULT_CONFIG.duplicate(true)
	if FileAccess.file_exists(CONFIG_PATH):
		var f := FileAccess.open(CONFIG_PATH, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				for k in parsed.keys():
					if config.has(k) and typeof(parsed[k]) == typeof(config[k]):
						config[k] = parsed[k]

func save_config() -> void:
	var f := FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(config))
	_reset_rotation()

func _reset_rotation() -> void:
	_rotation_index = 0
	_no_action_count = 0
	_combo_state = 0
	_skill_last_cast.clear()
	_skill_due.clear()
	_condition_yield_until.clear()

# ----------------------------------------------------------------- start / stop
func toggle() -> void:
	if active:
		stop()
	else:
		start()

func start() -> void:
	if active or not is_instance_valid(_player):
		return
	if _player.is_in_safe_zone():
		_notify("MU Helper: không thể bật trong Safe Zone", Color(1.0, 0.5, 0.4))
		return
	_reset_rotation()
	_total_cost = 0
	_buff_index = 0
	_buff_until.clear()
	_buff_refresh_done.clear()
	_timer_buff_ongoing = false
	_current_target = null
	_current_item = null
	_item_retry_at.clear()
	_item_requests.clear()
	_target_retry_at.clear()
	_attacking.clear()
	_origin = Vector2i(_player.grid_x, _player.grid_y)
	_now = Time.get_ticks_msec() / 1000.0
	_next_second_at = _now + 1.0
	_seconds_elapsed = 0
	_seconds_away = 0
	_next_buff_at = 0
	active = true
	state_changed.emit(true)
	_notify("MU Helper: BẬT", Color(0.4, 0.95, 0.5))

func stop() -> void:
	if not active:
		return
	active = false
	_current_target = null
	_current_item = null
	if is_instance_valid(_player):
		_player.clear_target()
		_player.waypoints.clear()
	state_changed.emit(false)
	_notify("MU Helper: TẮT", Color(1.0, 0.5, 0.4))

## Đăng xuất / đổi map / chết: dừng và quên mục tiêu + đồ (CMuHelper::EndSession)
func end_session() -> void:
	stop()
	_attacking.clear()
	_target_retry_at.clear()
	_item_retry_at.clear()
	_item_requests.clear()

func _notify(text: String, col: Color) -> void:
	var hud = get_tree().get_first_node_in_group("HUD") if is_inside_tree() else null
	if hud and hud.has_method("show_pickup_notification"):
		hud.show_pickup_notification(text, col)

# ----------------------------------------------------------------- tick
func _process(delta: float) -> void:
	if not active:
		return
	if not is_instance_valid(_player) or _player._dead:
		stop()
		return
	_tick_acc += delta
	if _tick_acc < TICK_INTERVAL:
		return
	_tick_acc = 0.0
	tick(Time.get_ticks_msec() / 1000.0)

func tick(now: float) -> void:
	_now = now
	if _player.is_in_safe_zone():
		stop()
		_notify("MU Helper: vào Safe Zone, đã dừng", Color(1.0, 0.8, 0.4))
		return

	# Giây của Helper theo đồng hồ thật
	var away := _dist_tiles(Vector2i(_player.grid_x, _player.grid_y), _origin) > 1
	while _now >= _next_second_at:
		_seconds_elapsed += 1
		_seconds_away = _seconds_away + 1 if away else 0
		_next_second_at += 1.0

	_work()

func _work() -> void:
	_consume_potion() # bình máu khẩn cấp không phải chờ hành động khác
	if not _buff():
		return
	if not _recover_health():
		return
	# Đồ đang đi tới được nhặt trước khi quay về
	if _current_item != null and not _obtain_item():
		return
	if not _regroup():
		return
	if not _obtain_item():
		return
	if _fight_back_player():
		_repair_equipments()
		return
	_attack()
	_repair_equipments()

# ----------------------------------------------------------------- helpers
static func _dist_tiles(a: Vector2i, b: Vector2i) -> int:
	var dx := a.x - b.x
	var dy := a.y - b.y
	return int(ceil(sqrt(float(dx * dx + dy * dy))))

func _hunting_distance() -> int:
	if bool(config["stay_in_place"]):
		# Đứng tại chỗ: chỉ quái trong tầm của đòn đang dùng (đòn chính / đánh thường)
		return int(ceil(_skill_range(int(config["skills"][0]))))
	return _dist_tiles(Vector2i.ZERO, Vector2i(int(config["hunting_range"]), int(config["hunting_range"])))

func _pick_distance() -> int:
	return _dist_tiles(Vector2i.ZERO, Vector2i(int(config["pick_range"]), int(config["pick_range"])))

func _monster_dist(m: MuMonster) -> int:
	return _dist_tiles(Vector2i(_player.grid_x, _player.grid_y), Vector2i(m.grid_x, m.grid_y))

func _hp_percent() -> int:
	if _player.max_hp <= 0 or _player.current_hp <= 0:
		return 100
	return int(ceil(float(_player.current_hp) * 100.0 / float(_player.max_hp)))

func _world() -> Node:
	var p := _player.get_parent()
	return p.get_node_or_null("MuWorld") if p else null

func _all_monsters() -> Array:
	var out: Array = []
	var p := _player.get_parent()
	if p == null:
		return out
	for c in p.get_children():
		if c is MuMonster and not c.is_dead:
			out.append(c)
	return out

func _is_cooling_down(m: MuMonster) -> bool:
	var id := m.get_instance_id()
	if not _target_retry_at.has(id):
		return false
	if _now < float(_target_retry_at[id]):
		return true
	_target_retry_at.erase(id)
	return false

func _forget_target(m: MuMonster, unreachable: bool) -> void:
	if m == _current_target:
		_current_target = null
	if unreachable and is_instance_valid(m):
		_target_retry_at[m.get_instance_id()] = _now + TARGET_RETRY_DELAY

func _is_attacking_player(m: MuMonster) -> bool:
	return m._chasing and _monster_dist(m) <= m.attack_range + 2

func _learned(num: int) -> bool:
	return num > 0 and _player.learned_skills.has(num)

func _skill_range(num: int) -> float:
	if num <= 0:
		return _player.attack_range
	var sk := MuCatalogRes.skill(num)
	return maxf(2.0, float(sk.get("distance", 2)) + 0.5)

func _skill_usable(num: int) -> bool:
	if num <= 0:
		return true
	if not _learned(num):
		return false
	if not _player.check_skill_delay(num):
		return false
	return true

func _mana_cost(num: int) -> int:
	return 0 if num <= 0 else int(MuCatalogRes.skill(num).get("mana", 0))

func _find_inventory_item(group: int, numbers: Array) -> Dictionary:
	# Ưu tiên bình nhỏ nhất đủ dùng -> dùng bình mạnh nhất cuối cùng; ở đây lấy loại có sẵn đầu tiên
	for n in numbers:
		for it in _player.inventory:
			if it is Dictionary and int(it.get("group", -1)) == group and int(it.get("number", -1)) == n:
				return it
	return {}

# ----------------------------------------------------------------- potion / heal
func _consume_potion() -> void:
	if not bool(config["use_heal_potion"]):
		return
	var hp := _hp_percent()
	var spam: bool = bool(config["potion_spam_enabled"]) and hp <= int(config["potion_spam_threshold"])
	if not spam and hp > int(config["potion_threshold"]):
		return
	# Bơm nhồi: máu vẫn tụt sâu -> uống bình mạnh nhất, dồn dập; bơm thường: bình nhỏ nhất, 1 bình / giây
	var gap := 0.3 if spam else 1.0
	if _now - _last_potion_at < gap:
		return
	var order: Array = [3, 2, 1, 0] if spam else [0, 1, 2, 3]
	var it := _find_inventory_item(14, order)
	if it.is_empty():
		it = _find_inventory_item(14, [3, 2, 1, 0])
	if it.is_empty():
		return
	_last_potion_at = _now
	_player.use_item(it)
	if _player.has_signal("inventory_changed"):
		_player.inventory_changed.emit()

func _use_mana_potion() -> bool:
	var it := _find_inventory_item(14, [6, 5, 4])
	if it.is_empty():
		return false
	_player.use_item(it)
	return true

func _find_skill_by_key(fragments: Array) -> int:
	for num in _player.learned_skills:
		var key := str(MuCatalogRes.skill(int(num)).get("key", ""))
		for f in fragments:
			if key.contains(f):
				return int(num)
	return 0

func _recover_health() -> bool:
	if not _heal():
		return false
	return _drain_life()

func _heal() -> bool:
	if not bool(config["auto_heal"]):
		return true
	var skill := _find_skill_by_key(["Heal"])
	if skill == 0 or _hp_percent() > int(config["heal_threshold"]):
		return true
	return _cast_support(skill)

func _drain_life() -> bool:
	if not bool(config["use_drain_life"]):
		return true
	var skill := _find_skill_by_key(["DrainLife", "Drain"])
	if skill == 0 or _hp_percent() > int(config["heal_threshold"]):
		return true
	var t := _nearest_target()
	if t == null:
		return true
	_current_target = t
	return _cast_support(skill, t)

## Skill hỗ trợ: chỉ khi đang thi triển dở mới giữ các hành động sau (SimulateSupportSkill)
func _cast_support(skill: int, target: MuMonster = null) -> bool:
	if not _skill_usable(skill):
		return true
	if _player.attack_timer > 0.0 or _player._action_lock > 0.0:
		return false
	if not _ensure_mana(skill):
		return true
	if target != null:
		_player.target_monster = target
	_player.cast_learned_skill(skill)
	_total_cost += _mana_cost(skill)
	return true

func _ensure_mana(skill: int) -> bool:
	if _player.infinite_hp_mp:
		return true
	var cost := _mana_cost(skill)
	if _player.current_mp >= cost:
		return true
	# Skill không đủ Mana: tự dùng bình Mana (như helper gốc)
	if bool(config["use_heal_potion"]) and _use_mana_potion():
		return _player.current_mp >= cost
	return false

# ----------------------------------------------------------------- buff
func _buff() -> bool:
	var buffs: Array = config["buffs"]
	var has_any := false
	for b in buffs:
		if int(b) != 0:
			has_any = true
	if not has_any:
		return true

	_start_timed_buff_refresh(bool(config["buff_duration"]))
	if not _buff_target(int(buffs[_buff_index])):
		return false

	_buff_index = (_buff_index + 1) % buffs.size()
	# Mọi buff đã được cast xong: đợt làm mới theo giờ hoàn tất
	if _buff_index == 0 and _timer_buff_ongoing:
		_timer_buff_ongoing = false
		_next_buff_at = _seconds_elapsed + int(config["buff_cast_interval"])
	return true

func _start_timed_buff_refresh(refresh_on_expiry_only: bool) -> void:
	if not refresh_on_expiry_only and int(config["buff_cast_interval"]) != 0 \
			and not _timer_buff_ongoing and _seconds_elapsed >= _next_buff_at:
		_timer_buff_ongoing = true

func _buff_duration(skill: int) -> float:
	var sk := MuCatalogRes.skill(skill)
	var d := float(sk.get("duration", 0.0))
	return d if d > 0.0 else 60.0

## 1 = xong / bỏ qua, 0 = đang thi triển dở (giữ lượt)
func _buff_target(skill: int) -> bool:
	if skill == 0 or not _skill_usable(skill):
		return true
	var expired := _now >= float(_buff_until.get(skill, 0.0))
	var due := expired or _timer_buff_ongoing
	if not due:
		return true
	if _player.attack_timer > 0.0 or _player._action_lock > 0.0:
		return false
	if not _ensure_mana(skill):
		return true
	_player.cast_learned_skill(skill)
	_total_cost += _mana_cost(skill)
	_buff_until[skill] = _now + _buff_duration(skill)
	return true

# ----------------------------------------------------------------- target selection
func _cleanup_targets() -> void:
	for id in _attacking.keys():
		var o = instance_from_id(id)
		if not (o is MuMonster) or o.is_dead:
			_attacking.erase(id)

func _in_hunting_range(m: MuMonster) -> bool:
	var counter := bool(config["long_range_counter"]) and _attacking.has(m.get_instance_id())
	return counter or _monster_dist(m) <= _hunting_distance()

func _nearest_target() -> MuMonster:
	var best: MuMonster = null
	var best_d := _hunting_distance()
	for m in _all_monsters():
		if _is_cooling_down(m):
			continue
		var d := _monster_dist(m)
		if d <= best_d:
			best_d = d
			best = m
	return best

func _farthest_attacking_target() -> MuMonster:
	var best: MuMonster = null
	var best_d := -1
	for id in _attacking.keys():
		var m = instance_from_id(id)
		if not (m is MuMonster) or m.is_dead or _is_cooling_down(m):
			continue
		var d := _monster_dist(m)
		if d > best_d:
			best_d = d
			best = m
	return best

func _select_attack_target() -> bool:
	_cleanup_targets()
	# Quái đang đánh mình -> cập nhật danh sách "attacking"
	for m in _all_monsters():
		if _is_attacking_player(m):
			_attacking[m.get_instance_id()] = true
		else:
			_attacking.erase(m.get_instance_id())

	var self_def_target: MuMonster = null
	if bool(config["self_defense"]):
		for m in _all_monsters():
			if _attacking.has(m.get_instance_id()) and not _is_cooling_down(m) and _monster_dist(m) <= _hunting_distance() \
					or (bool(config["long_range_counter"]) and _attacking.has(m.get_instance_id()) and not _is_cooling_down(m)):
				if self_def_target == null or _monster_dist(m) < _monster_dist(self_def_target):
					self_def_target = m
	if is_instance_valid(_current_target) and not _current_target.is_dead:
		var cur_attacking := _attacking.has(_current_target.get_instance_id())
		if self_def_target != null and not cur_attacking:
			_current_target = self_def_target
			return true
		if _in_hunting_range(_current_target) and not _is_cooling_down(_current_target):
			return true
		_current_target = null
	else:
		_current_target = null

	if bool(config["long_range_counter"]):
		_current_target = _farthest_attacking_target()
	if _current_target == null:
		_current_target = self_def_target if self_def_target != null else _nearest_target()
	return _current_target != null

# ----------------------------------------------------------------- đánh trả người chơi
## Có người chơi tấn công mình (hiện chỉ có trận quyết đấu: đối thủ đuổi theo và đánh Hero):
## Helper đánh trả đối thủ thay vì quái, MuSocial lo đuổi theo / tính sát thương.
func _fight_back_player() -> bool:
	if not bool(config["fight_back_players"]):
		return false
	var social = get_tree().get_first_node_in_group("MuSocial")
	if social == null or not social.in_duel():
		return false
	var e = social.duel_enemy
	var hero_dist := _player.global_position.distance_to(e.global_position)
	# Đối thủ đang tấn công: ở sát hoặc đang đuổi theo mình
	var attacked: bool = e.duel_target != null and hero_dist <= 8.0
	if not attacked and not social.duel_attacking:
		return false
	_current_target = null
	_player.clear_target()
	social.attack_duel_enemy()
	return true

# ----------------------------------------------------------------- attack
func _attack() -> bool:
	if not _select_attack_target():
		if _all_monsters().is_empty():
			_combo_state = 0
		# Không còn quái trong bán kính: về tọa độ đã lưu rồi đứng yên chờ quái
		if not bool(config["stay_in_place"]):
			_return_to_origin_idle()
		return false

	var target := _current_target
	if bool(config["use_combo"]):
		return _combo_attack(target)

	var slot := _select_attack_slot()
	if slot >= 0:
		var skill := int(config["skills"][slot])
		var res := _cast_attack(skill, target)
		_complete_slot(slot, res)
		return res == "cast"
	return _fallback_basic(target)

func _fallback_basic(target: MuMonster) -> bool:
	if not bool(config["fallback_basic_attack"]) and int(config["skills"][0]) != 0:
		return false
	return _cast_attack(0, target) == "cast"

func _combo_attack(target: MuMonster) -> bool:
	var skills: Array = config["skills"]
	for s in skills:
		if int(s) <= 0:
			return false
	if _cast_attack(int(skills[_combo_state]), target) == "cast":
		_combo_state = (_combo_state + 1) % 3
	return true

## Chọn ô đòn đánh: đòn phụ có Delay/Condition được ưu tiên, còn lại xoay vòng (AttackSkillRotation::Select)
func _select_attack_slot() -> int:
	var skills: Array = config["skills"]
	var nearby := 0
	var attacking := 0
	for m in _all_monsters():
		if _in_hunting_range(m):
			nearby += 1
			if _attacking.has(m.get_instance_id()):
				attacking += 1

	for slot in [1, 2]:
		var s := int(skills[slot])
		if s <= 0 or not _skill_usable(s):
			continue
		var by_timer := bool(config["skill_use_timer"][slot])
		var by_cond := bool(config["skill_use_condition"][slot])
		if not by_timer and not by_cond:
			continue
		if by_timer:
			var iv := int(config["skill_interval"][slot])
			if _seconds_elapsed - int(_skill_last_cast.get(slot, 0)) >= iv:
				_skill_due[slot] = true
		var cond_ok := false
		if by_cond and _now >= float(_condition_yield_until.get(slot, 0.0)):
			var count := attacking if int(config["skill_precon"][slot]) == PRE_ATTACKING else nearby
			var need := maxi(1, int(config["skill_subcon"][slot]) + 0)
			if int(config["skill_subcon"][slot]) <= 0:
				need = 1
			cond_ok = count >= need
		if bool(_skill_due.get(slot, false)) or cond_ok:
			return slot

	# Xoay vòng giữa đòn chính và các đòn phụ không có Delay / Condition
	var pool: Array = [0]
	for slot in [1, 2]:
		var s2 := int(skills[slot])
		if s2 > 0 and not bool(config["skill_use_timer"][slot]) and not bool(config["skill_use_condition"][slot]):
			pool.append(slot)
	for i in range(pool.size()):
		var slot2: int = pool[(_rotation_index + i) % pool.size()]
		var sk := int(skills[slot2])
		if slot2 == 0 and sk <= 0:
			return 0 if pool.size() == 1 else -1
		if _skill_usable(sk):
			_rotation_index = (_rotation_index + i) % pool.size()
			return slot2
	return -1

func _complete_slot(slot: int, result: String) -> void:
	if result == "cast" or result == "refused":
		_no_action_count = 0
		_skill_last_cast[slot] = _seconds_elapsed
		_skill_due[slot] = false
		_rotation_index += 1
	elif result == "none":
		_no_action_count += 1
		if _no_action_count >= NO_ACTION_YIELD:
			_no_action_count = 0
			_skill_last_cast[slot] = _seconds_elapsed
			_skill_due[slot] = false
			_rotation_index += 1
			if bool(config["skill_use_condition"][slot]):
				_condition_yield_until[slot] = _now + 1.0
	if result == "refused" and bool(config["skill_use_condition"][slot]):
		_condition_yield_until[slot] = _now + 1.0

## return: "cast" | "busy" | "approach" | "refused" | "none"
func _cast_attack(skill: int, target: MuMonster) -> String:
	if not is_instance_valid(target) or target.is_dead:
		return "none"
	var reach := _skill_range(skill)
	var dist := _player.global_position.distance_to(target.global_position)

	# Chưa tới tầm: đi tới gần mục tiêu (chế độ đứng tại chỗ thì không di chuyển)
	if dist > reach:
		if bool(config["stay_in_place"]):
			return "none"
		if _player.waypoints.is_empty() and not _player.is_moving:
			var world := _world()
			if world == null:
				_forget_target(target, true)
				return "refused"
			var my_tile := Vector2i(_player.grid_x, _player.grid_y)
			var path: Array[Vector2i] = world.find_path_grid(my_tile, Vector2i(target.grid_x, target.grid_y))
			if path.size() <= 1:
				_forget_target(target, true)
				return "refused"
			path.remove_at(path.size() - 1)
			_player.move_to_path(path)
		_player.target_monster = target
		return "approach"

	if _player.is_moving:
		_player.waypoints.clear()
	if _player.attack_timer > 0.0 or _player._action_lock > 0.0:
		return "busy"

	_player.target_monster = target
	if skill <= 0:
		_player._perform_attack()
		return "cast"
	if not _skill_usable(skill):
		return "refused"
	if not _ensure_mana(skill):
		return "refused"
	_player.cast_learned_skill(skill)
	_total_cost += _mana_cost(skill)
	return "cast"

# ----------------------------------------------------------------- regroup
## Hết quái trong bán kính: đi bộ về vị trí lúc bật Helper (đã lưu ở _origin) và đứng yên
func _return_to_origin_idle() -> void:
	var here := Vector2i(_player.grid_x, _player.grid_y)
	if _dist_tiles(here, _origin) <= 0:
		return
	if _player.is_moving or not _player.waypoints.is_empty():
		return # đang đi: hoàn tất đường hiện tại
	var world := _world()
	if world == null:
		return
	var path: Array[Vector2i] = world.find_path_grid(here, _origin)
	if path.size() < 1:
		return
	_player.clear_target()
	_player.move_to_path(path)

func _regroup() -> bool:
	if bool(config["stay_in_place"]) or not bool(config["return_to_origin"]) or _seconds_away <= int(config["max_seconds_away"]):
		return true
	var here := Vector2i(_player.grid_x, _player.grid_y)
	if _dist_tiles(here, _origin) <= 1:
		_seconds_away = 0
		_combo_state = 0
		_current_target = null
		return true
	if _player.is_moving or not _player.waypoints.is_empty():
		return false # đang đi: hoàn tất đường hiện tại trước khi lập đường mới
	var world := _world()
	if world == null:
		return true
	var path: Array[Vector2i] = world.find_path_grid(here, _origin)
	if path.size() <= 1:
		return true # không có đường: tiếp tục đánh, lần sau thử lại
	_player.clear_target()
	_player.move_to_path(path)
	return false

# ----------------------------------------------------------------- pickup
func _drop_tile(d: MuDropItem) -> Vector2i:
	return MuWorld.world_to_grid(d.global_position)

func _should_pick(d: MuDropItem) -> bool:
	if d.is_picked or d.is_despawned or d._is_falling or d.pickup_delay > 0.0:
		return false
	var id := d.get_instance_id()
	if _item_retry_at.has(id) and _now < float(_item_retry_at[id]):
		return false
	if bool(config["pick_all"]):
		return true
	if not bool(config["pick_select"]):
		return false
	var it: Dictionary = d.item_dict
	var is_zen := d.category == MuDropItem.ItemCategory.ZEN
	if bool(config["pick_zen"]) and is_zen:
		return true
	if it.is_empty():
		return false
	if bool(config["pick_jewel"]) and MuItemsRes.is_jewel(it):
		return true
	if bool(config["pick_ancient"]) and (bool(it.get("ancient", false)) or int(it.get("ancient", 0)) > 0):
		return true
	if bool(config["pick_excellent"]) and bool(it.get("excellent", false)):
		return true
	if bool(config["pick_extra"]):
		var nm := MuItemsRes.display_name(it).to_lower()
		for part in str(config["extra_items"]).split(";", false):
			var p := part.strip_edges().to_lower()
			if p != "" and nm.contains(p):
				return true
	return false

func _select_item_to_obtain() -> MuDropItem:
	var best: MuDropItem = null
	var best_d := _pick_distance()
	var p := _player.get_parent()
	if p == null:
		return null
	var here := Vector2i(_player.grid_x, _player.grid_y)
	for c in p.get_children():
		if c is MuDropItem and _should_pick(c):
			var d := _dist_tiles(here, _drop_tile(c))
			if d <= best_d:
				best_d = d
				best = c
	return best

## true = tiếp tục các việc khác, false = đang đi tới đồ (giữ lượt)
func _obtain_item() -> bool:
	if _current_item == null or not is_instance_valid(_current_item) \
			or _current_item.is_picked or _current_item.is_despawned:
		if _current_item != null:
			_forget_item(_current_item)
		_current_item = _select_item_to_obtain()
		if _current_item == null:
			return true

	var item := _current_item
	var id := item.get_instance_id()
	var here := Vector2i(_player.grid_x, _player.grid_y)
	var tile := _drop_tile(item)
	if _dist_tiles(here, tile) > _pick_distance():
		_current_item = null
		return true

	if _dist_tiles(here, tile) <= 1 or _player.global_position.distance_to(item.global_position) <= 1.6:
		# Yêu cầu nhặt; bị từ chối (đầy túi) thì thử lại sau 3s rồi 6s, bỏ sau lần thứ 3
		var n := int(_item_requests.get(id, 0)) + 1
		_item_requests[id] = n
		item.pickup(_player)
		if item.is_picked:
			_forget_item(item)
			return true
		if n >= MAX_PICKUP_REQUESTS:
			_forget_item(item)
			_item_retry_at[id] = _now + 1.0e9
			return true
		_item_retry_at[id] = _now + PICKUP_REQUEST_RETRY_DELAY * float(1 << (n - 1))
		_current_item = null
		return true

	if _player.is_moving or not _player.waypoints.is_empty():
		return false
	var world := _world()
	if world == null:
		_current_item = null
		return true
	if bool(config["stay_in_place"]):
		_item_retry_at[id] = _now + PICKUP_RETRY_DELAY
		_current_item = null
		return true
	var path: Array[Vector2i] = world.find_path_grid(here, tile)
	if path.is_empty():
		# Không có đường: đợi 1 giây rồi thử lại, chiến đấu vẫn tiếp tục
		_item_retry_at[id] = _now + PICKUP_RETRY_DELAY
		_current_item = null
		return true
	_player.clear_target()
	_player.move_to_path(path)
	return false

func _forget_item(item: MuDropItem) -> void:
	if is_instance_valid(item):
		_item_requests.erase(item.get_instance_id())
	if item == _current_item:
		_current_item = null

# ----------------------------------------------------------------- repair
func _repair_equipments() -> void:
	if not bool(config["repair_item"]) or _now - _last_repair_at < 5.0:
		return
	_last_repair_at = _now
	var need := false
	for slot in _player.equipment:
		var it = _player.equipment[slot]
		if it is Dictionary and it.has("dur") and int(it.get("dur", 255)) * 100 / 255 <= REPAIR_THRESHOLD:
			need = true
	if need:
		_player.repair_all_items()
