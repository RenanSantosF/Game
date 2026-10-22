class_name Weapons
extends RefCounted

# dmg = dano por bala, rate = tiros por segundo, spread = dispersão em graus,
# head = multiplicador de tiro na cabeça, zoom = aumento da mira, ammo = calibre.
# slot 0 = arma principal (2 vagas), slot 1 = pistola. Vida de cada jogador: 200.
const DATA := {
	"fist": {"name": "Soco", "dmg": 25.0, "rate": 2.2, "mag": 1, "reload": 0.0, "spread": 0.0, "range": 2.2, "pellets": 1, "head": 1.5, "zoom": 1.0, "recoil": 0.0, "len": 0.0, "type": "fist", "slot": 2, "ammo": ""},
	"glock": {"name": "Glock 17", "dmg": 30.0, "rate": 4.5, "mag": 17, "reload": 1.5, "spread": 1.2, "range": 60.0, "pellets": 1, "head": 2.2, "zoom": 1.0, "recoil": 0.014, "len": 0.2, "type": "pistol", "slot": 1, "ammo": "a9", "bloom": 0.25, "bloom_max": 2.0},
	"deagle": {"name": "Desert Eagle", "dmg": 72.0, "rate": 1.8, "mag": 7, "reload": 1.9, "spread": 1.0, "range": 80.0, "pellets": 1, "head": 2.5, "zoom": 1.0, "recoil": 0.06, "len": 0.27, "type": "pistol", "slot": 1, "ammo": "a9", "bloom": 0.7, "bloom_max": 3.0},
	"mp5": {"name": "MP5", "dmg": 31.0, "rate": 12.0, "mag": 30, "reload": 2.2, "spread": 1.7, "range": 70.0, "pellets": 1, "head": 1.9, "zoom": 1.3, "recoil": 0.008, "len": 0.62, "type": "smg", "slot": 0, "ammo": "a9", "bloom": 0.1, "bloom_max": 1.5},
	"ump45": {"name": "UMP-45", "dmg": 38.0, "rate": 9.5, "mag": 25, "reload": 2.3, "spread": 1.5, "range": 75.0, "pellets": 1, "head": 1.9, "zoom": 1.3, "recoil": 0.011, "len": 0.65, "type": "smg", "slot": 0, "ammo": "a9", "bloom": 0.13, "bloom_max": 1.7},
	"m4a1": {"name": "M4A1", "dmg": 38.0, "rate": 10.0, "mag": 30, "reload": 2.4, "spread": 0.9, "range": 160.0, "pellets": 1, "head": 2.2, "zoom": 1.6, "recoil": 0.012, "len": 0.85, "type": "rifle", "slot": 0, "ammo": "a556", "bloom": 0.15, "bloom_max": 2.2},
	"scar": {"name": "SCAR-L", "dmg": 41.0, "rate": 9.0, "mag": 30, "reload": 2.5, "spread": 0.9, "range": 170.0, "pellets": 1, "head": 2.2, "zoom": 1.8, "recoil": 0.015, "len": 0.88, "type": "scar", "slot": 0, "ammo": "a556", "bloom": 0.2, "bloom_max": 2.6},
	"ak47": {"name": "AK-47", "dmg": 50.0, "rate": 8.5, "mag": 30, "reload": 2.6, "spread": 1.1, "range": 160.0, "pellets": 1, "head": 2.2, "zoom": 1.5, "recoil": 0.024, "len": 0.88, "type": "ak", "slot": 0, "ammo": "a762", "bloom": 0.5, "bloom_max": 4.5},
	"r870": {"name": "Remington 870", "dmg": 27.0, "rate": 0.85, "mag": 5, "reload": 3.2, "spread": 5.0, "range": 32.0, "pellets": 8, "head": 1.6, "zoom": 1.0, "recoil": 0.09, "len": 1.0, "type": "shotgun", "slot": 0, "ammo": "a12"},
	"m1014": {"name": "M1014", "dmg": 21.0, "rate": 1.7, "mag": 6, "reload": 3.4, "spread": 6.0, "range": 28.0, "pellets": 8, "head": 1.6, "zoom": 1.0, "recoil": 0.075, "len": 1.0, "type": "shotgun", "slot": 0, "ammo": "a12"},
	"kar98": {"name": "Kar98k", "dmg": 125.0, "rate": 0.75, "mag": 5, "reload": 3.2, "spread": 3.5, "range": 350.0, "pellets": 1, "head": 3.0, "zoom": 3.0, "recoil": 0.06, "len": 1.1, "type": "bolt", "slot": 0, "ammo": "a762"},
	"awm": {"name": "AWM", "dmg": 160.0, "rate": 0.6, "mag": 5, "reload": 4.2, "spread": 4.0, "range": 400.0, "pellets": 1, "head": 2.6, "zoom": 4.0, "recoil": 0.08, "len": 1.2, "type": "sniper", "slot": 0, "ammo": "a762"},
}

# Dano cai com a distância: [até onde é dano cheio (m), quanto sobra no alcance máximo]
# Armas de perto (SMG e 12) batem forte colado e perdem muito de longe.
const FALLOFF := {
	"fist": [9.0, 1.0], "glock": [10.0, 0.45], "deagle": [15.0, 0.5], "mp5": [8.0, 0.3], "ump45": [9.0, 0.3],
	"m4a1": [30.0, 0.6], "scar": [32.0, 0.62], "ak47": [25.0, 0.55], "r870": [5.0, 0.1], "m1014": [4.0, 0.08],
	"kar98": [80.0, 0.8], "awm": [100.0, 0.85],
}


static func falloff(w: Dictionary, dist: float) -> float:
	var f: Array = FALLOFF.get(w.get("id", ""), [1000.0, 1.0])
	return lerpf(1.0, float(f[1]), smoothstep(float(f[0]), float(w["range"]), dist))


# Itens que não são armas. stack = quantos cabem numa vaga da mochila; count = quanto vem no chão.
# Colete, capacete, mochila, coronha e carregador têm nível 1, 2 e 3 (cor diferente no chão).
const ITEMS := {
	"a9": {"name": "Munição 9mm", "stack": 60, "count": 30, "kind": "ammo"},
	"a556": {"name": "Munição 5.56", "stack": 60, "count": 30, "kind": "ammo"},
	"a762": {"name": "Munição 7.62", "stack": 60, "count": 25, "kind": "ammo"},
	"a12": {"name": "Cartucho 12", "stack": 30, "count": 12, "kind": "ammo"},
	"bandage": {"name": "Bandagem", "stack": 10, "count": 4, "kind": "heal", "heal": 30.0, "time": 2.0},
	"med": {"name": "Kit médico", "stack": 4, "count": 1, "kind": "heal", "heal": 100.0, "time": 4.5},
	"drink": {"name": "Energético", "stack": 5, "count": 2, "kind": "heal", "heal": 50.0, "time": 2.5},
	"grenade": {"name": "Granada", "stack": 3, "count": 1, "kind": "throw"},
	"vest1": {"name": "Colete nível 1", "kind": "gear", "level": 1},
	"vest2": {"name": "Colete nível 2", "kind": "gear", "level": 2},
	"vest3": {"name": "Colete nível 3", "kind": "gear", "level": 3},
	"helmet1": {"name": "Capacete nível 1", "kind": "gear", "level": 1},
	"helmet2": {"name": "Capacete nível 2", "kind": "gear", "level": 2},
	"helmet3": {"name": "Capacete nível 3", "kind": "gear", "level": 3},
	"bag1": {"name": "Mochila nível 1", "kind": "gear", "level": 1},
	"bag2": {"name": "Mochila nível 2", "kind": "gear", "level": 2},
	"bag3": {"name": "Mochila nível 3", "kind": "gear", "level": 3},
	"stock1": {"name": "Coronha nível 1", "stack": 1, "count": 1, "kind": "att", "cat": "stock", "level": 1},
	"stock2": {"name": "Coronha nível 2", "stack": 1, "count": 1, "kind": "att", "cat": "stock", "level": 2},
	"stock3": {"name": "Coronha nível 3", "stack": 1, "count": 1, "kind": "att", "cat": "stock", "level": 3},
	"mag1": {"name": "Carregador nível 1", "stack": 1, "count": 1, "kind": "att", "cat": "mag", "level": 1},
	"mag2": {"name": "Carregador nível 2", "stack": 1, "count": 1, "kind": "att", "cat": "mag", "level": 2},
	"mag3": {"name": "Carregador nível 3", "stack": 1, "count": 1, "kind": "att", "cat": "mag", "level": 3},
	"holo": {"name": "Mira holográfica", "stack": 1, "count": 1, "kind": "att", "cat": "sight", "level": 1},
	"scope2": {"name": "Mira 2x", "stack": 1, "count": 1, "kind": "att", "cat": "sight", "level": 2},
	"scope4": {"name": "Luneta 4x", "stack": 1, "count": 1, "kind": "att", "cat": "sight", "level": 3},
	"scope8": {"name": "Luneta 8x", "stack": 1, "count": 1, "kind": "att", "cat": "sight", "level": 3},
	"silencer": {"name": "Silenciador", "stack": 1, "count": 1, "kind": "att", "cat": "muzzle", "level": 2},
}
const ATTS := ["stock1", "stock2", "stock3", "mag1", "mag2", "mag3", "holo", "scope2", "scope4", "scope8", "silencer"]
# o que cada tipo de arma aceita (escopeta não tem mira nem silenciador)
const FITS := {
	"pistol": ["mag", "holo", "muzzle"],
	"smg": ["stock", "mag", "holo", "scope2", "muzzle"],
	"rifle": ["stock", "mag", "holo", "scope2", "scope4", "muzzle"],
	"scar": ["stock", "mag", "holo", "scope2", "scope4", "muzzle"],
	"ak": ["stock", "mag", "holo", "scope2", "scope4", "muzzle"],
	"shotgun": ["stock", "mag"],
	"bolt": ["mag", "scope8", "muzzle"],
	"sniper": ["mag", "scope8", "muzzle"],
}
const AMMO := ["a9", "a556", "a762", "a12"]
const BAGS := [6, 10, 14, 18]       # vagas sem mochila e com mochila nível 1, 2 e 3
const VEST_ABSORB := [0.0, 0.3, 0.42, 0.55]    # quanto do dano no corpo o colete segura
const HELMET_ABSORB := [0.0, 0.25, 0.38, 0.5]  # quanto do dano na cabeça o capacete segura
# cor de raridade (destaque no chão): nível 1 branco, 2 azul, 3 roxo; armas dourado
const RARITY := [Color(0.9, 0.9, 0.9), Color(0.85, 0.85, 0.85), Color(0.3, 0.6, 1.0), Color(0.75, 0.35, 1.0)]

# Loot espalhado pelo mapa (repetido = mais comum)
const LOOT := [
	"mp5", "ump45", "m4a1", "scar", "ak47", "r870", "m1014", "kar98", "deagle", "glock", "glock",
	"bandage", "bandage", "bandage", "bandage", "bandage", "bandage", "med", "med", "med", "med", "med",
	"drink", "drink", "drink", "grenade", "grenade",
	"a9", "a9", "a9", "a556", "a556", "a556", "a762", "a762", "a762", "a12", "a12",
	"vest1", "vest1", "vest2", "vest3", "helmet1", "helmet1", "helmet2", "helmet3", "bag1", "bag1", "bag2", "bag3",
	"stock1", "stock2", "stock3", "mag1", "mag1", "mag2", "mag3", "holo", "holo", "scope2", "scope4", "scope8", "silencer",
]
const LOOT_GUNS := ["mp5", "ump45", "m4a1", "scar", "ak47", "r870", "m1014", "kar98", "deagle", "glock", "mp5", "m4a1", "ak47", "ump45", "glock"]
const LOOT_MILITARY := ["m4a1", "scar", "ak47", "kar98", "awm", "vest2", "vest3", "helmet2", "helmet3", "scope4", "scope8", "mag3", "stock3", "med", "bag2", "bag3", "a556", "a762"]

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


static func is_vest(kind: String) -> bool:
	return kind.begins_with("vest") and ITEMS.has(kind)


static func is_helmet(kind: String) -> bool:
	return kind.begins_with("helmet") and ITEMS.has(kind)


static func level_of(kind: String) -> int:
	if ITEMS.has(kind):
		return int(ITEMS[kind].get("level", 0))
	return 0


static func att_cat(att: String) -> String:
	return str(ITEMS[att].get("cat", "")) if ITEMS.has(att) else ""


# acessório da mesma categoria que já está na arma (pra trocar)
static func same_cat(att: String, list: Array) -> String:
	var c := att_cat(att)
	for a in list:
		if att_cat(a) == c:
			return a
	return ""


static func att_level(att: Array, cat: String) -> int:
	for a in att:
		if att_cat(a) == cat:
			return level_of(a)
	return 0


static func ammo_of(gun: String) -> String:
	return str(get_w(gun).get("ammo", ""))


static func fits(att: String, gun: String) -> bool:
	if not is_att(att) or not is_gun(gun):
		return false
	var allowed: Array = FITS.get(get_w(gun)["type"], [])
	var c := att_cat(att)
	if c == "sight":
		return att in allowed
	return c in allowed


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
	w["id"] = id
	w["bloom"] = float(w.get("bloom", 0.0))
	w["bloom_max"] = float(w.get("bloom_max", 0.0))
	var sl := att_level(att, "stock")
	if sl > 0:
		var k: float = [1.0, 0.8, 0.68, 0.55][sl]
		w["recoil"] = float(w["recoil"]) * k
		w["bloom"] = float(w["bloom"]) * k
		w["spread"] = float(w["spread"]) * (0.95 - sl * 0.03)
	var ml := att_level(att, "mag")
	if ml > 0:
		w["mag"] = ceili(float(w["mag"]) * [1.0, 1.25, 1.45, 1.7][ml])
		w["reload"] = float(w["reload"]) * (1.0 - ml * 0.05)
	w["ads"] = 0.4
	w["overlay"] = id in SCOPES
	if "holo" in att:
		w["zoom"] = maxf(float(w["zoom"]), 1.7)
		w["ads"] = 0.25
	if "scope2" in att:
		w["zoom"] = 2.2
		w["ads"] = 0.18
	if "scope4" in att:
		w["zoom"] = 4.0
		w["overlay"] = true
		w["ads"] = 0.05
	if "scope8" in att:
		w["zoom"] = 8.0
		w["overlay"] = true
		w["ads"] = 0.03
	w["silenced"] = "silencer" in att
	return w


static func _b(m: MB, pos: Vector3, size: Vector3, col: Color, rx := 0.0) -> void:
	m.box(Transform3D(Basis(Vector3.RIGHT, rx), pos), size, col, false)


# cilindro deitado ao longo de -Z, começando em "pos"
static func _tube(m: MB, pos: Vector3, r: float, length: float, col: Color, seg := 6) -> void:
	m.cyl(Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), pos), r, r, length, seg, col, true, true)


# Modelos detalhados (Ultimate Gun Pack da Quaternius, CC0, convertido por tools/prepare_guns.gd)
# com as miras e o silenciador encaixados no trilho e no cano.
static func _model_mesh(id: String, att: Array) -> Mesh:
	var info: Dictionary = GunInfo.INFO[id]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(load("res://models/guns/%s.res" % id), 0, Transform3D())
	var ln: float = info["len"]
	var rail: float = info["rail"]
	var mz: Vector3 = info["muzzle"]
	var own_scope := id in SCOPES
	for a in ["scope2", "scope4", "scope8"]:
		if a in att and not own_scope:
			st.append_from(load("res://models/guns/acc_%s.res" % a), 0, Transform3D(Basis(), Vector3(0, rail - 0.005, -ln * 0.3)))
	if "silencer" in att:
		var sm: Mesh = load("res://models/guns/acc_silencer.res")
		var ab := sm.get_aabb()
		st.append_from(sm, 0, Transform3D(Basis(), Vector3(0, mz.y - ab.get_center().y, mz.z - ab.end.z + 0.01)))
	if "holo" in att:
		var m := MB.new()
		m.tex(U.PLAIN, 6.0)
		_b(m, Vector3(0, rail + 0.012, -ln * 0.3), Vector3(0.035, 0.024, 0.07), METAL)
		_b(m, Vector3(0, rail + 0.045, -ln * 0.3 - 0.03), Vector3(0.04, 0.045, 0.008), METAL)
		_b(m, Vector3(0, rail + 0.045, -ln * 0.3 + 0.03), Vector3(0.04, 0.045, 0.008), METAL)
		_b(m, Vector3(0, rail + 0.045, -ln * 0.3 - 0.026), Vector3(0.03, 0.03, 0.002), Color(0.3, 0.6, 0.7))
		st.append_from(m.commit(), 0, Transform3D())
	return st.commit()


static func mesh_for(id: String, att: Array = []) -> Mesh:
	var key := id + "|" + ",".join(att)
	if _cache.has(key):
		return _cache[key]
	if GunInfo.INFO.has(id):
		_cache[key] = _model_mesh(id, att)
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
			if att_level(att, "mag") > 0:
				_b(m, Vector3(0, -0.15, -L * 0.27), Vector3(0.03, 0.05 + att_level(att, "mag") * 0.025, 0.05), METAL, 0.2)
			if t == "ak":
				m.tex(U.WOOD, 8.0)
				_b(m, Vector3(0, -0.01, 0.17), Vector3(0.04, 0.075, 0.26), WOOD, -0.08)
				m.tex(U.PLAIN, 6.0)
			elif t == "smg" and att_level(att, "stock") == 0:
				_b(m, Vector3(0, 0.0, 0.14), Vector3(0.035, 0.06, 0.2), POLY)
			else:
				_b(m, Vector3(0, -0.005, 0.12), Vector3(0.02, 0.03, 0.14), METAL)
				_b(m, Vector3(0, -0.01, 0.22), Vector3(0.042, 0.09, 0.08), furn)
			if att_level(att, "sight") == 0:
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
	if "scope2" in att:
		_tube(m, Vector3(0, 0.095, -L * 0.02), 0.02, 0.12, METAL, 8)
		_b(m, Vector3(0, 0.072, -L * 0.08), Vector3(0.015, 0.03, 0.03), METAL)
	if ("scope4" in att or "scope8" in att) and t != "bolt":
		_tube(m, Vector3(0, 0.1, 0.02), 0.022 if "scope4" in att else 0.026, 0.28 if "scope4" in att else 0.36, METAL, 8)
		_b(m, Vector3(0, 0.072, -0.1), Vector3(0.015, 0.03, 0.03), METAL)
	if "silencer" in att:
		_tube(m, Vector3(0, 0.03 if t != "pistol" else 0.025, -L * (1.0 if t != "pistol" else 0.92)), 0.02, 0.16, METAL, 8)
	var mesh := m.commit()
	_cache[key] = mesh
	return mesh


static func muzzle_len(id: String, att: Array) -> float:
	var L: float = GunInfo.INFO[id]["len"] if GunInfo.INFO.has(id) else float(get_w(id)["len"])
	return L + (0.16 if "silencer" in att else 0.0)


# Modelo da arma. Origem no cabo, cano apontando para -Z.
static func build_model(id: String, att: Array = []) -> Node3D:
	var root := Node3D.new()
	var mesh := mesh_for(id, att)
	if mesh:
		U.mesh(root, mesh)
	var muzzle := Node3D.new()
	muzzle.name = "Muzzle"
	var my: float = GunInfo.INFO[id]["muzzle"].y if GunInfo.INFO.has(id) else 0.035
	muzzle.position = Vector3(0, my, -muzzle_len(id, att))
	root.add_child(muzzle)
	return root


# ---------------- colete, capacete e mochila ----------------
# Um desenho só (vestido no boneco); no chão o mesmo modelo aparece deitado/em pé.
# Cor por nível: 1 verde-oliva, 2 azul, 3 roxo.
const LV_COL := [Color(0.46, 0.5, 0.32), Color(0.32, 0.46, 0.7), Color(0.52, 0.36, 0.66)]
const STRAP := Color(0.1, 0.1, 0.1)


static func gear(kind: String) -> Mesh:
	var key := "gear_" + kind
	if _cache.has(key):
		return _cache[key]
	var lv := clampi(level_of(kind), 1, 3)
	var c: Color = LV_COL[lv - 1]
	var m := MB.new()
	m.tex(U.FABRIC, 5.0)
	if is_vest(kind):
		# placas da frente e de trás arredondadas, faixa lateral, alças, bolsos e tiras (MOLLE)
		for sz in [-1.0, 1.0]:
			m.blob(Transform3D(Basis.from_scale(Vector3(0.185, 0.175, 0.045)), Vector3(0, 1.27, sz * 0.105)), 12, 6, c, null, 0.0, true, 0.25)
		for sx in [-1.0, 1.0]:
			m.box(Transform3D(Basis(), Vector3(sx * 0.17, 1.2, 0.0)), Vector3(0.04, 0.16, 0.2), c.darkened(0.15))
			m.box(Transform3D(Basis(Vector3.FORWARD, sx * 0.15), Vector3(sx * 0.09, 1.44, 0.0)), Vector3(0.07, 0.035, 0.24), c.darkened(0.1))
		m.tex(U.PLAIN, 4.0)
		for k in 3:
			m.box(Transform3D(Basis(), Vector3(0, 1.17 + k * 0.06, -0.152)), Vector3(0.3, 0.012, 0.012), STRAP)
		m.tex(U.FABRIC, 5.0)
		var np := 2 + lv
		for k in np:
			var x := (k - (np - 1) / 2.0) * 0.075
			m.box(Transform3D(Basis(), Vector3(x, 1.18, -0.155)), Vector3(0.062, 0.095, 0.04), c.lightened(0.08))
			m.box(Transform3D(Basis(), Vector3(x, 1.235, -0.157)), Vector3(0.064, 0.02, 0.046), c.darkened(0.2))
		if lv >= 2:
			# placa balística por cima
			m.box(Transform3D(Basis(Vector3.RIGHT, -0.05), Vector3(0, 1.33, -0.152)), Vector3(0.24, 0.13, 0.025), c.darkened(0.3))
		if lv == 3:
			# gola, ombreiras e rádio
			m.blob(Transform3D(Basis.from_scale(Vector3(0.14, 0.04, 0.12)), Vector3(0, 1.47, 0.0)), 10, 4, c.darkened(0.2))
			for sx in [-1.0, 1.0]:
				m.blob(Transform3D(Basis.from_scale(Vector3(0.06, 0.03, 0.08)), Vector3(sx * 0.2, 1.42, 0.0)), 8, 4, c.darkened(0.1))
			m.tex(U.PLAIN, 4.0)
			m.box(Transform3D(Basis(), Vector3(0.13, 1.36, -0.15)), Vector3(0.04, 0.07, 0.03), STRAP)
			m.cyl(Transform3D(Basis(), Vector3(0.14, 1.395, -0.15)), 0.004, 0.003, 0.08, 4, STRAP)
	elif is_helmet(kind):
		var hy := 1.665
		m.tex(U.PLAIN, 4.0)
		if lv == 1:
			# capacete leve de tecido (tipo boné de combate) com aba
			m.blob(Transform3D(Basis.from_scale(Vector3(0.128, 0.085, 0.14)), Vector3(0, hy + 0.005, 0.01)), 12, 6, c)
			m.box(Transform3D(Basis(Vector3.RIGHT, 0.15), Vector3(0, hy - 0.035, -0.135)), Vector3(0.17, 0.012, 0.08), c.darkened(0.2))
		else:
			# casco de aço com borda, jugular e (nível 3) suporte de visão noturna e trilhos
			m.blob(Transform3D(Basis.from_scale(Vector3(0.138, 0.115, 0.152)), Vector3(0, hy + 0.01, 0.01)), 14, 7, c, null, 0.0, true, 0.15)
			m.cyl(Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 1.1)), Vector3(0, hy - 0.035, 0.01)), 0.142, 0.138, 0.025, 14, c.darkened(0.2))
			for sx in [-1.0, 1.0]:
				m.box(Transform3D(Basis(), Vector3(sx * 0.125, hy - 0.08, 0.0)), Vector3(0.012, 0.09, 0.02), STRAP)
			if lv == 3:
				m.box(Transform3D(Basis(), Vector3(0, hy + 0.03, -0.15)), Vector3(0.05, 0.04, 0.02), STRAP)
				m.box(Transform3D(Basis(Vector3.RIGHT, 0.3), Vector3(0, hy + 0.01, -0.175)), Vector3(0.06, 0.035, 0.05), Color(0.2, 0.2, 0.22))
				for sx in [-1.0, 1.0]:
					m.box(Transform3D(Basis(), Vector3(sx * 0.13, hy - 0.005, 0.0)), Vector3(0.015, 0.025, 0.12), STRAP)
	elif is_bag(kind):
		# mochila: corpo arredondado (maior a cada nível), tampa, bolsos dos lados e da frente, alças
		var k := 0.85 + lv * 0.12
		var bz := 0.21
		m.blob(Transform3D(Basis.from_scale(Vector3(0.17, 0.23, 0.09) * k), Vector3(0, 1.26, bz + 0.03 * k)), 12, 6, c, null, 0.0, true, 0.25)
		m.box(Transform3D(Basis(Vector3.RIGHT, -0.25), Vector3(0, 1.26 + 0.2 * k, bz + 0.05 * k)), Vector3(0.3 * k, 0.05, 0.15 * k), c.darkened(0.2))
		m.blob(Transform3D(Basis.from_scale(Vector3(0.12, 0.09, 0.05) * k), Vector3(0, 1.17, bz + 0.11 * k)), 10, 5, c.lightened(0.06))
		if lv >= 2:
			for sx in [-1.0, 1.0]:
				m.blob(Transform3D(Basis.from_scale(Vector3(0.045, 0.1, 0.06) * k), Vector3(sx * 0.17 * k, 1.2, bz + 0.03 * k)), 8, 5, c.darkened(0.1))
		if lv == 3:
			# saco de dormir enrolado em cima
			m.tex(U.FABRIC, 6.0)
			m.cyl(Transform3D(Basis(Vector3.FORWARD, PI / 2.0), Vector3(0.16 * k, 1.53, bz + 0.03)), 0.06, 0.06, 0.32 * k, 10, Color(0.3, 0.3, 0.28))
		m.tex(U.PLAIN, 4.0)
		for sx in [-0.09, 0.09]:
			m.box(Transform3D(Basis(), Vector3(sx, 1.27, bz - 0.06 * k)), Vector3(0.035, 0.36, 0.02), STRAP)
	var mesh := m.commit()
	_cache[key] = mesh
	return mesh


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
		"drink":
			for k in 2:
				m.cyl(Transform3D(Basis(), Vector3(k * 0.1 - 0.05, 0, 0)), 0.035, 0.035, 0.13, 10, Color(0.15, 0.45, 0.85))
				m.cyl(Transform3D(Basis(), Vector3(k * 0.1 - 0.05, 0.13, 0)), 0.035, 0.03, 0.01, 10, Color(0.8, 0.8, 0.82))
		"grenade":
			m.blob(Transform3D(Basis.from_scale(Vector3(0.05, 0.065, 0.05)), Vector3(0, 0.065, 0)), 8, 5, Color(0.28, 0.32, 0.2))
			m.boxp(Vector3(0, 0.135, 0), Vector3(0.025, 0.03, 0.025), Color(0.5, 0.5, 0.5))
			m.boxp(Vector3(0.025, 0.12, 0), Vector3(0.01, 0.06, 0.02), Color(0.5, 0.5, 0.5))
		"bandage":
			m.tex(U.FABRIC, 6.0)
			for k in 3:
				m.cyl(Transform3D(Basis(), Vector3(k * 0.13 - 0.13, 0, 0)), 0.055, 0.055, 0.1, 10, Color(0.95, 0.93, 0.88))
		"vest1", "vest2", "vest3", "helmet1", "helmet2", "helmet3", "bag1", "bag2", "bag3":
			pass
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
			# acessórios: a peça de verdade, com a cor do nível
			var lvc: Color = RARITY[clampi(level_of(kind), 1, 3)]
			match att_cat(kind):
				"stock":
					pass
				"mag":
					# pente curvo deitado (maior a cada nível), com base e cartuchos aparecendo
					var lvm := level_of(kind)
					var segs := 3 + lvm
					for k in segs:
						m.box(Transform3D(Basis(Vector3.UP, k * 0.09), Vector3(-0.08 + k * 0.045, 0.022, k * k * 0.004)), Vector3(0.05, 0.04, 0.075), METAL.lightened(0.05))
					m.boxp(Vector3(-0.11, 0.022, 0), Vector3(0.02, 0.046, 0.085), POLY)
					m.boxp(Vector3(-0.08 + segs * 0.045, 0.03, segs * segs * 0.004), Vector3(0.025, 0.02, 0.03), Color(0.8, 0.65, 0.3))
				"sight":
					if kind == "holo":
						m.boxp(Vector3(0, 0.02, 0), Vector3(0.05, 0.03, 0.09), METAL)
						m.boxp(Vector3(0, 0.06, 0.03), Vector3(0.05, 0.05, 0.012), METAL)
				_:
					pass
			m.boxp(Vector3(0, 0.002, 0), Vector3(0.12, 0.004, 0.02), lvc)
	var mesh := m.commit()
	var acc := "stock" if att_cat(kind) == "stock" else kind
	if acc in ["scope2", "scope4", "scope8", "silencer", "stock"]:
		# luneta, silenciador e coronha: o modelo de verdade, maior pra ver no chão (com a faixa da cor do nível)
		var st2 := SurfaceTool.new()
		st2.begin(Mesh.PRIMITIVE_TRIANGLES)
		st2.append_from(load("res://models/guns/acc_%s.res" % acc), 0, Transform3D(Basis(Vector3.UP, PI / 2.0).scaled(Vector3.ONE * 1.6), Vector3(0, 0.0, 0)))
		st2.append_from(mesh, 0, Transform3D())
		mesh = st2.commit()
	if is_vest(kind) or is_helmet(kind) or is_bag(kind):
		# no chão: colete deitado de costas, capacete em pé, mochila deitada
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var xf := Transform3D()
		if is_vest(kind):
			xf = Transform3D(Basis(Vector3.RIGHT, -PI / 2.0).scaled(Vector3.ONE * 1.25) * Basis.from_scale(Vector3(1, 1, 0.45)), Vector3(0, 0.12, 0)) * Transform3D(Basis(), Vector3(0, -1.27, 0))
		elif is_helmet(kind):
			xf = Transform3D(Basis().scaled(Vector3.ONE * 1.3), Vector3(0, 0.17, 0)) * Transform3D(Basis(), Vector3(0, -1.665, 0))
		else:
			xf = Transform3D(Basis(Vector3.RIGHT, PI / 2.0).scaled(Vector3.ONE * 1.25), Vector3(0, 0.0, 0)) * Transform3D(Basis(), Vector3(0, -1.26, -0.3))
		st.append_from(gear(kind), 0, xf)
		mesh = st.commit()
	_cache[key] = mesh
	return mesh


# brilho do item no chão na cor da raridade (nível 2 azul, 3 roxo, armas dourado, resto branco fraco)
static var _glow_mats := {}


static func glow_mat(kind: String) -> ShaderMaterial:
	var lv := level_of(kind)
	var col: Color = RARITY[lv] if lv >= 2 else Color(1, 1, 1)
	var st := 1.25 if lv >= 2 else 0.5
	if is_gun(kind):
		col = Color(1.0, 0.72, 0.25)
		st = 1.0
	var key := col.to_html() + str(st)
	if not _glow_mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/item.gdshader")
		m.set_shader_parameter("tex", U.atlas())
		m.set_shader_parameter("glow", col)
		m.set_shader_parameter("strength", st)
		_glow_mats[key] = m
	return _glow_mats[key]


static func _apply_glow(n: Node, mat: ShaderMaterial) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_override = mat
	for c in n.get_children():
		_apply_glow(c, mat)


# Modelo de item no chão (arma deitada, kit, colete, capacete, caixa)
static func build_item(kind: String, glow := true) -> Node3D:
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
		if glow:
			_apply_glow(root, glow_mat(kind))
		return root
	var mi := U.mesh(root, item_mesh(kind))
	mi.visibility_range_end = 120.0 if kind == "box" else 80.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if glow and kind != "box":
		_apply_glow(root, glow_mat(kind))
	return root
