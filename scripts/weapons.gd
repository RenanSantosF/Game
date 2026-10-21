class_name Weapons
extends RefCounted

# dmg = dano por bala, rate = tiros por segundo, spread = dispersão em graus,
# head = multiplicador de tiro na cabeça, zoom = aumento da mira.
# slot 0 = arma principal, slot 1 = pistola.
const DATA := {
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

# Loot espalhado pelo mapa (repetido = mais comum)
const LOOT := [
	"mp5", "mp5", "ump45", "ump45", "m4a1", "m4a1", "scar", "ak47", "ak47", "r870", "r870",
	"kar98", "awm", "deagle", "deagle",
	"med", "med", "med", "med", "vest", "vest", "helmet", "helmet",
]
const LOOT_GUNS := ["mp5", "ump45", "m4a1", "scar", "ak47", "r870", "kar98", "deagle"]
const EXTRA := {
	"med": {"name": "Kit médico"},
	"vest": {"name": "Colete"},
	"helmet": {"name": "Capacete"},
}

const SCOPES := ["kar98", "awm"]   # armas com luneta (mira preta na tela inteira)

const METAL := Color(0.09, 0.09, 0.1)
const POLY := Color(0.15, 0.15, 0.14)
const WOOD := Color(0.36, 0.21, 0.11)
const TAN := Color(0.52, 0.45, 0.32)

static var _cache := {}


static func get_w(id: String) -> Dictionary:
	if DATA.has(id):
		return DATA[id]
	return DATA["glock"]


static func is_gun(kind: String) -> bool:
	return DATA.has(kind)


static func item_name(kind: String) -> String:
	if DATA.has(kind):
		return DATA[kind]["name"]
	if EXTRA.has(kind):
		return EXTRA[kind]["name"]
	return kind


static func _b(m: MB, pos: Vector3, size: Vector3, col: Color, rx := 0.0) -> void:
	m.box(Transform3D(Basis(Vector3.RIGHT, rx), pos), size, col, false)


# cilindro deitado ao longo de -Z, começando em "pos"
static func _tube(m: MB, pos: Vector3, r: float, length: float, col: Color, seg := 6) -> void:
	m.cyl(Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), pos), r, r, length, seg, col, true, true)


static func mesh_for(id: String) -> Mesh:
	if _cache.has(id):
		return _cache[id]
	var w := get_w(id)
	var L: float = w["len"]
	var t: String = w["type"]
	var m := MB.new()
	m.uvs = 6.0
	var body := METAL
	match t:
		"pistol":
			var c := POLY if id == "glock" else Color(0.32, 0.32, 0.33)
			_b(m, Vector3(0, -0.06, 0.02), Vector3(0.035, 0.12, 0.05), POLY, 0.25)
			_b(m, Vector3(0, 0.025, -L * 0.42), Vector3(0.04, 0.045, L), c)
			_b(m, Vector3(0, -0.012, -L * 0.3), Vector3(0.036, 0.03, L * 0.55), POLY)
			_b(m, Vector3(0, 0.052, -L * 0.88), Vector3(0.008, 0.012, 0.01), METAL)
		"smg", "rifle", "ak", "scar":
			if t == "scar":
				body = TAN
			var furn := WOOD if t == "ak" else (TAN if t == "scar" else POLY)
			# empunhadura
			_b(m, Vector3(0, -0.07, 0.03), Vector3(0.035, 0.12, 0.05), POLY, 0.3)
			# corpo
			_b(m, Vector3(0, 0.02, -L * 0.18), Vector3(0.05, 0.075, L * 0.5), body)
			# guarda-mão
			_b(m, Vector3(0, 0.022, -L * 0.55), Vector3(0.052, 0.06, L * 0.3), furn)
			# cano
			_tube(m, Vector3(0, 0.03, -L * 0.68), 0.011, L * 0.32, METAL)
			# carregador
			if t == "ak":
				_b(m, Vector3(0, -0.07, -L * 0.3), Vector3(0.03, 0.14, 0.055), METAL, 0.35)
			elif t == "smg" and id == "ump45":
				_b(m, Vector3(0, -0.075, -L * 0.25), Vector3(0.03, 0.13, 0.05), POLY, 0.15)
			else:
				_b(m, Vector3(0, -0.07, -L * 0.25), Vector3(0.028, 0.13, 0.05), METAL, 0.12)
			# coronha
			if t == "ak":
				_b(m, Vector3(0, -0.01, 0.17), Vector3(0.04, 0.075, 0.26), WOOD, -0.08)
			elif t == "smg":
				_b(m, Vector3(0, 0.0, 0.14), Vector3(0.035, 0.06, 0.2), POLY)
			else:
				_b(m, Vector3(0, -0.005, 0.12), Vector3(0.02, 0.03, 0.14), METAL)
				_b(m, Vector3(0, -0.01, 0.22), Vector3(0.042, 0.09, 0.08), furn)
			# mira
			if t == "rifle" or t == "scar":
				_b(m, Vector3(0, 0.07, -L * 0.12), Vector3(0.022, 0.02, 0.1), METAL)
				_tube(m, Vector3(0, 0.09, -L * 0.07), 0.016, 0.1, METAL)
			elif t == "ak":
				_b(m, Vector3(0, 0.07, -L * 0.62), Vector3(0.008, 0.035, 0.012), METAL)
			else:
				_b(m, Vector3(0, 0.07, -L * 0.05), Vector3(0.03, 0.018, 0.03), METAL)
		"shotgun":
			_b(m, Vector3(0, -0.06, 0.04), Vector3(0.035, 0.1, 0.05), WOOD, 0.35)
			_b(m, Vector3(0, 0.02, -L * 0.1), Vector3(0.05, 0.07, L * 0.25), METAL)
			_tube(m, Vector3(0, 0.035, -L * 0.22), 0.014, L * 0.78, METAL)
			_tube(m, Vector3(0, 0.0, -L * 0.22), 0.013, L * 0.6, METAL)
			_b(m, Vector3(0, 0.0, -L * 0.48), Vector3(0.045, 0.045, L * 0.2), WOOD)
			_b(m, Vector3(0, -0.02, 0.2), Vector3(0.045, 0.09, 0.3), WOOD, -0.1)
		"bolt", "sniper":
			var stock := WOOD if t == "bolt" else Color(0.25, 0.3, 0.2)
			_b(m, Vector3(0, -0.005, -L * 0.15), Vector3(0.05, 0.06, L * 0.75), stock)
			_b(m, Vector3(0, 0.03, -L * 0.1), Vector3(0.035, 0.035, L * 0.3), METAL)
			_tube(m, Vector3(0, 0.035, -L * 0.25), 0.012, L * 0.75, METAL)
			_b(m, Vector3(0, -0.03, 0.22), Vector3(0.045, 0.1, 0.3), stock, -0.08)
			_b(m, Vector3(0, -0.05, 0.03), Vector3(0.03, 0.08, 0.04), stock, 0.3)
			_b(m, Vector3(0.04, 0.035, 0.0), Vector3(0.04, 0.012, 0.012), METAL)
			# luneta
			_tube(m, Vector3(0, 0.09, 0.05), 0.022, 0.32, METAL, 8)
			_b(m, Vector3(0, 0.065, -0.1), Vector3(0.015, 0.03, 0.03), METAL)
			if t == "sniper":
				_b(m, Vector3(0, -0.05, -L * 0.25), Vector3(0.03, 0.06, 0.08), METAL)
	var mesh := m.commit()
	_cache[id] = mesh
	return mesh


# Modelo da arma. Origem no cabo, cano apontando para -Z.
static func build_model(id: String) -> Node3D:
	var w := get_w(id)
	var root := Node3D.new()
	U.mesh(root, mesh_for(id))
	var muzzle := Node3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, 0.035, -float(w["len"]))
	root.add_child(muzzle)
	return root


# Modelo de item no chão (arma deitada, kit, colete, capacete)
static func build_item(kind: String) -> Node3D:
	var root := Node3D.new()
	if DATA.has(kind):
		var g := build_model(kind)
		g.rotation = Vector3(0, 0, PI / 2.0)
		g.position.y = 0.05
		g.scale = Vector3(1.25, 1.25, 1.25)
		root.add_child(g)
		var gm: MeshInstance3D = g.get_child(0)
		gm.visibility_range_end = 80.0
		gm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return root
	var key := "item_" + kind
	if not _cache.has(key):
		var m := MB.new()
		m.uvs = 4.0
		match kind:
			"med":
				m.boxp(Vector3(0, 0.1, 0), Vector3(0.42, 0.2, 0.3), Color(0.85, 0.85, 0.82))
				m.boxp(Vector3(0, 0.201, 0), Vector3(0.22, 0.005, 0.06), Color(0.75, 0.1, 0.1))
				m.boxp(Vector3(0, 0.201, 0), Vector3(0.06, 0.005, 0.2), Color(0.75, 0.1, 0.1))
				m.boxp(Vector3(0, 0.23, 0), Vector3(0.14, 0.03, 0.03), Color(0.2, 0.2, 0.2))
			"vest":
				var oc := Color(0.27, 0.3, 0.2)
				m.boxp(Vector3(0, 0.06, 0), Vector3(0.5, 0.12, 0.6), oc)
				m.boxp(Vector3(0, 0.13, -0.12), Vector3(0.4, 0.04, 0.2), oc.darkened(0.15))
				m.boxp(Vector3(0, 0.13, 0.15), Vector3(0.3, 0.04, 0.16), oc.darkened(0.2))
			"helmet":
				m.blob(Transform3D(Basis.from_scale(Vector3(0.18, 0.15, 0.21)), Vector3(0, 0.02, 0)), 10, 4, Color(0.28, 0.31, 0.22))
		_cache[key] = m.commit()
	var mi := U.mesh(root, _cache[key])
	mi.visibility_range_end = 80.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root
