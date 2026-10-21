class_name World
extends Node3D

# Mapa gerado sempre igual (mesma semente) em todos os aparelhos e no servidor.
const SIZE := 640.0
const RES := 128
const SEED := 2018
const WALL_T := 0.22
const PLAY := 290.0            # metade da área jogável
# nome, centro, quantidade de casas, raio
const TOWNS := [
	["Vila Nova", Vector2(-190, -185), 6, 30.0],
	["Santa Rita", Vector2(10, -215), 5, 27.0],
	["Pedreira", Vector2(200, -180), 5, 27.0],
	["Bom Jesus", Vector2(-215, 0), 6, 29.0],
	["Cruzeiro", Vector2(0, 0), 8, 36.0],
	["Rio Seco", Vector2(205, 15), 5, 27.0],
	["Alto da Serra", Vector2(-185, 200), 5, 27.0],
	["São Miguel", Vector2(15, 205), 6, 29.0],
	["Boa Esperança", Vector2(195, 200), 5, 27.0],
	["Fazenda Velha", Vector2(-95, -90), 3, 20.0],
	["Sítio", Vector2(105, 100), 3, 20.0],
	["Granja", Vector2(-100, 105), 3, 20.0],
	["Olaria", Vector2(110, -95), 3, 20.0],
]
const WALL_COLORS := [
	Color(0.78, 0.75, 0.68), Color(0.74, 0.66, 0.52), Color(0.62, 0.66, 0.66),
	Color(0.7, 0.5, 0.4), Color(0.76, 0.7, 0.52), Color(0.64, 0.66, 0.58), Color(0.82, 0.8, 0.76),
]
const ROOF_COLORS := [Color(0.48, 0.24, 0.16), Color(0.42, 0.2, 0.14), Color(0.33, 0.33, 0.34), Color(0.52, 0.3, 0.2)]
const CAR_COLORS := [Color(0.45, 0.16, 0.12), Color(0.25, 0.3, 0.4), Color(0.75, 0.74, 0.7), Color(0.6, 0.55, 0.42), Color(0.2, 0.22, 0.2)]

var noise := FastNoiseLite.new()
var noise2 := FastNoiseLite.new()
var noise3 := FastNoiseLite.new()
var towns: Array = []      # {name, pos, h, r}
var roads: Array = []      # [Vector2, Vector2]
var items: Array = []      # {pos, kind, door_out, door_in}
var houses: Array = []     # {pos: Vector2, r}
var headless := false
var quality := 1
var map_tex: Texture2D
var _hs := PackedFloat32Array()
var _scatter_nodes: Array = []   # [MultiMeshInstance3D, tipo]


func build(is_headless: bool, q := 1) -> void:
	headless = is_headless
	quality = q
	noise.seed = SEED
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.006
	noise.fractal_octaves = 4
	noise2.seed = SEED + 7
	noise2.frequency = 0.02
	noise3.seed = SEED + 13
	noise3.frequency = 0.12
	for t in TOWNS:
		towns.append({"name": t[0], "pos": t[1], "h": _raw(t[1].x, t[1].y), "n": t[2], "r": t[3]})
	_make_roads()
	var cols := _build_terrain()
	for i in towns.size():
		_build_town(i)
	_build_nature()
	_build_bounds()
	if not headless:
		_build_map(cols)
		_build_env()


func _raw(x: float, z: float) -> float:
	return noise.get_noise_2d(x, z) * 20.0


func height(x: float, z: float) -> float:
	var h := _raw(x, z)
	for t in towns:
		var d: float = Vector2(x, z).distance_to(t["pos"])
		var r: float = t["r"]
		if d < r + 26.0:
			h = lerpf(t["h"], h, smoothstep(r, r + 26.0, d))
	var e := maxf(absf(x), absf(z))
	h += smoothstep(PLAY - 10.0, SIZE * 0.5, e) * 40.0
	return h


func town_factor(x: float, z: float) -> float:
	var f := 0.0
	for t in towns:
		var d: float = Vector2(x, z).distance_to(t["pos"])
		f = maxf(f, 1.0 - smoothstep(t["r"] - 4.0, t["r"] + 4.0, d))
	return f


func _near_town(x: float, z: float, extra: float) -> bool:
	for t in towns:
		if Vector2(x, z).distance_to(t["pos"]) < float(t["r"]) + extra:
			return true
	return false


func road_dist(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var best := 9999.0
	for r in roads:
		var a: Vector2 = r[0]
		var b: Vector2 = r[1]
		var ab := b - a
		var k := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * k))
	return best


func _make_roads() -> void:
	var seen := {}
	for i in towns.size():
		var near := []
		for j in towns.size():
			if i != j:
				near.append([Vector2(towns[i]["pos"]).distance_to(towns[j]["pos"]), j])
		near.sort_custom(func(a, b): return a[0] < b[0])
		for k in 2:
			var j: int = near[k][1]
			var key := "%d_%d" % [mini(i, j), maxi(i, j)]
			if seen.has(key):
				continue
			seen[key] = true
			roads.append([towns[i]["pos"], towns[j]["pos"]])


# ---------------- terreno ----------------

func ground_color(x: float, z: float, ny: float, h: float) -> Color:
	var g := noise2.get_noise_2d(x, z) * 0.5 + 0.5
	var g2 := noise3.get_noise_2d(x, z) * 0.5 + 0.5
	var c := Color(0.2, 0.27, 0.12).lerp(Color(0.38, 0.36, 0.2), clampf(g * 1.3 - 0.2, 0.0, 1.0))
	c = c.lerp(c.darkened(0.25), g2 * 0.6)
	if h > 22.0:
		c = c.lerp(Color(0.4, 0.38, 0.3), clampf((h - 22.0) / 20.0, 0.0, 0.7))
	if ny < 0.88:
		c = c.lerp(Color(0.36, 0.34, 0.31), clampf((0.88 - ny) * 5.0, 0.0, 1.0))
	var rd := road_dist(x, z)
	if rd < 7.0:
		c = c.lerp(Color(0.42, 0.35, 0.25), (1.0 - smoothstep(2.5, 7.0, rd)) * 0.9)
	c = c.lerp(Color(0.44, 0.38, 0.29).lerp(Color(0.38, 0.33, 0.25), g2), town_factor(x, z) * 0.85)
	return c


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
	var uvs := PackedVector2Array()
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
			uvs.append(Vector2(x, z) * 0.22)
			if headless:
				cols.append(Color.WHITE)
			else:
				cols.append(ground_color(x, z, nm.y, hh))
	for j in RES:
		for i in RES:
			var a := j * n + i
			var b := a + 1
			var c2 := a + n
			var d := c2 + 1
			idx.append_array(PackedInt32Array([a, b, c2, b, d, c2]))

	if not headless:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_NORMAL] = norms
		arr[Mesh.ARRAY_COLOR] = cols
		arr[Mesh.ARRAY_TEX_UV] = uvs
		arr[Mesh.ARRAY_INDEX] = idx
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = U.vmat()
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
	var h00 := _hs[j * n + i]
	var h10 := _hs[j * n + i + 1]
	var h01 := _hs[(j + 1) * n + i]
	var h11 := _hs[(j + 1) * n + i + 1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


# ---------------- cidades ----------------

func _build_town(ti: int) -> void:
	var t: Dictionary = towns[ti]
	var c: Vector2 = t["pos"]
	var base: float = t["h"]
	var tr: float = t["r"]
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + ti * 31
	var mb := MB.new()
	mb.uvs = 0.9
	var count: int = t["n"]
	var a0 := rng.randf() * TAU
	var farm := count <= 3
	for k in count:
		var ang := a0 + TAU * k / count + rng.randf_range(-0.1, 0.1)
		var dist := tr * rng.randf_range(0.5, 0.6)
		if count >= 8 and k % 2 == 1:
			dist = tr * 0.78
		var p := c + Vector2(cos(ang), sin(ang)) * dist
		var to_c := (c - p).normalized()
		var yaw := atan2(-to_c.x, -to_c.y)  # frente da casa (com a abertura) virada pro centro
		var kind := rng.randi() % 4
		if farm and k == 0:
			kind = 3
		var w: float
		var d: float
		match kind:
			2:
				w = rng.randf_range(10.0, 11.5)
				d = rng.randf_range(7.5, 8.5)
			3:
				w = rng.randf_range(12.0, 14.0)
				d = rng.randf_range(9.0, 10.0)
			_:
				w = rng.randf_range(7.0, 9.0)
				d = rng.randf_range(6.0, 7.5)
		_house(mb, Vector3(p.x, base, p.y), yaw, w, d, kind, rng)
	# caixotes e carros no meio da cidade pra se proteger
	for k in (2 if farm else 3):
		var cp := c + Vector2(rng.randf_range(-6, 6), rng.randf_range(-6, 6))
		_crates(mb, Vector3(cp.x, base, cp.y), rng)
	for k in (1 if farm else 2):
		var ang := rng.randf() * TAU
		var cp := c + Vector2(cos(ang), sin(ang)) * tr * rng.randf_range(0.15, 0.3)
		_car(mb, Vector3(cp.x, base, cp.y), rng.randf() * TAU, rng)
	if farm:
		_fence(mb, c, base, tr * 0.92, rng)
	if not headless:
		var mi := MeshInstance3D.new()
		mi.mesh = mb.commit()
		mi.material_override = U.vmat()
		mi.visibility_range_end = 600.0
		add_child(mi)


func _piece(root: StaticBody3D, mb: MB, size: Vector3, pos: Vector3, col: Color, collide := true, rot := Basis()) -> void:
	if not headless:
		mb.box(root.transform * Transform3D(rot, pos), size, col)
	if collide:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.transform = Transform3D(rot, pos)
		root.add_child(cs)


# Parede com um buraco opcional (porta ou janela). along_x = parede corre no eixo X.
func _wall(root: StaticBody3D, mb: MB, along_x: bool, fixed: float, length: float, wh: float, col: Color, hole_c := 0.0, hole_w := 0.0, hole_b := 0.0, hole_t := 0.0) -> void:
	var segs := []
	if hole_w <= 0.0:
		segs.append([-length / 2.0, length / 2.0, 0.0, wh])
	else:
		var h0 := hole_c - hole_w / 2.0
		var h1 := hole_c + hole_w / 2.0
		segs.append([-length / 2.0, h0, 0.0, wh])
		segs.append([h1, length / 2.0, 0.0, wh])
		if hole_b > 0.0:
			segs.append([h0, h1, 0.0, hole_b])
		if hole_t < wh:
			segs.append([h0, h1, hole_t, wh])
	for s in segs:
		var ls: float = s[1] - s[0]
		var hh: float = s[3] - s[2]
		if ls <= 0.01 or hh <= 0.01:
			continue
		var mid: float = (s[0] + s[1]) / 2.0
		var my: float = (s[2] + s[3]) / 2.0
		if along_x:
			_piece(root, mb, Vector3(ls, hh, WALL_T), Vector3(mid, my, fixed), col)
		else:
			_piece(root, mb, Vector3(WALL_T, hh, ls), Vector3(fixed, my, mid), col)
	if headless:
		return
	# rodapé escuro e moldura da abertura (só visual)
	var dark := col.darkened(0.35)
	if along_x:
		_piece(root, mb, Vector3(length + 0.04, 0.35, WALL_T + 0.05), Vector3(0, 0.175, fixed), dark, false)
	else:
		_piece(root, mb, Vector3(WALL_T + 0.05, 0.35, length + 0.04), Vector3(fixed, 0.175, 0), dark, false)
	if hole_w > 0.0:
		var fr := Color(0.3, 0.22, 0.15)
		var ft := 0.08
		for sx in [-1.0, 1.0]:
			var px: float = hole_c + sx * (hole_w / 2.0 + ft / 2.0)
			var py := (hole_b + hole_t) / 2.0
			var ph := hole_t - hole_b
			if along_x:
				_piece(root, mb, Vector3(ft, ph, WALL_T + 0.08), Vector3(px, py, fixed), fr, false)
			else:
				_piece(root, mb, Vector3(WALL_T + 0.08, ph, ft), Vector3(fixed, py, px), fr, false)
		if along_x:
			_piece(root, mb, Vector3(hole_w + ft * 2.0, ft, WALL_T + 0.08), Vector3(hole_c, hole_t + ft / 2.0, fixed), fr, false)
			if hole_b > 0.0:
				_piece(root, mb, Vector3(hole_w + 0.3, 0.06, WALL_T + 0.2), Vector3(hole_c, hole_b, fixed), dark, false)
		else:
			_piece(root, mb, Vector3(WALL_T + 0.08, ft, hole_w + ft * 2.0), Vector3(fixed, hole_t + ft / 2.0, hole_c), fr, false)
			if hole_b > 0.0:
				_piece(root, mb, Vector3(WALL_T + 0.2, 0.06, hole_w + 0.3), Vector3(fixed, hole_b, hole_c), dark, false)


# kind: 0/1 = casa simples, 2 = casa com dois cômodos, 3 = galpão
func _house(mb: MB, pos: Vector3, yaw: float, w: float, d: float, kind: int, rng: RandomNumberGenerator) -> void:
	var col: Color = WALL_COLORS[rng.randi() % WALL_COLORS.size()]
	var roof: Color = ROOF_COLORS[rng.randi() % ROOF_COLORS.size()]
	var wh := 3.0
	if kind == 3:
		wh = 4.2
		col = Color(0.55, 0.55, 0.53) if rng.randf() < 0.5 else Color(0.62, 0.42, 0.32)
		roof = Color(0.45, 0.46, 0.47)
	var root := StaticBody3D.new()
	root.collision_mask = 0
	root.position = pos
	root.rotation.y = yaw
	add_child(root)
	houses.append({"pos": Vector2(pos.x, pos.z), "r": maxf(w, d) * 0.5})
	var door_c := rng.randf_range(-w * 0.2, w * 0.2)
	var door_w := 3.6 if kind == 3 else 1.5
	var door_t := 3.4 if kind == 3 else 2.3
	# frente: abertura de porta (sem porta)
	_wall(root, mb, true, -d / 2.0, w, wh, col, door_c, door_w, 0.0, door_t)
	# fundo: janela
	_wall(root, mb, true, d / 2.0, w, wh, col, rng.randf_range(-w * 0.2, w * 0.2), 1.4, 1.0, 2.0)
	# lados
	_wall(root, mb, false, -w / 2.0, d, wh, col, 0.0, 1.2, 1.0, 2.0)
	if kind == 2:
		_wall(root, mb, false, w / 2.0, d, wh, col, 0.0, 1.2, 1.0, 2.0)
		# parede interna com passagem
		_wall(root, mb, false, w * 0.12, d - WALL_T, wh, col.lightened(0.15), -d * 0.15, 1.1, 0.0, 2.2)
	else:
		_wall(root, mb, false, w / 2.0, d, wh, col)
	# chão
	var floor_c := Color(0.55, 0.5, 0.44) if kind != 3 else Color(0.45, 0.45, 0.43)
	_piece(root, mb, Vector3(w, 0.08, d), Vector3(0, 0.0, 0), floor_c)
	# telhado de duas águas
	var ov := 0.35
	var half := d / 2.0 + ov
	var rh := 1.3 if kind != 3 else 1.0
	var slope := atan2(rh, half)
	var slab_w := sqrt(half * half + rh * rh)
	for s in [-1.0, 1.0]:
		var rot := Basis(Vector3.RIGHT, s * slope)
		_piece(root, mb, Vector3(w + ov * 2.0, 0.14, slab_w), Vector3(0, wh + rh / 2.0 + 0.05, s * half / 2.0), roof, true, rot)
	if not headless:
		# oitões (triângulos das pontas)
		var apex := wh + rh * (d / 2.0) / half
		for sx in [-1.0, 1.0]:
			var x: float = sx * w / 2.0
			var a := root.transform * Vector3(x, wh, -d / 2.0)
			var b := root.transform * Vector3(x, wh, d / 2.0)
			var c := root.transform * Vector3(x, apex, 0.0)
			var nrm := (root.transform.basis * Vector3(sx, 0, 0)).normalized()
			mb.tri(a, b, c, col, nrm)
			mb.tri(a, b, c, col.darkened(0.2), -nrm)
		# viga do topo
		mb.box(root.transform * Transform3D(Basis(), Vector3(0, wh + rh + 0.08, 0)), Vector3(w + ov * 2.0 + 0.05, 0.12, 0.22), roof.darkened(0.25))
	# loot dentro da casa
	var bs := Basis(Vector3.UP, yaw)
	var door_out := pos + bs * Vector3(door_c, 0.3, -d / 2.0 - 1.8)
	var door_in := pos + bs * Vector3(door_c, 0.3, -d / 2.0 + 1.3)
	var n_items := 1 + int(rng.randf() < 0.65) + int(kind >= 2)
	for k in n_items:
		var kind_s: String
		if k == 0:
			kind_s = Weapons.LOOT_GUNS[rng.randi() % Weapons.LOOT_GUNS.size()]
		else:
			kind_s = Weapons.LOOT[rng.randi() % Weapons.LOOT.size()]
		var lx := rng.randf_range(-w / 2.0 + 1.0, w / 2.0 - 1.0)
		if kind == 2:
			lx = rng.randf_range(-w / 2.0 + 1.0, w * 0.12 - 0.8)
		var local := Vector3(lx, 0.06, rng.randf_range(-d / 2.0 + 1.4, d / 2.0 - 1.0))
		items.append({"pos": pos + bs * local, "kind": kind_s, "door_out": door_out, "door_in": door_in})


func _crates(mb: MB, pos: Vector3, rng: RandomNumberGenerator) -> void:
	var root := StaticBody3D.new()
	root.collision_mask = 0
	root.position = pos
	root.rotation.y = rng.randf() * TAU
	add_child(root)
	var col := Color(0.42, 0.32, 0.2)
	_piece(root, mb, Vector3(1.2, 1.2, 1.2), Vector3(0, 0.6, 0), col)
	_piece(root, mb, Vector3(1.2, 1.2, 1.2), Vector3(1.25, 0.6, 0.1), col.darkened(0.12))
	if rng.randf() < 0.6:
		_piece(root, mb, Vector3(1.2, 1.2, 1.2), Vector3(0.6, 1.8, 0.05), col.lightened(0.06))
	if rng.randf() < 0.5:
		items.append({"pos": pos + Vector3(0, 0.06, 0) + Basis(Vector3.UP, root.rotation.y) * Vector3(0.6, 0, -1.2), "kind": Weapons.LOOT[rng.randi() % Weapons.LOOT.size()], "door_out": null, "door_in": null})


# carro abandonado: boa cobertura
func _car(mb: MB, pos: Vector3, yaw: float, rng: RandomNumberGenerator) -> void:
	var root := StaticBody3D.new()
	root.collision_mask = 0
	root.position = pos
	root.rotation.y = yaw
	add_child(root)
	var col: Color = CAR_COLORS[rng.randi() % CAR_COLORS.size()]
	var glass := Color(0.12, 0.14, 0.16)
	var tire := Color(0.07, 0.07, 0.07)
	_piece(root, mb, Vector3(1.8, 0.75, 4.2), Vector3(0, 0.72, 0), col)
	_piece(root, mb, Vector3(1.6, 0.6, 2.1), Vector3(0, 1.38, 0.25), glass)
	if not headless:
		mb.box(root.transform * Transform3D(Basis(), Vector3(0, 1.7, 0.25)), Vector3(1.62, 0.06, 2.0), col)
		mb.box(root.transform * Transform3D(Basis(), Vector3(0, 0.62, -2.12)), Vector3(1.7, 0.2, 0.08), Color(0.3, 0.3, 0.3))
		mb.box(root.transform * Transform3D(Basis(), Vector3(0, 0.62, 2.12)), Vector3(1.7, 0.2, 0.08), Color(0.3, 0.3, 0.3))
		for sx in [-0.82, 0.82]:
			for sz in [-1.35, 1.35]:
				var xf := root.transform * Transform3D(Basis(Vector3.FORWARD, PI / 2.0), Vector3(sx - 0.12 * signf(sx), 0.36, sz))
				mb.cyl(xf, 0.36, 0.36, 0.24, 10, tire)


func _fence(mb: MB, c: Vector2, base: float, r: float, rng: RandomNumberGenerator) -> void:
	var root := StaticBody3D.new()
	root.collision_mask = 0
	root.position = Vector3(c.x, base, c.y)
	add_child(root)
	var wood := Color(0.4, 0.31, 0.21)
	var seg := 26
	var gap := rng.randi() % seg
	for i in seg:
		if i == gap or i == (gap + seg / 2) % seg:
			continue
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var p0 := Vector2(cos(a0), sin(a0)) * r
		var p1 := Vector2(cos(a1), sin(a1)) * r
		var mid := (p0 + p1) / 2.0
		var ln := p0.distance_to(p1)
		var rot := Basis(Vector3.UP, -atan2(p1.y - p0.y, p1.x - p0.x))
		_piece(root, mb, Vector3(ln, 0.12, 0.06), Vector3(mid.x, 0.45, mid.y), wood, false, rot)
		_piece(root, mb, Vector3(ln, 0.12, 0.06), Vector3(mid.x, 0.8, mid.y), wood, false, rot)
		_fence_col(root, ln, mid, rot)
		_piece(root, mb, Vector3(0.12, 1.0, 0.12), Vector3(p0.x, 0.5, p0.y), wood.darkened(0.15), false)


func _fence_col(root: StaticBody3D, ln: float, mid: Vector2, rot: Basis) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(ln, 0.9, 0.1)
	cs.shape = bs
	cs.transform = Transform3D(rot, Vector3(mid.x, 0.45, mid.y))
	root.add_child(cs)


# ---------------- árvores, moitas, pedras e grama ----------------

func _tree_meshes() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 5
	var bark := Color(0.3, 0.22, 0.15)
	var out := {}
	# pinheiro
	var m := MB.new()
	m.cyl(Transform3D(), 0.24, 0.1, 7.5, 6, bark, false)
	var layers := [[1.8, 2.3, 3.0], [3.1, 1.9, 2.8], [4.4, 1.5, 2.6], [5.6, 1.05, 2.3], [6.7, 0.65, 1.9]]
	for i in layers.size():
		var L: Array = layers[i]
		var cc := Color(0.14, 0.22, 0.12).lerp(Color(0.18, 0.27, 0.14), float(i) / layers.size())
		m.cyl(Transform3D(Basis(Vector3.UP, i * 0.7), Vector3(0, L[0], 0)), L[1], 0.0, L[2], 8, cc, true, true)
	out["pine"] = m.commit()
	# árvore de copa
	m = MB.new()
	m.cyl(Transform3D(), 0.3, 0.17, 4.6, 7, bark, false)
	m.cyl(Transform3D(Basis(Vector3.FORWARD, 0.6), Vector3(0, 3.0, 0)), 0.12, 0.06, 1.8, 5, bark, false)
	m.cyl(Transform3D(Basis(Vector3.FORWARD, -0.7), Vector3(0, 3.3, 0)), 0.12, 0.06, 1.6, 5, bark, false)
	var blobs := [[Vector3(0, 5.2, 0), Vector3(2.3, 1.7, 2.3)], [Vector3(1.2, 4.6, 0.5), Vector3(1.6, 1.3, 1.6)],
		[Vector3(-1.1, 4.8, -0.4), Vector3(1.7, 1.3, 1.6)], [Vector3(0.2, 6.2, -0.3), Vector3(1.5, 1.2, 1.5)], [Vector3(-0.3, 4.6, 1.2), Vector3(1.4, 1.1, 1.4)]]
	for b in blobs:
		var cc := Color(0.2, 0.28, 0.13).lerp(Color(0.26, 0.33, 0.15), rng.randf())
		m.blob(Transform3D(Basis.from_scale(b[1]), b[0]), 7, 4, cc, rng, 0.18, true, 0.45)
	out["oak"] = m.commit()
	# moita
	m = MB.new()
	m.blob(Transform3D(Basis.from_scale(Vector3(1.0, 0.65, 1.0)), Vector3(0, 0.35, 0)), 8, 4, Color(0.2, 0.28, 0.13), rng, 0.18, true, 0.5)
	m.blob(Transform3D(Basis.from_scale(Vector3(0.7, 0.5, 0.7)), Vector3(0.6, 0.3, 0.3)), 7, 4, Color(0.23, 0.31, 0.15), rng, 0.18, true, 0.5)
	out["bush"] = m.commit()
	# pedra
	m = MB.new()
	m.blob(Transform3D(Basis.from_scale(Vector3(0.55, 0.5, 0.55)), Vector3.ZERO), 8, 5, Color(0.44, 0.43, 0.4), rng, 0.22, false, 0.3)
	out["rock"] = m.commit()
	# tufo de grama (lâminas finas, sem transparência)
	m = MB.new()
	for i in 7:
		var a := rng.randf() * TAU
		var o := Vector3(rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-0.25, 0.25))
		var side := Vector3(cos(a), 0, sin(a)) * 0.045
		var lean := Vector3(sin(a), 0, -cos(a)) * rng.randf_range(0.05, 0.2)
		var top := o + lean + Vector3(0, rng.randf_range(0.3, 0.55), 0)
		var gc := Color(0.24, 0.31, 0.13).lerp(Color(0.4, 0.38, 0.2), rng.randf())
		var nrm := Vector3(sin(a), 0.6, -cos(a)).normalized()
		m.tri(o - side, o + side, top, gc, nrm, Vector3.UP, Vector3.UP, Vector3.UP)
		m.tri(o - side, o + side, top, gc, -nrm, Vector3.UP, Vector3.UP, Vector3.UP)
	out["grass"] = m.commit()
	return out


func _build_nature() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 999
	var sets := {"pine": [], "oak": [], "bush": [], "rock": [], "grass": []}
	var body := StaticBody3D.new()
	body.collision_mask = 0
	add_child(body)
	var lim := PLAY + 15.0
	var tries := 0
	var trees := 0
	while trees < 1100 and tries < 20000:
		tries += 1
		var x := rng.randf_range(-lim, lim)
		var z := rng.randf_range(-lim, lim)
		# bosques: mais árvores onde o ruído é alto
		if noise2.get_noise_2d(x * 0.5, z * 0.5) < -0.25 and rng.randf() < 0.75:
			continue
		if _near_town(x, z, 4.0) or road_dist(x, z) < 6.0:
			continue
		var h := height(x, z)
		var s := rng.randf_range(0.8, 1.35)
		var r := rng.randf() * TAU
		var xf := Transform3D(Basis(Vector3.UP, r) * Basis.from_scale(Vector3(s, s * rng.randf_range(0.9, 1.15), s)), Vector3(x, h - 0.1, z))
		sets["pine" if rng.randf() < 0.5 else "oak"].append(xf)
		trees += 1
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.3 * s
		cyl.height = 4.5 * s
		cs.shape = cyl
		cs.position = Vector3(x, h + 2.25 * s, z)
		body.add_child(cs)
	# moitas: escondem, mas a bala passa
	tries = 0
	while sets["bush"].size() < 420 and tries < 6000:
		tries += 1
		var x := rng.randf_range(-lim, lim)
		var z := rng.randf_range(-lim, lim)
		if _near_town(x, z, -4.0) or road_dist(x, z) < 3.0:
			continue
		var s := rng.randf_range(0.8, 1.4)
		sets["bush"].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(s, s, s)), Vector3(x, height(x, z) - 0.05, z)))
	# pedras: cobertura que segura bala
	tries = 0
	while sets["rock"].size() < 170 and tries < 6000:
		tries += 1
		var x := rng.randf_range(-lim, lim)
		var z := rng.randf_range(-lim, lim)
		if _near_town(x, z, 2.0) or road_dist(x, z) < 4.0:
			continue
		var sc := Vector3(rng.randf_range(1.5, 4.0), rng.randf_range(1.0, 2.6), rng.randf_range(1.5, 4.0))
		var r := rng.randf() * TAU
		var gp := Vector3(x, height(x, z) + sc.y * 0.12, z)
		sets["rock"].append(Transform3D(Basis(Vector3.UP, r) * Basis.from_scale(sc), gp))
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(sc.x * 0.85, sc.y * 0.9, sc.z * 0.85)
		cs.shape = bs
		cs.transform = Transform3D(Basis(Vector3.UP, r), gp)
		body.add_child(cs)
		# às vezes tem loot perto da pedra
		if rng.randf() < 0.22:
			var off := Vector3(cos(r), 0, sin(r)) * (maxf(sc.x, sc.z) * 0.6 + 0.8)
			var ip := Vector3(x + off.x, 0, z + off.z)
			ip.y = height(ip.x, ip.z) + 0.06
			items.append({"pos": ip, "kind": Weapons.LOOT[rng.randi() % Weapons.LOOT.size()], "door_out": null, "door_in": null})
	if headless:
		return
	if quality >= 1:
		var gl := PLAY - 5.0
		var gcount := 22000 if quality == 1 else 40000
		tries = 0
		while sets["grass"].size() < gcount and tries < gcount * 3:
			tries += 1
			var x := rng.randf_range(-gl, gl)
			var z := rng.randf_range(-gl, gl)
			if town_factor(x, z) > 0.3 or road_dist(x, z) < 4.0:
				continue
			var s := rng.randf_range(0.7, 1.4)
			sets["grass"].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(s, s, s)), Vector3(x, grid_h(x, z) - 0.05, z)))
	var meshes := _tree_meshes()
	var tint := RandomNumberGenerator.new()
	tint.seed = SEED + 3
	for k in sets:
		var chunk := 32.0 if k == "grass" else 96.0
		_scatter(k, meshes[k], sets[k], chunk, tint)
	set_view(300.0)


# Espalha instâncias em blocos (MultiMesh por bloco), pra o motor descartar o que está longe.
func _scatter(kind: String, mesh: Mesh, xfs: Array, chunk: float, rng: RandomNumberGenerator) -> void:
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
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = list.size()
		for i in list.size():
			var xf: Transform3D = list[i]
			xf.origin -= center
			mm.set_instance_transform(i, xf)
			var k := rng.randf_range(0.82, 1.12)
			mm.set_instance_color(i, Color(k, k * rng.randf_range(0.95, 1.05), k))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = U.vmat()
		mmi.position = center
		if kind == "grass" or kind == "bush":
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		_scatter_nodes.append([mmi, kind])


# Distância de visão da vegetação (depende da qualidade gráfica)
func set_view(dist: float) -> void:
	for e in _scatter_nodes:
		var mmi: MultiMeshInstance3D = e[0]
		match e[1]:
			"grass":
				mmi.visibility_range_end = 45.0
			"bush":
				mmi.visibility_range_end = minf(dist, 160.0) + 50.0
			_:
				mmi.visibility_range_end = dist + 60.0


func _build_bounds() -> void:
	var body := StaticBody3D.new()
	body.collision_mask = 0
	add_child(body)
	var half := PLAY + 20.0
	for k in 4:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		var horiz := k < 2
		bs.size = Vector3(SIZE, 600, 2) if horiz else Vector3(2, 600, SIZE)
		cs.shape = bs
		var sg := -1.0 if k % 2 == 0 else 1.0
		cs.position = Vector3(0, 0, sg * half) if horiz else Vector3(sg * half, 0, 0)
		body.add_child(cs)


# Mapa visto de cima (minimapa)
func _build_map(cols: PackedColorArray) -> void:
	var n := RES + 1
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	for j in n:
		for i in n:
			var c: Color = cols[j * n + i]
			img.set_pixel(i, j, c.lightened(0.12))
	img.resize(384, 384, Image.INTERPOLATE_BILINEAR)
	var px := 384.0 / SIZE
	for h in houses:
		var p: Vector2 = (h["pos"] + Vector2(SIZE, SIZE) / 2.0) * px
		var r := int(float(h["r"]) * px * 0.85)
		img.fill_rect(Rect2i(int(p.x) - r, int(p.y) - r, r * 2, r * 2), Color(0.32, 0.26, 0.22))
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
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.66, 0.72, 0.78)
	env.fog_density = 0.0022
	env.fog_sky_affect = 0.3
	# chão em volta do mapa até o horizonte (só visual)
	var mb := MB.new()
	mb.uvs = 0.02
	var h := SIZE / 2.0
	var far := 4000.0
	var y := 24.0
	var oc := Color(0.3, 0.33, 0.2)
	var rects := [[-far, -far, far, -h], [-far, h, far, far], [-far, -h, -h, h], [h, -h, far, h]]
	for r in rects:
		mb.quad(Vector3(r[0], y, r[1]), Vector3(r[2], y, r[1]), Vector3(r[2], y, r[3]), Vector3(r[0], y, r[3]), oc, Vector3.UP)
	var ring := MeshInstance3D.new()
	ring.mesh = mb.commit()
	ring.material_override = U.vmat()
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	var we := WorldEnvironment.new()
	we.name = "Env"
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-48, 35, 0)
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.light_energy = 1.0
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


func random_spawn(rng: RandomNumberGenerator) -> Vector3:
	var t: Dictionary = towns[rng.randi() % towns.size()]
	var a := rng.randf() * TAU
	var r := float(t["r"]) + rng.randf_range(4.0, 14.0)
	var p: Vector2 = t["pos"] + Vector2(cos(a), sin(a)) * r
	return ground_pos(clamp_play(p))


func random_point_in(c: Vector2, r: float, rng: RandomNumberGenerator) -> Vector3:
	var a := rng.randf() * TAU
	var p := clamp_play(c + Vector2(cos(a), sin(a)) * sqrt(rng.randf()) * r)
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
