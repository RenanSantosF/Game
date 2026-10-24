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
const PLANE_SPEED := 18.0
const LOBBY_T := 45.0
const PLANE_OUT := 220.0     # metros de voo fora do mapa antes e depois
# espera, tempo fechando, raio final, dano por segundo
const ZONES := [
	[90.0, 60.0, 300.0, 3.0], [60.0, 45.0, 180.0, 6.0], [50.0, 35.0, 105.0, 10.0], [40.0, 30.0, 60.0, 16.0],
	[30.0, 25.0, 30.0, 22.0], [20.0, 20.0, 12.0, 30.0], [15.0, 15.0, 0.0, 44.0],
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
var map_editing := false
var sandbox := false        # editor: jogando no mapa com tudo liberado (vida e munição sem fim)
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
var _was_firing := false
var regen_t := 0.0
var vehicles: Array = []
var _veh_send_t := 0.0
var _shake := 0.0
var grenades: Array = []
var _runover_t := {}
var _snap_q: Array = []
var menu_stage: Node3D
var join_box: PanelContainer
var menu_cubes: Array = []
var menu_t := 0.0
var load_bar: ProgressBar
var load_lbl: Label
var menu_sol: Soldier
var menu_music: AudioStreamPlayer
var menu_theme := 0
var menu_fire: OmniLight3D
var menu_flame: MeshInstance3D
var menu_news: Label
const NEWS := [
	"COMEÇO DE GUERRA: cidades no alto do morro, ruas destruídas e barricadas",
	"Caixotes militares guardam armas em cima — fique de olho",
	"Carros novos: bater faz barulho, mas só tiro causa dano",
	"Toque no analógico para parar a corrida automática",
	"Use as barricadas e sacos de areia da subida para se proteger",
	"Kit médico: enrole o braço e espere a vida encher",
]
var menu_aim: Node3D
var menu_gun: Node3D
var menu_rot_v := 0.0
var menu_hold := 0.0     # itens pra encostar no chão (raio pra baixo), alguns por quadro
var _heal_snd := 0
var _pain_snd := 0
var _shot_pending := false
var _empty_done := false
var _press_t := 0.0
var _snap_t := 0.0
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
var alive_cached := 50     # vivos (atualizado no servidor a cada quadro; os bots usam)
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
var _seen_guns := ["", "", ""]
var _seen_inv := {}
var _seen_gear := [0, 0, 0, 0.0]


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

# Menu no estilo dos battle royale de celular: boneco no meio de um palco, menu à esquerda,
# perfil em cima e o botão INICIAR grande embaixo à direita
func _build_menu() -> void:
	_build_menu_stage()
	_menu_music_on()
	menu = CanvasLayer.new()
	add_child(menu)
	var drag := Control.new()
	drag.set_anchors_preset(Control.PRESET_FULL_RECT)
	drag.mouse_filter = Control.MOUSE_FILTER_PASS
	drag.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseMotion and (ev.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			menu_rot_v = ev.relative.x * 0.012
			menu_hold = 1.5
		elif ev is InputEventScreenDrag:
			menu_rot_v = ev.relative.x * 0.012
			menu_hold = 1.5)
	menu.add_child(drag)
	# perfil (canto superior esquerdo)
	var prof := PanelContainer.new()
	prof.add_theme_stylebox_override("panel", _menu_box(Color(0.02, 0.05, 0.12, 0.7), 8))
	prof.position = Vector2(14, 12)
	menu.add_child(prof)
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 10)
	prof.add_child(ph)
	var av := Control.new()
	av.custom_minimum_size = Vector2(54, 54)
	av.draw.connect(func():
		av.draw_rect(Rect2(Vector2.ZERO, av.size), Color(1, 0.72, 0.2))
		Hud.glyph(av, "sprint", av.size / 2.0, 20.0, Color(0.1, 0.08, 0.05)))
	ph.add_child(av)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 2)
	ph.add_child(pv)
	nick_edit = _menu_edit("Seu apelido")
	nick_edit.custom_minimum_size = Vector2(220, 34)
	nick_edit.add_theme_font_size_override("font_size", 18)
	nick_edit.add_theme_stylebox_override("normal", _menu_box(Color(1, 1, 1, 0.06), 4))
	nick_edit.add_theme_stylebox_override("focus", _menu_box(Color(1, 1, 1, 0.12), 4))
	pv.add_child(nick_edit)
	nick_edit.text = Cfg.get_v("nick")
	if nick_edit.text == "":
		nick_edit.text = "Jogador%d" % rng.randi_range(100, 999)
	var lv := _menu_label("toque no nome pra mudar", 12)
	lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lv.modulate = Color(1, 1, 1, 0.6)
	pv.add_child(lv)
	# logo (canto superior direito)
	var title := _menu_label("CONFRONTO", 40)
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.15, 0.8))
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.anchor_left = 1.0
	title.anchor_right = 1.0
	title.offset_left = -420
	title.offset_right = -80
	title.offset_top = 10
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	menu.add_child(title)
	var gear := _menu_icon_btn("gear", func(): open_settings())
	gear.anchor_left = 1.0
	gear.anchor_right = 1.0
	gear.offset_left = -66
	gear.offset_right = -14
	gear.offset_top = 14
	gear.offset_bottom = 66
	menu.add_child(gear)
	# menu da esquerda
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	left.position = Vector2(14, 104)
	menu.add_child(left)
	left.add_child(_menu_side("play", "TREINO", func(): start_host(false)))
	left.add_child(_menu_side("home", "SALA NO WI-FI", func(): start_host(true)))
	left.add_child(_menu_side("next", "ENTRAR NA SALA", func(): join_box.visible = not join_box.visible))
	left.add_child(_menu_side("hand", "CONTROLES", func():
		open_settings()
		settings.edit_buttons.emit()))
	left.add_child(_menu_side("gear", "CONFIGURAÇÕES", func(): open_settings()))
	left.add_child(_menu_side("hand", "EDITAR MAPA", func(): start_editor()))
	var rep := _last_log()
	if rep != "" and _crashed_loading(rep) and int(Cfg.get_v("quality")) > 0:
		Cfg.set_v("quality", 0)
		flash_msg = "Da última vez o jogo fechou ao carregar o mapa. Mudei os gráficos para BAIXA."
	if rep != "":
		left.add_child(_menu_side("reset", "RELATÓRIO", func(): _show_report(rep)))
	# novidades que vão trocando (canto inferior esquerdo)
	var news := PanelContainer.new()
	news.add_theme_stylebox_override("panel", _menu_box(Color(0.02, 0.05, 0.12, 0.7), 8))
	news.anchor_top = 1.0
	news.anchor_bottom = 1.0
	news.offset_left = 14
	news.offset_right = 470
	news.offset_top = -150
	news.offset_bottom = -84
	menu.add_child(news)
	var nv := VBoxContainer.new()
	news.add_child(nv)
	var nt := _menu_label("NOVIDADES · TEMPORADA COMEÇO DE GUERRA", 13)
	nt.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	nt.add_theme_color_override("font_color", Color(1.0, 0.78, 0.25))
	nv.add_child(nt)
	menu_news = _menu_label(NEWS[0], 16)
	menu_news.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	menu_news.autowrap_mode = TextServer.AUTOWRAP_WORD
	nv.add_child(menu_news)
	# caixinha de IP (abre pelo "ENTRAR NA SALA")
	join_box = PanelContainer.new()
	join_box.add_theme_stylebox_override("panel", _menu_box(Color(0.02, 0.05, 0.12, 0.85), 8))
	join_box.position = Vector2(250, 214)
	join_box.visible = false
	menu.add_child(join_box)
	var jh := HBoxContainer.new()
	jh.add_theme_constant_override("separation", 8)
	join_box.add_child(jh)
	ip_edit = _menu_edit("IP do servidor")
	ip_edit.custom_minimum_size = Vector2(240, 48)
	ip_edit.text = Cfg.get_v("ip")
	jh.add_child(ip_edit)
	var jb := _menu_btn("ENTRAR", func(): start_join(ip_edit.text.strip_edges()))
	jb.custom_minimum_size = Vector2(120, 48)
	jh.add_child(jb)
	# modo + INICIAR (canto inferior direito)
	var mode := PanelContainer.new()
	mode.add_theme_stylebox_override("panel", _menu_box(Color(0.02, 0.06, 0.16, 0.8), 8))
	mode.anchor_left = 1.0
	mode.anchor_right = 1.0
	mode.anchor_top = 1.0
	mode.anchor_bottom = 1.0
	mode.offset_left = -364
	mode.offset_right = -14
	mode.offset_top = -190
	mode.offset_bottom = -120
	menu.add_child(mode)
	var mv := VBoxContainer.new()
	mode.add_child(mv)
	var m1 := _menu_label("BATTLE ROYALE", 22)
	m1.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	m1.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	mv.add_child(m1)
	var m2 := _menu_label("Treino · você + 49 bots · último de pé vence", 14)
	m2.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	m2.modulate = Color(1, 1, 1, 0.75)
	mv.add_child(m2)
	var play := _menu_btn("INICIAR", func(): start_host(false))
	play.custom_minimum_size = Vector2(350, 96)
	play.add_theme_font_size_override("font_size", 42)
	_style_btn(play, Color(1.0, 0.78, 0.1), Color(1.0, 0.9, 0.4))
	play.anchor_left = 1.0
	play.anchor_right = 1.0
	play.anchor_top = 1.0
	play.anchor_bottom = 1.0
	play.offset_left = -364
	play.offset_right = -14
	play.offset_top = -112
	play.offset_bottom = -16
	menu.add_child(play)
	status_lbl = _menu_label(flash_msg, 15)
	status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	status_lbl.anchor_top = 1.0
	status_lbl.anchor_bottom = 1.0
	status_lbl.offset_left = 14
	status_lbl.offset_right = 520
	status_lbl.offset_top = -70
	status_lbl.offset_bottom = -16
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	menu.add_child(status_lbl)
	var hint := _menu_label("arraste pra girar o personagem", 13)
	hint.modulate = Color(1, 1, 1, 0.6)
	hint.anchor_left = 0.5
	hint.anchor_right = 0.5
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = -150
	hint.offset_right = 150
	hint.offset_top = -34
	hint.offset_bottom = -12
	menu.add_child(hint)
	flash_msg = ""


func _menu_box(c: Color, rad: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(rad)
	sb.set_content_margin_all(8)
	sb.border_color = Color(0.4, 0.7, 1.0, 0.35)
	sb.set_border_width_all(1)
	return sb


func _menu_side(icon: String, t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = "        " + t
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(220, 52)
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_color_override("font_color", Color(1, 0.88, 0.5))
	b.focus_mode = Control.FOCUS_NONE
	var n := _menu_box(Color(0.02, 0.05, 0.12, 0.72), 6)
	n.border_width_left = 4
	n.border_color = Color(1, 0.72, 0.2, 0.9)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", n)
	var pr := _menu_box(Color(1, 0.72, 0.2, 0.35), 6)
	b.add_theme_stylebox_override("pressed", pr)
	var g := Control.new()
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.position = Vector2(10, 10)
	g.size = Vector2(32, 32)
	g.draw.connect(func(): Hud.glyph(g, icon, Vector2(16, 16), 11.0, Color(1, 0.85, 0.45)))
	b.add_child(g)
	b.pressed.connect(cb)
	return b


func _menu_icon_btn(icon: String, cb: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	var n := _menu_box(Color(0.02, 0.05, 0.12, 0.72), 26)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", n)
	b.add_theme_stylebox_override("pressed", _menu_box(Color(1, 0.72, 0.2, 0.35), 26))
	var g := Control.new()
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.set_anchors_preset(Control.PRESET_FULL_RECT)
	g.draw.connect(func(): Hud.glyph(g, icon, g.size / 2.0, 13.0, Color.WHITE))
	b.add_child(g)
	b.pressed.connect(cb)
	return b


func _style_btn(b: Button, c: Color, hc: Color) -> void:
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = hc if st == "pressed" else c
		sb.set_corner_radius_all(10)
		sb.set_border_width_all(2)
		sb.border_color = Color(1, 1, 1, 0.5)
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_size = 6
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", Color(0.12, 0.08, 0.02))
	b.add_theme_color_override("font_pressed_color", Color(0.12, 0.08, 0.02))
	b.add_theme_color_override("font_hover_color", Color(0.12, 0.08, 0.02))


# Cenário do menu: palco de piso quadriculado, céu claro e cubos flutuando
func _build_menu_stage() -> void:
	menu_stage = Node3D.new()
	add_child(menu_stage)
	# cada vez que abre o menu, um cenário diferente
	# (a arena de cubos acesos saiu: parecia de brinquedo) — base ao pôr do sol ou acampamento à noite
	menu_theme = randi() % 2   # dia claro ou pôr do sol (a noite deixava o menu triste)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--menu-theme="):
			menu_theme = int(a.get_slice("=", 1)) % 3
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	var sky_cols := [
		[Color(0.18, 0.45, 0.9), Color(0.7, 0.88, 1.0), Color(0.55, 0.75, 0.95), Color(0.2, 0.35, 0.6)],    # arena
		[Color(0.25, 0.3, 0.6), Color(1.0, 0.62, 0.35), Color(0.75, 0.5, 0.35), Color(0.25, 0.2, 0.2)],     # pôr do sol
		[Color(0.02, 0.04, 0.12), Color(0.12, 0.18, 0.32), Color(0.08, 0.1, 0.16), Color(0.02, 0.03, 0.06)],  # noite
	]
	var sc: Array = sky_cols[menu_theme]
	sm.sky_top_color = sc[0]
	sm.sky_horizon_color = sc[1]
	sm.ground_horizon_color = sc[2]
	sm.ground_bottom_color = sc[3]
	sm.sky_curve = 0.12
	sky.sky_material = sm
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = [Color(0.7, 0.8, 0.95), Color(0.95, 0.75, 0.6), Color(0.35, 0.45, 0.7)][menu_theme]
	env.ambient_light_energy = [0.75, 0.6, 0.55][menu_theme]
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.2
	env.adjustment_contrast = 1.08
	if menu_theme == 1:
		env.fog_enabled = true
		env.fog_light_color = Color(1.0, 0.7, 0.45)
		env.fog_density = 0.008
	var we := WorldEnvironment.new()
	we.environment = env
	menu_stage.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = [Vector3(-35, -25, 0), Vector3(-12, -60, 0), Vector3(-50, 30, 0)][menu_theme]
	sun.light_color = [Color(1.0, 0.97, 0.9), Color(1.0, 0.66, 0.38), Color(0.55, 0.65, 1.0)][menu_theme]
	sun.light_energy = [1.1, 1.3, 0.45][menu_theme]
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 20.0
	menu_stage.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-10, 160, 0)
	rim.light_color = [Color(0.5, 0.8, 1.0), Color(0.6, 0.7, 1.0), Color(1.0, 0.55, 0.25)][menu_theme]
	rim.light_energy = [0.8, 0.5, 1.1][menu_theme]
	menu_stage.add_child(rim)
	var m := MB.new()
	var r := RandomNumberGenerator.new()
	r.seed = 7 + menu_theme
	menu_cubes.clear()
	menu_fire = null
	menu_flame = null
	match menu_theme:
		0:
			_menu_arena(m, r)
		1:
			_menu_base(m, r)
		2:
			_menu_night(m, r)
	var floor_mi := MeshInstance3D.new()
	floor_mi.mesh = m.commit()
	floor_mi.material_override = U.wmat()
	menu_stage.add_child(floor_mi)
	# boneco
	menu_sol = Soldier.new()
	menu_stage.add_child(menu_sol)
	var rr := RandomNumberGenerator.new()
	rr.seed = hash(Cfg.get_v("nick"))
	menu_sol.setup(Player.SKINS[rr.randi() % Player.SKINS.size()], Player.SHIRTS[rr.randi() % Player.SHIRTS.size()], Player.PANTS[rr.randi() % Player.PANTS.size()], Player.BOOTS[0], Player.HAIRS[rr.randi() % Player.HAIRS.size()])
	var cam := Camera3D.new()
	cam.fov = 38.0
	cam.position = Vector3(0, 1.15, 5.2)
	menu_stage.add_child(cam)
	cam.look_at(Vector3(0, 0.95, 0), Vector3.UP)
	cam.current = true
	menu_sol.rotation.y = PI


# cenário 1: arena de placas acesas com cubos flutuando
func _menu_arena(m: MB, r: RandomNumberGenerator) -> void:
	# piso de placas com bordas acesas
	m.tex(U.PLAIN, 1.0)
	for gx in range(-6, 7):
		for gz in range(-8, 4):
			var h := 0.0 if (absi(gx) <= 1 and gz >= -1 and gz <= 1) else r.randf_range(-0.25, 0.05)
			var c := Color(0.07, 0.17, 0.32).lerp(Color(0.12, 0.28, 0.48), r.randf())
			m.box(Transform3D(Basis(), Vector3(gx * 1.6, h - 0.2, gz * 1.6)), Vector3(1.52, 0.4, 1.52), c)
			m.box(Transform3D(Basis(), Vector3(gx * 1.6, h + 0.005, gz * 1.6 - 0.76)), Vector3(1.52, 0.01, 0.04), Color(0.35, 0.8, 1.0))
			m.box(Transform3D(Basis(), Vector3(gx * 1.6 - 0.76, h + 0.005, gz * 1.6)), Vector3(0.04, 0.01, 1.52), Color(0.35, 0.8, 1.0))
	# disco de destaque embaixo do boneco
	m.cyl(Transform3D(Basis(), Vector3(0, 0.0, 0)), 1.1, 1.1, 0.03, 32, Color(1.0, 0.75, 0.25))
	m.cyl(Transform3D(Basis(), Vector3(0, 0.02, 0)), 0.95, 0.95, 0.03, 32, Color(0.1, 0.2, 0.35))
	# cubos flutuando (vidro colorido e caixas)
	var cubes := [[Vector3(-5.5, 2.8, -6), 2.6, Color(0.2, 0.9, 0.8, 0.35)], [Vector3(6.0, 3.6, -7), 3.2, Color(1.0, 0.45, 0.8, 0.35)],
		[Vector3(-3.2, 1.2, -3.5), 0.7, Color(0.85, 0.65, 0.4, 1.0)], [Vector3(3.6, 0.9, -2.8), 0.5, Color(0.6, 0.4, 0.95, 0.8)],
		[Vector3(-8.0, 5.5, -10), 3.8, Color(0.4, 0.75, 1.0, 0.3)], [Vector3(2.4, 4.2, -5), 0.6, Color(0.85, 0.65, 0.4, 1.0)]]
	for cb in cubes:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE * float(cb[1])
		mi.mesh = bm
		var mat := StandardMaterial3D.new()
		var col: Color = cb[2]
		mat.albedo_color = col
		if col.a < 1.0:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.emission_enabled = true
			mat.emission = Color(col.r, col.g, col.b) * 0.35
		mi.material_override = mat
		mi.position = cb[0]
		mi.rotation = Vector3(r.randf() * TAU, r.randf() * TAU, 0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		menu_stage.add_child(mi)
		menu_cubes.append([mi, cb[0], r.randf() * TAU])


# cenário 2: começo de guerra ao pôr do sol (sacos de areia, barricada, caixote com arma, picape)
func _menu_base(m: MB, r: RandomNumberGenerator) -> void:
	m.tex(U.DIRT, 0.3)
	m.box(Transform3D(Basis(), Vector3(0, -0.2, -6)), Vector3(40, 0.4, 30), Color(0.75, 0.62, 0.48))
	m.tex(U.CONCRETE, 0.5)
	m.cyl(Transform3D(Basis(), Vector3(0, 0.0, 0)), 1.1, 1.1, 0.04, 24, Color(0.62, 0.6, 0.56))
	# sacos de areia em meia-lua atrás
	m.tex(U.FABRIC, 1.5)
	for k in 13:
		var a := lerpf(-1.1, 1.1, k / 12.0)
		for row in 3:
			var p := Vector3(sin(a) * 3.4, 0.18 + row * 0.3, -cos(a) * 3.4 - 1.6)
			m.blob(Transform3D(Basis(Vector3.UP, -a).scaled(Vector3(0.36, 0.17, 0.26)), p + Vector3(0.12 * (row % 2), 0, 0)), 6, 3, Color(0.72, 0.64, 0.48).darkened(r.randf() * 0.2))
	# barricadas em X
	for bx in [-4.6, 5.0]:
		for i in 3:
			var x: float = bx + (i - 1) * 0.7
			for sg in [-1.0, 1.0]:
				m.tex(U.WOOD, 0.6)
				m.box(Transform3D(Basis(Vector3.RIGHT, sg * 0.72).rotated(Vector3.UP, 0.4 * signf(bx)), Vector3(x, 0.62, -4.5)), Vector3(0.13, 1.55, 0.13), Color(0.55, 0.42, 0.3))
		m.box(Transform3D(Basis(Vector3.UP, 0.4 * signf(bx)), Vector3(bx, 0.62, -4.5)), Vector3(2.2, 0.14, 0.14), Color(0.45, 0.34, 0.24))
	# caixotes militares
	m.tex(U.WOOD, 0.7)
	m.box(Transform3D(Basis(Vector3.UP, 0.3), Vector3(-2.1, 0.42, -1.4)), Vector3(1.6, 0.85, 1.1), Color(0.5, 0.56, 0.38))
	m.box(Transform3D(Basis(Vector3.UP, -0.2), Vector3(2.3, 0.3, -1.6)), Vector3(1.0, 0.6, 0.9), Color(0.48, 0.54, 0.36))
	m.box(Transform3D(Basis(Vector3.UP, -0.2), Vector3(2.4, 0.9, -1.65)), Vector3(0.8, 0.6, 0.8), Color(0.55, 0.6, 0.42))
	var gun := Weapons.build_item("ak47", false)
	gun.position = Vector3(-2.1, 0.88, -1.4)
	gun.rotation = Vector3(0, 0.9, PI / 2.0)
	menu_stage.add_child(gun)
	var car := Vehicle.prop_node(1, Vehicle.car_material(Color(0.35, 0.38, 0.28), 0.6, 0.3))
	car.position = Vector3(4.5, 0, -6.5)
	car.rotation.y = 2.4
	menu_stage.add_child(car)
	# morros ao fundo com árvores
	m.tex(U.GRASS, 0.2)
	for k in 7:
		m.blob(Transform3D(Basis.from_scale(Vector3(r.randf_range(8, 14), r.randf_range(2.5, 5.0), 6)), Vector3(-24 + k * 8.0, -0.5, -22 - r.randf() * 6.0)), 10, 5, Color(0.55, 0.5, 0.35))
	for k in 8:
		_menu_tree(["oak", "tall"][k % 2], Vector3(-18 + k * 5.0 + r.randf_range(-1, 1), 0, -12 - r.randf() * 4.0), r)


# cenário 3: acampamento à noite (fogueira, holofote, carcaça de carro)
func _menu_night(m: MB, r: RandomNumberGenerator) -> void:
	m.tex(U.GRASS, 0.3)
	m.box(Transform3D(Basis(), Vector3(0, -0.2, -6)), Vector3(40, 0.4, 30), Color(0.35, 0.42, 0.3))
	m.tex(U.CONCRETE, 0.5)
	m.cyl(Transform3D(Basis(), Vector3(0, 0.0, 0)), 1.1, 1.1, 0.04, 24, Color(0.4, 0.4, 0.42))
	# fogueira
	var fp := Vector3(-2.3, 0, -2.2)
	m.tex(U.ROCK, 0.6)
	for k in 8:
		var a := TAU * k / 8.0
		m.blob(Transform3D(Basis.from_scale(Vector3(0.14, 0.09, 0.14)), fp + Vector3(cos(a) * 0.36, 0.04, sin(a) * 0.36)), 6, 3, Color(0.5, 0.5, 0.5))
	m.tex(U.WOOD, 0.6)
	for k in 4:
		m.box(Transform3D(Basis(Vector3.UP, k * 0.8) * Basis(Vector3.RIGHT, 1.2), fp + Vector3(0, 0.1, 0)), Vector3(0.07, 0.55, 0.07), Color(0.3, 0.2, 0.12))
	menu_fire = OmniLight3D.new()
	menu_fire.light_color = Color(1.0, 0.55, 0.2)
	menu_fire.light_energy = 2.2
	menu_fire.omni_range = 7.0
	menu_fire.position = fp + Vector3(0, 0.6, 0)
	menu_stage.add_child(menu_fire)
	var flame := MeshInstance3D.new()
	var fm := SphereMesh.new()
	fm.radius = 0.13
	fm.height = 0.45
	flame.mesh = fm
	var fmat := StandardMaterial3D.new()
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.albedo_color = Color(1.0, 0.6, 0.15, 0.85)
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flame.material_override = fmat
	flame.position = fp + Vector3(0, 0.25, 0)
	menu_stage.add_child(flame)
	menu_flame = flame
	# holofote azul de trás
	var spot := SpotLight3D.new()
	spot.position = Vector3(3, 5, -4)
	spot.light_color = Color(0.6, 0.75, 1.0)
	spot.light_energy = 4.0
	spot.spot_range = 14.0
	spot.spot_angle = 22.0
	menu_stage.add_child(spot)
	spot.look_at(Vector3(0, 0.8, 0), Vector3.UP)
	# carcaça de carro e caixotes
	var car := Vehicle.prop_node(0, Vehicle.car_material(Color(0.3, 0.3, 0.32), 0.5, 0.9))
	car.position = Vector3(4.2, 0, -6.0)
	car.rotation = Vector3(0, -0.6, 0.05)
	menu_stage.add_child(car)
	m.tex(U.WOOD, 0.7)
	m.box(Transform3D(Basis(Vector3.UP, 0.5), Vector3(2.2, 0.35, -2.2)), Vector3(0.7, 0.7, 0.7), Color(0.6, 0.5, 0.38))
	# árvores de verdade no fundo (as mesmas do mapa)
	for k in 9:
		var p := Vector3(-16 + k * 4.0 + r.randf(), 0, -16 - r.randf() * 5.0)
		_menu_tree(["oak", "tall"][k % 2], p, r)


func _menu_tree(kind: String, p: Vector3, r: RandomNumberGenerator) -> void:
	var path := "res://models/trees/%s.res" % kind
	if not ResourceLoader.exists(path):
		return
	var mi := MeshInstance3D.new()
	mi.mesh = load(path)
	mi.transform = Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3.ONE * r.randf_range(0.8, 1.15)), p)
	menu_stage.add_child(mi)


func _menu_tick(delta: float) -> void:
	if menu_stage == null or menu_sol == null:
		return
	menu_t += delta
	# configurações podem ter ligado/desligado a música
	if menu_music and int(menu_t * 2.0) != int((menu_t - delta) * 2.0):
		_menu_music_on()
	# solta o dedo: volta devagar a ficar de frente
	menu_hold -= delta
	if menu_hold <= 0.0:
		menu_sol.rotation.y = lerp_angle(menu_sol.rotation.y, PI, minf(1.0, 1.5 * delta))
	else:
		menu_sol.rotation.y += menu_rot_v
		menu_rot_v = lerpf(menu_rot_v, 0.0, minf(1.0, 6.0 * delta))
	for c in menu_cubes:
		var mi: MeshInstance3D = c[0]
		mi.position = (c[1] as Vector3) + Vector3(0, sin(menu_t * 0.6 + float(c[2])) * 0.25, 0)
		mi.rotation.y += delta * 0.15
	if menu_fire:
		menu_fire.light_energy = 2.0 + sin(menu_t * 17.0) * 0.25 + sin(menu_t * 7.3) * 0.35
	if menu_flame:
		menu_flame.scale = Vector3(1.0, 1.0 + sin(menu_t * 13.0) * 0.12 + sin(menu_t * 5.1) * 0.08, 1.0)
	if menu_news:
		var ni := int(menu_t / 5.0) % NEWS.size()
		if menu_news.text != NEWS[ni]:
			menu_news.text = NEWS[ni]
		menu_news.modulate.a = clampf(minf(fmod(menu_t, 5.0), 5.0 - fmod(menu_t, 5.0)) * 3.0, 0.0, 1.0)
	# parado à vontade: braços soltos, respirando
	var br := sin(menu_t * 1.8) * 0.008
	var g := menu_sol.global_transform
	# com as animações novas o parado já é natural; sem elas, os braços descem por código
	menu_sol.tick(delta, false, 0.0, 0.0, [] if menu_sol.has_anim("Sprint") else [g * Vector3(-0.27, 0.86 + br, 0.03), g * Vector3(0.27, 0.86 + br, 0.03)])


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
	var n := nick_edit.text.strip_edges().left(16) if is_instance_valid(nick_edit) else str(Cfg.get_v("nick"))
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
		"quality", "shadows", "tex_detail", "grass", "view":
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
	await _build_world()
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
	# arte do jogo de fundo (tools/render_keyart.gd + tools/keyart_post.py), sem textos de etapa
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.05, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(bg)
	var art := TextureRect.new()
	art.texture = load("res://art/loading.jpg")
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	menu.add_child(art)
	var t := _menu_label("CONFRONTO", 46)
	t.add_theme_color_override("font_color", Color(1, 0.86, 0.45))
	t.add_theme_constant_override("outline_size", 10)
	t.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02, 0.85))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	t.position = Vector2(34, 22)
	menu.add_child(t)
	load_lbl = null
	load_bar = ProgressBar.new()
	load_bar.show_percentage = false
	load_bar.anchor_left = 0.32
	load_bar.anchor_right = 0.68
	load_bar.anchor_top = 1.0
	load_bar.anchor_bottom = 1.0
	load_bar.offset_top = -40
	load_bar.offset_bottom = -32
	var bgs := StyleBoxFlat.new()
	bgs.bg_color = Color(1, 1, 1, 0.16)
	bgs.set_corner_radius_all(4)
	var fgs := StyleBoxFlat.new()
	fgs.bg_color = Color(1, 0.72, 0.22)
	fgs.set_corner_radius_all(4)
	load_bar.add_theme_stylebox_override("background", bgs)
	load_bar.add_theme_stylebox_override("fill", fgs)
	load_bar.max_value = 100.0
	menu.add_child(load_bar)
	await get_tree().process_frame
	await get_tree().process_frame


func _load_progress(k: float, txt: String) -> void:
	if load_bar:
		var tw := create_tween()
		tw.tween_property(load_bar, "value", k * 100.0, 0.15)
	if load_lbl:
		load_lbl.text = txt


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
	await _build_world()
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


# editor de cenário (scripts/map_editor.gd): mapa sem jogadores, câmera livre
func start_editor() -> void:
	_save_cfg()
	_step("editor de cenário")
	await _show_loading()
	training = true
	map_editing = true
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	local_id = multiplayer.get_unique_id()
	await _build_world()
	_menu_music_off()
	if menu:
		menu.queue_free()
		menu = null
	if menu_stage:
		menu_stage.queue_free()
		menu_stage = null
		menu_sol = null
		menu_fire = null
		menu_flame = null
		menu_news = null
	var ed := MapEditor.new()
	ed.game = self
	ed.world = world
	add_child(ed)


# ---------------- editor: jogar aqui ----------------
# O boneco entra no ponto escolhido com equipamento nível 3, arma e munição; as outras armas e
# acessórios ficam no chão em volta. Ninguém perde vida (fase de aquecimento) e o pente enche sozinho.
func sandbox_play(at: Vector3) -> void:
	if not sandbox:
		sandbox = true
		bots_per_match = 0
		_enter_game()
		_server_init()
		phase_t = 99999.0
		z_stage = 0
		z_wait = 1e9
		z_shrink = 1.0
		_server_add_player(local_id, _nick(), false)
		_sandbox_kit(players[local_id])
	var lp: Player = players[local_id]
	_sandbox_zone(at)
	lp.position = at + Vector3(0, 0.4, 0)
	lp.velocity = Vector3.ZERO
	lp.air = 0
	sandbox_hud(true)
	_sandbox_items(at)


func _sandbox_zone(at: Vector3) -> void:
	z_c0 = Vector2(at.x, at.z)
	z_c1 = z_c0
	z_r0 = 70.0
	z_r1 = 70.0


func sandbox_hud(on: bool) -> void:
	if hud == null:
		return
	hud.move_vec = Vector2.ZERO
	hud.joy_active = false
	hud.touches.clear()
	hud.fire_held = false
	hud.visible = on
	hud.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	if on:
		cam.current = true


func _sandbox_kit(p: Player) -> void:
	for k in ["bag3", "vest3", "helmet3"]:
		_give(p, k, 1, 100.0 if k == "vest3" else null)
	for k in [["a9", 120], ["a556", 150], ["a762", 30], ["a12", 40]]:
		_give(p, k[0], k[1], null)
	for k in [["med", 6], ["grenade", 6]]:
		_give(p, k[0], k[1], null)


var _sandbox_items_at := Vector3(0, -999, 0)
var _quiet_spawn := false


func _sandbox_items(at: Vector3) -> void:
	# não repete se já tem um monte de item ali perto
	if _sandbox_items_at.distance_to(at) < 25.0:
		return
	_sandbox_items_at = at
	var guns := ["glock", "deagle", "mp5", "ump45", "m4a1", "scar", "ak47", "r870", "m1014", "kar98", "awm"]
	var rest := Weapons.ATTS.duplicate()
	rest.append_array(["vest1", "vest2", "helmet1", "helmet2", "bag1", "bag2"])
	var all := guns + rest
	_quiet_spawn = true
	for i in all.size():
		var a := TAU * i / all.size()
		var r := 3.0 if i < guns.size() else 4.6
		var q := Vector2(at.x + cos(a) * r, at.z + sin(a) * r)
		var pos := Vector3(q.x, world.height(q.x, q.y) + 0.07, q.y)
		if absf(pos.y - at.y) > 1.5:
			pos.y = at.y + 0.07
		var kind: String = all[i]
		_all("spawn_item", [world.items.size(), pos, kind, Weapons.default_count(kind), null, [], ""])
	_quiet_spawn = false


# bots que não morrem, perto de onde você está
func sandbox_bots(n := 3) -> void:
	if not sandbox:
		return
	var lp: Player = players[local_id]
	var guns := ["mp5", "ump45", "m4a1", "scar", "ak47", "m1014"]
	for i in n:
		var id := next_bot
		next_bot += 1
		_server_add_player(id, "Bot " + str(BOT_NAMES[(id - 1000) % BOT_NAMES.size()]), true)
		var b: Player = players[id]
		var a := randf() * TAU
		var q := Vector2(lp.position.x + cos(a) * randf_range(8.0, 16.0), lp.position.z + sin(a) * randf_range(8.0, 16.0))
		b.position = Vector3(q.x, world.height(q.x, q.y) + 0.5, q.y)
		b.air = 0
		var g: String = guns[randi() % guns.size()]
		_give(b, g, 1, null)
		_give(b, Weapons.ammo_of(g), 200, null)
		_give(b, "vest2", 1, 100.0)


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
	await _build_world()
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
	world.editor = map_editing
	# ajustes feitos à mão: o do aparelho só vale no treino/editor; em rede todos usam o que vai no jogo
	world.edit_data = MapEdits.load_data(training or map_editing)
	add_child(world)
	var steps := world.build_steps(dedicated, int(Cfg.get_v("quality")))
	# quem entra numa sala monta tudo de uma vez (as mensagens da rede não podem chegar no meio)
	var show := load_bar != null and multiplayer.is_server()
	for i in steps.size():
		_load_progress(float(i) / steps.size(), str(steps[i][0]) + "...")
		if show:
			await get_tree().process_frame
			await get_tree().process_frame
		(steps[i][1] as Callable).call()
	_load_progress(1.0, "Pronto!")
	_step("mapa pronto")
	if map_editing:
		# itens do mapa não aparecem no editor; os do "jogar aqui" são criados na hora
		n_static = world.items.size()
		items_avail = []
		for i in world.items.size():
			items_avail.append(false)
		return
	n_static = world.items.size()
	items_avail = []
	_item_grid.clear()
	for i in world.items.size():
		items_avail.append(true)
		if not dedicated:
			_grid_add(i)
	_spawn_vehicles()


func _spawn_vehicles() -> void:
	for v in vehicles:
		v.queue_free()
	vehicles.clear()
	for i in world.car_spots.size():
		var sp: Array = world.car_spots[i]
		var v := Vehicle.new()
		v.name = "Car%d" % i
		add_child(v)
		v.setup(self, i, int(sp[2]), sp[0], float(sp[1]), sp[3], not dedicated)
		vehicles.append(v)


# ---------------- carros ----------------

func near_vehicle(p: Player) -> int:
	var best := -1
	var bd := 4.0
	for v: Vehicle in vehicles:
		var d := v.global_position.distance_to(p.global_position)
		if d < bd and (v.driver == 0 or v.driver == p.pid):
			bd = d
			best = v.idx
	return best


func _car_toggle(lp: Player) -> void:
	if lp.car >= 0:
		_to_server("req_car", [lp.car, false])
	else:
		var i := near_vehicle(lp)
		if i >= 0:
			_to_server("req_car", [i, true])


@rpc("any_peer", "call_remote", "reliable")
func req_car(i: int, enter: bool) -> void:
	if not multiplayer.is_server() or i < 0 or i >= vehicles.size():
		return
	var id := _sender()
	var p: Player = players.get(id)
	var v: Vehicle = vehicles[i]
	if p == null or not p.alive or p.air != 0:
		return
	if enter:
		if v.driver != 0 or p.car >= 0 or v.global_position.distance_to(p.global_position) > 5.0:
			return
		_all("on_car", [i, id])
	elif v.driver == id:
		_all("on_car", [i, 0])


@rpc("authority", "call_remote", "reliable")
func on_car(i: int, id: int) -> void:
	var v: Vehicle = vehicles[i]
	var old := v.driver
	v.driver = id
	if id != 0:
		var p: Player = players.get(id)
		if p:
			p.car = i
			p.scoped = false
			p.sprint = false
			p.set_crouch(false)
			p.set_prone(false)
			if id == local_id:
				sfx("door", -2.0)
	elif old != 0:
		var p: Player = players.get(old)
		v.speed = 0.0
		if p:
			p.car = -1
			# desce do lado do motorista
			var out := _exit_spot(v)
			p.position = out
			p.target_pos = out
			p.velocity = Vector3.ZERO
			if old == local_id:
				sfx("door", -2.0)


# lugar pra descer do carro: do lado do motorista (ou do outro, se tiver parede), em cima do chão
func _exit_spot(v: Vehicle) -> Vector3:
	var space := get_world_3d().direct_space_state
	for sx in [-1.9, 1.9, 0.0]:
		var off := Vector3(sx, 0, 0) if sx != 0.0 else Vector3(0, 0, 3.2)
		var o := v.global_position + Basis(Vector3.UP, v.yaw) * off
		var gy := world.height(o.x, o.z)
		var q := PhysicsRayQueryParameters3D.create(Vector3(o.x, maxf(gy, v.global_position.y) + 2.5, o.z), Vector3(o.x, gy - 0.5, o.z), 1)
		var hit := space.intersect_ray(q)
		var y := gy
		if not hit.is_empty():
			y = maxf(gy, (hit["position"] as Vector3).y)
		# não desce dentro de parede: confere se cabe a pessoa ali
		if hit.is_empty() or y - gy < 1.2:
			return Vector3(o.x, y + 0.12, o.z)
	return v.global_position + Vector3(0, 2.2, 0)


# posição do carro: motorista -> servidor -> todos
@rpc("any_peer", "call_remote", "unreliable_ordered")
func veh_st(i: int, pos: Vector3, yw: float, spd: float) -> void:
	if i < 0 or i >= vehicles.size():
		return
	var v: Vehicle = vehicles[i]
	if multiplayer.is_server():
		if v.driver != _sender():
			return
		for peer in multiplayer.get_peers():
			if peer != _sender():
				rpc_id(peer, "veh_st", i, pos, yw, spd)
	if v.driver == local_id:
		return
	v.target_pos = pos
	v.target_yaw = yw
	v.speed = spd


func _server_car_damage(v: Vehicle, amount: float, by: int) -> void:
	if v.dead:
		return
	v.hp -= amount
	if v.hp > 0.0:
		# vida do carro pra todo mundo (a fumaça engrossa conforme apanha)
		_all("on_car_hp", [v.idx, v.hp])
	if v.hp <= 0.0:
		_all("on_explode", [v.idx])
		# explosão: machuca quem estiver perto (quem está dentro quase morre)
		for id in players.keys():
			var p: Player = players.get(id)
			if p == null or not p.alive or p.air != 0:
				continue
			var d := p.global_position.distance_to(v.global_position)
			if p.car == v.idx:
				_server_damage(id, by, 180.0, false, "explosão", true)
			elif d < 7.0:
				_server_damage(id, by, 150.0 * (1.0 - d / 7.0) + 15.0, false, "explosão", true)


@rpc("authority", "call_remote", "unreliable_ordered")
func on_car_hp(i: int, hp: float) -> void:
	if i >= 0 and i < vehicles.size():
		vehicles[i].hp = hp


@rpc("authority", "call_remote", "reliable")
func on_explode(i: int) -> void:
	var v: Vehicle = vehicles[i]
	var old := v.driver
	if old != 0:
		on_car(i, 0)
	v.explode_visual()
	if dedicated:
		return
	_explosion_fx(v.global_position + Vector3(0, 0.8, 0), 1.3)


static var _scorch_mat: StandardMaterial3D


# nuvem de partículas com a textura de fumaça (cor do começo pro fim, sobe/espalha e cresce)
func _boom_particles(at: Vector3, size: float, n: int, life: float, c0: Color, c1: Color, v0: float, v1: float, grav: Vector3, s0: float, s1: float, fire: bool, spread: float) -> void:
	var ps := CPUParticles3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2.ONE
	ps.mesh = qm
	var m := StandardMaterial3D.new()
	m.albedo_texture = World.smoke_tex()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if fire else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	if fire:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ps.material_override = m
	ps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ps.one_shot = true
	ps.explosiveness = 0.85
	ps.amount = n
	ps.lifetime = life
	ps.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	ps.emission_sphere_radius = 0.5 * size
	ps.direction = Vector3.UP
	ps.spread = 180.0 if spread <= 0.0 else spread
	if spread >= 80.0:
		ps.flatness = 0.85
	ps.initial_velocity_min = v0 * size
	ps.initial_velocity_max = v1 * size
	ps.damping_min = 2.5
	ps.damping_max = 4.0
	ps.gravity = grav
	ps.scale_amount_min = s0
	ps.scale_amount_max = s0 * 1.4
	var cr := Curve.new()
	cr.add_point(Vector2(0, 0.6))
	cr.add_point(Vector2(1, s1 / maxf(s0, 0.01)))
	cr.max_value = maxf(4.0, s1 / maxf(s0, 0.01) + 0.5)
	ps.scale_amount_curve = cr
	var gr := Gradient.new()
	gr.set_color(0, c0)
	gr.set_color(1, c1)
	ps.color_ramp = gr
	add_child(ps)
	ps.global_position = at
	ps.emitting = true
	get_tree().create_timer(life + 0.5).timeout.connect(ps.queue_free)


func _explosion_fx(at: Vector3, size: float) -> void:
	if dedicated:
		return
	sfx_at("explosion", at, false, 0.0, 220.0)
	var fl := OmniLight3D.new()
	fl.light_color = Color(1.0, 0.55, 0.2)
	fl.light_energy = 6.0
	fl.omni_range = 12.0 * size
	add_child(fl)
	fl.global_position = at + Vector3(0, 0.8, 0)
	var tw := create_tween()
	tw.tween_property(fl, "light_energy", 0.0, 0.8)
	tw.tween_callback(fl.queue_free)
	# bola de fogo rápida, poeira rasteira em anel, fumaça escura subindo devagar, terra voando
	# e mancha de queimado no chão (tudo em partículas com textura de fumaça, nada de bolas)
	_boom_particles(at, size, 10, 0.45, Color(1.0, 0.72, 0.35, 1.0), Color(0.9, 0.3, 0.08, 0.0), 2.5, 5.0, Vector3(0, 0.5, 0), 0.9 * size, 2.4 * size, true, 0.0)
	_boom_particles(at, size, 14, 1.6, Color(0.55, 0.5, 0.42, 0.7), Color(0.55, 0.5, 0.42, 0.0), 3.0, 6.5, Vector3(0, -0.4, 0), 0.8 * size, 2.2 * size, false, 85.0)
	_boom_particles(at + Vector3(0, 0.6, 0), size, 12, 3.2, Color(0.16, 0.15, 0.14, 0.85), Color(0.3, 0.29, 0.27, 0.0), 0.8, 2.2, Vector3(0, 1.4, 0), 1.0 * size, 3.2 * size, false, 25.0)
	var dirt := CPUParticles3D.new()
	dirt.mesh = U.box_mesh(Vector3(0.06, 0.06, 0.06))
	dirt.material_override = U.mat(Color(0.3, 0.25, 0.2))
	dirt.one_shot = true
	dirt.explosiveness = 1.0
	dirt.amount = 16
	dirt.lifetime = 1.4
	dirt.direction = Vector3.UP
	dirt.spread = 55.0
	dirt.initial_velocity_min = 4.0 * size
	dirt.initial_velocity_max = 9.0 * size
	dirt.gravity = Vector3(0, -12.0, 0)
	add_child(dirt)
	dirt.global_position = at + Vector3(0, 0.2, 0)
	dirt.emitting = true
	get_tree().create_timer(2.0).timeout.connect(dirt.queue_free)
	# queimado no chão
	var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, 1.0, 0), at - Vector3(0, 3.0, 0))
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var sc := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2.ONE * 2.6 * size
		sc.mesh = qm
		if _scorch_mat == null:
			_scorch_mat = StandardMaterial3D.new()
			_scorch_mat.albedo_texture = World.smoke_tex()
			_scorch_mat.albedo_color = Color(0.05, 0.045, 0.04)
			_scorch_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sc.material_override = _scorch_mat
		sc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(sc)
		var n: Vector3 = hit["normal"]
		sc.global_transform = Transform3D(Basis.looking_at(-n, Vector3.FORWARD if absf(n.y) > 0.9 else Vector3.UP), (hit["position"] as Vector3) + n * 0.02)
		get_tree().create_timer(30.0).timeout.connect(sc.queue_free)
	if cam and cam.global_position.distance_to(at) < 30.0:
		_shake = 0.6


# ---------------- granada ----------------

# Granada: segurar o botão tira o pino (começa a contar e apita); soltar arremessa com o tempo que
# sobrou; segurando demais explode na mão. Enquanto segura aparece o X pra guardar de volta.
const GREN_FUSE := 4.0
var gren_t := -1.0
var _gren_beep := 0.0


func _grenade_hold(lp: Player) -> void:
	if gren_t >= 0.0 or lp.count("grenade") <= 0 or lp.air != 0 or lp.car >= 0 or not lp.alive:
		return
	gren_t = 0.0
	_gren_beep = 0.0
	sfx("pin")


func _grenade_tick(lp: Player, delta: float) -> void:
	lp.gren_hold = gren_t >= 0.0
	if gren_t < 0.0:
		if not hud.gren_path.is_empty():
			hud.gren_path = PackedVector2Array()
		return
	if not lp.alive or lp.count("grenade") <= 0:
		gren_t = -1.0
		return
	gren_t += delta
	hud.gren_path = _gren_preview(lp)
	_gren_beep -= delta
	if _gren_beep <= 0.0:
		_gren_beep = 1.0 if gren_t < GREN_FUSE - 1.2 else 0.3
		sfx("beep", -6.0)
	if gren_t >= GREN_FUSE:
		# não soltou a tempo: explode na mão
		gren_t = -1.0
		_to_server("req_grenade", [lp.global_position + Vector3(0, 1.0, 0), Vector3.ZERO, 0.02])


func _gren_launch(lp: Player) -> Array:
	var fwd := -cam.global_transform.basis.z
	var from := lp.global_position + Vector3(0, 1.6, 0) + Vector3(fwd.x, 0, fwd.z).normalized() * 0.5
	return [from, (fwd + Vector3(0, 0.35, 0)).normalized() * 17.0]


# pedaço do começo do arco da granada (pontinhos discretos na tela)
func _gren_preview(lp: Player) -> PackedVector2Array:
	var out := PackedVector2Array()
	var l := _gren_launch(lp)
	var p: Vector3 = l[0]
	var v: Vector3 = l[1]
	var space := get_world_3d().direct_space_state
	var dt := 0.06
	for i in 14:
		var p1 := p + v * dt
		v.y -= 18.0 * dt
		var r := space.intersect_ray(PhysicsRayQueryParameters3D.create(p, p1, 1))
		if not r.is_empty():
			break
		p = p1
		if i >= 2 and not cam.is_position_behind(p):
			out.append(cam.unproject_position(p))
	return out


func _throw_grenade(lp: Player) -> void:
	if gren_t < 0.0:
		return
	var fuse := maxf(GREN_FUSE - gren_t, 0.05)
	gren_t = -1.0
	lp.gren_hold = false
	var l := _gren_launch(lp)
	var from: Vector3 = l[0]
	var vel: Vector3 = l[1]
	lp.punch_t = 0.3
	sfx("punch_swing", -4.0)
	_to_server("req_grenade", [from, vel, fuse])


@rpc("any_peer", "call_remote", "reliable")
func req_grenade(from: Vector3, vel: Vector3, fuse := 2.6) -> void:
	if not multiplayer.is_server():
		return
	var id := _sender()
	var p: Player = players.get(id)
	if p == null or not p.alive or p.count("grenade") <= 0:
		return
	if from.distance_to(p.global_position) > 3.0:
		return
	p.inv["grenade"] = p.count("grenade") - 1
	_p_inv(p)
	_all("on_grenade", [from, vel.limit_length(20.0), id, clampf(fuse, 0.02, GREN_FUSE)])


@rpc("authority", "call_remote", "reliable")
func on_grenade(from: Vector3, vel: Vector3, owner_id: int, fuse := 2.6) -> void:
	var g := {"pos": from, "vel": vel, "t": fuse, "owner": owner_id, "node": null}
	if not dedicated:
		var mi := MeshInstance3D.new()
		mi.mesh = Weapons.item_mesh("grenade")
		mi.material_override = U.wmat()
		add_child(mi)
		mi.global_position = from
		g["node"] = mi
	grenades.append(g)


func _grenades_tick(delta: float) -> void:
	if grenades.is_empty():
		return
	var space := get_world_3d().direct_space_state
	for g in grenades.duplicate():
		g["t"] = float(g["t"]) - delta
		var v: Vector3 = g["vel"]
		v.y -= 18.0 * delta
		var p0: Vector3 = g["pos"]
		var p1 := p0 + v * delta
		var q := PhysicsRayQueryParameters3D.create(p0, p1, 1)
		var r := space.intersect_ray(q)
		if not r.is_empty():
			var nrm: Vector3 = r["normal"]
			v = v.bounce(nrm) * 0.42
			p1 = r["position"] + nrm * 0.06
			if v.length() > 2.0:
				sfx_at("impact", p1, false, -6.0, 30.0)
		g["vel"] = v
		g["pos"] = p1
		if g["node"]:
			(g["node"] as Node3D).global_position = p1 - Vector3(0, 0.06, 0)
			(g["node"] as Node3D).rotation.x += v.length() * delta * 3.0
		if float(g["t"]) <= 0.0:
			grenades.erase(g)
			if g["node"]:
				(g["node"] as Node3D).queue_free()
			_explosion_fx(p1, 1.0)
			if multiplayer.is_server():
				for id in players.keys():
					var pl: Player = players.get(id)
					if pl == null or not pl.alive or pl.air != 0:
						continue
					var c := pl.global_position + Vector3(0, 1.0, 0)
					var d := c.distance_to(p1)
					if d > 6.5:
						continue
					var lq := PhysicsRayQueryParameters3D.create(p1 + Vector3(0, 0.3, 0), c, 1)
					if not space.intersect_ray(lq).is_empty():
						continue
					_server_damage(id, int(g["owner"]), 170.0 * (1.0 - d / 6.5) + 10.0, false, "granada", true)
				for vc: Vehicle in vehicles:
					if not vc.dead and vc.global_position.distance_to(p1) < 5.0:
						_server_car_damage(vc, 260.0, int(g["owner"]))


# atropelou: o servidor confere a distância
@rpc("any_peer", "call_remote", "reliable")
func req_runover(vid: int, spd: float) -> void:
	if not multiplayer.is_server():
		return
	_server_runover(_sender(), vid, spd)


func _server_runover(driver: int, vid: int, spd: float) -> void:
	var d: Player = players.get(driver)
	var t: Player = players.get(vid)
	if d == null or t == null or d.car < 0 or not t.alive or t.car >= 0:
		return
	var v: Vehicle = vehicles[d.car]
	if v.global_position.distance_to(t.global_position) > 5.0:
		return
	_server_damage(vid, driver, clampf(absf(spd) * 7.0, 40.0, 220.0), false, "carro", true)


func _drive_local(lp: Player, delta: float) -> void:
	var v: Vehicle = vehicles[lp.car]
	# no carro só os botões (pedais e volante); o analógico some. Teclado continua valendo no PC.
	var mv := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	var di := hud.drive_input()
	var th := clampf(di.x - mv.y, -1.0, 1.0)
	var st := clampf(di.y + mv.x, -1.0, 1.0)
	v.drive(delta, th, st)
	lp.position = v.seat_pos()
	lp.velocity = Vector3.ZERO
	lp.yaw = v.yaw
	_veh_send_t += delta
	if _veh_send_t >= 0.05:
		_veh_send_t = 0.0
		if multiplayer.is_server():
			for peer in multiplayer.get_peers():
				rpc_id(peer, "veh_st", v.idx, v.global_position, v.yaw, v.speed)
		else:
			rpc_id(1, "veh_st", v.idx, v.global_position, v.yaw, v.speed)
	# atropelar quem está na frente
	if absf(v.speed) > 6.0:
		var fwd := Vector3(-sin(v.yaw), 0, -cos(v.yaw)) * signf(v.speed)
		for id in players:
			var o: Player = players[id]
			if o == lp or not o.alive or o.car >= 0 or o.air != 0:
				continue
			var rel := o.global_position - v.global_position
			if rel.length() < 3.4 and rel.normalized().dot(fwd) > 0.3 and Time.get_ticks_msec() - int(_runover_t.get(id, 0)) > 1200:
				_runover_t[id] = Time.get_ticks_msec()
				if multiplayer.is_server():
					_server_runover(local_id, id, v.speed)
				else:
					rpc_id(1, "req_runover", id, v.speed)


# item não fica flutuando: desce até o que tiver embaixo (chão, piso, mesa)
func _snap_items() -> void:
	if _snap_q.is_empty() or Engine.get_physics_frames() < 3:
		return
	var space := get_world_3d().direct_space_state
	for k in mini(40, _snap_q.size()):
		var i: int = _snap_q.pop_back()
		if i >= item_nodes.size() or item_nodes[i] == null:
			continue
		var n: Node3D = item_nodes[i]
		var q := PhysicsRayQueryParameters3D.create(n.position + Vector3(0, 0.4, 0), n.position + Vector3(0, -3.0, 0), 1)
		var r := space.intersect_ray(q)
		if not r.is_empty():
			n.position.y = r["position"].y + 0.01
			# guarda a altura certa (quando o item for montado de novo não precisa procurar)
			var ip: Vector3 = world.items[i]["pos"]
			world.items[i]["pos"] = Vector3(ip.x, n.position.y, ip.z)
			world.items[i]["snapped"] = true


# Itens no chão aparecem só perto da câmera: o mapa tem milhares e montar todos pesa no celular.
# Ficam numa grade de 40 m; a cada 0,3 s cria os de perto (aos poucos) e apaga os de longe.
const ITEM_CELL := 40.0
const ITEM_IN := 105.0
const ITEM_OUT := 140.0
var _item_grid := {}
var _item_live := {}       # célula -> true (itens dela montados)
var _item_build_q: Array = []
var _item_t := 0.0


func _grid_add(i: int) -> void:
	var p: Vector3 = world.items[i]["pos"]
	var c := Vector2i(floori(p.x / ITEM_CELL), floori(p.z / ITEM_CELL))
	if not _item_grid.has(c):
		_item_grid[c] = []
	_item_grid[c].append(i)


func _stream_items(delta: float) -> void:
	if dedicated or cam == null:
		return
	# monta poucos por quadro (sem engasgo)
	var built := 0
	while not _item_build_q.is_empty() and built < 60:
		var i: int = _item_build_q.pop_back()
		if i < items_avail.size() and items_avail[i] and (i >= item_nodes.size() or item_nodes[i] == null):
			_make_item_node(i)
			built += 1
	_item_t -= delta
	if _item_t > 0.0:
		return
	_item_t = 0.3
	var cp := cam.global_position
	var c0 := Vector2i(floori(cp.x / ITEM_CELL), floori(cp.z / ITEM_CELL))
	var rc := int(ceil(ITEM_OUT / ITEM_CELL)) + 1
	for dx in range(-rc, rc + 1):
		for dz in range(-rc, rc + 1):
			var c := c0 + Vector2i(dx, dz)
			if not _item_grid.has(c):
				continue
			var cc := Vector2((c.x + 0.5) * ITEM_CELL, (c.y + 0.5) * ITEM_CELL)
			var d := cc.distance_to(Vector2(cp.x, cp.z))
			if d < ITEM_IN and not _item_live.has(c):
				_item_live[c] = true
				_item_build_q.append_array(_item_grid[c])
	for c in _item_live.keys():
		var cc := Vector2((c.x + 0.5) * ITEM_CELL, (c.y + 0.5) * ITEM_CELL)
		if cc.distance_to(Vector2(cp.x, cp.z)) > ITEM_OUT:
			_item_live.erase(c)
			for i in _item_grid[c]:
				if i < item_nodes.size() and item_nodes[i]:
					item_nodes[i].queue_free()
					item_nodes[i] = null


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
	if not it.get("snapped", false):
		_snap_q.append(i)


# música do lobby: rock/metal (faixas CC0, ver sounds/CREDITOS.txt), uma sorteada, em loop no menu
func _menu_music_on() -> void:
	if menu_music == null:
		menu_music = AudioStreamPlayer.new()
		menu_music.stream = load("res://sounds/lobby_rock%d.ogg" % (randi() % 2 + 1))
		add_child(menu_music)
	var mv := float(Cfg.get_v("volume")) * float(Cfg.get_v("music_vol"))
	var want := bool(Cfg.get_v("music")) and mv > 0.0
	menu_music.volume_db = linear_to_db(maxf(mv, 0.001)) - 4.0
	if want and not menu_music.playing:
		menu_music.play()
	elif not want and menu_music.playing:
		menu_music.stop()


# vitória: tema pesado (sounds/win.wav) e depois o metal "Monolith" em loop
var win_music: AudioStreamPlayer


func _victory_music() -> void:
	_victory_music_off()
	var mv := float(Cfg.get_v("volume")) * maxf(float(Cfg.get_v("music_vol")), 0.35)
	if mv <= 0.0:
		return
	win_music = AudioStreamPlayer.new()
	win_music.stream = sfxn.streams.get("win")
	win_music.volume_db = linear_to_db(mv) + 2.0
	add_child(win_music)
	win_music.play()
	var wm := win_music
	wm.finished.connect(func():
		if wm != win_music or not is_instance_valid(wm):
			return
		wm.stream = load("res://sounds/lobby_rock2.ogg")
		wm.volume_db = linear_to_db(mv) - 3.0
		wm.play())


func _victory_music_off() -> void:
	if win_music == null:
		return
	var wm := win_music
	win_music = null
	if is_instance_valid(wm):
		var tw := create_tween()
		tw.tween_property(wm, "volume_db", -40.0, 1.0)
		tw.tween_callback(wm.queue_free)


func _menu_music_off() -> void:
	if menu_music == null:
		return
	var mm := menu_music
	menu_music = null
	var tw := create_tween()
	tw.tween_property(mm, "volume_db", -40.0, 1.2)
	tw.tween_callback(mm.queue_free)


func _enter_game() -> void:
	_menu_music_off()
	_victory_music_off()
	if menu:
		menu.queue_free()
		menu = null
	if menu_stage:
		menu_stage.queue_free()
		menu_stage = null
		menu_sol = null
		menu_fire = null
		menu_flame = null
		menu_news = null
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
	spring.margin = 0.25
	var sh := SphereShape3D.new()
	sh.radius = 0.28
	spring.shape = sh
	cam_pitch.add_child(spring)
	cam = Camera3D.new()
	cam.fov = 75.0
	cam.far = 400.0
	cam.near = 0.12     # perto demais estragava a profundidade (objetos longe "brigavam" e piscavam)
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
	var far := 300.0     # mais curto que antes: o jogo fica mais leve (a névoa esconde o fim)
	match int(Cfg.get_v("quality")):
		0:
			vp.scaling_3d_scale = 0.6
			vp.msaa_3d = Viewport.MSAA_DISABLED
			if sun:
				sun.shadow_enabled = false
			far = 250.0
			world.set_view(200.0)
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
			far = 380.0
			world.set_view(300.0)
	# ajustes finos das configurações
	if sun and not bool(Cfg.get_v("shadows")):
		sun.shadow_enabled = false
	U.tmat().set_shader_parameter("detail", 1.0 if bool(Cfg.get_v("tex_detail")) else 0.0)
	world.show_grass(bool(Cfg.get_v("grass")))
	var vk: float = [0.75, 1.0, 1.25][clampi(int(Cfg.get_v("view")), 0, 2)]
	far *= vk
	world.set_view(far * 0.8)
	# a câmera enxerga o mapa todo: depois da distância de visão entra o cenário simples (blocos),
	# então longe não fica só cinza; a névoa é mais leve (bruma de guerra, mas dá pra ver o horizonte)
	cam.far = 1050.0
	fog_base = 0.42 / far
	if env:
		env.environment.fog_density = fog_base


# avião do salto: bimotor CC0 (models/plane.scn, feito pelo tools/prepare_plane.gd); as hélices giram
func _build_plane() -> Node3D:
	var root: Node3D = (load("res://models/plane.scn") as PackedScene).instantiate()
	return root


func _lan_ip() -> String:
	for a in IP.get_local_addresses():
		if a.begins_with("192.168.") or a.begins_with("10.") or a.begins_with("172."):
			return a
	return "(não achei o IP, veja nas config. do Wi-Fi)"


# ---------------- estado compartilhado (todos calculam igual) ----------------

func plane_frac() -> float:
	return clampf(plane_t / plane_dur, 0.0, 1.0)


# trecho da rota em que dá pra saltar (em cima do mapa)
func plane_j0() -> float:
	var L := Vector2(plane_a.x, plane_a.z).distance_to(Vector2(plane_b.x, plane_b.z))
	return PLANE_OUT / maxf(L, 1.0)


func plane_j1() -> float:
	return 1.0 - plane_j0()


func can_leave_plane() -> bool:
	return plane_frac() >= plane_j0() and plane_frac() <= plane_j1() + 0.01


# onde o jogador aparece ao saltar: na porta de trás, na altura do avião (não flutuando embaixo dele)
func plane_exit() -> Vector3:
	var dir := (plane_b - plane_a).normalized()
	return plane_pos() + Vector3(0, 3.6, 0) - dir * 9.0


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
	# piso de casa/asfalto = duro; estrada de terra = cascalho; resto = grama/terra
	# um som de passo só, em qualquer chão: fica fácil reconhecer alguém chegando
	var n := "step_hard%d" % randi_range(0, 5)
	if p.is_local:
		sfxn.play(n, -14.0 if quiet else -9.0)
		return
	var d := 16.0 if quiet else 45.0
	sfxn.play_at(n, p.position, -6.0 if quiet else 0.0, d, 1.0, 4.0)
	var lp: Player = players.get(local_id)
	if hud and lp and lp.alive and lp.position.distance_to(p.position) < d:
		hud.add_step(p.position)


func _make_loops() -> void:
	# avião e vento vêm dos arquivos (já em loop); só garante que existem
	for n in ["plane", "wind_fall", "wind_chute"]:
		if not sfxn.streams.has(n):
			sfxn.streams[n] = AudioStreamWAV.new()


# ---------------- loop ----------------

func _process(delta: float) -> void:
	_menu_tick(delta)
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
	_snap_items()
	_stream_items(delta)
	_grenades_tick(delta)
	# carros dos outros: seguem a posição recebida; o motorista vai junto no banco
	for v: Vehicle in vehicles:
		if not v.settled and Engine.get_physics_frames() > 4:
			v.settle()
		if v.driver != 0 and (v.driver != local_id or dedicated):
			v.follow(delta)
			var dp: Player = players.get(v.driver)
			if dp:
				dp.position = v.seat_pos()
				dp.target_pos = dp.position
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
		alive_cached = _alive_count()
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
		lp.hp = 200.0
	_local_update(lp, delta)
	_update_world_fx(delta)


# clima de guerra: vento seco sempre, e de vez em quando artilharia, rajada, sirene ou jato ao longe
var _amb_wind: AudioStreamPlayer
var _amb_t := 4.0


func _war_ambience(delta: float) -> void:
	if dedicated or sfxn == null or cam == null:
		return
	if _amb_wind == null:
		_amb_wind = AudioStreamPlayer.new()
		_amb_wind.stream = sfxn.streams.get("ambient_wind")
		add_child(_amb_wind)
	if _amb_wind.stream and not _amb_wind.playing:
		_amb_wind.play()
	_amb_wind.volume_db = sfxn.db(-17.0)
	_amb_t -= delta
	if _amb_t > 0.0:
		return
	_amb_t = randf_range(7.0, 18.0)
	var r := randf()
	var n := "far_boom" if r < 0.5 else ("far_mg" if r < 0.8 else ("far_jet" if r < 0.93 else "far_siren"))
	# vem de um lado (com fone dá pra saber de onde): longe, fora do mapa
	var a := randf() * TAU
	var p := cam.global_position + Vector3(cos(a), 0.2, sin(a)) * 160.0
	sfxn.play_at(n, p, {"far_boom": 4.0, "far_mg": -2.0, "far_jet": 0.0, "far_siren": -4.0}[n], 400.0, randf_range(0.85, 1.1), 70.0)


func _update_world_fx(_delta: float) -> void:
	_war_ambience(_delta)
	plane_node.visible = phase == PLANE and plane_t < plane_dur + 3.0
	if plane_node.visible:
		var dir := (plane_b - plane_a).normalized()
		var pp := plane_a.lerp(plane_b, plane_t / plane_dur)
		plane_node.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP), pp + Vector3(0, 3, 0))
		for pn in ["PropL", "PropR"]:
			var pr: Node3D = plane_node.get_node_or_null(pn)
			if pr:
				pr.rotate_object_local(Vector3.FORWARD, _delta * 38.0)
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
			want = "wind_fall"
		elif lp.air == 2:
			want = "wind_chute"
	if want != loop_kind:
		loop_kind = want
		if want == "":
			loop_player.stop()
		else:
			loop_player.stream = sfxn.streams[want]
			loop_player.volume_db = sfxn.db({"plane": -1.0, "wind_fall": -6.0, "wind_chute": -9.0}[want])
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
	_grenade_tick(lp, delta)
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
	hud.proned = lp.prone
	hud.can_start = phase == LOBBY and multiplayer.is_server() and not training
	var zoom: float = float(w["zoom"]) if lp.scoped else 1.0
	var look := hud.take_look()
	if hud.bag_open or hud.edit_mode:
		look = Vector2.ZERO
	var sens: float = 0.0046 * float(Cfg.get_v("sens")) / zoom
	if lp.scoped:
		sens *= float(Cfg.get_v("sens_ads"))
	var inv_y := -1.0 if bool(Cfg.get_v("invert")) else 1.0
	var firing: bool = (hud.fire_held or test_fire) and playing and lp.air == 0 and not hud.bag_open
	if firing and look.y < 0.0:
		up_drag += -look.y
	elif not firing:
		up_drag = maxf(up_drag - delta * 120.0, 0.0)
	# atrito da mira: com alvo grudado o dedo mexe menos a câmera (fica no peito; subir pra capa
	# pede arrastar mais)
	if firing and assist_target != 0 and players.has(assist_target) and int(Cfg.get_v("aim_assist")) > 0:
		sens *= 0.62
	if playing:
		cam_yaw_v -= look.x * sens
		cam_pitch_v = clampf(cam_pitch_v - look.y * sens * inv_y, -1.3, 1.25)
		if lp.car >= 0:
			# dirigindo: analógico acelera/freia e vira; sem atirar
			lp.wish = Vector3.ZERO
			_drive_local(lp, delta)
			firing = false
		var mv := hud.move_vec if not hud.bag_open and lp.car < 0 else Vector2.ZERO
		# correr automático: anda sozinho pra frente da câmera; mexer no analógico desliga
		if lp.sprint and mv.length() > 0.25:
			lp.sprint = false
		if lp.sprint and lp.air == 0:
			mv = Vector2(0, -1)
		lp.wish = Basis(Vector3.UP, cam_yaw_v) * Vector3(mv.x, 0, mv.y) if lp.air != 3 else Vector3.ZERO
		lp.pitch = cam_pitch_v
		# tocou no tiro: a mira puxa pro alvo e o corpo vira pra onde vai atirar, aí sai o tiro
		if firing and not _was_firing:
			_shot_pending = true
			_empty_done = false
			_press_t = 0.0
			assist_t = 0.0
			_snap_t = 0.14
			lp.aim_t = 0.7
		_was_firing = firing
		if not firing:
			lp.bloom = maxf(lp.bloom - delta * 4.0, 0.0)
		hud.cross_bloom = lp.bloom + clampf(Vector2(lp.velocity.x, lp.velocity.z).length() / 2.6, 0.0, 1.6) * 0.8
		if _snap_t > 0.0:
			_snap_t -= delta
		if firing or _shot_pending or _snap_t > 0.0 or lp.scoped:
			_aim_assist(lp, w, delta, not (firing or _shot_pending or _snap_t > 0.0))
		if firing or _shot_pending:
			_press_t += delta
			lp.aim_t = maxf(lp.aim_t, 0.3)
			var facing := absf(angle_difference(lp.yaw, cam_yaw_v)) < 0.2 or lp.cur_wid() == "fist"
			if (facing and _press_t >= 0.05) or _press_t > 0.2:
				var before := lp.cool
				_local_fire(lp)
				if lp.cool > before or not firing:
					_shot_pending = false
		hud.can_leave = can_leave_plane()
		if lp.air == 3 and (plane_frac() >= plane_j1() or (auto_jump >= 0.0 and plane_frac() >= auto_jump and can_leave_plane())):
			_on_action("leave")
	else:
		lp.wish = Vector3.ZERO
	# câmera
	var t := _view_target()
	var target_len := 1.55
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
	elif t and t.car >= 0 and t.car < vehicles.size():
		target_len = 5.6
		base = vehicles[t.car].global_position + Vector3(0, 0.6, 0)
		# dirigindo: a câmera vai pra trás do carro e acompanha a frente dele
		var vy: float = vehicles[t.car].yaw
		cy = lerp_angle(cam_yaw.rotation.y, vy, minf(1.0, 3.5 * delta))
		if t == lp:
			cam_yaw_v = cy
		cp = minf(cp, -0.18)
	elif t != lp:
		target_len = 4.5
	# mirando (com ou sem acessório): primeira pessoa, no olho, olhando pela mira da arma
	var fp := t == lp and lp.scoped and lp.air == 0 and lp.car < 0
	if fp:
		target_len = 0.0
		fov = 75.0 / zoom
	if not playing and t == lp:
		target_len = 5.0
		fp = false
	if lp.model:
		lp.model.visible = not fp
	cam_yaw.position = base + Vector3(0, 0.75 if (t and t.prone) else ((1.62 if fp else 1.55) if not (t and t.crouch) else (1.15 if fp else 1.1)), 0)
	cam_yaw.rotation.y = cy if t == lp else lerp_angle(cam_yaw.rotation.y, cy, minf(1.0, 6.0 * delta))
	cam_pitch.rotation.x = cp
	# ombro da câmera: se tem parede do lado, encosta a câmera no centro (não vê através da parede)
	var side := 0.0 if fp else 0.45
	if t and t.car >= 0:
		side = 0.0
	if t and t.air == 0 and not fp and t.car < 0:
		var from := cam_yaw.global_position
		var right := cam_pitch.global_transform.basis * Vector3(0.45 + 0.35, 0.15, 0)
		var q := PhysicsRayQueryParameters3D.create(from, from + right, 1)
		if t:
			q.exclude = [t.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			side = clampf(from.distance_to(hit["position"]) - 0.35, 0.0, 0.45)
	spring.position.x = lerpf(spring.position.x, side, minf(1.0, (25.0 if side < spring.position.x else 6.0) * delta))
	spring.spring_length = lerpf(spring.spring_length, target_len, minf(1.0, 8.0 * delta))
	cam.fov = lerpf(cam.fov, fov, minf(1.0, 12.0 * delta))
	if _shake > 0.0:
		_shake = maxf(_shake - delta, 0.0)
		cam.h_offset = randf_range(-0.15, 0.15) * _shake
		cam.v_offset = randf_range(-0.15, 0.15) * _shake
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
	hud.heals = [lp.count("bandage") + lp.count("drink"), lp.count("med")]
	hud.grenades = lp.count("grenade")
	hud.gren_left = (GREN_FUSE - gren_t) if gren_t >= 0.0 else -1.0
	hud.overlay = lp.scoped and bool(w["overlay"])
	hud.red_dot = lp.scoped and not bool(w["overlay"]) and ("holo" in lp.cur_att() or "scope2" in lp.cur_att())
	hud.iron = lp.scoped and not hud.overlay and not hud.red_dot
	_view_gun_tick(lp.scoped and lp.air == 0 and lp.car < 0 and playing and not hud.overlay, lp.cur_wid(), lp.cur_att(), delta)
	hud.can_scope = float(w["zoom"]) > 1.0
	hud.reloading = lp.reload_t > 0.0
	var sl := [{"id": "fist", "att": [], "ammo": 0, "max": 0}]
	for g in lp.guns:
		var gid: String = g["id"]
		sl.append({"id": gid, "att": g["att"], "ammo": int(lp.mag.get(gid, 0)) if gid != "" else 0, "max": int(Weapons.stat(gid, g["att"])["mag"]) if gid != "" else 0,
			"res": lp.count(Weapons.ammo_of(gid)) if gid != "" else 0})
	hud.slots = sl
	hud.bag_fill = float(Weapons.slots_used(lp.inv)) / maxf(1.0, float(lp.capacity()))
	hud.sel = lp.sel + 1
	hud.sprinting = lp.sprint
	hud.car_near = lp.car >= 0 or (lp.air == 0 and lp.alive and phase != LOBBY and near_vehicle(lp) >= 0)
	hud.driving = lp.car >= 0
	hud.refresh_bag(lp)


# Mira assistida: só puxa ao tocar/segurar o tiro ou ao abrir a mira. Gruda no peito de quem está
# mais perto da mira (empate: o mais perto de mim); de longe precisa estar mais perto da mira pra pegar.
# Arrastar pra cima atirando sobe pra cabeça (capa).
func _aim_assist(lp: Player, w: Dictionary, delta: float, only_far := false) -> void:
	var mode: int = int(Cfg.get_v("aim_assist"))
	# armas de munição de sniper (Kar98, AWM) não têm mira assistida
	if mode == 0 or (mode == 1 and lp.scoped) or lp.cur_wid() == "fist" or Weapons.ammo_of(lp.cur_wid()) == "a762":
		return
	assist_t -= delta
	var from := cam.global_position
	var fwd := -cam.global_transform.basis.z
	if assist_t <= 0.0:
		assist_t = 0.08
		assist_target = 0
		var best := 1e9
		var space := get_world_3d().direct_space_state
		for id in players:
			var o: Player = players[id]
			if o == lp or not o.alive or o.spect or o.air != 0:
				continue
			var tp := o.position + Vector3(0, o.head_y() - 0.45, 0)
			var d := tp - from
			var dist := d.length()
			if dist > minf(float(w["range"]), 150.0 if lp.scoped else 120.0) or dist < 1.0:
				continue
			# só mirando parado (sem atirar): puxa só quem está longe
			if only_far and dist < 35.0:
				continue
			var ang := fwd.angle_to(d / dist)
			# cone em graus "de tamanho de gente": quanto mais longe, mais fino (de longe um pouco mais largo)
			var lim := clampf(atan2(4.4, dist), 0.06 if dist > 50.0 else 0.04, 0.5)
			if ang > lim:
				continue
			var score := ang + lp.position.distance_to(o.position) * 0.0025
			if score >= best:
				continue
			var q := PhysicsRayQueryParameters3D.create(from, tp, 1)
			if not space.intersect_ray(q).is_empty():
				continue
			best = score
			assist_target = id
	var t: Player = players.get(assist_target)
	if t == null or not t.alive:
		return
	var head := up_drag > 30.0
	var aimp := t.position + Vector3(0, t.head_y() + 0.1 if head else t.head_y() - 0.45, 0)
	# acompanha quem corre (pouco, e com limite: nada de puxão doido)
	var tv: Vector3 = t.velocity
	var lead := Vector3(tv.x, 0, tv.z) * clampf(from.distance_to(aimp) / 400.0, 0.0, 0.12)
	aimp += lead.limit_length(1.2)
	var dir := (aimp - from).normalized()
	if fwd.angle_to(dir) > 0.6:
		return
	var wy := atan2(-dir.x, -dir.z)
	var wp := asin(clampf(dir.y, -1.0, 1.0))
	# de longe puxa um pouco mais (alvo pequeno na tela)
	var far_k := clampf((from.distance_to(aimp) - 40.0) / 60.0, 0.0, 1.0)
	var k := minf(1.0, ((34.0 if head else 32.0) + 14.0 * far_k) * delta)
	if _snap_t > 0.0:
		k = minf(1.0, 56.0 * delta)
	if only_far:
		k = minf(1.0, (6.0 + 8.0 * far_k) * delta)
	cam_yaw_v = lerp_angle(cam_yaw_v, wy, k)
	cam_pitch_v = lerpf(cam_pitch_v, wp, k)


# mirando em primeira pessoa: a arma de verdade na frente da câmera, olhando por cima dela
# (alça e massa / mira holográfica alinhadas no meio da tela)
var view_gun: Node3D
var _view_key := ""
var _view_k := 0.0
var _view_top := 0.0


func _view_gun_tick(on: bool, wid: String, att: Array, delta: float) -> void:
	if wid == "fist" or wid == "" or not GunInfo.INFO.has(wid):
		on = false
	var key := wid + "|" + ",".join(att)
	if on and key != _view_key:
		if view_gun:
			view_gun.queue_free()
		# a holográfica/luneta curta não entra no modelo: a janela dela é desenhada na tela
		var a2 := att.filter(func(a): return a != "holo" and a != "scope2")
		view_gun = Weapons.build_model(wid, a2)
		_view_key = key
		cam.add_child(view_gun)
		_view_top = 0.0
		for mi in view_gun.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var ab: AABB = (mi as MeshInstance3D).get_aabb()
			_view_top = maxf(_view_top, ab.end.y)
	_view_k = move_toward(_view_k, 1.0 if on else 0.0, delta * 7.0)
	if view_gun == null:
		return
	view_gun.visible = _view_k > 0.02
	if not view_gun.visible:
		return
	# olha por cima do ponto mais alto da arma (alça/massa de mira ficam logo abaixo do centro)
	var top: float = maxf(_view_top, float(GunInfo.INFO[wid]["rail"]))
	var pistol: bool = Weapons.get_w(wid)["type"] == "pistol"
	# entra de baixo/da direita enquanto levanta a arma
	var e := 1.0 - _view_k
	view_gun.position = Vector3(0.06 * e, -top - 0.006 - 0.12 * e, -(0.36 if pistol else 0.3))
	view_gun.rotation = Vector3(0.0, 0.25 * e, 0.0)


# item no chão melhor do que o que você tem (brilha dourado na faixa de coleta)
func _is_better(lp: Player, kind: String, extra = null) -> bool:
	if Weapons.is_vest(kind):
		var dur: float = float(extra) if (extra is float or extra is int) and float(extra) > 0.0 else 100.0
		return Weapons.level_of(kind) > lp.vest_lv or (Weapons.level_of(kind) == lp.vest_lv and dur > lp.armor + 15.0) or lp.armor <= 0.0
	if Weapons.is_helmet(kind):
		return Weapons.level_of(kind) > lp.helmet
	if Weapons.is_bag(kind):
		return int(kind.substr(3)) > lp.bag
	if Weapons.is_gun(kind):
		if lp.wants(kind):
			return true
		# arma mais forte que a mais fraca que você carrega no mesmo lugar
		var w := Weapons.get_w(kind)
		var worst := 1e9
		for i in ([2] if int(w["slot"]) == 1 else [0, 1]):
			var g: String = lp.guns[i]["id"]
			if g != "" and g != kind:
				worst = minf(worst, _gun_power(g))
		return worst < 1e8 and _gun_power(kind) > worst * 1.15
	if Weapons.is_att(kind):
		if not lp.wants(kind):
			return false
		# acessório com nível: só brilha se for de nível maior do que o já equipado
		var lv := Weapons.level_of(kind)
		for g in lp.guns:
			for a in g["att"]:
				if str(a).rstrip("0123456789") == kind.rstrip("0123456789") and Weapons.level_of(str(a)) >= lv:
					return false
		return true
	if Weapons.ITEMS.has(kind) and Weapons.ITEMS[kind]["kind"] == "ammo":
		# munição só brilha se for de uma arma equipada (pistola não conta) e estiver faltando
		var need := {"a556": 170, "a9": 170, "a762": 20, "a12": 30}
		for g in lp.guns:
			var gid: String = g["id"]
			if gid == "" or not Weapons.is_gun(gid) or Weapons.get_w(gid)["type"] == "pistol":
				continue
			if Weapons.ammo_of(gid) == kind:
				return lp.count(kind) < int(need.get(kind, 0))
		return false
	return false


func _gun_power(id: String) -> float:
	var w := Weapons.get_w(id)
	return float(w["dmg"]) * float(w.get("pellets", 1)) * float(w["rate"]) * (1.0 + float(w["range"]) / 200.0)


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
					list.append({"key": [i, j], "kind": e[0], "n": e[1], "label": Weapons.item_name(e[0]), "best": _is_better(lp, e[0], e[2] if e.size() > 2 else null)})
				continue
			# colete, capacete e mochila pegam sozinhos quando servem
			if (Weapons.is_vest(kind) or Weapons.is_helmet(kind) or Weapons.is_bag(kind)) and lp.wants(kind) and dd < 1.8 and now - int(auto_tried.get(i, 0)) > 1500:
				auto_tried[i] = now
				_to_server("req_pickup", [i, -1])
				continue
			list.append({"key": [i, -1], "kind": kind, "n": it.get("n", 1), "label": Weapons.item_name(kind), "best": _is_better(lp, kind, it.get("extra"))})
	hud.set_pickups(list)
	var me = info.get(local_id)
	hud.alive_n = _alive_count()
	hud.kills_n = me["kills"] if me else 0
	var t := _view_target()
	if sandbox:
		hud.set_spec("Modo teste: vida e munição sem fim")
	elif phase == LOBBY:
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
			if lp.air == 3 and phase == PLANE and can_leave_plane():
				lp.leave_plane(plane_exit())
				lp.velocity = Vector3.ZERO
				sfx("jump")
		"chute":
			if lp.air == 1:
				lp.air = 2
				sfx("chute", 4.0)
		"jump":
			lp.want_jump = true
		"crouch":
			if lp.air == 0:
				lp.set_crouch(not lp.crouch)
		"prone":
			if lp.air == 0 and lp.car < 0:
				lp.set_prone(not lp.prone)
		"reload":
			_start_reload(lp)
		"scope":
			if float(w["zoom"]) > 1.0 and lp.heal_t <= 0.0:
				lp.scoped = not lp.scoped
				if lp.scoped:
					_snap_t = 0.18
					assist_t = 0.0
				lp.aim_t = 0.5
				sfx("click", -6.0)
		"heal":
			_start_heal(lp, "")
		"pickup":
			var l: Array = []
			for c in hud.pick_list.get_children():
				l.append(c)
			if not l.is_empty():
				(l[-1] as Button).pressed.emit()
		"slot0", "slot1", "slot2", "slot3":
			_select(lp, int(act.substr(4)) - 1)
		"joy_touch":
			lp.sprint = false
		"car":
			_car_toggle(lp)
		"grenade_hold":
			_grenade_hold(lp)
		"grenade_throw":
			_throw_grenade(lp)
		"gren_cancel":
			if gren_t >= 0.0:
				gren_t = -1.0
				sfx("equip", -4.0)
		"sprint":
			lp.sprint = not lp.sprint
			if lp.sprint and lp.crouch:
				lp.set_crouch(false)
				lp.set_prone(false)
			if lp.sprint and lp.prone:
				lp.set_prone(false)
			sfx("click", -8.0)


# muda a arma na mão; tocar na que já está na mão guarda (mãos livres, corre mais)
func _select(lp: Player, s: int) -> void:
	if s >= 0 and lp.guns[s]["id"] == "":
		return
	# tocar na arma que já está na mão recarrega; só guarda tocando na mão
	if s == lp.sel and s >= 0:
		lp.scoped = false
		_start_reload(lp)
		return
	if s == lp.sel:
		return
	lp.sel = s
	lp.reload_t = 0.0
	# trocar ou guardar a arma desfaz a mira na hora
	lp.scoped = false
	_view_k = 0.0
	lp.update_gun()
	sfx("switch", 2.0)
	# arma vazia na mão: recarrega sozinha (depois de sacar)
	var wid := lp.cur_wid()
	if wid != "fist" and int(lp.mag.get(wid, 0)) <= 0:
		get_tree().create_timer(Player.DRAW_T).timeout.connect(func():
			if is_instance_valid(lp) and lp.alive and lp.cur_wid() == wid and int(lp.mag.get(wid, 0)) <= 0 and lp.count(Weapons.ammo_of(wid)) > 0:
				_start_reload(lp))


func _start_heal(lp: Player, kind: String) -> void:
	if lp.heal_t > 0.0:
		lp.heal_t = 0.0
		return
	if lp.hp >= 200.0 or lp.air != 0:
		return
	if kind == "":
		# escolhe o que faz mais sentido pra vida que falta
		var opts := ["med", "drink", "bandage"]
		kind = "med"
		for o in opts:
			if lp.count(o) > 0:
				kind = o
				break
	if lp.count(kind) <= 0:
		hud.center("Sem kit médico", 1.2, "bad")
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
		if phase != LOBBY and lp.count(Weapons.ammo_of(wid)) <= 0:
			hud.center("Sem munição", 1.2, "bad")
			return
		lp.reload_t = w["reload"]
		lp.scoped = false
		sfx("reload_out", 3.0)


func _local_fire(lp: Player) -> void:
	if lp.cool > 0.0 or lp.reload_t > 0.0 or lp.heal_t > 0.0 or lp.vault_t >= 0.0:
		return
	var wid := lp.cur_wid()
	var w := lp.cur_stat()
	var melee := wid == "fist"
	if not melee and lp.mag[wid] <= 0:
		if not _empty_done:
			sfx("empty")
			_empty_done = true
		_start_reload(lp)
		lp.cool = 0.3
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
		spread *= 0.6
	if lp.prone:
		spread *= 0.5
	# andando o tiro abre bem mais (parado/agachado é que é preciso)
	var hv := Vector2(lp.velocity.x, lp.velocity.z).length()
	if hv > 0.6:
		spread *= 1.0 + clampf(hv / 2.6, 0.4, 1.6)
	if not lp.is_on_floor():
		spread *= 2.0
	# segurando o dedo o tiro vai abrindo (cada arma do seu jeito); soltando volta a ficar preciso
	spread *= 1.0 + lp.bloom
	lp.bloom = minf(lp.bloom + float(w.get("bloom", 0.2)), float(w.get("bloom_max", 3.0)))
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
		elif col is Vehicle and not col.dead:
			hits.append(["car", col.idx])
		else:
			hits.append(-1)
	_to_server("req_fire", [origin, ends, hits, wid])
	if melee:
		sfx("punch_swing")
		if hits.size() > 0 and hits[0] is Array:
			sfx("punch_hit")
		return
	_shot_fx(lp, ends, wid, true)
	# sem coice: a mira não sobe; segurando o dedo o tiro só vai abrindo (bloom)
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
	p.aim_t = maxf(p.aim_t, 0.8)
	p.ready_t = 1.6
	if wid == "fist":
		sfx_at("punch_swing", p.position, local)
		return
	var att := p.att_of(wid)
	var far := cam != null and cam.global_position.distance_to(p.position) > 200.0
	var from := p.muzzle_pos()
	# tranco da arma no tiro (todo mundo vê); quem atira sente na câmera (mais forte quanto mais dano)
	var wd := Weapons.get_w(wid)
	p.kick = 1.0
	if local:
		var pk := clampf((float(wd["dmg"]) * float(wd["pellets"])) / 160.0, 0.25, 1.0)
		# armas pequenas (pistola e submetralhadora) tremem um pouco menos; as grandes, o tranco cheio
		var auto_k := 0.82 if str(wd["type"]) in ["pistol", "smg"] else 1.0
		_shake = maxf(_shake, (0.12 + 0.3 * pk) * auto_k)
		cam.fov += (1.2 + 2.5 * pk) * auto_k
	if not far:
		# sem traçante colorido: só a poeira no impacto e um clarão rápido de luz no cano
		for e in ends:
			_impact(from, e)
		if not ("silencer" in att) and cam and cam.global_position.distance_to(from) < 60.0:
			var fl := OmniLight3D.new()
			fl.light_color = Color(1.0, 0.75, 0.45)
			fl.light_energy = 0.8
			fl.omni_range = 2.2
			fl.shadow_enabled = false
			add_child(fl)
			fl.global_position = from
			get_tree().create_timer(0.04).timeout.connect(fl.queue_free)
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


# respingo de sangue curto (pode desligar nas configurações)
func _blood(at: Vector3) -> void:
	if cam == null or cam.global_position.distance_to(at) > 70.0:
		return
	for i in 4:
		var mi := MeshInstance3D.new()
		mi.mesh = U.box_mesh(Vector3(0.05, 0.05, 0.05))
		mi.material_override = U.mat(Color(0.45, 0.02, 0.02))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		mi.global_position = at + Vector3(randf_range(-0.12, 0.12), randf_range(-0.1, 0.1), randf_range(-0.12, 0.12))
		var tw := create_tween()
		tw.tween_property(mi, "global_position", mi.global_position + Vector3(randf_range(-0.4, 0.4), randf_range(-0.6, 0.1), randf_range(-0.4, 0.4)), 0.35)
		tw.parallel().tween_property(mi, "scale", Vector3(0.2, 0.2, 0.2), 0.35)
		tw.tween_callback(mi.queue_free)


# ---------------- marca de tiro ----------------
# Onde a bala bate (parede, chão, carro): furo escuro com borda lascada que fica um tempo,
# nuvenzinha de poeira e lascas voando. Em gente o sangue é outro efeito.
var _holes: Array = []
static var _hole_mat: StandardMaterial3D
static var _dust_mat: StandardMaterial3D
static var _chip_mat: StandardMaterial3D


static func _hole_tex() -> Texture2D:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var cracks := []
	for k in 6:
		cracks.append([rng.randf() * TAU, rng.randf_range(0.55, 1.0)])
	for y in n:
		for x in n:
			var v := Vector2(x - n / 2.0 + 0.5, y - n / 2.0 + 0.5) / (n / 2.0)
			var r := v.length()
			var ang := atan2(v.y, v.x)
			var a := 0.0
			var c := Color(0.08, 0.07, 0.06)
			if r < 0.22:
				a = 1.0
				c = Color(0.03, 0.03, 0.03)
			elif r < 0.5:
				# borda lascada e chamuscada
				a = 1.0 - smoothstep(0.3, 0.5, r) * 0.6
				c = Color(0.18, 0.16, 0.14).lerp(Color(0.32, 0.29, 0.25), (r - 0.22) / 0.28)
			for cr in cracks:
				var da := absf(wrapf(ang - float(cr[0]), -PI, PI))
				if r < float(cr[1]) and da < 0.06 * (1.0 - r) + 0.01:
					a = maxf(a, 0.8 * (1.0 - r / float(cr[1])))
			img.set_pixel(x, y, Color(c.r, c.g, c.b, clampf(a, 0.0, 1.0)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _impact(from: Vector3, to: Vector3) -> void:
	if cam == null or cam.global_position.distance_to(to) > 90.0:
		return
	var dir := (to - from).normalized()
	var q := PhysicsRayQueryParameters3D.create(to - dir * 0.6, to + dir * 0.4)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or hit["collider"] is Player:
		return
	var pos: Vector3 = hit["position"]
	var nrm: Vector3 = hit["normal"]
	if _hole_mat == null:
		_hole_mat = StandardMaterial3D.new()
		_hole_mat.albedo_texture = _hole_tex()
		_hole_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_hole_mat.roughness = 1.0
		_dust_mat = StandardMaterial3D.new()
		_dust_mat.albedo_texture = World.smoke_tex()
		_dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_dust_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_dust_mat.vertex_color_use_as_albedo = true
		_chip_mat = StandardMaterial3D.new()
		_chip_mat.vertex_color_use_as_albedo = true
	# furo (fica ~20 s; no máximo 60 no mapa)
	var hole := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2.ONE * randf_range(0.09, 0.13)
	hole.mesh = qm
	hole.material_override = _hole_mat
	hole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(hole)
	var up := Vector3.UP if absf(nrm.y) < 0.95 else Vector3.FORWARD
	hole.global_transform = Transform3D(Basis.looking_at(-nrm, up).rotated(nrm, randf() * TAU), pos + nrm * 0.006)
	_holes.append(hole)
	if _holes.size() > 60:
		var old = _holes.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	get_tree().create_timer(20.0).timeout.connect(func():
		if is_instance_valid(hole):
			_holes.erase(hole)
			hole.queue_free())
	# poeira saindo da parede/chão
	var dust := CPUParticles3D.new()
	var dq := QuadMesh.new()
	dq.size = Vector2(0.18, 0.18)
	dust.mesh = dq
	dust.material_override = _dust_mat
	dust.one_shot = true
	dust.explosiveness = 0.9
	dust.amount = 7
	dust.lifetime = 0.7
	dust.direction = nrm
	dust.spread = 30.0
	dust.initial_velocity_min = 0.8
	dust.initial_velocity_max = 2.2
	dust.gravity = Vector3(0, -1.5, 0)
	dust.damping_min = 2.0
	dust.damping_max = 3.0
	dust.scale_amount_min = 0.8
	dust.scale_amount_max = 1.8
	var cr := Curve.new()
	cr.add_point(Vector2(0, 0.5))
	cr.add_point(Vector2(1, 1.6))
	dust.scale_amount_curve = cr
	var gr := Gradient.new()
	gr.set_color(0, Color(0.62, 0.57, 0.5, 0.75))
	gr.set_color(1, Color(0.62, 0.57, 0.5, 0.0))
	dust.color_ramp = gr
	add_child(dust)
	dust.global_position = pos + nrm * 0.03
	dust.emitting = true
	# lascas (pedacinhos que caem)
	var chips := CPUParticles3D.new()
	chips.mesh = U.box_mesh(Vector3(0.018, 0.018, 0.018))
	chips.material_override = _chip_mat
	chips.one_shot = true
	chips.explosiveness = 1.0
	chips.amount = 5
	chips.lifetime = 0.6
	chips.direction = nrm
	chips.spread = 45.0
	chips.initial_velocity_min = 2.0
	chips.initial_velocity_max = 4.0
	chips.gravity = Vector3(0, -9.8, 0)
	chips.color = Color(0.3, 0.27, 0.23)
	add_child(chips)
	chips.global_position = pos + nrm * 0.02
	chips.emitting = true
	get_tree().create_timer(1.2).timeout.connect(func():
		dust.queue_free()
		chips.queue_free())


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
	_fill_bots()


# bots já ficam no lobby com todo mundo; abre vaga quando entra gente
func _fill_bots() -> void:
	var nb := clampi(bots_per_match, 0, MAX_PLAYERS - _human_count())
	var bots := []
	for id in players:
		if players[id].is_bot:
			bots.append(id)
	while bots.size() > nb:
		_all("remove_player", [bots.pop_back()])
	for i in nb - bots.size():
		var k := next_bot - 1000
		var nm: String = BOT_NAMES[k % BOT_NAMES.size()]
		_server_add_player(next_bot, "Bot " + nm, true)
		next_bot += 1


# arma de aquecimento no lobby (some quando entra no avião)
func _lobby_kit(p: Player) -> void:
	if p.is_bot or p.spect or phase != LOBBY:
		return
	_give(p, "m4a1", 1, null)
	_give(p, "glock", 1, null)


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
	if not bot:
		_lobby_kit(players[id])
		if phase == LOBBY:
			_fill_bots()
	if dedicated and not bot:
		print("[servidor] entrou: %s (%d)%s" % [nick, id, " (assistindo)" if spect else ""])


func _snapshot() -> Array:
	var arr := []
	for id in players:
		var p: Player = players[id]
		arr.append({
			"id": id, "name": info[id]["name"], "bot": info[id]["bot"], "kills": info[id]["kills"],
			"pos": p.position, "alive": p.alive, "spect": p.spect, "hp": p.hp, "guns": _guns_net(p),
			"armor": p.armor, "vest_lv": p.vest_lv, "helmet": p.helmet, "bag": p.bag, "air": p.air,
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
	if phase == LOBBY:
		_fill_bots()
	_check_end()


func _server_tick(delta: float) -> void:
	match phase:
		LOBBY:
			if sandbox:
				phase_t = 99999.0
			elif dedicated and _human_count() == 0 and not bots_only:
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
	regen_t += delta
	if regen_t >= 0.1:
		for id in players:
			var p: Player = players[id]
			if p.regen > 0.0:
				if not p.alive or p.hp >= 200.0:
					p.regen = 0.0
					continue
				var add := minf(p.regen, 45.0 * regen_t)
				p.regen -= add
				_all("on_hp", [id, minf(200.0, p.hp + add), p.armor, 0, false, 0.0])
		regen_t = 0.0
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
			buf.resize(ids.size() * SNAP_REC)
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
				buf.encode_u16(o + 21, p.flags() & 0xFFFF)
				o += SNAP_REC
			rpc("snap", buf)


func _server_board() -> void:
	_fill_bots()
	var nb := 0
	# todo mundo entra no avião sem nada (larga a arma do aquecimento)
	for id in players:
		var p: Player = players[id]
		if p.is_bot:
			nb += 1
		if not p.spect:
			_all("on_respawn", [id, p.position])
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
	# o avião aparece antes do mapa e some depois dele; só dá pra saltar em cima do mapa
	var a2 := c + dir * (t0 - PLANE_OUT)
	var b2 := c + dir * (t1 + PLANE_OUT)
	n_start = _alive_count()
	_all("plane_set", [Vector3(a2.x, PLANE_H, a2.y), Vector3(b2.x, PLANE_H, b2.y), a2.distance_to(b2) / PLANE_SPEED])
	_all("phase_set", [PLANE, 0.0])
	if dedicated:
		print("[servidor] partida começou com %d jogadores (%d bots)" % [n_start, nb])


func server_bot_jump(p: Player) -> void:
	if p.air != 3:
		return
	p.leave_plane(plane_exit())
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
	phase = LOBBY
	for id in players:
		_lobby_kit(players[id])
	_fill_bots()
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
			# bot contra bot no começo da partida machuca menos (sobra mais gente pro final)
			var bm := 0.75 * (lerpf(0.45, 1.0, p.bot_aggro()) if c.is_bot else 1.0)
			_acc(dmg, c.pid, w, (r["position"].y - c.position.y) > c.head_y(), bm, origin.distance_to(r["position"]))
	_server_apply(id, ends, dmg, wid)


func _acc(dmg: Dictionary, vid: int, w: Dictionary, head: bool, mult := 1.0, dist := 0.0) -> void:
	var amt: float = float(w["dmg"]) * (float(w["head"]) if head else 1.0) * mult * Weapons.falloff(w, dist)
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
	if phase == END:
		return
	if phase == LOBBY:
		# aquecimento: ninguém perde vida, mas quem atirou vê o dano
		var lv: Player = players.get(vid)
		if lv and aid > 0 and aid != vid:
			_all("on_hp", [vid, lv.hp, lv.armor, aid, head, amount])
		return
	var v: Player = players.get(vid)
	if v == null or not v.alive or v.spect:
		return
	if not raw and v.car >= 0:
		amount *= 0.75     # dentro do carro é mais difícil, mas dá pra acertar
	var broke := ""
	if not raw:
		# capacete segura parte do tiro na cabeça; colete segura parte do tiro no corpo (e vai gastando)
		if head and v.helmet > 0:
			var hab := amount * float(Weapons.HELMET_ABSORB[clampi(v.helmet, 0, 3)])
			amount -= hab
			v.helmet_hp -= hab * 1.5
			if v.helmet_hp <= 0.0:
				broke = "helmet"
		elif not head and v.armor > 0.0 and v.vest_lv > 0:
			# o colete só gasta levando tiro (zona, queda, carro e explosão não contam) e dura mais
			var ab := minf(v.armor / 0.6, amount * float(Weapons.VEST_ABSORB[clampi(v.vest_lv, 0, 3)]))
			v.armor = maxf(v.armor - ab * 0.6, 0.0)
			amount -= ab
			if v.armor <= 0.0:
				broke = "vest"
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
		# colete/capacete quebrou: some do corpo e avisa
		if broke != "":
			if broke == "helmet":
				v.helmet = 0
			else:
				v.vest_lv = 0
				v.armor = 0.0
			_p_inv(v)
			_all("on_gear_break", [vid, aid, broke])


@rpc("authority", "call_remote", "reliable")
func on_gear_break(vid: int, aid: int, what: String) -> void:
	if hud == null:
		return
	var v: Player = players.get(vid)
	if v:
		sfx_at("gear_break", v.position + Vector3(0, 1.4, 0), vid == local_id, 2.0, 40.0)
	var nm := "Capacete" if what == "helmet" else "Colete"
	if vid == local_id:
		hud.alert("%s quebrou!" % nm, "bad")
	elif aid == local_id:
		hud.alert("%s do inimigo quebrou" % nm, "good")


# Quem morre vira uma caixinha com tudo o que tinha
func _server_death_box(v: Player) -> void:
	var list := []
	for g in v.guns:
		if g["id"] != "":
			list.append([g["id"], 1, g["att"].duplicate()])
	for k in v.inv:
		if int(v.inv[k]) > 0:
			list.append([k, int(v.inv[k]), null])
	if v.armor > 0.0 and v.vest_lv > 0:
		list.append(["vest%d" % v.vest_lv, 1, v.armor])
	if v.helmet > 0:
		list.append(["helmet%d" % v.helmet, 1, v.helmet_hp])
	if v.bag > 0:
		list.append(["bag%d" % v.bag, 1, null])
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
	_all("on_inv", [p.pid, p.inv.duplicate(), p.armor, p.vest_lv, p.helmet, p.bag])


func _p_guns(p: Player, sel: int) -> void:
	_all("on_loadout", [p.pid, _guns_net(p), sel])


# Dá um item pro jogador. Devolve quantos ele conseguiu pegar.
# force: o jogador tocou no item (pega mesmo sendo de nível menor; troca pelo que está usando)
func _give(p: Player, kind: String, n: int, extra, force := false) -> int:
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
		if old["id"] != "":
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
			if not Weapons.fits(kind, g["id"]) or kind in g["att"]:
				continue
			var old := Weapons.same_cat(kind, g["att"])
			if old != "" and Weapons.level_of(old) >= Weapons.level_of(kind):
				continue
			if old != "":
				g["att"].erase(old)
				if p.free_slots() > 0:
					p.inv[old] = p.count(old) + 1
				else:
					_server_drop(old, p.position)
			g["att"].append(kind)
			_p_guns(p, p.sel)
			_p_inv(p)
			return 1
		if p.free_slots() > 0:
			p.inv[kind] = p.count(kind) + 1
			_p_inv(p)
			return 1
		return 0
	if Weapons.is_vest(kind):
		var lv := Weapons.level_of(kind)
		var dur: float = float(extra) if (extra is float or extra is int) and float(extra) > 0.0 else 100.0
		if not force and (lv < p.vest_lv or (lv == p.vest_lv and dur <= p.armor + 1.0)):
			return 0
		if p.vest_lv > 0 and p.armor > 0.0:
			_server_drop("vest%d" % p.vest_lv, p.position, 1, p.armor)
		p.vest_lv = lv
		p.armor = dur
		_p_inv(p)
		return 1
	if Weapons.is_helmet(kind):
		var lv := Weapons.level_of(kind)
		var hd: float = float(extra) if (extra is float or extra is int) and float(extra) > 0.0 else 100.0
		if not force and (lv < p.helmet or (lv == p.helmet and hd <= p.helmet_hp + 1.0)):
			return 0
		if p.helmet > 0:
			_server_drop("helmet%d" % p.helmet, p.position, 1, p.helmet_hp)
		p.helmet = lv
		p.helmet_hp = hd
		_p_inv(p)
		return 1
	if Weapons.is_bag(kind):
		var lv := int(kind.substr(3))
		if lv == p.bag or (lv < p.bag and not force):
			return 0
		if p.bag > 0:
			_server_drop("bag%d" % p.bag, p.position)
		p.bag = lv
		_p_inv(p)
		return 1
	if not Weapons.ITEMS.has(kind):
		return 0
	# cabe o quanto sobrar de espaço (por quantidade)
	var others := {}
	for k in p.inv:
		if k != kind:
			others[k] = p.inv[k]
	var room := floori((p.capacity() - Weapons.slots_used(others)) / Weapons.weight(kind) + 0.001) - p.count(kind)
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
			var got := _give(p, e[0], int(e[1]), e[2], sub >= 0 and not p.is_bot)
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
	var got := _give(p, it["kind"], n, it.get("extra", null), not p.is_bot)
	if got <= 0:
		return
	if got >= n:
		_all("on_item", [i, false])
	else:
		_all("on_item_n", [i, n - got])


# munição gasta numa recarga
func ammo_used(p: Player, kind: String, n: int) -> void:
	if multiplayer.is_server():
		p.inv[kind] = maxi(p.count(kind) - n, 0)
		_p_inv(p)
	else:
		p.inv[kind] = maxi(p.count(kind) - n, 0)
		rpc_id(1, "req_ammo", kind, n)


func fall_damage(p: Player, dmg: float) -> void:
	if multiplayer.is_server():
		_server_damage(p.pid, -1, dmg, false, "queda", true)
	else:
		rpc_id(1, "req_fall", dmg)


@rpc("any_peer", "call_remote", "reliable")
func req_ammo(kind: String, n: int) -> void:
	if not multiplayer.is_server():
		return
	var p: Player = players.get(_sender())
	if p and p.alive:
		p.inv[kind] = maxi(p.count(kind) - clampi(n, 0, 200), 0)
		_p_inv(p)


@rpc("any_peer", "call_remote", "reliable")
func req_fall(dmg: float) -> void:
	if multiplayer.is_server():
		_server_damage(_sender(), -1, clampf(dmg, 0.0, 200.0), false, "queda", true)


func _server_heal(id: int, kind: String) -> void:
	var p: Player = players.get(id)
	if p == null or not p.alive or not Weapons.ITEMS.has(kind) or p.count(kind) <= 0 or p.hp >= 200.0:
		return
	p.inv[kind] = p.count(kind) - 1
	_p_inv(p)
	# a vida enche aos poucos depois que termina de usar o kit/bandagem
	p.regen += float(Weapons.ITEMS[kind]["heal"])


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
		if h[0] is String:
			if h[0] == "car" and int(h[1]) >= 0 and int(h[1]) < vehicles.size():
				var vc: Vehicle = vehicles[int(h[1])]
				if not vc.dead and vc.global_position.distance_to(ends[i]) < 5.0:
					_server_car_damage(vc, float(w["dmg"]), id)
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
		_acc(dmg, v.pid, w, bool(h[1]), 1.0, along)
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
			if p.armor <= 0.0 or p.vest_lv <= 0:
				return
			_server_drop("vest%d" % p.vest_lv, p.position, 1, p.armor)
			p.armor = 0.0
			p.vest_lv = 0
		"helmet":
			if p.helmet <= 0:
				return
			_server_drop("helmet%d" % p.helmet, p.position, 1, p.helmet_hp)
			p.helmet = 0
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
			# troca a peça da mesma categoria (a velha volta pra mochila)
			var old := Weapons.same_cat(att, g["att"])
			p.inv[att] = p.count(att) - 1
			if old != "":
				g["att"].erase(old)
				p.inv[old] = p.count(old) + 1
			g["att"].append(att)
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
		p.vest_lv = int(e.get("vest_lv", 0))
		p.helmet = int(e["helmet"])
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


# registro de cada jogador no pacote: id, posição, giro, mira, arma e os estados (16 bits)
const SNAP_REC := 23


@rpc("authority", "call_remote", "unreliable_ordered")
func snap(buf: PackedByteArray) -> void:
	var o := 0
	while o + SNAP_REC <= buf.size():
		var id := buf.decode_s32(o)
		if id != local_id:
			var p: Player = players.get(id)
			if p:
				var pos := Vector3(buf.decode_float(o + 4), buf.decode_float(o + 8), buf.decode_float(o + 12))
				var wi := buf.decode_u8(o + 20)
				p.net_target(pos, buf.decode_s16(o + 16) / 10000.0, buf.decode_s16(o + 18) / 20000.0, WIDS[wi] if wi < WIDS.size() else "fist", buf.decode_u16(o + 21))
		o += SNAP_REC


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
		hud.center("A zona vai fechar! Veja o círculo branco no mapa.", 3.0, "warn")
		sfx("zone")


@rpc("authority", "call_remote", "reliable")
func on_hp(vid: int, hp: float, armor: float, aid: int, head: bool, amount: float) -> void:
	var v: Player = players.get(vid)
	var old := 200.0
	if v:
		old = v.hp
		v.hp = hp
		v.armor = armor
		v.refresh_gear()
	if hud == null:
		return
	if hp > old and vid == local_id and Time.get_ticks_msec() - _heal_snd > 2500:
		_heal_snd = Time.get_ticks_msec()
		sfx("heal_done")
	# acerto (vale também no lobby, onde ninguém perde vida: mostra quanto teria tirado)
	if amount > 0.0 and aid == local_id and vid != local_id:
		hud.hit(head, false)
		# o tiro que mata não toca o "tic" de acerto: só o estrondo do abate
		if hp <= 0.0:
			pass
		# o "tim" metálico só quando bate no capacete
		elif head and v and v.helmet > 0:
			sfx("headshot", -6.0)
		elif head:
			sfx("head_flesh", -3.0)
		else:
			sfx("hit", -6.0)
		if v:
			hud.dmg_number(v.position, amount, head, false)
	if amount > 0.0 and v and aid != 0 and bool(Cfg.get_v("blood")):
		_blood(v.position + Vector3(0, v.head_y() - (0.0 if head else 0.45), 0))
	if hp < old:
		if vid == local_id:
			# dano da zona não faz barulho (só o aviso vermelho na tela)
			if aid != 0:
				sfx("hurt", -4.0)
			var a: Player = players.get(aid)
			if a and v:
				var d := a.position - v.position
				var wy := atan2(-d.x, -d.z)
				hud.hurt(-angle_difference(cam_yaw_v, wy))
			else:
				hud.hurt()


@rpc("authority", "call_remote", "reliable")
func on_died(vid: int, aid: int, wid: String, head: bool, rank: int, amount: float) -> void:
	var v: Player = players.get(vid)
	var vpos := v.position if v else Vector3.ZERO
	if v and v.car >= 0 and v.car < vehicles.size():
		vehicles[v.car].driver = 0
		vehicles[v.car].speed = 0.0
		v.car = -1
	if v:
		v.die()
	if info.has(aid) and aid != vid:
		info[aid]["kills"] += 1
	if dedicated:
		print("[morte] %s <- %s (%s)" % [info[vid]["name"] if info.has(vid) else "?", info[aid]["name"] if info.has(aid) else "-", wid])
	if hud == null:
		return
	var kn: String = info[aid]["name"] if info.has(aid) else "?"
	var vn: String = info[vid]["name"] if info.has(vid) else "?"
	var mine := aid == local_id or vid == local_id
	var col := Color(1, 0.85, 0.35) if mine else Color.WHITE
	if wid == "queda":
		hud.feed("%s caiu de muito alto" % vn, col)
	elif wid == "carro":
		hud.feed("%s atropelou %s" % [kn, vn], col)
	elif wid == "granada":
		hud.feed("%s  [Granada]  %s" % [kn, vn], col)
	elif wid == "explosão":
		hud.feed("%s explodiu %s" % [kn, vn] if kn != vn else "%s explodiu" % vn, col)
	elif wid == "zona" or aid == 0:
		hud.feed("%s morreu na zona" % vn, col)
	else:
		hud.feed("%s  [%s%s]  %s" % [kn, Weapons.get_w(wid)["name"], " · cabeça" if head else "", vn], col)
	if aid == local_id and vid != local_id:
		hud.hit(head, true)
		hud.kill_banner(vn, head, int(info[local_id]["kills"]) if info.has(local_id) else 0)
		sfx("kill", 3.0)
		hud.dmg_number(vpos, amount, head, true)
	if vid == local_id:
		my_rank = rank
		hud.hurt()
		hud.big_map = false
		hud.set_bag(false)
		spec_id = aid if players.has(aid) and aid != vid else 0
		if spec_id == 0:
			_spec_next()
		var me = info.get(local_id)
		var why := "na queda" if wid == "queda" else ("na zona" if (wid == "zona" or aid == 0) else "por %s" % kn)
		hud.center("Eliminado %s\nColocação: #%d    Abates: %d    Dano: %d" % [why, rank, me["kills"] if me else 0, int(me["dmg"]) if me else 0], 7.0, "bad")
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
		hud.victory("Último de pé    ·    Abates: %d    ·    Dano: %d" % [k, dmg])
		_victory_music()
	else:
		var wn: String = info[id]["name"] if info.has(id) else "Ninguém"
		var lp: Player = players.get(local_id)
		var rk := "" if lp == null or lp.spect else "\nVocê ficou em #%d    Abates: %d    Dano: %d" % [my_rank, k, dmg]
		hud.center("%s venceu a partida!%s" % [wn, rk], 999.0)


@rpc("authority", "call_remote", "reliable")
func match_reset() -> void:
	phase = LOBBY
	_spawn_vehicles()
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
	_victory_music_off()
	if hud:
		hud.center("", 0.0)
		hud.win_t = -1.0
		hud.win_ctl.queue_redraw()
		hud.can_retry = false


@rpc("authority", "call_remote", "reliable")
func on_respawn(id: int, pos: Vector3) -> void:
	var p: Player = players.get(id)
	if p:
		p.reset_state(pos)
	if id == local_id:
		_seen_guns = ["", "", ""]
		_seen_inv = {}
		_seen_gear = [0, 0, 0, 0.0]


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
	p.update_back_guns()
	if id == local_id and hud:
		# compara com o que eu já tinha visto (no treino o servidor muda o jogador antes)
		for i in 3:
			var gid: String = g[i][0]
			if gid != "" and gid != _seen_guns[i]:
				hud.center(Weapons.item_name(gid), 1.2)
			_seen_guns[i] = gid
		sfx("equip", -4.0)


@rpc("authority", "call_remote", "reliable")
func on_inv(id: int, inv: Dictionary, armor: float, vest_lv: int, helmet: int, bag: int) -> void:
	var p: Player = players.get(id)
	if p == null:
		return
	if id == local_id and hud:
		var gained: bool = vest_lv > int(_seen_gear[0]) or helmet > int(_seen_gear[1]) or bag > int(_seen_gear[2]) or armor > float(_seen_gear[3]) + 1.0
		for k in inv:
			if int(inv[k]) > int(_seen_inv.get(k, 0)):
				gained = true
		if gained:
			sfx("pickup", -3.0)
		if vest_lv > int(_seen_gear[0]):
			hud.center("Colete nível %d equipado" % vest_lv, 1.2)
		elif helmet > int(_seen_gear[1]):
			hud.center("Capacete nível %d equipado" % helmet, 1.2)
		elif bag > int(_seen_gear[2]):
			hud.center("Mochila nível %d: espaço %d" % [bag, Weapons.BAGS[bag]], 1.5)
		_seen_inv = inv.duplicate()
		_seen_gear = [vest_lv, helmet, bag, armor]
	p.inv = inv
	p.armor = armor
	p.vest_lv = vest_lv
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
	elif avail and not dedicated and i < world.items.size():
		# voltou a existir (partida nova): monta se estiver perto
		var p: Vector3 = world.items[i]["pos"]
		if _item_live.has(Vector2i(floori(p.x / ITEM_CELL), floori(p.z / ITEM_CELL))):
			_item_build_q.append(i)


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
		_grid_add(i)
		# barulho de item caindo no chão (largou da mochila / trocou de arma)
		if nm == "" and in_game and not _quiet_spawn and sfxn:
			sfxn.play_at("drop", pos, -3.0, 30.0)
