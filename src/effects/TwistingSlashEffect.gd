extends Node3D
class_name TwistingSlashEffect

## Twisting Slash (Xoay Kiếm) theo client gốc:
##   ZzzCharacter.cpp  AT_SKILL_TWISTING_SLASH -> CreateEffect(MODEL_SKILL_WHEEL1) + SOUND_SKILL_SWORD4
##   MODEL_SKILL_WHEEL1 (LifeTime 5): mỗi tick sinh 1 MODEL_SKILL_WHEEL2, SubType = 0..4
##   MODEL_SKILL_WHEEL2 (LifeTime 25, Move_MODEL_SKILL_WHEEL2 / RenderWheelWeapon):
##     - vẽ CHÍNH VŨ KHÍ đang cầm, nằm ngang (Angle[1] = 90), cao 100, cách người 150 (giáo 180)
##     - quay quanh người -18°/tick, tự xoay thêm Direction[2] -= 30°/tick
##     - Alpha theo SubType: 1.0 / 0.6 / 0.5 / 0.4 / 0.3  => 5 bóng mờ đuổi nhau
##     - mỗi tick: 1 khói (BITMAP_SMOKE), 4 tia lửa (BITMAP_JOINT_SPARK, 1/4 kèm BITMAP_SPARK),
##       đốm sáng BITMAP_LIGHT (flare01) màu (1, 0.8, 0.6) cỡ 2 ở độ cao 20
## Đơn vị MU: 1 tick = 1/25 s, 100 đơn vị = 1 m ; trục MU (x, y, z) -> Godot (x, z, -y)

const MuCatalogRes = preload("res://src/mu/MuCatalog.gd")
const MuModelRes = preload("res://src/mu/MuModel.gd")
const MuCharModelRes = preload("res://src/mu/MuCharacterModel.gd")
const BODY_SHADOW_SHADER = preload("res://src/shaders/mu_body_shadow.gdshader")

const TICK := 1.0 / 25.0
const GHOST_ALPHA := [1.0, 0.6, 0.5, 0.4, 0.3]
const GHOST_LIFE := 25.0
const ORBIT_STEP := -18.0     # o->Angle[2] -= 18 mỗi tick
const SPIN_STEP := -30.0      # o->Direction[2] -= 30 mỗi tick
const WEAPON_HEIGHT := 100.0
const LIGHT_HEIGHT := 20.0

var caster: Node3D = null
var _start_yaw := 0.0         # Angle[2] của người dùng lúc ra chiêu (độ, MU)
var _radius := 150.0
var _weapon_scale := 0.8
var _weapon_src: Node3D = null
var _origin := Vector3.ZERO   # vị trí chân người dùng (Godot)

var _ticks := 0.0             # số tick đã trôi qua kể từ lúc ra chiêu
var _tick_acc := 0.0
var _spawned := 0
var _ghosts: Array = []       # {age, alpha, weapon: Node3D, light: MeshInstance3D}
var _parts: Array = []        # {mi, kind, vel, life, max_life, size}

static var _quad: QuadMesh = null
static var _mats := {}

## Gọi trước add_child: lấy hướng mặt và vũ khí tay phải (hoặc trái) của người dùng
func setup(p_caster: Node3D) -> void:
	caster = p_caster
	if caster == null:
		return
	_start_yaw = rad_to_deg(caster.rotation.y)
	_origin = caster.global_position
	var model = caster.get("model")
	if model == null:
		return
	var nodes: Dictionary = model.get("_weapon_nodes") if model.get("_weapon_nodes") != null else {}
	var d: Dictionary = nodes.get("right", nodes.get("left", {}))
	if d.is_empty() or not is_instance_valid(d.get("node")):
		return
	_weapon_src = d["node"]
	var g := int(d.get("group", 0))
	# ITEM_SPEAR: bán kính 180 ; MODEL_SPEAR..MODEL_PLATINA_STAFF: Scale 0.7 (ItemObjectAttribute)
	if g == MuCatalogRes.GROUP_SPEAR:
		_radius = 180.0
	if g >= MuCatalogRes.GROUP_SPEAR and g <= MuCatalogRes.GROUP_STAFF:
		_weapon_scale = 0.7

func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_spawn_ghost()

func _process(delta: float) -> void:
	if is_instance_valid(caster):
		_origin = caster.global_position
	var dt := delta / TICK
	_ticks += dt
	_tick_acc += dt
	while _tick_acc >= 1.0:
		_tick_acc -= 1.0
		_on_tick()
	_update_ghosts(dt)
	_update_parts(dt)
	if _spawned >= GHOST_ALPHA.size() and _ghosts.is_empty() and _parts.is_empty():
		queue_free()

# ------------------------------------------------------------------ bóng vũ khí xoay

func _spawn_ghost() -> void:
	var i := _spawned
	_spawned += 1
	var g := {"age": 0.0, "alpha": float(GHOST_ALPHA[i]), "weapon": null, "light": null}
	if is_instance_valid(_weapon_src):
		var w := _weapon_src.duplicate() as Node3D
		add_child(w)
		for gi in MuModelRes.find_all(w, "GeometryInstance3D", []):
			(gi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			(gi as GeometryInstance3D).transparency = 1.0 - g["alpha"]
			if gi is MeshInstance3D:
				_strip_body_shadow(gi as MeshInstance3D)
		g["weapon"] = w
	g["light"] = _make_quad("flare01", Color(1.0, 0.8, 0.6), 1.3)
	_ghosts.append(g)

## RenderWheelWeapon gọi ItemObjectAttribute -> EnableShadow = false: kiếm xoay KHÔNG có bóng.
## Vũ khí trên tay có lớp bóng chiếu (mu_body_shadow) nối cuối chuỗi vật liệu -> chép chuỗi, bỏ lớp đó.
func _strip_body_shadow(mi: MeshInstance3D) -> void:
	if mi.mesh == null:
		return
	for s in mi.mesh.get_surface_count():
		var head := mi.get_surface_override_material(s) as ShaderMaterial
		if head == null:
			continue
		var chain: Array = []
		var m: ShaderMaterial = head
		while m != null:
			if m.shader != BODY_SHADOW_SHADER:
				chain.append(m.duplicate())
			m = m.next_pass as ShaderMaterial
		for i in chain.size():
			(chain[i] as ShaderMaterial).next_pass = chain[i + 1] if i + 1 < chain.size() else null
		mi.set_surface_override_material(s, chain[0] if not chain.is_empty() else null)

func _orbit_yaw(g: Dictionary) -> float:
	return _start_yaw + ORBIT_STEP * float(g["age"])

## Vị trí WHEEL2 (ở mặt đất): chân người + xoay (0, -R, 0) theo góc quỹ đạo
func _ghost_ground_pos(g: Dictionary) -> Vector3:
	var b := _mu_basis(0.0, 0.0, _orbit_yaw(g))
	return _origin + b * _mu_vec(Vector3(0.0, -_radius, 0.0))

func _update_ghosts(dt: float) -> void:
	for g in _ghosts.duplicate():
		g["age"] += dt
		if g["age"] >= GHOST_LIFE:
			if g["weapon"]:
				MuModelRes.cleanup_geometry(g["weapon"])
				g["weapon"].queue_free()
			_free_quad(g["light"])
			_ghosts.erase(g)
			continue
		var ground := _ghost_ground_pos(g)
		if g["weapon"]:
			# RenderWheelWeapon: Angle[1] = 90, Angle[2] = quỹ đạo + Direction[2], cao +100
			var yaw := _orbit_yaw(g) + SPIN_STEP * float(g["age"])
			var b := _mu_basis(0.0, 90.0, yaw).scaled(Vector3.ONE * _weapon_scale)
			(g["weapon"] as Node3D).global_transform = Transform3D(b, ground + _mu_vec(Vector3(0, 0, WEAPON_HEIGHT)))
		var lt := g["light"] as MeshInstance3D
		lt.global_position = ground + _mu_vec(Vector3(0, 0, LIGHT_HEIGHT))
		_face_camera(lt, 1.3)

func _on_tick() -> void:
	if _spawned < GHOST_ALPHA.size():
		_spawn_ghost()
	for g in _ghosts:
		var pos := _ghost_ground_pos(g)
		var yaw := _orbit_yaw(g)
		_spawn_smoke(pos)
		for j in 4:
			var ang := Vector3(float(randi() % 60 + 60 - 90), 0.0, float(randi() % 30 + 90) + yaw)
			var p := pos + _mu_vec(Vector3(randi() % 20 - 10, randi() % 20 - 10, 0))
			_spawn_joint_spark(p, ang)
			if randi() % 4 == 0:
				_spawn_spark(p)

# ------------------------------------------------------------------ hạt

## BITMAP_JOINT_SPARK SubType 0: vệt sáng bay thẳng, Velocity 6..25, LifeTime 8..15
func _spawn_joint_spark(pos: Vector3, ang: Vector3) -> void:
	var speed := float(randi() % 20 + 6)
	var dir := _mu_basis(ang.x, ang.y, ang.z) * _mu_vec(Vector3(0, -1, 0)).normalized()
	var mi := _make_quad("Spark01", Color(1, 1, 1), 1.0)
	var life := float(randi() % 8 + 8)
	_parts.append({"mi": mi, "kind": "joint", "pos": pos, "vel": dir * speed / 100.0,
		"life": life, "max_life": life, "size": 0.02})   # Scale 2 = rộng 2 đơn vị MU

## BITMAP_SPARK SubType 0: đốm lửa bắn lên rồi rơi, LifeTime 24..39
func _spawn_spark(pos: Vector3) -> void:
	var a := randf() * TAU
	var h := float(randi() % 20 + 20) * 0.1
	var vel := Vector3(sin(a) * h, float(randi() % 16 + 6), cos(a) * h) / 100.0
	# RenderParticles: Width = bitmap Width (Spark02 = 4px) * Scale (0.4..0.7) đơn vị MU
	var size := maxf(0.025, 4.0 * float(randi() % 4 + 4) * 0.1 / 100.0)
	var mi := _make_quad("Spark02", Color(1, 1, 1), size)
	var life := float(randi() % 16 + 24)
	_parts.append({"mi": mi, "kind": "spark", "pos": pos, "vel": vel, "life": life,
		"max_life": life, "size": size, "floor": pos.y})

## BITMAP_SMOKE: khói mờ bốc lên quanh vệt quét
func _spawn_smoke(pos: Vector3) -> void:
	var mi := _make_quad("smoke01", Color(0.3, 0.3, 0.3), 0.6)
	var life := 20.0
	_parts.append({"mi": mi, "kind": "smoke", "pos": pos + Vector3(0, 0.2, 0),
		"vel": Vector3(0, 0.012, 0), "life": life, "max_life": life, "size": 0.6})

func _update_parts(dt: float) -> void:
	for p in _parts.duplicate():
		p["life"] -= dt
		if p["life"] <= 0.0:
			_free_quad(p["mi"])
			_parts.erase(p)
			continue
		var mi := p["mi"] as MeshInstance3D
		var k: float = p["life"] / p["max_life"]
		match p["kind"]:
			"joint":
				p["pos"] += p["vel"] * dt
				# MaxTails 2 = 1 đoạn: dài bằng quãng bay 1 tick
				_streak(mi, p["pos"], p["vel"], float(p["size"]))
			"spark":
				var v: Vector3 = p["vel"]
				v.y -= 3.0 / 100.0 * dt   # Gravity giảm dần mỗi tick
				var sp: Vector3 = p["pos"] + v * dt
				if sp.y < float(p["floor"]):
					sp.y = float(p["floor"])
					v = Vector3.ZERO
				p["vel"] = v
				p["pos"] = sp
				mi.global_position = sp
				_face_camera(mi, float(p["size"]))
				mi.transparency = 1.0 - clampf(k * 2.0, 0.0, 1.0)
			"smoke":
				p["pos"] += p["vel"] * dt
				mi.global_position = p["pos"]
				_face_camera(mi, float(p["size"]) * (1.6 - 0.6 * k))
				mi.transparency = 1.0 - k

# ------------------------------------------------------------------ tiện ích

static func _mu_vec(v: Vector3) -> Vector3:
	return Vector3(v.x, v.z, -v.y) / 100.0

## AngleMatrix của MU (độ) đổi sang Basis Godot
static func _mu_basis(ax: float, ay: float, az: float) -> Basis:
	return MuCharModelRes._mu_matrix_to_transform([ax, ay, az], Vector3.ZERO).basis

func _make_quad(tex_name: String, color: Color, size: float) -> MeshInstance3D:
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
		m.albedo_texture = MuModelRes.fx(tex_name)
		m.albedo_color = color
		_mats[key] = m
	var mi := MeshInstance3D.new()
	mi.mesh = _quad
	mi.material_override = _mats[key]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.scale = Vector3.ONE * size
	return mi

func _free_quad(mi: MeshInstance3D) -> void:
	if is_instance_valid(mi):
		mi.material_override = null
		mi.queue_free()

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

## Vệt sáng: trục X dọc theo hướng bay, mặt quad hướng về camera
func _streak(mi: MeshInstance3D, pos: Vector3, vel: Vector3, width: float) -> void:
	var axis := vel.normalized()
	var length := maxf(0.04, vel.length())
	var to_cam := (_cam_pos() - pos).normalized()
	var n := (to_cam - axis * axis.dot(to_cam))
	if n.length() < 0.001:
		n = Vector3.UP
	n = n.normalized()
	var up := n.cross(axis).normalized()
	mi.global_transform = Transform3D(Basis(axis * length, up * width, n), pos - axis * length * 0.5)

func _exit_tree() -> void:
	MuModelRes.cleanup_geometry(self)
