extends Node3D

## Chụp ảnh giới thiệu 7 lớp nhân vật: mặc nguyên bộ giáp, vũ khí, cánh, thú cưỡi, toàn bộ +15 Excellent. Nền trong suốt.
## godot --path MuMain res://tools/class_shot.tscn -- <thư_mục_ra> [cỡ_chiều_rộng]
## Ghi <thư_mục_ra>/class_<id>.png (id: 0 DW, 1 DK, 2 Elf, 3 MG, 4 DL, 5 Summoner, 6 RF)

var LV := 15

# set: số bộ giáp ; right/left: [group, number] ; wings: [12, số] ; mount: [13, số]
const CLASSES := {
	0: {"set": 30, "right": [5, 12], "wings": [12, 37], "mount": [13, 37], "flags": 2},
	1: {"set": 29, "right": [0, 22], "left": [6, 17], "wings": [12, 36], "mount": [13, 37], "flags": 0},
	2: {"set": 31, "left": [4, 21], "wings": [12, 38], "mount": [13, 37], "flags": 4},
	3: {"set": 32, "right": [0, 23], "wings": [12, 39], "mount": [13, 37], "flags": 1},
	4: {"set": 33, "right": [2, 13], "wings": [12, 40], "mount": [13, 4]},
	5: {"set": 44, "right": [5, 20], "wings": [12, 43], "mount": [13, 37], "flags": 2},
	6: {"set": 73, "right": [0, 35], "left": [0, 35], "wings": [12, 50], "mount": [13, 37], "flags": 4},
}

func _item(g: int, n: int) -> Dictionary:
	return {"group": g, "number": n, "level": LV, "excellent": true}

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0]
	if a.size() > 3:
		LV = int(a[3])
	var w: int = int(a[1]) if a.size() > 1 else 900
	var h: int = int(w * 4 / 3)
	DirAccess.make_dir_recursive_absolute(out)
	MuCatalog.ensure_loaded()
	MuTerrain.change_world(1)

	var vp := SubViewport.new()
	vp.size = Vector2i(w, h)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.9, 0.95)
	env.ambient_light_energy = 1.3
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -30, 0)
	sun.light_energy = 1.2
	vp.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 150, 0)
	rim.light_color = Color(0.6, 0.7, 1.0)
	rim.light_energy = 0.8
	vp.add_child(rim)
	var cam := Camera3D.new()
	cam.fov = 32.0
	vp.add_child(cam)
	cam.position = Vector3(0, 1.5, 8.4) if OS.get_cmdline_user_args().size() < 3 else Vector3(0, 7.0, 6.0)
	cam.look_at(Vector3(0, 1.25, 0) if OS.get_cmdline_user_args().size() < 3 else Vector3(0, 0, 0.5))
	cam.current = true

	await get_tree().create_timer(1.5).timeout
	for cid in CLASSES.keys():
		var c: Dictionary = CLASSES[cid]
		var eq := {}
		for sl in [["helm", 7], ["armor", 8], ["pants", 9], ["gloves", 10], ["boots", 11]]:
			if MuCatalog.item_glb(sl[1], int(c["set"])) != "":
				eq[sl[0]] = _item(sl[1], int(c["set"]))
		for hand in ["right", "left"]:
			if c.has(hand):
				eq[hand] = _item(c[hand][0], c[hand][1])
		eq["wings"] = _item(c["wings"][0], c["wings"][1])
		eq["helper"] = {"group": c["mount"][0], "number": c["mount"][1], "level": 0, "excellent_flags": int(c.get("flags", 0))}

		var holder := Node3D.new()
		holder.rotation_degrees.y = -18.0
		vp.add_child(holder)
		var m := MuCharacterModel.new()
		holder.add_child(m)
		m.build_player(cid, eq)
		m.play_idle(true)
		m.scale = Vector3(0.9, 0.9, 0.9)
		var it: Dictionary = eq["helper"]
		if MuHelperFx.is_visual_helper(it):
			var fx := MuHelperFx.new()
			fx.name = "HelperFx"
			fx.preview = true
			fx.scale = m.scale
			holder.add_child(fx)
			fx.setup(m, it)
			var mi: Dictionary = MuHelperFx.mount_of(it)
			if not mi.is_empty():
				var hn := int(it.get("number", 0))
				m.position.y = float(mi.get("lift", 0.0)) * m.scale.y
				m.ride_kind = "fenrir" if hn == 37 else ("darkhorse" if hn == 4 else "")
				m.play_action(int(mi.get("p_idle", 13)))
		if OS.get_cmdline_user_args().size() < 3:
			_strip_shadow(holder)
		await get_tree().create_timer(2.0).timeout
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.save_png("%s/class_%d.png" % [out, cid])
		print("[class_shot] class ", cid, " ", img.get_size())
		holder.queue_free()
		await get_tree().process_frame
	print("[class_shot] xong")
	get_tree().quit()

## Bóng thân (mu_body_shadow) nối cuối chuỗi vật liệu: bỏ đi để ảnh nền trong suốt không có vệt đen dưới chân
func _strip_shadow(root: Node) -> void:
	for sh in root.find_children("*", "MeshInstance3D", true, false):
		if sh.has_meta("mu_shadow"):
			sh.queue_free()
	for cs in root.find_children("ClothShadow", "", true, false):
		cs.queue_free()
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(s) as ShaderMaterial
			while m != null:
				var nx := m.next_pass as ShaderMaterial
				if nx != null and nx.shader != null and nx.shader.resource_path.ends_with("mu_body_shadow.gdshader"):
					m.next_pass = null
					break
				m = nx
