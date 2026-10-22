class_name SettingsUI
extends CanvasLayer

# Tela de configurações (abre pelo menu ou durante a partida).
signal closed
signal edit_buttons
signal changed(key: String)

var panel: PanelContainer


func _ready() -> void:
	layer = 20
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.08, 0.96)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	add_child(panel)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(720, 560)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(sc)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 10)
	sc.add_child(vb)
	var top := HBoxContainer.new()
	vb.add_child(top)
	var back := _button("< VOLTAR", close)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.custom_minimum_size = Vector2(170, 52)
	top.add_child(back)
	var title := Label.new()
	title.text = "CONFIGURAÇÕES"
	title.add_theme_font_size_override("font_size", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	_section(vb, "CONTROLES")
	_cycle(vb, "Mira assistida", "aim_assist", Cfg.AIM_NAMES,
		"Controle total: sem ajuda. Gruda sem mira: a mira puxa pro inimigo só no tiro sem mirar. Gruda sempre: puxa também mirando. Arrastar pra cima enquanto atira sobe pra cabeça (capa).")
	_slider(vb, "Sensibilidade", "sens", 0.3, 2.5)
	_slider(vb, "Sensibilidade mirando", "sens_ads", 0.3, 2.5)
	_toggle(vb, "Inverter vertical", "invert")
	var eb := _button("EDITAR POSIÇÃO DOS BOTÕES", func():
		edit_buttons.emit())
	vb.add_child(eb)
	_section(vb, "VÍDEO")
	_cycle(vb, "Gráficos", "quality", Cfg.QUALITY_NAMES, "BAIXA: mais leve (sem sombra, sem grama, resolução menor). Grama muda na próxima partida.")
	_cycle_vals(vb, "Limite de FPS", "fps", [30, 45, 60], ["30", "45", "60"])
	_toggle(vb, "Sombras", "shadows")
	_toggle(vb, "Texturas detalhadas", "tex_detail")
	_toggle(vb, "Grama", "grass")
	_cycle_vals(vb, "Distância de visão", "view", [0, 1, 2], ["PERTO", "MÉDIA", "LONGE"])
	_hint(vb, "Desligar sombras, grama e textura detalhada deixa o jogo mais leve em celular fraco.")
	_toggle(vb, "Mostrar FPS", "show_fps")
	_section(vb, "JOGO")
	_toggle(vb, "Mostrar sangue", "blood")
	_toggle(vb, "Música do lobby", "music")
	_section(vb, "SOM")
	_slider(vb, "Volume", "volume", 0.0, 1.0)
	vb.add_child(_button("VOLTAR", close))


func close() -> void:
	Cfg.save()
	closed.emit()
	queue_free()


# botão "voltar" do celular fecha a tela
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		close()


func _process(_d: float) -> void:
	var s := get_viewport().get_visible_rect().size
	var w := minf(760.0, s.x - 40.0)
	var h := minf(600.0, s.y - 40.0)
	panel.position = (s - Vector2(w, h)) / 2.0
	panel.size = Vector2(w, h)
	(panel.get_child(0) as Control).custom_minimum_size = Vector2(w - 32, h - 32)


func _section(vb: VBoxContainer, t: String) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 20)
	l.modulate = Color(0.95, 0.8, 0.45)
	vb.add_child(l)


func _row(vb: VBoxContainer, t: String) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 19)
	l.custom_minimum_size = Vector2(250, 0)
	hb.add_child(l)
	vb.add_child(hb)
	return hb


func _button(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.add_theme_font_size_override("font_size", 19)
	b.custom_minimum_size = Vector2(0, 52)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	return b


func _hint(vb: VBoxContainer, t: String) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 14)
	l.modulate = Color(0.75, 0.75, 0.75)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	vb.add_child(l)


func _cycle(vb: VBoxContainer, label: String, key: String, names: Array, hint := "") -> void:
	var hb := _row(vb, label)
	var b := Button.new()
	b.add_theme_font_size_override("font_size", 18)
	b.custom_minimum_size = Vector2(0, 50)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.text = names[int(Cfg.get_v(key))]
	b.pressed.connect(func():
		var v := (int(Cfg.get_v(key)) + 1) % names.size()
		Cfg.set_v(key, v)
		b.text = names[v]
		changed.emit(key))
	hb.add_child(b)
	if hint != "":
		_hint(vb, hint)


func _cycle_vals(vb: VBoxContainer, label: String, key: String, vals: Array, names: Array) -> void:
	var hb := _row(vb, label)
	var b := Button.new()
	b.add_theme_font_size_override("font_size", 18)
	b.custom_minimum_size = Vector2(0, 50)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var idx := maxi(vals.find(Cfg.get_v(key)), 0)
	b.text = names[idx]
	b.pressed.connect(func():
		var i := (maxi(vals.find(Cfg.get_v(key)), 0) + 1) % vals.size()
		Cfg.set_v(key, vals[i])
		b.text = names[i]
		changed.emit(key))
	hb.add_child(b)


func _toggle(vb: VBoxContainer, label: String, key: String) -> void:
	var hb := _row(vb, label)
	var b := Button.new()
	b.add_theme_font_size_override("font_size", 18)
	b.custom_minimum_size = Vector2(0, 50)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.text = "SIM" if Cfg.get_v(key) else "NÃO"
	b.pressed.connect(func():
		var v := not bool(Cfg.get_v(key))
		Cfg.set_v(key, v)
		b.text = "SIM" if v else "NÃO"
		changed.emit(key))
	hb.add_child(b)


func _slider(vb: VBoxContainer, label: String, key: String, lo: float, hi: float) -> void:
	var hb := _row(vb, label)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = float(Cfg.get_v(key))
	s.custom_minimum_size = Vector2(300, 50)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vl := Label.new()
	vl.text = "%.2f" % s.value
	vl.custom_minimum_size = Vector2(60, 0)
	s.value_changed.connect(func(v: float):
		vl.text = "%.2f" % v
		Cfg.v[key] = v
		changed.emit(key))
	s.drag_ended.connect(func(_c: bool): Cfg.save())
	hb.add_child(s)
	hb.add_child(vl)
