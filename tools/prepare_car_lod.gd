extends SceneTree
# Gera models/car1_lo.res: o jipe simplificado pra ver de longe (o esportivo já é leve).
# O jipe é feito de muitas peças soltas (o simplificador do Godot não reduz), então junta os
# vértices que caem no mesmo cubinho de CELL metros e tira os triângulos que somem.
# Rodar: godot --headless --script tools/prepare_car_lod.gd
const CELL := 0.09
func _initialize():
	for k in [1]:
		var src: Mesh = load("res://models/car%d.res" % k)
		var out := ArrayMesh.new()
		var tot0 := 0
		var tot1 := 0
		for i in src.get_surface_count():
			var arr := src.surface_get_arrays(i)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(vs.size()))
			var rep := {}
			var remap := PackedInt32Array()
			remap.resize(vs.size())
			for v in vs.size():
				var key := Vector3i((vs[v] / CELL).floor())
				if not rep.has(key):
					rep[key] = v
				remap[v] = rep[key]
			var nidx := PackedInt32Array()
			var seen := {}
			for t in range(0, idx.size(), 3):
				var a := remap[idx[t]]
				var b := remap[idx[t + 1]]
				var c := remap[idx[t + 2]]
				if a == b or b == c or a == c:
					continue
				var tk := Vector3i(a, b, c)
				if seen.has(tk):
					continue
				seen[tk] = true
				nidx.append(a)
				nidx.append(b)
				nidx.append(c)
			tot0 += idx.size() / 3
			tot1 += nidx.size() / 3
			# só os vértices usados (arquivo menor)
			var used := {}
			var order := PackedInt32Array()
			for q in nidx.size():
				if not used.has(nidx[q]):
					used[nidx[q]] = order.size()
					order.append(nidx[q])
				nidx[q] = used[nidx[q]]
			for a in Mesh.ARRAY_MAX:
				if a == Mesh.ARRAY_INDEX or arr[a] == null:
					continue
				# arrays com vários números por vértice (tangente = 4) copiam o grupo inteiro
				var per: int = arr[a].size() / vs.size()
				var dst = arr[a].duplicate()
				dst.resize(order.size() * per)
				for q in order.size():
					for e in per:
						dst[q * per + e] = arr[a][order[q] * per + e]
				arr[a] = dst
			arr[Mesh.ARRAY_INDEX] = nidx
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			out.surface_set_material(i, src.surface_get_material(i))
		ResourceSaver.save(out, "res://models/car%d_lo.res" % k)
		print("carro ", k, ": ", tot0, " -> ", tot1, " triângulos")
	quit()
