extends Node3D

# Controla menu, partida battle royale, câmera, efeitos e toda a lógica do servidor.
# Quem decide dano, morte, loot, zona e vencedor é sempre o servidor.

const PORT := 7777
const MAX_PLAYERS := 50
const LOBBY := 0
const PLANE := 1
const MATCH := 2
const END := 3
const PLANE_H := 230.0
const PLANE_SPEED := 24.0
const LOBBY_T := 45.0
# espera, tempo fechando, raio final, dano por segundo
const ZONES := [
	[90.0, 60.0, 300.0, 1.5], [60.0, 45.0, 180.0, 3.0], [50.0, 35.0, 105.0, 5.0], [40.0, 30.0, 60.0, 8.0],
	[30.0, 25.0, 30.0, 11.0], [20.0, 20.0, 12.0, 15.0], [15.0, 15.0, 0.0, 22.0],
]
const ZONE_R0 := 540.0
const BOT_NAMES := ["Zé", "Tonho", "Bigode", "Chico", "Juca", "Lelo", "Dudu", "Pedrão", "Tião", "Neno",
	"Biro", "Cacá", "Dentinho", "Fumaça", "Gordo", "Jacaré", "Kiko", "Mancha", "Nego", "Pitoco",
	"Russo", "Sapo", "Tatu", "Vovô", "Xexéu", "Baiano", "Careca", "Dedé", "Ferrugem", "Gaúcho",
	"Índio", "Jaca", "Lambari", "Magrão", "Nenê", "Paçoca", "Quinzinho", "Rato", "Sabiá", "Tico",
	"Urubu", "Vadinho", "Zóio", "Bolacha", "Cebola", "Formiga", "Gambá", "Mosquito", "Pipoca", "Tanajura"]

static var flash_msg := ""
static var WIDS: Array = Weapons.DATA.keys()

var world: World
var hud: Hud
var sfxn: Sfx
var players := {}
var info := {}
var items_avail := []
var item_nodes := []
var items_root: Node3D
var local_id := 0
var dedicated := false
var in_game := false
var training := false
var rng := RandomNumberGenerator.new()
var players_root: Node3D

var cam_yaw: Node3D
var cam_pitch: Node3D
var spring: SpringArm3D
var cam: Camera3D
var cam_yaw_v := 0.0
var cam_pitch_v := -0.1
var plane_node: Node3D
var zone_wall: MeshInstance3D
var loop_player: AudioStreamPlayer
var loop_kind := ""
var fog_base := 0.0022

var menu: CanvasLayer
var status_lbl: Label
var nick_edit: LineEdit
var ip_edit: LineEdit
var settings: SettingsUI
var edit_hud: Hud

# partida
var phase := LOBBY
var phase_t := 0.0
var plane_a := Vector3.ZERO
var plane_b := Vector3.ZERO
var plane_t := 0.0
var plane_dur := 30.0
var z_stage := -1
var z_c0 := Vector2.ZERO
var z_r0 := ZONE_R0
var z_c1 := Vector2.ZERO
var z_r1 := ZONE_R0
var z_wait := 0.0
var z_shrink := 1.0
var z_dmg := 0.0
var z_t := 0.0
var z_tick := 0.0
var n_static := 0
var n_start := 0
var winner := 0
var spec_id := 0
var bots_per_match := 30
var next_bot := 1000
var match_time := 0.0
var my_rank := 0

var snap_t := 0.0
var send_t := 0.0
var ui_t := 0.0
var last_fire := {}
var auto_tried := {}
var assist_t := 0.0
var assist_target := 0
var up_drag := 0.0
var test_fire := false
var quit_after := 0.0
var shot_path := ""
var test_town := -1
var auto_jump := -1.0
var bots_only := false
var shot_times := []
var run_t := 0.0
var _frames := 0
var _seen_guns := ["", "", "glock"]
var _seen_inv := {}
var _seen_gear := [0.0, false, false]


func _ready() -> void:
	rng.randomize()
	Cfg.load_cfg()
	players_root = Node3D.new()
	players_root.name = "Players"
	add_child(players_root)
	items_root = Node3D.new()
	items_root.name = "Items"
	add_child(items_root)
	sfxn = Sfx.new()
	add_child(sfxn)
	sfxn.volume = float(Cfg.get_v("volume"))
	Engine.max_fps = int(Cfg.get_v("fps"))
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--bots="):
			bots_per_match = int(a.get_slice("=", 1))
		elif a.begins_with("--quit-after="):
			quit_after = float(a.get_slice("=", 1))
		elif a == "--test-fire":
			test_fire = true
		elif a.begins_with("--town="):
			test_town = int(a.get_slice("=", 1))
		elif a.begins_with("--shot="):
			shot_path = a.get_slice("=", 1)
		elif a.begins_with("--shots="):
			for v in a.get_slice("=", 1).split(","):
				shot_times.append(float(v))
		elif a.begins_with("--timescale="):
			Engine.time_scale = float(a.get_slice("=", 1))
			Engine.max_physics_steps_per_frame = 32
		elif a.begins_with("--autojump="):
			auto_jump = float(a.get_slice("=", 1))
		elif a.begins_with("--quality="):
			Cfg.v["quality"] = int(a.get_slice("=", 1))
	if "--server" in args:
		start_dedicated()
		return
	_build_menu()
	for a in args:
		if a.begins_with("--autojoin="):
			start_join(a.get_slice("=", 1))
		elif a == "--autotrain":
			start_host(false)


# ---------------- menu ----------------

func _build_menu() -> void:
	menu = CanvasLayer.new()
	add_child(menu)
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.12, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(bg)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(cc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	cc.add_child(vb)
	vb.add_child(_menu_label("CONFRONTO", 60))
	var sub := _menu_label("BATTLE ROYALE · 50 JOGADORES · ÚLTIMO DE PÉ VENCE", 18)
	sub.modulate = Color(0.85, 0.75, 0.5)
	vb.add_child(sub)
	nick_edit = _menu_edit("Seu apelido")
	vb.add_child(nick_edit)
	nick_edit.text = Cfg.get_v("nick")
	if nick_edit.text == "":
		nick_edit.text = "Jogador%d" % rng.randi_range(100, 999)
	vb.add_child(_menu_btn("JOGAR (TREINO CONTRA BOTS)", func(): start_host(false)))
	vb.add_child(_menu_btn("CRIAR SALA NO WI-FI", func(): start_host(true)))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	ip_edit = _menu_edit("IP do servidor (ex: 192.168.0.10)")
	ip_edit.custom_minimum_size = Vector2(284, 56)
	ip_edit.text = Cfg.get_v("ip")
	hb.add_child(ip_edit)
	var jb := _menu_btn("ENTRAR", func(): start_join(ip_edit.text.strip_edges()))
	jb.custom_minimum_size = Vector2(190, 56)
	hb.add_child(jb)
	vb.add_child(hb)
	vb.add_child(_menu_btn("CONFIGURAÇÕES", func(): open_settings()))
	var rep := _last_log()
	if rep != "" and _crashed_loading(rep) and int(Cfg.get_v("quality")) > 0:
		Cfg.set_v("quality", 0)
		flash_msg = "Da última vez o jogo fechou ao carregar o mapa. Mudei os gráficos para BAIXA."
	if rep != "":
		var rb := _menu_btn("RELATÓRIO DA ÚLTIMA VEZ (se fechou sozinho)", func(): _show_report(rep))
		rb.add_theme_font_size_override("font_size", 16)
		rb.custom_minimum_size = Vector2(482, 44)
		vb.add_child(rb)
	status_lbl = _menu_label(flash_msg, 18)
	status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	status_lbl.custom_minimum_size = Vector2(440, 44)
	vb.add_child(status_lbl)
	flash_msg = ""


# fim do arquivo de log da execução anterior (pra descobrir onde o jogo fechou)
func _last_log() -> String:
	var dir := DirAccess.open("user://logs")
	if dir == null:
		return ""
	var files := []
	for f in dir.get_files():
		if f.ends_with(".log") and f != "godot.log":
			files.append(f)
	if files.is_empty():
		return ""
	files.sort()
	var txt := FileAccess.get_file_as_string("user://logs/" + files[-1])
	var last := txt.rfind("[etapa]")
	if last < 0 or txt.substr(last).begins_with("[etapa] saiu"):
		return ""
	var lines := txt.split("\n")
	return "\n".join(lines.slice(maxi(0, lines.size() - 60)))


func _crashed_loading(txt: String) -> bool:
	var last := txt.rfind("[etapa]")
	if last < 0:
		return false
	var line := txt.substr(last).get_slice("\n", 0)
	for k in ["iniciar partida", "montando o mapa", "mapa pronto", "criando tela", "partida pronta"]:
		if line.contains(k):
			return true
	return false


func _show_report(txt: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.05, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 20
	vb.offset_right = -20
	vb.offset_top = 16
	vb.offset_bottom = -16
	layer.add_child(vb)
	var hb := HBoxContainer.new()
	vb.add_child(hb)
	var back := _menu_btn("< VOLTAR", func(): layer.queue_free())
	back.custom_minimum_size = Vector2(200, 52)
	hb.add_child(back)
	var cp := _menu_btn("COPIAR", func(): DisplayServer.clipboard_set(txt))
	cp.custom_minimum_size = Vector2(200, 52)
	hb.add_child(cp)
	var te := TextEdit.new()
	te.text = txt
	te.editable = false
	te.size_flags_vertical = Control.SIZE_EXPAND_FILL
	te.add_theme_font_size_override("font_size", 14)
	vb.add_child(te)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# botão voltar do celular: fecha o que estiver aberto, no menu sai do jogo
		if settings:
			return
		if edit_hud:
			edit_hud.queue_free()
			edit_hud = null
			return
		if hud:
			if hud.edit_mode:
				hud.edit_mode = false
				hud.layout = Cfg.get_v("layout").duplicate()
			elif hud.bag_open:
				hud.set_bag(false)
			elif hud.big_map:
				hud.big_map = false
			return
		_step("saiu")
		get_tree().quit()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_step("saiu")
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_step("voltou")


func _menu_label(t: String, fs: int) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", fs)
	return l


func _menu_edit(ph: String) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = ph
	e.custom_minimum_size = Vector2(482, 54)
	e.add_theme_font_size_override("font_size", 22)
	return e


func _menu_btn(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(482, 58)
	b.add_theme_font_size_override("font_size", 22)
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


func _nick() -> String:
	var n := nick_edit.text.strip_edges().left(16) if nick_edit else ""
	return n if n != "" else "Jogador"


func _save_cfg() -> void:
	if nick_edit == null:
		return
	Cfg.v["nick"] = nick_edit.text.strip_edges()
	Cfg.v["ip"] = ip_edit.text.strip_edges()
	Cfg.save()


func open_settings() -> void:
	if settings:
		return
	settings = SettingsUI.new()
	add_child(settings)
	settings.closed.connect(func(): settings = null)
	settings.changed.connect(_on_setting)
	settings.edit_buttons.connect(func():
		settings.queue_free()
		settings = null
		if hud:
			hud.edit_mode = true
		else:
			edit_hud = Hud.new()
			add_child(edit_hud)
			edit_hud.edit_mode = true
			edit_hud.action.connect(func(a: String):
				if a == "edit_done":
					edit_hud.queue_free()
					edit_hud = null))


func _on_setting(key: String) -> void:
	match key:
		"volume":
			sfxn.volume = float(Cfg.get_v("volume"))
		"fps":
			Engine.max_fps = int(Cfg.get_v("fps"))
		"quality":
			if in_game and not dedicated:
				_apply_quality()
		"show_fps":
			if hud:
				hud.show_fps = bool(Cfg.get_v("show_fps"))


# ---------------- iniciar ----------------

func start_dedicated() -> void:
	dedicated = true
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, 64)
	if err != OK:
		printerr("[servidor] não abriu a porta %d (erro %d)" % [PORT, err])
		get_tree().quit(1)
		return
	multiplayer.multiplayer_peer = peer
	_build_world()
	_server_init()
	in_game = true
	print("[servidor] rodando na porta %d, %d bots por partida" % [PORT, bots_per_match])
	bots_only = "--bots-only" in OS.get_cmdline_user_args()
	if bots_only:
		phase_t = 1.0


func _step(t: String) -> void:
	print("[etapa] %s  (memória %d MB)" % [t, OS.get_static_memory_usage() / 1048576])


# mostra "Carregando..." e espera a tela atualizar antes do trabalho pesado
func _show_loading() -> void:
	if menu == null:
		return
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.06, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(bg)
	var l := _menu_label("Carregando o mapa...", 30)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	menu.add_child(l)
	await get_tree().process_frame
	await get_tree().process_frame


func start_host(online: bool) -> void:
	_save_cfg()
	_step("iniciar partida (online=%s)" % online)
	await _show_loading()
	training = not online
	if online:
		var peer := ENetMultiplayerPeer.new()
		var err := peer.create_server(PORT, 32)
		if err != OK:
			status_lbl.text = "Não deu pra criar a sala (erro %d)." % err
			return
		multiplayer.multiplayer_peer = peer
	else:
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	bots_per_match = MAX_PLAYERS - 1
	local_id = multiplayer.get_unique_id()
	_build_world()
	_step("criando tela do jogo")
	_enter_game()
	_server_init()
	_server_add_player(local_id, _nick(), false)
	_step("partida pronta")
	if online:
		phase_t = 120.0
		hud.can_start = true
		hud.center("Sala criada! Quem estiver no mesmo Wi-Fi entra com o IP:\n" + _lan_ip() + "\nToque em COMEÇAR quando todos entrarem.", 15.0)
	else:
		phase_t = 6.0 if auto_jump < 0.0 else 1.0
	_all("phase_set", [LOBBY, phase_t])


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
	await _show_loading()
	_build_world()
	_enter_game()
	rpc_id(1, "req_join", _nick())


func _on_fail() -> void:
	_back_to_menu("Não conectou. Confere o IP e se o servidor está ligado.")


func _on_server_lost() -> void:
	_back_to_menu("A conexão com o servidor caiu.")


func _back_to_menu(msg: String) -> void:
	flash_msg = msg
	Engine.time_scale = 1.0
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	get_tree().call_deferred("reload_current_scene")


func _build_world() -> void:
	_step("montando o mapa")
	world = World.new()
	world.name = "World"
	add_child(world)
	world.build(dedicated, int(Cfg.get_v("quality")))
	_step("mapa pronto")
	n_static = world.items.size()
	items_avail = []
	for i in world.items.size():
		items_avail.append(true)
		if not dedicated:
			_make_item_node(i)


func _make_item_node(i: int) -> void:
	while item_nodes.size() <= i:
		item_nodes.append(null)
	if item_nodes[i]:
		item_nodes[i].queue_free()
	var it: Dictionary = world.items[i]
	var n := Weapons.build_item(it["kind"])
	n.position = it["pos"]
	n.rotation.y = float(i) * 2.39
	if it["kind"] == "box":
		var l := Label3D.new()
		l.text = str(it.get("name", ""))
		l.position = Vector3(0, 1.0, 0)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.pixel_size = 0.003
		l.font_size = 36
		l.outline_size = 8
		l.visibility_range_end = 25.0
		n.add_child(l)
	items_root.add_child(n)
	item_nodes[i] = n


func _enter_game() -> void:
	if menu:
		menu.queue_free()
		menu = null
	hud = Hud.new()
	hud.game = self
	add_child(hud)
	hud.show_fps = bool(Cfg.get_v("show_fps"))
	hud.action.connect(_on_action)
	hud.pick.connect(_on_pick)
	hud.inv_action.connect(_on_inv_action)
	cam_yaw = Node3D.new()
	add_child(cam_yaw)
	cam_pitch = Node3D.new()
	cam_yaw.add_child(cam_pitch)
	spring = SpringArm3D.new()
	spring.spring_length = 3.2
	spring.position = Vector3(0.55, 0.15, 0)
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
	plane_node = _build_plane()
	plane_node.visible = false
	add_child(plane_node)
	zone_wall = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 500.0
	cyl.radial_segments = 64
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	zone_wall.mesh = cyl
	var zm := ShaderMaterial.new()
	var sh2 := Shader.new()
	# parede da zona: forte de perto, some de longe (não fica cortada no fim da visão)
	sh2.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
varying float wy;
void vertex() { wy = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y; }
void fragment() {
	float d = length(VERTEX);
	float band = 0.75 + 0.25 * sin(wy * 0.8 + TIME * 2.0);
	ALBEDO = vec3(0.3, 0.55, 1.0);
	ALPHA = 0.32 * band * (1.0 - smoothstep(50.0, 170.0, d));
}"""
	zm.shader = sh2
	zone_wall.material_override = zm
	zone_wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	zone_wall.visible = false
	add_child(zone_wall)
	loop_player = AudioStreamPlayer.new()
	add_child(loop_player)
	_make_loops()
	_apply_quality()
	in_game = true


func _apply_quality() -> void:
	var vp := get_viewport()
	var sun: DirectionalLight3D = world.get_node_or_null("Sun")
	var env: WorldEnvironment = world.get_node_or_null("Env")
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	var far := 380.0
	match int(Cfg.get_v("quality")):
		0:
			vp.scaling_3d_scale = 0.6
			vp.msaa_3d = Viewport.MSAA_DISABLED
			if sun:
				sun.shadow_enabled = false
			far = 320.0
			world.set_view(220.0)
		1:
			vp.scaling_3d_scale = 0.8
			vp.msaa_3d = Viewport.MSAA_DISABLED
			if sun:
				sun.shadow_enabled = true
				sun.directional_shadow_max_distance = 30.0
			world.set_view(290.0)
		2:
			vp.scaling_3d_scale = 1.0
			vp.msaa_3d = Viewport.MSAA_2X
			if sun:
				sun.shadow_enabled = true
				sun.directional_shadow_max_distance = 55.0
			far = 460.0
			world.set_view(380.0)
	cam.far = far
	fog_base = 2.2 / far * 0.38
	if env:
		env.environment.fog_density = fog_base


func _build_plane() -> Node3D:
	var m := MB.new()
	m.tex(U.METAL, 0.15)
	var g := Color(0.65, 0.7, 0.66)
	var dark := Color(0.35, 0.37, 0.36)
	var along := Basis(Vector3.RIGHT, -PI / 2.0)   # cilindro deitado apontando pra -Z
	m.cyl(Transform3D(along, Vector3(0, 0, 12)), 2.2, 2.2, 22.0, 14, g, false)
	m.cyl(Transform3D(along, Vector3(0, 0, -10)), 2.2, 0.6, 4.0, 14, g, true)
	m.cyl(Transform3D(along, Vector3(0, 0.6, 15.5)), 1.2, 2.2, 3.5, 14, g, true)
	m.boxp(Vector3(0, 1.9, -1), Vector3(36, 0.45, 4.6), g)
	m.boxp(Vector3(0, 4.0, 15.5), Vector3(0.4, 5.0, 3.6), g)
	m.boxp(Vector3(0, 2.2, 16.0), Vector3(12, 0.3, 2.8), g)
	m.tex(U.PLAIN, 1.0)
	m.boxp(Vector3(0, 0.9, -10.5), Vector3(2.2, 0.8, 1.4), Color(0.15, 0.18, 0.2))
	m.tex(U.METAL, 0.3)
	for x in [-11.0, -5.5, 5.5, 11.0]:
		m.cyl(Transform3D(along, Vector3(x, 1.2, 1.5)), 0.65, 0.55, 4.0, 10, dark, true)
		m.boxp(Vector3(x, 1.2, -2.6), Vector3(3.4, 0.15, 0.2), Color(0.2, 0.2, 0.2))
	var root := Node3D.new()
	U.mesh(root, m.commit())
	return root


func _lan_ip() -> String:
	for a in IP.get_local_addresses():
		if a.begins_with("192.168.") or a.begins_with("10.") or a.begins_with("172."):
			return a
	return "(não achei o IP, veja nas config. do Wi-Fi)"


# ---------------- estado compartilhado (todos calculam igual) ----------------

func plane_frac() -> float:
	return clampf(plane_t / plane_dur, 0.0, 1.0)


func plane_pos() -> Vector3:
	return plane_a.lerp(plane_b, plane_frac())


func zone_now() -> Array:
	if z_stage < 0:
		return [Vector2.ZERO, 9999.0]
	var k := clampf((z_t - z_wait) / z_shrink, 0.0, 1.0)
	return [z_c0.lerp(z_c1, k), lerpf(z_r0, z_r1, k)]


func zone_next() -> Array:
	if z_stage < 0:
		return []
	return [z_c1, z_r1]


func zone_goal_c() -> Vector2:
	return z_c1 if z_stage >= 0 else Vector2.ZERO


func zone_goal_r() -> float:
	return maxf(z_r1, 8.0) if z_stage >= 0 else 340.0


func _alive_count() -> int:
	var n := 0
	for id in players:
		var p: Player = players[id]
		if p.alive and not p.spect:
			n += 1
	return n


func _view_target() -> Player:
	var lp: Player = players.get(local_id)
	if lp and lp.alive and not lp.spect:
		return lp
	var t: Player = players.get(spec_id)
	if t and t.alive:
		return t
	if phase == END and players.has(winner):
		return players[winner]
	return lp


func view_pos() -> Vector3:
	var t := _view_target()
	if t == null:
		return Vector3.ZERO
	return plane_pos() if t.air == 3 else t.position


func view_yaw() -> float:
	var t := _view_target()
	return t.yaw if t else 0.0


func near_cam(p: Vector3, d: float) -> bool:
	if cam == null:
		return true
	return cam.global_position.distance_squared_to(p) < d * d


# ---------------- sons ----------------

func sfx(n: String, vol := 0.0) -> void:
	if sfxn and not dedicated:
		sfxn.play(n, vol)


func sfx_at(n: String, pos: Vector3, local: bool, vol := 0.0, max_d := 50.0) -> void:
	if sfxn == null or dedicated:
		return
	if local:
		sfxn.play(n, vol - 3.0)
	else:
		sfxn.play_at(n, pos, vol, max_d)


func on_step(p: Player, quiet: bool) -> void:
	if dedicated or sfxn == null:
		return
	var hard := p.position.y - world.height(p.position.x, p.position.z) > 0.04
	var n := ("step_hard%d" if hard else "step_grass%d") % randi_range(0, 2)
	if p.is_local:
		sfxn.play(n, -14.0 if quiet else -9.0)
		return
	var d := 16.0 if quiet else 45.0
	sfxn.play_at(n, p.position, -6.0 if quiet else 0.0, d, 1.0, 4.0)
	var lp: Player = players.get(local_id)
	if hud and lp and lp.alive and lp.position.distance_to(p.position) < d:
		hud.add_step(p.position)


func _make_loops() -> void:
	sfxn.streams["plane"] = _gen_loop(1.0, 0.04, 0.6, 38.0)
	sfxn.streams["wind"] = _gen_loop(1.0, 0.12, 0.5, 0.0)


# ruído contínuo (motor do avião / vento); hum = frequência de ronco
func _gen_loop(dur: float, smooth: float, vol: float, hum: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(dur * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	var v := 0.0
	for i in n:
		var t := float(i) / rate
		v = lerpf(v, randf() * 2.0 - 1.0, smooth)
		var s := v * 3.0
		if hum > 0.0:
			s = s * 0.6 + sin(TAU * hum * t) * 0.35 + sin(TAU * hum * 2.0 * t) * 0.15
		data.encode_s16(i * 2, clampi(int(s * vol * 20000.0), -32768, 32767))
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = rate
	st.stereo = false
	st.data = data
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_begin = 0
	st.loop_end = n
	return st


# ---------------- loop ----------------

func _process(delta: float) -> void:
	run_t += delta / maxf(Engine.time_scale, 0.001)
	if not shot_times.is_empty() and run_t >= shot_times[0]:
		get_viewport().get_texture().get_image().save_png(shot_path.replace(".png", "_%d.png" % int(shot_times[0])))
		_print_debug_state()
		shot_times.pop_front()
	if quit_after > 0.0:
		quit_after -= delta / maxf(Engine.time_scale, 0.001)
		if quit_after <= 0.0:
			_print_debug_state()
			if shot_path != "":
				get_viewport().get_texture().get_image().save_png(shot_path)
			get_tree().quit()
	if not in_game:
		return
	if not dedicated and _frames < 30:
		_frames += 1
		if _frames == 30:
			_step("jogando")
	match phase:
		LOBBY:
			phase_t = maxf(phase_t - delta, 0.0)
		PLANE:
			plane_t += delta
		MATCH:
			z_t += delta
			match_time += delta
		END:
			phase_t = maxf(phase_t - delta, 0.0)
	if multiplayer.is_server():
		_server_tick(delta)
	if dedicated:
		return
	var lp: Player = players.get(local_id)
	if lp == null:
		return
	if test_town >= 0:
		var c: Vector2 = world.towns[test_town]["pos"]
		var p := Vector2(c.x + float(world.towns[test_town]["r"]) + 8.0, c.y + 10.0)
		lp.position = Vector3(p.x, world.height(p.x, p.y) + 0.2, p.y)
		lp.air = 0
		cam_yaw_v = atan2(-(c.x - p.x), -(c.y - p.y))
		cam_pitch_v = -0.08
		lp.hp = 100.0
	_local_update(lp, delta)
	_update_world_fx(delta)


func _update_world_fx(_delta: float) -> void:
	plane_node.visible = phase == PLANE and plane_t < plane_dur + 3.0
	if plane_node.visible:
		var dir := (plane_b - plane_a).normalized()
		var pp := plane_a.lerp(plane_b, plane_t / plane_dur)
		plane_node.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP), pp + Vector3(0, 3, 0))
	# de cima a névoa diminui, pra enxergar onde vai cair
	var env: WorldEnvironment = world.get_node_or_null("Env")
	if env:
		var alt := cam.global_position.y - world.height(cam.global_position.x, cam.global_position.z)
		env.environment.fog_density = fog_base * clampf(1.0 - (alt - 25.0) / 160.0, 0.3, 1.0)
	sfxn.listener_pos = cam.global_position
	var z := zone_now()
	zone_wall.visible = float(z[1]) < 1000.0
	if zone_wall.visible:
		var r := maxf(float(z[1]), 0.05)
		zone_wall.position = Vector3(z[0].x, 100.0, z[0].y)
		zone_wall.scale = Vector3(r, 1, r)
	var lp: Player = players.get(local_id)
	var want := ""
	if lp and lp.alive and not lp.spect:
		if lp.air == 3:
			want = "plane"
		elif lp.air == 1:
			want = "wind"
	if want != loop_kind:
		loop_kind = want
		if want == "":
			loop_player.stop()
		else:
			loop_player.stream = sfxn.streams[want]
			loop_player.volume_db = sfxn.db(-12.0 if want == "plane" else -14.0)
			loop_player.play()


func _print_debug_state() -> void:
	var parts := PackedStringArray()
	for id in info:
		var p: Player = players.get(id)
		if p == null:
			continue
		parts.append("%s k%d hp%d ar%d %s %s%s inv%s" % [info[id]["name"], info[id]["kills"], p.hp, p.armor, p.cur_wid(), "VIVO" if p.alive else "morto", "" if p.air == 0 else " ar%d" % p.air, str(p.inv)])
	print("[estado] fase=%d zona=%d tempo=%.0f vivos=%d itens=%d livres=%d vencedor=%s" % [phase, z_stage, match_time, _alive_count(), items_avail.size(), items_avail.count(true), info[winner]["name"] if info.has(winner) else "-"])
	print("   " + "\n   ".join(parts.slice(0, 12)))
	if not dedicated:
		print("[render] chamadas=%d triangulos=%d objetos=%d fps=%d" % [
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
			Engine.get_frames_per_second()])


func _local_update(lp: Player, delta: float) -> void:
	var wid := lp.cur_wid()
	var w := lp.cur_stat()
	var playing := lp.alive and not lp.spect
	# modo da tela
	var mode := "ground"
	if phase == END:
		mode = "end"
	elif not playing:
		mode = "dead"
	elif lp.air == 3:
		mode = "plane"
	elif lp.air == 1:
		mode = "fall"
	elif lp.air == 2:
		mode = "glide"
	elif phase == LOBBY:
		mode = "lobby"
	hud.mode = mode
	hud.crouched = lp.crouch
	hud.can_start = phase == LOBBY and multiplayer.is_server() and not training
	var zoom: float = float(w["zoom"]) if lp.scoped else 1.0
	var look := hud.take_look()
	if hud.bag_open or hud.edit_mode:
		look = Vector2.ZERO
	var sens: float = 0.0055 * float(Cfg.get_v("sens")) / zoom
	if lp.scoped:
		sens *= float(Cfg.get_v("sens_ads"))
	var inv_y := -1.0 if bool(Cfg.get_v("invert")) else 1.0
	var firing: bool = (hud.fire_held or test_fire) and playing and lp.air == 0 and not hud.bag_open
	if firing and look.y < 0.0:
		up_drag += -look.y
	elif not firing:
		up_drag = maxf(up_drag - delta * 120.0, 0.0)
	if playing:
		cam_yaw_v -= look.x * sens
		cam_pitch_v = clampf(cam_pitch_v - look.y * sens * inv_y, -1.3, 1.25)
		var mv := hud.move_vec if not hud.bag_open else Vector2.ZERO
		lp.wish = Basis(Vector3.UP, cam_yaw_v) * Vector3(mv.x, 0, mv.y) if lp.air != 3 else Vector3.ZERO
		lp.pitch = cam_pitch_v
		if firing:
			_aim_assist(lp, w, delta)
			_local_fire(lp)
		if lp.air == 3 and (plane_t >= plane_dur or (auto_jump >= 0.0 and plane_frac() >= auto_jump)):
			_on_action("leave")
	else:
		lp.wish = Vector3.ZERO
	# câmera
	var t := _view_target()
	var target_len := 3.0
	var fov := 75.0
	var base := t.position if t else Vector3.ZERO
	var cy := cam_yaw_v
	var cp := cam_pitch_v
	if t and t != lp:
		cy = t.yaw
		cp = t.pitch * 0.5 - 0.15
	if t and t.air == 3:
		base = plane_pos() + Vector3(0, 6, 0)
		target_len = 34.0
		if t == lp:
			cp = minf(cp, -0.25)
	elif t and (t.air == 1 or t.air == 2):
		target_len = 7.0
	elif t != lp:
		target_len = 4.5
	if t == lp and lp.scoped:
		target_len = 0.9
		fov = 75.0 / zoom
	if not playing and t == lp:
		target_len = 5.0
	cam_yaw.position = base + Vector3(0, 1.55 if not (t and t.crouch) else 1.1, 0)
	cam_yaw.rotation.y = cy if t == lp else lerp_angle(cam_yaw.rotation.y, cy, minf(1.0, 6.0 * delta))
	cam_pitch.rotation.x = cp
	spring.spring_length = lerpf(spring.spring_length, target_len, minf(1.0, 8.0 * delta))
	cam.fov = lerpf(cam.fov, fov, minf(1.0, 12.0 * delta))
	# manda posição pro servidor 20x por segundo
	send_t += delta
	if send_t >= 0.05 and not multiplayer.is_server() and playing:
		send_t = 0.0
		rpc_id(1, "st", lp.position, lp.yaw, lp.pitch, wid, lp.flags())
	hud.heal_k = 1.0 - lp.heal_t / float(Weapons.ITEMS[lp.heal_kind]["time"]) if lp.heal_t > 0.0 and lp.heal_kind != "" else -1.0
	var zn := zone_now()
	hud.out_zone = playing and lp.air == 0 and Vector2(lp.position.x, lp.position.z).distance_to(zn[0]) > float(zn[1])
	ui_t += delta
	if ui_t > 0.2:
		ui_t = 0.0
		_ui_slow(lp, playing)
	hud.hp = lp.hp
	hud.armor = lp.armor
	hud.heals = [lp.count("bandage"), lp.count("med")]
	hud.overlay = lp.scoped and bool(w["overlay"])
	hud.red_dot = lp.scoped and not bool(w["overlay"]) and ("holo" in lp.cur_att())
	hud.reloading = lp.reload_t > 0.0
	var sl := [{"id": "fist", "att": [], "ammo": 0, "max": 0}]
	for g in lp.guns:
		var gid: String = g["id"]
		sl.append({"id": gid, "att": g["att"], "ammo": int(lp.mag.get(gid, 0)) if gid != "" else 0, "max": int(Weapons.stat(gid, g["att"])["mag"]) if gid != "" else 0})
	hud.slots = sl
	hud.sel = lp.sel + 1
	hud.refresh_bag(lp)


func _aim_assist(lp: Player, w: Dictionary, delta: float) -> void:
	var mode: int = int(Cfg.get_v("aim_assist"))
	if mode == 0 or (mode == 1 and lp.scoped) or lp.cur_wid() == "fist":
		return
	assist_t -= delta
	var from := cam.global_position
	var fwd := -cam.global_transform.basis.z
	if assist_t <= 0.0:
		assist_t = 0.1
		assist_target = 0
		var best := 9.0
		var space := get_world_3d().direct_space_state
		for id in players:
			var o: Player = players[id]
			if o == lp or not o.alive or o.spect or o.air != 0:
				continue
			var tp := o.position + Vector3(0, o.head_y() - 0.35, 0)
			var d := tp - from
			var dist := d.length()
			if dist > minf(float(w["range"]), 120.0) or dist < 0.5:
				continue
			var ang := fwd.angle_to(d / dist)
			var lim := clampf(atan2(2.0, dist), 0.025, 0.2)
			if ang > lim or ang > best:
				continue
			var q := PhysicsRayQueryParameters3D.create(from, tp, 1)
			if not space.intersect_ray(q).is_empty():
				continue
			best = ang
			assist_target = id
	var t: Player = players.get(assist_target)
	if t == null or not t.alive:
		return
	# arrastar pra cima enquanto atira sobe a mira pra cabeça (capa)
	var aimp := t.position + Vector3(0, t.head_y() + 0.12 if up_drag > 18.0 else t.head_y() - 0.4, 0)
	var dir := (aimp - from).normalized()
	var wy := atan2(-dir.x, -dir.z)
	var wp := asin(clampf(dir.y, -1.0, 1.0))
	var k := minf(1.0, (9.0 if up_drag > 18.0 else 5.0) * delta)
	cam_yaw_v = lerp_angle(cam_yaw_v, wy, k)
	cam_pitch_v = lerpf(cam_pitch_v, wp, k)


func _ui_slow(lp: Player, playing: bool) -> void:
	# itens por perto (lista do canto direito)
	var list := []
	if playing and lp.air == 0 and phase != LOBBY:
		var now := Time.get_ticks_msec()
		for i in world.items.size():
			if not items_avail[i]:
				continue
			var it: Dictionary = world.items[i]
			var dd := lp.position.distance_to(it["pos"])
			if dd > 2.6:
				continue
			var kind: String = it["kind"]
			if kind == "box":
				var bl: Array = it.get("list", [])
				for j in bl.size():
					var e: Array = bl[j]
					list.append({"key": [i, j], "kind": e[0], "n": e[1], "label": Weapons.item_name(e[0])})
				continue
			# colete, capacete e mochila pegam sozinhos quando servem
			if (kind == "vest" or kind == "helmet" or kind == "bag") and lp.wants(kind) and dd < 1.8 and now - int(auto_tried.get(i, 0)) > 1500:
				auto_tried[i] = now
				_to_server("req_pickup", [i, -1])
				continue
			list.append({"key": [i, -1], "kind": kind, "n": it.get("n", 1), "label": Weapons.item_name(kind)})
	hud.set_pickups(list)
	var me = info.get(local_id)
	hud.alive_n = _alive_count()
	hud.kills_n = me["kills"] if me else 0
	var t := _view_target()
	if phase == LOBBY:
		hud.set_spec("Partida começa em %d s   ·   %d na sala" % [ceili(phase_t), players.size()])
	elif t and t != lp and phase != END:
		hud.set_spec("Assistindo: %s" % t.nick)
	else:
		hud.set_spec("")
	var zt := ""
	if phase == PLANE:
		zt = "Salte do avião!" if lp.air == 3 else ""
	elif phase == MATCH and z_stage >= 0:
		if z_t < z_wait:
			zt = "Zona fecha em %s" % _mmss(z_wait - z_t)
		elif z_t < z_wait + z_shrink:
			zt = "ZONA FECHANDO  %s" % _mmss(z_wait + z_shrink - z_t)
		elif z_stage < ZONES.size() - 1:
			zt = "Próxima zona..."
	elif phase == END and (dedicated or not training):
		zt = "Nova partida em %d s" % ceili(phase_t)
	if hud.out_zone:
		zt = "FORA DA ZONA! Corra pro círculo"
	hud.set_zone_text(zt)
	for id in players:
		var p: Player = players[id]
		if p.tag:
			p.tag.visible = phase == LOBBY and id != local_id


func _mmss(s: float) -> String:
	var t := ceili(s)
	return "%d:%02d" % [t / 60, t % 60]


func _on_action(act: String) -> void:
	match act:
		"exit", "menu":
			_back_to_menu("")
			return
		"settings":
			open_settings()
			return
		"edit_done":
			hud.layout = Cfg.get_v("layout").duplicate()
			return
		"map":
			hud.big_map = not hud.big_map
			return
		"spec":
			_spec_next()
			return
		"retry":
			if training and multiplayer.is_server():
				_server_reset()
			return
		"start":
			if multiplayer.is_server() and phase == LOBBY:
				phase_t = 0.0
			return
		"bag":
			hud.set_bag(not hud.bag_open)
			sfx("click")
			return
	var lp: Player = players.get(local_id)
	if lp == null or not lp.alive or lp.spect:
		return
	var w := lp.cur_stat()
	match act:
		"leave":
			if lp.air == 3 and phase == PLANE:
				lp.leave_plane(plane_pos() + Vector3(0, -4, 0))
				lp.velocity = Vector3.ZERO
				sfx("jump")
		"chute":
			if lp.air == 1:
				lp.air = 2
				sfx("chute")
		"jump":
			lp.want_jump = true
		"crouch":
			if lp.air == 0:
				lp.set_crouch(not lp.crouch)
		"reload":
			_start_reload(lp)
		"scope":
			if float(w["zoom"]) > 1.0 and lp.heal_t <= 0.0:
				lp.scoped = not lp.scoped
				lp.aim_t = 0.5
				sfx("click", -6.0)
		"heal":
			_start_heal(lp, "")
		"pickup":
			var l: Array = []
			for c in hud.pick_list.get_children():
				l.append(c)
			if not l.is_empty():
				(l[0] as Button).pressed.emit()
		"slot0", "slot1", "slot2", "slot3":
			_select(lp, int(act.substr(4)) - 1)


# muda a arma na mão; tocar na que já está na mão guarda (mãos livres, corre mais)
func _select(lp: Player, s: int) -> void:
	if s >= 0 and lp.guns[s]["id"] == "":
		return
	if s == lp.sel and s >= 0:
		s = -1
	if s == lp.sel:
		return
	lp.sel = s
	lp.reload_t = 0.0
	lp.scoped = false
	lp.update_gun()
	sfx("switch")


func _start_heal(lp: Player, kind: String) -> void:
	if lp.heal_t > 0.0:
		lp.heal_t = 0.0
		return
	if lp.hp >= 100.0 or lp.air != 0:
		return
	if kind == "":
		kind = "med" if (lp.count("med") > 0 and (lp.hp < 55.0 or lp.count("bandage") == 0)) else "bandage"
	if lp.count(kind) <= 0:
		hud.center("Sem bandagem nem kit médico", 1.2)
		return
	lp.heal_kind = kind
	lp.heal_t = float(Weapons.ITEMS[kind]["time"])
	lp.scoped = false
	lp.reload_t = 0.0
	sfx("heal")


func _on_pick(key: Array) -> void:
	_to_server("req_pickup", [int(key[0]), int(key[1])])


func _on_inv_action(act: String, a: String, b: int) -> void:
	var lp: Player = players.get(local_id)
	if lp == null or not lp.alive:
		return
	match act:
		"use":
			hud.set_bag(false)
			_start_heal(lp, a)
		"drop":
			_to_server("req_drop", [a, b])
		"drop_gun":
			_to_server("req_drop_gun", [b])
		"equip":
			_to_server("req_equip", [a, b])
		"unequip":
			_to_server("req_unequip", [a, b])


func _spec_next() -> void:
	var ids := []
	for id in players:
		var p: Player = players[id]
		if p.alive and not p.spect and id != local_id:
			ids.append(id)
	if ids.is_empty():
		return
	ids.sort()
	var k := ids.find(spec_id)
	spec_id = ids[(k + 1) % ids.size()]


func on_landed() -> void:
	var lp: Player = players.get(local_id)
	if lp == null:
		return
	sfx("land")
	var t := world.nearest_town(Vector2(lp.position.x, lp.position.z))
	if Vector2(lp.position.x, lp.position.z).distance_to(t["pos"]) < float(t["r"]) + 40.0:
		hud.center(t["name"], 2.5)


func heal_done(p: Player, kind: String) -> void:
	if multiplayer.is_server():
		_server_heal(p.pid, kind)
	else:
		rpc_id(1, "req_heal", kind)


func _start_reload(lp: Player) -> void:
	var wid := lp.cur_wid()
	if wid == "fist":
		return
	var w := lp.cur_stat()
	if lp.reload_t <= 0.0 and lp.mag[wid] < int(w["mag"]):
		lp.reload_t = w["reload"]
		lp.scoped = false
		sfx("reload_out")


func _local_fire(lp: Player) -> void:
	if lp.cool > 0.0 or lp.reload_t > 0.0 or lp.heal_t > 0.0 or lp.vault_t >= 0.0:
		return
	var wid := lp.cur_wid()
	var w := lp.cur_stat()
	var melee := wid == "fist"
	if not melee and lp.mag[wid] <= 0:
		sfx("empty")
		_start_reload(lp)
		return
	if not melee:
		lp.mag[wid] -= 1
	lp.cool = 1.0 / float(w["rate"])
	lp.aim_t = 0.7
	if melee:
		lp.punch_t = 0.3
	var xf := cam.global_transform
	var fwd := -xf.basis.z
	var right := xf.basis.x
	var up := xf.basis.y
	var head := lp.position + Vector3(0, lp.head_y(), 0)
	var origin := xf.origin + fwd * maxf(0.0, (head - xf.origin).dot(fwd))
	var spread: float = w["spread"]
	if lp.scoped:
		spread *= float(w["ads"])
	if lp.crouch:
		spread *= 0.7
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
			hits.append([col.pid, (res["position"].y - col.position.y) > col.head_y()])
		else:
			hits.append(-1)
	_to_server("req_fire", [origin, ends, hits, wid])
	if melee:
		sfx("punch_swing")
		if hits.size() > 0 and hits[0] is Array:
			sfx("punch_hit")
		return
	_shot_fx(lp, ends, wid, true)
	cam_pitch_v = minf(cam_pitch_v + float(w["recoil"]), 1.25)
	cam_yaw_v += randf_range(-0.3, 0.3) * float(w["recoil"])
	if w["type"] == "bolt" or w["type"] == "sniper":
		get_tree().create_timer(0.35).timeout.connect(func(): sfx("bolt", -4.0))
	if lp.mag[wid] <= 0:
		_start_reload(lp)


# ---------------- efeitos ----------------

func _play_shot(wid: String, att: Array, pos: Vector3, local: bool) -> void:
	var sil := "silencer" in att
	var n := sfxn.shot_name(wid, sil)
	if local:
		sfxn.play(n, -3.0)
	else:
		sfxn.play_at(n, pos + Vector3(0, 1.5, 0), 0.0, 45.0 if sil else 280.0, 1.0, 14.0 if not sil else 5.0)


func _shot_fx(p: Player, ends: PackedVector3Array, wid: String, local: bool) -> void:
	if dedicated:
		return
	if wid == "fist":
		sfx_at("punch_swing", p.position, local)
		return
	var att := p.att_of(wid)
	var far := cam != null and cam.global_position.distance_to(p.position) > 200.0
	var from := p.muzzle_pos()
	if not far:
		for e in ends:
			_tracer(from, e)
			_temp_box(e, 0.1, Color(0.5, 0.47, 0.4), 0.3)
		if not ("silencer" in att):
			_temp_box(from, 0.12, Color(1.0, 0.85, 0.3), 0.04, true)
	_play_shot(wid, att, p.position, local)


func _tracer(a: Vector3, b: Vector3) -> void:
	var length := a.distance_to(b)
	if length < 0.5:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = U.box_mesh(Vector3(0.02, 0.02, 1.0))
	mi.material_override = U.mat(Color(1.0, 0.85, 0.4), true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var dir := (b - a) / length
	var up := Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT
	mi.global_transform = Transform3D(Basis.looking_at(dir, up) * Basis.from_scale(Vector3(1, 1, length)), (a + b) / 2.0)
	get_tree().create_timer(0.05).timeout.connect(mi.queue_free)


func _temp_box(pos: Vector3, size: float, col: Color, life: float, unshaded := false) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = U.box_mesh(Vector3(size, size, size))
	mi.material_override = U.mat(col, unshaded)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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


func _guns_net(p: Player) -> Array:
	var a := []
	for g in p.guns:
		a.append([g["id"], g["att"].duplicate()])
	return a


# ---------------- servidor ----------------

func _server_init() -> void:
	multiplayer.peer_disconnected.connect(_on_peer_left)
	phase = LOBBY
	phase_t = LOBBY_T


func _human_count() -> int:
	var n := 0
	for id in players:
		if not players[id].is_bot:
			n += 1
	return n


func _server_add_player(id: int, nick: String, bot: bool) -> void:
	var pos := world.random_spawn(rng)
	var spect := phase != LOBBY and not bot
	if not bot and id != local_id:
		var ns := PackedInt32Array()
		for i in n_static:
			ns.append(int(world.items[i]["n"]))
		rpc_id(id, "welcome", _snapshot(), items_avail, _dyn_items(), ns, [phase, phase_t, plane_a, plane_b, plane_t, plane_dur],
			[z_stage, z_c0, z_r0, z_c1, z_r1, z_wait, z_shrink, z_dmg, z_t])
	_all("add_player", [id, nick, pos, bot, spect])
	if dedicated and not bot:
		print("[servidor] entrou: %s (%d)%s" % [nick, id, " (assistindo)" if spect else ""])


func _snapshot() -> Array:
	var arr := []
	for id in players:
		var p: Player = players[id]
		arr.append({
			"id": id, "name": info[id]["name"], "bot": info[id]["bot"], "kills": info[id]["kills"],
			"pos": p.position, "alive": p.alive, "spect": p.spect, "hp": p.hp, "guns": _guns_net(p),
			"armor": p.armor, "helmet": p.helmet, "bag": p.bag, "air": p.air,
		})
	return arr


func _dyn_items() -> Array:
	var arr := []
	for i in range(n_static, world.items.size()):
		var it: Dictionary = world.items[i]
		arr.append([i, it["pos"], it["kind"], it.get("n", 1), it.get("extra", null), it.get("list", []), it.get("name", "")])
	return arr


func _on_peer_left(id: int) -> void:
	last_fire.erase(id)
	if players.has(id):
		_all("remove_player", [id])
	_check_end()


func _server_tick(delta: float) -> void:
	match phase:
		LOBBY:
			if dedicated and _human_count() == 0 and not bots_only:
				phase_t = LOBBY_T
			elif phase_t <= 0.0:
				_server_board()
		PLANE:
			if plane_t >= plane_dur + 0.5:
				for id in players:
					var p: Player = players[id]
					if p.is_bot and p.air == 3:
						server_bot_jump(p)
			if plane_t >= plane_dur + 2.0:
				_all("phase_set", [MATCH, 0.0])
				_zone_next()
		MATCH:
			if z_stage >= 0 and z_t >= z_wait + z_shrink and z_stage < ZONES.size() - 1:
				_zone_next()
			z_tick += delta
			if z_tick >= 1.0:
				z_tick = 0.0
				var z := zone_now()
				for id in players.keys():
					var p: Player = players.get(id)
					if p and p.alive and not p.spect and p.air == 0:
						if Vector2(p.position.x, p.position.z).distance_to(z[0]) > float(z[1]):
							_server_damage(id, 0, z_dmg, false, "zona", true)
		END:
			if phase_t <= 0.0 and (dedicated or not training):
				_server_reset()
	snap_t += delta
	if snap_t >= 0.05:
		snap_t = 0.0
		if multiplayer.get_peers().size() > 0:
			# pacote compacto: 22 bytes por jogador (cabe num pacote mesmo com 50)
			var ids := []
			for id in players:
				var p: Player = players[id]
				if not p.spect and p.alive:
					ids.append(id)
			var buf := PackedByteArray()
			buf.resize(ids.size() * 22)
			var o := 0
			for id in ids:
				var p: Player = players[id]
				buf.encode_s32(o, id)
				buf.encode_float(o + 4, p.position.x)
				buf.encode_float(o + 8, p.position.y)
				buf.encode_float(o + 12, p.position.z)
				buf.encode_s16(o + 16, int(wrapf(p.yaw, -PI, PI) * 10000.0))
				buf.encode_s16(o + 18, int(clampf(p.pitch, -1.6, 1.6) * 20000.0))
				buf.encode_u8(o + 20, WIDS.find(p.shown_wid))
				buf.encode_u8(o + 21, p.flags() & 255)
				o += 22
			rpc("snap", buf)


func _server_board() -> void:
	var humans := _human_count()
	var nb := clampi(bots_per_match, 0, MAX_PLAYERS - humans)
	for i in nb:
		var k := next_bot - 1000
		var nm: String = BOT_NAMES[k % BOT_NAMES.size()]
		_server_add_player(next_bot, "Bot " + nm, true)
		next_bot += 1
	for id in players:
		var p: Player = players[id]
		if p.is_bot:
			p.b_jump_at = clampf(randf_range(0.05, 0.95) * 0.6 + randf() * 0.4, 0.04, 0.97)
	# rota do avião sempre dentro do mapa
	var lim := World.PLAY - 30.0
	var ang := rng.randf() * TAU
	var dir := Vector2(cos(ang), sin(ang))
	var perp := Vector2(-dir.y, dir.x)
	var c := perp * rng.randf_range(-120.0, 120.0)
	var t0 := -1e9
	var t1 := 1e9
	for axis in 2:
		var dv: float = dir[axis]
		var cv: float = c[axis]
		if absf(dv) < 1e-4:
			continue
		var ta := (-lim - cv) / dv
		var tb := (lim - cv) / dv
		t0 = maxf(t0, minf(ta, tb))
		t1 = minf(t1, maxf(ta, tb))
	var a2 := c + dir * t0
	var b2 := c + dir * t1
	n_start = _alive_count()
	_all("plane_set", [Vector3(a2.x, PLANE_H, a2.y), Vector3(b2.x, PLANE_H, b2.y), a2.distance_to(b2) / PLANE_SPEED])
	_all("phase_set", [PLANE, 0.0])
	if dedicated:
		print("[servidor] partida começou com %d jogadores (%d bots)" % [n_start, nb])


func server_bot_jump(p: Player) -> void:
	if p.air != 3:
		return
	p.leave_plane(plane_pos() + Vector3(0, -4, 0))
	# escolhe uma localidade perto de onde pulou (às vezes um ponto qualquer)
	var here := Vector2(p.position.x, p.position.z)
	var opts := []
	for t in world.towns:
		if here.distance_to(t["pos"]) < 230.0:
			opts.append(t)
	if opts.is_empty() or rng.randf() < 0.2:
		p.b_dest = world.random_point_in(here, 150.0, rng)
	else:
		var t: Dictionary = opts[rng.randi() % opts.size()]
		p.b_dest = world.random_point_in(t["pos"], float(t["r"]) * 0.7, rng)
	p.b_dest_t = 30.0


func _zone_next() -> void:
	var ns := z_stage + 1
	if ns >= ZONES.size():
		return
	var c0 := z_c1 if z_stage >= 0 else Vector2.ZERO
	var r0 := z_r1 if z_stage >= 0 else ZONE_R0
	var zr: float = ZONES[ns][2]
	var maxoff := maxf(r0 - zr, 0.0) * 0.85
	var a := rng.randf() * TAU
	var c1 := c0 + Vector2(cos(a), sin(a)) * sqrt(rng.randf()) * maxoff
	var lim := maxf(World.PLAY - zr - 15.0, 0.0)
	c1 = c1.clamp(Vector2(-lim, -lim), Vector2(lim, lim))
	# o centro final não fica dentro da lagoa
	if c1.distance_to(World.LAKE_C) < World.LAKE_R:
		c1 = World.LAKE_C + (c1 - World.LAKE_C).normalized() * (World.LAKE_R + 5.0)
	_all("zone_set", [ns, c0, r0, c1, zr, ZONES[ns][0], ZONES[ns][1], ZONES[ns][3], 0.0])


func _check_end() -> void:
	if not multiplayer.is_server() or (phase != PLANE and phase != MATCH):
		return
	if n_start < 2:
		return
	var last := 0
	var n := 0
	for id in players:
		var p: Player = players[id]
		if p.alive and not p.spect:
			n += 1
			last = id
	if n <= 1:
		_all("on_winner", [last])


func _server_reset() -> void:
	for id in players.keys():
		if players[id].is_bot:
			_all("remove_player", [id])
	_all("match_reset", [])
	for id in players:
		_all("on_respawn", [id, world.random_spawn(rng)])
	phase_t = LOBBY_T if not training else 6.0
	if not training and not dedicated:
		phase_t = 120.0
	_all("phase_set", [LOBBY, phase_t])


func server_bot_shot(id: int, origin: Vector3, dirs: Array, wid: String) -> void:
	var p: Player = players.get(id)
	if p == null or not p.alive:
		return
	var w := p.cur_stat()
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
			_acc(dmg, c.pid, w, (r["position"].y - c.position.y) > c.head_y(), 0.75)
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


func _server_damage(vid: int, aid: int, amount: float, head: bool, wid: String, raw := false) -> void:
	if phase == LOBBY or phase == END:
		return
	var v: Player = players.get(vid)
	if v == null or not v.alive or v.spect:
		return
	if not raw:
		if head and v.helmet:
			amount *= 0.6
		if v.armor > 0.0:
			var ab := minf(v.armor, amount * 0.5)
			v.armor -= ab
			amount -= ab
	if v.is_bot and aid != vid and players.has(aid):
		v.b_target = aid
		v.b_react = minf(v.b_react, 0.3)
	if info.has(aid) and aid != vid:
		info[aid]["dmg"] += amount
	var hp := v.hp - amount
	if hp <= 0.0:
		var rank := _alive_count()
		_server_death_box(v)
		_all("on_died", [vid, aid, wid, head, rank, amount])
		_check_end()
	else:
		_all("on_hp", [vid, hp, v.armor, aid, head, amount])


# Quem morre vira uma caixinha com tudo o que tinha
func _server_death_box(v: Player) -> void:
	var list := []
	for g in v.guns:
		if g["id"] != "" and g["id"] != "glock":
			list.append([g["id"], 1, g["att"].duplicate()])
	for k in v.inv:
		if int(v.inv[k]) > 0:
			list.append([k, int(v.inv[k]), null])
	if v.armor > 0.0:
		list.append(["vest", 1, v.armor])
	if v.helmet:
		list.append(["helmet", 1, null])
	if v.bag:
		list.append(["bag", 1, null])
	if list.is_empty():
		return
	var at := v.position
	var pos := Vector3(at.x, world.height(at.x, at.z) + 0.02, at.z)
	if at.y > pos.y + 0.03 and at.y - pos.y < 7.0:
		pos.y = at.y + 0.02
	_all("spawn_item", [world.items.size(), pos, "box", 1, null, list, v.nick])


func _server_drop(kind: String, at: Vector3, n := 1, extra = null) -> void:
	var a := rng.randf() * TAU
	at += Vector3(cos(a), 0, sin(a)) * 0.9
	var pos := Vector3(at.x, world.height(at.x, at.z) + 0.07, at.z)
	# no chão de casa: usa a altura de onde a pessoa estava
	if at.y > pos.y + 0.03 and at.y - pos.y < 7.0:
		pos.y = at.y + 0.07
	_all("spawn_item", [world.items.size(), pos, kind, n, extra, [], ""])


func _p_inv(p: Player) -> void:
	for k in p.inv.keys():
		if int(p.inv[k]) <= 0:
			p.inv.erase(k)
	_all("on_inv", [p.pid, p.inv.duplicate(), p.armor, p.helmet, p.bag])


func _p_guns(p: Player, sel: int) -> void:
	_all("on_loadout", [p.pid, _guns_net(p), sel])


# Dá um item pro jogador. Devolve quantos ele conseguiu pegar.
func _give(p: Player, kind: String, n: int, extra) -> int:
	if Weapons.is_gun(kind):
		var w := Weapons.get_w(kind)
		var slot := 2
		if int(w["slot"]) != 1:
			if p.guns[0]["id"] == "":
				slot = 0
			elif p.guns[1]["id"] == "":
				slot = 1
			else:
				slot = p.sel if (p.sel == 0 or p.sel == 1) else 0
		var old: Dictionary = p.guns[slot]
		if old["id"] != "" and old["id"] != "glock":
			_server_drop(old["id"], p.position, 1, old["att"].duplicate())
		var att: Array = (extra as Array).duplicate() if extra is Array else []
		for a in Weapons.ATTS:
			if not (a in att) and p.count(a) > 0 and Weapons.fits(a, kind):
				att.append(a)
				p.inv[a] = p.count(a) - 1
		p.guns[slot] = {"id": kind, "att": att}
		p.mag[kind] = Weapons.stat(kind, att)["mag"]
		_p_guns(p, slot)
		_p_inv(p)
		return 1
	if Weapons.is_att(kind):
		for s in [p.sel, 0, 1, 2]:
			if s < 0:
				continue
			var g: Dictionary = p.guns[s]
			if Weapons.fits(kind, g["id"]) and not (kind in g["att"]):
				g["att"].append(kind)
				_p_guns(p, p.sel)
				return 1
		if p.free_slots() > 0:
			p.inv[kind] = p.count(kind) + 1
			_p_inv(p)
			return 1
		return 0
	match kind:
		"vest":
			if p.armor >= 100.0:
				return 0
			p.armor = float(extra) if (extra is float or extra is int) and float(extra) > 0.0 else 100.0
			_p_inv(p)
			return 1
		"helmet":
			if p.helmet:
				return 0
			p.helmet = true
			_p_inv(p)
			return 1
		"bag":
			if p.bag:
				return 0
			p.bag = true
			_p_inv(p)
			return 1
	if not Weapons.ITEMS.has(kind):
		return 0
	# itens que empilham (bandagem, kit)
	var st := Weapons.stack_of(kind)
	var others := {}
	for k in p.inv:
		if k != kind:
			others[k] = p.inv[k]
	var room := (p.capacity() - Weapons.slots_used(others)) * st - p.count(kind)
	var take := clampi(room, 0, n)
	if take <= 0:
		return 0
	p.inv[kind] = p.count(kind) + take
	_p_inv(p)
	return take


func server_pickup(id: int, i: int, sub: int) -> void:
	if phase == LOBBY or phase == END or i < 0 or i >= items_avail.size() or not items_avail[i]:
		return
	var p: Player = players.get(id)
	if p == null or not p.alive or p.spect:
		return
	var it: Dictionary = world.items[i]
	if it["kind"] == "box":
		var list: Array = it.get("list", [])
		var idxs: Array = range(list.size() - 1, -1, -1) if sub < 0 else [sub]
		for j in idxs:
			if j < 0 or j >= list.size():
				continue
			var e: Array = list[j]
			if p.is_bot and not p.wants(e[0]):
				continue
			var got := _give(p, e[0], int(e[1]), e[2])
			if got >= int(e[1]):
				list.remove_at(j)
			elif got > 0:
				e[1] = int(e[1]) - got
		if list.is_empty():
			_all("on_item", [i, false])
		else:
			_all("on_box", [i, list])
		return
	var n: int = it.get("n", 1)
	var got := _give(p, it["kind"], n, it.get("extra", null))
	if got <= 0:
		return
	if got >= n:
		_all("on_item", [i, false])
	else:
		_all("on_item_n", [i, n - got])


func _server_heal(id: int, kind: String) -> void:
	var p: Player = players.get(id)
	if p == null or not p.alive or not Weapons.ITEMS.has(kind) or p.count(kind) <= 0 or p.hp >= 100.0:
		return
	p.inv[kind] = p.count(kind) - 1
	_p_inv(p)
	_all("on_hp", [id, minf(100.0, p.hp + float(Weapons.ITEMS[kind]["heal"])), p.armor, 0, false, 0.0])


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
func st(pos: Vector3, yw: float, pt: float, wid: String, fl: int) -> void:
	if not multiplayer.is_server():
		return
	var p: Player = players.get(_sender())
	if p == null or not p.alive or p.spect:
		return
	if not p.has_gun(wid):
		wid = "fist"
	# só dá pra estar no avião enquanto ele voa
	if (fl & 3) == 3 and phase != PLANE:
		fl = fl & ~3
	p.net_target(pos, yw, pt, wid, fl)


@rpc("any_peer", "call_remote", "reliable")
func req_fire(origin: Vector3, ends: PackedVector3Array, hits: Array, wid: String) -> void:
	if not multiplayer.is_server():
		return
	var id := _sender()
	var p: Player = players.get(id)
	if p == null or not p.alive or p.spect or p.air != 0:
		return
	if not p.has_gun(wid):
		return
	var w := Weapons.stat(wid, p.att_of(wid))
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(last_fire.get(id, -10.0)) < 0.7 / float(w["rate"]):
		return
	last_fire[id] = now
	var head_pos := p.position + Vector3(0, p.head_y(), 0)
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
func req_pickup(i: int, sub: int) -> void:
	if not multiplayer.is_server():
		return
	var id := _sender()
	var p: Player = players.get(id)
	if p == null or i < 0 or i >= world.items.size():
		return
	if p.position.distance_to(world.items[i]["pos"]) > 4.0:
		return
	server_pickup(id, i, sub)


@rpc("any_peer", "call_remote", "reliable")
func req_heal(kind: String) -> void:
	if multiplayer.is_server():
		_server_heal(_sender(), kind)


@rpc("any_peer", "call_remote", "reliable")
func req_drop(kind: String, n: int) -> void:
	if not multiplayer.is_server():
		return
	var p: Player = players.get(_sender())
	if p == null or not p.alive:
		return
	match kind:
		"vest":
			if p.armor <= 0.0:
				return
			_server_drop("vest", p.position, 1, p.armor)
			p.armor = 0.0
		"helmet":
			if not p.helmet:
				return
			_server_drop("helmet", p.position)
			p.helmet = false
		_:
			var c := mini(p.count(kind), maxi(n, 1))
			if c <= 0:
				return
			p.inv[kind] = p.count(kind) - c
			_server_drop(kind, p.position, c)
	_p_inv(p)


@rpc("any_peer", "call_remote", "reliable")
func req_drop_gun(slot: int) -> void:
	if not multiplayer.is_server() or slot < 0 or slot > 2:
		return
	var p: Player = players.get(_sender())
	if p == null or not p.alive or p.guns[slot]["id"] == "":
		return
	var g: Dictionary = p.guns[slot]
	_server_drop(g["id"], p.position, 1, g["att"].duplicate())
	p.guns[slot] = {"id": "", "att": []}
	_p_guns(p, -1 if p.sel == slot else p.sel)


@rpc("any_peer", "call_remote", "reliable")
func req_equip(att: String, slot: int) -> void:
	if not multiplayer.is_server():
		return
	var p: Player = players.get(_sender())
	if p == null or not p.alive or p.count(att) <= 0:
		return
	for s in [slot, 0, 1, 2]:
		if s < 0 or s > 2:
			continue
		var g: Dictionary = p.guns[s]
		if Weapons.fits(att, g["id"]) and not (att in g["att"]):
			g["att"].append(att)
			p.inv[att] = p.count(att) - 1
			_p_guns(p, p.sel)
			_p_inv(p)
			return


@rpc("any_peer", "call_remote", "reliable")
func req_unequip(att: String, slot: int) -> void:
	if not multiplayer.is_server() or slot < 0 or slot > 2:
		return
	var p: Player = players.get(_sender())
	if p == null or not p.alive or not (att in p.guns[slot]["att"]):
		return
	p.guns[slot]["att"].erase(att)
	if p.free_slots() > 0:
		p.inv[att] = p.count(att) + 1
	else:
		_server_drop(att, p.position)
	_p_guns(p, p.sel)
	_p_inv(p)


# ---------------- RPCs: servidor -> todos ----------------

@rpc("authority", "call_remote", "reliable")
func welcome(list: Array, avail: Array, dyn: Array, ns: PackedInt32Array, ph: Array, zn: Array) -> void:
	for d in dyn:
		spawn_item(d[0], d[1], d[2], d[3], d[4], d[5], d[6])
	for i in mini(ns.size(), n_static):
		world.items[i]["n"] = ns[i]
	for e in list:
		add_player(e["id"], e["name"], e["pos"], e["bot"], e["spect"])
		info[e["id"]]["kills"] = e["kills"]
		var p: Player = players[e["id"]]
		on_loadout(e["id"], e["guns"], 0)
		p.hp = e["hp"]
		p.armor = e["armor"]
		p.helmet = e["helmet"]
		p.bag = e["bag"]
		p.air = e["air"]
		p.refresh_gear()
		if not e["alive"]:
			p.die()
	for i in mini(avail.size(), items_avail.size()):
		on_item(i, avail[i])
	plane_a = ph[2]
	plane_b = ph[3]
	plane_t = ph[4]
	plane_dur = ph[5]
	phase_set(ph[0], ph[1])
	if ph[0] == PLANE:
		plane_t = ph[4]
	if int(zn[0]) >= 0:
		zone_set(zn[0], zn[1], zn[2], zn[3], zn[4], zn[5], zn[6], zn[7], zn[8])


@rpc("authority", "call_remote", "reliable")
func add_player(id: int, nick: String, pos: Vector3, bot: bool, spect: bool) -> void:
	if players.has(id):
		return
	info[id] = {"name": nick, "kills": 0, "dmg": 0.0, "bot": bot}
	var p := Player.new()
	p.name = "P%d" % id
	p.setup(self, id, nick, id == local_id and not dedicated, bot, not dedicated)
	p.position = pos
	players_root.add_child(p)
	players[id] = p
	if spect:
		p.spect = true
		p.die()
		if id == local_id and hud:
			hud.center("A partida já começou.\nVocê está assistindo; entra na próxima.", 5.0)
	if phase == PLANE and not spect:
		p.board()
	if hud and id != local_id and not bot:
		hud.feed("%s entrou" % nick)


@rpc("authority", "call_remote", "reliable")
func remove_player(id: int) -> void:
	if players.has(id):
		players[id].queue_free()
		players.erase(id)
	if info.has(id):
		if hud and not info[id]["bot"]:
			hud.feed("%s saiu" % info[id]["name"])
		info.erase(id)


@rpc("authority", "call_remote", "unreliable_ordered")
func snap(buf: PackedByteArray) -> void:
	var o := 0
	while o + 22 <= buf.size():
		var id := buf.decode_s32(o)
		if id != local_id:
			var p: Player = players.get(id)
			if p:
				var pos := Vector3(buf.decode_float(o + 4), buf.decode_float(o + 8), buf.decode_float(o + 12))
				var wi := buf.decode_u8(o + 20)
				p.net_target(pos, buf.decode_s16(o + 16) / 10000.0, buf.decode_s16(o + 18) / 20000.0, WIDS[wi] if wi < WIDS.size() else "fist", buf.decode_u8(o + 21))
		o += 22


@rpc("authority", "call_remote", "unreliable")
func fx_shot(id: int, ends: PackedVector3Array, wid: String) -> void:
	if dedicated or id == local_id:
		return
	var p: Player = players.get(id)
	if p:
		_shot_fx(p, ends, wid, false)


@rpc("authority", "call_remote", "reliable")
func phase_set(ph: int, t: float) -> void:
	var old := phase
	phase = ph
	phase_t = t
	if ph == PLANE:
		plane_t = t
	if ph == MATCH:
		match_time = 0.0
	if hud == null or old == ph:
		return
	match ph:
		LOBBY:
			if old == END or old == LOBBY:
				hud.center("Nova partida!\nAqui ninguém se machuca. Aquece a mira.", 4.0)
		PLANE:
			hud.big_map = false
			hud.set_bag(false)
			hud.center("No avião! Escolha onde saltar.\nToque no mapa (canto) pra ver a rota.", 4.0)


@rpc("authority", "call_remote", "reliable")
func plane_set(a: Vector3, b: Vector3, dur: float) -> void:
	plane_a = a
	plane_b = b
	plane_dur = dur
	plane_t = 0.0
	var d := b - a
	for id in players:
		var p: Player = players[id]
		if p.alive and not p.spect:
			p.board()
			if id == local_id:
				cam_yaw_v = atan2(-d.x, -d.z)
				cam_pitch_v = -0.3


@rpc("authority", "call_remote", "reliable")
func zone_set(stage: int, c0: Vector2, r0: float, c1: Vector2, r1: float, wait: float, shrink: float, dmg: float, t: float) -> void:
	z_stage = stage
	z_c0 = c0
	z_r0 = r0
	z_c1 = c1
	z_r1 = r1
	z_wait = wait
	z_shrink = shrink
	z_dmg = dmg
	z_t = t
	if hud and stage > 0:
		hud.center("A zona vai fechar! Veja o círculo branco no mapa.", 3.0)
		sfx("zone")


@rpc("authority", "call_remote", "reliable")
func on_hp(vid: int, hp: float, armor: float, aid: int, head: bool, amount: float) -> void:
	var v: Player = players.get(vid)
	var old := 100.0
	if v:
		old = v.hp
		v.hp = hp
		v.armor = armor
		v.refresh_gear()
	if hud == null:
		return
	if hp > old and vid == local_id:
		sfx("heal_done")
	if hp < old:
		if aid == local_id and vid != local_id:
			hud.hit(head, false)
			sfx("headshot" if head else "hit", -6.0)
			if v:
				hud.dmg_number(v.position, amount, head, false)
		if vid == local_id:
			sfx("hurt", -4.0)
			var a: Player = players.get(aid)
			if a and v:
				var d := a.position - v.position
				var wy := atan2(-d.x, -d.z)
				hud.hurt(-angle_difference(cam_yaw_v, wy))
			else:
				hud.hurt()
				if aid == 0:
					sfx("zone", -8.0)


@rpc("authority", "call_remote", "reliable")
func on_died(vid: int, aid: int, wid: String, head: bool, rank: int, amount: float) -> void:
	var v: Player = players.get(vid)
	var vpos := v.position if v else Vector3.ZERO
	if v:
		v.die()
	if info.has(aid) and aid != vid:
		info[aid]["kills"] += 1
	if hud == null:
		return
	var kn: String = info[aid]["name"] if info.has(aid) else "?"
	var vn: String = info[vid]["name"] if info.has(vid) else "?"
	var mine := aid == local_id or vid == local_id
	var col := Color(1, 0.85, 0.35) if mine else Color.WHITE
	if wid == "zona" or aid == 0:
		hud.feed("%s morreu na zona" % vn, col)
	else:
		hud.feed("%s  [%s%s]  %s" % [kn, Weapons.get_w(wid)["name"], " · cabeça" if head else "", vn], col)
	if aid == local_id and vid != local_id:
		hud.hit(head, true)
		sfx("kill", -2.0)
		hud.dmg_number(vpos, amount, head, true)
		hud.center("Você eliminou %s" % vn, 2.0)
	if vid == local_id:
		my_rank = rank
		hud.hurt()
		hud.big_map = false
		hud.set_bag(false)
		spec_id = aid if players.has(aid) and aid != vid else 0
		if spec_id == 0:
			_spec_next()
		var me = info.get(local_id)
		var why := "na zona" if (wid == "zona" or aid == 0) else "por %s" % kn
		hud.center("Eliminado %s\nColocação: #%d    Abates: %d    Dano: %d" % [why, rank, me["kills"] if me else 0, int(me["dmg"]) if me else 0], 7.0)
	elif vid == spec_id:
		get_tree().create_timer(2.0).timeout.connect(func():
			if players.has(spec_id) and not players[spec_id].alive:
				_spec_next())


@rpc("authority", "call_remote", "reliable")
func on_winner(id: int) -> void:
	phase = END
	phase_t = 15.0
	winner = id
	if hud == null:
		if dedicated:
			print("[servidor] vencedor: %s" % (info[id]["name"] if info.has(id) else "ninguém"))
		return
	hud.can_retry = training
	hud.big_map = false
	hud.set_bag(false)
	var me = info.get(local_id)
	var k: int = me["kills"] if me else 0
	var dmg: int = int(me["dmg"]) if me else 0
	if id == local_id:
		hud.center("VITÓRIA!\nVocê é o último de pé!\nAbates: %d    Dano: %d" % [k, dmg], 999.0)
		sfx("kill")
	else:
		var wn: String = info[id]["name"] if info.has(id) else "Ninguém"
		var lp: Player = players.get(local_id)
		var rk := "" if lp == null or lp.spect else "\nVocê ficou em #%d    Abates: %d    Dano: %d" % [my_rank, k, dmg]
		hud.center("%s venceu a partida!%s" % [wn, rk], 999.0)


@rpc("authority", "call_remote", "reliable")
func match_reset() -> void:
	phase = LOBBY
	z_stage = -1
	z_r1 = ZONE_R0
	z_c1 = Vector2.ZERO
	z_t = 0.0
	plane_t = 0.0
	winner = 0
	my_rank = 0
	spec_id = 0
	match_time = 0.0
	n_start = 0
	for i in range(world.items.size() - 1, n_static - 1, -1):
		if i < item_nodes.size() and item_nodes[i]:
			item_nodes[i].queue_free()
	world.items.resize(n_static)
	items_avail.resize(n_static)
	item_nodes.resize(mini(item_nodes.size(), n_static))
	for i in n_static:
		world.items[i]["n"] = Weapons.default_count(world.items[i]["kind"])
		on_item(i, true)
	for id in info:
		info[id]["kills"] = 0
		info[id]["dmg"] = 0.0
	auto_tried = {}
	if hud:
		hud.center("", 0.0)
		hud.can_retry = false


@rpc("authority", "call_remote", "reliable")
func on_respawn(id: int, pos: Vector3) -> void:
	var p: Player = players.get(id)
	if p:
		p.reset_state(pos)
	if id == local_id:
		_seen_guns = ["", "", "glock"]
		_seen_inv = {}
		_seen_gear = [0.0, false, false]


@rpc("authority", "call_remote", "reliable")
func on_loadout(id: int, g: Array, sel: int) -> void:
	var p: Player = players.get(id)
	if p == null:
		return
	var new_ids := []
	for i in 3:
		var gid: String = g[i][0]
		if gid != "" and gid != p.guns[i]["id"]:
			new_ids.append(gid)
		p.guns[i] = {"id": gid, "att": (g[i][1] as Array).duplicate()}
	for gid in new_ids:
		p.mag[gid] = Weapons.stat(gid, p.att_of(gid))["mag"]
	if id == local_id or p.is_bot:
		if sel >= -1 and sel <= 2:
			p.sel = sel if (sel < 0 or p.guns[sel]["id"] != "") else -1
		if p.sel >= 0 and p.guns[p.sel]["id"] == "":
			p.sel = -1
		p.reload_t = 0.0
		p.scoped = false
	p.update_gun()
	if id == local_id and hud:
		# compara com o que eu já tinha visto (no treino o servidor muda o jogador antes)
		for i in 3:
			var gid: String = g[i][0]
			if gid != "" and gid != _seen_guns[i]:
				hud.center(Weapons.item_name(gid), 1.2)
			_seen_guns[i] = gid
		sfx("equip", -4.0)


@rpc("authority", "call_remote", "reliable")
func on_inv(id: int, inv: Dictionary, armor: float, helmet: bool, bag: bool) -> void:
	var p: Player = players.get(id)
	if p == null:
		return
	if id == local_id and hud:
		var gained: bool = (armor > float(_seen_gear[0]) + 1.0) or (helmet and not _seen_gear[1]) or (bag and not _seen_gear[2])
		for k in inv:
			if int(inv[k]) > int(_seen_inv.get(k, 0)):
				gained = true
		if gained:
			sfx("pickup", -3.0)
		if armor >= 99.0 and float(_seen_gear[0]) < 99.0:
			hud.center("Colete equipado", 1.2)
		elif helmet and not _seen_gear[1]:
			hud.center("Capacete equipado", 1.2)
		elif bag and not _seen_gear[2]:
			hud.center("Mochila grande: 16 vagas", 1.5)
		_seen_inv = inv.duplicate()
		_seen_gear = [armor, helmet, bag]
	p.inv = inv
	p.armor = armor
	p.helmet = helmet
	p.bag = bag
	p.refresh_gear()


@rpc("authority", "call_remote", "reliable")
func on_item(i: int, avail: bool) -> void:
	if i < 0 or i >= items_avail.size():
		return
	items_avail[i] = avail
	if i < item_nodes.size() and item_nodes[i]:
		item_nodes[i].visible = avail


@rpc("authority", "call_remote", "reliable")
func on_item_n(i: int, n: int) -> void:
	if i >= 0 and i < world.items.size():
		world.items[i]["n"] = n


@rpc("authority", "call_remote", "reliable")
func on_box(i: int, list: Array) -> void:
	if i >= 0 and i < world.items.size():
		world.items[i]["list"] = list


@rpc("authority", "call_remote", "reliable")
func spawn_item(i: int, pos: Vector3, kind: String, n: int, extra, list: Array, nm: String) -> void:
	var it := {"pos": pos, "kind": kind, "n": n, "extra": extra, "list": list.duplicate(true), "name": nm, "door_out": null, "door_in": null, "up": false}
	while world.items.size() < i:
		world.items.append({"pos": Vector3(0, -500, 0), "kind": "med", "n": 0, "door_out": null, "door_in": null})
		items_avail.append(false)
	if i < world.items.size():
		world.items[i] = it
		items_avail[i] = true
	else:
		world.items.append(it)
		items_avail.append(true)
	if not dedicated:
		_make_item_node(i)
