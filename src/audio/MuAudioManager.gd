extends Node
class_name MuAudioManager

## Hệ thống Quản lý Âm Thanh MU Online (Gốc từ Season 9)
## Tích hợp trực tiếp toàn bộ 1013+ file âm thanh chuẩn WAV của game gốc:
## - Các đòn đánh, vung kiếm, chém trúng quái (Melee Hits, Swings)
## - Kỹ năng chiến binh & phép thuật (Twisting Slash, Fireball, Magic)
## - Âm thanh quái vật đầy đủ 547 loài quái (Idle, Attack, Pain, Die) theo chuẩn 3D Spatial Audio
## - Âm thanh vật phẩm huyền thoại: Tiếng KENG ngọc rơi (Jewel of Bless/Soul), rơi đồ, rơi zen, nhặt đồ, uống potion
## - Âm thanh giao diện (Click button, mở túi đồ / cửa sổ, Level Up)
## Tự động nạp trực tiếp PCM WAV không phụ thuộc file .import của Godot.

static var instance: MuAudioManager = null

const SOUND_DIR := "res://assets/mu/Sound/"
const MONSTER_SOUND_MAP_PATH := "res://assets/mu/catalog/Monsters/monster_sounds_map.json"

# Pool players
var players_2d: Array[AudioStreamPlayer] = []
var max_players_2d: int = 10
var current_idx_2d: int = 0

var players_3d: Array[AudioStreamPlayer3D] = []
var max_players_3d: int = 20
var current_idx_3d: int = 0

# Cache bộ nhớ AudioStreamWAV (tránh nạp lại nhiều lần từ ổ đĩa)
var _wav_cache: Dictionary = {}

# Dữ liệu âm quái vật ánh xạ từ Sounds.json và Monsters.json
var _monster_by_id: Dictionary = {}
var _monster_by_name: Dictionary = {}

# Danh sách file âm thanh gốc định sẵn
const SWING_SOUNDS := [
	"eSwingWeapon1.wav",
	"eSwingWeapon2.wav",
	"eSwingLightSword.wav"
]

const MELEE_HIT_SOUNDS := [
	"eMeleeHit1.wav",
	"eMeleeHit2.wav",
	"eMeleeHit3.wav",
	"eMeleeHit4.wav",
	"eMeleeHit5.wav"
]

static func get_instance() -> MuAudioManager:
	if instance == null:
		var tree = Engine.get_main_loop() as SceneTree
		if tree and tree.root:
			var node = MuAudioManager.new()
			node.name = "MuAudioManager"
			tree.root.add_child.call_deferred(node)
			instance = node
	return instance

func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS

	# 1. Tạo Pool 2D AudioStreamPlayer (cho UI, Pickup, BGM, Local sounds)
	for i in range(max_players_2d):
		var p = AudioStreamPlayer.new()
		p.name = "Player2D_%d" % i
		add_child(p)
		players_2d.append(p)

	# 2. Tạo Pool 3D AudioStreamPlayer3D (cho Quái vật, Đòn đánh, Nổ trong không gian 3D)
	for i in range(max_players_3d):
		var p = AudioStreamPlayer3D.new()
		p.name = "Player3D_%d" % i
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.unit_size = 4.0
		p.max_distance = 35.0
		p.max_db = 3.0
		add_child(p)
		players_3d.append(p)

	# 3. Nạp database âm quái
	_load_monster_sound_map()

	# 4. Preload trước các âm thanh thường dùng nhất để phát tức thì không giật
	_preload_common_sounds()

func _get_player_2d() -> AudioStreamPlayer:
	if players_2d.is_empty():
		return null
	var p = players_2d[current_idx_2d]
	current_idx_2d = (current_idx_2d + 1) % max_players_2d
	return p

func _get_player_3d() -> AudioStreamPlayer3D:
	if players_3d.is_empty():
		return null
	var p = players_3d[current_idx_3d]
	current_idx_3d = (current_idx_3d + 1) % max_players_3d
	return p

# ==================== TRÌNH NẠP FILE WAV GỐC (DIRECT WAV LOADER) ====================

func load_wav(filename_or_path: String) -> AudioStreamWAV:
	var clean_path := filename_or_path.replace("\\", "/").strip_edges()
	if not clean_path.begins_with("res://"):
		if not clean_path.begins_with("assets/"):
			clean_path = SOUND_DIR + clean_path
		else:
			clean_path = "res://" + clean_path

	if _wav_cache.has(clean_path):
		return _wav_cache[clean_path]

	# Thử nạp qua ResourceLoader nếu Godot đã import
	if ResourceLoader.exists(clean_path):
		var res = ResourceLoader.load(clean_path)
		if res is AudioStreamWAV:
			_wav_cache[clean_path] = res
			return res

	# Tự động phân tích nhị phân RIFF WAV chuẩn xác 100%
	if not FileAccess.file_exists(clean_path):
		# Thử tìm không phân biệt chữ hoa thường trong SOUND_DIR
		clean_path = _find_case_insensitive_path(clean_path)
		if clean_path.is_empty() or not FileAccess.file_exists(clean_path):
			return null

	var file = FileAccess.open(clean_path, FileAccess.READ)
	if not file:
		return null

	var bytes := file.get_buffer(file.get_length())
	file.close()

	if bytes.size() < 44:
		return null

	# Kiểm tra header "RIFF" và "WAVE"
	if bytes.slice(0, 4).get_string_from_ascii() != "RIFF":
		return null
	if bytes.slice(8, 12).get_string_from_ascii() != "WAVE":
		return null

	var idx := 12
	var total_len := bytes.size()
	var channels := 1
	var sample_rate := 22050
	var bits_per_sample := 16
	var audio_data := PackedByteArray()

	while idx + 8 <= total_len:
		var chunk_id := bytes.slice(idx, idx + 4).get_string_from_ascii()
		var chunk_size := bytes.decode_u32(idx + 4)
		var chunk_data_idx := idx + 8
		if chunk_id == "fmt ":
			if chunk_size >= 16 and chunk_data_idx + 16 <= total_len:
				channels = bytes.decode_u16(chunk_data_idx + 2)
				sample_rate = bytes.decode_u32(chunk_data_idx + 4)
				bits_per_sample = bytes.decode_u16(chunk_data_idx + 14)
		elif chunk_id == "data":
			var end_idx = mini(chunk_data_idx + chunk_size, total_len)
			audio_data = bytes.slice(chunk_data_idx, end_idx)
			break
		idx += 8 + chunk_size
		if chunk_size % 2 == 1:
			idx += 1

	if audio_data.is_empty():
		return null

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS if bits_per_sample == 16 else AudioStreamWAV.FORMAT_8_BITS
	stream.stereo = (channels == 2)
	stream.mix_rate = sample_rate
	stream.data = audio_data

	_wav_cache[clean_path] = stream
	return stream

func _find_case_insensitive_path(path: String) -> String:
	# Hỗ trợ tìm file nếu tên trong json viết hoa thường khác nhau
	var fname = path.get_file().to_lower()
	var dir = DirAccess.open(SOUND_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.to_lower() == fname:
				return SOUND_DIR + file_name
			file_name = dir.get_next()
	return ""

func _preload_common_sounds() -> void:
	var common := [
		"Jewel_Sound.wav", "eGem.wav", "pDropItem.wav", "pDropMoney.wav",
		"pGetItem.wav", "pDrink.wav", "pEatApple.wav", "pLevelUp.wav",
		"iButtonClick.wav", "iCreateWindow.wav",
		"eSwingWeapon1.wav", "eSwingWeapon2.wav", "eSwingLightSword.wav",
		"eMeleeHit1.wav", "eMeleeHit2.wav", "eMeleeHit3.wav",
		"sKnightSkill1.wav", "sMagic.wav", "eExplosion.wav"
	]
	for snd in common:
		load_wav(snd)

func _load_monster_sound_map() -> void:
	if not FileAccess.file_exists(MONSTER_SOUND_MAP_PATH):
		return
	var file = FileAccess.open(MONSTER_SOUND_MAP_PATH, FileAccess.READ)
	if not file:
		return
	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_text) == OK:
		var data = json.data
		if data is Dictionary:
			_monster_by_id = data.get("by_id", {})
			_monster_by_name = data.get("by_name", {})

# ==================== PHÁT ÂM THANH THEO FILE HOẶC STREAM ====================

static func play_sound_file(filename: String, volume_db: float = 0.0, pitch: float = 1.0, pos: Vector3 = Vector3.ZERO) -> void:
	var inst = get_instance()
	if inst:
		inst._play_sound_file_internal(filename, volume_db, pitch, pos)

func _play_sound_file_internal(filename: String, volume_db: float = 0.0, pitch: float = 1.0, pos: Vector3 = Vector3.ZERO) -> void:
	var stream = load_wav(filename)
	if not stream:
		return

	if pos != Vector3.ZERO:
		var p3 = _get_player_3d()
		if p3 and p3.is_inside_tree():
			p3.global_position = pos
			p3.stream = stream
			p3.volume_db = volume_db
			p3.pitch_scale = pitch
			p3.play()
	else:
		var p2 = _get_player_2d()
		if p2 and p2.is_inside_tree():
			p2.stream = stream
			p2.volume_db = volume_db
			p2.pitch_scale = pitch
			p2.play()

# ==================== 1. ÂM THANH VẬT PHẨM (ITEM SOUNDS) ====================

## Tiếng KENG ngọc rơi thần thánh của MU Online (Jewel of Bless / Soul / Chaos Drop)
static func play_jewel_drop(pos: Vector3 = Vector3.ZERO) -> void:
	var inst = get_instance()
	if inst:
		inst._play_sound_file_internal("Jewel_Sound.wav", 3.0, 1.0, pos)

## Tiếng Rơi Trang Bị / Vật phẩm thường ra đất (Item Drop)
static func play_item_drop(pos: Vector3 = Vector3.ZERO) -> void:
	var inst = get_instance()
	if inst:
		inst._play_sound_file_internal("pDropItem.wav", 1.0, randf_range(0.95, 1.05), pos)

## Tiếng Rơi Tiền Zen (Zen Drop)
static func play_coin_drop(pos: Vector3 = Vector3.ZERO) -> void:
	var inst = get_instance()
	if inst:
		inst._play_sound_file_internal("pDropMoney.wav", 0.0, randf_range(0.95, 1.05), pos)

## Tiếng Nhặt Tiền Zen (Coin Pickup)
static func play_coin_pickup() -> void:
	var inst = get_instance()
	if inst:
		inst._play_sound_file_internal("pDropMoney.wav", 0.0, randf_range(0.98, 1.05))

## Tiếng Nhặt Đồ vào Hòm Túi (Item Pickup)
static func play_item_pickup() -> void:
	var inst = get_instance()
	if inst:
		inst._play_sound_file_internal("pGetItem.wav", 1.0, 1.0)

## Tiếng Uống Bình Máu / Mana / Bình Thuốc (Potion Drink)
static func play_potion_drink() -> void:
	var inst = get_instance()
	if inst:
		var snd = "pDrink.wav" if randf() < 0.5 else "pEatApple.wav"
		inst._play_sound_file_internal(snd, 0.0, randf_range(0.95, 1.05))

# ==================== 2. ÂM THANH ĐÒN ĐÁNH & KỸ NĂNG (COMBAT & SKILLS) ====================

## Tiếng Vung Vũ Khí / Chém Gió (Weapon Swing)
static func play_weapon_swing(pos: Vector3 = Vector3.ZERO) -> void:
	var inst = get_instance()
	if inst:
		var snd = SWING_SOUNDS[randi() % SWING_SOUNDS.size()]
		inst._play_sound_file_internal(snd, -1.0, randf_range(0.92, 1.08), pos)

## Tiếng Chém Trúng Đòn Cận Chiến (Melee Hit Impact vào Quái)
static func play_melee_hit(pos: Vector3 = Vector3.ZERO) -> void:
	var inst = get_instance()
	if inst:
		var snd = MELEE_HIT_SOUNDS[randi() % MELEE_HIT_SOUNDS.size()]
		inst._play_sound_file_internal(snd, 1.0, randf_range(0.93, 1.07), pos)

## Tiếng Kỹ Năng Xoay Kiếm DK (Twisting Slash)
static func play_twisting_slash(pos: Vector3 = Vector3.ZERO) -> void:
	var inst = get_instance()
	if inst:
		inst._play_sound_file_internal("sKnightSkill1.wav", 1.0, randf_range(0.95, 1.05), pos)

## Tiếng Niệm Phép Cầu Lửa (Fireball Cast)
static func play_fireball_cast(pos: Vector3 = Vector3.ZERO) -> void:
	var inst = get_instance()
	if inst:
		inst._play_sound_file_internal("sMagic.wav", 0.0, randf_range(0.95, 1.05), pos)

## Tiếng Nổ Cầu Lửa (Fireball Impact / Explosion)
static func play_fireball_hit(pos: Vector3 = Vector3.ZERO) -> void:
	var inst = get_instance()
	if inst:
		inst._play_sound_file_internal("eExplosion.wav", 2.0, randf_range(0.9, 1.1), pos)

## Tương thích ngược với hàm cũ
static func play_sword_slash() -> void:
	play_weapon_swing()

# ==================== 3. ÂM THANH QUÁI VẬT (MONSTER SOUNDS) ====================

## Phát âm thanh quái vật theo sự kiện: "idle", "attack", "pain", "die"
## Tự động tra cứu trong monster_sounds_map.json của game gốc
static func play_monster_sound(monster_id: int, monster_name: String, event_name: String, pos: Vector3 = Vector3.ZERO) -> void:
	var inst = get_instance()
	if inst:
		inst._play_monster_sound_internal(monster_id, monster_name, event_name, pos)

func _play_monster_sound_internal(monster_id: int, monster_name: String, event_name: String, pos: Vector3 = Vector3.ZERO) -> void:
	var entry: Dictionary = {}

	# 1. Tra cứu theo ID quái
	var id_key = str(monster_id)
	if _monster_by_id.has(id_key):
		entry = _monster_by_id[id_key]

	# 2. Nếu chưa thấy, tra cứu theo tên quái
	if entry.is_empty():
		var clean_name = monster_name.to_lower().strip_edges()
		var hash_pos = clean_name.find("#")
		if hash_pos > 0:
			clean_name = clean_name.substr(0, hash_pos).strip_edges()
		if _monster_by_name.has(clean_name):
			entry = _monster_by_name[clean_name]

	# 3. Lấy danh sách sound theo sự kiện
	var sound_list: Array = []
	if not entry.is_empty():
		sound_list = entry.get(event_name, [])

	# 4. Fallback mặc định theo sự kiện nếu quái không có sound riêng
	if sound_list.is_empty():
		match event_name:
			"attack": sound_list = ["mBullAttack1.wav", "mBullAttack2.wav"]
			"die": sound_list = ["mBullDie.wav"]
			"pain": sound_list = ["eMeleeHit1.wav", "eMeleeHit2.wav"]
			"idle": sound_list = ["mBull1.wav", "mBull2.wav"]

	if sound_list.is_empty():
		return

	var pick = sound_list[randi() % sound_list.size()]
	if pick is String and not pick.is_empty():
		var vol = 0.0
		if event_name == "die":
			vol = 2.0
		elif event_name == "idle":
			vol = -3.0
		_play_sound_file_internal(pick, vol, randf_range(0.95, 1.05), pos)

# ==================== 4. ÂM THANH GIAO DIỆN & HỆ THỐNG (UI & SYSTEM) ====================

## Tiếng Click Nút Giao Diện (Button Click)
static func play_ui_click() -> void:
	var inst = get_instance()
	if inst:
		inst._play_sound_file_internal("iButtonClick.wav", -2.0, 1.0)

static func play_ui_button() -> void:
	play_ui_click()

## Tiếng Mở Cửa Sổ Bảng Giao Diện (Inventory, Shop, Warp Window Open)
static func play_ui_window() -> void:
	var inst = get_instance()
	if inst:
		inst._play_sound_file_internal("iCreateWindow.wav", -1.0, 1.0)

## Tiếng Thăng Cấp Thần Thánh (Level Up Fanfare)
static func play_level_up() -> void:
	var inst = get_instance()
	if inst:
		inst._play_sound_file_internal("pLevelUp.wav", 4.0, 1.0)
