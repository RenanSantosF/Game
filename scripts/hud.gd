class_name Hud
extends CanvasLayer

signal action(name: String)
signal pick(key: Array)
signal inv_action(act: String, a: String, b: int)

const JOY_R := 90.0
const MINI := 170.0
const MINI_M := 170.0      # metros mostrados no minimapa
const EDITABLE := ["fire", "fire2", "jump", "crouch", "reload", "scope", "heal", "bag"]
# posição padrão dos botões (fração da tela) e raio base
const DEFAULTS := {
	"fire": [0.883, 0.757, 78.0], "fire2": [0.3, 0.46, 46.0], "jump": [0.765, 0.882, 44.0], "crouch": [0.945, 0.917, 40.0],
	"reload": [0.945, 0.54, 38.0], "scope": [0.85, 0.54, 40.0], "heal": [0.68, 0.85, 40.0], "bag": [0.6, 0.075, 30.0],
}

var game: Node
var mode := "ground"       # lobby, plane, fall, glide, ground, dead, end
var move_vec := Vector2.ZERO
var fire_held := false
var _look := Vector2.ZERO
var touches := {}    # dedo -> "joy" | "look" | "fire" | "btn" | "gui" | "drag:<botão>"

var pad: Control
var mini: Control
var bigmap: Control
var tint: ColorRect
var flash: ColorRect
var lbl_center: Label
var lbl_zone: Label
var lbl_fps: Label
var lbl_spec: Label
var feed_box: VBoxContainer
var pick_panel: PanelContainer
var pick_list: VBoxContainer
var pick_scroll: ScrollContainer
var bag_panel: PanelContainer
var bag_left: VBoxContainer
var bag_right: VBoxContainer
var bag_title: Label

var center_t := 0.0
var hit_t := 0.0
var hit_head := false
var hit_kill := false
var hp := 100.0
var armor := 0.0
var heals := [0, 0]        # bandagens, kits
var overlay := false       # luneta (tela preta em volta)
var red_dot := false
var joy_active := false
var joy_origin := Vector2.ZERO
var big_map := false
var hurt_dirs := []
var heal_k := -1.0
var out_zone := false
var can_start := false
var can_retry := false
var show_fps := true
var crouched := false
var alive_n := 0
var kills_n := 0
var slots := []            # [{id, att, ammo, max}] x4 (mãos, principal 1, principal 2, pistola)
var sel := -1
var reloading := false
var dmg_nums := []         # [pos3d, texto, cor, t]
var steps := []            # [Vector2 mundo, t]
var icons := {}
var layout := {}
var edit_mode := false
var edit_sel := ""
var bag_open := false
var _pick_sig := ""
var _bag_sig := ""
var _slot_rects := []


func _ready() -> void:
	layer = 5
	layout = Cfg.get_v("layout").duplicate()
	tint = ColorRect.new()
	tint.color = Color(0.15, 0.35, 0.9, 0.0)
	tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tint)
	flash = ColorRect.new()
	flash.color = Color(0.8, 0.0, 0.0, 0.0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	pad = Control.new()
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pad)
	pad.draw.connect(_draw_pad)
	mini = Control.new()
	mini.position = Vector2(14, 14)
	mini.size = Vector2(MINI, MINI)
	mini.clip_contents = true
	mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mini)
	mini.draw.connect(_draw_mini)
	lbl_center = _label(30)
	lbl_center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_zone = _label(17)
	lbl_fps = _label(14)
	lbl_spec = _label(18)
	lbl_spec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feed_box = VBoxContainer.new()
	feed_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(feed_box)
	_build_pick_panel()
	_build_bag_panel()
	bigmap = Control.new()
	bigmap.set_anchors_preset(Control.PRESET_FULL_RECT)
	bigmap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bigmap.visible = false
	add_child(bigmap)
	bigmap.draw.connect(_draw_bigmap)
	make_icons()


func _label(fs: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _panel_style(alpha := 0.55) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.05, alpha)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(6)
	return sb


func _build_pick_panel() -> void:
	pick_panel = PanelContainer.new()
	pick_panel.add_theme_stylebox_override("panel", _panel_style(0.45))
	pick_panel.visible = false
	add_child(pick_panel)
	pick_scroll = ScrollContainer.new()
	pick_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pick_panel.add_child(pick_scroll)
	pick_list = VBoxContainer.new()
	pick_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick_list.add_theme_constant_override("separation", 4)
	pick_scroll.add_child(pick_list)


func _build_bag_panel() -> void:
	bag_panel = PanelContainer.new()
	bag_panel.add_theme_stylebox_override("panel", _panel_style(0.88))
	bag_panel.visible = false
	add_child(bag_panel)
	var vb := VBoxContainer.new()
	bag_panel.add_child(vb)
	var top := HBoxContainer.new()
	vb.add_child(top)
	bag_title = Label.new()
	bag_title.add_theme_font_size_override("font_size", 24)
	bag_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(bag_title)
	var close := _btn("FECHAR", func(): set_bag(false))
	top.add_child(close)
	var hb := HBoxContainer.new()
	hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hb.add_theme_constant_override("separation", 14)
	vb.add_child(hb)
	for side in 2:
		var sc := ScrollContainer.new()
		sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		hb.add_child(sc)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 6)
		sc.add_child(col)
		if side == 0:
			bag_left = col
		else:
			bag_right = col


func _btn(t: String, cb: Callable, fs := 18) -> Button:
	var b := Button.new()
	b.text = t
	b.add_theme_font_size_override("font_size", fs)
	b.custom_minimum_size = Vector2(0, 44)
	b.pressed.connect(cb)
	return b


# ---------------- ícones (armas e itens renderizados uma vez) ----------------

func make_icons() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(256, 128)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.8, 0.8)
	env.ambient_light_energy = 0.9
	we.environment = env
	vp.add_child(we)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -30, 0)
	light.light_energy = 1.2
	vp.add_child(light)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	vp.add_child(cam)
	cam.current = true
	var list := []
	for k in Weapons.DATA:
		list.append(k)
	for k in Weapons.ITEMS:
		list.append(k)
	list.append("box")
	for id in list:
		var node: Node3D
		var size := 0.5
		var center := Vector3.ZERO
		if id == "fist":
			node = Node3D.new()
			var m := MB.new()
			m.tex(U.PLAIN, 3.0)
			var sk := Color(0.86, 0.66, 0.5)
			m.blob(Transform3D(Basis.from_scale(Vector3(0.07, 0.055, 0.06)), Vector3.ZERO), 9, 5, sk)
			for i in 4:
				m.blob(Transform3D(Basis.from_scale(Vector3(0.018, 0.02, 0.025)), Vector3(-0.045 + i * 0.03, 0.04, -0.035)), 6, 3, sk.darkened(0.05))
			m.blob(Transform3D(Basis.from_scale(Vector3(0.02, 0.035, 0.02)), Vector3(0.07, -0.005, -0.02)), 6, 3, sk)
			U.mesh(node, m.commit())
			node.rotation = Vector3(0.4, 0.5, 0)
			size = 0.19
		elif Weapons.is_gun(id):
			node = Weapons.build_model(id)
			node.rotation.y = -PI / 2.0
			var L: float = Weapons.get_w(id)["len"]
			size = maxf(L * 1.1, 0.3)
			center = Vector3(L * 0.42, 0.0, 0)
		else:
			node = Weapons.build_item(id)
			node.rotation = Vector3(0.6, 0.6, 0)
			size = 0.95 if id == "box" else 0.6
			center = Vector3(0, 0.12, 0)
		vp.add_child(node)
		cam.size = size
		cam.position = center + Vector3(0, 0, 3)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		icons[id] = ImageTexture.create_from_image(img)
		node.queue_free()
	vp.queue_free()
	_pick_sig = ""
	_bag_sig = ""


# ---------------- API usada pelo jogo ----------------

func take_look() -> Vector2:
	var l := _look
	_look = Vector2.ZERO
	return l


func set_zone_text(t: String) -> void:
	lbl_zone.text = t


func set_spec(t: String) -> void:
	lbl_spec.text = t


func center(t: String, secs: float) -> void:
	lbl_center.text = t
	center_t = secs


func hit(head: bool, kill: bool) -> void:
	hit_t = 0.25
	hit_head = head
	hit_kill = kill


func hurt(dir_angle := 999.0) -> void:
	flash.color.a = 0.22
	if dir_angle < 900.0:
		hurt_dirs.append([dir_angle, 1.5])


func dmg_number(pos: Vector3, amount: float, head: bool, kill: bool) -> void:
	var c := Color(1, 1, 1)
	if head:
		c = Color(1, 0.3, 0.2)
	if kill:
		c = Color(1, 0.8, 0.2)
	dmg_nums.append([pos + Vector3(randf_range(-0.2, 0.2), 0, randf_range(-0.2, 0.2)), str(int(round(amount))), c, 0.0, head])


func add_step(p: Vector3) -> void:
	steps.append([Vector2(p.x, p.z), 1.6])
	if steps.size() > 40:
		steps.pop_front()


func feed(t: String, col := Color.WHITE) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feed_box.add_child(l)
	get_tree().create_timer(6.0).timeout.connect(l.queue_free)
	if feed_box.get_child_count() > 5:
		feed_box.get_child(0).queue_free()


func set_bag(open: bool) -> void:
	bag_open = open
	bag_panel.visible = open
	_bag_sig = ""


# lista de itens perto: [{key, kind, n, label}]
func set_pickups(list: Array) -> void:
	var sig := ""
	for e in list:
		sig += "%s:%s:%d;" % [str(e["key"]), e["kind"], e["n"]]
	sig += str(icons.size())
	if sig == _pick_sig:
		return
	_pick_sig = sig
	for c in pick_list.get_children():
		c.queue_free()
	for e in list:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 46)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var hb := HBoxContainer.new()
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.set_anchors_preset(Control.PRESET_FULL_RECT)
		hb.add_theme_constant_override("separation", 8)
		b.add_child(hb)
		var tr := TextureRect.new()
		tr.custom_minimum_size = Vector2(72, 36)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture = icons.get(e["kind"])
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(tr)
		var l := Label.new()
		l.text = e["label"] + ("  x%d" % e["n"] if int(e["n"]) > 1 else "")
		l.add_theme_font_size_override("font_size", 17)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.size_flags_vertical = Control.SIZE_EXPAND_FILL
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(l)
		var key: Array = e["key"]
		b.pressed.connect(func(): pick.emit(key))
		pick_list.add_child(b)
	pick_panel.visible = not list.is_empty()


func _bag_row(parent: Container, kind: String, text: String, buttons: Array) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	var tr := TextureRect.new()
	tr.custom_minimum_size = Vector2(80, 40)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture = icons.get(kind)
	hb.add_child(tr)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 17)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	hb.add_child(l)
	for bt in buttons:
		var b := _btn(bt[0], bt[1], 15)
		b.custom_minimum_size = Vector2(86, 42)
		hb.add_child(b)
	parent.add_child(hb)


func refresh_bag(p: Player) -> void:
	if not bag_open or p == null:
		return
	var sig := "%s|%s|%s|%d|%s|%s|%d" % [str(p.guns), str(p.inv), p.armor, int(p.helmet), p.bag, p.sel, icons.size()]
	if sig == _bag_sig:
		return
	_bag_sig = sig
	for c in bag_left.get_children():
		c.queue_free()
	for c in bag_right.get_children():
		c.queue_free()
	bag_title.text = "MOCHILA   %d / %d vagas" % [Weapons.slots_used(p.inv), p.capacity()]
	var names := ["Principal 1", "Principal 2", "Pistola"]
	for i in 3:
		var g: Dictionary = p.guns[i]
		var id: String = g["id"]
		if id == "":
			_bag_row(bag_left, "", "%s: vazio" % names[i], [])
			continue
		var t := "%s: %s" % [names[i], Weapons.item_name(id)]
		var bts := [["LARGAR", func(): inv_action.emit("drop_gun", "", i)]]
		_bag_row(bag_left, id, t, bts)
		for a in g["att"]:
			var att: String = a
			_bag_row(bag_left, att, "   + " + Weapons.item_name(att), [["TIRAR", func(): inv_action.emit("unequip", att, i)]])
	if p.armor > 0.0:
		_bag_row(bag_left, "vest", "Colete (%d)" % int(p.armor), [["LARGAR", func(): inv_action.emit("drop", "vest", 0)]])
	if p.helmet:
		_bag_row(bag_left, "helmet", "Capacete", [["LARGAR", func(): inv_action.emit("drop", "helmet", 0)]])
	if p.bag:
		_bag_row(bag_left, "bag", "Mochila grande (16 vagas)", [])
	if p.inv.is_empty():
		var l := Label.new()
		l.text = "Mochila vazia"
		bag_right.add_child(l)
	for k in p.inv:
		var kind: String = k
		var n: int = p.inv[k]
		if n <= 0:
			continue
		var bts := []
		if Weapons.ITEMS[kind]["kind"] == "heal":
			bts.append(["USAR", func(): inv_action.emit("use", kind, 0)])
		elif Weapons.is_att(kind):
			bts.append(["EQUIPAR", func(): inv_action.emit("equip", kind, p.sel)])
		bts.append(["LARGAR", func(): inv_action.emit("drop", kind, n)])
		_bag_row(bag_right, kind, "%s  x%d" % [Weapons.item_name(kind), n], bts)


# ---------------- botões e toque ----------------

func btn_pos(key: String, s: Vector2) -> Array:
	var d: Array = DEFAULTS[key]
	var l: Array = layout.get(key, [d[0], d[1], 1.0])
	return [Vector2(l[0] * s.x, l[1] * s.y), float(d[2]) * float(l[2])]


func _buttons() -> Dictionary:
	var s := get_viewport().get_visible_rect().size
	var b := {}
	if edit_mode:
		for k in EDITABLE:
			var bp := btn_pos(k, s)
			b[k] = [bp[0], bp[1], _btn_label(k)]
		b["e_small"] = [Vector2(s.x * 0.5 - 200, 60), 34.0, "MENOR"]
		b["e_big"] = [Vector2(s.x * 0.5 - 110, 60), 34.0, "MAIOR"]
		b["e_reset"] = [Vector2(s.x * 0.5 - 20, 60), 34.0, "PADRÃO"]
		b["e_save"] = [Vector2(s.x * 0.5 + 70, 60), 34.0, "SALVAR"]
		b["e_cancel"] = [Vector2(s.x * 0.5 + 160, 60), 34.0, "SAIR"]
		return b
	b["exit"] = [Vector2(212, 36), 24.0, "SAIR"]
	b["settings"] = [Vector2(272, 36), 24.0, "AJUSTES"]
	if big_map:
		b["map"] = [Vector2(s.x - 70, s.y - 60), 34.0, "FECHAR"]
		return b
	if bag_open:
		return b
	var fp := btn_pos("fire", s)
	match mode:
		"plane":
			b["leave"] = [fp[0], 80.0, "SALTAR"]
		"fall":
			b["chute"] = [fp[0], 70.0, "PARAQUEDAS"]
		"ground", "lobby":
			for k in ["fire", "fire2", "jump", "crouch", "reload", "scope", "heal", "bag"]:
				var bp := btn_pos(k, s)
				b[k] = [bp[0], bp[1], _btn_label(k)]
			if can_start:
				b["start"] = [Vector2(s.x * 0.5, s.y * 0.5 + 120), 60.0, "COMEÇAR"]
		"dead":
			b["spec"] = [Vector2(s.x - 110, s.y - 110), 54.0, "PRÓXIMO"]
			b["menu"] = [Vector2(110, s.y - 110), 54.0, "MENU"]
		"end":
			b["menu"] = [Vector2(s.x * 0.5 - (110 if can_retry else 0), s.y * 0.72), 62.0, "MENU"]
			if can_retry:
				b["retry"] = [Vector2(s.x * 0.5 + 110, s.y * 0.72), 62.0, "DE NOVO"]
	return b


func _btn_label(k: String) -> String:
	match k:
		"fire", "fire2":
			return "ATIRAR" if (sel >= 1 and _slot_has(sel)) else "SOCAR"
		"jump":
			return "PULAR"
		"crouch":
			return "LEVANTAR" if crouched else "AGACHAR"
		"reload":
			return "RECAR."
		"scope":
			return "MIRA"
		"heal":
			return "CURAR"
		"bag":
			return "MOCHILA"
	return k


func _slot_has(i: int) -> bool:
	return i >= 0 and i < slots.size() and str(slots[i]["id"]) != ""


func _hit_button(p: Vector2) -> String:
	var b := _buttons()
	for k in b:
		if p.distance_to(b[k][0]) <= float(b[k][1]) * 1.12:
			return k
	return ""


func _hit_slot(p: Vector2) -> int:
	for e in _slot_rects:
		if (e[0] as Rect2).has_point(p):
			return e[1]
	return -1


func _in_gui(p: Vector2) -> bool:
	if bag_open and Rect2(bag_panel.position, bag_panel.size).has_point(p):
		return true
	if pick_panel.visible and Rect2(pick_panel.position, pick_panel.size).has_point(p):
		return true
	return false


func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed:
			_down(e.index, e.position)
		else:
			_up(e.index)
	elif e is InputEventScreenDrag:
		_drag(e.index, e.position, e.relative)
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.physical_keycode:
			KEY_SPACE:
				action.emit("leave" if mode == "plane" else ("chute" if mode == "fall" else "jump"))
			KEY_R:
				action.emit("reload")
			KEY_1:
				action.emit("slot1")
			KEY_2:
				action.emit("slot2")
			KEY_3:
				action.emit("slot3")
			KEY_X:
				action.emit("slot0")
			KEY_E:
				action.emit("pickup")
			KEY_C:
				action.emit("scope")
			KEY_CTRL, KEY_Z:
				action.emit("crouch")
			KEY_H:
				action.emit("heal")
			KEY_M:
				action.emit("map")
			KEY_TAB:
				action.emit("bag")
			KEY_N:
				action.emit("spec")


func _down(i: int, p: Vector2) -> void:
	if _in_gui(p):
		touches[i] = "gui"
		return
	var b := _hit_button(p)
	if edit_mode:
		if b in EDITABLE:
			edit_sel = b
			touches[i] = "drag:" + b
		elif b != "":
			touches[i] = "btn"
			_edit_cmd(b)
		return
	if b == "fire" or b == "fire2":
		touches[i] = "fire"
		return
	if b != "":
		touches[i] = "btn"
		action.emit(b)
		return
	var sl := _hit_slot(p)
	if sl >= 0 and (mode == "ground" or mode == "lobby"):
		touches[i] = "btn"
		action.emit("slot%d" % sl)
		return
	if Rect2(mini.position, mini.size).grow(10).has_point(p) and not big_map:
		touches[i] = "btn"
		action.emit("map")
	elif p.x < get_viewport().get_visible_rect().size.x * 0.42 and not joy_active:
		touches[i] = "joy"
		joy_active = true
		joy_origin = p
		move_vec = Vector2.ZERO
	else:
		touches[i] = "look"


func _up(i: int) -> void:
	var r: String = touches.get(i, "")
	touches.erase(i)
	if r == "joy":
		joy_active = false
		move_vec = Vector2.ZERO


func _drag(i: int, p: Vector2, rel: Vector2) -> void:
	var r: String = touches.get(i, "")
	if r == "joy":
		var v := (p - joy_origin) / JOY_R
		if v.length() > 1.0:
			v = v.normalized()
		if v.length() < 0.12:
			v = Vector2.ZERO
		move_vec = v
	elif r == "look":
		_look += rel
	elif r == "fire":
		_look += rel * 0.8   # dá pra mirar arrastando o dedo no botão de tiro
	elif r.begins_with("drag:"):
		var k := r.substr(5)
		var s := get_viewport().get_visible_rect().size
		var cur: Array = layout.get(k, [DEFAULTS[k][0], DEFAULTS[k][1], 1.0])
		layout[k] = [clampf(p.x / s.x, 0.03, 0.97), clampf(p.y / s.y, 0.05, 0.97), cur[2]]


func _edit_cmd(b: String) -> void:
	match b:
		"e_small", "e_big":
			if edit_sel != "":
				var d: Array = DEFAULTS[edit_sel]
				var cur: Array = layout.get(edit_sel, [d[0], d[1], 1.0])
				var sc: float = clampf(float(cur[2]) + (-0.1 if b == "e_small" else 0.1), 0.6, 1.8)
				layout[edit_sel] = [cur[0], cur[1], sc]
		"e_reset":
			layout = {}
		"e_save":
			Cfg.set_v("layout", layout.duplicate())
			edit_mode = false
			action.emit("edit_done")
		"e_cancel":
			layout = Cfg.get_v("layout").duplicate()
			edit_mode = false
			action.emit("edit_done")


func _process(delta: float) -> void:
	center_t -= delta
	if center_t <= 0.0:
		lbl_center.text = ""
	hit_t = maxf(hit_t - delta, 0.0)
	flash.color.a = maxf(flash.color.a - delta * 1.5, 0.0)
	var ta := 0.0
	if out_zone:
		ta = 0.16 + sin(Time.get_ticks_msec() / 250.0) * 0.05
	tint.color.a = lerpf(tint.color.a, ta, minf(1.0, 5.0 * delta))
	for hd in hurt_dirs:
		hd[1] -= delta
	hurt_dirs = hurt_dirs.filter(func(h): return h[1] > 0.0)
	for dn in dmg_nums:
		dn[3] += delta
	dmg_nums = dmg_nums.filter(func(d): return d[3] < 0.9)
	for st in steps:
		st[1] -= delta
	steps = steps.filter(func(s2): return s2[1] > 0.0)
	# teclado (pra testar no PC)
	var kb := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	if not joy_active:
		move_vec = kb.normalized() if kb != Vector2.ZERO else Vector2.ZERO
	fire_held = touches.values().has("fire") or Input.is_physical_key_pressed(KEY_F)
	# layout
	var s := get_viewport().get_visible_rect().size
	lbl_center.position = Vector2(0, s.y * 0.24)
	lbl_center.size = Vector2(s.x, 100)
	lbl_spec.position = Vector2(0, 64)
	lbl_spec.size = Vector2(s.x, 30)
	lbl_zone.position = Vector2(14, MINI + 20)
	lbl_zone.size = Vector2(320, 30)
	lbl_fps.position = Vector2(14, MINI + 44)
	lbl_fps.visible = show_fps
	lbl_fps.text = "FPS %d" % Engine.get_frames_per_second()
	feed_box.position = Vector2(14, MINI + 70)
	feed_box.size = Vector2(420, 10)
	var pw := minf(330.0, s.x * 0.28)
	pick_panel.position = Vector2(s.x - pw - 12, 112)
	pick_panel.size = Vector2(pw, minf(48.0 * pick_list.get_child_count() + 14.0, s.y * 0.38))
	pick_panel.custom_minimum_size = pick_panel.size
	pick_scroll.custom_minimum_size = Vector2(pw - 14, pick_panel.size.y - 12)
	if mode != "ground" or bag_open or edit_mode or big_map:
		pick_panel.visible = false
	elif pick_list.get_child_count() > 0:
		pick_panel.visible = true
	bag_panel.position = Vector2(s.x * 0.08, s.y * 0.1)
	bag_panel.size = Vector2(s.x * 0.84, s.y * 0.8)
	bag_panel.custom_minimum_size = bag_panel.size
	bigmap.visible = big_map
	mini.visible = not big_map and mode != "end" and not edit_mode
	pad.queue_redraw()
	if mini.visible:
		mini.queue_redraw()
	if big_map:
		bigmap.queue_redraw()


# ---------------- desenho ----------------

func _draw_btn(font: Font, k: String, pos: Vector2, r: float, label: String) -> void:
	var held: bool = (k == "fire" or k == "fire2") and fire_held
	var bg := Color(0, 0, 0, 0.35)
	if held:
		bg = Color(1, 0.4, 0.2, 0.5)
	elif k == "leave" or k == "start" or k == "retry" or k == "e_save":
		bg = Color(0.85, 0.55, 0.1, 0.6)
	if edit_mode and k == edit_sel:
		bg = Color(0.2, 0.6, 1.0, 0.5)
	pad.draw_circle(pos, r, bg)
	pad.draw_arc(pos, r, 0, TAU, 40, Color(1, 1, 1, 0.6), 2.5)
	var fs := 22 if r >= 54.0 else (16 if label.length() <= 7 else 13)
	if r < 30.0:
		fs = mini(fs, 12 if label.length() > 4 else 14)
	var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var dy := fs * 0.35
	if k == "heal":
		dy -= 8.0
	pad.draw_string(font, pos + Vector2(-tw / 2.0, dy), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	if k == "heal":
		var sub := "B%d  K%d" % [heals[0], heals[1]]
		var sw := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		pad.draw_string(font, pos + Vector2(-sw / 2.0, 16), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.7, 1, 0.7))


func _draw_face(c: Vector2, r: float, col: Color) -> void:
	pad.draw_arc(c, r, 0, TAU, 24, col, 2.0)
	pad.draw_circle(c + Vector2(-r * 0.35, -r * 0.25), r * 0.13, col)
	pad.draw_circle(c + Vector2(r * 0.35, -r * 0.25), r * 0.13, col)
	pad.draw_arc(c + Vector2(0, r * 0.05), r * 0.5, 0.35, PI - 0.35, 12, col, 2.0)


func _draw_skull(c: Vector2, r: float, col: Color) -> void:
	pad.draw_circle(c + Vector2(0, -r * 0.15), r * 0.85, col)
	pad.draw_rect(Rect2(c + Vector2(-r * 0.5, r * 0.3), Vector2(r, r * 0.55)), col)
	var dark := Color(0.08, 0.02, 0.02)
	pad.draw_circle(c + Vector2(-r * 0.35, -r * 0.15), r * 0.24, dark)
	pad.draw_circle(c + Vector2(r * 0.35, -r * 0.15), r * 0.24, dark)
	pad.draw_colored_polygon(PackedVector2Array([c + Vector2(0, r * 0.08), c + Vector2(-r * 0.12, r * 0.3), c + Vector2(r * 0.12, r * 0.3)]), dark)
	for i in 3:
		pad.draw_line(c + Vector2(-r * 0.25 + i * r * 0.25, r * 0.55), c + Vector2(-r * 0.25 + i * r * 0.25, r * 0.85), dark, 1.5)


func _draw_slots(font: Font, s: Vector2) -> void:
	_slot_rects.clear()
	if slots.is_empty() or not (mode == "ground" or mode == "lobby"):
		return
	var x := s.x - 12.0
	var y := 12.0
	for i in range(slots.size() - 1, -1, -1):
		var e: Dictionary = slots[i]
		var active := i == sel
		var w := 150.0 if active else 92.0
		var h := 70.0 if active else 50.0
		x -= w
		var r := Rect2(x, y, w, h)
		_slot_rects.append([r, i])
		var has: bool = str(e["id"]) != ""
		pad.draw_rect(r, Color(0.1, 0.1, 0.08, 0.55 if active else 0.35))
		pad.draw_rect(r, Color(1, 0.85, 0.3, 0.9) if active else Color(1, 1, 1, 0.35), false, 2.0 if active else 1.0)
		if has:
			var tex: Texture2D = icons.get(e["id"])
			if tex:
				pad.draw_texture_rect(tex, r.grow(-4), false, Color(1, 1, 1, 1.0 if active else 0.75))
			else:
				var nm: String = Weapons.item_name(e["id"])
				pad.draw_string(font, r.position + Vector2(6, h * 0.6), nm, HORIZONTAL_ALIGNMENT_LEFT, w - 8, 13, Color.WHITE)
			if active and str(e["id"]) != "fist":
				var at := "RECARREGANDO" if reloading else "%d / %d" % [e["ammo"], e["max"]]
				var tw := font.get_string_size(at, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
				pad.draw_string_outline(font, Vector2(x + w - tw - 6, y + h + 18), at, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color(0, 0, 0, 0.8))
				pad.draw_string(font, Vector2(x + w - tw - 6, y + h + 18), at, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
		else:
			pad.draw_string(font, r.position + Vector2(8, h * 0.6), "—", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.4))
		x -= 6.0


func _draw_pad() -> void:
	var s := pad.size
	var font := ThemeDB.fallback_font
	var c := s / 2.0
	var white := Color(1, 1, 1, 0.9)
	if edit_mode:
		pad.draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.35))
		var msg := "Arraste os botões. Toque num botão e use MENOR/MAIOR pra mudar o tamanho."
		var mw := font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		pad.draw_string(font, Vector2(c.x - mw / 2.0, 120), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)
		var b := _buttons()
		for k in b:
			_draw_btn(font, k, b[k][0], b[k][1], b[k][2])
		return
	if big_map:
		var bb := _buttons()
		for k in bb:
			_draw_btn(font, k, bb[k][0], bb[k][1], bb[k][2])
		return
	var cam: Camera3D = game.cam if game else null
	# números de dano subindo
	if cam:
		for dn in dmg_nums:
			var p3: Vector3 = dn[0] + Vector3(0, 1.9 + float(dn[3]) * 1.4, 0)
			if cam.is_position_behind(p3):
				continue
			var sp := cam.unproject_position(p3)
			var a := clampf(1.0 - (float(dn[3]) - 0.5) / 0.4, 0.0, 1.0)
			var fs := 26 if dn[4] else 22
			var col: Color = dn[2]
			col.a = a
			pad.draw_string_outline(font, sp, dn[1], HORIZONTAL_ALIGNMENT_CENTER, -1, fs, 5, Color(0, 0, 0, a * 0.85))
			pad.draw_string(font, sp, dn[1], HORIZONTAL_ALIGNMENT_CENTER, -1, fs, col)
	# mira
	if mode == "ground" or mode == "lobby":
		if overlay:
			pad.draw_line(Vector2(0, c.y), Vector2(s.x, c.y), Color(0, 0, 0, 0.8), 2.0)
			pad.draw_line(Vector2(c.x, 0), Vector2(c.x, s.y), Color(0, 0, 0, 0.8), 2.0)
			pad.draw_arc(c, s.y * 0.46, 0, TAU, 64, Color(0, 0, 0, 0.9), 10.0)
			pad.draw_rect(Rect2(0, 0, c.x - s.y * 0.46, s.y), Color(0, 0, 0, 0.92))
			pad.draw_rect(Rect2(c.x + s.y * 0.46, 0, s.x, s.y), Color(0, 0, 0, 0.92))
		elif red_dot:
			pad.draw_arc(c, 14.0, 0, TAU, 24, Color(0.1, 0.1, 0.1, 0.6), 2.0)
			pad.draw_circle(c, 2.5, Color(1, 0.15, 0.1))
		else:
			var g := 7.0
			var L := 11.0
			pad.draw_line(c + Vector2(g, 0), c + Vector2(g + L, 0), white, 2.0)
			pad.draw_line(c - Vector2(g, 0), c - Vector2(g + L, 0), white, 2.0)
			pad.draw_line(c + Vector2(0, g), c + Vector2(0, g + L), white, 2.0)
			pad.draw_line(c - Vector2(0, g), c - Vector2(0, g + L), white, 2.0)
			pad.draw_circle(c, 1.5, white)
	if hit_t > 0.0:
		var hc := Color(1, 0.2, 0.2) if (hit_head or hit_kill) else Color(1, 1, 1)
		for k in 4:
			var dir := Vector2(1, 1).rotated(k * PI / 2.0).normalized()
			pad.draw_line(c + dir * 8.0, c + dir * 18.0, hc, 3.0)
	# de onde veio o tiro: setinha vermelha discreta em volta da mira
	for hd in hurt_dirs:
		var a: float = hd[0]
		var al := clampf(float(hd[1]), 0.0, 1.0)
		var dv := Vector2(sin(a), -cos(a))
		var tip := c + dv * 120.0
		var side := Vector2(-dv.y, dv.x)
		pad.draw_colored_polygon(PackedVector2Array([tip + dv * 14.0, tip + side * 12.0, tip - side * 12.0]), Color(1, 0.15, 0.1, al * 0.85))
		pad.draw_arc(c, 108.0, a - PI / 2.0 - 0.22, a - PI / 2.0 + 0.22, 12, Color(1, 0.15, 0.1, al * 0.5), 4.0)
	# cura em andamento
	if heal_k >= 0.0:
		pad.draw_arc(c, 44.0, -PI / 2.0, -PI / 2.0 + TAU * heal_k, 40, Color(0.4, 1, 0.5, 0.9), 6.0)
		var ht := "CURANDO"
		var htw := font.get_string_size(ht, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		pad.draw_string(font, c + Vector2(-htw / 2.0, 70), ht, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.6, 1, 0.7))
	# vivos e abates
	if mode != "end":
		var tx := s.x * 0.5 - 70.0
		_draw_face(Vector2(tx, 30), 13.0, Color(1, 1, 1, 0.95))
		pad.draw_string_outline(font, Vector2(tx + 20, 39), str(alive_n), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 5, Color(0, 0, 0, 0.8))
		pad.draw_string(font, Vector2(tx + 20, 39), str(alive_n), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
		_draw_skull(Vector2(tx + 90, 30), 12.0, Color(0.9, 0.15, 0.12))
		pad.draw_string_outline(font, Vector2(tx + 108, 39), str(kills_n), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 5, Color(0, 0, 0, 0.8))
		pad.draw_string(font, Vector2(tx + 108, 39), str(kills_n), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 0.45, 0.4))
	# joystick
	if mode in ["ground", "lobby", "fall", "glide", "plane"] and not bag_open:
		if joy_active:
			pad.draw_circle(joy_origin, JOY_R, Color(1, 1, 1, 0.1))
			pad.draw_arc(joy_origin, JOY_R, 0, TAU, 40, Color(1, 1, 1, 0.4), 2.0)
			pad.draw_circle(joy_origin + move_vec * JOY_R, 34.0, Color(1, 1, 1, 0.4))
		elif mode != "plane":
			var hint := Vector2(190, s.y - 170)
			pad.draw_arc(hint, JOY_R, 0, TAU, 40, Color(1, 1, 1, 0.15), 2.0)
			pad.draw_circle(hint, 34.0, Color(1, 1, 1, 0.12))
	_draw_slots(font, s)
	# botões
	var b := _buttons()
	for k in b:
		_draw_btn(font, k, b[k][0], b[k][1], b[k][2])
	# vida e colete
	if mode in ["ground", "lobby", "fall", "glide"]:
		var bw := 360.0
		var bx := s.x / 2.0 - bw / 2.0
		var by := s.y - 40.0
		var f := clampf(hp / 100.0, 0.0, 1.0)
		pad.draw_rect(Rect2(bx - 2, by - 2, bw + 4, 20), Color(0, 0, 0, 0.55))
		pad.draw_rect(Rect2(bx, by, bw * f, 16), Color(lerpf(0.9, 0.25, f), lerpf(0.2, 0.8, f), 0.2))
		pad.draw_string(font, Vector2(bx + bw + 10, by + 14), "%d" % ceili(hp), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
		if armor > 0.0:
			pad.draw_rect(Rect2(bx - 2, by - 12, bw + 4, 9), Color(0, 0, 0, 0.55))
			pad.draw_rect(Rect2(bx, by - 10, bw * clampf(armor / 100.0, 0.0, 1.0), 5), Color(0.35, 0.6, 1.0))


func _w2map(p: Vector2, center: Vector2, scale: float, origin: Vector2) -> Vector2:
	return origin + (p - center) * scale


func _draw_mini() -> void:
	if game == null or game.world == null or game.world.map_tex == null:
		return
	var me: Vector3 = game.view_pos()
	var mp := Vector2(me.x, me.z)
	var tex: Texture2D = game.world.map_tex
	var tpm := tex.get_width() / World.SIZE
	var src := Rect2((mp + Vector2(World.SIZE, World.SIZE) / 2.0) * tpm - Vector2(MINI_M, MINI_M) * tpm / 2.0, Vector2(MINI_M, MINI_M) * tpm)
	mini.draw_rect(Rect2(Vector2.ZERO, mini.size), Color(0.1, 0.12, 0.1))
	mini.draw_texture_rect_region(tex, Rect2(Vector2.ZERO, mini.size), src, Color(1, 1, 1, 0.92))
	var sc := MINI / MINI_M
	var o := mini.size / 2.0
	_draw_zone(mini, mp, sc, o)
	# passos de inimigos por perto
	for st in steps:
		var q := _w2map(st[0], mp, sc, o)
		var al := clampf(float(st[1]), 0.0, 1.0)
		mini.draw_circle(q, 3.0, Color(1, 0.3, 0.2, al))
		mini.draw_circle(q + Vector2(3, -4), 2.2, Color(1, 0.3, 0.2, al * 0.8))
	var yaw: float = game.view_yaw()
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var rt := Vector2(fwd.y, -fwd.x)
	# cone de visão
	var cy: float = game.cam_yaw_v
	var cf := Vector2(-sin(cy), -cos(cy))
	mini.draw_colored_polygon(PackedVector2Array([o, o + cf.rotated(-0.5) * 40.0, o + cf.rotated(0.5) * 40.0]), Color(1, 1, 1, 0.12))
	mini.draw_colored_polygon(PackedVector2Array([o + fwd * 9.0, o - fwd * 5.0 + rt * 5.0, o - fwd * 5.0 - rt * 5.0]), Color(1, 0.85, 0.2))
	mini.draw_rect(Rect2(Vector2.ZERO, mini.size), Color(0, 0, 0, 0.7), false, 2.0)


func _draw_zone(cv: Control, center: Vector2, sc: float, o: Vector2) -> void:
	var z: Array = game.zone_now()
	if float(z[1]) < 5000.0:
		cv.draw_arc(_w2map(z[0], center, sc, o), float(z[1]) * sc, 0, TAU, 72, Color(0.35, 0.55, 1.0, 0.95), 2.5)
	var ng: Array = game.zone_next()
	if not ng.is_empty():
		cv.draw_arc(_w2map(ng[0], center, sc, o), float(ng[1]) * sc, 0, TAU, 72, Color(1, 1, 1, 0.9), 1.5)


func _draw_bigmap() -> void:
	if game == null or game.world == null or game.world.map_tex == null:
		return
	var s := bigmap.size
	bigmap.draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.6))
	var side := s.y * 0.92
	var org := Vector2((s.x - side) / 2.0, (s.y - side) / 2.0)
	var tex: Texture2D = game.world.map_tex
	bigmap.draw_texture_rect(tex, Rect2(org, Vector2(side, side)), false)
	var sc := side / World.SIZE
	var o := org + Vector2(side, side) / 2.0
	var font := ThemeDB.fallback_font
	for t in game.world.towns:
		var p := _w2map(t["pos"], Vector2.ZERO, sc, o)
		var n: String = t["name"]
		var tw := font.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var tp := p + Vector2(-tw / 2.0, -float(t["r"]) * sc * 0.6)
		bigmap.draw_string_outline(font, tp, n, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, 0.9))
		bigmap.draw_string(font, tp, n, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	if game.phase == 1:
		var a: Vector3 = game.plane_a
		var bb: Vector3 = game.plane_b
		bigmap.draw_line(_w2map(Vector2(a.x, a.z), Vector2.ZERO, sc, o), _w2map(Vector2(bb.x, bb.z), Vector2.ZERO, sc, o), Color(1, 1, 1, 0.6), 2.0)
	_draw_zone(bigmap, Vector2.ZERO, sc, o)
	var me: Vector3 = game.view_pos()
	var mp := _w2map(Vector2(me.x, me.z), Vector2.ZERO, sc, o)
	bigmap.draw_circle(mp, 6.0, Color(1, 0.85, 0.2))
	bigmap.draw_arc(mp, 6.0, 0, TAU, 16, Color.BLACK, 1.5)
	bigmap.draw_rect(Rect2(org, Vector2(side, side)), Color(0, 0, 0, 0.8), false, 2.0)
