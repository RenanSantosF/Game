class_name Soldier
extends Node3D

# Boneco do jogador (models/soldier.scn, preparado por tools/prepare_man.gd a partir do modelo do Meshy, com textura).
# Animações do arquivo (parado, andar, correr, no ar, morrer) + ajustes por código:
# braços alcançam a arma (cinemática inversa), agachar dobra as pernas, o tronco acompanha a mira.

const SCENE := "res://models/soldier.scn"
static var _packed: PackedScene

var body: Node3D
var sk: Skeleton3D
var ap: AnimationPlayer
var meshes: Array = []
var mat: ShaderMaterial
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
	mat = (body.find_child("Body0", true, false).mesh.surface_get_material(0) as ShaderMaterial).duplicate()
	mat.set_shader_parameter("c_skin", skin)
	mat.set_shader_parameter("c_shirt", shirt)
	mat.set_shader_parameter("c_pants", pants)
	mat.set_shader_parameter("c_boots", boots)
	mat.set_shader_parameter("c_hair", hair)
	# quem tira a camisa verde-oliva fica com a jaqueta e o jeans originais da textura
	mat.set_shader_parameter("tint", 0.0 if shirt.is_equal_approx(Color(0.32, 0.36, 0.24)) else 1.0)
	for k in 2:
		var mi: MeshInstance3D = body.find_child("Body%d" % k, true, false)
		mi.material_override = mat
		meshes.append(mi)
	meshes[0].visibility_range_end = 22.0
	meshes[0].visibility_range_end_margin = 2.0
	meshes[1].visibility_range_begin = 22.0
	meshes[1].visibility_range_begin_margin = 2.0
	meshes[1].visibility_range_end = 320.0
	meshes[1].cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for n in ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head", "LeftArm", "LeftForeArm", "LeftHand", "RightArm",
			"RightForeArm", "RightHand", "LeftUpLeg", "LeftLeg", "LeftFoot", "RightUpLeg", "RightLeg", "RightFoot"]:
		b[n] = sk.find_bone("mixamorig_" + n)
	play("Idle")


func play(n: String, blend := 0.18, speed := 1.0) -> void:
	if n != cur:
		cur = n
		ap.play(n, blend)
	ap.speed_scale = speed


# ajuste dos acessórios (medidos no boneco antigo, que tinha a mesma altura): deslocamento e tamanho
const FIT := {"vest": [Vector3(0, -0.08, 0.0), Vector3(1.06, 1.0, 1.1)], "bag": [Vector3(0, -0.11, -0.06), Vector3.ONE],
	"helmet": [Vector3(0, 0.012, 0.0), Vector3(1.06, 1.0, 1.06)]}


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
func tick(delta: float, far: bool, pitch: float, crouch: float, hands: Array) -> void:
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
		_two_bone(b["LeftArm"], b["LeftForeArm"], b["LeftHand"], inv * (hands[0] as Vector3), inv.basis * (down - rt * 0.7 + back * 0.2))
		_two_bone(b["RightArm"], b["RightForeArm"], b["RightHand"], inv * (hands[1] as Vector3), inv.basis * (down + rt * 0.7 + back * 0.2))


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
