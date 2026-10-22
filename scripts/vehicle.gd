class_name Vehicle
extends CharacterBody3D

# Carro dirigível. kind 0 = sedã esportivo (rápido), kind 1 = picape (mais lenta, mais firme).
# Quem dirige simula o carro e manda a posição pro servidor, que repassa pros outros.

const MAX := [30.0, 19.0]        # velocidade máxima (m/s)
const ACCEL := [9.0, 6.5]
const TURN := [1.9, 1.5]         # giro (rad/s) em velocidade boa
const LEN := [4.4, 5.2]

var game: Node
var idx := 0
var kind := 0
var driver := 0
var speed := 0.0
var yaw := 0.0
var mesh: Node3D
var engine: AudioStreamPlayer3D
var target_pos := Vector3.ZERO
var target_yaw := 0.0
var _tilt := Basis()


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
	floor_max_angle = deg_to_rad(52.0)
	floor_snap_length = 0.6
	safe_margin = 0.05
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.85, 1.0, LEN[k])
	cs.shape = bs
	cs.position = Vector3(0, 0.75, 0)
	add_child(cs)
	var top := CollisionShape3D.new()
	var tb := BoxShape3D.new()
	tb.size = Vector3(1.6, 0.6, 1.7)
	top.shape = tb
	top.position = Vector3(0, 1.45, 0.1 if k == 0 else -0.5)
	add_child(top)
	if visual:
		mesh = Node3D.new()
		add_child(mesh)
		var mi := MeshInstance3D.new()
		mi.mesh = Build.car_mesh(k, tint, false)
		mi.material_override = U.wmat()
		mi.visibility_range_end = 450.0
		mesh.add_child(mi)
		engine = AudioStreamPlayer3D.new()
		engine.stream = load("res://sounds/engine.wav")
		engine.unit_size = 8.0
		engine.max_distance = 90.0
		add_child(engine)
	rotation.y = yaw


func seat_pos() -> Vector3:
	return global_position + Basis(Vector3.UP, yaw) * Vector3(-0.4, 0.55, 0.1)


# simulação de quem dirige: throttle -1..1 (ré/freio .. acelera), steer -1..1
func drive(delta: float, throttle: float, steer: float) -> void:
	var mx: float = MAX[kind]
	if throttle > 0.05:
		speed = move_toward(speed, mx * throttle, ACCEL[kind] * delta * (1.0 if speed >= 0.0 else 2.5))
	elif throttle < -0.05:
		speed = move_toward(speed, -mx * 0.3 * -throttle, (14.0 if speed > 0.0 else ACCEL[kind]) * delta)
	else:
		speed = move_toward(speed, 0.0, 4.0 * delta)
	var turn_k := clampf(absf(speed) / 7.0, 0.0, 1.0) * signf(speed) * (1.0 - clampf((absf(speed) - 18.0) / 30.0, 0.0, 0.35))
	yaw -= steer * TURN[kind] * turn_k * delta
	rotation.y = yaw
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	velocity.x = fwd.x * speed
	velocity.z = fwd.z * speed
	if is_on_floor():
		velocity.y = -1.0
	else:
		velocity.y -= 22.0 * delta
	var before := global_position
	move_and_slide()
	# bateu: perde velocidade
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	if absf(speed) > 3.0 and moved < absf(speed) * delta * 0.35:
		speed *= 0.4
	target_pos = global_position
	target_yaw = yaw
	_update_visual(delta)


# carro dos outros: vai suave até a posição recebida
func follow(delta: float) -> void:
	global_position = global_position.lerp(target_pos, minf(1.0, 12.0 * delta))
	yaw = lerp_angle(yaw, target_yaw, minf(1.0, 12.0 * delta))
	rotation.y = yaw
	_update_visual(delta)


func _update_visual(delta: float) -> void:
	if mesh == null:
		return
	# acompanha o chão (inclina pra frente/trás e pros lados)
	var w: World = game.world
	var b := Basis(Vector3.UP, yaw)
	var p := global_position
	var L: float = LEN[kind] * 0.42
	var hf := w.height(p.x + (b * Vector3(0, 0, -L)).x, p.z + (b * Vector3(0, 0, -L)).z)
	var hb := w.height(p.x + (b * Vector3(0, 0, L)).x, p.z + (b * Vector3(0, 0, L)).z)
	var hl := w.height(p.x + (b * Vector3(-0.85, 0, 0)).x, p.z + (b * Vector3(-0.85, 0, 0)).z)
	var hr := w.height(p.x + (b * Vector3(0.85, 0, 0)).x, p.z + (b * Vector3(0.85, 0, 0)).z)
	var on_ground := absf(p.y - w.height(p.x, p.z)) < 0.6
	var pitch := atan2(hf - hb, L * 2.0) if on_ground else 0.0
	var roll := atan2(hl - hr, 1.7) if on_ground else 0.0
	var want := Basis(Vector3.RIGHT, pitch) * Basis(Vector3.FORWARD, -roll)
	_tilt = _tilt.slerp(want, minf(1.0, 8.0 * delta))
	mesh.basis = _tilt
	if engine:
		var on := driver != 0
		if on and not engine.playing:
			engine.play()
		elif not on and engine.playing:
			engine.stop()
		if on:
			engine.pitch_scale = 0.7 + absf(speed) / MAX[kind] * 1.1
			engine.volume_db = game.sfxn.db(-4.0) if game.sfxn else -4.0
