extends Node3D
class_name MuCharacterModel

# nạp trực tiếp (không phụ thuộc bộ nhớ đệm class_name của editor)
const MuCatalogRes = preload("res://src/mu/MuCatalog.gd")
const MuModelRes = preload("res://src/mu/MuModel.gd")

## Model nhân vật / quái / NPC dựng từ .glb đã chuyển từ BMD gốc.
##  - Người chơi: xương + ~290 action của Player.bmd ; thân = HelmClass/ArmorClass/PantClass/GloveClass/BootClass
##    theo lớp, hoặc đồ đang mặc (Items/Models/Group07..11) ; vũ khí gắn xương 33 (tay phải) / 42 (tay trái),
##    cánh gắn xương 47 ; phát sáng +3..+15 / Excellent theo RenderPartObjectEffect.
##  - Quái / NPC: model theo Monsters.json -> Models.json ; NPC có bộ phận (parts) gắn vào xương của thân.
## Hướng mặt: model MU nhìn về -Y (MU) = +Z (Godot), khớp với rotation.y = atan2(dir.x, dir.z).

# ---------------------------------------------------------------- action của Player.bmd
const P_STOP_MALE := 1
const P_STOP_FEMALE := 2
const P_STOP_SUMMONER := 3
const P_STOP_SWORD := 4
const P_STOP_TWO_HAND_SWORD := 5
const P_STOP_SPEAR := 6
const P_STOP_SCYTHE := 7
const P_STOP_BOW := 8
const P_STOP_CROSSBOW := 9
const P_STOP_WAND := 10
const P_STOP_FLY := 11
const P_WALK_MALE := 15
const P_WALK_FEMALE := 16
const P_WALK_SWORD := 17
const P_WALK_TWO_HAND_SWORD := 18
const P_WALK_SPEAR := 19
const P_WALK_SCYTHE := 20
const P_WALK_BOW := 21
const P_WALK_CROSSBOW := 22
const P_WALK_WAND := 23
const P_RUN := 25
const P_RUN_SWORD := 26
const P_RUN_TWO_SWORD := 27
const P_RUN_TWO_HAND_SWORD := 28
const P_RUN_SPEAR := 29
const P_RUN_BOW := 30
const P_RUN_CROSSBOW := 31
const P_RUN_WAND := 32
const P_FLY := 34
const P_ATTACK_FIST := 38
const P_ATTACK_SWORD_RIGHT1 := 39
const P_ATTACK_SWORD_RIGHT2 := 40
const P_ATTACK_TWO_HAND_SWORD1 := 43
const P_ATTACK_SPEAR1 := 46
const P_ATTACK_SCYTHE1 := 47
const P_ATTACK_BOW := 50
const P_ATTACK_CROSSBOW := 51
const P_ATTACK_SKILL_SWORD1 := 60
const P_SKILL_WHEEL := 65
const P_SKILL_HAND1 := 146
const P_SKILL_HAND2 := 147
const P_SKILL_WEAPON1 := 148
const P_SKILL_ELF1 := 150
const P_SKILL_TELEPORT := 151
const P_SKILL_FLASH := 152
const P_SKILL_INFERNO := 153
const P_SKILL_HELL := 154
const P_DEFENSE1 := 192
const P_GREETING1 := 193
const P_SHOCK := 236
const P_DIE1 := 237
const P_SIT1 := 239
const P_POSE1 := 245

# PlaySpeed (ZzzOpenData.cpp OpenPlayers)
const PLAYER_SPEED := {
	1: 0.28, 2: 0.28, 3: 0.24, 4: 0.26, 5: 0.24, 6: 0.24, 7: 0.24, 8: 0.22, 9: 0.22, 10: 0.30, 11: 0.28,
	15: 0.33, 16: 0.33, 17: 0.33, 18: 0.33, 19: 0.33, 20: 0.33, 21: 0.33, 22: 0.33, 23: 0.44,
	25: 0.34, 26: 0.34, 27: 0.34, 28: 0.34, 29: 0.34, 30: 0.34, 31: 0.34, 32: 0.76, 34: 0.34,
	38: 0.6, 60: 0.24, 61: 0.24, 62: 0.27, 63: 0.30, 64: 0.30, 65: 0.30,
	146: 0.30, 147: 0.30, 148: 0.30, 149: 0.30, 150: 0.30, 151: 0.30, 152: 0.30, 153: 0.30, 154: 0.30,
	236: 0.4, 237: 0.3, 238: 0.3,
}

# Monster action (MONSTER01_*)
const M_STOP1 := 0
const M_STOP2 := 1
const M_WALK := 2
const M_ATTACK1 := 3
const M_ATTACK2 := 4
const M_SHOCK := 5
const M_DIE := 6

const MuFullSetFxRes = preload("res://src/mu/MuFullSetFx.gd")
const MuItemIconRes = preload("res://src/ui/MuItemIcon.gd")
const _SHADOW_SHADER = preload("res://src/shaders/mu_blob_shadow.gdshader")
const _BODY_SHADOW_SHADER = preload("res://src/shaders/mu_body_shadow.gdshader")
const _HIDDEN_SHADER = preload("res://src/shaders/mu_hidden.gdshader")
const _ADD_SHADER = preload("res://src/shaders/mu_character_add.gdshader")
## Bóng chiếu thân hình như MU gốc (RenderBodyShadow); false = dùng lại vệt tròn mờ dưới chân
const BODY_SHADOW := true
static var _body_shadow_mat: ShaderMaterial = null
var _shadow_meshes: Array = []
var _shadow_last := Vector3(INF, INF, INF)
const BONE_RIGHT_HAND := 33
const BONE_LEFT_HAND := 42
const BONE_BACK := 47

# Mũ để lộ mặt -> vẽ thêm đầu HelmClass (SetCharacterScale: MODEL_HELM, PAD_HELM, VINE..SPIRIT, +63/65/68/70)
const HELM_SHOWS_HEAD := [0, 2, 10, 11, 12, 13, 63, 65, 68, 70]
# Tỉ lệ thân theo lớp (SetCharacterScale, Skin == 0)
const CLASS_SCALE := [0.9, 0.9, 0.88, 0.95, 0.92, 0.90, 1.03]
# Bộ phận NPC dùng biến thể "+1" (CreateMonster: Lumen, Martin ...)
const NPC_PART_VARIANT := {255: 1, 248: 1}
# NPC là "người chơi" mặc giáp (Guard: Plate set + Berdysh / Light Crossbow + Bolt)
const NPC_AS_PLAYER := {
	249: {"class": 1, "set": 9, "right": [3, 7]},
	247: {"class": 1, "set": 9, "right": [4, 11], "left": [4, 7]},
}

static var _monster_scale: Dictionary = {}

var skeleton: Skeleton3D
var anim: AnimationPlayer
var is_player := false
var char_class := 0
var weapon_kind := ""     # "", sword, axe, mace, spear, scythe, bow, crossbow, staff, stick, glove ...
var two_handed := false
var has_wings := false
var monster_speeds: Dictionary = {}
var hold_last: Array = []
var _attachments: Dictionary = {}
var _weapon_nodes: Dictionary = {}
var _weapons_on_back := false
var in_safe_zone := false
var _current := -1

# ================================================================= dựng model
func _make_base(path: String) -> bool:
	var inst := MuModelRes.instantiate(path)
	if inst == null:
		return false
	inst.name = "Body"
	add_child(inst)
	skeleton = MuModelRes.find_first(inst, "Skeleton3D") as Skeleton3D
	anim = MuModelRes.find_first(inst, "AnimationPlayer") as AnimationPlayer
	MuModelRes.apply_materials(inst)
	return true

## Gắn 1 bộ phận dùng chung xương (HelmClass01.glb, NPC/FemaleUpper02.glb ...): chuyển MeshInstance3D
## (giữ nguyên Skin — bind theo tên xương b000..) sang Skeleton3D của thân.
func attach_part(path: String, glow: Dictionary = {}, tint: Color = Color(1, 1, 1)) -> Array:
	var out: Array = []
	if skeleton == null:
		return out
	var inst := MuModelRes.instantiate(path)
	if inst == null:
		return out
	var part_name := path.get_file().get_basename()
	for mi in MuModelRes.find_all(inst, "MeshInstance3D", []):
		var m := mi as MeshInstance3D
		var t := m.transform
		m.get_parent().remove_child(m)
		skeleton.add_child(m)
		m.skeleton = NodePath("..")
		m.transform = t
		m.name = part_name
		m.set_meta("mu_part", part_name)
		MuModelRes.apply_materials(m, tint, glow)
		out.append(m)
	inst.free()
	return out

func _exit_tree() -> void:
	cleanup_materials()

## Dọn dẹp material override và tắt cast shadow trước khi node bị giải phóng
func cleanup_materials() -> void:
	MuModelRes.cleanup_geometry(self)
	_shadow_meshes.clear()

## Gỡ toàn bộ đồ / bộ phận (để mặc lại)
func clear_model() -> void:
	cleanup_materials()
	for c in get_children():
		c.queue_free()
	skeleton = null
	anim = null
	_attachments.clear()
	_weapon_nodes.clear()
	_weapons_on_back = false
	in_safe_zone = false
	_current = -1

func _bone_attachment(bone: int) -> BoneAttachment3D:
	if _attachments.has(bone):
		return _attachments[bone]
	var ba := BoneAttachment3D.new()
	ba.name = "Bone%03d" % bone
	skeleton.add_child(ba)
	ba.bone_name = "b%03d" % bone
	_attachments[bone] = ba
	return ba

## Gắn model cứng (vũ khí, cánh) vào 1 xương ; model có animation riêng (cánh) thì chạy a000
func attach_to_bone(path: String, bone: int, glow: Dictionary = {}, tint: Color = Color(1, 1, 1)) -> Node3D:
	if skeleton == null or skeleton.find_bone("b%03d" % bone) < 0:
		return null
	var inst := MuModelRes.instantiate(path)
	if inst == null:
		return null
	_bone_attachment(bone).add_child(inst)
	MuModelRes.apply_materials(inst, tint, glow)
	var ap := MuModelRes.find_first(inst, "AnimationPlayer") as AnimationPlayer
	if ap:
		MuModelRes.play(ap, 0, 0.25, true)
	return inst

## Kiểm tra loại vũ khí có cất sau lưng khi ở trong thành hay không (IsBackItem trong ZzzCharacter.cpp)
static func is_back_weapon(group: int, number: int) -> bool:
	if group in [MuCatalogRes.GROUP_SWORD, MuCatalogRes.GROUP_AXE, MuCatalogRes.GROUP_MACE, MuCatalogRes.GROUP_SPEAR, MuCatalogRes.GROUP_BOW, MuCatalogRes.GROUP_SHIELD]:
		return true
	if group == MuCatalogRes.GROUP_STAFF:
		# Sách triệu hồi của Summoner (Book) không đeo sau lưng
		var info := MuCatalogRes.item_info(group, number)
		return str(info.get("weaponKind", "")) != "book"
	return false

## Ma trận gắn vũ khí sau lưng trong thành (PlaceLinkedPart của ZzzCharacter.cpp)
static func _mu_matrix_to_transform(angle_deg: Array, t_mu: Vector3) -> Transform3D:
	var r: Array = MuItemIconRes._angle_matrix(angle_deg)
	var c := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	var rm := Basis(Vector3(r[0][0], r[1][0], r[2][0]), Vector3(r[0][1], r[1][1], r[2][1]), Vector3(r[0][2], r[1][2], r[2][2]))
	var rot_godot := c * rm * c.inverse()
	var pos_godot := c * (t_mu / 100.0)
	return Transform3D(rot_godot, pos_godot)

static func calc_back_weapon_transform(group: int, number: int, is_right: bool) -> Transform3D:
	# Nỏ (Crossbow)
	if group == MuCatalogRes.GROUP_BOW and number in [8, 9, 10, 11, 12, 13, 14, 16]:
		return _mu_matrix_to_transform([0.0, 20.0, 180.0], Vector3(-10.0, 8.0, 40.0))
	# Cung (Bow)
	elif group == MuCatalogRes.GROUP_BOW:
		return _mu_matrix_to_transform([70.0, 0.0, 90.0], Vector3(-10.0, 5.0, 10.0))
	# Khiên (Shield)
	elif group == MuCatalogRes.GROUP_SHIELD:
		var angle := [70.0, 0.0, 90.0]
		var t := Vector3(-10.0, 0.0, 0.0)
		if number == 11:
			angle = [30.0, 0.0, 90.0]
			t = Vector3(-20.0, 0.0, -20.0)
		elif number in [6, 13]:
			angle = [50.0, 0.0, 90.0]
			t = Vector3(-28.0, 0.0, -25.0)
		elif number == 4:
			angle = [30.0, 0.0, 90.0]
			t = Vector3(-15.0, 0.0, -25.0)
		return _mu_matrix_to_transform(angle, t)

	# Vũ khí cận chiến & phép thuật (Kiếm, rìu, chùy, giáo, gậy):
	# Đeo chéo hình chữ X sau lưng cân đối, mũi kiếm cao ngang gối/đùi (không cắm đất hay đâm vào giáp/cánh)
	var tilt_deg := 46.0
	var tilt_rad := deg_to_rad(tilt_deg)
	var scale_factor := 0.82
	if is_right:
		var z_dir_r := Vector3(sin(tilt_rad), -cos(tilt_rad), 0.03).normalized()
		var x_dir_r := Vector3(0.0, 0.0, -1.0)
		var y_dir_r := z_dir_r.cross(x_dir_r).normalized()
		x_dir_r = y_dir_r.cross(z_dir_r).normalized()
		var basis_r := Basis(x_dir_r, y_dir_r, z_dir_r).scaled(Vector3.ONE * scale_factor)
		return Transform3D(basis_r, Vector3(-0.15, 0.28, -0.10))
	else:
		var z_dir_l := Vector3(-sin(tilt_rad), -cos(tilt_rad), 0.03).normalized()
		var x_dir_l := Vector3(0.0, 0.0, -1.0)
		var y_dir_l := z_dir_l.cross(x_dir_l).normalized()
		x_dir_l = y_dir_l.cross(z_dir_l).normalized()
		var basis_l := Basis(x_dir_l, y_dir_l, z_dir_l).scaled(Vector3.ONE * scale_factor)
		return Transform3D(basis_l, Vector3(0.15, 0.28, -0.13))

## Cập nhật trạng thái trong thành / ngoài thành -> chuyển vũ khí sau lưng / trên tay
func set_safe_zone(safe: bool) -> void:
	if not is_player:
		return
	if in_safe_zone != safe or _weapons_on_back != safe:
		in_safe_zone = safe
		_update_weapon_mount()

func _update_weapon_mount() -> void:
	if _weapons_on_back == in_safe_zone:
		return
	_weapons_on_back = in_safe_zone
	for hand in _weapon_nodes:
		var d: Dictionary = _weapon_nodes[hand]
		if not bool(d.get("can_back", false)):
			continue
		var inst: Node3D = d.get("node")
		if not is_instance_valid(inst):
			continue
		var old_parent = inst.get_parent()
		if _weapons_on_back:
			var back_ba := _bone_attachment(BONE_BACK)
			if old_parent != back_ba:
				if old_parent:
					old_parent.remove_child(inst)
				back_ba.add_child(inst)
			inst.transform = calc_back_weapon_transform(int(d["group"]), int(d["number"]), bool(d["is_right"]))
		else:
			var hand_ba := _bone_attachment(int(d["bone_hand"]))
			if old_parent != hand_ba:
				if old_parent:
					old_parent.remove_child(inst)
				hand_ba.add_child(inst)
			inst.transform = Transform3D.IDENTITY

## Người chơi.
## equip: {"helm"/"armor"/"pants"/"gloves"/"boots"/"right"/"left"/"wings": {"group", "number", "level", "excellent"}}
func build_player(cls: int, equip: Dictionary = {}) -> bool:
	if skeleton:
		clear_model()
	is_player = true
	char_class = clampi(cls, 0, 6)
	if not _make_base("res://assets/mu/Player/player.glb"):
		return false
	scale = Vector3.ONE * CLASS_SCALE[char_class]
	var slots := [["helm", "HelmClass", MuCatalogRes.GROUP_HELM], ["armor", "ArmorClass", MuCatalogRes.GROUP_ARMOR],
		["pants", "PantClass", MuCatalogRes.GROUP_PANTS], ["gloves", "GloveClass", MuCatalogRes.GROUP_GLOVES],
		["boots", "BootClass", MuCatalogRes.GROUP_BOOTS]]
	var class_file := "res://assets/mu/Player/%s%02d.glb"
	for s in slots:
		var it: Dictionary = equip.get(s[0], {})
		var path := ""
		if not it.is_empty():
			path = MuCatalogRes.item_glb(s[2], int(it.get("number", 0)))
		if path == "" or not ResourceLoader.exists(path):
			attach_part(class_file % [s[1], char_class + 1])
		else:
			attach_part(path, _glow_of(it, s[2]), MuModelRes.level_tint(MuCatalogRes.glow_level(s[2], int(it.get("number", 0)), int(it.get("level", 0)))))
			if s[0] == "helm" and int(it.get("number", -1)) in HELM_SHOWS_HEAD:
				attach_part(class_file % ["HelmClass", char_class + 1])
	weapon_kind = ""
	two_handed = false
	_weapon_nodes.clear()
	_weapons_on_back = false
	for hand in ["right", "left"]:
		var w: Dictionary = equip.get(hand, {})
		if w.is_empty():
			continue
		var g := int(w.get("group", 0))
		var n := int(w.get("number", 0))
		var info := MuCatalogRes.item_info(g, n)
		var bone := BONE_RIGHT_HAND
		if hand == "left" or str(info.get("slot", "")) == "offHand":
			bone = BONE_LEFT_HAND
		var inst := attach_to_bone(MuCatalogRes.item_glb(g, n), bone, _glow_of(w, g), MuModelRes.level_tint(MuCatalogRes.glow_level(g, n, int(w.get("level", 0)))))
		if inst != null:
			_weapon_nodes[hand] = {
				"node": inst,
				"bone_hand": bone,
				"group": g,
				"number": n,
				"is_right": (hand == "right"),
				"can_back": is_back_weapon(g, n),
			}
		var kind := str(info.get("weaponKind", ""))
		if kind != "" and (weapon_kind == "" or hand == "right"):
			weapon_kind = kind
			two_handed = bool(info.get("twoHanded", false))
	var wing: Dictionary = equip.get("wings", {})
	has_wings = false
	if not wing.is_empty():
		has_wings = attach_to_bone(MuCatalogRes.item_glb(MuCatalogRes.GROUP_WING, int(wing.get("number", 0))), BONE_BACK,
			_glow_of(wing, MuCatalogRes.GROUP_WING)) != null
	_add_grade15(equip)
	# hiệu ứng trọn bộ +10..+15 (UpdatePlayerEffects) + bóng dưới chân
	var fx = MuFullSetFxRes.new()
	fx.name = "FullSetFx"
	add_child(fx)
	if not fx.setup(self, equip, char_class):
		fx.queue_free()
	_add_body_shadow()
	_current = -1
	return true

## Vật trang trí của đồ +15 (ForEachNextGradeObject trong ZzzObject.cpp): mỗi món +15 gắn thêm
## Data/Item/class15_*.bmd vào xương, góc + vị trí theo RenderLinkObject (ZzzCharacter.cpp)
const GRADE15 := {
	"helm": [["class15_head", 20, [180.0, -90.0, 0.0], [28.0, 20.0, 0.0]]],
	"armor": [["class15_bodyleft", 35, [0.0, -90.0, 0.0], [5.0, -20.0, 0.0]], ["class15_bodyright", 26, [0.0, -90.0, 0.0], [5.0, -20.0, 0.0]]],
	"pants": [["class15_pantleft", 3, [0.0, 90.0, 180.0], [25.0, 5.0, -5.0]], ["class15_pantright", 10, [0.0, 90.0, 180.0], [25.0, 5.0, 5.0]]],
	"gloves": [["class15_armleft", 36, [0.0, -90.0, 0.0], [30.0, 0.0, 20.0]], ["class15_armright", 27, [0.0, -90.0, 0.0], [30.0, 0.0, -20.0]]],
	"boots": [["class15_bootleft", 4, [0.0, 90.0, 180.0], [20.0, 15.0, -10.0]], ["class15_bootright", 11, [0.0, 90.0, 180.0], [20.0, 15.0, 10.0]]],
}
const _CLASS15_SHADER = preload("res://src/shaders/mu_class15.gdshader")

func _add_grade15(equip: Dictionary) -> void:
	for slot in GRADE15:
		var it = equip.get(slot, {})
		if not (it is Dictionary) or int(it.get("level", 0)) < 15:
			continue
		for e in GRADE15[slot]:
			var path := "res://assets/mu/Item/%s.glb" % e[0]
			if skeleton == null or int(e[1]) >= skeleton.get_bone_count() or not ResourceLoader.exists(path):
				continue
			var inst := MuModelRes.instantiate(path)
			if inst == null:
				continue
			# ma trận MU (AngleMatrix + dời) -> Godot: C * M * C^T, C: MU (x, y, z) -> Godot (x, z, -y)
			var r: Array = MuItemIconRes._angle_matrix(e[2])
			var c := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))   # cột: ảnh của trục MU x, y, z
			var rm := Basis(Vector3(r[0][0], r[1][0], r[2][0]), Vector3(r[0][1], r[1][1], r[2][1]), Vector3(r[0][2], r[1][2], r[2][2]))
			var t: Array = e[3]
			inst.transform = Transform3D(c * rm * c.inverse(), c * Vector3(t[0], t[1], t[2]) / 100.0)
			_bone_attachment(int(e[1])).add_child(inst)
			var m := ShaderMaterial.new()
			m.shader = _CLASS15_SHADER
			m.set_shader_parameter("rgb_mix_tex", MuModelRes.fx("rgb_mix"))
			m.set_shader_parameter("chrome2_tex", MuModelRes.fx("Chrome02"))
			for mi in MuModelRes.find_all(inst, "MeshInstance3D", []):
				var mesh: Mesh = (mi as MeshInstance3D).mesh
				if mesh == null:
					continue
				for si in mesh.get_surface_count():
					var mm: ShaderMaterial = m.duplicate()
					var bm := mesh.surface_get_material(si) as BaseMaterial3D
					mm.set_shader_parameter("albedo_tex", bm.albedo_texture if bm else null)
					(mi as MeshInstance3D).set_surface_override_material(si, mm)
				(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## Bóng chiếu thân hình (BMD::RenderBodyShadow): nối lớp bóng vào cuối chuỗi vật liệu của mọi mesh
## (thân, đồ, vũ khí, cánh), trừ mesh ẩn / mesh cộng sáng. Gốc bóng cập nhật trong _process.
func _add_body_shadow() -> void:
	_shadow_meshes.clear()
	if not BODY_SHADOW:
		_add_shadow()
		return
	if _body_shadow_mat == null:
		_body_shadow_mat = ShaderMaterial.new()
		_body_shadow_mat.shader = _BODY_SHADOW_SHADER
	for n in MuModelRes.find_all(self, "MeshInstance3D", []):
		var mi := n as MeshInstance3D
		if mi.mesh == null or mi.name == "Shadow":
			continue
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var added := false
		for s in mi.mesh.get_surface_count():
			var head := mi.get_surface_override_material(s) as ShaderMaterial
			if head == null or head.shader == _HIDDEN_SHADER or head.shader == _ADD_SHADER:
				continue
			# chép cả chuỗi (vật liệu trong cache dùng chung) rồi nối lớp bóng vào cuối
			head = head.duplicate() as ShaderMaterial
			var last := head
			while last.next_pass != null:
				last.next_pass = last.next_pass.duplicate()
				last = last.next_pass as ShaderMaterial
			last.next_pass = _body_shadow_mat
			mi.set_surface_override_material(s, head)
			added = true
		if added:
			_shadow_meshes.append(mi)
	_update_shadow_origin(true)

func _update_shadow_origin(force: bool = false) -> void:
	if _shadow_meshes.is_empty() or not is_inside_tree():
		return
	var o := global_position
	# chỉ gửi khi gốc đổi (quái / NPC đứng yên không tốn gì)
	if not force and o.distance_squared_to(_shadow_last) < 0.0001:
		return
	_shadow_last = o
	for mi in _shadow_meshes:
		if is_instance_valid(mi):
			(mi as MeshInstance3D).set_instance_shader_parameter("shadow_origin", o)

func _process(_delta: float) -> void:
	_update_shadow_origin()

## Vệt tối mờ dưới chân (cách cũ, khi BODY_SHADOW = false)
func _add_shadow() -> void:
	var q := QuadMesh.new()
	q.size = Vector2(1.1, 1.1)
	q.orientation = PlaneMesh.FACE_Y
	var m := ShaderMaterial.new()
	m.shader = _SHADOW_SHADER
	var mi := MeshInstance3D.new()
	mi.name = "Shadow"
	mi.mesh = q
	mi.material_override = m
	mi.position = Vector3(0, 0.03, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _glow_of(it: Dictionary, group: int) -> Dictionary:
	var n := int(it.get("number", 0))
	var lv := MuCatalogRes.glow_level(group, n, int(it.get("level", 0)))
	var exc := bool(it.get("excellent", false))
	var md: Dictionary = MuCatalogRes.item_model(group, n)
	var g = md.get("glow", {})
	var out := {"level": lv, "excellent": exc, "style": str(md.get("renderStyle", "")),
		"ancient": bool(it.get("ancient", false)), "ancient_color": MuCatalogRes.item_ancient_color(group, n),
		"color": MuCatalogRes.item_glow_color(group, n), "shine": MuCatalogRes.item_shine_color(group, n)}
	var mat = md.get("material", {})
	if mat is Dictionary:
		out["specular"] = float(mat.get("specular", 0.0))   # độ bóng (Enhanced lighting)
	if g is Dictionary:
		if g.get("excellent", true) == false:
			out["excellent"] = false   # Glow::HasExcellentGlow
		if g.get("meshes") is Array:
			out["meshes"] = g["meshes"]
		if g.has("hiddenMesh"):
			out["hidden"] = int(g["hiddenMesh"])
	return out

## Quái / NPC theo số hiệu (Monsters.json) hoặc tên
func build_monster(number: int = -1, mon_name: String = "") -> bool:
	var mon := MuCatalogRes.find_monster(number, mon_name)
	if mon.is_empty():
		return false
	number = int(mon.get("number", number))
	if NPC_AS_PLAYER.has(number):
		var d: Dictionary = NPC_AS_PLAYER[number]
		var eq := {}
		var gi := 7
		for k in ["helm", "armor", "pants", "gloves", "boots"]:
			eq[k] = {"group": gi, "number": d["set"]}
			gi += 1
		for hand in ["right", "left"]:
			if d.has(hand):
				eq[hand] = {"group": d[hand][0], "number": d[hand][1]}
		var ok := build_player(int(d["class"]), eq)
		is_player = true
		return ok
	var model := MuCatalogRes.monster_model(mon)
	if model.is_empty():
		return false
	is_player = false
	if not _make_base(MuCatalogRes.bmd_to_glb(model.get("file", ""))):
		return false
	monster_speeds = model.get("animations", {}) if model.get("animations") is Dictionary else {}
	hold_last = model.get("holdLastFrame", []) if model.get("holdLastFrame") is Array else []
	# bộ phận NPC: mỗi nhóm (HEAD / UPPER / LOWER / GLOVES / BOOTS) lấy 1 biến thể
	var parts: Array = model.get("parts", []) if model.get("parts") is Array else []
	if not parts.is_empty():
		var variant := int(NPC_PART_VARIANT.get(number, 0))
		var groups := {}
		for p in parts:
			var slot := str(p.get("slot", ""))
			var base := slot.split("+")[0]
			var idx := int(slot.split("+")[1]) if slot.contains("+") else 0
			if idx == variant or (not groups.has(base) and idx == 0):
				groups[base] = p.get("file", "")
		for base in groups:
			attach_part(MuCatalogRes.bmd_to_glb(groups[base]))
	scale = Vector3.ONE * monster_scale(number)
	_add_body_shadow()
	_current = -1
	return true

static func monster_scale(number: int) -> float:
	if _monster_scale.is_empty():
		var p := "res://assets/mu_monster_scale.json"
		if FileAccess.file_exists(p):
			var d = JSON.parse_string(FileAccess.get_file_as_string(p))
			if d is Dictionary:
				_monster_scale = d.get("scale", {})
		if _monster_scale.is_empty():
			_monster_scale = {"_": 1.0}
	return float(_monster_scale.get(str(number), 1.0))

# ================================================================= animation
func play_action(action: int, speed: float = -1.0, loop: bool = true, restart: bool = false) -> bool:
	if anim == null:
		return false
	if speed < 0.0:
		speed = PLAYER_SPEED.get(action, 0.25) if is_player else 0.25
	if not restart and _current == action:
		return true
	if MuModelRes.play(anim, action, speed, loop, restart):
		_current = action
		return true
	return false

func is_action_finished() -> bool:
	return anim == null or not anim.is_playing() or anim.current_animation == ""

## safe_zone: trong thành (cất vũ khí sau lưng, không chạy/bay) — SetPlayerStop / SetPlayerWalk
func play_idle(safe_zone: bool = false) -> void:
	if not is_player:
		play_action(M_STOP1, _mspeed("stop1"))
		return
	set_safe_zone(safe_zone)
	if has_wings and not safe_zone:
		play_action(P_STOP_CROSSBOW if weapon_kind == "crossbow" else P_STOP_FLY)
		return
	if weapon_kind == "" or safe_zone:
		play_action(P_STOP_FEMALE if char_class == MuCatalogRes.CharClass.FAIRY_ELF else
			(P_STOP_SUMMONER if char_class == MuCatalogRes.CharClass.SUMMONER else P_STOP_MALE))
		return
	match weapon_kind:
		"sword", "axe", "mace", "glove":
			play_action(P_STOP_TWO_HAND_SWORD if two_handed else P_STOP_SWORD)
		"spear":
			play_action(P_STOP_SCYTHE if two_handed else P_STOP_SWORD)
		"scythe":
			play_action(P_STOP_SCYTHE)
		"bow":
			play_action(P_STOP_BOW)
		"crossbow":
			play_action(P_STOP_CROSSBOW)
		"stick":
			play_action(P_STOP_WAND)
		"staff", "scepter":
			play_action(P_STOP_SCYTHE if two_handed else P_STOP_SWORD)
		_:
			play_action(P_STOP_MALE)

func play_move(running: bool = true, safe_zone: bool = false) -> void:
	if not is_player:
		play_action(M_WALK, _mspeed("walk"))
		return
	set_safe_zone(safe_zone)
	if has_wings and not safe_zone:
		play_action(P_FLY)
		return
	if weapon_kind == "" or safe_zone:
		if running and not safe_zone:
			play_action(P_RUN)
		else:
			play_action(P_WALK_FEMALE if char_class == MuCatalogRes.CharClass.FAIRY_ELF else P_WALK_MALE)
		return
	if not running:
		match weapon_kind:
			"sword", "axe", "mace", "glove": play_action(P_WALK_TWO_HAND_SWORD if two_handed else P_WALK_SWORD)
			"spear": play_action(P_WALK_SPEAR)
			"scythe": play_action(P_WALK_SCYTHE)
			"bow": play_action(P_WALK_BOW)
			"crossbow": play_action(P_WALK_CROSSBOW)
			"stick": play_action(P_WALK_WAND)
			_: play_action(P_WALK_SCYTHE if two_handed else P_WALK_SWORD)
		return
	match weapon_kind:
		"sword", "axe", "mace", "glove": play_action(P_RUN_TWO_HAND_SWORD if two_handed else P_RUN_SWORD)
		"spear", "scythe": play_action(P_RUN_SPEAR)
		"bow": play_action(P_RUN_BOW)
		"crossbow": play_action(P_RUN_CROSSBOW)
		"stick": play_action(P_RUN_WAND)
		_: play_action(P_RUN_SPEAR if two_handed else P_RUN_SWORD)

## attack_speed: chỉ số tốc đánh (AttackSpeed) — PlaySpeed = 0.25 + AttackSpeed * 0.004 (xấp xỉ SetAttackSpeed)
func play_attack(attack_speed: int = 20) -> void:
	if not is_player:
		if anim == null:
			return
		var a := M_ATTACK1 if randi() % 2 == 0 or not anim.has_animation("a%03d" % M_ATTACK2) else M_ATTACK2
		play_action(a, _mspeed("attack1" if a == M_ATTACK1 else "attack2"), false, true)
		return
	set_safe_zone(false)
	var sp := 0.25 + attack_speed * 0.004
	var act := P_ATTACK_FIST
	match weapon_kind:
		"sword", "axe", "mace": act = P_ATTACK_TWO_HAND_SWORD1 if two_handed else P_ATTACK_SWORD_RIGHT1 + randi() % 2
		"spear": act = P_ATTACK_SPEAR1
		"scythe": act = P_ATTACK_SCYTHE1
		"bow": act = P_ATTACK_BOW
		"crossbow": act = P_ATTACK_CROSSBOW
		"staff", "stick": act = P_SKILL_HAND1
		_: sp = 0.6
	play_action(act, sp, false, true)

## Kỹ năng (action theo SKILL_*), mặc định SKILL_HAND1 cho phép thuật, SKILL_WHEEL cho Twisting Slash
func play_skill(action: int = P_SKILL_HAND1, speed: float = -1.0) -> void:
	if is_player:
		set_safe_zone(false)
	play_action(action, speed, false, true)

func play_shock() -> void:
	if is_player:
		play_action(P_SHOCK, 0.4, false, true)
	elif anim and anim.has_animation("a%03d" % M_SHOCK):
		play_action(M_SHOCK, _mspeed("shock"), false, true)

func play_die() -> void:
	if is_player:
		play_action(P_DIE1, 0.3, false, true)
	else:
		play_action(M_DIE, _mspeed("die"), false, true)

func _mspeed(key: String) -> float:
	return float(monster_speeds.get(key, 0.25))
