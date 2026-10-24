class_name Build
extends RefCounted

# Constrói as estruturas do mapa (casas, sobrados, galpões, torres, contêineres, carros...).
# Tudo de uma localidade vai numa malha só (self.mb); a colisão vai em caixas.

const FH := 3.65           # altura de um andar
const WALL_T := 0.22
const PLASTER_TINTS := [Color(0.96, 0.93, 0.86), Color(0.92, 0.8, 0.6), Color(0.78, 0.86, 0.9), Color(0.94, 0.76, 0.68),
	Color(0.84, 0.9, 0.78), Color(1, 1, 1), Color(0.86, 0.76, 0.64), Color(0.95, 0.88, 0.7)]
const CAR_TINTS := [Color(0.55, 0.12, 0.1), Color(0.18, 0.25, 0.42), Color(0.85, 0.85, 0.82), Color(0.62, 0.58, 0.45),
	Color(0.15, 0.16, 0.16), Color(0.35, 0.42, 0.3), Color(0.7, 0.55, 0.2)]
const FRAME := Color(0.5, 0.36, 0.25)

var w: World
var mb: MB
var rng := RandomNumberGenerator.new()
var vrng := RandomNumberGenerator.new()
var theme_tints: Array = []           # cores das paredes da cidade (vazio = sorteio geral)
var theme_roof := Color(1, 1, 1)      # tom do telhado da cidade    # sorteios só visuais (o servidor sem tela não usa, então não pode mexer no rng)
var headless := false
static var _car_cache := {}


func _init(world: World) -> void:
	w = world
	headless = world.headless


func begin(seed_v: int) -> void:
	mb = MB.new()
	rng.seed = seed_v
	vrng.seed = seed_v + 7


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
	b.rotation = Vector3(_tx, yaw + _dyaw, _tz)
	if _scale != 1.0:
		b.scale = Vector3.ONE * _scale
	if _skip:
		# objeto apagado no editor: monta "de mentira" (o sorteio continua igual) e joga fora
		_ghosts.append(b)
		return b
	(_cur if _cur else w).add_child(b)
	return b


# ---------------- ajustes feitos à mão (editor de cenário) ----------------

const NO_YAW := ["barrel", "water_tower", "silo", "radio_tower", "well"]
# raio de chão plano embaixo de cada coisa (o terreno se ajeita; nada fica flutuando nem inclinado)
const FOOT := {"monument": 2.4, "windmill": 1.8, "bus": 5.6, "shack": 3.8, "warehouse": 10.0, "church": 11.0, "barracks": 9.8, "store": 7.2, "ruin": 6.5,
	"watchtower": 2.8, "water_tower": 3.2, "silo": 3.4, "radio_tower": 4.2, "well": 1.8,
	"crates": 1.9, "barrel": 0.7, "container": 3.8, "barrier": 1.9, "barricade": 2.0, "gun_crate": 2.0,
	"hay": 1.6, "logs": 3.2, "car": 3.0,
	"hangar": 16.0, "galpao": 8.0, "stilt_hut": 3.6, "tent": 3.2, "bunker": 4.4, "tank_wreck": 4.2, "hedgehog": 1.4,
	"mg_nest": 3.0, "artillery": 2.8, "fuel_tank": 4.0, "checkpoint": 2.2, "barn": 10.5}
const PROPS := ["crates", "barrel", "container", "sandbags", "barrier", "barricade", "gun_crate", "hay", "logs", "car"]
const AB := ["low_wall", "fence"]

var edits: Dictionary = {}     # chave -> ajuste ("e" de MapEdits)
var editor := false            # editor: cada objeto vira um nó separado pra poder mexer
var no_items := false
var no_pads := false         # montando em cima de estrutura (não mexe no terreno)
var reg := {}                  # editor: chave -> dados pra remontar o objeto
var _used := {}
var _depth := 0
var _scale := 1.0
var _dyaw := 0.0
var _tx := 0.0      # inclinação feita à mão no editor
var _tz := 0.0
var _skip := false
var _ghosts: Array = []
var _cur: Node3D = null


# posição e giro originais do objeto (pros muros/cercas: o meio da linha)
static func obj_origin(kind: String, args: Array) -> Array:
	if kind in AB:
		var a: Vector2 = args[0]
		var c: Vector2 = args[1]
		return [Vector3((a.x + c.x) / 2.0, float(args[2]), (a.y + c.y) / 2.0), -atan2(c.y - a.y, c.x - a.x)]
	var yaw := 0.0
	if args.size() > 1 and typeof(args[1]) == TYPE_FLOAT:
		yaw = args[1]
	return [args[0], yaw]


static func _apply_args(kind: String, args: Array, o: Array, e: Dictionary) -> Array:
	var a2 := args.duplicate()
	if e.is_empty():
		return a2
	var np: Vector3 = MapEdits.v3(e["p"]) if e.has("p") else o[0]
	var dr := float(e.get("r", 0.0))
	if kind in AB:
		var mid := Vector2(o[0].x, o[0].z)
		var s := float(e.get("s", 1.0))
		var c2 := Vector2(np.x, np.z)
		a2[0] = c2 + ((args[0] as Vector2) - mid).rotated(-dr) * s
		a2[1] = c2 + ((args[1] as Vector2) - mid).rotated(-dr) * s
		a2[2] = np.y
		return a2
	a2[0] = np
	if not kind in NO_YAW and args.size() > 1 and typeof(args[1]) == TYPE_FLOAT:
		a2[1] = float(args[1]) + dr
	return a2


# área ocupada de cada coisa construída (pra achar uma estrutura dentro da outra)
func _footprint(kind: String, a: Array) -> void:
	var p: Vector3 = a[0]
	var yaw: float = a[1] if a.size() > 1 and typeof(a[1]) == TYPE_FLOAT else 0.0
	if kind == "house":
		var sp: Dictionary = a[2]
		w.footprints.append([kind, Vector2(p.x, p.z), yaw, float(sp.get("w", 8.0)) / 2.0, float(sp.get("d", 7.0)) / 2.0])
	else:
		var r: float = FOOT.get(kind, 1.0)
		w.footprints.append([kind, Vector2(p.x, p.z), yaw, r, r])
		# toda coisa construída reserva o espaço dela (nada nasce em cima depois)
		w.claim(Vector2(p.x, p.z), r * 0.85)


func _obj(kind: String, args: Array, key := "", e_over = null) -> void:
	if _depth > 0:
		callv("_k_" + kind, args)
		return
	var o := obj_origin(kind, args)
	if key == "":
		key = MapEdits.key(kind, o[0])
		while _used.has(key):
			key += "'"
	_used[key] = true
	var e: Dictionary = e_over if e_over != null else edits.get(key, {})
	var st := rng.state
	var vst := vrng.state
	var a2 := _apply_args(kind, args, o, e)
	_skip = bool(e.get("d", false))
	if not _skip:
		_ground_pad(kind, a2, e.has("p"))
	_scale = 1.0 if kind in AB else float(e.get("s", 1.0))
	_dyaw = float(e.get("r", 0.0)) if kind in NO_YAW else 0.0
	_tx = float(e.get("tx", 0.0))
	_tz = float(e.get("tz", 0.0))
	var hs := w.houses.size()
	var its := w.items.size()
	var saved := mb
	if _skip or editor:
		mb = MB.new()
	if editor and not _skip:
		_cur = Node3D.new()
		_cur.set_meta("key", key)
		w.add_child(_cur)
	_depth += 1
	callv("_k_" + kind, a2)
	_depth -= 1
	if not _skip and not kind in AB:
		_footprint(kind, a2)
	if _skip or no_items:
		w.items.resize(its)
	if _skip:
		w.houses.resize(hs)
		for g in _ghosts:
			g.free()
	elif editor and not headless and mb.count > 0:
		var mi := MeshInstance3D.new()
		mi.mesh = mb.commit()
		mi.material_override = U.wmat()
		mi.visibility_range_end = 450.0
		_cur.add_child(mi)
	_ghosts.clear()
	mb = saved
	if editor:
		reg[key] = {"kind": kind, "args": args, "st": st, "vst": vst, "node": _cur, "o": o}
	_cur = null
	_skip = false
	_scale = 1.0
	_dyaw = 0.0
	_tx = 0.0
	_tz = 0.0


# deixa o chão plano embaixo (casas na altura delas; objetos soltos assentam no chão)
func _ground_pad(kind: String, a2: Array, edited: bool) -> void:
	if not (kind in FOOT or kind == "house" or kind == "sandbags"):
		return
	# em cima do deque da cidade alta o chão não sobe atrás das casas
	if no_pads:
		return
	var pos: Vector3 = a2[0]
	if absf(pos.x) > World.SIZE / 2.0 - 4.0 or absf(pos.z) > World.SIZE / 2.0 - 4.0:
		return
	var c := Vector2(pos.x, pos.z)
	var r: float = FOOT.get(kind, 2.0)
	if kind == "house":
		var sp: Dictionary = a2[2]
		r = 0.5 * Vector2(float(sp.get("w", 8.0)), float(sp.get("d", 7.0))).length() + 1.0
		if sp.get("ext_stairs", false) or sp.get("porch", false) or sp.get("balcony", false):
			r += 1.6
	elif kind == "sandbags":
		r = float(a2[2]) / 2.0 + 0.6
	if kind in PROPS:
		if edited:
			return
		var gy := w.height(c.x, c.y)
		a2[0] = Vector3(pos.x, gy - 0.03, pos.z)
		w.add_pad(c, r, gy, 3.0)
	else:
		# a rampa em volta cresce com o desnível (nunca vira barranco)
		w.add_pad(c, r, pos.y + 0.02, maxf(6.0, _pad_blend(c, r, pos.y)))


# largura da rampa em volta do chão plano: ~4x o maior desnível até o terreno em volta
func _pad_blend(c: Vector2, r: float, y: float) -> float:
	var dh := 0.0
	for k in 8:
		var o := Vector2(r + 3.0, 0).rotated(k * TAU / 8.0)
		dh = maxf(dh, absf(w.height(c.x + o.x, c.y + o.y) - y))
	return minf(dh * 3.0, 14.0)


# editor: remonta um objeto depois de mexer nele (mesmo sorteio de antes)
func rebuild(key: String, e_over = null) -> void:
	var info: Dictionary = reg[key]
	if info["node"]:
		(info["node"] as Node).free()
	rng.state = info["st"]
	vrng.state = info["vst"]
	no_items = true
	_obj(info["kind"], info["args"], key, e_over)
	no_items = false


# argumentos de um objeto novo (adicionado no editor) a partir de posição e giro
func new_args(kind: String, pos: Vector3, yaw: float, extra: Array) -> Array:
	if kind in AB:
		var d := Vector2(cos(-yaw), sin(-yaw)) * 2.0
		var c := Vector2(pos.x, pos.z)
		return [c - d, c + d, pos.y]
	if kind in NO_YAW:
		return [pos]
	var args := [pos, yaw]
	if kind == "house":
		args.append(extra[0] if extra.size() > 0 else w._house_spec(rng))
	else:
		args.append_array(extra)
	return args


# objeto adicionado no editor ("a" de MapEdits)
func add_new(ent: Dictionary) -> void:
	rng.seed = int(ent.get("n", 1))
	vrng.seed = int(ent.get("n", 1)) + 7
	var kind: String = ent["k"]
	var pos := MapEdits.v3(ent["p"])
	var args := new_args(kind, pos, float(ent.get("r", 0.0)), ent.get("x", []))
	var e := {"s": ent.get("s", 1.0), "tx": ent.get("tx", 0.0), "tz": ent.get("tz", 0.0)}
	if kind in NO_YAW:
		e["r"] = ent.get("r", 0.0)
	_obj(kind, args, "+%d" % int(ent.get("n", 1)), e)


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
			return [U.BRICK, 0.5, Color(0.86, 0.8, 0.74).darkened(rng.randf() * 0.22)]
		"wood":
			return [U.WOOD, 0.4, Color(1, 1, 1).darkened(rng.randf() * 0.25)]
		"metal":
			return [U.METAL, 0.3, Color(0.92, 0.95, 1.0).darkened(rng.randf() * 0.2)]
		"concrete":
			return [U.CONCRETE, 0.3, Color(0.95, 0.95, 0.92)]
	var tints: Array = theme_tints if not theme_tints.is_empty() else PLASTER_TINTS
	# reboco desbotado e encardido (cidade abandonada às pressas)
	var c: Color = (tints[rng.randi() % tints.size()] as Color).darkened(rng.randf() * 0.1)
	return [U.PLASTER, 0.3, c.lerp(Color(c.get_luminance(), c.get_luminance(), c.get_luminance()), 0.4).darkened(0.08)]


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
	_obj("house", [pos, yaw, spec])


func _k_house(pos: Vector3, yaw: float, spec: Dictionary) -> void:
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
	# casa danificada pela guerra: parede rombuda, fuligem, entulho e às vezes sem telhado
	var dmg: bool = spec.get("damaged", false)
	if dmg:
		col = col.darkened(0.12)
		if roof == "tile" and floors == 1 and rng.randf() < 0.55:
			roof = "burnt"
	var breach_c := rng.randf_range(-dp * 0.2, dp * 0.2)
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
		if roof == "burnt":
			lh = fh - rng.randf_range(0.0, 0.5)
		wall(root, true, -dp / 2.0, wd, lh, y0, front, col, lay, uvs)
		wall(root, true, dp / 2.0, wd, lh, y0, back, col, lay, uvs)
		var side := [_win(0.0)] if dp < 9.0 else [_win(-dp * 0.25), _win(dp * 0.25)]
		if dmg and f == 0:
			# rombo de explosão na parede do lado (sem batente)
			wall(root, false, -wd / 2.0, dp, lh, y0, [[breach_c, 2.0, 0.3, 2.5]], col, lay, uvs, false)
		else:
			wall(root, false, -wd / 2.0, dp, lh, y0, side, col, lay, uvs)
		# do lado da escada não tem janela no térreo
		var rh := [] if (floors > 1 and f == 0) else [_win(-dp * 0.2)]
		if spec.get("ext_stairs", false) and f == floors - 1 and roof == "flat":
			rh.append([-dp / 2.0 + 0.95, 1.1, fh - 0.02, lh + 0.1])
		wall(root, false, wd / 2.0, dp, lh, y0, rh, col, lay, uvs)
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
			_gable(root, wd, dp, top, 1.4 if wd < 11.0 else 1.8, U.ROOF, (theme_roof * Color(0.78, 0.76, 0.74)).darkened(rng.randf() * 0.2), col, lay)
		"metal":
			_gable(root, wd, dp, top, 0.9, U.METAL, Color(0.9, 0.92, 0.95), col, lay)
		"burnt":
			# telhado queimado: só sobraram umas vigas pretas
			for i in 4:
				if rng.randf() < 0.3:
					continue
				var bx := -wd / 2.0 + (i + 0.5) * wd / 4.0
				piece(root, Vector3(0.16, 0.2, dp + 0.3), Vector3(bx, top - 0.35, 0), Color(0.16, 0.13, 0.11), U.WOOD, 0.6, false, Basis(Vector3.FORWARD, rng.randf_range(-0.08, 0.08)))
		_:
			piece(root, Vector3(wd + 0.1, 0.2, dp + 0.1), Vector3(0, top + 0.1, 0), Color(0.85, 0.85, 0.85), U.CONCRETE, 0.3)
			if spec.get("ext_stairs", false):
				_ext_stairs(root, wd, dp, top, col, lay, uvs)
	if balcony:
		var bw := 3.2
		var bd := 1.5
		piece(root, Vector3(bw, 0.18, bd), Vector3(bal_c, fh - 0.09, -dp / 2.0 - bd / 2.0), Color(0.85, 0.85, 0.83), U.CONCRETE, 0.4)
		piece(root, Vector3(bw, 1.0, 0.1), Vector3(bal_c, fh + 0.5, -dp / 2.0 - bd + 0.05), col, lay, uvs)
		for sx in [-1.0, 1.0]:
			piece(root, Vector3(0.1, 1.0, bd), Vector3(bal_c + sx * (bw / 2.0 - 0.05), fh + 0.5, -dp / 2.0 - bd / 2.0), col, lay, uvs)
			piece(root, Vector3(0.16, fh - 0.18, 0.16), Vector3(bal_c + sx * (bw / 2.0 - 0.12), (fh - 0.18) / 2.0, -dp / 2.0 - bd + 0.12), Color(0.9, 0.9, 0.88), U.CONCRETE, 0.4)
	if spec.get("porch", false):
		var pw := minf(wd * 0.7, 5.0)
		var pd := 2.2
		var pc := door_c
		piece(root, Vector3(pw, 0.12, pd), Vector3(pc, 2.75, -dp / 2.0 - pd / 2.0), Color(0.95, 0.95, 0.95), U.ROOF if roof == "tile" else U.METAL, 0.42)
		piece(root, Vector3(pw, 0.12, pd), Vector3(pc, 0.06, -dp / 2.0 - pd / 2.0), Color(0.9, 0.85, 0.8), U.WOOD, 0.4)
		for sx in [-1.0, 1.0]:
			piece(root, Vector3(0.14, 2.7, 0.14), Vector3(pc + sx * (pw / 2.0 - 0.1), 1.35, -dp / 2.0 - pd + 0.1), Color(0.9, 0.85, 0.8), U.WOOD, 0.5)
	if dmg and not headless:
		# fuligem em cima das janelas/porta da frente e entulho no rombo
		for hc in [door_c, -wd * 0.25, wd * 0.25]:
			if vrng.randf() < 0.6:
				vis(root, Vector3(vrng.randf_range(1.2, 2.2), vrng.randf_range(0.6, 1.2), 0.02), Vector3(hc, 2.6, -dp / 2.0 - WALL_T / 2.0 - 0.012), Color(0.12, 0.11, 0.1), U.PLAIN, 1.0)
		rubble(root.transform * Vector3(-wd / 2.0 - 0.9, 0, breach_c), 1.1, 9)
		rubble(root.transform * Vector3(-wd / 2.0 + 0.9, 0.05, breach_c), 0.8, 5)
		if roof == "burnt":
			rubble(root.transform * Vector3(0, 0.05, 0), wd * 0.3, 8, Color(0.3, 0.26, 0.22))
	# loot
	var bs := Basis(Vector3.UP, yaw)
	var door_out := pos + bs * Vector3(door_c, 0.3, -dp / 2.0 - 2.0)
	var door_in := pos + bs * Vector3(door_c, 0.3, -dp / 2.0 + 1.3)
	w.houses[-1]["din"] = door_in
	w.houses[-1]["dout"] = door_out
	if spec.get("ext_stairs", false):
		w.add_item(pos + bs * Vector3(-wd * 0.2, floors * fc_h(spec) + 0.22, 0.5), w.loot_kind(rng, true), null, null, true)
	var n_items := 3 + int(rng.randf() < 0.6) + int(wd * dp > 70.0)
	for k in n_items:
		var lx := rng.randf_range(-wd / 2.0 + 1.0, wd / 2.0 - 1.6)
		if rooms > 1:
			lx = rng.randf_range(-wd / 2.0 + 1.0, -wd * 0.1 - 0.8)
		var local := Vector3(lx, 0.07, rng.randf_range(-dp / 2.0 + 1.5, dp / 2.0 - 1.0))
		w.add_item(pos + bs * local, w.loot_kind(rng, k == 0), door_out, door_in)
	for f in range(1, floors):
		var local := Vector3(rng.randf_range(-wd / 2.0 + 1.0, wd / 2.0 - 2.0), f * fh + 0.12, rng.randf_range(-dp / 2.0 + 1.0, dp / 2.0 - 1.5))
		w.add_item(pos + bs * local, w.loot_kind(rng, rng.randf() < 0.5), null, null, true)


# escada por fora, encostada na parede do lado, subindo pra laje (com patamar e corrimão)
static func fc_h(spec: Dictionary) -> float:
	return float(spec.get("fh", FH))


func _ext_stairs(root: Node3D, wd: float, dp: float, top: float, col: Color, lay: int, uvs: float) -> void:
	var x := wd / 2.0 + 0.7
	var zb := dp / 2.0 - 0.2
	var zt := -dp / 2.0 + 1.6
	var H := top + 0.2
	var L := zb - zt
	var ang := atan2(H, L)
	var ramp := sqrt(L * L + H * H)
	var conc := Color(0.82, 0.8, 0.76)
	col_box(root, Vector3(1.2, 0.15, ramp), Vector3(x, H / 2.0, (zb + zt) / 2.0), Basis(Vector3.RIGHT, ang))
	# patamar na altura da laje, na frente da abertura do parapeito
	piece(root, Vector3(1.3, 0.2, 1.5), Vector3(x, H - 0.1, -dp / 2.0 + 0.85), conc, U.CONCRETE, 0.4)
	piece(root, Vector3(0.08, 1.0, 1.5), Vector3(x + 0.62, H + 0.5, -dp / 2.0 + 0.85), Color(0.3, 0.3, 0.3), U.METAL, 0.5)
	# escada maciça: colisão em 8 blocos embaixo da rampa (ninguém atravessa nem entra por baixo)
	for j in 8:
		var k0 := j / 8.0
		var bh := maxf(k0 * H - 0.05, 0.3)
		col_box(root, Vector3(1.2, bh, L / 8.0 + 0.02), Vector3(x, bh / 2.0, zb - (k0 + 1.0 / 16.0) * L))
	if headless:
		return
	var n := int(H / 0.2)
	for i in n:
		var k := (i + 0.5) / n
		vis(root, Vector3(1.2, 0.2, L / n + 0.02), Vector3(x, k * H - 0.1, zb - k * L), conc, U.CONCRETE, 0.4)
		var bh := maxf(k * H - 0.14, 0.05)
		vis(root, Vector3(1.2, bh, L / n + 0.02), Vector3(x, bh / 2.0, zb - k * L), col, lay, uvs)
	# corrimão
	vis(root, Vector3(0.05, 0.05, ramp), Vector3(x + 0.6, H / 2.0 + 0.9, (zb + zt) / 2.0), Color(0.25, 0.25, 0.25), U.METAL, 0.5, Basis(Vector3.RIGHT, ang))


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
	_obj("shack", [pos, yaw])


func _k_shack(pos: Vector3, yaw: float) -> void:
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
	_obj("warehouse", [pos, yaw])


func _k_warehouse(pos: Vector3, yaw: float) -> void:
	house(pos, yaw, {"w": rng.randf_range(13.0, 16.0), "d": rng.randf_range(9.0, 11.0), "fh": 4.6, "style": "metal",
		"roof": "metal", "door_w": 4.0})
	var bs := Basis(Vector3.UP, yaw)
	for k in 2:
		crates(pos + bs * Vector3(rng.randf_range(-4, 4), 0.05, rng.randf_range(1, 3)), rng.randf() * TAU, false)


func church(pos: Vector3, yaw: float) -> void:
	_obj("church", [pos, yaw])


func _k_church(pos: Vector3, yaw: float) -> void:
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
	_obj("barracks", [pos, yaw])


func _k_barracks(pos: Vector3, yaw: float) -> void:
	house(pos, yaw, {"w": 16.0, "d": 7.0, "style": "concrete", "roof": "flat", "rooms": 2, "door_w": 1.6})


func store(pos: Vector3, yaw: float) -> void:
	_obj("store", [pos, yaw])


func _k_store(pos: Vector3, yaw: float) -> void:
	house(pos, yaw, {"w": 10.0, "d": 8.0, "style": "concrete", "roof": "flat", "door_w": 2.6})


# ---------------- coberturas e objetos ----------------

func crates(pos: Vector3, yaw: float, loot := true) -> void:
	_obj("crates", [pos, yaw, loot])


func _k_crates(pos: Vector3, yaw: float, loot := true) -> void:
	var root := body(pos, yaw)
	var col := Color(1, 1, 1).darkened(rng.randf() * 0.25)
	w.claim(Vector2(pos.x, pos.z), 2.5)
	piece(root, Vector3(1.2, 1.2, 1.2), Vector3(0, 0.6, 0), col, U.WOOD, 0.8)
	piece(root, Vector3(1.2, 1.2, 1.2), Vector3(1.25, 0.6, 0.1), col.darkened(0.12), U.WOOD, 0.8)
	if rng.randf() < 0.6:
		piece(root, Vector3(1.2, 1.2, 1.2), Vector3(0.6, 1.8, 0.05), col.lightened(0.06), U.WOOD, 0.8)
	if loot and rng.randf() < 0.8:
		w.add_item(pos + Vector3(0, 0.07, 0) + Basis(Vector3.UP, yaw) * Vector3(0.6, 0, -1.2), w.loot_kind(rng, false), null, null)


func barrel(pos: Vector3) -> void:
	_obj("barrel", [pos])


func _k_barrel(pos: Vector3) -> void:
	var root := body(pos, 0.0)
	var cols := [Color(0.35, 0.45, 0.6), Color(0.6, 0.25, 0.15), Color(0.4, 0.45, 0.3)]
	var c: Color = cols[rng.randi() % cols.size()]
	if not headless:
		mb.tex(U.METAL, 0.8)
		mb.cyl(root.transform, 0.32, 0.32, 0.95, 10, c, true, true)
	col_box(root, Vector3(0.6, 0.95, 0.6), Vector3(0, 0.475, 0))


func container(pos: Vector3, yaw: float, open := false, stack := false) -> void:
	_obj("container", [pos, yaw, open, stack])


func _k_container(pos: Vector3, yaw: float, open := false, stack := false) -> void:
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
	_obj("sandbags", [pos, yaw, length])


func _k_sandbags(pos: Vector3, yaw: float, length := 3.0) -> void:
	var root := body(pos, yaw)
	var c := Color(0.72, 0.64, 0.48)
	w.claim(Vector2(pos.x, pos.z), length * 0.6)
	# 4 fileiras (~1,3 m): agachado atrás fica bem protegido
	col_box(root, Vector3(length, 1.32, 0.75), Vector3(0, 0.66, 0))
	if headless:
		return
	mb.tex(U.FABRIC, 1.5)
	var n := int(length / 0.55)
	for row in 4:
		for i in n - (row % 2):
			var x := -length / 2.0 + 0.3 + i * 0.55 + (0.27 if row % 2 == 1 else 0.0)
			mb.blob(root.transform * Transform3D(Basis.from_scale(Vector3(0.3, 0.18, 0.34)), Vector3(x, 0.18 + row * 0.33, 0)), 6, 3, c.darkened(rng.randf() * 0.15))


func barrier(pos: Vector3, yaw: float) -> void:
	_obj("barrier", [pos, yaw])


func _k_barrier(pos: Vector3, yaw: float) -> void:
	var root := body(pos, yaw)
	piece(root, Vector3(3.0, 0.5, 0.7), Vector3(0, 0.25, 0), Color(0.9, 0.9, 0.88), U.CONCRETE, 0.5)
	piece(root, Vector3(3.0, 0.5, 0.35), Vector3(0, 0.75, 0), Color(0.9, 0.9, 0.88), U.CONCRETE, 0.5)


# barricada de madeira em X (cavalo de frisa): dois cavaletes cruzados ligados por uma viga
func barricade(pos: Vector3, yaw: float, length := 3.2) -> void:
	_obj("barricade", [pos, yaw, length])


func _k_barricade(pos: Vector3, yaw: float, length := 3.2) -> void:
	var root := body(pos, yaw)
	w.claim(Vector2(pos.x, pos.z), length * 0.55)
	col_box(root, Vector3(length, 1.15, 0.9), Vector3(0, 0.58, 0))
	if headless:
		return
	var wc := Color(0.62, 0.48, 0.34).darkened(vrng.randf() * 0.25)
	var n := 3 if length > 2.5 else 2
	for i in n:
		var x := -length / 2.0 + 0.2 + i * (length - 0.4) / (n - 1)
		for sg in [-1.0, 1.0]:
			vis(root, Vector3(0.13, 1.55, 0.13), Vector3(x, 0.62, 0), wc.darkened(vrng.randf() * 0.1), U.WOOD, 0.6, Basis(Vector3.RIGHT, sg * 0.72))
	vis(root, Vector3(length + 0.2, 0.14, 0.14), Vector3(0, 0.62, 0), wc.darkened(0.1), U.WOOD, 0.6)
	# arame enrolado (só visual)
	vis(root, Vector3(length, 0.03, 0.03), Vector3(0, 1.05, 0.25), Color(0.3, 0.3, 0.3), U.METAL, 0.5)
	vis(root, Vector3(length, 0.03, 0.03), Vector3(0, 1.05, -0.25), Color(0.3, 0.3, 0.3), U.METAL, 0.5)


# caixote militar com uma arma em cima (e a munição do lado, também em cima)
func gun_crate(pos: Vector3, yaw: float, kind := "") -> void:
	_obj("gun_crate", [pos, yaw, kind])


func _k_gun_crate(pos: Vector3, yaw: float, kind := "") -> void:
	var root := body(pos, yaw)
	w.claim(Vector2(pos.x, pos.z), 1.6)
	var olive := Color(0.55, 0.62, 0.42).darkened(rng.randf() * 0.2)
	var h := 0.85
	piece(root, Vector3(1.7, h, 1.25), Vector3(0, h / 2.0, 0), olive, U.WOOD, 0.7)
	if not headless:
		for sx in [-0.6, 0.6]:
			vis(root, Vector3(0.1, h + 0.02, 1.28), Vector3(sx, h / 2.0, 0), olive.darkened(0.3), U.WOOD, 0.7)
		vis(root, Vector3(0.5, 0.012, 0.28), Vector3(0, h * 0.55, -0.632), Color(0.92, 0.9, 0.8), U.PLAIN, 1.0)
	var gun: String = kind if kind != "" else w.loot_kind(rng, true)
	w.add_item(pos + Vector3(0, h + 0.02, 0), gun, null, null, true)
	# um segundo caixote do lado às vezes (cobertura baixa)
	if rng.randf() < 0.5:
		piece(root, Vector3(1.0, 0.6, 0.9), Vector3(1.45, 0.3, 0.15), olive.darkened(0.12), U.WOOD, 0.7)


# entulho (pedaços de tijolo/concreto) espalhado — baixo, só visual
func rubble(pos: Vector3, r: float, n := 6, col := Color(0.72, 0.6, 0.5)) -> void:
	if headless:
		return
	mb.tex(U.BRICK, 0.6)
	for k in n:
		var o := Vector2(vrng.randf_range(-r, r), vrng.randf_range(-r, r))
		var sz := Vector3(vrng.randf_range(0.15, 0.45), vrng.randf_range(0.08, 0.22), vrng.randf_range(0.15, 0.45))
		mb.blob(Transform3D(Basis(Vector3.UP, vrng.randf() * TAU).scaled(sz), pos + Vector3(o.x, sz.y * 0.4, o.y)), 5, 3, col.darkened(vrng.randf() * 0.3), vrng, 0.35, false)


func monument(pos: Vector3, yaw: float) -> void:
	_obj("monument", [pos, yaw])


# marco: pedestal de pedra com estátua de soldado (silhueta) e placa
func _k_monument(pos: Vector3, yaw: float) -> void:
	var root := body(pos, yaw)
	w.claim(Vector2(pos.x, pos.z), 3.5)
	var st := Color(0.72, 0.7, 0.66)
	piece(root, Vector3(3.2, 0.4, 3.2), Vector3(0, 0.2, 0), st.darkened(0.1), U.CONCRETE, 0.4)
	piece(root, Vector3(1.6, 2.2, 1.6), Vector3(0, 1.5, 0), st, U.CONCRETE, 0.4)
	if headless:
		return
	var br := Color(0.32, 0.36, 0.3)
	mb.tex(U.METAL, 1.5)
	var t := root.transform
	mb.box(t * Transform3D(Basis(), Vector3(0, 3.35, 0)), Vector3(0.55, 1.1, 0.35), br)
	mb.blob(t * Transform3D(Basis.from_scale(Vector3(0.17, 0.2, 0.17)), Vector3(0, 4.1, 0)), 8, 5, br)
	for sx in [-0.14, 0.14]:
		mb.box(t * Transform3D(Basis(), Vector3(sx, 2.5, 0)), Vector3(0.2, 0.8, 0.22), br)
	mb.box(t * Transform3D(Basis(Vector3.RIGHT, 0.6), Vector3(0.35, 3.7, -0.25)), Vector3(0.06, 0.06, 1.1), br.darkened(0.2))
	mb.box(t * Transform3D(Basis(), Vector3(-0.38, 3.4, 0)), Vector3(0.16, 0.8, 0.18), br)
	mb.tex(U.PLAIN, 2.0)
	mb.box(t * Transform3D(Basis(), Vector3(0, 1.2, -0.81)), Vector3(1.0, 0.45, 0.02), Color(0.55, 0.45, 0.25))


func windmill(pos: Vector3, yaw: float) -> void:
	_obj("windmill", [pos, yaw])


# catavento de fazenda: torre de ferro alta com hélice
func _k_windmill(pos: Vector3, yaw: float) -> void:
	var root := body(pos, yaw)
	w.claim(Vector2(pos.x, pos.z), 2.5)
	col_box(root, Vector3(1.6, 9.0, 1.6), Vector3(0, 4.5, 0))
	if headless:
		return
	var m := Color(0.45, 0.45, 0.47)
	var t := root.transform
	mb.tex(U.METAL, 1.0)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var a := Vector3(sx * 1.0, 0, sz * 1.0)
			var e := Vector3(sx * 0.2, 9.0, sz * 0.2)
			var d := e - a
			mb.box(t * Transform3D(Basis(Quaternion(Vector3.UP, d.normalized())), (a + e) / 2.0), Vector3(0.1, d.length(), 0.1), m)
	for k in 4:
		var hy := 2.0 + k * 2.0
		var hw := lerpf(1.0, 0.2, hy / 9.0)
		mb.box(t * Transform3D(Basis(), Vector3(0, hy, hw)), Vector3(hw * 2.0, 0.06, 0.06), m)
		mb.box(t * Transform3D(Basis(), Vector3(0, hy, -hw)), Vector3(hw * 2.0, 0.06, 0.06), m)
	mb.box(t * Transform3D(Basis(), Vector3(0, 9.2, 0.3)), Vector3(0.3, 0.3, 1.2), m.darkened(0.2))
	mb.box(t * Transform3D(Basis(), Vector3(0, 9.3, 1.3)), Vector3(0.05, 0.9, 1.0), m)
	for k in 12:
		var a := TAU * k / 12.0
		mb.box(t * Transform3D(Basis(Vector3.FORWARD, a), Vector3(0, 9.2, -0.45) + Vector3(sin(a), cos(a), 0) * 0.9), Vector3(0.28, 1.5, 0.03), Color(0.75, 0.75, 0.72))


func bus(pos: Vector3, yaw: float) -> void:
	_obj("bus", [pos, yaw])


# ônibus queimado atravessado (cobertura grande no meio da cidade)
func _k_bus(pos: Vector3, yaw: float) -> void:
	var root := body(pos, yaw)
	w.claim(Vector2(pos.x, pos.z), 6.0)
	var L := 10.5
	var c := Color(0.32, 0.26, 0.2)
	piece(root, Vector3(2.5, 1.6, L), Vector3(0, 1.3, 0), c, U.METAL, 0.4)
	piece(root, Vector3(2.5, 0.12, L), Vector3(0, 3.05, 0), c.darkened(0.1), U.METAL, 0.4)
	for sx in [-1.0, 1.0]:
		for z in range(-4, 5):
			piece(root, Vector3(0.1, 0.9, 0.12), Vector3(sx * 1.2, 2.55, z * 1.2), c.darkened(0.2), U.METAL, 0.5)
	if headless:
		return
	mb.tex(U.PLAIN, 1.0)
	var t := root.transform
	for z in [-3.4, 3.4]:
		for sx in [-1.0, 1.0]:
			mb.cyl(t * Transform3D(Basis(Vector3.FORWARD, PI / 2.0), Vector3(sx * 1.05, 0.48, z)), 0.48, 0.48, 0.3, 10, Color(0.08, 0.08, 0.08))
	mb.tex(U.METAL, 0.8)
	for k in 8:
		mb.box(t * Transform3D(Basis(Vector3.UP, vrng.randf() * TAU), Vector3(vrng.randf_range(-1.0, 1.0), 2.15, vrng.randf_range(-4.5, 4.5))), Vector3(0.5, 0.04, 0.6), Color(0.12, 0.1, 0.09))


func low_wall(a: Vector2, b: Vector2, y: float, style := "brick", h := 1.1) -> void:
	_obj("low_wall", [a, b, y, style, h])


func _k_low_wall(a: Vector2, b: Vector2, y: float, style := "brick", h := 1.1) -> void:
	var mid := (a + b) / 2.0
	var ln := a.distance_to(b)
	var root := body(Vector3(mid.x, y, mid.y), -atan2(b.y - a.y, b.x - a.x))
	var st := _style_tex(style)
	# base desce até o ponto mais baixo do chão ao longo do muro (sem vão embaixo)
	var dn := 0.0
	if absf(mid.x) < World.SIZE / 2.0:
		for i in 9:
			var q := a.lerp(b, i / 8.0)
			dn = maxf(dn, y - w.height(q.x, q.y))
	dn = minf(dn, 3.0)
	piece(root, Vector3(ln, h + dn, 0.25), Vector3(0, (h - dn) / 2.0, 0), st[2], st[0], st[1])
	if not headless:
		vis(root, Vector3(ln + 0.05, 0.08, 0.32), Vector3(0, h + 0.04, 0), Color(0.85, 0.85, 0.83), U.CONCRETE, 0.5)


func fence(a: Vector2, b: Vector2, y: float) -> void:
	_obj("fence", [a, b, y])


func _k_fence(a: Vector2, b: Vector2, y: float) -> void:
	# cerca acompanha o chão: cada mourão no seu ponto e as tábuas inclinadas entre eles
	var mid := (a + b) / 2.0
	var ln := a.distance_to(b)
	var root := body(Vector3(mid.x, y, mid.y), -atan2(b.y - a.y, b.x - a.x))
	var n := maxi(1, int(ln / 2.2))
	var ys := []
	for i in n + 1:
		var q := a.lerp(b, float(i) / n)
		ys.append(w.height(q.x, q.y) - y if absf(mid.x) < World.SIZE / 2.0 else 0.0)
	var seg := ln / n
	var wood := Color(0.85, 0.75, 0.65)
	for i in n:
		var x0 := -ln / 2.0 + i * seg
		var y0: float = ys[i]
		var y1: float = ys[i + 1]
		var ang := atan2(y1 - y0, seg)
		var rot := Basis(Vector3.BACK, ang)
		var cx := x0 + seg / 2.0
		var cy := (y0 + y1) / 2.0
		var sl := sqrt(seg * seg + (y1 - y0) * (y1 - y0))
		col_box(root, Vector3(sl, 1.0, 0.1), Vector3(cx, cy + 0.5, 0), rot)
		if not headless:
			vis(root, Vector3(sl, 0.12, 0.05), Vector3(cx, cy + 0.45, 0), wood, U.WOOD, 0.6, rot)
			vis(root, Vector3(sl, 0.12, 0.05), Vector3(cx, cy + 0.85, 0), wood, U.WOOD, 0.6, rot)
	if headless:
		return
	for i in n + 1:
		vis(root, Vector3(0.12, 1.4, 0.12), Vector3(-ln / 2.0 + i * seg, float(ys[i]) + 0.4, 0), wood.darkened(0.2), U.WOOD, 0.8)


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
	_obj("ruin", [pos, yaw])


func _k_ruin(pos: Vector3, yaw: float) -> void:
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
			mb.blob(root.transform * Transform3D(Basis.from_scale(Vector3(vrng.randf_range(0.3, 0.9), vrng.randf_range(0.2, 0.5), vrng.randf_range(0.3, 0.9))), Vector3(vrng.randf_range(-wd / 2.0, wd / 2.0), 0.1, vrng.randf_range(-dp / 2.0, dp / 2.0))), 6, 3, Color(0.8, 0.7, 0.62), vrng, 0.3, false)
	var bs := Basis(Vector3.UP, yaw)
	for k in 2:
		w.add_item(pos + bs * Vector3(rng.randf_range(-wd / 3.0, wd / 3.0), 0.07, rng.randf_range(-dp / 3.0, dp / 3.0)), w.loot_kind(rng, k == 0), null, null)


func watchtower(pos: Vector3, yaw: float) -> void:
	_obj("watchtower", [pos, yaw])


func _k_watchtower(pos: Vector3, yaw: float) -> void:
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
	_obj("water_tower", [pos])


func _k_water_tower(pos: Vector3) -> void:
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
	_obj("silo", [pos])


func _k_silo(pos: Vector3) -> void:
	var root := body(pos, 0.0)
	w.claim(Vector2(pos.x, pos.z), 3.5)
	if not headless:
		mb.tex(U.METAL, 0.3)
		mb.cyl(root.transform, 2.3, 2.3, 10.0, 16, Color(0.9, 0.92, 0.95), false)
		mb.cyl(root.transform * Transform3D(Basis(), Vector3(0, 10, 0)), 2.4, 0.3, 2.2, 16, Color(0.75, 0.78, 0.8), true)
	col_box(root, Vector3(4.2, 10, 4.2), Vector3(0, 5, 0))


func hay(pos: Vector3, yaw: float) -> void:
	_obj("hay", [pos, yaw])


func _k_hay(pos: Vector3, yaw: float) -> void:
	var root := body(pos, yaw)
	col_box(root, Vector3(1.4, 1.4, 1.5), Vector3(0, 0.7, 0))
	if not headless:
		mb.tex(U.FABRIC, 1.2)
		mb.cyl(root.transform * Transform3D(Basis(Vector3.FORWARD, PI / 2.0), Vector3(-0.75, 0.72, 0)), 0.72, 0.72, 1.5, 12, Color(0.85, 0.72, 0.4), true)


func logs(pos: Vector3, yaw: float) -> void:
	_obj("logs", [pos, yaw])


func _k_logs(pos: Vector3, yaw: float) -> void:
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
	_obj("radio_tower", [pos])


func _k_radio_tower(pos: Vector3) -> void:
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
	_obj("well", [pos])


func _k_well(pos: Vector3) -> void:
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
	_obj("pole", [pos, yaw])


func _k_pole(pos: Vector3, yaw: float) -> void:
	var root := body(pos, yaw)
	col_box(root, Vector3(0.3, 8, 0.3), Vector3(0, 4, 0))
	if not headless:
		mb.tex(U.WOOD, 0.5)
		mb.cyl(root.transform, 0.14, 0.11, 8.0, 6, Color(0.75, 0.65, 0.55), false)
		mb.box(root.transform * Transform3D(Basis(), Vector3(0, 7.3, 0)), Vector3(1.8, 0.12, 0.12), Color(0.7, 0.6, 0.5))


func pier(pos: Vector3, yaw: float, length: float, y: float) -> void:
	_obj("pier", [pos, yaw, length, y])


func _k_pier(pos: Vector3, yaw: float, length: float, y: float) -> void:
	var root := body(Vector3(pos.x, y, pos.z), yaw)
	var wood := Color(0.85, 0.78, 0.68)
	piece(root, Vector3(2.4, 0.15, length), Vector3(0, 0, -length / 2.0), wood, U.WOOD, 0.5)
	if not headless:
		for i in int(length / 2.5) + 1:
			for sx in [-1.1, 1.1]:
				vis(root, Vector3(0.18, 2.5, 0.18), Vector3(sx, -1.2, -i * 2.5), wood.darkened(0.3), U.WOOD, 0.6)


func boat(pos: Vector3, yaw: float) -> void:
	_obj("boat", [pos, yaw])


func _k_boat(pos: Vector3, yaw: float) -> void:
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
	_obj("wagon", [pos, yaw])


func _k_wagon(pos: Vector3, yaw: float) -> void:
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
	_obj("car", [pos, yaw])


func _k_car(pos: Vector3, yaw: float) -> void:
	var kind := 0 if rng.randf() < 0.65 else 1
	var tint: Color = CAR_TINTS[rng.randi() % CAR_TINTS.size()]
	var wreck := rng.randf() < 0.35
	if wreck:
		tint = tint.lerp(Color(0.45, 0.3, 0.2), 0.45)
	var ci: Dictionary = CarInfo.INFO[kind]
	var L: float = ci["len"]
	var root := body(pos, yaw)
	w.claim(Vector2(pos.x, pos.z), 3.5)
	col_box(root, Vector3(float(ci["wid"]) * 0.92, 1.0, L * 0.95), Vector3(0, 0.62, 0))
	if kind == 0:
		col_box(root, Vector3(1.5, 0.5, 1.9), Vector3(0, 1.2, 0.2))
	if not headless:
		var mi := Vehicle.prop_node(kind, Vehicle.car_material(Vehicle.paint_for(kind, tint).darkened(0.15), 0.55, 0.85 if wreck else 0.15))
		root.add_child(mi)
		if wreck:
			mi.rotation.z = 0.04
			mi.position.y = -0.08


# ---------------- estruturas de guerra e de cidade (cenário pré-guerra) ----------------

# escada reta: rampa na colisão, degraus no desenho. Sai de "top" (beira de cima, altura h em cima de top.y)
# e desce na direção dir (local, horizontal).
func stairs(root: Node3D, top: Vector3, dir: Vector3, h: float, wdt: float, col: Color, solid := true) -> void:
	var L := h * 1.45
	var rot := Basis(Vector3.UP, atan2(dir.x, dir.z))
	var ang := atan2(h, L)
	col_box(root, Vector3(wdt, 0.15, sqrt(L * L + h * h)), top + dir * (L / 2.0) - Vector3(0, h / 2.0 + 0.06, 0), rot * Basis(Vector3.RIGHT, ang))
	if headless:
		return
	var n := maxi(3, int(ceil(h / 0.2)))
	for i in n:
		var sy := h - (i + 1) * h / n
		var c := top + dir * ((i + 0.5) * L / n)
		if solid:
			vis(root, Vector3(wdt, sy + h / n, L / n + 0.01), Vector3(c.x, top.y - h + (sy + h / n) / 2.0, c.z), col.darkened((i % 2) * 0.05), U.CONCRETE, 0.4, rot)
		else:
			vis(root, Vector3(wdt, 0.06, L / n * 0.8), Vector3(c.x, top.y - h + sy + h / n - 0.03, c.z), col, U.WOOD, 0.8, rot)
	if not solid:
		for sx in [-1.0, 1.0]:
			var o := rot * Vector3(sx * (wdt / 2.0 + 0.05), 0, 0)
			vis(root, Vector3(0.08, 0.2, sqrt(L * L + h * h)), top + o + dir * (L / 2.0) - Vector3(0, h / 2.0, 0), col.darkened(0.25), U.WOOD, 0.6, rot * Basis(Vector3.RIGHT, ang))


# guarda-corpo reto de a até b (local), com colisão
func railing(root: Node3D, a: Vector3, b2: Vector3, col: Color, layer := U.METAL, h := 1.0) -> void:
	var d := b2 - a
	var L := Vector2(d.x, d.z).length()
	if L < 0.1:
		return
	var rot := Basis(Vector3.UP, atan2(d.x, d.z))
	var m := (a + b2) / 2.0
	col_box(root, Vector3(0.1, h, L), m + Vector3(0, h / 2.0, 0), rot)
	if headless:
		return
	vis(root, Vector3(0.08, 0.08, L), m + Vector3(0, h, 0), col, layer, 0.6, rot)
	vis(root, Vector3(0.05, 0.05, L), m + Vector3(0, h * 0.5, 0), col, layer, 0.6, rot)
	for i in int(L / 1.5) + 1:
		var p := a + d * (float(i) / maxf(1.0, float(int(L / 1.5))))
		vis(root, Vector3(0.07, h, 0.07), p + Vector3(0, h / 2.0, 0), col.darkened(0.1), layer, 0.6)


# hangar de avião: teto em arco, frente aberta, fundo fechado com porta
func hangar(pos: Vector3, yaw: float) -> void:
	_obj("hangar", [pos, yaw])


func _k_hangar(pos: Vector3, yaw: float) -> void:
	var root := body(pos, yaw)
	var W := 22.0
	var D := 28.0
	var H := 9.0
	var col := Color(0.86, 0.88, 0.82).darkened(rng.randf() * 0.12)
	var bs := Basis(Vector3.UP, yaw)
	w.claim(Vector2(pos.x, pos.z), 17.0)
	piece(root, Vector3(W, 0.12, D), Vector3(0, 0.0, 0), Color(0.7, 0.7, 0.68), U.CONCRETE, 0.25)
	var n := 9
	for k in n:
		var t0 := PI * k / n
		var t1 := PI * (k + 1) / n
		var p0 := Vector2(cos(t0) * W / 2.0, sin(t0) * H)
		var p1 := Vector2(cos(t1) * W / 2.0, sin(t1) * H)
		var dd := p1 - p0
		var rot := Basis(Vector3(0, 0, 1), atan2(dd.y, dd.x))
		piece(root, Vector3(dd.length() + 0.12, 0.2, D), Vector3((p0.x + p1.x) / 2.0, (p0.y + p1.y) / 2.0, 0), col.darkened((k % 2) * 0.06), U.METAL, 0.3, true, rot)
		if not headless:
			for rz in range(-2, 3):
				vis(root, Vector3(dd.length() + 0.1, 0.32, 0.25), Vector3((p0.x + p1.x) / 2.0, (p0.y + p1.y) / 2.0 - 0.12, rz * D / 4.4), col.darkened(0.35), U.METAL, 0.5, rot)
	# fundo (fatias verticais seguindo o arco) com porta no meio; na frente só a testeira de cima
	var sl := 11
	for i in sl:
		var x := -W / 2.0 + (i + 0.5) * W / sl
		# altura pela beira de fora da fatia, um pouco abaixo do arco (não fura o teto)
		var xe := minf(absf(x) + W / sl / 2.0, W / 2.0)
		var hh := H * sqrt(maxf(0.0, 1.0 - pow(xe / (W / 2.0), 2.0))) * 0.96 - 0.15
		if hh < 0.4:
			continue
		if i == sl / 2:
			piece(root, Vector3(W / sl, hh - 2.6, 0.2), Vector3(x, 2.6 + (hh - 2.6) / 2.0, D / 2.0 - 0.1), col, U.METAL, 0.3)
		else:
			piece(root, Vector3(W / sl + 0.02, hh, 0.2), Vector3(x, hh / 2.0, D / 2.0 - 0.1), col, U.METAL, 0.3)
		if hh > 6.8:
			piece(root, Vector3(W / sl + 0.02, hh - 6.8, 0.2), Vector3(x, 6.8 + (hh - 6.8) / 2.0, -D / 2.0 + 0.1), col.darkened(0.08), U.METAL, 0.3)
	if not headless:
		# número pintado e faixa de alerta na entrada
		vis(root, Vector3(4.0, 1.2, 0.02), Vector3(0, 7.6, -D / 2.0 - 0.01), Color(0.9, 0.88, 0.8), U.PLAIN, 1.0)
		for k in 8:
			vis(root, Vector3(1.0, 0.012, 0.5), Vector3(-W / 2.0 + 1.5 + k * 2.7, 0.07, -D / 2.0 + 0.4), Color(0.85, 0.7, 0.15) if k % 2 == 0 else Color(0.12, 0.12, 0.12), U.PLAIN, 1.0)
	# dentro: caixotes, tambores e um bimotor velho desmontado (asa e fuselagem)
	piece(root, Vector3(2.0, 1.6, 8.0), Vector3(-1.5, 1.4, 2.0), Color(0.4, 0.43, 0.38), U.METAL, 0.4)
	piece(root, Vector3(12.0, 0.25, 2.2), Vector3(-1.5, 1.6, 0.5), Color(0.38, 0.41, 0.36), U.METAL, 0.4)
	for sx in [-5.0, 2.0]:
		piece(root, Vector3(0.25, 1.5, 0.25), Vector3(sx, 0.75, 0.5), Color(0.2, 0.2, 0.2), U.METAL, 0.6)
	crates(pos + bs * Vector3(W / 2.0 - 2.5, 0.05, D / 2.0 - 3.0), yaw, false)
	crates(pos + bs * Vector3(-W / 2.0 + 2.8, 0.05, -3.0), yaw + 0.3, false)
	for k in 3:
		barrel(pos + bs * Vector3(W / 2.0 - 2.0 - k * 1.0, 0.05, -D / 2.0 + 4.0 + (k % 2) * 0.9))
	var din := pos + bs * Vector3(0, 0.3, -D / 2.0 + 3.0)
	var dout := pos + bs * Vector3(0, 0.3, -D / 2.0 - 3.0)
	w.houses.append({"pos": Vector2(pos.x, pos.z), "r": 11.0, "yaw": yaw, "w": W, "d": D, "din": din, "dout": dout})
	for k in 4:
		w.add_item(pos + bs * Vector3(rng.randf_range(-W * 0.35, W * 0.35), 0.1, rng.randf_range(-D * 0.35, D * 0.35)), w.loot_kind(rng, k < 2), dout, din)


# galpão industrial comprido: portão grande, janelas altas e mezanino com escada por dentro
func galpao(pos: Vector3, yaw: float) -> void:
	_obj("galpao", [pos, yaw])


func _k_galpao(pos: Vector3, yaw: float) -> void:
	var root := body(pos, yaw)
	var W := rng.randf_range(22.0, 28.0)
	var D := 15.0
	var H := 6.2
	var col: Color = [Color(0.62, 0.58, 0.5), Color(0.5, 0.55, 0.52), Color(0.66, 0.5, 0.42)][rng.randi() % 3].darkened(rng.randf() * 0.15)
	var bs := Basis(Vector3.UP, yaw)
	for k in [-1.0, 0.0, 1.0]:
		var cp: Vector3 = pos + bs * Vector3(k * W / 3.0, 0, 0)
		w.claim(Vector2(cp.x, cp.z), D * 0.58)
	var gx := rng.randf_range(-W * 0.2, W * 0.2)
	var hi := []
	for k in int(W / 5.0):
		var x := -W / 2.0 + 2.5 + k * 5.0
		if absf(x - gx) > 3.6:
			hi.append([x, 2.0, 4.3, 5.4])
	hi.append([gx, 5.0, 0.0, 4.6])
	wall(root, true, -D / 2.0, W, H, 0.0, hi, col, U.METAL, 0.3, false)
	wall(root, true, D / 2.0, W, H, 0.0, [[-W / 2.0 + 3.0, 1.4, 0.0, 2.3], [W / 4.0, 2.0, 4.3, 5.4], [-W / 4.0, 2.0, 4.3, 5.4]], col, U.METAL, 0.3, false)
	wall(root, false, -W / 2.0, D, H, 0.0, [_door(2.0, 1.4), [-3.0, 2.0, 4.3, 5.4]], col, U.METAL, 0.3, false)
	wall(root, false, W / 2.0, D, H, 0.0, [[0.0, 2.0, 4.3, 5.4]], col, U.METAL, 0.3, false)
	piece(root, Vector3(W, 0.12, D), Vector3(0, 0, 0), Color(0.66, 0.65, 0.62), U.CONCRETE, 0.25)
	_gable(root, W, D, H, 2.2, U.METAL, Color(0.75, 0.75, 0.72), col, U.METAL)
	# mezanino no fundo, com guarda-corpo e escada
	var mh := 3.3
	var md := 3.4
	var x0 := -W / 2.0 + 1.8
	var x1 := W / 2.0 - 0.2
	piece(root, Vector3(x1 - x0, 0.18, md), Vector3((x0 + x1) / 2.0, mh, D / 2.0 - md / 2.0 - 0.15), Color(0.42, 0.4, 0.38), U.METAL, 0.4)
	for k in int((x1 - x0) / 4.0) + 1:
		piece(root, Vector3(0.22, mh, 0.22), Vector3(x0 + 0.3 + k * 4.0, mh / 2.0, D / 2.0 - md - 0.05), Color(0.3, 0.3, 0.3), U.METAL, 0.5)
	railing(root, Vector3(x0 + 1.4, mh + 0.09, D / 2.0 - md - 0.1), Vector3(x1, mh + 0.09, D / 2.0 - md - 0.1), Color(0.75, 0.6, 0.15))
	stairs(root, Vector3(x0 + 0.65, mh + 0.09, D / 2.0 - md - 0.15), Vector3(0, 0, -1), mh + 0.09, 1.2, Color(0.4, 0.4, 0.4), false)
	for k in 3:
		crates(pos + bs * Vector3(rng.randf_range(-W * 0.35, W * 0.35), 0.05, rng.randf_range(-D * 0.3, D * 0.05)), yaw + rng.randf_range(-0.3, 0.3), false)
	var din := pos + bs * Vector3(gx, 0.3, -D / 2.0 + 2.0)
	var dout := pos + bs * Vector3(gx, 0.3, -D / 2.0 - 3.0)
	w.houses.append({"pos": Vector2(pos.x, pos.z), "r": D * 0.5, "yaw": yaw, "w": W, "d": D, "din": din, "dout": dout})
	w.add_item(pos + bs * Vector3(rng.randf_range(-W * 0.3, W * 0.3), mh + 0.12, D / 2.0 - md / 2.0), w.loot_kind(rng, true), null, null, true)
	w.add_item(pos + bs * Vector3(rng.randf_range(-W * 0.3, W * 0.3), mh + 0.12, D / 2.0 - md / 2.0), w.loot_kind(rng, false), null, null, true)
	for k in 2:
		w.add_item(pos + bs * Vector3(rng.randf_range(-W * 0.35, W * 0.35), 0.1, rng.randf_range(-D * 0.3, 0.0)), w.loot_kind(rng, k == 0), dout, din)


# casinha pobre de madeira em cima de estacas (chão seco), com varandinha e escada
# linked: a frente da varanda encosta numa passarela (sem guarda-corpo nem escada na frente)
func stilt_hut(pos: Vector3, yaw: float, linked := false) -> void:
	_obj("stilt_hut", [pos, yaw, linked])


func _k_stilt_hut(pos: Vector3, yaw: float, linked := false) -> void:
	var root := body(pos, yaw)
	var h := 2.4 if linked else rng.randf_range(2.0, 2.8)
	var wd := rng.randf_range(3.8, 4.8)
	var dp := 3.8 if linked else rng.randf_range(3.4, 4.0)
	var wh := 2.4
	var col := Color(1.0, 0.88, 0.72).darkened(rng.randf() * 0.3)
	var bs := Basis(Vector3.UP, yaw)
	w.claim(Vector2(pos.x, pos.z), 4.2)
	for sx in [-1.0, 0.0, 1.0]:
		for sz in [-1.0, 1.0]:
			piece(root, Vector3(0.2, h, 0.2), Vector3(sx * (wd / 2.0 - 0.15), h / 2.0, sz * (dp / 2.0 - 0.15)), col.darkened(0.3), U.WOOD, 0.8)
	# estacas da varanda e escoras em X
	for sx in [-1.0, 1.0]:
		piece(root, Vector3(0.16, h, 0.16), Vector3(sx * (wd / 2.0 - 0.15), h / 2.0, -dp / 2.0 - 1.4), col.darkened(0.3), U.WOOD, 0.8)
		vis(root, Vector3(0.08, sqrt(h * h + dp * dp) * 0.9, 0.08), Vector3(sx * (wd / 2.0 - 0.15), h / 2.0, 0), col.darkened(0.4), U.WOOD, 0.8, Basis(Vector3.RIGHT, atan2(dp, h)))
	piece(root, Vector3(wd + 0.2, 0.14, dp + 1.6), Vector3(0, h, -0.8), col, U.WOOD, 0.6)
	wall(root, true, -dp / 2.0, wd, wh, h + 0.07, [_door(-wd * 0.18, 0.9), [wd * 0.22, 0.9, 1.0, 1.7]], col, U.WOOD, 0.45)
	wall(root, true, dp / 2.0, wd, wh, h + 0.07, [[0.0, 0.8, 1.0, 1.6]], col, U.WOOD, 0.45)
	wall(root, false, -wd / 2.0, dp, wh, h + 0.07, [], col.darkened(0.05), U.WOOD, 0.45)
	wall(root, false, wd / 2.0, dp, wh, h + 0.07, [[0.0, 0.8, 1.0, 1.6]], col.darkened(0.05), U.WOOD, 0.45)
	# telhado de zinco torto (uma água), enferrujado
	piece(root, Vector3(wd + 0.7, 0.06, dp + 2.2), Vector3(0, h + wh + 0.35, -0.6), Color(0.62, 0.5, 0.42), U.METAL, 0.3, true, Basis(Vector3.RIGHT, -0.16))
	if not linked:
		railing(root, Vector3(-wd / 2.0, h + 0.07, -dp / 2.0 - 1.55), Vector3(wd / 2.0 - 1.3, h + 0.07, -dp / 2.0 - 1.55), col.darkened(0.2), U.WOOD, 0.9)
		railing(root, Vector3(-wd / 2.0 - 0.02, h + 0.07, -dp / 2.0 - 1.55), Vector3(-wd / 2.0 - 0.02, h + 0.07, -dp / 2.0), col.darkened(0.2), U.WOOD, 0.9)
		stairs(root, Vector3(wd / 2.0 - 0.6, h + 0.07, -dp / 2.0 - 1.6), Vector3(0, 0, -1), h + 0.07, 1.0, col.darkened(0.1), false)
	if not headless:
		# varal, bacia e lenha embaixo da casa
		vis(root, Vector3(0.6, 0.25, 0.6), Vector3(0.6, 0.12, 0.3), Color(0.5, 0.5, 0.5), U.METAL, 0.6)
		for k in 4:
			vis(root, Vector3(1.4, 0.16, 0.16), Vector3(-0.8, 0.08 + k * 0.15, -0.2 + (k % 2) * 0.12), Color(0.55, 0.42, 0.3), U.WOOD, 0.8, Basis(Vector3.UP, k * 0.2))
	if not linked:
		w.houses.append({"pos": Vector2(pos.x, pos.z), "r": 2.4, "yaw": yaw, "w": wd, "d": dp,
			"din": pos + bs * Vector3(-wd * 0.18, h + 0.3, -dp / 2.0 + 1.0), "dout": pos + bs * Vector3(wd / 2.0 - 0.6, 0.3, -dp / 2.0 - 1.6 - h * 1.6)})
	w.add_item(pos + bs * Vector3(rng.randf_range(-wd * 0.3, wd * 0.3), h + 0.14, rng.randf_range(0.0, dp * 0.3)), w.loot_kind(rng, rng.randf() < 0.45), null, null, true)


# passarela (madeira ou concreto) de comprimento L (no Z local), em cima de altura h; pos = chão no meio.
# ends: escada descendo nas duas pontas; rails: guarda-corpo dos lados
func walkway(pos: Vector3, yaw: float, length: float, h: float, wood := true, ends := false, rails := true) -> void:
	_obj("walkway", [pos, yaw, length, h, wood, ends, rails])


func _k_walkway(pos: Vector3, yaw: float, length: float, h: float, wood := true, ends := false, rails := true) -> void:
	var root := body(pos, yaw)
	var col := Color(0.66, 0.55, 0.42).darkened(rng.randf() * 0.2) if wood else Color(0.78, 0.77, 0.74)
	var lay := U.WOOD if wood else U.CONCRETE
	var wd := 1.6 if wood else 2.4
	piece(root, Vector3(wd, 0.14, length), Vector3(0, h, 0), col, lay, 0.6)
	for k in int(length / 3.0) + 1:
		var z := -length / 2.0 + 0.3 + k * (length - 0.6) / maxf(1.0, float(int(length / 3.0)))
		for sx in [-1.0, 1.0]:
			piece(root, Vector3(0.16, h + 2.0, 0.16) if wood else Vector3(0.35, h + 2.0, 0.35), Vector3(sx * (wd / 2.0 - 0.1), h / 2.0 - 1.0, z), col.darkened(0.3), lay, 0.6)
	var bw := Basis(Vector3.UP, yaw)
	for k in int(length / 3.0) + 1:
		var cp: Vector3 = pos + bw * Vector3(0, 0, -length / 2.0 + k * 3.0)
		w.claim(Vector2(cp.x, cp.z), 1.6)
	if rails:
		for sx in [-1.0, 1.0]:
			railing(root, Vector3(sx * wd / 2.0, h + 0.07, -length / 2.0 + 0.4), Vector3(sx * wd / 2.0, h + 0.07, length / 2.0 - 0.4), col.darkened(0.2), lay if wood else U.METAL, 0.95)
	if ends:
		for sg in [-1.0, 1.0]:
			stairs(root, Vector3(0, h + 0.07, sg * length / 2.0), Vector3(0, 0, sg), h + 0.07, wd - 0.1, col.darkened(0.1), not wood)


# plataforma elevada (chão de concreto acima do chão) com pilares, escadas dos dois lados e quiosque em cima
# open: 1 = lado +X sem mureta, 2 = lado -X sem mureta (onde chega uma passarela)
func platform(pos: Vector3, yaw: float, sx: float, sz: float, h: float, open := 0) -> void:
	_obj("platform", [pos, yaw, sx, sz, h, open])


func _k_platform(pos: Vector3, yaw: float, sx: float, sz: float, h: float, open := 0) -> void:
	var root := body(pos, yaw)
	var col := Color(0.74, 0.73, 0.7)
	var bs := Basis(Vector3.UP, yaw)
	w.claim(Vector2(pos.x, pos.z), maxf(sx, sz) * 0.62)
	piece(root, Vector3(sx, 0.35, sz), Vector3(0, h - 0.175, 0), col, U.CONCRETE, 0.3)
	var nx := int(sx / 6.0) + 1
	var nz := int(sz / 6.0) + 1
	for i in nx:
		for j in nz:
			var px := -sx / 2.0 + 0.5 + i * (sx - 1.0) / maxf(1.0, nx - 1)
			var pz := -sz / 2.0 + 0.5 + j * (sz - 1.0) / maxf(1.0, nz - 1)
			piece(root, Vector3(0.6, h + 1.5, 0.6), Vector3(px, (h - 1.5) / 2.0, pz), col.darkened(0.12), U.CONCRETE, 0.4)
	# mureta em volta com abertura das escadas (frente e fundo, cantos opostos)
	var gap := 2.0
	var ex := sx / 2.0 - 1.4
	for sg in [-1.0, 1.0]:
		var zz: float = sg * sz / 2.0
		var gx: float = sg * ex
		railing(root, Vector3(-sx / 2.0, h, zz), Vector3(gx - gap / 2.0, h, zz), Color(0.35, 0.36, 0.34))
		railing(root, Vector3(gx + gap / 2.0, h, zz), Vector3(sx / 2.0, h, zz), Color(0.35, 0.36, 0.34))
		if not (open & (1 if sg > 0 else 2)):
			railing(root, Vector3(sg * sx / 2.0, h, -sz / 2.0), Vector3(sg * sx / 2.0, h, sz / 2.0), Color(0.35, 0.36, 0.34))
		else:
			# mureta só nas pontas, com a passagem de 3 m no meio
			railing(root, Vector3(sg * sx / 2.0, h, -sz / 2.0), Vector3(sg * sx / 2.0, h, -1.6), Color(0.35, 0.36, 0.34))
			railing(root, Vector3(sg * sx / 2.0, h, 1.6), Vector3(sg * sx / 2.0, h, sz / 2.0), Color(0.35, 0.36, 0.34))
		stairs(root, Vector3(gx, h, zz), Vector3(0, 0, sg), h, gap - 0.1, col.darkened(0.05))
	# em cima: quiosque com cobertura, sacos de areia e caixotes (troca de tiro lá do alto)
	for px in [-1.6, 1.6]:
		for pz in [-1.6, 1.6]:
			piece(root, Vector3(0.18, 2.6, 0.18), Vector3(px, h + 1.3, pz), Color(0.3, 0.3, 0.3), U.METAL, 0.6)
	piece(root, Vector3(4.4, 0.1, 4.4), Vector3(0, h + 2.65, 0), Color(0.55, 0.3, 0.22), U.METAL, 0.3)
	sandbags(pos + bs * Vector3(-sx * 0.28, h, sz * 0.2), yaw + 0.2, 3.0)
	sandbags(pos + bs * Vector3(sx * 0.3, h, -sz * 0.22), yaw - 0.15, 3.0)
	crates(pos + bs * Vector3(sx * 0.25, h, sz * 0.28), yaw, false)
	for k in 3:
		w.add_item(pos + bs * Vector3(rng.randf_range(-sx * 0.35, sx * 0.35), h + 0.1, rng.randf_range(-sz * 0.35, sz * 0.35)), w.loot_kind(rng, k == 0), null, null, true)


# tenda militar (lona em V), aberta na frente
func tent(pos: Vector3, yaw: float) -> void:
	_obj("tent", [pos, yaw])


func _k_tent(pos: Vector3, yaw: float) -> void:
	var root := body(pos, yaw)
	var col := Color(0.42, 0.45, 0.32).darkened(rng.randf() * 0.2)
	var W := 3.6
	var D := 5.2
	var H := 2.4
	var bs := Basis(Vector3.UP, yaw)
	w.claim(Vector2(pos.x, pos.z), 3.4)
	var sl := sqrt(H * H + W * W / 4.0)
	for sg in [-1.0, 1.0]:
		piece(root, Vector3(sl, 0.06, D), Vector3(sg * W / 4.0, H / 2.0, 0), col, U.FABRIC, 0.6, true, Basis(Vector3(0, 0, 1), -sg * atan2(H, W / 2.0)))
	if not headless:
		var t := root.transform
		mb.tex(U.FABRIC, 0.6)
		mb.tri(t * Vector3(-W / 2.0, 0, D / 2.0), t * Vector3(W / 2.0, 0, D / 2.0), t * Vector3(0, H, D / 2.0), col.darkened(0.15), bs * Vector3(0, 0, 1))
		mb.tri(t * Vector3(W / 2.0, 0, D / 2.0), t * Vector3(-W / 2.0, 0, D / 2.0), t * Vector3(0, H, D / 2.0), col.darkened(0.3), bs * Vector3(0, 0, -1))
		vis(root, Vector3(0.08, 0.08, D + 0.4), Vector3(0, H, 0), Color(0.3, 0.25, 0.2), U.WOOD, 0.8)
		for sx in [-0.8, 0.8]:
			vis(root, Vector3(0.7, 0.35, 1.9), Vector3(sx, 0.18, 0.6), Color(0.35, 0.38, 0.28), U.FABRIC, 0.8)
	col_box(root, Vector3(W, H * 0.8, 0.1), Vector3(0, H * 0.4, D / 2.0))
	w.add_item(pos + bs * Vector3(0, 0.1, 0.2), w.loot_kind(rng, rng.randf() < 0.4), pos + bs * Vector3(0, 0.3, -D / 2.0 - 1.5), pos + bs * Vector3(0, 0.3, -D / 2.0 + 1.0))


# casamata de concreto: paredes grossas, seteira na frente, porta atrás, sacos de areia no teto
func bunker(pos: Vector3, yaw: float) -> void:
	_obj("bunker", [pos, yaw])


func _k_bunker(pos: Vector3, yaw: float) -> void:
	var root := body(pos, yaw)
	var W := 6.4
	var D := 5.0
	var H := 2.4
	var col := Color(0.62, 0.62, 0.58).darkened(rng.randf() * 0.15)
	var bs := Basis(Vector3.UP, yaw)
	w.claim(Vector2(pos.x, pos.z), 4.8)
	for f in [[true, -D / 2.0, W, [[0.0, 3.6, 1.2, 1.6]]], [true, D / 2.0, W, [[1.6, 1.0, 0.0, 2.0]]], [false, -W / 2.0, D, [[0.0, 1.4, 1.2, 1.6]]], [false, W / 2.0, D, [[0.0, 1.4, 1.2, 1.6]]]]:
		var holes: Array = f[3]
		var segs := []
		var x := -float(f[2]) / 2.0
		for hl in holes:
			segs.append([x, hl[0] - hl[1] / 2.0, 0.0, H])
			if hl[2] > 0.0:
				segs.append([hl[0] - hl[1] / 2.0, hl[0] + hl[1] / 2.0, 0.0, hl[2]])
			segs.append([hl[0] - hl[1] / 2.0, hl[0] + hl[1] / 2.0, hl[3], H])
			x = hl[0] + hl[1] / 2.0
		segs.append([x, float(f[2]) / 2.0, 0.0, H])
		for s in segs:
			var ls: float = s[1] - s[0]
			var hh: float = s[3] - s[2]
			if ls < 0.01 or hh < 0.01:
				continue
			var c := Vector3((s[0] + s[1]) / 2.0, (s[2] + s[3]) / 2.0, f[1])
			if f[0]:
				piece(root, Vector3(ls, hh, 0.5), c, col, U.CONCRETE, 0.3)
			else:
				piece(root, Vector3(0.5, hh, ls), Vector3(f[1], c.y, c.x), col, U.CONCRETE, 0.3)
	piece(root, Vector3(W + 0.6, 0.55, D + 0.6), Vector3(0, H + 0.27, 0), col.darkened(0.08), U.CONCRETE, 0.3)
	piece(root, Vector3(W, 0.1, D), Vector3(0, 0, 0), col.darkened(0.2), U.CONCRETE, 0.4)
	if not headless:
		mb.tex(U.FABRIC, 1.5)
		for i in 9:
			mb.blob(root.transform * Transform3D(Basis.from_scale(Vector3(0.32, 0.18, 0.36)), Vector3(-W / 2.0 + 0.5 + i * 0.7, H + 0.72, -D / 2.0 + 0.2)), 6, 3, Color(0.7, 0.62, 0.46).darkened(vrng.randf() * 0.15))
		mb.tex(U.DIRT, 0.4)
		mb.blob(root.transform * Transform3D(Basis.from_scale(Vector3(W * 0.42, 0.6, D * 0.42)), Vector3(0, H + 0.55, 0.3)), 8, 3, Color(0.5, 0.44, 0.34), vrng, 0.2)
	var din := pos + bs * Vector3(1.6, 0.3, D / 2.0 - 1.0)
	var dout := pos + bs * Vector3(1.6, 0.3, D / 2.0 + 1.8)
	w.houses.append({"pos": Vector2(pos.x, pos.z), "r": 2.6, "yaw": yaw, "w": W, "d": D, "din": din, "dout": dout})
	w.add_item(pos + bs * Vector3(-1.2, 0.1, 0.4), w.loot_kind(rng, true), dout, din)
	w.add_item(pos + bs * Vector3(1.4, 0.1, -0.6), w.loot_kind(rng, false), dout, din)


# tanque de guerra destruído (queimado), boa cobertura
func tank_wreck(pos: Vector3, yaw: float) -> void:
	_obj("tank_wreck", [pos, yaw])


func _k_tank_wreck(pos: Vector3, yaw: float) -> void:
	var root := body(pos, yaw)
	var col := Color(0.3, 0.32, 0.26).lerp(Color(0.16, 0.15, 0.14), rng.randf() * 0.7)
	w.claim(Vector2(pos.x, pos.z), 4.6)
	piece(root, Vector3(3.2, 1.25, 6.4), Vector3(0, 1.0, 0), col, U.METAL, 0.35)
	for sx in [-1.0, 1.0]:
		piece(root, Vector3(0.62, 1.0, 6.9), Vector3(sx * 1.85, 0.5, 0), col.darkened(0.4), U.METAL, 0.5)
	var ty := rng.randf_range(-1.2, 1.2)
	var tr := Basis(Vector3.UP, ty)
	piece(root, Vector3(2.3, 0.85, 2.8), Vector3(0, 2.05, 0.4), col.darkened(0.08), U.METAL, 0.4, true, tr)
	if not headless:
		var droop := rng.randf_range(0.0, 0.22)
		mb.tex(U.METAL, 0.6)
		mb.cyl(root.transform * Transform3D(tr * Basis(Vector3.RIGHT, -PI / 2.0 + droop), Vector3(0, 2.05, 0.4) + tr * Vector3(0, -droop * 1.4, -1.3)), 0.13, 0.11, 4.2, 8, col.darkened(0.2))
		mb.tex(U.PLAIN, 1.0)
		for sx in [-1.0, 1.0]:
			for k in 5:
				mb.cyl(root.transform * Transform3D(Basis(Vector3.FORWARD, PI / 2.0), Vector3(sx * 1.88, 0.42, -2.6 + k * 1.3)), 0.38, 0.38, 0.66, 10, Color(0.1, 0.1, 0.1))
		# manchas de queimado no chão em volta
		mb.cyl(Transform3D(Basis(), pos + Vector3(0, 0.03, 0)), 4.2, 4.2, 0.01, 12, Color(0.12, 0.11, 0.1), true, false, null, 0.35, vrng)
	if rng.randf() < 0.5:
		w.smoke_spots.append(Vector2(pos.x, pos.z))


# cratera de bomba: o chão afunda num buraco raso, com terra revirada e queimado
func crater(pos: Vector3) -> void:
	_obj("crater", [pos])


func _k_crater(pos: Vector3) -> void:
	var r := rng.randf_range(2.5, 4.2)
	var c := Vector2(pos.x, pos.z)
	w.claim(c, r)
	w.add_pad(c, r * 0.35, pos.y - r * 0.32, r * 0.75)
	if headless:
		return
	mb.tex(U.DIRT, 0.5)
	for k in 9:
		var a := TAU * k / 9.0 + vrng.randf() * 0.3
		var p := pos + Vector3(cos(a), 0, sin(a)) * r * 1.05
		mb.blob(Transform3D(Basis(Vector3.UP, a).scaled(Vector3(vrng.randf_range(0.8, 1.4), vrng.randf_range(0.25, 0.45), 0.6)), p), 6, 3, Color(0.42, 0.35, 0.27).darkened(vrng.randf() * 0.25), vrng, 0.3)
	rubble(pos, r * 0.9, 6, Color(0.4, 0.36, 0.32))


# arame farpado em sanfona entre estacas em X (pula por cima com dificuldade, segura bala nenhuma)
func wire(pos: Vector3, yaw: float, length := 6.0) -> void:
	_obj("wire", [pos, yaw, length])


func _k_wire(pos: Vector3, yaw: float, length := 6.0) -> void:
	var root := body(pos, yaw)
	w.claim(Vector2(pos.x, pos.z), length * 0.5)
	col_box(root, Vector3(length, 0.8, 0.9), Vector3(0, 0.4, 0))
	if headless:
		return
	var wc := Color(0.5, 0.4, 0.3)
	var n := int(length / 2.5) + 1
	for i in n:
		var x := -length / 2.0 + i * length / maxf(1.0, n - 1)
		for sg in [-1.0, 1.0]:
			vis(root, Vector3(0.08, 1.2, 0.08), Vector3(x, 0.5, 0), wc, U.WOOD, 0.8, Basis(Vector3.RIGHT, sg * 0.5))
	# espirais de arame (anéis inclinados)
	mb.tex(U.METAL, 1.0)
	var rings := int(length / 0.45)
	for i in rings:
		var x := -length / 2.0 + (i + 0.5) * length / rings
		mb.cyl(root.transform * Transform3D(Basis(Vector3(0, 0, 1), PI / 2.0 + 0.35), Vector3(x, 0.45, 0)), 0.42, 0.42, 0.02, 9, Color(0.32, 0.3, 0.28), false, false)


# ouriço tcheco (três vigas de aço cruzadas): barra carro
func hedgehog(pos: Vector3, yaw: float) -> void:
	_obj("hedgehog", [pos, yaw])


func _k_hedgehog(pos: Vector3, yaw: float) -> void:
	var root := body(pos, yaw)
	w.claim(Vector2(pos.x, pos.z), 1.5)
	var c := Color(0.32, 0.28, 0.24)
	for b3 in [Basis(Vector3(1, 0, 1).normalized(), 0.9), Basis(Vector3(1, 0, -1).normalized(), 0.9), Basis(Vector3.RIGHT, PI / 2.0)]:
		piece(root, Vector3(0.18, 2.1, 0.18), Vector3(0, 0.7, 0), c.darkened(vrng.randf() * 0.2), U.METAL, 0.6, true, b3)


# ninho de metralhadora: anel de sacos de areia com a arma e munição
func mg_nest(pos: Vector3, yaw: float) -> void:
	_obj("mg_nest", [pos, yaw])


func _k_mg_nest(pos: Vector3, yaw: float) -> void:
	var root := body(pos, yaw)
	var bs := Basis(Vector3.UP, yaw)
	w.claim(Vector2(pos.x, pos.z), 3.4)
	var rr := 2.3
	for k in 7:
		var a := -PI * 0.75 + k * PI * 1.5 / 6.0
		var p := Vector3(sin(a) * rr, 0, -cos(a) * rr)
		_k_sandbags(pos + bs * p, yaw - a + PI, 1.8)
	if not headless:
		var gp := Vector3(0, 1.25, -1.5)
		mb.tex(U.METAL, 1.0)
		mb.box(root.transform * Transform3D(Basis(), gp), Vector3(0.22, 0.2, 0.9), Color(0.15, 0.15, 0.14))
		mb.cyl(root.transform * Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), gp + Vector3(0, 0.04, -0.45)), 0.04, 0.04, 0.9, 6, Color(0.1, 0.1, 0.1))
		for k in 3:
			var a := k * TAU / 3.0
			mb.box(root.transform * Transform3D(Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, 0.5), gp + Vector3(sin(a) * 0.25, -0.55, cos(a) * 0.25)), Vector3(0.04, 1.2, 0.04), Color(0.15, 0.15, 0.14))
	w.add_item(pos + bs * Vector3(0.6, 0.1, 0.3), w.loot_kind(rng, true), null, null, true)


# canhão de artilharia de campo (escudo, rodas, cano erguido) com caixas de munição
func artillery(pos: Vector3, yaw: float) -> void:
	_obj("artillery", [pos, yaw])


func _k_artillery(pos: Vector3, yaw: float) -> void:
	var root := body(pos, yaw)
	var c := Color(0.38, 0.4, 0.32).darkened(rng.randf() * 0.2)
	var bs := Basis(Vector3.UP, yaw)
	w.claim(Vector2(pos.x, pos.z), 3.2)
	piece(root, Vector3(2.4, 1.5, 0.12), Vector3(0, 1.15, -0.4), c, U.METAL, 0.4)
	piece(root, Vector3(0.7, 0.7, 1.6), Vector3(0, 0.85, 0.2), c.darkened(0.15), U.METAL, 0.4)
	for sg in [-1.0, 1.0]:
		piece(root, Vector3(0.18, 0.18, 3.0), Vector3(sg * 0.6, 0.35, 1.7), c.darkened(0.2), U.METAL, 0.5, true, Basis(Vector3.UP, sg * 0.25))
	if not headless:
		mb.tex(U.METAL, 0.6)
		mb.cyl(root.transform * Transform3D(Basis(Vector3.RIGHT, -PI / 2.0 + 0.32), Vector3(0, 1.15, -1.9)), 0.12, 0.09, 3.6, 8, c.darkened(0.1))
		for sx in [-1.0, 1.0]:
			mb.cyl(root.transform * Transform3D(Basis(Vector3.FORWARD, PI / 2.0), Vector3(sx * 1.05, 0.6, 0.0)), 0.6, 0.6, 0.18, 12, Color(0.12, 0.12, 0.12))
	crates(pos + bs * Vector3(2.4, 0.0, 1.0), yaw + 0.4, false)
	w.add_item(pos + bs * Vector3(-1.6, 0.1, 1.2), w.loot_kind(rng, false), null, null)


# tanque de combustível deitado em berços (tem que contornar)
func fuel_tank(pos: Vector3, yaw: float) -> void:
	_obj("fuel_tank", [pos, yaw])


func _k_fuel_tank(pos: Vector3, yaw: float) -> void:
	var root := body(pos, yaw)
	var c: Color = [Color(0.82, 0.8, 0.72), Color(0.45, 0.5, 0.4), Color(0.65, 0.3, 0.22)][rng.randi() % 3].darkened(rng.randf() * 0.2)
	var L := rng.randf_range(6.0, 8.0)
	w.claim(Vector2(pos.x, pos.z), L * 0.55)
	col_box(root, Vector3(2.6, 2.6, L), Vector3(0, 1.75, 0))
	for sz in [-L * 0.32, L * 0.32]:
		piece(root, Vector3(2.4, 0.55, 0.4), Vector3(0, 0.28, sz), Color(0.5, 0.5, 0.48), U.CONCRETE, 0.5)
	if not headless:
		mb.tex(U.METAL, 0.3)
		mb.cyl(root.transform * Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, 1.75, -L / 2.0)), 1.3, 1.3, L, 14, c)
		mb.tex(U.PLAIN, 1.0)
		vis(root, Vector3(0.9, 0.18, 0.6), Vector3(0, 3.1, 0), Color(0.3, 0.3, 0.3), U.METAL, 0.6)
		vis(root, Vector3(2.62, 0.5, 0.02), Vector3(0, 1.8, -L / 2.0 - 0.01), Color(0.85, 0.7, 0.15), U.PLAIN, 1.0)


# posto de controle na estrada: guarita, cancela levantada, sacos de areia e ouriços na beira
func checkpoint(pos: Vector3, yaw: float) -> void:
	_obj("checkpoint", [pos, yaw])


func _k_checkpoint(pos: Vector3, yaw: float) -> void:
	var root := body(pos, yaw)
	var bs := Basis(Vector3.UP, yaw)
	var c := Color(0.82, 0.8, 0.74)
	var side := 6.6
	w.claim(Vector2(pos.x, pos.z), 3.0)
	# guarita (2x2) do lado direito
	var gx := side + 0.6
	for f in [[0.0, -1.0], [0.0, 1.0], [-1.0, 0.0], [1.0, 0.0]]:
		var along: bool = f[0] == 0.0
		var hh := 2.5
		var p := Vector3(gx + f[0] * 1.0, 0, f[1] * 1.0)
		if along:
			piece(root, Vector3(2.1, 1.0, 0.12), p + Vector3(0, 0.5, 0), c, U.CONCRETE, 0.4)
			piece(root, Vector3(2.1, 0.3, 0.12), p + Vector3(0, hh - 0.15, 0), c, U.CONCRETE, 0.4)
		elif f[0] > 0.0:
			piece(root, Vector3(0.12, hh, 2.1), p + Vector3(0, hh / 2.0, 0), c, U.CONCRETE, 0.4)
		else:
			piece(root, Vector3(0.12, 1.0, 0.6), p + Vector3(0, 0.5, -0.75), c, U.CONCRETE, 0.4)
			piece(root, Vector3(0.12, 0.3, 2.1), p + Vector3(0, hh - 0.15, 0), c, U.CONCRETE, 0.4)
	piece(root, Vector3(2.6, 0.12, 2.6), Vector3(gx, 2.56, 0), Color(0.75, 0.2, 0.15), U.METAL, 0.4)
	piece(root, Vector3(2.1, 0.1, 2.1), Vector3(gx, 0.0, 0), c.darkened(0.2), U.CONCRETE, 0.4)
	if not headless:
		# cancela levantada (listrada)
		piece(root, Vector3(0.3, 1.1, 0.3), Vector3(side - 0.4, 0.55, -1.6), Color(0.3, 0.3, 0.3), U.METAL, 0.6, false)
		var arm := Basis(Vector3(0, 0, 1), -1.25)
		for k in 6:
			vis(root, Vector3(1.0, 0.12, 0.12), Vector3(side - 0.4, 1.1, -1.6) + arm * Vector3(-0.5 - k * 1.0, 0, 0), Color(0.9, 0.9, 0.88) if k % 2 == 0 else Color(0.8, 0.15, 0.12), U.PLAIN, 1.0, arm)
	_k_sandbags(pos + bs * Vector3(side + 0.4, 0, -3.2), yaw, 3.0)
	_k_sandbags(pos + bs * Vector3(-side - 0.2, 0, -2.4), yaw, 3.2)
	_k_hedgehog(pos + bs * Vector3(-side - 0.8, 0, 2.6), yaw + 0.5)
	_k_hedgehog(pos + bs * Vector3(side + 2.8, 0, 3.4), yaw - 0.3)
	w.add_item(pos + bs * Vector3(gx, 0.1, 0.3), w.loot_kind(rng, true), pos + bs * Vector3(gx - 2.2, 0.3, 0.0), pos + bs * Vector3(gx, 0.3, 0.0))


# trincheira: duas linhas de sacos de areia com escoras de madeira e tábuas no chão
func trench(pos: Vector3, yaw: float, length := 12.0) -> void:
	_obj("trench", [pos, yaw, length])


func _k_trench(pos: Vector3, yaw: float, length := 12.0) -> void:
	var root := body(pos, yaw)
	var bs := Basis(Vector3.UP, yaw)
	w.claim(Vector2(pos.x, pos.z), length * 0.5)
	var seg := 3.0
	var n := int(length / seg)
	for i in n:
		var x := -length / 2.0 + (i + 0.5) * length / n
		var zig := (0.6 if i % 2 == 0 else -0.6)
		_k_sandbags(pos + bs * Vector3(x, 0, -1.0 + zig * 0.3), yaw, length / n + 0.15)
		if i % 3 != 1:
			_k_sandbags(pos + bs * Vector3(x, 0, 1.2 + zig * 0.3), yaw, length / n + 0.15)
	if not headless:
		for i in int(length / 1.2):
			vis(root, Vector3(0.25, 0.04, 1.3), Vector3(-length / 2.0 + 0.6 + i * 1.2, 0.03, 0.1), Color(0.5, 0.4, 0.3), U.WOOD, 0.8)
		for i in n + 1:
			var x := -length / 2.0 + i * length / n
			vis(root, Vector3(0.14, 1.6, 0.14), Vector3(x, 0.8, -0.55), Color(0.42, 0.34, 0.26), U.WOOD, 0.8)
	w.add_item(pos + bs * Vector3(rng.randf_range(-length * 0.3, length * 0.3), 0.08, 0.1), w.loot_kind(rng, rng.randf() < 0.5), null, null)


# celeiro de fazenda: madeira vermelha desbotada, telhado de duas águas alto, portão grande,
# janela do sótão e mezanino de feno com escada por dentro
func barn(pos: Vector3, yaw: float) -> void:
	_obj("barn", [pos, yaw])


func _k_barn(pos: Vector3, yaw: float) -> void:
	var root := body(pos, yaw)
	var W := 12.0
	var D := 16.0
	var H := 5.2
	var col := Color(0.72, 0.28, 0.2).darkened(rng.randf() * 0.2)
	var trim := Color(0.92, 0.9, 0.84)
	var bs := Basis(Vector3.UP, yaw)
	w.claim(Vector2(pos.x, pos.z), 11.0)
	wall(root, true, -D / 2.0, W, H, 0.0, [[0.0, 4.2, 0.0, 4.2]], col, U.WOOD, 0.45, false)
	wall(root, true, D / 2.0, W, H, 0.0, [[0.0, 1.4, 0.0, 2.3]], col, U.WOOD, 0.45, false)
	for sx in [-1.0, 1.0]:
		wall(root, false, sx * W / 2.0, D, H, 0.0, [_win(-4.0), _win(4.0)], col, U.WOOD, 0.45)
	piece(root, Vector3(W, 0.1, D), Vector3(0, 0, 0), Color(0.6, 0.5, 0.38), U.WOOD, 0.5)
	_gable_x(root, W, D, H, 3.4, col)
	# mezanino de feno no fundo + escada
	var mh := 2.9
	piece(root, Vector3(W - 0.4, 0.15, 5.0), Vector3(0, mh, D / 2.0 - 2.7), Color(0.55, 0.45, 0.33), U.WOOD, 0.6)
	railing(root, Vector3(-W / 2.0 + 1.6, mh + 0.08, D / 2.0 - 5.2), Vector3(W / 2.0 - 0.2, mh + 0.08, D / 2.0 - 5.2), Color(0.45, 0.35, 0.25), U.WOOD, 0.9)
	stairs(root, Vector3(-W / 2.0 + 0.8, mh + 0.08, D / 2.0 - 5.25), Vector3(0, 0, -1), mh + 0.08, 1.2, Color(0.5, 0.4, 0.3), false)
	if not headless:
		# portão em X (branco) aberto pros lados, molduras brancas
		for sx in [-1.0, 1.0]:
			vis(root, Vector3(2.1, 4.2, 0.08), Vector3(sx * 3.2, 2.1, -D / 2.0 - 0.6), col.darkened(0.1), U.WOOD, 0.5, Basis(Vector3.UP, sx * 1.1))
		vis(root, Vector3(W + 0.1, 0.18, 0.06), Vector3(0, H - 0.1, -D / 2.0 - 0.12), trim, U.PLAIN, 1.0)
		for sx in [-1.0, 1.0]:
			vis(root, Vector3(0.18, H, 0.06), Vector3(sx * (W / 2.0 - 0.09), H / 2.0, -D / 2.0 - 0.12), trim, U.PLAIN, 1.0)
		# janela do sótão
		vis(root, Vector3(1.6, 1.4, 0.06), Vector3(0, H + 1.4, -D / 2.0 - 0.12), Color(0.12, 0.1, 0.08), U.PLAIN, 1.0)
	# fardos de feno dentro e em cima
	for k in 3:
		hay(pos + bs * Vector3(rng.randf_range(-W * 0.3, W * 0.3), 0.05, rng.randf_range(-D * 0.3, 0.0)), yaw + rng.randf_range(-0.4, 0.4))
	var din := pos + bs * Vector3(0, 0.3, -D / 2.0 + 2.0)
	var dout := pos + bs * Vector3(0, 0.3, -D / 2.0 - 3.0)
	w.houses.append({"pos": Vector2(pos.x, pos.z), "r": 7.0, "yaw": yaw, "w": W, "d": D, "din": din, "dout": dout})
	w.add_item(pos + bs * Vector3(rng.randf_range(-3, 3), mh + 0.12, D / 2.0 - 2.5), w.loot_kind(rng, true), null, null, true)
	for k in 2:
		w.add_item(pos + bs * Vector3(rng.randf_range(-W * 0.35, W * 0.35), 0.1, rng.randf_range(-D * 0.35, 0.0)), w.loot_kind(rng, k == 0), dout, din)


# telhado de duas águas com a cumeeira no comprimento (Z), oitão na frente e atrás
func _gable_x(root: Node3D, wdt: float, dpt: float, y: float, rise: float, wall_col: Color) -> void:
	var ov := 0.5
	var half := wdt / 2.0 + ov
	var slope := atan2(rise, half)
	var slab_w := sqrt(half * half + rise * rise)
	var rc := Color(0.62, 0.6, 0.56)
	for s in [-1.0, 1.0]:
		var rot := Basis(Vector3(0, 0, 1), -s * slope)
		piece(root, Vector3(slab_w, 0.14, dpt + ov * 2.0), Vector3(s * half / 2.0, y + rise / 2.0 + 0.05, 0), rc, U.METAL, 0.35, true, rot)
	if headless:
		return
	var apex := y + rise * (wdt / 2.0) / half
	mb.tex(U.WOOD, 0.45)
	for sz in [-1.0, 1.0]:
		var z: float = sz * dpt / 2.0
		var a := root.transform * Vector3(-wdt / 2.0, y, z)
		var b2 := root.transform * Vector3(wdt / 2.0, y, z)
		var c := root.transform * Vector3(0.0, apex, z)
		var nrm := (root.transform.basis * Vector3(0, 0, sz)).normalized()
		mb.tri(a, b2, c, wall_col, nrm)
		mb.tri(a, b2, c, wall_col.darkened(0.3), -nrm)


# deque gigante (a cidade inteira fica em cima, bem alta): pilares, mureta em volta, escadas largas
# no meio de cada lado e frades de concreto no pé da escada (carro não sobe)
func deck(pos: Vector3, yaw: float, size: float, h: float) -> void:
	_obj("deck", [pos, yaw, size, h])


func _k_deck(pos: Vector3, yaw: float, size: float, h: float) -> void:
	var root := body(pos, yaw)
	var col := Color(0.76, 0.75, 0.72)
	var half := size / 2.0
	piece(root, Vector3(size, 0.5, size), Vector3(0, h - 0.25, 0), col, U.CONCRETE, 0.25)
	if not headless:
		# piso de cima com placas (concreto mais claro) e faixas
		vis(root, Vector3(size - 0.2, 0.02, size - 0.2), Vector3(0, h + 0.01, 0), col.lightened(0.05), U.CONCRETE, 0.2)
	var n := int(size / 7.0) + 1
	for i in n:
		for j in n:
			var px := -half + 0.6 + i * (size - 1.2) / (n - 1)
			var pz := -half + 0.6 + j * (size - 1.2) / (n - 1)
			piece(root, Vector3(0.9, h + 2.0, 0.9), Vector3(px, (h - 2.0) / 2.0, pz), col.darkened(0.15), U.CONCRETE, 0.35)
	var sw := 3.2
	var L := h * 1.45
	for side in 4:
		var rot := Basis(Vector3.UP, side * PI / 2.0)
		var out_dir: Vector3 = rot * Vector3(0, 0, 1)
		var top: Vector3 = rot * Vector3(0, 0, half)
		top.y = h
		# mureta do lado, com a abertura da escada no meio
		var a0: Vector3 = rot * Vector3(-half, 0, half)
		var a1: Vector3 = rot * Vector3(-sw / 2.0, 0, half)
		var b0: Vector3 = rot * Vector3(sw / 2.0, 0, half)
		var b1: Vector3 = rot * Vector3(half, 0, half)
		for seg in [[a0, a1], [b0, b1]]:
			var p0: Vector3 = seg[0]
			var p1: Vector3 = seg[1]
			railing(root, Vector3(p0.x, h, p0.z), Vector3(p1.x, h, p1.z), Color(0.35, 0.36, 0.34))
		stairs(root, top, out_dir, h, sw, col.darkened(0.06))
		# frades no pé da escada: gente passa entre eles, carro não
		var foot: Vector3 = top + out_dir * (L + 0.9)
		foot.y = 0.0
		var rt: Vector3 = rot * Vector3(1, 0, 0)
		for k in 4:
			var bp: Vector3 = foot + rt * (-1.5 + k * 1.0)
			piece(root, Vector3(0.3, 0.9, 0.3), bp + Vector3(0, 0.45, 0), Color(0.85, 0.83, 0.78), U.CONCRETE, 0.5)
	w.claim(Vector2(pos.x, pos.z), half * 0.9)
