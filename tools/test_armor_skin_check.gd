extends SceneTree
## Kiểm tra: mũ Dragon Knight (7:29) và các áo/quần Summoner (39/41/42) + Seraphim (49)
## - Mặc trên người (build_player)  -> out/armor_check_body.png
## - Ảnh đồ trong ô vẽ trực tiếp (bỏ ảnh nướng) -> out/armor_check_icons.png

const CharModel = preload("res://src/mu/MuCharacterModel.gd")
const ItemIcon = preload("res://src/ui/MuItemIcon.gd")

func _snap_body(cls: int, num: int, helm: int, armor: int = -2, full: bool = false) -> Image:
	var vp := SubViewport.new()
	vp.size = Vector2i(260, 360)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.25, 0.25, 0.3)
	we.environment = env
	vp.add_child(we)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.1, 4.2) if full else Vector3(0, 1.75, 0.9)
	cam.fov = 30.0
	vp.add_child(cam)
	cam.look_at(Vector3(0, 0.95, 0) if full else Vector3(0, 1.55, 0))
	var m := CharModel.new()
	vp.add_child(m)
	var eq := {}
	if helm >= 0:
		eq["helm"] = {"group": 7, "number": helm}
	var an := num if armor == -2 else armor
	if an >= 0:
		eq["armor"] = {"group": 8, "number": an}
	eq["pants"] = {"group": 9, "number": num}
	m.build_player(cls, eq)
	m.rotation_degrees = Vector3(0, 20, 0)
	for i in 6:
		await process_frame
	var img := vp.get_texture().get_image()
	vp.queue_free()
	return img

func _init() -> void:
	await process_frame
	var bodies := []
	# DK + mũ DK ; Summoner Violent Wind / Ancient / Demonic ; Elf Seraphim
	for e in [[1, 29, 29, -2], [1, 29, -1, -2], [1, 29, 29, -1], [1, 0, 29, -1]]:
		bodies.append(await _snap_body(e[0], e[1], e[2], e[3]))
	for e in [[5, 39, 39], [5, 41, 41], [5, 42, 42], [2, 49, 49]]:
		bodies.append(await _snap_body(e[0], e[1], e[2], -2, true))
	var out := Image.create(260 * bodies.size(), 360, false, Image.FORMAT_RGBA8)
	for i in bodies.size():
		var b: Image = bodies[i]
		b.convert(Image.FORMAT_RGBA8)
		out.blit_rect(b, Rect2i(0, 0, 260, 360), Vector2i(260 * i, 0))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/out"))
	out.save_png(ProjectSettings.globalize_path("res://tools/out/armor_check_body.png"))

	# ảnh đồ vẽ trực tiếp
	ItemIcon._baked_state = 0
	var items := [[7, 29], [8, 39], [8, 41], [8, 42], [8, 49], [9, 39], [9, 41], [9, 42], [9, 49]]
	var texs := []
	for it in items:
		texs.append(ItemIcon.icon(self, {"group": it[0], "number": it[1], "level": 0}))
	for i in 10:
		await process_frame
	var cell := 96
	var icons := Image.create(cell * items.size(), cell, false, Image.FORMAT_RGBA8)
	icons.fill(Color(0.15, 0.15, 0.15))
	for i in texs.size():
		var t: Texture2D = texs[i]
		if t == null:
			continue
		var im := t.get_image()
		if im == null:
			continue
		im.convert(Image.FORMAT_RGBA8)
		im.resize(cell, cell)
		icons.blend_rect(im, Rect2i(0, 0, cell, cell), Vector2i(cell * i, 0))
	icons.save_png(ProjectSettings.globalize_path("res://tools/out/armor_check_icons.png"))
	print("DONE")
	quit()
