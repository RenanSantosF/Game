class_name MapEditor
extends Node

# Editor de cenário dentro do jogo (pelo celular).
# Câmera livre: analógico à esquerda anda, arrastar à direita olha em volta, ▲▼ sobe e desce.
# Toque rápido num objeto seleciona; o painel de baixo move, gira, sobe/desce, aumenta, apaga e duplica.
# "+ ADICIONAR" coloca peças novas onde a mira do meio está olhando.
# Tudo é salvo no aparelho na hora (user://map_edits.json); "COPIAR" copia as alterações em texto
# pra colar no chat e entrar no jogo de todo mundo (res://data/map_edits.json).

const NAMES := {"house": "Casa", "shack": "Barraco", "warehouse": "Galpão", "church": "Igreja", "barracks": "Alojamento",
	"store": "Loja", "crates": "Caixotes", "barrel": "Barril", "container": "Contêiner", "sandbags": "Sacos de areia",
	"barrier": "Barreira de concreto", "barricade": "Barricada de madeira", "gun_crate": "Caixote com arma", "low_wall": "Muro",
	"fence": "Cerca", "ruin": "Ruína", "watchtower": "Torre de vigia", "water_tower": "Caixa d'água", "silo": "Silo",
	"hay": "Feno", "logs": "Toras", "radio_tower": "Torre de rádio", "well": "Poço", "pole": "Poste", "pier": "Píer",
	"boat": "Barco", "wagon": "Vagão", "car": "Carro abandonado", "oak": "Árvore", "pine": "Pinheiro", "tall": "Árvore alta",
	"bush": "Moita", "rock": "Pedra", "log": "Tronco caído"}
const ADD_LIST := ["barricade", "sandbags", "crates", "gun_crate", "barrier", "barrel", "container", "car", "low_wall",
	"fence", "hay", "logs", "rock", "oak", "pine", "bush", "log", "ruin", "shack", "house", "watchtower", "well"]

var game: Node
var world: World
var data: Dictionary
var cam: Camera3D
var yaw := 0.0
var pitch := -0.55
var fast := false
var sel := ""
var hl: MeshInstance3D
var undo: Array = []
var ui: CanvasLayer
var info_lbl: Label
var count_lbl: Label
var toast_lbl: Label
var toast_t := 0.0
var sel_panel: PanelContainer
var add_panel: PanelContainer
var top_bar: HBoxContainer
var cam_btns: VBoxContainer
var joy_draw: Control
var clear_t := 0.0
# toques
var joy_id := -1
var joy_c := Vector2.ZERO
var joy_v := Vector2.ZERO
var look_id := -1
var look_start := Vector2.ZERO
var look_t := 0.0
var look_moved := false
# botão segurado (repete)
var hold := ""
var hold_t := 0.0
var cam_v := 0.0


func _ready() -> void:
	data = world.edit_data
	cam = Camera3D.new()
	cam.far = 600.0
	cam.fov = 65.0
	world.add_child(cam)
	var c: Vector2 = world.towns[11]["pos"]
	cam.position = Vector3(c.x + 30.0, world.height(c.x + 30.0, c.y + 30.0) + 25.0, c.y + 30.0)
	yaw = atan2(30.0, 30.0)
	cam.current = true
	hl = MeshInstance3D.new()
	var bm := BoxMesh.new()
	hl.mesh = bm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(1.0, 0.8, 0.1, 0.22)
	hl.material_override = m
	hl.visible = false
	hl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(hl)
	_build_ui()
	_update_count()
	_toast("Modo editor: analógico anda, arraste à direita pra olhar, toque num objeto pra selecionar", 5.0)


# ---------------- interface ----------------

func _btn(t: String, cb: Callable, holdable := "", w := 0.0) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 20)
	b.custom_minimum_size = Vector2(maxf(w, 64.0), 56.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.08, 0.14, 0.82)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(6)
	var sp := sb.duplicate()
	sp.bg_color = Color(1.0, 0.72, 0.2, 0.9)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sp)
	if holdable != "":
		b.button_down.connect(func():
			hold = holdable
			hold_t = -0.35
			_hold_step(holdable))
		b.button_up.connect(func(): hold = "")
	elif cb.is_valid():
		b.pressed.connect(cb)
	return b


func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.04, 0.08, 0.6)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(6)
	p.add_theme_stylebox_override("panel", sb)
	return p


func _label(t: String, size: int) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	return l


func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	joy_draw = Control.new()
	joy_draw.set_anchors_preset(Control.PRESET_FULL_RECT)
	joy_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joy_draw.draw.connect(_draw_overlay)
	ui.add_child(joy_draw)
	# barra de cima
	top_bar = HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 6)
	top_bar.position = Vector2(10, 10)
	ui.add_child(top_bar)
	top_bar.add_child(_btn("SAIR", _exit))
	top_bar.add_child(_btn("DESFAZER", _undo))
	top_bar.add_child(_btn("+ ADICIONAR", func(): add_panel.visible = not add_panel.visible))
	top_bar.add_child(_btn("COPIAR", _copy))
	top_bar.add_child(_btn("LIMPAR", _clear))
	top_bar.add_child(_btn("▶ JOGAR AQUI", _play))
	count_lbl = _label("", 16)
	top_bar.add_child(count_lbl)
	# câmera: subir/descer e velocidade (direita)
	cam_btns = VBoxContainer.new()
	cam_btns.add_theme_constant_override("separation", 6)
	cam_btns.anchor_left = 1.0
	cam_btns.anchor_right = 1.0
	cam_btns.offset_left = -150
	cam_btns.offset_right = -46
	cam_btns.offset_top = 96
	cam_btns.add_theme_constant_override("separation", 10)
	ui.add_child(cam_btns)
	var bu := _btn("▲\nSOBE", Callable(), "cam_up")
	var bd := _btn("▼\nDESCE", Callable(), "cam_down")
	for bb in [bu, bd]:
		bb.custom_minimum_size = Vector2(104, 96)
		bb.add_theme_font_size_override("font_size", 22)
		cam_btns.add_child(bb)
	var fb := _btn("x1", Callable())
	fb.custom_minimum_size = Vector2(104, 60)
	fb.pressed.connect(func():
		fast = not fast
		fb.text = "x4" if fast else "x1")
	cam_btns.add_child(fb)
	# mira do meio
	var info_box := _panel()
	info_box.position = Vector2(10, 76)
	ui.add_child(info_box)
	info_lbl = _label("Nada selecionado", 16)
	info_box.add_child(info_lbl)
	toast_lbl = _label("", 18)
	toast_lbl.anchor_left = 0.0
	toast_lbl.anchor_right = 1.0
	toast_lbl.anchor_top = 0.5
	toast_lbl.anchor_bottom = 0.5
	toast_lbl.offset_top = -120
	toast_lbl.offset_bottom = -80
	toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	toast_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tl := CanvasLayer.new()
	tl.layer = 6
	add_child(tl)
	tl.add_child(toast_lbl)
	# painel do objeto selecionado (embaixo, à direita do analógico)
	sel_panel = _panel()
	sel_panel.anchor_left = 1.0
	sel_panel.anchor_right = 1.0
	sel_panel.anchor_top = 1.0
	sel_panel.anchor_bottom = 1.0
	sel_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	sel_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	sel_panel.offset_right = -10
	sel_panel.offset_bottom = -10
	sel_panel.visible = false
	ui.add_child(sel_panel)
	var g := GridContainer.new()
	g.columns = 6
	g.add_theme_constant_override("h_separation", 5)
	g.add_theme_constant_override("v_separation", 5)
	sel_panel.add_child(g)
	for e in [["⟲ GIRA", "rot_l"], ["▲ FRENTE", "fwd"], ["GIRA ⟳", "rot_r"], ["SOBE", "up"], ["MAIOR", "big"], ["CHÃO", ""],
			["◄ ESQ", "left"], ["▼ TRÁS", "back"], ["DIR ►", "right"], ["DESCE", "down"], ["MENOR", "small"], ["AQUI", ""],
			["INCLINA ▲", "tilt_f"], ["INCLINA ▼", "tilt_b"], ["INCLINA ◄", "tilt_l"], ["INCLINA ►", "tilt_r"], ["RETO", ""], ["DUPLICAR", ""],
			["APAGAR", ""], ["PRONTO", ""]]:
		var b: Button
		match e[0]:
			"CHÃO":
				b = _btn(e[0], _snap_ground)
			"AQUI":
				b = _btn(e[0], _move_here)
			"DUPLICAR":
				b = _btn(e[0], _duplicate)
			"RETO":
				b = _btn(e[0], _straighten)
			"APAGAR":
				b = _btn(e[0], _delete)
			"PRONTO":
				b = _btn(e[0], func(): _select(""))
			_:
				b = _btn(e[0], Callable(), e[1])
		b.add_theme_font_size_override("font_size", 16)
		b.custom_minimum_size = Vector2(92, 52)
		g.add_child(b)
	# lista de peças pra adicionar
	add_panel = _panel()
	add_panel.anchor_left = 0.5
	add_panel.anchor_right = 0.5
	add_panel.anchor_top = 0.5
	add_panel.anchor_bottom = 0.5
	add_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_panel.visible = false
	ui.add_child(add_panel)
	var av := VBoxContainer.new()
	add_panel.add_child(av)
	av.add_child(_label("Escolha a peça (vai pra onde a mira do meio aponta)", 16))
	var ag := GridContainer.new()
	ag.columns = 5
	ag.add_theme_constant_override("h_separation", 5)
	ag.add_theme_constant_override("v_separation", 5)
	av.add_child(ag)
	for k in ADD_LIST:
		var b := _btn(NAMES[k], _add.bind(k))
		b.add_theme_font_size_override("font_size", 15)
		b.custom_minimum_size = Vector2(150, 48)
		ag.add_child(b)
	av.add_child(_btn("FECHAR", func(): add_panel.visible = false))


func _draw_overlay() -> void:
	var s := joy_draw.size
	# mira do meio
	var c := s / 2.0
	joy_draw.draw_circle(c, 4.0, Color(1, 1, 1, 0.9))
	joy_draw.draw_arc(c, 12.0, 0, TAU, 24, Color(1, 1, 1, 0.5), 2.0)
	# analógico
	var base := joy_c if joy_id >= 0 else Vector2(130, s.y - 130)
	joy_draw.draw_circle(base, 80.0, Color(1, 1, 1, 0.08))
	joy_draw.draw_arc(base, 80.0, 0, TAU, 40, Color(1, 1, 1, 0.3), 2.0)
	joy_draw.draw_circle(base + joy_v * 80.0, 30.0, Color(1, 1, 1, 0.3))


func _over_ui(p: Vector2) -> bool:
	for c in [top_bar, cam_btns, sel_panel, add_panel]:
		if (c as Control).visible and (c as Control).get_global_rect().grow(4.0).has_point(p):
			return true
	return false


func _toast(t: String, d := 3.0) -> void:
	toast_lbl.text = t
	toast_t = d


func _update_count() -> void:
	count_lbl.text = "%d alterações" % MapEdits.count(data)


# ---------------- toques ----------------

func _input(ev: InputEvent) -> void:
	var vw := get_viewport().get_visible_rect().size
	if ev is InputEventScreenTouch:
		if ev.pressed:
			if _over_ui(ev.position):
				return
			if ev.position.x < vw.x * 0.35 and ev.position.y > vw.y * 0.35 and joy_id < 0:
				joy_id = ev.index
				joy_c = ev.position
				joy_v = Vector2.ZERO
			elif look_id < 0:
				look_id = ev.index
				look_start = ev.position
				look_t = 0.0
				look_moved = false
		else:
			if ev.index == joy_id:
				joy_id = -1
				joy_v = Vector2.ZERO
			elif ev.index == look_id:
				look_id = -1
				if not look_moved and look_t < 0.4:
					_pick(ev.position)
	elif ev is InputEventScreenDrag:
		if ev.index == joy_id:
			joy_v = ((ev.position - joy_c) / 80.0).limit_length(1.0)
		elif ev.index == look_id:
			if ev.position.distance_to(look_start) > 14.0:
				look_moved = true
			yaw -= ev.relative.x * 0.005
			pitch = clampf(pitch - ev.relative.y * 0.005, -1.5, 1.2)
	# PC (testes): clique esquerdo seleciona, direito arrasta pra olhar
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed and not DisplayServer.is_touchscreen_available():
		if not _over_ui(ev.position):
			_pick(ev.position)
	elif ev is InputEventMouseMotion and (ev.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
		yaw -= ev.relative.x * 0.005
		pitch = clampf(pitch - ev.relative.y * 0.005, -1.5, 1.2)


func _process(delta: float) -> void:
	if toast_t > 0.0:
		toast_t -= delta
		toast_lbl.modulate.a = clampf(toast_t * 2.0, 0.0, 1.0)
	if playing:
		return
	look_t += delta
	# teclado (PC): WASD anda, Q/E sobe e desce
	var kv := Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down"))
	var mv := joy_v if joy_v.length() > 0.05 else kv
	var sp := (40.0 if fast else 12.0) * delta
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var rt := Vector3(cos(yaw), 0, -sin(yaw))
	cam.position += (rt * mv.x - fwd * mv.y) * sp
	cam.position.y += cam_v * sp
	var gh := world.height(cam.position.x, cam.position.z)
	cam.position.y = clampf(cam.position.y, gh + 0.6, gh + 160.0)
	cam.rotation = Vector3(pitch, yaw, 0)
	if hold != "":
		hold_t += delta
		while hold_t > 0.08:
			hold_t -= 0.08
			_hold_step(hold)
	cam_v = 1.0 if hold == "cam_up" else (-1.0 if hold == "cam_down" else 0.0)
	if clear_t > 0.0:
		clear_t -= delta
	if hl.visible:
		(hl.material_override as StandardMaterial3D).albedo_color.a = 0.16 + 0.1 * sin(Time.get_ticks_msec() * 0.006)
	joy_draw.queue_redraw()


# ---------------- seleção ----------------

func _pick(p: Vector2) -> void:
	add_panel.visible = false
	var from := cam.project_ray_origin(p)
	var to := from + cam.project_ray_normal(p) * 600.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	var r := world.get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		_select("")
		return
	var n: Node = r["collider"]
	while n and not n.has_meta("key"):
		n = n.get_parent()
	_select(String(n.get_meta("key")) if n else "")


func _select(key: String) -> void:
	sel = key
	sel_panel.visible = key != ""
	_refresh_sel()


func _refresh_sel() -> void:
	var node := _node_of(sel)
	if sel == "" or node == null:
		hl.visible = false
		info_lbl.text = "Nada selecionado" if sel == "" else "%s (apagado)" % NAMES.get(_kind_of(sel), _kind_of(sel))
		return
	var ab := _aabb(node)
	hl.visible = ab.size != Vector3.ZERO
	hl.position = ab.get_center()
	(hl.mesh as BoxMesh).size = ab.size + Vector3.ONE * 0.1
	var st := _state(sel)
	var changed := sel.begins_with("+") or (data["e"] as Dictionary).has(sel)
	info_lbl.text = "%s%s\ngiro %d°  inclinação %d° / %d°  tamanho %d%%" % [NAMES.get(_kind_of(sel), _kind_of(sel)), " (novo)" if sel.begins_with("+") else (" (alterado)" if changed else ""),
		roundi(rad_to_deg(float(st["r"]))), roundi(rad_to_deg(float(st["tx"]))), roundi(rad_to_deg(float(st["tz"]))), roundi(float(st["s"]) * 100.0)]


func _aabb(n: Node) -> AABB:
	var out := AABB()
	var first := true
	for c in n.find_children("*", "VisualInstance3D", true, false):
		var vi := c as VisualInstance3D
		if not vi.is_visible_in_tree():
			continue
		var a: AABB = vi.global_transform * vi.get_aabb()
		if first:
			out = a
			first = false
		else:
			out = out.merge(a)
	return out


func _is_nat(key: String) -> bool:
	return world.nat_reg.has(key)


func _kind_of(key: String) -> String:
	if world.nat_reg.has(key):
		return world.nat_reg[key][0]
	if world.b.reg.has(key):
		return world.b.reg[key]["kind"]
	return ""


func _node_of(key: String) -> Node:
	if key == "":
		return null
	if world.nat_reg.has(key):
		return world.nat_reg[key][2]
	if world.b.reg.has(key):
		return world.b.reg[key]["node"]
	return null


func _entry(key: String) -> Dictionary:
	var n := int(key.substr(1))
	for e in data["a"]:
		if int(e.get("n", 0)) == n:
			return e
	return {}


# posição atual, giro extra e escala do objeto
func _state(key: String) -> Dictionary:
	if key.begins_with("+"):
		var en := _entry(key)
		return {"p": MapEdits.v3(en["p"]), "r": float(en.get("r", 0.0)), "s": float(en.get("s", 1.0)), "tx": float(en.get("tx", 0.0)), "tz": float(en.get("tz", 0.0))}
	var e: Dictionary = (data["e"] as Dictionary).get(key, {})
	var orig: Vector3 = (world.nat_reg[key][1] as Transform3D).origin if _is_nat(key) else world.b.reg[key]["o"][0]
	return {"p": MapEdits.v3(e["p"]) if e.has("p") else orig, "r": float(e.get("r", 0.0)), "s": float(e.get("s", 1.0)),
		"tx": float(e.get("tx", 0.0)), "tz": float(e.get("tz", 0.0))}


func _push_undo(key: String) -> void:
	if key.begins_with("+"):
		undo.append([key, _entry(key).duplicate(true)])
	else:
		var e = (data["e"] as Dictionary).get(key)
		undo.append([key, e.duplicate(true) if e != null else null])
	if undo.size() > 200:
		undo.pop_front()


func _set_state(key: String, st: Dictionary, push := true) -> void:
	if push:
		_push_undo(key)
	if key.begins_with("+"):
		var en := _entry(key)
		en["p"] = MapEdits.arr(st["p"])
		en["r"] = snappedf(st["r"], 0.001)
		en["s"] = snappedf(st["s"], 0.001)
		en["tx"] = snappedf(st["tx"], 0.001)
		en["tz"] = snappedf(st["tz"], 0.001)
	else:
		var e: Dictionary = (data["e"] as Dictionary).get(key, {})
		e["p"] = MapEdits.arr(st["p"])
		e["r"] = snappedf(st["r"], 0.001)
		e["s"] = snappedf(st["s"], 0.001)
		e["tx"] = snappedf(st["tx"], 0.001)
		e["tz"] = snappedf(st["tz"], 0.001)
		e["k"] = _kind_of(key)
		data["e"][key] = e
	_rebuild(key)
	_saved()


func _rebuild(key: String) -> void:
	if key.begins_with("+"):
		var en := _entry(key)
		var node := _node_of(key)
		if node:
			node.free()
		if en.is_empty():
			world.nat_reg.erase(key)
			world.b.reg.erase(key)
		elif en["k"] in World.NAT_KINDS:
			var sc := float(en.get("s", 1.0))
			world._nat(en["k"], World.added_nat_xf(en), {}, key, {})
		else:
			world.b.no_items = true
			world.b.add_new(en)
			world.b.no_items = false
	elif _is_nat(key):
		world.nat_rebuild(key)
	else:
		world.b.rebuild(key)
	_refresh_sel()


func _saved() -> void:
	MapEdits.save_local(data)
	_update_count()


# ---------------- ações ----------------

func _hold_step(what: String) -> void:
	if what.begins_with("cam_"):
		return
	if sel == "" or _node_of(sel) == null:
		return
	var st := _state(sel)
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var rt := Vector3(cos(yaw), 0, -sin(yaw))
	var step := 0.2
	match what:
		"fwd":
			st["p"] += fwd * step
		"back":
			st["p"] -= fwd * step
		"left":
			st["p"] -= rt * step
		"right":
			st["p"] += rt * step
		"up":
			st["p"] += Vector3(0, 0.05, 0)
		"down":
			st["p"] -= Vector3(0, 0.05, 0)
		"rot_l":
			st["r"] += deg_to_rad(5.0)
		"rot_r":
			st["r"] -= deg_to_rad(5.0)
		"tilt_f":
			st["tx"] -= deg_to_rad(2.0)
		"tilt_b":
			st["tx"] += deg_to_rad(2.0)
		"tilt_l":
			st["tz"] += deg_to_rad(2.0)
		"tilt_r":
			st["tz"] -= deg_to_rad(2.0)
		"big":
			st["s"] = minf(float(st["s"]) * 1.05, 4.0)
		"small":
			st["s"] = maxf(float(st["s"]) / 1.05, 0.25)
	# segurando o botão vira um passo só no desfazer
	_set_state(sel, st, hold_t < -0.3)


func _straighten() -> void:
	if sel == "" or _node_of(sel) == null:
		return
	var st := _state(sel)
	st["tx"] = 0.0
	st["tz"] = 0.0
	_set_state(sel, st)
	_toast("Sem inclinação")


# ---------------- jogar aqui / voar ----------------

var play_ui: CanvasLayer
var playing := false


func _play() -> void:
	var p = _aim_point()
	if p == null:
		return
	_select("")
	add_panel.visible = false
	playing = true
	ui.visible = false
	set_process_input(false)
	game.sandbox_play(p)
	if play_ui == null:
		play_ui = CanvasLayer.new()
		play_ui.layer = 5
		add_child(play_ui)
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 8)
		box.anchor_left = 0.5
		box.anchor_right = 0.5
		box.offset_left = -140
		box.offset_top = 112
		play_ui.add_child(box)
		var fly := _btn("✈ VOAR", _fly)
		fly.custom_minimum_size = Vector2(130, 64)
		box.add_child(fly)
		var bots := _btn("+3 BOTS", func():
			game.sandbox_bots(3)
			_toast("3 bots perto de você (não morrem)"))
		bots.custom_minimum_size = Vector2(130, 64)
		box.add_child(bots)
	play_ui.visible = true


func _fly() -> void:
	if not playing:
		return
	playing = false
	game.sandbox_hud(false)
	play_ui.visible = false
	ui.visible = true
	set_process_input(true)
	var lp: Player = game.players.get(game.local_id)
	if lp:
		cam.position = lp.position + Vector3(0, 6.0, 0) - Vector3(-sin(yaw), 0, -cos(yaw)) * 8.0
		pitch = -0.4
	cam.current = true


func _snap_ground() -> void:
	if sel == "" or _node_of(sel) == null:
		return
	var st := _state(sel)
	var p: Vector3 = st["p"]
	var kind := _kind_of(sel)
	st["p"] = Vector3(p.x, world.low_h(Vector2(p.x, p.z), 1.0) - (0.1 if kind in ["oak", "pine", "tall", "bush", "log"] else 0.05), p.z)
	_set_state(sel, st)
	_toast("Encostado no chão")


func _aim_point() -> Variant:
	var c := get_viewport().get_visible_rect().size / 2.0
	var from := cam.project_ray_origin(c)
	var q := PhysicsRayQueryParameters3D.create(from, from + cam.project_ray_normal(c) * 400.0)
	var node := _node_of(sel)
	if node:
		var ex: Array[RID] = []
		for b in node.find_children("*", "CollisionObject3D", true, false):
			ex.append((b as CollisionObject3D).get_rid())
		q.exclude = ex
	var r := world.get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		_toast("Aponte a mira do meio pro chão")
		return null
	return r["position"]


func _move_here() -> void:
	if sel == "" or _node_of(sel) == null:
		return
	var p = _aim_point()
	if p == null:
		return
	var st := _state(sel)
	st["p"] = p
	_set_state(sel, st)


func _new_entry(kind: String, p: Vector3, r: float, s: float, x: Array) -> String:
	var n := randi() % 900000000 + 1000
	var en := {"k": kind, "p": MapEdits.arr(p), "r": snappedf(r, 0.001), "s": s, "n": n}
	if not x.is_empty():
		en["x"] = x
	(data["a"] as Array).append(en)
	var key := "+%d" % n
	undo.append([key, null])
	_rebuild(key)
	_saved()
	return key


func _add(kind: String) -> void:
	add_panel.visible = false
	var p = _aim_point()
	if p == null:
		return
	var key := _new_entry(kind, p, yaw, 1.0, [])
	_select(key)
	_toast("%s adicionado" % NAMES[kind])


func _duplicate() -> void:
	if sel == "" or _node_of(sel) == null:
		return
	var kind := _kind_of(sel)
	var st := _state(sel)
	var x: Array = []
	if sel.begins_with("+"):
		x = _entry(sel).get("x", [])
	elif not _is_nat(sel) and not kind in Build.AB and not kind in Build.NO_YAW:
		var args: Array = world.b.reg[sel]["args"]
		for i in range(2, args.size()):
			x.append(args[i])
	var base_r := 0.0
	if not sel.begins_with("+") and not _is_nat(sel):
		base_r = float(world.b.reg[sel]["o"][1])
	elif _is_nat(sel) and not sel.begins_with("+"):
		var xf: Transform3D = world.nat_reg[sel][1]
		base_r = atan2(-xf.basis.x.z, xf.basis.x.x)
	var rt := Vector3(cos(yaw), 0, -sin(yaw))
	var ab := _aabb(_node_of(sel))
	var off := maxf(ab.size.x, ab.size.z) * 0.6 + 1.0
	var s := float(st["s"])
	if _is_nat(sel) and not sel.begins_with("+"):
		# a árvore/pedra original já tem tamanho próprio; a cópia usa o padrão vezes a escala dela
		var xf: Transform3D = world.nat_reg[sel][1]
		s *= xf.basis.x.length() / World._nat_default_basis(kind).x.length()
	var key := _new_entry(kind, (st["p"] as Vector3) + rt * off, base_r + float(st["r"]), s, x)
	_select(key)
	_toast("Duplicado")


func _delete() -> void:
	if sel == "" or _node_of(sel) == null:
		return
	_push_undo(sel)
	if sel.begins_with("+"):
		(data["a"] as Array).erase(_entry(sel))
	else:
		var e: Dictionary = (data["e"] as Dictionary).get(sel, {})
		e["d"] = true
		e["k"] = _kind_of(sel)
		data["e"][sel] = e
	var k := sel
	_rebuild(k)
	_saved()
	_select("")
	_toast("Apagado (DESFAZER volta)")


func _undo() -> void:
	if undo.is_empty():
		_toast("Nada pra desfazer")
		return
	var u: Array = undo.pop_back()
	var key: String = u[0]
	if key.begins_with("+"):
		var cur := _entry(key)
		if u[1] == null:
			(data["a"] as Array).erase(cur)
		elif cur.is_empty():
			(data["a"] as Array).append(u[1])
		else:
			cur.merge(u[1], true)
	else:
		if u[1] == null:
			(data["e"] as Dictionary).erase(key)
		else:
			data["e"][key] = u[1]
	_rebuild(key)
	_saved()
	_select(key if _node_of(key) else "")
	_toast("Desfeito")


func _copy() -> void:
	DisplayServer.clipboard_set(MapEdits.to_text(data))
	_toast("Copiado! Cole no chat do Claude (%d alterações)" % MapEdits.count(data), 5.0)


func _clear() -> void:
	if clear_t <= 0.0:
		clear_t = 3.0
		_toast("Toque em LIMPAR de novo pra apagar TODAS as alterações deste aparelho")
		return
	MapEdits.clear_local()
	_toast("Alterações apagadas. Saindo...")
	await get_tree().create_timer(1.0).timeout
	_exit()


func _exit() -> void:
	get_tree().reload_current_scene()
