class_name Hud
extends CanvasLayer

signal action(name: String)

const JOY_R := 90.0

var move_vec := Vector2.ZERO
var fire_held := false
var _look := Vector2.ZERO
var touches := {}    # índice do dedo -> "joy" | "look" | "fire" | "btn"

var pad: Control
var flash: ColorRect
var lbl_center: Label
var lbl_score: Label
var lbl_info: Label
var lbl_fps: Label
var feed_box: VBoxContainer

var center_t := 0.0
var hit_t := 0.0
var hit_head := false
var hit_kill := false
var pickup_name := ""
var hp := 100.0
var sniper_scope := false
var joy_active := false
var joy_origin := Vector2.ZERO


func _ready() -> void:
	layer = 5
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
	lbl_center = _label(34)
	lbl_center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_score = _label(20)
	lbl_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_info = _label(26)
	lbl_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_fps = _label(16)
	feed_box = VBoxContainer.new()
	feed_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(feed_box)


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


func set_status(h: float, wname: String, ammo: int, max_ammo: int, reloading: bool, sniper: bool) -> void:
	hp = h
	sniper_scope = sniper
	var a := "RECARREGANDO..." if reloading else "%d / %d" % [ammo, max_ammo]
	lbl_info.text = "%s     %s" % [wname, a]


func set_pickup(n: String) -> void:
	pickup_name = n


func set_score(t: String) -> void:
	lbl_score.text = t


func center(t: String, secs: float) -> void:
	lbl_center.text = t
	center_t = secs


func hit(head: bool, kill: bool) -> void:
	hit_t = 0.25
	hit_head = head
	hit_kill = kill


func hurt() -> void:
	flash.color.a = 0.35


func feed(t: String) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feed_box.add_child(l)
	get_tree().create_timer(5.0).timeout.connect(l.queue_free)
	if feed_box.get_child_count() > 5:
		feed_box.get_child(0).queue_free()


# ---------------- botões e toque ----------------

func _buttons() -> Dictionary:
	var s := get_viewport().get_visible_rect().size
	var b := {
		"fire": [Vector2(s.x - 150, s.y - 175), 78.0, "ATIRAR"],
		"jump": [Vector2(s.x - 300, s.y - 85), 46.0, "PULAR"],
		"reload": [Vector2(s.x - 70, s.y - 330), 40.0, "RECAR."],
		"scope": [Vector2(s.x - 190, s.y - 330), 42.0, "MIRA"],
		"switch": [Vector2(s.x - 310, s.y - 220), 40.0, "TROCAR"],
		"exit": [Vector2(48, 42), 32.0, "SAIR"],
	}
	if pickup_name != "":
		b["pickup"] = [Vector2(s.x * 0.5 + 200, s.y * 0.5 + 70), 50.0, "PEGAR"]
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
				action.emit("jump")
			KEY_R:
				action.emit("reload")
			KEY_Q:
				action.emit("switch")
			KEY_E:
				action.emit("pickup")
			KEY_C:
				action.emit("scope")


func _down(i: int, p: Vector2) -> void:
	var b := _hit_button(p)
	if b == "fire":
		touches[i] = "fire"
	elif b != "":
		touches[i] = "btn"
		action.emit(b)
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
	# teclado (pra testar no PC)
	var kb := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	if not joy_active:
		move_vec = kb.normalized() if kb != Vector2.ZERO else Vector2.ZERO
	fire_held = touches.values().has("fire") or Input.is_physical_key_pressed(KEY_F)
	# layout
	var s := get_viewport().get_visible_rect().size
	lbl_center.position = Vector2(0, s.y * 0.26)
	lbl_center.size = Vector2(s.x, 100)
	lbl_score.position = Vector2(0, 8)
	lbl_score.size = Vector2(s.x, 30)
	lbl_info.position = Vector2(0, s.y - 82)
	lbl_info.size = Vector2(s.x, 34)
	lbl_fps.position = Vector2(95, 30)
	lbl_fps.text = "FPS %d" % Engine.get_frames_per_second()
	feed_box.position = Vector2(s.x - 470, 44)
	feed_box.size = Vector2(450, 10)
	pad.queue_redraw()


func _draw_pad() -> void:
	var s := pad.size
	var font := ThemeDB.fallback_font
	var c := s / 2.0
	var white := Color(1, 1, 1, 0.9)
	# mira
	if sniper_scope:
		pad.draw_line(Vector2(0, c.y), Vector2(s.x, c.y), Color(0, 0, 0, 0.8), 2.0)
		pad.draw_line(Vector2(c.x, 0), Vector2(c.x, s.y), Color(0, 0, 0, 0.8), 2.0)
		pad.draw_arc(c, s.y * 0.46, 0, TAU, 64, Color(0, 0, 0, 0.9), 10.0)
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
	# joystick
	if joy_active:
		pad.draw_circle(joy_origin, JOY_R, Color(1, 1, 1, 0.1))
		pad.draw_arc(joy_origin, JOY_R, 0, TAU, 40, Color(1, 1, 1, 0.4), 2.0)
		pad.draw_circle(joy_origin + move_vec * JOY_R, 34.0, Color(1, 1, 1, 0.4))
	else:
		var hint := Vector2(190, s.y - 190)
		pad.draw_arc(hint, JOY_R, 0, TAU, 40, Color(1, 1, 1, 0.15), 2.0)
		pad.draw_circle(hint, 34.0, Color(1, 1, 1, 0.12))
	# botões
	var b := _buttons()
	for k in b:
		var pos: Vector2 = b[k][0]
		var r: float = b[k][1]
		var held: bool = k == "fire" and fire_held
		pad.draw_circle(pos, r, Color(1, 0.4, 0.2, 0.5) if held else Color(0, 0, 0, 0.35))
		pad.draw_arc(pos, r, 0, TAU, 40, Color(1, 1, 1, 0.6), 2.5)
		var label: String = b[k][2]
		var fs := 22 if k == "fire" else 15
		var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		pad.draw_string(font, pos + Vector2(-tw / 2.0, fs * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
		if k == "pickup":
			var nw := font.get_string_size(pickup_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
			pad.draw_string(font, pos + Vector2(-nw / 2.0, r + 24), pickup_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 0.9, 0.5))
	# vida
	var bw := 360.0
	var bx := s.x / 2.0 - bw / 2.0
	var by := s.y - 40.0
	var f := clampf(hp / 100.0, 0.0, 1.0)
	pad.draw_rect(Rect2(bx - 2, by - 2, bw + 4, 20), Color(0, 0, 0, 0.55))
	pad.draw_rect(Rect2(bx, by, bw * f, 16), Color(lerpf(0.9, 0.25, f), lerpf(0.2, 0.8, f), 0.2))
	var ht := "%d" % ceili(hp)
	pad.draw_string(font, Vector2(bx + bw + 10, by + 14), ht, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
