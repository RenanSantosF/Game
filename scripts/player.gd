class_name Player
extends CharacterBody3D

const SPEED := 6.0
const GRAVITY := 18.5
const JUMP := 6.3
const FALL_SPEED := 15.0       # queda livre
const FALL_MOVE := 16.0
const CHUTE_SPEED := 4.5       # paraquedas
const CHUTE_MOVE := 6.5
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
var prone := false       # deitado (rasteja devagar, fica baixinho)
var want_jump := false
var wish := Vector3.ZERO  # direção desejada no mundo (comprimento até 1)
var shown_wid := "glock"
var air := 0             # 0 = no chão, 1 = queda livre, 2 = paraquedas, 3 = no avião
var armor := 0.0
var helmet := 0          # nível do capacete (0 = sem)
var helmet_hp := 100.0   # durabilidade do capacete (só no servidor); quebra no zero
var vest_lv := 0          # nível do colete
var bag := 0             # nível da mochila (0 = sem mochila)
var sprint := false
var stun_t := 0.0        # atordoado depois de cair de alto
var _fall_v := 0.0
var inv := {}
var heal_t := 0.0
var heal_kind := ""
var punch_t := 0.0
var gren_hold := false      # segurando a granada sem pino (braço pra trás, pronto pra jogar)
var _gren_k := 0.0
var _vel_mul := 1.0
var _chute_age := -1.0      # tempo desde que o paraquedas abriu (tranco da abertura)
var _gren_mi: MeshInstance3D
static var _handle_cache := {}
var vault_t := -1.0
var _vault := []
var aim_t := 0.0         # tempo virado pra mira depois de atirar
var ready_t := 0.0       # tempo com a arma apontada (depois volta pra perto da barriga)
var _ready_k := 0.0
var _air_time := 0.0
var _jump_seen := false
var _jump_t := -1.0          # tempo da animação do pulo (-1 = no chão)
const JUMP_ANIM_T := 0.76   # ~ tempo no ar de um pulo normal
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


func sim_local() -> bool:
	return is_local or (is_bot and multiplayer.is_server())
var regen := 0.0
var _breath := 0.0
var _crouch_k := 0.0
var _heal_anim := 0.0
var _last_hp := 200.0
var _hit_t := 0.0       # tomou tiro agora (animação de reação parado)
var _wall_chk := 0.0
var _wall_near := false
var _gun_low := 0.0
var b_exit: Array = []       # caminho pra sair de casa (porta de dentro, porta de fora)
var b_stuck_n := 0
var b_escape_t := 0.0
var b_escape := Vector3.ZERO
var b_cover := Vector3.INF   # ponto atrás de alguma coisa (protegido do alvo) ou INF
var b_cover_t := 0.0         # quando procurar cobertura de novo
var b_peek := false          # atrás da cobertura: true = levantou pra atirar, false = escondido
var b_peek_t := 0.0
var b_hold := 0.0            # escondido: continua "lembrando" do alvo mesmo sem ver


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
	floor_snap_length = 0.55
	# na rampa anda na mesma velocidade (sem "patinar" subindo) e parado não escorrega
	floor_constant_speed = true
	floor_stop_on_slope = true
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
	return 0.38 if prone else (1.03 if crouch else 1.48)


func capacity() -> int:
	return Weapons.BAGS[clampi(bag, 0, 3)]


func free_slots() -> int:
	return capacity() - Weapons.slots_used(inv)


func count(kind: String) -> int:
	return int(inv.get(kind, 0))


func flags() -> int:
	return air | (int(crouch) << 2) | (int(heal_t > 0.0) << 3) | (int(vault_t >= 0.0) << 4) | (int(punch_t > 0.0) << 5) | (int(not is_on_floor() and air == 0) << 6) | (int(car >= 0) << 7) | (int(stun_t > 0.0) << 8) | (int(reload_t > 0.0) << 9) | (int(prone) << 10) | (int(gren_hold) << 11)


func set_flags(f: int) -> void:
	air = f & 3
	set_crouch(((f >> 2) & 1) == 1)
	set_prone(((f >> 10) & 1) == 1)
	heal_t = 1.0 if ((f >> 3) & 1) == 1 else 0.0
	vault_t = 0.2 if ((f >> 4) & 1) == 1 else -1.0
	if ((f >> 5) & 1) == 1 and punch_t <= 0.0:
		punch_t = 0.3
	_remote_air = ((f >> 6) & 1) == 1
	if not sim_local():
		gren_hold = ((f >> 11) & 1) == 1
	_remote_car = ((f >> 7) & 1) == 1
	if not sim_local():
		stun_t = 0.3 if ((f >> 8) & 1) == 1 else 0.0
		var rl := ((f >> 9) & 1) == 1
		if rl and reload_t <= 0.0:
			reload_t = float(cur_stat()["reload"])
		elif not rl:
			reload_t = 0.0


var _remote_air := false


func set_crouch(c: bool) -> void:
	if c == crouch:
		return
	crouch = c
	if c:
		sprint = false
		if prone:
			prone = false
	_fit_capsule()


func set_prone(c: bool) -> void:
	if c == prone:
		return
	prone = c
	if c:
		sprint = false
		crouch = false
	_fit_capsule()


# altura da colisão: em pé, agachado ou deitado
func _fit_capsule() -> void:
	cap.height = 0.8 if prone else (1.25 if crouch else 1.8)
	cshape.position.y = cap.height / 2.0


# ---------------- modelo ----------------



static func _gear(kind: String) -> Mesh:
	if _shared.has(kind):
		return _shared[kind]
	var m := MB.new()
	match kind:
		"vest1", "vest2", "vest3", "helmet1", "helmet2", "helmet3", "bag1", "bag2", "bag3":
			_shared[kind] = Weapons.gear(kind)
			return _shared[kind]
		"chute":
			_shared[kind] = _chute_mesh()
			return _shared[kind]
	var mesh := m.commit()
	_shared[kind] = mesh
	return mesh


# Paraquedas: velame tipo asa, largo (8,6 m) e arqueado, com 9 células estufadas entre as costuras,
# perfil de asa (grosso na frente, fino atrás), listras e cordas finas em cascata (várias cordas do
# velame juntam em 4 pontos e descem nos dois tirantes dos ombros). Tecido brilhante (shaders/chute).
static func _chute_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const CELLS := 9
	const SU := 6           # divisões por célula
	const SV := 9           # divisões na corda (frente -> trás)
	var span_a := 0.95      # meio ângulo do arco
	var R := 3.9
	var H := 5.2
	var chord := 3.3
	var cols := [Color(0.4, 0.47, 0.28), Color(0.9, 0.85, 0.68)]
	var nu := CELLS * SU
	# ponto do velame: u 0..1 envergadura, v 0..1 corda, side +1 em cima / -1 embaixo
	var surf := func(u: float, v: float, side: float) -> Vector3:
		var a := lerpf(-span_a, span_a, u)
		var x := sin(a) * R
		var y := H + (cos(a) - 1.0) * R * 0.55
		var z := lerpf(-chord * 0.5, chord * 0.5, v)
		# ângulo de ataque: bordo de fuga um pouco mais baixo
		y -= v * 0.28
		# perfil de asa e células estufadas (entre costuras) só em cima
		var cell := fmod(u * CELLS, 1.0)
		var puff := 0.7 + 0.3 * sin(cell * PI)
		# perfil cheio até perto das bordas (quinas arredondadas e gordinhas, não em ponta)
		var prof := pow(sin(PI * clampf(pow(v, 0.65), 0.0, 1.0)), 0.55)
		var thick := 0.82 * prof * puff
		if side > 0.0:
			y += thick
		else:
			y -= 0.16 * pow(sin(PI * v), 0.6)
		# o arco "empurra" a altura pra fora do centro (normal do arco)
		return Vector3(x, y, z)
	for side in [1.0, -1.0]:
		for j in SV:
			for i in nu:
				var u0 := float(i) / nu
				var u1 := float(i + 1) / nu
				var v0 := float(j) / SV
				var v1 := float(j + 1) / SV
				var ci := int(float(i) / SU)
				var c: Color = cols[ci % cols.size()] if ci != CELLS / 2 else Color(0.78, 0.2, 0.12)
				if side < 0.0:
					c = c.darkened(0.08)
				var pts := [surf.call(u0, v0, side), surf.call(u1, v0, side), surf.call(u1, v1, side), surf.call(u0, v1, side)]
				var uvs := [Vector2(u0 * CELLS, v0), Vector2(u1 * CELLS, v0), Vector2(u1 * CELLS, v1), Vector2(u0 * CELLS, v1)]
				var order := [0, 1, 2, 0, 2, 3] if side > 0.0 else [0, 2, 1, 0, 3, 2]
				for k in order:
					st.set_color(c)
					st.set_uv(uvs[k])
					st.set_uv2(Vector2(0.0, 1.0 if side < 0.0 else 0.0))
					st.add_vertex(pts[k])
	# boca de ar na frente e fechamento atrás (entre a pele de cima e a de baixo)
	for edge_v in [0.0, 1.0]:
		for i in nu:
			var u0 := float(i) / nu
			var u1 := float(i + 1) / nu
			var t0: Vector3 = surf.call(u0, edge_v, 1.0)
			var t1: Vector3 = surf.call(u1, edge_v, 1.0)
			var b0: Vector3 = surf.call(u0, edge_v, -1.0)
			var b1: Vector3 = surf.call(u1, edge_v, -1.0)
			var c := Color(0.2, 0.22, 0.16)
			for p in [t0, t1, b1, t0, b1, b0]:
				st.set_color(c)
				st.set_uv(Vector2(0.5, edge_v))
				st.set_uv2(Vector2.ZERO)
				st.add_vertex(p)
	# cordas finas: 4 fileiras (A..D) em cada costura -> 2 pontos de junção por lado -> tirante no ombro
	var line_c := Color(0.86, 0.85, 0.8)
	var risers := [Vector3(-0.2, 1.62, 0.02), Vector3(0.2, 1.62, 0.02)]
	var add_line := func(a: Vector3, b: Vector3, w: float) -> void:
		var d := b - a
		var side := d.cross(Vector3.FORWARD).normalized() * w
		var side2 := d.cross(Vector3.RIGHT).normalized() * w
		for sv in [side, side2]:
			for p in [a - sv, a + sv, b + sv, a - sv, b + sv, b - sv]:
				st.set_color(line_c)
				st.set_uv(Vector2.ZERO)
				st.set_uv2(Vector2(1.0, 0.0))
				st.add_vertex(p)
	for sd in 2:
		var r: Vector3 = risers[sd]
		var sx := -1.0 if sd == 0 else 1.0
		for g in 2:
			# ponto de junção (cascata) a ~1,3 m acima do ombro, um mais pra dentro e outro pra fora
			var gx := sx * (0.55 + g * 1.0)
			var jp := Vector3(gx, 3.0 + g * 0.15, 0.0)
			add_line.call(r, jp, 0.008)
			for rib in range(CELLS + 1):
				var u := float(rib) / CELLS
				var px: float = (surf.call(u, 0.5, -1.0) as Vector3).x
				if signf(px) != sx and absf(px) > 0.05:
					continue
				# cada junção pega as costuras do seu lado (dentro / fora)
				var outer := absf(px) > R * 0.45
				if (g == 1) != outer:
					continue
				for v in [0.12, 0.38, 0.62, 0.88]:
					add_line.call(jp, surf.call(u, v, -1.0), 0.005)
	st.generate_normals()
	var mesh := st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/chute.gdshader")
	mat.set_shader_parameter("cells", float(CELLS))
	mesh.surface_set_material(0, mat)
	return mesh


func _build_model() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(pid) * 7919 + 13
	var shirt: Color = SHIRTS[rng.randi() % SHIRTS.size()]
	var pants: Color = PANTS[rng.randi() % PANTS.size()]
	var skin: Color = SKINS[rng.randi() % SKINS.size()]
	var hair: Color = HAIRS[rng.randi() % HAIRS.size()]
	var long_sleeve := rng.randf() < 0.5
	var cap_hat := false     # skin fixa: ninguém ganha boné sorteado
	model = Node3D.new()
	add_child(model)
	# boneco animado (Mixamo), com a mesma skin pra todos
	sol = Soldier.new()
	model.add_child(sol)
	sol.setup(skin, shirt, pants, BOOTS[rng.randi() % BOOTS.size()], hair)
	vest_mi = MeshInstance3D.new()
	vest_mi.mesh = _gear("vest1")
	vest_mi.set_surface_override_material(0, U.wmat())
	sol.attach("Spine2", vest_mi, "vest")
	bag_mi = MeshInstance3D.new()
	bag_mi.mesh = _gear("bag1")
	bag_mi.set_surface_override_material(0, U.wmat())
	sol.attach("Spine2", bag_mi, "bag")
	helmet_mi = MeshInstance3D.new()
	helmet_mi.mesh = _gear("helmet1")
	helmet_mi.set_surface_override_material(0, U.wmat())
	sol.attach("Head", helmet_mi, "helmet")
	if cap_hat:
		var hat := MeshInstance3D.new()
		var hm := MB.new()
		var hc: Color = SHIRTS[rng.randi() % SHIRTS.size()]
		hm.tex(U.FABRIC, 4.0)
		hm.blob(Transform3D(Basis.from_scale(Vector3(0.1, 0.065, 0.112)), Vector3(0, 1.66, 0.0)), 9, 4, hc)
		hm.box(Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3(0, 1.655, -0.12)), Vector3(0.16, 0.012, 0.09), hc.darkened(0.1))
		hat.mesh = hm.commit()
		hat.material_override = U.wmat()
		sol.attach("Head", hat, "helmet")
	# mira (gira com o pitch); a arma fica aqui e os braços alcançam a arma
	aim = Node3D.new()
	aim.position = Vector3(0, 1.36, 0)
	model.add_child(aim)
	chute = Node3D.new()
	var cmi := MeshInstance3D.new()
	cmi.mesh = _gear("chute")
	cmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chute.add_child(cmi)
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
	if bag_mi.visible:
		bag_mi.mesh = _gear("bag%d" % clampi(bag, 1, 3))


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
	_gun_base = gun.position
	# saque: pistola sai rápido do coldre (da lateral da perna pra mão); arma grande vem das costas
	# por cima do ombro, desce pra frente e dá um tranco (engatilha)
	_draw_dur = DRAW_TIME if t == "pistol" else DRAW_T
	_draw_t = _draw_dur
	_draw_pistol = t == "pistol"
	aim.add_child(gun)
	for c in gun.get_children():
		if c is GeometryInstance3D:
			c.visibility_range_end = 0.0     # o inimigo aparece igual de qualquer distância
	update_back_guns()


const DRAW_TIME := 0.22
const DRAW_T := 0.45        # saque da arma grande (das costas pra mão)
var _draw_t := 0.0
var _draw_dur := DRAW_TIME
var _draw_pistol := true
var _wind_t := 0.0
var vis_dy := 0.0           # diferença entre a altura mostrada (suave) e a real
var _last_vis_y := 0.0
var kick := 0.0             # tranco do tiro (1 no disparo, volta rápido)
var _gun_base := Vector3.ZERO
var _back := []        # armas grandes penduradas nas costas


# armas grandes que não estão na mão ficam nas costas (em X, cano pra cima)
var _back_key := ""


const BACK_SCALE := 0.74


func update_back_guns() -> void:
	if not visual or sol == null:
		return
	_back_key = _back_sig()
	for n in _back:
		if is_instance_valid(n):
			n.queue_free()
	_back.clear()
	var k := 0
	for i in 2:
		var g: Dictionary = guns[i]
		if g["id"] == "" or (i == sel and shown_wid == g["id"]):
			continue
		var holder := Node3D.new()
		var m := Weapons.build_model(g["id"], g["att"])
		# cano pra cima, atravessado nas costas; a segunda arma cruza a primeira
		var tilt := 0.55 if k == 0 else -0.55
		# colada nas costas (ou por cima da mochila, se tiver)
		var bz: float = 0.175 if bag <= 0 else 0.15 + 0.11 * [0.0, 0.85, 1.0, 1.12][clampi(bag, 0, 3)] + 0.03
		# nas costas a arma fica menor (não cobre o boneco inteiro)
		m.transform = Transform3D(Basis(Vector3.FORWARD, tilt) * Basis(Vector3.RIGHT, PI / 2.0) * Basis.from_scale(Vector3.ONE * BACK_SCALE), Vector3(0.0, 1.05, bz + k * 0.03))
		for c in m.get_children():
			if c is GeometryInstance3D:
				c.visibility_range_end = 0.0
				(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(m)
		sol.attach("Spine2", holder)
		_back.append(holder.get_parent())
		k += 1


# o que está nas costas depende das armas, da selecionada e da que aparece na mão
func _back_sig() -> String:
	return "%s|%s|%d|%s|%d" % [guns[0]["id"], guns[1]["id"], sel, shown_wid, bag]


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
	set_prone(false)
	velocity = Vector3.ZERO
	if sol and model and model.visible and air == 0:
		dying_t = 2.2
		sol.play("Dead", 0.08, 2.0 if sol.has_anim("RifleIdle") else (1.7 if sol.has_anim("Sprint") else 1.0))
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
	set_prone(false)
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


# meio do cabo da pistola (no espaço da arma): embaixo e atrás do modelo
static func _pistol_handle(id: String) -> Vector3:
	if not _handle_cache.has(id):
		var ab := AABB(Vector3(-0.02, -0.05, -0.15), Vector3(0.04, 0.12, 0.19))
		if ResourceLoader.exists("res://models/guns/%s.res" % id):
			ab = (load("res://models/guns/%s.res" % id) as Mesh).get_aabb()
		_handle_cache[id] = Vector3(0.0, ab.position.y * 0.55, ab.end.z - 0.03)
	return _handle_cache[id]


func board() -> void:
	air = 3
	dying_t = 0.0
	if model:
		model.visible = false
	set_crouch(false)
	set_prone(false)
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
	ready_t = maxf(ready_t - delta, 0.0)
	if reload_t > 0.0:
		var tot := maxf(float(cur_stat()["reload"]), 0.3)
		var before := reload_t
		reload_t -= delta
		# no meio da recarga: o pente novo entra ("TCHAK"), o som não some no meio
		if is_local and before > tot * 0.45 and reload_t <= tot * 0.45:
			game.sfx("reload_mid", 3.0)
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
				game.sfx("reload_in", 3.0)
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
			_vel_mul = 1.0
			if car >= 0:
				velocity = Vector3.ZERO
			elif vault_t >= 0.0:
				_vault_step(delta)
			elif is_bot and b_far and air == 0 and not game.near_cam(position, 120.0):
				# longe de todos e da câmera: anda só 1 quadro a cada 3
				if Engine.get_physics_frames() % 3 == pid % 3:
					_vel_mul = 3.0
					_move(delta * 3.0)
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
	if visual and air == 3 and model and model.visible:
		# dentro do avião ninguém aparece (nem de longe, sem esperar a animação)
		model.visible = false
		if chute:
			chute.visible = false
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
		# no paraquedas é mais pesado pra mudar de direção
		var k := minf(1.0, (2.5 if air == 1 else 1.3) * delta)
		velocity.x = lerpf(velocity.x, dir.x * hs, k)
		velocity.z = lerpf(velocity.z, dir.z * hs, k)
		velocity.y = -FALL_SPEED if air == 1 else -CHUTE_SPEED
		if dir.length() > 0.1:
			yaw = lerp_angle(yaw, atan2(-dir.x, -dir.z), minf(1.0, (3.0 if air == 1 else 1.2) * delta))
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
				game.sfx("chute", 4.0)
		_keep_in()
		return
	# analógico: quanto mais empurra, mais rápido (até uma corrida leve); botão de correr = corrida forte
	# o analógico já corre (corrida leve); o botão de correr é a corrida forte
	# toque leve perto do centro: só vira / anda devagarinho (girar o analógico no meio não desliza)
	var dl := dir.length()
	var spd := 0.0
	if dl > 0.15:
		spd = lerpf(0.0, 3.15, smoothstep(0.15, 0.45, dl)) if dl < 0.45 else lerpf(3.15, 4.05, clampf((dl - 0.45) / 0.4, 0.0, 1.0))
	if sprint:
		spd = 5.6 if (sel < 0 or cur_wid() == "fist") else 5.3
	# atirando ou dando soco anda bem mais devagar
	if (aim_t > 0.0 and not sprint) or (is_local and game.hud != null and game.hud.fire_held):
		spd = minf(spd, 2.6)
	if punch_t > 0.0:
		spd = minf(spd, 2.2)
	if crouch:
		spd = 2.8
	if prone:
		spd = minf(spd, 0.9)
	if scoped:
		spd = minf(spd, 3.2)
	if heal_t > 0.0:
		spd = 2.0
	if game.world.in_water(position):
		spd = minf(spd, 3.2)
	if is_bot:
		spd = (5.3 if sprint else 4.05) if b_target == 0 else (5.15 if sprint else 3.8)
		if crouch:
			spd = 2.6
	if stun_t > 0.0:
		spd = 0.0
	var on_floor := is_on_floor()
	# mudou muito de direção: primeiro vira o corpo, depois anda (não sai de lado deslizando)
	if not is_bot and dl > 0.15 and aim_t <= 0.0 and not scoped and not sprint:
		var tdiff := absf(angle_difference(yaw, atan2(-dir.x, -dir.z)))
		spd *= clampf(1.25 - tdiff / 1.6, 0.12, 1.0)
	# no ar não dá pra mudar a direção
	if on_floor:
		velocity.x = dir.x * spd
		velocity.z = dir.z * spd
	# corpo vira pra onde anda, ou pra mira quando está atirando (no ar não gira)
	if not is_bot and on_floor:
		# soltou o tiro e mexeu no analógico: já larga a mira e vira pra onde anda (sem atraso)
		if aim_t > 0.0 and not scoped and dir.length() > 0.3 and is_local and game.hud != null and not game.hud.fire_held:
			aim_t = 0.0
		if aim_t > 0.0 or scoped:
			yaw = lerp_angle(yaw, game.cam_yaw_v, minf(1.0, 28.0 * delta))
		elif dir.length() > 0.15:
			# vira pra onde anda sem estalar (girando o analógico rápido ele gira mais devagar)
			var want := atan2(-dir.x, -dir.z)
			var diff := angle_difference(yaw, want)
			yaw += clampf(diff, -11.0 * delta, 11.0 * delta)
	if not on_floor:
		velocity.y -= GRAVITY * delta
		_air_time += delta
		_fall_v = maxf(_fall_v, -velocity.y)
	elif not want_jump or stun_t > 0.0:
		# no chão: nada de velocidade vertical sobrando (senão fica quicando na rampa)
		velocity.y = 0.0
	elif want_jump and stun_t <= 0.0:
		if prone:
			set_prone(false)
		elif crouch:
			set_crouch(false)
			set_prone(false)
		elif not try_vault(dir if dir.length() > 0.1 else Basis(Vector3.UP, yaw) * Vector3.FORWARD):
			velocity.y = JUMP
			if is_local:
				game.sfx("jump")
	want_jump = false
	if _vel_mul != 1.0:
		# bot longe de todo mundo anda 1 quadro a cada 3 (com o passo 3x maior): física bem mais leve
		var vm := velocity
		velocity *= _vel_mul
		move_and_slide()
		velocity = Vector3(vm.x, velocity.y / _vel_mul, vm.z)
	else:
		move_and_slide()
	_step_up(dir, spd, delta)
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


# sobe em coisa baixa (pedra, degrau, meio-fio) sem precisar pular: até ~55 cm
const STEP_H := 0.55


func _step_up(dir: Vector3, spd: float, delta: float) -> void:
	if not is_on_floor() or not is_on_wall() or dir.length() < 0.2 or spd <= 0.0 or vault_t >= 0.0:
		return
	var f := Vector3(dir.x, 0, dir.z).normalized() * maxf(spd * delta, 0.08) * 2.0
	var xf := global_transform
	# cabe lá em cima?
	if test_move(xf, Vector3(0, STEP_H, 0)):
		return
	var up := xf.translated(Vector3(0, STEP_H, 0))
	if test_move(up, f):
		return
	# desce até encostar no degrau
	var top := up.translated(f)
	var col := KinematicCollision3D.new()
	if not test_move(top, Vector3(0, -STEP_H, 0), col):
		return
	if col.get_normal().y < 0.7:
		return
	var drop := col.get_travel().y
	global_position = top.origin + Vector3(0, drop + 0.02, 0)


func _keep_in() -> void:
	var lobby: bool = game.phase == game.LOBBY and not game.sandbox
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
	# subindo escada/rampa não é janela: pulo normal
	if is_on_floor() and get_floor_normal().y < 0.9:
		return false
	var hit_d := 99.0
	for hgt in [0.45, 0.85, 1.2]:
		var q := PhysicsRayQueryParameters3D.create(base + Vector3(0, hgt, 0), base + Vector3(0, hgt, 0) + f * 1.25, 1, ex)
		var r := space.intersect_ray(q)
		# só conta parede de pé (rampa da escada é inclinada)
		if not r.is_empty() and absf((r["normal"] as Vector3).y) < 0.4:
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
	if top < 0.4 or top > 1.45 or (tr["normal"] as Vector3).y < 0.85:
		return false
	# coisa larga (caixote, feno, caixa de arma, pedra): sobe e fica em cima, não atravessa
	var on_top := true
	for extra in [0.35, 0.9]:
		var pp: Vector3 = base + f * (hit_d + extra)
		var oq := PhysicsRayQueryParameters3D.create(pp + Vector3(0, top + 0.5, 0), pp + Vector3(0, top - 0.3, 0), 1, ex)
		var orr := space.intersect_ray(oq)
		if orr.is_empty() or absf((orr["position"] as Vector3).y - (base.y + top)) > 0.25:
			on_top = false
	if on_top:
		var spot: Vector3 = base + f * (hit_d + 0.45) + Vector3(0, top + 0.04, 0)
		var hq := PhysicsRayQueryParameters3D.create(spot + Vector3(0, 0.2, 0), spot + Vector3(0, 1.75, 0), 1, ex)
		if space.intersect_ray(hq).is_empty():
			_vault_drop = false
			_vault = [base, base + f * (hit_d * 0.5) + Vector3(0, top + 0.45, 0), spot]
			vault_t = 0.0
			collision_mask = 0
			yaw = atan2(-f.x, -f.z)
			set_crouch(false)
			set_prone(false)
			game.sfx_at("vault", base, is_local)
			return true
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
		set_prone(false)
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
		# termina com o pé batendo no chão do outro lado
		if game:
			game.on_step(self, false)


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
	# dentro do avião nada do boneco aparece (nem animação de morte que sobrou do lobby)
	if air == 3:
		dying_t = 0.0
		model.visible = false
		chute.visible = false
		if _gren_mi:
			_gren_mi.visible = false
		return
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
	model.visible = air != 3 and not spect and alive
	chute.visible = alive and air == 2
	if not model.visible:
		return
	# dirigindo: sentado, mãos no volante, sem arma
	if car >= 0 and car < game.vehicles.size():
		var v: Vehicle = game.vehicles[car]
		model.rotation = Vector3(0, v.yaw, 0)
		model.position = Vector3(0, -0.45, 0)
		aim.visible = false
		sol.play("Driving" if sol.has_anim("Driving") else "Idle", 0.2)
		var wp := v.wheel_pos()
		var rt := Basis(Vector3.UP, v.yaw) * Vector3.RIGHT
		sol.tick(delta, not game.near_cam(global_position, 35.0), 0.0, 0.85, [wp - rt * 0.2, wp + rt * 0.2])
		return
	aim.visible = true
	# arma das costas sempre igual ao que o jogador tem (largou/trocou: atualiza na hora)
	if _back_sig() != _back_key:
		update_back_guns()
	# o corpo vira rápido mas não de estalo (movimento mais natural)
	model.rotation.y = lerp_angle(model.rotation.y, yaw, minf(1.0, 16.0 * delta))
	chute.rotation.y = yaw
	var k := minf(1.0, 12.0 * delta)
	var airborne := (not is_on_floor()) if sim else _remote_air
	if not airborne:
		_jump_t = -1.0
		_jump_seen = false
	var armed := shown_wid != "fist"
	var far: bool = not game.near_cam(global_position, 35.0)
	var cr := 0.0
	var hands := []
	var hand_dirs := []
	var pole_k := 0.0
	aim.rotation.x = 0.0
	if air == 1:
		# queda livre: a animação já é deitada (braços abertos); só endireita o corpo
		var mix := sol.has_anim("Fall")
		model.rotation.x = lerpf(model.rotation.x, 0.0 if mix else -1.2, k)
		model.position.y = 0.2 if mix else 0.6
		sol.play("Fall" if mix else "Air", 0.25)
		# vento na queda livre: o corpo balança e treme um pouco
		_wind_t += delta
		var wt := _wind_t + float(pid % 7)
		model.rotation.z = sin(wt * 2.3) * 0.12 + sin(wt * 6.1) * 0.035
		model.rotation.x += sin(wt * 1.7) * 0.07 + sin(wt * 7.3) * 0.02
		if not mix:
			hands = [model.global_transform * Vector3(-0.8, 1.45, 0.15), model.global_transform * Vector3(0.8, 1.45, 0.15)]
		sol.tick(delta, far, 0.0, 0.0, hands)
		return
	# pulando a janela: corpo inclina pra frente e as pernas encolhem (passa por cima do batente)
	# com a animação de salto do Mixamo o corpo não precisa inclinar por código
	var vault_anim := sol.has_anim("Vault")
	var vk := sin(clampf(vault_t / VAULT_TIME, 0.0, 1.0) * PI) if vault_t >= 0.0 else 0.0
	if vault_anim:
		vk = 0.0
	model.rotation.x = lerpf(model.rotation.x, -0.55 * vk, minf(1.0, 20.0 * delta))
	if air == 2:
		# paraquedas: pendurado com os braços pra cima segurando as cordas
		model.position.y = -0.15 if sol.has_anim("Chute") else 0.0
		# pendurado no paraquedas: balança como pêndulo com o vento (e o paraquedas acompanha de leve)
		_wind_t += delta
		var ct := _wind_t + float(pid % 5)
		model.rotation.z = sin(ct * 1.35) * 0.16 + sin(ct * 3.7) * 0.035
		model.rotation.x = sin(ct * 1.05) * 0.1
		chute.rotation.z = sin(ct * 1.35 - 0.5) * 0.08 + sin(ct * 2.9) * 0.02
		chute.rotation.x = sin(ct * 1.05 - 0.5) * 0.05
		# abertura bruta: o velame estoura de uma vez (passa do tamanho e volta) e o corpo leva o tranco
		if _chute_age < 0.0:
			_chute_age = 0.0
			if is_local and game:
				game._shake = maxf(game._shake, 0.75)
		_chute_age += delta
		var ca := _chute_age
		if ca < 1.6:
			var inf := 1.0 - exp(-ca * 7.0) * cos(ca * 15.0)
			chute.scale = Vector3(lerpf(0.15, 1.0, inf), lerpf(0.35, 1.0, inf), lerpf(0.1, 1.0, inf))
			var jolt := exp(-ca * 3.5)
			model.position.y += -0.55 * jolt * cos(ca * 11.0)
			model.rotation.x += 0.75 * jolt * sin(ca * 9.0 + 0.6)
			model.rotation.z += 0.22 * jolt * sin(ca * 13.0)
		else:
			chute.scale = Vector3.ONE
		if sol.has_anim("Chute"):
			sol.play("Chute", 0.3)
		else:
			sol.play("Air", 0.3, 0.2)
			hands = [model.global_transform * Vector3(-0.3, 1.95, -0.05), model.global_transform * Vector3(0.3, 1.95, -0.05)]
		sol.tick(delta, far, 0.0, 0.0, hands)
		return
	_chute_age = -1.0
	model.position.y = 0.0
	model.rotation.z = lerpf(model.rotation.z, 0.0, minf(1.0, 8.0 * delta))
	# degrau/rampa irregular: o corpo acompanha a altura suave (o pulo da colisão não aparece)
	if not airborne:
		var jump_y := _last_vis_y - global_position.y
		vis_dy = lerpf(vis_dy, 0.0, minf(1.0, 14.0 * delta))
		# só esconde saltos bruscos (degrau); subida contínua de rampa passa direto
		if absf(jump_y) > 0.06 and absf(jump_y) < 0.6:
			vis_dy = clampf(vis_dy + jump_y, -0.3, 0.3)
		model.position.y = vis_dy
	else:
		vis_dy = 0.0
	_last_vis_y = global_position.y
	# arma encostada na parede: abaixa o cano (não atravessa a parede)
	_wall_chk -= delta
	if _wall_chk <= 0.0 and armed and gun and not far:
		_wall_chk = 0.15
		var from := global_position + Vector3(0, 1.4, 0)
		var fw := Basis(Vector3.UP, yaw) * Vector3.FORWARD
		var q := PhysicsRayQueryParameters3D.create(from, from + fw * 1.05, 1)
		_wall_near = not get_world_3d().direct_space_state.intersect_ray(q).is_empty()
	_gun_low = lerpf(_gun_low, 1.0 if (_wall_near and armed) else 0.0, minf(1.0, 10.0 * delta))
	# sem atirar: arma baixa, perto da barriga; atirando ou mirando: levanta e aponta
	var rdy: bool = ready_t > 0.0 or aim_t > 0.0 or scoped or (is_local and game.hud != null and game.hud.fire_held)
	_ready_k = lerpf(_ready_k, 1.0 if rdy else 0.0, minf(1.0, (18.0 if rdy else 5.0) * delta))
	# sem atirar: arma abaixada e atravessada na frente do corpo (cano pra baixo e pro lado esquerdo);
	# atirando ou mirando levanta e aponta pra mira
	var idle_k := 1.0 - _ready_k
	var low := _gun_low
	_crouch_k = lerpf(_crouch_k, 1.0 if crouch else 0.0, k)
	var pistol := armed and str(Weapons.get_w(shown_wid)["type"]) == "pistol"
	# pistola: baixa na frente (braço esticado pra frente, não dobrado pra dentro do peito)
	aim.rotation.x = pitch * 0.85 * _ready_k * (1.0 - low) - 1.1 * low - (0.45 if pistol else 0.5) * idle_k * (1.0 - low)
	aim.rotation.y = (0.08 if pistol else 0.42) * idle_k
	# agachado a arma desce junto (fica no ombro/peito, não em cima da cabeça)
	var sh_y := lerpf(1.36, 0.98, _crouch_k)
	# sem atirar a arma fica um pouco à frente do corpo (não entra no colete)
	aim.position = Vector3((0.02 if pistol else -0.03) * idle_k, sh_y - idle_k * (0.14 if pistol else 0.1), -idle_k * (0.1 if pistol else 0.07))
	if stun_t > 0.0 and not airborne:
		# caiu de alto: aterrissa agachado com a mão no chão
		if sol.has_anim("Land"):
			if sol.cur != "Land":
				sol.play("Land", 0.08, 1.6)
			if gun:
				gun.visible = false
			sol.tick(delta, far, 0.0, 0.0, [])
			return
		sol.play("Idle", 0.08)
		var gp2 := model.global_transform
		sol.tick(delta, far, 0.0, 1.0, [gp2 * Vector3(-0.22, 0.75, -0.25), gp2 * Vector3(0.18, 0.05, -0.45)])
		return
	# venceu: comemora (sem arma na mão)
	if game.winner == pid and game.winner != 0 and sol.has_anim("Victory"):
		sol.play("Victory", 0.25)
		if gun:
			gun.visible = false
		sol.tick(delta, far, 0.0, 0.0, [])
		return
	# deitado: rasteja (parado segura a pose); a arma fica baixinha na frente, sem esticar os braços
	if prone and not airborne and sol.has_anim("Prone"):
		if sp < 0.15:
			sol.play("ProneIdle" if sol.has_anim("ProneIdle") else "Prone", 0.3)
		else:
			sol.play("Prone", 0.3, clampf(sp / 0.45, 0.6, 1.6))
		aim.rotation = Vector3(pitch * 0.3 * _ready_k, 0.0, 0.0)
		if gun:
			gun.visible = armed and heal_t <= 0.0
		var ph := []
		if heal_t > 0.0 and sol.b.has("Head"):
			# deitado se curando: braço esquerdo na frente do rosto e a mão direita enrolando a faixa
			_heal_anim += delta
			var hd: Vector3 = sol.sk.global_transform * sol.sk.get_bone_global_pose(sol.b["Head"]).origin
			var mf := -model.global_transform.basis.z.normalized()
			var mr := model.global_transform.basis.x.normalized()
			var c0 := hd + mf * 0.28 + Vector3(0, -0.12, 0)
			var ang := _heal_anim * 9.0
			ph = [c0 - mr * 0.06, c0 + mr * 0.04 + Vector3(0, cos(ang) * 0.06, 0) + mf * sin(ang) * 0.06]
		sol.tick(delta, far, 0.0, 0.0, ph)
		# a arma fica na mão direita (a animação de rastejar mexe os braços; a arma vai junto)
		if gun and armed and heal_t <= 0.0 and sol.b.has("RightHand"):
			var hand: Vector3 = sol.sk.global_transform * sol.sk.get_bone_global_pose(sol.b["RightHand"]).origin
			var grip := gun.position + Vector3(0, -0.05, 0.03)
			aim.global_position = hand - aim.global_transform.basis * grip
		return
	# animações do Mixamo: parado (com e sem arma), andar, correr, correr rápido, pular, saltar janela.
	# O ritmo acompanha a velocidade do jogo (o pé quase não desliza), com limite pra não ficar frenético.
	var ual := sol.has_anim("Sprint")
	var mix := sol.has_anim("RifleIdle")
	var crouch_anim := sol.has_anim("CrouchIdle")
	if hp < _last_hp - 0.5:
		_hit_t = 0.35
	_last_hp = hp
	_hit_t = maxf(_hit_t - delta, 0.0)
	if vault_t >= 0.0 and vault_anim:
		# salto da janela: a animação inteira cabe no tempo do pulo
		if sol.cur != "Vault":
			sol.play("Vault", 0.06, sol.ap.get_animation("Vault").length / (VAULT_TIME * 1.6))
	elif airborne and mix and (not sim or velocity.y > 1.5 or _air_time > 0.2 or _jump_t >= 0.0):
		# pulo: o pulo antigo (pernas menos abertas) uma vez; se ainda estiver caindo, pose de queda
		if _jump_t < 0.0 and (velocity.y > 1.5 or (not sim and not _jump_seen)) and sol.has_anim("JumpSoft"):
			_jump_t = 0.0
		if _jump_t >= 0.0 and _jump_t < JUMP_ANIM_T:
			_jump_t += delta
			sol.play("JumpSoft", 0.08, sol.ap.get_animation("JumpSoft").length / JUMP_ANIM_T)
		else:
			sol.play("Air", 0.25)
		_jump_seen = true
	elif airborne and sp > 2.5 and vault_t < 0.0:
		# pulando correndo: as pernas continuam no passo
		sol.play("Running", 0.15, 0.8)
	elif vault_t >= 0.0 or airborne:
		sol.play("Air", 0.12)
	elif crouch and crouch_anim:
		if sp < 0.35:
			sol.play("CrouchIdle", 0.25)
		else:
			sol.play("CrouchWalk", 0.2, clampf(sp / 1.7, 0.45, 1.4))
	elif sp < 0.35:
		var firing: bool = armed and (ready_t > 0.0 or (is_local and game.hud != null and game.hud.fire_held))
		if mix and _hit_t > 0.0 and not crouch:
			sol.play("Hit", 0.06, 1.2)
		elif mix and firing and not crouch:
			sol.play("Fire", 0.12)
		elif mix and armed:
			sol.play("RifleIdle", 0.3)
		else:
			sol.play("Idle", 0.3)
	elif sp < (1.9 if mix else 2.9) or crouch:
		# andando (mirando, atirando, agachado): com arma anda com o rifle, sem arma com os braços soltos
		var wn := "Walking" if armed or not sol.has_anim("WalkFree") else "WalkFree"
		if mix:
			sol.play(wn, 0.3, clampf(sp / 1.25, 0.6, 1.4) if not crouch else clampf(sp / 1.8, 0.4, 1.0))
		else:
			sol.play("Walking", 0.2, clampf(sp / 1.15, 0.55, 2.3) if not crouch else clampf(sp / 2.4, 0.25, 0.8))
	elif sp < 5.2 or not ual:
		if mix:
			sol.play("Running", 0.25, clampf(sp / 3.6, 0.8, 1.25))
		else:
			sol.play("Running", 0.2, clampf(sp / 3.2, 0.8, 1.7) if ual else clampf(sp / 5.4, 0.62, 1.5))
	else:
		sol.play("Sprint", 0.25, clampf(sp / 5.0, 0.95, 1.3) if mix else clampf(sp / 5.0, 0.9, 1.6))
	if crouch_anim and crouch:
		cr = -1.0     # a própria animação agacha (sem dobrar as pernas por código)
	if heal_t > 0.0:
		# curando: braço esquerdo na frente e a mão direita dá voltas nele (enrolando a faixa)
		_heal_anim += delta
		var mg := model.global_transform
		var ctr := Vector3(-0.08, 1.18, -0.32)
		var ang := _heal_anim * 9.0
		hands = [mg * Vector3(-0.02, 1.2, -0.42), mg * (ctr + Vector3(cos(ang) * 0.07, sin(ang) * 0.07, 0.02))]
		if gun:
			gun.visible = false
	elif armed:
		if gun:
			gun.visible = true
			if _draw_t > 0.0:
				_draw_t = maxf(_draw_t - delta, 0.0)
				var dk := _draw_t / _draw_dur
				var e2 := dk * dk
				if _draw_pistol:
					gun.position = _gun_base + Vector3(0.12, -0.5, 0.32) * e2
					gun.rotation = Vector3(-1.2 * e2, 0, 0)
				else:
					# das costas: sobe por cima do ombro (cano pra cima), desce e dá o tranco no fim
					var rack := sin(clampf(dk / 0.35, 0.0, 1.0) * PI) * (1.0 if dk < 0.35 else 0.0)
					gun.position = _gun_base + Vector3(0.16, 0.3, 0.45) * e2 + Vector3(0, 0, 0.05) * rack
					gun.rotation = Vector3(1.15 * e2 - 0.08 * rack, 0.0, 0.55 * e2)
			else:
				gun.rotation = Vector3.ZERO
				gun.position = _gun_base
			if kick > 0.0:
				kick = maxf(kick - delta * 9.0, 0.0)
				var kk := kick * kick
				gun.position += Vector3(0, 0.015, 0.07) * kk
				gun.rotation.x += 0.16 * kk
		var gp := gun.position if gun else Vector3(0.12, -0.02, -0.36)
		var t: String = Weapons.get_w(shown_wid)["type"]
		# o pulso fica atrás/abaixo do cabo (a palma é que abraça o cabo)
		var grip := aim.global_transform * (gp + (Vector3(0.0, -0.075, 0.085) if t == "pistol" else Vector3(0, -0.07, 0.07)))
		var fore := aim.global_transform * (gp + (Vector3(-0.045, -0.09, 0.07) if t == "pistol" else Vector3(-0.02, -0.06, -0.2)))
		if reload_t > 0.0:
			# recarga: inclina a arma, mão esquerda tira o pente, vai na cintura e volta
			var tot := maxf(float(cur_stat()["reload"]), 0.3)
			var k2 := clampf(1.0 - reload_t / tot, 0.0, 1.0)
			aim.rotation.z = lerpf(aim.rotation.z, 0.45, minf(1.0, 10.0 * delta))
			aim.rotation.x -= 0.25
			var mag_p := aim.global_transform * (gp + Vector3(0, -0.13, -0.14 if t != "pistol" else 0.0))
			var belt := model.global_transform * Vector3(-0.18, 1.0, -0.08)
			if k2 < 0.3:
				fore = fore.lerp(mag_p, k2 / 0.3)
			elif k2 < 0.6:
				fore = mag_p.lerp(belt, sin((k2 - 0.3) / 0.3 * PI * 0.5))
			elif k2 < 0.9:
				fore = belt.lerp(mag_p, (k2 - 0.6) / 0.3)
			else:
				fore = mag_p.lerp(fore, (k2 - 0.9) / 0.1)
		else:
			aim.rotation.z = lerpf(aim.rotation.z, 0.0, minf(1.0, 10.0 * delta))
		hands = [fore, grip]
		# pulsos acompanham a arma (dedos pra frente/baixo na empunhadura; mão de apoio por baixo)
		var ab := aim.global_transform.basis
		var gf := -ab.z.normalized()
		var gu := ab.y.normalized()
		var gr := ab.x.normalized()
		if t == "pistol":
			hand_dirs = [(gf - gu * 0.55 + gr * 0.35).normalized(), (gf - gu * 0.6).normalized()]
			pole_k = 1.0
		else:
			hand_dirs = [(gf * 0.6 + gr * 0.55 - gu * 0.35).normalized(), (gf - gu * 0.7).normalized()]
			pole_k = 0.35
	elif sol.cur == "Idle" and vault_t < 0.0 and not ual and not mix:
		# parado de mãos livres: braços soltos do lado do corpo, respirando
		_breath += delta
		var br := sin(_breath * 1.8) * 0.008
		hands = [model.global_transform * Vector3(-0.27, 0.86 + br, 0.02), model.global_transform * Vector3(0.27, 0.86 + br, 0.02)]
	if punch_t > 0.0 and not armed:
		var pk := sin(clampf(punch_t / 0.3, 0.0, 1.0) * PI)
		hands = [model.global_transform * Vector3(-0.2, 1.3, -0.25), aim.global_transform * Vector3(0.12, 0.0, -0.2 - pk * 0.4)]
	if vk > 0.0:
		# mão de apoio no batente
		hands = [model.global_transform * Vector3(-0.25, 0.95, -0.45), hands[1] if hands.size() == 2 else model.global_transform * Vector3(0.25, 0.95, -0.4)]
	# granada sem pino: braço de apoio aponta pra frente e a mão da granada fica atrás da cabeça
	_gren_k = move_toward(_gren_k, 1.0 if (gren_hold and car < 0 and heal_t <= 0.0) else 0.0, delta * 7.0)
	if _gren_k > 0.0:
		var mg2 := model.global_transform
		var e3 := _gren_k * _gren_k * (3.0 - 2.0 * _gren_k)
		var hl := mg2 * Vector3(-0.2, 1.36, -0.36)
		var hr := mg2 * Vector3(0.24, 1.6 + sin(Time.get_ticks_msec() * 0.004) * 0.01, 0.2)
		if hands.size() == 2:
			hands = [(hands[0] as Vector3).lerp(hl, e3), (hands[1] as Vector3).lerp(hr, e3)]
		else:
			hands = [hl, hr]
		if gun:
			gun.visible = gun.visible and _gren_k < 0.5
		if _gren_mi == null:
			_gren_mi = MeshInstance3D.new()
			_gren_mi.mesh = Weapons.item_mesh("grenade")
			_gren_mi.material_override = U.wmat()
			_gren_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(_gren_mi)
		_gren_mi.visible = _gren_k > 0.5
		_gren_mi.global_position = hr + mg2.basis.z * 0.02 - mg2.basis.y * 0.02
	elif _gren_mi:
		_gren_mi.visible = false
	if hands.size() != 2 or reload_t > 0.0 or heal_t > 0.0 or punch_t > 0.0 or vk > 0.0 or _gren_k > 0.0:
		hand_dirs = []
	sol.tick(delta, far, pitch * (1.0 - _gun_low) if armed else 0.0, maxf(0.0 if cr < 0.0 else _crouch_k, 0.85 * vk), hands, hand_dirs, pole_k)
	# pistola: o cabo fica na palma da mão (a mão já está virada como quem empunha); assim a arma nunca
	# fica solta na frente da mão, seja qual for o tamanho da pistola
	if armed and gun and gun.visible and not far and _gren_k <= 0.0 and heal_t <= 0.0 and reload_t <= 0.0 and sol.b.has("RightHandMiddle1") and shown_wid != "" and shown_wid != "fist":
		var wrist: Vector3 = sol.sk.global_transform * sol.sk.get_bone_global_pose(sol.b["RightHand"]).origin
		var knuckle: Vector3 = sol.sk.global_transform * sol.sk.get_bone_global_pose(sol.b["RightHandMiddle1"]).origin
		var palm := wrist.lerp(knuckle, 0.55)
		var pist: bool = Weapons.get_w(shown_wid)["type"] == "pistol"
		var want_p := aim.global_transform.affine_inverse() * palm - (_pistol_handle(shown_wid) if pist else Vector3(0.0, -0.035, 0.02))
		# fuzil: só corrige o que falta (a mão de apoio continua no guarda-mão)
		gun.position = want_p if pist else gun.position.lerp(want_p, 0.85)





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
	if game.phase == game.LOBBY and not game.sandbox:
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
		if b_cover == Vector3.INF or b_peek or b_cover.distance_to(position) > 1.0:
			heal_t = 0.0   # só se cura no meio da briga escondido atrás da cobertura
		b_exit.clear()
		if sel < 0 or cur_wid() == "fist" or not _has_ammo(cur_wid()):
			_bot_best_gun()
		var from := position + Vector3(0, head_y(), 0)
		# mira no peito, às vezes na cabeça
		var aimp := t.position + Vector3(0, t.head_y() - (0.05 if randf() < 0.18 * b_skill else 0.45), 0)
		var d := aimp - from
		var wy := atan2(-d.x, -d.z)
		var wp := atan2(d.y, Vector2(d.x, d.z).length())
		yaw = lerp_angle(yaw, wy, minf(1.0, 7.0 * b_skill * delta))
		pitch = lerpf(pitch, wp, minf(1.0, 7.0 * delta))
		b_strafe_t -= delta
		if b_strafe_t <= 0.0:
			b_strafe = [-1.0, -1.0, 0.0, 1.0, 1.0].pick_random()
			b_strafe_t = randf_range(0.5, 1.4)
			if b_cover == Vector3.INF:
				set_crouch(randf() < 0.2 and hp > 80.0)
				# pula de vez em quando pra atrapalhar a mira
				if randf() < 0.12 * b_skill:
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
		# briga de média/longa distância: procura algo pra se esconder atrás (caixote, muro, carro, árvore)
		var can_fire := true
		b_cover_t -= delta
		if w["type"] != "fist" and w["type"] != "shotgun" and dist > 9.0 and not out_zone:
			if b_cover_t <= 0.0:
				b_cover_t = randf_range(2.5, 4.0)
				if b_cover == Vector3.INF or b_cover.distance_to(position) > 12.0 or not _bot_covered(b_cover, t):
					b_cover = _bot_find_cover(t)
			if b_cover != Vector3.INF:
				var tc := b_cover - position
				if Vector2(tc.x, tc.z).length() > 0.7:
					# corre pra cobertura olhando pro inimigo
					mv = _world_to_local(Vector3(tc.x, 0, tc.z).normalized())
					set_crouch(false)
				else:
					# atrás da cobertura: abaixa (recarrega/se cura escondido) e levanta pra atirar
					mv = Vector2.ZERO
					b_peek_t -= delta
					if b_peek_t <= 0.0:
						b_peek = not b_peek
						b_peek_t = randf_range(1.2, 2.2) if b_peek else randf_range(0.9, 1.7)
					var low_hp := hp < 110.0
					if reload_t > 0.0 or low_hp and not b_peek:
						b_peek = false
					set_crouch(not b_peek)
					can_fire = b_peek
					b_hold = 3.0
					if not b_peek and hp < 120.0 and heal_t <= 0.0:
						_bot_try_heal(false)
		else:
			b_cover = Vector3.INF
		# fora da zona: briga andando pra dentro dela
		if out_zone:
			var to := (zc - me).normalized()
			mv = _world_to_local(Vector3(to.x, 0, to.y))
		b_react -= delta
		if can_fire and b_react <= 0.0 and absf(angle_difference(yaw, wy)) < 0.12 and dist < float(w["range"]):
			_bot_fire(from, aimp, w)
	else:
		b_react = randf_range(0.45, 0.9)
		b_cover = Vector3.INF
		set_crouch(false)
		set_prone(false)
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


# ponto protegido: algo baixo entre o ponto e o alvo, perto do ponto (agachado não leva tiro)
func _bot_covered(p: Vector3, t: Player) -> bool:
	var space := get_world_3d().direct_space_state
	var tp := t.position + Vector3(0, 1.2, 0)
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.75, 0), tp, 1, [get_rid(), t.get_rid()])
	var r := space.intersect_ray(q)
	return not r.is_empty() and (r["position"] as Vector3).distance_to(p) < 3.0


# procura cobertura em volta (de lado/pra trás em relação ao alvo), a mais perto que sirva
func _bot_find_cover(t: Player) -> Vector3:
	var space := get_world_3d().direct_space_state
	var to_t := Vector3(t.position.x - position.x, 0, t.position.z - position.z).normalized()
	var best := Vector3.INF
	var bd := 99.0
	for k in 12:
		var a := TAU * k / 12.0 + randf() * 0.3
		var dir := Vector3(sin(a), 0, cos(a))
		# não corre pra cima do inimigo
		if dir.dot(to_t) > 0.5:
			continue
		var r := randf_range(2.5, 8.0)
		var p := position + dir * r
		var dq := PhysicsRayQueryParameters3D.create(p + Vector3(0, 3.0, 0), p + Vector3(0, -4.0, 0), 1, [get_rid()])
		var dr := space.intersect_ray(dq)
		if dr.is_empty():
			continue
		p = dr["position"]
		if absf(p.y - position.y) > 1.2:
			continue
		# dá pra chegar (nada no caminho) e dá pra ficar em pé lá
		var wq := PhysicsRayQueryParameters3D.create(position + Vector3(0, 0.9, 0), p + Vector3(0, 0.9, 0), 1, [get_rid()])
		if not space.intersect_ray(wq).is_empty():
			continue
		if not _bot_covered(p, t):
			continue
		# levantando tem que enxergar o alvo (senão não dá pra atirar dali)
		var hq := PhysicsRayQueryParameters3D.create(p + Vector3(0, 1.6, 0), t.position + Vector3(0, 1.3, 0), 1, [get_rid(), t.get_rid()])
		var peek_ok := space.intersect_ray(hq).is_empty()
		var sc := r + (0.0 if peek_ok else 6.0)
		if sc < bd:
			bd = sc
			best = p
	return best


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
	if hp < 150.0 and count("med") > 0:
		heal_kind = "med"
	elif hp < 160.0 and count("drink") > 0:
		heal_kind = "drink"
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
			return count("med") < 3 and free_slots() >= int(Weapons.ITEMS["med"]["w"])
		"drink":
			return count("drink") < 5 and free_slots() > 0
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


# 0 = começo (cheio de gente) .. 1 = fim (pouca gente): o quanto o bot procura briga
func bot_aggro() -> float:
	var alive: int = game.alive_cached
	return clampf(1.0 - (float(alive) - 10.0) / 28.0, 0.25, 1.0)


func _bot_pick_target() -> void:
	var zn: Array = game.zone_now()
	var far_out: bool = Vector2(position.x, position.z).distance_to(zn[0]) > float(zn[1]) + 10.0
	var best := 0
	# começo da partida (muita gente viva): bot foca em lootear e só briga de perto;
	# com pouca gente o bot fica agressivo (sobra mais gente pro final)
	var agg := bot_aggro()
	var bd := lerpf(18.0, 75.0, agg)
	if float(cur_stat()["range"]) > 150.0:
		bd = lerpf(30.0, 120.0, agg)
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
		# no começo bot quase não caça outro bot (só se estiver colado)
		if o.is_bot and agg < 0.65 and dd > lerpf(7.0, 24.0, agg / 0.65):
			continue
		# agachado em moita fica mais difícil de ver de longe
		if o.crouch and dd > 35.0:
			continue
		var q := PhysicsRayQueryParameters3D.create(from, o.position + Vector3(0, o.head_y() - 0.1, 0), 1)
		if space.intersect_ray(q).is_empty():
			best = id
			bd = dd
	# escondido atrás da cobertura não vê o alvo, mas lembra dele por um tempo
	b_hold = maxf(b_hold - 0.25, 0.0)
	if best == 0 and b_hold > 0.0 and game.players.has(b_target):
		var ot: Player = game.players[b_target]
		if ot.alive and ot.air == 0 and ot.position.distance_to(position) < 90.0:
			best = b_target
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
	cool = 1.0 / float(w["rate"]) * 1.3
	var base := (aimp - from).normalized()
	var right := base.cross(Vector3.UP).normalized()
	var up := right.cross(base)
	# erra um pouco mais (e mais ainda de longe e com o alvo correndo)
	var far_k := clampf(from.distance_to(aimp) / 60.0, 0.0, 1.0)
	# no começo erram bem mais (menos mortes cedo); no fim mira normal
	var early := 1.0 + (1.0 - bot_aggro()) * 1.5
	var s := tan(deg_to_rad(float(w["spread"]) * 0.85 + (2.9 + 1.6 * far_k) / b_skill * early))
	var dirs := []
	for i in int(w["pellets"]):
		var a := randf() * TAU
		var r := sqrt(randf()) * s
		dirs.append((base + right * cos(a) * r + up * sin(a) * r).normalized())
	game.server_bot_shot(pid, from, dirs, wid)
	if mag[wid] <= 0 and count(Weapons.ammo_of(wid)) > 0:
		reload_t = w["reload"]
