extends Node3D

## Hiệu ứng mặc TRỌN BỘ +10..+15 (ZzzCharacter.cpp: FullSetOf + UpdatePlayerEffects):
##   - BITMAP_LIGHT (Effect/flare01) ở 2 tay: xương LinkBone, LinkBone-6, LinkBone-7, scale 1.3,
##     màu = PartObjectColor(giày, 0.5) = màu glow của bộ * 0.5
##   - giày Dragon Knight..Sunlight / Aura: hạt WATERFALL2 bốc lên từ thân (màu theo bộ, vd DK (0.65, 0.3, 0.1))
##   - BITMAP_FLARE: hạt sáng trắng quanh người + vệt sáng xoáy (CreateJoint type 18) từ +12
##   - +15: 2 đốm sáng xanh nhấp nháy sau lưng (xương 20): shiny05 (0.2, 0.4, 0.8) + pin_lights (0.1, 0.15, 1)
## Hệ hạt của MU được mô phỏng gần đúng bằng CPUParticles3D.

const MuModelRes = preload("res://src/mu/MuModel.gd")
const MuCatalogRes = preload("res://src/mu/MuCatalog.gd")

const BONE_RIGHT := 33
const BONE_LEFT := 42
const BONE_BACK := 20
## Vệt sáng trắng xoáy quanh người (trọn bộ +12 trở lên): tắt theo yêu cầu, đặt true để bật lại
const SHOW_FLARE_SPIN := false
## màu hạt WATERFALL2 theo bộ (số đồ của giày -> màu)
const BOOTS_COLOR := {
	29: Color(0.65, 0.3, 0.1),   # Dragon Knight
	30: Color(0.1, 0.1, 0.9),    # Venom Mist
	31: Color(0.0, 0.32, 0.24),  # Sylphid Ray
	32: Color(0.5, 0.24, 0.8),   # Volcano
	33: Color(0.6, 0.4, 0.0),    # Sunlight
}

var _pins: Array = []
var _t := 0.0

## Mức bộ đồ: mọi món (mũ..giày) cùng số hiệu, cấp >= 9; trả về cấp thấp nhất (0 = không phải trọn bộ)
static func set_level(equip: Dictionary, cls: int) -> int:
	var slots := ["boots", "gloves", "pants", "armor", "helm"]
	if cls == 3:   # Magic Gladiator: không cần mũ
		slots = ["boots", "gloves", "pants", "armor"]
	if cls == 6:   # Rage Fighter: không có găng
		slots.erase("gloves")
	var num := -1
	var lv := 99
	for s in slots:
		var it = equip.get(s, {})
		if not (it is Dictionary) or it.is_empty():
			return 0
		var n := int(it.get("number", -1))
		if num < 0:
			num = n
		if n != num or int(it.get("level", 0)) < 9:
			return 0
		lv = mini(lv, int(it.get("level", 0)))
	return lv

static func _tex(name: String) -> Texture2D:
	return MuModelRes.fx(name)

## Quad billboard vẽ cộng sáng. Dùng shader riêng (alpha = độ sáng, màu bù lại) thay cho StandardMaterial3D
## BLEND_MODE_ADD: với StandardMaterial3D phần đen của texture có alpha = 1 nên trên nền trong suốt
## (SubViewport chọn nhân vật) nó thành khung đen đặc quanh nhân vật.
const ADD_SHADER_CODE := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform bool billboard = true;
void vertex() {
	if (billboard) {
		mat4 w = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = VIEW_MATRIX * w * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	}
}
void fragment() {
	vec4 t = texture(tex, UV);
	vec3 c = t.rgb * tint.rgb * COLOR.rgb * (t.a * tint.a * COLOR.a);
	float a = clamp(max(max(c.r, c.g), c.b), 0.0, 1.0);
	if (a < 0.02) {
		discard;
	}
	ALPHA = a;
	ALBEDO = c / max(a, 0.001);
}
"""
static var _add_shader: Shader = null

static func _add_mat(tex: Texture2D, col: Color, billboard: bool = true) -> ShaderMaterial:
	if _add_shader == null:
		_add_shader = Shader.new()
		_add_shader.code = ADD_SHADER_CODE
	var m := ShaderMaterial.new()
	m.shader = _add_shader
	m.set_shader_parameter("tex", tex)
	m.set_shader_parameter("tint", col)
	m.set_shader_parameter("billboard", billboard)
	return m

func _sprite(parent: Node3D, tex: Texture2D, size: float, col: Color, pos := Vector3.ZERO) -> MeshInstance3D:
	var q := QuadMesh.new()
	# sprite MU giữ tỉ lệ texture (pin_lights 16x128 = tia sáng dọc)
	var asp := 1.0
	if tex and tex.get_height() > 0:
		asp = float(tex.get_width()) / float(tex.get_height())
	q.size = Vector2(size * minf(asp, 1.0), size / maxf(asp, 1.0))
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
	p.initial_velocity_min = vel.length() * 0.6
	p.initial_velocity_max = vel.length()
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.0
	var g := Gradient.new()
	g.set_color(0, col)
	g.set_color(1, Color(col.r, col.g, col.b, 0.0) * Color(0, 0, 0, 1))
	p.color_ramp = g
	parent.add_child(p)
	return p

## model: MuCharacterModel đã dựng ; equip: đồ đang mặc
func setup(model, equip: Dictionary, cls: int) -> bool:
	var lv := set_level(equip, cls)
	if lv < 10:
		return false
	var boots: Dictionary = equip.get("boots", {})
	var bn := int(boots.get("number", 0))
	# PartObjectColor(giày, alpha 1, bright 0.5)
	var gc: Color = MuCatalogRes.item_glow_color(11, bn)
	var hand_col := Color(gc.r * 0.5, gc.g * 0.5, gc.b * 0.5)
	var flare: Texture2D = _tex("flare01")
	# 3 đốm sáng mỗi tay (LinkBone, -6, -7), scale 1.3 * 64 đơn vị MU
	for b in [BONE_RIGHT, BONE_RIGHT - 6, BONE_RIGHT - 7, BONE_LEFT, BONE_LEFT - 6, BONE_LEFT - 7]:
		var ba = model._bone_attachment(b)
		if ba:
			_sprite(ba, flare, 0.83, hand_col)
	var root: Node3D = model
	# hạt WATERFALL2 bốc lên (giày bộ DK..Sunlight)
	if BOOTS_COLOR.has(bn):
		var rate := {10: 4, 11: 6, 12: 8, 13: 12, 14: 12, 15: 14}
		_particles(root, _tex("WATERFALL2"), BOOTS_COLOR[bn], int(rate.get(lv, 8)), 1.0, 0.55,
			Vector3(0, 0.9, 0), 10.0, Vector3(0.18, 0.25, 0.05)).position = Vector3(0, 0.6, 0)
	# hạt flare trắng quanh người
	_particles(root, _tex("Flare"), Color(1, 1, 1, 0.9), 3 + (lv - 10) * 2, 1.2, 0.35,
		Vector3(0, 0.5, 0), 60.0, Vector3(0.35, 0.6, 0.35)).position = Vector3(0, 0.9, 0)
	# vệt sáng xoáy quanh người (CreateJoint BITMAP_FLARE type 18) từ +12
	if SHOW_FLARE_SPIN and lv >= 12:
		for i in 2:
			var spin := Node3D.new()
			spin.name = "FlareSpin%d" % i
			spin.position = Vector3(0, 0.3 + 0.8 * i, 0)
			root.add_child(spin)
			var emitter := _particles(spin, _tex("Flare02"), Color(0.75, 0.85, 1.0, 0.9), 40, 0.45, 0.22,
				Vector3.ZERO, 0.0, Vector3(0.01, 0.01, 0.01), false)
			emitter.position = Vector3(0.7, 0, 0)
			spin.set_meta("speed", 4.5 if i == 0 else -3.8)
			spin.set_meta("rise", 0.9)
			_pins.append(spin)
	# +15: 2 đốm xanh sau lưng nhấp nháy
	if lv >= 15:
		var back = model._bone_attachment(BONE_BACK)
		if back:
			for side in [1.0, -1.0]:
				var pos := Vector3(0.13, 0.10, 0.03 * side)
				var s1 := _sprite(back, _tex("shiny05"), 0.32, Color(0.2, 0.4, 0.8), pos)
				var s2 := _sprite(back, _tex("pin_lights"), 0.8, Color(0.1, 0.15, 1.0), pos)
				s1.set_meta("pulse", 0.5)
				s2.set_meta("pulse2", 1.3)
				_pins.append(s1)
				_pins.append(s2)
	return true

func _process(delta: float) -> void:
	_t += delta
	var f := sin(_t * 2.0)   # sinf(WorldTime * 0.002)
	for n in _pins:
		if not is_instance_valid(n):
			continue
		if n.has_meta("speed"):
			n.rotate_y(float(n.get_meta("speed")) * delta)
			var base_y := 0.3 if n.name.ends_with("0") else 1.1
			n.position.y = base_y + 0.35 * sin(_t * float(n.get_meta("rise")))
		elif n.has_meta("pulse"):
			var s := maxf(0.05, 0.5 * absf(f) / 0.5)
			n.scale = Vector3.ONE * s
		elif n.has_meta("pulse2"):
			n.scale = Vector3.ONE * maxf(0.1, 1.3 * f + 0.5) / 1.3
