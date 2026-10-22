extends SceneTree

# Prepara o boneco (models_src/soldado.fbx, feito no Meshy) pra rodar leve no celular:
# - solda os vértices e reduz a malha (177 mil vértices -> poucos milhares), 4 ossos por vértice
# - pinta as regiões do corpo pela cor do vértice (r = região: pele, camisa, calça, bota, cabelo)
#   pra cada jogador ter a sua cor no shader (models/soldier.gdshader)
# - tira as trilhas dos dedos das animações e cria poses "Idle" e "Air" a partir da caminhada/corrida
# Uso: godot --headless --path . -s tools/prepare_soldier.gd

const SRC := "res://models_src/soldado.fbx"   # fica fora do APK (exclude_filter)
const OUT := "res://models/soldier.scn"
const LODS := [8188, 2048]   # triângulos de cada versão (perto, longe)

var regions := {}


func _initialize() -> void:
	var root: Node3D = (load(SRC) as PackedScene).instantiate()
	var sk: Skeleton3D = root.find_child("Skeleton3D", true, false)
	var mi: MeshInstance3D = root.find_child("mesh_node", true, false)
	var ap: AnimationPlayer = root.find_child("AnimationPlayer", true, false)
	var src: ArrayMesh = mi.mesh
	var a := src.surface_get_arrays(0)
	var pos: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var nrm: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
	var wts: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
	var idx_src: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var bpv := bones.size() / pos.size()
	print("origem: ", pos.size(), " vértices, ", bpv, " ossos/vértice, índices ", idx_src.size())
	# soldar por posição
	var key_to := {}
	var upos := PackedVector3Array()
	var unrm := PackedVector3Array()
	var ubone := PackedInt32Array()
	var uwt := PackedFloat32Array()
	var remap := PackedInt32Array()
	remap.resize(pos.size())
	for i in pos.size():
		var p := pos[i]
		var k := Vector3i(roundi(p.x * 2e6), roundi(p.y * 2e6), roundi(p.z * 2e6))
		if key_to.has(k):
			var j: int = key_to[k]
			remap[i] = j
			unrm[j] += nrm[i]
			continue
		var j := upos.size()
		key_to[k] = j
		remap[i] = j
		upos.append(p)
		unrm.append(nrm[i])
		# 4 ossos mais fortes
		var pairs := []
		for b in bpv:
			pairs.append([wts[i * bpv + b], bones[i * bpv + b]])
		pairs.sort_custom(func(x, y): return x[0] > y[0])
		var tot := 0.0
		for b in 4:
			tot += pairs[b][0]
		for b in 4:
			ubone.append(pairs[b][1])
			uwt.append(pairs[b][0] / maxf(tot, 1e-6))
	var tris := PackedInt32Array()
	var n_src := idx_src.size() if idx_src.size() > 0 else pos.size()
	for t in range(0, n_src, 3):
		var i0 := remap[idx_src[t] if idx_src.size() > 0 else t]
		var i1 := remap[idx_src[t + 1] if idx_src.size() > 0 else t + 1]
		var i2 := remap[idx_src[t + 2] if idx_src.size() > 0 else t + 2]
		if i0 == i1 or i1 == i2 or i0 == i2:
			continue
		tris.append_array([i0, i1, i2])
	print("soldado: ", upos.size(), " vértices, ", tris.size() / 3, " triângulos")
	# região de cada vértice pelo osso mais forte
	var reg := PackedColorArray()
	var head_i := sk.find_bone("mixamorig_Head")
	var head_z := sk.get_bone_global_rest(head_i).origin.z
	for j in upos.size():
		var bn := sk.get_bone_name(ubone[j * 4])
		var r := 1
		if bn.contains("Head") or bn.contains("Neck") or bn.begins_with("Bone_") or bn == "headfront" or bn.contains("Hand"):
			r = 0
			if (bn.contains("Head") or bn.begins_with("Bone_")) and upos[j].z > head_z + 0.0011:
				r = 4
		elif bn.contains("Foot") or bn.contains("Toe"):
			r = 3
		elif bn.contains("Leg") or bn == "mixamorig_Hips":
			r = 2
		reg.append(Color(r / 8.0, 0, 0, 1))
	# versões reduzidas
	var meshes := []
	var im := ImporterMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = upos
	arr[Mesh.ARRAY_NORMAL] = unrm
	arr[Mesh.ARRAY_INDEX] = tris
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arr)
	im.generate_lods(180.0, 180.0, [])
	var levels := []
	for l in im.get_surface_lod_count(0):
		levels.append(im.get_surface_lod_indices(0, l))
		print("  lod ", l, ": ", levels[-1].size() / 3, " triângulos")
	for target in LODS:
		var best: PackedInt32Array = tris
		for lv in levels:
			if absi(lv.size() / 3 - target) < absi(best.size() / 3 - target):
				best = lv
		print("  alvo ", target, " -> ", best.size() / 3, " triângulos")
		meshes.append(_compact(upos, ubone, uwt, reg, best))
	# cena final
	var out := Node3D.new()
	out.name = "Soldier"
	var tc: Node3D = root.get_child(0)
	root.remove_child(tc)
	out.add_child(tc)
	tc.owner = out
	sk.owner = out
	mi.get_parent().remove_child(mi)
	mi.free()
	for k in meshes.size():
		var m := MeshInstance3D.new()
		m.name = "Body%d" % k
		m.mesh = meshes[k]
		m.skeleton = NodePath("..")
		sk.add_child(m)
		m.owner = out
	# animações: sem dedos/rosto, com Idle e Air
	var lib := AnimationLibrary.new()
	var src_lib: AnimationLibrary = ap.get_animation_library("")
	for an_name in src_lib.get_animation_list():
		var an: Animation = src_lib.get_animation(an_name).duplicate(true)
		for t in range(an.get_track_count() - 1, -1, -1):
			var p := str(an.track_get_path(t))
			if p.contains("Thumb") or p.contains("Index") or p.contains("Middle") or p.contains("Ring") or p.contains("Pinky") or p.contains("Bone_") or p.contains("headfront") or p.contains("_End"):
				an.remove_track(t)
		# trilha de posição do quadril tira o deslocamento pra frente (anda no lugar)
		an.loop_mode = Animation.LOOP_LINEAR if an_name in ["Walking", "Running", "Run_03"] else Animation.LOOP_NONE
		an.track_set_path(0, an.track_get_path(0))
		lib.add_animation(an_name, an)
	lib.add_animation("Idle", _rest_pose(lib.get_animation("Walking"), sk))
	lib.add_animation("Air", _pose_from(lib.get_animation("Running"), 0.12))
	var nap := AnimationPlayer.new()
	nap.name = "Anim"
	out.add_child(nap)
	nap.owner = out
	nap.root_node = NodePath("..")
	nap.add_animation_library("", lib)
	var ps := PackedScene.new()
	ps.pack(out)
	ResourceSaver.save(ps, OUT)
	for an_name in lib.get_animation_list():
		print("anim ", an_name, " trilhas=", lib.get_animation(an_name).get_track_count())
	print("salvo ", OUT)
	quit()


func _compact(upos: PackedVector3Array, ubone: PackedInt32Array, uwt: PackedFloat32Array, reg: PackedColorArray, lod: PackedInt32Array) -> ArrayMesh:
	# UV = (lado, altura) e UV2 = (frente, região) na pose de descanso, em metros: o shader pinta
	# roupa/pele/cabelo por altura com bordas suaves, sem "escorregar" quando o boneco anima
	var used := {}
	var vp := PackedVector3Array()
	var vb := PackedInt32Array()
	var vw := PackedFloat32Array()
	var vc := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var ix := PackedInt32Array()
	for i in lod:
		if not used.has(i):
			used[i] = vp.size()
			vp.append(upos[i])
			vc.append(reg[i])
			uv.append(Vector2(upos[i].x * 100.0, upos[i].z * 100.0))
			uv2.append(Vector2(-upos[i].y * 100.0, reg[i].r * 8.0))
			for b in 4:
				vb.append(ubone[i * 4 + b])
				vw.append(uwt[i * 4 + b])
		ix.append(used[i])
	# normais suaves
	var vn := PackedVector3Array()
	vn.resize(vp.size())
	for t in range(0, ix.size(), 3):
		var fa := (vp[ix[t + 1]] - vp[ix[t]]).cross(vp[ix[t + 2]] - vp[ix[t]])
		for k in 3:
			vn[ix[t + k]] += fa
	for i in vn.size():
		vn[i] = vn[i].normalized()
	# a frente da malha: confere a orientação dos triângulos com a normal original
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vp
	arr[Mesh.ARRAY_NORMAL] = vn
	arr[Mesh.ARRAY_COLOR] = vc
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_BONES] = vb
	arr[Mesh.ARRAY_WEIGHTS] = vw
	arr[Mesh.ARRAY_INDEX] = ix
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://models/soldier.gdshader")
	m.surface_set_material(0, mat)
	return m


# parado em pé: pose de descanso do esqueleto (pernas retas); os braços descem por código
func _rest_pose(src: Animation, sk: Skeleton3D) -> Animation:
	var an := Animation.new()
	an.length = 1.0
	an.loop_mode = Animation.LOOP_LINEAR
	for i in src.get_track_count():
		var ty := src.track_get_type(i)
		var path := src.track_get_path(i)
		var bi := sk.find_bone(path.get_concatenated_subnames())
		var k := an.add_track(ty)
		an.track_set_path(k, path)
		var rest := sk.get_bone_rest(bi)
		match ty:
			Animation.TYPE_ROTATION_3D:
				an.rotation_track_insert_key(k, 0.0, rest.basis.get_rotation_quaternion())
			Animation.TYPE_POSITION_3D:
				an.position_track_insert_key(k, 0.0, src.position_track_interpolate(i, 0.0))
			Animation.TYPE_SCALE_3D:
				an.scale_track_insert_key(k, 0.0, Vector3.ONE)
	return an


# animação parada (uma pose só) tirada de um instante de outra animação
func _pose_from(src: Animation, t: float) -> Animation:
	var an := Animation.new()
	an.length = 1.0
	an.loop_mode = Animation.LOOP_LINEAR
	for i in src.get_track_count():
		var ty := src.track_get_type(i)
		var k := an.add_track(ty)
		an.track_set_path(k, src.track_get_path(i))
		match ty:
			Animation.TYPE_ROTATION_3D:
				an.rotation_track_insert_key(k, 0.0, src.rotation_track_interpolate(i, t * src.length))
			Animation.TYPE_POSITION_3D:
				an.position_track_insert_key(k, 0.0, src.position_track_interpolate(i, t * src.length))
			Animation.TYPE_SCALE_3D:
				an.scale_track_insert_key(k, 0.0, src.scale_track_interpolate(i, t * src.length))
	return an
