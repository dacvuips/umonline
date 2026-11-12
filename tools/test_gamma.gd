extends SceneTree
## Kiểm tra gamma của renderer: texture xám 128 nhân với (a) uniform 0.5, (b) vertex COLOR 0.5
func _init() -> void:
	root.size = Vector2i(256, 256)
	var img := Image.create(4, 4, false, Image.FORMAT_RGB8)
	img.fill(Color8(128, 128, 128))
	var tex := ImageTexture.create_from_image(img)
	var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0, 0, 0)
	var we := WorldEnvironment.new(); we.environment = env; root.add_child(we)
	var cam := Camera3D.new(); cam.position = Vector3(0, 0, 3); root.add_child(cam); cam.make_current()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in [Vector3(-5, -5, 0), Vector3(5, -5, 0), Vector3(5, 5, 0), Vector3(-5, -5, 0), Vector3(5, 5, 0), Vector3(-5, 5, 0)]:
		st.set_color(Color(0.5, 0.5, 0.5)); st.set_uv(Vector2(0, 0)); st.add_vertex(v)
	var mi := MeshInstance3D.new(); mi.mesh = st.commit(); root.add_child(mi)
	for code in ["ALBEDO = texture(t, UV).rgb;", "ALBEDO = texture(t, UV).rgb * 0.5;", "ALBEDO = COLOR.rgb;", "ALBEDO = texture(t, UV).rgb * COLOR.rgb;"]:
		var sh := Shader.new()
		sh.code = "shader_type spatial; render_mode unshaded, cull_disabled; uniform sampler2D t : source_color; void fragment(){ %s }" % code
		var m := ShaderMaterial.new(); m.shader = sh; m.set_shader_parameter("t", tex); mi.material_override = m
		for _i in 4: await process_frame
		print(code, " -> ", root.get_texture().get_image().get_pixel(128, 128).r8)
	quit(0)
