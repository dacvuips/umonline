extends Node3D
class_name MuMonsterFx

## Hiệu ứng trên người quái vật (Aura, Glow & Ambient Particle Effects):
##   - Quái vàng (Golden Monsters): Hào quang vàng kim, hạt sao lấp lánh (Shiny01), đốm sáng
##   - Quái lửa (Balrog, Red Dragon, Hell Maine, Dark Phoenix...): Ngọn lửa bốc lên, khói đen, tàn lửa
##   - Quái băng (Ice Queen, Yeti, Ice Monster, Silver Valkyrie...): Bụi băng lấp lánh, sương giá xanh lạnh
##   - Quái độc (Poison Bull, Poison Shadow, Hell Spider, Larva...): Hơi độc xanh lá, bong bóng độc
##   - Quái sấm sét / biển sâu (Death Beam Knight, Hydra, Vepar, Bahamut...): Tia điện xanh, hạt năng lượng
##   - Boss hắc ám (Kundun, Death Gorgon, Gorgon, Nightmare...): Hào quang tím hắc ám, mắt rực sáng
##   - Quái có mắt sáng (Bull Fighter, Death Cow, Crust, Lizard...): 2 mắt đỏ rực

const MuModelRes = preload("res://src/mu/MuModel.gd")

var _pins: Array = []
var _particles_list: Array = []

static func _tex(name: String) -> Texture2D:
	return MuModelRes.fx(name)

static func _add_mat(tex: Texture2D, col: Color, billboard: bool = true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = tex
	m.albedo_color = col
	m.vertex_color_use_as_albedo = true
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.billboard_keep_scale = true
	return m

func _sprite(parent: Node3D, tex: Texture2D, size: float, col: Color, pos := Vector3.ZERO) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = _add_mat(tex, col)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	parent.add_child(mi)
	return mi

func _particles(parent: Node3D, tex: Texture2D, col: Color, amount: int, life: float, size: float,
		vel: Vector3, spread: float, box: Vector3, local := false) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = _add_mat(tex, Color(1, 1, 1))
	p.mesh = q
	p.amount = amount
	p.lifetime = life
	p.local_coords = local
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = box
	p.direction = vel.normalized() if vel.length() > 0.0 else Vector3.UP
	p.spread = spread
	p.initial_velocity_min = vel.length() * 0.5
	p.initial_velocity_max = vel.length()
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var g := Gradient.new()
	g.set_color(0, col)
	g.set_color(1, Color(col.r, col.g, col.b, 0.0))
	p.color_ramp = g
	parent.add_child(p)
	_particles_list.append(p)
	return p

# ======================================================================
# Hiệu ứng GỐC theo model quái (ZzzCharacter.cpp: UpdateCharacterTypeEffects / MoveCharacterVisual /
# UpdateMonsterBodyEffects). Khoá = slot model trong catalog (MONSTER_MODEL_xxx, bỏ tiền tố).
# Xương của BMD được chuyển sang tên b000, b001... nên chỉ số xương dùng y như client gốc.
#   eyes  : [trái, phải, cỡ]       -> SpawnEyeLights (eye01.jpg, sáng nhịp sin)
#   bones : [[xương, tex, cỡ]...]  -> SpawnBoneLight (màu cam nhạt nhịp sin) / CreateSprite
#   fire  : [xương...]             -> CreateParticle(BITMAP_FIRE) liên tục
#   smoke : {bone, color, rate}    -> CreateParticle(BITMAP_SMOKE)
#   ground_smoke: true             -> bụi khói quanh chân (Larva, Dark Knight, Chain Scorpion...)
#   attack_fire / attack_energy    -> phun lửa / năng lượng khi ra đòn (Budge Dragon, Bali)
# ======================================================================
const MuObjectFxRes = preload("res://src/world/MuObjectFx.gd")
const MuCatalogRes = preload("res://src/mu/MuCatalog.gd")

const BONE_LIGHT := Color(1.0, 0.6, 0.4)
const ORIGINAL_FX := {
	"BULL_FIGHTER": {"eyes_if_elite": [22, 23, 1.0], "smoke": {"bone": 24, "color": Color(0.7, 0.7, 0.7, 0.35), "rate": 3}},
	"DEATH_COW": {"eyes": [22, 23, 1.0]},
	"CRUST": {"eyes": [26, 27, 2.0]},
	"HYDRA": {"bones": [[63, "lightning2", 1.0], [63, "Shiny03", 4.0]]},
	"VEPAR": {"bones": [[30, "lightning2", 0.5], [39, "lightning2", 0.5], [30, "Spark02", 4.0], [39, "Spark02", 4.0],
		[30, "Shiny03", 2.0], [39, "Shiny03", 2.0]]},
	"LIZARD": {"eyes": [42, 43, 1.0], "bones": [[26, "Spark02", 2.0], [31, "Spark02", 2.0], [36, "Spark02", 2.0], [41, "Spark02", 2.0],
		[26, "Shiny03", 1.0], [31, "Shiny03", 1.0], [36, "Shiny03", 1.0], [41, "Shiny03", 1.0]]},
	"GOLDEN_LIZARD_KING": {"eyes": [42, 43, 1.0], "bones": [[26, "Spark02", 2.0], [31, "Spark02", 2.0], [36, "Spark02", 2.0], [41, "Spark02", 2.0]]},
	"BAHAMUT": {"bones": [[9, "Spark02", 4.0], [9, "Shiny03", 3.0]]},
	"SHADOW": {"all_bones": true},
	# Death Gorgon (c->Level = 2): mỗi tick 10 x CreateParticle(BITMAP_FIRE) ở xương ngẫu nhiên -> cháy khắp thân
	# Gorgon thường (Level 0): chỉ có BlendMesh chập chờn, không lửa
	"GORGON": {"body_fire_numbers": [35]},
	"DEATH_KNIGHT": {"fire": [2]},
	"YETI": {"smoke": {"bone": 22, "color": Color(0.85, 0.9, 1.0, 0.35), "rate": 4}},
	"ELITE_YETI": {"smoke": {"bone": 22, "color": Color(0.85, 0.9, 1.0, 0.35), "rate": 4}},
	"BUDGE_DRAGON": {"attack_fire": 7, "ground_smoke": true},
	"DARK_KNIGHT": {"ground_smoke": true},
	"LARVA": {"ground_smoke": true},
	"CHAIN_SCORPION": {"ground_smoke": true, "sprites": [{"bone": 7, "tex": "flare01", "scale": 1.0, "color": Color(1.0, 0.4, 0.2), "flicker": 0.3}]},
	"BALI": {"attack_energy": [33, 20, 41, 49]},
	"TANTALLOS": {"fire_if_name": ["zaikan", [6, 13]]},
	"DRAKAN": {"bone_range": [[13, 26], [52, 58]], "range_color": Color(0.1, 0.1, 1.0), "range_scale": 0.8},
	"GREAT_DRAKAN": {"fire": [18]},
	"ALQUAMOS": {"sprites_bones": [10, 18, 37, 38, 51, 52, 58, 59, 66], "sprite_color": Color(0.8, 0.9, 1.0), "sprite_scale": 0.6, "sparks": true},
	"QUEEN_RAINER": {"sprites": [{"bone": 20, "tex": "flare01", "scale": 0.8, "color": Color(1, 1, 1)}], "sparks": true},
}

## Nhóm hiệu ứng đoán theo tên (lửa / băng / độc / điện / boss / mắt) — không có trong client gốc
const ENABLE_GUESSED_FX := false

var _attack_fx: Dictionary = {}
var _model_ref: Node3D = null

static func _slot_of(number: int, mon_name: String) -> String:
	var mon := MuCatalogRes.find_monster(number, "") if number >= 0 else {}
	if mon.is_empty() and mon_name != "":
		mon = MuCatalogRes.find_monster(-1, mon_name)
	return str(mon.get("model", "")).replace("MONSTER_MODEL_", "")

func _skel(model: Node3D) -> Skeleton3D:
	var sk = model.get("skeleton")
	if sk is Skeleton3D:
		return sk
	return MuObjectFxRes.MuModelFind.skeleton(model)

func _bone_node(sk: Skeleton3D, bone: int) -> Node3D:
	if sk == null or sk.find_bone("b%03d" % bone) < 0:
		return null
	return MuObjectFxRes.MuModelFind.bone_attachment(sk, bone)

func _bone_sprite(sk: Skeleton3D, d: Dictionary) -> bool:
	var parent := _bone_node(sk, int(d.get("bone", 0)))
	if parent == null:
		return false
	var s := MuObjectFxRes.make_sprite(d, randf() * 10.0)
	if s == null:
		return false
	parent.add_child(s)
	_pins.append(s)
	return true

## Lửa / khói / tia lửa gắn trên xương (hạt bay trong toạ độ thế giới)
func _bone_particles(sk: Skeleton3D, bone: int, kind: String, col := Color(1, 1, 1, 0.5), rate := 4) -> CPUParticles3D:
	var parent := _bone_node(sk, bone)
	if parent == null:
		return null
	var p: CPUParticles3D
	match kind:
		"fire":
			p = MuObjectFxRes.make_fire()
			p.amount = rate
			p.initial_velocity_min = 0.1
			p.initial_velocity_max = 0.3
		"smoke":
			p = MuObjectFxRes.make_particles(MuObjectFxRes.tex("smoke01"), col, rate, 1.2, 0.45,
				Vector3(0, 0.5, 0), 30.0, Vector3(0.03, 0.03, 0.03), false)
		"spark":
			p = MuObjectFxRes.make_particles(MuObjectFxRes.tex("Spark02"), col, rate, 0.5, 0.15,
				Vector3(0, 0.6, 0), 180.0, Vector3(0.1, 0.1, 0.1))
		"energy":
			p = MuObjectFxRes.make_particles(MuObjectFxRes.tex("energy01"), col, rate, 0.4, 0.5,
				Vector3(0, 0.3, 0), 180.0, Vector3(0.05, 0.05, 0.05))
	if p == null:
		return null
	parent.add_child(p)
	_particles_list.append(p)
	return p

## Port hiệu ứng client gốc; trả về true nếu model có hiệu ứng riêng
func _setup_original(model: Node3D, number: int, mon_name: String) -> bool:
	var slot := _slot_of(number, mon_name)
	if not ORIGINAL_FX.has(slot):
		return false
	var e: Dictionary = ORIGINAL_FX[slot]
	var sk := _skel(model)
	if sk == null:
		return true
	var nl := mon_name.to_lower()
	var any := false
	# Mắt sáng (Elite Bull Fighter: c->Level == 1)
	var eyes: Array = e.get("eyes", [])
	if eyes.is_empty() and e.has("eyes_if_elite") and ("elite" in nl or number != 0):
		eyes = e["eyes_if_elite"]
	if not eyes.is_empty():
		for i in 2:
			any = _bone_sprite(sk, {"bone": eyes[i], "tex": "eye01", "scale": eyes[2], "color": Color(1, 1, 1),
				"sine": [0.3, 0.8, 2.0]}) or any
	# SpawnBoneLight: sáng (L, 0.6L, 0.4L), L = sin(t)*0.3 + 0.7
	for b in e.get("bones", []):
		any = _bone_sprite(sk, {"bone": b[0], "tex": b[1], "scale": b[2], "color": BONE_LIGHT, "sine": [0.3, 0.7, 2.0]}) or any
	for d in e.get("sprites", []):
		any = _bone_sprite(sk, d) or any
	for b in e.get("sprites_bones", []):
		any = _bone_sprite(sk, {"bone": b, "tex": "flare01", "scale": e.get("sprite_scale", 0.6),
			"color": e.get("sprite_color", Color(1, 1, 1)), "flicker": 0.3}) or any
	for r in e.get("bone_range", []):
		for b in range(int(r[0]), int(r[1]) + 1):
			any = _bone_sprite(sk, {"bone": b, "tex": "flare01", "scale": e.get("range_scale", 0.8),
				"color": e.get("range_color", Color(1, 1, 1))}) or any
	# Shadow / Poison Shadow: đốm sáng trên mọi xương trừ 2 cánh tay (15-20, 27-32)
	if e.get("all_bones", false):
		var poison := "poison" in nl
		for b in sk.get_bone_count():
			if (b >= 15 and b <= 20) or (b >= 27 and b <= 32):
				continue
			if poison:
				# Level 1: CreateSprite(BITMAP_MAGIC+1, 0.8, Light (0.2, 0.7, 0.1)) cộng sáng
				_bone_sprite(sk, {"bone": b, "tex": "Magic_Ground2", "scale": 0.8, "color": Color(0.2, 0.7, 0.1)})
			else:
				# Level 0: CreateSprite(BITMAP_SHINY+1, 2.5, trắng, SubType 1) -> Blend::Subtract: bóng ĐEN quanh thân
				_bone_sprite(sk, {"bone": b, "tex": "Shiny02", "scale": 2.5, "color": Color(1, 1, 1), "blend": "sub"})
		any = true
	if number in e.get("body_fire_numbers", []):
		# lửa phủ khắp thân: rải nguồn lửa lên các xương (bỏ xương gốc 0)
		var n := sk.get_bone_count()
		var step := maxi(1, n / 12)
		for b in range(1, n, step):
			var f := _bone_particles(sk, b, "fire", Color(1, 1, 1), 4)
			if f:
				f.scale_amount_min = 0.7
				f.scale_amount_max = 1.1
				any = true
	for b in e.get("fire", []):
		any = _bone_particles(sk, b, "fire", Color(1, 1, 1), 6) != null or any
	if e.has("fire_if_name") and e["fire_if_name"][0] in nl:
		for b in e["fire_if_name"][1]:
			any = _bone_particles(sk, b, "fire", Color(1, 1, 1), 6) != null or any
	if e.has("smoke"):
		var sd: Dictionary = e["smoke"]
		any = _bone_particles(sk, int(sd["bone"]), "smoke", sd["color"], int(sd["rate"])) != null or any
	if e.get("sparks", false):
		var p := _bone_particles(sk, 0, "spark", Color(0.6, 0.7, 0.8, 0.9), 6)
		if p:
			p.emission_box_extents = Vector3(0.6, 0.8, 0.6)
			any = true
	if e.get("ground_smoke", false):
		var g := MuObjectFxRes.make_particles(MuObjectFxRes.tex("smoke01"), Color(0.55, 0.5, 0.45, 0.3), 3, 1.5, 0.6,
			Vector3(0, 0.25, 0), 40.0, Vector3(0.32, 0.08, 0.32), false)
		add_child(g)
		_particles_list.append(g)
		any = true
	# Hiệu ứng khi ra đòn
	if e.has("attack_fire"):
		var p := _bone_particles(sk, int(e["attack_fire"]), "fire", Color(1, 1, 1), 10)
		if p:
			p.emitting = false
			p.preprocess = 0.0
			p.direction = Vector3(0, 0, 1)
			p.initial_velocity_min = 1.2
			p.initial_velocity_max = 1.8
			_attack_fx["fire"] = [p]
			any = true
	if e.has("attack_energy"):
		var lst := []
		for b in e["attack_energy"]:
			var p := _bone_particles(sk, b, "energy", Color(0.6, 1.0, 0.8, 0.9), 6)
			if p:
				p.emitting = false
				p.preprocess = 0.0
				lst.append(p)
		_attack_fx["energy"] = lst
		any = any or not lst.is_empty()
	# model đã có bảng gốc: dù không sinh hiệu ứng nào (vd. Gorgon thường) cũng không dùng hiệu ứng đoán theo tên
	return true

# ======================================================================
# BlendMesh của thân quái (CreateMonster: c->Object.BlendMesh / MoveCharacterVisual: BlendMeshTexCoordU/V):
# mesh đó vẽ CỘNG SÁNG (phần phát sáng của thân), có thể trôi UV / chập chờn. -2 = cả thân.
#   mesh: chỉ số mesh BMD ; su / sv: vòng texture / giây ; flicker: [min, max]
# ======================================================================
const BLEND_SHADER := preload("res://src/shaders/mu_object_blend.gdshader")
const BODY_BLEND := {
	"TANTALLOS": {"mesh": 2},
	"ALQUAMOS": {"mesh": 0},
	"QUEEN_RAINER": {"mesh": -2},
	"CRUST": {"mesh": 1, "su": 0.4},
	"VALKYRIE": {"mesh": 0},
	"GORGON": {"mesh": 1, "flicker": [0.0, 0.9]},
	"BEETLE_MONSTER": {"mesh": 1},
	"ICE_QUEEN": {"mesh": 2},
	"ICE_MONSTER": {"mesh": 0, "sv": 0.5},
	"TITAN": {"mesh": 2},
	"DEATH_KNIGHT": {"mesh": 3, "sv": 1.0},
}
## theo số quái (Death Beam Knight: BlendMesh = -2 -> cả thân cháy sáng)
const BODY_BLEND_BY_NUMBER := {63: {"mesh": -2}}

func _apply_body_blend(model: Node3D, number: int, slot: String) -> bool:
	var e: Dictionary = BODY_BLEND_BY_NUMBER.get(number, BODY_BLEND.get(slot, {}))
	if e.is_empty():
		return false
	var sk := _skel(model)
	if sk == null:
		return false
	var mesh_idx := int(e.get("mesh", -1))
	var done := false
	for c in sk.get_children():
		var mi := c as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			if mesh_idx != -2 and s != mesh_idx:
				continue
			var src := mi.mesh.surface_get_material(s) as BaseMaterial3D
			var m := ShaderMaterial.new()
			m.shader = BLEND_SHADER
			m.set_shader_parameter("albedo_tex", src.albedo_texture if src else null)
			m.set_shader_parameter("scroll_u", float(e.get("su", 0.0)))
			m.set_shader_parameter("scroll_v", float(e.get("sv", 0.0)))
			var fl: Array = e.get("flicker", [1.0, 1.0])
			m.set_shader_parameter("flicker_min", float(fl[0]))
			m.set_shader_parameter("flicker_max", float(fl[1]))
			m.set_shader_parameter("flicker_seed", randf() * 100.0)
			mi.set_surface_override_material(s, m)
			done = true
		break # chỉ thân chính (mesh đầu tiên dưới skeleton)
	return done

# ======================================================================
# Hiệu ứng TRÍCH TỰ ĐỘNG từ source gốc (tools/mu_monster_fx.py -> assets/mu/monster_fx.json):
# CreateSprite / CreateParticle liên tục trên xương của ~70 model quái (Aida, Kalima, Kanturu, Crywolf,
# Raklion, Swamp, Karutan, Empire Guardian, Land of Trials, Elvenland, Doppelganger, Balgass...).
# ======================================================================
const EXTRACTED_PATH := "res://assets/mu/monster_fx.json"
## Quái có bảng tay ORIGINAL_FX nhưng vẫn dùng thêm mục riêng theo số quái (Death Beam Knight, Golden Great Dragon)
const EXTRA_BY_NUMBER := [63, 501]
const MAX_EMITTERS := 8
static var _extracted = null

static func _extracted_data() -> Dictionary:
	if _extracted == null:
		_extracted = {}
		if FileAccess.file_exists(EXTRACTED_PATH):
			var d = JSON.parse_string(FileAccess.get_file_as_string(EXTRACTED_PATH))
			if d is Dictionary:
				_extracted = d
	return _extracted

func _setup_extracted(model: Node3D, number: int, slot: String) -> bool:
	var data := _extracted_data()
	var lst: Array = []
	if not ORIGINAL_FX.has(slot):
		lst.append_array((data.get("slots", {}) as Dictionary).get(slot, []))
	if not ORIGINAL_FX.has(slot) or number in EXTRA_BY_NUMBER:
		lst.append_array((data.get("monsters", {}) as Dictionary).get(str(number), []))
	if lst.is_empty():
		return false
	var sk := _skel(model)
	if sk == null:
		return false
	var any := false
	var emitters := 0
	for fx in lst:
		var col_a: Array = fx.get("color", [1, 1, 1])
		var col := Color(float(col_a[0]), float(col_a[1]), float(col_a[2]))
		for b in fx.get("bones", []):
			if str(fx.get("call")) == "sprite":
				var d := {"bone": int(b), "tex": fx["tex"], "scale": float(fx.get("scale", 1.0)), "color": col,
					"blend": fx.get("blend", "add"), "rot": float(fx.get("rot", 0.0))}
				if fx.get("flicker", false):
					d["flicker"] = 0.3
				any = _bone_sprite(sk, d) or any
			elif emitters < MAX_EMITTERS:
				if _extracted_particle(sk, int(b), fx, col):
					emitters += 1
					any = true
	return any

## CreateParticle gốc -> nguồn hạt CPU trên xương (lửa / khói / tia sáng), tần suất theo rand_fps_check
func _extracted_particle(sk: Skeleton3D, bone: int, fx: Dictionary, col: Color) -> bool:
	var parent := _bone_node(sk, bone)
	if parent == null:
		return false
	var t := str(fx.get("tex", ""))
	var low := t.to_lower()
	var rate := clampf(float(fx.get("rate", 25.0)), 0.5, 25.0)
	var sc := clampf(float(fx.get("scale", 1.0)), 0.1, 4.0)
	var p: CPUParticles3D
	if low.begins_with("fire") or low.begins_with("flame") or low.begins_with("fanta"):
		# BITMAP_FIRE / BITMAP_TRUE_FIRE / BITMAP_FLAME: ngọn lửa có khung hình, nhuộm theo Light gốc
		p = MuObjectFxRes.make_fire()
		p.amount = clampi(int(rate * 0.96 * 0.4), 2, 10)
		var k := clampf(sc, 0.3, 1.6)
		p.scale_amount_min = 0.5 * k
		p.scale_amount_max = 0.9 * k
		p.initial_velocity_min = 0.1
		p.initial_velocity_max = 0.3
		if not col.is_equal_approx(Color(1, 1, 1)):
			p.color_initial_ramp = null
			p.color = Color(maxf(col.r, 0.1), maxf(col.g, 0.08), maxf(col.b, 0.05))
	else:
		var tex := MuObjectFxRes.tex(t)
		if tex == null:
			return false
		var life := 1.4 if low.begins_with("smoke") or low.begins_with("clud") else 0.6
		var size := clampf(float(tex.get_width()) * sc / 100.0 * 0.6, 0.08, 1.0)
		var smoke := low.begins_with("smoke") or low.begins_with("clud")
		var c := Color(col.r, col.g, col.b, 0.35 if smoke else 0.9)
		p = MuObjectFxRes.make_particles(tex, c, clampi(int(rate * life * 0.5), 1, 14), life, size,
			Vector3(0, 0.45 if smoke else 0.2, 0), 60.0, Vector3(0.05, 0.05, 0.05), true)
	parent.add_child(p)
	_particles_list.append(p)
	return true

## Gọi khi quái ra đòn (MuMonster._attack): Budge Dragon phun lửa, Bali toả năng lượng
func on_attack() -> void:
	for k in _attack_fx:
		var lst: Array = _attack_fx[k]
		if lst.is_empty():
			continue
		# Bali: mỗi đòn (ATTACK1..4) phát sáng ở 1 xương khác nhau
		var p: CPUParticles3D = lst[randi() % lst.size()] if k == "energy" else lst[0]
		if is_instance_valid(p):
			p.restart()
			p.emitting = true
			get_tree().create_timer(0.35).timeout.connect(func():
				if is_instance_valid(p):
					p.emitting = false)

## Cài đặt hiệu ứng theo số hiệu và tên quái vật
func setup(model: Node3D, number: int, mon_name: String) -> bool:
	var nl := mon_name.to_lower()
	var is_golden := "golden" in nl or (number in [43, 53, 54, 78, 79, 80, 81, 82, 83, 236, 493, 494, 495, 496, 497, 498, 499, 500, 501, 502])
	_model_ref = model
	# Hiệu ứng gốc của model: có thì không dùng các nhóm đoán theo tên (chỉ giữ hào quang quái vàng)
	var original := _setup_original(model, number, mon_name)
	var slot := _slot_of(number, mon_name)
	var extracted := _setup_extracted(model, number, slot)
	var blended := _apply_body_blend(model, number, slot)
	var trails := _setup_eye_trails(model, slot)
	original = original or extracted or blended or trails
	if original and not is_golden:
		return true
	if original and is_golden:
		var mg := model.scale.y if model.scale.y > 0.0 else 1.0
		_particles(self, _tex("Shiny01"), Color(1.0, 0.85, 0.3, 0.95), 14, 1.4, 0.45 * mg,
			Vector3(0, 0.6, 0), 30.0, Vector3(0.4 * mg, 0.6 * mg, 0.4 * mg)).position = Vector3(0, 0.8 * mg, 0)
		return true

	var m_scale := 1.0
	if model.scale.y > 0.0:
		m_scale = model.scale.y

	var root: Node3D = self
	var has_fx := false

	# 1. Quái vàng (Golden Monsters)
	if is_golden:
		has_fx = true
		# Hạt sao vàng lấp lánh bốc lên quanh thân
		_particles(root, _tex("Shiny01"), Color(1.0, 0.85, 0.3, 0.95), 14, 1.4, 0.45 * m_scale,
			Vector3(0, 0.6, 0), 30.0, Vector3(0.4 * m_scale, 0.6 * m_scale, 0.4 * m_scale)).position = Vector3(0, 0.8 * m_scale, 0)
		# Đốm sáng vàng tỏa nhẹ ở trung tâm
		var s := _sprite(root, _tex("flare01"), 1.2 * m_scale, Color(1.0, 0.75, 0.15, 0.6), Vector3(0, 0.9 * m_scale, 0))
		s.set_meta("pulse", 1.8)
		_pins.append(s)

	# Client gốc không có hào quang / lửa / mắt sáng "đoán theo tên" cho các quái còn lại:
	# chỉ giữ hiệu ứng quái vàng, các nhóm dưới đây tắt (ENABLE_GUESSED_FX) để không khác bản gốc.
	if not ENABLE_GUESSED_FX:
		return has_fx

	# 2. Quái Lửa / Rồng / Balrog / Hell Maine / Dark Phoenix
	var is_fire := (number in [38, 42, 44, 67, 77, 309]) or ("dragon" in nl) or ("balrog" in nl) or ("fire" in nl) or ("lava" in nl) or ("hell" in nl and not "spider" in nl)
	if is_fire:
		has_fx = true
		# Đốm lửa bốc lên
		_particles(root, _tex("Flare02"), Color(1.0, 0.45, 0.1, 0.9), 12, 1.1, 0.5 * m_scale,
			Vector3(0, 0.9, 0), 20.0, Vector3(0.35 * m_scale, 0.5 * m_scale, 0.35 * m_scale)).position = Vector3(0, 0.6 * m_scale, 0)
		# Khói đen cuộn nhẹ
		_particles(root, _tex("smoke01"), Color(0.25, 0.15, 0.1, 0.4), 6, 1.6, 0.7 * m_scale,
			Vector3(0, 0.7, 0), 35.0, Vector3(0.3 * m_scale, 0.5 * m_scale, 0.3 * m_scale)).position = Vector3(0, 0.9 * m_scale, 0)

	# 3. Quái Băng Tuyết (Ice Queen, Yeti, Ice Monster, Silver Valkyrie...)
	var is_ice := (number in [19, 20, 22, 25, 52, 445, 454]) or ("ice" in nl) or ("yeti" in nl) or ("frost" in nl) or ("snow" in nl) or ("cold" in nl) or ("silver" in nl)
	if is_ice:
		has_fx = true
		# Hạt băng lấp lánh
		_particles(root, _tex("Spark01"), Color(0.45, 0.85, 1.0, 0.9), 10, 1.3, 0.4 * m_scale,
			Vector3(0, 0.5, 0), 40.0, Vector3(0.4 * m_scale, 0.5 * m_scale, 0.4 * m_scale)).position = Vector3(0, 0.7 * m_scale, 0)
		# Sương giá xanh mờ
		_particles(root, _tex("smoke01"), Color(0.5, 0.75, 1.0, 0.35), 6, 1.8, 0.65 * m_scale,
			Vector3(0, 0.4, 0), 30.0, Vector3(0.35 * m_scale, 0.4 * m_scale, 0.35 * m_scale)).position = Vector3(0, 0.8 * m_scale, 0)

	# 4. Quái Độc (Poison Bull, Poison Shadow, Hell Spider, Larva...)
	var is_poison := (number in [8, 12, 13, 39, 448]) or ("poison" in nl) or ("venom" in nl) or ("larva" in nl) or ("spider" in nl) or ("worm" in nl)
	if is_poison and not is_fire:
		has_fx = true
		# Khí độc và bong bóng xanh lá
		_particles(root, _tex("Spark02"), Color(0.3, 1.0, 0.4, 0.85), 10, 1.2, 0.45 * m_scale,
			Vector3(0, 0.6, 0), 35.0, Vector3(0.35 * m_scale, 0.4 * m_scale, 0.35 * m_scale)).position = Vector3(0, 0.6 * m_scale, 0)

	# 5. Quái Điện / Thủy tộc (Death Beam Knight, Hydra, Vepar, Bahamut...)
	var is_electric := (number in [9, 46, 48, 49, 50, 51, 61, 63, 69]) or ("beam" in nl) or ("hydra" in nl) or ("thunder" in nl) or ("lightning" in nl) or ("vepar" in nl) or ("alquamos" in nl)
	if is_electric and not is_fire:
		has_fx = true
		_particles(root, _tex("lighting_mega01"), Color(0.3, 0.7, 1.0, 0.9), 8, 0.8, 0.5 * m_scale,
			Vector3(0, 0.4, 0), 60.0, Vector3(0.4 * m_scale, 0.5 * m_scale, 0.4 * m_scale)).position = Vector3(0, 0.8 * m_scale, 0)

	# 6. Boss & Quái cao cấp (Kundun, Death Gorgon, Gorgon, Nightmare, Selupan...)
	var is_boss := (number in [18, 35, 161, 181, 189, 197, 267, 275, 338, 361, 459, 460]) or ("kundun" in nl) or ("gorgon" in nl) or ("nightmare" in nl) or ("boss" in nl)
	if is_boss:
		has_fx = true
		# Hào quang hắc ám xoáy quanh boss
		_particles(root, _tex("Flare02"), Color(0.85, 0.25, 0.95, 0.8), 12, 1.5, 0.6 * m_scale,
			Vector3(0, 0.5, 0), 50.0, Vector3(0.5 * m_scale, 0.7 * m_scale, 0.5 * m_scale)).position = Vector3(0, 1.0 * m_scale, 0)

	# 7. Quái có mắt sáng (Bull Fighter, Death Cow, Crust, Lizard...)
	var has_eye_lights := (number in [0, 4, 8, 35, 48, 80]) or ("bull" in nl) or ("cow" in nl) or ("crust" in nl) or ("lizard" in nl) or ("gorgon" in nl)
	if has_eye_lights:
		has_fx = true
		var eye_col := Color(1.0, 0.2, 0.1, 0.85)
		if is_ice:
			eye_col = Color(0.2, 0.8, 1.0, 0.85)
		elif is_poison:
			eye_col = Color(0.3, 1.0, 0.2, 0.85)
		elif is_golden:
			eye_col = Color(1.0, 0.9, 0.2, 0.85)
		
		# Thử gắn vào xương đầu nếu có
		var sk = model.get("skeleton") as Skeleton3D
		var head_bone := -1
		if sk:
			for b_name in ["b006", "b005", "b004", "b007", "b008", "b022", "b023", "b026", "b027"]:
				var bi = sk.find_bone(b_name)
				if bi >= 0:
					head_bone = bi
					break
		if head_bone >= 0 and model.has_method("_bone_attachment"):
			var ba = model._bone_attachment(head_bone)
			if ba:
				var e1 := _sprite(ba, _tex("flare01"), 0.35 * m_scale, eye_col, Vector3(0.08 * m_scale, 0.05 * m_scale, 0.12 * m_scale))
				var e2 := _sprite(ba, _tex("flare01"), 0.35 * m_scale, eye_col, Vector3(-0.08 * m_scale, 0.05 * m_scale, 0.12 * m_scale))
				e1.set_meta("pulse", 2.0)
				e2.set_meta("pulse", 2.0)
				_pins.append(e1)
				_pins.append(e2)
		else:
			# Fallback vị trí đầu
			var eye := _sprite(root, _tex("flare01"), 0.5 * m_scale, eye_col, Vector3(0, 1.35 * m_scale, 0.2 * m_scale))
			eye.set_meta("pulse", 2.0)
			_pins.append(eye)

	return has_fx

# ======================================================================
# Vệt sáng ở mắt: lúc tạo quái client gốc gọi
#   CreateJoint(BITMAP_JOINT_ENERGY, ..., SubType 2, o, 30.f)  -> bám EyeLeft,  MaxTails 20
#   CreateJoint(BITMAP_JOINT_ENERGY, ..., SubType 3, o, 30.f)  -> bám EyeRight, MaxTails 8
# EyeLeft / EyeRight = MoveEye(o, b, Phải, Trái) trong MoveCharacterVisual. Texture JointLaser01, rộng 30 đơn vị.
# ======================================================================
const EYE_TRAILS := {
	"MUTANT": [8, 9], "BEAM_KNIGHT": [8, 9], "GOLDEN_WHEEL": [8, 9], "BLOODY_WOLF": [11, 12],
	"TANTALLOS": [24, 25], "TITAN": [28, 27],
}
const EYE_TRAIL_WIDTH := 0.3
var _trails: Array = []   # {node, pts, max, im}
var _trail_acc := 0.0
static var _trail_mat: StandardMaterial3D = null

func _setup_eye_trails(model: Node3D, slot: String) -> bool:
	if not EYE_TRAILS.has(slot):
		return false
	var sk := _skel(model)
	if sk == null:
		return false
	if _trail_mat == null:
		_trail_mat = StandardMaterial3D.new()
		_trail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_trail_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_trail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_trail_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		_trail_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_trail_mat.vertex_color_use_as_albedo = true
		_trail_mat.albedo_texture = MuObjectFxRes.tex("JointLaser01")
	var right: int = EYE_TRAILS[slot][0]
	var left: int = EYE_TRAILS[slot][1]
	for pair in [[left, 20], [right, 8]]:
		var node := _bone_node(sk, int(pair[0]))
		if node == null:
			continue
		var im := ImmediateMesh.new()
		var mi := MeshInstance3D.new()
		mi.mesh = im
		mi.material_override = _trail_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.top_level = true
		add_child(mi)
		mi.global_transform = Transform3D.IDENTITY
		_trails.append({"node": node, "pts": [], "max": int(pair[1]), "im": im, "mi": mi})
	return not _trails.is_empty()

func _update_trails(delta: float) -> void:
	if _trails.is_empty():
		return
	_trail_acc += delta
	var push := _trail_acc >= 0.04   # đuôi mới mỗi tick 25fps (CreateTail)
	if push:
		_trail_acc = 0.0
	var vp := get_viewport()
	var cam := vp.get_camera_3d() if vp else null
	for t in _trails:
		var node := t["node"] as Node3D
		if not is_instance_valid(node) or not node.is_inside_tree():
			continue
		var pts: Array = t["pts"]
		var head := node.global_position
		if push:
			pts.insert(0, head)
			while pts.size() > int(t["max"]):
				pts.pop_back()
		var im := t["im"] as ImmediateMesh
		im.clear_surfaces()
		if pts.size() < 2 or cam == null or not visible:
			continue
		var draw: Array = pts.duplicate()
		draw[0] = head
		var cp := cam.global_position
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		var n := draw.size()
		for i in n:
			var p: Vector3 = draw[i]
			var nb: Vector3 = draw[mini(i + 1, n - 1)] - draw[maxi(i - 1, 0)]
			if nb.length() < 0.0001:
				nb = Vector3.UP
			var side := nb.normalized().cross((cp - p).normalized())
			if side.length() < 0.0001:
				side = Vector3.RIGHT
			side = side.normalized() * EYE_TRAIL_WIDTH * 0.5
			var k := 1.0 - float(i) / float(n)
			im.surface_set_color(Color(k, k, k, 1.0))
			im.surface_set_uv(Vector2(float(i) / float(n - 1), 0))
			im.surface_add_vertex(p - side)
			im.surface_set_uv(Vector2(float(i) / float(n - 1), 1))
			im.surface_add_vertex(p + side)
		im.surface_end()

## Quái chết: tắt mọi hiệu ứng (kể cả sprite / hạt gắn vào xương nằm ngoài node này)
func hide_all() -> void:
	visible = false
	for pin in _pins:
		if is_instance_valid(pin):
			pin.visible = false
	for p in _particles_list:
		if is_instance_valid(p):
			(p as CPUParticles3D).emitting = false
			p.visible = false
	for t in _trails:
		(t["im"] as ImmediateMesh).clear_surfaces()
	_trails.clear()

func _process(delta: float) -> void:
	_update_trails(delta)
	for pin in _pins:
		if not is_instance_valid(pin):
			continue
		var pulse: float = pin.get_meta("pulse", 0.0)
		if pulse > 0.0:
			var alpha: float = sin(Time.get_ticks_msec() * 0.005 * pulse) * 0.35 + 0.65
			var mat = pin.material_override as StandardMaterial3D
			if mat:
				mat.albedo_color.a = clampf(alpha, 0.2, 1.0)

func _exit_tree() -> void:
	for pin in _pins:
		if is_instance_valid(pin) and pin.get_parent() != self:
			pin.queue_free()
	_pins.clear()
	_particles_list.clear()
