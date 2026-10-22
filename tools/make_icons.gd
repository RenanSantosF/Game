extends SceneTree

# Gera as imagens dos ícones de armas e itens (icons/*.png).
# Uso: godot --path . -s tools/make_icons.gd   (precisa de tela; no servidor use xvfb-run)


func _initialize() -> void:
	render_all()

func render_all() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(256, 128)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.8, 0.8)
	env.ambient_light_energy = 0.9
	we.environment = env
	vp.add_child(we)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -30, 0)
	light.light_energy = 1.2
	vp.add_child(light)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	vp.add_child(cam)
	cam.current = true
	var list := []
	for k in Weapons.DATA:
		list.append(k)
	for k in Weapons.ITEMS:
		list.append(k)
	list.append("box")
	for id in list:
		var node: Node3D
		var size := 0.5
		var center := Vector3.ZERO
		if id == "fist":
			node = Node3D.new()
			var m := MB.new()
			m.tex(U.PLAIN, 3.0)
			var sk := Color(0.86, 0.66, 0.5)
			m.blob(Transform3D(Basis.from_scale(Vector3(0.07, 0.055, 0.06)), Vector3.ZERO), 9, 5, sk)
			for i in 4:
				m.blob(Transform3D(Basis.from_scale(Vector3(0.018, 0.02, 0.025)), Vector3(-0.045 + i * 0.03, 0.04, -0.035)), 6, 3, sk.darkened(0.05))
			m.blob(Transform3D(Basis.from_scale(Vector3(0.02, 0.035, 0.02)), Vector3(0.07, -0.005, -0.02)), 6, 3, sk)
			U.mesh(node, m.commit())
			node.rotation = Vector3(0.4, 0.5, 0)
			size = 0.19
		elif Weapons.is_gun(id):
			node = Weapons.build_model(id)
			node.rotation.y = -PI / 2.0
			var L: float = Weapons.get_w(id)["len"]
			size = maxf(L * 1.1, 0.3)
			center = Vector3(L * 0.42, 0.0, 0)
		else:
			node = Weapons.build_item(id, false)
			node.rotation = Vector3(0.6, 0.6, 0)
			size = 0.95 if id == "box" else 0.6
			if Weapons.is_att(id):
				node.rotation = Vector3(0.35, 0.9, 0)
				size = 0.3 if Weapons.att_cat(id) != "sight" or id == "holo" else 0.42
				center = Vector3(0, 0.04, 0)
			center = Vector3(0, 0.12, 0)
		vp.add_child(node)
		cam.size = size
		cam.position = center + Vector3(0, 0, 3)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://icons/%s.png" % id))
		print("ícone ", id)
		node.queue_free()
	quit()
