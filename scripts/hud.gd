class_name Hud
extends CanvasLayer

signal action(name: String)

const JOY_R := 90.0
const MINI := 170.0
const MINI_M := 170.0      # metros mostrados no minimapa

var game: Node
var mode := "ground"       # lobby, plane, fall, ground, dead, end
var move_vec := Vector2.ZERO
var fire_held := false
var _look := Vector2.ZERO
var touches := {}    # índice do dedo -> "joy" | "look" | "fire" | "btn"

var pad: Control
var mini: Control
var bigmap: Control
var tint: ColorRect
var flash: ColorRect
var lbl_center: Label
var lbl_top: Label
var lbl_info: Label
var lbl_fps: Label
var lbl_zone: Label
var feed_box: VBoxContainer

var center_t := 0.0
var hit_t := 0.0
var hit_head := false
var hit_kill := false
var pickup_name := ""
var hp := 100.0
var armor := 0.0
var kits := 0
var sniper_scope := false
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


func _ready() -> void:
	layer = 5
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
	lbl_center = _label(32)
	lbl_center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_top = _label(22)
	lbl_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_info = _label(24)
	lbl_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_zone = _label(17)
	lbl_fps = _label(14)
	feed_box = VBoxContainer.new()
	feed_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(feed_box)
	bigmap = Control.new()
	bigmap.set_anchors_preset(Control.PRESET_FULL_RECT)
	bigmap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bigmap.visible = false
	add_child(bigmap)
	bigmap.draw.connect(_draw_bigmap)


func _label(fs: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


# ---------------- API usada pelo jogo ----------------

func take_look() -> Vector2:
	var l := _look
	_look = Vector2.ZERO
	return l


func set_status(h: float, ar: float, k: int, wname: String, ammo: int, max_ammo: int, reloading: bool, sniper: bool) -> void:
	hp = h
	armor = ar
	kits = k
	sniper_scope = sniper
	if mode == "ground":
		var a := "RECARREGANDO..." if reloading else "%d / %d" % [ammo, max_ammo]
		lbl_info.text = "%s     %s" % [wname, a]
	else:
		lbl_info.text = ""


func set_pickup(n: String) -> void:
	pickup_name = n


func set_top(t: String) -> void:
	lbl_top.text = t


func set_zone_text(t: String) -> void:
	lbl_zone.text = t


func center(t: String, secs: float) -> void:
	lbl_center.text = t
	center_t = secs


func hit(head: bool, kill: bool) -> void:
	hit_t = 0.25
	hit_head = head
	hit_kill = kill


func hurt(dir_angle := 999.0) -> void:
	flash.color.a = 0.3
	if dir_angle < 900.0:
		hurt_dirs.append([dir_angle, 1.2])


func feed(t: String, col := Color.WHITE) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feed_box.add_child(l)
	get_tree().create_timer(6.0).timeout.connect(l.queue_free)
	if feed_box.get_child_count() > 5:
		feed_box.get_child(0).queue_free()


# ---------------- botões e toque ----------------

func _buttons() -> Dictionary:
	var s := get_viewport().get_visible_rect().size
	var b := {"exit": [Vector2(s.x - 40, 34), 26.0, "SAIR"]}
	if big_map:
		b["map"] = [Vector2(s.x - 110, 34), 30.0, "FECHAR"]
		return b
	match mode:
		"plane":
			b["leave"] = [Vector2(s.x - 160, s.y - 170), 80.0, "SALTAR"]
		"fall":
			b["chute"] = [Vector2(s.x - 160, s.y - 170), 70.0, "PARAQUEDAS"]
		"ground", "lobby":
			b["fire"] = [Vector2(s.x - 150, s.y - 175), 78.0, "ATIRAR"]
			b["jump"] = [Vector2(s.x - 300, s.y - 85), 44.0, "PULAR"]
			b["crouch"] = [Vector2(s.x - 70, s.y - 60), 40.0, "AGACHAR" if not crouched else "LEVANTAR"]
			b["reload"] = [Vector2(s.x - 70, s.y - 330), 38.0, "RECAR."]
			b["scope"] = [Vector2(s.x - 190, s.y - 330), 40.0, "MIRA"]
			b["switch"] = [Vector2(s.x - 310, s.y - 215), 38.0, "TROCAR"]
			b["heal"] = [Vector2(s.x - 410, s.y - 110), 38.0, "CURAR %d" % kits]
			if pickup_name != "":
				b["pickup"] = [Vector2(s.x * 0.5 + 200, s.y * 0.5 + 70), 48.0, "PEGAR"]
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


func _hit_button(p: Vector2) -> String:
	var b := _buttons()
	for k in b:
		if p.distance_to(b[k][0]) <= float(b[k][1]) * 1.15:
			return k
	return ""


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
			KEY_Q:
				action.emit("switch")
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
				action.emit("spec")


func _down(i: int, p: Vector2) -> void:
	var b := _hit_button(p)
	if b == "fire":
		touches[i] = "fire"
	elif b != "":
		touches[i] = "btn"
		action.emit(b)
	elif Rect2(mini.position, mini.size).grow(10).has_point(p) and not big_map:
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
		if v.length() < 0.15:
			v = Vector2.ZERO
		move_vec = v
	elif r == "look":
		_look += rel
	elif r == "fire":
		_look += rel * 0.7   # dá pra mirar arrastando o dedo no botão de tiro


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
	lbl_top.position = Vector2(0, 10)
	lbl_top.size = Vector2(s.x, 30)
	lbl_info.position = Vector2(0, s.y - 92)
	lbl_info.size = Vector2(s.x, 34)
	lbl_zone.position = Vector2(14, MINI + 20)
	lbl_zone.size = Vector2(320, 30)
	lbl_fps.position = Vector2(14, MINI + 44)
	lbl_fps.visible = show_fps
	lbl_fps.text = "FPS %d" % Engine.get_frames_per_second()
	feed_box.position = Vector2(s.x - 470, 70)
	feed_box.size = Vector2(450, 10)
	bigmap.visible = big_map
	mini.visible = not big_map and mode != "end"
	pad.queue_redraw()
	if mini.visible:
		mini.queue_redraw()
	if big_map:
		bigmap.queue_redraw()


# ---------------- desenho ----------------

func _draw_btn(font: Font, k: String, pos: Vector2, r: float, label: String) -> void:
	var held: bool = k == "fire" and fire_held
	var bg := Color(0, 0, 0, 0.35)
	if held:
		bg = Color(1, 0.4, 0.2, 0.5)
	elif k == "leave" or k == "start" or k == "retry":
		bg = Color(0.85, 0.55, 0.1, 0.6)
	pad.draw_circle(pos, r, bg)
	pad.draw_arc(pos, r, 0, TAU, 40, Color(1, 1, 1, 0.6), 2.5)
	var fs := 22 if r >= 54.0 else (16 if label.length() <= 7 else 13)
	var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	pad.draw_string(font, pos + Vector2(-tw / 2.0, fs * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


func _draw_pad() -> void:
	var s := pad.size
	var font := ThemeDB.fallback_font
	var c := s / 2.0
	var white := Color(1, 1, 1, 0.9)
	if big_map:
		_draw_btn(font, "map", _buttons()["map"][0], 30.0, "FECHAR")
		_draw_btn(font, "exit", _buttons()["exit"][0], 26.0, "SAIR")
		return
	# mira
	if mode == "ground" or mode == "lobby":
		if sniper_scope:
			pad.draw_line(Vector2(0, c.y), Vector2(s.x, c.y), Color(0, 0, 0, 0.8), 2.0)
			pad.draw_line(Vector2(c.x, 0), Vector2(c.x, s.y), Color(0, 0, 0, 0.8), 2.0)
			pad.draw_arc(c, s.y * 0.46, 0, TAU, 64, Color(0, 0, 0, 0.9), 10.0)
			pad.draw_rect(Rect2(0, 0, c.x - s.y * 0.46, s.y), Color(0, 0, 0, 0.92))
			pad.draw_rect(Rect2(c.x + s.y * 0.46, 0, s.x, s.y), Color(0, 0, 0, 0.92))
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
	# de onde veio o tiro
	for hd in hurt_dirs:
		var a: float = hd[0] - PI / 2.0
		pad.draw_arc(c, 130.0, a - 0.3, a + 0.3, 16, Color(1, 0.15, 0.1, clampf(hd[1], 0.0, 1.0) * 0.8), 9.0)
	# cura em andamento
	if heal_k >= 0.0:
		pad.draw_arc(c, 44.0, -PI / 2.0, -PI / 2.0 + TAU * heal_k, 40, Color(0.4, 1, 0.5, 0.9), 6.0)
		var ht := "CURANDO"
		var htw := font.get_string_size(ht, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		pad.draw_string(font, c + Vector2(-htw / 2.0, 70), ht, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.6, 1, 0.7))
	# joystick
	if mode in ["ground", "lobby", "fall", "glide", "plane"]:
		if joy_active:
			pad.draw_circle(joy_origin, JOY_R, Color(1, 1, 1, 0.1))
			pad.draw_arc(joy_origin, JOY_R, 0, TAU, 40, Color(1, 1, 1, 0.4), 2.0)
			pad.draw_circle(joy_origin + move_vec * JOY_R, 34.0, Color(1, 1, 1, 0.4))
		elif mode != "plane":
			var hint := Vector2(190, s.y - 170)
			pad.draw_arc(hint, JOY_R, 0, TAU, 40, Color(1, 1, 1, 0.15), 2.0)
			pad.draw_circle(hint, 34.0, Color(1, 1, 1, 0.12))
	# botões
	var b := _buttons()
	for k in b:
		_draw_btn(font, k, b[k][0], b[k][1], b[k][2])
		if k == "pickup":
			var nw := font.get_string_size(pickup_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
			pad.draw_string(font, b[k][0] + Vector2(-nw / 2.0, float(b[k][1]) + 24), pickup_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 0.9, 0.5))
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
	# eu
	var yaw: float = game.view_yaw()
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var rt := Vector2(fwd.y, -fwd.x)
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
	var side := s.y * 0.9
	var org := Vector2((s.x - side) / 2.0, (s.y - side) / 2.0)
	var tex: Texture2D = game.world.map_tex
	bigmap.draw_texture_rect(tex, Rect2(org, Vector2(side, side)), false)
	var sc := side / World.SIZE
	var o := org + Vector2(side, side) / 2.0
	var font := ThemeDB.fallback_font
	for t in game.world.towns:
		var p := _w2map(t["pos"], Vector2.ZERO, sc, o)
		var n: String = t["name"]
		var tw := font.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		bigmap.draw_string_outline(font, p + Vector2(-tw / 2.0, -float(t["r"]) * sc - 4.0), n, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0, 0, 0, 0.9))
		bigmap.draw_string(font, p + Vector2(-tw / 2.0, -float(t["r"]) * sc - 4.0), n, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
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
