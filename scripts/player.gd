class_name Player
extends CharacterBody3D

const SPEED := 6.0
const GRAVITY := 22.0
const JUMP := 7.0
const FALL_SPEED := 20.0       # queda livre
const FALL_MOVE := 22.0
const CHUTE_SPEED := 5.5       # paraquedas
const CHUTE_MOVE := 8.0
const CHUTE_OPEN_H := 60.0
const VAULT_TIME := 0.5

const SHIRTS := [Color(0.32, 0.36, 0.24), Color(0.55, 0.5, 0.38), Color(0.2, 0.24, 0.32), Color(0.42, 0.42, 0.44),
	Color(0.16, 0.16, 0.17), Color(0.45, 0.18, 0.16), Color(0.42, 0.32, 0.22), Color(0.3, 0.4, 0.52), Color(0.68, 0.66, 0.6),
	Color(0.55, 0.45, 0.25), Color(0.25, 0.35, 0.3)]
const PANTS := [Color(0.22, 0.28, 0.4), Color(0.3, 0.33, 0.23), Color(0.15, 0.15, 0.16), Color(0.5, 0.44, 0.33), Color(0.33, 0.33, 0.34), Color(0.38, 0.3, 0.22)]
const SKINS := [Color(0.93, 0.76, 0.62), Color(0.84, 0.64, 0.48), Color(0.68, 0.48, 0.34), Color(0.5, 0.34, 0.23), Color(0.97, 0.82, 0.7), Color(0.76, 0.56, 0.4)]
const HAIRS := [Color(0.1, 0.08, 0.06), Color(0.24, 0.16, 0.1), Color(0.4, 0.3, 0.18), Color(0.05, 0.05, 0.05), Color(0.55, 0.45, 0.3)]
const OLIVE := Color(0.38, 0.42, 0.28)

static var _shared := {}

var game: Node
var pid := 0
var nick := ""
var is_local := false
var is_bot := false
var visual := true

var hp := 100.0
var alive := true
var spect := false       # entrou com a partida em andamento: só assiste
var yaw := 0.0           # para onde o corpo olha
var pitch := 0.0         # mira pra cima/baixo
var guns := [{"id": "", "att": []}, {"id": "", "att": []}, {"id": "glock", "att": []}]
var sel := 2             # 0/1 = principais, 2 = pistola, -1 = mãos livres
var mag := {}
var reload_t := 0.0
var cool := 0.0
var scoped := false
var crouch := false
var want_jump := false
var wish := Vector3.ZERO  # direção desejada no mundo (comprimento até 1)
var shown_wid := "glock"
var air := 0             # 0 = no chão, 1 = queda livre, 2 = paraquedas, 3 = no avião
var armor := 0.0
var helmet := false
var bag := false
var inv := {}
var heal_t := 0.0
var heal_kind := ""
var punch_t := 0.0
var vault_t := -1.0
var _vault := []
var aim_t := 0.0         # tempo virado pra mira depois de atirar
var _air_time := 0.0
var _step_t := 0.0

# jogadores remotos (interpolação)
var target_pos := Vector3.ZERO
var target_yaw := 0.0
var target_pitch := 0.0
var est_speed := 0.0
var _last_pos := Vector3.ZERO
var _was_floor := true

# visual
var model: Node3D
var aim: Node3D
var gun: Node3D
var gun_key := ""
var leg_l: Node3D
var leg_r: Node3D
var knee_l: Node3D
var knee_r: Node3D
var arm_parts := []      # [upper, fore, hand] x2 (esq, dir)
var vest_mi: MeshInstance3D
var helmet_mi: MeshInstance3D
var bag_mi: MeshInstance3D
var head_n: Node3D
var chute: Node3D
var tag: Label3D
var anim_t := 0.0
var cshape: CollisionShape3D
var cap: CapsuleShape3D

# bot
var b_think := 0.0
var b_target := 0
var b_react := 0.5
var b_strafe := 0.0
var b_strafe_t := 0.0
var b_dest := Vector3.ZERO
var b_dest_t := 0.0
var b_stuck_t := 0.0
var b_last := Vector3.ZERO
var b_jump_at := 0.5
var b_item := -1
var b_way := 0
var b_item_t := 0.0
var b_ignore := {}
var b_skill := 1.0
var b_far := false


func setup(g: Node, id: int, n: String, local: bool, bot: bool, vis: bool) -> void:
	game = g
	pid = id
	nick = n
	is_local = local
	is_bot = bot
	visual = vis


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_max_angle = deg_to_rad(50)
	floor_snap_length = 0.4
	cshape = CollisionShape3D.new()
	cap = CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cshape.shape = cap
	cshape.position.y = 0.9
	add_child(cshape)
	target_pos = position
	_last_pos = position
	b_last = position
	b_think = randf() * 0.3
	b_skill = randf_range(0.75, 1.2)
	refill()
	if visual:
		_build_model()
	update_gun()


func refill() -> void:
	for k in Weapons.DATA:
		mag[k] = Weapons.DATA[k]["mag"]


func cur_wid() -> String:
	if sel >= 0 and sel < 3 and guns[sel]["id"] != "":
		return guns[sel]["id"]
	return "fist"


func cur_att() -> Array:
	if sel >= 0 and sel < 3:
		return guns[sel]["att"]
	return []


func cur_stat() -> Dictionary:
	return Weapons.stat(cur_wid(), cur_att())


func att_of(wid: String) -> Array:
	for g in guns:
		if g["id"] == wid:
			return g["att"]
	return []


func has_gun(wid: String) -> bool:
	if wid == "fist":
		return true
	for g in guns:
		if g["id"] == wid:
			return true
	return false


func head_y() -> float:
	return 1.03 if crouch else 1.48


func capacity() -> int:
	return Weapons.BAG_BIG if bag else Weapons.BAG_BASE


func free_slots() -> int:
	return capacity() - Weapons.slots_used(inv)


func count(kind: String) -> int:
	return int(inv.get(kind, 0))


func flags() -> int:
	return air | (int(crouch) << 2) | (int(heal_t > 0.0) << 3) | (int(vault_t >= 0.0) << 4) | (int(punch_t > 0.0) << 5) | (int(not is_on_floor() and air == 0) << 6)


func set_flags(f: int) -> void:
	air = f & 3
	set_crouch(((f >> 2) & 1) == 1)
	heal_t = 1.0 if ((f >> 3) & 1) == 1 else 0.0
	vault_t = 0.2 if ((f >> 4) & 1) == 1 else -1.0
	if ((f >> 5) & 1) == 1 and punch_t <= 0.0:
		punch_t = 0.3
	_remote_air = ((f >> 6) & 1) == 1


var _remote_air := false


func set_crouch(c: bool) -> void:
	if c == crouch:
		return
	crouch = c
	cap.height = 1.25 if c else 1.8
	cshape.position.y = cap.height / 2.0


# ---------------- modelo ----------------

# membro afunilado apontando pra baixo (coxa, canela), com junta redonda em cima
static func _limb(rb: float, rt: float, h: float, col: Color, layer: int, foot := false) -> Mesh:
	var key := "limb_%s_%.3f_%.3f_%.3f_%s_%d" % [col.to_html(), rb, rt, h, foot, layer]
	if _shared.has(key):
		return _shared[key]
	var m := MB.new()
	m.tex(layer, 3.0)
	m.cyl(Transform3D(Basis(Vector3.RIGHT, PI), Vector3.ZERO), rb, rt, h, 8, col, true, true)
	m.blob(Transform3D(Basis.from_scale(Vector3(rb, rb, rb)), Vector3.ZERO), 8, 4, col)
	if foot:
		var boot := Color(0.2, 0.17, 0.14)
		m.tex(U.PLAIN, 4.0)
		m.box(Transform3D(Basis(), Vector3(0, -h - 0.04, -0.045)), Vector3(0.115, 0.09, 0.27), boot)
		m.cyl(Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0, -h + 0.08, 0)), rt + 0.012, rt + 0.018, 0.1, 8, boot, false)
	var mesh := m.commit()
	_shared[key] = mesh
	return mesh


# segmento de braço ao longo de -Y com comprimento 1 (escalado depois)
static func _seg(r0: float, r1: float, col: Color, layer: int, hand := false) -> Mesh:
	var key := "seg_%s_%.3f_%.3f_%s_%d" % [col.to_html(), r0, r1, hand, layer]
	if _shared.has(key):
		return _shared[key]
	var m := MB.new()
	m.tex(layer, 3.0)
	if hand:
		m.blob(Transform3D(Basis.from_scale(Vector3(0.04, 0.055, 0.05)), Vector3(0, -0.04, 0)), 7, 4, col)
		m.blob(Transform3D(Basis.from_scale(Vector3(0.015, 0.03, 0.015)), Vector3(0.035, -0.03, -0.03)), 5, 3, col)
	else:
		m.cyl(Transform3D(Basis(Vector3.RIGHT, PI), Vector3.ZERO), r0, r1, 1.0, 7, col, false, true)
		m.blob(Transform3D(Basis.from_scale(Vector3(r0, r0 * 0.3, r0)), Vector3.ZERO), 7, 3, col)
	var mesh := m.commit()
	_shared[key] = mesh
	return mesh


static func _gear(kind: String) -> Mesh:
	if _shared.has(kind):
		return _shared[kind]
	var m := MB.new()
	match kind:
		"vest":
			m.tex(U.FABRIC, 3.0)
			m.box(Transform3D(Basis(), Vector3(0, 1.3, -0.005)), Vector3(0.47, 0.42, 0.29), OLIVE)
			m.box(Transform3D(Basis(), Vector3(0, 1.2, -0.155)), Vector3(0.38, 0.13, 0.04), OLIVE.darkened(0.2))
			for sx in [-0.12, 0.12]:
				m.box(Transform3D(Basis(), Vector3(sx, 1.53, -0.02)), Vector3(0.08, 0.06, 0.26), OLIVE.darkened(0.1))
		"helmet":
			m.tex(U.PLAIN, 3.0)
			m.blob(Transform3D(Basis.from_scale(Vector3(0.14, 0.12, 0.155)), Vector3(0, 1.735, 0.005)), 10, 5, OLIVE)
			m.box(Transform3D(Basis(), Vector3(0, 1.685, -0.005)), Vector3(0.29, 0.025, 0.32), OLIVE.darkened(0.15))
		"bag":
			m.tex(U.FABRIC, 3.0)
			m.box(Transform3D(Basis(), Vector3(0, 1.25, 0.21)), Vector3(0.34, 0.44, 0.17), Color(0.45, 0.4, 0.3))
			m.box(Transform3D(Basis(), Vector3(0, 1.12, 0.3)), Vector3(0.28, 0.16, 0.06), Color(0.4, 0.35, 0.26))
		"chute":
			var cc := Color(0.5, 0.55, 0.38)
			m.tex(U.FABRIC, 0.6)
			m.blob(Transform3D(Basis.from_scale(Vector3(2.6, 0.7, 1.8)), Vector3(0, 6.0, 0)), 12, 3, cc, null, 0.0, true, 0.4)
			var line := Color(0.2, 0.2, 0.18)
			m.tex(U.PLAIN, 1.0)
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					var top := Vector3(sx * 2.2, 5.8, sz * 1.3)
					var bot := Vector3(sx * 0.2, 1.5, sz * 0.1)
					var dir := (top - bot)
					var bb := Basis(Quaternion(Vector3.UP, dir.normalized()))
					m.box(Transform3D(bb, (top + bot) / 2.0), Vector3(0.02, dir.length(), 0.02), line)
	var mesh := m.commit()
	_shared[kind] = mesh
	return mesh


func _build_model() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(pid) * 7919 + 13
	var shirt: Color = SHIRTS[rng.randi() % SHIRTS.size()]
	var pants: Color = PANTS[rng.randi() % PANTS.size()]
	var skin: Color = SKINS[rng.randi() % SKINS.size()]
	var hair: Color = HAIRS[rng.randi() % HAIRS.size()]
	var long_sleeve := rng.randf() < 0.5
	var cap_hat := rng.randf() < 0.3
	model = Node3D.new()
	add_child(model)
	# corpo (uma malha só): quadril, barriga, peito, ombros, pescoço, cabeça com rosto
	var m := MB.new()
	m.tex(U.FABRIC, 3.0)
	m.box(Transform3D(Basis(), Vector3(0, 0.97, 0)), Vector3(0.34, 0.2, 0.22), pants)
	m.box(Transform3D(Basis(), Vector3(0, 1.075, 0)), Vector3(0.35, 0.04, 0.225), Color(0.2, 0.16, 0.12))
	m.box(Transform3D(Basis(), Vector3(0, 1.17, 0.0)), Vector3(0.34, 0.18, 0.21), shirt.darkened(0.04))
	m.box(Transform3D(Basis(), Vector3(0, 1.34, -0.005)), Vector3(0.42, 0.2, 0.24), shirt)
	m.box(Transform3D(Basis(Vector3.RIGHT, -0.15), Vector3(0, 1.35, -0.09)), Vector3(0.38, 0.17, 0.1), shirt)
	m.box(Transform3D(Basis(), Vector3(0, 1.47, 0.0)), Vector3(0.36, 0.07, 0.2), shirt)
	for sx in [-0.21, 0.21]:
		m.blob(Transform3D(Basis.from_scale(Vector3(0.075, 0.07, 0.08)), Vector3(sx, 1.45, 0)), 7, 4, shirt)
	m.tex(U.PLAIN, 3.0)
	m.cyl(Transform3D(Basis(), Vector3(0, 1.48, 0.005)), 0.055, 0.05, 0.1, 7, skin, false)
	# cabeça
	var hc := Vector3(0, 1.66, -0.005)
	m.blob(Transform3D(Basis.from_scale(Vector3(0.098, 0.12, 0.112)), hc), 10, 6, skin)
	m.blob(Transform3D(Basis.from_scale(Vector3(0.075, 0.05, 0.08)), hc + Vector3(0, -0.07, -0.025)), 8, 4, skin)
	m.box(Transform3D(Basis(Vector3.RIGHT, -0.25), hc + Vector3(0, -0.005, -0.112)), Vector3(0.028, 0.05, 0.03), skin.darkened(0.06))
	for sx in [-0.038, 0.038]:
		m.box(Transform3D(Basis(), hc + Vector3(sx, 0.022, -0.1)), Vector3(0.026, 0.014, 0.01), Color(0.95, 0.95, 0.95))
		m.box(Transform3D(Basis(), hc + Vector3(sx, 0.022, -0.105)), Vector3(0.012, 0.012, 0.006), Color(0.12, 0.1, 0.08))
		m.box(Transform3D(Basis(), hc + Vector3(sx, 0.045, -0.103)), Vector3(0.034, 0.008, 0.012), hair.darkened(0.2))
	m.box(Transform3D(Basis(), hc + Vector3(0, -0.055, -0.1)), Vector3(0.04, 0.007, 0.01), skin.darkened(0.3))
	for sx in [-1.0, 1.0]:
		m.blob(Transform3D(Basis.from_scale(Vector3(0.015, 0.03, 0.022)), hc + Vector3(sx * 0.098, 0.0, 0.01)), 6, 3, skin.darkened(0.05))
	if cap_hat:
		m.tex(U.FABRIC, 4.0)
		var hat: Color = SHIRTS[rng.randi() % SHIRTS.size()]
		m.blob(Transform3D(Basis.from_scale(Vector3(0.105, 0.07, 0.118)), hc + Vector3(0, 0.055, 0.0)), 9, 4, hat)
		m.box(Transform3D(Basis(Vector3.RIGHT, 0.12), hc + Vector3(0, 0.06, -0.13)), Vector3(0.17, 0.012, 0.09), hat.darkened(0.1))
	else:
		m.blob(Transform3D(Basis.from_scale(Vector3(0.104, 0.085, 0.118)), hc + Vector3(0, 0.045, 0.014)), 9, 4, hair)
	U.mesh(model, m.commit())
	vest_mi = U.mesh(model, _gear("vest"))
	helmet_mi = U.mesh(model, _gear("helmet"))
	bag_mi = U.mesh(model, _gear("bag"))
	# pernas com joelho
	leg_l = _leg(model, -0.095, pants)
	leg_r = _leg(model, 0.095, pants)
	knee_l = leg_l.get_child(1)
	knee_r = leg_r.get_child(1)
	# mira (gira com o pitch); a arma fica aqui e os braços alcançam a arma
	aim = Node3D.new()
	aim.position = Vector3(0, 1.4, 0)
	model.add_child(aim)
	var sleeve := shirt
	var fore := shirt.darkened(0.05) if long_sleeve else skin
	for side in 2:
		var up := MeshInstance3D.new()
		up.mesh = _seg(0.058, 0.048, sleeve, U.FABRIC)
		up.material_override = U.wmat()
		model.add_child(up)
		var fo := MeshInstance3D.new()
		fo.mesh = _seg(0.046, 0.036, fore, U.FABRIC if long_sleeve else U.PLAIN)
		fo.material_override = U.wmat()
		model.add_child(fo)
		var ha := MeshInstance3D.new()
		ha.mesh = _seg(0.0, 0.0, skin, U.PLAIN, true)
		ha.material_override = U.wmat()
		model.add_child(ha)
		arm_parts.append([up, fo, ha])
	chute = Node3D.new()
	U.mesh(chute, _gear("chute"))
	chute.visible = false
	add_child(chute)
	tag = Label3D.new()
	tag.text = nick
	tag.position = Vector3(0, 2.2, 0)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.pixel_size = 0.004
	tag.font_size = 38
	tag.outline_size = 10
	tag.modulate = Color(1, 1, 1, 0.85)
	tag.visible = false
	add_child(tag)
	for c in model.get_children():
		if c is GeometryInstance3D:
			c.visibility_range_end = 320.0
	refresh_gear()


func _leg(parent: Node3D, x: float, pants: Color) -> Node3D:
	var hip := Node3D.new()
	hip.position = Vector3(x, 0.92, 0)
	parent.add_child(hip)
	var th := MeshInstance3D.new()
	th.mesh = _limb(0.095, 0.07, 0.45, pants, U.FABRIC)
	th.material_override = U.wmat()
	hip.add_child(th)
	var knee := Node3D.new()
	knee.position = Vector3(0, -0.45, 0)
	hip.add_child(knee)
	var sh := MeshInstance3D.new()
	sh.mesh = _limb(0.068, 0.05, 0.42, pants.darkened(0.04), U.FABRIC, true)
	sh.material_override = U.wmat()
	knee.add_child(sh)
	return hip


func refresh_gear() -> void:
	if not visual or model == null:
		return
	vest_mi.visible = armor > 0.0
	helmet_mi.visible = helmet
	bag_mi.visible = bag


func update_gun() -> void:
	shown_wid = cur_wid()
	_set_gun_model(shown_wid, cur_att())


func _set_gun_model(w: String, att: Array) -> void:
	var key := w + "|" + ",".join(att)
	if not visual or aim == null or key == gun_key:
		return
	if gun:
		gun.queue_free()
		gun = null
	gun_key = key
	if w == "fist":
		return
	gun = Weapons.build_model(w, att)
	var t: String = Weapons.get_w(w)["type"]
	gun.position = Vector3(0.13, -0.02, -0.36) if t != "pistol" else Vector3(0.06, 0.0, -0.45)
	aim.add_child(gun)
	for c in gun.get_children():
		if c is GeometryInstance3D:
			c.visibility_range_end = 200.0


func muzzle_pos() -> Vector3:
	if gun and gun.has_node("Muzzle"):
		return gun.get_node("Muzzle").global_position
	return global_position + Vector3(0, 1.45, 0)


func net_target(pos: Vector3, yw: float, pt: float, wid: String, fl: int) -> void:
	target_pos = pos
	target_yaw = yw
	target_pitch = pt
	set_flags(fl)
	if pos.distance_to(position) > 10.0:
		position = pos
	shown_wid = wid
	_set_gun_model(wid, att_of(wid))


func die() -> void:
	alive = false
	hp = 0.0
	collision_layer = 0
	scoped = false
	reload_t = 0.0
	heal_t = 0.0
	vault_t = -1.0
	set_crouch(false)
	velocity = Vector3.ZERO
	if model:
		model.visible = false


# Volta ao estado inicial (nova partida)
func reset_state(pos: Vector3) -> void:
	alive = true
	spect = false
	hp = 100.0
	collision_layer = 2
	collision_mask = 1
	guns = [{"id": "", "att": []}, {"id": "", "att": []}, {"id": "glock", "att": []}]
	sel = 2
	scoped = false
	reload_t = 0.0
	heal_t = 0.0
	vault_t = -1.0
	armor = 0.0
	helmet = false
	bag = false
	inv = {}
	air = 0
	set_crouch(false)
	refill()
	position = pos
	target_pos = pos
	velocity = Vector3.ZERO
	b_item = -1
	b_ignore = {}
	b_target = 0
	update_gun()
	refresh_gear()
	if model:
		model.rotation = Vector3.ZERO
		model.position = Vector3.ZERO
		model.visible = true


func board() -> void:
	air = 3
	set_crouch(false)
	velocity = Vector3.ZERO
	collision_mask = 0


func leave_plane(pos: Vector3) -> void:
	air = 1
	collision_mask = 1
	position = pos
	target_pos = pos
	velocity = Vector3.ZERO


func _physics_process(delta: float) -> void:
	cool = maxf(cool - delta, 0.0)
	punch_t = maxf(punch_t - delta, 0.0)
	aim_t = maxf(aim_t - delta, 0.0)
	if reload_t > 0.0:
		reload_t -= delta
		if reload_t <= 0.0:
			reload_t = 0.0
			var w := cur_wid()
			mag[w] = cur_stat()["mag"]
			if is_local:
				game.sfx("reload_in")
	var sim := is_local or (is_bot and multiplayer.is_server())
	if sim and heal_t > 0.0:
		heal_t -= delta
		if heal_t <= 0.0:
			heal_t = 0.0
			game.heal_done(self, heal_kind)
	if sim:
		if alive:
			if is_bot and not (b_far and Engine.get_physics_frames() % 3 != pid % 3):
				_bot(delta * (3.0 if b_far else 1.0))
			if vault_t >= 0.0:
				_vault_step(delta)
			else:
				_move(delta)
	else:
		if air == 3:
			position = game.plane_pos()
		else:
			position = position.lerp(target_pos, minf(1.0, 15.0 * delta))
		yaw = lerp_angle(yaw, target_yaw, minf(1.0, 15.0 * delta))
		pitch = lerpf(pitch, target_pitch, minf(1.0, 15.0 * delta))
		est_speed = lerpf(est_speed, Vector2(position.x - _last_pos.x, position.z - _last_pos.z).length() / maxf(delta, 0.001), 0.2)
		_last_pos = position
	if visual:
		_steps(delta, sim)
		if game.near_cam(position, 140.0):
			_animate(delta, sim)


func _move(delta: float) -> void:
	if air == 3:
		velocity = Vector3.ZERO
		position = game.plane_pos()
		return
	var dir := wish
	if dir.length() > 1.0:
		dir = dir.normalized()
	if air == 1 or air == 2:
		var hs := FALL_MOVE if air == 1 else CHUTE_MOVE
		var k := minf(1.0, 2.5 * delta)
		velocity.x = lerpf(velocity.x, dir.x * hs, k)
		velocity.z = lerpf(velocity.z, dir.z * hs, k)
		velocity.y = -FALL_SPEED if air == 1 else -CHUTE_SPEED
		if dir.length() > 0.1:
			yaw = lerp_angle(yaw, atan2(-dir.x, -dir.z), minf(1.0, 4.0 * delta))
		move_and_slide()
		# não deixa sair da área do mapa durante a queda
		var lim := World.PLAY - 4.0
		position.x = clampf(position.x, -lim, lim)
		position.z = clampf(position.z, -lim, lim)
		if is_on_floor():
			air = 0
			velocity = Vector3.ZERO
			if is_local:
				game.on_landed()
		elif air == 1 and position.y - game.world.height(position.x, position.z) < CHUTE_OPEN_H:
			air = 2
			if is_local:
				game.sfx("chute")
		_keep_in()
		return
	var spd := SPEED
	if sel < 0 or cur_wid() == "fist":
		spd = 6.9
	if crouch:
		spd = 2.8
	if scoped:
		spd = minf(spd, 3.2)
	if heal_t > 0.0:
		spd = 2.0
	if game.world.in_water(position):
		spd = minf(spd, 3.2)
	if is_bot:
		spd = minf(spd, 5.4)
	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	# corpo vira pra onde anda, ou pra mira quando está atirando
	if not is_bot:
		if aim_t > 0.0 or scoped:
			yaw = lerp_angle(yaw, game.cam_yaw_v, minf(1.0, 18.0 * delta))
		elif dir.length() > 0.15:
			yaw = lerp_angle(yaw, atan2(-dir.x, -dir.z), minf(1.0, 10.0 * delta))
	var on_floor := is_on_floor()
	if not on_floor:
		velocity.y -= GRAVITY * delta
		_air_time += delta
	elif want_jump:
		if crouch:
			set_crouch(false)
		elif not try_vault(dir if dir.length() > 0.1 else Basis(Vector3.UP, yaw) * Vector3.FORWARD):
			velocity.y = JUMP
			if is_local:
				game.sfx("jump")
	want_jump = false
	move_and_slide()
	if is_on_floor() and not _was_floor and _air_time > 0.35:
		game.sfx_at("land", global_position, is_local)
	if is_on_floor():
		_air_time = 0.0
	_was_floor = is_on_floor()
	_keep_in()


func _keep_in() -> void:
	if position.y < -60.0:
		position = game.world.random_spawn(game.rng)
		velocity = Vector3.ZERO
		air = 0


# ---------------- pular janela / muro baixo ----------------

func try_vault(dir: Vector3) -> bool:
	if air != 0 or vault_t >= 0.0:
		return false
	var f := Vector3(dir.x, 0, dir.z)
	if f.length() < 0.1:
		return false
	f = f.normalized()
	var space := get_world_3d().direct_space_state
	var base := global_position
	var ex := [get_rid()]
	var hit_d := 99.0
	for hgt in [0.45, 0.85, 1.2]:
		var q := PhysicsRayQueryParameters3D.create(base + Vector3(0, hgt, 0), base + Vector3(0, hgt, 0) + f * 1.25, 1, ex)
		var r := space.intersect_ray(q)
		if not r.is_empty():
			hit_d = minf(hit_d, Vector2(r["position"].x - base.x, r["position"].z - base.z).length())
	if hit_d > 1.2:
		return false
	# tem que ter vão em cima (janela ou muro baixo)
	for hgt in [1.6, 1.9]:
		var q := PhysicsRayQueryParameters3D.create(base + Vector3(0, hgt, 0), base + Vector3(0, hgt, 0) + f * (hit_d + 1.0), 1, ex)
		if not space.intersect_ray(q).is_empty():
			return false
	# altura do topo do obstáculo
	var tq := PhysicsRayQueryParameters3D.create(base + f * (hit_d + 0.12) + Vector3(0, 2.0, 0), base + f * (hit_d + 0.12) + Vector3(0, 0.2, 0), 1, ex)
	var tr := space.intersect_ray(tq)
	if tr.is_empty():
		return false
	var top: float = tr["position"].y - base.y
	if top < 0.4 or top > 1.45:
		return false
	# onde vai cair do outro lado
	for extra in [0.75, 1.1, 1.5]:
		var p: Vector3 = base + f * (hit_d + extra)
		var dq := PhysicsRayQueryParameters3D.create(p + Vector3(0, top + 0.5, 0), p + Vector3(0, -3.0, 0), 1, ex)
		var dr := space.intersect_ray(dq)
		if dr.is_empty():
			continue
		var land: Vector3 = dr["position"]
		if land.y > base.y + top - 0.25:
			continue
		var cq := PhysicsRayQueryParameters3D.create(land + Vector3(0, 0.3, 0), land + Vector3(0, 1.7, 0), 1, ex)
		if not space.intersect_ray(cq).is_empty():
			continue
		_vault = [base, base + f * (hit_d * 0.6) + Vector3(0, top + 0.35, 0), land + Vector3(0, 0.05, 0)]
		vault_t = 0.0
		collision_mask = 0
		yaw = atan2(-f.x, -f.z)
		set_crouch(false)
		game.sfx_at("vault", base, is_local)
		return true
	return false


func _vault_step(delta: float) -> void:
	vault_t += delta
	var k := clampf(vault_t / VAULT_TIME, 0.0, 1.0)
	var a: Vector3 = _vault[0]
	var m: Vector3 = _vault[1]
	var c: Vector3 = _vault[2]
	position = a.lerp(m, k).lerp(m.lerp(c, k), k)
	velocity = Vector3.ZERO
	if k >= 1.0:
		vault_t = -1.0
		collision_mask = 1


# ---------------- passos ----------------

func _steps(delta: float, sim: bool) -> void:
	if not alive or spect or air != 0 or vault_t >= 0.0:
		return
	var sp := Vector2(velocity.x, velocity.z).length() if sim else est_speed
	var airborne := (not is_on_floor()) if sim else _remote_air
	if sp < 1.2 or airborne:
		_step_t = 0.0
		return
	_step_t -= delta
	if _step_t <= 0.0:
		_step_t = clampf(2.3 / sp, 0.28, 0.6)
		game.on_step(self, crouch)


# ---------------- animação ----------------

func _animate(delta: float, sim: bool) -> void:
	var sp := est_speed
	if sim:
		sp = Vector2(velocity.x, velocity.z).length()
	model.visible = air != 3 and not spect and alive
	chute.visible = alive and air == 2
	if not model.visible:
		return
	model.rotation.y = yaw
	chute.rotation.y = yaw
	var k := minf(1.0, 12.0 * delta)
	var airborne := (not is_on_floor()) if sim else _remote_air
	var armed := shown_wid != "fist"
	if air == 1:
		model.rotation.x = lerpf(model.rotation.x, -1.2, k)
		model.position.y = 0.6
		_legs(0.2, -0.1, -0.5, -0.7)
		aim.rotation.x = 0.6
		_arms(false, sp, true)
		return
	model.rotation.x = lerpf(model.rotation.x, 0.0, k)
	if air == 2:
		model.position.y = 0.0
		_legs(0.15, -0.05, -0.25, -0.15)
		aim.rotation.x = 0.0
		_arms(false, sp, false, true)
		return
	aim.rotation.x = pitch * 0.85
	if vault_t >= 0.0:
		model.position.y = lerpf(model.position.y, -0.15, k)
		_legs(1.3, 0.4, -1.6, -0.6)
		_arms(armed, 0.0)
		return
	if crouch:
		model.position.y = lerpf(model.position.y, -0.4, k)
		var cw := sin(anim_t) * clampf(sp / 3.0, 0.0, 1.0) * 0.25
		anim_t += delta * sp * 2.0
		_legs(1.15 + cw, 1.05 - cw, -1.65, -1.55)
		_arms(armed, sp)
		return
	if airborne:
		model.position.y = lerpf(model.position.y, 0.0, k)
		_legs(0.7, 0.25, -1.1, -0.5)
		_arms(armed, 0.0, false, false, true)
		return
	model.position.y = lerpf(model.position.y, 0.0, k)
	anim_t += delta * sp * 1.5
	var amt := clampf(sp / 6.0, 0.0, 1.0)
	var sw := sin(anim_t) * amt * 0.7
	_legs(sw, -sw, -maxf(0.0, sin(anim_t - 1.4)) * amt * 1.15, -maxf(0.0, sin(anim_t + PI - 1.4)) * amt * 1.15)
	model.position.y = absf(sin(anim_t)) * amt * 0.045 - amt * 0.02
	_arms(armed, sp)


func _legs(l: float, r: float, kl: float, kr: float) -> void:
	leg_l.rotation.x = l
	leg_r.rotation.x = r
	knee_l.rotation.x = kl
	knee_r.rotation.x = kr


# braços por cinemática inversa simples (ombro -> cotovelo -> mão)
func _arms(armed: bool, sp: float, spread := false, chute_up := false, jumping := false) -> void:
	var sh := [Vector3(-0.22, 1.44, 0.0), Vector3(0.22, 1.44, 0.0)]
	var targets := []
	if armed:
		var gp := gun.position if gun else Vector3(0.12, -0.02, -0.36)
		var t: String = Weapons.get_w(shown_wid)["type"]
		var grip := aim.transform * (gp + Vector3(0, -0.05, 0.02))
		var fore := aim.transform * (gp + Vector3(-0.02, -0.03, -0.26 if t != "pistol" else -0.02))
		targets = [fore, grip]
	else:
		var swing := sin(anim_t) * clampf(sp / 6.0, 0.0, 1.0) * 0.25
		targets = [Vector3(-0.26, 0.92, -swing), Vector3(0.26, 0.92, swing)]
		if spread:
			targets = [Vector3(-0.85, 1.5, 0.1), Vector3(0.85, 1.5, 0.1)]
		elif chute_up:
			targets = [Vector3(-0.35, 1.95, -0.05), Vector3(0.35, 1.95, -0.05)]
		elif jumping:
			targets = [Vector3(-0.35, 1.25, -0.2), Vector3(0.35, 1.25, -0.2)]
		if punch_t > 0.0:
			var pk := sin(clampf(punch_t / 0.3, 0.0, 1.0) * PI)
			targets[1] = aim.transform * Vector3(0.12, 0.0, -0.25 - pk * 0.45)
			targets[0] = Vector3(-0.18, 1.3, -0.25)
	for side in 2:
		_ik(arm_parts[side], sh[side], targets[side], -1.0 if side == 0 else 1.0)


func _ik(parts: Array, s: Vector3, t: Vector3, side: float) -> void:
	var a := 0.29
	var b := 0.27
	var d := t - s
	var L := clampf(d.length(), 0.05, a + b - 0.005)
	var dir := d.normalized()
	# o cotovelo dobra pra fora e pra baixo
	var hint := Vector3(side * 0.6, -1.0, 0.25).normalized()
	var pole := (hint - dir * hint.dot(dir)).normalized()
	var x := (a * a - b * b + L * L) / (2.0 * L)
	var hgt := sqrt(maxf(a * a - x * x, 0.0))
	var e := s + dir * x + pole * hgt
	var hand := s + dir * L
	_place(parts[0], s, e)
	_place(parts[1], e, hand)
	var hp: MeshInstance3D = parts[2]
	hp.transform = Transform3D(Basis(Quaternion(Vector3.DOWN, (hand - e).normalized())), hand)


func _place(mi: MeshInstance3D, p0: Vector3, p1: Vector3) -> void:
	var d := p1 - p0
	var l := d.length()
	if l < 0.001:
		return
	var bs := Basis(Quaternion(Vector3.DOWN, d / l))
	mi.transform = Transform3D(bs * Basis.from_scale(Vector3(1, l, 1)), p0)


# ---------------- bot (só roda no servidor) ----------------

func _bot(delta: float) -> void:
	if air == 3:
		wish = Vector3.ZERO
		if game.plane_frac() >= b_jump_at:
			game.server_bot_jump(self)
		return
	if air == 1 or air == 2:
		var d := b_dest - position
		wish = Vector3(d.x, 0, d.z).normalized() if Vector2(d.x, d.z).length() > 4.0 else Vector3.ZERO
		return
	b_think -= delta
	if b_think <= 0.0:
		b_think = 0.3
		_bot_pick_target()
		if b_target == 0:
			_bot_plan()
	var mv := Vector2.ZERO
	var t: Player = game.players.get(b_target)
	if t != null and is_instance_valid(t) and t.alive and t.air == 0:
		heal_t = 0.0
		if sel < 0 or cur_wid() == "fist":
			_bot_best_gun()
		var from := position + Vector3(0, head_y(), 0)
		var aimp := t.position + Vector3(0, t.head_y() - 0.3, 0)
		var d := aimp - from
		var wy := atan2(-d.x, -d.z)
		var wp := atan2(d.y, Vector2(d.x, d.z).length())
		yaw = lerp_angle(yaw, wy, minf(1.0, 5.0 * b_skill * delta))
		pitch = lerpf(pitch, wp, minf(1.0, 5.0 * delta))
		b_strafe_t -= delta
		if b_strafe_t <= 0.0:
			b_strafe = [-1.0, 0.0, 1.0].pick_random()
			b_strafe_t = randf_range(0.7, 1.8)
			set_crouch(randf() < 0.25)
		var dist := d.length()
		var w := cur_stat()
		var ideal := 8.0 if w["type"] == "shotgun" else (2.0 if w["type"] == "fist" else 22.0)
		var fwd := 0.0
		if dist > ideal + 6.0:
			fwd = -1.0
		elif dist < ideal - 6.0:
			fwd = 0.6
		mv = Vector2(b_strafe, fwd)
		b_react -= delta
		if b_react <= 0.0 and absf(angle_difference(yaw, wy)) < 0.15 and dist < float(w["range"]):
			_bot_fire(from, aimp, w)
	else:
		b_react = randf_range(0.6, 1.2)
		set_crouch(false)
		if heal_t > 0.0:
			wish = Vector3.ZERO
			return
		if hp < 70.0 and count("bandage") > 0 and hp > 40.0:
			heal_kind = "bandage"
			heal_t = Weapons.ITEMS["bandage"]["time"]
			return
		if hp < 60.0 and count("med") > 0:
			heal_kind = "med"
			heal_t = Weapons.ITEMS["med"]["time"]
			return
		var dest := b_dest
		if b_item >= 0:
			dest = _bot_item_step(delta)
		var d2 := dest - position
		if Vector2(d2.x, d2.z).length() > 1.0:
			yaw = lerp_angle(yaw, atan2(-d2.x, -d2.z), minf(1.0, 4.0 * delta))
			mv = Vector2(0, -1)
		pitch = lerpf(pitch, 0.0, minf(1.0, 3.0 * delta))
	if mv.length() > 1.0:
		mv = mv.normalized()
	wish = Basis(Vector3.UP, yaw) * Vector3(mv.x, 0, mv.y)
	b_stuck_t += delta
	if b_stuck_t > 0.8:
		if mv != Vector2.ZERO and position.distance_to(b_last) < 0.6:
			want_jump = true
			b_strafe = -b_strafe
			b_dest_t = 0.0
			if b_item >= 0 and b_item_t > 6.0:
				b_ignore[b_item] = true
				b_item = -1
		b_last = position
		b_stuck_t = 0.0


func _bot_best_gun() -> void:
	for i in [0, 1, 2]:
		if guns[i]["id"] != "":
			sel = i
			update_gun()
			return


func _bot_item_step(delta: float) -> Vector3:
	b_item_t += delta
	if b_item_t > 18.0 or b_item >= game.items_avail.size() or not game.items_avail[b_item]:
		b_ignore[b_item] = true
		b_item = -1
		return b_dest
	var it: Dictionary = game.world.items[b_item]
	var ip: Vector3 = it["pos"]
	if it["door_out"] != null:
		var wps: Array = [it["door_out"], it["door_in"], ip]
		if b_way < 2:
			var wp: Vector3 = wps[b_way]
			if Vector2(wp.x - position.x, wp.z - position.z).length() < 1.3:
				b_way += 1
			return wps[b_way]
	if Vector2(ip.x - position.x, ip.z - position.z).length() < 1.4:
		game.server_pickup(pid, b_item, -1)
		b_ignore[b_item] = true
		b_item = -1
	return ip


func wants(kind: String) -> bool:
	if Weapons.is_gun(kind):
		var w := Weapons.get_w(kind)
		if int(w["slot"]) == 1:
			return guns[2]["id"] == "glock" and kind == "deagle"
		if guns[0]["id"] == "" or guns[1]["id"] == "":
			return not has_gun(kind)
		return false
	if Weapons.is_att(kind):
		for i in 3:
			var g: Dictionary = guns[i]
			if Weapons.fits(kind, g["id"]) and not (kind in g["att"]):
				return true
		return false
	match kind:
		"bandage":
			return count("bandage") < 10 and free_slots() > 0
		"med":
			return count("med") < 3 and free_slots() > 0
		"vest":
			return armor < 50.0
		"helmet":
			return not helmet
		"bag":
			return not bag
		"box":
			return true
	return false


func _bot_plan() -> void:
	var zc: Vector2 = game.zone_goal_c()
	var zr: float = game.zone_goal_r()
	var me := Vector2(position.x, position.z)
	var outside := me.distance_to(zc) > zr * 0.85
	b_dest_t -= 0.3
	if outside:
		b_item = -1
		if b_dest_t <= 0.0 or Vector2(b_dest.x, b_dest.z).distance_to(zc) > zr * 0.8:
			b_dest = game.world.random_point_in(zc, zr * 0.6, game.rng)
			b_dest_t = 20.0
		return
	if b_item < 0:
		var best := -1
		var bd := 55.0
		for i in game.items_avail.size():
			if not game.items_avail[i] or b_ignore.has(i):
				continue
			var it: Dictionary = game.world.items[i]
			if it.get("up", false):
				continue
			var ip: Vector3 = it["pos"]
			var dd := me.distance_to(Vector2(ip.x, ip.z))
			if dd < bd and wants(it["kind"]):
				bd = dd
				best = i
		if best >= 0:
			b_item = best
			b_item_t = 0.0
			b_way = 0
			var it: Dictionary = game.world.items[best]
			if it["door_out"] != null:
				var din: Vector3 = it["door_in"]
				var dout: Vector3 = it["door_out"]
				if position.distance_to(din) < position.distance_to(dout):
					b_way = 2
			return
	if b_dest_t <= 0.0 or Vector2(b_dest.x - position.x, b_dest.z - position.z).length() < 3.0:
		b_dest = game.world.random_point_in(zc, zr * 0.7, game.rng)
		b_dest_t = 25.0


func _bot_pick_target() -> void:
	var best := 0
	var bd := 75.0
	if float(cur_stat()["range"]) > 150.0:
		bd = 120.0
	var space := get_world_3d().direct_space_state
	var from := position + Vector3(0, head_y(), 0)
	b_far = true
	for id in game.players:
		var o: Player = game.players[id]
		if o == self or not o.alive or o.air != 0:
			continue
		var dd := o.position.distance_to(position)
		if dd < 160.0:
			b_far = false
		if dd >= bd:
			continue
		# agachado em moita fica mais difícil de ver de longe
		if o.crouch and dd > 35.0:
			continue
		var q := PhysicsRayQueryParameters3D.create(from, o.position + Vector3(0, o.head_y() - 0.1, 0), 1)
		if space.intersect_ray(q).is_empty():
			best = id
			bd = dd
	if best != b_target:
		b_react = randf_range(0.35, 0.8) / b_skill
	b_target = best


func _bot_fire(from: Vector3, aimp: Vector3, w: Dictionary) -> void:
	if cool > 0.0 or reload_t > 0.0:
		return
	var wid := cur_wid()
	if wid == "fist":
		cool = 1.0 / float(w["rate"])
		punch_t = 0.3
		game.server_bot_shot(pid, from, [(aimp - from).normalized()], wid)
		return
	if mag[wid] <= 0:
		reload_t = w["reload"]
		return
	mag[wid] -= 1
	cool = 1.0 / float(w["rate"]) * 1.4
	var base := (aimp - from).normalized()
	var right := base.cross(Vector3.UP).normalized()
	var up := right.cross(base)
	var s := tan(deg_to_rad(float(w["spread"]) + 4.0 / b_skill))
	var dirs := []
	for i in int(w["pellets"]):
		var a := randf() * TAU
		var r := sqrt(randf()) * s
		dirs.append((base + right * cos(a) * r + up * sin(a) * r).normalized())
	game.server_bot_shot(pid, from, dirs, wid)
	if mag[wid] <= 0:
		reload_t = w["reload"]
