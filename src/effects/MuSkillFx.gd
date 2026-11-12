extends Node3D
class_name MuSkillFx

## Hiệu ứng skill TỰ ĐỘNG theo assets/mu/skill_fx.json (tools/mu_skill_fx.py trích từ source client gốc).
## Mỗi skill: hành động (animation), âm thanh, các hiệu ứng gốc:
##   effect MODEL_*  -> model .glb của hiệu ứng (bay tới mục tiêu / bám người / đứng yên theo Move handler)
##   effect/particle/sprite BITMAP_* -> chùm hạt billboard cộng sáng bằng texture gốc
##   joint BITMAP_JOINT_* -> tia (beam) từ người tới mục tiêu, hoặc vệt sáng toả quanh người
## Đây là bản GẦN ĐÚNG. Hiệu ứng nào đã port tay thì khai báo trong PORTED (ưu tiên hơn bản tự động).

const MuModelRes = preload("res://src/mu/MuModel.gd")
const MuCharModelRes = preload("res://src/mu/MuCharacterModel.gd")
const MuWorldRes = preload("res://src/world/MuWorld.gd")
const DATA_PATH := "res://assets/mu/skill_fx.json"
const TICK := 1.0 / 25.0

## Loại hiệu ứng gốc -> script đã port tay (nhận setup(caster))
const PORTED := {
	"MODEL_SKILL_WHEEL1": "res://src/effects/TwistingSlashEffect.gd",
}

## Script port tay theo nhóm skill (có hằng SKILLS = [số AT_SKILL ...], kế thừa MuFx)
const PORTED_SKILLS := [
	"res://src/effects/DarkWizardFx.gd",
	"res://src/effects/DarkKnightFx.gd",
	"res://src/effects/ElfFx.gd",
	"res://src/effects/MagicGladiatorFx.gd",
	"res://src/effects/DarkLordFx.gd",
	"res://src/effects/SummonerFx.gd",
	"res://src/effects/RageFighterFx.gd",
]

static var _data: Dictionary = {}
static var _quad: QuadMesh = null
static var _mats: Dictionary = {}
static var _model_mats: Dictionary = {}

var caster: Node3D = null
var target: Node3D = null
var _skill: Dictionary = {}
var _types: Dictionary = {}
var _models: Array = []     # {node, life, max_life, mode, from, to, speed, children}
var _parts: Array = []      # {mi, kind, pos, vel, life, max_life, size, a, b}
var _impact := 0.0

# ------------------------------------------------------------------ dữ liệu

static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(DATA_PATH, FileAccess.READ)
		if f:
			var d = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_data = d
		if _data.is_empty():
			_data = {"skills": {}, "types": {}}
	return _data

static func skill_info(num: int) -> Dictionary:
	return data()["skills"].get(str(num), {})

static func has_skill(num: int) -> bool:
	return not skill_info(num).is_empty()

## Ra chiêu: animation + âm thanh + hiệu ứng. Trả về số giây tới lúc trúng đích (-1 nếu skill không có dữ liệu).
static func play(p_caster: Node3D, num: int, p_target: Node3D = null) -> float:
	if p_caster == null or p_caster.get_parent() == null:
		return -1.0
	var sk := skill_info(num)
	_play_action(p_caster, sk)
	var sounds: Array = sk.get("sounds", [])
	if not sounds.is_empty() and MuAudioManager:
		MuAudioManager.play_sound_file(str(sounds[0]), 0.0, 1.0, p_caster.global_position)
	# hiệu ứng port tay theo skill (ưu tiên hơn bản tự động, chạy được cả khi sk trong skill_fx.json trống)
	var base := int(sk.get("base", num))
	for script in PORTED_SKILLS:
		var cls = load(script)
		if cls == null or not cls.can_instantiate() or not ("SKILLS" in cls.get_script_constant_map()):
			continue
		var skills: Array = cls.get_script_constant_map()["SKILLS"]
		if base in skills or num in skills:
			var hand: MuFx = cls.new()
			hand.setup_skill(p_caster, p_target, num if num in skills else base)
			p_caster.get_parent().add_child(hand)
			return hand.impact_delay
	if sk.is_empty():
		return -1.0
	var fx := MuSkillFx.new()
	fx.caster = p_caster
	fx.target = p_target
	fx._skill = sk
	fx._types = data()["types"]
	p_caster.get_parent().add_child(fx)
	return fx._impact

static func _play_action(c: Node3D, sk: Dictionary) -> void:
	if c.has_method("play_action") and c.get("is_player") != true:
		c.play_action("action02" if randf() < 0.5 else "action03")
		return
	var model = c.get("model")
	if model == null:
		return
	if model.get("is_player") != true:
		if model.has_method("play_attack"):
			model.play_attack()
		return
	if model.get("anim") == null:
		return
	var idx := int(sk.get("action_index", -1))
	var act := str(sk.get("action", ""))
	if idx < 0:
		if act == "magic":
			idx = MuCharModelRes.P_SKILL_ELF1 if int(c.get("char_class")) == 2 else MuCharModelRes.P_SKILL_HAND1
		else:
			idx = MuCharModelRes.P_SKILL_WEAPON1
	model.play_skill(idx, 0.3)
	if c.has_method("_lock_action"):
		c._lock_action(0.9)

## Hiệu ứng trúng đòn cận chiến (tia lửa va chạm + âm thanh đánh trúng)
static func play_melee_hit(hit_pos: Vector3, parent: Node = null) -> void:
	var root := parent
	if root == null and MuWorldRes != null and MuWorldRes.current != null:
		root = MuWorldRes.current
	if root == null:
		return
	var cls = load("res://src/effects/DarkWizardFx.gd")
	if cls != null and cls.can_instantiate():
		var fx: MuFx = cls.new()
		fx._min_ticks = 4
		fx.setup_skill(null, null, 0)
		root.add_child(fx)
		fx.particle("BITMAP_SPARK+1", hit_pos, {
			"size": randf_range(0.4, 0.7), "life": 8,
			"vel": Vector3(randf_range(-0.04, 0.04), randf_range(0.01, 0.05), randf_range(-0.04, 0.04)),
			"color": Color(1.0, 0.85, 0.4)
		})
		fx.particle("BITMAP_LIGHT", hit_pos, {
			"size": 0.8, "life": 5, "color": Color(1.0, 0.7, 0.3)
		})
	if MuAudioManager:
		var sounds := ["eMeleeHit1.wav", "eMeleeHit2.wav", "eMeleeHit3.wav"]
		MuAudioManager.play_sound_file(sounds[randi() % sounds.size()], 0.0, randf_range(0.95, 1.05), hit_pos)

# ------------------------------------------------------------------ dựng hiệu ứng

func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	var fx_list: Array = _skill.get("fx", [])
	var n_models := 0
	for f in fx_list:
		var typ := str(f.get("type", ""))
		var call := str(f.get("call", "effect"))
		var info: Dictionary = _types.get("%s:%s" % [call, typ], {})
		var at := str(f.get("at", "self"))
		var count := clampi(int(f.get("count", 1)), 1, 4)
		if PORTED.has(typ):
			var ported = load(PORTED[typ]).new()
			if ported.has_method("setup"):
				ported.setup(caster)
			get_parent().add_child(ported)
			_impact = maxf(_impact, 0.3)
			continue
		if call == "effect" and info.has("glb") and n_models < 4:
			n_models += 1
			_spawn_model(info, at)
		elif call == "joint":
			_spawn_joint(info, at, count)
		else:
			_spawn_burst(info, _anchor(at), count * 3)
	if _impact <= 0.0:
		_impact = 0.35

func _anchor(at: String) -> Vector3:
	if at == "target" and is_instance_valid(target):
		return target.global_position
	return caster.global_position if is_instance_valid(caster) else global_position

func _caster_yaw() -> float:
	return caster.rotation.y if is_instance_valid(caster) else 0.0

func _spawn_model(info: Dictionary, at: String) -> void:
	var node := MuModelRes.instantiate("res://assets/mu/%s.glb" % info["glb"])
	if node == null:
		_spawn_burst(info, _anchor(at), 4)
		return
	add_child(node)
	_additive(node)
	var ap := MuModelRes.find_first(node, "AnimationPlayer") as AnimationPlayer
	if ap and ap.get_animation_list().size() > 0:
		var a := ap.get_animation_list()[0]
		ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
		ap.play(a)
	var sc := float(info.get("scale", 1.0))
	if sc <= 0.0 or sc > 5.0:
		sc = 1.0
	node.scale = Vector3.ONE * sc
	var life := clampf(float(info.get("life", 25.0)) * TICK, 0.4, 2.5)
	var mode := str(info.get("motion", "static"))
	var m := {"node": node, "life": life, "max_life": life, "mode": mode,
		"children": info.get("children", []), "done": false}
	var has_target := is_instance_valid(target) and target != caster
	if has_target and (mode == "homing" or mode == "forward") and at != "target":
		var from := _anchor("self") + Vector3(0, 1.2, 0)
		var to := target.global_position + Vector3(0, 1.0, 0)
		var speed := clampf(float(info.get("velocity", 40.0)) * 25.0 / 100.0, 8.0, 25.0)
		m["mode"] = "fly"
		m["from"] = from
		m["to"] = to
		m["t"] = 0.0
		m["dur"] = from.distance_to(to) / speed
		m["life"] = m["dur"] + 0.05
		m["max_life"] = m["life"]
		node.global_position = from
		node.look_at(to, Vector3.UP, true)
		_impact = maxf(_impact, m["dur"])
	else:
		node.global_position = _anchor(at)
		node.rotation.y = _caster_yaw()
		m["at"] = at
		_burst_children(m)
	_models.append(m)

func _burst_children(m: Dictionary) -> void:
	if m.get("done", false):
		return
	m["done"] = true
	var pos: Vector3 = (m["node"] as Node3D).global_position
	for c in m["children"]:
		var info: Dictionary = _types.get("%s:%s" % [c.get("call", ""), c.get("type", "")], {})
		if info.has("tex"):
			_spawn_burst(info, pos, 4)

## Tia: từ tay người tới mục tiêu (zigzag), hoặc vệt sáng toả ra quanh người
func _spawn_joint(info: Dictionary, at: String, count: int) -> void:
	var tex := str(info.get("tex", ""))
	if tex == "" or _tex(tex) == null:
		return
	var life := clampf(float(info.get("life", 10.0)) * TICK, 0.25, 1.0)
	var has_target := is_instance_valid(target) and target != caster
	if (at == "beam" or str(info.get("motion", "")) == "homing") and has_target:
		var a := _anchor("self") + Vector3(0, 1.3, 0)
		var b := target.global_position + Vector3(0, 1.0, 0)
		for i in clampi(count, 1, 3):
			var segs := 6
			var prev := a
			for s in segs:
				var t := float(s + 1) / segs
				var p := a.lerp(b, t)
				if s < segs - 1:
					p += Vector3(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3), randf_range(-0.3, 0.3))
				var mi := _make_quad(tex, Color(1, 1, 1))
				_parts.append({"mi": mi, "kind": "beam", "a": prev, "b": p, "life": life, "max_life": life, "size": 0.35})
				prev = p
		_impact = maxf(_impact, 0.1)
		return
	var center := _anchor(at) + Vector3(0, 1.0, 0)
	for i in clampi(count * 6, 6, 18):
		var ang := randf() * TAU
		var dir := Vector3(sin(ang), randf_range(-0.2, 0.5), cos(ang)).normalized()
		var speed := clampf(float(info.get("velocity", 20.0)) * 25.0 / 100.0, 3.0, 12.0)
		var mi := _make_quad(tex, Color(1, 1, 1))
		_parts.append({"mi": mi, "kind": "streak", "pos": center, "vel": dir * speed,
			"life": life, "max_life": life, "size": 0.25})

## Chùm hạt billboard (particle / sprite / BITMAP effect)
func _spawn_burst(info: Dictionary, pos: Vector3, n: int) -> void:
	var tex := str(info.get("tex", ""))
	if tex == "" or _tex(tex) == null:
		return
	var life := clampf(float(info.get("life", 20.0)) * TICK, 0.3, 1.5)
	var t := _tex(tex)
	var px := float(t.get_width()) if t else 64.0
	var size := clampf(px * clampf(float(info.get("scale", 1.0)), 0.2, 3.0) / 100.0, 0.25, 2.5)
	for i in clampi(n, 1, 12):
		var mi := _make_quad(tex, Color(1, 1, 1))
		var vel := Vector3(randf_range(-1, 1), randf_range(0.2, 1.5), randf_range(-1, 1))
		_parts.append({"mi": mi, "kind": "puff", "pos": pos + Vector3(0, 0.8, 0) + vel * 0.2, "vel": vel,
			"life": life, "max_life": life, "size": size * randf_range(0.7, 1.2)})

# ------------------------------------------------------------------ cập nhật

func _process(delta: float) -> void:
	for m in _models.duplicate():
		m["life"] -= delta
		var node := m["node"] as Node3D
		match m["mode"]:
			"fly":
				m["t"] += delta
				var k := clampf(m["t"] / m["dur"], 0.0, 1.0)
				var to: Vector3 = m["to"]
				if is_instance_valid(target):
					to = target.global_position + Vector3(0, 1.0, 0)
				node.global_position = (m["from"] as Vector3).lerp(to, k)
				if k >= 1.0:
					_burst_children(m)
			"follow":
				if is_instance_valid(caster):
					node.global_position = _anchor(str(m.get("at", "self")))
		var f: float = m["life"] / m["max_life"]
		if m["mode"] != "fly" and f < 0.3:
			_set_transparency(node, 1.0 - f / 0.3)
		if m["life"] <= 0.0:
			MuModelRes.cleanup_geometry(node)
			node.queue_free()
			_models.erase(m)
	for p in _parts.duplicate():
		p["life"] -= delta
		var mi := p["mi"] as MeshInstance3D
		if p["life"] <= 0.0:
			mi.queue_free()
			_parts.erase(p)
			continue
		var k: float = p["life"] / p["max_life"]
		match p["kind"]:
			"beam":
				_segment(mi, p["a"], p["b"], float(p["size"]))
			"streak":
				p["pos"] = (p["pos"] as Vector3) + (p["vel"] as Vector3) * delta
				var v: Vector3 = p["vel"]
				_segment(mi, p["pos"], (p["pos"] as Vector3) + v.normalized() * 0.6, float(p["size"]))
			"puff":
				p["pos"] = (p["pos"] as Vector3) + (p["vel"] as Vector3) * delta
				mi.global_position = p["pos"]
				_face_camera(mi, float(p["size"]) * (1.3 - 0.3 * k))
		mi.transparency = 1.0 - clampf(k * 1.5, 0.0, 1.0)
	if _models.is_empty() and _parts.is_empty():
		queue_free()

# ------------------------------------------------------------------ tiện ích

static var _tex_cache: Dictionary = {}

static func _tex(name: String) -> Texture2D:
	if _tex_cache.has(name):
		return _tex_cache[name]
	var t: Texture2D = null
	for ext in ["jpg", "png"]:
		var p := "res://assets/mu/fx/skill/%s.%s" % [name, ext]
		if ResourceLoader.exists(p):
			t = load(p)
			break
	if t == null:
		t = MuModelRes.fx(name)
	if t == null:
		_tex_miss[name] = int(_tex_miss.get(name, 0)) + 1
		if int(_tex_miss[name]) == 1:
			push_warning("MuSkillFx: thiếu texture '%s'" % name)
		if int(_tex_miss[name]) < 4:
			return null
	_tex_cache[name] = t
	return t

static var _tex_miss := {}

func _make_quad(tex_name: String, color: Color) -> MeshInstance3D:
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2.ONE
	var key := "%s|%s" % [tex_name, color.to_html()]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		var _qt := _tex(tex_name)
		m.albedo_texture = _qt
		m.albedo_color = color if _qt != null else Color(1, 1, 1, 0)   # thiếu texture -> ẩn, tránh ô trắng
		if tex_name.to_lower().begins_with("explotion01"):
			# texture 4x4 khung (10 khung thật, phần còn lại nền trắng): chỉ lấy khung đầu
			m.uv1_scale = Vector3(0.24, 0.24, 1)
			m.uv1_offset = Vector3(0.005, 0.005, 0)
		if _qt == null:
			var mi0 := MeshInstance3D.new()
			mi0.mesh = _quad
			mi0.material_override = m
			mi0.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi0)
			return mi0
		_mats[key] = m
	var mi := MeshInstance3D.new()
	mi.mesh = _quad
	mi.material_override = _mats[key]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

## Model hiệu ứng MU hầu hết vẽ cộng sáng (RENDER_BRIGHT): giữ texture, bỏ ánh sáng
func _additive(root: Node) -> void:
	for n in MuModelRes.find_all(root, "MeshInstance3D", []):
		var mi := n as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s) as BaseMaterial3D
			var tex: Texture2D = src.albedo_texture if src else null
			var key := tex.get_instance_id() if tex else 0
			if not _model_mats.has(key):
				var m := StandardMaterial3D.new()
				m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
				m.cull_mode = BaseMaterial3D.CULL_DISABLED
				m.albedo_texture = tex
				if tex == null:
					m.albedo_color = Color(1, 1, 1, 0)   # mesh hiệu ứng không texture -> ẩn
				_model_mats[key] = m
			mi.set_surface_override_material(s, _model_mats[key])

func _set_transparency(root: Node, t: float) -> void:
	for n in MuModelRes.find_all(root, "GeometryInstance3D", []):
		(n as GeometryInstance3D).transparency = clampf(t, 0.0, 1.0)

func _cam_pos() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	return cam.global_position if cam else Vector3(0, 100, 0)

func _face_camera(mi: MeshInstance3D, size: float) -> void:
	var to_cam := (_cam_pos() - mi.global_position).normalized()
	var right := Vector3.UP.cross(to_cam)
	if right.length() < 0.001:
		right = Vector3.RIGHT
	right = right.normalized()
	var up := to_cam.cross(right).normalized()
	mi.global_transform = Transform3D(Basis(right * size, up * size, to_cam), mi.global_position)

## Quad nối a -> b (rộng width), mặt hướng camera
func _segment(mi: MeshInstance3D, a: Vector3, b: Vector3, width: float) -> void:
	var d := b - a
	var length := d.length()
	if length < 0.001:
		return
	var axis := d / length
	var mid := (a + b) * 0.5
	var to_cam := (_cam_pos() - mid).normalized()
	var n := to_cam - axis * axis.dot(to_cam)
	if n.length() < 0.001:
		n = Vector3.UP
	n = n.normalized()
	var up := n.cross(axis).normalized()
	mi.global_transform = Transform3D(Basis(axis * length, up * width, n), mid)

func _exit_tree() -> void:
	MuModelRes.cleanup_geometry(self)
