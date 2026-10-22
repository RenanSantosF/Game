class_name Hud
extends CanvasLayer

signal action(name: String)
signal pick(key: Array)
signal inv_action(act: String, a: String, b: int)

const JOY_R := 90.0
const MINI := 170.0
const MINI_M := 170.0      # metros mostrados no minimapa
const EDITABLE := ["fire", "fire2", "jump", "crouch", "reload", "scope", "heal", "bag", "sprint"]
# posição padrão dos botões (fração da tela) e raio base
# mochila e cura ficam embaixo do minimapa; correr do lado do minimapa
const DEFAULTS := {
	"fire": [0.883, 0.757, 78.0], "fire2": [0.3, 0.46, 46.0], "jump": [0.765, 0.882, 44.0], "crouch": [0.945, 0.917, 40.0],
	"reload": [0.945, 0.54, 38.0], "scope": [0.85, 0.54, 40.0], "heal": [0.112, 0.345, 32.0], "bag": [0.04, 0.345, 32.0],
	"sprint": [0.18, 0.13, 36.0],
}

var game: Node
var mode := "ground"       # lobby, plane, fall, glide, ground, dead, end
var move_vec := Vector2.ZERO
var cross_bloom := 0.0
var iron := false
var gren_left := -1.0     # segundos até a granada na mão explodir (-1 = sem granada na mão)
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
var pick_list: HBoxContainer
var pick_scroll: ScrollContainer
var bag_panel: PanelContainer
var bag_back: Control
var bag_left: VBoxContainer
var bag_grid: GridContainer
var bag_title: Label
var bag_cap: Label
var bag_bar: Control
var bag_act: HBoxContainer
var bag_sel := {}          # item escolhido na mochila: {t, kind, slot}
var _bag_cap_k := 0.0

var center_t := 0.0
var hit_t := 0.0
var hit_head := false
var hit_kill := false
var hp := 200.0
var sprinting := false
var can_scope := true
var can_leave := true
var grenades := 0
var car_near := false
var driving := false
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
var _pick_n := 0
var kill_t := 0.0
var _pick_touch := {}
var kill_txt := ""
var kill_head := false
var kill_n := 0
var _bag_sig := ""
var _slot_rects := []
var _slots_bottom := 160.0


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


# coleta: faixa horizontal (largura 100 x altura 20), mostra 5 itens; arrasta pro lado pra ver o resto
func _build_pick_panel() -> void:
	pick_panel = PanelContainer.new()
	pick_panel.add_theme_stylebox_override("panel", _panel_style(0.5))
	pick_panel.visible = false
	add_child(pick_panel)
	pick_scroll = ScrollContainer.new()
	pick_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pick_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	pick_scroll.scroll_deadzone = 12
	pick_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pick_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pick_panel.add_child(pick_scroll)
	pick_list = HBoxContainer.new()
	pick_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pick_list.alignment = BoxContainer.ALIGNMENT_END
	pick_list.add_theme_constant_override("separation", 4)
	pick_scroll.add_child(pick_list)


func _tile_style(c: Color, border := Color(1, 1, 1, 0.18)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(1)
	sb.border_color = border
	sb.set_content_margin_all(3)
	return sb


func _build_bag_panel() -> void:
	# fundo: arrastar um item pra fora da mochila larga ele no chão
	bag_back = Control.new()
	bag_back.set_anchors_preset(Control.PRESET_FULL_RECT)
	bag_back.visible = false
	add_child(bag_back)
	bag_back.set_drag_forwarding(Callable(), func(_p, d): return d is Dictionary and d.get("t") in ["item", "att", "gun", "gear"],
		func(_p, d): _drop_any(d))
	bag_panel = PanelContainer.new()
	var st := _panel_style(0.9)
	st.set_corner_radius_all(14)
	st.set_content_margin_all(12)
	st.border_color = Color(1, 1, 1, 0.12)
	st.set_border_width_all(1)
	bag_panel.add_theme_stylebox_override("panel", st)
	bag_panel.visible = false
	add_child(bag_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	bag_panel.add_child(vb)
	# topo: ícone da mochila, ocupação e X
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	vb.add_child(top)
	var ic := Control.new()
	ic.custom_minimum_size = Vector2(34, 34)
	ic.draw.connect(func(): glyph(ic, "bag", ic.size / 2.0, 15.0, Color(1, 0.85, 0.35)))
	top.add_child(ic)
	bag_title = Label.new()
	bag_title.add_theme_font_size_override("font_size", 20)
	top.add_child(bag_title)
	bag_bar = Control.new()
	bag_bar.custom_minimum_size = Vector2(120, 34)
	bag_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag_bar.draw.connect(func():
		var r := Rect2(Vector2(0, 13), Vector2(bag_bar.size.x, 8))
		bag_bar.draw_rect(r, Color(1, 1, 1, 0.12))
		var k := clampf(_bag_cap_k, 0.0, 1.0)
		bag_bar.draw_rect(Rect2(r.position, Vector2(r.size.x * k, r.size.y)), Color(1, 0.3, 0.25) if k >= 1.0 else Color(1, 0.8, 0.3)))
	top.add_child(bag_bar)
	bag_cap = Label.new()
	bag_cap.add_theme_font_size_override("font_size", 18)
	top.add_child(bag_cap)
	top.add_child(_icon_btn("close", 40.0, func(): set_bag(false)))
	var hb := HBoxContainer.new()
	hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hb.add_theme_constant_override("separation", 12)
	vb.add_child(hb)
	bag_left = VBoxContainer.new()
	bag_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag_left.size_flags_stretch_ratio = 1.15
	bag_left.add_theme_constant_override("separation", 6)
	hb.add_child(bag_left)
	var sc := ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.scroll_deadzone = 12
	hb.add_child(sc)
	# tirar acessório arrastando ele pra mochila
	sc.set_drag_forwarding(Callable(), func(_p, d): return d is Dictionary and d.get("t") == "att",
		func(_p, d): inv_action.emit("unequip", d["kind"], int(d["slot"])); bag_sel = {})
	bag_grid = GridContainer.new()
	bag_grid.columns = 4
	bag_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag_grid.add_theme_constant_override("h_separation", 6)
	bag_grid.add_theme_constant_override("v_separation", 6)
	sc.add_child(bag_grid)
	# barra de ações do item escolhido + lixeira (arraste pra largar)
	var bot := HBoxContainer.new()
	bot.add_theme_constant_override("separation", 8)
	vb.add_child(bot)
	bag_act = HBoxContainer.new()
	bag_act.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag_act.add_theme_constant_override("separation", 8)
	bag_act.custom_minimum_size = Vector2(0, 48)
	bot.add_child(bag_act)


func _drop_any(d: Dictionary) -> void:
	bag_sel = {}
	match d.get("t"):
		"item":
			inv_action.emit("drop", d["kind"], int(d["n"]))
		"att":
			inv_action.emit("unequip", d["kind"], int(d["slot"]))
		"gun":
			inv_action.emit("drop_gun", "", int(d["slot"]))
		"gear":
			inv_action.emit("drop", d["kind"], 0)
	_bag_sig = ""


# botão redondo com ícone desenhado (sem texto)
func _icon_btn(kind: String, sz: float, cb: Callable, col := Color(1, 1, 1, 0.08)) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(sz, sz)
	b.focus_mode = Control.FOCUS_NONE
	var sb := _tile_style(col, Color(1, 1, 1, 0.35))
	sb.set_corner_radius_all(int(sz / 2.0))
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	var sp := _tile_style(Color(1, 0.8, 0.3, 0.4), Color(1, 1, 1, 0.6))
	sp.set_corner_radius_all(int(sz / 2.0))
	b.add_theme_stylebox_override("pressed", sp)
	var g := Control.new()
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.set_anchors_preset(Control.PRESET_FULL_RECT)
	g.draw.connect(func(): glyph(g, kind, g.size / 2.0, sz * 0.27, Color.WHITE))
	b.add_child(g)
	b.pressed.connect(cb)
	return b


# ---------------- ícones (imagens prontas em icons/, feitas por tools/make_icons.gd) ----------------

func make_icons() -> void:
	var list := []
	for k in Weapons.DATA:
		list.append(k)
	for k in Weapons.ITEMS:
		list.append(k)
	list.append("box")
	for id in list:
		var path := "res://icons/%s.png" % id
		if ResourceLoader.exists(path):
			icons[id] = load(path)
		var wp := "res://icons/w_%s.png" % id
		if ResourceLoader.exists(wp):
			icons["w_" + id] = load(wp)
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


# abate: caveira grande no meio da tela, curta e séria
func kill_banner(victim: String, head: bool, total: int) -> void:
	kill_t = 1.6
	kill_txt = victim
	kill_head = head
	kill_n = total


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
	bag_back.visible = open
	bag_sel = {}
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
	_pick_n = list.size()
	for c in pick_list.get_children():
		pick_list.remove_child(c)
		c.queue_free()
	# o primeiro item fica na direita (lê da direita pra esquerda)
	var rev := list.duplicate()
	rev.reverse()
	for e in rev:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.set_meta("key", e["key"])
		b.add_theme_stylebox_override("normal", _tile_style(Color(0.62, 0.66, 0.62, 0.3)))
		b.add_theme_stylebox_override("hover", _tile_style(Color(0.62, 0.66, 0.62, 0.3)))
		b.add_theme_stylebox_override("pressed", _tile_style(Color(1, 0.8, 0.3, 0.35)))
		var vb := VBoxContainer.new()
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.set_anchors_preset(Control.PRESET_FULL_RECT)
		vb.add_theme_constant_override("separation", 0)
		b.add_child(vb)
		var tr := TextureRect.new()
		tr.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture = icons.get(e["kind"])
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(tr)
		var l := Label.new()
		l.text = e["label"]
		l.add_theme_font_size_override("font_size", 12)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(l)
		if int(e["n"]) > 1:
			var nl := Label.new()
			nl.text = "x%d" % e["n"]
			nl.add_theme_font_size_override("font_size", 13)
			nl.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
			nl.add_theme_constant_override("outline_size", 4)
			nl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
			nl.position = Vector2(4, 1)
			nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(nl)
		var key: Array = e["key"]
		b.pressed.connect(func(): pick.emit(key))
		pick_list.add_child(b)
	pick_panel.visible = _pick_n > 0
	await get_tree().process_frame
	pick_scroll.scroll_horizontal = int(pick_scroll.get_h_scroll_bar().max_value)


# quadradinho de item da mochila (arrastável)
func _item_tile(kind: String, n: int, data: Dictionary, sz: float, white := false) -> PanelContainer:
	var t := PanelContainer.new()
	var selected: bool = not bag_sel.is_empty() and bag_sel.get("t") == data.get("t") and bag_sel.get("kind") == data.get("kind") and int(bag_sel.get("slot", -9)) == int(data.get("slot", -9))
	var lv := Weapons.level_of(kind)
	var border: Color = Weapons.RARITY[lv] if lv >= 2 else Color(1, 1, 1, 0.22)
	var st := _tile_style(Color(1, 0.8, 0.3, 0.35) if selected else Color(0.62, 0.66, 0.62, 0.32), Color(1, 0.85, 0.35, 0.9) if selected else border)
	if lv >= 2 and not selected:
		st.set_border_width_all(2)
	t.add_theme_stylebox_override("panel", st)
	t.custom_minimum_size = Vector2(sz, sz)
	var tr := TextureRect.new()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture = icons.get(("w_" if white else "") + kind, icons.get(kind))
	if data.has("icon"):
		tr.texture = icons.get(data["icon"])
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.add_child(tr)
	if n > 1:
		var l := Label.new()
		l.text = str(n)
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_constant_override("outline_size", 4)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		l.size_flags_horizontal = Control.SIZE_SHRINK_END
		l.size_flags_vertical = Control.SIZE_SHRINK_END
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.add_child(l)
	t.set_drag_forwarding(func(_p):
		var pv := TextureRect.new()
		pv.texture = tr.texture
		pv.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pv.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pv.size = Vector2(sz, sz) * 1.2
		pv.modulate = Color(1, 1, 1, 0.85)
		var wrap := Control.new()
		wrap.add_child(pv)
		pv.position = -pv.size / 2.0
		t.set_drag_preview(wrap)
		return data, Callable(), Callable())
	t.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and not ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and not t.get_viewport().gui_is_dragging():
			bag_sel = {} if selected else data
			_bag_sig = "")
	return t


# vaga vazia com o desenho do que vai nela
func _empty_slot(cat: String, sz: float) -> Control:
	var e := Panel.new()
	e.custom_minimum_size = Vector2(sz, sz)
	e.add_theme_stylebox_override("panel", _tile_style(Color(0, 0, 0, 0.25), Color(1, 1, 1, 0.08)))
	e.mouse_filter = Control.MOUSE_FILTER_IGNORE
	e.draw.connect(func(): glyph(e, "slot_" + cat, e.size / 2.0, sz * 0.3, Color(1, 1, 1, 0.28)))
	return e


func _act_btn(kind: String, cb: Callable) -> void:
	bag_act.add_child(_icon_btn(kind, 46.0, cb, Color(1, 1, 1, 0.12)))


func refresh_bag(p: Player) -> void:
	if not bag_open or p == null:
		return
	var sig := "%s|%s|%s|%d|%d|%s|%s|%d|%s" % [str(p.guns), str(p.inv), p.armor, p.vest_lv, p.helmet, p.bag, p.sel, icons.size(), str(bag_sel)]
	if sig == _bag_sig:
		return
	_bag_sig = sig
	for c in bag_left.get_children():
		bag_left.remove_child(c)
		c.queue_free()
	for c in bag_grid.get_children():
		bag_grid.remove_child(c)
		c.queue_free()
	for c in bag_act.get_children():
		bag_act.remove_child(c)
		c.queue_free()
	var used := Weapons.slots_used(p.inv)
	_bag_cap_k = float(used) / maxf(1.0, float(p.capacity()))
	bag_title.text = "MOCHILA" if p.bag <= 0 else "MOCHILA NÍV. %d" % p.bag
	bag_cap.text = "%d/%d" % [used, p.capacity()]
	bag_bar.queue_redraw()
	# armas: arraste um acessório em cima da arma pra equipar
	for i in 3:
		var g: Dictionary = p.guns[i]
		var id: String = g["id"]
		var card := PanelContainer.new()
		var active := i == p.sel
		card.add_theme_stylebox_override("panel", _tile_style(Color(1, 1, 1, 0.1 if active else 0.05), Color(1, 0.85, 0.35, 0.9) if active else Color(1, 1, 1, 0.15)))
		card.custom_minimum_size = Vector2(0, 84)
		var slot := i
		card.set_drag_forwarding(
			func(_p): return {"t": "gun", "kind": id, "slot": slot} if id != "" else null,
			func(_p, d): return d is Dictionary and d.get("t") == "item" and Weapons.is_att(d["kind"]) and Weapons.fits(d["kind"], id),
			func(_p, d): inv_action.emit("equip", d["kind"], slot); bag_sel = {})
		card.gui_input.connect(func(ev: InputEvent):
			if id != "" and ev is InputEventMouseButton and not ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and not card.get_viewport().gui_is_dragging():
				var d := {"t": "gun", "kind": id, "slot": slot}
				bag_sel = {} if bag_sel == d else d
				_bag_sig = "")
		var hb := HBoxContainer.new()
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_theme_constant_override("separation", 6)
		card.add_child(hb)
		var tr := TextureRect.new()
		tr.custom_minimum_size = Vector2(150, 74)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture = icons.get("w_" + id) if id != "" else null
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(tr)
		var col := VBoxContainer.new()
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 2)
		hb.add_child(col)
		var nm := Label.new()
		nm.text = Weapons.item_name(id).to_upper() if id != "" else ("PISTOLA" if i == 2 else "ARMA %d" % (i + 1))
		nm.add_theme_font_size_override("font_size", 15)
		nm.add_theme_color_override("font_color", Color.WHITE if id != "" else Color(1, 1, 1, 0.35))
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(nm)
		var ar := HBoxContainer.new()
		ar.add_theme_constant_override("separation", 3)
		col.add_child(ar)
		if id != "":
			# uma vaga por tipo de acessório que a arma aceita (ícone próprio de cada tipo)
			var allowed: Array = Weapons.FITS.get(Weapons.get_w(id)["type"], [])
			var cats := []
			for c in ["sight", "muzzle", "mag", "stock"]:
				if c in allowed or (c == "sight" and (allowed.has("holo") or allowed.has("scope8"))):
					cats.append(c)
			for c in cats:
				var have := ""
				for a in g["att"]:
					if Weapons.att_cat(a) == c:
						have = a
				if have != "":
					ar.add_child(_item_tile(have, 1, {"t": "att", "kind": have, "slot": i}, 40.0))
				else:
					ar.add_child(_empty_slot(c, 40.0))
		bag_left.add_child(card)
	# equipamento vestido
	var gear := HBoxContainer.new()
	gear.add_theme_constant_override("separation", 6)
	bag_left.add_child(gear)
	for gk in ["vest", "helmet", "bag"]:
		var lv: int = {"vest": p.vest_lv if p.armor > 0.0 else 0, "helmet": p.helmet, "bag": p.bag}[gk]
		if lv > 0:
			gear.add_child(_item_tile("%s%d" % [gk, lv], int(p.armor) if gk == "vest" else 1, {"t": "gear" if gk != "bag" else "none", "kind": gk, "icon": "%s%d" % [gk, lv]}, 76.0))
		else:
			gear.add_child(_empty_slot(gk, 76.0))
	# itens soltos
	for k in p.inv:
		var kind: String = k
		var n: int = p.inv[k]
		if n <= 0:
			continue
		bag_grid.add_child(_item_tile(kind, n, {"t": "item", "kind": kind, "n": n}, 72.0))
	for i in maxi(0, p.capacity() - used):
		var empty := Panel.new()
		empty.custom_minimum_size = Vector2(72, 72)
		empty.add_theme_stylebox_override("panel", _tile_style(Color(0, 0, 0, 0.22), Color(1, 1, 1, 0.06)))
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bag_grid.add_child(empty)
	# ações do item escolhido
	if bag_sel.is_empty():
		var hint := Label.new()
		hint.text = "Arraste até a arma pra equipar · arraste pra fora pra largar"
		hint.add_theme_font_size_override("font_size", 14)
		hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
		bag_act.add_child(hint)
		return
	var d := bag_sel
	var nm2 := Label.new()
	nm2.text = Weapons.item_name(d.get("icon", d["kind"])) if d["t"] != "gun" else Weapons.item_name(d["kind"]).to_upper()
	nm2.add_theme_font_size_override("font_size", 16)
	nm2.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bag_act.add_child(nm2)
	match d["t"]:
		"item":
			var kind: String = d["kind"]
			if Weapons.ITEMS.get(kind, {}).get("kind", "") == "heal":
				_act_btn("heal", func(): inv_action.emit("use", kind, 0))
			elif Weapons.is_att(kind):
				for i in 3:
					if p.guns[i]["id"] != "" and Weapons.fits(kind, p.guns[i]["id"]) and not (kind in p.guns[i]["att"]):
						var gi := i
						_act_btn("equip", func(): inv_action.emit("equip", kind, gi); bag_sel = {})
						break
		"att":
			_act_btn("unequip", func(): inv_action.emit("unequip", d["kind"], int(d["slot"])); bag_sel = {})
		"gun":
			var si: int = d["slot"]
			_act_btn("hand", func(): action.emit("slot%d" % (si + 1)); bag_sel = {}; _bag_sig = "")


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
			b[k] = [bp[0], bp[1], _btn_icon(k)]
		b["e_small"] = [Vector2(s.x * 0.5 - 200, 60), 30.0, "minus"]
		b["e_big"] = [Vector2(s.x * 0.5 - 110, 60), 30.0, "plus"]
		b["e_reset"] = [Vector2(s.x * 0.5 - 20, 60), 30.0, "reset"]
		b["e_save"] = [Vector2(s.x * 0.5 + 70, 60), 30.0, "check"]
		b["e_cancel"] = [Vector2(s.x * 0.5 + 160, 60), 30.0, "close"]
		return b
	b["exit"] = [Vector2(s.x - 300, 34), 22.0, "exit"]
	b["settings"] = [Vector2(s.x - 352, 34), 22.0, "gear"]
	if big_map:
		b["map"] = [Vector2(s.x - 70, s.y - 60), 34.0, "close"]
		return b
	if bag_open:
		return b
	var fp := btn_pos("fire", s)
	match mode:
		"plane":
			if can_leave:
				b["leave"] = [fp[0], 80.0, "leave"]
		"fall":
			b["chute"] = [fp[0], 70.0, "chute"]
		"ground", "lobby":
			if car_near:
				b["car"] = [Vector2(s.x * 0.66, s.y * 0.68), 40.0, "car"]
			if driving:
				return b
			if grenades > 0:
				b["grenade"] = [Vector2(s.x * 0.66, s.y * 0.88), 34.0, "grenade"]
			if gren_left >= 0.0:
				b["gren_cancel"] = [Vector2(s.x * 0.66, s.y * 0.72), 28.0, "close"]
			for k in ["fire", "fire2", "jump", "crouch", "reload", "scope", "heal", "bag", "sprint"]:
				if k == "scope" and not can_scope:
					continue
				var bp := btn_pos(k, s)
				b[k] = [bp[0], bp[1], _btn_icon(k)]
			if can_start:
				b["start"] = [Vector2(s.x * 0.5, s.y * 0.5 + 120), 56.0, "play"]
		"dead":
			b["spec"] = [Vector2(s.x - 110, s.y - 110), 50.0, "next"]
			b["menu"] = [Vector2(110, s.y - 110), 50.0, "home"]
		"end":
			b["menu"] = [Vector2(s.x * 0.5 - (110 if can_retry else 0), s.y * 0.72), 58.0, "home"]
			if can_retry:
				b["retry"] = [Vector2(s.x * 0.5 + 110, s.y * 0.72), 58.0, "reset"]
	return b


func _btn_icon(k: String) -> String:
	match k:
		"fire", "fire2":
			return "fire" if (sel >= 1 and _slot_has(sel)) else "punch"
		"crouch":
			return "stand" if crouched else "crouch"
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
	# faixa de coleta: tratada aqui (funciona com outro dedo no analógico)
	if pick_panel.visible and Rect2(pick_panel.position, pick_panel.size).has_point(p) and not bag_open:
		touches[i] = "pick"
		_pick_touch[i] = [p, 0.0]
		return
	if _in_gui(p):
		touches[i] = "gui"
		return
	# tocar fora da mochila fecha ela
	if bag_open and not edit_mode:
		touches[i] = "btn"
		set_bag(false)
		return
	var b := _hit_button(p)
	if edit_mode:
		if b in EDITABLE:
			edit_sel = b
			touches[i] = "drag:" + b
		elif b != "":
			touches[i] = "btn"
			_edit_cmd(b)
		elif _hit_slot(p) >= 0:
			# painel das armas: dá pra mudar o tamanho (MENOR/MAIOR)
			edit_sel = "slots"
			touches[i] = "btn"
		return
	if b == "fire" or b == "fire2":
		touches[i] = "fire"
		return
	if b == "grenade":
		# segura pra tirar o pino; solta pra jogar
		touches[i] = "gren"
		action.emit("grenade_hold")
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
		# encostar no analógico já para a corrida automática
		action.emit("joy_touch")
		touches[i] = "joy"
		joy_active = true
		joy_origin = p
		move_vec = Vector2.ZERO
	else:
		touches[i] = "look"


func _up(i: int) -> void:
	var r: String = touches.get(i, "")
	touches.erase(i)
	if r == "pick" and _pick_touch.has(i):
		var st: Array = _pick_touch[i]
		_pick_touch.erase(i)
		if float(st[1]) < 14.0:
			for c in pick_list.get_children():
				if (c as Control).get_global_rect().has_point(st[0]) and c.has_meta("key"):
					pick.emit(c.get_meta("key"))
					break
	if r == "joy":
		joy_active = false
		move_vec = Vector2.ZERO
	if r == "gren":
		action.emit("grenade_throw")


func _drag(i: int, p: Vector2, rel: Vector2) -> void:
	var r: String = touches.get(i, "")
	if r == "joy":
		var v := (p - joy_origin) / JOY_R
		if v.length() > 1.0:
			v = v.normalized()
		if v.length() < 0.12:
			v = Vector2.ZERO
		move_vec = v
	elif r == "pick" and _pick_touch.has(i):
		_pick_touch[i][1] = float(_pick_touch[i][1]) + rel.length()
		pick_scroll.scroll_horizontal -= int(rel.x)
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
			if edit_sel == "slots":
				var sc0 := slot_scale()
				layout["slots"] = [0.0, 0.0, clampf(sc0 + (-0.1 if b == "e_small" else 0.1), 0.7, 1.5)]
			elif edit_sel != "":
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
	kill_t = maxf(kill_t - delta, 0.0)
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
	lbl_spec.position = Vector2(0, 92)
	lbl_spec.size = Vector2(s.x, 30)
	var under := s.y * 0.345 + 40.0
	lbl_zone.position = Vector2(14, under)
	lbl_zone.size = Vector2(320, 30)
	lbl_fps.position = Vector2(14, under + 24)
	lbl_fps.visible = show_fps
	lbl_fps.text = "FPS %d" % Engine.get_frames_per_second()
	feed_box.position = Vector2(14, under + 50)
	feed_box.size = Vector2(420, 10)
	# faixa de coleta: proporção 100 x 20, cabem 5 itens
	var pw := clampf(s.x * 0.3, 300.0, 400.0)
	var ph := pw * 0.2
	pick_panel.position = Vector2(s.x - pw - 14.0, _slots_bottom + 10.0)
	pick_panel.size = Vector2(pw, ph)
	pick_panel.custom_minimum_size = pick_panel.size
	pick_scroll.custom_minimum_size = Vector2(pw - 12, ph - 12)
	var cell := (pw - 12.0 - 4.0 * 4.0) / 5.0
	for c in pick_list.get_children():
		(c as Control).custom_minimum_size = Vector2(cell, ph - 12)
	pick_list.custom_minimum_size = Vector2(pw - 12.0, 0)
	pick_panel.visible = _pick_n > 0 and mode == "ground" and not bag_open and not edit_mode and not big_map
	# mochila: no meio, sem ocupar a tela toda
	var bw := clampf(s.x * 0.62, 560.0, 860.0)
	bag_panel.size = Vector2(bw, s.y * 0.82)
	bag_panel.position = Vector2((s.x - bw) / 2.0, s.y * 0.09)
	bag_panel.custom_minimum_size = bag_panel.size
	bigmap.visible = big_map
	mini.visible = not big_map and mode != "end" and not edit_mode
	pad.queue_redraw()
	if mini.visible:
		mini.queue_redraw()
	if big_map:
		bigmap.queue_redraw()


# ---------------- desenho ----------------

func _draw_btn(font: Font, k: String, pos: Vector2, r: float, icon: String) -> void:
	var held: bool = (k == "fire" or k == "fire2") and fire_held
	var bg := Color(0, 0, 0, 0.32)
	var ring := Color(1, 1, 1, 0.55)
	if held:
		bg = Color(1, 0.4, 0.2, 0.5)
	elif k == "leave" or k == "start" or k == "retry" or k == "e_save":
		bg = Color(0.85, 0.55, 0.1, 0.6)
	elif (k == "sprint" and sprinting) or (k == "crouch" and crouched):
		bg = Color(1, 0.75, 0.2, 0.45)
		ring = Color(1, 0.85, 0.35, 0.95)
	if edit_mode and k == edit_sel:
		bg = Color(0.2, 0.6, 1.0, 0.5)
	pad.draw_circle(pos, r, bg)
	pad.draw_arc(pos, r, 0, TAU, 40, ring, 2.5)
	glyph(pad, icon, pos, r * 0.48, Color(1, 1, 1, 0.95))
	if k == "grenade":
		var gs := "%d" % grenades
		pad.draw_circle(pos + Vector2(r * 0.68, -r * 0.68), 10.0, Color(0.5, 0.45, 0.2))
		var gw := font.get_string_size(gs, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		pad.draw_string(font, pos + Vector2(r * 0.68 - gw / 2.0, -r * 0.68 + 5), gs, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	if k == "heal":
		var sub := "%d" % (heals[0] + heals[1])
		pad.draw_circle(pos + Vector2(r * 0.68, -r * 0.68), 10.0, Color(0.15, 0.6, 0.25))
		var sw := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		pad.draw_string(font, pos + Vector2(r * 0.68 - sw / 2.0, -r * 0.68 + 5), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)


# Ícones vetoriais simples (brancos), usados nos botões e na mochila.
static func glyph(ci: CanvasItem, k: String, c: Vector2, r: float, col: Color) -> void:
	var w := maxf(2.0, r * 0.13)
	match k:
		"fire":
			ci.draw_arc(c, r * 0.62, 0, TAU, 28, col, w)
			for i in 4:
				var d := Vector2.RIGHT.rotated(i * PI / 2.0)
				ci.draw_line(c + d * r * 0.35, c + d * r, col, w)
			ci.draw_circle(c, w * 0.8, col)
		"punch":
			for i in 4:
				ci.draw_circle(c + Vector2(-r * 0.45 + i * r * 0.3, -r * 0.35), r * 0.17, col)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.62, -r * 0.35), Vector2(r * 1.24, r * 0.75)), col)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.4, r * 0.38), Vector2(r * 0.85, r * 0.45)), col)
			ci.draw_line(c + Vector2(-r * 0.6, 0.0), c + Vector2(r * 0.1, 0.0), Color(0, 0, 0, 0.45), w * 0.8)
		"jump":
			for o in [0.0, 0.45]:
				ci.draw_polyline(PackedVector2Array([c + Vector2(-r * 0.6, r * (0.15 + o)), c + Vector2(0, r * (-0.45 + o)), c + Vector2(r * 0.6, r * (0.15 + o))]), col, w * 1.2)
		"crouch", "stand":
			var sg := 1.0 if k == "crouch" else -1.0
			ci.draw_polyline(PackedVector2Array([c + Vector2(-r * 0.55, -r * 0.35 * sg), c + Vector2(0, r * 0.2 * sg), c + Vector2(r * 0.55, -r * 0.35 * sg)]), col, w * 1.2)
			ci.draw_line(c + Vector2(-r * 0.7, r * 0.62), c + Vector2(r * 0.7, r * 0.62), col, w)
		"reload", "reset":
			ci.draw_arc(c, r * 0.65, -PI * 0.35, PI * 1.45, 28, col, w)
			var tip := c + Vector2(cos(-PI * 0.35), sin(-PI * 0.35)) * r * 0.65
			ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(r * 0.35, -r * 0.05), tip + Vector2(-r * 0.2, -r * 0.3), tip + Vector2(-r * 0.05, r * 0.28)]), col)
		"scope":
			ci.draw_arc(c, r * 0.75, 0, TAU, 32, col, w)
			ci.draw_line(c + Vector2(-r, 0), c + Vector2(-r * 0.25, 0), col, w)
			ci.draw_line(c + Vector2(r, 0), c + Vector2(r * 0.25, 0), col, w)
			ci.draw_line(c + Vector2(0, -r), c + Vector2(0, -r * 0.25), col, w)
			ci.draw_line(c + Vector2(0, r), c + Vector2(0, r * 0.25), col, w)
			ci.draw_circle(c, w * 0.7, Color(1, 0.3, 0.2))
		"heal":
			ci.draw_rect(Rect2(c - Vector2(r * 0.8, r * 0.6), Vector2(r * 1.6, r * 1.2)), col, false, w)
			ci.draw_rect(Rect2(c - Vector2(r * 0.12, r * 0.42), Vector2(r * 0.24, r * 0.84)), Color(1, 0.3, 0.25))
			ci.draw_rect(Rect2(c - Vector2(r * 0.42, r * 0.12), Vector2(r * 0.84, r * 0.24)), Color(1, 0.3, 0.25))
		"bag":
			ci.draw_arc(c + Vector2(0, -r * 0.55), r * 0.28, PI, TAU, 12, col, w)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.6, -r * 0.55), Vector2(r * 1.2, r * 1.35)), col, false, w)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.38, r * 0.15), Vector2(r * 0.76, r * 0.45)), col, false, w * 0.8)
			ci.draw_line(c + Vector2(-r * 0.6, -r * 0.15), c + Vector2(r * 0.6, -r * 0.15), col, w * 0.8)
		"sprint":
			# bonequinho correndo
			ci.draw_circle(c + Vector2(r * 0.28, -r * 0.72), r * 0.18, col)
			var hip := c + Vector2(-r * 0.05, r * 0.15)
			var neck := c + Vector2(r * 0.18, -r * 0.45)
			ci.draw_line(neck, hip, col, w * 1.2)
			ci.draw_polyline(PackedVector2Array([neck + Vector2(0, r * 0.1), c + Vector2(-r * 0.3, -r * 0.2), c + Vector2(-r * 0.55, r * 0.05)]), col, w)
			ci.draw_polyline(PackedVector2Array([neck + Vector2(0, r * 0.1), c + Vector2(r * 0.45, -r * 0.05), c + Vector2(r * 0.7, -r * 0.35)]), col, w)
			ci.draw_polyline(PackedVector2Array([hip, c + Vector2(r * 0.35, r * 0.45), c + Vector2(r * 0.25, r * 0.9)]), col, w)
			ci.draw_polyline(PackedVector2Array([hip, c + Vector2(-r * 0.3, r * 0.55), c + Vector2(-r * 0.75, r * 0.6)]), col, w)
		"gear":
			for i in 8:
				var d := Vector2.RIGHT.rotated(i * TAU / 8.0)
				ci.draw_line(c + d * r * 0.5, c + d * r * 0.95, col, w * 1.8)
			ci.draw_arc(c, r * 0.58, 0, TAU, 24, col, w * 1.4)
			ci.draw_arc(c, r * 0.22, 0, TAU, 16, col, w)
		"exit":
			ci.draw_polyline(PackedVector2Array([c + Vector2(r * 0.1, -r * 0.8), c + Vector2(-r * 0.7, -r * 0.8), c + Vector2(-r * 0.7, r * 0.8), c + Vector2(r * 0.1, r * 0.8)]), col, w)
			ci.draw_line(c + Vector2(-r * 0.25, 0), c + Vector2(r * 0.85, 0), col, w)
			ci.draw_polyline(PackedVector2Array([c + Vector2(r * 0.5, -r * 0.35), c + Vector2(r * 0.85, 0), c + Vector2(r * 0.5, r * 0.35)]), col, w)
		"close":
			ci.draw_line(c + Vector2(-r * 0.6, -r * 0.6), c + Vector2(r * 0.6, r * 0.6), col, w * 1.3)
			ci.draw_line(c + Vector2(r * 0.6, -r * 0.6), c + Vector2(-r * 0.6, r * 0.6), col, w * 1.3)
		"leave":
			ci.draw_line(c + Vector2(0, -r * 0.8), c + Vector2(0, r * 0.6), col, w * 1.3)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-r * 0.5, r * 0.15), c + Vector2(0, r * 0.7), c + Vector2(r * 0.5, r * 0.15)]), col, w * 1.3)
		"chute":
			ci.draw_arc(c + Vector2(0, -r * 0.1), r * 0.85, PI, TAU, 20, col, w * 1.3)
			for x in [-0.85, -0.3, 0.3, 0.85]:
				ci.draw_line(c + Vector2(r * x, -r * 0.1), c + Vector2(0, r * 0.8), col, w * 0.6)
			ci.draw_circle(c + Vector2(0, r * 0.8), r * 0.14, col)
		"next", "play":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.4, -r * 0.65), c + Vector2(r * 0.65, 0), c + Vector2(-r * 0.4, r * 0.65)]), col)
		"home":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-r * 0.8, -r * 0.05), c + Vector2(0, -r * 0.8), c + Vector2(r * 0.8, -r * 0.05)]), col, w * 1.2)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.55, -r * 0.15), Vector2(r * 1.1, r * 0.85)), col, false, w)
		"minus":
			ci.draw_line(c + Vector2(-r * 0.6, 0), c + Vector2(r * 0.6, 0), col, w * 1.4)
		"plus":
			ci.draw_line(c + Vector2(-r * 0.6, 0), c + Vector2(r * 0.6, 0), col, w * 1.4)
			ci.draw_line(c + Vector2(0, -r * 0.6), c + Vector2(0, r * 0.6), col, w * 1.4)
		"check":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-r * 0.6, 0), c + Vector2(-r * 0.15, r * 0.5), c + Vector2(r * 0.65, -r * 0.5)]), col, w * 1.4)
		"drop":
			# lixeira
			ci.draw_line(c + Vector2(-r * 0.75, -r * 0.55), c + Vector2(r * 0.75, -r * 0.55), col, w)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.22, -r * 0.8), Vector2(r * 0.44, r * 0.25)), col, false, w * 0.8)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-r * 0.55, -r * 0.45), c + Vector2(-r * 0.42, r * 0.8), c + Vector2(r * 0.42, r * 0.8), c + Vector2(r * 0.55, -r * 0.45)]), col, w)
			for x in [-0.18, 0.18]:
				ci.draw_line(c + Vector2(r * x, -r * 0.25), c + Vector2(r * x, r * 0.55), col, w * 0.7)
		"equip":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.75, -r * 0.25), Vector2(r * 1.5, r * 0.55)), col, false, w)
			ci.draw_line(c + Vector2(0, -r * 0.95), c + Vector2(0, -r * 0.35), col, w)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-r * 0.25, -r * 0.6), c + Vector2(0, -r * 0.3), c + Vector2(r * 0.25, -r * 0.6)]), col, w)
		"unequip":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.75, -r * 0.0), Vector2(r * 1.5, r * 0.55)), col, false, w)
			ci.draw_line(c + Vector2(0, -r * 0.95), c + Vector2(0, -r * 0.15), col, w)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-r * 0.25, -r * 0.7), c + Vector2(0, -r * 0.95), c + Vector2(r * 0.25, -r * 0.7)]), col, w)
		"hand":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.45, -r * 0.1), Vector2(r * 0.9, r * 0.8)), col)
			for i in 4:
				ci.draw_rect(Rect2(c + Vector2(-r * 0.45 + i * r * 0.23, -r * 0.75), Vector2(r * 0.18, r * 0.7)), col)
			ci.draw_line(c + Vector2(-r * 0.45, r * 0.25), c + Vector2(-r * 0.85, -r * 0.2), col, w * 1.6)
		"slot_sight":
			ci.draw_arc(c, r * 0.7, 0, TAU, 24, col, w)
			ci.draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), col, w * 0.7)
			ci.draw_line(c + Vector2(0, -r), c + Vector2(0, r), col, w * 0.7)
		"slot_muzzle":
			ci.draw_rect(Rect2(c + Vector2(-r, -r * 0.25), Vector2(r * 2.0, r * 0.5)), col, false, w)
			for x in [-0.4, 0.0, 0.4]:
				ci.draw_line(c + Vector2(r * x, -r * 0.25), c + Vector2(r * x, r * 0.25), col, w * 0.6)
		"slot_mag":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.35, -r), c + Vector2(r * 0.25, -r), c + Vector2(r * 0.55, r), c + Vector2(-r * 0.05, r)]), col)
		"slot_stock":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r, -r * 0.2), c + Vector2(r * 0.4, -r * 0.2), c + Vector2(r, r * 0.6), c + Vector2(r * 0.4, r * 0.6), c + Vector2(r * 0.1, r * 0.15), c + Vector2(-r, r * 0.15)]), col)
		"slot_vest":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.7, -r * 0.8), c + Vector2(-r * 0.3, -r * 0.8), c + Vector2(0, -r * 0.5), c + Vector2(r * 0.3, -r * 0.8), c + Vector2(r * 0.7, -r * 0.8), c + Vector2(r * 0.8, r * 0.9), c + Vector2(-r * 0.8, r * 0.9)]), col)
		"slot_helmet":
			ci.draw_arc(c + Vector2(0, r * 0.3), r * 0.8, PI, TAU, 16, col, w * 2.0)
			ci.draw_line(c + Vector2(-r, r * 0.35), c + Vector2(r, r * 0.35), col, w * 1.5)
		"slot_bag":
			glyph(ci, "bag", c, r, col)
		"grenade":
			ci.draw_circle(c + Vector2(0, r * 0.15), r * 0.55, col)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.18, -r * 0.6), Vector2(r * 0.36, r * 0.25)), col)
			ci.draw_line(c + Vector2(r * 0.2, -r * 0.5), c + Vector2(r * 0.55, -r * 0.1), col, w)
			ci.draw_arc(c + Vector2(-r * 0.35, -r * 0.6), r * 0.18, 0, TAU, 10, col, w * 0.7)
		"car":
			# carrinho visto de lado
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.9, r * 0.25), c + Vector2(-r * 0.9, -r * 0.05), c + Vector2(-r * 0.45, -r * 0.1), c + Vector2(-r * 0.2, -r * 0.5), c + Vector2(r * 0.4, -r * 0.5), c + Vector2(r * 0.65, -r * 0.1), c + Vector2(r * 0.9, -r * 0.05), c + Vector2(r * 0.9, r * 0.25)]), col)
			for x in [-0.5, 0.5]:
				ci.draw_circle(c + Vector2(r * x, r * 0.3), r * 0.22, Color(0, 0, 0, 0.6))
				ci.draw_arc(c + Vector2(r * x, r * 0.3), r * 0.22, 0, TAU, 12, col, w)
		_:
			ci.draw_circle(c, r * 0.3, col)


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


# Painel de armas estilo FF: a da mão grande em cima; as outras pequenas embaixo, lado a lado.
func _draw_slots(font: Font, s: Vector2) -> void:
	_slot_rects.clear()
	if slots.is_empty() or not (mode == "ground" or mode == "lobby" or edit_mode):
		return
	var sc := slot_scale()
	var right := s.x - 14.0
	var bw := 236.0 * sc
	var bh := 86.0 * sc
	var big := Rect2(right - bw, 12.0, bw, bh)
	var cur: int = clampi(sel, 0, slots.size() - 1)
	var others := []
	for i in slots.size():
		if i != cur:
			others.append(i)
	_slot_cell(font, big, cur, true)
	var gap := 4.0
	var sw := (bw - gap * (others.size() - 1)) / others.size()
	for k in others.size():
		var r := Rect2(big.position.x + k * (sw + gap), big.end.y + 5.0, sw, 46.0 * sc)
		_slot_cell(font, r, others[k], false)
	_slots_bottom = big.end.y + 5.0 + 46.0 * sc
	if edit_mode:
		var all := Rect2(big.position, Vector2(bw, _slots_bottom - big.position.y))
		pad.draw_rect(all.grow(4), Color(0.2, 0.6, 1.0, 0.35) if edit_sel == "slots" else Color(1, 1, 1, 0.12))


func slot_scale() -> float:
	return float(layout.get("slots", [0.0, 0.0, 1.0])[2])


func _slot_cell(font: Font, r: Rect2, i: int, active: bool) -> void:
	_slot_rects.append([r, i])
	var e: Dictionary = slots[i]
	var id: String = str(e["id"])
	var has := id != ""
	pad.draw_rect(r, Color(0.03, 0.04, 0.03, 0.55 if active else 0.38))
	pad.draw_rect(r, Color(1, 0.85, 0.3, 0.95) if active else Color(1, 1, 1, 0.22), false, 2.0 if active else 1.0)
	if not has:
		var dash := "—"
		pad.draw_string(font, r.get_center() + Vector2(-6, 6), dash, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.3))
		return
	var tex: Texture2D = icons.get("w_" + id, icons.get(id))
	var name := "MÃOS" if id == "fist" else Weapons.item_name(id).to_upper()
	if active:
		var ir := Rect2(r.position + Vector2(8, 4), Vector2(r.size.x * 0.62, r.size.y - 26))
		if tex:
			pad.draw_texture_rect(tex, ir, false)
		pad.draw_string(font, r.position + Vector2(10, r.size.y - 8), name, HORIZONTAL_ALIGNMENT_LEFT, r.size.x * 0.6, 15, Color.WHITE)
		if id != "fist":
			var at := "%d" % e["ammo"]
			var aw := font.get_string_size(at, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
			var ax := r.end.x - aw - 10
			pad.draw_string_outline(font, Vector2(ax, r.position.y + 38), at, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, 4, Color(0, 0, 0, 0.7))
			pad.draw_string(font, Vector2(ax, r.position.y + 38), at, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1, 0.3, 0.25) if int(e["ammo"]) == 0 else Color.WHITE)
			var rs := "RECARREG." if reloading else "/ %d" % int(e.get("res", 0))
			var rw := font.get_string_size(rs, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			pad.draw_string(font, Vector2(r.end.x - rw - 10, r.position.y + 60), rs, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.85, 0.4) if reloading else Color(1, 1, 1, 0.75))
	else:
		var ir := Rect2(r.position + Vector2(4, 2), Vector2(r.size.x - 8, r.size.y - 18))
		if tex:
			pad.draw_texture_rect(tex, ir, false, Color(1, 1, 1, 0.8))
		var nw := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		pad.draw_string(font, Vector2(r.get_center().x - minf(nw, r.size.x - 4) / 2.0, r.end.y - 4), name, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 4, 11, Color(1, 1, 1, 0.8))


# bússola no topo: gira junto com a câmera
func _draw_compass(font: Font, s: Vector2) -> void:
	var yaw: float = game.cam_yaw.rotation.y if game and game.cam_yaw else 0.0
	var head := fposmod(rad_to_deg(-yaw), 360.0)   # 0 = norte (-Z), 90 = leste (+X)
	var w := minf(420.0, s.x * 0.34)
	var cx := s.x * 0.5
	var y := 14.0
	pad.draw_rect(Rect2(cx - w / 2.0, y, w, 30), Color(0, 0, 0, 0.28))
	var span := 100.0
	var names := {0: "N", 45: "NE", 90: "L", 135: "SE", 180: "S", 225: "SO", 270: "O", 315: "NO"}
	var d0 := int(floor((head - span / 2.0) / 15.0)) * 15
	var d := d0
	while d <= head + span / 2.0:
		var x := cx + (d - head) / span * w
		var dd := posmod(d, 360)
		if names.has(dd):
			var t: String = names[dd]
			var fs := 17 if t.length() == 1 else 13
			var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var cc := Color(1, 0.8, 0.3) if dd == 0 else Color.WHITE
			pad.draw_string(font, Vector2(x - tw / 2.0, y + 22), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, cc)
		else:
			pad.draw_line(Vector2(x, y + 20), Vector2(x, y + 28), Color(1, 1, 1, 0.6), 1.5)
		d += 15
	pad.draw_colored_polygon(PackedVector2Array([Vector2(cx, y + 31), Vector2(cx - 6, y + 39), Vector2(cx + 6, y + 39)]), Color(1, 0.85, 0.3))
	var deg := "%d" % (int(round(head)) % 360)
	var dw := font.get_string_size(deg, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	pad.draw_string(font, Vector2(cx - dw / 2.0, y + 52), deg, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.8))


func _draw_pad() -> void:
	var s := pad.size
	var font := ThemeDB.fallback_font
	var c := s / 2.0
	var white := Color(1, 1, 1, 0.9)
	if edit_mode:
		pad.draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.35))
		var msg := "Arraste os botões. Toque num botão (ou no painel das armas) e use − / + pra mudar o tamanho."
		var mw := font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		pad.draw_string(font, Vector2(c.x - mw / 2.0, 120), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)
		var b := _buttons()
		for k in b:
			_draw_btn(font, k, b[k][0], b[k][1], b[k][2])
		_draw_slots(font, s)
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
		elif iron:
			# mira de ferro (sem acessório): alça atrás e massa de mira na frente
			var dk := Color(0.08, 0.08, 0.08, 0.95)
			pad.draw_rect(Rect2(c.x - 9, c.y + 2, 18, s.y * 0.2), dk)
			pad.draw_arc(c + Vector2(0, 26), 46.0, PI * 1.08, PI * 1.92, 24, dk, 10.0)
			pad.draw_rect(Rect2(c.x - 70, c.y + 28, 52, 14), dk)
			pad.draw_rect(Rect2(c.x + 18, c.y + 28, 52, 14), dk)
			pad.draw_circle(c, 2.0, Color(1, 0.3, 0.2))
		elif red_dot:
			pad.draw_arc(c, 14.0, 0, TAU, 24, Color(0.1, 0.1, 0.1, 0.6), 2.0)
			pad.draw_circle(c, 2.5, Color(1, 0.15, 0.1))
		else:
			# a mira abre junto com o tiro (segurando o dedo)
			var g := 7.0 + cross_bloom * 9.0
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
	# granada sem pino na mão: contagem bem visível
	if gren_left >= 0.0:
		var gt := "GRANADA  %d" % ceili(gren_left)
		var gw := font.get_string_size(gt, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		var gc := Color(1, 0.25, 0.15) if gren_left < 1.3 else Color(1, 0.85, 0.3)
		pad.draw_string_outline(font, Vector2(c.x - gw / 2.0, c.y + 90), gt, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, 6, Color(0, 0, 0, 0.8))
		pad.draw_string(font, Vector2(c.x - gw / 2.0, c.y + 90), gt, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, gc)
	# cura em andamento
	if heal_k >= 0.0:
		pad.draw_arc(c, 44.0, -PI / 2.0, -PI / 2.0 + TAU * heal_k, 40, Color(0.4, 1, 0.5, 0.9), 6.0)
		var ht := "CURANDO"
		var htw := font.get_string_size(ht, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		pad.draw_string(font, c + Vector2(-htw / 2.0, 70), ht, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.6, 1, 0.7))
	# vivos e abates
	if mode != "end":
		_draw_compass(font, s)
		var tx := s.x * 0.5 - minf(420.0, s.x * 0.34) / 2.0 - 128.0
		_draw_face(Vector2(tx, 29), 12.0, Color(1, 1, 1, 0.95))
		pad.draw_string_outline(font, Vector2(tx + 18, 37), str(alive_n), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 5, Color(0, 0, 0, 0.8))
		pad.draw_string(font, Vector2(tx + 18, 37), str(alive_n), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
		_draw_skull(Vector2(tx + 78, 29), 11.0, Color(0.9, 0.15, 0.12))
		pad.draw_string_outline(font, Vector2(tx + 94, 37), str(kills_n), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 5, Color(0, 0, 0, 0.8))
		pad.draw_string(font, Vector2(tx + 94, 37), str(kills_n), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.45, 0.4))
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
		var f := clampf(hp / 200.0, 0.0, 1.0)
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
	# nomes das cidades que aparecem no minimapa
	var font := ThemeDB.fallback_font
	for t in game.world.towns:
		var q := _w2map(t["pos"], mp, sc, o)
		if q.x < -40 or q.y < -10 or q.x > mini.size.x + 40 or q.y > mini.size.y + 10:
			continue
		var nm: String = t["name"]
		var tw := font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		mini.draw_string_outline(font, q + Vector2(-tw / 2.0, 4), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(0, 0, 0, 0.85))
		mini.draw_string(font, q + Vector2(-tw / 2.0, 4), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.95))
	# passos de inimigos por perto
	for st in steps:
		var q := _w2map(st[0], mp, sc, o)
		var al := clampf(float(st[1]), 0.0, 1.0)
		mini.draw_circle(q, 3.0, Color(1, 0.3, 0.2, al))
		mini.draw_circle(q + Vector2(3, -4), 2.2, Color(1, 0.3, 0.2, al * 0.8))
	# uma seta só: pra onde a câmera olha
	var cy: float = game.cam_yaw.rotation.y
	var fwd := Vector2(-sin(cy), -cos(cy))
	var rt := Vector2(fwd.y, -fwd.x)
	mini.draw_colored_polygon(PackedVector2Array([o, o + fwd.rotated(-0.45) * 34.0, o + fwd.rotated(0.45) * 34.0]), Color(1, 1, 1, 0.1))
	var tri := PackedVector2Array([o + fwd * 10.0, o - fwd * 6.0 + rt * 6.5, o - fwd * 2.5, o - fwd * 6.0 - rt * 6.5])
	mini.draw_colored_polygon(tri, Color(1, 0.85, 0.2))
	mini.draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[3], tri[0]]), Color(0, 0, 0, 0.7), 1.2)
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
