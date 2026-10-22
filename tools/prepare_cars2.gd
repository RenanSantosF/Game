extends SceneTree
# Carros do jogo a partir de modelos gratuitos (models_src/, fora do APK):
#   0 = esportivo: "Low Poly American Muscle" (T Allen Studios, CC-BY 4.0)
#   1 = jeep aberto: "GAZ-67 lowpoly" (Artie31, CC0)
# Saída: models/car<k>.res (carroceria), models/car<k>_wheel.res (uma roda, eixo em X, raio 1) e
# scripts/car_info.gd (tamanho, rodas). As cores das texturas viram cor por vértice; no esportivo a
# pintura fica marcada (UV2.x = 1) pra cada carro ter uma cor; os vidros saem (dá pra ver quem dirige).
# Uso: godot --headless --script tools/prepare_cars2.gd

const PAINT := Color8(237, 28, 36)


func _initialize() -> void:
	var info := []
	info.append(_muscle())
	info.append(_jeep())
	var txt := "class_name CarInfo\nextends RefCounted\n\n# Gerado por tools/prepare_cars2.gd (não editar à mão).\n# len/wid/hgt = tamanho; wh = [x da roda, raio, z da frente, z de trás, largura da roda]\nconst INFO := [\n"
	for c in info:
		txt += "\t{\"len\": %.3f, \"wid\": %.3f, \"hgt\": %.3f, \"wh\": [%.3f, %.3f, %.3f, %.3f, %.3f]},\n" % [c["len"], c["wid"], c["hgt"], c["wh"][0], c["wh"][1], c["wh"][2], c["wh"][3], c["wh"][4]]
	txt += "]\n"
	var f := FileAccess.open("res://scripts/car_info.gd", FileAccess.WRITE)
	f.store_string(txt)
	f.close()
	quit()


func _muscle() -> Dictionary:
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://models_src/muscle/Red.png"))
	var full: MeshInstance3D = (load("res://models_src/muscle/full.fbx") as PackedScene).instantiate().find_child("67Camaro", true, false)
	var body: MeshInstance3D = (load("res://models_src/muscle/body.fbx") as PackedScene).instantiate().find_child("67CamaroNoWheels", true, false)
	var wheel: MeshInstance3D = (load("res://models_src/muscle/wheel.fbx") as PackedScene).instantiate().find_child("FrontWheel", true, false)
	var fab := _world_aabb(full)
	var bab := _world_aabb(body)
	# o corpo sem rodas está deslocado: alinha pelo topo/centro com o modelo completo
	var shift := Vector3(fab.get_center().x - bab.get_center().x, fab.end.y - bab.end.y, fab.end.z - bab.end.z)
	# rodas: pontos mais baixos do modelo completo em 4 grupos
	var wab := _world_aabb(wheel)
	var wr := wab.size.y / 2.0
	var groups := {}
	var fx := full.global_transform if full.is_inside_tree() else _xf(full)
	for v: Vector3 in (full.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
		var p := fx * v
		if p.y < fab.position.y + 0.08:
			var k := Vector2i(1 if p.x > fab.get_center().x else -1, 1 if p.z > fab.get_center().z else -1)
			if not groups.has(k):
				groups[k] = []
			groups[k].append(p)
	var cs := {}
	for k in groups:
		var s := Vector3.ZERO
		for p in groups[k]:
			s += p
		cs[k] = s / groups[k].size()
	var wx: float = absf((cs[Vector2i(1, 1)] as Vector3).x - fab.get_center().x)
	var zf_raw: float = (cs[Vector2i(1, 1)] as Vector3).z
	var zb_raw: float = (cs[Vector2i(1, -1)] as Vector3).z
	print("muscle: rodas x=±%.2f z=%.2f/%.2f raio=%.2f" % [wx, zf_raw, zb_raw, wr])
	# frente do modelo é +Z: gira 180° pra ficar -Z; escala pra 5 m de comprimento
	var s := 5.0 / fab.size.z
	var c := Vector3(fab.get_center().x, fab.position.y, fab.get_center().z)
	var xf := Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE * s), Vector3.ZERO) * Transform3D(Basis(), -c) * Transform3D(Basis(), shift) * _xf(body)
	# vidros do esportivo são a parte escura de cima (acima de 62% da altura)
	ResourceSaver.save(_bake([[body.mesh, xf]], img, true, fab.size.y * s * 0.62), "res://models/car0.res")
	var wxf := Transform3D(Basis(Vector3.UP, PI / 2.0 if wab.size.x < wab.size.z else 0.0), Vector3.ZERO) * Transform3D(Basis(), -wab.get_center()) * _xf(wheel)
	ResourceSaver.save(_bake_unit([[wheel.mesh, wxf]], img), "res://models/car0_wheel.res")
	return {"len": fab.size.z * s, "wid": fab.size.x * s, "hgt": fab.size.y * s,
		"wh": [wx * s, wr * s, -(zf_raw - c.z) * s, -(zb_raw - c.z) * s, wab.size.x * s if wab.size.x < wab.size.z else wab.size.z * s]}


func _jeep() -> Dictionary:
	var sc: Node3D = (load("res://models_src/jeep/gaz67.fbx") as PackedScene).instantiate()
	var parts := []
	var wheel: MeshInstance3D
	var wheels := []
	var all := AABB()
	var first := true
	for n in sc.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var ab := _xf(mi) * mi.mesh.get_aabb()
		all = ab if first else all.merge(ab)
		first = false
		if String(mi.name).begins_with("wheel"):
			wheels.append(ab.get_center())
			if mi.name == "wheel FL":
				wheel = mi
		else:
			parts.append(mi)
	var s := 4.6 / all.size.z
	var c := Vector3(all.get_center().x, all.position.y, all.get_center().z)
	var xf0 := Transform3D(Basis().scaled(Vector3.ONE * s), Vector3.ZERO) * Transform3D(Basis(), -c)
	var list := []
	for mi in parts:
		list.append([mi.mesh, xf0 * _xf(mi)])
	ResourceSaver.save(_bake(list, null, true), "res://models/car1.res")
	var wab := _xf(wheel) * wheel.mesh.get_aabb()
	var wxf := Transform3D(Basis(), -wab.get_center()) * _xf(wheel)
	ResourceSaver.save(_bake_unit([[wheel.mesh, wxf]], null), "res://models/car1_wheel.res")
	var zs := []
	var xs := 0.0
	for w: Vector3 in wheels:
		zs.append(w.z)
		xs += absf(w.x - c.x)
	zs.sort()
	print("jeep: rodas ", wheels)
	return {"len": all.size.z * s, "wid": all.size.x * s, "hgt": all.size.y * s,
		"wh": [xs / wheels.size() * s, wab.size.y / 2.0 * s, (float(zs[0]) - c.z) * s, (float(zs[-1]) - c.z) * s, wab.size.x * s]}


func _xf(n: Node) -> Transform3D:
	var t := Transform3D()
	var p := n
	while p and p is Node3D:
		t = (p as Node3D).transform * t
		p = p.get_parent()
	return t


func _world_aabb(mi: MeshInstance3D) -> AABB:
	return _xf(mi) * mi.mesh.get_aabb()


func _texel(img: Image, mat: Material, uv: Vector2) -> Color:
	var col := Color(0.5, 0.5, 0.5)
	var tex: Texture2D = null
	if mat is BaseMaterial3D:
		# cor do material do FBX vem linear
		col = (mat as BaseMaterial3D).albedo_color.linear_to_srgb()
		tex = (mat as BaseMaterial3D).albedo_texture
	var im := img
	if im == null and tex:
		im = tex.get_image()
		if im and im.is_compressed():
			im.decompress()
	if im:
		var x := clampi(int(fposmod(uv.x, 1.0) * im.get_width()), 0, im.get_width() - 1)
		var y := clampi(int(fposmod(uv.y, 1.0) * im.get_height()), 0, im.get_height() - 1)
		return im.get_pixel(x, y) * Color(col.r, col.g, col.b, 1.0) if img == null else im.get_pixel(x, y)
	return col


static func _is_glass(c: Color) -> bool:
	return c.b > c.r + 0.05 and c.s < 0.45 and c.v > 0.45


# junta tudo numa malha: cor da textura no vértice (por triângulo), pintura marcada, sem vidros
func _bake(list: Array, img: Image, paint: bool, glass_hi := -1.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dropped := 0
	for e in list:
		var m: Mesh = e[0]
		var xf: Transform3D = e[1]
		for si in m.get_surface_count():
			var a := m.surface_get_arrays(si)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
			var uv = a[Mesh.ARRAY_TEX_UV]
			var idx = a[Mesh.ARRAY_INDEX]
			var order: Array = range(v.size()) if idx == null or (idx as PackedInt32Array).is_empty() else Array(idx)
			var mat := m.surface_get_material(si)
			for t0 in range(0, order.size(), 3):
				var cuv := Vector2.ZERO
				if uv != null and (uv as PackedVector2Array).size() > 0:
					cuv = ((uv[order[t0]] + uv[order[t0 + 1]] + uv[order[t0 + 2]]) / 3.0)
				var col := _texel(img, mat, cuv)
				var mname := String(mat.resource_name).to_lower() if mat else ""
				var cy := ((xf * v[order[t0]]).y + (xf * v[order[t0 + 1]]).y + (xf * v[order[t0 + 2]]).y) / 3.0
				if mname.contains("glass") or _is_glass(col) or (glass_hi > 0.0 and cy > glass_hi and col.v < 0.3):
					dropped += 1
					continue
				var is_paint := paint and ((absf(col.r - PAINT.r) < 0.12 and absf(col.g - PAINT.g) < 0.12 and absf(col.b - PAINT.b) < 0.12) or mname.contains("khaki"))
				var nf := ((xf * v[order[t0 + 1]]) - (xf * v[order[t0]])).cross((xf * v[order[t0 + 2]]) - (xf * v[order[t0]]))
				var flip := xf.basis.determinant() < 0.0
				for j in 3:
					var t: int = order[t0 + (2 - j if flip else j)]
					st.set_color(Color(1, 1, 1) if is_paint else col)
					st.set_uv(Vector2.ZERO)
					st.set_uv2(Vector2(1.0 if is_paint else 0.0, 0.0))
					st.set_normal((xf.basis.inverse().transposed() * n[t]).normalized() if n.size() > 0 else nf.normalized())
					st.add_vertex(xf * v[t])
	print("  vidros tirados: ", dropped, " triângulos")
	st.index()
	return st.commit()


# roda com raio 1 e largura 1 (o jogo escala)
func _bake_unit(list: Array, img: Image) -> ArrayMesh:
	var m := _bake(list, img, false)
	var ab := m.get_aabb()
	var sx := 1.0 / ab.size.x
	var sr := 2.0 / ab.size.y
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(m, 0, Transform3D(Basis.from_scale(Vector3(sx, sr, sr)), Vector3.ZERO))
	return st.commit()
