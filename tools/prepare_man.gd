extends SceneTree

# Prepara o personagem com textura (models_src/man/man.fbx, do Meshy) pra rodar leve no celular:
# - solda os vértices iguais (posição + UV) e reduz a malha (≈180 mil vértices -> poucos milhares)
# - mantém a textura de cor (jaqueta, jeans, rosto, cabelo), reduzida pra 1024
# - renomeia os ossos pro padrão que o jogo usa (mixamorig_*), tira os dedos das animações
# - cria "Idle" (pose de descanso), "Air" (uma pose da corrida) e "Dead" (cai de costas)
# Uso (3 passos; MAN_TMP = pasta temporária):
#   MAN_STAGE=dump godot --headless -s tools/prepare_man.gd     (exporta a malha completa)
#   python3 tools/decimate_man.py $MAN_TMP                      (reduz mantendo a textura)
#   python3 tools/man_mask.py                                   (textura e máscara da roupa)
#   godot --headless -s tools/prepare_man.gd                    (monta models/soldier.scn)

const SRC := "res://models_src/man/man.fbx"   # fica fora do APK (exclude_filter)
const TEX := "res://models/man_albedo.png"
const OUT := "res://models/soldier.scn"
const LODS := [9000, 2200]   # triângulos de cada versão (perto, longe) — feitas pelo decimate_man.py
const HEIGHT := 1.7          # altura final (o jogo foi medido pra esse tamanho)

# nome no arquivo -> nome usado no jogo (sem o prefixo mixamorig_)
const RENAME := {"Spine02": "Spine", "Spine01": "Spine1", "Spine": "Spine2", "neck": "Neck"}


func _initialize() -> void:
	var root: Node3D = (load(SRC) as PackedScene).instantiate()
	var sk: Skeleton3D = root.find_child("Skeleton3D", true, false)
	var arm: Node3D = sk.get_parent()
	var mi: MeshInstance3D = root.find_child("char1", true, false)
	var ap: AnimationPlayer = root.find_child("AnimationPlayer", true, false)
	var src: ArrayMesh = mi.mesh
	var a := src.surface_get_arrays(0)
	var pos: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
	var wts: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
	var idx_src: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var bpv := bones.size() / pos.size()
	print("origem: ", pos.size(), " vértices, ", idx_src.size() / 3, " triângulos")
	var tmp := OS.get_environment("MAN_TMP")
	# soldar por posição (os pesos dos ossos vêm daqui)
	var key_to := {}
	var upos := PackedVector3Array()
	var ubone := PackedInt32Array()
	var uwt := PackedFloat32Array()
	var remap := PackedInt32Array()
	remap.resize(pos.size())
	for i in pos.size():
		var p := pos[i]
		var k := Vector3i(roundi(p.x * 1e5), roundi(p.y * 1e5), roundi(p.z * 1e5))
		if key_to.has(k):
			remap[i] = key_to[k]
			continue
		key_to[k] = upos.size()
		remap[i] = upos.size()
		upos.append(p)
		for b in 4:
			ubone.append(bones[i * bpv + b])
			uwt.append(wts[i * bpv + b])
	if OS.get_environment("MAN_STAGE") == "dump":
		# malha completa pro tools/decimate_man.py reduzir mantendo a textura
		var f := FileAccess.open(tmp + "/hi.obj", FileAccess.WRITE)
		for p in upos:
			f.store_line("v %f %f %f" % [p.x, p.y, p.z])
		for u in uvs:
			f.store_line("vt %f %f" % [u.x, 1.0 - u.y])
		for t in range(0, idx_src.size(), 3):
			var q := [idx_src[t], idx_src[t + 1], idx_src[t + 2]]
			if remap[q[0]] == remap[q[1]] or remap[q[1]] == remap[q[2]] or remap[q[0]] == remap[q[2]]:
				continue
			f.store_line("f %d/%d %d/%d %d/%d" % [remap[q[0]] + 1, q[0] + 1, remap[q[1]] + 1, q[1] + 1, remap[q[2]] + 1, q[2] + 1])
		f.close()
		print("exportado ", upos.size(), " vértices")
		quit()
		return
	var grid := _grid(upos)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://models/man.gdshader")
	mat.set_shader_parameter("albedo", load(TEX))
	mat.set_shader_parameter("mask", load("res://models/man_mask.png"))
	var meshes := []
	for l in LODS.size():
		meshes.append(_from_obj(tmp + "/lod%d.obj" % l, upos, ubone, uwt, grid, mat))
	# ossos com os nomes do jogo
	for i in sk.get_bone_count():
		var n := sk.get_bone_name(i)
		sk.set_bone_name(i, "mixamorig_" + RENAME.get(n, n))
	# tamanho: mesma altura do boneco antigo
	var s := HEIGHT / src.get_aabb().size.z
	arm.scale = Vector3.ONE * s
	print("escala ", s)
	# cena final
	var out := Node3D.new()
	out.name = "Soldier"
	root.remove_child(arm)
	out.add_child(arm)
	arm.owner = out
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
	# animações
	var lib := AnimationLibrary.new()
	var names := {"walk": "Walking", "run": "Running"}
	for an_name in ap.get_animation_list():
		if not names.has(an_name):
			continue
		var an: Animation = ap.get_animation(an_name).duplicate(true)
		for t in range(an.get_track_count() - 1, -1, -1):
			var p := str(an.track_get_path(t))
			if p.contains("Thumb") or p.contains("Index") or p.contains("Middle") or p.contains("Ring") or p.contains("Pinky") or p.contains("headfront") or p.contains("_end"):
				an.remove_track(t)
				continue
			var bn := p.get_slice(":", 1)
			an.track_set_path(t, NodePath("%s:mixamorig_%s" % [p.get_slice(":", 0), RENAME.get(bn, bn)]))
		an.loop_mode = Animation.LOOP_LINEAR
		_in_place(an)
		lib.add_animation(names[an_name], an)
	var walk := lib.get_animation("Walking")
	lib.add_animation("Idle", _rest_pose(walk, sk))
	lib.add_animation("Air", _pose_from(lib.get_animation("Running"), 0.12))
	lib.add_animation("Dead", _dead(walk, sk))
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
		print("anim ", an_name, " trilhas=", lib.get_animation(an_name).get_track_count(), " dur=", lib.get_animation(an_name).length)
	print("salvo ", OUT)
	quit()


func _grid(upos: PackedVector3Array) -> Dictionary:
	var g := {}
	for i in upos.size():
		var c := Vector3i((upos[i] / 0.03).floor())
		if not g.has(c):
			g[c] = PackedInt32Array()
		g[c].append(i)
	return g


func _nearest(p: Vector3, upos: PackedVector3Array, grid: Dictionary) -> int:
	var c := Vector3i((p / 0.03).floor())
	var best := -1
	var bd := 1e9
	for r in 3:
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				for dz in range(-r, r + 1):
					var k := c + Vector3i(dx, dy, dz)
					if not grid.has(k):
						continue
					for i in grid[k]:
						var d := p.distance_squared_to(upos[i])
						if d < bd:
							bd = d
							best = i
		if best >= 0:
			return best
	return 0


# lê a malha reduzida (posição + UV por canto) e copia os pesos do vértice original mais perto
func _from_obj(path: String, upos: PackedVector3Array, ubone: PackedInt32Array, uwt: PackedFloat32Array, grid: Dictionary, mat: Material) -> ArrayMesh:
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
					corners.append([int(q[0]) - 1, int(q[1]) - 1])
	# normais suaves por posição (inclusive nas costuras da textura)
	var pn := PackedVector3Array()
	pn.resize(vs.size())
	for t in range(0, corners.size(), 3):
		var a: Vector3 = vs[corners[t][0]]
		var fa := (vs[corners[t + 1][0]] - a).cross(vs[corners[t + 2][0]] - a)
		for k in 3:
			pn[corners[t + k][0]] += fa
	var near := PackedInt32Array()
	for v in vs:
		near.append(_nearest(v, upos, grid))
	var used := {}
	var vp := PackedVector3Array()
	var vn := PackedVector3Array()
	var uv := PackedVector2Array()
	var vb := PackedInt32Array()
	var vw := PackedFloat32Array()
	var ix := PackedInt32Array()
	for t in range(0, corners.size(), 3):
		for k in 3:
			var cn: Array = corners[t + k]
			var key := Vector2i(cn[0], cn[1])
			if not used.has(key):
				used[key] = vp.size()
				vp.append(vs[cn[0]])
				vn.append(pn[cn[0]].normalized())
				uv.append(ts[cn[1]])
				var o: int = near[cn[0]]
				for b in 4:
					vb.append(ubone[o * 4 + b])
					vw.append(uwt[o * 4 + b])
			ix.append(used[key])
	print(path.get_file(), ": ", vp.size(), " vértices, ", ix.size() / 3, " triângulos")
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vp
	arr[Mesh.ARRAY_NORMAL] = vn
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_BONES] = vb
	arr[Mesh.ARRAY_WEIGHTS] = vw
	arr[Mesh.ARRAY_INDEX] = ix
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, mat)
	return m


# anda no lugar: tira o avanço do quadril (o jogo é que move o boneco)
func _in_place(an: Animation) -> void:
	for t in an.get_track_count():
		if an.track_get_type(t) != Animation.TYPE_POSITION_3D or not str(an.track_get_path(t)).ends_with("Hips"):
			continue
		var n := an.track_get_key_count(t)
		if n < 2:
			continue
		var p0: Vector3 = an.track_get_key_value(t, 0)
		var p1: Vector3 = an.track_get_key_value(t, n - 1)
		var drift := p1 - p0
		drift.z = 0.0   # altura (z no arquivo) continua
		for k in n:
			var f := an.track_get_key_time(t, k) / maxf(an.length, 0.001)
			an.track_set_key_value(t, k, (an.track_get_key_value(t, k) as Vector3) - drift * f)


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
				an.position_track_insert_key(k, 0.0, rest.origin)
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


# morrer: dobra os joelhos e cai de costas (o quadril gira e desce até o chão)
func _dead(src: Animation, sk: Skeleton3D) -> Animation:
	var an := Animation.new()
	an.length = 0.7
	an.loop_mode = Animation.LOOP_NONE
	var hips := sk.find_bone("mixamorig_Hips")
	var hrest := sk.get_bone_rest(hips)
	# no arquivo z é pra cima e -y é a frente; cair de costas = girar em volta do x
	var fall := Quaternion(Vector3.RIGHT, -1.45)
	var bend := {"mixamorig_LeftUpLeg": 0.5, "mixamorig_RightUpLeg": 0.35, "mixamorig_LeftLeg": -0.7, "mixamorig_RightLeg": -0.45,
		"mixamorig_Spine1": 0.15, "mixamorig_Neck": 0.25, "mixamorig_LeftArm": -0.3, "mixamorig_RightArm": -0.3}
	for i in src.get_track_count():
		var ty := src.track_get_type(i)
		var path := src.track_get_path(i)
		var bn := path.get_concatenated_subnames()
		var bi := sk.find_bone(bn)
		var rest := sk.get_bone_rest(bi)
		var k := an.add_track(ty)
		an.track_set_path(k, path)
		var q0 := rest.basis.get_rotation_quaternion()
		match ty:
			Animation.TYPE_ROTATION_3D:
				if bi == hips:
					an.rotation_track_insert_key(k, 0.0, q0)
					an.rotation_track_insert_key(k, 0.16, Quaternion(Vector3.RIGHT, -0.35) * q0)
					an.rotation_track_insert_key(k, 0.45, fall * q0)
					an.rotation_track_insert_key(k, 0.58, Quaternion(Vector3.RIGHT, -1.52) * q0)
				else:
					var ang: float = bend.get(bn, 0.0)
					var q1 := q0 * Quaternion(Vector3.RIGHT, ang)
					an.rotation_track_insert_key(k, 0.0, q0)
					an.rotation_track_insert_key(k, 0.24, q0.slerp(q1, 0.8))
					an.rotation_track_insert_key(k, 0.5, q1)
			Animation.TYPE_POSITION_3D:
				var p0 := hrest.origin if bi == hips else rest.origin
				an.position_track_insert_key(k, 0.0, p0)
				if bi == hips:
					an.position_track_insert_key(k, 0.16, p0 + Vector3(0, 0.08, -0.3))
					an.position_track_insert_key(k, 0.45, Vector3(p0.x, 0.35, 0.16))
					an.position_track_insert_key(k, 0.58, Vector3(p0.x, 0.4, 0.12))
			Animation.TYPE_SCALE_3D:
				an.scale_track_insert_key(k, 0.0, Vector3.ONE)
	return an
