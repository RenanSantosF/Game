extends SceneTree

# Personagem do Mixamo -> models/soldier.scn
# A skin (malha + textura) vem de um FBX "com skin"; as animações vêm dos FBX "sem skin" (mesmo esqueleto).
# - skin fixa pra todos os jogadores (textura original, sem trocar cor)
# - animações renomeadas pro que o jogo usa; corridas e andar no lugar (o jogo é que move o boneco)
# - "WalkFree": andar com os braços soltos (pernas do andar com rifle + braços do parado)
# Uso: MIXAMO_DIR=models_src/mixamo godot --headless -s tools/prepare_mixamo.gd   (FBX originais em models_src/mixamo)

const OUT := "res://models/soldier.scn"
const TEX := "res://models/soldier_albedo.png"
const HEIGHT := 1.7          # altura final (o jogo foi medido pra esse tamanho)
const SKIN_FILE := "Rifle_Idle"

# trecho do nome do arquivo -> [nome no jogo, repete?, no lugar?]
const ANIMS := [
	["Neutral_Idle", "Idle", true, true],
	["Rifle_Idle", "RifleIdle", true, true],
	["Walk_With_Rifle", "Walking", true, true],
	["correndo_lento", "Running", true, true],
	["correndo_r_pido", "Sprint", true, true],
	["pulando_correndo", "Jump", false, true],
	["saltando_janela", "Vault", false, true],
	["caindo_de_lugar_alto", "JumpDown", false, true],
	["Flying", "Fall", true, true],
	["Hanging_Idle", "Chute", true, true],
	["Hard_Landing", "Land", false, true],
	["Death", "Dead", false, false],
	["Driving", "Driving", true, true],
	["Firing_Rifle", "Fire", true, true],
	["Reload_parado", "Reload", false, true],
	["Reload_1", "ReloadRun", false, true],
	["Reload_agachado", "ReloadCrouch", false, true],
	["Hit_Reaction", "Hit", false, true],
	["Victory", "Victory", false, true],
	["Prone_Forward", "Prone", true, true],
	["Crawl_Backwards", "ProneBack", true, true],
	["Braced_To_Free_Hang", "HangGrab", false, true],
	["Free_Hang_Hop_Right", "HangHop", false, true],
]
# o jogo é que sobe o boneco no pulo: o quadril dessas fica na altura de pé
const LOCK_Y := ["Jump"]
# ossos dos braços (o "WalkFree" pega esses do parado)
const ARM_WORDS := ["Shoulder", "Arm", "Hand"]


func _load(path: String) -> Node:
	var doc := FBXDocument.new()
	var st := FBXState.new()
	if doc.append_from_file(path, st) != OK:
		return null
	return doc.generate_scene(st)


func _find_file(files: PackedStringArray, key: String) -> String:
	for f in files:
		if key in f and f.ends_with(".fbx"):
			return f
	return ""


func _initialize() -> void:
	var dir := OS.get_environment("MIXAMO_DIR")
	if not dir.ends_with("/"):
		dir += "/"
	var files := DirAccess.get_files_at(dir)
	var src := _load(dir + _find_file(files, SKIN_FILE))
	var ssk: Skeleton3D = src.find_children("*", "Skeleton3D", true, false)[0]
	var imi: ImporterMeshInstance3D = src.find_children("*", "ImporterMeshInstance3D", true, false)[0]
	# ---- esqueleto novo (cópia limpa) ----
	var out := Node3D.new()
	out.name = "Soldier"
	var arm := Node3D.new()
	arm.name = "Armature"
	out.add_child(arm)
	arm.owner = out
	var sk := Skeleton3D.new()
	sk.name = "Skeleton3D"
	arm.add_child(sk)
	sk.owner = out
	for i in ssk.get_bone_count():
		sk.add_bone(ssk.get_bone_name(i))
	for i in ssk.get_bone_count():
		sk.set_bone_parent(i, ssk.get_bone_parent(i))
		sk.set_bone_rest(i, ssk.get_bone_rest(i))
	# o descanso da raiz no FBX com skin vem num espaço diferente da malha (e das animações, que já vêm
	# em pé): acerta a raiz pelo bind da malha (aí espaço do esqueleto = espaço da malha, como o jogo espera)
	var skin0: Skin = imi.skin
	var hip := ssk.find_bone("mixamorig_Hips")
	var fix := Transform3D()
	for k in skin0.get_bind_count():
		if skin0.get_bind_name(k) == "mixamorig_Hips" or skin0.get_bind_bone(k) == hip:
			fix = (ssk.get_bone_global_rest(hip) * skin0.get_bind_pose(k)).affine_inverse()
	for i in sk.get_bone_count():
		if sk.get_bone_parent(i) < 0:
			sk.set_bone_rest(i, fix * sk.get_bone_rest(i))
	sk.reset_bone_poses()
	# ---- malha: textura de cor só (leve pro celular), com níveis de detalhe ----
	var im: ImporterMesh = imi.mesh
	var mat0: BaseMaterial3D = im.get_surface_material(0) as BaseMaterial3D
	var albedo: Texture2D = mat0.albedo_texture if mat0 else null
	var img: Image = albedo.get_image() if albedo else null
	if img:
		if img.is_compressed():
			img.decompress()
		img.save_png(ProjectSettings.globalize_path(TEX))
	im.generate_lods(25.0, 60.0, [])
	var mesh := im.get_mesh()
	for k in mesh.get_surface_count():
		mesh.surface_set_material(k, null)     # o material vem do material_override (sem textura embutida)
	var xf: Transform3D = _rel(imi, ssk)
	var aabb := xf * mesh.get_aabb()
	var scale := HEIGHT / aabb.size.y
	arm.scale = Vector3.ONE * scale
	arm.position = Vector3(0, -aabb.position.y * scale, 0)
	print("malha ", mesh.get_surface_count(), " superfícies, aabb=", aabb, " escala=", scale)
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.85
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if img:
		mat.albedo_texture = load(TEX) if ResourceLoader.exists(TEX) else ImageTexture.create_from_image(img)
	for k in 2:
		var mi := MeshInstance3D.new()
		mi.name = "Body%d" % k
		mi.mesh = mesh
		mi.skin = imi.skin
		mi.transform = xf
		mi.material_override = mat
		sk.add_child(mi)
		mi.owner = out
		mi.skeleton = NodePath("..")
	# ---- animações ----
	var lib := AnimationLibrary.new()
	var idle_anim: Animation = null
	for e in ANIMS:
		var f := _find_file(files, e[0])
		if f == "":
			print("faltando arquivo: ", e[0])
			continue
		var s := _load(dir + f)
		var sap: AnimationPlayer = s.find_children("*", "AnimationPlayer", true, false)[0]
		var sa: Animation = sap.get_animation(sap.get_animation_list()[0])
		var an := _clean(sa, e[3], e[1] in LOCK_Y)
		an.loop_mode = Animation.LOOP_LINEAR if e[2] else Animation.LOOP_NONE
		lib.add_animation(e[1], an)
		if e[1] == "Idle":
			idle_anim = an
		print("animação ", e[1], " <- ", f.get_slice("-", 1).substr(0, 40), "  ", snappedf(an.length, 0.01), " s")
		s.free()
	if lib.has_animation("Walking") and idle_anim:
		lib.add_animation("WalkFree", _arms_from(lib.get_animation("Walking"), idle_anim))
	if lib.has_animation("Jump"):
		lib.add_animation("Air", _pose_at(lib.get_animation("Jump"), 0.2))
	var ap := AnimationPlayer.new()
	ap.name = "Anim"
	out.add_child(ap)
	ap.owner = out
	ap.root_node = NodePath("..")
	ap.add_animation_library("", lib)
	var ps := PackedScene.new()
	ps.pack(out)
	ResourceSaver.save(ps, OUT)
	print("salvo ", OUT, " com ", lib.get_animation_list().size(), " animações")
	src.free()
	quit()


func _rel(n: Node, top: Node) -> Transform3D:
	var t := Transform3D()
	var c := n
	while c != null and c != top:
		if c is Node3D:
			t = (c as Node3D).transform * t
		c = c.get_parent()
	return t


# caminho das trilhas pro boneco novo; tira o deslocamento do quadril pra frente/pros lados (no lugar)
func _clean(sa: Animation, in_place: bool, lock_y := false) -> Animation:
	var an := sa.duplicate(true) as Animation
	for t in an.get_track_count():
		var p := str(an.track_get_path(t))
		an.track_set_path(t, NodePath("Armature/Skeleton3D:" + p.get_slice(":", 1)))
	if not in_place:
		return an
	for t in an.get_track_count():
		if an.track_get_type(t) != Animation.TYPE_POSITION_3D or not str(an.track_get_path(t)).ends_with("mixamorig_Hips"):
			continue
		var n := an.track_get_key_count(t)
		if n == 0:
			continue
		var p0: Vector3 = an.track_get_key_value(t, 0)
		for k in n:
			var v: Vector3 = an.track_get_key_value(t, k)
			an.track_set_key_value(t, k, Vector3(p0.x, p0.y if lock_y else v.y, p0.z))
	return an


# andar com braços soltos: braços/ombros/mãos do parado, o resto do andar
func _arms_from(walk: Animation, idle: Animation) -> Animation:
	var an := walk.duplicate(true) as Animation
	for t in range(an.get_track_count() - 1, -1, -1):
		var p := str(an.track_get_path(t))
		for w in ARM_WORDS:
			if w in p.get_slice(":", 1) and not "UpLeg" in p:
				an.remove_track(t)
				break
	for t in idle.get_track_count():
		var p := str(idle.track_get_path(t))
		var bone := p.get_slice(":", 1)
		var is_arm := false
		for w in ARM_WORDS:
			if w in bone:
				is_arm = true
		if not is_arm or idle.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		var nt := an.add_track(Animation.TYPE_ROTATION_3D)
		an.track_set_path(nt, idle.track_get_path(t))
		for k in idle.track_get_key_count(t):
			var tm := idle.track_get_key_time(t, k)
			if tm > an.length:
				break
			an.rotation_track_insert_key(nt, tm, idle.track_get_key_value(t, k))
	an.loop_mode = Animation.LOOP_LINEAR
	return an


# pose parada tirada de um instante (no ar)
func _pose_at(src: Animation, frac: float) -> Animation:
	var an := Animation.new()
	an.length = 0.5
	an.loop_mode = Animation.LOOP_LINEAR
	var t0 := src.length * frac
	for t in src.get_track_count():
		var ty := src.track_get_type(t)
		if ty != Animation.TYPE_ROTATION_3D and ty != Animation.TYPE_POSITION_3D:
			continue
		var nt := an.add_track(ty)
		an.track_set_path(nt, src.track_get_path(t))
		if ty == Animation.TYPE_ROTATION_3D:
			an.rotation_track_insert_key(nt, 0.0, src.rotation_track_interpolate(t, t0))
		else:
			an.position_track_insert_key(nt, 0.0, src.position_track_interpolate(t, t0))
	return an
