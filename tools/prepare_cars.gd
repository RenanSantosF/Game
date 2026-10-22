extends SceneTree
# Converte os carros do Car Kit da Kenney (CC0, models_src/cars) para malhas do jogo:
#   models/car0.res (esportivo), models/car1.res (picape), models/car_wheel.res
# A carroceria ganha COLOR.r = 1 nas partes pintadas (a cor sai do shader). Sem vidros (dá pra ver quem
# está dentro); o jeep (feito do SUV) perde também o teto e as colunas: fica aberto em cima.
# Uso: godot --headless --script tools/prepare_cars.gd

const SRC := "res://models_src/cars/"
const CARS := [["sedan-sports", "car0", false], ["suv", "car1", true]]


func _initialize() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(SRC + "Textures/colormap.png"))
	for e in CARS:
		var sc := _load(e[0])
		var body: MeshInstance3D = sc.find_child("body", true, false)
		var parts := []
		_collect(body, Transform3D(), parts)
		# célula da paleta (8x4) mais usada que não seja cinza/branca = pintura
		var area := {}
		for p in parts:
			var a: Array = p[0]
			var xf: Transform3D = p[1]
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
			var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
			for t in range(0, idx.size(), 3):
				var ar := ((xf * v[idx[t + 1]]) - (xf * v[idx[t]])).cross((xf * v[idx[t + 2]]) - (xf * v[idx[t]])).length()
				var c := _cell(uv[idx[t]])
				area[c] = area.get(c, 0.0) + ar
		var paint := Vector2i(-1, -1)
		var best := 0.0
		for c in area:
			var col := _cell_color(img, c)
			if col.s > 0.35 and area[c] > best:
				best = area[c]
				paint = c
		print(e[0], " pintura=", paint, " cor=", _cell_color(img, paint))
		# altura de baixo dos vidros (o jeep corta tudo que estiver acima dela)
		var glass_y := 99.0
		var top := 0.0
		for p in parts:
			for vv in (p[0][Mesh.ARRAY_VERTEX] as PackedVector3Array):
				top = maxf(top, ((p[1] as Transform3D) * vv).y)
		for p in parts:
			var a: Array = p[0]
			var xf: Transform3D = p[1]
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
			for t in range(v.size()):
				var cc := _cell_color(img, _cell(uv[t]))
				if cc.v > 0.85 and cc.s < 0.25 and cc.b >= cc.r and (xf * v[t]).y > top * 0.6:
					glass_y = minf(glass_y, (xf * v[t]).y)
		print("  vidro começa em y=", glass_y)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for p in parts:
			var a: Array = p[0]
			var xf: Transform3D = p[1]
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
			var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
			var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
			for t0 in range(0, idx.size(), 3):
				var cc := _cell_color(img, _cell(uv[idx[t0]]))
				if cc.v > 0.85 and cc.s < 0.25 and cc.b >= cc.r:
					continue
				if e[2]:
					var lo := minf((xf * v[idx[t0]]).y, minf((xf * v[idx[t0 + 1]]).y, (xf * v[idx[t0 + 2]]).y))
					if lo > glass_y + 0.02:
						continue
				for j in 3:
					var t := idx[t0 + j]
					st.set_color(Color(1.0 if _cell(uv[t]) == paint else 0.0, 0.0, 0.0))
					st.set_uv(uv[t])
					st.set_normal((xf.basis * n[t]).normalized())
					st.add_vertex(xf * v[t])
		st.index()
		var mesh: ArrayMesh = st.commit()
		ResourceSaver.save(mesh, "res://models/%s.res" % e[1])
		for w in sc.find_children("wheel-*", "MeshInstance3D", true, false):
			print("  ", w.name, " ", (w as Node3D).transform.origin)
		sc.free()
	# roda (do esportivo), centrada no eixo
	var sc2 := _load("sedan-sports")
	var wm: MeshInstance3D = sc2.find_child("wheel-front-left", true, false)
	var a2 := wm.mesh.surface_get_arrays(0)
	var ab := wm.mesh.get_aabb()
	var ctr := ab.get_center()
	print("roda aabb=", ab)
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	var v2: PackedVector3Array = a2[Mesh.ARRAY_VERTEX]
	var n2: PackedVector3Array = a2[Mesh.ARRAY_NORMAL]
	var uv2: PackedVector2Array = a2[Mesh.ARRAY_TEX_UV]
	for t in (a2[Mesh.ARRAY_INDEX] as PackedInt32Array):
		st2.set_color(Color(0, 0, 0))
		st2.set_uv(uv2[t])
		st2.set_normal(n2[t])
		# normaliza: raio 1, eixo X, largura 1
		var p := v2[t] - ctr
		st2.add_vertex(Vector3(p.x / ab.size.x, p.y / (ab.size.y / 2.0), p.z / (ab.size.z / 2.0)))
	st2.index()
	ResourceSaver.save(st2.commit(), "res://models/car_wheel.res")
	sc2.free()
	quit()


func _load(n: String) -> Node:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	doc.append_from_file(ProjectSettings.globalize_path(SRC + n + ".glb"), st)
	return doc.generate_scene(st)


func _collect(nd: Node, xf: Transform3D, out: Array) -> void:
	var t := xf * (nd as Node3D).transform
	if nd is MeshInstance3D and not String(nd.name).begins_with("wheel"):
		var m: Mesh = (nd as MeshInstance3D).mesh
		for s in m.get_surface_count():
			out.append([m.surface_get_arrays(s), t])
	for c in nd.get_children():
		_collect(c, t, out)


func _cell(uv: Vector2) -> Vector2i:
	return Vector2i(clampi(int(fposmod(uv.x, 1.0) * 8.0), 0, 7), clampi(int(fposmod(uv.y, 1.0) * 4.0), 0, 3))


func _cell_color(img: Image, c: Vector2i) -> Color:
	if c.x < 0:
		return Color.BLACK
	return img.get_pixel(c.x * 64 + 32, c.y * 128 + 64)
