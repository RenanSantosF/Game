class_name Player
extends CharacterBody3D

const SKIN := Color(0.86, 0.67, 0.5)
const PANTS := Color(0.22, 0.26, 0.36)
const SPEED := 6.0
const GRAVITY := 22.0
const JUMP := 7.0

var game: Node
var pid := 0
var nick := ""
var color := Color.WHITE
var is_local := false
var is_bot := false
var visual := true

var hp := 100.0
var alive := true
var yaw := 0.0
var pitch := 0.0
var primary := ""
var slot := 1          # 0 = arma principal, 1 = pistola
var mag := {}
var reload_t := 0.0
var cool := 0.0
var scoped := false
var want_jump := false
var move_in := Vector2.ZERO
var shown_wid := "glock"

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
var anim_t := 0.0

# bot
var b_think := 0.0
var b_target := 0
var b_react := 0.5
var b_strafe := 0.0
var b_strafe_t := 0.0
var b_wander := Vector3.ZERO
var b_wander_t := 0.0
var b_stuck_t := 0.0
var b_last := Vector3.ZERO


func setup(g: Node, id: int, n: String, c: Color, local: bool, bot: bool, vis: bool) -> void:
	game = g
	pid = id
	nick = n
	color = c
	is_local = local
	is_bot = bot
	visual = vis


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_max_angle = deg_to_rad(50)
	floor_snap_length = 0.4
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	target_pos = position
	_last_pos = position
	b_last = position
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
	return "glock"


func _build_model() -> void:
	model = Node3D.new()
	add_child(model)
	leg_l = Node3D.new()
	leg_l.position = Vector3(-0.12, 0.92, 0)
	model.add_child(leg_l)
	U.box(leg_l, Vector3(0.18, 0.9, 0.2), Vector3(0, -0.45, 0), PANTS)
	leg_r = Node3D.new()
	leg_r.position = Vector3(0.12, 0.92, 0)
	model.add_child(leg_r)
	U.box(leg_r, Vector3(0.18, 0.9, 0.2), Vector3(0, -0.45, 0), PANTS)
	U.box(model, Vector3(0.5, 0.62, 0.28), Vector3(0, 1.25, 0), color)
	U.box(model, Vector3(0.26, 0.28, 0.26), Vector3(0, 1.73, 0), SKIN)
	U.box(model, Vector3(0.28, 0.07, 0.3), Vector3(0, 1.89, -0.02), color.darkened(0.4))
	upper = Node3D.new()
	upper.position = Vector3(0, 1.45, 0)
	model.add_child(upper)
	U.box(upper, Vector3(0.11, 0.11, 0.45), Vector3(0.2, -0.02, -0.2), color)
	U.box(upper, Vector3(0.11, 0.11, 0.5), Vector3(-0.12, -0.04, -0.28), color)
	hand = Node3D.new()
	hand.position = Vector3(0.12, -0.02, -0.45)
	upper.add_child(hand)
	if not is_local:
		var lbl := Label3D.new()
		lbl.text = nick
		lbl.position = Vector3(0, 2.25, 0)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.pixel_size = 0.004
		lbl.font_size = 40
		lbl.outline_size = 10
		lbl.modulate = Color(1, 1, 1, 0.9)
		add_child(lbl)


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


func net_target(pos: Vector3, yw: float, pt: float, wid: String) -> void:
	target_pos = pos
	target_yaw = yw
	target_pitch = pt
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
	velocity = Vector3.ZERO


func respawn(pos: Vector3) -> void:
	alive = true
	hp = 100.0
	collision_layer = 2
	primary = ""
	slot = 1
	scoped = false
	reload_t = 0.0
	refill()
	position = pos
	target_pos = pos
	velocity = Vector3.ZERO
	update_gun()


func _physics_process(delta: float) -> void:
	cool = maxf(cool - delta, 0.0)
	if reload_t > 0.0:
		reload_t -= delta
		if reload_t <= 0.0:
			reload_t = 0.0
			var w := cur_wid()
			mag[w] = Weapons.get_w(w)["mag"]
	if is_local:
		if alive:
			_move(delta)
	elif is_bot and multiplayer.is_server():
		if alive:
			_bot(delta)
			_move(delta)
	else:
		position = position.lerp(target_pos, minf(1.0, 15.0 * delta))
		yaw = lerp_angle(yaw, target_yaw, minf(1.0, 15.0 * delta))
		pitch = lerpf(pitch, target_pitch, minf(1.0, 15.0 * delta))
		est_speed = lerpf(est_speed, Vector2(position.x - _last_pos.x, position.z - _last_pos.z).length() / maxf(delta, 0.001), 0.2)
		_last_pos = position
	if visual:
		_animate(delta)


func _move(delta: float) -> void:
	var dir := Basis(Vector3.UP, yaw) * Vector3(move_in.x, 0, move_in.y)
	var spd := SPEED
	if scoped:
		spd = 3.2
	if is_bot:
		spd = 5.0
	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif want_jump:
		velocity.y = JUMP
	want_jump = false
	move_and_slide()
	if position.y < -40.0:
		position = game.world.random_spawn(game.rng)
		velocity = Vector3.ZERO


func _animate(delta: float) -> void:
	var sp := est_speed
	if is_local or (is_bot and multiplayer.is_server()):
		sp = Vector2(velocity.x, velocity.z).length()
	model.rotation.y = yaw
	if alive:
		anim_t += delta * sp * 1.6
		var sw := sin(anim_t) * clampf(sp / 6.0, 0.0, 1.0) * 0.7
		leg_l.rotation.x = sw
		leg_r.rotation.x = -sw
		upper.rotation.x = pitch * 0.8
		model.rotation.x = 0.0
		model.position.y = 0.0
	else:
		model.rotation.x = lerpf(model.rotation.x, -1.45, minf(1.0, 8.0 * delta))
		model.position.y = 0.15


# ---------------- bot (só roda no servidor) ----------------

func _bot(delta: float) -> void:
	b_think -= delta
	if b_think <= 0.0:
		b_think = 0.3
		_bot_pick_target()
	var mv := Vector2.ZERO
	var t: Player = game.players.get(b_target)
	if t != null and is_instance_valid(t) and t.alive:
		var from := position + Vector3(0, 1.5, 0)
		var aim := t.position + Vector3(0, 1.2, 0)
		var d := aim - from
		var wy := atan2(-d.x, -d.z)
		var wp := atan2(d.y, Vector2(d.x, d.z).length())
		yaw = lerp_angle(yaw, wy, minf(1.0, 5.0 * delta))
		pitch = lerpf(pitch, wp, minf(1.0, 5.0 * delta))
		b_strafe_t -= delta
		if b_strafe_t <= 0.0:
			b_strafe = [-1.0, 0.0, 1.0].pick_random()
			b_strafe_t = randf_range(0.7, 1.8)
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
		b_wander_t -= delta
		if b_wander_t <= 0.0 or Vector2(b_wander.x - position.x, b_wander.z - position.z).length() < 3.0:
			b_wander = game.world.random_point(game.rng)
			b_wander_t = 25.0
		var d2 := b_wander - position
		yaw = lerp_angle(yaw, atan2(-d2.x, -d2.z), minf(1.0, 3.0 * delta))
		pitch = lerpf(pitch, 0.0, minf(1.0, 3.0 * delta))
		mv = Vector2(0, -1)
	if mv.length() > 1.0:
		mv = mv.normalized()
	move_in = mv
	b_stuck_t += delta
	if b_stuck_t > 0.8:
		if mv != Vector2.ZERO and position.distance_to(b_last) < 0.6:
			want_jump = true
			b_wander_t = 0.0
			b_strafe = -b_strafe
		b_last = position
		b_stuck_t = 0.0


func _bot_pick_target() -> void:
	var best := 0
	var bd := 70.0
	var space := get_world_3d().direct_space_state
	var from := position + Vector3(0, 1.5, 0)
	for id in game.players:
		var o: Player = game.players[id]
		if o == self or not o.alive:
			continue
		var dd := o.position.distance_to(position)
		if dd >= bd:
			continue
		var q := PhysicsRayQueryParameters3D.create(from, o.position + Vector3(0, 1.4, 0), 1)
		if space.intersect_ray(q).is_empty():
			best = id
			bd = dd
	if best != b_target:
		b_react = randf_range(0.35, 0.8)
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
	var s := tan(deg_to_rad(float(w["spread"]) + 4.0))
	var dirs := []
	for i in int(w["pellets"]):
		var a := randf() * TAU
		var r := sqrt(randf()) * s
		dirs.append((base + right * cos(a) * r + up * sin(a) * r).normalized())
	game.server_bot_shot(pid, from, dirs, wid)
	if mag[wid] <= 0:
		reload_t = w["reload"]
