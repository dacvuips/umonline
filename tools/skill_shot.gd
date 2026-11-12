extends Node3D

## Bộ chụp hiệu ứng skill: dựng cảnh Lorencia tối giản, tung từng skill rồi lưu ảnh PNG theo mốc thời gian.
## Chạy:  godot --path MuGodot res://tools/skill_shot.tscn -- <thư_mục_ảnh> [số_skill,số_skill,...]
## Ví dụ: ... -- C:/tmp/shots 61,62,65,238

const DEFAULT_SKILLS := [60, 61, 62, 63, 64, 65, 66, 74, 78, 238]
const TIMES := [0.15, 0.4, 0.8, 1.3, 2.0]
## skill dài hơn (Địa Chấn) chụp thêm mốc muộn
const LONG_TIMES := [0.12, 0.45, 0.85, 1.2, 1.6, 2.4]
const LONG_SKILLS := [62]

var _out := ""
var _skills: Array = DEFAULT_SKILLS.duplicate()

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_skills = []
		for s in args[1].split(","):
			_skills.append(int(s))
	if _out == "":
		_out = ProjectSettings.globalize_path("user://skill_shots")
	DirAccess.make_dir_recursive_absolute(_out)
	get_window().size = Vector2i(960, 540)
	_run()

func _run() -> void:
	MuTerrain.change_world(1)
	MuTerrain.ensure_loaded()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.22, 0.25, 0.3)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.8, 0.8)
	env.ambient_light_energy = 1.0
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)
	# giống MuWorld._setup_bloom(): glow + bloom riêng của model
	env.glow_enabled = true
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 0.85
	for i in 7:
		env.set_glow_level(i, 1.0 if i in [1, 2, 3, 4] else 0.0)
	if "--no-bloom" not in OS.get_cmdline_user_args():
		var mb: Node = load("res://src/world/MuModelBloom.gd").new()
		mb.name = "MuModelBloom"
		add_child(mb)
	var terrain := MuTerrain.new()
	add_child(terrain)

	# Lorencia gần cổng thành (131, 109); đất phẳng quanh đó
	var gx := 135.0
	var gz := -112.0
	var h := MuTerrain.height_at(gx, -gz)
	var caster := Node3D.new()
	caster.name = "Caster"
	add_child(caster)
	caster.global_position = Vector3(gx, h, gz)
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.height = 1.7
	cap.radius = 0.3
	body.mesh = cap
	body.position = Vector3(0, 0.85, 0)
	caster.add_child(body)

	var cam := Camera3D.new()
	cam.fov = 55.0
	add_child(cam)
	cam.global_position = Vector3(gx + 3.6, h + 2.4, gz - 3.6)
	cam.look_at(Vector3(gx, h + 1.0, gz + 3.0), Vector3.UP)
	cam.current = true

	await get_tree().create_timer(2.5).timeout   # đợi nạp địa hình / texture
	for num in _skills:
		var fx_before := get_child_count()
		var d := MuSkillFx.play(caster, int(num), null)
		print("[skill_shot] skill %d impact_delay=%s" % [num, str(d)])
		var elapsed := 0.0
		for t in (LONG_TIMES if int(num) in LONG_SKILLS else TIMES):
			await get_tree().create_timer(float(t) - elapsed).timeout
			elapsed = float(t)
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.save_png("%s/skill_%d_t%03d.png" % [_out, num, int(float(t) * 100)])
		await get_tree().create_timer(2.5).timeout
		# dọn hiệu ứng còn sót
		for c in get_children():
			if c is MuFx or c is MuSkillFx:
				c.queue_free()
		await get_tree().create_timer(0.3).timeout
	print("[skill_shot] xong -> ", _out)
	get_tree().quit()
