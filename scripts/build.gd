class_name Build
extends RefCounted

# Constrói as estruturas do mapa (casas, sobrados, galpões, torres, contêineres, carros...).
# Tudo de uma localidade vai numa malha só (self.mb); a colisão vai em caixas.

const FH := 3.3            # altura de um andar
const WALL_T := 0.22
const PLASTER_TINTS := [Color(0.96, 0.93, 0.86), Color(0.92, 0.8, 0.6), Color(0.78, 0.86, 0.9), Color(0.94, 0.76, 0.68),
	Color(0.84, 0.9, 0.78), Color(1, 1, 1), Color(0.86, 0.76, 0.64), Color(0.95, 0.88, 0.7)]
const CAR_TINTS := [Color(0.55, 0.12, 0.1), Color(0.18, 0.25, 0.42), Color(0.85, 0.85, 0.82), Color(0.62, 0.58, 0.45),
	Color(0.15, 0.16, 0.16), Color(0.35, 0.42, 0.3), Color(0.7, 0.55, 0.2)]
const FRAME := Color(0.5, 0.36, 0.25)

var w: World
var mb: MB
var rng := RandomNumberGenerator.new()
var headless := false
static var _car_cache := {}


func _init(world: World) -> void:
	w = world
	headless = world.headless


func begin(seed_v: int) -> void:
	mb = MB.new()
	rng.seed = seed_v


func finish(vis := 700.0) -> void:
	if headless or mb.count == 0:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = mb.commit()
	mi.material_override = U.wmat()
	mi.visibility_range_end = vis
	w.add_child(mi)


func body(pos: Vector3, yaw: float) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_mask = 0
	b.position = pos
	b.rotation.y = yaw
	w.add_child(b)
	return b


func col_box(root: Node3D, size: Vector3, pos: Vector3, rot := Basis()) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.transform = Transform3D(rot, pos)
	root.add_child(cs)


# peça visível + colisão (no espaço local de root)
func piece(root: Node3D, size: Vector3, pos: Vector3, col: Color, layer: int, uvs := 0.35, collide := true, rot := Basis()) -> void:
	if not headless:
		mb.tex(layer, uvs)
		mb.box(root.transform * Transform3D(rot, pos), size, col)
	if collide:
		col_box(root, size, pos, rot)


func vis(root: Node3D, size: Vector3, pos: Vector3, col: Color, layer: int, uvs := 0.35, rot := Basis()) -> void:
	piece(root, size, pos, col, layer, uvs, false, rot)


# Parede com vários buracos. holes = [[centro, largura, base, topo], ...] relativo à parede.
func wall(root: Node3D, along_x: bool, fixed: float, length: float, h: float, y0: float, holes: Array, col: Color, layer: int, uvs := 0.35, frames := true) -> void:
	holes.sort_custom(func(a, b): return a[0] < b[0])
	var x := -length / 2.0
	var segs := []
	for hl in holes:
		var h0: float = hl[0] - hl[1] / 2.0
		var h1: float = hl[0] + hl[1] / 2.0
		segs.append([x, h0, 0.0, h])
		if hl[2] > 0.0:
			segs.append([h0, h1, 0.0, hl[2]])
		if hl[3] < h:
			segs.append([h0, h1, hl[3], h])
		x = h1
	segs.append([x, length / 2.0, 0.0, h])
	for s in segs:
		var ls: float = s[1] - s[0]
		var hh: float = s[3] - s[2]
		if ls <= 0.01 or hh <= 0.01:
			continue
		var mid: float = (s[0] + s[1]) / 2.0
		var my: float = y0 + (s[2] + s[3]) / 2.0
		if along_x:
			piece(root, Vector3(ls, hh, WALL_T), Vector3(mid, my, fixed), col, layer, uvs)
		else:
			piece(root, Vector3(WALL_T, hh, ls), Vector3(fixed, my, mid), col, layer, uvs)
	if headless or not frames:
		return
	var ft := 0.07
	for hl in holes:
		var c: float = hl[0]
		var hw: float = hl[1]
		var hb: float = hl[2]
		var ht: float = hl[3]
		var py := y0 + (hb + ht) / 2.0
		for sx in [-1.0, 1.0]:
			var px: float = c + sx * (hw / 2.0 + ft / 2.0)
			if along_x:
				vis(root, Vector3(ft, ht - hb, WALL_T + 0.06), Vector3(px, py, fixed), FRAME, U.WOOD, 1.0)
			else:
				vis(root, Vector3(WALL_T + 0.06, ht - hb, ft), Vector3(fixed, py, px), FRAME, U.WOOD, 1.0)
		if along_x:
			vis(root, Vector3(hw + ft * 2.0, ft, WALL_T + 0.06), Vector3(c, y0 + ht + ft / 2.0, fixed), FRAME, U.WOOD, 1.0)
			if hb > 0.0:
				vis(root, Vector3(hw + 0.24, 0.06, WALL_T + 0.22), Vector3(c, y0 + hb, fixed), Color(0.8, 0.8, 0.78), U.CONCRETE, 1.0)
		else:
			vis(root, Vector3(WALL_T + 0.06, ft, hw + ft * 2.0), Vector3(fixed, y0 + ht + ft / 2.0, c), FRAME, U.WOOD, 1.0)
			if hb > 0.0:
				vis(root, Vector3(WALL_T + 0.22, 0.06, hw + 0.24), Vector3(fixed, y0 + hb, c), Color(0.8, 0.8, 0.78), U.CONCRETE, 1.0)


func _win(c: float) -> Array:
	return [c, 1.3, 0.9, 2.1]


func _door(c: float, wd := 1.4) -> Array:
	return [c, wd, 0.0, 2.3]


func _style_tex(style: String) -> Array:
	match style:
		"brick":
			return [U.BRICK, 0.5, Color(1, 1, 1).darkened(rng.randf() * 0.15)]
		"wood":
			return [U.WOOD, 0.4, Color(1, 1, 1).darkened(rng.randf() * 0.25)]
		"metal":
			return [U.METAL, 0.3, Color(0.92, 0.95, 1.0).darkened(rng.randf() * 0.2)]
		"concrete":
			return [U.CONCRETE, 0.3, Color(0.95, 0.95, 0.92)]
	return [U.PLASTER, 0.3, PLASTER_TINTS[rng.randi() % PLASTER_TINTS.size()]]


func _gable(root: Node3D, wdt: float, dpt: float, y: float, rise: float, layer: int, col: Color, wall_col: Color, wall_layer: int) -> void:
	var ov := 0.4
	var half := dpt / 2.0 + ov
	var slope := atan2(rise, half)
	var slab_w := sqrt(half * half + rise * rise)
	for s in [-1.0, 1.0]:
		var rot := Basis(Vector3.RIGHT, s * slope)
		piece(root, Vector3(wdt + ov * 2.0, 0.14, slab_w), Vector3(0, y + rise / 2.0 + 0.05, s * half / 2.0), col, layer, 0.42, true, rot)
	if headless:
		return
	var apex := y + rise * (dpt / 2.0) / half
	mb.tex(wall_layer, 0.3)
	for sx in [-1.0, 1.0]:
		var x: float = sx * wdt / 2.0
		var a := root.transform * Vector3(x, y, -dpt / 2.0)
		var b := root.transform * Vector3(x, y, dpt / 2.0)
		var c := root.transform * Vector3(x, apex, 0.0)
		var nrm := (root.transform.basis * Vector3(sx, 0, 0)).normalized()
		mb.tri(a, b, c, wall_col, nrm)
		mb.tri(a, b, c, wall_col.darkened(0.25), -nrm)
	vis(root, Vector3(wdt + ov * 2.0 + 0.05, 0.14, 0.24), Vector3(0, y + rise + 0.1, 0), col.darkened(0.25), layer, 0.4)


# Casa genérica. spec: w, d, floors, style, roof ("tile"/"metal"/"flat"), rooms, balcony, porch
func house(pos: Vector3, yaw: float, spec: Dictionary) -> void:
	var wd: float = spec.get("w", 8.0)
	var dp: float = spec.get("d", 7.0)
	var floors: int = spec.get("floors", 1)
	var style: String = spec.get("style", "plaster")
	var roof: String = spec.get("roof", "tile")
	var rooms: int = spec.get("rooms", 1)
	var fh: float = spec.get("fh", FH)
	var st := _style_tex(style)
	var lay: int = st[0]
	var uvs: float = st[1]
	var col: Color = st[2]
	var root := body(pos, yaw)
	w.claim(Vector2(pos.x, pos.z), maxf(wd, dp) * 0.75)
	w.houses.append({"pos": Vector2(pos.x, pos.z), "r": maxf(wd, dp) * 0.5, "yaw": yaw, "w": wd, "d": dp})
	var door_c := rng.randf_range(-wd * 0.18, wd * 0.18)
	var door_w: float = spec.get("door_w", 1.4)
	var balcony: bool = spec.get("balcony", false) and floors > 1
	var bal_c := rng.randf_range(-wd * 0.15, wd * 0.15)
	var stair_x := wd / 2.0 - 0.7
	for f in floors:
		var y0 := f * fh
		var front := []
		var back := []
		if f == 0:
			front.append([door_c, door_w, 0.0, minf(2.3 if door_w < 2.5 else fh - 0.6, fh - 0.3)])
			if wd > 8.5:
				var wc := door_c + (2.6 if door_c < 0.0 else -2.6)
				front.append(_win(wc))
		else:
			if balcony:
				front.append(_door(bal_c, 1.2))
			else:
				front.append(_win(-wd * 0.25))
				front.append(_win(wd * 0.25))
		back.append(_win(rng.randf_range(-wd * 0.25, wd * 0.25)))
		if wd > 9.5:
			back.append(_win(-wd * 0.32 if back[0][0] > 0.0 else wd * 0.32))
		var lh := fh if f < floors - 1 or roof != "flat" else fh + 0.9
		wall(root, true, -dp / 2.0, wd, lh, y0, front, col, lay, uvs)
		wall(root, true, dp / 2.0, wd, lh, y0, back, col, lay, uvs)
		var side := [_win(0.0)] if dp < 9.0 else [_win(-dp * 0.25), _win(dp * 0.25)]
		wall(root, false, -wd / 2.0, dp, lh, y0, side, col, lay, uvs)
		# do lado da escada não tem janela no térreo
		wall(root, false, wd / 2.0, dp, lh, y0, [] if (floors > 1 and f == 0) else [_win(-dp * 0.2)], col, lay, uvs)
		if rooms > 1 and f == 0:
			wall(root, false, -wd * 0.1, dp - WALL_T, fh, 0.0, [_door(-dp * 0.2, 1.1)], col.lightened(0.1), U.PLASTER, 0.3, false)
		# piso
		if f == 0:
			piece(root, Vector3(wd, 0.1, dp), Vector3(0, 0.0, 0), Color(0.85, 0.82, 0.78), U.CONCRETE if style != "wood" else U.WOOD, 0.4)
		else:
			_upper_floor(root, wd, dp, y0, stair_x)
	if floors > 1:
		_stairs(root, wd, dp, fh, stair_x)
	var top := floors * fh
	# telhado
	match roof:
		"tile":
			_gable(root, wd, dp, top, 1.4 if wd < 11.0 else 1.8, U.ROOF, Color(1, 1, 1).darkened(rng.randf() * 0.2), col, lay)
		"metal":
			_gable(root, wd, dp, top, 0.9, U.METAL, Color(0.9, 0.92, 0.95), col, lay)
		_:
			piece(root, Vector3(wd + 0.1, 0.2, dp + 0.1), Vector3(0, top + 0.1, 0), Color(0.85, 0.85, 0.85), U.CONCRETE, 0.3)
	if balcony:
		var bw := 3.2
		var bd := 1.5
		piece(root, Vector3(bw, 0.18, bd), Vector3(bal_c, fh - 0.09, -dp / 2.0 - bd / 2.0), Color(0.85, 0.85, 0.83), U.CONCRETE, 0.4)
		piece(root, Vector3(bw, 1.0, 0.1), Vector3(bal_c, fh + 0.5, -dp / 2.0 - bd + 0.05), col, lay, uvs)
		for sx in [-1.0, 1.0]:
			piece(root, Vector3(0.1, 1.0, bd), Vector3(bal_c + sx * (bw / 2.0 - 0.05), fh + 0.5, -dp / 2.0 - bd / 2.0), col, lay, uvs)
			vis(root, Vector3(0.16, fh - 0.18, 0.16), Vector3(bal_c + sx * (bw / 2.0 - 0.12), (fh - 0.18) / 2.0, -dp / 2.0 - bd + 0.12), Color(0.9, 0.9, 0.88), U.CONCRETE, 0.4)
	if spec.get("porch", false):
		var pw := minf(wd * 0.7, 5.0)
		var pd := 2.2
		var pc := door_c
		piece(root, Vector3(pw, 0.12, pd), Vector3(pc, 2.75, -dp / 2.0 - pd / 2.0), Color(0.95, 0.95, 0.95), U.ROOF if roof == "tile" else U.METAL, 0.42)
		piece(root, Vector3(pw, 0.12, pd), Vector3(pc, 0.06, -dp / 2.0 - pd / 2.0), Color(0.9, 0.85, 0.8), U.WOOD, 0.4)
		for sx in [-1.0, 1.0]:
			piece(root, Vector3(0.14, 2.7, 0.14), Vector3(pc + sx * (pw / 2.0 - 0.1), 1.35, -dp / 2.0 - pd + 0.1), Color(0.9, 0.85, 0.8), U.WOOD, 0.5)
	# loot
	var bs := Basis(Vector3.UP, yaw)
	var door_out := pos + bs * Vector3(door_c, 0.3, -dp / 2.0 - 2.0)
	var door_in := pos + bs * Vector3(door_c, 0.3, -dp / 2.0 + 1.3)
	w.houses[-1]["din"] = door_in
	w.houses[-1]["dout"] = door_out
	var n_items := 2 + int(rng.randf() < 0.5) + int(wd * dp > 70.0)
	for k in n_items:
		var lx := rng.randf_range(-wd / 2.0 + 1.0, wd / 2.0 - 1.6)
		if rooms > 1:
			lx = rng.randf_range(-wd / 2.0 + 1.0, -wd * 0.1 - 0.8)
		var local := Vector3(lx, 0.07, rng.randf_range(-dp / 2.0 + 1.5, dp / 2.0 - 1.0))
		w.add_item(pos + bs * local, w.loot_kind(rng, k == 0), door_out, door_in)
	for f in range(1, floors):
		var local := Vector3(rng.randf_range(-wd / 2.0 + 1.0, wd / 2.0 - 2.0), f * fh + 0.12, rng.randf_range(-dp / 2.0 + 1.0, dp / 2.0 - 1.5))
		w.add_item(pos + bs * local, w.loot_kind(rng, rng.randf() < 0.5), null, null, true)


func _upper_floor(root: Node3D, wd: float, dp: float, y0: float, stair_x: float) -> void:
	var hole_x0 := stair_x - 0.6
	var z0 := dp / 2.0 - 1.2
	var z1 := z0 - 4.8
	var y := y0 - 0.1
	var fcol := Color(0.85, 0.82, 0.78)
	# parte sem buraco
	piece(root, Vector3(hole_x0 + wd / 2.0, 0.2, dp), Vector3((-wd / 2.0 + hole_x0) / 2.0, y, 0), fcol, U.WOOD, 0.4)
	# faixa da frente e de trás do buraco
	var fl := z1 + dp / 2.0
	piece(root, Vector3(wd / 2.0 - hole_x0, 0.2, fl), Vector3((hole_x0 + wd / 2.0) / 2.0, y, -dp / 2.0 + fl / 2.0), fcol, U.WOOD, 0.4)
	var bl := dp / 2.0 - z0
	piece(root, Vector3(wd / 2.0 - hole_x0, 0.2, bl), Vector3((hole_x0 + wd / 2.0) / 2.0, y, dp / 2.0 - bl / 2.0), fcol, U.WOOD, 0.4)
	# guarda-corpo do lado do buraco
	piece(root, Vector3(0.08, 1.0, z0 - z1 - 1.0), Vector3(hole_x0, y0 + 0.5, (z0 + z1) / 2.0 - 0.5), Color(0.4, 0.3, 0.22), U.WOOD, 0.5)


func _stairs(root: Node3D, wd: float, dp: float, fh: float, stair_x: float) -> void:
	var z0 := dp / 2.0 - 1.2
	var z1 := z0 - 4.8
	var L := z0 - z1
	var ang := atan2(fh, L)
	var ramp := sqrt(L * L + fh * fh)
	col_box(root, Vector3(1.15, 0.2, ramp), Vector3(stair_x, fh / 2.0 - 0.05, (z0 + z1) / 2.0), Basis(Vector3.RIGHT, -ang))
	if headless:
		return
	var n := 14
	for i in n:
		var sy := (i + 1) * fh / n
		var sz := z1 + (i + 0.5) * L / n
		vis(root, Vector3(1.15, 0.12, L / n + 0.02), Vector3(stair_x, sy - 0.06, sz), Color(0.75, 0.6, 0.45), U.WOOD, 0.6)
	vis(root, Vector3(0.08, 0.3, ramp), Vector3(stair_x - 0.6, fh / 2.0 + 0.05, (z0 + z1) / 2.0), Color(0.45, 0.33, 0.24), U.WOOD, 0.5, Basis(Vector3.RIGHT, -ang))


func shack(pos: Vector3, yaw: float) -> void:
	var root := body(pos, yaw)
	var wd := rng.randf_range(4.5, 5.5)
	var dp := rng.randf_range(3.8, 4.4)
	var h := 2.8
	var col := Color(1, 1, 1).darkened(rng.randf() * 0.3)
	w.claim(Vector2(pos.x, pos.z), 4.0)
	w.houses.append({"pos": Vector2(pos.x, pos.z), "r": 2.5, "yaw": yaw, "w": wd, "d": dp})
	wall(root, true, -dp / 2.0, wd, h, 0.0, [_door(0.6, 1.2)], col, U.WOOD, 0.4)
	wall(root, true, dp / 2.0, wd, h, 0.0, [_win(-0.5)], col, U.WOOD, 0.4)
	wall(root, false, -wd / 2.0, dp, h, 0.0, [], col, U.WOOD, 0.4)
	wall(root, false, wd / 2.0, dp, h, 0.0, [_win(0.0)], col, U.WOOD, 0.4)
	piece(root, Vector3(wd, 0.1, dp), Vector3(0, 0, 0), col, U.WOOD, 0.4)
	piece(root, Vector3(wd + 0.6, 0.1, dp + 0.8), Vector3(0, h + 0.2, 0), Color(0.85, 0.85, 0.85), U.METAL, 0.3, true, Basis(Vector3.RIGHT, 0.12))
	var bs := Basis(Vector3.UP, yaw)
	w.houses[-1]["din"] = pos + bs * Vector3(0.6, 0.3, -dp / 2.0 + 1.0)
	w.houses[-1]["dout"] = pos + bs * Vector3(0.6, 0.3, -dp / 2.0 - 1.8)
	w.add_item(pos + bs * Vector3(-0.8, 0.07, 0.3), w.loot_kind(rng, rng.randf() < 0.5), pos + bs * Vector3(0.6, 0.3, -dp / 2.0 - 1.8), pos + bs * Vector3(0.6, 0.3, -dp / 2.0 + 1.0))


func warehouse(pos: Vector3, yaw: float) -> void:
	house(pos, yaw, {"w": rng.randf_range(13.0, 16.0), "d": rng.randf_range(9.0, 11.0), "fh": 4.6, "style": "metal",
		"roof": "metal", "door_w": 4.0})
	var bs := Basis(Vector3.UP, yaw)
	for k in 2:
		crates(pos + bs * Vector3(rng.randf_range(-4, 4), 0.05, rng.randf_range(1, 3)), rng.randf() * TAU, false)


func church(pos: Vector3, yaw: float) -> void:
	var root := body(pos, yaw)
	var wd := 9.0
	var dp := 17.0
	var h := 5.5
	var col: Color = PLASTER_TINTS[rng.randi() % PLASTER_TINTS.size()]
	w.claim(Vector2(pos.x, pos.z), 12.0)
	w.houses.append({"pos": Vector2(pos.x, pos.z), "r": 8.0, "yaw": yaw, "w": wd, "d": dp})
	wall(root, true, -dp / 2.0, wd, h, 0.0, [[0.0, 2.2, 0.0, 3.4]], col, U.PLASTER, 0.3)
	wall(root, true, dp / 2.0, wd, h, 0.0, [[0.0, 1.0, 2.5, 4.2]], col, U.PLASTER, 0.3)
	for sx in [-1.0, 1.0]:
		wall(root, false, sx * wd / 2.0, dp, h, 0.0, [_win(-4.5), [0.0, 1.3, 0.9, 3.2], _win(4.5)], col, U.PLASTER, 0.3)
	piece(root, Vector3(wd, 0.1, dp), Vector3(0, 0, 0), Color(0.7, 0.62, 0.55), U.BRICK, 0.6)
	_gable(root, wd, dp, h, 3.2, U.ROOF, Color(0.85, 0.85, 0.85), col, U.PLASTER)
	# torre do sino na frente
	var tz := -dp / 2.0 - 1.8
	var tw := 3.6
	var th := 15.0
	for sz in [-1.0, 1.0]:
		var holes := [[0.0, 1.2, th - 3.2, th - 1.2], [0.0, 1.6, 0.0, 2.6]]
		wall(root, true, tz + sz * tw / 2.0, tw, th, 0.0, holes, col, U.PLASTER, 0.3)
	for sx in [-1.0, 1.0]:
		_tower_side(root, sx * tw / 2.0, tz, tw, th, col)
	piece(root, Vector3(tw + 0.3, 0.2, tw + 0.3), Vector3(0, th, tz), Color(0.8, 0.8, 0.8), U.CONCRETE, 0.4)
	if not headless:
		mb.tex(U.ROOF, 0.4)
		mb.cyl(root.transform * Transform3D(Basis(Vector3.UP, PI / 4.0), Vector3(0, th + 0.1, tz)), tw * 0.78, 0.0, 4.0, 4, Color(0.8, 0.8, 0.8), true, false)
		mb.tex(U.METAL, 1.0)
		mb.box(root.transform * Transform3D(Basis(), Vector3(0, th + 4.6, tz)), Vector3(0.12, 1.4, 0.12), Color(0.4, 0.4, 0.4))
		mb.box(root.transform * Transform3D(Basis(), Vector3(0, th + 4.8, tz)), Vector3(0.7, 0.12, 0.12), Color(0.4, 0.4, 0.4))
	var bs := Basis(Vector3.UP, yaw)
	w.houses[-1]["din"] = pos + bs * Vector3(0, 0.3, -dp / 2.0 + 1.5)
	w.houses[-1]["dout"] = pos + bs * Vector3(0, 0.3, -dp / 2.0 - 4.5)
	for k in 3:
		w.add_item(pos + bs * Vector3(rng.randf_range(-3, 3), 0.07, rng.randf_range(-6, 6)), w.loot_kind(rng, k == 0), pos + bs * Vector3(0, 0.3, -dp / 2.0 - 4.5), pos + bs * Vector3(0, 0.3, -dp / 2.0 + 1.5))


func _tower_side(root: Node3D, x: float, tz: float, tw: float, th: float, col: Color) -> void:
	# parede lateral da torre (corre em Z), centrada em tz
	var segs := [[-tw / 2.0, -0.6, 0.0, th], [0.6, tw / 2.0, 0.0, th], [-0.6, 0.6, 0.0, th - 3.2], [-0.6, 0.6, th - 1.2, th]]
	for s in segs:
		var ls: float = s[1] - s[0]
		var hh: float = s[3] - s[2]
		piece(root, Vector3(WALL_T, hh, ls), Vector3(x, (s[2] + s[3]) / 2.0, tz + (s[0] + s[1]) / 2.0), col, U.PLASTER, 0.3)


func barracks(pos: Vector3, yaw: float) -> void:
	house(pos, yaw, {"w": 16.0, "d": 7.0, "style": "concrete", "roof": "flat", "rooms": 2, "door_w": 1.6})


func store(pos: Vector3, yaw: float) -> void:
	house(pos, yaw, {"w": 10.0, "d": 8.0, "style": "concrete", "roof": "flat", "door_w": 2.6})


# ---------------- coberturas e objetos ----------------

func crates(pos: Vector3, yaw: float, loot := true) -> void:
	var root := body(pos, yaw)
	var col := Color(1, 1, 1).darkened(rng.randf() * 0.25)
	w.claim(Vector2(pos.x, pos.z), 2.5)
	piece(root, Vector3(1.2, 1.2, 1.2), Vector3(0, 0.6, 0), col, U.WOOD, 0.8)
	piece(root, Vector3(1.2, 1.2, 1.2), Vector3(1.25, 0.6, 0.1), col.darkened(0.12), U.WOOD, 0.8)
	if rng.randf() < 0.6:
		piece(root, Vector3(1.2, 1.2, 1.2), Vector3(0.6, 1.8, 0.05), col.lightened(0.06), U.WOOD, 0.8)
	if loot and rng.randf() < 0.55:
		w.add_item(pos + Vector3(0, 0.07, 0) + Basis(Vector3.UP, yaw) * Vector3(0.6, 0, -1.2), w.loot_kind(rng, false), null, null)


func barrel(pos: Vector3) -> void:
	var root := body(pos, 0.0)
	var cols := [Color(0.35, 0.45, 0.6), Color(0.6, 0.25, 0.15), Color(0.4, 0.45, 0.3)]
	var c: Color = cols[rng.randi() % cols.size()]
	if not headless:
		mb.tex(U.METAL, 0.8)
		mb.cyl(root.transform, 0.32, 0.32, 0.95, 10, c, true, true)
	col_box(root, Vector3(0.6, 0.95, 0.6), Vector3(0, 0.475, 0))


func container(pos: Vector3, yaw: float, open := false, stack := false) -> void:
	var root := body(pos, yaw)
	var cols := [Color(0.75, 0.3, 0.2), Color(0.3, 0.45, 0.65), Color(0.4, 0.55, 0.35), Color(0.85, 0.65, 0.3), Color(0.7, 0.7, 0.7)]
	var c: Color = cols[rng.randi() % cols.size()]
	var L := 6.0
	var W := 2.44
	var H := 2.6
	w.claim(Vector2(pos.x, pos.z), 4.0)
	if open:
		piece(root, Vector3(L, 0.1, W), Vector3(0, 0.05, 0), c.darkened(0.3), U.METAL, 0.4)
		piece(root, Vector3(L, 0.1, W), Vector3(0, H - 0.05, 0), c, U.METAL, 0.4)
		piece(root, Vector3(L, H, 0.08), Vector3(0, H / 2.0, -W / 2.0), c, U.METAL, 0.4)
		piece(root, Vector3(L, H, 0.08), Vector3(0, H / 2.0, W / 2.0), c, U.METAL, 0.4)
		piece(root, Vector3(0.08, H, W), Vector3(L / 2.0, H / 2.0, 0), c, U.METAL, 0.4)
		var bs := Basis(Vector3.UP, yaw)
		w.add_item(pos + bs * Vector3(0.8, 0.12, 0), w.loot_kind(rng, true), pos + bs * Vector3(-L / 2.0 - 1.5, 0.3, 0), pos + bs * Vector3(-L / 2.0 + 1.0, 0.3, 0))
	else:
		piece(root, Vector3(L, H, W), Vector3(0, H / 2.0, 0), c, U.METAL, 0.4)
	if stack:
		piece(root, Vector3(L, H, W), Vector3(0.3, H * 1.5, 0), cols[rng.randi() % cols.size()], U.METAL, 0.4, true, Basis(Vector3.UP, 0.05))


func sandbags(pos: Vector3, yaw: float, length := 3.0) -> void:
	var root := body(pos, yaw)
	var c := Color(0.72, 0.64, 0.48)
	w.claim(Vector2(pos.x, pos.z), length * 0.6)
	col_box(root, Vector3(length, 1.05, 0.7), Vector3(0, 0.52, 0))
	if headless:
		return
	mb.tex(U.FABRIC, 1.5)
	var n := int(length / 0.55)
	for row in 3:
		for i in n - (row % 2):
			var x := -length / 2.0 + 0.3 + i * 0.55 + (0.27 if row % 2 == 1 else 0.0)
			mb.blob(root.transform * Transform3D(Basis.from_scale(Vector3(0.3, 0.18, 0.34)), Vector3(x, 0.18 + row * 0.33, 0)), 6, 3, c.darkened(rng.randf() * 0.15))


func barrier(pos: Vector3, yaw: float) -> void:
	var root := body(pos, yaw)
	piece(root, Vector3(3.0, 0.5, 0.7), Vector3(0, 0.25, 0), Color(0.9, 0.9, 0.88), U.CONCRETE, 0.5)
	piece(root, Vector3(3.0, 0.5, 0.35), Vector3(0, 0.75, 0), Color(0.9, 0.9, 0.88), U.CONCRETE, 0.5)


func low_wall(a: Vector2, b: Vector2, y: float, style := "brick", h := 1.1) -> void:
	var mid := (a + b) / 2.0
	var ln := a.distance_to(b)
	var root := body(Vector3(mid.x, y, mid.y), -atan2(b.y - a.y, b.x - a.x))
	var st := _style_tex(style)
	piece(root, Vector3(ln, h, 0.25), Vector3(0, h / 2.0, 0), st[2], st[0], st[1])
	if not headless:
		vis(root, Vector3(ln + 0.05, 0.08, 0.32), Vector3(0, h + 0.04, 0), Color(0.85, 0.85, 0.83), U.CONCRETE, 0.5)


func fence(a: Vector2, b: Vector2, y: float) -> void:
	var mid := (a + b) / 2.0
	var ln := a.distance_to(b)
	var root := body(Vector3(mid.x, y, mid.y), -atan2(b.y - a.y, b.x - a.x))
	col_box(root, Vector3(ln, 1.0, 0.1), Vector3(0, 0.5, 0))
	if headless:
		return
	var wood := Color(0.85, 0.75, 0.65)
	vis(root, Vector3(ln, 0.12, 0.05), Vector3(0, 0.45, 0), wood, U.WOOD, 0.6)
	vis(root, Vector3(ln, 0.12, 0.05), Vector3(0, 0.85, 0), wood, U.WOOD, 0.6)
	var n := maxi(1, int(ln / 2.2))
	for i in n + 1:
		vis(root, Vector3(0.12, 1.1, 0.12), Vector3(-ln / 2.0 + i * ln / n, 0.55, 0), wood.darkened(0.2), U.WOOD, 0.8)


# cerca em volta (polígono de pontos), com portões nos índices gaps
func fence_ring(pts: Array, gaps: Array, use_wall := false) -> void:
	# guarda o cercado e os portões (os bots usam pra sair)
	var c := Vector2.ZERO
	for q in pts:
		c += q
	c /= pts.size()
	var r := 0.0
	for q in pts:
		r = maxf(r, c.distance_to(q))
	var gates := []
	for i in gaps:
		var g: Vector2 = (pts[i] + pts[(i + 1) % pts.size()]) / 2.0
		var d := (c - g).normalized()
		gates.append([w.ground_pos(g + d * 2.5, 0.3), w.ground_pos(g - d * 3.0, 0.3)])
	w.compounds.append({"c": c, "r": r, "gates": gates})
	for i in pts.size():
		if i in gaps:
			continue
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % pts.size()]
		var y := minf(w.height(a.x, a.y), w.height(b.x, b.y)) - 0.05
		if use_wall:
			low_wall(a, b, y, "concrete", 2.6)
		else:
			fence(a, b, y)


func ruin(pos: Vector3, yaw: float) -> void:
	var root := body(pos, yaw)
	var wd := rng.randf_range(7.0, 11.0)
	var dp := rng.randf_range(6.0, 9.0)
	w.claim(Vector2(pos.x, pos.z), maxf(wd, dp) * 0.7)
	w.houses.append({"pos": Vector2(pos.x, pos.z), "r": maxf(wd, dp) * 0.5, "yaw": yaw, "w": wd, "d": dp})
	var col := Color(1, 1, 1).darkened(rng.randf() * 0.2)
	for side in 4:
		var along := side % 2 == 0
		var length := wd if along else dp
		var fixed := (dp / 2.0 if side == 0 else -dp / 2.0) if along else (wd / 2.0 if side == 1 else -wd / 2.0)
		var n := int(length / 1.1)
		for i in n:
			if rng.randf() < 0.18:
				continue
			var h := rng.randf_range(0.6, 3.2) if rng.randf() < 0.8 else rng.randf_range(0.3, 0.9)
			var x := -length / 2.0 + (i + 0.5) * length / n
			var sz := Vector3(length / n, h, WALL_T + 0.08)
			var p := Vector3(x, h / 2.0, fixed)
			if not along:
				sz = Vector3(WALL_T + 0.08, h, length / n)
				p = Vector3(fixed, h / 2.0, x)
			piece(root, sz, p, col, U.BRICK, 0.5)
	if not headless:
		mb.tex(U.CONCRETE, 0.5)
		for k in 6:
			mb.blob(root.transform * Transform3D(Basis.from_scale(Vector3(rng.randf_range(0.3, 0.9), rng.randf_range(0.2, 0.5), rng.randf_range(0.3, 0.9))), Vector3(rng.randf_range(-wd / 2.0, wd / 2.0), 0.1, rng.randf_range(-dp / 2.0, dp / 2.0))), 6, 3, Color(0.8, 0.7, 0.62), rng, 0.3, false)
	var bs := Basis(Vector3.UP, yaw)
	for k in 2:
		w.add_item(pos + bs * Vector3(rng.randf_range(-wd / 3.0, wd / 3.0), 0.07, rng.randf_range(-dp / 3.0, dp / 3.0)), w.loot_kind(rng, k == 0), null, null)


func watchtower(pos: Vector3, yaw: float) -> void:
	var root := body(pos, yaw)
	var h := 6.0
	var s := 3.2
	var wood := Color(0.9, 0.8, 0.7)
	w.claim(Vector2(pos.x, pos.z), 6.0)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			piece(root, Vector3(0.25, h + 2.6, 0.25), Vector3(sx * s / 2.0, (h + 2.6) / 2.0, sz * s / 2.0), wood, U.WOOD, 0.6)
	piece(root, Vector3(s + 0.4, 0.2, s + 0.4), Vector3(0, h, 0), wood, U.WOOD, 0.5)
	for side in 4:
		var a := side * PI / 2.0
		var rot := Basis(Vector3.UP, a)
		if side == 2:
			continue
		piece(root, Vector3(s + 0.4, 1.05, 0.12), rot * Vector3(0, 0, s / 2.0 + 0.15) + Vector3(0, h + 0.6, 0), wood, U.WOOD, 0.5, true, rot)
	piece(root, Vector3(s + 1.2, 0.12, s + 1.2), Vector3(0, h + 2.65, 0), Color(0.85, 0.85, 0.85), U.METAL, 0.3)
	# escada (rampa) até a plataforma, chegando pelo lado sem guarda-corpo
	var L := 8.0
	var ang := atan2(h, L)
	var ramp := sqrt(L * L + h * h)
	var rz := -s / 2.0 - 0.2 - L / 2.0
	col_box(root, Vector3(1.0, 0.15, ramp), Vector3(0, h / 2.0, rz), Basis(Vector3.RIGHT, -ang))
	if not headless:
		var n := 16
		for i in n:
			vis(root, Vector3(1.0, 0.08, 0.3), Vector3(0, (i + 1) * h / n - 0.04, -s / 2.0 - 0.2 - L + (i + 0.5) * L / n), wood, U.WOOD, 0.8)
		for sx in [-0.55, 0.55]:
			vis(root, Vector3(0.1, 0.18, ramp), Vector3(sx, h / 2.0, rz), wood.darkened(0.25), U.WOOD, 0.6, Basis(Vector3.RIGHT, -ang))
	var bs := Basis(Vector3.UP, yaw)
	w.add_item(pos + bs * Vector3(0.5, h + 0.12, 0.5), w.loot_kind(rng, true), null, null, true)


func water_tower(pos: Vector3) -> void:
	var root := body(pos, rng.randf() * TAU)
	var h := 9.0
	w.claim(Vector2(pos.x, pos.z), 4.0)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			piece(root, Vector3(0.3, h, 0.3), Vector3(sx * 1.4, h / 2.0, sz * 1.4), Color(0.9, 0.9, 0.9), U.CONCRETE, 0.5)
	if not headless:
		mb.tex(U.METAL, 0.3)
		mb.cyl(root.transform * Transform3D(Basis(), Vector3(0, h, 0)), 2.2, 2.2, 3.2, 14, Color(0.85, 0.9, 0.95), true)
		mb.cyl(root.transform * Transform3D(Basis(), Vector3(0, h + 3.2, 0)), 2.3, 0.2, 1.0, 14, Color(0.7, 0.75, 0.8), true)
	col_box(root, Vector3(4.2, 3.2, 4.2), Vector3(0, h + 1.6, 0))


func silo(pos: Vector3) -> void:
	var root := body(pos, 0.0)
	w.claim(Vector2(pos.x, pos.z), 3.5)
	if not headless:
		mb.tex(U.METAL, 0.3)
		mb.cyl(root.transform, 2.3, 2.3, 10.0, 16, Color(0.9, 0.92, 0.95), false)
		mb.cyl(root.transform * Transform3D(Basis(), Vector3(0, 10, 0)), 2.4, 0.3, 2.2, 16, Color(0.75, 0.78, 0.8), true)
	col_box(root, Vector3(4.2, 10, 4.2), Vector3(0, 5, 0))


func hay(pos: Vector3, yaw: float) -> void:
	var root := body(pos, yaw)
	col_box(root, Vector3(1.4, 1.4, 1.5), Vector3(0, 0.7, 0))
	if not headless:
		mb.tex(U.FABRIC, 1.2)
		mb.cyl(root.transform * Transform3D(Basis(Vector3.FORWARD, PI / 2.0), Vector3(-0.75, 0.72, 0)), 0.72, 0.72, 1.5, 12, Color(0.85, 0.72, 0.4), true)


func logs(pos: Vector3, yaw: float) -> void:
	var root := body(pos, yaw)
	w.claim(Vector2(pos.x, pos.z), 4.0)
	col_box(root, Vector3(5.0, 1.4, 2.0), Vector3(0, 0.7, 0))
	if headless:
		return
	mb.tex(U.BARK, 0.6)
	var along := Basis(Vector3.FORWARD, PI / 2.0)
	for row in 3:
		for i in 4 - row:
			var z := -0.75 + i * 0.5 + row * 0.25
			mb.cyl(root.transform * Transform3D(along, Vector3(-2.5, 0.25 + row * 0.44, z)), 0.25, 0.25, 5.0, 8, Color(0.9, 0.85, 0.8), true)


func radio_tower(pos: Vector3) -> void:
	var root := body(pos, rng.randf() * TAU)
	var h := 30.0
	w.claim(Vector2(pos.x, pos.z), 6.0)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var bot := Vector3(sx * 2.2, 0, sz * 2.2)
			var top := Vector3(sx * 0.35, h, sz * 0.35)
			var d := top - bot
			var b := Basis(Quaternion(Vector3.UP, d.normalized()))
			col_box(root, Vector3(0.2, d.length(), 0.2), (top + bot) / 2.0, b)
			if not headless:
				mb.tex(U.METAL, 1.0)
				mb.box(root.transform * Transform3D(b, (top + bot) / 2.0), Vector3(0.16, d.length(), 0.16), Color(0.85, 0.85, 0.85))
	if not headless:
		mb.tex(U.METAL, 1.0)
		for k in 10:
			var y := 1.5 + k * 2.8
			var r := lerpf(2.2, 0.35, y / h)
			var c := Color(0.85, 0.25, 0.2) if k % 2 == 0 else Color(0.9, 0.9, 0.9)
			for side in 4:
				var a := side * PI / 2.0
				mb.box(root.transform * Transform3D(Basis(Vector3.UP, a), Basis(Vector3.UP, a) * Vector3(0, y, r)), Vector3(r * 2.0, 0.1, 0.1), c)
	house(pos + Basis(Vector3.UP, 0.4) * Vector3(7, 0, 2), 0.4 + PI / 2.0, {"w": 5.0, "d": 4.5, "style": "concrete", "roof": "flat"})


func well(pos: Vector3) -> void:
	var root := body(pos, rng.randf() * TAU)
	col_box(root, Vector3(1.6, 0.9, 1.6), Vector3(0, 0.45, 0))
	if not headless:
		mb.tex(U.ROCK, 0.8)
		mb.cyl(root.transform, 0.85, 0.85, 0.9, 12, Color(0.9, 0.88, 0.85), false, false)
		mb.tex(U.WOOD, 0.6)
		for sx in [-0.8, 0.8]:
			mb.box(root.transform * Transform3D(Basis(), Vector3(sx, 1.2, 0)), Vector3(0.12, 1.6, 0.12), Color(0.8, 0.7, 0.6))
		mb.tex(U.ROOF, 0.5)
		for s in [-1.0, 1.0]:
			mb.box(root.transform * Transform3D(Basis(Vector3.RIGHT, s * 0.6), Vector3(0, 2.15, s * 0.42)), Vector3(2.0, 0.08, 1.0), Color(0.9, 0.9, 0.9))


func pole(pos: Vector3, yaw: float) -> void:
	var root := body(pos, yaw)
	col_box(root, Vector3(0.3, 8, 0.3), Vector3(0, 4, 0))
	if not headless:
		mb.tex(U.WOOD, 0.5)
		mb.cyl(root.transform, 0.14, 0.11, 8.0, 6, Color(0.75, 0.65, 0.55), false)
		mb.box(root.transform * Transform3D(Basis(), Vector3(0, 7.3, 0)), Vector3(1.8, 0.12, 0.12), Color(0.7, 0.6, 0.5))


func pier(pos: Vector3, yaw: float, length: float, y: float) -> void:
	var root := body(Vector3(pos.x, y, pos.z), yaw)
	var wood := Color(0.85, 0.78, 0.68)
	piece(root, Vector3(2.4, 0.15, length), Vector3(0, 0, -length / 2.0), wood, U.WOOD, 0.5)
	if not headless:
		for i in int(length / 2.5) + 1:
			for sx in [-1.1, 1.1]:
				vis(root, Vector3(0.18, 2.5, 0.18), Vector3(sx, -1.2, -i * 2.5), wood.darkened(0.3), U.WOOD, 0.6)


func boat(pos: Vector3, yaw: float) -> void:
	var root := body(pos, yaw)
	var c: Color = [Color(0.9, 0.9, 0.88), Color(0.35, 0.5, 0.6), Color(0.6, 0.25, 0.2)][rng.randi() % 3]
	col_box(root, Vector3(1.6, 0.7, 4.0), Vector3(0, 0.35, 0))
	if headless:
		return
	mb.tex(U.WOOD, 0.5)
	for sx in [-1.0, 1.0]:
		mb.box(root.transform * Transform3D(Basis(Vector3.FORWARD, sx * 0.25), Vector3(sx * 0.7, 0.4, 0)), Vector3(0.08, 0.6, 3.6), c)
	mb.box(root.transform * Transform3D(Basis(), Vector3(0, 0.12, 0)), Vector3(1.3, 0.08, 3.6), c.darkened(0.3))
	mb.box(root.transform * Transform3D(Basis(), Vector3(0, 0.45, 0.2)), Vector3(1.4, 0.06, 0.3), c.darkened(0.2))
	mb.box(root.transform * Transform3D(Basis(Vector3.RIGHT, 0.4), Vector3(0, 0.4, -1.9)), Vector3(1.1, 0.6, 0.1), c)


func wagon(pos: Vector3, yaw: float) -> void:
	var root := body(pos, yaw)
	var cols := [Color(0.6, 0.3, 0.2), Color(0.35, 0.4, 0.32), Color(0.4, 0.42, 0.5)]
	var c: Color = cols[rng.randi() % cols.size()]
	w.claim(Vector2(pos.x, pos.z), 7.0)
	piece(root, Vector3(2.9, 2.8, 12.0), Vector3(0, 2.4, 0), c, U.METAL, 0.35)
	piece(root, Vector3(2.4, 0.9, 11.0), Vector3(0, 0.55, 0), Color(0.25, 0.25, 0.25), U.METAL, 0.5)
	if not headless:
		mb.tex(U.METAL, 0.6)
		for sz in [-4.5, -3.2, 3.2, 4.5]:
			for sx in [-0.8, 0.8]:
				mb.cyl(root.transform * Transform3D(Basis(Vector3.FORWARD, PI / 2.0), Vector3(sx - 0.1 * signf(sx), 0.45, sz)), 0.42, 0.42, 0.2, 10, Color(0.3, 0.3, 0.3))


func rails(pts: Array) -> void:
	if headless:
		return
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var d := b - a
		var n := int(d.length() / 1.1)
		var yaw := -atan2(d.y, d.x)
		var rb := MB.new()
		var dir := d.normalized()
		var side := Vector2(-dir.y, dir.x)
		for k in n:
			var p := a + d * (float(k) / n)
			var y := w.height(p.x, p.y)
			rb.tex(U.WOOD, 0.8)
			rb.box(Transform3D(Basis(Vector3.UP, yaw + PI / 2.0), Vector3(p.x, y + 0.06, p.y)), Vector3(2.4, 0.14, 0.25), Color(0.7, 0.6, 0.5))
		var segs := int(d.length() / 6.0)
		for k in segs:
			var p0 := a + d * (float(k) / segs)
			var p1 := a + d * (float(k + 1) / segs)
			for sx in [-0.72, 0.72]:
				var q0: Vector2 = p0 + side * sx
				var q1: Vector2 = p1 + side * sx
				var y0 := w.height(q0.x, q0.y) + 0.2
				var y1 := w.height(q1.x, q1.y) + 0.2
				var mid := Vector3((q0.x + q1.x) / 2.0, (y0 + y1) / 2.0, (q0.y + q1.y) / 2.0)
				var v := Vector3(q1.x - q0.x, y1 - y0, q1.y - q0.y)
				var bs := Basis.looking_at(v.normalized(), Vector3.UP)
				rb.tex(U.METAL, 1.0)
				rb.box(Transform3D(bs, mid), Vector3(0.09, 0.14, v.length() + 0.02), Color(0.45, 0.4, 0.38))
		var mi := MeshInstance3D.new()
		mi.mesh = rb.commit()
		mi.material_override = U.wmat()
		mi.visibility_range_end = 220.0
		w.add_child(mi)


# ---------------- carros ----------------

static func car_mesh(kind: int, tint: Color, wreck: bool) -> Mesh:
	var key := "%d_%s_%s" % [kind, tint.to_html(), wreck]
	if _car_cache.has(key):
		return _car_cache[key]
	var m := MB.new()
	var paint := tint
	var dark := Color(0.12, 0.12, 0.12)
	var glass := Color(0.22, 0.27, 0.3)
	var chrome := Color(0.7, 0.7, 0.72)
	var L := 4.4 if kind == 0 else 5.2
	var W := 1.8
	m.tex(U.PLAIN, 0.5)
	# carroceria de baixo
	m.box(Transform3D(Basis(), Vector3(0, 0.62, 0)), Vector3(W, 0.5, L), paint)
	# para-choques
	m.box(Transform3D(Basis(), Vector3(0, 0.45, -L / 2.0 - 0.06)), Vector3(W + 0.04, 0.22, 0.16), dark)
	m.box(Transform3D(Basis(), Vector3(0, 0.45, L / 2.0 + 0.06)), Vector3(W + 0.04, 0.22, 0.16), dark)
	# faróis e lanternas
	for sx in [-0.62, 0.62]:
		m.box(Transform3D(Basis(), Vector3(sx, 0.72, -L / 2.0 - 0.005)), Vector3(0.38, 0.14, 0.02), Color(0.95, 0.95, 0.85))
		m.box(Transform3D(Basis(), Vector3(sx, 0.72, L / 2.0 + 0.005)), Vector3(0.36, 0.12, 0.02), Color(0.7, 0.08, 0.05))
	m.box(Transform3D(Basis(), Vector3(0, 0.65, -L / 2.0 - 0.005)), Vector3(0.7, 0.12, 0.02), dark)
	# capô inclinado
	m.box(Transform3D(Basis(Vector3.RIGHT, -0.08), Vector3(0, 0.9, -L / 2.0 + 0.65)), Vector3(W - 0.02, 0.08, 1.3), paint)
	if kind == 0:
		# cabine com para-brisa inclinado (sedã)
		_cabin(m, W - 0.1, 0.86, 1.38, -0.75, 1.05, -0.3, 0.65, paint, glass)
		m.box(Transform3D(Basis(Vector3.RIGHT, 0.06), Vector3(0, 0.9, L / 2.0 - 0.55)), Vector3(W - 0.02, 0.08, 1.1), paint)
	else:
		# picape: cabine curta + caçamba aberta
		_cabin(m, W - 0.1, 0.86, 1.55, -1.1, 0.4, -0.75, 0.3, paint, glass)
		m.box(Transform3D(Basis(), Vector3(0, 0.9, 1.5)), Vector3(W, 0.1, 2.1), dark)
		for sx in [-1.0, 1.0]:
			m.box(Transform3D(Basis(), Vector3(sx * (W / 2.0 - 0.04), 1.08, 1.5)), Vector3(0.08, 0.45, 2.1), paint)
		m.box(Transform3D(Basis(), Vector3(0, 1.08, L / 2.0 - 0.04)), Vector3(W, 0.45, 0.08), paint)
	# retrovisores
	for sx in [-1.0, 1.0]:
		m.box(Transform3D(Basis(), Vector3(sx * (W / 2.0 + 0.08), 1.0, -0.6 if kind == 0 else -0.95)), Vector3(0.14, 0.1, 0.06), dark)
	# rodas (com caixa de roda escura)
	var wz := [-L / 2.0 + 0.85, L / 2.0 - 0.85]
	for z in wz:
		for sx in [-1.0, 1.0]:
			m.box(Transform3D(Basis(), Vector3(sx * (W / 2.0 - 0.01), 0.55, z)), Vector3(0.04, 0.32, 0.86), dark)
			if wreck and rng_free(z, sx):
				continue
			var xf := Transform3D(Basis(Vector3.FORWARD, PI / 2.0), Vector3(sx * (W / 2.0 - 0.13) + sx * 0.12, 0.36, z))
			m.cyl(xf, 0.36, 0.36, 0.24, 12, dark)
			m.cyl(Transform3D(Basis(Vector3.FORWARD, PI / 2.0), Vector3(sx * (W / 2.0 + 0.115), 0.36, z)), 0.2, 0.2, 0.01, 10, chrome)
	var mesh := m.commit()
	_car_cache[key] = mesh
	return mesh


static func rng_free(z: float, sx: float) -> bool:
	return int(absf(z * 10.0) + sx * 3.0) % 3 == 0


# cabine: base em y0 de z0 a z1, teto em y1 de z2 a z3 (frente = -Z)
static func _cabin(m: MB, W: float, y0: float, y1: float, z0: float, z1: float, z2: float, z3: float, paint: Color, glass: Color) -> void:
	var hw := W / 2.0
	var tw := hw - 0.08
	var p := {
		"bfl": Vector3(-hw, y0, z0), "bfr": Vector3(hw, y0, z0), "bbl": Vector3(-hw, y0, z1), "bbr": Vector3(hw, y0, z1),
		"tfl": Vector3(-tw, y1, z2), "tfr": Vector3(tw, y1, z2), "tbl": Vector3(-tw, y1, z3), "tbr": Vector3(tw, y1, z3),
	}
	m.quad(p["bfl"], p["bfr"], p["tfr"], p["tfl"], glass, Vector3(0, 0.5, -1).normalized())
	m.quad(p["bbl"], p["bbr"], p["tbr"], p["tbl"], glass, Vector3(0, 0.5, 1).normalized())
	m.quad(p["bfl"], p["bbl"], p["tbl"], p["tfl"], glass, Vector3.LEFT)
	m.quad(p["bfr"], p["bbr"], p["tbr"], p["tfr"], glass, Vector3.RIGHT)
	m.quad(p["tfl"], p["tfr"], p["tbr"], p["tbl"], paint, Vector3.UP)
	# colunas
	var mid := (z0 + z1) / 2.0
	var mt := (z2 + z3) / 2.0
	for sx in [-1.0, 1.0]:
		var a := Vector3(sx * (hw + 0.005), y0, mid)
		var b := Vector3(sx * (tw + 0.005), y1, mt)
		var d := b - a
		m.box(Transform3D(Basis(Quaternion(Vector3.UP, d.normalized())), (a + b) / 2.0), Vector3(0.02, d.length(), 0.1), paint)


func car(pos: Vector3, yaw: float) -> void:
	var kind := 0 if rng.randf() < 0.65 else 1
	var tint: Color = CAR_TINTS[rng.randi() % CAR_TINTS.size()]
	var wreck := rng.randf() < 0.35
	if wreck:
		tint = tint.lerp(Color(0.45, 0.3, 0.2), 0.45)
	var L := 4.4 if kind == 0 else 5.2
	var root := body(pos, yaw)
	w.claim(Vector2(pos.x, pos.z), 3.5)
	col_box(root, Vector3(1.85, 0.95, L), Vector3(0, 0.6, 0))
	col_box(root, Vector3(1.6, 0.6, 1.6), Vector3(0, 1.2, 0.1 if kind == 0 else -0.4))
	if not headless:
		var mi := MeshInstance3D.new()
		mi.mesh = car_mesh(kind, tint, wreck)
		mi.material_override = U.wmat()
		mi.visibility_range_end = 400.0
		root.add_child(mi)
		if wreck:
			mi.rotation.z = 0.04
			mi.position.y = -0.08
