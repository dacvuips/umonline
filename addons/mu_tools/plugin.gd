@tool
extends EditorPlugin

const DockScript = preload("res://addons/mu_tools/mu_tools_dock.gd")
var dock: Control

func _enter_tree() -> void:
	dock = DockScript.new()
	dock.name = "MU Tools"
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)

func _exit_tree() -> void:
	if dock:
		remove_control_from_docks(dock)
		dock.queue_free()
		dock = null
