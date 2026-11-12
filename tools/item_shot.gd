extends Node3D

## Chụp ảnh đồ trong túi (MuItemIcon) để kiểm tra ánh kim / glow.
## godot --path MuGodot res://tools/item_shot.tscn -- <thư_mục> 8:70:15,8:40:15[,g:n:cấp[:x]]   (x = excellent)

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else ProjectSettings.globalize_path("user://item_shots")
	DirAccess.make_dir_recursive_absolute(out)
	var spec_arg: String = args[1] if args.size() > 1 else "8:70:15"
	if spec_arg.begins_with("scan:"):
		await _scan(spec_arg.substr(5).split(","), out)
		get_tree().quit()
		return
	var specs: PackedStringArray = spec_arg.split(",")
	get_window().size = Vector2i(400, 300)
	MuCatalog.ensure_loaded()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.1, 0.18, 0.18)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	await get_tree().create_timer(1.0).timeout
	for sp in specs:
		var p := sp.split(":")
		var it := {"group": int(p[0]), "number": int(p[1]), "level": int(p[2]), "excellent": p.size() > 3 and p[3] == "x",
			"ancient": false}
		var tex: Texture2D = MuItemIcon.icon(get_tree(), it)
		for i in 6:
			await get_tree().process_frame
		await get_tree().create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		if tex:
			var img := tex.get_image()
			img.save_png("%s/item_%s.png" % [out, sp.replace(":", "_")])
			print("[item_shot] ", sp, " ", img.get_size())
		else:
			print("[item_shot] ", sp, " NULL")
	get_tree().quit()

## Quét: so ảnh +0 và +15 excellent của mọi món trong các nhóm; liệt kê món gần như không đổi (thiếu ánh kim)
func _scan(groups: PackedStringArray, out: String) -> void:
	MuCatalog.ensure_loaded()
	var list: Array = []
	for g in groups:
		for key in MuCatalog.item_models.keys():
			var p: PackedStringArray = str(key).split(":")
			if int(p[0]) == int(g) and MuCatalog.item_glb(int(p[0]), int(p[1])) != "":
				list.append([int(p[0]), int(p[1])])
	print("[item_shot] quét ", list.size(), " món")
	var batch := 24
	var results: Array = []
	for start in range(0, list.size(), batch):
		var texs: Array = []
		for i in range(start, mini(start + batch, list.size())):
			var gn: Array = list[i]
			var t0 = MuItemIcon.icon(get_tree(), {"group": gn[0], "number": gn[1], "level": 0, "excellent": false, "ancient": false})
			var t1 = MuItemIcon.icon(get_tree(), {"group": gn[0], "number": gn[1], "level": 15, "excellent": true, "ancient": false})
			texs.append([gn, t0, t1])
		for i in 8:
			await get_tree().process_frame
		await get_tree().create_timer(1.2).timeout
		await RenderingServer.frame_post_draw
		for e in texs:
			if e[1] == null or e[2] == null:
				results.append([e[0], -1.0])
				continue
			var a: Image = (e[1] as Texture2D).get_image()
			var b: Image = (e[2] as Texture2D).get_image()
			a.convert(Image.FORMAT_RGBA8)
			b.convert(Image.FORMAT_RGBA8)
			var da := a.get_data()
			var db := b.get_data()
			var sum := 0.0
			var cnt := 0
			for k in range(0, da.size(), 4):
				if da[k + 3] > 8 or db[k + 3] > 8:
					cnt += 1
					sum += absf(float(da[k]) - float(db[k])) + absf(float(da[k + 1]) - float(db[k + 1])) + absf(float(da[k + 2]) - float(db[k + 2]))
			results.append([e[0], sum / maxf(cnt, 1.0)])
	results.sort_custom(func(x, y): return x[1] < y[1])
	var f := FileAccess.open(out + "/scan.txt", FileAccess.WRITE)
	for r in results:
		f.store_line("%d:%d %.2f" % [r[0][0], r[0][1], r[1]])
	f.close()
	print("[item_shot] scan xong -> ", out)
