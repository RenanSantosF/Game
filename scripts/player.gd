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
const BOOTS := [Color(0.1, 0.08, 0.06), Color(0.22, 0.16, 0.1), Color(0.14, 0.14, 0.14), Color(0.35, 0.27, 0.18)]
const HAIRS := [Color(0.1, 0.08, 0.06), Color(0.24, 0.16, 0.1), Color(0.4, 0.3, 0.18), Color(0.05, 0.05, 0.05), Color(0.55, 0.45, 0.3)]
const OLIVE := Color(0.38, 0.42, 0.28)

static var _shared := {}

var game: Node
var pid := 0
var nick := ""
var is_local := false
var is_bot := false
var visual := true

var hp := 200.0
var alive := true
var spect := false       # entrou com a partida em andamento: só assiste
var yaw := 0.0           # para onde o corpo olha
var pitch := 0.0         # mira pra cima/baixo
var guns := [{"id": "", "att": []}, {"id": "", "att": []}, {"id": "", "att": []}]
var sel := -1            # 0/1 = principais, 2 = pistola, -1 = mãos livres
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
var helmet := 0          # nível do capacete (0 = sem)
var vest_lv := 0          # nível do colete
var bag := 0             # nível da mochila (0 = sem mochila)
var sprint := false
var stun_t := 0.0        # atordoado depois de cair de alto
var _fall_v := 0.0
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
var sol: Soldier
var dying_t := 0.0
var aim: Node3D
var gun: Node3D
var gun_key := ""
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
var _vault_drop := false
var bloom := 0.0
var car := -1             # carro que está dirigindo (-1 = a pé)
var _remote_car := false
var regen := 0.0
var _breath := 0.0
var _crouch_k := 0.0
var _wall_chk := 0.0
var _wall_near := false
var _gun_low := 0.0
var b_exit: Array = []       # caminho pra sair de casa (porta de dentro, porta de fora)
var b_stuck_n := 0
var b_escape_t := 0.0
var b_escape := Vector3.ZERO


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
	return Weapons.BAGS[clampi(bag, 0, 3)]


func free_slots() -> int:
	return capacity() - Weapons.slots_used(inv)


func count(kind: String) -> int:
	return int(inv.get(kind, 0))


func flags() -> int:
	return air | (int(crouch) << 2) | (int(heal_t > 0.0) << 3) | (int(vault_t >= 0.0) << 4) | (int(punch_t > 0.0) << 5) | (int(not is_on_floor() and air == 0) << 6) | (int(car >= 0) << 7)


func set_flags(f: int) -> void:
	air = f & 3
	set_crouch(((f >> 2) & 1) == 1)
	heal_t = 1.0 if ((f >> 3) & 1) == 1 else 0.0
	vault_t = 0.2 if ((f >> 4) & 1) == 1 else -1.0
	if ((f >> 5) & 1) == 1 and punch_t <= 0.0:
		punch_t = 0.3
	_remote_air = ((f >> 6) & 1) == 1
	_remote_car = ((f >> 7) & 1) == 1


var _remote_air := false


func set_crouch(c: bool) -> void:
	if c == crouch:
		return
	crouch = c
	cap.height = 1.25 if c else 1.8
	cshape.position.y = cap.height / 2.0


# ---------------- modelo ----------------



static func _gear(kind: String) -> Mesh:
	if _shared.has(kind):
		return _shared[kind]
	var m := MB.new()
	match kind:
		"vest1", "vest2", "vest3":
			var lv := int(kind.substr(4))
			var vc: Color = [OLIVE, Color(0.62, 0.55, 0.4), Color(0.13, 0.13, 0.14)][lv - 1]
			m.tex(U.FABRIC, 3.0)
			m.box(Transform3D(Basis(), Vector3(0, 1.27, 0.0)), Vector3(0.35, 0.33, 0.23), vc)
			m.box(Transform3D(Basis(), Vector3(0, 1.17, -0.12)), Vector3(0.3, 0.1, 0.03), vc.darkened(0.2))
			for sx in [-0.1, 0.1]:
				m.box(Transform3D(Basis(), Vector3(sx, 1.45, 0.0)), Vector3(0.06, 0.05, 0.21), vc.darkened(0.1))
			if lv >= 2:
				m.box(Transform3D(Basis(), Vector3(0, 1.29, -0.125)), Vector3(0.27, 0.2, 0.025), vc.darkened(0.3))
			if lv == 3:
				for k in 3:
					m.box(Transform3D(Basis(), Vector3(-0.09 + k * 0.09, 1.16, -0.14)), Vector3(0.07, 0.08, 0.035), vc.lightened(0.12))
		"helmet1", "helmet2", "helmet3":
			var lv := int(kind.substr(6))
			var hc: Color = [Color(0.48, 0.45, 0.33), OLIVE, Color(0.12, 0.12, 0.13)][lv - 1]
			m.tex(U.PLAIN, 3.0)
			m.blob(Transform3D(Basis.from_scale(Vector3(0.13, 0.11 if lv > 1 else 0.08, 0.145)), Vector3(0, 1.665, 0.01)), 10, 5, hc)
			if lv >= 2:
				m.box(Transform3D(Basis(), Vector3(0, 1.625, 0.0)), Vector3(0.27, 0.02, 0.3), hc.darkened(0.15))
			if lv == 3:
				m.box(Transform3D(Basis(Vector3.RIGHT, 0.2), Vector3(0, 1.62, -0.14)), Vector3(0.2, 0.06, 0.015), Color(0.2, 0.35, 0.45))
		"bag":
			m.tex(U.FABRIC, 3.0)
			m.box(Transform3D(Basis(), Vector3(0, 1.25, 0.21)), Vector3(0.34, 0.44, 0.17), Color(0.45, 0.4, 0.3))
			m.box(Transform3D(Basis(), Vector3(0, 1.12, 0.3)), Vector3(0.28, 0.16, 0.06), Color(0.4, 0.35, 0.26))
		"chute":
			# velame retangular (asa) arqueado, com espessura, e cordas presas na borda de baixo
			var ca := Color(0.52, 0.56, 0.38)
			var cb := Color(0.82, 0.8, 0.7)
			var n := 10
			var tops := []
			var bots := []
			for i in n + 1:
				var ang := lerpf(-0.85, 0.85, float(i) / n)
				var x := sin(ang) * 3.0
				var y := 4.7 + cos(ang) * 1.5
				tops.append(Vector3(x, y, 0))
				bots.append(Vector3(x * 0.97, y - 0.32, 0))
			m.tex(U.FABRIC, 0.6)
			var zf := -1.15
			var zb := 1.0
			for i in n:
				var c: Color = ca if i % 2 == 0 else cb
				var t0: Vector3 = tops[i]
				var t1: Vector3 = tops[i + 1]
				var b0: Vector3 = bots[i]
				var b1: Vector3 = bots[i + 1]
				var up := ((t0 + t1) / 2.0 - Vector3(0, 4.7, 0)).normalized()
				# em cima, embaixo, frente (boca de ar) e trás
				m.quad(t0 + Vector3(0, 0.1, zf), t1 + Vector3(0, 0.1, zf), t1 + Vector3(0, 0, zb), t0 + Vector3(0, 0, zb), c, up)
				m.quad(b0 + Vector3(0, 0, zf * 0.92), b1 + Vector3(0, 0, zf * 0.92), b1 + Vector3(0, 0.12, zb), b0 + Vector3(0, 0.12, zb), c.darkened(0.25), -up)
				m.quad(t0 + Vector3(0, 0.1, zf), t1 + Vector3(0, 0.1, zf), b1 + Vector3(0, 0, zf * 0.92), b0 + Vector3(0, 0, zf * 0.92), c.darkened(0.45), Vector3.FORWARD)
				m.quad(t0 + Vector3(0, 0, zb), t1 + Vector3(0, 0, zb), b1 + Vector3(0, 0.12, zb), b0 + Vector3(0, 0.12, zb), c.darkened(0.1), Vector3.BACK)
			for e in [0, n]:
				var t: Vector3 = tops[e]
				var bt: Vector3 = bots[e]
				var sd := Vector3(signf(t.x), 0, 0)
				m.quad(t + Vector3(0, 0.1, zf), t + Vector3(0, 0, zb), bt + Vector3(0, 0.12, zb), bt + Vector3(0, 0, zf * 0.92), ca.darkened(0.2), sd)
			# cordas: da borda de baixo do velame até os tirantes nos ombros
			var line := Color(0.15, 0.15, 0.14)
			m.tex(U.PLAIN, 1.0)
			for i in [0, 2, 4, 6, 8, 10]:
				var bp: Vector3 = bots[i]
				var riser := Vector3(signf(bp.x) * 0.2 if absf(bp.x) > 0.2 else 0.0, 1.62, 0)
				for z in [zf * 0.85, zb * 0.85]:
					var top := bp + Vector3(0, 0.03, z)
					var dir := top - riser
					var bb := Basis(Quaternion(Vector3.UP, dir.normalized()))
					m.box(Transform3D(bb, (top + riser) / 2.0), Vector3(0.018, dir.length(), 0.018), line)
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
	# boneco animado (modelo do Meshy); cada jogador com as suas cores
	sol = Soldier.new()
	model.add_child(sol)
	sol.setup(skin, shirt, pants, BOOTS[rng.randi() % BOOTS.size()], hair)
	vest_mi = MeshInstance3D.new()
	vest_mi.mesh = _gear("vest1")
	vest_mi.material_override = U.wmat()
	sol.attach("Spine2", vest_mi)
	bag_mi = MeshInstance3D.new()
	bag_mi.mesh = _gear("bag")
	bag_mi.material_override = U.wmat()
	sol.attach("Spine2", bag_mi)
	helmet_mi = MeshInstance3D.new()
	helmet_mi.mesh = _gear("helmet1")
	helmet_mi.material_override = U.wmat()
	sol.attach("Head", helmet_mi)
	if cap_hat:
		var hat := MeshInstance3D.new()
		var hm := MB.new()
		var hc: Color = SHIRTS[rng.randi() % SHIRTS.size()]
		hm.tex(U.FABRIC, 4.0)
		hm.blob(Transform3D(Basis.from_scale(Vector3(0.1, 0.065, 0.112)), Vector3(0, 1.66, 0.0)), 9, 4, hc)
		hm.box(Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3(0, 1.655, -0.12)), Vector3(0.16, 0.012, 0.09), hc.darkened(0.1))
		hat.mesh = hm.commit()
		hat.material_override = U.wmat()
		sol.attach("Head", hat)
	# mira (gira com o pitch); a arma fica aqui e os braços alcançam a arma
	aim = Node3D.new()
	aim.position = Vector3(0, 1.36, 0)
	model.add_child(aim)
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
	for g in [vest_mi, bag_mi, helmet_mi]:
		g.visibility_range_end = 120.0
	refresh_gear()



func refresh_gear() -> void:
	if not visual or model == null:
		return
	vest_mi.visible = armor > 0.0 and vest_lv > 0
	if vest_mi.visible:
		vest_mi.mesh = _gear("vest%d" % vest_lv)
	helmet_mi.visible = helmet > 0
	if helmet_mi.visible:
		helmet_mi.mesh = _gear("helmet%d" % helmet)
	bag_mi.visible = bag > 0


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
	if sol and model and model.visible and air == 0:
		dying_t = 2.2
		sol.play("Dead", 0.08)
		_set_gun_model("fist", [])
	elif model:
		model.visible = false


# Volta ao estado inicial (nova partida)
func reset_state(pos: Vector3) -> void:
	alive = true
	spect = false
	hp = 200.0
	collision_layer = 2
	collision_mask = 1
	guns = [{"id": "", "att": []}, {"id": "", "att": []}, {"id": "", "att": []}]
	sel = -1
	scoped = false
	reload_t = 0.0
	heal_t = 0.0
	vault_t = -1.0
	armor = 0.0
	helmet = 0
	vest_lv = 0
	regen = 0.0
	car = -1
	bag = 0
	stun_t = 0.0
	sprint = false
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
	dying_t = 0.0
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
			var full: int = cur_stat()["mag"]
			var am := Weapons.ammo_of(w)
			var take := mini(full - int(mag.get(w, 0)), count(am))
			if game.phase == game.LOBBY:
				mag[w] = full
				take = 0
			if take > 0:
				mag[w] = int(mag.get(w, 0)) + take
				if is_local or (is_bot and multiplayer.is_server()):
					game.ammo_used(self, am, take)
			if is_local:
				game.sfx("reload_in")
	var sim := is_local or (is_bot and multiplayer.is_server())
	stun_t = maxf(stun_t - delta, 0.0)
	if sim and heal_t > 0.0:
		heal_t -= delta
		if heal_t <= 0.0:
			heal_t = 0.0
			game.heal_done(self, heal_kind)
	if sim:
		if alive:
			if is_bot and not (b_far and Engine.get_physics_frames() % 3 != pid % 3):
				_bot(delta * (3.0 if b_far else 1.0))
			if car >= 0:
				velocity = Vector3.ZERO
			elif vault_t >= 0.0:
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
	# analógico: quanto mais empurra, mais rápido (até uma corrida leve); botão de correr = corrida forte
	var spd := lerpf(1.6, 5.0, clampf((dir.length() - 0.15) / 0.75, 0.0, 1.0))
	if sprint:
		spd = 7.0 if (sel < 0 or cur_wid() == "fist") else 6.5
	if crouch:
		spd = 2.8
	if scoped:
		spd = minf(spd, 3.2)
	if heal_t > 0.0:
		spd = 2.0
	if game.world.in_water(position):
		spd = minf(spd, 3.2)
	if is_bot:
		spd = (6.6 if sprint else 5.4) if b_target == 0 else (6.0 if sprint else 4.6)
		if crouch:
			spd = 2.6
	if stun_t > 0.0:
		spd = 0.0
	var on_floor := is_on_floor()
	# no ar não dá pra mudar a direção
	if on_floor:
		velocity.x = dir.x * spd
		velocity.z = dir.z * spd
	# corpo vira pra onde anda, ou pra mira quando está atirando (no ar não gira)
	if not is_bot and on_floor:
		if aim_t > 0.0 or scoped:
			yaw = lerp_angle(yaw, game.cam_yaw_v, minf(1.0, 28.0 * delta))
		elif dir.length() > 0.15:
			yaw = lerp_angle(yaw, atan2(-dir.x, -dir.z), minf(1.0, 10.0 * delta))
	if not on_floor:
		velocity.y -= GRAVITY * delta
		_air_time += delta
		_fall_v = maxf(_fall_v, -velocity.y)
	elif want_jump and stun_t <= 0.0:
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
		# queda alta: dano e um tempinho sem conseguir andar (pular da janela de cima = ~1 s)
		# só trava em queda de altura considerável (mais de ~4 m); descer ladeira pulando não trava
		if _fall_v > 13.5:
			stun_t = clampf(0.5 + (_fall_v - 13.5) * 0.12, 0.5, 1.4)
		if _vault_drop and _fall_v > 10.5:
			stun_t = maxf(stun_t, 1.0)
		if _fall_v > 16.0:
			game.fall_damage(self, (_fall_v - 16.0) * 10.0)
		_vault_drop = false
	if is_on_floor():
		_air_time = 0.0
		_fall_v = 0.0
	_was_floor = is_on_floor()
	_keep_in()


func _keep_in() -> void:
	var lobby: bool = game.phase == game.LOBBY
	if position.y < -60.0 or (lobby and position.y < World.LOBBY_P.y - 8.0):
		position = game.world.random_spawn(game.rng) if lobby else game.world.map_spawn(game.rng)
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
		var dq := PhysicsRayQueryParameters3D.create(p + Vector3(0, top + 0.5, 0), p + Vector3(0, -12.0, 0), 1, ex)
		var dr := space.intersect_ray(dq)
		if dr.is_empty():
			continue
		var land: Vector3 = dr["position"]
		if land.y > base.y + top - 0.25:
			continue
		var cq := PhysicsRayQueryParameters3D.create(land + Vector3(0, 0.3, 0), land + Vector3(0, 1.7, 0), 1, ex)
		if not space.intersect_ray(cq).is_empty():
			continue
		# se do outro lado é alto (janela de cima), passa e cai
		_vault_drop = land.y < base.y - 1.2
		if _vault_drop:
			land = Vector3(p.x, base.y + top + 0.05, p.z)
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
	if dying_t > 0.0:
		dying_t -= delta
		model.visible = dying_t > 0.0
		model.rotation.x = 0.0
		model.position.y = 0.0
		sol.tick(delta, false, 0.0, 0.0, [])
		chute.visible = false
		return
	model.visible = air != 3 and not spect and alive and car < 0 and not (_remote_car and not is_local)
	chute.visible = alive and air == 2
	if not model.visible:
		return
	model.rotation.y = yaw
	chute.rotation.y = yaw
	var k := minf(1.0, 12.0 * delta)
	var airborne := (not is_on_floor()) if sim else _remote_air
	var armed := shown_wid != "fist"
	var far: bool = not game.near_cam(global_position, 35.0)
	var cr := 0.0
	var hands := []
	aim.rotation.x = 0.0
	if air == 1:
		model.rotation.x = lerpf(model.rotation.x, -1.2, k)
		model.position.y = 0.6
		sol.play("Air")
		hands = [model.global_transform * Vector3(-0.8, 1.45, 0.15), model.global_transform * Vector3(0.8, 1.45, 0.15)]
		sol.tick(delta, far, 0.0, 0.0, hands)
		return
	model.rotation.x = lerpf(model.rotation.x, 0.0, k)
	if air == 2:
		model.position.y = 0.0
		sol.play("Air", 0.3, 0.2)
		hands = [model.global_transform * Vector3(-0.3, 1.95, -0.05), model.global_transform * Vector3(0.3, 1.95, -0.05)]
		sol.tick(delta, far, 0.0, 0.0, hands)
		return
	# arma encostada na parede: abaixa o cano (não atravessa a parede)
	_wall_chk -= delta
	if _wall_chk <= 0.0 and armed and gun and not far:
		_wall_chk = 0.15
		var from := global_position + Vector3(0, 1.4, 0)
		var fw := Basis(Vector3.UP, yaw) * Vector3.FORWARD
		var q := PhysicsRayQueryParameters3D.create(from, from + fw * 1.05, 1)
		_wall_near = not get_world_3d().direct_space_state.intersect_ray(q).is_empty()
	_gun_low = lerpf(_gun_low, 1.0 if (_wall_near and armed) else 0.0, minf(1.0, 10.0 * delta))
	aim.rotation.x = pitch * 0.85 * (1.0 - _gun_low) - 1.1 * _gun_low
	_crouch_k = lerpf(_crouch_k, 1.0 if crouch else 0.0, k)
	if vault_t >= 0.0 or airborne:
		sol.play("Air", 0.12)
	elif sp < 0.35:
		sol.play("Idle", 0.25)
	elif sp < 5.0 or crouch:
		sol.play("Walking", 0.2, clampf(sp / (1.25 if not crouch else 0.9), 0.5, 3.0))
	else:
		sol.play("Running", 0.2, clampf(sp / 5.2, 0.8, 1.6))
	if armed:
		var gp := gun.position if gun else Vector3(0.12, -0.02, -0.36)
		var t: String = Weapons.get_w(shown_wid)["type"]
		var grip := aim.global_transform * (gp + Vector3(0, -0.05, 0.03))
		var fore := aim.global_transform * (gp + Vector3(-0.02, -0.03, -0.26 if t != "pistol" else -0.02))
		hands = [fore, grip]
	elif heal_t > 0.0:
		hands = [model.global_transform * Vector3(-0.06, 1.12, -0.3), model.global_transform * Vector3(0.06, 1.12, -0.3)]
	elif sol.cur == "Idle" and vault_t < 0.0:
		# parado de mãos livres: braços soltos do lado do corpo, respirando
		_breath += delta
		var br := sin(_breath * 1.8) * 0.008
		hands = [model.global_transform * Vector3(-0.27, 0.86 + br, 0.02), model.global_transform * Vector3(0.27, 0.86 + br, 0.02)]
	if punch_t > 0.0 and not armed:
		var pk := sin(clampf(punch_t / 0.3, 0.0, 1.0) * PI)
		hands = [model.global_transform * Vector3(-0.2, 1.3, -0.25), aim.global_transform * Vector3(0.12, 0.0, -0.2 - pk * 0.4)]
	sol.tick(delta, far, pitch * (1.0 - _gun_low) if armed else 0.0, _crouch_k, hands)





# ---------------- bot (só roda no servidor) ----------------

func _bot(delta: float) -> void:
	if air == 3:
		wish = Vector3.ZERO
		if game.plane_frac() >= game.plane_j0() + b_jump_at * (game.plane_j1() - game.plane_j0()):
			game.server_bot_jump(self)
		return
	if air == 1 or air == 2:
		var d := b_dest - position
		wish = Vector3(d.x, 0, d.z).normalized() if Vector2(d.x, d.z).length() > 4.0 else Vector3.ZERO
		return
	if game.phase == game.LOBBY:
		_bot_lobby(delta)
		return
	b_think -= delta
	if b_think <= 0.0:
		b_think = 0.25
		_bot_pick_target()
		if b_target == 0:
			_bot_plan()
			# dentro de casa/cercado com o destino lá fora: sai pela porta/portão (sem ficar raspando na parede)
			if b_exit.is_empty() and b_item < 0:
				var h := _bot_house()
				if not h.is_empty() and Vector2(b_dest.x, b_dest.z).distance_to(h["pos"]) > float(h["r"]) + 1.0:
					b_exit = [h["din"], h["dout"]]
				else:
					b_exit = _bot_gate()
	var mv := Vector2.ZERO
	var t: Player = game.players.get(b_target)
	var zc: Vector2 = game.zone_now()[0]
	var zr: float = game.zone_now()[1]
	var me := Vector2(position.x, position.z)
	var out_zone := me.distance_to(zc) > zr - 6.0
	# bem fora da zona: larga a briga (a não ser que o inimigo esteja colado) e corre pra dentro
	if t != null and me.distance_to(zc) > zr + 10.0 and t.position.distance_to(position) > 12.0:
		t = null
		b_target = 0
		b_think = 0.0
	if t != null and is_instance_valid(t) and t.alive and t.air == 0:
		heal_t = 0.0
		b_exit.clear()
		if sel < 0 or cur_wid() == "fist" or not _has_ammo(cur_wid()):
			_bot_best_gun()
		var from := position + Vector3(0, head_y(), 0)
		# mira no peito, às vezes na cabeça
		var aimp := t.position + Vector3(0, t.head_y() - (0.05 if randf() < 0.25 * b_skill else 0.45), 0)
		var d := aimp - from
		var wy := atan2(-d.x, -d.z)
		var wp := atan2(d.y, Vector2(d.x, d.z).length())
		yaw = lerp_angle(yaw, wy, minf(1.0, 7.0 * b_skill * delta))
		pitch = lerpf(pitch, wp, minf(1.0, 7.0 * delta))
		b_strafe_t -= delta
		if b_strafe_t <= 0.0:
			b_strafe = [-1.0, -1.0, 0.0, 1.0, 1.0].pick_random()
			b_strafe_t = randf_range(0.5, 1.4)
			set_crouch(randf() < 0.2 and hp > 80.0)
			# pula de vez em quando pra atrapalhar a mira
			if randf() < 0.15 * b_skill:
				want_jump = true
		var dist := d.length()
		var w := cur_stat()
		var ideal := 8.0 if w["type"] == "shotgun" else (2.0 if w["type"] == "fist" else (60.0 if w["type"] == "sniper" else 20.0))
		var fwd := 0.0
		if dist > ideal + 6.0:
			fwd = -1.0
		elif dist < ideal - 6.0:
			fwd = 0.6
		# vida baixa: recua pra quebrar a linha de visão e se curar
		if hp < 70.0 and (count("med") > 0 or count("bandage") > 0) and w["type"] != "fist":
			fwd = 1.0
		mv = Vector2(b_strafe, fwd)
		# fora da zona: briga andando pra dentro dela
		if out_zone:
			var to := (zc - me).normalized()
			mv = _world_to_local(Vector3(to.x, 0, to.y))
		b_react -= delta
		if b_react <= 0.0 and absf(angle_difference(yaw, wy)) < 0.12 and dist < float(w["range"]):
			_bot_fire(from, aimp, w)
	else:
		b_react = randf_range(0.45, 0.9)
		set_crouch(false)
		if heal_t > 0.0:
			if not out_zone:
				wish = Vector3.ZERO
				return
		elif _bot_try_heal(out_zone):
			if not out_zone:
				wish = Vector3.ZERO
				return
		if (sel < 0 or not _has_ammo(cur_wid())) and has_any_gun():
			_bot_best_gun()
		var dest := b_dest
		if b_item >= 0:
			dest = _bot_item_step(delta)
		if not b_exit.is_empty():
			dest = b_exit[0]
			if Vector2(dest.x - position.x, dest.z - position.z).length() < 1.0:
				b_exit.pop_front()
		var d2 := dest - position
		if Vector2(d2.x, d2.z).length() > 1.0:
			yaw = lerp_angle(yaw, atan2(-d2.x, -d2.z), minf(1.0, 5.0 * delta))
			mv = Vector2(0, -1)
		pitch = lerpf(pitch, 0.0, minf(1.0, 3.0 * delta))
	sprint = mv != Vector2.ZERO and (b_target == 0 or out_zone)
	if mv.length() > 1.0:
		mv = mv.normalized()
	wish = Basis(Vector3.UP, yaw) * Vector3(mv.x, 0, mv.y)
	# preso: tenta pular e depois anda numa direção aleatória por um tempo
	if b_escape_t > 0.0:
		b_escape_t -= delta
		wish = b_escape
		yaw = lerp_angle(yaw, atan2(-b_escape.x, -b_escape.z), minf(1.0, 6.0 * delta))
	b_stuck_t += delta
	if b_stuck_t > 0.8:
		if wish != Vector3.ZERO and position.distance_to(b_last) < 0.6:
			b_stuck_n += 1
			want_jump = true
			b_strafe = -b_strafe
			if b_stuck_n >= 2:
				var h := _bot_house()
				var gate := _bot_gate()
				if not h.is_empty() and b_exit.is_empty() and b_stuck_n < 4:
					b_exit = [h["din"], h["dout"]]
				elif not gate.is_empty() and b_exit.is_empty() and b_stuck_n < 5:
					b_exit = gate
				else:
					b_exit.clear()
					b_escape = _bot_free_dir()
					b_escape_t = randf_range(1.0, 1.8)
			if b_stuck_n >= 6:
				# preso no andar de cima (ou sem saída): desce pela porta da frente
				var hh := _bot_house(true)
				if not hh.is_empty() and position.y - float(hh["din"].y) > 2.0:
					position = hh["dout"]
					target_pos = position
					velocity = Vector3.ZERO
				b_dest_t = 0.0
				b_stuck_n = 0
			if b_item >= 0 and b_item_t > 6.0:
				b_ignore[b_item] = true
				b_item = -1
		else:
			b_stuck_n = 0
		b_last = position
		b_stuck_t = 0.0


# direção mais livre (raio no peito e no joelho), puxando pro destino
func _bot_free_dir() -> Vector3:
	var space := get_world_3d().direct_space_state
	var to := Vector3(b_dest.x - position.x, 0, b_dest.z - position.z).normalized()
	var best := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	var bs := -1.0
	for k in 12:
		var d := Vector3.FORWARD.rotated(Vector3.UP, k * TAU / 12.0 + randf_range(-0.2, 0.2))
		var free := 6.0
		for hy in [0.45, 1.3]:
			var from := position + Vector3(0, hy, 0)
			var q := PhysicsRayQueryParameters3D.create(from, from + d * 6.0, 1)
			var r := space.intersect_ray(q)
			if not r.is_empty():
				free = minf(free, from.distance_to(r["position"]))
		var sc := free + d.dot(to) * 1.5 + randf() * 0.5
		if sc > bs:
			bs = sc
			best = d
	return best


func _world_to_local(v: Vector3) -> Vector2:
	var l := Basis(Vector3.UP, yaw).inverse() * v
	return Vector2(l.x, l.z)


# casa onde o bot está (com porta conhecida), ou vazio
func _bot_house(any_floor := false) -> Dictionary:
	var me := Vector2(position.x, position.z)
	for h in game.world.houses:
		if not h.has("din"):
			continue
		var l: Vector2 = (me - h["pos"]).rotated(-float(h["yaw"]))
		if absf(l.x) < float(h["w"]) / 2.0 + 0.3 and absf(l.y) < float(h["d"]) / 2.0 + 0.3 and (any_floor or position.y - float(h["din"].y) < 2.0):
			return h
	return {}


# preso num cercado com o destino do lado de fora: vai pelo portão mais perto
func _bot_gate() -> Array:
	var me := Vector2(position.x, position.z)
	var dst := Vector2(b_dest.x, b_dest.z)
	for cp in game.world.compounds:
		var c: Vector2 = cp["c"]
		if me.distance_to(c) < float(cp["r"]) and dst.distance_to(c) > float(cp["r"]) * 0.9:
			var best: Array = []
			var bd := 1e9
			for g in cp["gates"]:
				var d := position.distance_to(g[0])
				if d < bd:
					bd = d
					best = [g[0], g[1]]
			return best
	return []


func _bot_try_heal(moving: bool) -> bool:
	if heal_t > 0.0:
		return true
	if hp < 120.0 and count("med") > 0:
		heal_kind = "med"
	elif hp < 170.0 and count("bandage") > 0:
		heal_kind = "bandage"
	else:
		return false
	heal_t = Weapons.ITEMS[heal_kind]["time"]
	return true


func _has_ammo(wid: String) -> bool:
	if wid == "" or wid == "fist":
		return wid == "fist"
	return int(mag.get(wid, 0)) > 0 or count(Weapons.ammo_of(wid)) > 0


func has_any_gun() -> bool:
	for g in guns:
		if g["id"] != "" and _has_ammo(g["id"]):
			return true
	return false


# no lobby: anda à toa pela área de aquecimento
func _bot_lobby(delta: float) -> void:
	b_dest_t -= delta
	if b_dest_t <= 0.0 or Vector2(b_dest.x - position.x, b_dest.z - position.z).length() < 1.5:
		b_dest = game.world.lobby_point(game.rng)
		b_dest_t = randf_range(4.0, 10.0)
	var d := b_dest - position
	if Vector2(d.x, d.z).length() > 1.5:
		yaw = lerp_angle(yaw, atan2(-d.x, -d.z), minf(1.0, 4.0 * delta))
		wish = Basis(Vector3.UP, yaw) * Vector3.FORWARD
	else:
		wish = Vector3.ZERO
	sprint = randf() < 0.01 or sprint


func _bot_best_gun() -> void:
	for i in [0, 1, 2]:
		if guns[i]["id"] != "" and _has_ammo(guns[i]["id"]):
			if sel != i:
				sel = i
				update_gun()
			return
	if sel != -1:
		sel = -1
		update_gun()


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
			return guns[2]["id"] == "" or (guns[2]["id"] == "glock" and kind == "deagle")
		if guns[0]["id"] == "" or guns[1]["id"] == "":
			return not has_gun(kind)
		return false
	if Weapons.is_att(kind):
		for i in 3:
			var g: Dictionary = guns[i]
			if Weapons.fits(kind, g["id"]) and not (kind in g["att"]):
				return true
		return false
	if Weapons.is_ammo(kind):
		for g in guns:
			if g["id"] != "" and Weapons.ammo_of(g["id"]) == kind:
				return count(kind) < 90 and free_slots() > 0
		return false
	if Weapons.is_bag(kind):
		return int(kind.substr(3)) > bag
	match kind:
		"bandage":
			return count("bandage") < 10 and free_slots() > 0
		"med":
			return count("med") < 4 and free_slots() > 0
		"vest1", "vest2", "vest3":
			return Weapons.level_of(kind) > vest_lv or armor < 40.0
		"helmet1", "helmet2", "helmet3":
			return Weapons.level_of(kind) > helmet
		"box":
			return true
	return false


func _bot_plan() -> void:
	var zc: Vector2 = game.zone_goal_c()
	var zr: float = game.zone_goal_r()
	var me := Vector2(position.x, position.z)
	var outside := me.distance_to(zc) > zr * 0.85
	# ainda tem tempo até a zona fechar? então dá pra lootear antes de correr pra ela
	if outside and game.z_stage >= 0:
		var left: float = float(game.z_wait) + float(game.z_shrink) - float(game.z_t)
		var need := (me.distance_to(zc) - zr * 0.8) / 4.5
		if left > need + 70.0 and not has_any_gun():
			outside = false
	b_dest_t -= 0.3
	if outside:
		b_item = -1
		if b_dest_t <= 0.0 or Vector2(b_dest.x, b_dest.z).distance_to(zc) > zr * 0.8:
			b_dest = game.world.random_point_in(zc, zr * 0.6, game.rng)
			b_dest_t = 20.0
		return
	if b_item < 0:
		var best := -1
		var bd := 60.0 if has_any_gun() else 180.0
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
	var zn: Array = game.zone_now()
	var far_out: bool = Vector2(position.x, position.z).distance_to(zn[0]) > float(zn[1]) + 10.0
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
		if dd >= bd or (far_out and dd > 12.0):
			continue
		# sem arma não compra briga de longe: vai atrás de arma primeiro
		if not has_any_gun() and dd > 7.0:
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
	if int(mag.get(wid, 0)) <= 0:
		if count(Weapons.ammo_of(wid)) > 0:
			reload_t = w["reload"]
		else:
			_bot_best_gun()
		return
	mag[wid] -= 1
	cool = 1.0 / float(w["rate"]) * 1.2
	var base := (aimp - from).normalized()
	var right := base.cross(Vector3.UP).normalized()
	var up := right.cross(base)
	var s := tan(deg_to_rad(float(w["spread"]) * 0.8 + 2.2 / b_skill))
	var dirs := []
	for i in int(w["pellets"]):
		var a := randf() * TAU
		var r := sqrt(randf()) * s
		dirs.append((base + right * cos(a) * r + up * sin(a) * r).normalized())
	game.server_bot_shot(pid, from, dirs, wid)
	if mag[wid] <= 0 and count(Weapons.ammo_of(wid)) > 0:
		reload_t = w["reload"]
