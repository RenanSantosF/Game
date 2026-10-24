extends SceneTree

# Árvore nova (modelo do usuário, gerado no Tripo, FBX com 18 partes e uma textura cada) pro celular:
#   1) TREE_STAGE=dump: exporta cada parte (posição, UV, normal) em OBJ, já na altura final
#   2) python3 tools/tripo_tree.py <pasta> <pasta .fbm>: junta as texturas num atlas e as partes numa malha
#   3) sem TREE_STAGE: monta models/trees/tripo.res (perto) e tripo_lo.res (longe) com o atlas
# Variáveis: TREE_FBX (res:// do .fbx importado), TREE_TMP (pasta temporária)

const OUT := "res://models/trees/"
const HEIGHT := 8.6


func _initialize() -> void:
	var tmp := OS.get_environment("TREE_TMP")
	if OS.get_environment("TREE_STAGE") == "dump":
		_dump(OS.get_environment("TREE_FBX"), tmp)
	else:
		for lod in 2:
			var m := _compact(_load_obj(tmp + "/tree_lod%d.obj" % lod))
			ResourceSaver.save(m, OUT + ("tripo_lo.res" if lod == 1 else "tripo.res"))
			print("salvo lod ", lod, " tris=", m.surface_get_array_index_len(0) / 3)
	quit()


func _gx(n: Node3D) -> Transform3D:
	var t := n.transform
	var p := n.get_parent()
	while p and p is Node3D:
		t = (p as Node3D).transform * t
		p = p.get_parent()
	return t


func _dump(fbx: String, tmp: String) -> void:
	var root: Node = (load(fbx) as PackedScene).instantiate()
	var parts := root.find_children("*", "MeshInstance3D", true, false)
	var ab := AABB()
	var first := true
	for mi: MeshInstance3D in parts:
		var b := _gx(mi) * mi.get_aabb()
		ab = b if first else ab.merge(b)
		first = false
	var sc := HEIGHT / ab.size.y
	var base := Vector3(ab.get_center().x, ab.position.y, ab.get_center().z)
	var lst := PackedStringArray()
	for mi: MeshInstance3D in parts:
		var xf := _gx(mi)
		var m: Mesh = mi.mesh
		var a := m.surface_get_arrays(0)
		var pos: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		var name := str(mi.name)
		var txt := PackedStringArray()
		for i in pos.size():
			var p := (xf * pos[i] - base) * sc
			txt.append("v %f %f %f" % [p.x, p.y, p.z])
		for i in uv.size():
			txt.append("vt %f %f" % [uv[i].x, 1.0 - uv[i].y])
		for i in range(0, idx.size(), 3):
			var x := idx[i] + 1
			var y := idx[i + 1] + 1
			var z := idx[i + 2] + 1
			txt.append("f %d/%d %d/%d %d/%d" % [x, x, y, y, z, z])
		var f := FileAccess.open(tmp + "/" + name + ".obj", FileAccess.WRITE)
		f.store_string("\n".join(txt))
		f.close()
		lst.append(name)
		print(name, " tris=", idx.size() / 3)
	var f2 := FileAccess.open(tmp + "/parts.txt", FileAccess.WRITE)
	f2.store_string("\n".join(lst))
	f2.close()


# lê o OBJ (v/vt/f com o mesmo índice) em arrays de malha, com normais
func _load_obj(path: String) -> Array:
	var vs := PackedVector3Array()
	var ts := PackedVector2Array()
	var ix := PackedInt32Array()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var p := line.split(" ", false)
		if p.is_empty():
			continue
		if p[0] == "v":
			vs.append(Vector3(float(p[1]), float(p[2]), float(p[3])))
		elif p[0] == "vt":
			ts.append(Vector2(float(p[1]), 1.0 - float(p[2])))
		elif p[0] == "f":
			# Godot desenha no sentido horário
			ix.append(int(p[1].split("/")[0]) - 1)
			ix.append(int(p[3].split("/")[0]) - 1)
			ix.append(int(p[2].split("/")[0]) - 1)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vs
	arr[Mesh.ARRAY_TEX_UV] = ts
	arr[Mesh.ARRAY_INDEX] = ix
	var st := SurfaceTool.new()
	st.create_from_arrays(arr)
	st.generate_normals()
	return st.commit_to_arrays()


# só os vértices usados e o material com o atlas (barato: sem brilho nem sombra recebida)
func _compact(arr: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.create_from_arrays(arr)
	st.index()
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(OUT + "tripo_atlas.png")
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.roughness = 1.0
	mat.disable_receive_shadows = true
	mesh.surface_set_material(0, mat)
	return mesh
