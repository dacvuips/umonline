extends MuFx
class_name MoveTargetFx

## Điểm đích khi nhấp chuột xuống đất để nhân vật chạy tới — PORT từ client gốc:
##   ZzzInterface.cpp  : sau PathFinding2 thành công -> DeleteEffect + CreateEffect(MODEL_MOVE_TARGETPOSITION_EFFECT, vị trí va chạm, Light (1, 1, 0))
##                       (chỉ khi ô đích không phải TW_NOMOVE)
##   ZzzEffect.cpp     : MODEL_MOVE_TARGETPOSITION_EFFECT SubType 0 -> LifeTime 30, xoá hiệu ứng cũ rồi tạo
##                       BITMAP_MAGIC (SubType 11, vòng phép xoay), BITMAP_TARGET_POSITION_EFFECT2 (cursorpin02, ngôi sao 4 cánh)
##                       và 4 tia MODEL_SPEARSKILL SubType 16 (ánh sáng dựng đứng) cao +85
##   MoveHandlers.cpp  : mỗi tick tạo hạt BITMAP_SPARK+1 màu (1, .7, .3) ở +110 ; cứ 15 tick tạo thêm BITMAP_TARGET_POSITION_EFFECT1
##                       (cursorpin01, thu nhỏ 0.04/tick tới 0.2 rồi biến mất) ; EFFECT2 phập phồng Scale 0.8..1.8 (±0.15/tick) ;
##                       10 tick cuối mờ dần.
## 1 ô decal (RenderTerrainAlphaBitmap) = 1 m.

const LIFE := 30.0
const LIGHT := Color(1.0, 0.7, 0.3)
const RING_START := 1.8
const RING_STEP := 0.04
const RING_MIN := 0.2

static var _current: MoveTargetFx = null

var _origin := Vector3.ZERO
var _star: Dictionary = {}
var _magic: Dictionary = {}
var _rings: Array = []
var _star_dir := 0          # m_iAnimation: 0 = thu nhỏ, 1 = phóng to
var _star_scale := 1.8
var _beam: MeshInstance3D = null

## Hiện điểm đích tại vị trí đất (Godot, m). Gọi sau khi tìm được đường đi.
static func show_at(parent: Node, pos: Vector3) -> void:
	if is_instance_valid(_current):
		_current.queue_free()
	var fx := MoveTargetFx.new()
	fx._origin = pos
	_current = fx
	parent.add_child(fx)

func _exit_tree() -> void:
	if _current == self:
		_current = null
	super._exit_tree()

func _start() -> void:
	_min_ticks = int(LIFE)
	var g := _ground_point()
	_star = particle("BITMAP_TARGET_POSITION_EFFECT2", g, {"size": _star_scale, "life": LIFE, "color": LIGHT, "fade": false, "rot": 0.0})
	if not _star.is_empty():
		_star["flat"] = true
	_magic = particle("BITMAP_MAGIC+1", g, {"size": 1.2, "life": LIFE, "color": LIGHT, "fade": false, "rot": 0.0, "rspeed": 4.0})
	if not _magic.is_empty():
		_magic["flat"] = true
	_build_beam()

func _ground_point() -> Vector3:
	return Vector3(_origin.x, ground(_origin) + 0.05, _origin.z)

## Tia sáng dựng đứng hình thoi (MODEL_SPEARSKILL SubType 16): quay quanh trục đứng, sáng dần rồi mờ
func _build_beam() -> void:
	var half_w := 0.11
	var h := 0.85
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := Vector3(0, h, 0)
	var mid := Vector3(0, h * 0.35, 0)
	var bottom := Vector3(0, 0.0, 0)
	var left := Vector3(-half_w, h * 0.35, 0)
	var right := Vector3(half_w, h * 0.35, 0)
	var bright := Color(1.0, 0.85, 0.45)
	var dim := Color(0.35, 0.22, 0.05)
	for tri in [[top, left, right, dim, bright, bright], [bottom, right, left, dim, bright, bright]]:
		for i in 3:
			st.set_color(tri[3 + i])
			st.add_vertex(tri[i])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = _ground_point() + Vector3(0, 0.15, 0)
	_beam = mi

func _mu_tick(t: int) -> void:
	var g := _ground_point()
	# Hạt tia lửa vàng ở +110
	particle("BITMAP_SPARK+1", g + Vector3(0, 1.1, 0), {"size": 0.5, "life": 5.0, "color": LIGHT, "fade": true,
		"vel": Vector3(0, 0.02, 0)})
	# Cứ 15 tick một vòng cursorpin01 thu nhỏ dần
	if t % 15 == 0:
		var r := particle("BITMAP_TARGET_POSITION_EFFECT1", g, {"size": RING_START, "life": 1000.0, "color": LIGHT, "fade": false, "rot": 0.0})
		if not r.is_empty():
			r["flat"] = true
			r["age"] = 0
			_rings.append(r)
	for r in _rings.duplicate():
		r["size"] = float(r["size"]) - RING_STEP
		if float(r["size"]) <= RING_MIN:
			r["life"] = 0.0
			_rings.erase(r)
	# cursorpin02 phập phồng 0.8..1.8
	if _star_scale >= 1.8:
		_star_dir = 0
	elif _star_scale <= 0.8:
		_star_dir = 1
	_star_scale += 0.15 if _star_dir == 1 else -0.15
	if not _star.is_empty():
		_star["size"] = _star_scale
	# 10 tick cuối: mờ dần
	var remain := LIFE - float(t)
	var k := clampf(remain / 10.0, 0.0, 1.0)
	for p in [_star, _magic]:
		if not p.is_empty():
			p["color"] = Color(LIGHT.r * k, LIGHT.g * k, LIGHT.b * k)
	for r in _rings.duplicate():
		r["color"] = Color(LIGHT.r * k, LIGHT.g * k, LIGHT.b * k)
		if remain <= 0.0:
			r["life"] = 0.0
			_rings.erase(r)
	if _beam and is_instance_valid(_beam):
		_beam.global_position = g + Vector3(0, 0.15, 0)
		var s := 0.8 + 0.2 * sin(float(t) * 0.6)
		_beam.scale = Vector3(s, 1.0, s)
		(_beam.material_override as StandardMaterial3D).albedo_color = Color(k, k, k, 1.0)
		if remain <= 0.0:
			_beam.queue_free()
			_beam = null

func _process(delta: float) -> void:
	super._process(delta)
	if _tick_no >= int(LIFE) and _beam and is_instance_valid(_beam):
		_beam.queue_free()
		_beam = null
