extends RefCounted
class_name MuItemIcon

## Ảnh đồ trong ô túi đồ / cửa hàng: vẽ model 3D của món đồ (assets/mu/Item/...glb) vào SubViewport,
## xoay theo "inventory.rotation" trong Items/Models/GroupXX.json (góc MU, camera nhìn thẳng như
## UI::Items::DrawUnderItemCamera — FOV 1° gần như chiếu song song), tự căn giữa và vừa khít số ô.

const MuCatalogRes = preload("res://src/mu/MuCatalog.gd")
const MuModelRes = preload("res://src/mu/MuModel.gd")
const MuItemsRes = preload("res://src/mu/MuItems.gd")
const ICON_SHADER := preload("res://src/shaders/mu_item_icon.gdshader")
const ICON_ALPHA_SHADER := preload("res://src/shaders/mu_item_icon_alpha.gdshader")
const ADD_SHADER := preload("res://src/shaders/mu_character_add.gdshader")
const HIDDEN_SHADER := preload("res://src/shaders/mu_hidden.gdshader")
const PX := 48   # điểm ảnh render cho mỗi ô
## Lề render thêm quanh ô (tính bằng ô, mỗi phía): phần đồ lớn hơn khung (áo, vũ khí, cánh...) tràn ra ngoài
## khung thay vì bị cắt. Chỗ vẽ ảnh dùng overflow_rect() để nới khung vẽ ra đúng lề này.
const PAD_CELLS := 0.4

static var _host: Node = null
static var _cache: Dictionary = {}
static var _mats: Dictionary = {}

static func _get_host(tree: SceneTree) -> Node:
	if _host == null or not is_instance_valid(_host):
		_host = Node.new()
		_host.name = "MuItemIconHost"
		tree.root.add_child.call_deferred(_host)
	return _host

static func _angle_matrix(a: Array) -> Array:
	var r0 := deg_to_rad(float(a[0]))
	var r1 := deg_to_rad(float(a[1]))
	var r2 := deg_to_rad(float(a[2]))
	var sy := sin(r2)
	var cy := cos(r2)
	var sp := sin(r1)
	var cp := cos(r1)
	var sr := sin(r0)
	var cr := cos(r0)
	return [[cp * cy, sr * sp * cy - cr * sy, cr * sp * cy + sr * sy],
		[cp * sy, sr * sp * sy + cr * cy, cr * sp * sy - sr * cy],
		[-sp, sr * cp, cr * cp]]

## Basis đưa đỉnh glb (toạ độ Godot) về không gian camera của MU: R(rotation) * C^T
static func _basis(rot: Array) -> Basis:
	var r := _angle_matrix(rot)
	# C^T: Godot (x, y, z) -> MU (x, -z, y)
	var ct := [[1, 0, 0], [0, 0, -1], [0, 1, 0]]
	var m := []
	for i in 3:
		var row := []
		for j in 3:
			var v := 0.0
			for k in 3:
				v += r[i][k] * ct[k][j]
			row.append(v)
		m.append(row)
	return Basis(Vector3(m[0][0], m[1][0], m[2][0]), Vector3(m[0][1], m[1][1], m[2][1]), Vector3(m[0][2], m[1][2], m[2][2]))

static func _material(src: Material, level: int, light_mul: float = 1.0) -> Material:
	var tex: Texture2D = null
	var alpha := false
	var bm := src as BaseMaterial3D
	if bm:
		tex = bm.albedo_texture
		alpha = bm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
	var stem := MuModelRes.tex_stem(src)
	if MuModelRes.is_skin_or_hair(stem):
		return HIDDEN_SHADER_MAT()
	var kind: String = MuModelRes.mesh_script(stem)
	var tint: Color = MuModelRes.level_tint(level)
	tint = Color(tint.r * light_mul, tint.g * light_mul, tint.b * light_mul, tint.a)
	var key := "%d|%s|%s|%s" % [tex.get_instance_id() if tex else 0, kind, str(alpha), "%.3f,%.3f,%.3f,%.2f" % [tint.r, tint.g, tint.b, tint.a]]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	if kind == "hide":
		m.shader = HIDDEN_SHADER
	elif kind == "bright":
		m.shader = ADD_SHADER
		m.set_shader_parameter("albedo_tex", tex)
	else:
		m.shader = ICON_ALPHA_SHADER if alpha else ICON_SHADER
		m.set_shader_parameter("albedo_tex", tex)
		m.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
		m.set_shader_parameter("tint_pulse", 1.0 if tint.a < 0.99 else 0.0)
	_mats[key] = m
	return m

## Lớp phát sáng của đồ trong ô (RenderObjectScreen gọi RenderPartObject như đồ mặc trên người):
## +7.. chrome / metal / chrome2 / chrome4, excellent nhấp nháy, ancient
static func _glow_info(it: Dictionary, g: int, n: int) -> Dictionary:
	var md: Dictionary = MuCatalogRes.item_model(g, n)
	var gl = md.get("glow", {})
	var out := {"level": int(it.get("level", 0)), "excellent": bool(it.get("excellent", false)),
		"ancient": bool(it.get("ancient", false)), "ancient_color": MuCatalogRes.item_ancient_color(g, n),
		"color": MuCatalogRes.item_glow_color(g, n), "shine": MuCatalogRes.item_shine_color(g, n)}
	if gl is Dictionary:
		if gl.get("excellent", true) == false:
			out["excellent"] = false   # Glow::HasExcellentGlow
		if gl.get("meshes") is Array:
			out["meshes"] = MuModelRes.ints(gl["meshes"])   # JSON là float: `1 in [1.0]` là false -> đổi sang int
		if gl.has("hiddenMesh"):
			out["hidden"] = int(gl["hiddenMesh"])
	return out

static func _needs_glow(gi: Dictionary) -> bool:
	return int(gi.get("level", 0)) >= 7 or bool(gi.get("excellent", false)) or bool(gi.get("ancient", false))

## Ảnh cần vẽ lại liên tục: cấp +3.. (nhấp nháy / chrome chạy), excellent, ancient, kiểu vẽ động
static func _animated(it: Dictionary, style: String) -> bool:
	return MuCatalogRes.glow_level(int(it.get("group", 0)), int(it.get("number", 0)), int(it.get("level", 0))) >= 3 or bool(it.get("excellent", false)) or bool(it.get("ancient", false)) \
		or (style != "" and not style.begins_with("textured"))

const ItemStylesRes = preload("res://src/mu/MuItemStyles.gd")
const ICON_DIR := "res://assets/mu/icons/"
## ITEM_SACRED_ARMOR (8:59), STORM_HARD_ARMOR (8:60), PIERCING_ARMOR (8:61), PHOENIX_SOUL_ARMOR (8:73)
const RF_ARMOR_INVENTORY_GLB := {
	"8:59": "res://assets/mu/Player/Armor_inventory60.glb",
	"8:60": "res://assets/mu/Player/ArmorMale61_inventory.glb",
	"8:61": "res://assets/mu/Player/ArmorMale62_inventory.glb",
	"8:73": "res://assets/mu/Player/ArmorMale74_inven.glb",
}
## Độ sáng lớp phủ phát sáng theo cấp của ẢNH ĐỒ TRONG TÚI / RƯƠNG (tách riêng với đồ mặc ngoài
## thế giới: MuModel.GLOW_GAIN_*). Ảnh đồ vẽ với ánh sáng cố định 1.0 trên nền tối của ô.
const ICON_GLOW_GAIN_7 := 1.4    # +7 .. +10
const ICON_GLOW_GAIN_11 := 1.9   # +11, +12
const ICON_GLOW_GAIN_13 := 2.5   # +13 .. +15
## số điểm ảnh trên 1 đơn vị MU nhân với "scale" trong dữ liệu (đo trên ô 20 px của màn hình 640x480 gốc)
## RenderObjectScreen (ZzzInventory.cpp): camera đồ FOV 1°, đồ đặt ở độ sâu 0.1 * RENDER_ITEMVIEW_FAR = 200
## => 1 đơn vị thế giới = 480 / (2 * 200 * tan 0.5°) = 137.5 điểm ảnh trên màn 640x480 (ô 20 px)
const PX_PER_WORLD := 137.51
## ItemInventoryDisplay (ItemModelDefinition.h): giá trị mặc định khi Items/Models không ghi
const DEFAULT_ROT := [270.0, -10.0, 0.0]
const DEFAULT_ANCHOR := [0.5, 0.6]
const DEFAULT_SCALE := 0.0025
## đồ đang rê chuột: angle[1] = WorldTime * 0.45 (độ / ms)
const HOVER_TURN_DEG_PER_SEC := 450.0

## Khung vẽ ảnh đồ cho ô `rc` chiếm `sz` ô: nới ra PAD_CELLS ô mỗi phía (ảnh render có lề này)
static func overflow_rect(rc: Rect2, sz: Vector2i) -> Rect2:
	var cell := rc.size.x / maxf(float(sz.x), 1.0)
	return rc.grow(cell * PAD_CELLS)

static func anchor_of(g: int, n: int) -> Vector2:
	var inv = MuCatalogRes.item_model(g, n).get("inventory", {})
	var a = inv.get("anchor", DEFAULT_ANCHOR) if inv is Dictionary else DEFAULT_ANCHOR
	return Vector2(float(a[0]), float(a[1]))

## Tăng số này mỗi khi đổi cách vẽ ảnh đồ -> ảnh nướng cũ tự bị bỏ qua (vẽ trực tiếp) cho tới khi nướng lại
const ICON_VERSION := 16
static var _baked_state := -1

static func _baked_ok() -> bool:
	if _baked_state < 0:
		var vp := ProjectSettings.globalize_path(ICON_DIR + "version.txt")
		if FileAccess.file_exists(vp) and FileAccess.get_file_as_string(vp).strip_edges() == str(ICON_VERSION):
			_baked_state = 1

		else:
			_baked_state = 0
	return _baked_state == 1

static func baked_path(g: int, n: int) -> String:
	return "%s%02d_%03d.png" % [ICON_DIR, g, n]

## Texture ảnh đồ (ViewportTexture, dùng chung theo loại + cấp)
static func icon(tree: SceneTree, it: Dictionary) -> Texture2D:
	if tree == null:
		return null
	var g := int(it.get("group", 0))
	var n := int(it.get("number", 0))
	var lv := int(it.get("level", 0))
	var key := "%d:%d:%d:%s:%s" % [g, n, lv, str(bool(it.get("excellent", false))), str(bool(it.get("ancient", false)))]
	if _cache.has(key):
		return _cache[key]
	# ảnh đã nướng sẵn (cấp 0..2, không đổi màu) — chỉ dùng khi được nướng bằng ĐÚNG phiên bản cách vẽ hiện tại,
	# đọc thẳng file PNG (không qua bộ import của Godot nên không bị ảnh cũ trong cache)
	if lv < 3 and not bool(it.get("excellent", false)) and not bool(it.get("ancient", false)) and _baked_ok():
		var img := Image.load_from_file(ProjectSettings.globalize_path(baked_path(g, n)))
		if img != null and not img.is_empty():
			var bt := ImageTexture.create_from_image(img)
			_cache[key] = bt
			return bt
	var t := _render(tree, it, g, n, lv)
	_cache[key] = t
	return t

## Texture ảnh đồ dạng vuông đóng khung (cho danh mục / thẻ / GM picker / chợ)
## Tự căn giữa và xoay chéo các vũ khí dài để hiển thị to rõ, phủ đều ô vuông
static func catalog_icon(tree: SceneTree, it: Dictionary, px_size: int = 52) -> Texture2D:
	if tree == null:
		return null
	var g := int(it.get("group", 0))
	var n := int(it.get("number", 0))
	var lv := int(it.get("level", 0))
	var key := "cat:%d:%d:%d:%s:%s:%d" % [g, n, lv, str(bool(it.get("excellent", false))), str(bool(it.get("ancient", false))), px_size]
	if _cache.has(key):
		return _cache[key]
	var t := _render(tree, it, g, n, lv, false, Vector2i(px_size, px_size), false)
	_cache[key] = t
	return t

## Texture ảnh đồ xem trước chi tiết (cho ô Preview rộng)
## Tự căn giữa và xoay chéo theo tỉ lệ khung hình rộng để vũ khí phủ 85-90% khung hình
static func preview_icon(tree: SceneTree, it: Dictionary, sz: Vector2i = Vector2i(246, 100)) -> Texture2D:
	if tree == null:
		return null
	var g := int(it.get("group", 0))
	var n := int(it.get("number", 0))
	var lv := int(it.get("level", 0))
	var key := "prev:%d:%d:%d:%s:%s:%dx%d" % [g, n, lv, str(bool(it.get("excellent", false))), str(bool(it.get("ancient", false))), sz.x, sz.y]
	if _cache.has(key):
		return _cache[key]
	var t := _render(tree, it, g, n, lv, false, sz, true)
	_cache[key] = t
	return t

## Đồ đang được rê chuột: MU vẽ nó xoay vòng liên tục (ảnh 3D sống, không phải ảnh tĩnh)
static var _live_key := ""
static var _live_tex: Texture2D = null
static var _live_vp: SubViewport = null
static var _live_holder: Node3D = null
static var _live_rot: Array = []
static var _live_time := 0.0

static func live_icon(tree: SceneTree, it: Dictionary) -> Texture2D:
	var g := int(it.get("group", 0))
	var n := int(it.get("number", 0))
	var lv := int(it.get("level", 0))
	var key := "%d:%d:%d" % [g, n, lv]
	if key == _live_key and _live_vp != null and is_instance_valid(_live_vp):
		return _live_tex
	stop_live()
	_live_key = key
	_live_tex = _render(tree, it, g, n, lv, true)
	return _live_tex

static func spin(delta: float) -> void:
	if _live_holder != null and is_instance_valid(_live_holder) and _live_rot.size() == 3:
		_live_time += delta
		_live_holder.basis = _basis([_live_rot[0], fmod(_live_time * HOVER_TURN_DEG_PER_SEC, 360.0), _live_rot[2]])

static func stop_live() -> void:
	if _live_vp != null and is_instance_valid(_live_vp):
		MuModelRes.cleanup_geometry(_live_vp)
		_live_vp.queue_free()
	_live_vp = null
	_live_holder = null
	_live_time = 0.0
	_live_tex = null
	_live_key = ""

static func _render(tree: SceneTree, it: Dictionary, g: int, n: int, lv: int, live: bool = false, framed_size: Vector2i = Vector2i.ZERO, is_preview: bool = false) -> Texture2D:
	var path: String = MuCatalogRes.item_glb(g, n)
	# Giáp Rage Fighter vẽ trong túi bằng model riêng (ItemDisplay.cpp: ArmorInventoryModels / MonkSystem.cpp)
	var inv_glb: String = RF_ARMOR_INVENTORY_GLB.get("%d:%d" % [g, n], "")
	if inv_glb != "" and ResourceLoader.exists(inv_glb):
		path = inv_glb
	var inst := MuModelRes.instantiate(path) if path != "" else null
	if inst == null:
		return null
	var sz: Vector2i = MuItemsRes.size_of(it)
	var vp := SubViewport.new()
	var is_framed := (framed_size != Vector2i.ZERO)
	if is_framed:
		vp.size = framed_size * 2
	else:
		var pad := int(round(PX * PAD_CELLS))
		vp.size = sz * PX + Vector2i(pad, pad) * 2
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	# vẽ một lần (model + texture đã nạp xong khi load) rồi giữ ảnh
	var md0: Dictionary = MuCatalogRes.item_model(g, n)
	var anim := live or _animated(it, str(md0.get("renderStyle", "")) + str(md0.get("itemEffect", "")))
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if not anim:
		# Render đủ 3 khung hình để texture, xương và shader nạp trọn vẹn rồi dừng render (tiết kiệm GPU)
		var h := [3]
		var cb_ref := [Callable()]
		cb_ref[0] = func():
			h[0] -= 1
			if h[0] <= 0:
				if is_instance_valid(vp):
					vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
				if tree and tree.process_frame.is_connected(cb_ref[0]):
					tree.process_frame.disconnect(cb_ref[0])
		tree.process_frame.connect(cb_ref[0])
	var holder := Node3D.new()
	vp.add_child(holder)
	if live:
		_live_vp = vp
		_live_holder = holder
	holder.add_child(inst)
	var model: Dictionary = MuCatalogRes.item_model(g, n)
	var inv: Dictionary = model.get("inventory", {}) if model.get("inventory") is Dictionary else {}
	var rot: Array = inv.get("rotation", DEFAULT_ROT) if inv.get("rotation") is Array else DEFAULT_ROT
	if is_framed and (0 <= g and g <= 5):
		rot = rot.duplicate()
		rot[2] = 65.0 if is_preview else 40.0
	holder.basis = _basis(rot)
	if live:
		_live_rot = rot.duplicate()
	var fixed := not is_framed
	if fixed:
		# thân đồ vẽ trên bộ xương nhân vật: dịch xuống theo bodyHeight (đơn vị MU, trục Z)
		inst.position = Vector3(0, float(inv.get("bodyHeight", 0.0)) / 100.0, 0)
	# vật liệu + khung bao
	var style := str(model.get("renderStyle", ""))
	# itemEffect (ItemEffects.cpp): kiểu vẽ theo cấp / thời gian thay renderStyle
	var fxr: Dictionary = ItemStylesRes.resolve(style, str(model.get("itemEffect", "")), lv)
	style = str(fxr["style"])
	# Glow::GetLevel: một số đồ có mức phát sáng cố định (cánh = 0, Devil's Eye +7.. = 13...)
	lv = MuCatalogRes.glow_level(g, n, lv)
	var gi := _glow_info(it, g, n)
	gi["level"] = lv
	var aabb := AABB()
	var first := true
	var inven_tex_path := MuModelRes.inven_texture_path(g, n)
	var inven_override_tex: Texture2D = load(inven_tex_path) if inven_tex_path != "" and ResourceLoader.exists(inven_tex_path) else null
	for mi in MuModelRes.find_all(inst, "MeshInstance3D", []):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for s in m.mesh.get_surface_count():
			var smat: Material = _surface_material(m.mesh.surface_get_material(s), lv, style, s, fxr, inven_override_tex)
			if _needs_glow(gi) and smat is ShaderMaterial and (smat as ShaderMaterial).shader != HIDDEN_SHADER \
					and (smat as ShaderMaterial).shader != ADD_SHADER \
					and (not gi.has("meshes") or s in gi["meshes"]) and s != int(gi.get("hidden", -1)):
				# chép cả chuỗi next_pass (không sửa vật liệu dùng chung trong cache) rồi nối lớp phát sáng vào cuối
				var head: ShaderMaterial = _glow_base(smat as ShaderMaterial)
				var last: ShaderMaterial = head
				while last.next_pass != null:
					last.next_pass = (last.next_pass as ShaderMaterial).duplicate()
					last = last.next_pass as ShaderMaterial
				var gm: ShaderMaterial = MuModelRes.glow_material(m.mesh.surface_get_material(s), gi, inven_override_tex if s == 0 else null)
				gm.set_shader_parameter("fixed_light", 1.0)   # RenderObjectScreen: Light = (1,1,1)
				gm.set_shader_parameter("glow_gain_7", ICON_GLOW_GAIN_7)
				gm.set_shader_parameter("glow_gain_11", ICON_GLOW_GAIN_11)
				gm.set_shader_parameter("glow_gain_13", ICON_GLOW_GAIN_13)
				last.next_pass = gm
				smat = head
			m.set_surface_override_material(s, smat)
		var xf := holder.transform * _local(m, holder)
		var bb: AABB = xf * m.mesh.get_aabb()
		aabb = bb if first else aabb.merge(bb)
		first = false
	var ap := MuModelRes.find_first(inst, "AnimationPlayer") as AnimationPlayer
	if ap:
		if ap.has_animation("a000"):
			ap.play("a000")
			ap.advance(0.0)
		ap.stop()
	for skel in MuModelRes.find_all(inst, "Skeleton3D", []):
		(skel as Skeleton3D).force_update_all_bone_transforms()
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.near = 0.01
	if fixed:
		# RenderItem3D: tỉ lệ cố định "scale", gốc model đặt tại anchor + offset của ô (tỉ lệ theo rộng / cao)
		var anchor: Array = inv.get("anchor", DEFAULT_ANCHOR) if inv.get("anchor") is Array else DEFAULT_ANCHOR
		var off: Array = inv.get("offset", [0.0, 0.0]) if inv.get("offset") is Array else [0.0, 0.0]
		var ppu_world: float = PX_PER_WORLD * (float(PX) / 20.0)
		var ppu: float = float(inv.get("scale", DEFAULT_SCALE)) * ppu_world * 100.0
		# anchor / offset tính theo ô thật (không tính lề); lề đối xứng nên tâm ảnh vẫn là tâm ô
		var w := float(sz.x * PX)
		var h := float(sz.y * PX)
		# Tự động co tỉ lệ vừa vặn khung ô, tránh việc các món đồ mặc (giáp, quần, nón...) bị quá to tràn lấn sang ô khác
		# Giống client gốc (RenderItem3D): vẽ đúng tỉ lệ "scale" trong dữ liệu, KHÔNG co cho vừa ô —
		# đồ lớn (giáp, cánh, vũ khí...) được phép tràn ra ngoài ô.
		# offset cộng vào vị trí THẾ GIỚI (x phải, y lên) ở độ sâu 200
		var px: float = float(anchor[0]) * w + float(off[0]) * ppu_world
		var py: float = float(anchor[1]) * h - float(off[1]) * ppu_world
		cam.size = float(vp.size.y) / ppu
		cam.position = Vector3((w * 0.5 - px) / ppu, (py - h * 0.5) / ppu, 50.0)
		cam.far = 200.0
	else:
		var aspect := float(vp.size.x) / float(vp.size.y)
		var need_h := maxf(aabb.size.y, aabb.size.x / aspect) * 1.15
		cam.size = maxf(need_h, 0.01)
		var c := aabb.get_center()
		cam.position = Vector3(c.x, c.y, aabb.end.z + 10.0)
		cam.far = aabb.size.z + 20.0
	vp.add_child(cam)
	_get_host(tree).add_child.call_deferred(vp)
	return vp.get_texture()

## Vật liệu nền khi có lớp ánh kim chồng lên. Vật liệu alpha (blend_mix, ghi ALPHA) nằm ở hàng vẽ trong suốt nên
## vẽ SAU / đè mất lớp ánh kim (next_pass) -> đổi sang bản mờ-cắt (alpha test) cùng texture: áo Summoner (texture PNG có alpha,
## texture che da InvenArmorMale4x), áo choàng, cánh... mới giữ được ánh kim như đồ thường.
static func _glow_base(m: ShaderMaterial) -> ShaderMaterial:
	if m.shader != ICON_ALPHA_SHADER:
		return m.duplicate()
	var o := ShaderMaterial.new()
	o.shader = ICON_SHADER
	o.set_shader_parameter("albedo_tex", m.get_shader_parameter("albedo_tex"))
	o.set_shader_parameter("alpha_cut", 0.45)
	o.set_shader_parameter("tint", m.get_shader_parameter("tint"))
	o.set_shader_parameter("tint_pulse", m.get_shader_parameter("tint_pulse"))
	o.next_pass = m.next_pass
	return o

## Vật liệu 1 surface trong ảnh đồ (có kiểu vẽ riêng nếu đồ có renderStyle)
static func HIDDEN_SHADER_MAT() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = HIDDEN_SHADER
	return m

## Màu theo cấp cho ảnh đồ có kiểu vẽ riêng: giữ sắc (+3/+4 đỏ, +5/+6 xanh) nhưng không làm tối,
## giống icon_tint_mix = 0.5 của mu_item_icon.gdshader, không nhấp nháy
static func icon_tint(level: int) -> Color:
	var t: Color = MuModelRes.level_tint(level)
	var mx := maxf(maxf(t.r, t.g), maxf(t.b, 0.001))
	return Color(1.0, 1.0, 1.0).lerp(Color(t.r / mx, t.g / mx, t.b / mx), 0.5)

static func _surface_material(src: Material, level: int, style: String, mesh: int, fxr: Dictionary = {}, inven_tex: Texture2D = null) -> Material:
	var stem := MuModelRes.tex_stem(src)
	if MuModelRes.is_skin_or_hair(stem):
		return HIDDEN_SHADER_MAT()
	if inven_tex != null and mesh == 0:
		var tint: Color = MuModelRes.level_tint(level)
		var key := "inven|%d|%d|%.3f,%.3f,%.3f,%.2f" % [inven_tex.get_instance_id(), level, tint.r, tint.g, tint.b, tint.a]
		if _mats.has(key):
			return _mats[key]
		var m := ShaderMaterial.new()
		m.shader = ICON_ALPHA_SHADER
		m.set_shader_parameter("albedo_tex", inven_tex)
		m.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
		m.set_shader_parameter("tint_pulse", 1.0 if tint.a < 0.99 else 0.0)
		_mats[key] = m
		return m
	var bright := MuModelRes.mesh_script(stem) == "bright"
	var bp: Vector3 = fxr.get("blend_pulse", Vector3.ZERO)
	if bp != Vector3.ZERO and style == "" and bright:
		# itemEffect redSpirit / wingsOfSoul...: mesh sáng nhấp nháy
		var pm := (_material(src, level) as ShaderMaterial).duplicate() as ShaderMaterial
		if pm.shader == MuModelRes.CHAR_ADD_SHADER:
			pm.set_shader_parameter("sin_pulse", bp)
		return pm
	if style != "":
		var jm = ItemStylesRes.json_materials(style, mesh, src, icon_tint(level), 1.0,
			bright, MuModelRes.terrain_light())
		if jm != null and bool(fxr.get("fx_base", false)) and not (jm as Array).is_empty():
			# itemEffect "Applied": lớp hiệu ứng rồi vẽ món đồ như thường / theo renderStyle
			var bs := str(fxr.get("base_style", ""))
			var bj = ItemStylesRes.json_materials(bs, mesh, src, icon_tint(level), 1.0, bright,
				MuModelRes.terrain_light()) if bs != "" else null
			jm = (jm as Array) + (bj if bj != null else [(_material(src, level) as ShaderMaterial).duplicate()])
		if jm != null:
			if (jm as Array).is_empty():
				return HIDDEN_SHADER_MAT()
			for i in range((jm as Array).size() - 1):
				(jm[i] as ShaderMaterial).next_pass = jm[i + 1]
			return jm[0]
	var passes: Array = ItemStylesRes.passes_for(style, mesh) if style != "" else []
	if passes.is_empty():
		return _material(src, level)
	var chain: Array = []
	for e in passes:
		var kind := str(e[1])
		var par: Dictionary = e[2] if e.size() > 2 else {}
		var bm := src as BaseMaterial3D
		var tex: Texture2D = bm.albedo_texture if bm else null
		if kind == "hide":
			continue
		if kind == "tex":
			chain.append(_material(src, level, float(par.get("light_mul", 1.0))))
		elif kind == "add" or kind == "flame":
			var m := ShaderMaterial.new()
			m.shader = ADD_SHADER
			m.set_shader_parameter("albedo_tex", MuModelRes.fx(str(par["tex"])) if par.has("tex") else tex)
			var sc: Array = par.get("scroll", [0.0, 0.0])
			m.set_shader_parameter("uv_scroll", Vector2(sc[0], sc[1]))
			var l: Array = par.get("light", [1.0, 1.0, 1.0])
			m.set_shader_parameter("light", Vector3(l[0], l[1], l[2]))
			m.set_shader_parameter("flame", 1.0 if kind == "flame" else 0.0)
			chain.append(m)
		# "chrome": cần môi trường phản chiếu 3D, bỏ qua trong ảnh 2D
	if chain.is_empty():
		return _material(src, level)
	for i in range(chain.size() - 1):
		chain[i] = (chain[i] as ShaderMaterial).duplicate()
		(chain[i] as ShaderMaterial).next_pass = chain[i + 1]
	return chain[0]

## Nướng ẢNH TẤT CẢ ĐỒ ra assets/mu/icons/GG_NNN.png (cấp 0) — gọi từ MU Tools. Trả về số ảnh đã lưu.
static func bake_all(tree: SceneTree, progress: Callable = Callable()) -> int:
	MuCatalogRes.ensure_loaded()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ICON_DIR))
	var keys: Array = MuCatalogRes.item_models.keys()
	var saved := 0
	var batch: Array = []
	var done := 0
	for k in keys:
		var parts: PackedStringArray = str(k).split(":")
		var g := int(parts[0])
		var n := int(parts[1])
		if MuCatalogRes.item_glb(g, n) == "":
			continue
		var it := {"group": g, "number": n, "level": 0}
		var t := _render(tree, it, g, n, 0)
		if t:
			batch.append([g, n, t])
		if batch.size() >= 24:
			saved += await _flush(tree, batch)
			batch.clear()
		done += 1
		if progress.is_valid():
			progress.call(done, keys.size())
	saved += await _flush(tree, batch)
	var f := FileAccess.open(ProjectSettings.globalize_path(ICON_DIR + "version.txt"), FileAccess.WRITE)
	if f:
		f.store_string(str(ICON_VERSION))
		f.close()
	_baked_state = -1
	_cache.clear()
	return saved

static func _flush(tree: SceneTree, batch: Array) -> int:
	for _i in 4:
		await tree.process_frame
	var n := 0
	for e in batch:
		var tex: Texture2D = e[2]
		var img := tex.get_image()
		if img:
			img.save_png(ProjectSettings.globalize_path(baked_path(e[0], e[1])))
			n += 1
	for c in _get_host(tree).get_children():
		MuModelRes.cleanup_geometry(c)
		c.queue_free()
	return n

static func _local(n: Node3D, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = n
	while cur and cur != root:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t
