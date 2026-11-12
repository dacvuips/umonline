extends Node3D

## In chuỗi shader của từng surface khi mặc bộ +15 / +0 (chẩn đoán bóng): godot --path MuMain res://tools/chain_dump.tscn -- <lớp> <bộ> <cấp>
func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var cls := int(a[0]); var sn := int(a[1]); var lv := int(a[2])
	MuCatalog.ensure_loaded()
	MuTerrain.change_world(1)
	var eq := {}
	for sl in [["helm", 7], ["armor", 8], ["pants", 9], ["gloves", 10], ["boots", 11]]:
		if MuCatalog.item_glb(sl[1], sn) != "":
			eq[sl[0]] = {"group": sl[1], "number": sn, "level": lv, "excellent": lv > 0}
	var m := MuCharacterModel.new()
	add_child(m)
	m.build_player(cls, eq)
	await get_tree().create_timer(1.0).timeout
	for n in m.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_surface_override_material(s) as ShaderMaterial
			var names: Array = []
			while mat != null:
				names.append(mat.shader.resource_path.get_file().replace(".gdshader", "") if mat.shader else "?")
				mat = mat.next_pass as ShaderMaterial
			print("CHAIN ", mi.name, " s", s, ": ", " > ".join(names))
	get_tree().quit()
