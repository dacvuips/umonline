extends Control
class_name MuItemGrid

## Lưới ô đồ của MU (túi đồ 8x8, rương NPC 8x15...). Mỗi ô 20x20 đơn vị MU (newui_item_box).
## items: Array các Dictionary đồ (MuItems) có x, y. Vẽ nền ô + ảnh 3D của đồ + màu nền đồ khi rê chuột.

signal cell_clicked(col: int, row: int, button: int)
signal hover_changed(item: Dictionary)
## Nhả chuột trái sau khi bấm ở một ô khác / ngoài lưới (kéo thả): vị trí màn hình, ô đang chỉ tới, có nằm trong lưới không
signal released_at(global_pos: Vector2, cell: Vector2i, inside: bool)

const MuItemsRes = preload("res://src/mu/MuItems.gd")
const MuItemIconRes = preload("res://src/ui/MuItemIcon.gd")
const MuUiSkinRes = preload("res://src/ui/MuUiSkin.gd")

var cols := 8
var rows := 8
var cell := 20.0 * 1.5
var items: Array = []
var hover_cell := Vector2i(-1, -1)
## ô đang muốn đặt đồ cầm trên chuột (để tô xanh / đỏ)
var preview_size := Vector2i.ZERO
var preview_ok := false
var _hover_item: Dictionary = {}
var _press_cell := Vector2i(-1, -1)
var _box_tex: Texture2D

func setup(c: int, r: int, cell_px: float) -> void:
	cols = c
	rows = r
	cell = cell_px
	custom_minimum_size = Vector2(cols, rows) * cell
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	_box_tex = MuUiSkinRes.tex("newui_item_box")
	queue_redraw()

func set_items(list: Array) -> void:
	items = list
	queue_redraw()

func item_at(c: int, r: int) -> Dictionary:
	for it in items:
		var sz: Vector2i = MuItemsRes.size_of(it)
		var x := int(it["x"])
		var y := int(it["y"])
		if c >= x and c < x + sz.x and r >= y and r < y + sz.y:
			return it
	return {}

func _gui_input(event: InputEvent) -> void:
	var mm := event as InputEventMouseMotion
	if mm:
		var c := Vector2i(floori(mm.position.x / cell), floori(mm.position.y / cell))
		if c != hover_cell:
			hover_cell = c
			var it := item_at(c.x, c.y)
			if it != _hover_item:
				_hover_item = it
				if it.is_empty():
					MuItemIconRes.stop_live()
				hover_changed.emit(it)
			queue_redraw()
		return
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and (mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT):
		var c := Vector2i(floori(mb.position.x / cell), floori(mb.position.y / cell))
		if c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows:
			if mb.button_index == MOUSE_BUTTON_LEFT:
				_press_cell = c
			cell_clicked.emit(c.x, c.y, mb.button_index)
			accept_event()
	elif mb and not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _press_cell.x >= 0:
		# kéo thả: bấm ở ô này (nhấc đồ lên) rồi nhả ở ô khác / ngoài lưới -> coi như bấm thả vào đó
		var rc := Vector2i(floori(mb.position.x / cell), floori(mb.position.y / cell))
		var inside := rc.x >= 0 and rc.y >= 0 and rc.x < cols and rc.y < rows
		var moved := (not inside) or rc != _press_cell
		_press_cell = Vector2i(-1, -1)
		if moved:
			released_at.emit(get_global_transform() * mb.position, rc, inside)
			accept_event()
	elif mb and not mb.pressed:
		_press_cell = Vector2i(-1, -1)

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		hover_cell = Vector2i(-1, -1)
		if not _hover_item.is_empty():
			_hover_item = {}
			hover_changed.emit({})
		queue_redraw()

## Nền ô có đồ (item_grid.rcss: .item-cell.tint-normal = rgba(80, 128, 128, 153)), vẽ dưới khung newui_item_box
const TINT_NORMAL := Color(80.0 / 255.0, 128.0 / 255.0, 128.0 / 255.0, 153.0 / 255.0)

func _draw() -> void:
	var occupied := {}   # ô -> màu nền (tint-normal, hoặc vàng / cam / đỏ khi độ bền thấp)
	for it in items:
		var osz: Vector2i = MuItemsRes.size_of(it)
		var st: int = MuItemsRes.durability_state(it)
		var tc: Color = TINT_NORMAL if st == 0 else MuItemsRes.durability_tint(st, 102.0 / 255.0)
		for dy in osz.y:
			for dx in osz.x:
				occupied[Vector2i(int(it["x"]) + dx, int(it["y"]) + dy)] = tc
	for r in rows:
		for c in cols:
			var rc := Rect2(Vector2(c, r) * cell, Vector2(cell, cell))
			if occupied.has(Vector2i(c, r)):
				draw_rect(rc, occupied[Vector2i(c, r)])
			if _box_tex:
				draw_texture_rect(_box_tex, rc, false)
			else:
				draw_rect(rc, Color(0.12, 0.1, 0.08, 0.9))
				draw_rect(rc, Color(0.35, 0.3, 0.22, 0.8), false, 1.0)
	# ô đặt đồ đang cầm
	if preview_size != Vector2i.ZERO and hover_cell.x >= 0:
		var pr := Rect2(Vector2(hover_cell) * cell, Vector2(preview_size) * cell)
		draw_rect(pr, Color(0.1, 0.6, 0.2, 0.35) if preview_ok else Color(0.7, 0.1, 0.1, 0.35))
	for it in items:
		var sz: Vector2i = MuItemsRes.size_of(it)
		var rc := Rect2(Vector2(int(it["x"]), int(it["y"])) * cell, Vector2(sz) * cell)
		var hov := hover_cell.x >= int(it["x"]) and hover_cell.x < int(it["x"]) + sz.x and hover_cell.y >= int(it["y"]) and hover_cell.y < int(it["y"]) + sz.y
		# nền xanh của ô có đồ đã vẽ ở trên (tint-normal); rê chuột chỉ sáng nhẹ
		if hov:
			draw_rect(rc.grow(-1), Color(0.35, 0.35, 0.35, 0.18))
		# đồ đang rê chuột: ảnh 3D sống, xoay vòng như MU
		var t: Texture2D = MuItemIconRes.live_icon(get_tree(), it) if hov else MuItemIconRes.icon(get_tree(), it)
		if t:
			draw_texture_rect(t, MuItemIconRes.overflow_rect(rc, sz), false)
		else:
			var f := get_theme_default_font()
			draw_string(f, rc.position + Vector2(2, 12), MuItemsRes.base_name(it).left(6), HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
		# số lượng (thuốc, mũi tên)
		if int(it.get("dur", 0)) > 1 and (int(it.get("group", 0)) == 14 or int(it.get("group", 0)) == 4):
			var f2 := get_theme_default_font()
			draw_string_outline(f2, rc.position + Vector2(2, rc.size.y - 3), str(int(it["dur"])), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color.BLACK)
			draw_string(f2, rc.position + Vector2(2, rc.size.y - 3), str(int(it["dur"])), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.9, 0.5))

func _process(d: float) -> void:
	if not visible:
		return
	if not _hover_item.is_empty():
		MuItemIconRes.spin(d)
		queue_redraw()
	# ảnh đồ là ViewportTexture: vẽ lại vài khung đầu để nhận ảnh đã render
	elif Engine.get_process_frames() % 15 == 0:
		queue_redraw()
