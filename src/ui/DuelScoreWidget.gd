extends Control
class_name DuelScoreWidget

## Bảng điểm Quyết đấu — clone CDuelWindow (UI/Combat/DuelWindow.cpp + duel_window.rcss legacy):
##   nền newui_Figure_ground 131x70 ; tên Hero xanh #0096ff (55,33) điểm (31,33) ; đối thủ đỏ #ff1919 (55,56) điểm (31,56).
##   Đặt giữa phía trên màn hình. Thắng khi đạt 10 điểm (DuelRoom.cs của OpenMU).

const MuUiSkinRes = preload("res://src/ui/MuUiSkin.gd")
const S := 1.5
var social = null
var _hn: Label
var _hs: Label
var _en: Label
var _es: Label

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(131, 70) * S
	MuUiSkinRes.img(self, "newui_figure_ground", Vector2.ZERO, Vector2(131, 70))
	_hs = MuUiSkinRes.text(self, "0", Vector2(24, 28), Vector2(22, 15), 13, Color("#0096ff"), HORIZONTAL_ALIGNMENT_CENTER)
	_hn = MuUiSkinRes.text(self, "", Vector2(55, 28), Vector2(72, 15), 12, Color("#0096ff"))
	_es = MuUiSkinRes.text(self, "0", Vector2(24, 51), Vector2(22, 15), 13, Color("#ff1919"), HORIZONTAL_ALIGNMENT_CENTER)
	_en = MuUiSkinRes.text(self, "", Vector2(55, 51), Vector2(72, 15), 12, Color("#ff1919"))

func setup(p_social) -> void:
	social = p_social
	social.duel_changed.connect(_refresh)

func _refresh() -> void:
	visible = social.in_duel()
	if not visible:
		return
	_hn.text = social._hero_name()
	_en.text = social.duel_enemy.character_name
	_hs.text = str(social.duel_score_hero)
	_es.text = str(social.duel_score_enemy)
	var vs := get_viewport_rect().size
	position = Vector2(floorf((vs.x - size.x) * 0.5), 84)
