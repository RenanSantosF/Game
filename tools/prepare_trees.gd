extends SceneTree

# Árvores e moita a partir de modelos do Poly Haven (CC0), leves pra celular:
# - tronco e galhos: a malha de verdade, reduzida pelo tools/decimate_trees.py (mantém a textura)
# - copa: cartões de folhas (models/trees/leaves.png, do tools/make_leaf_cards.py) postos onde o
#   modelo original tem folha (as ~milhões de folhas viram umas centenas de cartões)
# Uso (TREES_SRC = pasta com os modelos baixados do Poly Haven, TREES_TMP = pasta temporária):
#   TREES_STAGE=dump godot --headless -s tools/prepare_trees.gd
#   python3 tools/decimate_trees.py $TREES_TMP
#   godot --headless -s tools/prepare_trees.gd
# Sai em models/trees/<tipo>.res e <tipo>_lo.res (oak, tall, pine, bush) + texturas de casca.

const OUT := "res://models/trees/"
# tipo -> [modelo, altura final (m), superfícies de casca, superfície das folhas, cartão (0..3)]
const TREES := {
	"oak": ["tree_small_02", 7.4, ["tree_small_02_trunk", "tree_small_02_branches"], "tree_small_02_leaves", 0],
	"tall": ["island_tree_02", 6.6, ["island_tree_02", "island_tree_02_branches"], "island_tree_02_leaves", 1],
}

var src := ""
var tmp := ""


func _initialize() -> void:
	src = OS.get_environment("TREES_SRC")
	tmp = OS.get_environment("TREES_TMP")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	if OS.get_environment("TREES_STAGE") == "dump":
		for kind in TREES:
			_dump(kind)
		quit()
		return
	var leaves := _leaf_mat()
	for kind in TREES:
		for lod in 2:
			var m := _build(kind, lod, leaves)
			ResourceSaver.save(m, OUT + kind + ("_lo" if lod == 1 else "") + ".res")
	for lod in 2:
		ResourceSaver.save(_pine(lod, leaves), OUT + "pine" + ("_lo" if lod == 1 else "") + ".res")
	ResourceSaver.save(_bush(leaves), OUT + "bush.res")
	print("árvores prontas")
	quit()


func _scene(name: String) -> Node:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	doc.append_from_file(src + "/" + name + "/" + name + "_1k.gltf", st)
	return doc.generate_scene(st)


func _dump(kind: String) -> void:
	var t: Array = TREES[kind]
	var root := _scene(t[0])
	# escala: altura final
	var ab := AABB()
	var first := true
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var b := mi.transform * mi.get_aabb()
		ab = b if first else ab.merge(b)
		first = false
	var sc: float = float(t[1]) / ab.size.y
	var base := Vector3(ab.get_center().x, ab.position.y, ab.get_center().z)
	var pts := PackedStringArray()
	var objs := {}
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = mi.mesh
		for s in m.get_surface_count():
			var mat := m.surface_get_material(s)
			var mname := mat.resource_name if mat else ""
			var a := m.surface_get_arrays(s)
			var pos: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
			if mname == t[3]:
				# folhas: um ponto a cada poucos triângulos (posição e normal)
				var nrm: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
				for i in range(0, idx.size(), 3 * 12):
					var p := (mi.transform * pos[idx[i]] - base) * sc
					var nn := (mi.transform.basis * nrm[idx[i]]).normalized()
					pts.append("%f %f %f %f %f %f" % [p.x, p.y, p.z, nn.x, nn.y, nn.z])
			elif mname in t[2]:
				var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
				if not objs.has(mname):
					objs[mname] = [[], [], 0]
				var o: Array = objs[mname]
				var off: int = o[2]
				for i in pos.size():
					var p := (mi.transform * pos[i] - base) * sc
					(o[0] as Array).append("v %f %f %f" % [p.x, p.y, p.z])
					(o[0] as Array).append("vt %f %f" % [uv[i].x, 1.0 - uv[i].y])
				for i in range(0, idx.size(), 3):
					var q := [idx[i] + 1 + off, idx[i + 1] + 1 + off, idx[i + 2] + 1 + off]
					(o[1] as Array).append("f %d/%d %d/%d %d/%d" % [q[0], q[0], q[1], q[1], q[2], q[2]])
				o[2] = off + pos.size()
	for mname in objs:
		var o: Array = objs[mname]
		var f := FileAccess.open(tmp + "/%s__%s.obj" % [kind, mname], FileAccess.WRITE)
		f.store_string("\n".join(PackedStringArray(o[0])) + "\n" + "\n".join(PackedStringArray(o[1])) + "\n")
		f.close()
		# casca: textura reduzida
		var img := Image.load_from_file(src + "/" + t[0] + "/textures/" + _tex_name(t[0], mname))
		img.resize(512, 512, Image.INTERPOLATE_LANCZOS)
		img.save_jpg(ProjectSettings.globalize_path(OUT + mname + ".jpg"), 0.88)
	var f2 := FileAccess.open(tmp + "/%s__leafpts.txt" % kind, FileAccess.WRITE)
	f2.store_string("\n".join(pts))
	f2.close()
	print(kind, ": ", objs.keys(), " pontos de folha ", pts.size())


func _tex_name(model: String, mname: String) -> String:
	var dir := DirAccess.open(src + "/" + model + "/textures")
	var want := mname.replace(model, "").trim_prefix("_")
	for fn in dir.get_files():
		if fn.contains("_diff_"):
			var mid := fn.replace(model, "").replace("_diff_1k.jpg", "").trim_prefix("_")
			if mid == want or (want == "branches" and mid == "branch"):
				return fn
	return model + "_diff_1k.jpg"


func _leaf_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(OUT + "leaves.png")
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.45
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.95
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return m


# casca com projeção triplanar (a malha reduzida não guarda UV)
func _bark_mat(mname: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(OUT + mname + ".jpg")
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	m.albedo_color = Color(0.72, 0.68, 0.64)
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.9, 0.9, 0.9)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return m


func _obj(path: String) -> Array:
	var vs := PackedVector3Array()
	var ts := PackedVector2Array()
	var corners := []
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var w := line.strip_edges().split(" ", false)
		if w.is_empty():
			continue
		match w[0]:
			"v":
				vs.append(Vector3(float(w[1]), float(w[2]), float(w[3])))
			"vt":
				ts.append(Vector2(float(w[1]), 1.0 - float(w[2])))
			"f":
				for c in range(1, 4):
					var q := w[c].split("/")
					corners.append([int(q[0]) - 1, int(q[1]) - 1 if q.size() > 1 and q[1] != "" else -1])
	return [vs, ts, corners]


func _add_obj(st: SurfaceTool, path: String, thick: float) -> void:
	var o := _obj(path)
	var vs: PackedVector3Array = o[0]
	var ts: PackedVector2Array = o[1]
	var corners: Array = o[2]
	for c in corners:
		var p: Vector3 = vs[c[0]]
		# troncos um pouco mais grossos (perto do eixo engrossa mais)
		var k := lerpf(thick, 1.0, smoothstep(1.2, 3.2, p.y))
		p = Vector3(p.x * k, p.y, p.z * k)
		st.set_color(Color.WHITE)
		if int(c[1]) >= 0:
			st.set_uv(ts[c[1]])
		st.add_vertex(p)


func _build(kind: String, lod: int, leaves: Material) -> ArrayMesh:
	var t: Array = TREES[kind]
	var am := ArrayMesh.new()
	for mname in t[2]:
		var path := tmp + "/%s__%s_lod%d.obj" % [kind, mname, lod]
		if not FileAccess.file_exists(path):
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_add_obj(st, path, 1.35)
		st.generate_normals()
		st.set_material(_bark_mat(mname))
		st.commit(am)
	_cards_from_points(am, tmp + "/%s__leafpts.txt" % kind, 0.62 if lod == 0 else 1.25, int(t[4]), leaves, kind.hash())
	print(kind, " lod", lod, ": ", _tris(am), " triângulos")
	return am


func _tris(m: ArrayMesh) -> int:
	var n := 0
	for s in m.get_surface_count():
		n += m.surface_get_array_len(s) / 3
	return n


# junta os pontos de folha em cubinhos; cada cubinho com folha vira um cartão
func _cards_from_points(am: ArrayMesh, path: String, cell: float, card: int, mat: Material, seed: int) -> void:
	var cells := {}
	var lo := Vector3(1e9, 1e9, 1e9)
	var hi := -lo
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var w := line.split(" ", false)
		if w.size() < 6:
			continue
		var p := Vector3(float(w[0]), float(w[1]), float(w[2]))
		lo = lo.min(p)
		hi = hi.max(p)
		var k := Vector3i((p / cell).floor())
		if not cells.has(k):
			cells[k] = [Vector3.ZERO, 0]
		cells[k][0] += p
		cells[k][1] += 1
	var ctr := (lo + hi) / 2.0
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var counts := []
	for k in cells:
		counts.append(cells[k][1])
	counts.sort()
	var minc: int = counts[int(counts.size() * 0.25)] if counts.size() > 8 else 1
	for k in cells:
		if int(cells[k][1]) < minc:
			continue
		var c: Vector3 = cells[k][0] / float(cells[k][1])
		_card(st, c, ctr, cell * rng.randf_range(1.9, 2.5), card, rng, hi.y, lo.y)
	st.set_material(mat)
	st.commit(am)


func _card(st: SurfaceTool, c: Vector3, ctr: Vector3, size: float, card: int, rng: RandomNumberGenerator, top: float, bot: float) -> void:
	var out := (c - ctr)
	out.y *= 0.6
	out = out.normalized() if out.length() > 0.01 else Vector3.UP
	# cartão virado mais ou menos pra fora, girado à toa
	var n := (out + Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.3, 0.5), rng.randf_range(-0.6, 0.6))).normalized()
	var up := Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT
	var r := n.cross(up).normalized().rotated(n, rng.randf_range(-0.5, 0.5))
	var u := r.cross(n).normalized()
	var hs := size / 2.0
	var cx := float(card % 2) * 0.5
	var cy := float(card / 2) * 0.5
	var uvs := [Vector2(cx, cy + 0.5), Vector2(cx + 0.5, cy + 0.5), Vector2(cx + 0.5, cy), Vector2(cx, cy)]
	var ps := [c - r * hs - u * hs, c + r * hs - u * hs, c + r * hs + u * hs, c - r * hs + u * hs]
	# luz: por cima e por fora mais claro, dentro e embaixo mais escuro
	var h := clampf((c.y - bot) / maxf(top - bot, 0.01), 0.0, 1.0)
	var shade := lerpf(0.62, 1.08, h) * lerpf(0.85, 1.0, clampf((c - ctr).length() / 2.5, 0.0, 1.0))
	var col := Color(shade, shade, shade)
	# normal "inflada" (de dentro da copa pra fora): a copa sombreia como um volume
	var nv := ((c - ctr).normalized() * 0.7 + n * 0.3).normalized()
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_color(col)
		st.set_normal(nv)
		st.set_uv(uvs[i])
		st.add_vertex(ps[i])


# pinheiro: tronco reto (casca do tree_small_02) e andares de ramos caídos com o cartão de agulhas
func _pine(lod: int, leaves: Material) -> ArrayMesh:
	var am := ArrayMesh.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var H := 8.0
	var seg := 8 if lod == 0 else 5
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		for j in 4:
			var y0 := H * 0.85 * j / 4.0
			var y1 := H * 0.85 * (j + 1) / 4.0
			var r0 := lerpf(0.32, 0.06, y0 / H)
			var r1 := lerpf(0.32, 0.06, y1 / H)
			var q := [Vector3(cos(a0) * r0, y0 - (0.3 if j == 0 else 0.0), sin(a0) * r0), Vector3(cos(a1) * r0, y0 - (0.3 if j == 0 else 0.0), sin(a1) * r0),
				Vector3(cos(a1) * r1, y1, sin(a1) * r1), Vector3(cos(a0) * r1, y1, sin(a0) * r1)]
			var uv := [Vector2(float(i) / seg, y0 / 3.0), Vector2(float(i + 1) / seg, y0 / 3.0), Vector2(float(i + 1) / seg, y1 / 3.0), Vector2(float(i) / seg, y1 / 3.0)]
			for k in [0, 2, 1, 0, 3, 2]:
				st.set_color(Color.WHITE)
				st.set_uv(uv[k])
				st.add_vertex(q[k])
	st.generate_normals()
	st.set_material(_bark_mat("tree_small_02_trunk"))
	st.commit(am)
	var lf := SurfaceTool.new()
	lf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var whorls := 9 if lod == 0 else 5
	for w in whorls:
		var t := float(w) / (whorls - 1)
		var y := lerpf(2.0, H - 0.2, t)
		var rad := lerpf(2.4, 0.5, t)
		var nb := (7 if lod == 0 else 4) - int(t * 2.0)
		for b in nb:
			var a := TAU * b / nb + rng.randf_range(-0.3, 0.3) + w * 0.7
			var d := Vector3(cos(a), 0, sin(a))
			# ramo: dois cartões em X saindo do tronco e caindo na ponta (dá volume de qualquer lado)
			var root := Vector3(0, y, 0)
			var tip := d * rad + Vector3(0, -rad * 0.3, 0)
			var shade := lerpf(0.75, 1.1, t)
			var nrm := (d * 0.6 + Vector3.UP).normalized()
			var uvs := [Vector2(0.0, 1.0), Vector2(0.5, 1.0), Vector2(0.5, 0.5), Vector2(0.0, 0.5)]
			var flat := d.cross(Vector3.UP).normalized()
			for sg in [1.0, -1.0]:
				var side: Vector3 = (flat * 0.75 + Vector3.UP * 0.66 * sg).normalized() * rad * 0.5
				var ps := [root - side * 0.25, root + side * 0.25, tip + side, tip - side]
				for tri in [[0, 1, 2], [0, 2, 3]]:
					for k in tri:
						lf.set_color(Color(shade, shade, shade))
						lf.set_normal(nrm)
						lf.set_uv(uvs[k])
						lf.add_vertex(ps[k])
	# ponta
	lf.set_material(leaves)
	lf.commit(am)
	print("pinheiro lod", lod, ": ", _tris(am), " triângulos")
	return am


# moita: cartões fechados num domo
func _bush(leaves: Material) -> ArrayMesh:
	var am := ArrayMesh.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 26:
		var a := rng.randf() * TAU
		var e := rng.randf_range(0.0, 1.2)
		var c := Vector3(cos(a) * cos(e) * 0.42, 0.2 + sin(e) * 0.34, sin(a) * cos(e) * 0.42)
		_card(st, c, Vector3(0, 0.2, 0), rng.randf_range(0.5, 0.7), 3, rng, 0.7, 0.0)
	st.set_material(leaves)
	st.commit(am)
	print("moita: ", _tris(am), " triângulos")
	return am
