extends SceneTree
# Gera models/soldier_lo.res: o boneco simplificado (~1/4 dos triângulos, mesmo esqueleto/pesos)
# pra ver de longe. Rodar: godot --headless --script tools/prepare_soldier_lod.gd
const TARGET := 0.55
func _initialize():
	var sc = (load("res://models/soldier.scn") as PackedScene).instantiate()
	var body: MeshInstance3D = sc.find_child("Body0", true, false)
	var src: ArrayMesh = body.mesh
	var im := ImporterMesh.new()
	for i in src.get_surface_count():
		im.add_surface(src.surface_get_primitive_type(i), src.surface_get_arrays(i), [], {}, src.surface_get_material(i), "", src.surface_get_format(i))
	im.generate_lods(25.0, 60.0, [])
	var out := ArrayMesh.new()
	for i in im.get_surface_count():
		var arr := im.get_surface_arrays(i)
		var base: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		# simplificação com alvo de triângulos (a automática ia longe demais e abria buracos na
		# roupa, mostrando a pele de baixo)
		var st := SurfaceTool.new()
		st.create_from_arrays(arr)
		var best: PackedInt32Array = st.generate_lod(0.5, int(base.size() * TARGET) / 3 * 3)
		if best.is_empty():
			best = base
		# só os vértices usados (arquivo e memória menores)
		var vn: int = (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var used := {}
		var order := PackedInt32Array()
		var nidx := best.duplicate()
		for q in nidx.size():
			if not used.has(nidx[q]):
				used[nidx[q]] = order.size()
				order.append(nidx[q])
			nidx[q] = used[nidx[q]]
		for a in Mesh.ARRAY_MAX:
			if a == Mesh.ARRAY_INDEX or arr[a] == null:
				continue
			var per: int = arr[a].size() / vn
			var dst = arr[a].duplicate()
			dst.resize(order.size() * per)
			for q in order.size():
				for e in per:
					dst[q * per + e] = arr[a][order[q] * per + e]
			arr[a] = dst
		best = nidx
		arr[Mesh.ARRAY_INDEX] = best
		var fmt := src.surface_get_format(i) & (Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, fmt)
		out.surface_set_material(i, src.surface_get_material(i))
		print("boneco: ", base.size() / 3, " -> ", best.size() / 3)
	ResourceSaver.save(out, "res://models/soldier_lo.res")
	quit()
