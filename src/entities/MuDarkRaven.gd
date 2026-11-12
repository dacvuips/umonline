extends Node3D
class_name MuDarkRaven

## Quạ Tinh Chúa Tể (Dark Raven, 13:5) của Dark Lord — port CSPetDarkSpirit (GameLogic/Pets/CSPetSystem.cpp)
## + phần "server" của OpenMU (GameLogic/Pet/RavenCommandManager.cs, ClassDarkLord.cs):
##   * model MODEL_DARK_SPIRIT (Skill/DarkSpirit), Scale 0.7, tốc độ animation 0.4 ; action 0 bay, 1 bay nhanh, 2 đậu, 3 lao mổ
##   * thân theo cấp quạ (ZzzObject.cpp): luôn mesh 3 ; < 20: mesh 2 ; >= 20: mesh 1 ; >= 40: mesh 0 + lớp chrome xanh (0.3,0.6,1)
##   * AI: PET_FLY / PET_FLYING (lượn quanh chủ trong FlyRange 150, cao hơn chủ 250 — 350 khi cưỡi Chiến Mã),
##         PET_STAND (trong thành: đậu trên vai — xương 37), PET_STAND_START (bay về tay — xương 42 rồi đậu),
##         PET_ATTACK (lao mổ: Velocity 20..29 tăng dần, MoveHumming về mục tiêu) -> PET_ESCAPE (bay vụt lên rồi về),
##         PET_ATTACK_MAGIC (quay về mục tiêu, tụ sáng 15 khung rồi bắn tia sáng)
##   * 4 lệnh (PetCommandMode): 0 Hành động cơ bản, 1 Tấn công ngẫu nhiên (quái trong 7 ô), 2 Tấn công cùng chủ,
##     3 Tấn công mục tiêu (tới khi chết rồi về lệnh cơ bản). Không đánh trong khu vực an toàn.
##   * Mỗi đòn: 70% đánh đơn (lao mổ), 30% đánh lan (phép: 3 đòn lên mục tiêu + tối đa 2 quái trong 3 ô).
##   * Sát thương: min 180 + Thống soái/8 + 15*cấp ; max 200 + Thống soái/4 + 15*cấp ;
##     tốc đánh 20 + Thống soái/50 + 0.8*cấp ; nhịp đánh = max(100, 1500 - tốc đánh*10) ms.

const MuModelRes = preload("res://src/mu/MuModel.gd")
const MuFxRes = preload("res://src/effects/MuFx.gd")

enum { PET_FLYING, PET_FLY, PET_ESCAPE, PET_STAND, PET_STAND_START, PET_ATTACK, PET_ATTACK_MAGIC }
enum { CMD_DEFAULT, CMD_RANDOM, CMD_OWNER, CMD_TARGET }

const GLB := "res://assets/mu/Skill/darkspirit.glb"
const SCALE := 0.7
const FLY_RANGE := 150.0
const ATTACK_RANGE_TILES := 7.0
const TURN_MIN := 5.0
const TURN_MAX := 19.0
const COURSE_CHANGE := 59.0
const MAGIC_TURN := 40.0
const RECOVERY_HEIGHT := 250.0

var player: Node3D = null
var pet_level := 1
var command := CMD_DEFAULT
var command_target: Node3D = null

var _inst: Node3D = null
var _ap: AnimationPlayer = null
var _skel: Skeleton3D = null
var _fx = null

# trạng thái MU (đơn vị MU, độ)
var ai := PET_FLYING
var ang := Vector3.ZERO
var dir_mu := Vector3.ZERO
var velocity := 1.0
var gravity := 13.0
var life_time := 0.0
var attack_time := 0.0
var action_start := false
var _vis_target: Node3D = null      # mục tiêu đang lao tới (hiệu ứng)
var _magic_target: Node3D = null
var _magic_fired := false
var _skill_fx_done := false
var _cur_action := -1
var _tick_acc := 0.0
var _tick_now := false
var _streaks: Array = []     # CreateJoint(BITMAP_LIGHT, SubType 1)
var _spirits: Array = []     # CreateJoint(BITMAP_JOINT_SPIRIT, SubType 13)
var _attack_fx_time := -1.0  # LastAttackEffectTime (CheckAttackTime)

# "server": nhịp đánh + đòn lan đang chờ
var _atk_timer := 0.5
var _random_target: Node3D = null
var _pending_hits: Array = []        # [thời điểm còn lại (s), mục tiêu]

func setup(p: Node3D, level: int) -> void:
	player = p
	pet_level = clampi(level, 1, 50)

func _ready() -> void:
	top_level = true
	_inst = MuModelRes.instantiate(GLB)
	if _inst == null:
		return
	add_child(_inst)
	MuModelRes.brightness_scale = 1.8
	var glow := {"level": 7, "color": Color(0.3, 0.6, 1.0), "shine": Color(1, 1, 1), "meshes": [0]} if pet_level >= 40 else {}
	MuModelRes.apply_materials(_inst, Color(1, 1, 1), glow)
	MuModelRes.brightness_scale = 1.0
	_show_meshes()
	_add_shadow()
	_ap = MuModelRes.find_first(_inst, "AnimationPlayer") as AnimationPlayer
	_skel = MuModelRes.find_first(_inst, "Skeleton3D") as Skeleton3D
	_inst.scale = Vector3.ONE * SCALE
	# CSPetDarkSpirit(): sinh tại chỗ chủ, cao hơn 300
	global_position = _owner_pos() + MuFxRes.mu(Vector3(0, 0, 300))
	_fx = MuFxRes.new()
	_fx.name = "RavenFx"
	_fx.set("_min_ticks", 1 << 30)   # hiệu ứng sống cùng quạ
	player.get_parent().add_child.call_deferred(_fx)

func _exit_tree() -> void:
	if _fx and is_instance_valid(_fx):
		_fx.queue_free()

## MODEL_DARK_SPIRIT trong RenderObject: luôn mesh 3 ; cấp < 20 mesh 2 ; >= 20 mesh 1 ; >= 40 mesh 0
func _show_meshes() -> void:
	var show := [3, 2] if pet_level < 20 else ([3, 1] if pet_level < 40 else [3, 0])
	for mi in MuModelRes.find_all(_inst, "MeshInstance3D", []):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for s in m.mesh.get_surface_count():
			if not (s in show):
				m.set_surface_override_material(s, MuModelRes._hidden())

## Bóng thân (RenderBodyShadow): chiếu xuống mặt đất ngay dưới quạ (BodyOrigin.z = độ cao địa hình)
const _BODY_SHADOW_SHADER = preload("res://src/shaders/mu_body_shadow.gdshader")
const _HIDDEN_SHADER = preload("res://src/shaders/mu_hidden.gdshader")
var _shadow_meshes: Array = []
var _shadow_mat: ShaderMaterial = null

func _add_shadow() -> void:
	var sm := ShaderMaterial.new()
	sm.shader = _BODY_SHADOW_SHADER
	_shadow_mat = sm
	for n in MuModelRes.find_all(_inst, "MeshInstance3D", []):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var added := false
		for si in mi.mesh.get_surface_count():
			var head := mi.get_surface_override_material(si) as ShaderMaterial
			if head == null or head.shader == _HIDDEN_SHADER:
				continue
			head = head.duplicate() as ShaderMaterial
			var last := head
			while last.next_pass != null:
				last.next_pass = last.next_pass.duplicate()
				last = last.next_pass as ShaderMaterial
			last.next_pass = sm
			mi.set_surface_override_material(si, head)
			added = true
		if added:
			_shadow_meshes.append(mi)

func _update_shadow() -> void:
	var o := Vector3(global_position.x, MuWorld.ground_height(global_position), global_position.z)
	if _shadow_mat != null:
		_shadow_mat.set_shader_parameter("shadow_origin", o)

# ------------------------------------------------------------------ tiện ích toạ độ
static func to_mu(g: Vector3) -> Vector3:
	return Vector3(g.x, -g.z, g.y) * 100.0

func _owner_pos() -> Vector3:
	return player.global_position if is_instance_valid(player) else global_position

func _owner_bone(b: int, p_mu: Vector3) -> Vector3:
	var m = player.get("model")
	var sk: Skeleton3D = m.skeleton if m != null else null
	if sk == null:
		return _owner_pos() + Vector3(0, 1.5, 0)
	var bi := sk.find_bone("b%03d" % b)
	if bi < 0:
		return _owner_pos() + Vector3(0, 1.5, 0)
	return (sk.global_transform * sk.get_bone_global_pose(bi)) * MuFxRes.mu(p_mu)

func _owner_yaw() -> float:
	return rad_to_deg(player.rotation.y)

func _owner_safe() -> bool:
	return player.has_method("is_in_safe_zone") and player.is_in_safe_zone()

static func _turn(a: float, b: float, d: float) -> float:
	return a + clampf(wrapf(b - a, -180.0, 180.0), -d, d)

static func _yaw_to(a: Vector3, b: Vector3) -> float:
	return rad_to_deg(atan2(b.x - a.x, b.z - a.z))

## MoveHumming dùng chung (vị trí Godot, góc MU) -> [góc mới, khoảng cách MU]
static func humming(pos: Vector3, a: Vector3, target: Vector3, turn: float) -> Array:
	a.z = _turn(a.z, _yaw_to(pos, target), turn)
	var r := to_mu(pos) - to_mu(target)
	var horiz := sqrt(r.x * r.x + r.y * r.y)
	var want := 360.0 - wrapf(rad_to_deg(atan2(to_mu(target).z - to_mu(pos).z, horiz)), 0.0, 360.0)
	a.x = _turn(a.x, want, turn)
	return [a, r.length()]

## MoveHumming: quay yaw + pitch về mục tiêu (bước Turn độ), trả về khoảng cách (MU)
func _move_humming(target: Vector3, turn: float) -> float:
	ang.z = _turn(ang.z, _yaw_to(global_position, target), turn)
	var r := to_mu(global_position) - to_mu(target)
	var horiz := sqrt(r.x * r.x + r.y * r.y)
	# CreateAngle(z, dist, tz, 0) = atan2(tz - z, dist) ; pitch = 360 - góc đó
	var dz := to_mu(target).z - to_mu(global_position).z
	var want := 360.0 - wrapf(rad_to_deg(atan2(dz, horiz)), 0.0, 360.0)
	ang.x = _turn(ang.x, want, turn)
	return r.length()

func _rand_check(n: float, f: float) -> bool:
	return randf() < f / maxf(1.0, n)

## PlayAnimation(playSpeed 0.4): action mới chỉ thay khi vòng animation hiện tại chạy hết (Play == false) ;
## đòn mổ / bay thoát (SetAction(o, 3) mỗi khung) đổi ngay
func _play(action: int, immediate: bool = false) -> void:
	if _ap == null or action == _cur_action:
		return
	if not immediate and _cur_action >= 0 and _ap.is_playing():
		var alen := _ap.current_animation_length
		if alen > 0.0 and _ap.current_animation_position < alen - 0.05:
			return
	if MuModelRes.play(_ap, action, 0.4, true):
		_cur_action = action

func set_ai(a: int) -> void:
	ai = a
	life_time = 0.0

# ------------------------------------------------------------------ khung hình (MovePet)
func _process(delta: float) -> void:
	if not is_instance_valid(player):
		queue_free()
		return
	if _inst == null:
		return
	var f := clampf(25.0 * delta, 0.0, 1.0)   # FPS_ANIMATION_FACTOR
	_tick_acc += f
	_tick_now = _tick_acc >= 1.0                # một khung tham chiếu 25 fps (rand_fps_check(1))
	if _tick_now:
		_tick_acc -= 1.0
	_server_tick(delta)
	_move_pet(f)
	_attack_effect(f)
	if _fx_ok():
		_update_streaks(f)
		_update_spirits(f)
	_inst.global_transform = Transform3D(MuFxRes.basis(ang).scaled(Vector3.ONE * SCALE), global_position)
	_update_shadow()

func _move_pet(f: float) -> void:
	var opos := _owner_pos()
	# trong thành: về đậu trên vai
	if _owner_safe():
		if ai != PET_STAND and ai != PET_STAND_START:
			var d := Vector2(global_position.x - opos.x, global_position.z - opos.z).length() * 100.0
			var prev := ai
			set_ai(PET_STAND)
			if d > 50.0 or (prev != PET_STAND_START and prev >= PET_FLYING and prev <= PET_STAND):
				set_ai(PET_STAND_START)
				velocity = 3.0
	elif ai == PET_STAND or ai == PET_STAND_START:
		set_ai(PET_FLYING)

	match ai:
		PET_FLY: _play(0)
		PET_FLYING, PET_STAND_START: _play(1)
		PET_STAND: _play(2)
		PET_ATTACK, PET_ESCAPE: _play(3, true)
		_: _play(0)

	var target_pos := opos
	if action_start and is_instance_valid(_vis_target):
		target_pos = _vis_target.global_position
	var rng := to_mu(target_pos) - to_mu(global_position)

	if ai == PET_FLY or ai == PET_FLYING:
		action_start = false
		# CreateParticleFpsChecked(BITMAP_SPARK+1, xương ngẫu nhiên, Angle, (0.3, 0.4, 0.7), 5, 0.8)
		if _tick_now:
			_spark(_random_bone_pos())
		var dist2 := rng.x * rng.x + rng.y * rng.y
		if dist2 >= FLY_RANGE * FLY_RANGE:
			ang.z = _turn(ang.z, _yaw_to(global_position, target_pos), randf_range(TURN_MIN, TURN_MAX) * f)
		global_position += MuFxRes.rot(dir_mu, ang) * f
		var speed_random := 28.0
		var char_h := 250.0
		var helper = player.get("equipment").get("helper") if player.get("equipment") is Dictionary else null
		if helper is Dictionary and int(helper.get("number", -1)) == 4:
			char_h = 350.0
		var h := to_mu(target_pos).z + char_h
		var z := to_mu(global_position).z
		if z < h:
			speed_random = 10.0
			ang.x = maxf(-15.0, ang.x - 2.0 * f)
		elif z > h + 100.0:
			speed_random = 20.0
			ang.x = minf(15.0, ang.x + 2.0 * f)
		if _rand_check(speed_random, f):
			var speed := 0.0
			if dist2 >= FLY_RANGE * FLY_RANGE:
				speed = -(randf_range(0.0, 63.0) + 128.0) * 0.1
			else:
				speed = -(randf_range(0.0, 7.0) + 32.0) * 0.1
				ang.z += randf_range(0.0, COURSE_CHANGE)
			speed = (speed + dir_mu.y) / 2.0
			dir_mu = Vector3(0.0, speed, randf_range(-32.0, 31.0) * 0.1)
		if dir_mu.y < -12.0:
			if ai != PET_FLYING:
				set_ai(PET_FLYING)
		elif ai != PET_FLY:
			set_ai(PET_FLY)
	elif ai == PET_ATTACK or ai == PET_ESCAPE:
		global_position += MuFxRes.rot(Vector3(0, -velocity, 0), ang) * f
		if ai == PET_ATTACK:
			var tp := target_pos + MuFxRes.mu(Vector3(0, 0, 50))
			var d2 := _move_humming(tp, velocity * f)
			if d2 < 20.0 or life_time > 20.0:
				set_ai(PET_ESCAPE)
				ang.x = -45.0
				if command != CMD_TARGET:
					action_start = false
			velocity += gravity * f
			gravity += 0.2 * f
			life_time += f
		else:
			var dist3 := rng.x * rng.x + rng.y * rng.y
			if dist3 >= (FLY_RANGE + 100.0) * (FLY_RANGE + 100.0):
				set_ai(PET_FLYING)
			velocity -= 1.0 * f
	elif ai == PET_ATTACK_MAGIC:
		if is_instance_valid(_magic_target):
			ang.z = _turn(ang.z, _yaw_to(global_position, _magic_target.global_position), MAGIC_TURN * f)
	elif ai == PET_STAND:
		global_position = _owner_bone(37, Vector3(-10, 0, 10))
		ang = Vector3(0, 0, _owner_yaw() - 120.0)
	elif ai == PET_STAND_START:
		if velocity != 0.0:
			global_position += MuFxRes.rot(Vector3(0, -velocity, 0), ang) * f
		var hand := _owner_bone(42, Vector3.ZERO)
		var d4 := _move_humming(hand, velocity * f)
		velocity += f
		if d4 < 50.0:
			set_ai(PET_STAND)
	if ai >= PET_ATTACK and ai <= PET_ATTACK_MAGIC:
		attack_time = minf(15.0, attack_time + f)
	# tiếng kêu thỉnh thoảng
	if _rand_check(100.0, f) and randi() % 60 == 0 and MuAudioManager:
		MuAudioManager.play_sound_file("DSpirit_Shout.wav", -4.0, 1.0, global_position)
	# lạc xa chủ (rơi thấp / quá 640 MU): đếm 90 khung rồi đưa về trên đầu chủ
	var r2 := to_mu(opos) - to_mu(global_position)
	if to_mu(global_position).z < to_mu(opos).z - 200.0 or r2.x * r2.x + r2.y * r2.y > 409600.0:
		life_time += f
	if life_time > 90.0:
		life_time = 0.0
		global_position = opos + MuFxRes.mu(Vector3(0, 0, RECOVERY_HEIGHT))

func _random_bone_pos() -> Vector3:
	if _skel and _skel.get_bone_count() > 0:
		var bi := randi() % _skel.get_bone_count()
		return _skel.global_transform * _skel.get_bone_global_pose(bi).origin
	return global_position

# ------------------------------------------------------------------ hiệu ứng (AttackEffect + hạt / joint port từ ZzzEffectParticle.cpp, ZzzEffectJoint.cpp)
func _fx_ok() -> bool:
	return _fx != null and is_instance_valid(_fx) and _fx.is_inside_tree()

## Cỡ sprite / hạt MU: Width = cỡ texture (px) * Scale đơn vị MU
func _tex_size(bitmap: String, scale: float) -> float:
	var t: Texture2D = MuFxRes.tex(bitmap)
	return (float(t.get_width()) if t else 32.0) * scale / 100.0

## BITMAP_SPARK+1 SubType 5: LifeTime 10, Velocity = AngleMatrix(0,0,yaw) * (-(2..3), 0, 0),
## Scale *= 0.9 / khung, Light /= 1.03 / khung ; Light (0.3, 0.4, 0.7), Scale 0.8
func _spark(pos: Vector3) -> void:
	if not _fx_ok():
		return
	var v: Vector3 = MuFxRes.rot(Vector3(-(randi() % 2 + 2.0), 0.0, 0.0), Vector3(0, 0, ang.z))
	_fx.particle("BITMAP_SPARK+1", pos, {"size": _tex_size("BITMAP_SPARK+1", 0.8), "life": 10, "vel": v,
		"grow": 0.9, "fade": false, "color": Color(0.3, 0.4, 0.7) * 0.86})

## BITMAP_LIGHT SubType 6: LifeTime 10..19, Scale = (0.5..1.0) * 1.3 ; mỗi khung bay lên 2.5, lắc ±0.2,
## Scale *= 0.95, Light *= 0.95 ; Light (1, 0.6, 0.4)
func _gather_light(pos: Vector3) -> void:
	if not _fx_ok():
		return
	var sc := (randi() % 50 + 50.0) / 100.0 * 1.3
	_fx.particle("BITMAP_LIGHT", pos, {"size": _tex_size("BITMAP_LIGHT", sc), "life": randi() % 10 + 10,
		"vel": MuFxRes.mu(Vector3(randf_range(-0.2, 0.2), randf_range(-0.2, 0.2), 2.5)), "grow": 0.95,
		"fade": true, "color": Color(1.0, 0.6, 0.4)})

## CreateJoint(BITMAP_LIGHT, pos, pos, Angle, SubType 1, NULL, 20..59): LifeTime 10, MaxTails 20,
## Angle (30, 0, ngẫu nhiên), Velocity 1..5 (+0.5 mỗi bước), mỗi khung kéo 5 đuôi khi Skill == 0 hoặc LifeTime > 3 ;
## Light (1, 0.8, 0.6) giảm /1.2 mỗi khung
func _streak(pos: Vector3) -> void:
	if not _fx_ok():
		return
	var r: Dictionary = _fx.ribbon("BITMAP_LIGHT", pos, {"width": randf_range(20.0, 59.0) / 100.0, "color": Color(1.0, 0.8, 0.6),
		"max_tails": 20, "life": 1000, "fade": false, "taper": false})
	_streaks.append({"r": r, "pos": pos, "ang": Vector3(30.0, 0.0, float(randi() % 360)), "vel": float(randi() % 5 + 1),
		"life": 10.0, "skill": randi() % 5, "light": 1.0})

func _update_streaks(f: float) -> void:
	for st in _streaks.duplicate():
		var r: Dictionary = st["r"]
		if int(st["skill"]) == 0 or float(st["life"]) > 3.0:
			for i in 5:
				r["head"] = st["pos"]
				_fx.ribbon_push(r)
				st["pos"] = (st["pos"] as Vector3) + MuFxRes.rot(Vector3(0, -float(st["vel"]) * f, 0), st["ang"])
				st["vel"] = float(st["vel"]) + 0.5 * f
			r["head"] = st["pos"]
		st["light"] = float(st["light"]) * pow(1.0 / 1.2, f)
		r["color"] = Color(1.0, 0.8, 0.6) * float(st["light"])
		st["life"] = float(st["life"]) - f
		if float(st["life"]) <= 0.0:
			r["life"] = 0.0
			_streaks.erase(st)

## SpawnMeshEffects(1, BITMAP_LIGHT, 1, Angle, target): mỗi tam giác thứ 22 của mesh 1, mỗi đỉnh của nó sinh
## CreateJoint(BITMAP_JOINT_SPIRIT, đỉnh, target, (-rand 90, 0, yaw ± 60), SubType 13, target, 20)
func _spawn_spirits(target: Node3D) -> void:
	if not _fx_ok() or not is_instance_valid(target):
		return
	for p in _mesh1_points():
		var a := Vector3(-float(randi() % 90), 0.0, ang.z + float(randi() % 120 - 60))
		var r: Dictionary = _fx.ribbon("BITMAP_JOINT_SPIRIT", p, {"width": 0.2, "color": Color(1.0, 0.6, 0.4),
			"max_tails": 10, "life": 1000, "fade": false, "taper": false})
		_spirits.append({"r": r, "pos": p, "ang": a, "vel": 40.0, "life": 20.0, "light": Color(1.0, 0.6, 0.4),
			"target": target, "aim": _spirit_aim(target)})

func _spirit_aim(target: Node3D) -> Vector3:
	return target.global_position + MuFxRes.mu(Vector3(randi() % 150 - 70.0, randi() % 150 - 70.0, 50.0))

## Joint BITMAP_JOINT_SPIRIT SubType 13 (MoveJoint): Position += R(Angle)*(0,-Velocity,0) ; lật góc ngẩng ±20
## nửa số khung ; MoveHumming tới mục tiêu (lệch ngẫu nhiên, +50) với bước (Velocity - 20), Velocity tăng tới 50 ;
## gần (< 50) thì LifeTime giảm thêm ; LifeTime < 10: Light /1.2 ; đầu vệt: sprite BITMAP_LIGHT (2*(Life/10)+2)
## và BITMAP_SHINY+1 (một nửa)
func _update_spirits(f: float) -> void:
	for sp in _spirits.duplicate():
		var r: Dictionary = sp["r"]
		var tgt: Node3D = sp["target"] if is_instance_valid(sp["target"]) else null
		var pos: Vector3 = sp["pos"]
		var a: Vector3 = sp["ang"]
		pos += MuFxRes.rot(Vector3(0, -float(sp["vel"]), 0), a) * f
		if tgt != null:
			if _tick_now and randi() % 2 == 0:
				a.x = a.x + 20.0 if a.x < -90.0 else a.x - 20.0
			if _tick_now:
				sp["aim"] = _spirit_aim(tgt)
			var res := humming(pos, a, sp["aim"], float(sp["vel"]) - 20.0)
			a = res[0]
			sp["vel"] = minf(50.0, float(sp["vel"]) + f)
			if float(res[1]) < 50.0:
				sp["life"] = float(sp["life"]) - f
		sp["life"] = float(sp["life"]) - f
		var light: Color = sp["light"]
		if float(sp["life"]) < 10.0:
			light = light * pow(1.0 / 1.2, f)
			sp["light"] = light
		sp["pos"] = pos
		sp["ang"] = a
		r["head"] = pos
		r["color"] = light
		if _tick_now:
			_fx.ribbon_push(r)
			var sc := 2.0 * float(int(float(sp["life"]) / 10.0)) + 2.0
			_fx.sprite("BITMAP_LIGHT", pos, sc, light, randf() * 360.0)
			_fx.sprite("BITMAP_SHINY+1", pos, sc / 2.0, light, randf() * 360.0)
		if float(sp["life"]) <= 0.0:
			r["life"] = 0.0
			_spirits.erase(sp)

## Đỉnh (đã skin) của các tam giác thứ 22 thuộc mesh 1 thân quạ
func _mesh1_points() -> Array:
	var out: Array = []
	for n in MuModelRes.find_all(_inst, "MeshInstance3D", []):
		var mi := n as MeshInstance3D
		var am := mi.mesh as ArrayMesh
		if am == null or am.get_surface_count() <= 1:
			continue
		var arr := am.surface_get_arrays(1)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx := PackedInt32Array()
		if arr[Mesh.ARRAY_INDEX] != null:
			idx = arr[Mesh.ARRAY_INDEX]
		var bones := PackedInt32Array()
		if arr[Mesh.ARRAY_BONES] != null:
			bones = arr[Mesh.ARRAY_BONES]
		var sk := mi.get_node_or_null(mi.skeleton) as Skeleton3D
		var skin := mi.skin
		var tri_count := (idx.size() if idx.size() > 0 else verts.size()) / 3
		for j in tri_count:
			if j % 22 != 0:
				continue
			for k in 3:
				var vi: int = idx[j * 3 + k] if idx.size() > 0 else j * 3 + k
				var v: Vector3 = verts[vi]
				var world := mi.global_transform * v
				if sk and skin and bones.size() > vi * 4:
					var bind: int = bones[vi * 4]
					if bind < skin.get_bind_count():
						var bi := skin.get_bind_bone(bind)
						if bi < 0:
							bi = sk.find_bone(skin.get_bind_name(bind))
						if bi >= 0:
							world = sk.global_transform * sk.get_bone_global_pose(bi) * skin.get_bind_pose(bind) * v
				out.append(world)
	return out

func _attack_effect(f: float) -> void:
	if not _fx_ok():
		return
	match ai:
		PET_ATTACK:
			if attack_time >= 0.0 and attack_time <= 2.0 and is_instance_valid(_vis_target):
				# CreateRavenAttackTrail: 10 joint BITMAP_LIGHT SubType 1 mỗi khung tham chiếu
				if _tick_now:
					for i in 10:
						_streak(global_position)
				# CheckAttackTime(1): MODEL_DARKLORD_SKILL SubType 3 một lần, Angle (45, rand 0..179 - 90, 0), Light (1, 0.8, 0.6)
				if attack_time >= 1.0 and _attack_fx_time < 0.0:
					_attack_fx_time = attack_time
					_fx.model("Skill/DarkLordSkill", global_position, {"ang": Vector3(45.0, randf_range(0.0, 179.0) - 90.0, 0.0),
						"scale": 0.2, "life": 10, "blend_mesh": -1, "color": Color(1.0, 0.8, 0.6), "anim_speed": 0.4})
			if attack_time > 3.0 and int(attack_time) % 2 == 1 and _tick_now:
				if to_mu(global_position).z > to_mu(_owner_pos()).z + 100.0:
					# MODEL_AIR_FORCE SubType 0 tại xương 6 (+50, 0, 0): LifeTime 15, Scale 0.6 (+0.2 / khung), BlendMeshLight /1.5
					var p := _bone_point(6, Vector3(50, 0, 0))
					var af: Dictionary = _fx.model("Skill/airforce", p, {"ang": ang, "scale": 0.6, "life": 15, "blend_mesh": -2})
					af["update"] = func(ob, dt):
						ob["scale"] = float(ob["scale"]) + 0.2 * dt
						ob["light"] = float(ob["light"]) * pow(1.0 / 1.5, dt)
		PET_ATTACK_MAGIC:
			if attack_time < 15.0:
				# BITMAP_LIGHT SubType 6 (1.3) trên các xương bắt đầu 0 hoặc 1, bước 2
				if _tick_now and _skel:
					for i in range(randi() % 2, mini(66, _skel.get_bone_count()), 2):
						_gather_light(_skel.global_transform * _skel.get_bone_global_pose(i).origin)
			elif not _magic_fired:
				_magic_fired = true
				if is_instance_valid(_magic_target):
					_spawn_spirits(_magic_target)
				set_ai(PET_FLYING)
				attack_time = 0.0
				_attack_fx_time = -1.0

func _bone_point(b: int, p_mu: Vector3) -> Vector3:
	if _skel == null or b >= _skel.get_bone_count():
		return global_position
	return (_skel.global_transform * _skel.get_bone_global_pose(b)) * MuFxRes.mu(p_mu)

## SetAttack: hiển thị đòn đánh (0 = lao mổ, 1 = phép tầm xa)
func show_attack(target: Node3D, attack_type: int) -> void:
	attack_time = 0.0
	_attack_fx_time = -1.0
	_skill_fx_done = false
	if attack_type == 0:
		_vis_target = target
		set_ai(PET_ATTACK)
		action_start = true
		velocity = randf_range(0.0, 9.0) + 20.0
		gravity = 0.5
		if MuAudioManager:
			MuAudioManager.play_sound_file("DSpirit_Rush.wav", 0.0, 1.0, global_position)
	else:
		_magic_target = target
		_magic_fired = false
		set_ai(PET_ATTACK_MAGIC)
		if MuAudioManager:
			MuAudioManager.play_sound_file("DSpirit_Missile.wav", 0.0, 1.0, global_position)

# ------------------------------------------------------------------ "server" (RavenCommandManager)
func set_command(cmd: int, target: Node3D = null) -> void:
	command = cmd
	command_target = target
	_random_target = null
	_atk_timer = 0.2
	if cmd == CMD_DEFAULT and (ai == PET_ATTACK or ai == PET_ATTACK_MAGIC):
		set_ai(PET_FLYING)

func attack_speed() -> float:
	return 20.0 + float(player.get("stat_cmd")) / 50.0 + 0.8 * pet_level

func attack_delay() -> float:
	return maxf(100.0, 1500.0 - attack_speed() * 10.0) / 1000.0

func damage_range() -> Vector2i:
	var cmd := int(player.get("stat_cmd"))
	return Vector2i(180 + cmd / 8 + 15 * pet_level, 200 + cmd / 4 + 15 * pet_level)

func _valid(t) -> bool:
	return t != null and is_instance_valid(t) and t is MuMonster and not t.is_dead

func _monsters_near(center: Vector3, tiles: float) -> Array:
	var out: Array = []
	for c in player.get_parent().get_children():
		if c is MuMonster and not c.is_dead and c.global_position.distance_to(center) <= tiles:
			out.append(c)
	return out

func _server_tick(delta: float) -> void:
	# đòn lan đang chờ (mỗi đòn cách nhau delay / 4)
	for h in _pending_hits.duplicate():
		h[0] = float(h[0]) - delta
		if float(h[0]) <= 0.0:
			_pending_hits.erase(h)
			if _valid(h[1]) and not _owner_safe():
				_hit(h[1])
	if command == CMD_DEFAULT:
		return
	_atk_timer -= delta
	if _atk_timer > 0.0:
		return
	_atk_timer = attack_delay()
	if _owner_safe():
		return
	var target: Node3D = null
	match command:
		CMD_RANDOM:
			if not _valid(_random_target) or _random_target.global_position.distance_to(_owner_pos()) > ATTACK_RANGE_TILES:
				var list := _monsters_near(_owner_pos(), ATTACK_RANGE_TILES)
				_random_target = list.pick_random() if not list.is_empty() else null
			target = _random_target
		CMD_OWNER:
			var t = player.get("target_monster")
			target = t if _valid(t) else null
		CMD_TARGET:
			if not _valid(command_target):
				# mục tiêu đã chết -> về lệnh cơ bản
				set_command(CMD_DEFAULT)
				var hud = get_tree().get_first_node_in_group("HUD")
				if hud and hud.has_method("on_raven_command_changed"):
					hud.on_raven_command_changed()
				return
			target = command_target
	if not _valid(target):
		return
	if randf() < 0.3:
		# PetAttackType.RangeAttack: 3 đòn lên mục tiêu chính + tối đa 2 quái trong 3 ô
		show_attack(target, 1)
		var group: Array = [target]
		for m in _monsters_near(target.global_position, 3.0):
			if m != target and group.size() < 3:
				group.append(m)
		var step := attack_delay() / 4.0
		for i in 3:
			_pending_hits.append([0.6 + step * i, group[i % group.size()]])
	else:
		show_attack(target, 0)
		_pending_hits.append([0.35, target])

func _hit(m: Node3D) -> void:
	var r := damage_range()
	var dmg := randi_range(r.x, r.y)
	m.take_damage(dmg)
	if m.is_dead and player.has_method("reward_kill"):
		player.reward_kill(m)
