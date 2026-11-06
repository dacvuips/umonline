extends Control
class_name TopMapWidget

## Widget Bản đồ & Tọa độ góc trên bên trái chuẩn 100% MU Online
## Khung hoa văn Rồng bạc kim loại 207x25px kèm nút thiết lập tự động

@onready var lbl_coords: Label = $MapFrame/CoordsLabel
@export var player: MuPlayer = null

var current_map_name: String = "Lorencia"

func _ready() -> void:
	_update_map_name()
	if player:
		setup(player)

func _update_map_name() -> void:
	var wid = MuTerrain.world_id
	if wid == 1:
		current_map_name = "Lorencia"
		return
	var p := "res://assets/mu/maps/maps_index.json"
	if FileAccess.file_exists(p):
		var d = JSON.parse_string(FileAccess.get_file_as_string(p))
		if d is Dictionary and d.has(str(wid)):
			current_map_name = str(d[str(wid)].get("name", "World %d" % wid))
			return
	current_map_name = "World %d" % wid

func setup(p_player: MuPlayer) -> void:
	player = p_player
	if player:
		if not player.position_changed.is_connected(update_coords):
			player.position_changed.connect(update_coords)
		update_coords(player.grid_x, player.grid_y)

func update_coords(x: int, y: int) -> void:
	if lbl_coords:
		lbl_coords.text = "%s ( %d , %d )" % [current_map_name, x, y]

func set_map_name(m_name: String) -> void:
	current_map_name = m_name
	if player:
		update_coords(player.grid_x, player.grid_y)
