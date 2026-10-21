extends Node3D

# Controla menu, partida, câmera, efeitos e toda a lógica do servidor.
# Quem decide dano, morte, renascimento e armas no chão é sempre o servidor.

const PORT := 7777
const COLORS := [
	Color(0.8, 0.2, 0.2), Color(0.2, 0.45, 0.85), Color(0.95, 0.75, 0.15), Color(0.2, 0.65, 0.3),
	Color(0.6, 0.3, 0.75), Color(0.95, 0.5, 0.15), Color(0.15, 0.7, 0.7), Color(0.9, 0.9, 0.9),
	Color(0.35, 0.35, 0.35), Color(0.85, 0.4, 0.6),
]
const BOT_NAMES := ["Zé", "Tonho", "Bigode", "Chico", "Juca", "Lelo", "Dudu", "Pedrão", "Tião", "Neno"]
const CFG_PATH := "user://config.cfg"

static var flash_msg := ""

var world: World
var hud: Hud
var players := {}
var info := {}
var items_avail := []
var item_nodes := []
var local_id := 0
var dedicated := false
var in_game := false
var rng := RandomNumberGenerator.new()
var players_root: Node3D

var cam_yaw: Node3D
var cam_pitch: Node3D
var spring: SpringArm3D
var cam: Camera3D

var menu: CanvasLayer
var status_lbl: Label
var nick_edit: LineEdit
var ip_edit: LineEdit

var snap_t := 0.0
var send_t := 0.0
var ui_t := 0.0
var respawn_q := {}
var item_q := {}
var last_fire := {}
var sounds := {}
var near_item := -1
var test_fire := false
var quit_after := 0.0
var shot_path := ""
var test_town := -1


func _ready() -> void:
	rng.randomize()
	players_root = Node3D.new()
	players_root.name = "Players"
	add_child(players_root)
	var args := OS.get_cmdline_user_args()
	var bots := 4
	for a in args:
		if a.begins_with("--bots="):
			bots = int(a.get_slice("=", 1))
		elif a.begins_with("--quit-after="):
			quit_after = float(a.get_slice("=", 1))
		elif a == "--test-fire":
			test_fire = true
		elif a.begins_with("--town="):
			test_town = int(a.get_slice("=", 1))
		elif a.begins_with("--shot="):
			shot_path = a.get_slice("=", 1)
	if "--server" in args:
		start_dedicated(bots)
		return
	_make_sounds()
	_build_menu()
	for a in args:
		if a.begins_with("--autojoin="):
			start_join(a.get_slice("=", 1))
		elif a == "--autotrain":
			start_host(false, 5)


# ---------------- menu ----------------

func _build_menu() -> void:
	menu = CanvasLayer.new()
	add_child(menu)
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.16, 0.11)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(bg)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(cc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	cc.add_child(vb)
	var title := _menu_label("CONFRONTO", 60)
	vb.add_child(title)
	nick_edit = _menu_edit("Seu apelido")
	vb.add_child(nick_edit)
	ip_edit = _menu_edit("IP do servidor (ex: 192.168.0.10)")
	vb.add_child(ip_edit)
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) == OK:
		nick_edit.text = cfg.get_value("jogo", "nick", "")
		ip_edit.text = cfg.get_value("jogo", "ip", "")
	if nick_edit.text == "":
		nick_edit.text = "Jogador%d" % rng.randi_range(100, 999)
	vb.add_child(_menu_btn("TREINAR CONTRA BOTS", func(): start_host(false, 6)))
	vb.add_child(_menu_btn("CRIAR SALA NO WI-FI", func(): start_host(true, 0)))
	vb.add_child(_menu_btn("ENTRAR NA SALA", func(): start_join(ip_edit.text.strip_edges())))
	status_lbl = _menu_label(flash_msg, 20)
	status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	status_lbl.custom_minimum_size = Vector2(440, 50)
	vb.add_child(status_lbl)
	flash_msg = ""


func _menu_label(t: String, fs: int) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", fs)
	return l


func _menu_edit(ph: String) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = ph
	e.custom_minimum_size = Vector2(440, 54)
	e.add_theme_font_size_override("font_size", 22)
	return e


func _menu_btn(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(440, 60)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(cb)
	return b


func _nick() -> String:
	var n := nick_edit.text.strip_edges().left(16) if nick_edit else ""
	return n if n != "" else "Jogador"


func _save_cfg() -> void:
	if nick_edit == null:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("jogo", "nick", nick_edit.text.strip_edges())
	cfg.set_value("jogo", "ip", ip_edit.text.strip_edges())
	cfg.save(CFG_PATH)


# ---------------- iniciar ----------------

func start_dedicated(bots: int) -> void:
	dedicated = true
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, 32)
	if err != OK:
		printerr("[servidor] não abriu a porta %d (erro %d)" % [PORT, err])
		get_tree().quit(1)
		return
	multiplayer.multiplayer_peer = peer
	_build_world()
	_server_init(bots)
	in_game = true
	print("[servidor] rodando na porta %d com %d bots" % [PORT, bots])


func start_host(online: bool, bots: int) -> void:
	_save_cfg()
	if online:
		var peer := ENetMultiplayerPeer.new()
		var err := peer.create_server(PORT, 16)
		if err != OK:
			status_lbl.text = "Não deu pra criar a sala (erro %d)." % err
			return
		multiplayer.multiplayer_peer = peer
	else:
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	local_id = multiplayer.get_unique_id()
	_build_world()
	_enter_game()
	_server_init(bots)
	_server_add_player(local_id, _nick(), false)
	if online:
		hud.center("Sala criada! Quem estiver no mesmo Wi-Fi entra com o IP:\n" + _lan_ip(), 12.0)


func start_join(addr: String) -> void:
	if addr == "":
		status_lbl.text = "Digite o IP do servidor."
		return
	_save_cfg()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(addr, PORT)
	if err != OK:
		status_lbl.text = "Endereço inválido (erro %d)." % err
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_fail)
	multiplayer.server_disconnected.connect(_on_server_lost)
	status_lbl.text = "Conectando em %s..." % addr


func _on_connected() -> void:
	local_id = multiplayer.get_unique_id()
	_build_world()
	_enter_game()
	rpc_id(1, "req_join", _nick())


func _on_fail() -> void:
	_back_to_menu("Não conectou. Confere o IP e se o servidor está ligado.")


func _on_server_lost() -> void:
	_back_to_menu("A conexão com o servidor caiu.")


func _back_to_menu(msg: String) -> void:
	flash_msg = msg
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	get_tree().call_deferred("reload_current_scene")


func _build_world() -> void:
	world = World.new()
	world.name = "World"
	add_child(world)
	world.build(dedicated)
	items_avail = []
	for i in world.items.size():
		items_avail.append(true)
	if not dedicated:
		for it in world.items:
			var n := Node3D.new()
			n.position = it["pos"]
			var m := Weapons.build_model(it["wid"])
			m.scale = Vector3(1.4, 1.4, 1.4)
			n.add_child(m)
			add_child(n)
			item_nodes.append(n)


func _enter_game() -> void:
	if menu:
		menu.queue_free()
		menu = null
	hud = Hud.new()
	add_child(hud)
	hud.action.connect(_on_action)
	cam_yaw = Node3D.new()
	add_child(cam_yaw)
	cam_pitch = Node3D.new()
	cam_yaw.add_child(cam_pitch)
	spring = SpringArm3D.new()
	spring.spring_length = 3.2
	spring.position = Vector3(0.6, 0.1, 0)
	spring.collision_mask = 1
	spring.margin = 0.2
	var sh := SphereShape3D.new()
	sh.radius = 0.2
	spring.shape = sh
	cam_pitch.add_child(spring)
	cam = Camera3D.new()
	cam.fov = 75.0
	cam.far = 400.0
	spring.add_child(cam)
	cam.current = true
	cam_yaw.position = Vector3(0, 20, 0)
	in_game = true


func _lan_ip() -> String:
	for a in IP.get_local_addresses():
		if a.begins_with("192.168.") or a.begins_with("10.") or a.begins_with("172."):
			return a
	return "(não achei o IP, veja nas config. do Wi-Fi)"


# ---------------- loop ----------------

func _process(delta: float) -> void:
	if quit_after > 0.0:
		quit_after -= delta
		if quit_after <= 0.0:
			_print_debug_state()
			if shot_path != "":
				get_viewport().get_texture().get_image().save_png(shot_path)
			get_tree().quit()
	if not in_game:
		return
	if multiplayer.is_server():
		_server_tick(delta)
	if dedicated:
		return
	for n in item_nodes:
		if n.visible:
			n.rotate_y(delta * 1.6)
	var lp: Player = players.get(local_id)
	if lp == null:
		return
	if test_town >= 0:
		var c: Vector2 = world.towns[test_town]["pos"]
		var p := Vector2(c.x + 30, c.y + 12)
		lp.position = Vector3(p.x, world.height(p.x, p.y) + 0.2, p.y)
		lp.yaw = atan2(-(c.x - p.x), -(c.y - p.y))
		lp.pitch = -0.05
		lp.hp = 100.0
	_local_update(lp, delta)


func _print_debug_state() -> void:
	var parts := PackedStringArray()
	for id in info:
		var p: Player = players.get(id)
		parts.append("%s k%d d%d hp%d %s" % [info[id]["name"], info[id]["kills"], info[id]["deaths"], p.hp if p else -1, p.position.snapped(Vector3(0.1, 0.1, 0.1)) if p else ""])
	print("[estado] jogadores=%d itens_livres=%d | %s" % [players.size(), items_avail.count(true), " ; ".join(parts)])


func _local_update(lp: Player, delta: float) -> void:
	var wid := lp.cur_wid()
	var w := Weapons.get_w(wid)
	var zoom: float = float(w["zoom"]) if lp.scoped else 1.0
	var look := hud.take_look()
	var sens := 0.0055 / zoom
	if lp.alive:
		lp.yaw -= look.x * sens
		lp.pitch = clampf(lp.pitch - look.y * sens, -1.3, 1.25)
		lp.move_in = hud.move_vec
		if hud.fire_held or test_fire:
			_local_fire(lp)
	else:
		lp.move_in = Vector2.ZERO
	cam_yaw.position = lp.position + Vector3(0, 1.55, 0)
	cam_yaw.rotation.y = lp.yaw
	cam_pitch.rotation.x = lp.pitch
	var target_len := 3.2
	var fov := 75.0
	if lp.scoped:
		target_len = 0.9
		fov = 75.0 / zoom
	if not lp.alive:
		target_len = 5.0
	spring.spring_length = lerpf(spring.spring_length, target_len, minf(1.0, 12.0 * delta))
	cam.fov = lerpf(cam.fov, fov, minf(1.0, 12.0 * delta))
	# manda posição pro servidor 20x por segundo
	send_t += delta
	if send_t >= 0.05 and not multiplayer.is_server():
		send_t = 0.0
		rpc_id(1, "st", lp.position, lp.yaw, lp.pitch, wid)
	ui_t += delta
	if ui_t > 0.2:
		ui_t = 0.0
		near_item = -1
		if lp.alive:
			var bd := 2.6
			for i in world.items.size():
				if not items_avail[i] or world.items[i]["wid"] == lp.primary:
					continue
				var dd := lp.position.distance_to(world.items[i]["pos"])
				if dd < bd:
					bd = dd
					near_item = i
		hud.set_pickup(Weapons.get_w(world.items[near_item]["wid"])["name"] if near_item >= 0 else "")
		hud.set_score(_score_text())
	hud.set_status(lp.hp, w["name"], lp.mag[wid], w["mag"], lp.reload_t > 0.0, lp.scoped and wid == "awm")


func _score_text() -> String:
	var ids := info.keys()
	ids.sort_custom(func(a, b): return info[a]["kills"] > info[b]["kills"])
	var parts := PackedStringArray()
	for k in mini(3, ids.size()):
		parts.append("%dº %s %d" % [k + 1, info[ids[k]]["name"], info[ids[k]]["kills"]])
	var me = info.get(local_id)
	var mine := "" if me == null else "     Você: %d abates / %d mortes" % [me["kills"], me["deaths"]]
	return "   ".join(parts) + mine


func _on_action(act: String) -> void:
	if act == "exit":
		_back_to_menu("")
		return
	var lp: Player = players.get(local_id)
	if lp == null or not lp.alive:
		return
	var w := Weapons.get_w(lp.cur_wid())
	match act:
		"jump":
			lp.want_jump = true
		"reload":
			_start_reload(lp)
		"switch":
			if lp.primary != "":
				lp.slot = 1 - lp.slot
				lp.reload_t = 0.0
				lp.scoped = false
				lp.update_gun()
		"scope":
			if float(w["zoom"]) > 1.0:
				lp.scoped = not lp.scoped
		"pickup":
			if near_item >= 0:
				_to_server("req_pickup", [near_item])


func _start_reload(lp: Player) -> void:
	var wid := lp.cur_wid()
	var w := Weapons.get_w(wid)
	if lp.reload_t <= 0.0 and lp.mag[wid] < int(w["mag"]):
		lp.reload_t = w["reload"]
		lp.scoped = false


func _local_fire(lp: Player) -> void:
	if lp.cool > 0.0 or lp.reload_t > 0.0:
		return
	var wid := lp.cur_wid()
	var w := Weapons.get_w(wid)
	if lp.mag[wid] <= 0:
		_start_reload(lp)
		return
	lp.mag[wid] -= 1
	lp.cool = 1.0 / float(w["rate"])
	var xf := cam.global_transform
	var fwd := -xf.basis.z
	var right := xf.basis.x
	var up := xf.basis.y
	var head := lp.position + Vector3(0, 1.5, 0)
	var origin := xf.origin + fwd * maxf(0.0, (head - xf.origin).dot(fwd))
	var spread: float = w["spread"]
	if lp.scoped:
		spread *= 0.0 if wid == "awm" else 0.4
	if Vector2(lp.velocity.x, lp.velocity.z).length() > 1.0:
		spread *= 1.4
	if not lp.is_on_floor():
		spread *= 2.0
	var s := tan(deg_to_rad(spread))
	var space := get_world_3d().direct_space_state
	var ends := PackedVector3Array()
	var hits := []
	for i in int(w["pellets"]):
		var a := randf() * TAU
		var r := sqrt(randf()) * s
		var d := (fwd + right * cos(a) * r + up * sin(a) * r).normalized()
		var to := origin + d * float(w["range"])
		var q := PhysicsRayQueryParameters3D.create(origin, to, 3, [lp.get_rid()])
		var res := space.intersect_ray(q)
		if res.is_empty():
			ends.append(to)
			hits.append(-1)
			continue
		ends.append(res["position"])
		var col = res["collider"]
		if col is Player and col.alive:
			hits.append([col.pid, (res["position"].y - col.position.y) > 1.5])
		else:
			hits.append(-1)
	_to_server("req_fire", [origin, ends, hits, wid])
	_shot_fx(lp, ends, wid, true)
	lp.pitch = minf(lp.pitch + float(w["recoil"]), 1.25)
	if lp.mag[wid] <= 0:
		_start_reload(lp)


# ---------------- efeitos ----------------

func _make_sounds() -> void:
	sounds["pistol"] = _gen_shot(0.18, 28.0, 0.5)
	sounds["auto"] = _gen_shot(0.22, 22.0, 0.35)
	sounds["heavy"] = _gen_shot(0.45, 11.0, 0.22)


func _gen_shot(dur: float, decay: float, smooth: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(dur * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	var v := 0.0
	for i in n:
		var t := float(i) / rate
		v = lerpf(v, randf() * 2.0 - 1.0, smooth)
		var env := exp(-t * decay)
		if t < 0.003:
			env *= t / 0.003
		data.encode_s16(i * 2, clampi(int(v * env * 30000.0), -32768, 32767))
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = rate
	st.stereo = false
	st.data = data
	return st


func _play_shot(wid: String, pos: Vector3, local: bool) -> void:
	var t: String = Weapons.get_w(wid)["type"]
	var key := "auto"
	var pt := 1.0
	match t:
		"pistol":
			key = "pistol"
			pt = 1.1
		"smg":
			key = "pistol"
			pt = 0.95
		"ak":
			pt = 0.85
		"shotgun":
			key = "heavy"
			pt = 1.15
		"sniper":
			key = "heavy"
			pt = 0.8
	if local:
		var ap := AudioStreamPlayer.new()
		ap.stream = sounds[key]
		ap.pitch_scale = pt * randf_range(0.95, 1.05)
		ap.volume_db = -4.0
		add_child(ap)
		ap.play()
		ap.finished.connect(ap.queue_free)
	else:
		var ap3 := AudioStreamPlayer3D.new()
		ap3.stream = sounds[key]
		ap3.pitch_scale = pt * randf_range(0.95, 1.05)
		ap3.unit_size = 12.0
		ap3.max_distance = 250.0
		add_child(ap3)
		ap3.global_position = pos + Vector3(0, 1.5, 0)
		ap3.play()
		ap3.finished.connect(ap3.queue_free)


func _shot_fx(p: Player, ends: PackedVector3Array, wid: String, local: bool) -> void:
	if dedicated:
		return
	var from := p.muzzle_pos()
	for e in ends:
		_tracer(from, e)
		_temp_box(e, 0.14, Color(0.6, 0.55, 0.45), 0.3)
	_temp_box(from, 0.12, Color(1.0, 0.85, 0.3), 0.04, true)
	_play_shot(wid, p.position, local)


func _tracer(a: Vector3, b: Vector3) -> void:
	var length := a.distance_to(b)
	if length < 0.5:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = U.box_mesh(Vector3(0.025, 0.025, 1.0))
	mi.material_override = U.mat(Color(1.0, 0.85, 0.4), true)
	add_child(mi)
	var dir := (b - a) / length
	var up := Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT
	mi.global_transform = Transform3D(Basis.looking_at(dir, up) * Basis.from_scale(Vector3(1, 1, length)), (a + b) / 2.0)
	get_tree().create_timer(0.05).timeout.connect(mi.queue_free)


func _temp_box(pos: Vector3, size: float, col: Color, life: float, unshaded := false) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = U.box_mesh(Vector3(size, size, size))
	mi.material_override = U.mat(col, unshaded)
	add_child(mi)
	mi.global_position = pos
	get_tree().create_timer(life).timeout.connect(mi.queue_free)


# ---------------- rede: utilitários ----------------

func _sender() -> int:
	var s := multiplayer.get_remote_sender_id()
	return s if s != 0 else multiplayer.get_unique_id()


func _to_server(method: String, args: Array) -> void:
	if multiplayer.is_server():
		callv(method, args)
	else:
		callv("rpc_id", [1, method] + args)


# Executa aqui (servidor) e manda pra todos os clientes.
func _all(method: String, args: Array) -> void:
	callv(method, args)
	if multiplayer.get_peers().size() > 0:
		callv("rpc", [method] + args)


# ---------------- servidor ----------------

func _server_init(bots: int) -> void:
	multiplayer.peer_disconnected.connect(_on_peer_left)
	for i in bots:
		_server_add_player(1000 + i, "Bot " + BOT_NAMES[i % BOT_NAMES.size()], true)


func _server_add_player(id: int, nick: String, bot: bool) -> void:
	var col: Color = COLORS[info.size() % COLORS.size()]
	var pos := world.random_spawn(rng)
	if not bot and id != local_id:
		rpc_id(id, "welcome", _snapshot(), items_avail)
	_all("add_player", [id, nick, col, pos, bot])
	if bot:
		_all("on_primary", [id, Weapons.BOT_GUNS.pick_random()])
	if dedicated:
		print("[servidor] entrou: %s (%d)" % [nick, id])


func _snapshot() -> Array:
	var arr := []
	for id in players:
		var p: Player = players[id]
		arr.append({
			"id": id, "name": info[id]["name"], "color": info[id]["color"], "bot": info[id]["bot"],
			"kills": info[id]["kills"], "deaths": info[id]["deaths"],
			"pos": p.position, "alive": p.alive, "hp": p.hp, "primary": p.primary,
		})
	return arr


func _on_peer_left(id: int) -> void:
	respawn_q.erase(id)
	last_fire.erase(id)
	if players.has(id):
		_all("remove_player", [id])


func _server_tick(delta: float) -> void:
	for id in respawn_q.keys():
		respawn_q[id] -= delta
		if respawn_q[id] <= 0.0:
			respawn_q.erase(id)
			if players.has(id):
				_all("on_respawn", [id, world.random_spawn(rng)])
				if players[id].is_bot:
					_all("on_primary", [id, Weapons.BOT_GUNS.pick_random()])
	for i in item_q.keys():
		item_q[i] -= delta
		if item_q[i] <= 0.0:
			item_q.erase(i)
			_all("on_item", [i, true])
	snap_t += delta
	if snap_t >= 0.05:
		snap_t = 0.0
		if multiplayer.get_peers().size() > 0:
			var arr := []
			for id in players:
				var p: Player = players[id]
				arr.append([id, p.position, p.yaw, p.pitch, p.shown_wid])
			rpc("snap", arr)


func server_bot_shot(id: int, origin: Vector3, dirs: Array, wid: String) -> void:
	var p: Player = players.get(id)
	if p == null or not p.alive:
		return
	var w := Weapons.get_w(wid)
	var space := get_world_3d().direct_space_state
	var ends := PackedVector3Array()
	var dmg := {}
	for d in dirs:
		var to: Vector3 = origin + d * float(w["range"])
		var q := PhysicsRayQueryParameters3D.create(origin, to, 3, [p.get_rid()])
		var r := space.intersect_ray(q)
		if r.is_empty():
			ends.append(to)
			continue
		ends.append(r["position"])
		var c = r["collider"]
		if c is Player and c.alive:
			_acc(dmg, c.pid, w, (r["position"].y - c.position.y) > 1.5, 0.75)
	_server_apply(id, ends, dmg, wid)


func _acc(dmg: Dictionary, vid: int, w: Dictionary, head: bool, mult := 1.0) -> void:
	var amt: float = float(w["dmg"]) * (float(w["head"]) if head else 1.0) * mult
	if dmg.has(vid):
		dmg[vid][0] += amt
		dmg[vid][1] = dmg[vid][1] or head
	else:
		dmg[vid] = [amt, head]


func _server_apply(id: int, ends: PackedVector3Array, dmg: Dictionary, wid: String) -> void:
	if not dedicated and id != local_id:
		fx_shot(id, ends, wid)
	if multiplayer.get_peers().size() > 0:
		rpc("fx_shot", id, ends, wid)
	for vid in dmg:
		_server_damage(vid, id, dmg[vid][0], dmg[vid][1], wid)


func _server_damage(vid: int, aid: int, amount: float, head: bool, wid: String) -> void:
	var v: Player = players.get(vid)
	if v == null or not v.alive:
		return
	if v.is_bot and aid != vid:
		v.b_target = aid
		v.b_react = minf(v.b_react, 0.3)
	var hp := v.hp - amount
	if hp <= 0.0:
		_all("on_died", [vid, aid, wid, head])
		respawn_q[vid] = 4.0
	else:
		_all("on_hp", [vid, hp, aid, head])


# ---------------- RPCs: cliente -> servidor ----------------

@rpc("any_peer", "call_remote", "reliable")
func req_join(nick: String) -> void:
	if not multiplayer.is_server():
		return
	var id := _sender()
	if players.has(id):
		return
	nick = nick.strip_edges().left(16)
	_server_add_player(id, nick if nick != "" else "Jogador", false)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func st(pos: Vector3, yw: float, pt: float, wid: String) -> void:
	if not multiplayer.is_server():
		return
	var p: Player = players.get(_sender())
	if p == null or not p.alive:
		return
	if wid != "glock" and wid != p.primary:
		wid = "glock"
	p.net_target(pos, yw, pt, wid)


@rpc("any_peer", "call_remote", "reliable")
func req_fire(origin: Vector3, ends: PackedVector3Array, hits: Array, wid: String) -> void:
	if not multiplayer.is_server():
		return
	var id := _sender()
	var p: Player = players.get(id)
	if p == null or not p.alive:
		return
	if wid != "glock" and wid != p.primary:
		return
	var w := Weapons.get_w(wid)
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(last_fire.get(id, -10.0)) < 0.7 / float(w["rate"]):
		return
	last_fire[id] = now
	var head_pos := p.position + Vector3(0, 1.5, 0)
	if origin.distance_to(head_pos) > 6.0:
		origin = head_pos
	var n := mini(mini(ends.size(), hits.size()), int(w["pellets"]))
	var space := get_world_3d().direct_space_state
	var dmg := {}
	for i in n:
		var h = hits[i]
		if not (h is Array) or h.size() < 2:
			continue
		var v: Player = players.get(int(h[0]))
		if v == null or not v.alive or v == p:
			continue
		# confere se o tiro bate com a posição que o servidor conhece (com folga pro lag)
		var dir := (ends[i] - origin).normalized()
		var to_v := (v.position + Vector3(0, 1.0, 0)) - origin
		var along := to_v.dot(dir)
		if along < 0.0 or along > float(w["range"]) + 3.0:
			continue
		if (to_v - dir * along).length() > 3.0:
			continue
		var q := PhysicsRayQueryParameters3D.create(origin, v.position + Vector3(0, 1.4, 0), 1)
		if not space.intersect_ray(q).is_empty():
			var q2 := PhysicsRayQueryParameters3D.create(origin, v.position + Vector3(0, 0.6, 0), 1)
			if not space.intersect_ray(q2).is_empty():
				continue
		_acc(dmg, v.pid, w, bool(h[1]))
	_server_apply(id, ends, dmg, wid)


@rpc("any_peer", "call_remote", "reliable")
func req_pickup(i: int) -> void:
	if not multiplayer.is_server():
		return
	var id := _sender()
	var p: Player = players.get(id)
	if p == null or not p.alive or i < 0 or i >= items_avail.size() or not items_avail[i]:
		return
	if p.position.distance_to(world.items[i]["pos"]) > 4.0:
		return
	item_q[i] = 25.0
	_all("on_item", [i, false])
	_all("on_primary", [id, world.items[i]["wid"]])


# ---------------- RPCs: servidor -> todos ----------------

@rpc("authority", "call_remote", "reliable")
func welcome(list: Array, avail: Array) -> void:
	for e in list:
		add_player(e["id"], e["name"], e["color"], e["pos"], e["bot"])
		info[e["id"]]["kills"] = e["kills"]
		info[e["id"]]["deaths"] = e["deaths"]
		var p: Player = players[e["id"]]
		p.primary = e["primary"]
		p.hp = e["hp"]
		if not e["alive"]:
			p.die()
	for i in mini(avail.size(), items_avail.size()):
		on_item(i, avail[i])


@rpc("authority", "call_remote", "reliable")
func add_player(id: int, nick: String, col: Color, pos: Vector3, bot: bool) -> void:
	if players.has(id):
		return
	info[id] = {"name": nick, "kills": 0, "deaths": 0, "color": col, "bot": bot}
	var p := Player.new()
	p.name = "P%d" % id
	p.setup(self, id, nick, col, id == local_id and not dedicated, bot, not dedicated)
	p.position = pos
	players_root.add_child(p)
	players[id] = p
	if hud and id != local_id:
		hud.feed("%s entrou" % nick)


@rpc("authority", "call_remote", "reliable")
func remove_player(id: int) -> void:
	if players.has(id):
		players[id].queue_free()
		players.erase(id)
	if info.has(id):
		if hud:
			hud.feed("%s saiu" % info[id]["name"])
		info.erase(id)


@rpc("authority", "call_remote", "unreliable_ordered")
func snap(arr: Array) -> void:
	for e in arr:
		var id: int = e[0]
		if id == local_id:
			continue
		var p: Player = players.get(id)
		if p:
			p.net_target(e[1], e[2], e[3], e[4])


@rpc("authority", "call_remote", "unreliable")
func fx_shot(id: int, ends: PackedVector3Array, wid: String) -> void:
	if dedicated or id == local_id:
		return
	var p: Player = players.get(id)
	if p:
		_shot_fx(p, ends, wid, false)


@rpc("authority", "call_remote", "reliable")
func on_hp(vid: int, hp: float, aid: int, head: bool) -> void:
	var v: Player = players.get(vid)
	if v:
		v.hp = hp
	if hud:
		if aid == local_id and vid != local_id:
			hud.hit(head, false)
		if vid == local_id:
			hud.hurt()


@rpc("authority", "call_remote", "reliable")
func on_died(vid: int, aid: int, wid: String, head: bool) -> void:
	var v: Player = players.get(vid)
	if v:
		v.die()
	if info.has(vid):
		info[vid]["deaths"] += 1
	if info.has(aid) and aid != vid:
		info[aid]["kills"] += 1
	if hud:
		var kn: String = info[aid]["name"] if info.has(aid) else "?"
		var vn: String = info[vid]["name"] if info.has(vid) else "?"
		hud.feed("%s  [%s%s]  %s" % [kn, Weapons.get_w(wid)["name"], " · cabeça" if head else "", vn])
		if aid == local_id and vid != local_id:
			hud.hit(head, true)
			hud.center("Você eliminou %s" % vn, 2.0)
		if vid == local_id:
			hud.hurt()
			hud.center("Eliminado por %s\nVoltando em 4 segundos..." % kn, 4.0)


@rpc("authority", "call_remote", "reliable")
func on_respawn(id: int, pos: Vector3) -> void:
	var p: Player = players.get(id)
	if p:
		p.respawn(pos)


@rpc("authority", "call_remote", "reliable")
func on_primary(id: int, wid: String) -> void:
	var p: Player = players.get(id)
	if p == null:
		return
	p.primary = wid
	if wid != "":
		p.mag[wid] = Weapons.get_w(wid)["mag"]
	if id == local_id or p.is_bot:
		p.slot = 0 if wid != "" else 1
		p.reload_t = 0.0
		p.scoped = false
		p.update_gun()


@rpc("authority", "call_remote", "reliable")
func on_item(i: int, avail: bool) -> void:
	if i < 0 or i >= items_avail.size():
		return
	items_avail[i] = avail
	if i < item_nodes.size():
		item_nodes[i].visible = avail
