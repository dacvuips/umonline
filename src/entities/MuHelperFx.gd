extends Node3D
class_name MuHelperFx

## Hiển thị vật phẩm "Helper" (nhóm 13) đang mặc ngoài map:
##  - Thú đi theo / bay quanh chủ (Thiên Thần, Tiểu Quỷ, Demon, Spirit of Guardian, Rudolf, Panda, Unicorn, Skeleton, Quạ...):
##    CreateMountSub / MoveMount (GOBoid.cpp): bay lượn trong bán kính FlyRange 150 (MU) quanh chủ, cao hơn chủ 100..200 (MU).
##  - Thú cưỡi (Uniria, Dinorant, Chiến Mã, Sói Tinh): model nằm dưới chân, chủ ngồi lên (action PLAYER_STOP_RIDE / RUN_RIDE).
## Node này là con của MuPlayer: thú cưỡi đi theo node; thú đi theo dùng top_level để tự di chuyển.

const MuCatalogRes = preload("res://src/mu/MuCatalog.gd")
const MuModelRes = preload("res://src/mu/MuModel.gd")
const MuItemsRes = preload("res://src/mu/MuItems.gd")

## Thú cưỡi: model đang vẽ, tỉ lệ (OBJECT::Scale), độ nâng chủ (mét), action đứng / chạy của THÚ, action đứng / chạy của CHỦ
const MOUNTS := {
	2: {"glb": "res://assets/mu/Skill/Rider01.glb", "scale": 0.9, "bright": 1.3, "lift": -0.03, "m_idle": 0, "m_move": 2, "p_idle": 13, "p_move": 36},
	3: {"glb": "res://assets/mu/Skill/Rider02.glb", "scale": 0.9, "bright": 1.4, "lift": -0.05, "y_off": -0.3, "m_idle": 0, "m_move": 2, "p_idle": 13, "p_move": 36},   # Pegasus: Position[2] -= 30 (MU)
	4: {"glb": "res://assets/mu/Skill/DarkHorse.glb", "scale": 1.0, "bright": 2.2, "lift": -0.25, "m_idle": 0, "v_idle": 0.3, "m_move": 1, "v_move": 0.34, "m_walk": 1, "v_walk": 0.2, "p_idle": 78, "p_move": 79},
	37: {"glb": "res://assets/mu/Skill/fenril_black.glb", "scale": 0.9, "bright": 2.0, "lift": -0.12, "m_idle": 0, "m_move": 2, "v_idle": 0.4, "v_move": 0.6, "m_walk": 1, "v_walk": 1.0, "p_idle": 122, "p_move": 110, "p_walk": 126},
}
## Sói Tinh theo cờ Excellent: 0 đỏ (mặc định), 1 Destroy = đen, 2 Protect = xanh, 4 Illusion = vàng
const FENRIR_GLB := {
	0: "res://assets/mu/Skill/fenril_red.glb", 1: "res://assets/mu/Skill/fenril_black.glb",
	2: "res://assets/mu/Skill/fenril_blue.glb", 4: "res://assets/mu/Skill/fenril_gold.glb",
}

## Lớp bóng loáng (RENDER_CHROME | RENDER_BRIGHT) vẽ chồng lên thân thú, đúng ZzzObject.cpp (RenderObject):
##  - Sói Tinh vàng: chrome lên mesh 0 ; các Sói Tinh khác: chrome lên mesh 1 (BodyLight 1,1,1)
##  - Chiến Mã: chrome lên mesh 12..15, BodyLight (1, 0.8, 0.3) vàng
static func _chrome_glow(n: int, it: Dictionary) -> Dictionary:
	if n == 37:
		var gold := fenrir_flags(it) == 4
		var cg := 1.8 if gold else 1.0   # vàng: lớp chrome bạc dày hơn cho giống ảnh thật
		return {"level": 7, "color": Color(cg, cg, cg), "shine": Color(1, 1, 1), "meshes": [0] if gold else [1]}
	if n == 4:
		return {"level": 7, "color": Color(1.0, 0.8, 0.3), "shine": Color(1, 1, 1), "meshes": [12, 13, 14, 15]}
	return {}

## Độ sáng theo loại Sói Tinh: bản đen tối nhất nên cần sáng hơn, bản vàng / đỏ / xanh vốn sáng
## Fenrir vàng: lệch màu thân sang vàng chanh (bản Source gốc vàng, không ngả cam)
const GOLD_CHROMA := Color(0.95, 1.12, 0.95)   # chỉ nhuộm vùng có màu của Fenrir vàng (vàng chanh như Source)
const FENRIR_BRIGHT := {0: 1.5, 1: 2.0, 2: 1.7, 4: 1.2}

static func fenrir_flags(it: Dictionary) -> int:
	return int(it.get("excellent_flags", 0)) if int(it.get("number", 0)) == 37 else 0

## Model thú trong thế giới khác model vật phẩm trong túi: Quạ Tinh = MODEL_DARK_SPIRIT (Skill/darkspirit)
const PET_GLB := {5: "res://assets/mu/Skill/darkspirit.glb"}

## Thú bay (Angel, Imp, Demon, Maria, Raven) và thú đi bộ (Rudolf, Panda, Unicorn, Skeleton)
const FLYING_PETS := [0, 1, 5, 64, 65]
## Hệ số nhân thêm vào độ sáng thú (1.0 = như nhân vật). Tăng nếu thú còn tối.
const MOUNT_BRIGHTNESS := 1.8
const FLY_RANGE := 1.5          # 150 MU
const PET_SIZE := 0.9           # kích thước cao/dài tối đa (mét) khi thú không có scale riêng

var player: Node3D = null
var item: Dictionary = {}
var is_mount := false
var mount_info: Dictionary = {}
var _inst: Node3D = null
var _ap: AnimationPlayer = null
var _dir := Vector3(0, 0, 1)    # hướng bay hiện tại (mặt phẳng XZ)
var _speed := 0.6
var _vy := 0.0
var _change := 0.0
var _flying := true
var _fit_scale := 1.0
var _cur_action := -1
## Chế độ xem trước (màn chọn nhân vật): không cần MuPlayer, thú cưỡi luôn hiện + đứng yên,
## thú đi theo lơ lửng cạnh chủ, không có hiệu ứng / không check safe zone
var preview := false

static func is_visual_helper(it: Dictionary) -> bool:
	if int(it.get("group", 0)) != 13 or int(it.get("number", 0)) == 5:
		return false   # Quạ Tinh do MuDarkRaven đảm nhận
	return MuItemsRes.is_mount(it) or MuItemsRes.is_pet(it)

## Thông tin thú cưỡi đang cưỡi ({} nếu không phải thú cưỡi): dùng cho MuPlayer (action cưỡi, độ nâng)
static func mount_of(it: Dictionary) -> Dictionary:
	if int(it.get("group", 0)) != 13:
		return {}
	return MOUNTS.get(int(it.get("number", 0)), {})

func setup(p: Node3D, it: Dictionary) -> void:
	player = p
	item = it
	var n := int(it.get("number", 0))
	is_mount = MOUNTS.has(n)
	mount_info = MOUNTS.get(n, {})
	var path: String = str(mount_info.get("glb", "")) if is_mount else MuCatalogRes.item_glb(13, n)
	if PET_GLB.has(n):
		path = PET_GLB[n]
	if n == 37:
		path = FENRIR_GLB.get(fenrir_flags(it), FENRIR_GLB[0])
	if path == "":
		return
	_inst = MuModelRes.instantiate(path)
	if _inst == null:
		return
	add_child(_inst)
	# Thú tối quá (texture đen + ánh sáng địa hình): nhân thêm độ sáng như quái / NPC (build_monster)
	var bright := float(mount_info.get("bright", MOUNT_BRIGHTNESS))
	if n == 37:
		bright = float(FENRIR_BRIGHT.get(fenrir_flags(it), bright))
	MuModelRes.brightness_scale = bright
	MuModelRes.apply_materials(_inst, Color(1, 1, 1), _chrome_glow(n, it))   # shader MU + lớp bóng loáng (chrome)
	MuModelRes.brightness_scale = 1.0
	_soften(_inst, Vector3(GOLD_CHROMA.r, GOLD_CHROMA.g, GOLD_CHROMA.b) if (n == 37 and fenrir_flags(it) == 4) else Vector3.ONE)
	if n == 5:
		_dark_spirit_meshes(_inst)
	_ap = MuModelRes.find_first(_inst, "AnimationPlayer") as AnimationPlayer
	if is_mount:
		_inst.scale = Vector3.ONE * float(mount_info.get("scale", 1.0))
		_inst.position.y = float(mount_info.get("y_off", 0.0))
		if preview:
			_play(int(mount_info.get("m_idle", 0)), float(mount_info.get("v_idle", 0.34)))
			return
		var in_safe: bool = player.has_method("is_in_safe_zone") and player.is_in_safe_zone()
		_inst.visible = not in_safe
		_add_fx(null)
		return
	# Thú đi theo: Thiên Thần / Tiểu Quỷ scale 0.7 (CreateMountSub), thú khác tự co theo kích thước
	_flying = n in FLYING_PETS
	if n == 0 or n == 1:
		_inst.scale = Vector3.ONE * 0.7
	else:
		var bb := _model_aabb(_inst)
		var longest := maxf(bb.size.x, maxf(bb.size.y, bb.size.z))
		if longest > 0.001:
			_inst.scale = Vector3.ONE * clampf(PET_SIZE / longest, 0.0005, 50.0)
	if preview:
		# lơ lửng cạnh chủ, không top_level (đi theo bục / model cha)
		position = Vector3(0.9, 1.5 if _flying else 0.0, 0.3)
		_play(0)
		return
	top_level = true
	_add_fx(self)
	global_position = _owner_pos() + Vector3(randf_range(-1.0, 1.0), 1.4, randf_range(-1.0, 1.0))
	_new_heading(false)

## Giảm tương phản / chống cháy: ánh sáng phẳng hơn (ít chênh sáng - tối theo hướng bề mặt), nâng vùng tối,
## nén vùng sáng sớm hơn để màu không bị cháy trắng
func _soften(root: Node, chroma: Vector3 = Vector3.ONE) -> void:
	for mi in MuModelRes.find_all(root, "MeshInstance3D", []):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for sidx in m.mesh.get_surface_count():
			var mat := m.get_surface_override_material(sidx) as ShaderMaterial
			while mat != null:
				mat.set_shader_parameter("diffuse_scale", SOFT_DIFFUSE)
				mat.set_shader_parameter("ambient", SOFT_AMBIENT)
				mat.set_shader_parameter("diffuse_floor", SOFT_FLOOR)
				mat.set_shader_parameter("knee", SOFT_KNEE)
				if chroma != Vector3.ONE:
					mat.set_shader_parameter("chroma_tint", chroma)
				mat = mat.next_pass as ShaderMaterial

const SOFT_DIFFUSE := 0.45
const SOFT_AMBIENT := 1.0
const SOFT_FLOOR := 0.85
const SOFT_KNEE := 0.65

## MODEL_DARK_SPIRIT (ZzzObject.cpp): luôn vẽ mesh 3 ; cấp thú < 20 vẽ thêm mesh 2 (>= 20: mesh 1, >= 40: mesh 0 + chrome xanh)
func _dark_spirit_meshes(root: Node, pet_level: int = 0) -> void:
	var show := [3, 2] if pet_level < 20 else ([3, 1] if pet_level < 40 else [3, 0])
	for mi in MuModelRes.find_all(root, "MeshInstance3D", []):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for sidx in m.mesh.get_surface_count():
			if not (sidx in show):
				m.set_surface_override_material(sidx, MuModelRes._hidden())

func _add_fx(follower_node: Node3D) -> void:
	var fx := MuMountFx.new()
	fx.name = "MountFx"
	add_child(fx)
	fx.setup_mount(player, int(item.get("number", 0)), fenrir_flags(item), follower_node, _inst)

func _owner_pos() -> Vector3:
	return player.global_position if is_instance_valid(player) else global_position

static func _model_aabb(root: Node) -> AABB:
	var out := AABB()
	var first := true
	for mi in MuModelRes.find_all(root, "MeshInstance3D", []):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var bb := m.mesh.get_aabb()
		out = bb if first else out.merge(bb)
		first = false
	return out

func _play(action: int, speed: float = -1.0, loop: bool = true) -> void:
	if _ap == null:
		return
	if action == _cur_action:
		# cùng action nhưng đổi tốc độ (đi bộ <-> chạy của ngựa / chim)
		if speed >= 0.0 and absf(_ap.speed_scale - speed / MuModelRes.BASE_PLAY_SPEED) > 0.01:
			_ap.speed_scale = speed / MuModelRes.BASE_PLAY_SPEED
		return
	# MoveMount: o->Velocity = 0.34 cho thú cưỡi (Sói Tinh: đứng 0.4, chạy 0.6); thú đi theo 0.5
	if speed < 0.0:
		speed = 0.34 if is_mount else 0.5
	if MuModelRes.play(_ap, action, speed, loop):
		_cur_action = action

## Đổi hướng / tốc độ bay ngẫu nhiên (GOBoid.cpp: mỗi 32 lượt: xa chủ thì bay nhanh về phía chủ, gần thì dạo chậm)
func _new_heading(far: bool) -> void:
	if far:
		_speed = randf_range(3.2, 4.8)
	else:
		_speed = randf_range(0.4, 1.6)
		var a := randf() * TAU
		_dir = Vector3(sin(a), 0, cos(a))
	_vy = randf_range(-0.3, 0.3)

func _process(delta: float) -> void:
	if preview:
		if _flying and not is_mount:
			position.y = 1.5 + sin(Time.get_ticks_msec() * 0.002) * 0.12
		return
	if not is_instance_valid(player):
		queue_free()
		return
	if is_mount:
		# GOBoid.cpp (MoveMount lines 197, 341, 514): Trong SafeZone (thành), thú cưỡi bị ẩn hoàn toàn (Alpha = 0.f)
		var in_safe: bool = player.has_method("is_in_safe_zone") and player.is_in_safe_zone()
		if _inst != null and _inst.visible == in_safe:
			_inst.visible = not in_safe
		if in_safe:
			return
		# đang đánh / dùng skill: thú đổi action theo action của chủ (GOBoid.cpp MoveMount)
		var pact := int(player.model._current) if player.get("model") != null else -1
		var atk := _mount_attack_action(pact)
		if atk.size() > 0:
			_cur_action = -2   # ép phát lại action chạy / đứng sau khi đánh xong
			if _ap != null and _ap.current_animation != "a%03d" % int(atk[0]):
				MuModelRes.play(_ap, int(atk[0]), float(atk[1]), false, true)
			return
		var moving: bool = bool(player.get("is_moving"))
		if moving and not bool(player.call("ride_running")):
			# đi bộ (Sói Tinh: FENRIR_WALK, Velocity 1.0 ; ngựa / chim trong thành: chạy chậm lại)
			_play(int(mount_info.get("m_walk", mount_info.get("m_move", 2))), float(mount_info.get("v_walk", 0.2)))
		elif moving:
			_play(int(mount_info.get("m_move", 2)), float(mount_info.get("v_move", 0.34)))
		else:
			_play(int(mount_info.get("m_idle", 0)), float(mount_info.get("v_idle", 0.34)))
		return
	_update_pet(delta)

## Action của THÚ khi chủ đang đánh (action người: 54..59 cưỡi, 82..87 ngựa, 90..101 / 102..105 Sói Tinh, 68..69 skill)
func _mount_attack_action(pact: int) -> Array:
	var n := int(item.get("number", 0))
	match n:
		2, 3:
			if (pact >= 54 and pact <= 59) or pact == 68 or pact == 69:
				return [4 if n == 3 else 3, 0.34]
		4:
			if pact == 87:
				return [3, 0.34]
			if pact >= 82 and pact <= 86:
				return [2, 0.34]
		37:
			if pact >= 90 and pact <= 101:
				return [3, 0.4]
			if pact >= 102 and pact <= 105:
				return [4, 0.4]
	return []

func _update_pet(delta: float) -> void:
	var target := _owner_pos()
	var to_owner := target - global_position
	var flat := Vector3(to_owner.x, 0, to_owner.z)
	var dist := flat.length()
	var far := dist >= FLY_RANGE
	_change -= delta
	if _change <= 0.0:
		_change = randf_range(0.5, 1.3)
		_new_heading(far)
	if far and dist > 0.001:
		# quay dần về phía chủ (TurnAngle2 20°/lượt)
		var want := flat / dist
		var ang := _dir.signed_angle_to(want, Vector3.UP)
		var step := 6.0 * delta
		_dir = _dir.rotated(Vector3.UP, clampf(ang, -step, step)).normalized()
	var pos := global_position + _dir * _speed * delta
	if _flying:
		# cao hơn chủ 1..2 m
		var h := pos.y - target.y
		_vy += (1.5 if h < 1.0 else (-1.5 if h > 2.0 else 0.0)) * delta
		_vy = clampf(_vy, -1.0, 1.0)
		pos.y += _vy * delta
	else:
		pos.y = MuTerrain.height_at(pos.x, pos.z * -1.0)
	# không bay quá xa chủ (chủ chạy nhanh / dịch chuyển)
	if dist > 8.0:
		pos = target + Vector3(randf_range(-1, 1), 1.5, randf_range(-1, 1))
	global_position = pos
	if _dir.length_squared() > 0.0001:
		rotation.y = lerp_angle(rotation.y, atan2(_dir.x, _dir.z), clampf(delta * 8.0, 0.0, 1.0))
	_play(0)
