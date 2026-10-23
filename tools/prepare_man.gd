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
	# animações da Universal Animation Library (Quaternius, CC0), passadas pro esqueleto do boneco
	var ual := OS.get_environment("UAL_GLB")
	if ual != "":
		get_root().add_child(out)
		_retarget(ual, out, arm, sk, lib)
	var nap := AnimationPlayer.new()
	nap.name = "Anim"
	out.add_child(nap)
	nap.owner = out
	nap.root_node = NodePath("..")
	nap.add_animation_library("", lib)
	if out.get_parent():
		out.get_parent().remove_child(out)
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


func _blend_weights(p: Vector3, upos: PackedVector3Array, ubone: PackedInt32Array, uwt: PackedFloat32Array, grid: Dictionary) -> Array:
	var c := Vector3i((p / 0.03).floor())
	var acc := {}
	var R := 0.045
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			for dz in range(-2, 3):
				var k := c + Vector3i(dx, dy, dz)
				if not grid.has(k):
					continue
				for i in grid[k]:
					var d := p.distance_to(upos[i])
					if d > R:
						continue
					var w := 1.0 / (d + 0.004)
					for b in 4:
						var bi: int = ubone[i * 4 + b]
						acc[bi] = float(acc.get(bi, 0.0)) + uwt[i * 4 + b] * w
	if acc.is_empty():
		var o := _nearest(p, upos, grid)
		return [[ubone[o * 4], ubone[o * 4 + 1], ubone[o * 4 + 2], ubone[o * 4 + 3]], [uwt[o * 4], uwt[o * 4 + 1], uwt[o * 4 + 2], uwt[o * 4 + 3]]]
	var pairs := []
	for bi in acc:
		pairs.append([acc[bi], bi])
	pairs.sort_custom(func(x, y): return x[0] > y[0])
	var bs := []
	var ws := []
	var tot := 0.0
	for k in 4:
		if k < pairs.size():
			tot += pairs[k][0]
	for k in 4:
		if k < pairs.size():
			bs.append(pairs[k][1])
			ws.append(pairs[k][0] / tot)
		else:
			bs.append(0)
			ws.append(0.0)
	return [bs, ws]


# lê a malha reduzida (posição + UV por canto) e mistura os pesos dos vértices originais em volta
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
	# pesos dos ossos: mistura os vizinhos de perto (não só o mais perto), pra roupa dobrar lisa
	var vb_all := []
	for v in vs:
		vb_all.append(_blend_weights(v, upos, ubone, uwt, grid))
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
				var bw: Array = vb_all[cn[0]]
				for b in 4:
					vb.append(bw[0][b])
					vw.append(bw[1][b])
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


# ---------------- animações da Universal Animation Library ----------------
# nome no jogo -> animação da biblioteca
const UAL_ANIMS := {"Idle": "Idle_Loop", "Walking": "Walk_Loop", "Running": "Jog_Fwd_Loop", "Sprint": "Sprint_Loop",
	"CrouchIdle": "Crouch_Idle_Loop", "CrouchWalk": "Crouch_Fwd_Loop", "Dead": "Death01", "Air": "Jump_Loop",
	"PistolIdle": "Pistol_Idle_Loop", "Driving": "Driving_Loop", "Punch": "Punch_Jab", "Land": "Jump_Land"}
# osso do boneco (sem mixamorig_) -> osso da biblioteca
const UAL_BONES := {"Hips": "pelvis", "Spine": "spine_01", "Spine1": "spine_02", "Spine2": "spine_03", "Neck": "neck_01", "Head": "Head",
	"LeftShoulder": "clavicle_l", "LeftArm": "upperarm_l", "LeftForeArm": "lowerarm_l", "LeftHand": "hand_l",
	"RightShoulder": "clavicle_r", "RightArm": "upperarm_r", "RightForeArm": "lowerarm_r", "RightHand": "hand_r",
	"LeftUpLeg": "thigh_l", "LeftLeg": "calf_l", "LeftFoot": "foot_l", "LeftToeBase": "ball_l",
	"RightUpLeg": "thigh_r", "RightLeg": "calf_r", "RightFoot": "foot_r", "RightToeBase": "ball_r"}
# braços e pernas: copia a direção do osso (o descanso das duas bibliotecas é diferente: A x T)
const UAL_DIR := {"LeftArm": "LeftForeArm", "LeftForeArm": "LeftHand", "RightArm": "RightForeArm", "RightForeArm": "RightHand",
	"LeftUpLeg": "LeftLeg", "LeftLeg": "LeftFoot", "RightUpLeg": "RightLeg", "RightLeg": "RightFoot"}


func _to_root(n: Node, root: Node) -> Transform3D:
	var t := Transform3D()
	var c := n
	while c != null and c != root:
		if c is Node3D:
			t = (c as Node3D).transform * t
		c = c.get_parent()
	return t


func _retarget(path: String, out: Node3D, arm: Node3D, sk: Skeleton3D, lib: AnimationLibrary) -> void:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	doc.append_from_file(path, st)
	var src: Node3D = doc.generate_scene(st)
	get_root().add_child(src)
	var ssk: Skeleton3D = src.find_children("*", "Skeleton3D", true, false)[0]
	var sap: AnimationPlayer = src.find_children("*", "AnimationPlayer", true, false)[0]
	sap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var SA := _to_root(ssk, src)
	var TA := _to_root(sk, out)
	var TAr := TA.basis.orthonormalized()
	# quem é quem
	var tb := {}
	var sb := {}
	for n in UAL_BONES:
		tb[n] = sk.find_bone("mixamorig_" + n)
		sb[n] = ssk.find_bone(UAL_BONES[n])
		if tb[n] < 0 or sb[n] < 0:
			print("osso faltando: ", n)
	var t_rest := {}
	var s_rest := {}
	for n in UAL_BONES:
		t_rest[n] = TA * sk.get_bone_global_rest(tb[n])
		s_rest[n] = SA * ssk.get_bone_global_rest(sb[n])
	var hip_k: float = (t_rest["Hips"] as Transform3D).origin.y / maxf((s_rest["Hips"] as Transform3D).origin.y, 0.01)
	var order := ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head", "LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand",
		"RightShoulder", "RightArm", "RightForeArm", "RightHand", "LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase",
		"RightUpLeg", "RightLeg", "RightFoot", "RightToeBase"]
	var prefix := "%s:" % str(out.get_path_to(sk))
	for game_name in UAL_ANIMS:
		var aname: String = UAL_ANIMS[game_name]
		if not sap.has_animation(aname):
			print("sem animação ", aname)
			continue
		var sa: Animation = sap.get_animation(aname)
		var an := Animation.new()
		an.length = sa.length
		an.loop_mode = Animation.LOOP_LINEAR if aname.ends_with("_Loop") else Animation.LOOP_NONE
		var tracks := {}
		for n in order:
			var k := an.add_track(Animation.TYPE_ROTATION_3D)
			an.track_set_path(k, NodePath(prefix + "mixamorig_" + n))
			tracks[n] = k
		var hp := an.add_track(Animation.TYPE_POSITION_3D)
		an.track_set_path(hp, NodePath(prefix + "mixamorig_Hips"))
		sap.play(aname)
		var fps := 30.0
		var nf := maxi(2, int(ceil(sa.length * fps)) + 1)
		for f in nf:
			var t := minf(f / fps, sa.length)
			sap.seek(t, true)
			sap.advance(0.0)
			ssk.force_update_all_bone_transforms()
			var s_pose := {}
			for n in order:
				s_pose[n] = SA * ssk.get_bone_global_pose(sb[n])
			# rotação de cada osso no espaço do modelo
			var t_glob := {}
			for n in order:
				var tr: Transform3D = t_rest[n]
				var q: Basis
				if UAL_DIR.has(n):
					var ch: String = UAL_DIR[n]
					var sd := ((s_pose[ch] as Transform3D).origin - (s_pose[n] as Transform3D).origin).normalized()
					var td := ((t_rest[ch] as Transform3D).origin - tr.origin).normalized()
					q = Basis(Quaternion(td, sd)) * tr.basis.orthonormalized()
				else:
					var d := (s_pose[n] as Transform3D).basis.orthonormalized() * (s_rest[n] as Transform3D).basis.orthonormalized().inverse()
					q = d * tr.basis.orthonormalized()
				t_glob[n] = TAr.inverse() * q
			for n in order:
				var par := sk.get_bone_parent(tb[n])
				var local: Basis
				var pn := ""
				for m in order:
					if tb[m] == par:
						pn = m
				if pn != "":
					local = (t_glob[pn] as Basis).inverse() * (t_glob[n] as Basis)
				else:
					var pg := sk.get_bone_global_rest(par).basis.orthonormalized() if par >= 0 else Basis()
					local = pg.inverse() * (t_glob[n] as Basis)
				an.rotation_track_insert_key(tracks[n], t, local.get_rotation_quaternion())
			# quadril: sobe e desce como na biblioteca (na escala do boneco)
			var dp: Vector3 = ((s_pose["Hips"] as Transform3D).origin - (s_rest["Hips"] as Transform3D).origin) * hip_k
			if game_name != "Dead":
				dp.x = 0.0
				dp.z = 0.0
			var mp: Vector3 = (t_rest["Hips"] as Transform3D).origin + dp
			var skp := TA.affine_inverse() * mp
			var par0 := sk.get_bone_parent(tb["Hips"])
			if par0 >= 0:
				skp = sk.get_bone_global_rest(par0).affine_inverse() * skp
			an.position_track_insert_key(hp, t, skp)
		if lib.has_animation(game_name):
			lib.remove_animation(game_name)
		lib.add_animation(game_name, an)
		print("animação ", game_name, " <- ", aname, " ", an.length, " s  braço mexe: ", (ssk.get_bone_global_pose(sb["LeftArm"]).basis.get_rotation_quaternion().angle_to(ssk.get_bone_global_rest(sb["LeftArm"]).basis.get_rotation_quaternion())))
	src.queue_free()
