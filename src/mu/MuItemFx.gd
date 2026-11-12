extends Node3D

## Hiệu ứng sinh ra từ model VẬT PHẨM (cánh đang đeo, đồ nằm trên đất).
## 1) Hiệu ứng gốc theo "itemEffect" của Items/Models (Render/Items/ItemEffects.cpp):
##    wingsOfDarkness : tia sét JointThunder + JointSpirit nối từng cặp lông (xương 22-i <-> 30-i, 7-i <-> 11+i)
##                      và đốm flareBlue tím (0.6, 0.3, 0.8) ở mỗi lông, cỡ nhịp theo sin  (SpawnWingsOfDarkness)
##    wingOfStorm     : mây Clud64 xoay, đốm flare01 cam / đỏ, sét lẻ tẻ                     (SpawnWingOfStorm)
##    wingOfEternal   : đốm flare01 trắng + xanh dương                                          (SpawnWingOfEternal)
##    wingOfIllusion  : đốm Flare đỏ, flare01 xanh lá, hạt Shiny                               (SpawnWingOfIllusion)
##    wingOfRuin      : đốm flare01 tím, hạt energy02 bay lên                                   (SpawnWingOfRuin)
##    wingOfDimension : đốm Flare vàng / tím                                                    (SpawnWingOfDimension)
##    devilsKey / devilsInvitation : 2 đốm Spark02 đỏ nhịp ở xương 1, 2 / 9, 10    (SpawnDevilsKey / SpawnDevilsInvitation)
##    rena            : đốm Spark02 cam lớn ở gốc model                                    (SpawnRena)
##    (wingsOfSoul / wingsOfDragon: mesh sáng nhấp nháy -> item_effect_styles.json "_blend_pulse")
## 2) Bậc hiệu ứng theo CẤP cánh (riêng bản Godot — MU gốc không đổi hình cánh theo cấp):
##    +0..+6  : như gốc
##    +7..+9  : hiệu ứng gốc sáng / to hơn, quầng sáng nhịp ở gốc cánh
##    +10..+12: hiệu ứng gốc sáng hơn (đã bỏ ngôi sao bay theo yêu cầu)
##    +13..+15: tia sét nhỏ chạy giữa các lông cánh (đã bỏ ngôi sao bay)
## Toạ độ: TransformPosition(bones[i], 0) = gốc xương i của model cánh ; cỡ sprite = số điểm ảnh texture * Scale (đơn vị MU).

const MuModelRes = preload("res://src/mu/MuModel.gd")
const GradeFxRes = preload("res://src/mu/MuWeaponGradeFx.gd")

const TICK := 1.0 / 25.0

## Bậc theo cấp: [cấp tối thiểu, độ sáng, cỡ, hạt lấp lánh / giây, tia sét nhỏ / giây]
## (độ sáng / cỡ chỉ tăng nhẹ: hiệu ứng gốc đã là lớp cộng sáng, nhân mạnh sẽ cháy trắng)
## Đã tắt hạt lấp lánh (ngôi sao bay) cho cánh khi cấp cao (cột 3 = 0.0).
const LEVEL_TIERS := [
	[0, 1.0, 1.0, 0.0, 0.0],
	[7, 1.08, 1.0, 0.0, 0.0],
	[10, 1.12, 1.05, 0.0, 0.0],
	[13, 1.18, 1.08, 0.0, 3.0],
]

## Màu chủ đạo của mỗi loại cánh (quầng sáng / hạt theo cấp)
const THEME := {
	"wingsOfDarkness": Color(0.6, 0.3, 0.8),
	"wingOfStorm": Color(0.9, 0.55, 0.25),
	"wingOfEternal": Color(0.35, 0.45, 1.0),
	"wingOfIllusion": Color(1.0, 0.35, 0.3),
	"wingOfRuin": Color(0.7, 0.5, 0.85),
	"wingOfDimension": Color(1.0, 0.7, 0.25),
	"wingsOfSoul": Color(0.4, 0.65, 1.0),
	"wingsOfDragon": Color(1.0, 0.5, 0.2),
}

var _skel: Skeleton3D
var _root: Node3D
var _with_levels := true
var _bone_idx: Dictionary = {}
var _kind := ""
var _level := 0
var _gain := 1.0
var _size := 1.0
var _spark_rate := 0.0
var _arc_rate := 0.0
var _theme := Color(0.6, 0.8, 1.0)
var _t := 0.0
var _acc := 0.0
var _tick := 0
var _spark_acc := 0.0
var _arc_acc := 0.0

var _pool: Array = []        # MeshInstance3D quad dùng lại mỗi khung
var _used := 0
var _parts: Array = []       # hạt: {tex, pos, vel, life, max, scale, color}
var _bolts: Array = []       # tia sét: {tex, a, b (chỉ số xương hoặc Vector3), off: [Vector3], life, max, width, color}
var _bolt_mesh: Dictionary = {}   # tex -> MeshInstance3D(ImmediateMesh)

static func level_tier(level: int) -> Array:
	var out: Array = LEVEL_TIERS[0]
	for t in LEVEL_TIERS:
		if level >= int(t[0]):
			out = t
	return out

const SPAWN_KINDS := ["wingsOfDarkness", "wingOfStorm", "wingOfEternal", "wingOfIllusion", "wingOfRuin", "wingOfDimension",
	"devilsKey", "devilsInvitation", "rena"] + NPC_KINDS

## NPC có hiệu ứng riêng (ZzzCharacter.cpp: UpdateCharacterTypeEffects), khoá = "model" trong Monsters.json
const NPC_KINDS := ["MODEL_NPC_DEVILSQUARE", "MODEL_MIX_NPC", "MODEL_NPC_SEVINA", "MODEL_SEED_MASTER",
	"MODEL_SEED_INVESTIGATOR", "MODEL_NPC_CASTEL_GATE"]

static func has_npc(model_slot: String) -> bool:
	return model_slot in NPC_KINDS

static func has_spawn(effect: String) -> bool:
	return effect in SPAWN_KINDS

## inst: model vật phẩm (cánh đã gắn vào lưng / đồ trên đất) ; item: {"group","number","level"} ; effect: itemEffect
## with_levels: thêm bậc hiệu ứng theo cấp (cánh). false = chỉ hiệu ứng gốc
func setup(inst: Node3D, item: Dictionary, effect: String, with_levels := true) -> bool:
	_root = inst
	_skel = MuModelRes.find_first(inst, "Skeleton3D") as Skeleton3D
	_with_levels = with_levels
	_kind = effect
	_level = int(item.get("level", 0))
	var tier := level_tier(_level)
	_gain = float(tier[1])
	_size = float(tier[2])
	_spark_rate = float(tier[3])
	_arc_rate = float(tier[4])
	_theme = THEME.get(_kind, Color(0.6, 0.8, 1.0))
	# model không có bộ xương (Devil01, ConChip00): đốm sáng đặt ở gốc model
	if _skel == null and _kind not in ["rena", "devilsKey", "devilsInvitation"]:
		return false
	return has_spawn(_kind) or (_with_levels and _level >= 7)

# ============================================================== xương

func _bone(i: int) -> Vector3:
	if _skel == null:
		return _root.global_position
	var idx: int = _bone_idx.get(i, -2)
	if idx == -2:
		idx = _skel.find_bone("b%03d" % i)
		_bone_idx[i] = idx
	if idx < 0:
		return _skel.global_position
	return _skel.global_transform * _skel.get_bone_global_pose(idx).origin

func _bone_count() -> int:
	return _skel.get_bone_count() if _skel else 0

func _model_scale() -> float:
	return (_skel if _skel else _root).global_transform.basis.get_scale().x

# ============================================================== sprite (mỗi khung)

func _quad() -> MeshInstance3D:
	if _used < _pool.size():
		var q: MeshInstance3D = _pool[_used]
		_used += 1
		q.visible = true
		return q
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2.ONE
	mi.mesh = qm
	mi.top_level = true
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new()
	m.shader = _add_shader()
	mi.material_override = m
	add_child(mi)
	_pool.append(mi)
	_used += 1
	return mi

static var _shader: Shader = null
static func _add_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = GradeFxRes.ADD_SHADER_CODE
	return _shader

## CreateSprite(bitmap, pos, scale, light, o, rotation)
## Cỡ như DescribeSprite / RenderParticles: rộng = số điểm ảnh của texture * Scale (đơn vị MU, 100 = 1 m)
func sprite(bitmap: String, pos: Vector3, scale_mu: float, col: Color, rot_deg := 0.0) -> void:
	var tex: Texture2D = MuFx.tex(bitmap)
	var w := float(tex.get_width()) if tex else 64.0
	var h := float(tex.get_height()) if tex else 64.0
	var q := _quad()
	var k := scale_mu / 100.0 * _model_scale()
	q.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3(w * k, h * k, w * k)), pos)
	var m := q.material_override as ShaderMaterial
	m.set_shader_parameter("tex", tex)
	m.set_shader_parameter("tint", Vector3(col.r, col.g, col.b))
	m.set_shader_parameter("rot", rot_deg)

## CreateParticle: hạt bay nhẹ rồi mờ dần
## shrink: Scale giảm mỗi giây ; spin: độ xoay mỗi giây ; col là độ sáng LÚC SINH, giảm tuyến tính về 0
func particle(bitmap: String, pos: Vector3, scale_mu: float, col: Color, life := 0.5, vel := Vector3.ZERO,
		shrink := 0.0, spin := 0.0) -> void:
	_parts.append({"tex": bitmap, "pos": pos, "vel": vel, "life": life, "max": life, "scale": scale_mu, "color": col,
		"rot": randf() * 360.0, "shrink": shrink, "spin": spin})

## CreateJoint: tia sét gãy khúc giữa 2 xương (đi theo cánh khi vỗ)
func bolt(bitmap: String, a, b, width_mu: float, col: Color, life := 0.16, segs := 6, jitter := 0.08) -> void:
	var off: Array = [Vector3.ZERO]
	for i in range(1, segs):
		off.append(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * jitter)
	off.append(Vector3.ZERO)
	_bolts.append({"tex": bitmap, "a": a, "b": b, "off": off, "life": life, "max": life,
		"width": width_mu / 100.0, "color": col})

func _pt(v) -> Vector3:
	return _bone(int(v)) if v is int else v

# ============================================================== hiệu ứng gốc (mỗi khung / mỗi tick)

func _process(delta: float) -> void:
	if _root == null or not is_instance_valid(_root) or not is_visible_in_tree():
		return
	_t += delta
	_acc += delta
	while _acc >= TICK:
		_acc -= TICK
		_tick += 1
		_on_tick()
	_used = 0
	var wt := _t * 1000.0   # WorldTime (ms)
	match _kind:
		"wingsOfDarkness": _darkness(wt)
		"wingOfStorm": _storm(wt)
		"wingOfEternal": _eternal(wt)
		"wingOfIllusion": _illusion(wt)
		"wingOfRuin": _ruin(wt)
		"wingOfDimension": _dimension(wt)
		"devilsKey": _devils(wt, [1, 2])
		"devilsInvitation": _devils(wt, [9, 10])
		"rena":
			var l := sin(wt * 0.002) * 0.25 + 0.75
			sprite("BITMAP_SPARK+1", _root.global_position, 2.5, Color(l, l * 0.5, 0.0))
		"MODEL_NPC_DEVILSQUARE": _charon(wt)
		"MODEL_MIX_NPC": _bone_light(wt, "BITMAP_LIGHT", 1.5, 32)
		"MODEL_NPC_SEVINA": _bone_light(wt, "BITMAP_LIGHT", 2.5, 6)
		"MODEL_SEED_MASTER":
			var fl := (sin(wt * 0.001) + 1.0) * 0.3 + 0.4
			sprite("BITMAP_FLARE", _bone(39), 2.0, Color(fl * 0.5, fl * 0.5, fl * 0.5))
		"MODEL_SEED_INVESTIGATOR":
			var fl2 := (sin(wt * 0.001) + 1.0) * 0.3 + 0.4
			for bi in [69, 70]:
				sprite("BITMAP_FLARE_BLUE", _bone(bi), 1.0, Color(fl2 * 0.5, fl2 * 0.5, fl2 * 0.5))
		"MODEL_NPC_CASTEL_GATE":
			var gl := (sin(wt * 0.002) + 2.0) * 0.5
			for e in [[2, Vector3(4, 3, -4)], [4, Vector3(5, 3, 2)]]:
				sprite("BITMAP_LIGHT", _bone_at(e[0], e[1]), gl / 2.0, Color(gl, gl * 0.5, gl * 0.3))
	_update_trails()
	_level_fx(wt, delta)
	_draw_parts(delta)
	_draw_bolts(delta)
	for i in range(_used, _pool.size()):
		(_pool[i] as MeshInstance3D).visible = false

func _c(r: float, g: float, b: float) -> Color:
	return Color(r * _gain, g * _gain, b * _gain)

func _on_tick() -> void:
	match _kind:
		"MODEL_NPC_DEVILSQUARE":
			_trail_tick()
			# rand_fps_check(30): CreateJoint(BITMAP_JOINT_ENERGY, điểm ngẫu nhiên ±50, quả cầu, SubType 6, 20)
			if randi() % 30 == 0:
				var o := _charon_orb()
				var start := o + Vector3(randf_range(-50, 50), randf_range(-50, 50), randf_range(-50, 50)) / 100.0 * _model_scale()
				_trails.append({"head": start, "pts": [start], "life": 120, "swirl": Vector3(randf_range(-1, 1),
					randf_range(-1, 1), randf_range(-1, 1)).normalized()})
		"wingsOfDarkness":
			var sc := (sin(_t * 4.0) * 0.3 + 0.3) * 10.0 + 20.0
			for i in 5:
				# rand_fps_check(1): mỗi tick tham chiếu
				bolt("BITMAP_JOINT_THUNDER", 30 - i, 22 - i, sc * _size, _c(0.55, 0.35, 1.0), 0.16, 6, 0.06)
				bolt("BITMAP_JOINT_SPIRIT", 22 - i, 30 - i, (sc + 5.0) * _size, _c(0.35, 0.2, 0.7), 0.2, 4, 0.03)
				bolt("BITMAP_JOINT_THUNDER", 11 + i, 7 - i, sc * _size, _c(0.55, 0.35, 1.0), 0.16, 6, 0.06)
				bolt("BITMAP_JOINT_SPIRIT", 7 - i, 11 + i, (sc + 5.0) * _size, _c(0.35, 0.2, 0.7), 0.2, 4, 0.03)
		"wingOfStorm":
			if _tick % 2 == 0:
				for bi in [11, 21, 29, 63, 81, 89]:
					if randi() % 20 == 0:
						var p := _bone(bi)
						bolt("BITMAP_JOINT_THUNDER", p, p + Vector3(randf_range(-0.4, 0.4), randf_range(-0.6, 0.1), randf_range(-0.4, 0.4)),
							18.0 * _size, _c(0.6, 0.6, 0.9), 0.24, 5, 0.08)
		"wingOfIllusion":
			if _tick % 2 == 0:
				var l := (sin(_t * 4.0) + 1.0) * 0.05
				for bi in [13, 31]:
					particle("BITMAP_SHINY", _bone(bi), 0.5 * _size, _c(0.8 + l, 0.8 + l, 0.3 + l), 0.6,
						Vector3(randf_range(-0.2, 0.2), randf_range(0.1, 0.4), randf_range(-0.2, 0.2)))
		"wingOfRuin":
			var light := _c(0.6, 0.4, 0.7)
			var spark := [7, 16, 25, 57, 48, 39, 11, 22, 31, 63, 54, 40, 10, 21, 30, 62, 53, 41, 9,
				20, 29, 61, 52, 42, 8, 19, 28, 60, 51, 43, 18, 27, 59, 50, 17, 26, 58, 49]
			for i in spark.size():
				var sc := 0.1 if i < 6 else (0.3 if i < 18 else (0.5 if i < 30 else 0.7))
				# BITMAP_CHROME_ENERGY2 (ZzzEffectParticle.cpp): sống 8 tick, đứng yên, Scale = sc * rand(1.28..1.91)
				# giảm 0.04 / tick, xoay 5 độ / tick, độ sáng = LifeTime / 24 (lúc sinh 8/24 = 1/3)
				particle("BITMAP_CHROME_ENERGY2", _bone(spark[i]), sc * _size * randf_range(1.28, 1.91),
					light * (8.0 / 24.0), 8.0 * TICK, Vector3.ZERO, 0.04 * 25.0, 5.0 * 25.0)

func _darkness(wt: float) -> void:
	var sc := (sin(wt * 0.004) * 0.3 + 0.3) * 10.0 + 20.0
	var col := _c(0.6, 0.3, 0.8)
	for i in 5:
		sprite("BITMAP_FLARE_BLUE", _bone(22 - i), sc / 28.0 * _size, col)
		sprite("BITMAP_FLARE_BLUE", _bone(7 - i), sc / 28.0 * _size, col)

func _storm(wt: float) -> void:
	# Đã tắt mây mờ BITMAP_CLUD64 theo yêu cầu để cánh sạch và rõ nét
	var fs := absf(sin(wt * 0.003)) * 0.2
	for bi in [64, 61, 69, 77, 86, 98, 97, 99, 104, 103, 105, 12, 8, 17, 26, 34, 52, 44, 51, 50, 49, 45]:
		if bi in [12, 64, 98, 52]:
			sprite("BITMAP_LIGHT", _bone(bi), (fs + 1.4) * _size, _c(0.9, 0.0, 0.0))
		else:
			sprite("BITMAP_LIGHT", _bone(bi), (fs + 0.3) * _size, _c(0.8, 0.5, 0.2))

func _eternal(wt: float) -> void:
	var sc := absf(sin(wt * 0.003)) * 0.2
	var lum := absf(sin(wt * 0.003)) * 0.3
	for bi in [24, 31, 15, 8, 53, 35]:
		sprite("BITMAP_LIGHT", _bone(bi), (sc + 1.3) * _size, _c(0.5 + lum, 0.5 + lum, 0.6 + lum))
	var blue := _c(0.1, 0.1, 0.9)
	for bi in [22, 23, 25, 29, 30, 28, 32, 13, 16, 14, 12, 9, 7, 6, 57, 58, 40, 39]:
		sprite("BITMAP_LIGHT", _bone(bi), (sc + 1.5) * _size, blue)
	for bi in [56, 38, 51, 45]:
		sprite("BITMAP_LIGHT", _bone(bi), (sc + 0.5) * _size, blue)

func _illusion(wt: float) -> void:
	var sc := absf(sin(wt * 0.002)) * 0.2
	var lum := absf(sin(wt * 0.002)) * 0.4
	for bi in [5, 6, 7, 8, 18, 19, 23, 24, 25, 27, 37, 38]:
		sprite("BITMAP_FLARE", _bone(bi), (sc + 0.6) * _size, _c(0.5 + lum, lum, lum))
	for bi in [4, 9, 13, 14, 26, 32, 31, 33]:
		sprite("BITMAP_LIGHT", _bone(bi), 1.3 * _size, _c(lum, 0.5 + lum, lum))
	var fl := (sin(wt * 0.004) + 1.0) * 0.05
	sprite("BITMAP_LIGHT", _bone(33), 0.4 * _size, _c(0.8 + fl, 0.8 + fl, 0.3 + fl), 0.5)

func _ruin(wt: float) -> void:
	var sc := absf(sin(wt * 0.003)) * 0.2
	var lum := absf(sin(wt * 0.003)) * 0.3
	for bi in [6, 15, 24, 56, 47, 38]:
		sprite("BITMAP_LIGHT", _bone(bi), (sc + 1.5) * _size, _c(0.7 + lum, 0.5 + lum, 0.8 + lum))

func _dimension(wt: float) -> void:
	var sc := absf(sin(wt * 0.002)) * 0.2
	var lum := absf(sin(wt * 0.002)) * 0.4
	var pos := [7, 30, 31, 43, 8, 20]
	for i in 2:
		sprite("BITMAP_FLARE", _bone(pos[i]), (sc + 2.0) * _size, _c((1.0 + lum) / 2.0, (0.7 + lum) / 2.0, (0.2 + lum) / 2.0))
	for i in range(2, 6):
		sprite("BITMAP_FLARE", _bone(pos[i]), (sc + 0.5) * _size, _c((1.0 + lum) / 4.0, (0.7 + lum) / 4.0, (0.2 + lum) / 4.0))
	for bi in [29, 38, 42, 19, 15, 6]:
		sprite("BITMAP_FLARE", _bone(bi), (sc + 2.0) * _size, _c((0.5 + lum) / 2.0, (0.1 + lum) / 2.0, (0.4 + lum) / 2.0))

# ============================================================== bậc theo cấp

## Điểm lệch `off` (đơn vị MU) trong hệ toạ độ của xương i (TransformPosition(BoneTransform[i], off))
func _bone_at(i: int, off: Vector3) -> Vector3:
	if _skel == null:
		return _root.global_position
	_bone(i)
	var idx: int = _bone_idx.get(i, -1)
	if idx < 0:
		return _skel.global_position
	return _skel.global_transform * (_skel.get_bone_global_pose(idx) * (off / 100.0))

## SpawnBoneLight: sáng (L, 0.6L, 0.4L), L = sin(WorldTime * 0.002) * 0.3 + 0.7
func _bone_light(wt: float, bitmap: String, scale_mu: float, bone: int) -> void:
	var l := sin(wt * 0.002) * 0.3 + 0.7
	sprite(bitmap, _bone(bone), scale_mu, Color(l, l * 0.6, l * 0.4))

## Charon (MODEL_NPC_DEVILSQUARE): quả cầu = 2 sprite lightning2 xoay ngược chiều (WorldTime / 50 độ)
## tại xương 20 lệch (3.5, -12, 10), sáng L = sin(WorldTime * 0.002) * 0.35 + 0.65
func _charon_orb() -> Vector3:
	return _bone_at(20, Vector3(3.5, -12.0, 10.0))

func _charon(wt: float) -> void:
	var l := sin(wt * 0.002) * 0.35 + 0.65
	var o := _charon_orb()
	sprite("BITMAP_LIGHTNING+1", o, 0.3, Color(l, l, l), wt / 50.0)
	sprite("BITMAP_LIGHTNING+1", o, 0.3, Color(l, l, l), -wt / 50.0)

## Vệt năng lượng (BITMAP_JOINT_ENERGY SubType 6): đầu vệt bay vòng về quả cầu, đuôi 8 điểm, rộng 20
var _trails: Array = []

func _trail_tick() -> void:
	var o := _charon_orb()
	var keep: Array = []
	for t in _trails:
		t["life"] -= 1
		var head: Vector3 = t["head"]
		var to := o - head
		var d := to.length()
		if t["life"] <= 0 or d < 0.03:
			continue
		# bay về đích, lệch vòng theo trục xoáy (giảm dần khi tới gần) -> đường cong như vệt gốc
		var step := minf(0.06 * _model_scale(), d)
		var curl: Vector3 = (t["swirl"] as Vector3).cross(to.normalized()) * minf(d, 0.4) * 0.35
		head += (to.normalized() * step + curl * step * 4.0)
		t["head"] = head
		var pts: Array = t["pts"]
		pts.append(head)
		if pts.size() > 8:
			pts.pop_front()
		keep.append(t)
	_trails = keep

func _update_trails() -> void:
	for t in _trails:
		if (t["pts"] as Array).size() >= 2:
			_bolts.append({"tex": "BITMAP_JOINT_ENERGY", "pts": (t["pts"] as Array).duplicate(), "life": 0.0001,
				"max": 0.0001, "width": 20.0 / 100.0, "color": Color(0.9, 0.9, 0.9), "frame": true})

## SpawnDevilsKey / SpawnDevilsInvitation: Spark+1 đỏ nhịp ở 2 xương
func _devils(wt: float, bones: Array) -> void:
	var l := sin(wt * 0.002) * 0.35 + 0.65
	for bi in bones:
		sprite("BITMAP_SPARK+1", _bone(bi), l * 0.8, Color(l * 2.0, l * 0.32, l * 0.32))

func _level_fx(wt: float, delta: float) -> void:
	if not _with_levels or _level < 7:
		return
	var n := _bone_count()
	if n <= 0:
		return
	# quầng sáng nhịp ở gốc cánh (xương 0)
	var p := 0.75 + 0.25 * sin(wt * 0.003)
	var th := _theme * (0.12 * p)
	sprite("BITMAP_LIGHT", _bone(0), 1.2 * p, Color(th.r, th.g, th.b))
	# hạt lấp lánh bay ra từ lông cánh
	if _spark_rate > 0.0:
		_spark_acc += delta * _spark_rate
		while _spark_acc >= 1.0:
			_spark_acc -= 1.0
			var b := _bone(1 + randi() % maxi(n - 1, 1))
			# shiny05: ngôi sao 8 tia mảnh (Shiny01 là dấu thập 16 px, phóng to thành nét dày)
			var c := _theme.lerp(Color(1, 1, 1), 0.5) * 1.15
			particle("shiny05", b, randf_range(0.5, 0.8), Color(c.r, c.g, c.b), randf_range(0.6, 1.0),
				Vector3(randf_range(-0.15, 0.15), randf_range(0.15, 0.45), randf_range(-0.15, 0.15)))
	# tia sét nhỏ giữa 2 lông kề nhau
	if _arc_rate > 0.0:
		_arc_acc += delta * _arc_rate
		while _arc_acc >= 1.0:
			_arc_acc -= 1.0
			var a := 1 + randi() % maxi(n - 2, 1)
			var c2 := _theme.lerp(Color(1, 1, 1), 0.3) * 0.45
			bolt("BITMAP_JOINT_THUNDER", a, a + 1, 10.0 * _size, Color(c2.r, c2.g, c2.b), 0.14, 4, 0.04)

# ============================================================== vẽ hạt / tia sét

func _draw_parts(delta: float) -> void:
	var keep: Array = []
	for p in _parts:
		p["life"] -= delta
		if p["life"] <= 0.0:
			continue
		p["pos"] += p["vel"] * delta
		p["scale"] = maxf(float(p["scale"]) - float(p["shrink"]) * delta, 0.0)
		p["rot"] = float(p["rot"]) + float(p["spin"]) * delta
		var k: float = p["life"] / p["max"]
		var c: Color = p["color"] * k
		sprite(p["tex"], p["pos"], p["scale"], Color(c.r, c.g, c.b), p["rot"])
		keep.append(p)
	_parts = keep

func _bolt_mi(bitmap: String) -> MeshInstance3D:
	if _bolt_mesh.has(bitmap):
		return _bolt_mesh[bitmap]
	var mi := MeshInstance3D.new()
	mi.mesh = ImmediateMesh.new()
	mi.top_level = true
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.material_override = MuFx.mat(bitmap, "add")
	add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	_bolt_mesh[bitmap] = mi
	return mi

func _draw_bolts(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var cam_pos: Vector3 = cam.global_position if cam else Vector3.ZERO
	var keep: Array = []
	var by_tex: Dictionary = {}
	for b in _bolts:
		if b.get("frame", false):
			b["life"] = b["max"]
		else:
			b["life"] -= delta
			if b["life"] <= 0.0:
				continue
			keep.append(b)
		if not by_tex.has(b["tex"]):
			by_tex[b["tex"]] = []
		by_tex[b["tex"]].append(b)
	_bolts = keep
	var ms := _model_scale()
	for tex_name in _bolt_mesh.keys():
		if not by_tex.has(tex_name):
			(_bolt_mesh[tex_name].mesh as ImmediateMesh).clear_surfaces()
	for tex_name in by_tex.keys():
		var mi := _bolt_mi(tex_name)
		mi.global_transform = Transform3D.IDENTITY
		var im := mi.mesh as ImmediateMesh
		im.clear_surfaces()
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for b in by_tex[tex_name]:
			var k: float = b["life"] / b["max"]
			var col: Color = b["color"] * k
			col.a = 1.0
			var w: float = b["width"] * ms * 0.5
			var pts: Array = []
			if b.has("pts"):
				pts = b["pts"]
			else:
				var a := _pt(b["a"])
				var e := _pt(b["b"])
				var off: Array = b["off"]
				for i in off.size():
					pts.append(a.lerp(e, float(i) / (off.size() - 1)) + (off[i] as Vector3) * ms)
			var n := pts.size() - 1
			for i in n:
				var p0: Vector3 = pts[i]
				var p1: Vector3 = pts[i + 1]
				var dir := (p1 - p0)
				var side := dir.cross(cam_pos - p0).normalized() * w
				if side == Vector3.ZERO:
					continue
				var u0 := float(i) / n
				var u1 := float(i + 1) / n
				var v := [[p0 - side, Vector2(u0, 0)], [p0 + side, Vector2(u0, 1)], [p1 + side, Vector2(u1, 1)],
					[p0 - side, Vector2(u0, 0)], [p1 + side, Vector2(u1, 1)], [p1 - side, Vector2(u1, 0)]]
				for vv in v:
					im.surface_set_color(col)
					im.surface_set_uv(vv[1])
					im.surface_add_vertex(vv[0])
		im.surface_end()
