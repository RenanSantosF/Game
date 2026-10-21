class_name Weapons
extends RefCounted

# dmg = dano por bala, rate = tiros por segundo, spread = dispersão em graus,
# head = multiplicador de tiro na cabeça, zoom = aumento da mira.
# slot 0 = arma principal (2 vagas), slot 1 = pistola.
const DATA := {
	"fist": {"name": "Soco", "dmg": 18.0, "rate": 2.2, "mag": 1, "reload": 0.0, "spread": 0.0, "range": 2.2, "pellets": 1, "head": 1.5, "zoom": 1.0, "recoil": 0.0, "len": 0.0, "type": "fist", "slot": 2},
	"glock": {"name": "Glock 17", "dmg": 19.0, "rate": 4.5, "mag": 17, "reload": 1.5, "spread": 1.6, "range": 60.0, "pellets": 1, "head": 1.8, "zoom": 1.0, "recoil": 0.012, "len": 0.2, "type": "pistol", "slot": 1},
	"deagle": {"name": "Desert Eagle", "dmg": 45.0, "rate": 2.0, "mag": 7, "reload": 1.9, "spread": 1.8, "range": 80.0, "pellets": 1, "head": 2.0, "zoom": 1.0, "recoil": 0.045, "len": 0.27, "type": "pistol", "slot": 1},
	"mp5": {"name": "MP5", "dmg": 17.0, "rate": 12.0, "mag": 30, "reload": 2.2, "spread": 2.4, "range": 70.0, "pellets": 1, "head": 1.6, "zoom": 1.3, "recoil": 0.008, "len": 0.62, "type": "smg", "slot": 0},
	"ump45": {"name": "UMP-45", "dmg": 21.0, "rate": 9.5, "mag": 25, "reload": 2.3, "spread": 2.2, "range": 75.0, "pellets": 1, "head": 1.6, "zoom": 1.3, "recoil": 0.01, "len": 0.65, "type": "smg", "slot": 0},
	"m4a1": {"name": "M4A1", "dmg": 24.0, "rate": 10.0, "mag": 30, "reload": 2.4, "spread": 1.6, "range": 160.0, "pellets": 1, "head": 1.8, "zoom": 1.6, "recoil": 0.012, "len": 0.85, "type": "rifle", "slot": 0},
	"scar": {"name": "SCAR-L", "dmg": 26.0, "rate": 9.0, "mag": 30, "reload": 2.5, "spread": 1.5, "range": 170.0, "pellets": 1, "head": 1.8, "zoom": 1.8, "recoil": 0.014, "len": 0.88, "type": "scar", "slot": 0},
	"ak47": {"name": "AK-47", "dmg": 31.0, "rate": 8.5, "mag": 30, "reload": 2.6, "spread": 2.2, "range": 160.0, "pellets": 1, "head": 1.8, "zoom": 1.5, "recoil": 0.02, "len": 0.88, "type": "ak", "slot": 0},
	"r870": {"name": "Remington 870", "dmg": 13.0, "rate": 1.2, "mag": 6, "reload": 3.0, "spread": 5.5, "range": 32.0, "pellets": 8, "head": 1.5, "zoom": 1.0, "recoil": 0.05, "len": 1.0, "type": "shotgun", "slot": 0},
	"kar98": {"name": "Kar98k", "dmg": 75.0, "rate": 0.9, "mag": 5, "reload": 3.0, "spread": 3.5, "range": 350.0, "pellets": 1, "head": 2.5, "zoom": 3.0, "recoil": 0.05, "len": 1.1, "type": "bolt", "slot": 0},
	"awm": {"name": "AWM", "dmg": 92.0, "rate": 0.75, "mag": 5, "reload": 3.4, "spread": 4.0, "range": 400.0, "pellets": 1, "head": 2.2, "zoom": 4.0, "recoil": 0.06, "len": 1.2, "type": "sniper", "slot": 0},
}

# Itens que não são armas. stack = quantos cabem numa vaga da mochila.
const ITEMS := {
	"bandage": {"name": "Bandagem", "stack": 10, "count": 5, "kind": "heal", "heal": 15.0, "time": 1.8},
	"med": {"name": "Kit médico", "stack": 3, "count": 1, "kind": "heal", "heal": 60.0, "time": 4.0},
	"vest": {"name": "Colete", "kind": "gear"},
	"helmet": {"name": "Capacete", "kind": "gear"},
	"bag": {"name": "Mochila", "kind": "gear"},
	"stock": {"name": "Coronha", "stack": 1, "count": 1, "kind": "att", "fits": ["smg", "rifle", "scar", "ak", "shotgun"]},
	"extmag": {"name": "Carregador estendido", "stack": 1, "count": 1, "kind": "att", "fits": ["pistol", "smg", "rifle", "scar", "ak", "bolt", "sniper"]},
	"holo": {"name": "Mira holográfica", "stack": 1, "count": 1, "kind": "att", "fits": ["smg", "rifle", "scar", "ak", "shotgun"]},
	"scope4": {"name": "Luneta 4x", "stack": 1, "count": 1, "kind": "att", "fits": ["rifle", "scar", "ak", "bolt"]},
	"silencer": {"name": "Silenciador", "stack": 1, "count": 1, "kind": "att", "fits": ["pistol", "smg", "rifle", "scar", "ak", "bolt", "sniper"]},
}
const ATTS := ["stock", "extmag", "holo", "scope4", "silencer"]
const BAG_BASE := 8
const BAG_BIG := 16

# Loot espalhado pelo mapa (repetido = mais comum)
const LOOT := [
	"mp5", "mp5", "ump45", "ump45", "m4a1", "m4a1", "scar", "ak47", "ak47", "r870", "r870",
	"kar98", "awm", "deagle", "deagle",
	"bandage", "bandage", "bandage", "bandage", "med", "med", "vest", "vest", "helmet", "helmet", "bag", "bag",
	"stock", "extmag", "extmag", "holo", "holo", "scope4", "silencer",
]
const LOOT_GUNS := ["mp5", "ump45", "m4a1", "scar", "ak47", "r870", "kar98", "deagle", "mp5", "m4a1", "ak47"]
const LOOT_MILITARY := ["m4a1", "scar", "ak47", "kar98", "awm", "vest", "helmet", "scope4", "extmag", "med", "bag"]

const SCOPES := ["kar98", "awm"]   # armas com luneta própria (mira preta na tela inteira)

const METAL := Color(0.16, 0.16, 0.17)
const POLY := Color(0.2, 0.2, 0.19)
const WOOD := Color(0.75, 0.55, 0.4)
const TAN := Color(0.62, 0.53, 0.38)

static var _cache := {}


static func get_w(id: String) -> Dictionary:
	if DATA.has(id):
		return DATA[id]
	return DATA["fist"]


static func is_gun(kind: String) -> bool:
	return DATA.has(kind) and kind != "fist"


static func is_att(kind: String) -> bool:
	return ITEMS.has(kind) and ITEMS[kind]["kind"] == "att"


static func fits(att: String, gun: String) -> bool:
	if not is_att(att) or not is_gun(gun):
		return false
	return get_w(gun)["type"] in ITEMS[att]["fits"]


static func item_name(kind: String) -> String:
	if DATA.has(kind):
		return DATA[kind]["name"]
	if ITEMS.has(kind):
		return ITEMS[kind]["name"]
	if kind == "box":
		return "Caixa de loot"
	return kind


static func default_count(kind: String) -> int:
	if ITEMS.has(kind) and ITEMS[kind].has("count"):
		return int(ITEMS[kind]["count"])
	return 1


static func stack_of(kind: String) -> int:
	if ITEMS.has(kind) and ITEMS[kind].has("stack"):
		return int(ITEMS[kind]["stack"])
	return 1


# vagas que um inventário ocupa
static func slots_used(inv: Dictionary) -> int:
	var n := 0
	for k in inv:
		var c: int = inv[k]
		if c > 0:
			n += ceili(float(c) / stack_of(k))
	return n


# status da arma com os acessórios
static func stat(id: String, att: Array) -> Dictionary:
	var w: Dictionary = get_w(id).duplicate()
	if "stock" in att:
		w["recoil"] = float(w["recoil"]) * 0.55
		w["spread"] = float(w["spread"]) * 0.85
	if "extmag" in att:
		w["mag"] = ceili(float(w["mag"]) * 1.5)
		w["reload"] = float(w["reload"]) * 0.9
	w["ads"] = 0.4
	w["overlay"] = id in SCOPES
	if "holo" in att:
		w["zoom"] = maxf(float(w["zoom"]), 1.7)
		w["ads"] = 0.25
	if "scope4" in att:
		w["zoom"] = 4.0
		w["overlay"] = true
		w["ads"] = 0.05
	w["silenced"] = "silencer" in att
	return w


static func _b(m: MB, pos: Vector3, size: Vector3, col: Color, rx := 0.0) -> void:
	m.box(Transform3D(Basis(Vector3.RIGHT, rx), pos), size, col, false)


# cilindro deitado ao longo de -Z, começando em "pos"
static func _tube(m: MB, pos: Vector3, r: float, length: float, col: Color, seg := 6) -> void:
	m.cyl(Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), pos), r, r, length, seg, col, true, true)


static func mesh_for(id: String, att: Array = []) -> Mesh:
	var key := id + "|" + ",".join(att)
	if _cache.has(key):
		return _cache[key]
	var w := get_w(id)
	var L: float = w["len"]
	var t: String = w["type"]
	var m := MB.new()
	m.tex(U.PLAIN, 6.0)
	var body := METAL
	match t:
		"fist":
			pass
		"pistol":
			var c := POLY if id == "glock" else Color(0.45, 0.45, 0.46)
			_b(m, Vector3(0, -0.06, 0.02), Vector3(0.035, 0.12, 0.05), POLY, 0.25)
			_b(m, Vector3(0, 0.025, -L * 0.42), Vector3(0.04, 0.045, L), c)
			_b(m, Vector3(0, -0.012, -L * 0.3), Vector3(0.036, 0.03, L * 0.55), POLY)
			_b(m, Vector3(0, 0.052, -L * 0.88), Vector3(0.008, 0.012, 0.01), METAL)
		"smg", "rifle", "ak", "scar":
			if t == "scar":
				body = TAN
			var furn := WOOD if t == "ak" else (TAN if t == "scar" else POLY)
			_b(m, Vector3(0, -0.07, 0.03), Vector3(0.035, 0.12, 0.05), POLY, 0.3)
			_b(m, Vector3(0, 0.02, -L * 0.18), Vector3(0.05, 0.075, L * 0.5), body)
			if t == "ak":
				m.tex(U.WOOD, 8.0)
			_b(m, Vector3(0, 0.022, -L * 0.55), Vector3(0.052, 0.06, L * 0.3), furn)
			m.tex(U.PLAIN, 6.0)
			_tube(m, Vector3(0, 0.03, -L * 0.68), 0.011, L * 0.32, METAL)
			if t == "ak":
				_b(m, Vector3(0, -0.07, -L * 0.3), Vector3(0.03, 0.14, 0.055), METAL, 0.35)
			elif id == "ump45":
				_b(m, Vector3(0, -0.075, -L * 0.25), Vector3(0.03, 0.13, 0.05), POLY, 0.15)
			else:
				_b(m, Vector3(0, -0.07, -L * 0.25), Vector3(0.028, 0.13, 0.05), METAL, 0.12)
			if "extmag" in att:
				_b(m, Vector3(0, -0.15, -L * 0.27), Vector3(0.03, 0.08, 0.05), METAL, 0.2)
			if t == "ak":
				m.tex(U.WOOD, 8.0)
				_b(m, Vector3(0, -0.01, 0.17), Vector3(0.04, 0.075, 0.26), WOOD, -0.08)
				m.tex(U.PLAIN, 6.0)
			elif t == "smg" and not ("stock" in att):
				_b(m, Vector3(0, 0.0, 0.14), Vector3(0.035, 0.06, 0.2), POLY)
			else:
				_b(m, Vector3(0, -0.005, 0.12), Vector3(0.02, 0.03, 0.14), METAL)
				_b(m, Vector3(0, -0.01, 0.22), Vector3(0.042, 0.09, 0.08), furn)
			if not ("holo" in att or "scope4" in att):
				if t == "rifle" or t == "scar":
					_b(m, Vector3(0, 0.07, -L * 0.12), Vector3(0.022, 0.02, 0.1), METAL)
					_tube(m, Vector3(0, 0.09, -L * 0.07), 0.016, 0.1, METAL)
				elif t == "ak":
					_b(m, Vector3(0, 0.07, -L * 0.62), Vector3(0.008, 0.035, 0.012), METAL)
				else:
					_b(m, Vector3(0, 0.07, -L * 0.05), Vector3(0.03, 0.018, 0.03), METAL)
		"shotgun":
			m.tex(U.WOOD, 8.0)
			_b(m, Vector3(0, -0.06, 0.04), Vector3(0.035, 0.1, 0.05), WOOD, 0.35)
			m.tex(U.PLAIN, 6.0)
			_b(m, Vector3(0, 0.02, -L * 0.1), Vector3(0.05, 0.07, L * 0.25), METAL)
			_tube(m, Vector3(0, 0.035, -L * 0.22), 0.014, L * 0.78, METAL)
			_tube(m, Vector3(0, 0.0, -L * 0.22), 0.013, L * 0.6, METAL)
			m.tex(U.WOOD, 8.0)
			_b(m, Vector3(0, 0.0, -L * 0.48), Vector3(0.045, 0.045, L * 0.2), WOOD)
			_b(m, Vector3(0, -0.02, 0.2), Vector3(0.045, 0.09, 0.3), WOOD, -0.1)
			m.tex(U.PLAIN, 6.0)
		"bolt", "sniper":
			var stock := WOOD if t == "bolt" else Color(0.35, 0.4, 0.3)
			if t == "bolt":
				m.tex(U.WOOD, 8.0)
			_b(m, Vector3(0, -0.005, -L * 0.15), Vector3(0.05, 0.06, L * 0.75), stock)
			_b(m, Vector3(0, -0.03, 0.22), Vector3(0.045, 0.1, 0.3), stock, -0.08)
			_b(m, Vector3(0, -0.05, 0.03), Vector3(0.03, 0.08, 0.04), stock, 0.3)
			m.tex(U.PLAIN, 6.0)
			_b(m, Vector3(0, 0.03, -L * 0.1), Vector3(0.035, 0.035, L * 0.3), METAL)
			_tube(m, Vector3(0, 0.035, -L * 0.25), 0.012, L * 0.75, METAL)
			_b(m, Vector3(0.04, 0.035, 0.0), Vector3(0.04, 0.012, 0.012), METAL)
			_tube(m, Vector3(0, 0.09, 0.05), 0.022, 0.32, METAL, 8)
			_b(m, Vector3(0, 0.065, -0.1), Vector3(0.015, 0.03, 0.03), METAL)
			if t == "sniper":
				_b(m, Vector3(0, -0.05, -L * 0.25), Vector3(0.03, 0.06, 0.08), METAL)
	if "holo" in att:
		_b(m, Vector3(0, 0.075, -L * 0.1), Vector3(0.04, 0.02, 0.07), METAL)
		_b(m, Vector3(0, 0.1, -L * 0.13), Vector3(0.04, 0.035, 0.012), METAL)
		_b(m, Vector3(0, 0.1, -L * 0.07), Vector3(0.04, 0.035, 0.012), METAL)
	if "scope4" in att and t != "bolt":
		_tube(m, Vector3(0, 0.1, 0.02), 0.022, 0.28, METAL, 8)
		_b(m, Vector3(0, 0.072, -0.1), Vector3(0.015, 0.03, 0.03), METAL)
	if "silencer" in att:
		_tube(m, Vector3(0, 0.03 if t != "pistol" else 0.025, -L * (1.0 if t != "pistol" else 0.92)), 0.02, 0.16, METAL, 8)
	var mesh := m.commit()
	_cache[key] = mesh
	return mesh


static func muzzle_len(id: String, att: Array) -> float:
	var L: float = get_w(id)["len"]
	return L + (0.16 if "silencer" in att else 0.0)


# Modelo da arma. Origem no cabo, cano apontando para -Z.
static func build_model(id: String, att: Array = []) -> Node3D:
	var root := Node3D.new()
	var mesh := mesh_for(id, att)
	if mesh:
		U.mesh(root, mesh)
	var muzzle := Node3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, 0.035, -muzzle_len(id, att))
	root.add_child(muzzle)
	return root


static func item_mesh(kind: String) -> Mesh:
	var key := "item_" + kind
	if _cache.has(key):
		return _cache[key]
	var m := MB.new()
	m.tex(U.PLAIN, 4.0)
	var olive := Color(0.38, 0.42, 0.28)
	match kind:
		"med":
			m.boxp(Vector3(0, 0.1, 0), Vector3(0.42, 0.2, 0.3), Color(0.9, 0.9, 0.88))
			m.boxp(Vector3(0, 0.201, 0), Vector3(0.22, 0.005, 0.06), Color(0.8, 0.1, 0.1))
			m.boxp(Vector3(0, 0.201, 0), Vector3(0.06, 0.005, 0.2), Color(0.8, 0.1, 0.1))
			m.boxp(Vector3(0, 0.23, 0), Vector3(0.14, 0.03, 0.03), Color(0.2, 0.2, 0.2))
		"bandage":
			m.tex(U.FABRIC, 6.0)
			for k in 3:
				m.cyl(Transform3D(Basis(), Vector3(k * 0.13 - 0.13, 0, 0)), 0.055, 0.055, 0.1, 10, Color(0.95, 0.93, 0.88))
		"vest":
			m.tex(U.FABRIC, 3.0)
			m.boxp(Vector3(0, 0.06, 0), Vector3(0.5, 0.12, 0.6), olive)
			m.boxp(Vector3(0, 0.13, -0.12), Vector3(0.4, 0.04, 0.2), olive.darkened(0.15))
			m.boxp(Vector3(0, 0.13, 0.15), Vector3(0.3, 0.04, 0.16), olive.darkened(0.2))
		"helmet":
			m.blob(Transform3D(Basis.from_scale(Vector3(0.18, 0.15, 0.21)), Vector3(0, 0.02, 0)), 10, 4, olive)
		"bag":
			m.tex(U.FABRIC, 3.0)
			m.boxp(Vector3(0, 0.12, 0), Vector3(0.45, 0.24, 0.55), Color(0.45, 0.4, 0.3))
			m.boxp(Vector3(0, 0.12, -0.3), Vector3(0.32, 0.16, 0.08), Color(0.4, 0.36, 0.27))
		"box":
			m.tex(U.METAL, 1.5)
			m.boxp(Vector3(0, 0.25, 0), Vector3(0.9, 0.5, 0.6), olive)
			m.boxp(Vector3(0, 0.52, 0), Vector3(0.94, 0.06, 0.64), olive.darkened(0.2))
			m.tex(U.PLAIN, 4.0)
			m.boxp(Vector3(0, 0.3, -0.31), Vector3(0.3, 0.12, 0.02), Color(0.9, 0.75, 0.2))
		_:
			# acessórios: caixinha com uma faixa de cor
			var cols := {"stock": Color(0.3, 0.3, 0.3), "extmag": Color(0.6, 0.5, 0.2), "holo": Color(0.2, 0.5, 0.6), "scope4": Color(0.25, 0.3, 0.55), "silencer": Color(0.45, 0.45, 0.45)}
			m.boxp(Vector3(0, 0.06, 0), Vector3(0.3, 0.12, 0.2), Color(0.2, 0.2, 0.2))
			m.boxp(Vector3(0, 0.121, 0), Vector3(0.3, 0.005, 0.06), cols.get(kind, Color.WHITE))
	var mesh := m.commit()
	_cache[key] = mesh
	return mesh


# Modelo de item no chão (arma deitada, kit, colete, capacete, caixa)
static func build_item(kind: String) -> Node3D:
	var root := Node3D.new()
	if is_gun(kind):
		var g := build_model(kind)
		g.rotation = Vector3(0, 0, PI / 2.0)
		g.position.y = 0.05
		g.scale = Vector3(1.25, 1.25, 1.25)
		root.add_child(g)
		for c in g.get_children():
			if c is MeshInstance3D:
				c.visibility_range_end = 80.0
				c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return root
	var mi := U.mesh(root, item_mesh(kind))
	mi.visibility_range_end = 120.0 if kind == "box" else 80.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root
