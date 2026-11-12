extends PanelContainer
## Cửa sổ cấu hình MU Helper (tương ứng mu_helper_config.rml của client gốc).
## Mở bằng phím End, bật/tắt Helper bằng phím Home.

const MuCatalogRes = preload("res://src/mu/MuCatalog.gd")

var helper = null
var player = null
var _ctl: Dictionary = {}   # key -> Control
var _skill_opts: Array = []
var _buff_opts: Array = []
var _start_btn: Button = null
var _drag := false
var _drag_off := Vector2.ZERO

func setup(h, p) -> void:
	helper = h
	player = p
	helper.state_changed.connect(func(_a): _refresh_start_btn())
	_build()

func _ready() -> void:
	visible = false
	z_index = 36
	position = Vector2(120, 40)
	custom_minimum_size = Vector2(430, 0)

func toggle() -> void:
	visible = not visible
	if visible:
		_reload()

func _build() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.10, 0.96)
	sb.border_color = Color(0.75, 0.6, 0.25)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(8)
	add_theme_stylebox_override("panel", sb)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	add_child(root)

	var title := Label.new()
	title.text = "MU HELPER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	title.mouse_filter = Control.MOUSE_FILTER_STOP
	title.gui_input.connect(_on_title_input)
	root.add_child(title)

	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(414, 330)
	root.add_child(tabs)

	var t1 := _tab(tabs, "Săn quái")
	_check(t1, "stay_in_place", "Đứng tại chỗ (chỉ đánh quái trong tầm đòn, không di chuyển)")
	_spin(t1, "hunting_range", "Bán kính tìm quái (ô)", 1, 12)
	_check(t1, "long_range_counter", "Phản công từ xa")
	_check(t1, "self_defense", "Tự vệ (ưu tiên quái đang đánh mình)")
	_check(t1, "fight_back_players", "Đánh trả người chơi khác khi bị tấn công")
	_check(t1, "return_to_origin", "Quay về vị trí ban đầu")
	_spin(t1, "max_seconds_away", "Số giây tối đa rời vị trí", 1, 300)
	_check(t1, "fallback_basic_attack", "Dùng đánh thường khi không dùng được skill")
	_check(t1, "use_combo", "Combo (đòn 1 → 2 → 3)")
	for i in 3:
		_skill_opts.append(_skill_row(t1, i))

	var t2 := _tab(tabs, "Hỗ trợ")
	for i in 3:
		_buff_opts.append(_buff_row(t2, i))
	_check(t2, "buff_duration", "Buff lại khi hết hạn")
	_spin(t2, "buff_cast_interval", "Chu kỳ buff lại (giây, 0 = tắt)", 0, 3600)
	_check(t2, "auto_heal", "Tự hồi máu bằng skill (Healing)")
	_spin(t2, "heal_threshold", "Hồi máu khi HP ≤ (%)", 1, 100)
	_check(t2, "use_drain_life", "Dùng Drain Life")
	_check(t2, "use_heal_potion", "Tự uống bình máu / mana")
	_spin(t2, "potion_threshold", "Bơm máu khi HP ≤ (%)", 1, 100)
	_check(t2, "potion_spam_enabled", "Bơm nhồi (uống liên tục bình lớn nhất)")
	_spin(t2, "potion_spam_threshold", "Bơm nhồi khi HP ≤ (%)", 1, 100)
	_check(t2, "repair_item", "Tự sửa trang bị (độ bền ≤ 50%)")

	var t3 := _tab(tabs, "Nhặt đồ")
	_spin(t3, "pick_range", "Tầm nhặt (ô)", 1, 12)
	_check(t3, "pick_all", "Nhặt tất cả")
	_check(t3, "pick_select", "Nhặt theo chọn lọc")
	_check(t3, "pick_zen", "   Zen")
	_check(t3, "pick_jewel", "   Ngọc (Jewel)")
	_check(t3, "pick_ancient", "   Ancient")
	_check(t3, "pick_excellent", "   Excellent")
	_check(t3, "pick_extra", "   Vật phẩm thêm (tên, ngăn cách bằng ;)")
	var le := LineEdit.new()
	le.placeholder_text = "Jewel of Bless;Jewel of Soul"
	le.text_changed.connect(func(t): helper.config["extra_items"] = t)
	_ctl["extra_items"] = le
	t3.add_child(le)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(row)
	_start_btn = Button.new()
	_start_btn.pressed.connect(func():
		helper.save_config()
		helper.toggle())
	row.add_child(_start_btn)
	var save := Button.new()
	save.text = "Lưu"
	save.pressed.connect(helper.save_config)
	row.add_child(save)
	var close := Button.new()
	close.text = "Đóng"
	close.pressed.connect(func(): visible = false)
	row.add_child(close)
	_refresh_start_btn()

func _on_title_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		_drag = ev.pressed
		_drag_off = get_global_mouse_position() - global_position
	elif ev is InputEventMouseMotion and _drag:
		global_position = get_global_mouse_position() - _drag_off

func _refresh_start_btn() -> void:
	if _start_btn:
		_start_btn.text = "Dừng (Home)" if helper.active else "Bắt đầu (Home)"

func _tab(tabs: TabContainer, title: String) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.name = title
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 3)
	sc.add_child(v)
	tabs.add_child(sc)
	return v

func _check(parent: Control, key: String, text: String) -> void:
	var cb := CheckBox.new()
	cb.text = text
	cb.toggled.connect(func(on): helper.config[key] = on)
	_ctl[key] = cb
	parent.add_child(cb)

func _spin(parent: Control, key: String, text: String, lo: int, hi: int) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = text
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var sp := SpinBox.new()
	sp.min_value = lo
	sp.max_value = hi
	sp.value_changed.connect(func(v): helper.config[key] = int(v))
	_ctl[key] = sp
	h.add_child(sp)
	parent.add_child(h)

func _skill_row(parent: Control, idx: int) -> OptionButton:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = "Đòn chính" if idx == 0 else "Đòn phụ %d" % idx
	l.custom_minimum_size.x = 70
	h.add_child(l)
	var ob := OptionButton.new()
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ob.item_selected.connect(func(i): helper.config["skills"][idx] = int(ob.get_item_metadata(i)))
	h.add_child(ob)
	parent.add_child(h)
	if idx > 0:
		var h2 := HBoxContainer.new()
		var cbt := CheckBox.new()
		cbt.text = "Delay"
		cbt.toggled.connect(func(on): helper.config["skill_use_timer"][idx] = on)
		h2.add_child(cbt)
		var sp := SpinBox.new()
		sp.max_value = 600
		sp.suffix = "s"
		sp.value_changed.connect(func(v): helper.config["skill_interval"][idx] = int(v))
		h2.add_child(sp)
		var cbc := CheckBox.new()
		cbc.text = "Điều kiện"
		cbc.toggled.connect(func(on): helper.config["skill_use_condition"][idx] = on)
		h2.add_child(cbc)
		var pre := OptionButton.new()
		pre.add_item("Quái gần", 0)
		pre.add_item("Quái đang đánh", 1)
		pre.item_selected.connect(func(i): helper.config["skill_precon"][idx] = i)
		h2.add_child(pre)
		var sub := OptionButton.new()
		for n in [1, 2, 3, 4, 5]:
			sub.add_item("≥ %d" % n if n == 1 else "> %d" % n, n)
		sub.item_selected.connect(func(i): helper.config["skill_subcon"][idx] = int(sub.get_item_id(i)))
		h2.add_child(sub)
		parent.add_child(h2)
		ob.set_meta("cb_timer", cbt)
		ob.set_meta("sp_interval", sp)
		ob.set_meta("cb_cond", cbc)
		ob.set_meta("pre", pre)
		ob.set_meta("sub", sub)
	return ob

func _buff_row(parent: Control, idx: int) -> OptionButton:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = "Buff %d" % (idx + 1)
	l.custom_minimum_size.x = 70
	h.add_child(l)
	var ob := OptionButton.new()
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ob.item_selected.connect(func(i): helper.config["buffs"][idx] = int(ob.get_item_metadata(i)))
	h.add_child(ob)
	parent.add_child(h)
	return ob

func _skill_name(num: int) -> String:
	var sk := MuCatalogRes.skill(num)
	return MuCatalogRes.get_skill_vietnamese_name(num, str(sk.get("name", "Skill %d" % num)))

func _fill_skill_options(ob: OptionButton, buff_only: bool, selected: int) -> void:
	ob.clear()
	ob.add_item("(Trống)" if buff_only else "Đánh thường")
	ob.set_item_metadata(0, 0)
	var sel_idx := 0
	for n in player.learned_skills:
		var num := int(n)
		if num <= 0 or num >= 300:
			continue
		var is_buff: bool = player.skill_kind(MuCatalogRes.skill(num)) == "buff"
		if is_buff != buff_only:
			continue
		ob.add_item(_skill_name(num))
		var i := ob.item_count - 1
		ob.set_item_metadata(i, num)
		if num == selected:
			sel_idx = i
	ob.select(sel_idx)

func _reload() -> void:
	var c: Dictionary = helper.config
	for key in _ctl.keys():
		var w: Control = _ctl[key]
		if w is CheckBox:
			w.set_pressed_no_signal(bool(c[key]))
		elif w is SpinBox:
			w.set_value_no_signal(float(c[key]))
		elif w is LineEdit:
			w.text = str(c[key])
	for i in _skill_opts.size():
		var ob: OptionButton = _skill_opts[i]
		_fill_skill_options(ob, false, int(c["skills"][i]))
		if i > 0:
			ob.get_meta("cb_timer").set_pressed_no_signal(bool(c["skill_use_timer"][i]))
			ob.get_meta("sp_interval").set_value_no_signal(float(c["skill_interval"][i]))
			ob.get_meta("cb_cond").set_pressed_no_signal(bool(c["skill_use_condition"][i]))
			ob.get_meta("pre").select(int(c["skill_precon"][i]))
			var sub: OptionButton = ob.get_meta("sub")
			var want := maxi(1, int(c["skill_subcon"][i]))
			for j in sub.item_count:
				if sub.get_item_id(j) == want:
					sub.select(j)
	for i in _buff_opts.size():
		_fill_skill_options(_buff_opts[i], true, int(c["buffs"][i]))
