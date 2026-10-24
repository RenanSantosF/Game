class_name Soldier
extends Node3D

# Boneco do jogador (models/soldier.scn, preparado por tools/prepare_mixamo.gd: skin e animações do Mixamo).
# Animações do arquivo (parado, andar, correr, pular, cair, paraquedas, morrer...) + ajustes por código:
# braços alcançam a arma (cinemática inversa), agachar dobra as pernas, o tronco acompanha a mira.

const SCENE := "res://models/soldier.scn"
static var _packed: PackedScene

var body: Node3D
var sk: Skeleton3D
var ap: AnimationPlayer
var meshes: Array = []
var cur := ""
var _acc := 0.0
var b := {}            # nome curto -> índice do osso
var _feet_ground := []


static func available() -> bool:
	return ResourceLoader.exists(SCENE)


func setup(skin: Color, shirt: Color, pants: Color, boots: Color, hair: Color) -> void:
	if _packed == null:
		_packed = load(SCENE)
	body = _packed.instantiate()
	body.rotation.y = PI    # o modelo olha pra +Z; o jogo usa -Z como frente
	add_child(body)
	sk = body.find_child("Skeleton3D", true, false)
	ap = body.get_node("Anim")
	ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	# skin fixa (textura do Mixamo): todo mundo igual, as cores recebidas não mudam nada
	for k in 2:
		var mi: MeshInstance3D = body.find_child("Body%d" % k, true, false)
		meshes.append(mi)
	# inimigo aparece igual em qualquer distância (sem trocar de modelo nem sumir de longe);
	# a malha já tem níveis de detalhe automáticos, então a cópia de longe não é usada
	meshes[1].visible = false
	for n in ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head", "LeftArm", "LeftForeArm", "LeftHand", "RightArm",
			"RightForeArm", "RightHand", "LeftHandMiddle1", "RightHandMiddle1", "LeftUpLeg", "LeftLeg", "LeftFoot", "RightUpLeg", "RightLeg", "RightFoot"]:
		b[n] = sk.find_bone("mixamorig_" + n)
	play("Idle")


func has_anim(n: String) -> bool:
	return ap.has_animation(n)


func play(n: String, blend := 0.18, speed := 1.0) -> void:
	if n != cur:
		cur = n
		ap.play(n, blend)
	ap.speed_scale = speed


# ajuste dos acessórios (medidos no boneco antigo, que tinha a mesma altura): deslocamento e tamanho
const FIT := {}   # colete, capacete e mochila já são feitos nas medidas do boneco do Mixamo


# anexa um objeto (colete, capacete, mochila feitos no espaço do boneco) num osso
func attach(bone: String, node: Node3D, fit := "") -> void:
	var ba := BoneAttachment3D.new()
	ba.bone_name = "mixamorig_" + bone
	sk.add_child(ba)
	var rest: Transform3D = body.transform * (sk.get_parent() as Node3D).transform * sk.get_bone_global_rest(b[bone])
	# acerta o acessório no corpo (escala em volta do osso e desloca)
	var f: Array = FIT.get(fit, [Vector3.ZERO, Vector3.ONE])
	var fx := Transform3D(Basis.from_scale(f[1]), rest.origin + f[0]) * Transform3D(Basis(), -rest.origin)
	node.transform = rest.affine_inverse() * fx
	ba.add_child(node)


# Avança a animação e aplica os ajustes. hands = [alvo mão esq., alvo mão dir.] no mundo (ou vazio)
# hand_dirs (opcional): pra onde os dedos de cada mão apontam no mundo (a mão gira junto com a arma,
# senão o pulso fica torto com a rotação da animação do fuzil); pole_k: 0 cotovelo pra fora .. 1 pra baixo
func tick(delta: float, far: bool, pitch: float, crouch: float, hands: Array, hand_dirs: Array = [], pole_k := 0.0) -> void:
	_acc += delta
	# longe: anima menos vezes por segundo
	if far and _acc < 0.1:
		return
	ap.advance(_acc)
	_acc = 0.0
	var inv := sk.global_transform.affine_inverse()
	if crouch > 0.01:
		_crouch(crouch, inv)
	if absf(pitch) > 0.01:
		var right := global_transform.basis.x.normalized()
		for n in ["Spine1", "Spine2"]:
			_rotate_global(b[n], inv.basis * right, -pitch * 0.28)
	if hands.size() == 2:
		var gb := global_transform.basis
		var down := -gb.y.normalized()
		var back := gb.z.normalized()
		var rt := gb.x.normalized()
		var side := lerpf(0.7, 0.3, pole_k)
		_two_bone(b["LeftArm"], b["LeftForeArm"], b["LeftHand"], inv * (hands[0] as Vector3), inv.basis * (down - rt * side + back * 0.2))
		_two_bone(b["RightArm"], b["RightForeArm"], b["RightHand"], inv * (hands[1] as Vector3), inv.basis * (down + rt * side + back * 0.2))
		if hand_dirs.size() == 2:
			_aim_hand(b["LeftHand"], b.get("LeftHandMiddle1", -1), inv.basis * (hand_dirs[0] as Vector3))
			_aim_hand(b["RightHand"], b.get("RightHandMiddle1", -1), inv.basis * (hand_dirs[1] as Vector3))
			# dedos fechados em volta do cabo/guarda-mão (a animação do fuzil deixava a mão aberta)
			_grip("Right", 1.0)
			_grip("Left", 0.8)


static var CURL_SIGN := 1.0
var _fingers := {}


# fecha a mão (k = 0 aberta .. 1 fechada no cabo)
func _grip(side: String, k: float) -> void:
	if not _fingers.has(side):
		var l := []
		for f in ["Index", "Middle", "Ring", "Pinky"]:
			for j in [1, 2, 3]:
				l.append([sk.find_bone("mixamorig_%sHand%s%d" % [side, f, j]), [0.85, 1.0, 0.7][j - 1]])
		var th := []
		for j in [1, 2, 3]:
			th.append([sk.find_bone("mixamorig_%sHandThumb%d" % [side, j]), [0.25, 0.4, 0.35][j - 1]])
		_fingers[side] = [l, th]
	var e: Array = _fingers[side]
	for f in e[0]:
		if f[0] >= 0:
			sk.set_bone_pose_rotation(f[0], Quaternion(Vector3.RIGHT, CURL_SIGN * k * float(f[1])))
	for f in e[1]:
		if f[0] >= 0:
			sk.set_bone_pose_rotation(f[0], sk.get_bone_rest(f[0]).basis.get_rotation_quaternion() * Quaternion(Vector3.FORWARD, -CURL_SIGN * k * float(f[1]) * (1.0 if side == "Right" else -1.0)))


# gira a mão pra os dedos apontarem na direção pedida (espaço do esqueleto)
func _aim_hand(ih: int, imid: int, want: Vector3) -> void:
	if ih < 0 or imid < 0 or want.length_squared() < 1e-6:
		return
	var h := _gpose(ih)
	var cur := (_gpose(imid).origin - h.origin)
	if cur.length_squared() < 1e-8:
		return
	_set_global_rot(ih, Basis(Quaternion(cur.normalized(), want.normalized())) * h.basis)


func _gpose(i: int) -> Transform3D:
	return sk.get_bone_global_pose(i)


func _set_global_rot(i: int, g: Basis) -> void:
	var p := sk.get_bone_parent(i)
	var pg := _gpose(p) if p >= 0 else Transform3D()
	sk.set_bone_pose_rotation(i, (pg.basis.inverse() * g).get_rotation_quaternion())


func _rotate_global(i: int, axis: Vector3, ang: float) -> void:
	var g := _gpose(i)
	_set_global_rot(i, Basis(axis.normalized(), ang) * g.basis)


# cinemática inversa de dois ossos (ombro-cotovelo-mão / quadril-joelho-pé), no espaço do esqueleto
func _two_bone(ia: int, ib: int, ic: int, t: Vector3, pole: Vector3) -> void:
	var pa := _gpose(ia).origin
	var pb := _gpose(ib).origin
	var pc := _gpose(ic).origin
	var la := pa.distance_to(pb)
	var lb := pb.distance_to(pc)
	var d := t - pa
	var L := clampf(d.length(), (la + lb) * 0.05, (la + lb) * 0.999)
	var dir := d.normalized()
	var pl := (pole - dir * pole.dot(dir))
	if pl.length_squared() < 1e-12:
		return
	pl = pl.normalized()
	var x := (la * la - lb * lb + L * L) / (2.0 * L)
	var h := sqrt(maxf(la * la - x * x, 0.0))
	var e := pa + dir * x + pl * h
	var ga := _gpose(ia)
	_set_global_rot(ia, Basis(Quaternion((pb - pa).normalized(), (e - pa).normalized())) * ga.basis)
	var gb := _gpose(ib)
	var pc2 := _gpose(ic).origin
	_set_global_rot(ib, Basis(Quaternion((pc2 - gb.origin).normalized(), (pa + dir * L - e).normalized())) * gb.basis)


# agachar: desce o quadril e mantém os pés no chão dobrando os joelhos
func _crouch(k: float, inv: Transform3D) -> void:
	var feet := [_gpose(b["LeftFoot"]).origin, _gpose(b["RightFoot"]).origin]
	var up := (inv.basis * Vector3.UP).normalized()
	var fwd := (inv.basis * -global_transform.basis.z).normalized()
	var hp := sk.get_bone_pose_position(b["Hips"])
	var drop := up * (inv.basis * Vector3(0, 0.42 * k, 0)).length()
	var hg := _gpose(b["Hips"])
	# a posição do quadril é local ao pai (raiz), que no esqueleto é o próprio espaço
	sk.set_bone_pose_position(b["Hips"], hp + hg.basis.inverse() * Vector3.ZERO + (_parent_basis_inv(b["Hips"]) * -drop))
	_rotate_global(b["Spine"], (inv.basis * global_transform.basis.x).normalized(), -0.35 * k)
	_two_bone(b["LeftUpLeg"], b["LeftLeg"], b["LeftFoot"], feet[0] + fwd * (inv.basis * Vector3(0, 0, 0.12 * k)).length(), fwd)
	_two_bone(b["RightUpLeg"], b["RightLeg"], b["RightFoot"], feet[1] - fwd * (inv.basis * Vector3(0, 0, 0.05 * k)).length(), fwd)


func _parent_basis_inv(i: int) -> Basis:
	var p := sk.get_bone_parent(i)
	return _gpose(p).basis.inverse() if p >= 0 else Basis()
