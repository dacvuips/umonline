extends MuFx
class_name MuMountFx

## Hiệu ứng đi kèm thú cưỡi / thú đi theo, PORT từ client gốc:
##  - GOBoid.cpp MoveMount / UpdateDrawnMountEffects:
##      Uniria / Dinorant / Chiến Mã khi chạy: khói BITMAP_SMOKE quanh chân (1 tick / 2).
##      Thiên Thần (MODEL_HELPER): mỗi tick 4 đốm BITMAP_SPARK quanh thân + 1 sprite BITMAP_LIGHT xanh lục.
##  - ZzzObject.cpp (UpdateRenderObjectEffects, case MODEL_FENRIR_*):
##      Sói Tinh: 2 sprite đỏ ở mắt (xương 11, lệch (50, 2, ±11)), 2 sprite ở xương 13 (40, 15, 0),
##      2 tia sét lightning_type01 (MODEL_FENRIR_THUNDER SubType 0) mỗi tick bám quanh thân,
##      và vết sét dưới chân (MODEL_FENRIR_FOOT_THUNDER) mỗi bước chân khi đi / chạy.
## Sống đến khi thú / chủ bị gỡ.

var player: Node3D = null
var number := 0
var fenrir_flags := 0
var follower: Node3D = null    # thú đi theo (Thiên Thần...) ; null với thú cưỡi
var mount_inst: Node3D = null  # model thú cưỡi (để lấy xương)
var _skel: Skeleton3D = null
var _foot_timer := 0
var _foot_pair := 0

## màu sét theo loại (ZzzObject.cpp): đỏ (0.8,0,0) / xanh dương (0.1,0.1,0.8) / vàng (0.8,0.8,0.1) / đen (1,1,0.2)
## Theo yêu cầu: sét luôn trắng cho mọi loại Sói Tinh (Source gốc: đỏ / xanh / vàng / đen)
const THUNDER_YELLOW := Color(1.0, 1.0, 1.0)
const THUNDER_COLOR := {0: THUNDER_YELLOW, 2: THUNDER_YELLOW, 4: THUNDER_YELLOW, 1: THUNDER_YELLOW}
## SubType của vết sét dưới chân: đỏ 1, xanh 2, đen 3, vàng 4 (kênh màu bị trừ dần theo SubType trong Move_MODEL_FENRIR_FOOT_THUNDER)
const FOOT_SUB := {0: 0, 2: 0, 1: 0, 4: 0}   # vết sét dưới chân cũng trắng (không mất kênh màu)
const FOOT_FADE := {1: [1, 2], 2: [0, 1], 3: [0, 2], 4: [2]}   # kênh RGB bị trừ 0.05 / tick

func setup_mount(p: Node3D, num: int, flags: int, p_follower: Node3D = null, p_inst: Node3D = null) -> void:
	player = p
	number = num
	fenrir_flags = flags
	follower = p_follower
	mount_inst = p_inst
	if mount_inst != null:
		_skel = MuModelRes.find_first(mount_inst, "Skeleton3D") as Skeleton3D
	_min_ticks = 1 << 30

## Vị trí thế giới của xương MU `bone`, lệch `off` (đơn vị MU, trục MU)
func _bone(bone: int, off: Vector3 = Vector3.ZERO) -> Vector3:
	if _skel == null or bone >= _skel.get_bone_count():
		return player.global_position + Vector3(0, 0.8, 0)
	var xf := _skel.global_transform * _skel.get_bone_global_pose(bone)
	return xf * mu(off)

func _mu_tick(_t_no: int) -> void:
	if not is_instance_valid(player) or (follower != null and not is_instance_valid(follower)):
		_min_ticks = 0
		return
	if follower != null:
		_follower_tick()
		return
	# Trong SafeZone: ẩn hoàn toàn hiệu ứng của thú cưỡi (khói chân, tia sét Fenrir)
	if player.has_method("is_in_safe_zone") and player.is_in_safe_zone():
		return
	var base := player.global_position
	var moving: bool = bool(player.get("is_moving"))
	if moving and randi() % 2 == 0:
		var p := base + Vector3(randf_range(-0.32, 0.32), randf_range(-0.16, 0.16) + 0.1, randf_range(-0.32, 0.32))
		particle("BITMAP_SMOKE", p, {"size": 0.7, "grow": 1.03, "life": 20, "color": Color(0.8, 0.75, 0.65),
			"vel": Vector3(0, 0.02, 0)})
	if number == 37:
		_fenrir_tick(base, moving)

func _follower_tick() -> void:
	var fp := follower.global_position
	if number == 0:
		# MODEL_HELPER: Luminosity 0.7..1.0, sprite BITMAP_LIGHT (0.5L, 0.8L, 0.6L)
		var l := randf_range(0.7, 1.0)
		sprite("BITMAP_LIGHT", fp + Vector3(0, 0.3, 0), 1.0, Color(l * 0.5, l * 0.8, l * 0.6))
		for i in 4:
			var o := Vector3(randf_range(-0.08, 0.08), randf_range(-0.08, 0.08), randf_range(-0.08, 0.08))
			particle("BITMAP_SPARK", fp + o + Vector3(0, 0.3, 0),
				{"size": 0.12, "life": 10, "color": Color(0.4, 0.4, 0.4), "vel": Vector3.ZERO})

func _fenrir_tick(base: Vector3, moving: bool) -> void:
	var lum := sin(Time.get_ticks_msec() * 0.002) * 0.2
	# mắt: 2 đốm đỏ cam ở xương 11
	var eye_c := Color(0.9 + lum, 0.2 + lum * 0.5, 0.1 + lum * 0.5)
	var eye_s := 0.5 + lum * 0.1
	sprite("BITMAP_LIGHT", _bone(11, Vector3(50, 2, 11)), eye_s, eye_c)
	sprite("BITMAP_LIGHT", _bone(11, Vector3(50, 2, -11)), eye_s, eye_c)
	sprite("BITMAP_LIGHT", _bone(11, Vector3(50, 2, 11)), eye_s, eye_c)
	sprite("BITMAP_LIGHT", _bone(11, Vector3(50, 2, -11)), eye_s, eye_c)
	# xương 13: 2 sprite sáng đỏ nhạt
	var c13 := Color(1.0, 0.3, 0.2)
	sprite("BITMAP_LIGHT", _bone(13, Vector3(40, 15, 0)), 1.5, c13)
	sprite("BITMAP_LIGHT", _bone(13, Vector3(40, 15, 0)), 1.0, c13)
	# 2 tia sét quanh thân
	var col: Color = THUNDER_COLOR.get(fenrir_flags, THUNDER_COLOR[0])
	for i in 2:
		_spawn_thunder(base, col)
	# vết sét dưới chân khi đi / chạy (xương chân 22, 28 / 36, 44 lần lượt)
	if moving:
		_foot_timer -= 1
		if _foot_timer <= 0:
			_foot_timer = 5
			var feet := [22, 28] if _foot_pair == 0 else [36, 44]
			_foot_pair = 1 - _foot_pair
			for b in feet:
				_foot_decal(_bone(b))
	else:
		_foot_timer = 0

## Move/Create MODEL_FENRIR_THUNDER SubType 0 : vị trí chọn ngẫu nhiên trên các xương thân
func _spawn_thunder(base: Vector3, col: Color) -> void:
	var sc := 0.3 + float(randi() % 100) * 0.002
	var r := randi() % 30
	var pos := base
	if r >= 1 and r <= 2:
		pos = _bone(10)
	elif r == 3:
		sc -= 0.2
		pos = _bone(14)
	elif r >= 4 and r <= 5:
		pos = _bone(2)
	elif r >= 6 and r <= 7:
		sc -= 0.2
		pos = _bone(50 if randi() % 2 == 0 else 51)
	elif r == 8:
		sc -= 0.2
		pos = _bone(53)
	elif r >= 9 and r <= 10:
		return   # Live = false ngay
	else:
		sc += 0.1
		pos = base + mu(Vector3(randi() % 240 - 120, randi() % 10 - 5, 110))
	var l := Color(maxf(col.r - 0.1, 0.0), maxf(col.g - 0.1, 0.0), maxf(col.b - 0.1, 0.0))
	sprite("BITMAP_LIGHT", pos, 2.0, l)
	var o := model("Effect/lightning_type01", pos, {"ang": Vector3(randf() * 360, randf() * 360, randf() * 360),
		"scale": maxf(sc, 0.05), "life": 5, "blend_mesh": -2, "color": col, "light": 1.6})
	# Alpha: 0.7 -> 1.0 (+0.3 / tick) rồi giảm 0.3 / tick tới 0
	o["update"] = func(ob, _dt):
		var a := float(ob["age"])
		ob["light"] = 1.6 * clampf(0.7 + 0.3 * a if a < 1.0 else 1.0 - 0.3 * (a - 1.0), 0.0, 1.0)

## MODEL_FENRIR_FOOT_THUNDER: vết sét nằm trên đất, đổi 1 / 5 khung texture eff_lightinga01..05 mỗi 200 ms,
## tối dần (Alpha -0.05 / tick) và mất màu theo loại
func _foot_decal(pos: Vector3) -> void:
	var sub: int = FOOT_SUB.get(fenrir_flags, 1)
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	mi.mesh = q
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	add_child(mi)
	var gy := MuTerrain.height_at(pos.x, -pos.z) + 0.03
	mi.global_position = Vector3(pos.x, gy, pos.z)
	mi.rotation = Vector3(-PI * 0.5, randf() * TAU, 0.0)
	var o := {"mi": mi, "mat": m, "t": 0.0, "sub": sub}
	_decals.append(o)
	_decal_apply(o)

var _decals: Array = []

func _decal_apply(o: Dictionary) -> void:
	var t: float = o["t"]   # tick
	var frame := int(t * (1000.0 / 25.0) / 200.0) % 5
	var tx := tex("eff_lightinga0%d" % (frame + 1))
	var m: StandardMaterial3D = o["mat"]
	m.albedo_texture = tx
	var c := [1.0, 1.0, 1.0]
	for ch in FOOT_FADE.get(int(o["sub"]), []):
		c[ch] = maxf(0.0, 1.0 - 0.05 * t)
	var a := maxf(0.0, 1.0 - 0.05 * t)
	m.albedo_color = Color(c[0] * a, c[1] * a, c[2] * a, 1.0)

func _process(delta: float) -> void:
	super._process(delta)
	for o in _decals.duplicate():
		o["t"] += delta / TICK
		if float(o["t"]) >= 20.0:
			(o["mi"] as MeshInstance3D).queue_free()
			_decals.erase(o)
		else:
			_decal_apply(o)
