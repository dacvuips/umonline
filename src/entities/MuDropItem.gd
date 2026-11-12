extends Area3D
class_name MuDropItem

## Vật phẩm rơi trên đất trong MU Online (Zen, Ngọc Bless, Soul, Chaos, Trang bị, Bình máu/mana...)
## Chuẩn theo server OpenMU: Hỗ trợ nhặt vào túi đồ thật, xoay tròn lấp lánh, âm thanh gốc, màu chữ theo phẩm cấp.

signal item_picked_up(item: MuDropItem)
signal item_despawned(item: MuDropItem)

enum ItemCategory {
	ZEN,
	BLESS,
	SOUL,
	CHAOS,
	EQUIPMENT,
	POTION
}

const MuCatalogRes = preload("res://src/mu/MuCatalog.gd")
const MuItemsRes = preload("res://src/mu/MuItems.gd")
const MuModelRes = preload("res://src/mu/MuModel.gd")
const MuItemStylesRes = preload("res://src/mu/MuItemStyles.gd")
const MuItemFxRes = preload("res://src/mu/MuItemFx.gd")
const MuCharModelRes = preload("res://src/mu/MuCharacterModel.gd")

@export var item_dict: Dictionary = {}:
	set(v):
		item_dict = v
		_resolve_data()
@export var item_name: String = "Zen"
@export var category: ItemCategory = ItemCategory.ZEN
@export var amount: int = 500
@export var is_fresh_drop: bool = true
## Thời gian tồn tại trên đất trước khi tự mất (chuẩn server gốc OpenMU / Webzen: 60s)
@export var despawn_duration: float = 60.0
## Bật/tắt tự hủy theo thời gian
@export var can_despawn: bool = true

var is_picked: bool = false
var is_despawned: bool = false
var pickup_delay: float = 0.0
var _elapsed_ground_time: float = 0.0
var _base_y: float = 0.2
var _time_offset: float = 0.0
var _item_mat: StandardMaterial3D = null
var _visual_node: Node3D = null
var _ground_basis: Basis = Basis.IDENTITY
var _ground_offset: Vector3 = Vector3.ZERO
var _is_shield: bool = false
var _label_node: Label3D = null

var _is_falling: bool = false
var _fall_start_pos: Vector3 = Vector3.ZERO
var _fall_target_pos: Vector3 = Vector3.ZERO
var _fall_elapsed: float = 0.0
var _fall_duration: float = 0.48
var _fall_g: float = 30.0
var _fall_v0: float = 0.0

func setup_drop(target_pos: Vector3, from_pos: Vector3 = Vector3.ZERO) -> void:
	_fall_target_pos = target_pos
	_fall_start_pos = from_pos
	is_fresh_drop = true

func _ready() -> void:
	_time_offset = randf_range(0.0, 10.0)
	_resolve_data()
	_setup_visual()
	_setup_label()
	_setup_collision()
	
	if is_fresh_drop:
		_start_drop_animation()
	else:
		_finish_drop_instantly()

	# Xử lý khi người chơi bước vào vùng nhặt tự động
	body_entered.connect(_on_body_entered)

func _start_drop_animation() -> void:
	if _fall_target_pos == Vector3.ZERO:
		_fall_target_pos = global_position if is_inside_tree() else position
	if _fall_start_pos == Vector3.ZERO:
		# Chiều cao rơi chuẩn trong ZzzObject.cpp: RequestTerrainHeight + 180.f (~1.8m)
		_fall_start_pos = _fall_target_pos + Vector3(0.0, 1.8, 0.0)
	
	_fall_elapsed = 0.0
	_fall_duration = 0.48
	_fall_g = 30.0
	var delta_y := _fall_target_pos.y - _fall_start_pos.y
	_fall_v0 = (delta_y + 0.5 * _fall_g * _fall_duration * _fall_duration) / _fall_duration
	
	_is_falling = true
	if _label_node:
		_label_node.visible = false
	# Client gốc (CreateItemDrop / CreateMoneyDrop, isFreshDrop): âm thanh phát NGAY khi vật phẩm xuất hiện
	# (ngọc: Jewel01, Đá Nguyên Thủy: Jewel02, Zen: DropGold01, còn lại: DropItem01), không đợi chạm đất
	_play_drop_sound()
	
	if is_inside_tree():
		global_position = _fall_start_pos
	else:
		position = _fall_start_pos

func _finish_drop_instantly() -> void:
	_is_falling = false
	if _visual_node:
		_visual_node.basis = _ground_basis
		_visual_node.position = _ground_offset
	if _label_node:
		_label_node.visible = true

func _update_falling(delta: float) -> void:
	_fall_elapsed += delta
	var t_clamped := clampf(_fall_elapsed, 0.0, _fall_duration)
	var t_norm := t_clamped / _fall_duration
	
	# Bay ngang từ vị trí ném tới vị trí tiếp đất
	var cur_x := lerpf(_fall_start_pos.x, _fall_target_pos.x, t_norm)
	var cur_z := lerpf(_fall_start_pos.z, _fall_target_pos.z, t_norm)
	
	# Vật lý rơi chuẩn MU: y(t) = y0 + v0*t - 0.5*g*t^2
	var cur_y := _fall_start_pos.y + _fall_v0 * t_clamped - 0.5 * _fall_g * t_clamped * t_clamped
	
	if is_inside_tree():
		global_position = Vector3(cur_x, cur_y, cur_z)
	else:
		position = Vector3(cur_x, cur_y, cur_z)
	
	# Xoay nhào lộn chuẩn HandleItemFalling trong ZzzObject.cpp: Angle = -Gravity * 10
	var vy := _fall_v0 - _fall_g * t_clamped
	var gravity_mu := vy / 0.25 # Quy đổi m/s sang đơn vị Gravity của client C++ gốc
	var tumble_pitch := deg_to_rad(-gravity_mu * 10.0)
	
	if _visual_node:
		if _is_shield:
			_visual_node.basis = _ground_basis.rotated(Vector3.UP, tumble_pitch)
		else:
			_visual_node.basis = _ground_basis.rotated(Vector3.RIGHT, tumble_pitch)
	
	# Khi tiếp đất
	if _fall_elapsed >= _fall_duration or cur_y <= _fall_target_pos.y:
		_is_falling = false
		if is_inside_tree():
			global_position = _fall_target_pos
		else:
			position = _fall_target_pos
		
		if _visual_node:
			_visual_node.basis = _ground_basis
			_visual_node.position = _ground_offset
			
			# Hiệu ứng nảy nhẹ khi va chạm mặt đất (micro-bounce)
			if is_inside_tree():
				var tw := create_tween()
				if tw:
					tw.tween_property(_visual_node, "position:y", _ground_offset.y + 0.06, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
					tw.tween_property(_visual_node, "position:y", _ground_offset.y, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		
		if _label_node:
			_label_node.visible = true

## Đá Nguyên Thủy (14:41) dùng âm riêng (Jewel_Sound.wav) như client gốc
func _is_gemstone() -> bool:
	return int(item_dict.get("group", 0)) == 14 and int(item_dict.get("number", 0)) == 41

func _play_drop_sound() -> void:
	if MuAudioManager:
		var snd_pos := global_position if is_inside_tree() else position
		if _is_gemstone():
			MuAudioManager.play_gemstone_sound(snd_pos)
		elif category in [ItemCategory.BLESS, ItemCategory.SOUL, ItemCategory.CHAOS]:
			MuAudioManager.play_jewel_drop(snd_pos)
		elif category == ItemCategory.ZEN:
			MuAudioManager.play_coin_drop(snd_pos)
		else:
			MuAudioManager.play_item_drop(snd_pos)

func _resolve_data() -> void:
	if not item_dict.is_empty():
		item_name = MuItemsRes.display_name(item_dict)
		var g := int(item_dict.get("group", 0))
		var n := int(item_dict.get("number", 0))
		_is_shield = (g == 6)
		if MuItemsRes.is_jewel(item_dict):
			if g == 14 and n == 13:
				category = ItemCategory.BLESS
			elif g == 14 and n == 14:
				category = ItemCategory.SOUL
			elif g == 12 and n == 15:
				category = ItemCategory.CHAOS
			else:
				category = ItemCategory.BLESS
		elif MuItemsRes.is_potion(item_dict):
			category = ItemCategory.POTION
		else:
			category = ItemCategory.EQUIPMENT
	else:
		_is_shield = false

func _setup_visual() -> void:
	# Thử nạp model 3D thật từ catalog nếu là trang bị/vật phẩm
	if not item_dict.is_empty() and category != ItemCategory.ZEN:
		var g := int(item_dict.get("group", 0))
		var n := int(item_dict.get("number", 0))
		var glb_path := MuCatalogRes.item_glb(g, n)
		if glb_path != "" and ResourceLoader.exists(glb_path):
			var inst := MuModelRes.instantiate(glb_path)
			if inst:
				inst.name = "ItemMesh"
				
				# Góc nằm trên đất chuẩn MU Online (ItemGroundDisplay trong ZzzObject.cpp)
				var md: Dictionary = MuCatalogRes.item_model(g, n)
				var ground: Dictionary = md.get("ground", {})
				var rot_arr: Array = ground.get("rotation", [0.0, 0.0, -45.0])
				# Giáp, quần, găng, giày, cánh phải xoay nằm ngang phẳng trên đất (pitch 270°)
				if g in [8, 9, 10, 11, 12] and not ground.has("rotation"):
					rot_arr = [270.0, 0.0, -45.0]
				
				var sc_val: float = float(ground.get("scale", 1.0))
				if sc_val <= 0.0 or sc_val > 10.0:
					sc_val = 1.0
				var t := MuCharModelRes._mu_matrix_to_transform(rot_arr, Vector3.ZERO)
				inst.basis = t.basis.scaled(Vector3.ONE * sc_val)
				
				# Đo AABB sau khi xoay để đặt vật phẩm nằm sát mặt đất (3cm) và chính giữa XZ
				var aabb := _calc_mesh_aabb(inst)
				inst.position.x = -aabb.get_center().x
				inst.position.z = -aabb.get_center().z
				inst.position.y = -aabb.position.y + 0.03
				
				var glow_col := MuItemsRes.name_color(item_dict)
				var it_lvl := int(item_dict.get("level", 0))
				var glow_opts := {
					"level": MuCatalogRes.glow_level(g, n, it_lvl),
					"excellent": bool(item_dict.get("excellent", false)),
					"ancient": int(item_dict.get("ancient", 0)) > 0,
					"hide_skin": true,
					"group": g,
					"number": n
				}
				# kiểu vẽ riêng (renderStyle) + hiệu ứng vật phẩm (itemEffect) theo cấp
				MuItemStylesRes.apply_to_glow(glow_opts, str(md.get("renderStyle", "")), str(md.get("itemEffect", "")), it_lvl)
				MuModelRes.apply_materials(inst, glow_col, glow_opts)
				add_child(inst)
				_visual_node = inst
				_ground_basis = inst.basis
				_ground_offset = inst.position
				# itemEffect sinh đốm sáng trên đất (Devil's Key / Invitation, Rena)
				var eff := str(md.get("itemEffect", ""))
				if MuItemFxRes.has_spawn(eff) and g != MuCatalogRes.GROUP_WING:
					var ifx = MuItemFxRes.new()
					ifx.name = "ItemFx"
					add_child(ifx)
					if not ifx.setup(inst, item_dict, eff, false):
						ifx.queue_free()
				return

	# Zen: đống đồng xu vàng (RenderZen trong ZzzObject.cpp)
	if category == ItemCategory.ZEN and item_dict.is_empty() and _setup_coin_heap():
		return

	# Fallback khối 3D phát sáng đặc trưng của MU Online
	var mesh_node = CSGBox3D.new()
	mesh_node.name = "ItemMesh"
	
	var mat = StandardMaterial3D.new()
	mat.emission_enabled = true
	
	match category:
		ItemCategory.ZEN:
			mesh_node.size = Vector3(0.35, 0.15, 0.25) # Thỏi vàng
			mat.albedo_color = Color(1.0, 0.85, 0.2)
			mat.emission = Color(0.9, 0.7, 0.1)
			mat.emission_energy_multiplier = 2.2
		ItemCategory.BLESS:
			mesh_node.size = Vector3(0.3, 0.45, 0.3) # Viên ngọc Ước Nguyện
			mat.albedo_color = Color(0.9, 0.2, 0.7) # Màu tím hồng Bless
			mat.emission = Color(0.8, 0.1, 0.6)
			mat.emission_energy_multiplier = 3.0
		ItemCategory.SOUL:
			mesh_node.size = Vector3(0.3, 0.45, 0.3)
			mat.albedo_color = Color(0.2, 0.5, 1.0) # Màu xanh lam Soul
			mat.emission = Color(0.1, 0.4, 0.9)
			mat.emission_energy_multiplier = 3.0
		ItemCategory.CHAOS:
			mesh_node.size = Vector3(0.35, 0.35, 0.35)
			mat.albedo_color = Color(0.3, 0.9, 0.4) # Màu xanh lục Chaos
			mat.emission = Color(0.2, 0.8, 0.3)
			mat.emission_energy_multiplier = 3.0
		ItemCategory.POTION:
			var n := int(item_dict.get("number", 0))
			mesh_node.size = Vector3(0.25, 0.35, 0.25)
			if n in [0, 1, 2, 3]: # Máu hoặc Táo
				mat.albedo_color = Color(1.0, 0.2, 0.2)
				mat.emission = Color(0.8, 0.1, 0.1)
			elif n in [4, 5, 6]: # Mana
				mat.albedo_color = Color(0.2, 0.4, 1.0)
				mat.emission = Color(0.1, 0.3, 0.8)
			else: # Antidote
				mat.albedo_color = Color(0.2, 0.85, 0.3)
				mat.emission = Color(0.1, 0.7, 0.2)
			mat.emission_energy_multiplier = 2.0
		ItemCategory.EQUIPMENT, _:
			mesh_node.size = Vector3(0.4, 0.3, 0.4)
			var is_exc := bool(item_dict.get("excellent", false))
			if is_exc:
				# Đồ Hoàn Hảo phát sáng xanh ngọc lục bảo rực rỡ
				mat.albedo_color = Color(0.1, 1.0, 0.45)
				mat.emission = Color(0.05, 0.9, 0.35)
				mat.emission_energy_multiplier = 3.5
			else:
				var col := MuItemsRes.name_color(item_dict)
				mat.albedo_color = col
				mat.emission = col * 0.7
				mat.emission_energy_multiplier = 1.8

	_item_mat = mat
	mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_node.material_override = mat
	mesh_node.position = Vector3(0, mesh_node.size.y * 0.5 + 0.02, 0)
	add_child(mesh_node)
	_visual_node = mesh_node
	_ground_basis = mesh_node.basis
	_ground_offset = mesh_node.position

## Đống xu Zen: số xu = clamp(sqrt(zen) / 2, 3, 12); mỗi xu quay ngẫu nhiên, rải trong bán kính (số xu + 20) MU
## quanh tâm rồi xếp chồng lên nhau (BeginRenderCoinHeap / AddToCoinHeap).
const COIN_GLB := "res://assets/mu/Item/Gold01.glb"
const MAX_COINS := 12

func _setup_coin_heap() -> bool:
	if not ResourceLoader.exists(COIN_GLB):
		return false
	var coin_count := clampi(int(sqrt(float(maxi(amount, 0))) / 2.0), 3, MAX_COINS)
	var heap := Node3D.new()
	heap.name = "ItemMesh"
	var rng := RandomNumberGenerator.new()
	rng.seed = int(amount) * 7919 + get_instance_id()
	var max_r := float(coin_count + 20) / 100.0
	var placed: Array[Vector3] = []
	for i in coin_count:
		var coin := MuModelRes.instantiate(COIN_GLB)
		if coin == null:
			break
		MuModelRes.apply_materials(coin)
		var a := rng.randf() * TAU
		var r := rng.randf() * max_r
		var pos := Vector3(cos(a) * r, 0.0, sin(a) * r)
		# xếp chồng: coin nằm trên các xu đã có ở gần
		var h := 0.0
		for q in placed:
			if Vector2(q.x - pos.x, q.z - pos.z).length() < 0.10:
				h = maxf(h, q.y + 0.025)
		pos.y = h + 0.02
		placed.append(pos)
		coin.position = pos
		coin.rotation.y = rng.randf() * TAU
		heap.add_child(coin)
	if heap.get_child_count() == 0:
		heap.free()
		return false
	add_child(heap)
	_visual_node = heap
	_ground_basis = heap.basis
	_ground_offset = heap.position
	return true

func _calc_mesh_aabb(root: Node3D) -> AABB:
	var aabb := AABB()
	var first := true
	for mi in MuModelRes.find_all(root, "MeshInstance3D", []):
		var m := (mi as MeshInstance3D).mesh
		if m:
			var xform := Transform3D(root.basis, Vector3.ZERO) * (mi as MeshInstance3D).transform
			var box := xform * m.get_aabb()
			if first:
				aabb = box
				first = false
			else:
				aabb = aabb.merge(box)
	return aabb

func _exit_tree() -> void:
	if has_node("ItemMesh"):
		var mesh_node = get_node("ItemMesh") as GeometryInstance3D
		if mesh_node:
			mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mesh_node.material_override = null

func _setup_label() -> void:
	var lbl = Label3D.new()
	lbl.name = "ItemLabel"
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.font_size = 22
	lbl.outline_size = 5
	lbl.outline_modulate = Color.BLACK
	
	var label_y := 0.45
	if _visual_node:
		if _visual_node is CSGBox3D:
			label_y = _visual_node.position.y + (_visual_node as CSGBox3D).size.y * 0.5 + 0.2
		else:
			var aabb := _calc_mesh_aabb(_visual_node)
			label_y = maxf(label_y, _visual_node.position.y + aabb.end.y + 0.15)
	lbl.position = Vector3(0, label_y, 0)
	
	if category == ItemCategory.ZEN:
		lbl.text = "Zen (%s)" % MuItemsRes.format_zen(amount)
		lbl.modulate = Color(1.0, 0.9, 0.35)
	else:
		if not item_dict.is_empty():
			lbl.text = MuItemsRes.display_name(item_dict)
			lbl.modulate = MuItemsRes.name_color(item_dict)
		else:
			lbl.text = item_name
			if category == ItemCategory.BLESS:
				lbl.modulate = Color(1.0, 0.4, 0.9)
			elif category == ItemCategory.SOUL:
				lbl.modulate = Color(0.4, 0.8, 1.0)
			elif category == ItemCategory.CHAOS:
				lbl.modulate = Color(0.4, 1.0, 0.5)
			else:
				lbl.modulate = Color.WHITE

	_label_node = lbl
	if _is_falling:
		lbl.visible = false
	add_child(lbl)

func _setup_collision() -> void:
	var col = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 1.3 # Bán kính tự động nhặt
	col.shape = sphere
	col.position = Vector3(0, 0.3, 0)
	add_child(col)

func _process(delta: float) -> void:
	if is_picked or is_despawned:
		return
	if pickup_delay > 0.0:
		pickup_delay = maxf(0.0, pickup_delay - delta)
	var t = Time.get_ticks_msec() * 0.001 + _time_offset
	# Vật phẩm rớt nằm phẳng trên đất, đứng yên không xoay / không bay bồng bềnh
	if _item_mat:
		_item_mat.emission_energy_multiplier = 2.0 + sin(t * 3.5) * 0.6
	
	if _is_falling:
		_update_falling(delta)
	elif can_despawn:
		_update_despawn(delta)

func _update_despawn(delta: float) -> void:
	_elapsed_ground_time += delta
	var time_left: float = despawn_duration - _elapsed_ground_time
	
	if time_left <= 0.0:
		despawn()
		return
	
	# Trong 10 giây cuối cùng, vật phẩm và nhãn nhấp nháy báo hiệu sắp hết hạn
	if time_left <= 10.0:
		var blink_freq: float = 8.0 if time_left <= 3.0 else 4.0
		var is_vis: bool = fmod(_elapsed_ground_time * blink_freq, 1.0) < 0.5
		if _visual_node:
			_visual_node.visible = is_vis
		if _label_node:
			_label_node.visible = is_vis

## Làm biến mất vật phẩm khi hết thời gian tồn tại trên đất (hoặc nhận gói 0x21 từ Server)
func despawn(instant: bool = false) -> void:
	if is_picked or is_despawned:
		return
	is_despawned = true
	emit_signal("item_despawned", self)
	
	if _visual_node:
		_visual_node.visible = true
	if _label_node:
		_label_node.visible = true
	
	# Vô hiệu hóa collision để không thể nhặt khi đang tan biến
	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", true)
	
	if instant or not is_inside_tree():
		queue_free()
		return
	
	var tween = create_tween()
	if tween:
		tween.set_parallel(true)
		tween.tween_property(self, "scale", Vector3.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		if _label_node:
			tween.tween_property(_label_node, "modulate:a", 0.0, 0.2)
		tween.chain().tween_callback(queue_free)
	else:
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	if body is MuPlayer and not is_picked and not is_despawned and pickup_delay <= 0.0 and not _is_falling:
		pickup(body)

func pickup(player: MuPlayer) -> void:
	if is_picked or is_despawned:
		return
	
	var tree := get_tree()
	var hud = tree.get_first_node_in_group("HUD") if tree else null
	if not hud and get_parent():
		var hud_node = get_parent().get_node_or_null("MuHud")
		if hud_node is MuHud:
			hud = hud_node

	if category == ItemCategory.ZEN:
		is_picked = true
		emit_signal("item_picked_up", self)
		player.add_zen(amount)
		if MuAudioManager:
			MuAudioManager.play_coin_pickup()
		print("[MuDropItem] Nhặt được %s Zen! Tổng Zen: %s" % [MuItemsRes.format_zen(amount), MuItemsRes.format_zen(player.zen)])
		if hud:
			hud.show_pickup_notification("+%s Zen" % MuItemsRes.format_zen(amount), Color(1.0, 0.9, 0.3))
	else:
		# Nhặt vật phẩm vào túi đồ 8x8 thực tế của người chơi
		if not item_dict.is_empty():
			if not player.inv_add(item_dict):
				# Túi đồ đã đầy, không thể nhặt
				if hud:
					hud.show_pickup_notification("Hành trang đã đầy!", Color(1.0, 0.3, 0.3))
				return
		else:
			player.inventory_items.append(item_name)
		
		is_picked = true
		emit_signal("item_picked_up", self)
		
		if MuAudioManager:
			# client gốc (ReceiveGetItem): ngọc = eGem.wav, Đá Nguyên Thủy = Jewel_Sound.wav, còn lại pGetItem.wav
			if _is_gemstone():
				MuAudioManager.play_gemstone_sound()
			elif not item_dict.is_empty() and MuItemsRes.is_jewel(item_dict):
				MuAudioManager.play_jewel_drop()
			else:
				MuAudioManager.play_item_pickup()
			
		var disp_name := MuItemsRes.display_name(item_dict) if not item_dict.is_empty() else item_name
		var col: Color = MuItemsRes.name_color(item_dict) if not item_dict.is_empty() else Color(1.0, 1.0, 1.0)
		print("[MuDropItem] Nhặt được: %s" % disp_name)
		if hud:
			hud.show_pickup_notification("Nhặt được: " + disp_name, col)
	
	# Hiệu ứng bay vào người chơi & biến mất
	if not is_inside_tree():
		queue_free()
		return
	var tween = create_tween()
	if tween:
		tween.tween_property(self, "global_position:y", global_position.y + 0.8, 0.2)
		tween.tween_property(self, "scale", Vector3.ZERO, 0.15)
		tween.tween_callback(queue_free)

func _input_event(_camera: Camera3D, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	var tree := get_tree()
	if not tree:
		return
	var item_ui = tree.get_first_node_in_group("MuItemUi")
	if item_ui and not item_ui.held.is_empty():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var player = tree.get_first_node_in_group("Player")
		if player and not is_picked and not is_despawned and pickup_delay <= 0.0 and not _is_falling:
			pickup(player)
