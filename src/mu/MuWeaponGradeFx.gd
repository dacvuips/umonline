extends Node3D

## Hiệu ứng VŨ KHÍ +15 (ZzzObject.cpp: SpawnNextGradeWeaponEffects), mỗi vũ khí +15 đang cầm:
##   xương weaponIndex (tay phải 27, tay trái 36; cung / nỏ luôn 27) — cẳng tay:
##     3 x BITMAP_LIGHT (Effect/flare01) màu (1, 0.6, 0), scale 0.6, tại x = 0 / 10 / 20 (đơn vị MU)
##   xương weaponIndex2 (28 / 37) — bàn tay, tại x = 10:
##     BITMAP_MAGIC (Magic_Ground1) scale 0.35, màu (0.7f + 0.3, 0.1f + 0.1, 0), f = |sin(t * 2)|
##     BITMAP_FLARE_RED (flareRed) màu trắng, scale 0.6 * rand(0..0.6) + 0.4 (đổi mỗi khung)
##     hạt BITMAP_LIGHTNING_MEGA1..3 (lighting_mega01..03) mỗi khung tham chiếu (25 / giây), màu (1, 0.2, 0),
##       scale rand(0.1..0.9), xoay ngẫu nhiên, đứng yên tại chỗ sinh, alpha giảm 0.15 / khung (~0.24 giây)
## Không hiện ở Chaos Castle / Cursed Temple ngoài vùng an toàn (DrawsNextGradeObjects) — bản Godot chưa có các map này.

const MuModelRes = preload("res://src/mu/MuModel.gd")
const MuCatalogRes = preload("res://src/mu/MuCatalog.gd")

## 1 đơn vị scale sprite / hạt của MU = 64 đơn vị MU = 0.64 m (giống MuFullSetFx)
const SPRITE_UNIT := 0.64
const REF_FPS := 25.0
const LIGHTNING_LIFE := 6.0 / REF_FPS   # alpha 1 -> 0.1, giảm 0.15 mỗi khung

## Cộng sáng theo giá trị gamma như bộ đệm 8-bit của MU (xem mu_item_glow.gdshader).
## particle = true: billboard xoay theo góc của hạt (INSTANCE_CUSTOM.x), màu theo COLOR của hạt.
const ADD_SHADER_CODE := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform sampler2D tex : filter_linear, repeat_disable;
uniform vec3 tint = vec3(1.0);
uniform bool particle = false;
uniform float rot = 0.0;      // góc xoay sprite trên màn hình (độ), CreateSprite(..., Rotation)
uniform float pulse = 0.0;    // > 0: màu nhân |sin(TIME * pulse)|
void vertex() {
	mat4 w = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	if (particle || rot != 0.0) {
		float a = particle ? INSTANCE_CUSTOM.x : radians(rot);
		w = w * mat4(vec4(cos(a), -sin(a), 0.0, 0.0), vec4(sin(a), cos(a), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	}
	MODELVIEW_MATRIX = VIEW_MATRIX * w * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}
void fragment() {
	vec3 c = texture(tex, UV).rgb * tint;
	if (particle) { c *= COLOR.rgb; }
	if (pulse > 0.0) { c *= abs(sin(TIME * pulse)); }
	float a = clamp(max(max(c.r, c.g), c.b), 0.0, 1.0);
	if (a < 0.03) {
		discard;
	}
	ALPHA = a;
	ALBEDO = c / max(a, 0.001);
}
"""
static var _shader: Shader = null

var _t := 0.0
var _magic: Array = []      # sprite vòng phép đỏ nhấp nháy
var _flare_red: Array = []  # sprite flareRed đổi cỡ mỗi khung
var _acc := 0.0

static func _mat(tex: Texture2D, tint: Color, particle := false) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = ADD_SHADER_CODE
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("tex", tex)
	m.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	m.set_shader_parameter("particle", particle)
	return m

func _sprite(parent: Node3D, tex_name: String, scale_mu: float, col: Color, pos: Vector3) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2.ONE * scale_mu * SPRITE_UNIT
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = _mat(MuModelRes.fx(tex_name), col)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	parent.add_child(mi)
	return mi

## Hạt sét: phát từ vị trí của `parent` (theo xương), hạt sinh ra đứng yên trong thế giới
func _lightning(parent: Node3D, tex_name: String, pos: Vector3, per_sec: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE * SPRITE_UNIT
	q.material = _mat(MuModelRes.fx(tex_name), Color(1, 1, 1), true)
	p.mesh = q
	p.lifetime = LIGHTNING_LIFE
	p.amount = maxi(2, int(ceil(per_sec * LIGHTNING_LIFE)) + 1)
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINT
	p.direction = Vector3.UP
	p.spread = 0.0
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.0
	p.gravity = Vector3.ZERO
	p.angle_min = 0.0
	p.angle_max = 360.0
	# fScale = rand(10..89) * 0.01
	p.scale_amount_min = 0.1
	p.scale_amount_max = 0.9
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.2, 0.0))
	g.set_color(1, Color(0.1, 0.02, 0.0))
	p.color_ramp = g
	p.position = pos
	parent.add_child(p)
	return p

static func _static_sprite(parent: Node3D, tex_name: String, scale_mu: float, col: Color, pos := Vector3.ZERO) -> MeshInstance3D:
	var tex: Texture2D = MuModelRes.fx(tex_name)
	var q := QuadMesh.new()
	# sprite MU giữ tỉ lệ texture (pin_lights 16x128 = tia sáng dọc)
	var asp := 1.0
	if tex and tex.get_height() > 0:
		asp = float(tex.get_width()) / float(tex.get_height())
	var sz := scale_mu * SPRITE_UNIT
	q.size = Vector2(sz * minf(asp, 1.0), sz / maxf(asp, 1.0))
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = _mat(tex, col)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	parent.add_child(mi)
	return mi

## Ngôi sao xanh của mỗi món trang trí +15 (RenderLinkObject, ZzzCharacter.cpp: MODEL_15GRADE_ARMOR_OBJ_*),
## đặt tại gốc của món (xương 0):
##   BITMAP_MAGIC scale 0.12, màu (0.2, 0.4, 1) * |sin(WorldTime * 0.01)|
##   BITMAP_SHINY+5 (shiny05) scale 0.4, màu (0.4, 0.7, 1)
##   BITMAP_PIN_LIGHT (pin_lights) scale 0.6, màu (0.1, 0.3, 1), xoay 90 độ
static func add_grade15_star(parent: Node3D) -> void:
	var m := _static_sprite(parent, "Magic_Ground1", 0.12, Color(0.2, 0.4, 1.0))
	(m.material_override as ShaderMaterial).set_shader_parameter("pulse", 10.0)
	_static_sprite(parent, "shiny05", 0.4, Color(0.4, 0.7, 1.0))
	var pin := _static_sprite(parent, "pin_lights", 0.6, Color(0.1, 0.3, 1.0))
	(pin.material_override as ShaderMaterial).set_shader_parameter("rot", 90.0)

## model: MuCharacterModel đã dựng ; equip: đồ đang mặc. false = không có vũ khí +15
func setup(model, equip: Dictionary) -> bool:
	var any := false
	var hands := ["right", "left"]
	for i in hands.size():
		var w = equip.get(hands[i], {})
		if not (w is Dictionary) or w.is_empty() or int(w.get("level", 0)) < 15:
			continue
		var g := int(w.get("group", 0))
		# MODEL_BOW <= Type < MODEL_STAFF: cung / nỏ luôn dùng xương tay phải
		var bone1 := 27 if (g == MuCatalogRes.GROUP_BOW or i == 0) else 36
		var bone2 := bone1 + 1
		var ba1 = model._bone_attachment(bone1)
		var ba2 = model._bone_attachment(bone2)
		if ba1 == null or ba2 == null:
			continue
		any = true
		for x in [0.0, 10.0, 20.0]:
			_sprite(ba1, "flare01", 0.6, Color(1.0, 0.6, 0.0), Vector3(x / 100.0, 0, 0))
		var at := Vector3(0.1, 0, 0)
		_magic.append(_sprite(ba2, "Magic_Ground1", 0.35, Color(1, 1, 1), at))
		_flare_red.append(_sprite(ba2, "flareRed", 0.7, Color(1, 1, 1), at))
		# 25 hạt / giây, chọn ngẫu nhiên 1 trong 3 texture sét
		for k in 3:
			_lightning(ba2, "lighting_mega0%d" % (k + 1), at, REF_FPS / 3.0)
	return any

func _process(delta: float) -> void:
	_t += delta
	var f := absf(sin(_t * 2.0))   # absf(sinf(WorldTime * 0.002f))
	var mc := Vector3(0.7 * f + 0.3, 0.1 * f + 0.1, 0.0)
	for m in _magic:
		if is_instance_valid(m):
			(m.material_override as ShaderMaterial).set_shader_parameter("tint", mc)
	# flareRed đổi cỡ mỗi khung tham chiếu: 0.6 * rand(0..0.59) + 0.4
	_acc += delta
	if _acc >= 1.0 / REF_FPS:
		_acc = 0.0
		for s in _flare_red:
			if is_instance_valid(s):
				s.scale = Vector3.ONE * ((0.6 * randf() * 0.6 + 0.4) / 0.7)
