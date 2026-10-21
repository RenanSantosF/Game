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
	["Brejo Seco", Vector2(-300, -115), "bairro", 40.0],
	["Serraria Toco Velho", Vector2(-160, -150), "serraria", 30.0],
	["Pouso Velho", Vector2(-35, -135), "igreja", 40.0],
	["Posto Alvorada", Vector2(110, -160), "posto", 26.0],
	["Fazenda Taquaral", Vector2(225, -70), "fazenda", 42.0],
	["Vale do Corvo", Vector2(-205, 5), "bairro", 42.0],
	["Bela Poeira", Vector2(25, -10), "centro", 58.0],
	["Estação Carvoeira", Vector2(175, 40), "estacao", 34.0],
	["Ruínas do Engenho", Vector2(305, 110), "ruinas", 30.0],
	["Chapada Ventania", Vector2(-320, 135), "esparso", 42.0],
	["Ponte Partida", Vector2(-100, 100), "ruinas", 26.0],
	["Colônia Caracol", Vector2(-205, 205), "vila", 36.0],
	["Mina do Tatu", Vector2(-300, 305), "pedreira", 34.0],
	["Porto Lambari", Vector2(-80, 205), "porto", 24.0],
	["Sítio Três Pinheiros", Vector2(90, 155), "fazenda", 32.0],
	["Rancho Poeira", Vector2(250, 205), "esparso", 36.0],
	["Granja Galo Doido", Vector2(120, 300), "fazenda", 34.0],
	["Vila Cachorro Magro", Vector2(295, 300), "vila", 34.0],
]
# morros grandes: centro, altura, raio
const MOUNTS := [
	[Vector2(305, -170), 42.0, 75.0], [Vector2(-335, 135), 26.0, 85.0], [Vector2(235, -315), 34.0, 70.0],
	[Vector2(-60, -340), 28.0, 60.0], [Vector2(-330, -330), 30.0, 70.0], [Vector2(330, 340), 22.0, 60.0],
	[Vector2(110, 60), 14.0, 55.0], [Vector2(-160, -70), 18.0, 55.0],
]
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
var b: Build


func build(is_headless: bool, q := 1) -> void:
	headless = is_headless
	quality = q
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
		towns.append({"name": t[0], "pos": t[1], "kind": t[2], "r": t[3], "h": 0.0})
	for t in towns:
		t["h"] = _base(t["pos"].x, t["pos"].y)
	_make_highways()
	_make_roads()
	b = Build.new(self)
	var wts := _build_terrain()
	for i in towns.size():
		_build_loc(i)
	_build_highway_props()
	_build_extras()
	_build_nature()
	_build_bounds()
	_build_lobby()
	if not headless:
		_build_highway_mesh()
		_build_map(wts)
		_build_env()


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
	for t in towns:
		var d: float = Vector2(x, z).distance_to(t["pos"])
		var r: float = t["r"]
		if d < r + 40.0:
			var th: float = t["h"]
			if t["kind"] == "pedreira" and d < r * 0.8:
				th -= 6.0 * (1.0 - smoothstep(r * 0.55, r * 0.8, d))
			h = lerpf(th, h, smoothstep(r, r + 40.0, d))
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
	return h


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
		var pts := _catmull(poly, 6.0)
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
	var r := rng.randf()
	var styles := ["plaster", "plaster", "plaster", "brick", "wood"]
	var st: String = styles[rng.randi() % styles.size()]
	if r < (0.15 if big else 0.07):
		return {"w": rng.randf_range(8.5, 10.5), "d": rng.randf_range(8.0, 9.0), "floors": 2, "style": "plaster" if st == "wood" else st,
			"roof": "tile" if rng.randf() < 0.75 else "flat", "balcony": rng.randf() < 0.7}
	if r < 0.45:
		return {"w": rng.randf_range(10.0, 12.0), "d": rng.randf_range(7.5, 8.5), "rooms": 2, "style": st, "porch": rng.randf() < 0.4}
	return {"w": rng.randf_range(7.0, 9.0), "d": rng.randf_range(6.0, 7.5), "style": st, "porch": rng.randf() < 0.35}


func _build_loc(ti: int) -> void:
	var t: Dictionary = towns[ti]
	b.begin(SEED + ti * 31)
	var c: Vector2 = t["pos"]
	var y: float = t["h"]
	var r: float = t["r"]
	match t["kind"]:
		"vila":
			_vila(c, y, r, false)
		"igreja":
			_vila(c, y, r, true)
		"bairro":
			_bairro(c, y, r, false)
		"centro":
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
	b.finish()


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


func _vila(c: Vector2, y: float, r: float, church: bool) -> void:
	var rng := b.rng
	var n := rng.randi_range(5, 8)
	var a0 := rng.randf() * TAU
	if church:
		b.church(_p3(c, y), rng.randf() * TAU)
	else:
		b.well(_p3(c + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3)), y))
	for k in n:
		var ang := a0 + TAU * k / n + rng.randf_range(-0.3, 0.3)
		var dist := r * rng.randf_range(0.5, 0.85)
		var p := c + Vector2(cos(ang), sin(ang)) * dist
		var yaw := _face(p, c) + rng.randf_range(-0.45, 0.45)
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


func _street(a: Vector2, c: Vector2, y: float, width := 6.0) -> void:
	if headless:
		return
	var d := c - a
	var yaw := -atan2(d.y, d.x)
	var mid := (a + c) / 2.0
	b.mb.tex(U.ASPHALT, 0.25)
	b.mb.box(Transform3D(Basis(Vector3.UP, yaw), Vector3(mid.x, y + 0.02, mid.y)), Vector3(d.length(), 0.04, width), Color(1, 1, 1))
	var side := Vector2(-d.normalized().y, d.normalized().x)
	for s in [-1.0, 1.0]:
		var q: Vector2 = mid + side * s * (width / 2.0 + 0.8)
		b.mb.tex(U.CONCRETE, 0.4)
		b.mb.box(Transform3D(Basis(Vector3.UP, yaw), Vector3(q.x, y + 0.05, q.y)), Vector3(d.length(), 0.1, 1.6), Color(0.95, 0.95, 0.92))
	# faixa
	b.mb.tex(U.PLAIN, 1.0)
	var n := int(d.length() / 6.0)
	for i in n:
		var q := a + d * ((i + 0.5) / n)
		b.mb.box(Transform3D(Basis(Vector3.UP, yaw), Vector3(q.x, y + 0.045, q.y)), Vector3(2.0, 0.01, 0.14), Color(0.9, 0.85, 0.5))


func _bairro(c: Vector2, y: float, r: float, big: bool) -> void:
	var rng := b.rng
	var th := rng.randf() * TAU
	var dir := Vector2(cos(th), sin(th))
	var side := Vector2(-dir.y, dir.x)
	var streets := [[c - dir * r, c + dir * r, dir, side]]
	if big or rng.randf() < 0.5:
		var off := rng.randf_range(-r * 0.25, r * 0.25)
		streets.append([c + dir * off - side * r * 0.85, c + dir * off + side * r * 0.85, side, -dir])
	for s in streets:
		_street(s[0], s[1], y)
		var sa: Vector2 = s[0]
		var sb: Vector2 = s[1]
		var sd: Vector2 = s[2]
		var sn: Vector2 = s[3]
		var L := sa.distance_to(sb)
		var x := 6.0
		while x < L - 6.0:
			for sgn in [-1.0, 1.0]:
				if rng.randf() < 0.18:
					continue
				var spec := _house_spec(rng, big)
				var off: float = 4.4 + spec["d"] / 2.0 + rng.randf_range(0.5, 2.5)
				var p: Vector2 = sa + sd * x + sn * sgn * off
				if not is_free(p, maxf(spec["w"], spec["d"]) * 0.45):
					continue
				var yaw := _face(p, p - sn * sgn)
				if big and rng.randf() < 0.12:
					b.store(_p3(p, y), yaw)
				else:
					b.house(_p3(p, y), yaw, spec)
				if rng.randf() < 0.3:
					var fa: Vector2 = p - sn * sgn * (spec["d"] / 2.0 + 1.6) - sd * (spec["w"] / 2.0)
					b.low_wall(fa, fa + sd * spec["w"] * 0.35, y)
			x += rng.randf_range(12.5, 16.0)
		for k in rng.randi_range(2, 4):
			var p: Vector2 = sa + sd * rng.randf_range(8.0, L - 8.0) + sn * (2.0 if rng.randf() < 0.5 else -2.0)
			if is_free(p, 2.5):
				b.car(_p3(p, y), atan2(-sd.x, -sd.y) + (PI if rng.randf() < 0.5 else 0.0) + rng.randf_range(-0.1, 0.1))
	if big:
		# praça com caixa d'água, barreiras e caixotes
		b.water_tower(_p3(c + side * 9.0 + dir * 9.0, y))
		for k in 3:
			var p := c + Vector2(rng.randf_range(-7, 7), rng.randf_range(-7, 7))
			if is_free(p, 2.0):
				b.barrier(_p3(p, y), rng.randf() * TAU)
		b.crates(_p3(c - side * 7.0 - dir * 5.0, y), rng.randf() * TAU)


func _esparso(c: Vector2, y: float, r: float) -> void:
	var rng := b.rng
	var n := rng.randi_range(3, 5)
	var placed := []
	var tries := 0
	while placed.size() < n and tries < 60:
		tries += 1
		var p := c + Vector2(rng.randf_range(-r * 0.8, r * 0.8), rng.randf_range(-r * 0.8, r * 0.8))
		var ok := true
		for q in placed:
			if p.distance_to(q) < 16.0:
				ok = false
		if not ok:
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
	b.silo(_p3(c - dir * r * 0.35 + side * 11.0, y))
	b.silo(_p3(c - dir * r * 0.35 + side * 16.0, y))
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
	# casinhas na borda de cima
	for k in 2:
		var a := rng.randf() * TAU
		var p := c + Vector2(cos(a), sin(a)) * (r + 8.0)
		b.house(_p3(p, height(p.x, p.y) - 0.1), _face(p, c), _house_spec(rng))


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
	while covers < 70 and tries < 1500:
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
	# Árvores ralas e baixas (estilo FF): copa feita de poucos tufos separados, com
	# buracos por onde se vê através; tronco fino. "_lo" = mesma silhueta, menos polígonos.
	var specs := {
		# [altura do tronco, raio do tronco, tufos, raio da copa, altura da copa, tamanho do tufo]
		"oak": [4.6, 0.26, 6, 1.9, 1.6, 1.15],
		"pine": [7.2, 0.2, 5, 1.6, 0.9, 1.05],
		"tall": [8.0, 0.17, 7, 1.1, 3.0, 0.8],
	}
	for kind in specs:
		var sp: Array = specs[kind]
		var th: float = sp[0]
		var tr: float = sp[1]
		var m := MB.new()
		var lo := MB.new()
		m.tex(U.BARK, 0.5)
		m.cyl(Transform3D(Basis(), Vector3(0, -0.6, 0)), tr * 1.25, tr * 0.6, th + 0.6, 7, bark, false)
		lo.tex(U.BARK, 0.5)
		lo.cyl(Transform3D(Basis(), Vector3(0, -0.6, 0)), tr * 1.25, tr * 0.6, th + 0.6, 4, bark, false)
		var tufts := []
		for k in int(sp[2]):
			var a := TAU * k / float(sp[2]) + rng.randf_range(-0.3, 0.3)
			var rr: float = float(sp[3]) * rng.randf_range(0.45, 1.0)
			var y: float = th - 0.4 + rng.randf_range(0.0, float(sp[4]))
			if k == 0:
				rr = 0.0
				y = th + float(sp[4]) * 0.6
			var p := Vector3(cos(a) * rr, y, sin(a) * rr)
			var ts: float = float(sp[5]) * rng.randf_range(0.8, 1.2)
			tufts.append([p, ts])
			# galho do tronco até o tufo
			if rr > 0.3:
				var from := Vector3(0, y - rr * 0.6 - 0.3, 0)
				var d := p - from
				m.tex(U.BARK, 0.5)
				m.cyl(Transform3D(Basis(Quaternion(Vector3.UP, d.normalized())), from), tr * 0.5, tr * 0.25, d.length(), 4, bark, false)
		m.tex(U.LEAVES, 0.6, 1.0)
		lo.tex(U.LEAVES, 0.4)
		for tf in tufts:
			var ts: float = tf[1]
			var sc := Vector3(ts * 1.2, ts * 0.75, ts * 1.2)
			var c := Color(1, 1, 1).darkened(rng.randf() * 0.18)
			m.blob(Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(sc), tf[0]), 6, 4, c, rng, 0.45, false, 0.45)
			lo.blob(Transform3D(Basis.from_scale(sc), tf[0]), 5, 3, c, rng, 0.2, false, 0.4)
		out[kind] = m.commit()
		out[kind + "_lo"] = lo.commit()
	# moita
	var m3 := MB.new()
	m3.tex(U.LEAVES, 0.8, 0.5)
	for k in 4:
		var a := rng.randf() * TAU
		m3.blob(Transform3D(Basis.from_scale(Vector3(rng.randf_range(0.6, 0.9), rng.randf_range(0.45, 0.7), rng.randf_range(0.6, 0.9))), Vector3(cos(a) * 0.4, 0.4, sin(a) * 0.4)), 6, 4, Color(1, 1, 1).darkened(rng.randf() * 0.2), rng, 0.35, false, 0.5)
	out["bush"] = m3.commit()
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


func _build_nature() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 999
	var sets := {"oak": [], "pine": [], "tall": [], "bush": [], "rock": [], "grass": [], "log": []}
	var body := StaticBody3D.new()
	body.collision_mask = 0
	add_child(body)
	var lim := PLAY + 10.0
	# pedras grandes das pedreiras
	for e in _big_rocks:
		var p: Vector2 = e[0]
		var s: float = e[1]
		var sc := Vector3(s, s * float(e[3]), s * rng.randf_range(0.7, 1.1))
		var gp := Vector3(p.x, height(p.x, p.y) + sc.y * 0.1, p.y)
		sets["rock"].append(Transform3D(Basis(Vector3.UP, e[2]) * Basis.from_scale(sc), gp))
		_rock_col(body, sc, e[2], gp)
	var tries := 0
	var trees := 0
	while trees < 1700 and tries < 30000:
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
		sets[kind].append(xf)
		trees += 1
		claim(p, 1.2)
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.32 * s
		cyl.height = 6.0 * s
		cs.shape = cyl
		cs.position = Vector3(x, gy + 3.0 * s, z)
		body.add_child(cs)
	# moitas: escondem, mas a bala passa
	tries = 0
	while sets["bush"].size() < 500 and tries < 8000:
		tries += 1
		var x := rng.randf_range(-lim, lim)
		var z := rng.randf_range(-lim, lim)
		var p := Vector2(x, z)
		if _near_town(p, -6.0) or road_dist(x, z) < 3.0 or hw_dist(x, z) < 6.0 or not is_free(p, 1.0) or height(x, z) < WATER_Y + 0.4:
			continue
		var s := rng.randf_range(0.9, 1.6)
		sets["bush"].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(s, s, s)), Vector3(x, height(x, z) - 0.1, z)))
	# pedras: cobertura que segura bala (algumas enormes)
	tries = 0
	while sets["rock"].size() < 380 and tries < 9000:
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
		var gp := Vector3(x, height(x, z) + sc.y * 0.08, z)
		sets["rock"].append(Transform3D(Basis(Vector3.UP, r) * Basis.from_scale(sc), gp))
		_rock_col(body, sc, r, gp)
		claim(p, s * 0.55)
		if rng.randf() < 0.18:
			var off := Vector3(cos(r), 0, sin(r)) * (maxf(sc.x, sc.z) * 0.6 + 0.8)
			var ip := Vector3(x + off.x, 0, z + off.z)
			ip.y = height(ip.x, ip.z) + 0.07
			add_item(ip, loot_kind(rng, false), null, null)
	# troncos caídos
	tries = 0
	while sets["log"].size() < 90 and tries < 3000:
		tries += 1
		var x := rng.randf_range(-lim, lim)
		var z := rng.randf_range(-lim, lim)
		var p := Vector2(x, z)
		if _near_town(p, 2.0) or road_dist(x, z) < 4.0 or hw_dist(x, z) < 9.0 or not is_free(p, 4.0) or _slope(p) > 0.15 or height(x, z) < WATER_Y + 0.4:
			continue
		var r := rng.randf() * TAU
		var gp := Vector3(x, low_h(p, 3.5) - 0.1, z)
		sets["log"].append(Transform3D(Basis(Vector3.UP, r), gp))
		var cs := CollisionShape3D.new()
		var cy := CylinderShape3D.new()
		cy.radius = 0.45
		cy.height = 7.0
		cs.shape = cy
		cs.transform = Transform3D(Basis(Vector3.UP, r) * Basis(Vector3.FORWARD, PI / 2.0), gp + Vector3(0, 0.45, 0))
		body.add_child(cs)
		claim(p, 4.0)
	if headless:
		return
	if quality >= 1:
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
	var meshes := _tree_meshes()
	var tint := RandomNumberGenerator.new()
	tint.seed = SEED + 3
	for k in sets:
		var chunk := 32.0 if k == "grass" else 80.0
		_scatter(k, meshes[k], sets[k], chunk, tint, meshes.get(k + "_lo"))
	set_view(300.0)


# colisão arredondada (casco convexo de um elipsoide) pra não entrar na pedra
func _rock_col(body: StaticBody3D, sc: Vector3, r: float, gp: Vector3) -> void:
	var pts := PackedVector3Array()
	for i in 5:
		var la := lerpf(-PI / 2.0, PI / 2.0, i / 4.0)
		var n := 1 if i == 0 or i == 4 else 8
		for k in n:
			var lo := TAU * k / n
			pts.append(Vector3(cos(la) * cos(lo) * sc.x, sin(la) * sc.y, cos(la) * sin(lo) * sc.z) * 0.53)
	var sh := ConvexPolygonShape3D.new()
	sh.points = pts
	var cs := CollisionShape3D.new()
	cs.shape = sh
	cs.transform = Transform3D(Basis(Vector3.UP, r), gp)
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
			mmi.material_override = U.wmat()
			mmi.position = center
			if kind == "grass" or kind == "bush" or variant == lo:
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mmi)
			_scatter_nodes.append([mmi, kind if variant == mesh else kind + "_lo", lo != null])


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
func _build_map(wts: PackedColorArray) -> void:
	var n := RES + 1
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var cg := Color(0.36, 0.44, 0.22)
	var cd := Color(0.55, 0.46, 0.33)
	var cr := Color(0.5, 0.49, 0.46)
	var cs := Color(0.7, 0.64, 0.48)
	var cw := Color(0.22, 0.36, 0.42)
	for j in n:
		for i in n:
			var c: Color = wts[j * n + i]
			var gw := clampf(1.0 - c.r - c.g - c.b, 0.0, 1.0)
			var col := cg * gw + cd * c.r + cr * c.g + cs * c.b
			col = col.lightened((c.a - 0.5) * 0.15)
			if _hs[j * n + i] < WATER_Y - 0.1 and Vector2(-SIZE / 2.0 + i * SIZE / RES, -SIZE / 2.0 + j * SIZE / RES).distance_to(LAKE_C) < LAKE_R + 40.0:
				col = cw
			img.set_pixel(i, j, col)
	img.resize(512, 512, Image.INTERPOLATE_BILINEAR)
	var px := 512.0 / SIZE
	for h in houses:
		var bs := Basis(Vector3.UP, h["yaw"])
		var hw: float = h["w"] / 2.0
		var hd: float = h["d"] / 2.0
		var steps := 6
		for a in steps:
			for c in steps:
				var lp := Vector3(-hw + (a + 0.5) * 2.0 * hw / steps, 0, -hd + (c + 0.5) * 2.0 * hd / steps)
				var wp: Vector3 = bs * lp
				var q: Vector2 = (h["pos"] + Vector2(wp.x, wp.z) + Vector2(SIZE, SIZE) / 2.0) * px
				img.fill_rect(Rect2i(int(q.x) - 1, int(q.y) - 1, 3, 3), Color(0.3, 0.25, 0.22))
	# rodovias asfaltadas
	for line in hw_pts:
		for i in line.size() - 1:
			var a: Vector2 = line[i][0]
			var c: Vector2 = line[i + 1][0]
			var k := int(a.distance_to(c))
			for t in k + 1:
				var q: Vector2 = (a.lerp(c, float(t) / maxf(k, 1)) + Vector2(SIZE, SIZE) / 2.0) * px
				img.fill_rect(Rect2i(int(q.x) - 2, int(q.y) - 2, 5, 5), Color(0.26, 0.26, 0.28))
		for e in line:
			var q: Vector2 = (Vector2(e[0]) + Vector2(SIZE, SIZE) / 2.0) * px
			img.set_pixel(clampi(int(q.x), 0, 511), clampi(int(q.y), 0, 511), Color(0.85, 0.75, 0.3))
	map_tex = ImageTexture.create_from_image(img)


func _build_env() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.3, 0.47, 0.7)
	sm.sky_horizon_color = Color(0.68, 0.74, 0.8)
	sm.ground_horizon_color = Color(0.64, 0.69, 0.72)
	sm.ground_bottom_color = Color(0.5, 0.55, 0.55)
	sm.sun_angle_max = 20.0
	sky.sky_material = sm
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.66, 0.74)
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.66, 0.72, 0.78)
	env.fog_density = 0.0022
	env.fog_sky_affect = 0.3
	# chão em volta do mapa até o horizonte (só visual)
	var mb := MB.new()
	mb.tex(U.GRASS, 0.02)
	var h := SIZE / 2.0
	var far := 4000.0
	var y := 40.0
	var oc := Color(0.75, 0.78, 0.7)
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
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.light_energy = 1.05
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
