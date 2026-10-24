class_name Vehicle
extends CharacterBody3D

# Carro dirigível. kind 0 = esportivo (mais rápido), kind 1 = picape (mais lenta, mais firme).
# Quem dirige simula o carro e manda a posição pro servidor, que repassa pros outros.
# As rodas procuram o chão (raio pra baixo): o carro sobe e desce morro acompanhando o terreno.
# Tiro machuca o carro; sem vida ele explode e machuca quem estiver perto.

const MAX := [15.5, 12.5]        # velocidade máxima (m/s)
const ACCEL := [4.2, 3.8]        # arranca devagar (o torque pra subir morro continua)
const TURN := [1.7, 1.35]        # giro (rad/s) em velocidade boa
const LEN := [5.0, 4.6]
const HP := 520.0
const WHEEL_R := 0.36
# modelos do Car Kit da Kenney (CC0): escala do modelo e rodas (x, raio, z da frente, z de trás)
# 0 = esportivo (rápido), 1 = jeep aberto (mais lento e alto). Sem vidro: dá pra ver e acertar quem dirige.
# rodas de cada modelo (gerado por tools/prepare_cars2.gd): [x, raio, z da frente, z de trás, largura]
static func wh_of(k: int) -> Array:
	return CarInfo.INFO[k]["wh"]
static var _shader: Shader

var game: Node
var idx := 0
var kind := 0
var driver := 0
var speed := 0.0
var yaw := 0.0
var hp := HP
var dead := false
var mesh: Node3D
var wheels: Array = []         # [nó da roda, é da frente]
var engine: AudioStreamPlayer3D
var target_pos := Vector3.ZERO
var target_yaw := 0.0
var steer_v := 0.0
var _tilt := Basis()
var _spin := 0.0
var smoke: CPUParticles3D
var _vy := 0.0
static var _mesh_cache := {}


func setup(g: Node, i: int, k: int, pos: Vector3, yw: float, tint: Color, visual: bool) -> void:
	game = g
	idx = i
	kind = k
	yaw = yw
	position = pos
	target_pos = pos
	target_yaw = yw
	collision_layer = 1
	collision_mask = 1
	floor_max_angle = deg_to_rad(55.0)
	safe_margin = 0.05
	# só a parte de baixo bloqueia tiro: quem está dirigindo dá pra acertar pelo vidro
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(float(CarInfo.INFO[k]["wid"]) * 0.92, 0.8, LEN[k] * 0.95)
	cs.shape = bs
	cs.position = Vector3(0, 0.72, 0)
	add_child(cs)
	if visual:
		mesh = Node3D.new()
		add_child(mesh)
		var mat := car_material(paint_for(k, tint), 0.3)
		mesh.add_child(body_node(k, mat))
		var wm: Mesh = wheel_of(k)
		var wh: Array = wh_of(k)
		for z in [wh[2], wh[3]]:
			for sx in [-1.0, 1.0]:
				var piv := Node3D.new()
				piv.position = Vector3(sx * wh[0], wh[1], z)
				mesh.add_child(piv)
				var w := MeshInstance3D.new()
				w.mesh = wm
				w.material_override = mat if k != 0 else U.wmat()
				w.rotation.y = 0.0 if sx > 0 else PI
				w.scale = Vector3(wh[4], wh[1], wh[1])
				w.visibility_range_end = 200.0
				piv.add_child(w)
				wheels.append([piv, z == wh[2]])
		# fumaça do motor: aparece e engrossa conforme o carro perde vida (preta perto de explodir)
		smoke = CPUParticles3D.new()
		smoke.amount = 40
		smoke.lifetime = 2.2
		smoke.emitting = false
		smoke.local_coords = false
		smoke.position = Vector3(0, 1.1, float(wh[2]) - 0.3)
		smoke.direction = Vector3(0, 1, 0)
		smoke.spread = 18.0
		smoke.gravity = Vector3(0, 1.2, 0)
		smoke.initial_velocity_min = 0.6
		smoke.initial_velocity_max = 1.4
		smoke.scale_amount_min = 0.6
		smoke.scale_amount_max = 1.4
		var sc := Curve.new()
		sc.add_point(Vector2(0, 0.4))
		sc.add_point(Vector2(1, 2.6))
		smoke.scale_amount_curve = sc
		var sm := SphereMesh.new()
		sm.radius = 0.35
		sm.height = 0.7
		sm.radial_segments = 6
		sm.rings = 3
		var smat := StandardMaterial3D.new()
		smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smat.vertex_color_use_as_albedo = true
		sm.material = smat
		smoke.mesh = sm
		var grad := Gradient.new()
		grad.set_color(0, Color(0.55, 0.55, 0.55, 0.55))
		grad.set_color(1, Color(0.4, 0.4, 0.4, 0.0))
		smoke.color_ramp = grad
		add_child(smoke)
		crash_snd = AudioStreamPlayer3D.new()
		crash_snd.stream = load("res://sounds/crash.wav")
		crash_snd.unit_size = 10.0
		crash_snd.max_distance = 110.0
		add_child(crash_snd)
		engine = AudioStreamPlayer3D.new()
		# cada carro com seu motor: esportivo mais agudo, jeep diesel grave
		engine.stream = load("res://sounds/engine.wav" if k == 0 else "res://sounds/engine_jeep.wav")
		engine.unit_size = 8.0
		engine.max_distance = 90.0
		add_child(engine)
	rotation.y = yaw


# jeep é militar: cáqui, verde-oliva ou areia; esportivo usa a cor sorteada
static func paint_for(k: int, tint: Color) -> Color:
	if k == 1:
		var opts := [Color(0.56, 0.54, 0.4), Color(0.42, 0.46, 0.3), Color(0.66, 0.58, 0.42)]
		return opts[absi(hash(tint.to_html())) % opts.size()]
	return tint


static func car_material(paint: Color, dirt: float, rust := 0.0, burn := 0.0) -> ShaderMaterial:
	if _shader == null:
		_shader = load("res://shaders/car.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("paint", paint)
	m.set_shader_parameter("dirt", dirt)
	m.set_shader_parameter("rust", rust)
	m.set_shader_parameter("burn", burn)
	return m


# carroceria (sem rodas), já virada pra -Z e no tamanho do jogo
static func body_node(k: int, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = load("res://models/car%d.res" % k)
	mi.material_override = mat
	mi.visibility_range_end = 450.0
	# piso e bancos por dentro: o carro tem fundo e dá pra ver quem está sentado
	var inn := MeshInstance3D.new()
	inn.mesh = interior(k)
	inn.material_override = U.wmat()
	inn.visibility_range_end = 120.0
	mi.add_child(inn)
	return mi


static var _inner := {}


static func interior(k: int) -> Mesh:
	if _inner.has(k):
		return _inner[k]
	var c: Dictionary = CarInfo.INFO[k]
	var wh: Array = c["wh"]
	var L: float = c["len"]
	var W: float = c["wid"]
	var r: float = wh[1]
	var m := MB.new()
	m.tex(U.METAL, 1.0)
	# assoalho cobrindo o vão entre as rodas (de baixo não se vê o chão através do carro)
	m.box(Transform3D(Basis(), Vector3(0, r * 0.75, (float(wh[2]) + float(wh[3])) / 2.0)), Vector3(W * 0.86, 0.1, L * 0.82), Color(0.12, 0.12, 0.12))
	m.tex(U.FABRIC, 3.0)
	var sy := r * 0.8 + (0.12 if k == 0 else 0.3)
	var sz := 0.25 if k == 0 else 0.05
	for sx in [-0.42, 0.42]:
		m.box(Transform3D(Basis(), Vector3(sx, sy + 0.12, sz)), Vector3(0.5, 0.18, 0.5), Color(0.25, 0.2, 0.17))
		m.box(Transform3D(Basis(Vector3.RIGHT, -0.2), Vector3(sx, sy + 0.45, sz + 0.27)), Vector3(0.5, 0.6, 0.12), Color(0.22, 0.18, 0.15))
	if k == 0:
		m.tex(U.PLAIN, 2.0)
		m.box(Transform3D(Basis(), Vector3(0, sy + 0.45, sz - 0.85)), Vector3(W * 0.82, 0.25, 0.3), Color(0.08, 0.08, 0.08))
		m.box(Transform3D(Basis(), Vector3(0, sy + 0.2, (float(wh[3]) + 0.9))), Vector3(W * 0.8, 0.3, 0.6), Color(0.2, 0.17, 0.15))
	_inner[k] = m.commit()
	return _inner[k]


# carro parado de enfeite (com rodas fixas)
static func prop_node(k: int, mat: Material) -> Node3D:
	var n := Node3D.new()
	n.add_child(body_node(k, mat))
	var wm: Mesh = wheel_of(k)
	var wh: Array = wh_of(k)
	for z in [wh[2], wh[3]]:
		for sx in [-1.0, 1.0]:
			var w := MeshInstance3D.new()
			w.mesh = wm
			w.material_override = mat if k != 0 else U.wmat()
			w.position = Vector3(sx * wh[0], wh[1], z)
			w.rotation.y = 0.0 if sx > 0 else PI
			w.scale = Vector3(wh[4], wh[1], wh[1])
			w.visibility_range_end = 150.0
			n.add_child(w)
	return n


func seat_pos() -> Vector3:
	return global_position + Basis(Vector3.UP, yaw) * (Vector3(-0.42, 0.38, 0.25) if kind == 0 else Vector3(-0.42, 0.62, 0.05))


func wheel_pos() -> Vector3:
	return global_position + Basis(Vector3.UP, yaw) * (Vector3(-0.42, 1.0, -0.3) if kind == 0 else Vector3(-0.42, 1.3, -0.45))


# simulação de quem dirige: throttle -1..1 (ré/freio .. acelera), steer -1..1
func drive(delta: float, throttle: float, steer: float) -> void:
	if dead:
		speed = 0.0
		return
	var mx: float = MAX[kind]
	if throttle > 0.05:
		speed = move_toward(speed, mx * throttle, ACCEL[kind] * delta * (1.0 if speed >= 0.0 else 2.5))
	elif throttle < -0.05:
		speed = move_toward(speed, -mx * 0.3 * -throttle, (12.0 if speed > 0.0 else ACCEL[kind]) * delta)
	else:
		speed = move_toward(speed, 0.0, 3.5 * delta)
	steer_v = lerpf(steer_v, steer, minf(1.0, 6.0 * delta))
	# vira como carro de verdade: em volta do eixo de trás, raio pelo ângulo das rodas da frente
	# (devagar vira pouco, sem parecer que o carro escorrega de lado)
	var wh: Array = wh_of(kind)
	var wb := absf(float(wh[3]) - float(wh[2]))
	var rate := clampf(speed * tan(steer_v * 0.55) / maxf(wb, 1.5), -TURN[kind], TURN[kind])
	var rear := Vector3(0, 0, float(wh[3]))
	var rear_w0 := Basis(Vector3.UP, yaw) * rear
	yaw -= rate * delta
	var rear_w1 := Basis(Vector3.UP, yaw) * rear
	global_position += rear_w0 - rear_w1
	rotation.y = yaw
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	# subindo morro perde um pouco de força, descendo ganha (os dois têm torque pra subir morro)
	var up_k := -_tilt.z.y if mesh else 0.0
	speed -= up_k * (3.0 if kind == 0 else 0.9) * delta * signf(speed)
	velocity = Vector3(fwd.x * speed, 0, fwd.z * speed)
	var before := global_position
	move_and_slide()
	# o chão (terreno) nunca segura o carro de frente: as rodas é que acompanham o morro
	var hit_wall := false
	var hit_other := false
	var only_ground := get_slide_collision_count() > 0
	for ci in get_slide_collision_count():
		var c := get_slide_collision(ci)
		if c.get_collider() == game.world.terrain_body or c.get_collider() == game.world.floor_body:
			continue
		only_ground = false
		var n := c.get_normal()
		# chão de outra coisa (calçada, laje, pedra deitada) não conta como batida
		if n.y > 0.6:
			continue
		hit_other = true
		if absf(n.y) < 0.6 and fwd.dot(-n) * signf(speed) > 0.45 and absf(speed) > 4.0:
			hit_wall = true
	if only_ground:
		global_position = Vector3(before.x + velocity.x * delta, global_position.y, before.z + velocity.z * delta)
	# bateu de frente em algo: perde velocidade (o som sai em _update_visual)
	if hit_wall:
		speed *= 0.5
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	if hit_other and absf(speed) > 3.0 and moved < absf(speed) * delta * 0.15:
		speed *= 0.5
		hit_wall = true
	_hit_now = hit_wall
	_ground(delta)
	target_pos = global_position
	target_yaw = yaw
	_update_visual(delta)


# acha o chão embaixo das quatro rodas e ajusta altura e inclinação
func _ground(delta: float) -> void:
	var space := get_world_3d().direct_space_state
	var b := Basis(Vector3.UP, yaw)
	var wh: Array = wh_of(kind)
	var hz: float = (float(wh[3]) - float(wh[2])) / 2.0
	var zc: float = (float(wh[3]) + float(wh[2])) / 2.0
	var wx: float = wh[0]
	var ys := []
	for o in [Vector3(-wx, 0, zc - hz), Vector3(wx, 0, zc - hz), Vector3(-wx, 0, zc + hz), Vector3(wx, 0, zc + hz)]:
		var p: Vector3 = global_position + b * o
		var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 3.0, 0), p + Vector3(0, -2.5, 0), 1, [get_rid()])
		var r := space.intersect_ray(q)
		ys.append(float(r["position"].y) if not r.is_empty() else -9999.0)
	var hits := 0
	var avg := 0.0
	for y in ys:
		if y > -9000.0:
			hits += 1
			avg += y
	if hits >= 2:
		avg /= hits
		if global_position.y - avg > 0.35:
			# no ar (pulou um barranco): cai
			_vy -= 22.0 * delta
			global_position.y = maxf(global_position.y + _vy * delta, avg)
		else:
			_vy = 0.0
			global_position.y = lerpf(global_position.y, avg, minf(1.0, 18.0 * delta))
		var f := (float(ys[0]) + float(ys[1])) / 2.0 if ys[0] > -9000.0 and ys[1] > -9000.0 else avg
		var bk := (float(ys[2]) + float(ys[3])) / 2.0 if ys[2] > -9000.0 and ys[3] > -9000.0 else avg
		var l := (float(ys[0]) + float(ys[2])) / 2.0 if ys[0] > -9000.0 and ys[2] > -9000.0 else avg
		var rr := (float(ys[1]) + float(ys[3])) / 2.0 if ys[1] > -9000.0 and ys[3] > -9000.0 else avg
		# girar no eixo da frente (-Z) com ângulo positivo levanta o lado esquerdo
		_want_tilt = Basis(Vector3.RIGHT, atan2(f - bk, hz * 2.0)) * Basis(Vector3.FORWARD, atan2(l - rr, wx * 2.0))
		# torção que o plano não cobre: cada roda desce/sobe um pouco (suspensão)
		if hits == 4:
			var tw := (float(ys[0]) - float(ys[1]) - float(ys[2]) + float(ys[3])) / 4.0
			_susp = [tw, -tw, -tw, tw]
	else:
		_vy -= 22.0 * delta
		global_position.y += _vy * delta
	# nunca fica embaixo do terreno (antes dava pra cair no "limbo" numa subida forte)
	if game and game.world:
		var gy: float = game.world.height(global_position.x, global_position.z)
		if global_position.y < gy - 0.3:
			global_position.y = gy + 0.05
			_vy = 0.0


var _want_tilt := Basis()
var settled := false
var _susp := [0.0, 0.0, 0.0, 0.0]
var _susp_v := [0.0, 0.0, 0.0, 0.0]
var _last_speed := 0.0
var _crash_cd := 0.0
var _hit_now := false     # bateu em parede/objeto neste quadro (subir morro não é batida)
var crash_snd: AudioStreamPlayer3D


# assenta o carro parado no chão (depois que a física está pronta)
func settle() -> void:
	settled = true
	_ground(1.0)
	_vy = 0.0
	_tilt = _want_tilt
	if mesh:
		mesh.basis = _tilt


# carro dos outros: vai suave até a posição recebida
func follow(delta: float) -> void:
	global_position = global_position.lerp(target_pos, minf(1.0, 12.0 * delta))
	yaw = lerp_angle(yaw, target_yaw, minf(1.0, 12.0 * delta))
	rotation.y = yaw
	if mesh and Engine.get_process_frames() % 3 == idx % 3:
		_ground_tilt_only()
	_update_visual(delta)


func _ground_tilt_only() -> void:
	var y0 := global_position.y
	_ground(0.0)
	global_position.y = y0


func _update_visual(delta: float) -> void:
	if mesh == null:
		return
	_tilt = _tilt.slerp(_want_tilt, minf(1.0, 10.0 * delta))
	mesh.basis = _tilt
	# rodas giram com a velocidade e as da frente viram com o volante
	_spin -= speed / float(wh_of(kind)[1]) * delta
	for wi in wheels.size():
		var e: Array = wheels[wi]
		var piv: Node3D = e[0]
		piv.rotation = Vector3(_spin, -steer_v * 0.45 if e[1] else 0.0, 0)
		_susp_v[wi] = lerpf(float(_susp_v[wi]), clampf(float(_susp[wi]), -0.18, 0.18), minf(1.0, 12.0 * delta))
		piv.position.y = float(wh_of(kind)[1]) + float(_susp_v[wi])
	# batida: perdeu velocidade de repente (só som, carro não toma dano de batida)
	_crash_cd -= delta
	var drop := absf(_last_speed) - absf(speed)
	if _hit_now and drop > 2.0 and absf(_last_speed) > 3.5 and _crash_cd <= 0.0 and crash_snd:
		_crash_cd = 0.6
		crash_snd.volume_db = (game.sfxn.db(0.0) if game.sfxn else 0.0) + clampf((drop - 2.0) * 0.8, 0.0, 6.0) + 1.0
		crash_snd.pitch_scale = randf_range(0.9, 1.1)
		crash_snd.play()
	_last_speed = speed
	if smoke:
		var dmg := 1.0 - hp / HP
		smoke.emitting = not dead and dmg > 0.3
		if smoke.emitting:
			var k := clampf((dmg - 0.3) / 0.6, 0.0, 1.0)
			smoke.amount_ratio = lerpf(0.25, 1.0, k)
			var g := lerpf(0.6, 0.08, k)
			smoke.color_ramp.set_color(0, Color(g, g, g, lerpf(0.35, 0.8, k)))
			smoke.scale_amount_max = lerpf(1.0, 2.2, k)
	if engine:
		var on := driver != 0 and not dead
		if on and not engine.playing:
			engine.play()
		elif not on and engine.playing:
			engine.stop()
		if on:
			engine.pitch_scale = 0.7 + absf(speed) / MAX[kind] * 1.1
			engine.volume_db = game.sfxn.db(-4.0) if game.sfxn else -4.0


func explode_visual() -> void:
	dead = true
	speed = 0.0
	if mesh:
		for c in mesh.get_children():
			if c is MeshInstance3D:
				c.material_override = U.mat(Color(0.08, 0.07, 0.06))
		mesh.rotation.z = 0.06


# ---------------- modelos ----------------

# malha da roda de cada carro (no tamanho 1: o jogo escala pelo raio e largura). O esportivo usa uma
# roda feita aqui (a do modelo vinha com o eixo torto e girava "dobrada"); o jipe usa a do modelo.
static func wheel_of(k: int) -> Mesh:
	if k == 0:
		return sport_wheel()
	return load("res://models/car%d_wheel.res" % k)


static func sport_wheel() -> Mesh:
	if _mesh_cache.has("sport_wheel"):
		return _mesh_cache["sport_wheel"]
	var m := MB.new()
	var tire := Color(0.08, 0.08, 0.085)
	var wall := Color(0.13, 0.13, 0.14)
	var chrome := Color(0.8, 0.8, 0.82)
	m.tex(U.PLAIN, 1.0)
	var side := Basis(Vector3.FORWARD, PI / 2.0)   # eixo ao longo de X; lado de fora = +X
	# pneu (banda de rodagem) e flancos arredondados
	m.cyl(Transform3D(side, Vector3(-0.42, 0, 0)), 1.0, 1.0, 0.84, 22, tire)
	m.cyl(Transform3D(side, Vector3(0.42, 0, 0)), 0.97, 0.84, 0.08, 22, wall)
	m.cyl(Transform3D(side, Vector3(-0.5, 0, 0)), 0.84, 0.97, 0.08, 22, wall)
	# cravos do pneu
	for k in 22:
		var a := TAU * (k + 0.5) / 22.0
		var b := Basis(Vector3.RIGHT, a)
		m.box(Transform3D(b, b * Vector3(0, 1.005, 0)), Vector3(0.78, 0.04, 0.12), Color(0.06, 0.06, 0.06))
	# aro cromado fundo, 5 raios largos e cubo
	m.cyl(Transform3D(side, Vector3(0.42, 0, 0)), 0.62, 0.62, 0.1, 18, chrome.darkened(0.45))
	m.cyl(Transform3D(side, Vector3(0.5, 0, 0)), 0.64, 0.6, 0.03, 18, chrome)
	for k in 5:
		var a := TAU * k / 5.0
		var b := Basis(Vector3.RIGHT, a)
		m.box(Transform3D(b, b * Vector3(0.5, 0.3, 0)), Vector3(0.05, 0.52, 0.16), chrome.darkened(0.1))
	m.cyl(Transform3D(side, Vector3(0.5, 0, 0)), 0.16, 0.13, 0.07, 10, chrome.lightened(0.1))
	_mesh_cache["sport_wheel"] = m.commit()
	return _mesh_cache["sport_wheel"]


static func wheel_mesh() -> Mesh:
	if _mesh_cache.has("wheel"):
		return _mesh_cache["wheel"]
	var m := MB.new()
	var tire := Color(0.09, 0.09, 0.09)
	var rim := Color(0.72, 0.72, 0.74)
	m.tex(U.PLAIN, 1.0)
	var side := Basis(Vector3.FORWARD, PI / 2.0)   # eixo da roda ao longo de X
	m.cyl(Transform3D(side, Vector3(-0.12, 0, 0)), WHEEL_R, WHEEL_R, 0.24, 14, tire)
	m.cyl(Transform3D(side, Vector3(0.115, 0, 0)), 0.22, 0.2, 0.02, 10, rim)
	# raios do aro (mostram que a roda está girando)
	for k in 5:
		var a := TAU * k / 5.0
		m.box(Transform3D(Basis(Vector3.RIGHT, a), Vector3(0.13, 0, 0)), Vector3(0.02, 0.36, 0.05), rim.darkened(0.2))
	m.cyl(Transform3D(side, Vector3(0.12, 0, 0)), 0.05, 0.05, 0.03, 8, rim.darkened(0.4))
	_mesh_cache["wheel"] = m.commit()
	return _mesh_cache["wheel"]


static func body_mesh(k: int, paint: Color) -> Mesh:
	var key := "%d_%s" % [k, paint.to_html()]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var m := MB.new()
	var dark := Color(0.1, 0.1, 0.11)
	var glass := Color(0.12, 0.16, 0.2)
	var chrome := Color(0.75, 0.76, 0.78)
	var L: float = LEN[k]
	var W := 1.82
	var hl := L / 2.0
	m.tex(U.PLAIN, 0.6)
	if k == 0:
		# esportivo: baixo, capô comprido, teto curto e aerofólio
		m.box(Transform3D(Basis(), Vector3(0, 0.58, 0)), Vector3(W, 0.42, L - 0.3), paint)
		m.box(Transform3D(Basis(), Vector3(0, 0.62, 0)), Vector3(W - 0.12, 0.42, L), paint)
		m.box(Transform3D(Basis(Vector3.RIGHT, -0.06), Vector3(0, 0.84, -hl + 0.85)), Vector3(W - 0.14, 0.06, 1.55), paint.lightened(0.05))
		m.box(Transform3D(Basis(Vector3.RIGHT, 0.08), Vector3(0, 0.86, hl - 0.5)), Vector3(W - 0.14, 0.06, 0.9), paint)
		_cabin(m, W - 0.16, 0.84, 1.28, -0.55, 0.85, -0.12, 0.45, paint, glass)
		# aerofólio
		for sx in [-0.6, 0.6]:
			m.box(Transform3D(Basis(), Vector3(sx, 0.98, hl - 0.18)), Vector3(0.06, 0.2, 0.08), dark)
		m.box(Transform3D(Basis(), Vector3(0, 1.08, hl - 0.18)), Vector3(W - 0.2, 0.04, 0.26), dark)
		# faixas de corrida
		for sx in [-0.18, 0.18]:
			m.box(Transform3D(Basis(Vector3.RIGHT, -0.06), Vector3(sx, 0.875, -hl + 0.85)), Vector3(0.14, 0.01, 1.5), Color(0.95, 0.95, 0.95))
	else:
		# picape: alta, cabine dupla, caçamba com santantônio, quebra-mato
		m.box(Transform3D(Basis(), Vector3(0, 0.78, 0)), Vector3(W, 0.55, L), paint)
		m.box(Transform3D(Basis(Vector3.RIGHT, -0.04), Vector3(0, 1.08, -hl + 0.75)), Vector3(W - 0.08, 0.08, 1.4), paint)
		_cabin(m, W - 0.1, 1.06, 1.68, -1.25, 0.45, -0.95, 0.4, paint, glass)
		m.box(Transform3D(Basis(), Vector3(0, 1.08, hl - 1.0)), Vector3(W - 0.08, 0.05, 1.9), dark)
		for sx in [-1.0, 1.0]:
			m.box(Transform3D(Basis(), Vector3(sx * (W / 2.0 - 0.05), 1.22, hl - 1.0)), Vector3(0.1, 0.3, 1.95), paint)
			m.box(Transform3D(Basis(), Vector3(sx * 0.7, 1.5, 0.55)), Vector3(0.06, 0.5, 0.06), dark)
		m.box(Transform3D(Basis(), Vector3(0, 1.22, hl - 0.05)), Vector3(W, 0.3, 0.1), paint)
		m.box(Transform3D(Basis(), Vector3(0, 1.74, 0.55)), Vector3(1.46, 0.06, 0.06), dark)
		# quebra-mato
		for sx in [-0.55, 0.55]:
			m.box(Transform3D(Basis(), Vector3(sx, 0.75, -hl - 0.18)), Vector3(0.07, 0.6, 0.07), dark)
		m.box(Transform3D(Basis(), Vector3(0, 1.0, -hl - 0.18)), Vector3(1.25, 0.07, 0.07), dark)
		m.box(Transform3D(Basis(), Vector3(0, 0.62, -hl - 0.18)), Vector3(1.25, 0.07, 0.07), dark)
	var by := 0.62 if k == 0 else 0.82
	# para-choques, grade cromada, faróis e lanternas
	m.box(Transform3D(Basis(), Vector3(0, by - 0.16, -hl - 0.04)), Vector3(W + 0.02, 0.2, 0.14), dark)
	m.box(Transform3D(Basis(), Vector3(0, by - 0.16, hl + 0.04)), Vector3(W + 0.02, 0.2, 0.14), dark)
	m.box(Transform3D(Basis(), Vector3(0, by + 0.06, -hl - 0.005)), Vector3(0.75, 0.16, 0.02), dark)
	for i in 4:
		m.box(Transform3D(Basis(), Vector3(0, by + 0.0 + i * 0.04, -hl - 0.012)), Vector3(0.72, 0.012, 0.012), chrome)
	for sx in [-0.62, 0.62]:
		m.box(Transform3D(Basis(), Vector3(sx, by + 0.08, -hl - 0.008)), Vector3(0.34, 0.12, 0.02), Color(1.0, 1.0, 0.92))
		m.box(Transform3D(Basis(), Vector3(sx, by + 0.1, hl + 0.008)), Vector3(0.32, 0.12, 0.02), Color(0.75, 0.05, 0.04))
	# placas
	m.box(Transform3D(Basis(), Vector3(0, by - 0.12, -hl - 0.115)), Vector3(0.42, 0.13, 0.01), Color(0.92, 0.92, 0.9))
	m.box(Transform3D(Basis(), Vector3(0, by - 0.12, hl + 0.115)), Vector3(0.42, 0.13, 0.01), Color(0.92, 0.92, 0.9))
	# portas: frisos e maçanetas
	for sx in [-1.0, 1.0]:
		var x: float = sx * (W / 2.0 + 0.003)
		for z in ([-0.5, 0.75] if k == 0 else [-1.2, -0.1, 0.45]):
			m.box(Transform3D(Basis(), Vector3(x, by + 0.02, z)), Vector3(0.01, 0.4, 0.015), dark)
		m.box(Transform3D(Basis(), Vector3(x + sx * 0.008, by + 0.12, -0.25 if k == 0 else -0.85)), Vector3(0.015, 0.03, 0.12), chrome)
		# frisos de borracha embaixo e caixas de roda
		m.box(Transform3D(Basis(), Vector3(x, by - 0.2, 0)), Vector3(0.02, 0.06, L - 1.9), dark)
		for z in [-hl + 0.85, hl - 0.85]:
			m.box(Transform3D(Basis(), Vector3(sx * (W / 2.0 - 0.05), WHEEL_R + 0.18, z)), Vector3(0.14, 0.12, 0.95), dark)
		# retrovisor
		m.box(Transform3D(Basis(), Vector3(sx * (W / 2.0 + 0.1), by + 0.36, -0.45 if k == 0 else -1.05)), Vector3(0.16, 0.11, 0.07), dark)
	# escapamento
	m.cyl(Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0.55, by - 0.22, hl - 0.1)), 0.04, 0.04, 0.25, 6, chrome)
	_mesh_cache[key] = m.commit()
	return _mesh_cache[key]


# cabine com vidros escuros: base em y0 (de z0 a z1), teto em y1 (de z2 a z3); frente = -Z
static func _cabin(m: MB, W: float, y0: float, y1: float, z0: float, z1: float, z2: float, z3: float, paint: Color, glass: Color) -> void:
	var hw := W / 2.0
	var tw := hw - 0.1
	var bfl := Vector3(-hw, y0, z0)
	var bfr := Vector3(hw, y0, z0)
	var bbl := Vector3(-hw, y0, z1)
	var bbr := Vector3(hw, y0, z1)
	var tfl := Vector3(-tw, y1, z2)
	var tfr := Vector3(tw, y1, z2)
	var tbl := Vector3(-tw, y1, z3)
	var tbr := Vector3(tw, y1, z3)
	m.quad(bfl, bfr, tfr, tfl, glass, Vector3(0, 0.5, -1).normalized())
	m.quad(bbl, bbr, tbr, tbl, glass, Vector3(0, 0.5, 1).normalized())
	m.quad(bfl, bbl, tbl, tfl, glass, Vector3.LEFT)
	m.quad(bfr, bbr, tbr, tfr, glass, Vector3.RIGHT)
	m.box(Transform3D(Basis(), Vector3(0, y1 + 0.03, (z2 + z3) / 2.0)), Vector3(W - 0.16, 0.06, z3 - z2 + 0.08), paint)
	# colunas e moldura
	for sx in [-1.0, 1.0]:
		for pair in [[Vector3(sx * hw, y0, z0), Vector3(sx * tw, y1, z2)], [Vector3(sx * hw, y0, z1), Vector3(sx * tw, y1, z3)],
				[Vector3(sx * hw, y0, (z0 + z1) / 2.0), Vector3(sx * tw, y1, (z2 + z3) / 2.0)]]:
			var a: Vector3 = pair[0]
			var b: Vector3 = pair[1]
			var d := b - a
			m.box(Transform3D(Basis(Quaternion(Vector3.UP, d.normalized())), (a + b) / 2.0), Vector3(0.07, d.length(), 0.08), paint)
		m.box(Transform3D(Basis(), Vector3(sx * hw, y0, (z0 + z1) / 2.0)), Vector3(0.05, 0.05, z1 - z0), Color(0.75, 0.76, 0.78))
