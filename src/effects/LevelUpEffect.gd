extends MuFx
class_name LevelUpEffect

## Hiệu ứng Thăng Cấp theo client gốc (ReceiveLevelUp, WSclient.cpp):
##   for i < 15: CreateJoint(BITMAP_FLARE, Position, Position, Angle, SubType 0, Hero, Scale 40, 2)
##   CreateEffect(BITMAP_MAGIC + 1, Position, Angle, Light, SubType 0, Hero)
##
## BITMAP_FLARE SubType 0 (ZzzEffectJoint.cpp, CreateJoint / MoveJoint):
##   Scale 40 (> 10) -> LifeTime 50, MaxTails 20, Velocity 40 (bán kính quỹ đạo, đơn vị MU)
##   Direction[1] = rand(-250..249) (lệch pha), Direction[2] = rand(200..449)/100 (bay lên mỗi tick)
##   count = (Direction[1] + LifeTime) * 0.1 ; Position.xy = Target + (cos(count), -sin(count)) * Velocity
##   Position.z += Direction[2] mỗi tick -> 15 vệt sáng xoắn ốc bay lên quanh nhân vật
##   Light = Target->Light ; vệt rộng = Scale (40 đơn vị MU = 0.4 m), texture Flare
##
## BITMAP_MAGIC+1 SubType 0 (ZzzEffect.cpp): LifeTime 20, vòng phép Magic_Ground2 dán trên mặt đất
##   Scale = (20 - LifeTime) * 0.15 ô (lớn dần 0 -> 3 m), màu (0.4, 0.6, 1.0) * Luminosity,
##   Luminosity giảm 0.2 mỗi tick ở 5 tick cuối.

const FLARE_COUNT := 15
const FLARE_LIFE := 50
const FLARE_RADIUS := 40.0      # Velocity, đơn vị MU
const FLARE_WIDTH := 0.4        # Scale 40 đơn vị MU
const FLARE_TAILS := 20
const MAGIC_LIFE := 20

var _origin := Vector3.ZERO
var _follow: Node3D = null
var _flares: Array = []          # {r: ribbon, phase, rise, z}
var _magic: Dictionary = {}

func _ready() -> void:
	# nơi gọi đặt global_position trước khi add_child -> ghi lại trước khi MuFx đưa node về gốc toạ độ
	_origin = position
	_follow = _find_owner(_origin)
	if MuAudioManager:
		MuAudioManager.play_level_up()
	super._ready()

## Nhân vật đứng tại điểm phát hiệu ứng (o->Target = Hero): vòng sáng bám theo khi nhân vật di chuyển
func _find_owner(p: Vector3) -> Node3D:
	var tree := get_tree()
	if tree == null:
		return null
	var best: Node3D = null
	var best_d := 1.0
	for n in tree.get_nodes_in_group("Player"):
		if n is Node3D:
			var d := (n as Node3D).global_position.distance_to(p)
			if d < best_d:
				best_d = d
				best = n
	return best

func _center() -> Vector3:
	if _follow != null and is_instance_valid(_follow):
		return _follow.global_position
	return _origin

func _start() -> void:
	_min_ticks = FLARE_LIFE
	var c := _center()
	for i in FLARE_COUNT:
		var f := {"phase": float(rnd(500) - 250), "rise": float(rnd(250) + 200) / 100.0, "z": 0.0, "life": float(FLARE_LIFE)}
		f["r"] = ribbon("BITMAP_FLARE", _flare_pos(c, f), {"width": FLARE_WIDTH, "max_tails": FLARE_TAILS,
			"life": FLARE_LIFE, "color": Color(1, 1, 1), "fade": false})
		_flares.append(f)
	_magic = particle("BITMAP_MAGIC+1", c + Vector3(0, 0.05, 0), {"size": 0.01, "life": MAGIC_LIFE,
		"color": Color(0.4, 0.6, 1.0), "fade": false, "rot": 0.0})
	if not _magic.is_empty():
		_magic["flat"] = true

## Vị trí đầu vệt (Godot, m) theo MoveJoint SubType 0
func _flare_pos(c: Vector3, f: Dictionary) -> Vector3:
	var count := (float(f["phase"]) + float(f["life"])) * 0.1
	var off := mu(Vector3(cos(count) * FLARE_RADIUS, -sin(count) * FLARE_RADIUS, float(f["z"])))
	return c + off

func _mu_tick(_tick: int) -> void:
	var c := _center()
	for f in _flares:
		f["life"] = float(f["life"]) - 1.0
		f["z"] = float(f["z"]) + float(f["rise"])
		var r: Dictionary = f["r"]
		r["head"] = _flare_pos(c, f)
		ribbon_push(r)
	if not _magic.is_empty() and _parts.has(_magic):
		var life := float(_magic["life"])
		# Scale = (20 - LifeTime) * 0.15 ô ; 1 ô = 1 m (RenderTerrainAlphaBitmap: texture trải Size ô)
		_magic["size"] = maxf((MAGIC_LIFE - life) * 0.15, 0.01)
		_magic["pos"] = Vector3(c.x, ground(c) + 0.05, c.z)
		var lum := 1.0
		if life < 5.0:
			lum -= (5.0 - life) * 0.2
		_magic["color"] = Color(0.4 * lum, 0.6 * lum, 1.0 * lum)
