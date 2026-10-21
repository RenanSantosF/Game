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
const HEAL_TIME := 3.0
const HEAL_AMOUNT := 45.0
const MAX_KITS := 6

const SHIRTS := [Color(0.3, 0.33, 0.22), Color(0.5, 0.45, 0.33), Color(0.17, 0.2, 0.27), Color(0.36, 0.36, 0.38),
	Color(0.13, 0.13, 0.14), Color(0.38, 0.16, 0.14), Color(0.35, 0.27, 0.19), Color(0.26, 0.33, 0.43), Color(0.55, 0.54, 0.5)]
const PANTS := [Color(0.2, 0.25, 0.34), Color(0.28, 0.3, 0.21), Color(0.12, 0.12, 0.13), Color(0.45, 0.4, 0.3), Color(0.3, 0.3, 0.31)]
const SKINS := [Color(0.87, 0.69, 0.55), Color(0.76, 0.57, 0.42), Color(0.6, 0.43, 0.3), Color(0.44, 0.3, 0.2), Color(0.92, 0.76, 0.64)]
const HAIRS := [Color(0.1, 0.08, 0.06), Color(0.22, 0.15, 0.09), Color(0.35, 0.26, 0.16), Color(0.05, 0.05, 0.05)]
const OLIVE := Color(0.27, 0.3, 0.2)

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
var yaw := 0.0
var pitch := 0.0
var primary := ""
var secondary := "glock"
var slot := 1            # 0 = arma principal, 1 = pistola
var mag := {}
var reload_t := 0.0
var cool := 0.0
var scoped := false
var crouch := false
var want_jump := false
var move_in := Vector2.ZERO
var shown_wid := "glock"
var air := 0             # 0 = no chão, 1 = queda livre, 2 = paraquedas, 3 = no avião
var armor := 0.0
var helmet := false
var kits := 0
var heal_t := 0.0

# jogadores remotos (interpolação)
var target_pos := Vector3.ZERO
var target_yaw := 0.0
var target_pitch := 0.0
var est_speed := 0.0
var _last_pos := Vector3.ZERO

# visual
var model: Node3D
var upper: Node3D
var hand: Node3D
var gun: Node3D
var gun_id := ""
var leg_l: Node3D
var leg_r: Node3D
var knee_l: Node3D
var knee_r: Node3D
var vest_mi: MeshInstance3D
var helmet_mi: MeshInstance3D
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
	b_skill = randf_range(0.8, 1.2)
	refill()
	if visual:
		_build_model()
	update_gun()


func refill() -> void:
	for k in Weapons.DATA:
		mag[k] = Weapons.DATA[k]["mag"]


func cur_wid() -> String:
	if slot == 0 and primary != "":
		return primary
	return secondary


func head_y() -> float:
	return 1.03 if crouch else 1.48


func flags() -> int:
	return air | (int(crouch) << 2) | (int(heal_t > 0.0) << 3)


func set_flags(f: int) -> void:
	air = f & 3
	set_crouch(((f >> 2) & 1) == 1)
	heal_t = 1.0 if ((f >> 3) & 1) == 1 else 0.0


func set_crouch(c: bool) -> void:
	if c == crouch:
		return
	crouch = c
	cap.height = 1.25 if c else 1.8
	cshape.position.y = cap.height / 2.0


# ---------------- modelo ----------------

# membro afunilado apontando pra baixo (coxa, canela), com junta redonda em cima
static func _limb(rb: float, rt: float, h: float, col: Color, foot := false) -> Mesh:
	var key := "%s_%.3f_%.3f_%.3f_%s" % [col.to_html(), rb, rt, h, foot]
	if _shared.has(key):
		return _shared[key]
	var m := MB.new()
	m.cyl(Transform3D(Basis(Vector3.RIGHT, PI), Vector3.ZERO), rb, rt, h, 8, col, true, true)
	m.blob(Transform3D(Basis.from_scale(Vector3(rb, rb, rb)), Vector3.ZERO), 8, 4, col)
	if foot:
		var boot := Color(0.13, 0.11, 0.09)
		m.box(Transform3D(Basis(), Vector3(0, -h - 0.03, -0.04)), Vector3(0.12, 0.1, 0.27), boot)
		m.cyl(Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0, -h + 0.1, 0)), rt + 0.012, rt + 0.012, 0.1, 8, boot, false)
	var mesh := m.commit()
	_shared[key] = mesh
	return mesh


static func _gear(kind: String) -> Mesh:
	if _shared.has(kind):
		return _shared[kind]
	var m := MB.new()
	match kind:
		"vest":
			m.box(Transform3D(Basis(), Vector3(0, 1.27, -0.005)), Vector3(0.49, 0.4, 0.29), OLIVE)
			m.box(Transform3D(Basis(), Vector3(0, 1.17, -0.15)), Vector3(0.36, 0.12, 0.04), OLIVE.darkened(0.2))
		"helmet":
			m.blob(Transform3D(Basis.from_scale(Vector3(0.145, 0.12, 0.16)), Vector3(0, 1.72, 0.0)), 9, 4, OLIVE)
			m.box(Transform3D(Basis(), Vector3(0, 1.665, -0.01)), Vector3(0.3, 0.025, 0.32), OLIVE.darkened(0.15))
		"chute":
			var cc := Color(0.33, 0.36, 0.24)
			m.blob(Transform3D(Basis.from_scale(Vector3(2.6, 0.7, 1.8)), Vector3(0, 6.0, 0)), 12, 3, cc, null, 0.0, true, 0.4)
			var line := Color(0.15, 0.15, 0.13)
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					var top := Vector3(sx * 2.2, 5.8, sz * 1.3)
					var bot := Vector3(sx * 0.2, 1.5, sz * 0.1)
					var dir := (top - bot)
					var b := Basis(Quaternion(Vector3.UP, dir.normalized()))
					m.box(Transform3D(b, (top + bot) / 2.0), Vector3(0.02, dir.length(), 0.02), line)
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
	model = Node3D.new()
	add_child(model)
	# corpo (uma malha só)
	var m := MB.new()
	m.box(Transform3D(Basis(), Vector3(0, 0.97, 0)), Vector3(0.34, 0.18, 0.22), pants)
	m.box(Transform3D(Basis(), Vector3(0, 1.12, 0)), Vector3(0.38, 0.16, 0.22), shirt.darkened(0.05))
	m.box(Transform3D(Basis(), Vector3(0, 1.31, 0)), Vector3(0.46, 0.26, 0.25), shirt)
	m.box(Transform3D(Basis(), Vector3(0, 1.43, 0)), Vector3(0.4, 0.06, 0.22), shirt)
	m.box(Transform3D(Basis(), Vector3(0, 1.065, 0)), Vector3(0.35, 0.04, 0.225), Color(0.12, 0.1, 0.08))
	m.blob(Transform3D(Basis.from_scale(Vector3(0.05, 0.06, 0.05)), Vector3(0, 1.5, 0)), 6, 3, skin)
	m.blob(Transform3D(Basis.from_scale(Vector3(0.105, 0.13, 0.12)), Vector3(0, 1.64, 0)), 9, 5, skin)
	m.blob(Transform3D(Basis.from_scale(Vector3(0.11, 0.085, 0.125)), Vector3(0, 1.69, 0.015)), 9, 4, hair)
	m.box(Transform3D(Basis(), Vector3(0, 1.28, 0.17)), Vector3(0.28, 0.32, 0.11), Color(0.3, 0.27, 0.2))
	U.mesh(model, m.commit())
	vest_mi = U.mesh(model, _gear("vest"))
	helmet_mi = U.mesh(model, _gear("helmet"))
	# pernas com joelho
	leg_l = _leg(model, -0.1, pants)
	leg_r = _leg(model, 0.1, pants)
	knee_l = leg_l.get_child(1)
	knee_r = leg_r.get_child(1)
	# braços segurando a arma (giram com a mira)
	upper = Node3D.new()
	upper.position = Vector3(0, 1.4, 0)
	model.add_child(upper)
	var am := MB.new()
	_arm(am, Vector3(0.24, 0.0, 0.0), Vector3(0.1, -0.07, -0.4), shirt, skin)
	_arm(am, Vector3(-0.24, 0.0, 0.0), Vector3(0.0, -0.04, -0.62), shirt, skin)
	U.mesh(upper, am.commit())
	hand = Node3D.new()
	hand.position = Vector3(0.1, -0.05, -0.42)
	upper.add_child(hand)
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
	refresh_gear()


func _leg(parent: Node3D, x: float, pants: Color) -> Node3D:
	var hip := Node3D.new()
	hip.position = Vector3(x, 0.92, 0)
	parent.add_child(hip)
	var th := MeshInstance3D.new()
	th.mesh = _limb(0.098, 0.075, 0.46, pants)
	th.material_override = U.vmat()
	hip.add_child(th)
	var knee := Node3D.new()
	knee.position = Vector3(0, -0.46, 0)
	hip.add_child(knee)
	var sh := MeshInstance3D.new()
	sh.mesh = _limb(0.072, 0.055, 0.42, pants.darkened(0.05), true)
	sh.material_override = U.vmat()
	knee.add_child(sh)
	return hip


func _arm(m: MB, a: Vector3, b: Vector3, sleeve: Color, skin: Color) -> void:
	var d := b - a
	var elbow := a + d * 0.5 + Vector3(0, -0.07, 0.02)
	for seg in [[a, elbow, sleeve, 0.065, 0.052], [elbow, b, skin.darkened(0.05), 0.045, 0.038]]:
		var p0: Vector3 = seg[0]
		var p1: Vector3 = seg[1]
		var dd := p1 - p0
		m.cyl(Transform3D(Basis(Quaternion(Vector3.UP, dd.normalized())), p0), seg[3], seg[4], dd.length(), 7, seg[2], false)
		m.blob(Transform3D(Basis.from_scale(Vector3.ONE * float(seg[3])), p0), 7, 3, seg[2])
	m.blob(Transform3D(Basis.from_scale(Vector3(0.045, 0.05, 0.06)), b), 6, 3, skin)


func refresh_gear() -> void:
	if not visual or model == null:
		return
	vest_mi.visible = armor > 0.0
	helmet_mi.visible = helmet


func update_gun() -> void:
	shown_wid = cur_wid()
	_set_gun_model(shown_wid)


func _set_gun_model(w: String) -> void:
	if not visual or hand == null or w == gun_id:
		return
	if gun:
		gun.queue_free()
	gun = Weapons.build_model(w)
	hand.add_child(gun)
	gun_id = w


func muzzle_pos() -> Vector3:
	if gun and gun.has_node("Muzzle"):
		return gun.get_node("Muzzle").global_position
	return global_position + Vector3(0, 1.5, 0)


func net_target(pos: Vector3, yw: float, pt: float, wid: String, fl: int) -> void:
	target_pos = pos
	target_yaw = yw
	target_pitch = pt
	set_flags(fl)
	if pos.distance_to(position) > 10.0:
		position = pos
	shown_wid = wid
	_set_gun_model(wid)


func die() -> void:
	alive = false
	hp = 0.0
	collision_layer = 0
	scoped = false
	reload_t = 0.0
	heal_t = 0.0
	set_crouch(false)
	velocity = Vector3.ZERO


# Volta ao estado inicial (nova partida)
func reset_state(pos: Vector3) -> void:
	alive = true
	spect = false
	hp = 100.0
	collision_layer = 2
	collision_mask = 1
	primary = ""
	secondary = "glock"
	slot = 1
	scoped = false
	reload_t = 0.0
	heal_t = 0.0
	armor = 0.0
	helmet = false
	kits = 0
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
	if reload_t > 0.0:
		reload_t -= delta
		if reload_t <= 0.0:
			reload_t = 0.0
			var w := cur_wid()
			mag[w] = Weapons.get_w(w)["mag"]
	var sim := is_local or (is_bot and multiplayer.is_server())
	if sim and heal_t > 0.0:
		heal_t -= delta
		if heal_t <= 0.0:
			heal_t = 0.0
			game.heal_done(self)
	if sim:
		if alive:
			if is_bot:
				_bot(delta)
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
		_animate(delta)


func _move(delta: float) -> void:
	if air == 3:
		velocity = Vector3.ZERO
		position = game.plane_pos()
		return
	var dir := Basis(Vector3.UP, yaw) * Vector3(move_in.x, 0, move_in.y)
	if air == 1 or air == 2:
		var hs := FALL_MOVE if air == 1 else CHUTE_MOVE
		var k := minf(1.0, 2.5 * delta)
		velocity.x = lerpf(velocity.x, dir.x * hs, k)
		velocity.z = lerpf(velocity.z, dir.z * hs, k)
		velocity.y = -FALL_SPEED if air == 1 else -CHUTE_SPEED
		move_and_slide()
		if is_on_floor():
			air = 0
			velocity = Vector3.ZERO
			if is_local:
				game.on_landed()
		elif air == 1 and position.y - game.world.height(position.x, position.z) < CHUTE_OPEN_H:
			air = 2
		_keep_in()
		return
	var spd := SPEED
	if crouch:
		spd = 2.8
	if scoped:
		spd = minf(spd, 3.2)
	if heal_t > 0.0:
		spd = 2.0
	if is_bot:
		spd = minf(spd, 5.3)
	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif want_jump:
		if crouch:
			set_crouch(false)
		else:
			velocity.y = JUMP
	want_jump = false
	move_and_slide()
	_keep_in()


func _keep_in() -> void:
	if position.y < -60.0:
		position = game.world.random_spawn(game.rng)
		velocity = Vector3.ZERO
		air = 0


func _animate(delta: float) -> void:
	var sp := est_speed
	if is_local or (is_bot and multiplayer.is_server()):
		sp = Vector2(velocity.x, velocity.z).length()
	model.visible = air != 3 and not spect
	chute.visible = alive and air == 2
	model.rotation.y = yaw
	chute.rotation.y = yaw
	if not alive:
		model.rotation.x = lerpf(model.rotation.x, 1.45, minf(1.0, 8.0 * delta))
		model.position.y = 0.15
		return
	var k := minf(1.0, 12.0 * delta)
	if air == 1:
		model.rotation.x = lerpf(model.rotation.x, -1.2, k)
		model.position.y = 0.6
		leg_l.rotation.x = 0.2
		leg_r.rotation.x = -0.1
		knee_l.rotation.x = -0.5
		knee_r.rotation.x = -0.7
		upper.rotation.x = 0.6
		return
	model.rotation.x = lerpf(model.rotation.x, 0.0, k)
	if air == 2:
		model.position.y = 0.0
		leg_l.rotation.x = 0.15
		leg_r.rotation.x = -0.05
		knee_l.rotation.x = -0.25
		knee_r.rotation.x = -0.15
		upper.rotation.x = 0.0
		return
	upper.rotation.x = pitch * 0.8
	if crouch:
		model.position.y = lerpf(model.position.y, -0.4, k)
		var cw := sin(anim_t) * clampf(sp / 3.0, 0.0, 1.0) * 0.25
		anim_t += delta * sp * 2.0
		leg_l.rotation.x = 1.15 + cw
		leg_r.rotation.x = 1.05 - cw
		knee_l.rotation.x = -1.65
		knee_r.rotation.x = -1.55
		return
	model.position.y = lerpf(model.position.y, 0.0, k)
	anim_t += delta * sp * 1.55
	var amt := clampf(sp / 6.0, 0.0, 1.0)
	var sw := sin(anim_t) * amt * 0.65
	leg_l.rotation.x = sw
	leg_r.rotation.x = -sw
	knee_l.rotation.x = -maxf(0.0, sin(anim_t - 1.4)) * amt * 1.1
	knee_r.rotation.x = -maxf(0.0, sin(anim_t + PI - 1.4)) * amt * 1.1
	model.position.y = absf(sin(anim_t)) * amt * 0.04


# ---------------- bot (só roda no servidor) ----------------

func _bot(delta: float) -> void:
	if air == 3:
		move_in = Vector2.ZERO
		if game.plane_frac() >= b_jump_at:
			game.server_bot_jump(self)
		return
	if air == 1 or air == 2:
		var d := b_dest - position
		yaw = lerp_angle(yaw, atan2(-d.x, -d.z), minf(1.0, 3.0 * delta))
		move_in = Vector2(0, -1) if Vector2(d.x, d.z).length() > 4.0 else Vector2.ZERO
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
		var from := position + Vector3(0, head_y(), 0)
		var aim := t.position + Vector3(0, t.head_y() - 0.3, 0)
		var d := aim - from
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
		var w := Weapons.get_w(cur_wid())
		var ideal := 8.0 if w["type"] == "shotgun" else 22.0
		var fwd := 0.0
		if dist > ideal + 6.0:
			fwd = -1.0
		elif dist < ideal - 6.0:
			fwd = 0.6
		mv = Vector2(b_strafe, fwd)
		b_react -= delta
		if b_react <= 0.0 and absf(angle_difference(yaw, wy)) < 0.15 and dist < float(w["range"]):
			_bot_fire(from, aim, w)
	else:
		b_react = randf_range(0.6, 1.2)
		set_crouch(false)
		if heal_t > 0.0:
			move_in = Vector2.ZERO
			return
		if hp < 60.0 and kits > 0:
			heal_t = HEAL_TIME
			return
		var dest := b_dest
		if b_item >= 0:
			dest = _bot_item_step()
		var d2 := dest - position
		if Vector2(d2.x, d2.z).length() > 1.0:
			yaw = lerp_angle(yaw, atan2(-d2.x, -d2.z), minf(1.0, 4.0 * delta))
			mv = Vector2(0, -1)
		pitch = lerpf(pitch, 0.0, minf(1.0, 3.0 * delta))
	if mv.length() > 1.0:
		mv = mv.normalized()
	move_in = mv
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


func _bot_item_step() -> Vector3:
	b_item_t += get_physics_process_delta_time()
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
		game.server_pickup(pid, b_item)
		b_ignore[b_item] = true
		b_item = -1
	return ip


func _wants(kind: String) -> bool:
	if Weapons.is_gun(kind):
		var w := Weapons.get_w(kind)
		if int(w["slot"]) == 1:
			return secondary == "glock"
		return primary == "" or (primary == "mp5" and kind != "mp5")
	match kind:
		"med":
			return kits < 3
		"vest":
			return armor < 50.0
		"helmet":
			return not helmet
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
			var ip: Vector3 = game.world.items[i]["pos"]
			var dd := me.distance_to(Vector2(ip.x, ip.z))
			if dd < bd and _wants(game.world.items[i]["kind"]):
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
	if Weapons.get_w(cur_wid())["range"] > 150.0:
		bd = 120.0
	var space := get_world_3d().direct_space_state
	var from := position + Vector3(0, head_y(), 0)
	for id in game.players:
		var o: Player = game.players[id]
		if o == self or not o.alive or o.air != 0:
			continue
		var dd := o.position.distance_to(position)
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


func _bot_fire(from: Vector3, aim: Vector3, w: Dictionary) -> void:
	if cool > 0.0 or reload_t > 0.0:
		return
	var wid := cur_wid()
	if mag[wid] <= 0:
		reload_t = w["reload"]
		return
	mag[wid] -= 1
	cool = 1.0 / float(w["rate"]) * 1.4
	var base := (aim - from).normalized()
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
