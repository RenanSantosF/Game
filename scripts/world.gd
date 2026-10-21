class_name World
extends Node3D

# Mapa gerado sempre igual (mesma semente) em todos os aparelhos e no servidor.
const SIZE := 300.0
const RES := 100
const SEED := 2018
const TOWN_R := 26.0
const WALL_H := 3.0
const WALL_T := 0.25
const HOUSE_COLORS := [
	Color(0.8, 0.77, 0.7), Color(0.78, 0.68, 0.52), Color(0.6, 0.7, 0.75),
	Color(0.76, 0.48, 0.36), Color(0.8, 0.74, 0.5), Color(0.66, 0.7, 0.62),
]
const ROOF_COLORS := [Color(0.45, 0.2, 0.15), Color(0.3, 0.3, 0.32), Color(0.5, 0.32, 0.2)]

var noise := FastNoiseLite.new()
var noise2 := FastNoiseLite.new()
var towns: Array = []
var items: Array = []   # {pos: Vector3, wid: String}
var headless := false


func build(is_headless: bool) -> void:
	headless = is_headless
	noise.seed = SEED
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.009
	noise.fractal_octaves = 3
	noise2.seed = SEED + 7
	noise2.frequency = 0.05
	var centers := [Vector2(-80, -75), Vector2(82, -80), Vector2(0, 5), Vector2(-85, 80), Vector2(80, 78)]
	for c in centers:
		towns.append({"pos": c, "h": _raw(c.x, c.y)})
	_build_terrain()
	for i in towns.size():
		_build_town(i)
	_build_nature()
	_build_bounds()
	if not headless:
		_build_env()


func _raw(x: float, z: float) -> float:
	return noise.get_noise_2d(x, z) * 15.0


func height(x: float, z: float) -> float:
	var h := _raw(x, z)
	for t in towns:
		var d: float = Vector2(x, z).distance_to(t["pos"])
		if d < TOWN_R + 24.0:
			h = lerpf(t["h"], h, smoothstep(TOWN_R, TOWN_R + 24.0, d))
	var e := maxf(absf(x), absf(z))
	h += smoothstep(SIZE * 0.4, SIZE * 0.5, e) * 20.0
	return h


func town_factor(x: float, z: float) -> float:
	var f := 0.0
	for t in towns:
		var d: float = Vector2(x, z).distance_to(t["pos"])
		f = maxf(f, 1.0 - smoothstep(TOWN_R - 4.0, TOWN_R + 6.0, d))
	return f


func _near_town(x: float, z: float, r: float) -> bool:
	for t in towns:
		if Vector2(x, z).distance_to(t["pos"]) < r:
			return true
	return false


# ---------------- terreno ----------------

func _build_terrain() -> void:
	var cell := SIZE / RES
	var n := RES + 1
	var hs := PackedFloat32Array()
	hs.resize(n * n)
	for j in n:
		for i in n:
			hs[j * n + i] = height(-SIZE / 2.0 + i * cell, -SIZE / 2.0 + j * cell)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for j in n:
		for i in n:
			var x := -SIZE / 2.0 + i * cell
			var z := -SIZE / 2.0 + j * cell
			verts.append(Vector3(x, hs[j * n + i], z))
			var hl := hs[j * n + maxi(i - 1, 0)]
			var hr := hs[j * n + mini(i + 1, n - 1)]
			var hd := hs[maxi(j - 1, 0) * n + i]
			var hu := hs[mini(j + 1, n - 1) * n + i]
			var nm := Vector3(hl - hr, 2.0 * cell, hd - hu).normalized()
			norms.append(nm)
			var g := noise2.get_noise_2d(x, z) * 0.5 + 0.5
			var c := Color(0.2, 0.34, 0.12).lerp(Color(0.3, 0.42, 0.16), g)
			if nm.y < 0.85:
				c = c.lerp(Color(0.38, 0.35, 0.3), clampf((0.85 - nm.y) * 4.0, 0.0, 1.0))
			c = c.lerp(Color(0.46, 0.38, 0.26), town_factor(x, z))
			cols.append(c)
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
		arr[Mesh.ARRAY_INDEX] = idx
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.roughness = 1.0
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = m
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


# ---------------- cidades ----------------

func _build_town(ti: int) -> void:
	var t: Dictionary = towns[ti]
	var c: Vector2 = t["pos"]
	var base: float = t["h"]
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + ti * 31
	var count := 5 + rng.randi() % 2
	var a0 := rng.randf() * TAU
	for k in count:
		var ang := a0 + TAU * k / count + rng.randf_range(-0.12, 0.12)
		var dist := rng.randf_range(14.0, 17.5)
		var p := c + Vector2(cos(ang), sin(ang)) * dist
		var w := rng.randf_range(7.0, 9.0)
		var d := rng.randf_range(6.0, 7.5)
		var to_c := (c - p).normalized()
		var yaw := atan2(-to_c.x, -to_c.y)  # frente da casa (com a abertura) virada pro centro
		_house(Vector3(p.x, base, p.y), yaw, w, d, rng)
	# caixotes no meio da cidade pra se proteger
	for k in 3:
		var cp := c + Vector2(rng.randf_range(-6, 6), rng.randf_range(-6, 6))
		_crates(Vector3(cp.x, base, cp.y), rng)


func _piece(root: Node3D, size: Vector3, pos: Vector3, col: Color) -> void:
	if not headless:
		U.box(root, size, pos, col)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = pos
	root.add_child(cs)


# Parede com um buraco opcional (porta ou janela). along_x = parede corre no eixo X.
func _wall(root: Node3D, along_x: bool, fixed: float, length: float, hole_c := 0.0, hole_w := 0.0, hole_b := 0.0, hole_t := 0.0, col := Color.WHITE) -> void:
	var segs := []
	if hole_w <= 0.0:
		segs.append([-length / 2.0, length / 2.0, 0.0, WALL_H])
	else:
		var h0 := hole_c - hole_w / 2.0
		var h1 := hole_c + hole_w / 2.0
		segs.append([-length / 2.0, h0, 0.0, WALL_H])
		segs.append([h1, length / 2.0, 0.0, WALL_H])
		if hole_b > 0.0:
			segs.append([h0, h1, 0.0, hole_b])
		if hole_t < WALL_H:
			segs.append([h0, h1, hole_t, WALL_H])
	for s in segs:
		var ls: float = s[1] - s[0]
		var hh: float = s[3] - s[2]
		if ls <= 0.01 or hh <= 0.01:
			continue
		var mid: float = (s[0] + s[1]) / 2.0
		var my: float = (s[2] + s[3]) / 2.0
		if along_x:
			_piece(root, Vector3(ls, hh, WALL_T), Vector3(mid, my, fixed), col)
		else:
			_piece(root, Vector3(WALL_T, hh, ls), Vector3(fixed, my, mid), col)


func _house(pos: Vector3, yaw: float, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var col: Color = HOUSE_COLORS[rng.randi() % HOUSE_COLORS.size()]
	var roof: Color = ROOF_COLORS[rng.randi() % ROOF_COLORS.size()]
	var root := StaticBody3D.new()
	root.collision_mask = 0
	root.position = pos
	root.rotation.y = yaw
	add_child(root)
	# frente: abertura de porta (sem porta)
	_wall(root, true, -d / 2.0, w, rng.randf_range(-w * 0.2, w * 0.2), 1.6, 0.0, 2.3, col)
	# fundo: janela
	_wall(root, true, d / 2.0, w, rng.randf_range(-w * 0.2, w * 0.2), 1.4, 1.0, 2.0, col)
	# lados: um com janela, outro liso
	_wall(root, false, -w / 2.0, d, 0.0, 1.2, 1.0, 2.0, col)
	_wall(root, false, w / 2.0, d, 0.0, 0.0, 0.0, 0.0, col)
	# chão e teto
	_piece(root, Vector3(w, 0.06, d), Vector3(0, 0.0, 0), Color(0.55, 0.52, 0.48))
	_piece(root, Vector3(w + 0.5, 0.2, d + 0.5), Vector3(0, WALL_H + 0.1, 0), roof)
	# arma no chão da casa
	var local := Vector3(0, 0.35, d * 0.1)
	var gp := pos + Basis(Vector3.UP, yaw) * local
	items.append({"pos": gp, "wid": Weapons.LOOT[rng.randi() % Weapons.LOOT.size()]})


func _crates(pos: Vector3, rng: RandomNumberGenerator) -> void:
	var root := StaticBody3D.new()
	root.collision_mask = 0
	root.position = pos
	root.rotation.y = rng.randf() * TAU
	add_child(root)
	var col := Color(0.55, 0.4, 0.22)
	_piece(root, Vector3(1.2, 1.2, 1.2), Vector3(0, 0.6, 0), col)
	_piece(root, Vector3(1.2, 1.2, 1.2), Vector3(1.25, 0.6, 0.1), col.darkened(0.1))
	if rng.randf() < 0.6:
		_piece(root, Vector3(1.2, 1.2, 1.2), Vector3(0.6, 1.8, 0.05), col.lightened(0.05))


# ---------------- árvores, moitas e pedras ----------------

func _build_nature() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 999
	var trunks := []
	var rounds := []
	var pines := []
	var bushes := []
	var rocks := []
	var body := StaticBody3D.new()
	body.collision_mask = 0
	add_child(body)
	var lim := SIZE * 0.46
	var tries := 0
	while trunks.size() < 230 and tries < 6000:
		tries += 1
		var x := rng.randf_range(-lim, lim)
		var z := rng.randf_range(-lim, lim)
		if _near_town(x, z, TOWN_R + 3.0):
			continue
		var h := height(x, z)
		var s := rng.randf_range(0.8, 1.4)
		trunks.append(Transform3D(Basis.from_scale(Vector3(s, s, s)), Vector3(x, h + 1.5 * s, z)))
		if rng.randf() < 0.5:
			pines.append(Transform3D(Basis.from_scale(Vector3(s, s * 1.2, s)), Vector3(x, h + 3.0 * s + 1.6 * s, z)))
		else:
			rounds.append(Transform3D(Basis.from_scale(Vector3(s, s, s)), Vector3(x, h + 3.0 * s + 0.8 * s, z)))
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.3 * s
		cyl.height = 3.0 * s
		cs.shape = cyl
		cs.position = Vector3(x, h + 1.5 * s, z)
		body.add_child(cs)
	# moitas: escondem, mas a bala passa
	tries = 0
	while bushes.size() < 160 and tries < 4000:
		tries += 1
		var x := rng.randf_range(-lim, lim)
		var z := rng.randf_range(-lim, lim)
		if _near_town(x, z, 20.0):
			continue
		var s := rng.randf_range(0.8, 1.3)
		bushes.append(Transform3D(Basis.from_scale(Vector3(s, s, s)), Vector3(x, height(x, z) + 0.45 * s, z)))
	# pedras: cobertura que segura bala
	tries = 0
	while rocks.size() < 70 and tries < 4000:
		tries += 1
		var x := rng.randf_range(-lim, lim)
		var z := rng.randf_range(-lim, lim)
		if _near_town(x, z, TOWN_R + 2.0):
			continue
		var sc := Vector3(rng.randf_range(1.5, 3.5), rng.randf_range(1.0, 2.2), rng.randf_range(1.5, 3.5))
		var r := rng.randf() * TAU
		var xf := Transform3D(Basis(Vector3.UP, r) * Basis.from_scale(sc), Vector3(x, height(x, z) + sc.y * 0.35, z))
		rocks.append(xf)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = sc
		cs.shape = bs
		cs.transform = Transform3D(Basis(Vector3.UP, r), xf.origin)
		body.add_child(cs)

	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.18
	trunk.bottom_radius = 0.26
	trunk.height = 3.0
	trunk.radial_segments = 6
	trunk.rings = 1
	var crown := SphereMesh.new()
	crown.radius = 1.9
	crown.height = 3.4
	crown.radial_segments = 8
	crown.rings = 5
	var pine := CylinderMesh.new()
	pine.top_radius = 0.0
	pine.bottom_radius = 1.8
	pine.height = 4.0
	pine.radial_segments = 7
	pine.rings = 1
	var bush := SphereMesh.new()
	bush.radius = 1.0
	bush.height = 1.3
	bush.radial_segments = 7
	bush.rings = 4
	var rock := BoxMesh.new()
	_mm(trunk, trunks, Color(0.36, 0.25, 0.16), rng)
	_mm(crown, rounds, Color(0.22, 0.42, 0.16), rng)
	_mm(pine, pines, Color(0.16, 0.34, 0.18), rng)
	_mm(bush, bushes, Color(0.25, 0.45, 0.18), rng)
	_mm(rock, rocks, Color(0.5, 0.5, 0.48), rng)


func _mm(mesh: Mesh, xfs: Array, col: Color, rng: RandomNumberGenerator) -> void:
	if headless or xfs.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		var k := rng.randf_range(0.85, 1.15)
		mm.set_instance_color(i, Color(col.r * k, col.g * k, col.b * k))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 1.0
	mmi.material_override = m
	add_child(mmi)


func _build_bounds() -> void:
	var body := StaticBody3D.new()
	body.collision_mask = 0
	add_child(body)
	var half := SIZE / 2.0 - 4.0
	for k in 4:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		var horiz := k < 2
		bs.size = Vector3(SIZE, 300, 2) if horiz else Vector3(2, 300, SIZE)
		cs.shape = bs
		var sg := -1.0 if k % 2 == 0 else 1.0
		cs.position = Vector3(0, 0, sg * half) if horiz else Vector3(sg * half, 0, 0)
		body.add_child(cs)


func _build_env() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.32, 0.55, 0.85)
	sm.sky_horizon_color = Color(0.72, 0.82, 0.9)
	sm.ground_horizon_color = Color(0.62, 0.68, 0.62)
	sm.ground_bottom_color = Color(0.3, 0.35, 0.3)
	sky.sky_material = sm
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.68, 0.75)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.8, 0.88)
	env.fog_density = 0.0012
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 55.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)


# ---------------- pontos ----------------

func random_spawn(rng: RandomNumberGenerator) -> Vector3:
	var t: Dictionary = towns[rng.randi() % towns.size()]
	var a := rng.randf() * TAU
	var r := rng.randf_range(28.0, 40.0)
	var p: Vector2 = t["pos"] + Vector2(cos(a), sin(a)) * r
	p = p.clamp(Vector2(-125, -125), Vector2(125, 125))
	return Vector3(p.x, height(p.x, p.y) + 0.4, p.y)


func random_point(rng: RandomNumberGenerator) -> Vector3:
	if rng.randf() < 0.6:
		var t: Dictionary = towns[rng.randi() % towns.size()]
		var p: Vector2 = t["pos"] + Vector2(rng.randf_range(-10, 10), rng.randf_range(-10, 10))
		return Vector3(p.x, height(p.x, p.y), p.y)
	var x := rng.randf_range(-120, 120)
	var z := rng.randf_range(-120, 120)
	return Vector3(x, height(x, z), z)
