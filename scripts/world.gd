class_name World
extends Node3D

# Mapa gerado sempre igual (mesma semente) em todos os aparelhos e no servidor.
const SIZE := 800.0
const RES := 200
const SEED := 2018
const PLAY := 365.0            # metade da área jogável
const WATER_Y := -3.0
const LAKE_C := Vector2(-40, 280)
const LAKE_R := 58.0
# nome, centro, tipo, raio
const LOCS := [
	["Vila Ferrugem", Vector2(-250, -245), "vila", 34.0],
	["Arraial do Sapo", Vector2(-125, -285), "esparso", 40.0],
	["Base Coruja", Vector2(35, -262), "base", 46.0],
	["Pedra Funda", Vector2(205, -280), "pedreira", 40.0],
	["Morro Torto", Vector2(305, -170), "torre", 18.0],
	["Brejo Seco", Vector2(-300, -115), "palafitas", 40.0],
	["Serraria Toco Velho", Vector2(-160, -150), "serraria", 30.0],
	["Pouso Velho", Vector2(-35, -135), "igreja", 40.0],
	["Posto Alvorada", Vector2(110, -160), "posto", 26.0],
	["Fazenda Taquaral", Vector2(225, -70), "fazenda", 42.0],
	["Vale do Corvo", Vector2(-205, 5), "bairro", 42.0],
	["Bela Poeira", Vector2(25, -10), "centro", 58.0],
	["Estação Carvoeira", Vector2(175, 40), "estacao", 34.0],
	["Ruínas do Engenho", Vector2(305, 110), "ruinas", 30.0],
	["Chapada Ventania", Vector2(-320, 135), "mirante", 42.0],
	["Ponte Partida", Vector2(-100, 100), "ruinas", 26.0],
	["Colônia Caracol", Vector2(-205, 205), "vila", 36.0],
	["Mina do Tatu", Vector2(-300, 305), "pedreira", 34.0],
	["Porto Lambari", Vector2(-80, 205), "porto", 24.0],
	["Sítio Três Pinheiros", Vector2(90, 155), "fazenda", 32.0],
	["Rancho Poeira", Vector2(250, 205), "esparso", 36.0],
	["Granja Galo Doido", Vector2(120, 300), "fazenda", 34.0],
	["Vila Cachorro Magro", Vector2(295, 300), "vila", 34.0],
	["Aeródromo Carcará", Vector2(302, -15), "aerodromo", 52.0],
	["Pátio dos Galpões", Vector2(-170, 312), "galpoes", 38.0],
	["Acampamento Sentinela", Vector2(300, -298), "acampamento", 32.0],
]
# morros grandes: centro, altura, raio
const MOUNTS := [
	[Vector2(305, -170), 42.0, 75.0], [Vector2(-335, 135), 44.0, 150.0], [Vector2(235, -315), 34.0, 70.0],
	[Vector2(-60, -340), 28.0, 60.0], [Vector2(-330, -330), 30.0, 70.0], [Vector2(330, 340), 22.0, 60.0],
	[Vector2(110, 60), 14.0, 55.0], [Vector2(-160, -70), 18.0, 55.0],
	# cidades bem no alto de morro, com rampa longa e suave (troca de tiro subindo/descendo)
	[Vector2(-250, -245), 34.0, 100.0], [Vector2(-205, 205), 30.0, 85.0], [Vector2(250, 205), 32.0, 95.0],
	[Vector2(-125, -285), 24.0, 80.0], [Vector2(295, 300), 30.0, 85.0],
]
const HILL_TOWNS := ["Vila Ferrugem", "Colônia Caracol", "Rancho Poeira", "Arraial do Sapo", "Vila Cachorro Magro", "Chapada Ventania"]
# rodovias asfaltadas que cruzam o mapa (passam do lado das cidades e do posto)
const HIGHWAYS := [
	[Vector2(-380, -60), Vector2(-250, -58), Vector2(-120, -82), Vector2(0, -86), Vector2(120, -108), Vector2(230, -128), Vector2(380, -120)],
	[Vector2(105, -380), Vector2(92, -240), Vector2(74, -150), Vector2(90, -60), Vector2(104, 40), Vector2(132, 150), Vector2(160, 260), Vector2(172, 380)],
]
const LOBBY_P := Vector3(2200, 40.3, 0)
const LOBBY_HALF := 22.0
const RAIL := [Vector2(-375, 50), Vector2(-150, 45), Vector2(60, 66), Vector2(175, 40), Vector2(375, 30)]

var noise := FastNoiseLite.new()
var noise_r := FastNoiseLite.new()
var noise2 := FastNoiseLite.new()
var noise3 := FastNoiseLite.new()
var towns: Array = []      # {name, pos, h, r, kind}
var roads: Array = []      # [Vector2, Vector2]
var items: Array = []      # {pos, kind, n, door_out, door_in, up}
var houses: Array = []     # {pos, r, yaw, w, d, din, dout}
var compounds: Array = []  # cercados: {c, r, gates: [[dentro, fora], ...]}
var headless := false
var quality := 1
var map_tex: Texture2D
var _hs := PackedFloat32Array()
var _road_grid := PackedFloat32Array()
var _hw_d := PackedFloat32Array()
var _hw_h := PackedFloat32Array()
var hw_pts: Array = []
var _rl_d := PackedFloat32Array()
var _rl_h := PackedFloat32Array()
var _claims := {}
var _scatter_nodes: Array = []
var _lobby_cover: Array = []
var car_spots: Array = []   # carros dirigíveis: [posição, yaw, tipo, cor]
var b: Build
var _wts := PackedColorArray()
var edit_data: Dictionary = MapEdits.empty()   # ajustes feitos à mão (MapEdits)
var editor := false                            # montando pro editor de cenário
var nat_reg := {}                              # editor: chave -> [tipo, transformação original, nó]
var _nat_used := {}
var _nat_body: StaticBody3D
var _nat_meshes := {}


func build(is_headless: bool, q := 1) -> void:
	for st in build_steps(is_headless, q):
		(st[1] as Callable).call()


# Etapas da montagem do mapa (o jogo mostra uma barra de progresso entre elas)
func build_steps(is_headless: bool, q := 1) -> Array:
	headless = is_headless
	quality = q
	return [
		["Gerando o relevo", _step_relief],
		["Traçando rodovias e estradas", func():
			_make_highways()
			_make_roads()
			b = Build.new(self)
			b.edits = edit_data["e"]
			b.editor = editor],
		["Construindo as cidades", func():
			for i in towns.size():
				_build_loc(i)],
		["Colocando carros e objetos", func():
			# o sorteio daqui em diante não depende de como as cidades foram montadas
			# (mantém no lugar os objetos que o jogador já ajustou no editor)
			b.rng.state = 8992035089481542627
			b.vrng.state = 8532983171605503413
			_build_highway_props()
			_car_spots()
			_build_extras()
			_build_war()
			_build_added()],
		["Moldando o terreno", func():
			_wts = _build_terrain()
			_highway_floor()
			_build_floor_body()],
		["Plantando árvores", _build_nature],
		["Arrumando a área de aquecimento", func(): _build_bounds(); _build_lobby()],
		["Desenhando o mapa", func():
			if not headless:
				_build_highway_mesh()
				_build_map(_wts)
				_build_env()
				_build_smoke()],
	]


func _step_relief() -> void:
	noise.seed = SEED
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.0026
	noise.fractal_octaves = 3
	noise_r.seed = SEED + 3
	noise_r.frequency = 0.006
	noise_r.fractal_octaves = 1
	noise2.seed = SEED + 7
	noise2.frequency = 0.018
	noise3.seed = SEED + 13
	noise3.frequency = 0.09
	for t in LOCS:
		towns.append({"name": t[0], "pos": t[1], "kind": t[2], "r": t[3], "h": 0.0, "blend": 95.0 if t[0] in HILL_TOWNS else 40.0})
	for t in towns:
		t["h"] = _base(t["pos"].x, t["pos"].y)


# ---------------- relevo ----------------

# Relevo suave: morros longos entre as cidades, quase sem calombo perto um do outro.
func _base(x: float, z: float) -> float:
	var h := noise.get_noise_2d(x, z) * 26.0
	h += noise_r.get_noise_2d(x, z) * 6.0
	h += noise2.get_noise_2d(x, z) * 0.8
	for m in MOUNTS:
		var d2: float = Vector2(x, z).distance_squared_to(m[0])
		var rr: float = m[2]
		h += float(m[1]) * exp(-d2 / (rr * rr))
	var e := maxf(absf(x), absf(z))
	h += smoothstep(PLAY - 15.0, SIZE * 0.5, e) * 55.0
	# lagoa rasa (até a canela) com margem suave
	var dl := Vector2(x, z).distance_to(LAKE_C)
	if dl < LAKE_R + 40.0:
		var shore := lerpf(WATER_Y - 0.3, WATER_Y + 0.25, smoothstep(LAKE_R - 8.0, LAKE_R, dl))
		h = lerpf(shore, maxf(h, WATER_Y + 0.25), smoothstep(LAKE_R, LAKE_R + 40.0, dl))
	return h


# relevo com as áreas planas das localidades
func _pre(x: float, z: float) -> float:
	var h := _base(x, z)
	# áreas planas das localidades; onde duas rampas se cruzam, a cidade mais perto manda
	var ws := []
	for t in towns:
		var d: float = Vector2(x, z).distance_to(t["pos"])
		var r: float = t["r"]
		# cidade no alto: rampa longa e suave (dá pra trocar tiro subindo/descendo)
		var bw: float = t.get("blend", 40.0)
		if d < r + bw:
			var th: float = t["h"]
			if t["kind"] == "pedreira" and d < r * 0.8:
				th -= 6.0 * (1.0 - smoothstep(r * 0.55, r * 0.8, d))
			ws.append([1.0 - smoothstep(r, r + bw, d), th])
	# ordem fixa (da cidade mais baixa pra mais alta): o chão nunca dá degrau onde duas rampas se
	# encontram, e a rampa longa da cidade alta é que manda (subida suave)
	if ws.size() > 1:
		ws.sort_custom(func(a, b): return a[1] < b[1])
	for e in ws:
		h = lerpf(h, e[1], e[0])
	return h


func height(x: float, z: float) -> float:
	var h := _pre(x, z)
	# rodovia: pista plana acompanhando o relevo suavizado
	if not _hw_d.is_empty():
		var hd := _grid(_hw_d, x, z)
		if hd < 18.0:
			h = lerpf(_grid(_hw_h, x, z), h, smoothstep(6.0, 18.0, hd))
	# trilho: aterro/corte suave acompanhando a linha do trem
	if not _rl_d.is_empty():
		var rd := _grid(_rl_d, x, z)
		if rd < 30.0:
			h = lerpf(_grid(_rl_h, x, z), h, smoothstep(4.0, 30.0, rd))
	if not _pads.is_empty():
		h = _pad_h(x, z, h)
	return h


# ---------------- chão plano embaixo das construções ----------------
# Casa nunca fica inclinada: o terreno é que fica plano embaixo dela (e dos objetos).
# Por isso o relevo é montado depois das cidades e objetos.
const PAD_CELL := 24.0
var _pads := {}


func add_pad(c: Vector2, r: float, h: float, blend := 5.0) -> void:
	var e := [c, r, h, blend]
	var ext := r + blend
	for cx in range(floori((c.x - ext) / PAD_CELL), floori((c.x + ext) / PAD_CELL) + 1):
		for cz in range(floori((c.y - ext) / PAD_CELL), floori((c.y + ext) / PAD_CELL) + 1):
			var k := Vector2i(cx, cz)
			if not _pads.has(k):
				_pads[k] = []
			_pads[k].append(e)


func _pad_h(x: float, z: float, h: float) -> float:
	var k := Vector2i(floori(x / PAD_CELL), floori(z / PAD_CELL))
	if not _pads.has(k):
		return h
	# mistura contínua entre chãos planos vizinhos (sem degrau onde as rampas se encontram)
	var best := 0.0
	var sw := 0.0
	var sh := 0.0
	var p := Vector2(x, z)
	for e in _pads[k]:
		var d: float = p.distance_to(e[0])
		var wt := 1.0 - smoothstep(float(e[1]), float(e[1]) + float(e[3]), d)
		if wt <= 0.0:
			continue
		best = maxf(best, wt)
		var q := wt * wt * wt * wt
		sw += q
		sh += q * float(e[2])
	if best <= 0.0:
		return h
	return lerpf(h, sh / sw, best)


func town_factor(x: float, z: float) -> float:
	var f := 0.0
	for t in towns:
		var d: float = Vector2(x, z).distance_to(t["pos"])
		f = maxf(f, 1.0 - smoothstep(t["r"] - 4.0, t["r"] + 4.0, d))
	return f


func rail_dist(p: Vector2) -> float:
	var best := 9999.0
	for i in RAIL.size() - 1:
		var a: Vector2 = RAIL[i]
		var ab: Vector2 = RAIL[i + 1] - a
		var k := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * k))
	return best


func _grid(arr: PackedFloat32Array, x: float, z: float) -> float:
	var cell := SIZE / RES
	var fx := clampf((x + SIZE / 2.0) / cell, 0.0, RES - 0.001)
	var fz := clampf((z + SIZE / 2.0) / cell, 0.0, RES - 0.001)
	var i := int(fx)
	var j := int(fz)
	var tx := fx - i
	var tz := fz - j
	var n := RES + 1
	return lerpf(lerpf(arr[j * n + i], arr[j * n + i + 1], tx), lerpf(arr[(j + 1) * n + i], arr[(j + 1) * n + i + 1], tx), tz)


# ---------------- rodovias (asfalto) ----------------

static func _catmull(pts: Array, step: float) -> Array:
	var out := []
	for i in pts.size() - 1:
		var p0: Vector2 = pts[maxi(i - 1, 0)]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p3: Vector2 = pts[mini(i + 2, pts.size() - 1)]
		var n := maxi(1, int(p1.distance_to(p2) / step))
		for k in n:
			var t := float(k) / n
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(pts[-1])
	return out


func _make_highways() -> void:
	hw_pts = _line_grid(HIGHWAYS, _hw_d, _hw_h, 5)
	_line_grid([RAIL], _rl_d, _rl_h, 9)


# Faixa plana que acompanha uma linha (rodovia/trilho): perfil de altura suavizado e grade
# com a distância até a linha e a altura da pista, pra achatar o chão em volta.
func _line_grid(polys: Array, d_arr: PackedFloat32Array, h_arr: PackedFloat32Array, win: int) -> Array:
	var gn := RES + 1
	var cell := SIZE / RES
	d_arr.resize(gn * gn)
	d_arr.fill(99.0)
	h_arr.resize(gn * gn)
	h_arr.fill(0.0)
	var lines := []
	for poly in polys:
		var pts := _catmull(poly, 3.0)
		var hs := []
		for q in pts:
			hs.append(_pre(q.x, q.y))
		# suaviza o perfil (sem subida brusca)
		for it in 3:
			var nh := hs.duplicate()
			for i in hs.size():
				var acc := 0.0
				var c := 0
				for k in range(maxi(0, i - win), mini(hs.size(), i + win + 1)):
					acc += hs[k]
					c += 1
				nh[i] = acc / c
			hs = nh
		var line := []
		for i in pts.size():
			line.append([pts[i], hs[i]])
		lines.append(line)
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var c2: Vector2 = pts[i + 1]
			var lo := (Vector2(minf(a.x, c2.x), minf(a.y, c2.y)) + Vector2(SIZE, SIZE) / 2.0) / cell - Vector2(8, 8)
			var hi := (Vector2(maxf(a.x, c2.x), maxf(a.y, c2.y)) + Vector2(SIZE, SIZE) / 2.0) / cell + Vector2(8, 8)
			var ab := c2 - a
			for j in range(maxi(0, int(lo.y)), mini(gn, int(hi.y) + 1)):
				for ii in range(maxi(0, int(lo.x)), mini(gn, int(hi.x) + 1)):
					var p := Vector2(-SIZE / 2.0 + ii * cell, -SIZE / 2.0 + j * cell)
					var k := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
					var d := p.distance_to(a + ab * k)
					if d < d_arr[j * gn + ii]:
						d_arr[j * gn + ii] = d
						h_arr[j * gn + ii] = lerpf(hs[i], hs[i + 1], k)
	return lines


func hw_dist(x: float, z: float) -> float:
	return _grid(_hw_d, x, z)


# pista de asfalto com faixas, seguindo o chão
# pista da rodovia sólida (mesma superfície que o desenho dela)
func _highway_floor() -> void:
	var half := 4.2
	for line in hw_pts:
		for i in line.size() - 1:
			var p0: Vector2 = line[i][0]
			var p1: Vector2 = line[i + 1][0]
			var sd := Vector2(-(p1 - p0).normalized().y, (p1 - p0).normalized().x)
			var y0 := height(p0.x, p0.y) + 0.07
			var y1 := height(p1.x, p1.y) + 0.07
			var a0 := p0 + sd * half
			var b0 := p0 - sd * half
			var a1 := p1 + sd * half
			var b1 := p1 - sd * half
			floor_faces.append_array(PackedVector3Array([Vector3(a0.x, y0, a0.y), Vector3(a1.x, y1, a1.y), Vector3(b1.x, y1, b1.y), Vector3(a0.x, y0, a0.y), Vector3(b1.x, y1, b1.y), Vector3(b0.x, y0, b0.y)]))


func _build_highway_mesh() -> void:
	var half := 4.2
	for line in hw_pts:
		var m := MB.new()
		var chunk := 0
		for i in line.size() - 1:
			var p0: Vector2 = line[i][0]
			var p1: Vector2 = line[i + 1][0]
			var d := (p1 - p0).normalized()
			var sd := Vector2(-d.y, d.x)
			var y0 := height(p0.x, p0.y) + 0.07
			var y1 := height(p1.x, p1.y) + 0.07
			var a0 := p0 + sd * half
			var b0 := p0 - sd * half
			var a1 := p1 + sd * half
			var b1 := p1 - sd * half
			m.tex(U.ASPHALT, 0.22)
			m.quad(Vector3(a0.x, y0, a0.y), Vector3(a1.x, y1, a1.y), Vector3(b1.x, y1, b1.y), Vector3(b0.x, y0, b0.y), Color(1, 1, 1), Vector3.UP)
			# acostamento descendo até o chão (a pista nunca aparece flutuando)
			for e in [[a0, a1, sd], [b0, b1, -sd]]:
				var e0: Vector2 = e[0]
				var e1: Vector2 = e[1]
				var nn: Vector2 = e[2]
				var g0 := height(e0.x + nn.x * 0.8, e0.y + nn.y * 0.8) - 0.4
				var g1 := height(e1.x + nn.x * 0.8, e1.y + nn.y * 0.8) - 0.4
				m.quad(Vector3(e0.x, y0, e0.y), Vector3(e1.x, y1, e1.y), Vector3(e1.x + nn.x * 0.8, g1, e1.y + nn.y * 0.8), Vector3(e0.x + nn.x * 0.8, g0, e0.y + nn.y * 0.8), Color(0.85, 0.82, 0.75), Vector3(nn.x, 1.0, nn.y).normalized())
			# faixa branca nas bordas e amarela tracejada no meio
			m.tex(U.PLAIN, 1.0)
			for sgn in [-1.0, 1.0]:
				var e0: Vector2 = p0 + sd * sgn * (half - 0.35)
				var e1: Vector2 = p1 + sd * sgn * (half - 0.35)
				var w0: Vector2 = sd * 0.08
				m.quad(Vector3(e0.x + w0.x, y0 + 0.01, e0.y + w0.y), Vector3(e1.x + w0.x, y1 + 0.01, e1.y + w0.y), Vector3(e1.x - w0.x, y1 + 0.01, e1.y - w0.y), Vector3(e0.x - w0.x, y0 + 0.01, e0.y - w0.y), Color(0.92, 0.92, 0.9), Vector3.UP)
			if i % 2 == 0:
				var w1 := sd * 0.08
				m.quad(Vector3(p0.x + w1.x, y0 + 0.01, p0.y + w1.y), Vector3(p1.x + w1.x, y1 + 0.01, p1.y + w1.y), Vector3(p1.x - w1.x, y1 + 0.01, p1.y - w1.y), Vector3(p0.x - w1.x, y0 + 0.01, p0.y - w1.y), Color(0.95, 0.8, 0.25), Vector3.UP)
			chunk += 1
			if chunk >= 20 or i == line.size() - 2:
				var mi := MeshInstance3D.new()
				mi.mesh = m.commit()
				mi.material_override = U.wmat()
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mi.visibility_range_end = 420.0
				add_child(mi)
				m = MB.new()
				chunk = 0


# postes com fio, placas e carros na beira da rodovia
func _build_highway_props() -> void:
	b.begin(SEED + 601)
	var rng := b.rng
	for line in hw_pts:
		var last := Vector3.ZERO
		for i in range(3, line.size() - 3, 7):
			var p: Vector2 = line[i][0]
			var q: Vector2 = line[i + 1][0]
			var d := (q - p).normalized()
			var sd := Vector2(-d.y, d.x)
			var pp := p + sd * 7.5
			if _near_town(pp, 0.0) or not is_free(pp, 1.0):
				last = Vector3.ZERO
				continue
			var y := height(pp.x, pp.y) - 0.2
			b.pole(Vector3(pp.x, y, pp.y), -atan2(d.y, d.x))
			var top := Vector3(pp.x, y + 7.3, pp.y)
			if last != Vector3.ZERO and not headless:
				for o: float in [-0.7, 0.7]:
					var off: Vector3 = Vector3(d.x, 0, d.y).cross(Vector3.UP).normalized() * o
					var a3: Vector3 = last + off
					var b3: Vector3 = top + off
					var mid := (a3 + b3) / 2.0 - Vector3(0, 0.5, 0)
					for seg in [[a3, mid], [mid, b3]]:
						var v: Vector3 = seg[1] - seg[0]
						b.mb.tex(U.PLAIN, 1.0)
						b.mb.box(Transform3D(Basis.looking_at(v.normalized(), Vector3.UP), (seg[0] + seg[1]) / 2.0), Vector3(0.03, 0.03, v.length()), Color(0.12, 0.12, 0.12))
			last = top
			if rng.randf() < 0.08:
				var cp := p - sd * rng.randf_range(6.5, 9.0)
				if is_free(cp, 3.0) and not _near_town(cp, 0.0):
					b.car(Vector3(cp.x, height(cp.x, cp.y), cp.y), atan2(-d.x, -d.y) + rng.randf_range(-0.4, 0.4))
	b.finish(450.0)


# lugares dos carros que dá pra dirigir: na beira da estrada, perto das cidades
func _car_spots() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 909
	var order := range(towns.size())
	for k in order.size():
		var j := rng.randi_range(k, order.size() - 1)
		var tmp = order[k]
		order[k] = order[j]
		order[j] = tmp
	for ti in order:
		if car_spots.size() >= 16:
			break
		var t: Dictionary = towns[ti]
		for tries in 12:
			var a := rng.randf() * TAU
			var p: Vector2 = t["pos"] + Vector2(cos(a), sin(a)) * (float(t["r"]) + rng.randf_range(4.0, 14.0))
			if absf(p.x) > PLAY - 20.0 or absf(p.y) > PLAY - 20.0 or not is_free(p, 4.0) or _slope(p) > 0.12:
				continue
			if height(p.x, p.y) < WATER_Y + 0.8 or road_dist(p.x, p.y) > 12.0 and hw_dist(p.x, p.y) > 14.0:
				continue
			claim(p, 4.0)
			var kind := car_spots.size() % 2
			var tint: Color = Build.CAR_TINTS[rng.randi() % Build.CAR_TINTS.size()]
			car_spots.append([Vector3(p.x, height(p.x, p.y), p.y), rng.randf() * TAU, kind, tint])
			break


# ---------------- estradas de terra ----------------

func _make_roads() -> void:
	# árvore geradora mínima entre as localidades + ligação de cada uma com a rodovia mais perto
	var n := towns.size()
	var in_tree := [0]
	var edges := []
	while in_tree.size() < n:
		var best := []
		var bd := 1e9
		for i in in_tree:
			for j in n:
				if j in in_tree:
					continue
				var d: float = Vector2(towns[i]["pos"]).distance_to(towns[j]["pos"])
				if d < bd:
					bd = d
					best = [i, j]
		edges.append(best)
		in_tree.append(best[1])
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 77
	var segs := []
	for e in edges:
		segs.append([towns[e[0]]["pos"], towns[e[1]]["pos"]])
	for t in towns:
		var c: Vector2 = t["pos"]
		var best_p := Vector2.ZERO
		var bd := 1e9
		for line in hw_pts:
			for e in line:
				var d: float = c.distance_to(e[0])
				if d < bd:
					bd = d
					best_p = e[0]
		if bd < 170.0 and bd > float(t["r"]) + 6.0:
			segs.append([c, best_p])
	for sg in segs:
		var a: Vector2 = sg[0]
		var c: Vector2 = sg[1]
		var dir := (c - a).normalized()
		var side := Vector2(-dir.y, dir.x)
		var m1 := a.lerp(c, 0.35) + side * rng.randf_range(-14, 14)
		var m2 := a.lerp(c, 0.7) + side * rng.randf_range(-14, 14)
		var pts := _catmull([a, m1, m2, c], 8.0)
		for i in pts.size() - 1:
			roads.append([pts[i], pts[i + 1]])
	# grade com distância até a estrada mais próxima (rápido de consultar)
	var gn := RES + 1
	var cell := SIZE / RES
	_road_grid.resize(gn * gn)
	_road_grid.fill(99.0)
	for r in roads:
		var a: Vector2 = r[0]
		var c: Vector2 = r[1]
		var lo := (Vector2(minf(a.x, c.x), minf(a.y, c.y)) + Vector2(SIZE, SIZE) / 2.0) / cell - Vector2(3, 3)
		var hi := (Vector2(maxf(a.x, c.x), maxf(a.y, c.y)) + Vector2(SIZE, SIZE) / 2.0) / cell + Vector2(3, 3)
		for j in range(maxi(0, int(lo.y)), mini(gn, int(hi.y) + 1)):
			for i in range(maxi(0, int(lo.x)), mini(gn, int(hi.x) + 1)):
				var p := Vector2(-SIZE / 2.0 + i * cell, -SIZE / 2.0 + j * cell)
				var ab := c - a
				var k := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
				var d := p.distance_to(a + ab * k)
				if d < _road_grid[j * gn + i]:
					_road_grid[j * gn + i] = d


func road_dist(x: float, z: float) -> float:
	return _grid(_road_grid, x, z)


# ---------------- terreno ----------------

# pesos do chão: r = terra, g = pedra, b = areia, a = tom
func ground_w(x: float, z: float, ny: float, h: float) -> Color:
	var tone := clampf(noise2.get_noise_2d(x, z) * 0.6 + 0.5 + noise3.get_noise_2d(x, z) * 0.2, 0.0, 1.0)
	var dirt := 0.0
	var rock := 0.0
	var sand := 0.0
	var rd := road_dist(x, z)
	dirt = maxf(dirt, (1.0 - smoothstep(2.0, 5.5, rd)) * 0.95)
	dirt = maxf(dirt, clampf(noise3.get_noise_2d(x * 0.5, z * 0.5) * 2.0 - 1.0, 0.0, 0.5))
	var tf := 0.0
	for t in towns:
		var d: float = Vector2(x, z).distance_to(t["pos"])
		var f := 1.0 - smoothstep(float(t["r"]) - 6.0, float(t["r"]) + 6.0, d)
		if f <= 0.0:
			continue
		tf = maxf(tf, f)
		match t["kind"]:
			"pedreira":
				rock = maxf(rock, f * 0.75)
				sand = maxf(sand, f * 0.2)
			"base":
				sand = maxf(sand, f * 0.55)
			"fazenda":
				dirt = maxf(dirt, f * 0.35)
	dirt = maxf(dirt, tf * 0.55)
	if ny < 0.86:
		rock = maxf(rock, clampf((0.86 - ny) * 5.0, 0.0, 1.0))
	if h > 38.0:
		rock = maxf(rock, clampf((h - 38.0) / 25.0, 0.0, 0.65))
	var dl := Vector2(x, z).distance_to(LAKE_C)
	if dl < LAKE_R + 25.0 and h < WATER_Y + 2.0:
		sand = maxf(sand, 1.0 - smoothstep(WATER_Y + 0.5, WATER_Y + 2.0, h))
	if rail_dist(Vector2(x, z)) < 4.0:
		sand = maxf(sand, 0.8)
	var tot := dirt + rock + sand
	if tot > 1.0:
		dirt /= tot
		rock /= tot
		sand /= tot
	return Color(dirt, rock, sand, tone)


func _build_terrain() -> PackedColorArray:
	var cell := SIZE / RES
	var n := RES + 1
	_hs.resize(n * n)
	for j in n:
		for i in n:
			_hs[j * n + i] = height(-SIZE / 2.0 + i * cell, -SIZE / 2.0 + j * cell)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for j in n:
		for i in n:
			var x := -SIZE / 2.0 + i * cell
			var z := -SIZE / 2.0 + j * cell
			var hh := _hs[j * n + i]
			verts.append(Vector3(x, hh, z))
			var hl := _hs[j * n + maxi(i - 1, 0)]
			var hr := _hs[j * n + mini(i + 1, n - 1)]
			var hd := _hs[maxi(j - 1, 0) * n + i]
			var hu := _hs[mini(j + 1, n - 1) * n + i]
			var nm := Vector3(hl - hr, 2.0 * cell, hd - hu).normalized()
			norms.append(nm)
			if headless:
				cols.append(Color.WHITE)
			else:
				cols.append(ground_w(x, z, nm.y, hh))
	for j in RES:
		for i in RES:
			var a := j * n + i
			var b2 := a + 1
			var c2 := a + n
			var d := c2 + 1
			idx.append_array(PackedInt32Array([a, b2, c2, b2, d, c2]))
	if not headless:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_NORMAL] = norms
		arr[Mesh.ARRAY_COLOR] = cols
		arr[Mesh.ARRAY_INDEX] = idx
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = U.tmat()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	var faces := PackedVector3Array()
	faces.resize(idx.size())
	for k in idx.size():
		faces[k] = verts[idx[k]]
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var body := StaticBody3D.new()
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	add_child(body)
	terrain_body = body
	return cols


# altura aproximada pela grade (rápida, pra grama)
func grid_h(x: float, z: float) -> float:
	var cell := SIZE / RES
	var fx := clampf((x + SIZE / 2.0) / cell, 0.0, RES - 0.001)
	var fz := clampf((z + SIZE / 2.0) / cell, 0.0, RES - 0.001)
	var i := int(fx)
	var j := int(fz)
	var tx := fx - i
	var tz := fz - j
	var n := RES + 1
	return lerpf(lerpf(_hs[j * n + i], _hs[j * n + i + 1], tx), lerpf(_hs[(j + 1) * n + i], _hs[(j + 1) * n + i + 1], tx), tz)


# ---------------- ocupação (pra árvore não nascer dentro de casa) ----------------

func claim(p: Vector2, r: float) -> void:
	var c := Vector2i(floori(p.x / 16.0), floori(p.y / 16.0))
	if not _claims.has(c):
		_claims[c] = []
	_claims[c].append([p, r])


func is_free(p: Vector2, r: float) -> bool:
	var c := Vector2i(floori(p.x / 16.0), floori(p.y / 16.0))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var k := c + Vector2i(dx, dz)
			if not _claims.has(k):
				continue
			for e in _claims[k]:
				if p.distance_to(e[0]) < float(e[1]) + r:
					return false
	return true


func add_item(pos: Vector3, kind: String, dout, din, up := false) -> void:
	items.append({"pos": pos, "kind": kind, "n": Weapons.default_count(kind), "door_out": dout, "door_in": din, "up": up})
	# arma sempre vem com uma caixa de munição do lado
	if Weapons.is_gun(kind):
		var am := Weapons.ammo_of(kind)
		var off := Vector3(0.45, 0, 0.3)
		items.append({"pos": pos + off, "kind": am, "n": Weapons.default_count(am), "door_out": dout, "door_in": din, "up": up})


func loot_kind(rng: RandomNumberGenerator, gun: bool) -> String:
	if gun:
		return Weapons.LOOT_GUNS[rng.randi() % Weapons.LOOT_GUNS.size()]
	return Weapons.LOOT[rng.randi() % Weapons.LOOT.size()]


# ---------------- localidades ----------------

func _house_spec(rng: RandomNumberGenerator, big := false) -> Dictionary:
	var sp := _house_spec0(rng, big)
	# cenário de começo de guerra: parte das casas está danificada
	if rng.randf() < 0.3 and not sp.get("ext_stairs", false):
		sp["damaged"] = true
	return sp


func _house_spec0(rng: RandomNumberGenerator, big := false) -> Dictionary:
	var r := rng.randf()
	var styles := ["plaster", "plaster", "plaster", "brick", "wood"]
	if not _theme_styles.is_empty():
		styles = _theme_styles
	var st: String = styles[rng.randi() % styles.size()]
	if r > 0.8:
		# casa de laje com escada por fora pra subir no teto
		return {"w": rng.randf_range(8.0, 9.5), "d": rng.randf_range(7.0, 8.0), "style": "plaster" if st == "wood" else st,
			"roof": "flat", "ext_stairs": true}
	if r < (0.15 if big else 0.07):
		return {"w": rng.randf_range(8.5, 10.5), "d": rng.randf_range(8.0, 9.0), "floors": 2, "style": "plaster" if st == "wood" else st,
			"roof": "tile" if rng.randf() < 0.75 else "flat", "balcony": rng.randf() < 0.7}
	if r < 0.45:
		return {"w": rng.randf_range(10.0, 12.0), "d": rng.randf_range(7.5, 8.5), "rooms": 2, "style": st, "porch": rng.randf() < 0.4}
	return {"w": rng.randf_range(7.0, 9.0), "d": rng.randf_range(6.0, 7.5), "style": st, "porch": rng.randf() < 0.35}


# Cada cidade com a sua cara (cores das paredes, telhado, estilo e um marco no centro),
# pra dar pra saber onde está só de olhar.
const THEMES := {
	"Vila Ferrugem": {"tints": [Color(0.86, 0.55, 0.38), Color(0.78, 0.48, 0.32), Color(0.9, 0.68, 0.5)], "roof": Color(0.55, 0.32, 0.22), "styles": ["plaster", "plaster", "metal"], "mark": "tank"},
	"Arraial do Sapo": {"tints": [Color(0.7, 0.85, 0.62), Color(0.62, 0.78, 0.55), Color(0.82, 0.9, 0.72)], "roof": Color(0.4, 0.45, 0.3), "styles": ["plaster", "wood", "wood"], "mark": "windmill"},
	"Brejo Seco": {"tints": [Color(0.86, 0.78, 0.58), Color(0.8, 0.7, 0.5), Color(0.9, 0.84, 0.66)], "roof": Color(0.6, 0.5, 0.36), "styles": ["plaster", "wood", "brick"], "mark": "bus"},
	"Pouso Velho": {"tints": [Color(0.97, 0.97, 0.95), Color(0.92, 0.94, 0.98), Color(0.95, 0.95, 0.92)], "roof": Color(0.36, 0.42, 0.62), "styles": ["plaster", "plaster", "plaster"], "mark": ""},
	"Vale do Corvo": {"tints": [Color(0.55, 0.55, 0.58), Color(0.48, 0.48, 0.5), Color(0.62, 0.6, 0.6)], "roof": Color(0.25, 0.25, 0.28), "styles": ["brick", "brick", "plaster"], "mark": "monument"},
	"Bela Poeira": {"tints": [Color(0.96, 0.8, 0.62), Color(0.94, 0.72, 0.58), Color(0.98, 0.88, 0.7)], "roof": Color(0.85, 0.42, 0.3), "styles": ["plaster", "plaster", "brick"], "mark": "monument"},
	"Chapada Ventania": {"tints": [Color(0.7, 0.82, 0.92), Color(0.62, 0.75, 0.88), Color(0.82, 0.9, 0.96)], "roof": Color(0.3, 0.38, 0.5), "styles": ["plaster", "plaster", "wood"], "mark": "windmill"},
	"Colônia Caracol": {"tints": [Color(0.9, 0.72, 0.8), Color(0.82, 0.7, 0.88), Color(0.95, 0.82, 0.86)], "roof": Color(0.55, 0.3, 0.4), "styles": ["plaster", "plaster", "brick"], "mark": "monument"},
	"Rancho Poeira": {"tints": [Color(0.75, 0.58, 0.42), Color(0.68, 0.52, 0.38), Color(0.8, 0.66, 0.5)], "roof": Color(0.42, 0.3, 0.22), "styles": ["wood", "wood", "plaster"], "mark": "tank"},
	"Vila Cachorro Magro": {"tints": [Color(0.98, 0.88, 0.45), Color(0.95, 0.8, 0.4), Color(0.98, 0.92, 0.6)], "roof": Color(0.7, 0.35, 0.2), "styles": ["plaster", "plaster", "wood"], "mark": "bus"},
}


func _build_loc(ti: int) -> void:
	var t: Dictionary = towns[ti]
	b.begin(SEED + ti * 31)
	var th: Dictionary = THEMES.get(t["name"], {})
	b.theme_tints = th.get("tints", [])
	b.theme_roof = th.get("roof", Color(1, 1, 1))
	_theme_styles = th.get("styles", [])
	var c: Vector2 = t["pos"]
	var y: float = t["h"]
	var r: float = t["r"]
	match t["kind"]:
		"vila":
			_vila(c, y, r, false)
		"igreja":
			_vila(c, y, r, true)
		"bairro":
			if t["name"] == "Vale do Corvo":
				_plaza(c, y, r)
			_bairro(c, y, r, false)
		"centro":
			_plaza(c, y, r)
			_bairro(c, y, r, true)
		"esparso":
			_esparso(c, y, r)
		"fazenda":
			_fazenda(c, y, r)
		"base":
			_base_mil(c, y, r)
		"posto":
			_posto(c, y, r)
		"pedreira":
			_pedreira(c, y, r)
		"serraria":
			_serraria(c, y, r)
		"ruinas":
			_ruinas(c, y, r)
		"torre":
			_torre(c, y, r)
		"estacao":
			_estacao(c, y, r)
		"porto":
			_porto(c, y, r)
		"aerodromo":
			_aerodromo(c, y, r)
		"galpoes":
			_galpoes(c, y, r)
		"acampamento":
			_acampamento(c, y, r)
		"palafitas":
			_palafitas(c, y, r)
		"mirante":
			_mirante(c, y, r)
	# localidade pequena com pouca casa: completa (cidade grande ganha algumas a mais também)
	var extra: int = {"mirante": 3, "palafitas": 1, "posto": 3, "serraria": 3, "fazenda": 2, "estacao": 3, "porto": 3, "esparso": 2, "vila": 2, "igreja": 2, "bairro": 2, "centro": 3}.get(t["kind"], 0)
	if extra > 0:
		_more_houses(c, y, r, extra)
	if t["kind"] in ["vila", "igreja", "bairro", "centro", "esparso", "mirante", "palafitas"]:
		_war_props(c, y, r)
	if t["name"] in HILL_TOWNS:
		_slope_cover(c, y, r)
	var mark: String = th.get("mark", "")
	if mark != "":
		_landmark(mark, c, y)
	b.theme_tints = []
	b.theme_roof = Color(1, 1, 1)
	_theme_styles = []
	b.finish()


var _theme_styles: Array = []


# marco no centro da cidade (procura um lugar livre perto do meio)
func _landmark(kind: String, c: Vector2, y: float) -> void:
	for k in 12:
		var p := c + Vector2(cos(k * 2.4), sin(k * 2.4)) * (k * 1.6)
		if is_free(p, 5.5 if kind == "bus" else 3.5):
			match kind:
				"monument":
					b.monument(_p3(p, y), b.rng.randf() * TAU)
				"windmill":
					b.windmill(_p3(p, y), b.rng.randf() * TAU)
				"bus":
					b.bus(_p3(p, y), b.rng.randf() * TAU)
				"tank":
					b.water_tower(_p3(p, y))
			return


# começo de guerra: barricadas de madeira, caixotes com arma e sacos de areia pela cidade
func _war_props(c: Vector2, y: float, r: float) -> void:
	var rng := b.rng
	var placed := 0
	var tries := 0
	while placed < 4 + int(r > 45.0) * 2 and tries < 40:
		tries += 1
		var a := rng.randf() * TAU
		var p := c + Vector2(cos(a), sin(a)) * r * rng.randf_range(0.15, 0.95)
		if not is_free(p, 2.2):
			continue
		placed += 1
		var k := rng.randf()
		if k < 0.45:
			b.barricade(_p3(p, y), _face(p, c) + PI / 2.0 + rng.randf_range(-0.3, 0.3))
		elif k < 0.75:
			b.gun_crate(_p3(p, y), rng.randf() * TAU)
		else:
			b.sandbags(_p3(p, y), _face(p, c) + PI / 2.0, rng.randf_range(2.5, 4.0))
	# itens soltos na rua
	for k in 3 + int(r / 15.0):
		var p := c + Vector2(rng.randf_range(-r * 0.8, r * 0.8), rng.randf_range(-r * 0.8, r * 0.8))
		if is_free(p, 0.8):
			add_item(_p3(p, y + 0.07), loot_kind(rng, rng.randf() < 0.3), null, null)


# coberturas na rampa das cidades altas: pedras, sacos de areia, barricadas, caixotes e carcaças
func _slope_cover(c: Vector2, y: float, r: float) -> void:
	var rng := b.rng
	var placed := 0
	var tries := 0
	while placed < 38 and tries < 380:
		tries += 1
		var a := rng.randf() * TAU
		var p := c + Vector2(cos(a), sin(a)) * rng.randf_range(r + 4.0, r + 80.0)
		if not is_free(p, 2.5) or road_dist(p.x, p.y) < 4.0 or hw_dist(p.x, p.y) < 8.0 or height(p.x, p.y) < WATER_Y + 1.0:
			continue
		# não invade outra localidade (ela ainda pode não ter sido montada)
		if town_factor(p.x, p.y) > 0.0:
			continue
		placed += 1
		var yaw := _face(p, c) + PI / 2.0 + rng.randf_range(-0.4, 0.4)
		var k := rng.randf()
		if k < 0.3:
			_rock(p, rng.randf_range(2.2, 3.8), rng)
		elif k < 0.5:
			b.sandbags(_p3(p, low_h(p, 1.8) - 0.05), yaw, rng.randf_range(2.5, 4.0))
		elif k < 0.68:
			b.barricade(_p3(p, low_h(p, 1.6) - 0.05), yaw)
		elif k < 0.8:
			b.crates(_p3(p, low_h(p, 1.4) - 0.05), yaw)
		elif k < 0.9:
			b.car(_p3(p, low_h(p, 2.0)), yaw)
		else:
			b.gun_crate(_p3(p, low_h(p, 1.0) - 0.05), yaw)


# menor altura do chão sob um objeto (não fica flutuando em barranco)
func low_h(p: Vector2, r: float) -> float:
	var h := height(p.x, p.y)
	for k in 8:
		var o := Vector2(r, 0).rotated(k * TAU / 8.0)
		h = minf(h, height(p.x + o.x, p.y + o.y))
	return h


func _p3(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, p.y)


func _face(from: Vector2, to: Vector2) -> float:
	var d := (to - from).normalized()
	return atan2(-d.x, -d.y)


# mais casas em volta do centro (sem encostar em nada: confere o espaço livre antes)
func _more_houses(c: Vector2, y: float, r: float, n: int, d0 := 0.55, d1 := 0.92, on_ground := false) -> void:
	var rng := b.rng
	var made := 0
	for t in n * 6:
		if made >= n:
			return
		var a := rng.randf() * TAU
		var p := c + Vector2(cos(a), sin(a)) * r * rng.randf_range(d0, d1)
		var spec := _house_spec(rng)
		if not is_free(p, maxf(spec["w"], spec["d"]) * 0.55) or road_dist(p.x, p.y) < 5.0 or hw_dist(p.x, p.y) < 9.0 or rail_dist(p) < 7.0:
			continue
		var hy := height(p.x, p.y) - 0.1 if on_ground else y
		b.house(_p3(p, hy), _face(p, c) + rng.randf_range(-0.3, 0.3), spec)
		made += 1


func _vila(c: Vector2, y: float, r: float, church: bool) -> void:
	var rng := b.rng
	var n := rng.randi_range(8, 11)
	var a0 := rng.randf() * TAU
	if church:
		b.church(_p3(c, y), rng.randf() * TAU)
	else:
		b.well(_p3(c + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3)), y))
	for k in n:
		var ang := a0 + TAU * k / n + rng.randf_range(-0.3, 0.3)
		# duas voltas de casas (por dentro e por fora), sem encostar uma na outra
		var dist := r * (rng.randf_range(0.42, 0.58) if k % 2 == 0 else rng.randf_range(0.72, 0.92))
		var p := c + Vector2(cos(ang), sin(ang)) * dist
		var yaw := _face(p, c) + rng.randf_range(-0.45, 0.45)
		if not is_free(p, 4.5):
			continue
		if rng.randf() < 0.15:
			b.shack(_p3(p, y), yaw)
		else:
			var spec := _house_spec(rng)
			b.house(_p3(p, y), yaw, spec)
			if rng.randf() < 0.35:
				_yard(p, yaw, spec, y)
	for k in rng.randi_range(1, 3):
		var p := c + Vector2(rng.randf_range(-r * 0.35, r * 0.35), rng.randf_range(-r * 0.35, r * 0.35))
		if is_free(p, 3.0):
			b.car(_p3(p, y), rng.randf() * TAU)
	for k in 2:
		var p := c + Vector2(rng.randf_range(-r * 0.3, r * 0.3), rng.randf_range(-r * 0.3, r * 0.3))
		if is_free(p, 2.0):
			b.crates(_p3(p, y), rng.randf() * TAU)


# muro ou cerca em volta do quintal
func _yard(p: Vector2, yaw: float, spec: Dictionary, y: float) -> void:
	var hw: float = spec["w"] / 2.0 + 2.5
	var hd: float = spec["d"] / 2.0 + 2.5
	var bs := Basis(Vector3.UP, yaw)
	var pts := []
	for q in [Vector3(-hw, 0, -hd), Vector3(hw, 0, -hd), Vector3(hw, 0, hd), Vector3(-hw, 0, hd)]:
		var v: Vector3 = bs * q
		pts.append(p + Vector2(v.x, v.z))
	if b.rng.randf() < 0.5:
		# muro baixo com portão na frente
		var fa: Vector2 = pts[0]
		var fb: Vector2 = pts[1]
		b.low_wall(fa, fa.lerp(fb, 0.35), y)
		b.low_wall(fa.lerp(fb, 0.65), fb, y)
		b.low_wall(pts[1], pts[2], y)
		b.low_wall(pts[3], pts[0], y)
	else:
		b.fence_ring(pts, [0, 2])


# rua em pedaços que acompanham o chão (com "saia" pra baixo: nunca fica flutuando)
# caixa sólida do chão (asfalto, calçada, cimento): entra na colisão única do piso
func floor_box(xf: Transform3D, size: Vector3) -> void:
	var h := size / 2.0
	var c := []
	for k in 8:
		c.append(xf * Vector3(h.x * (1 if k & 1 else -1), h.y * (1 if k & 2 else -1), h.z * (1 if k & 4 else -1)))
	# topo + 4 lados (a base fica enterrada)
	for q in [[2, 3, 7, 6], [0, 1, 3, 2], [4, 6, 7, 5], [0, 2, 6, 4], [1, 5, 7, 3]]:
		floor_faces.append_array(PackedVector3Array([c[q[0]], c[q[1]], c[q[2]], c[q[0]], c[q[2]], c[q[3]]]))


func _build_floor_body() -> void:
	if floor_faces.is_empty():
		return
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(floor_faces)
	shape.backface_collision = true
	floor_body = StaticBody3D.new()
	floor_body.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = shape
	floor_body.add_child(cs)
	add_child(floor_body)
	floor_faces = PackedVector3Array()


func _street(a: Vector2, c: Vector2, y: float, width := 6.0) -> void:
	map_streets.append([a, c, width])
	var d := c - a
	var yaw := -atan2(d.y, d.x)
	var bs := Basis(Vector3.UP, yaw)
	var side := Vector2(-d.normalized().y, d.normalized().x)
	var n := maxi(1, int(d.length() / 4.0))
	var seg := d.length() / n
	for i in n:
		var q := a + d * ((i + 0.5) / n)
		var gy := minf(y, low_h(q, width * 0.5))
		# dentro da cidade fica no nível dela; fora, segue o chão
		var ty := y if town_factor(q.x, q.y) > 0.9 else height(q.x, q.y)
		var top := ty + 0.04
		var dep := top - gy + 0.3
		var sx := Transform3D(bs, Vector3(q.x, top - dep / 2.0, q.y))
		floor_box(sx, Vector3(seg + 0.05, dep, width))
		var walks := []
		for sgn in [-1.0, 1.0]:
			var w: Vector2 = q + side * sgn * (width / 2.0 + 0.8)
			var wy := ty if town_factor(w.x, w.y) > 0.9 else maxf(ty, height(w.x, w.y))
			var wd := wy + 0.12 - gy + 0.3
			var wx := Transform3D(bs, Vector3(w.x, wy + 0.12 - wd / 2.0, w.y))
			floor_box(wx, Vector3(seg + 0.05, wd, 1.6))
			walks.append([wx, wd])
		if headless:
			continue
		b.mb.tex(U.ASPHALT, 0.25)
		b.mb.box(sx, Vector3(seg + 0.05, dep, width), Color(1, 1, 1))
		for wk in walks:
			b.mb.tex(U.CONCRETE, 0.4)
			b.mb.box(wk[0], Vector3(seg + 0.05, wk[1], 1.6), Color(0.8, 0.78, 0.73))
		# faixa (apagada em alguns trechos)
		if i % 2 == 0 and b.rng.randf() < 0.75:
			b.mb.tex(U.PLAIN, 1.0)
			b.mb.box(Transform3D(bs, Vector3(q.x, top + 0.005, q.y)), Vector3(2.0, 0.01, 0.14), Color(0.78, 0.74, 0.5))
		# rua destruída: buracos, rachaduras, manchas de queimado e entulho
		var rr := b.vrng.randf()
		if rr < 0.22:
			var o := side * b.vrng.randf_range(-width * 0.3, width * 0.3) + d.normalized() * b.vrng.randf_range(-1.2, 1.2)
			var hp := q + o
			var hs := b.vrng.randf_range(0.9, 1.8)
			b.mb.tex(U.DIRT, 0.5)
			b.mb.cyl(Transform3D(Basis(Vector3.UP, b.vrng.randf() * TAU), Vector3(hp.x, top - 0.005, hp.y)), hs, hs * 0.9, 0.02, 9, Color(0.45, 0.38, 0.3), true, false, null, 0.25, b.vrng)
			b.mb.tex(U.PLAIN, 1.0)
			b.mb.cyl(Transform3D(Basis(), Vector3(hp.x, top + 0.008, hp.y)), hs * 0.6, hs * 0.55, 0.01, 8, Color(0.08, 0.07, 0.06), true, false, null, 0.3, b.vrng)
			b.rubble(Vector3(hp.x, top, hp.y), hs * 1.1, 5, Color(0.42, 0.42, 0.42))
		elif rr < 0.4:
			b.mb.tex(U.PLAIN, 1.0)
			for ci in 3:
				var cp := q + side * b.vrng.randf_range(-width * 0.4, width * 0.4) + d.normalized() * b.vrng.randf_range(-1.5, 1.5)
				b.mb.box(Transform3D(Basis(Vector3.UP, b.vrng.randf() * TAU), Vector3(cp.x, top + 0.006, cp.y)), Vector3(b.vrng.randf_range(0.6, 1.6), 0.01, 0.05), Color(0.1, 0.1, 0.1))
		elif rr < 0.5:
			var bp := q + side * b.vrng.randf_range(-width * 0.3, width * 0.3)
			b.mb.tex(U.PLAIN, 1.0)
			b.mb.cyl(Transform3D(Basis(), Vector3(bp.x, top + 0.007, bp.y)), b.vrng.randf_range(1.0, 2.0), 0.9, 0.01, 10, Color(0.13, 0.12, 0.11), true, false, null, 0.35, b.vrng)


# curva suave (Bézier) entre a e c passando perto de m, em n pedaços
func _curve(a: Vector2, m: Vector2, c: Vector2, n: int) -> Array:
	var pts := []
	for k in n + 1:
		var t := float(k) / n
		pts.append(a.lerp(m, t).lerp(m.lerp(c, t), t))
	return pts


# ponto e direção a uma distância ao longo do caminho
func _along(pts: Array, d: float) -> Array:
	for k in pts.size() - 1:
		var a: Vector2 = pts[k]
		var e: Vector2 = pts[k + 1]
		var l := a.distance_to(e)
		if d <= l or k == pts.size() - 2:
			return [a.lerp(e, clampf(d / maxf(l, 0.001), 0.0, 1.0)), (e - a).normalized()]
		d -= l
	return [pts[0], Vector2.RIGHT]


# rua curva: pedaços retos curtos que se sobrepõem um pouco nas emendas
func _street_path(pts: Array, y: float) -> void:
	for k in pts.size() - 1:
		var a: Vector2 = pts[k]
		var e: Vector2 = pts[k + 1]
		var d := (e - a).normalized()
		_street(a - d * 0.8, e + d * 0.8, y)
		# reserva o espaço da rua pra nenhuma casa cair em cima
		var l := a.distance_to(e)
		for i in int(l / 3.0) + 1:
			claim(a + d * minf(i * 3.0, l), 3.2)


# chão de cimento em toda a cidade (plano)
func _plaza(c: Vector2, y: float, r: float) -> void:
	var seg := 36
	var rr := r - 1.0
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		floor_faces.append_array(PackedVector3Array([Vector3(c.x, y + 0.025, c.y), Vector3(c.x + cos(a0) * rr, y + 0.025, c.y + sin(a0) * rr), Vector3(c.x + cos(a1) * rr, y + 0.025, c.y + sin(a1) * rr)]))
	if headless:
		return
	b.mb.tex(U.CONCRETE, 0.22)
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var p0 := Vector3(c.x, y + 0.025, c.y)
		var p1 := Vector3(c.x + cos(a0) * rr, y + 0.025, c.y + sin(a0) * rr)
		var p2 := Vector3(c.x + cos(a1) * rr, y + 0.025, c.y + sin(a1) * rr)
		b.mb.tri(p0, p1, p2, Color(0.82, 0.81, 0.78), Vector3.UP)
		# guia na borda, descendo até o chão
		var e1 := Vector3(p1.x, minf(y, height(p1.x, p1.z)) - 0.3, p1.z)
		var e2 := Vector3(p2.x, minf(y, height(p2.x, p2.z)) - 0.3, p2.z)
		b.mb.quad(p1, p2, e2, e1, Color(0.7, 0.7, 0.68), Vector3(cos((a0 + a1) / 2.0), 0, sin((a0 + a1) / 2.0)))
	# juntas da calçada
	b.mb.tex(U.PLAIN, 1.0)
	var k := int(rr / 6.0)
	for gx in range(-k, k + 1):
		var hl := sqrt(maxf(rr * rr - pow(gx * 6.0, 2), 0.0))
		b.mb.box(Transform3D(Basis(), Vector3(c.x + gx * 6.0, y + 0.03, c.y)), Vector3(0.06, 0.005, hl * 2.0), Color(0.55, 0.55, 0.53))
		b.mb.box(Transform3D(Basis(), Vector3(c.x, y + 0.03, c.y + gx * 6.0)), Vector3(hl * 2.0, 0.005, 0.06), Color(0.55, 0.55, 0.53))


func _bairro(c: Vector2, y: float, r: float, big: bool) -> void:
	var rng := b.rng
	var th := rng.randf() * TAU
	var dir := Vector2(cos(th), sin(th))
	var side := Vector2(-dir.y, dir.x)
	# rua principal em curva (atravessa a cidade) e uma ou duas ruas que saem dela, também curvas
	var bend := r * rng.randf_range(0.25, 0.45) * (1.0 if rng.randf() < 0.5 else -1.0)
	var main := _curve(c - dir * r, c + side * bend, c + dir * r, 9)
	var paths := [main]
	var nb := 3 if big else (2 if rng.randf() < 0.5 else 1)
	for k in nb:
		var at: Vector2 = main[[2, 6, 4][k]]
		var sg := 1.0 if k % 2 == 0 else -1.0
		var tip := at + side * sg * r * 0.9 + dir * rng.randf_range(-r * 0.3, r * 0.3)
		# a rua termina dentro da cidade
		tip = c + (tip - c).limit_length(r * 0.82)
		paths.append(_curve(at, at.lerp(tip, 0.5) + dir * rng.randf_range(-r * 0.25, r * 0.25), tip, 6))
	for path in paths:
		_street_path(path, y)
	for path in paths:
		var pts: Array = path
		var L := 0.0
		for k in pts.size() - 1:
			L += (pts[k] as Vector2).distance_to(pts[k + 1])
		var x := 6.0
		while x < L - 6.0:
			var q := _along(pts, x)
			var pnt: Vector2 = q[0]
			var tg: Vector2 = q[1]
			var nrm := Vector2(-tg.y, tg.x)
			for sgn in [-1.0, 1.0]:
				if rng.randf() < 0.1:
					continue
				var spec := _house_spec(rng, big)
				var off: float = 4.4 + spec["d"] / 2.0 + rng.randf_range(0.5, 2.0)
				var p: Vector2 = pnt + nrm * sgn * off
				if not is_free(p, maxf(spec["w"], spec["d"]) * 0.45) or road_dist(p.x, p.y) < 3.0:
					continue
				var yaw := _face(p, pnt)
				if big and rng.randf() < 0.12 and is_free(p, 6.5):
					b.store(_p3(p, y), yaw)
				else:
					b.house(_p3(p, y), yaw, spec)
				if rng.randf() < 0.3:
					var fa: Vector2 = pnt + nrm * sgn * (off - spec["d"] / 2.0 - 1.6) - tg * (spec["w"] / 2.0)
					b.low_wall(fa, fa + tg * spec["w"] * 0.35, y)
			x += rng.randf_range(10.5, 13.0)
		for k in rng.randi_range(2, 4):
			var q := _along(pts, rng.randf_range(8.0, maxf(L - 8.0, 9.0)))
			var tg: Vector2 = q[1]
			var p: Vector2 = q[0] + Vector2(-tg.y, tg.x) * (2.0 if rng.randf() < 0.5 else -2.0)
			if is_free(p, 2.5):
				b.car(_p3(p, y), atan2(-tg.x, -tg.y) + (PI if rng.randf() < 0.5 else 0.0) + rng.randf_range(-0.1, 0.1))
	if big:
		# praça com caixa d'água, barreiras e caixotes
		b.water_tower(_p3(c + side * 9.0 + dir * 9.0, y))
		for k in 3:
			var p := c + Vector2(rng.randf_range(-7, 7), rng.randf_range(-7, 7))
			if is_free(p, 2.0):
				b.barrier(_p3(p, y), rng.randf() * TAU)
		var cp := c - side * 7.0 - dir * 5.0
		var cy := rng.randf() * TAU
		if is_free(cp, 1.8):
			b.crates(_p3(cp, y), cy)


# ---------------- localidades novas (pré-guerra) ----------------

# pista de pouso: asfalto sólido (colisão no chão) com faixas e marcas de cabeceira
func _runway(a: Vector2, e: Vector2, y: float, width: float) -> void:
	var d := e - a
	var dir := d.normalized()
	var yaw := -atan2(d.y, d.x)
	var bs := Basis(Vector3.UP, yaw)
	var n := maxi(1, int(d.length() / 6.0))
	var seg := d.length() / n
	for i in n:
		var q := a + d * ((i + 0.5) / n)
		var gy := minf(y, low_h(q, width * 0.5))
		var top := y + 0.06
		var dep := top - gy + 0.3
		var xf := Transform3D(bs, Vector3(q.x, top - dep / 2.0, q.y))
		floor_box(xf, Vector3(seg + 0.05, dep, width))
		if headless:
			continue
		b.mb.tex(U.ASPHALT, 0.2)
		b.mb.box(xf, Vector3(seg + 0.05, dep, width), Color(0.78, 0.78, 0.78))
		b.mb.tex(U.PLAIN, 1.0)
		if i % 2 == 0 and i > 1 and i < n - 2:
			b.mb.box(Transform3D(bs, Vector3(q.x, top + 0.006, q.y)), Vector3(seg * 0.6, 0.01, 0.35), Color(0.9, 0.9, 0.86))
		for sg in [-1.0, 1.0]:
			var ep: Vector2 = q + Vector2(-dir.y, dir.x) * sg * (width / 2.0 - 0.6)
			b.mb.box(Transform3D(bs, Vector3(ep.x, top + 0.006, ep.y)), Vector3(seg + 0.05, 0.01, 0.25), Color(0.88, 0.88, 0.84))
		# marcas de pneu e buracos de bomba na pista
		if b.vrng.randf() < 0.3:
			var hp: Vector2 = q + Vector2(-dir.y, dir.x) * b.vrng.randf_range(-width * 0.3, width * 0.3)
			b.mb.cyl(Transform3D(Basis(), Vector3(hp.x, top + 0.008, hp.y)), b.vrng.randf_range(0.8, 1.8), 0.9, 0.01, 10, Color(0.1, 0.09, 0.08), true, false, null, 0.35, b.vrng)
	if not headless:
		for end in [[a, dir], [e, -dir]]:
			var p0: Vector2 = end[0] + end[1] * 6.0
			for k in 8:
				var o: Vector2 = p0 + Vector2(-dir.y, dir.x) * (-width * 0.38 + k * width * 0.76 / 7.0)
				b.mb.box(Transform3D(bs, Vector3(o.x, y + 0.067, o.y)), Vector3(9.0, 0.01, 0.9), Color(0.92, 0.92, 0.88))
	for i in int(d.length() / 6.0) + 1:
		claim(a + dir * i * 6.0, width * 0.6)


func _aerodromo(c: Vector2, y: float, r: float) -> void:
	var rng := b.rng
	# pista no sentido norte-sul do lado leste; hangares olhando pra pista
	var rx := c.x + 26.0
	var ra := Vector2(rx, c.y - 62.0)
	var re := Vector2(rx, c.y + 72.0)
	for k in 14:
		add_pad(ra.lerp(re, k / 13.0), 10.0, y, 30.0)
	_runway(ra, re, y, 18.0)
	var east := _face(c, c + Vector2(1, 0))
	for hz in [-20.0, 13.0]:
		b.hangar(_p3(c + Vector2(-8.0, hz), y), _face(c + Vector2(-8.0, hz), c + Vector2(10.0, hz)))
	# torre de controle (sobrado de concreto) e área das tendas
	b.house(_p3(c + Vector2(-6.0, 38.0), y), _face(c + Vector2(-6.0, 38.0), Vector2(rx, c.y + 38.0)), {"w": 7.0, "d": 6.5, "floors": 2, "style": "concrete", "roof": "flat"})
	b.radio_tower(_p3(c + Vector2(-20.0, 42.0), y))
	for k in 2:
		b.fuel_tank(_p3(c + Vector2(-34.0, -38.0 + k * 9.0), y), PI / 2.0)
	for k in 3:
		var p := c + Vector2(-40.0 + k * 6.0, 26.0)
		if is_free(p, 3.0):
			b.tent(_p3(p, y), east + PI)
	# avião de carga destruído na beira da pista e sacos de areia nas cabeceiras
	b.tank_wreck(_p3(Vector2(rx - 14.0, c.y - 44.0), y), rng.randf() * TAU)
	b.mg_nest(_p3(Vector2(rx - 13.0, c.y + 62.0), y), PI)
	b.mg_nest(_p3(Vector2(rx + 13.0, c.y - 55.0), y), 0.0)
	for k in 6:
		var p := c + Vector2(rng.randf_range(-30.0, 8.0), rng.randf_range(-40.0, 40.0))
		if is_free(p, 2.5):
			if k % 3 == 0:
				b.car(_p3(p, y), rng.randf() * TAU)
			elif k % 3 == 1:
				b.crates(_p3(p, y), rng.randf() * TAU)
			else:
				b.barrel(_p3(p, y))
	for k in 4:
		var p := Vector2(rx + (1.0 if k % 2 == 0 else -1.0) * rng.randf_range(13.0, 18.0), c.y + rng.randf_range(-50.0, 60.0))
		if is_free(p, 3.0):
			b.crater(_p3(p, y))
	smoke_spots.append(Vector2(rx - 14.0, c.y - 44.0))


func _galpoes(c: Vector2, y: float, r: float) -> void:
	var rng := b.rng
	var th := rng.randf_range(-0.25, 0.25)
	var bs := Basis(Vector3.UP, -th)
	var at := func(x: float, z: float) -> Vector2:
		var v: Vector3 = bs * Vector3(x, 0, z)
		return c + Vector2(v.x, v.z)
	b.galpao(_p3(at.call(-9.0, -15.0), y), -th)
	b.galpao(_p3(at.call(-9.0, 11.0), y), -th + PI)
	b.galpao(_p3(at.call(22.0, -2.0), y), -th + PI / 2.0)
	# pátio: contêineres empilhados, tanques de combustível, empilhadeira (carro), caixotes
	for k in 6:
		var p: Vector2 = at.call(rng.randf_range(-24.0, 8.0), rng.randf_range(-3.0, 0.0))
		if is_free(p, 3.5):
			b.container(_p3(p, y), -th + (PI / 2.0 if rng.randf() < 0.3 else 0.0), rng.randf() < 0.4, rng.randf() < 0.4)
	b.fuel_tank(_p3(at.call(10.0, 26.0), y), -th + PI / 2.0)
	b.water_tower(_p3(at.call(-30.0, 22.0), y))
	for k in 5:
		var p: Vector2 = c + Vector2(rng.randf_range(-r * 0.8, r * 0.8), rng.randf_range(-r * 0.8, r * 0.8))
		if is_free(p, 2.0):
			if k < 2:
				b.car(_p3(p, y), rng.randf() * TAU)
			else:
				b.crates(_p3(p, y), rng.randf() * TAU)
	for k in 2:
		var p: Vector2 = c + Vector2(rng.randf_range(-r * 0.7, r * 0.7), rng.randf_range(-r * 0.7, r * 0.7))
		if is_free(p, 1.6):
			b.gun_crate(_p3(p, y), rng.randf() * TAU)


func _acampamento(c: Vector2, y: float, r: float) -> void:
	var rng := b.rng
	var th := rng.randf() * TAU
	var fwd := Vector2(cos(th), sin(th))
	var rt := Vector2(-fwd.y, fwd.x)
	# duas fileiras de tendas
	for row in 2:
		for k in 4:
			var p := c + rt * (-9.0 + k * 6.0) + fwd * (6.0 if row == 0 else -6.0)
			if is_free(p, 2.8):
				b.tent(_p3(p, y), _face(p, c + rt * (-9.0 + k * 6.0)))
	b.bunker(_p3(c + fwd * 18.0, y), _face(c + fwd * 18.0, c + fwd * 40.0))
	b.bunker(_p3(c - rt * 20.0, y), _face(c - rt * 20.0, c - rt * 40.0))
	b.mg_nest(_p3(c + fwd * 20.0 + rt * 13.0, y), _face(c, c + fwd))
	b.artillery(_p3(c - fwd * 18.0 + rt * 8.0, y), _face(c, c - fwd))
	b.artillery(_p3(c - fwd * 18.0 - rt * 4.0, y), _face(c, c - fwd))
	b.watchtower(_p3(c + rt * 22.0 - fwd * 6.0, y), _face(c + rt * 22.0 - fwd * 6.0, c))
	b.trench(_p3(c + fwd * 27.0, y), -atan2(rt.y, rt.x), 18.0)
	# arame farpado e ouriços em volta
	for k in 10:
		var a := th + k * TAU / 10.0 + 0.2
		var p := c + Vector2(cos(a), sin(a)) * (r + 6.0)
		if is_free(p, 2.0) and road_dist(p.x, p.y) > 4.0:
			if k % 3 == 0:
				b.hedgehog(_p3(p, low_h(p, 1.2) - 0.05), rng.randf() * TAU)
			else:
				b.wire(_p3(p, low_h(p, 3.0) - 0.05), -a + PI / 2.0 + PI, 7.0)
	for k in 3:
		var p := c + Vector2(rng.randf_range(-r * 0.6, r * 0.6), rng.randf_range(-r * 0.6, r * 0.6))
		if is_free(p, 1.8):
			b.gun_crate(_p3(p, y), rng.randf() * TAU)
	for k in 2:
		var p := c + Vector2(rng.randf_range(-r * 0.6, r * 0.6), rng.randf_range(-r * 0.6, r * 0.6))
		if is_free(p, 3.0):
			b.car(_p3(p, y), rng.randf() * TAU)


# Brejo Seco: o brejo secou, ficaram as palafitas de madeira em cima da terra rachada,
# ligadas por passarelas altas (com escada nas pontas)
func _palafitas(c: Vector2, y: float, r: float) -> void:
	var rng := b.rng
	var th := rng.randf() * TAU
	var dir := Vector2(cos(th), sin(th))
	var nrm := Vector2(-dir.y, dir.x)
	for line in 2:
		var L := r * (1.3 if line == 0 else 1.0)
		var mid := c + nrm * (line * 2 - 1) * 10.5
		var hh := 2.4
		b.walkway(_p3(mid, y), atan2(-dir.x, -dir.y), L, hh, true, true, false)
		var n := int(L / 6.5)
		for i in n:
			var t := -L / 2.0 + 4.0 + i * (L - 8.0) / maxf(1.0, n - 1)
			for sg in [-1.0, 1.0]:
				if rng.randf() < 0.25:
					continue
				var p: Vector2 = mid + dir * t + nrm * sg * (0.8 + 1.9 + 1.6)
				if not is_free(p, 2.4):
					continue
				b.stilt_hut(_p3(p, y), _face(p, mid + dir * t), true)
	# palafitas soltas com escada própria, canoas largadas na terra seca, lenha e tambores
	for k in 6:
		var a := rng.randf() * TAU
		var p := c + Vector2(cos(a), sin(a)) * rng.randf_range(r * 0.6, r * 0.95)
		if is_free(p, 4.0):
			b.stilt_hut(_p3(p, y), _face(p, c))
	for k in 3:
		var p := c + Vector2(rng.randf_range(-r * 0.8, r * 0.8), rng.randf_range(-r * 0.8, r * 0.8))
		if is_free(p, 2.5):
			b.boat(_p3(p, y + 0.05), rng.randf() * TAU)
	for k in 4:
		var p := c + Vector2(rng.randf_range(-r * 0.8, r * 0.8), rng.randf_range(-r * 0.8, r * 0.8))
		if is_free(p, 1.5):
			if k % 2 == 0:
				b.logs(_p3(p, y), rng.randf() * TAU)
			else:
				b.barrel(_p3(p, y))


# Chapada Ventania: no alto do morro, praça elevada (chão de concreto acima do chão) com
# escadas e uma passarela até um mirante menor; casas em volta
func _mirante(c: Vector2, y: float, r: float) -> void:
	var rng := b.rng
	var th := rng.randf_range(-0.4, 0.4)
	var bs := Basis(Vector3.UP, th)
	var ax := bs * Vector3.RIGHT
	var dx := Vector2(ax.x, ax.z)
	var ph := 4.2
	var big := 22.0
	var small := 12.0
	var gap := 12.0
	var pa := c - dx * 8.0
	var pb := pa + dx * (big / 2.0 + gap + small / 2.0)
	b.platform(_p3(pa, y), th, big, big, ph, 1)
	b.platform(_p3(pb, y), th, small, small, ph, 2)
	var wm := pa + dx * (big / 2.0 + gap / 2.0)
	b.walkway(_p3(wm, y), th + PI / 2.0, gap + 0.6, ph - 0.07, false, false, true)
	_plaza(c, y, r)
	_esparso(c, y, r)
	for k in 4:
		var p := c + Vector2(rng.randf_range(-r * 0.7, r * 0.7), rng.randf_range(-r * 0.7, r * 0.7))
		if is_free(p, 2.0):
			b.sandbags(_p3(p, y), rng.randf() * TAU, rng.randf_range(2.5, 4.0))


func _esparso(c: Vector2, y: float, r: float) -> void:
	var rng := b.rng
	var n := rng.randi_range(6, 8)
	var placed := []
	var tries := 0
	while placed.size() < n and tries < 60:
		tries += 1
		var p := c + Vector2(rng.randf_range(-r * 0.8, r * 0.8), rng.randf_range(-r * 0.8, r * 0.8))
		var ok := true
		for q in placed:
			if p.distance_to(q) < 13.0:
				ok = false
		if not ok or not is_free(p, 5.0):
			continue
		placed.append(p)
		var yaw := rng.randf() * TAU
		var spec := _house_spec(rng)
		b.house(_p3(p, y), yaw, spec)
		if rng.randf() < 0.5:
			_yard(p, yaw, spec, y)
		elif rng.randf() < 0.5:
			b.shack(_p3(p + Vector2(cos(yaw), sin(yaw)) * 9.0, y), yaw + 0.3)
	for k in 2:
		var p := c + Vector2(rng.randf_range(-r * 0.6, r * 0.6), rng.randf_range(-r * 0.6, r * 0.6))
		if is_free(p, 3.0):
			b.car(_p3(p, y), rng.randf() * TAU)


func _fazenda(c: Vector2, y: float, r: float) -> void:
	var rng := b.rng
	var th := rng.randf() * TAU
	var dir := Vector2(cos(th), sin(th))
	var side := Vector2(-dir.y, dir.x)
	b.house(_p3(c + dir * r * 0.35, y), _face(c + dir * r * 0.35, c), {"w": 10.0, "d": 8.5, "floors": 2, "style": "plaster", "roof": "tile", "balcony": true, "porch": false})
	b.warehouse(_p3(c - dir * r * 0.35, y), _face(c - dir * r * 0.35, c))
	b.silo(_p3(c - dir * r * 0.35 + side * 14.5, y))
	b.silo(_p3(c - dir * r * 0.35 + side * 21.5, y))
	b.water_tower(_p3(c + side * r * 0.5, y))
	for k in rng.randi_range(5, 8):
		var p := c + Vector2(rng.randf_range(-r * 0.7, r * 0.7), rng.randf_range(-r * 0.7, r * 0.7))
		if is_free(p, 1.5):
			b.hay(_p3(p, y), rng.randf() * TAU)
	var p2 := c - side * r * 0.4
	if is_free(p2, 3.0):
		b.car(_p3(p2, y), rng.randf() * TAU)
	var pts := []
	for k in 10:
		var a := TAU * k / 10.0 + th
		pts.append(c + Vector2(cos(a), sin(a)) * r * 0.92)
	b.fence_ring(pts, [0, 5])


func _base_mil(c: Vector2, y: float, r: float) -> void:
	var rng := b.rng
	var th := rng.randf_range(-0.3, 0.3)
	var bs := Basis(Vector3.UP, -th)
	var hw := r * 0.8
	var pts := []
	for q in [Vector2(-hw, -hw), Vector2(0, -hw), Vector2(hw, -hw), Vector2(hw, hw), Vector2(0, hw), Vector2(-hw, hw)]:
		var v: Vector3 = bs * Vector3(q.x, 0, q.y)
		pts.append(c + Vector2(v.x, v.z))
	var wall_pts := []
	# portões no meio de dois lados
	for i in pts.size():
		var a: Vector2 = pts[i]
		var e: Vector2 = pts[(i + 1) % pts.size()]
		if i == 0 or i == 3:
			wall_pts.append([a, a.lerp(e, 0.82)])
		else:
			wall_pts.append([a, e])
	for wp in wall_pts:
		b.low_wall(wp[0], wp[1], y, "concrete", 2.6)
	var gates := []
	for i in [0, 3]:
		var g: Vector2 = pts[i].lerp(pts[(i + 1) % pts.size()], 0.91)
		var d := (c - g).normalized()
		gates.append([ground_pos(g + d * 3.0, 0.3), ground_pos(g - d * 3.0, 0.3)])
	compounds.append({"c": c, "r": hw * 1.3, "gates": gates})
	var fwd := Vector2((bs * Vector3.FORWARD).x, (bs * Vector3.FORWARD).z)
	var rt := Vector2((bs * Vector3.RIGHT).x, (bs * Vector3.RIGHT).z)
	b.barracks(_p3(c + fwd * hw * 0.5 - rt * hw * 0.35, y), -th)
	b.barracks(_p3(c - fwd * hw * 0.45 - rt * hw * 0.35, y), -th + PI)
	for k in 8:
		var p := c + rt * rng.randf_range(0.0, hw * 0.75) + fwd * rng.randf_range(-hw * 0.75, hw * 0.75)
		if is_free(p, 3.0):
			b.container(_p3(p, y), -th + (PI / 2.0 if rng.randf() < 0.5 else 0.0), rng.randf() < 0.4, rng.randf() < 0.25)
	b.watchtower(_p3(pts[0].lerp(c, 0.12), y), _face(pts[0], c))
	b.watchtower(_p3(pts[3].lerp(c, 0.12), y), _face(pts[3], c))
	for k in 6:
		var p := c + Vector2(rng.randf_range(-hw * 0.7, hw * 0.7), rng.randf_range(-hw * 0.7, hw * 0.7))
		if is_free(p, 2.0):
			b.sandbags(_p3(p, y), rng.randf() * TAU, rng.randf_range(2.5, 4.5))
	for k in 4:
		var p := c + Vector2(rng.randf_range(-hw * 0.6, hw * 0.6), rng.randf_range(-hw * 0.6, hw * 0.6))
		if is_free(p, 2.0):
			b.barrier(_p3(p, y), rng.randf() * TAU)
	if not headless:
		b.mb.tex(U.CONCRETE, 0.3)
		var hp := c - rt * hw * 0.35
		b.mb.box(Transform3D(Basis(), Vector3(hp.x, y + 0.04, hp.y)), Vector3(10, 0.08, 10), Color(0.9, 0.9, 0.88))
	for k in 3:
		var p := c + Vector2(rng.randf_range(-hw * 0.6, hw * 0.6), rng.randf_range(-hw * 0.6, hw * 0.6))
		add_item(_p3(p, y + 0.07), Weapons.LOOT_MILITARY[rng.randi() % Weapons.LOOT_MILITARY.size()], null, null)


func _posto(c: Vector2, y: float, r: float) -> void:
	var rng := b.rng
	var th := rng.randf() * TAU
	var root := b.body(_p3(c, y), th)
	claim(c, 9.0)
	for sx in [-4.5, 4.5]:
		for sz in [-3.0, 3.0]:
			b.piece(root, Vector3(0.4, 4.5, 0.4), Vector3(sx, 2.25, sz), Color(0.95, 0.95, 0.95), U.CONCRETE, 0.4)
	b.piece(root, Vector3(12, 0.5, 8.5), Vector3(0, 4.7, 0), Color(0.95, 0.95, 0.95), U.PLAIN, 0.3)
	if not headless:
		b.vis(root, Vector3(12.05, 0.3, 8.55), Vector3(0, 4.6, 0), Color(0.75, 0.15, 0.12), U.PLAIN, 0.3)
		b.vis(root, Vector3(13, 0.06, 10), Vector3(0, 0.03, 0), Color(0.9, 0.9, 0.9), U.CONCRETE, 0.25)
	for sx in [-2.0, 2.0]:
		b.piece(root, Vector3(0.6, 1.5, 0.9), Vector3(sx, 0.75, 0), Color(0.85, 0.2, 0.15), U.PLAIN, 0.5)
	var bs := Basis(Vector3.UP, th)
	var sp := c + Vector2((bs * Vector3(0, 0, 14)).x, (bs * Vector3(0, 0, 14)).z)
	if is_free(sp, 6.5):
		b.store(_p3(sp, y), th + PI)
	for k in 3:
		var p := c + Vector2(rng.randf_range(-r * 0.6, r * 0.6), rng.randf_range(-r * 0.6, r * 0.6))
		if is_free(p, 3.0):
			b.car(_p3(p, y), rng.randf() * TAU)
	for k in 4:
		var p := c + Vector2(rng.randf_range(-r * 0.7, r * 0.7), rng.randf_range(-r * 0.7, r * 0.7))
		if is_free(p, 1.0):
			b.barrel(_p3(p, y))
	var hp := c + Vector2((bs * Vector3(16, 0, -4)).x, (bs * Vector3(16, 0, -4)).z)
	if is_free(hp, 5.0):
		b.house(_p3(hp, y), th - PI / 2.0, _house_spec(rng))


func _pedreira(c: Vector2, y: float, r: float) -> void:
	var rng := b.rng
	var pit := y - 6.0
	for k in 12:
		var a := rng.randf() * TAU
		var d := r * rng.randf_range(0.2, 0.75)
		var p := c + Vector2(cos(a), sin(a)) * d
		_rock(p, rng.randf_range(2.5, 5.5), rng)
	b.warehouse(_p3(c + Vector2(r * 0.15, -r * 0.2), pit), rng.randf() * TAU)
	b.shack(_p3(c + Vector2(-r * 0.3, r * 0.15), pit), rng.randf() * TAU)
	for k in 2:
		var p := c + Vector2(rng.randf_range(-r * 0.4, r * 0.4), rng.randf_range(-r * 0.4, r * 0.4))
		if is_free(p, 3.0):
			b.container(_p3(p, pit), rng.randf() * TAU, true)
	var tp := c + Vector2(rng.randf_range(-r * 0.3, r * 0.3), rng.randf_range(-r * 0.3, r * 0.3))
	if is_free(tp, 3.0):
		b.car(_p3(tp, pit), rng.randf() * TAU)
	# casinhas na borda de cima (sem uma dentro da outra)
	_more_houses(c, y, r, 4, 1.15, 1.35, true)


func _serraria(c: Vector2, y: float, r: float) -> void:
	var rng := b.rng
	b.warehouse(_p3(c, y), rng.randf() * TAU)
	for k in 5:
		var a := rng.randf() * TAU
		var p := c + Vector2(cos(a), sin(a)) * r * rng.randf_range(0.45, 0.8)
		if is_free(p, 3.0):
			b.logs(_p3(p, y), rng.randf() * TAU)
	for k in 3:
		var a := rng.randf() * TAU
		var p := c + Vector2(cos(a), sin(a)) * r * rng.randf_range(0.5, 0.85)
		if is_free(p, 4.0):
			b.shack(_p3(p, y), _face(p, c))
	b.crates(_p3(c + Vector2(r * 0.3, r * 0.4), y), rng.randf() * TAU)


func _ruinas(c: Vector2, y: float, r: float) -> void:
	var rng := b.rng
	for k in rng.randi_range(3, 4):
		var a := rng.randf() * TAU
		var p := c + Vector2(cos(a), sin(a)) * r * rng.randf_range(0.2, 0.7)
		if is_free(p, 4.0):
			b.ruin(_p3(p, y), rng.randf() * TAU)
	b.well(_p3(c, y))
	for k in 3:
		var p := c + Vector2(rng.randf_range(-r * 0.7, r * 0.7), rng.randf_range(-r * 0.7, r * 0.7))
		if is_free(p, 2.0):
			b.sandbags(_p3(p, y), rng.randf() * TAU)


func _torre(c: Vector2, y: float, r: float) -> void:
	var rng := b.rng
	b.radio_tower(_p3(c, y))
	b.crates(_p3(c + Vector2(-6, 5), y), rng.randf() * TAU)
	b.sandbags(_p3(c + Vector2(5, -6), y), rng.randf() * TAU)
	var pts := []
	for k in 8:
		var a := TAU * k / 8.0
		pts.append(c + Vector2(cos(a), sin(a)) * r * 0.95)
	b.fence_ring(pts, [2])


func _estacao(c: Vector2, y: float, r: float) -> void:
	var rng := b.rng
	# direção do trilho por aqui
	var dir := (RAIL[4] - RAIL[3]).normalized()
	var side := Vector2(-dir.y, dir.x)
	var yaw := -atan2(dir.y, dir.x)
	var root := b.body(_p3(c + side * 4.2, y), yaw)
	b.piece(root, Vector3(34, 0.7, 4.0), Vector3(0, 0.35, 0), Color(0.9, 0.9, 0.88), U.CONCRETE, 0.35)
	for k in 5:
		b.piece(root, Vector3(0.3, 3.6, 0.3), Vector3(-14 + k * 7.0, 2.5, 1.2), Color(0.5, 0.4, 0.3), U.WOOD, 0.5)
	b.piece(root, Vector3(34, 0.15, 3.2), Vector3(0, 4.35, 0.8), Color(0.9, 0.9, 0.9), U.METAL, 0.3)
	var hp := c + side * 13.0
	b.house(_p3(hp, y), _face(hp, c), {"w": 14.0, "d": 7.0, "style": "brick", "roof": "tile", "rooms": 2, "porch": true})
	for k in 3:
		var t := rng.randf_range(-r * 0.9, r * 0.9)
		var p := c + dir * t
		b.wagon(_p3(p, height(p.x, p.y) + 0.2), yaw + PI / 2.0)
	for k in 2:
		var p := c - side * rng.randf_range(10, 16) + dir * rng.randf_range(-r * 0.6, r * 0.6)
		if is_free(p, 3.0):
			b.container(_p3(p, y), yaw, rng.randf() < 0.5)
	b.crates(_p3(c - side * 9.0, y), rng.randf() * TAU)


func _porto(c: Vector2, y: float, r: float) -> void:
	var rng := b.rng
	var to_lake := (LAKE_C - c).normalized()
	var shore := c + to_lake * r * 0.9
	b.pier(_p3(shore, WATER_Y + 0.6), _face(shore, shore + to_lake), 22.0, WATER_Y + 0.6)
	for k in 3:
		var p := shore + to_lake * rng.randf_range(6, 20) + Vector2(-to_lake.y, to_lake.x) * rng.randf_range(-6, 6)
		b.boat(_p3(p, WATER_Y - 0.15), rng.randf() * TAU)
	for k in 3:
		var a := rng.randf_range(-1.2, 1.2)
		var p := c - to_lake.rotated(a) * r * rng.randf_range(0.2, 0.7)
		if is_free(p, 4.0):
			b.shack(_p3(p, y), _face(p, LAKE_C))
	b.house(_p3(c - to_lake * r * 0.1 + Vector2(-to_lake.y, to_lake.x) * 10.0, y), _face(c, LAKE_C), _house_spec(rng))
	for k in 3:
		var p := c + Vector2(rng.randf_range(-r * 0.6, r * 0.6), rng.randf_range(-r * 0.6, r * 0.6))
		if is_free(p, 1.0):
			b.barrel(_p3(p, y))
	b.crates(_p3(c + Vector2(-to_lake.y, to_lake.x) * -8.0, y), rng.randf() * TAU)


func _rock(p: Vector2, s: float, rng: RandomNumberGenerator) -> void:
	_big_rocks.append([p, s, rng.randf() * TAU, rng.randf_range(0.55, 0.9)])
	claim(p, s * 0.6)


var _big_rocks := []


# casas soltas, ruínas, coberturas e postes pelo mapa
func _build_extras() -> void:
	b.begin(SEED + 501)
	var rng := b.rng
	var lim := PLAY - 25.0
	var placed := 0
	var tries := 0
	while placed < 26 and tries < 600:
		tries += 1
		var p := Vector2(rng.randf_range(-lim, lim), rng.randf_range(-lim, lim))
		if _near_town(p, 25.0) or not is_free(p, 10.0) or road_dist(p.x, p.y) < 6.0 or hw_dist(p.x, p.y) < 14.0 or rail_dist(p) < 10.0:
			continue
		var h := height(p.x, p.y)
		if h < WATER_Y + 1.0 or _slope(p) > 0.25:
			continue
		placed += 1
		var yaw := rng.randf() * TAU
		var k := rng.randf()
		if k < 0.45:
			b.house(_p3(p, h - 0.15), yaw, _house_spec(rng))
		elif k < 0.65:
			b.shack(_p3(p, h - 0.1), yaw)
		elif k < 0.8:
			b.ruin(_p3(p, h - 0.1), yaw)
		else:
			b.watchtower(_p3(p, low_h(p, 2.0) - 0.05), yaw)
	# coberturas soltas
	tries = 0
	var covers := 0
	while covers < 90 and tries < 1800:
		tries += 1
		var p := Vector2(rng.randf_range(-lim, lim), rng.randf_range(-lim, lim))
		if _near_town(p, 6.0) or not is_free(p, 3.0) or road_dist(p.x, p.y) < 3.0 or hw_dist(p.x, p.y) < 7.0:
			continue
		var h := height(p.x, p.y)
		if h < WATER_Y + 0.6 or _slope(p) > 0.3:
			continue
		covers += 1
		var k := rng.randf()
		if k < 0.3:
			b.crates(_p3(p, low_h(p, 1.0) - 0.05), rng.randf() * TAU)
		elif k < 0.5:
			b.sandbags(_p3(p, low_h(p, 1.5) - 0.05), rng.randf() * TAU, rng.randf_range(2.5, 4.0))
		elif k < 0.65:
			b.car(_p3(p, low_h(p, 1.5)), rng.randf() * TAU)
		elif k < 0.8:
			b.logs(_p3(p, low_h(p, 2.5) - 0.05), rng.randf() * TAU)
		else:
			b.hay(_p3(p, low_h(p, 0.8) - 0.05), rng.randf() * TAU)
	# postes de luz ao longo das estradas
	for r in roads:
		var a: Vector2 = r[0]
		var c: Vector2 = r[1]
		var d := c - a
		var n := int(d.length() / 45.0)
		var sd := Vector2(-d.normalized().y, d.normalized().x)
		for i in n:
			var p := a + d * ((i + 0.5) / n) + sd * 5.0
			if _near_town(p, 0.0) or not is_free(p, 1.0):
				continue
			b.pole(_p3(p, height(p.x, p.y) - 0.2), -atan2(d.y, d.x))
	b.finish()
	_build_fields()
	b.begin(SEED + 502)
	b.rails(RAIL)
	# vagões abandonados no meio da linha
	for t in [0.3, 0.62]:
		var p: Vector2 = RAIL[1].lerp(RAIL[2], t)
		var dir: Vector2 = (RAIL[2] - RAIL[1]).normalized()
		b.wagon(_p3(p, height(p.x, p.y) + 0.2), -atan2(dir.y, dir.x) + PI / 2.0)
	b.finish(500.0)


# Marcas da guerra pelo mapa todo: postos de controle nas rodovias, tanques queimados, crateras,
# trincheiras com ninho de metralhadora, arame farpado, ouriços, casamatas e canhões
func _build_war() -> void:
	b.begin(SEED + 505)
	var rng := b.rng
	var lim := PLAY - 25.0
	# postos de controle na rodovia, chegando perto das cidades
	for line in hw_pts:
		var last := -999
		for i in range(4, line.size() - 4):
			var p: Vector2 = line[i][0]
			if i - last < 25 or _near_town(p, 0.0) or not _near_town(p, 45.0) or not is_free(p, 9.0):
				continue
			var d: Vector2 = (line[i + 1][0] - line[i - 1][0]).normalized()
			b.checkpoint(_p3(p, height(p.x, p.y)), atan2(d.x, d.y))
			last = i
	var fields := func(r0: float, slope: float) -> Vector2:
		for t in 60:
			var p := Vector2(rng.randf_range(-lim, lim), rng.randf_range(-lim, lim))
			if _near_town(p, 12.0) or not is_free(p, r0) or road_dist(p.x, p.y) < r0 + 2.0 or hw_dist(p.x, p.y) < r0 + 6.0 or rail_dist(p) < r0 + 4.0:
				continue
			if height(p.x, p.y) < WATER_Y + 1.0 or _slope(p) > slope:
				continue
			return p
		return Vector2.INF
	for k in 7:
		var p: Vector2 = fields.call(5.0, 0.15)
		if p != Vector2.INF:
			b.tank_wreck(_p3(p, low_h(p, 3.0) - 0.05), rng.randf() * TAU)
			for j in 2:
				var q := p + Vector2(rng.randf_range(-12, 12), rng.randf_range(-12, 12))
				if is_free(q, 3.5) and road_dist(q.x, q.y) > 5.0:
					b.crater(_p3(q, height(q.x, q.y)))
	for k in 26:
		var p: Vector2 = fields.call(3.5, 0.25)
		if p != Vector2.INF:
			b.crater(_p3(p, height(p.x, p.y)))
	# trincheira com ninho de metralhadora numa ponta e arame na frente
	for k in 6:
		var p: Vector2 = fields.call(9.0, 0.12)
		if p == Vector2.INF:
			continue
		var yaw := rng.randf() * TAU
		var ax := Vector2(cos(yaw), -sin(yaw))
		var fr := Vector2(-ax.y, ax.x)
		var L := rng.randf_range(12.0, 18.0)
		b.trench(_p3(p, low_h(p, L * 0.5) - 0.05), yaw, L)
		var np := p + ax * (L / 2.0 + 3.2)
		if is_free(np, 2.8):
			b.mg_nest(_p3(np, low_h(np, 2.5) - 0.05), _face(np, np - fr))
		var wp := p - fr * 7.0
		if is_free(wp, 3.0):
			b.wire(_p3(wp, low_h(wp, 3.5) - 0.05), yaw, L)
	for k in 8:
		var p: Vector2 = fields.call(4.0, 0.2)
		if p != Vector2.INF:
			b.wire(_p3(p, low_h(p, 3.5) - 0.05), rng.randf() * TAU, rng.randf_range(6.0, 10.0))
	for k in 5:
		var p: Vector2 = fields.call(4.5, 0.15)
		if p != Vector2.INF:
			b.bunker(_p3(p, low_h(p, 3.5) - 0.05), rng.randf() * TAU)
	for k in 4:
		var p: Vector2 = fields.call(4.0, 0.15)
		if p == Vector2.INF:
			continue
		var yaw := rng.randf() * TAU
		b.artillery(_p3(p, low_h(p, 2.0) - 0.05), yaw)
		var bs := Basis(Vector3.UP, yaw)
		var sp: Vector3 = bs * Vector3(0, 0, -4.6)
		b.sandbags(_p3(p + Vector2(sp.x, sp.z), low_h(p, 2.5) - 0.05), yaw, 4.0)
	# ouriços tchecos na beira da rodovia (em grupos)
	for line in hw_pts:
		for i in range(10, line.size() - 10, 37):
			var p: Vector2 = line[i][0]
			var d: Vector2 = (line[i + 1][0] - p).normalized()
			for j in 3:
				var q := p + Vector2(-d.y, d.x) * (7.0 + j * 0.8) * (1.0 if i % 2 == 0 else -1.0) + d * (j * 2.4)
				if not _near_town(q, 4.0) and is_free(q, 1.4):
					b.hedgehog(_p3(q, height(q.x, q.y) - 0.05), rng.randf() * TAU)
	# barracas de refugiados/soldados soltas
	for k in 6:
		var p: Vector2 = fields.call(3.5, 0.15)
		if p != Vector2.INF:
			b.tent(_p3(p, low_h(p, 2.5) - 0.05), rng.randf() * TAU)
	b.finish()


# plantações (fileiras de milho/soja) e placas: o campo parece trabalhado, não vazio
func _build_fields() -> void:
	b.begin(SEED + 503)
	var rng := b.rng
	var lim := PLAY - 30.0
	var made := 0
	var tries := 0
	while made < 16 and tries < 900:
		tries += 1
		var c := Vector2(rng.randf_range(-lim, lim), rng.randf_range(-lim, lim))
		var near_farm := false
		for t in towns:
			if t["kind"] == "fazenda" and c.distance_to(t["pos"]) < float(t["r"]) + 70.0:
				near_farm = true
		if not near_farm and rng.randf() < 0.6:
			continue
		var fw := rng.randf_range(18.0, 34.0)
		var fd := rng.randf_range(16.0, 30.0)
		var rad := maxf(fw, fd) * 0.6
		if _near_town(c, rad) or not is_free(c, rad) or road_dist(c.x, c.y) < rad * 0.8 or hw_dist(c.x, c.y) < rad + 6.0 or rail_dist(c) < rad + 6.0:
			continue
		if _slope(c) > 0.12 or height(c.x, c.y) < WATER_Y + 1.5:
			continue
		made += 1
		claim(c, rad)
		var yaw := rng.randf() * TAU
		var bs := Basis(Vector3.UP, yaw)
		var corn := rng.randf() < 0.5
		var col := Color(0.55, 0.6, 0.28) if corn else Color(0.42, 0.55, 0.22)
		if rng.randf() < 0.3:
			col = Color(0.78, 0.66, 0.36)
		map_fields.append([c, fw, fd, yaw, col])
		var hh := 1.7 if corn else 0.55
		if not headless:
			var rows := int(fw / 1.3)
			b.mb.tex(U.LEAVES, 0.6, 0.6)
			for i in rows:
				var x := -fw / 2.0 + (i + 0.5) * fw / rows
				var n := int(fd / 6.0)
				for k in n:
					var z := -fd / 2.0 + (k + 0.5) * fd / n
					var lp := c + Vector2(x, z).rotated(-yaw)
					var y := height(lp.x, lp.y)
					var sh := hh * rng.randf_range(0.85, 1.1)
					b.mb.box(Transform3D(bs, Vector3(lp.x, y + sh / 2.0 - 0.1, lp.y)), Vector3(0.55, sh, fd / n + 0.05), col.darkened(rng.randf() * 0.12))
		# cerca em dois lados
		for side in [0, 1]:
			var a2 := c + (Vector2(-fw / 2.0 - 1.0, -fd / 2.0 - 1.0) if side == 0 else Vector2(fw / 2.0 + 1.0, -fd / 2.0 - 1.0)).rotated(-yaw)
			var e2 := c + (Vector2(fw / 2.0 + 1.0, -fd / 2.0 - 1.0) if side == 0 else Vector2(fw / 2.0 + 1.0, fd / 2.0 + 1.0)).rotated(-yaw)
			b.fence(a2, e2, minf(height(a2.x, a2.y), height(e2.x, e2.y)) - 0.05)
	b.finish(380.0)


func _near_town(p: Vector2, extra: float) -> bool:
	for t in towns:
		if p.distance_to(t["pos"]) < float(t["r"]) + extra:
			return true
	return false


func _slope(p: Vector2) -> float:
	var h0 := height(p.x, p.y)
	var m := 0.0
	for o in [Vector2(3, 0), Vector2(0, 3), Vector2(-3, 0), Vector2(0, -3)]:
		m = maxf(m, absf(height(p.x + o.x, p.y + o.y) - h0) / 3.0)
	return m


# ---------------- árvores, moitas, pedras e grama ----------------

func _tree_meshes() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 5
	var bark := Color(0.95, 0.9, 0.85)
	var out := {}
	# Árvores ralas e baixas (estilo FF): copa de vários tufos pequenos e irregulares, claros em cima
	# e escuros embaixo, com galhos aparecendo e buracos por onde se vê; "_lo" = mesma silhueta, leve.
	var specs := {
		# [altura do tronco, raio do tronco, tufos, raio da copa, altura da copa, tamanho do tufo, cor]
		"oak": [4.2, 0.4, 11, 2.2, 2.0, 0.88, Color(1.0, 1.0, 0.95)],
		"pine": [6.6, 0.32, 9, 1.6, 1.2, 0.82, Color(0.85, 0.95, 0.85)],
		"tall": [7.5, 0.28, 10, 1.2, 3.4, 0.66, Color(1.05, 1.05, 0.9)],
	}
	for kind in specs:
		var sp: Array = specs[kind]
		var th: float = sp[0]
		var tr: float = sp[1]
		var tint: Color = sp[6]
		var m := MB.new()
		var lo := MB.new()
		m.tex(U.BARK, 0.5)
		m.cyl(Transform3D(Basis(), Vector3(0, -0.6, 0)), tr * 1.3, tr * 0.55, th + 0.6, 7, bark, false)
		# raízes saindo do chão
		for k in 3:
			var ra := TAU * k / 3.0 + 0.4
			m.cyl(Transform3D(Basis(Vector3(cos(ra), 0, sin(ra)).cross(Vector3.UP).normalized(), 1.1), Vector3(0, -0.1, 0)), tr * 0.7, tr * 0.2, 0.7, 4, bark.darkened(0.1), false)
		lo.tex(U.BARK, 0.5)
		lo.cyl(Transform3D(Basis(), Vector3(0, -0.6, 0)), tr * 1.25, tr * 0.6, th + 0.6, 4, bark, false)
		var tufts := []
		var n_t: int = sp[2]
		for k in n_t:
			var a := TAU * k / float(n_t) * 2.0 + rng.randf_range(-0.4, 0.4)
			var rr: float = float(sp[3]) * sqrt(rng.randf_range(0.15, 1.0))
			var y: float = th - 0.6 + rng.randf_range(0.0, float(sp[4]))
			if k == 0:
				rr = 0.0
				y = th + float(sp[4]) * 0.75
			var p := Vector3(cos(a) * rr, y, sin(a) * rr)
			var ts: float = float(sp[5]) * rng.randf_range(0.75, 1.25)
			tufts.append([p, ts])
			# galho do tronco até o tufo
			if rr > 0.35:
				var from := Vector3(0, y - rr * 0.7 - 0.2, 0)
				var d := p - from
				m.tex(U.BARK, 0.5)
				m.cyl(Transform3D(Basis(Quaternion(Vector3.UP, d.normalized())), from), tr * 0.45, tr * 0.18, d.length() * 0.9, 4, bark, false)
		m.tex(U.LEAVES, 0.9, 1.0)
		lo.tex(U.LEAVES, 0.5)
		for tf in tufts:
			var ts: float = tf[1]
			var pp: Vector3 = tf[0]
			var sc := Vector3(ts * 1.25, ts * 0.8, ts * 1.25)
			# mais alto = mais claro (sol batendo)
			var hk := clampf((pp.y - th + 0.6) / (float(sp[4]) + 0.6), 0.0, 1.0)
			var c := Color(0.78, 0.86, 0.72).lerp(Color(1.12, 1.12, 0.95), hk) * tint
			m.blob(Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(sc), pp), 7, 4, c, rng, 0.5, true, 0.55)
			# folhinhas soltas em volta do tufo (quebram a forma de bola)
			for q in 2:
				var off := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.4, 0.6), rng.randf_range(-1, 1)).normalized() * ts * 1.05
				m.blob(Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(sc * 0.42), pp + off), 5, 3, c * 0.95, rng, 0.45, true, 0.4)
			lo.blob(Transform3D(Basis.from_scale(sc * 1.1), pp), 5, 3, c, rng, 0.25, true, 0.45)
		out[kind] = m.commit()
		out[kind + "_lo"] = lo.commit()
	# moita: vários tufos de tamanhos diferentes, escura por dentro e clara nas pontas
	var m3 := MB.new()
	m3.tex(U.LEAVES, 1.1, 0.5)
	for k in 7:
		var a := rng.randf() * TAU
		var rr := rng.randf_range(0.0, 0.55)
		var hgt := rng.randf_range(0.25, 0.65)
		var sz := rng.randf_range(0.3, 0.55)
		var c := Color(0.8, 0.88, 0.72).lerp(Color(1.08, 1.08, 0.9), hgt)
		m3.blob(Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(sz * 1.2, sz, sz * 1.2)), Vector3(cos(a) * rr, hgt, sin(a) * rr)), 6, 4, c, rng, 0.45, true, 0.6)
	# galhinhos secos saindo
	m3.tex(U.BARK, 0.6)
	for k in 4:
		var a := rng.randf() * TAU
		var d := Vector3(cos(a) * 0.6, 1.0, sin(a) * 0.6).normalized()
		m3.cyl(Transform3D(Basis(Quaternion(Vector3.UP, d)), Vector3(0, 0.05, 0)), 0.02, 0.005, 0.9, 3, bark, false)
	out["bush"] = m3.commit()
	# árvores e moita de verdade (Poly Haven, CC0; tools/prepare_trees.gd): troca o desenho simples
	for k in ["oak", "pine", "tall", "bush"]:
		var path := "res://models/trees/%s.res" % k
		if ResourceLoader.exists(path):
			out[k] = load(path)
			if ResourceLoader.exists("res://models/trees/%s_lo.res" % k):
				out[k + "_lo"] = load("res://models/trees/%s_lo.res" % k)
	# pedra
	var m4 := MB.new()
	m4.tex(U.ROCK, 0.8)
	m4.blob(Transform3D(Basis.from_scale(Vector3(0.55, 0.5, 0.55)), Vector3.ZERO), 9, 6, Color(1, 1, 1), rng, 0.2, false, 0.3)
	out["rock"] = m4.commit()
	# tronco caído
	var m5 := MB.new()
	m5.tex(U.BARK, 0.5)
	m5.cyl(Transform3D(Basis(Vector3.FORWARD, PI / 2.0), Vector3(-3.5, 0.45, 0)), 0.48, 0.38, 7.0, 8, bark, true)
	out["log"] = m5.commit()
	# tufo de grama (lâminas finas, sem transparência)
	var m6 := MB.new()
	m6.tex(U.PLAIN, 1.0)
	for i in 8:
		var a := rng.randf() * TAU
		var o := Vector3(rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-0.25, 0.25))
		var sd := Vector3(cos(a), 0, sin(a)) * 0.04
		var lean := Vector3(sin(a), 0, -cos(a)) * rng.randf_range(0.05, 0.2)
		var top := o + lean + Vector3(0, rng.randf_range(0.3, 0.6), 0)
		var gc := Color(0.27, 0.34, 0.15).lerp(Color(0.48, 0.45, 0.25), rng.randf())
		var nrm := Vector3(sin(a), 0.6, -cos(a)).normalized()
		m6.tri(o - sd, o + sd, top, gc, nrm, Vector3.UP, Vector3.UP, Vector3.UP)
		m6.tri(o - sd, o + sd, top, gc, -nrm, Vector3.UP, Vector3.UP, Vector3.UP)
	out["grass"] = m6.commit()
	return out


# objetos colocados à mão no editor (os de construção; árvores e pedras vão em _build_nature)
func _build_added() -> void:
	b.begin(SEED + 777)
	for ent in edit_data["a"]:
		if not ent.get("k", "") in NAT_KINDS:
			b.add_new(ent)
	b.finish()


const NAT_KINDS := ["oak", "pine", "tall", "bush", "rock", "log"]
const BUSH_LAYER := 1 << 9


# árvore/pedra/moita/tronco: aplica o ajuste à mão e guarda (ou, no editor, vira um nó próprio)
var terrain_body: StaticBody3D   # colisão do chão (o carro não "bate" nele)
var floor_body: StaticBody3D     # colisão de asfalto, calçadas e cimento (idem)
var floor_faces := PackedVector3Array()
var footprints := []     # [tipo, centro, giro, meia largura, meia profundidade] de tudo que foi construído
var map_marks := []     # árvores, moitas e pedras (pontinhos no mapa)
var map_fields := []    # plantações (listras no mapa)
var map_streets := []   # ruas das cidades


func _nat(kind: String, xf: Transform3D, sets: Dictionary, key := "", e_over = null) -> void:
	if key == "":
		key = MapEdits.key(kind, xf.origin)
		while _nat_used.has(key):
			key += "'"
	_nat_used[key] = true
	var e: Dictionary = e_over if e_over != null else edit_data["e"].get(key, {})
	if editor:
		nat_reg[key] = [kind, xf, null]
	if bool(e.get("d", false)):
		return
	var x2 := MapEdits.nat_apply(xf, e)
	if kind != "grass":
		map_marks.append([kind, Vector2(x2.origin.x, x2.origin.z), x2.basis.get_scale().x])
	if editor and not headless:
		var n := Node3D.new()
		n.set_meta("key", key)
		add_child(n)
		var mi := MeshInstance3D.new()
		mi.mesh = _nat_meshes[kind]
		if (mi.mesh as Mesh).surface_get_material(0) == null:
			mi.material_override = U.wmat()
		mi.transform = x2
		mi.visibility_range_end = 260.0
		n.add_child(mi)
		var bd := StaticBody3D.new()
		bd.collision_mask = 0
		if kind == "bush":
			# só pra tocar no editor: camada própria, o boneco passa por dentro
			bd.collision_layer = BUSH_LAYER
		n.add_child(bd)
		_nat_col(kind, x2, bd)
		nat_reg[key][2] = n
		return
	sets[kind].append(x2)
	_nat_col(kind, x2, _nat_body)


func _nat_col(kind: String, xf: Transform3D, body: StaticBody3D) -> void:
	var sc := Vector3(xf.basis.x.length(), xf.basis.y.length(), xf.basis.z.length())
	var r := atan2(-xf.basis.x.z, xf.basis.x.x)
	match kind:
		"oak", "pine", "tall":
			var cs := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = 0.5 * sc.x
			cyl.height = 6.0 * sc.x
			cs.shape = cyl
			cs.position = xf.origin + Vector3(0, 3.0 * sc.x, 0)
			body.add_child(cs)
		"rock":
			_rock_col(body, xf)
		"log":
			var cs := CollisionShape3D.new()
			var cy := CylinderShape3D.new()
			cy.radius = 0.45 * sc.x
			cy.height = 7.0 * sc.x
			cs.shape = cy
			cs.transform = Transform3D(Basis(Vector3.UP, r) * Basis(Vector3.FORWARD, PI / 2.0), xf.origin + Vector3(0, 0.45 * sc.x, 0))
			body.add_child(cs)
		"bush":
			# moita não segura bala; só no editor tem caixa pra dar pra tocar nela
			if editor:
				var cs := CollisionShape3D.new()
				var bx := BoxShape3D.new()
				bx.size = Vector3(1.2, 1.0, 1.2) * sc.x
				cs.shape = bx
				cs.position = xf.origin + Vector3(0, 0.5 * sc.x, 0)
				body.add_child(cs)


static func added_nat_xf(ent: Dictionary) -> Transform3D:
	var k: String = ent["k"]
	var base := _nat_default_basis(k)
	if ent.has("b"):
		# forma guardada (pedra/tronco que veio do mapa gerado)
		var m: Array = ent["b"]
		base = Basis(Vector3(m[0], m[1], m[2]), Vector3(m[3], m[4], m[5]), Vector3(m[6], m[7], m[8]))
	var b := Basis.from_euler(Vector3(float(ent.get("tx", 0.0)), float(ent.get("r", 0.0)), float(ent.get("tz", 0.0)))) * base * float(ent.get("s", 1.0))
	return Transform3D(b, MapEdits.v3(ent["p"]))


static func _nat_default_basis(k: String) -> Basis:
	match k:
		"rock":
			return Basis.from_scale(Vector3(2.6, 1.7, 2.2))
		"bush":
			return Basis.from_scale(Vector3.ONE * 1.7)
	return Basis()


# editor: refaz uma árvore/pedra depois de mexer
func nat_rebuild(key: String, e_over = null) -> void:
	var info: Array = nat_reg[key]
	if info[2]:
		(info[2] as Node).free()
	_nat(info[0], info[1], {}, key, e_over)


func _build_nature() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 999
	var sets := {"oak": [], "pine": [], "tall": [], "bush": [], "rock": [], "grass": [], "log": []}
	var body := StaticBody3D.new()
	body.collision_mask = 0
	add_child(body)
	_nat_body = body
	if not headless:
		_nat_meshes = _tree_meshes()
	var lim := PLAY + 10.0
	# pedras grandes das pedreiras
	for e in _big_rocks:
		var p: Vector2 = e[0]
		var s: float = e[1]
		var sc := Vector3(s, s * float(e[3]), s * rng.randf_range(0.7, 1.1))
		var gp := Vector3(p.x, low_h(p, s * 0.45) + sc.y * 0.06, p.y)
		_nat("rock", Transform3D(Basis(Vector3.UP, e[2]) * Basis.from_scale(sc), gp), sets)
	var tries := 0
	var trees := 0
	while trees < 950 and tries < 30000:
		tries += 1
		var x := rng.randf_range(-lim, lim)
		var z := rng.randf_range(-lim, lim)
		# bosques ralos: um pouco mais de árvore onde o ruído é alto
		var f := noise2.get_noise_2d(x * 0.45, z * 0.45)
		if f < -0.1 and rng.randf() < 0.6:
			continue
		var p := Vector2(x, z)
		if _near_town(p, 3.0) or road_dist(x, z) < 6.0 or hw_dist(x, z) < 9.0 or rail_dist(p) < 7.0 or not is_free(p, 3.0):
			continue
		var h := height(x, z)
		if h < WATER_Y + 0.6:
			continue
		var s := rng.randf_range(0.8, 1.25)
		var r := rng.randf() * TAU
		var k := rng.randf()
		var kind := "oak" if k < 0.5 else ("pine" if k < 0.78 else "tall")
		# base afundada no ponto mais baixo em volta do tronco (sem flutuar no barranco)
		var gy := low_h(p, 0.5 * s) - 0.1
		var xf := Transform3D(Basis(Vector3.UP, r) * Basis.from_scale(Vector3(s, s * rng.randf_range(0.9, 1.15), s)), Vector3(x, gy, z))
		_nat(kind, xf, sets)
		trees += 1
		claim(p, 1.2)
	# moitas: escondem, mas a bala passa
	tries = 0
	var bushes := 0
	while bushes < 500 and tries < 8000:
		tries += 1
		var x := rng.randf_range(-lim, lim)
		var z := rng.randf_range(-lim, lim)
		var p := Vector2(x, z)
		if _near_town(p, -6.0) or road_dist(x, z) < 3.0 or hw_dist(x, z) < 6.0 or not is_free(p, 1.0) or height(x, z) < WATER_Y + 0.4:
			continue
		var s := rng.randf_range(1.3, 2.2)
		_nat("bush", Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(s, s, s)), Vector3(x, low_h(p, 0.45 * s) - 0.08, z)), sets)
		bushes += 1
	# pedras: cobertura que segura bala (algumas enormes)
	tries = 0
	var rocks := 0
	while rocks < 380 and tries < 9000:
		tries += 1
		var x := rng.randf_range(-lim, lim)
		var z := rng.randf_range(-lim, lim)
		var p := Vector2(x, z)
		if _near_town(p, 2.0) or road_dist(x, z) < 4.0 or hw_dist(x, z) < 8.0 or rail_dist(p) < 6.0 or not is_free(p, 2.0) or height(x, z) < WATER_Y + 0.4:
			continue
		var big := rng.randf() < 0.25
		var s := rng.randf_range(3.5, 7.5) if big else rng.randf_range(1.6, 3.5)
		var sc := Vector3(s, s * rng.randf_range(0.5, 0.85), s * rng.randf_range(0.7, 1.1))
		var r := rng.randf() * TAU
		var gp := Vector3(x, low_h(p, s * 0.45) + sc.y * 0.05, z)
		_nat("rock", Transform3D(Basis(Vector3.UP, r) * Basis.from_scale(sc), gp), sets)
		rocks += 1
		claim(p, s * 0.55)
		if rng.randf() < 0.3:
			var off := Vector3(cos(r), 0, sin(r)) * (maxf(sc.x, sc.z) * 0.6 + 0.8)
			var ip := Vector3(x + off.x, 0, z + off.z)
			ip.y = height(ip.x, ip.z) + 0.07
			add_item(ip, loot_kind(rng, false), null, null)
	# troncos caídos
	tries = 0
	var logs := 0
	while logs < 90 and tries < 3000:
		tries += 1
		var x := rng.randf_range(-lim, lim)
		var z := rng.randf_range(-lim, lim)
		var p := Vector2(x, z)
		if _near_town(p, 2.0) or road_dist(x, z) < 4.0 or hw_dist(x, z) < 9.0 or not is_free(p, 4.0) or _slope(p) > 0.15 or height(x, z) < WATER_Y + 0.4:
			continue
		var r := rng.randf() * TAU
		var gp := Vector3(x, low_h(p, 3.5) - 0.1, z)
		_nat("log", Transform3D(Basis(Vector3.UP, r), gp), sets)
		logs += 1
		claim(p, 4.0)
	# árvores e pedras colocadas à mão
	for ent in edit_data["a"]:
		var k: String = ent.get("k", "")
		if k in NAT_KINDS:
			var sc := float(ent.get("s", 1.0))
			_nat(k, added_nat_xf(ent), sets, "+%d" % int(ent.get("n", 1)), {})
	if headless:
		return
	if quality >= 1 and not editor:
		var gl := PLAY - 5.0
		var gcount := 22000 if quality == 1 else 50000
		tries = 0
		while sets["grass"].size() < gcount and tries < gcount * 3:
			tries += 1
			var x := rng.randf_range(-gl, gl)
			var z := rng.randf_range(-gl, gl)
			if town_factor(x, z) > 0.3 or road_dist(x, z) < 4.0 or hw_dist(x, z) < 6.0:
				continue
			var h := grid_h(x, z)
			if h < WATER_Y + 0.5 or h > 45.0:
				continue
			var s := rng.randf_range(0.7, 1.5)
			sets["grass"].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(s, s, s)), Vector3(x, h - 0.05, z)))
	var meshes := _nat_meshes
	var tint := RandomNumberGenerator.new()
	tint.seed = SEED + 3
	for k in sets:
		var chunk := 32.0 if k == "grass" else 80.0
		_scatter(k, meshes[k], sets[k], chunk, tint, meshes.get(k + "_lo"))
	set_view(300.0)


# colisão arredondada (casco convexo de um elipsoide) pra não entrar na pedra
# colisão da pedra = casco convexo do próprio desenho dela (não dá pra entrar com parte do corpo)
var _rock_pts := PackedVector3Array()


func _rock_col(body: StaticBody3D, xf: Transform3D) -> void:
	if _rock_pts.is_empty():
		var m: Mesh = _nat_meshes["rock"] if _nat_meshes.has("rock") else _tree_meshes()["rock"]
		var seen := {}
		for v: Vector3 in (m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			var k := Vector3i(roundi(v.x * 200.0), roundi(v.y * 200.0), roundi(v.z * 200.0))
			if not seen.has(k):
				seen[k] = true
				_rock_pts.append(v)
	var pts := PackedVector3Array()
	for v in _rock_pts:
		pts.append(xf.basis * v * 1.02)
	var sh := ConvexPolygonShape3D.new()
	sh.points = pts
	var cs := CollisionShape3D.new()
	cs.shape = sh
	cs.position = xf.origin
	body.add_child(cs)


# Espalha instâncias em blocos (MultiMesh por bloco), pra o motor descartar o que está longe.
# Com "lo", cada bloco tem uma versão simples que aparece de longe.
func _scatter(kind: String, mesh: Mesh, xfs: Array, chunk: float, rng: RandomNumberGenerator, lo: Mesh = null) -> void:
	if xfs.is_empty():
		return
	var buckets := {}
	for xf: Transform3D in xfs:
		var key := Vector2i(floori(xf.origin.x / chunk), floori(xf.origin.z / chunk))
		if not buckets.has(key):
			buckets[key] = []
		buckets[key].append(xf)
	for key in buckets:
		var list: Array = buckets[key]
		var center := Vector3((key.x + 0.5) * chunk, 0, (key.y + 0.5) * chunk)
		var cols := []
		for i in list.size():
			var k := rng.randf_range(0.8, 1.1)
			cols.append(Color(k, k * rng.randf_range(0.94, 1.06), k))
		for variant in ([mesh] if lo == null else [mesh, lo]):
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = variant
			mm.instance_count = list.size()
			for i in list.size():
				var xf: Transform3D = list[i]
				xf.origin -= center
				mm.set_instance_transform(i, xf)
				mm.set_instance_color(i, cols[i])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			# malha com material próprio (árvores com textura) não usa o material do mundo
			if (variant as Mesh).surface_get_material(0) == null:
				mmi.material_override = U.wmat()
			mmi.position = center
			if kind == "grass" or kind == "bush" or variant == lo:
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mmi)
			_scatter_nodes.append([mmi, kind if variant == mesh else kind + "_lo", lo != null])


func show_grass(on: bool) -> void:
	for e in _scatter_nodes:
		if e[1] == "grass":
			(e[0] as Node3D).visible = on


# Distância de visão da vegetação (depende da qualidade gráfica)
func set_view(dist: float) -> void:
	var lod := clampf(dist * 0.35, 75.0, 140.0)
	for e in _scatter_nodes:
		var mmi: MultiMeshInstance3D = e[0]
		var kind: String = e[1]
		var has_lo: bool = e[2]
		match kind:
			"grass":
				mmi.visibility_range_end = 45.0
			"bush":
				mmi.visibility_range_end = minf(dist, 160.0) + 40.0
			"log":
				mmi.visibility_range_end = minf(dist, 200.0) + 40.0
			_:
				if kind.ends_with("_lo"):
					mmi.visibility_range_begin = lod
					mmi.visibility_range_end = dist + 60.0
				elif has_lo:
					mmi.visibility_range_begin = 0.0
					mmi.visibility_range_end = lod
				else:
					mmi.visibility_range_end = dist + 60.0


# Área de aquecimento: um pátio cercado longe do mapa, onde todos esperam o avião.
func _build_lobby() -> void:
	b.begin(SEED + 777)
	var rng := b.rng
	var root := b.body(LOBBY_P, 0.0)
	var L := LOBBY_HALF
	b.piece(root, Vector3(L * 2.0 + 2.0, 0.4, L * 2.0 + 2.0), Vector3(0, -0.2, 0), Color(0.78, 0.78, 0.76), U.CONCRETE, 0.25)
	# faixas pintadas no chão
	if not headless:
		for k in [-1.0, 0.0, 1.0]:
			b.vis(root, Vector3(L * 2.0, 0.02, 0.25), Vector3(0, 0.01, k * L * 0.5), Color(0.95, 0.85, 0.3), U.PLAIN, 1.0)
		b.vis(root, Vector3(0.25, 0.02, L * 2.0), Vector3(0, 0.01, 0), Color(0.95, 0.85, 0.3), U.PLAIN, 1.0)
	# muro em volta (com colisão alta invisível pra ninguém cair)
	for side in 4:
		var rot := Basis(Vector3.UP, side * PI / 2.0)
		b.piece(root, Vector3(L * 2.0 + 2.0, 1.3, 0.3), rot * Vector3(0, 0.65, L + 0.85), Color(0.85, 0.85, 0.82), U.CONCRETE, 0.4, true, rot)
		b.col_box(root, Vector3(L * 2.0 + 2.0, 12.0, 0.6), rot * Vector3(0, 6.0, L + 1.1), rot)
		# grade por cima do muro
		if not headless:
			for i in 23:
				var x := -L + i * (L * 2.0 / 22.0)
				b.vis(root, Vector3(0.08, 1.6, 0.08), rot * Vector3(x, 2.1, L + 0.85), Color(0.5, 0.5, 0.5), U.METAL, 0.5, rot)
			b.vis(root, Vector3(L * 2.0 + 2.0, 0.08, 0.08), rot * Vector3(0, 2.9, L + 0.85), Color(0.5, 0.5, 0.5), U.METAL, 0.5, rot)
	# coberturas pra aquecer a mira
	for k in 10:
		var p := Vector2(rng.randf_range(-L + 5.0, L - 5.0), rng.randf_range(-L + 5.0, L - 5.0))
		if p.length() < 6.0:
			continue
		_lobby_cover.append(p)
		var q := LOBBY_P + Vector3(p.x, 0, p.y)
		var kk := k % 3
		if kk == 0:
			b.crates(q, rng.randf() * TAU, false)
		elif kk == 1:
			b.sandbags(q, rng.randf() * TAU, 3.0)
		else:
			b.barrier(q, rng.randf() * TAU)
	# alvos de tiro numa ponta
	if not headless:
		for i in 5:
			var x := -L * 0.6 + i * L * 0.3
			b.vis(root, Vector3(0.1, 1.6, 0.1), Vector3(x, 0.8, -L + 1.2), Color(0.5, 0.4, 0.3), U.WOOD, 0.5)
			b.vis(root, Vector3(0.9, 1.1, 0.06), Vector3(x, 1.5, -L + 1.25), Color(0.95, 0.95, 0.92), U.PLAIN, 1.0)
			b.vis(root, Vector3(0.45, 0.55, 0.07), Vector3(x, 1.5, -L + 1.25), Color(0.85, 0.2, 0.15), U.PLAIN, 1.0)
	b.finish(300.0)


func _build_bounds() -> void:
	var body := StaticBody3D.new()
	body.collision_mask = 0
	add_child(body)
	var half := PLAY + 12.0
	for k in 4:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		var horiz := k < 2
		bs.size = Vector3(SIZE, 800, 2) if horiz else Vector3(2, 800, SIZE)
		cs.shape = bs
		var sg := -1.0 if k % 2 == 0 else 1.0
		cs.position = Vector3(0, 0, sg * half) if horiz else Vector3(sg * half, 0, 0)
		body.add_child(cs)


# Mapa visto de cima (minimapa)
# Mapa visto de cima (minimapa e mapa grande): 1024 px, com estradas, rodovias, trilho,
# casas e lagoa desenhados nítidos por cima do relevo
const MAP_PX := 2048


func _build_map(wts: PackedColorArray) -> void:
	var n := RES + 1
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var cg := Color(0.42, 0.55, 0.27)
	var cg2 := Color(0.33, 0.46, 0.22)
	var cd := Color(0.66, 0.55, 0.38)
	var cr := Color(0.58, 0.57, 0.53)
	var cs := Color(0.8, 0.73, 0.54)
	var cell := SIZE / RES
	var light := Vector3(-0.6, 0.75, -0.45).normalized()   # sol do noroeste
	for j in n:
		for i in n:
			var c: Color = wts[j * n + i]
			var gw := clampf(1.0 - c.r - c.g - c.b, 0.0, 1.0)
			# grama com dois tons (manchas), terra, pedra e areia
			var gc := cg.lerp(cg2, clampf(noise2.get_noise_2d(i * 7.0, j * 7.0) * 1.2 + 0.5, 0.0, 1.0))
			var col := gc * gw + cd * c.r + cr * c.g + cs * c.b
			col = col.lightened((c.a - 0.5) * 0.1)
			# relevo sombreado (luz do noroeste) + morro um pouco mais claro: dá pra "ver" a altura
			var hx := _hs[j * n + mini(i + 1, n - 1)] - _hs[j * n + maxi(i - 1, 0)]
			var hz := _hs[mini(j + 1, n - 1) * n + i] - _hs[maxi(j - 1, 0) * n + i]
			var nr := Vector3(-hx / (2.0 * cell), 1.0, -hz / (2.0 * cell)).normalized()
			var sh := clampf(nr.dot(light) / light.y, 0.55, 1.25)
			col = Color(col.r * sh, col.g * sh, col.b * sh)
			col = col.lightened(clampf(_hs[j * n + i] / 160.0, -0.1, 0.14))
			img.set_pixel(i, j, col)
	img.resize(MAP_PX, MAP_PX, Image.INTERPOLATE_CUBIC)
	var px := MAP_PX / SIZE
	var off := Vector2(SIZE, SIZE) / 2.0
	# plantações: listras
	for f in map_fields:
		var fc: Vector2 = f[0]
		var fw: float = f[1]
		var fd: float = f[2]
		var rot := Vector2(cos(f[3]), sin(f[3]))
		var col: Color = f[4]
		var cp := (fc + off) * px
		var ext := (fw + fd) * 0.5 * px
		for y in range(int(cp.y - ext), int(cp.y + ext) + 1):
			for x in range(int(cp.x - ext), int(cp.x + ext) + 1):
				if x < 0 or y < 0 or x >= MAP_PX or y >= MAP_PX:
					continue
				var d := (Vector2(x, y) - cp) / px
				var lx := d.x * rot.x - d.y * rot.y
				var lz := d.x * rot.y + d.y * rot.x
				if absf(lx) <= fw / 2.0 and absf(lz) <= fd / 2.0:
					var row := int((lx + fw / 2.0) / 1.3) % 2 == 0
					img.set_pixel(x, y, col.darkened(0.18) if row else col.lightened(0.05))
	# lagoa com borda nítida
	var lc := (LAKE_C + off) * px
	var lr := (LAKE_R + 1.0) * px
	for y in range(int(lc.y - lr), int(lc.y + lr) + 1):
		for x in range(int(lc.x - lr), int(lc.x + lr) + 1):
			var d := Vector2(x, y).distance_to(lc)
			if d < lr and x >= 0 and y >= 0 and x < MAP_PX and y < MAP_PX:
				var wc := Color(0.2, 0.44, 0.58).lerp(Color(0.14, 0.33, 0.48), clampf(1.0 - d / lr, 0.0, 1.0))
				img.set_pixel(x, y, wc if d < lr - 3.0 else Color(0.86, 0.82, 0.64))
	# pedras, moitas e árvores: pontinhos com sombra (copa verde-escura)
	for mk in map_marks:
		var q: Vector2 = (Vector2(mk[1]) + off) * px
		var sc: float = mk[2]
		match mk[0]:
			"rock":
				_map_dot(img, q, maxf(1.2, sc * 0.5 * px * 0.5), Color(0.62, 0.6, 0.56), 0.7)
			"bush":
				_map_dot(img, q, maxf(1.2, sc * 0.45 * px * 0.5), Color(0.3, 0.42, 0.18), 0.6)
			"log":
				_map_dot(img, q, 1.2, Color(0.4, 0.3, 0.2), 0.5)
			_:
				_map_dot(img, q, maxf(2.0, 2.2 * sc * px * 0.5), Color(0.2, 0.33, 0.14) if mk[0] != "pine" else Color(0.15, 0.27, 0.13), 1.0)
	# estradas de terra (com borda)
	for r in roads:
		_map_line(img, (r[0] + off) * px, (r[1] + off) * px, 4, Color(0.5, 0.42, 0.3))
	for r in roads:
		_map_line(img, (r[0] + off) * px, (r[1] + off) * px, 3, Color(0.78, 0.66, 0.46))
	# ruas das cidades (asfalto com calçada)
	for st in map_streets:
		_map_line(img, (Vector2(st[0]) + off) * px, (Vector2(st[1]) + off) * px, int(float(st[2]) * 0.5 * px) + 1, Color(0.62, 0.6, 0.56))
	for st in map_streets:
		_map_line(img, (Vector2(st[0]) + off) * px, (Vector2(st[1]) + off) * px, int(float(st[2]) * 0.5 * px) - 1, Color(0.3, 0.3, 0.32))
	# trilho
	for i in RAIL.size() - 1:
		_map_line(img, (RAIL[i] + off) * px, (RAIL[i + 1] + off) * px, 2, Color(0.4, 0.33, 0.28))
	for i in RAIL.size() - 1:
		if i % 2 == 0:
			_map_line(img, (RAIL[i] + off) * px, (RAIL[i + 1] + off) * px, 0, Color(0.7, 0.68, 0.62))
	# rodovias asfaltadas com borda clara e faixa no meio
	for line in hw_pts:
		for i in line.size() - 1:
			_map_line(img, (Vector2(line[i][0]) + off) * px, (Vector2(line[i + 1][0]) + off) * px, 7, Color(0.62, 0.6, 0.56))
		for i in line.size() - 1:
			_map_line(img, (Vector2(line[i][0]) + off) * px, (Vector2(line[i + 1][0]) + off) * px, 6, Color(0.24, 0.24, 0.26))
		for i in line.size() - 1:
			if i % 2 == 0:
				_map_line(img, (Vector2(line[i][0]) + off) * px, (Vector2(line[i + 1][0]) + off) * px, 0, Color(0.95, 0.82, 0.3))
	# casas: sombra, telhado com cumeeira e borda
	for h in houses:
		var yaw: float = h["yaw"]
		var hw: float = h["w"] / 2.0
		var hd: float = h["d"] / 2.0
		var c: Vector2 = (Vector2(h["pos"]) + off) * px
		var ext := (hw + hd) * px + 6.0
		var rot := Vector2(cos(yaw), sin(yaw))
		var hh := absi(hash(Vector2i(int(c.x), int(c.y))))
		var roof: Color = [Color(0.62, 0.33, 0.26), Color(0.5, 0.48, 0.46), Color(0.55, 0.4, 0.3), Color(0.68, 0.42, 0.3)][hh % 4]
		var shadow := Vector2(1.6, 1.6) * px
		for pass_i in 2:
			for y in range(int(c.y - ext), int(c.y + ext) + 1):
				for x in range(int(c.x - ext), int(c.x + ext) + 1):
					if x < 0 or y < 0 or x >= MAP_PX or y >= MAP_PX:
						continue
					var d := (Vector2(x, y) - c - (shadow if pass_i == 0 else Vector2.ZERO)) / px
					# casa gira no sentido do Basis(UP, yaw): x' = x cos + z sin ; z' = -x sin + z cos
					var lx := d.x * rot.x - d.y * rot.y
					var lz := d.x * rot.y + d.y * rot.x
					if absf(lx) <= hw and absf(lz) <= hd:
						if pass_i == 0:
							img.set_pixel(x, y, img.get_pixel(x, y).darkened(0.35))
							continue
						var edge := absf(lx) > hw - 0.5 or absf(lz) > hd - 0.5
						var half := roof.darkened(0.12) if lz > 0.0 else roof.lightened(0.08)
						img.set_pixel(x, y, Color(0.18, 0.15, 0.13) if edge else half)
	img.generate_mipmaps()
	map_tex = ImageTexture.create_from_image(img)


func _map_dot(img: Image, q: Vector2, r: float, col: Color, shadow: float) -> void:
	var ri := int(ceil(r)) + 2
	for dy in range(-ri, ri + 1):
		for dx in range(-ri, ri + 1):
			var x := int(q.x) + dx
			var y := int(q.y) + dy
			if x < 0 or y < 0 or x >= MAP_PX or y >= MAP_PX:
				continue
			var d := Vector2(dx, dy).length()
			var ds := Vector2(dx - r * 0.5, dy - r * 0.5).length()
			if d <= r:
				# copa com um lado iluminado
				var k := clampf((dx + dy) / (r * 2.0 + 0.01), -1.0, 1.0)
				img.set_pixel(x, y, col.lightened(0.12 * -k) if k < 0.0 else col.darkened(0.15 * k))
			elif ds <= r and shadow > 0.0:
				img.set_pixel(x, y, img.get_pixel(x, y).darkened(0.25 * shadow))


func _map_line(img: Image, a: Vector2, b: Vector2, r: int, col: Color) -> void:
	var n := int(a.distance_to(b)) + 1
	for t in n + 1:
		var p := a.lerp(b, float(t) / n)
		var x := int(p.x)
		var y := int(p.y)
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if dx * dx + dy * dy <= r * r + r and x + dx >= 0 and y + dy >= 0 and x + dx < MAP_PX and y + dy < MAP_PX:
					img.set_pixel(x + dx, y + dy, col)


# colunas de fumaça subindo ao longe (coisa queimando): dá o clima de guerra de qualquer ponto do mapa
var smoke_spots := []


static func smoke_tex() -> Texture2D:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var nz := FastNoiseLite.new()
	nz.frequency = 0.09
	for y in n:
		for x in n:
			var d := Vector2(x - n / 2.0, y - n / 2.0).length() / (n / 2.0)
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a * (0.65 + 0.35 * (nz.get_noise_2d(x, y) * 0.5 + 0.5))
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _build_smoke() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 31
	var tex := smoke_tex()
	var spots := smoke_spots.duplicate()
	for k in 5:
		spots.append(Vector2(rng.randf_range(-PLAY, PLAY), rng.randf_range(-PLAY, PLAY)))
	# e umas bem longe, fora do mapa (o horizonte também está em guerra)
	for k in 4:
		var a := rng.randf() * TAU
		spots.append(Vector2(cos(a), sin(a)) * rng.randf_range(520.0, 700.0))
	for sp: Vector2 in spots:
		var big := sp.length() > 450.0
		var ps := CPUParticles3D.new()
		ps.amount = 18 if big else 14
		ps.lifetime = 16.0 if big else 11.0
		ps.preprocess = 3.0
		ps.local_coords = false
		var qm := QuadMesh.new()
		qm.size = Vector2(1, 1) * (26.0 if big else 9.0)
		var m := StandardMaterial3D.new()
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.albedo_texture = tex
		m.disable_receive_shadows = true
		qm.material = m
		ps.mesh = qm
		ps.direction = Vector3(0.25, 1, 0.1)
		ps.spread = 12.0
		ps.gravity = Vector3(0.6, 0.9, 0.2)
		ps.initial_velocity_min = 2.0 if not big else 5.0
		ps.initial_velocity_max = 3.5 if not big else 8.0
		ps.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		ps.emission_sphere_radius = 1.5 if not big else 6.0
		var sc := Curve.new()
		sc.add_point(Vector2(0, 0.35))
		sc.add_point(Vector2(1, 1.6))
		ps.scale_amount_curve = sc
		ps.angle_min = 0.0
		ps.angle_max = 360.0
		var g := Gradient.new()
		g.set_color(0, Color(0.16, 0.15, 0.14, 0.75))
		g.set_color(1, Color(0.45, 0.44, 0.42, 0.0))
		ps.color_ramp = g
		ps.position = Vector3(sp.x, height(sp.x, sp.y) + 1.0 if not big else 40.0, sp.y)
		ps.visibility_aabb = AABB(Vector3(-80, -10, -80), Vector3(160, 260, 160))
		ps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ps)


func _build_env() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	# dia nublado e pesado (pré-guerra): céu cinza, sol fraco, névoa de poeira e fumaça
	sm.sky_top_color = Color(0.4, 0.44, 0.49)
	sm.sky_horizon_color = Color(0.64, 0.64, 0.62)
	sm.ground_horizon_color = Color(0.56, 0.55, 0.52)
	sm.ground_bottom_color = Color(0.42, 0.41, 0.39)
	sm.sky_curve = 0.18
	sm.sun_angle_max = 40.0
	sm.sun_curve = 0.6
	sky.sky_material = sm
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.64, 0.64, 0.64)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.6, 0.59, 0.56)
	env.fog_density = 0.0032
	env.fog_sky_affect = 0.55
	# cores mais secas e frias (o mundo parece cansado)
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.72
	env.adjustment_contrast = 1.06
	env.adjustment_brightness = 0.98
	# chão em volta do mapa até o horizonte (só visual)
	var mb := MB.new()
	mb.tex(U.GRASS, 0.02)
	var h := SIZE / 2.0
	var far := 4000.0
	var y := 40.0
	var oc := Color(0.62, 0.62, 0.54)
	var rects := [[-far, -far, far, -h], [-far, h, far, far], [-far, -h, -h, h], [h, -h, far, h]]
	for r in rects:
		mb.quad(Vector3(r[0], y, r[1]), Vector3(r[2], y, r[1]), Vector3(r[2], y, r[3]), Vector3(r[0], y, r[3]), oc, Vector3.UP)
	var ring := MeshInstance3D.new()
	ring.mesh = mb.commit()
	ring.material_override = U.wmat()
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	# lagoa
	# lagoa rasa: disco que termina antes da margem (não aparece pedaço de água fora dela)
	var water := MeshInstance3D.new()
	var wmb := MB.new()
	var seg := 48
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		for rg in 2:
			var r0 := (LAKE_R + 1.0) * (0.5 * rg)
			var r1 := (LAKE_R + 1.0) * (0.5 * (rg + 1))
			var p00 := Vector3(cos(a0) * r0, 0, sin(a0) * r0)
			var p01 := Vector3(cos(a1) * r0, 0, sin(a1) * r0)
			var p10 := Vector3(cos(a0) * r1, 0, sin(a0) * r1)
			var p11 := Vector3(cos(a1) * r1, 0, sin(a1) * r1)
			wmb.quad(p00, p10, p11, p01, Color.WHITE, Vector3.UP)
	water.mesh = wmb.commit()
	var wm := ShaderMaterial.new()
	wm.shader = load("res://shaders/water.gdshader")
	water.material_override = wm
	water.position = Vector3(LAKE_C.x, WATER_Y, LAKE_C.y)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	var we := WorldEnvironment.new()
	we.name = "Env"
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-48, 35, 0)
	sun.light_color = Color(0.94, 0.91, 0.85)
	sun.light_energy = 0.78
	sun.shadow_enabled = true
	sun.shadow_blur = 1.0
	sun.directional_shadow_max_distance = 40.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	add_child(sun)


# ---------------- pontos ----------------

func clamp_play(p: Vector2, margin := 10.0) -> Vector2:
	var l := PLAY - margin
	return p.clamp(Vector2(-l, -l), Vector2(l, l))


func ground_pos(p: Vector2, up := 0.4) -> Vector3:
	return Vector3(p.x, height(p.x, p.y) + up, p.y)


# todo mundo nasce junto na área de aquecimento (fora do mapa)
func random_spawn(rng: RandomNumberGenerator) -> Vector3:
	return lobby_point(rng) + Vector3(0, 0.6, 0)


func lobby_point(rng: RandomNumberGenerator) -> Vector3:
	var half := LOBBY_HALF - 3.0
	for k in 12:
		var p := Vector2(rng.randf_range(-half, half), rng.randf_range(-half, half))
		var ok := true
		for c in _lobby_cover:
			if p.distance_to(c) < 3.0:
				ok = false
				break
		if ok:
			return LOBBY_P + Vector3(p.x, 0.05, p.y)
	return LOBBY_P + Vector3(0, 0.05, 0)


func in_lobby(p: Vector3) -> bool:
	return absf(p.x - LOBBY_P.x) < LOBBY_HALF + 20.0 and absf(p.z - LOBBY_P.z) < LOBBY_HALF + 20.0


func map_spawn(rng: RandomNumberGenerator) -> Vector3:
	for k in 20:
		var t: Dictionary = towns[rng.randi() % towns.size()]
		var a := rng.randf() * TAU
		var r := float(t["r"]) + rng.randf_range(4.0, 16.0)
		var p: Vector2 = clamp_play(t["pos"] + Vector2(cos(a), sin(a)) * r)
		if is_free(p, 1.0) and height(p.x, p.y) > WATER_Y + 0.5:
			return ground_pos(p, 1.0)
	return ground_pos(Vector2.ZERO, 2.0)


func random_point_in(c: Vector2, r: float, rng: RandomNumberGenerator) -> Vector3:
	var p := c
	for k in 8:
		var a := rng.randf() * TAU
		p = clamp_play(c + Vector2(cos(a), sin(a)) * sqrt(rng.randf()) * r)
		if height(p.x, p.y) > WATER_Y + 0.3:
			break
	return ground_pos(p, 0.0)


func nearest_town(p: Vector2) -> Dictionary:
	var best: Dictionary = towns[0]
	var bd := 1e9
	for t in towns:
		var d := p.distance_to(t["pos"])
		if d < bd:
			bd = d
			best = t
	return best


func in_water(p: Vector3) -> bool:
	return p.y < WATER_Y - 0.25 and Vector2(p.x, p.z).distance_to(LAKE_C) < LAKE_R + 30.0
