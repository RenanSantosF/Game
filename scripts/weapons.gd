class_name Weapons
extends RefCounted

# dmg = dano por bala, rate = tiros por segundo, spread = dispersão em graus,
# head = multiplicador de tiro na cabeça, zoom = aumento da mira, ammo = calibre.
# slot 0 = arma principal (2 vagas), slot 1 = pistola. Vida de cada jogador: 200.
const DATA := {
	"fist": {"name": "Soco", "dmg": 25.0, "rate": 2.2, "mag": 1, "reload": 0.0, "spread": 0.0, "range": 2.2, "pellets": 1, "head": 1.5, "zoom": 1.0, "recoil": 0.0, "len": 0.0, "type": "fist", "slot": 2, "ammo": ""},
	"glock": {"name": "Glock 17", "dmg": 30.0, "rate": 4.5, "mag": 17, "reload": 1.5, "spread": 1.6, "range": 60.0, "pellets": 1, "head": 1.8, "zoom": 1.0, "recoil": 0.012, "len": 0.2, "type": "pistol", "slot": 1, "ammo": "a9"},
	"deagle": {"name": "Desert Eagle", "dmg": 72.0, "rate": 2.0, "mag": 7, "reload": 1.9, "spread": 1.8, "range": 80.0, "pellets": 1, "head": 2.0, "zoom": 1.0, "recoil": 0.045, "len": 0.27, "type": "pistol", "slot": 1, "ammo": "a9"},
	"mp5": {"name": "MP5", "dmg": 27.0, "rate": 12.0, "mag": 30, "reload": 2.2, "spread": 2.4, "range": 70.0, "pellets": 1, "head": 1.6, "zoom": 1.3, "recoil": 0.008, "len": 0.62, "type": "smg", "slot": 0, "ammo": "a9"},
	"ump45": {"name": "UMP-45", "dmg": 34.0, "rate": 9.5, "mag": 25, "reload": 2.3, "spread": 2.2, "range": 75.0, "pellets": 1, "head": 1.6, "zoom": 1.3, "recoil": 0.01, "len": 0.65, "type": "smg", "slot": 0, "ammo": "a9"},
	"m4a1": {"name": "M4A1", "dmg": 38.0, "rate": 10.0, "mag": 30, "reload": 2.4, "spread": 1.6, "range": 160.0, "pellets": 1, "head": 1.8, "zoom": 1.6, "recoil": 0.012, "len": 0.85, "type": "rifle", "slot": 0, "ammo": "a556"},
	"scar": {"name": "SCAR-L", "dmg": 41.0, "rate": 9.0, "mag": 30, "reload": 2.5, "spread": 1.5, "range": 170.0, "pellets": 1, "head": 1.8, "zoom": 1.8, "recoil": 0.014, "len": 0.88, "type": "scar", "slot": 0, "ammo": "a556"},
	"ak47": {"name": "AK-47", "dmg": 50.0, "rate": 8.5, "mag": 30, "reload": 2.6, "spread": 2.2, "range": 160.0, "pellets": 1, "head": 1.8, "zoom": 1.5, "recoil": 0.02, "len": 0.88, "type": "ak", "slot": 0, "ammo": "a762"},
	"r870": {"name": "Remington 870", "dmg": 21.0, "rate": 1.2, "mag": 6, "reload": 3.0, "spread": 5.5, "range": 32.0, "pellets": 8, "head": 1.5, "zoom": 1.0, "recoil": 0.05, "len": 1.0, "type": "shotgun", "slot": 0, "ammo": "a12"},
	"m1014": {"name": "M1014", "dmg": 17.0, "rate": 3.2, "mag": 7, "reload": 3.2, "spread": 6.0, "range": 28.0, "pellets": 8, "head": 1.5, "zoom": 1.0, "recoil": 0.04, "len": 1.0, "type": "shotgun", "slot": 0, "ammo": "a12"},
	"kar98": {"name": "Kar98k", "dmg": 120.0, "rate": 0.9, "mag": 5, "reload": 3.0, "spread": 3.5, "range": 350.0, "pellets": 1, "head": 2.5, "zoom": 3.0, "recoil": 0.05, "len": 1.1, "type": "bolt", "slot": 0, "ammo": "a762"},
	"awm": {"name": "AWM", "dmg": 150.0, "rate": 0.75, "mag": 5, "reload": 3.4, "spread": 4.0, "range": 400.0, "pellets": 1, "head": 2.2, "zoom": 4.0, "recoil": 0.06, "len": 1.2, "type": "sniper", "slot": 0, "ammo": "a762"},
}

# Itens que não são armas. stack = quantos cabem numa vaga da mochila; count = quanto vem no chão.
const ITEMS := {
	"a9": {"name": "Munição 9mm", "stack": 60, "count": 30, "kind": "ammo"},
	"a556": {"name": "Munição 5.56", "stack": 60, "count": 30, "kind": "ammo"},
	"a762": {"name": "Munição 7.62", "stack": 60, "count": 25, "kind": "ammo"},
	"a12": {"name": "Cartucho 12", "stack": 30, "count": 12, "kind": "ammo"},
	"bandage": {"name": "Bandagem", "stack": 10, "count": 4, "kind": "heal", "heal": 30.0, "time": 2.0},
	"med": {"name": "Kit médico", "stack": 4, "count": 1, "kind": "heal", "heal": 100.0, "time": 4.5},
	"vest": {"name": "Colete", "kind": "gear"},
	"helmet": {"name": "Capacete", "kind": "gear"},
	"bag1": {"name": "Mochila nível 1", "kind": "gear", "level": 1},
	"bag2": {"name": "Mochila nível 2", "kind": "gear", "level": 2},
	"bag3": {"name": "Mochila nível 3", "kind": "gear", "level": 3},
	"stock": {"name": "Coronha", "stack": 1, "count": 1, "kind": "att", "fits": ["smg", "rifle", "scar", "ak", "shotgun"]},
	"extmag": {"name": "Carregador estendido", "stack": 1, "count": 1, "kind": "att", "fits": ["pistol", "smg", "rifle", "scar", "ak", "bolt", "sniper"]},
	"holo": {"name": "Mira holográfica", "stack": 1, "count": 1, "kind": "att", "fits": ["smg", "rifle", "scar", "ak", "shotgun"]},
	"scope4": {"name": "Luneta 4x", "stack": 1, "count": 1, "kind": "att", "fits": ["rifle", "scar", "ak", "bolt"]},
	"silencer": {"name": "Silenciador", "stack": 1, "count": 1, "kind": "att", "fits": ["pistol", "smg", "rifle", "scar", "ak", "bolt", "sniper"]},
}
const ATTS := ["stock", "extmag", "holo", "scope4", "silencer"]
const AMMO := ["a9", "a556", "a762", "a12"]
const BAGS := [6, 10, 14, 18]       # vagas sem mochila e com mochila nível 1, 2 e 3

# Loot espalhado pelo mapa (repetido = mais comum)
const LOOT := [
	"mp5", "ump45", "m4a1", "scar", "ak47", "r870", "m1014", "kar98", "deagle", "glock", "glock",
	"bandage", "bandage", "bandage", "bandage", "bandage", "med", "med", "med",
	"a9", "a9", "a9", "a556", "a556", "a556", "a762", "a762", "a762", "a12", "a12",
	"vest", "vest", "helmet", "helmet", "bag1", "bag1", "bag2", "bag3",
	"stock", "extmag", "holo", "scope4", "silencer",
]
const LOOT_GUNS := ["mp5", "ump45", "m4a1", "scar", "ak47", "r870", "m1014", "kar98", "deagle", "glock", "mp5", "m4a1", "ak47", "ump45", "glock"]
const LOOT_MILITARY := ["m4a1", "scar", "ak47", "kar98", "awm", "vest", "helmet", "scope4", "extmag", "med", "bag2", "bag3", "a556", "a762"]

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


static func is_ammo(kind: String) -> bool:
	return ITEMS.has(kind) and ITEMS[kind]["kind"] == "ammo"


static func is_bag(kind: String) -> bool:
	return kind.begins_with("bag") and ITEMS.has(kind)


static func ammo_of(gun: String) -> String:
	return str(get_w(gun).get("ammo", ""))


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
			# Remington de madeira; M1014 toda preta com coronha e empunhadura de pistola
			var wood_s := id == "r870"
			var furn: Color = WOOD if wood_s else POLY
			m.tex(U.WOOD if wood_s else U.PLAIN, 8.0)
			_b(m, Vector3(0, -0.06, 0.04), Vector3(0.035, 0.11, 0.05), furn, 0.35)
			m.tex(U.PLAIN, 6.0)
			_b(m, Vector3(0, 0.02, -L * 0.1), Vector3(0.05, 0.075, L * 0.28), METAL)
			_tube(m, Vector3(0, 0.035, -L * 0.22), 0.015, L * 0.78, METAL)
			_tube(m, Vector3(0, 0.0, -L * 0.22), 0.014, L * 0.6, METAL)
			m.tex(U.WOOD if wood_s else U.PLAIN, 8.0)
			_b(m, Vector3(0, 0.0, -L * 0.48), Vector3(0.048, 0.048, L * 0.22), furn)
			if wood_s:
				_b(m, Vector3(0, -0.02, 0.2), Vector3(0.045, 0.09, 0.3), furn, -0.1)
			else:
				_b(m, Vector3(0, 0.0, 0.14), Vector3(0.025, 0.035, 0.18), METAL)
				_b(m, Vector3(0, -0.02, 0.25), Vector3(0.045, 0.1, 0.08), furn)
				_b(m, Vector3(0, 0.07, -L * 0.15), Vector3(0.015, 0.02, 0.06), METAL)
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
		"bag1", "bag2", "bag3":
			var lv := int(kind.substr(3))
			var bc: Color = [Color(0.45, 0.4, 0.3), Color(0.3, 0.36, 0.25), Color(0.2, 0.22, 0.25)][lv - 1]
			var sz := 0.8 + lv * 0.15
			m.tex(U.FABRIC, 3.0)
			m.boxp(Vector3(0, 0.12 * sz, 0), Vector3(0.42, 0.24, 0.5) * sz, bc)
			m.boxp(Vector3(0, 0.12 * sz, -0.28 * sz), Vector3(0.3, 0.16, 0.08) * sz, bc.darkened(0.15))
		"a9", "a556", "a762", "a12":
			var ac: Color = {"a9": Color(0.75, 0.6, 0.2), "a556": Color(0.35, 0.5, 0.3), "a762": Color(0.6, 0.25, 0.2), "a12": Color(0.7, 0.15, 0.12)}[kind]
			m.tex(U.METAL, 3.0)
			m.boxp(Vector3(0, 0.08, 0), Vector3(0.34, 0.16, 0.2), Color(0.3, 0.33, 0.26))
			m.tex(U.PLAIN, 4.0)
			m.boxp(Vector3(0, 0.161, 0), Vector3(0.3, 0.004, 0.08), ac)
			for i in 4:
				m.cyl(Transform3D(Basis(), Vector3(-0.09 + i * 0.06, 0.16, 0.06)), 0.012, 0.006, 0.05, 5, Color(0.8, 0.65, 0.3))
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
