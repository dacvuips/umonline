extends Node3D

## Chụp nhân vật mặc nguyên bộ (mũ, giáp, quần, găng, giày cùng số hiệu) ở cấp +0 và +15 excellent, đo độ khác nhau
## (kiểm tra ánh kim trên người). godot --path MuMain res://tools/body_shot.tscn -- <thư_mục> <lớp> <số_bộ,số_bộ|all>
## Ghi scan.txt: "<số bộ> <độ khác>" tăng dần ; lưu ảnh +15 (và +0 nếu chỉ định ít bộ).

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0]
	var cls := int(a[1])
	var sets: Array = []
	var save_all := false
	var only_slot: String = a[3] if a.size() > 3 else ""   # chỉ mặc 1 món (tránh hiệu ứng full set làm nhiễu phép đo)
	if a[2] == "all":
		for i in range(0, 80):
			sets.append(i)
	else:
		for s in a[2].split(","):
			sets.append(int(s))
		save_all = true
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = Vector2i(400, 540)
	MuCatalog.ensure_loaded()
	MuTerrain.change_world(1)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.2, 0.22, 0.26)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.85, 0.85)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var cam := Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	cam.position = Vector3(0, 1.0, 3.2)
	cam.look_at(Vector3(0, 0.95, 0))
	cam.current = true
	await get_tree().create_timer(1.5).timeout
	var results: Array = []
	for sn in sets:
		var imgs: Array = []
		var have := false
		for lv in [0, 15]:
			var eq := {}
			for sl in [["helm", 7], ["armor", 8], ["pants", 9], ["gloves", 10], ["boots", 11]]:
				if only_slot != "" and sl[0] != only_slot:
					continue
				if MuCatalog.item_glb(sl[1], sn) != "":
					eq[sl[0]] = {"group": sl[1], "number": sn, "level": lv, "excellent": lv > 0}
					have = true
			if not have:
				break
			var m := MuCharacterModel.new()
			add_child(m)
			m.build_player(cls, eq)
			await get_tree().create_timer(0.9).timeout
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			imgs.append(img)
			if save_all:
				img.save_png("%s/body_%d_L%d.png" % [out, sn, lv])
			m.queue_free()
			await get_tree().process_frame
		if imgs.size() == 2:
			var d := _diff(imgs[0], imgs[1])
			results.append([sn, d])
			if not save_all and d < 6.0:
				imgs[1].save_png("%s/low_%d.png" % [out, sn])
	results.sort_custom(func(x, y): return x[1] < y[1])
	var f := FileAccess.open(out + "/scan.txt", FileAccess.WRITE)
	for r in results:
		f.store_line("%d %.2f" % [r[0], r[1]])
	f.close()
	print("[body_shot] xong ", results.size(), " bộ")
	get_tree().quit()

func _diff(x: Image, y: Image) -> float:
	x.convert(Image.FORMAT_RGB8)
	y.convert(Image.FORMAT_RGB8)
	var dx := x.get_data()
	var dy := y.get_data()
	var sum := 0.0
	for i in range(0, dx.size(), 3):
		sum += absf(float(dx[i]) - float(dy[i])) + absf(float(dx[i + 1]) - float(dy[i + 1])) + absf(float(dx[i + 2]) - float(dy[i + 2]))
	return sum / float(dx.size() / 3)
