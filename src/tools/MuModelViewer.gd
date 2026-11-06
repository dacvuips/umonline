extends Node3D

## MU Model Viewer — xem mọi model đã chuyển (assets/mu), chạy từng action, mặc thử đồ + phát sáng.
## Mở: dock "MU Tools" -> "Mở Model Viewer", hoặc mở src/tools/MuModelViewer.tscn rồi bấm F6.
## Chuột phải / giữa kéo: xoay ; lăn chuột: phóng to.

const MuModelRes = preload("res://src/mu/MuModel.gd")
const MuCatalogRes = preload("res://src/mu/MuCatalog.gd")
const MuCharModelRes = preload("res://src/mu/MuCharacterModel.gd")
const INDEX := "res://assets/mu/mu_models_index.json"

const CLASS_NAMES := ["Dark Wizard", "Dark Knight", "Fairy Elf", "Magic Gladiator", "Dark Lord", "Summoner", "Rage Fighter"]
const PLAYER_ACTION_NAMES := {
	1: "STOP_MALE", 2: "STOP_FEMALE", 3: "STOP_SUMMONER", 4: "STOP_SWORD", 5: "STOP_TWO_HAND_SWORD", 6: "STOP_SPEAR",
	7: "STOP_SCYTHE", 8: "STOP_BOW", 9: "STOP_CROSSBOW", 10: "STOP_WAND", 11: "STOP_FLY", 15: "WALK_MALE", 16: "WALK_FEMALE",
	17: "WALK_SWORD", 18: "WALK_TWO_HAND_SWORD", 19: "WALK_SPEAR", 21: "WALK_BOW", 22: "WALK_CROSSBOW", 23: "WALK_WAND",
	25: "RUN", 26: "RUN_SWORD", 27: "RUN_TWO_SWORD", 28: "RUN_TWO_HAND_SWORD", 29: "RUN_SPEAR", 30: "RUN_BOW",
	31: "RUN_CROSSBOW", 32: "RUN_WAND", 34: "FLY", 38: "ATTACK_FIST", 39: "ATTACK_SWORD_RIGHT1", 40: "ATTACK_SWORD_RIGHT2",
	43: "ATTACK_TWO_HAND_SWORD1", 46: "ATTACK_SPEAR1", 50: "ATTACK_BOW", 51: "ATTACK_CROSSBOW", 60: "SKILL_SWORD1",
	61: "SKILL_SWORD2", 62: "SKILL_SWORD3", 63: "SKILL_SWORD4", 64: "SKILL_SWORD5", 65: "SKILL_WHEEL", 66: "FURY_STRIKE",
	71: "DEATHSTAB", 146: "SKILL_HAND1", 147: "SKILL_HAND2", 148: "SKILL_WEAPON1", 149: "SKILL_WEAPON2", 150: "SKILL_ELF1",
	151: "SKILL_TELEPORT", 152: "SKILL_FLASH", 153: "SKILL_INFERNO", 154: "SKILL_HELL", 172: "SKILL_SUMMON",
	192: "DEFENSE1", 193: "GREETING1", 236: "SHOCK", 237: "DIE1", 238: "DIE2", 239: "SIT1", 243: "HEALING1", 245: "POSE1",
}
const MONSTER_ACTION_NAMES := {0: "STOP1", 1: "STOP2", 2: "WALK", 3: "ATTACK1", 4: "ATTACK2", 5: "SHOCK", 6: "DIE"}

var _holder: Node3D
var _cam: Camera3D
var _yaw := 45.0
var _pitch := -20.0
var _dist := 4.0
var _target := Vector3(0, 0.9, 0)
var _anim: AnimationPlayer
var _is_player_rig := false
var _index: Dictionary = {}
var _keys: PackedStringArray = []

# UI
var _tabs: TabContainer
var _class_opt: OptionButton
var _set_spin: SpinBox
var _lvl_spin: SpinBox
var _exc_chk: CheckBox
var _wg_spin: SpinBox
var _wn_spin: SpinBox
var _lg_spin: SpinBox
var _ln_spin: SpinBox
var _wing_spin: SpinBox
var _mon_spin: SpinBox
var _mon_label: Label
var _filter: LineEdit
var _list: ItemList
var _act_opt: OptionButton
var _speed: HSlider
var _speed_label: Label
var _loop_chk: CheckBox
var _info: Label

func _ready() -> void:
	MuModelRes.fixed_light = 1.0
	_build_scene()
	_build_ui()
	_load_index()
	_build_player()

# ================================================================== cảnh 3D
func _build_scene() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.16, 0.17, 0.2)
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	add_child(env)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(6, 6)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(0.24, 0.25, 0.28)
	floor_mi.material_override = fm
	add_child(floor_mi)
	# lưới 1 ô = 1 tile MU (100 đơn vị)
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(-3, 4):
		im.surface_add_vertex(Vector3(i, 0.002, -3))
		im.surface_add_vertex(Vector3(i, 0.002, 3))
		im.surface_add_vertex(Vector3(-3, 0.002, i))
		im.surface_add_vertex(Vector3(3, 0.002, i))
	im.surface_end()
	var grid := MeshInstance3D.new()
	grid.mesh = im
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.albedo_color = Color(0.4, 0.42, 0.46)
	grid.material_override = gm
	add_child(grid)
	_holder = Node3D.new()
	add_child(_holder)
	_cam = Camera3D.new()
	_cam.fov = 40
	_cam.near = 0.05
	add_child(_cam)
	_update_cam()

func _update_cam() -> void:
	var b := Basis.from_euler(Vector3(deg_to_rad(_pitch), deg_to_rad(_yaw), 0))
	_cam.global_transform = Transform3D(b, _target + b.z * _dist)

func _unhandled_input(ev: InputEvent) -> void:
	var mm := ev as InputEventMouseMotion
	if mm and (mm.button_mask & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE | MOUSE_BUTTON_MASK_LEFT)):
		_yaw -= mm.relative.x * 0.4
		_pitch = clampf(_pitch - mm.relative.y * 0.3, -85, 60)
		_update_cam()
		return
	var mb := ev as InputEventMouseButton
	if mb and mb.pressed:
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = maxf(0.5, _dist * 0.9)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = minf(40.0, _dist * 1.1)
		_update_cam()

# ================================================================== giao diện
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(8, 8)
	panel.custom_minimum_size = Vector2(330, 0)
	layer.add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	var t := Label.new()
	t.text = "MU Model Viewer"
	v.add_child(t)
	_tabs = TabContainer.new()
	_tabs.custom_minimum_size = Vector2(320, 300)
	v.add_child(_tabs)

	# --- Nhân vật
	var pv := VBoxContainer.new()
	pv.name = "Nhân vật"
	_tabs.add_child(pv)
	_class_opt = OptionButton.new()
	for i in CLASS_NAMES.size():
		_class_opt.add_item(CLASS_NAMES[i], i)
	_class_opt.selected = 1
	pv.add_child(_row("Lớp", _class_opt))
	_set_spin = _spin(-1, 200, 1)
	pv.add_child(_row("Bộ giáp số (-1 = mặc định)", _set_spin))
	_lvl_spin = _spin(0, 15, 11)
	pv.add_child(_row("Cấp đồ +", _lvl_spin))
	_exc_chk = CheckBox.new()
	_exc_chk.text = "Excellent"
	pv.add_child(_exc_chk)
	_wg_spin = _spin(0, 6, 0)
	_wn_spin = _spin(-1, 200, 5)
	pv.add_child(_row("Tay phải: nhóm / số", _wg_spin, _wn_spin))
	_lg_spin = _spin(0, 6, 6)
	_ln_spin = _spin(-1, 200, -1)
	pv.add_child(_row("Tay trái: nhóm / số", _lg_spin, _ln_spin))
	_wing_spin = _spin(-1, 300, -1)
	pv.add_child(_row("Cánh số (-1 = không)", _wing_spin))
	var bp := Button.new()
	bp.text = "Dựng nhân vật"
	bp.pressed.connect(_build_player)
	pv.add_child(bp)

	# --- Quái / NPC
	var mv := VBoxContainer.new()
	mv.name = "Quái / NPC"
	_tabs.add_child(mv)
	_mon_spin = _spin(0, 1000, 0)
	var prev := Button.new()
	prev.text = "<"
	prev.pressed.connect(_step_monster.bind(-1))
	var nxt := Button.new()
	nxt.text = ">"
	nxt.pressed.connect(_step_monster.bind(1))
	mv.add_child(_row("Số hiệu", prev, _mon_spin, nxt))
	_mon_label = Label.new()
	_mon_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	mv.add_child(_mon_label)
	var bm := Button.new()
	bm.text = "Xem"
	bm.pressed.connect(_build_monster)
	mv.add_child(bm)

	# --- Model bất kỳ
	var av := VBoxContainer.new()
	av.name = "Model"
	_tabs.add_child(av)
	_filter = LineEdit.new()
	_filter.placeholder_text = "Lọc (vd: Wing, Monster/Monster1, Skill)"
	_filter.text_changed.connect(func(_t): _refresh_list())
	av.add_child(_filter)
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(0, 220)
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(func(i): _build_any(_list.get_item_text(i)))
	av.add_child(_list)

	# --- animation
	_act_opt = OptionButton.new()
	_act_opt.item_selected.connect(func(_i): _play_selected())
	v.add_child(_row("Action", _act_opt))
	_speed = HSlider.new()
	_speed.min_value = 0.02
	_speed.max_value = 1.0
	_speed.step = 0.01
	_speed.value = 0.25
	_speed.custom_minimum_size = Vector2(150, 0)
	_speed.value_changed.connect(func(_x): _play_selected())
	_speed_label = Label.new()
	v.add_child(_row("PlaySpeed", _speed, _speed_label))
	_loop_chk = CheckBox.new()
	_loop_chk.text = "Lặp"
	_loop_chk.button_pressed = true
	_loop_chk.toggled.connect(func(_b): _play_selected())
	v.add_child(_loop_chk)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	_info.custom_minimum_size = Vector2(320, 0)
	v.add_child(_info)

func _spin(lo: float, hi: float, val: float) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.value = val
	s.allow_greater = true
	return s

func _row(text: String, a: Control, b: Control = null, c: Control = null) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = text
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	for x in [a, b, c]:
		if x:
			h.add_child(x)
	return h

# ================================================================== dựng model
func _clear() -> void:
	for c in _holder.get_children():
		c.queue_free()
	_anim = null

func _build_player() -> void:
	_clear()
	var lv := int(_lvl_spin.value)
	var exc := _exc_chk.button_pressed
	var eq := {}
	var sn := int(_set_spin.value)
	if sn >= 0:
		var g := 7
		for slot in ["helm", "armor", "pants", "gloves", "boots"]:
			eq[slot] = {"group": g, "number": sn, "level": lv, "excellent": exc}
			g += 1
	if int(_wn_spin.value) >= 0:
		eq["right"] = {"group": int(_wg_spin.value), "number": int(_wn_spin.value), "level": lv, "excellent": exc}
	if int(_ln_spin.value) >= 0:
		eq["left"] = {"group": int(_lg_spin.value), "number": int(_ln_spin.value), "level": lv, "excellent": exc}
	if int(_wing_spin.value) >= 0:
		eq["wings"] = {"group": 12, "number": int(_wing_spin.value), "level": lv}
	var m := MuCharModelRes.new()
	_holder.add_child(m)
	if not m.build_player(_class_opt.selected, eq):
		_info.text = "Chưa có res://assets/mu/Player/player.glb — chạy 'Chuyển TẤT CẢ' trong dock MU Tools."
		return
	_is_player_rig = true
	_anim = m.anim
	var txt := "%s" % CLASS_NAMES[_class_opt.selected]
	if sn >= 0:
		txt += " | bộ: %s +%d%s" % [MuCatalogRes.item_name(8, sn), lv, " Exc" if exc else ""]
	if eq.has("right"):
		txt += " | phải: %s" % MuCatalogRes.item_name(int(_wg_spin.value), int(_wn_spin.value))
	if eq.has("left"):
		txt += " | trái: %s" % MuCatalogRes.item_name(int(_lg_spin.value), int(_ln_spin.value))
	if eq.has("wings"):
		txt += " | cánh: %s" % MuCatalogRes.item_name(12, int(_wing_spin.value))
	txt += "\nvũ khí: %s%s" % [m.weapon_kind if m.weapon_kind != "" else "tay không", " (2 tay)" if m.two_handed else ""]
	_info.text = txt
	_fill_actions(1)

func _step_monster(d: int) -> void:
	_mon_spin.value += d
	_build_monster()

func _build_monster() -> void:
	_clear()
	var num := int(_mon_spin.value)
	var mon: Dictionary = MuCatalogRes.find_monster(num)
	if mon.is_empty():
		_mon_label.text = "#%d: không có trong Monsters.json" % num
		return
	var nm = mon.get("name", {})
	var en: String = nm.get("en", "") if nm is Dictionary else str(nm)
	var model: Dictionary = MuCatalogRes.monster_model(mon)
	_mon_label.text = "#%d %s (%s)\nmodel: %s\nfile: %s\nscale: %.2f" % [num, en, mon.get("kind", ""), mon.get("model", ""),
		model.get("file", "?"), MuCharModelRes.monster_scale(num)]
	var m := MuCharModelRes.new()
	_holder.add_child(m)
	if not m.build_monster(num):
		_mon_label.text += "\n(chưa có .glb — chạy chuyển đổi)"
		return
	_is_player_rig = m.is_player
	_anim = m.anim
	_fill_actions(1 if m.is_player else 0)

func _build_any(key: String) -> void:
	_clear()
	var path := "res://assets/mu/%s.glb" % key
	var inst := MuModelRes.instantiate(path)
	if inst == null:
		_info.text = "Không mở được " + path
		return
	_holder.add_child(inst)
	MuModelRes.apply_materials(inst)
	_anim = MuModelRes.find_first(inst, "AnimationPlayer") as AnimationPlayer
	_is_player_rig = key.to_lower() == "player/player"
	var d: Dictionary = _index.get(key, {})
	_info.text = "%s\nxương: %s | mesh: %s | action: %d\ntexture: %s" % [key, str(d.get("bones", 0)), str(d.get("meshes", 0)),
		d.get("actions", []).size(), ", ".join(PackedStringArray(d.get("textures", [])))]
	_fill_actions(0)

func _fill_actions(default_action: int) -> void:
	_act_opt.clear()
	if _anim == null:
		_act_opt.add_item("(không có animation)", -1)
		return
	var names := _anim.get_animation_list()
	var sel := 0
	for n in names:
		if not n.begins_with("a"):
			continue
		var a := n.substr(1).to_int()
		var label := "%03d" % a
		var dict: Dictionary = PLAYER_ACTION_NAMES if _is_player_rig else MONSTER_ACTION_NAMES
		if dict.has(a):
			label += "  " + dict[a]
		var nk := int(_anim.get_animation(n).length * 4.0)
		label += "  (%d key)" % nk
		_act_opt.add_item(label, a)
		if a == default_action:
			sel = _act_opt.item_count - 1
	if _act_opt.item_count > 0:
		_act_opt.selected = sel
		var a0 := _act_opt.get_item_id(sel)
		_speed.set_value_no_signal(MuCharModelRes.PLAYER_SPEED.get(a0, 0.25) if _is_player_rig else 0.25)
	_play_selected()

func _play_selected() -> void:
	_speed_label.text = "%.2f" % _speed.value
	if _anim == null or _act_opt.item_count == 0:
		return
	var a := _act_opt.get_item_id(_act_opt.selected)
	if a < 0:
		return
	MuModelRes.play(_anim, a, _speed.value, _loop_chk.button_pressed, true)

# ================================================================== danh sách
func _load_index() -> void:
	if FileAccess.file_exists(INDEX):
		var d = JSON.parse_string(FileAccess.get_file_as_string(INDEX))
		if d is Dictionary:
			_index = d
	var ks := _index.keys()
	ks.sort()
	_keys = PackedStringArray(ks)
	_refresh_list()

func _refresh_list() -> void:
	_list.clear()
	var f := _filter.text.strip_edges().to_lower()
	var n := 0
	for k in _keys:
		if f == "" or k.to_lower().contains(f):
			_list.add_item(k)
			n += 1
			if n >= 2000:
				break
