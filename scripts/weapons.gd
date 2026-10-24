class_name Weapons
extends RefCounted

# dmg = dano por bala, rate = tiros por segundo, spread = dispersão em graus,
# head = multiplicador de tiro na cabeça, zoom = aumento da mira, ammo = calibre.
# slot 0 = arma principal (2 vagas), slot 1 = pistola. Vida de cada jogador: 200.
const DATA := {
	"fist": {"name": "Soco", "dmg": 25.0, "rate": 2.2, "mag": 1, "reload": 0.0, "spread": 0.0, "range": 2.2, "pellets": 1, "head": 1.5, "zoom": 1.0, "recoil": 0.0, "len": 0.0, "type": "fist", "slot": 2, "ammo": ""},
	"glock": {"name": "Glock 17", "dmg": 36.0, "rate": 3.6, "mag": 17, "reload": 1.5, "spread": 1.2, "range": 60.0, "pellets": 1, "head": 2.2, "zoom": 1.0, "recoil": 0.014, "len": 0.2, "type": "pistol", "slot": 1, "ammo": "a9", "bloom": 0.25, "bloom_max": 2.0},
	"deagle": {"name": "Desert Eagle", "dmg": 82.0, "rate": 1.4, "mag": 7, "reload": 1.9, "spread": 1.0, "range": 80.0, "pellets": 1, "head": 2.5, "zoom": 1.0, "recoil": 0.06, "len": 0.27, "type": "pistol", "slot": 1, "ammo": "a9", "bloom": 0.7, "bloom_max": 3.0},
	"mp5": {"name": "MP5", "dmg": 37.0, "rate": 9.0, "mag": 30, "reload": 2.2, "spread": 1.7, "range": 70.0, "pellets": 1, "head": 1.9, "zoom": 1.3, "recoil": 0.008, "len": 0.62, "type": "smg", "slot": 0, "ammo": "a9", "bloom": 0.1, "bloom_max": 1.5},
	"ump45": {"name": "UMP-45", "dmg": 45.0, "rate": 7.5, "mag": 25, "reload": 2.3, "spread": 1.5, "range": 75.0, "pellets": 1, "head": 1.9, "zoom": 1.3, "recoil": 0.011, "len": 0.65, "type": "smg", "slot": 0, "ammo": "a9", "bloom": 0.13, "bloom_max": 1.7},
	"m4a1": {"name": "M4A1", "dmg": 47.0, "rate": 6.8, "mag": 30, "reload": 2.4, "spread": 0.9, "range": 160.0, "pellets": 1, "head": 2.2, "zoom": 1.6, "recoil": 0.012, "len": 0.85, "type": "rifle", "slot": 0, "ammo": "a556", "bloom": 0.15, "bloom_max": 2.2},
	"scar": {"name": "SCAR-L", "dmg": 51.0, "rate": 6.3, "mag": 30, "reload": 2.5, "spread": 0.9, "range": 170.0, "pellets": 1, "head": 2.2, "zoom": 1.8, "recoil": 0.015, "len": 0.88, "type": "scar", "slot": 0, "ammo": "a556", "bloom": 0.2, "bloom_max": 2.6},
	"ak47": {"name": "AK-47", "dmg": 60.0, "rate": 6.5, "mag": 30, "reload": 2.6, "spread": 1.1, "range": 160.0, "pellets": 1, "head": 2.2, "zoom": 1.5, "recoil": 0.024, "len": 0.88, "type": "ak", "slot": 0, "ammo": "a556", "bloom": 0.5, "bloom_max": 4.5},
	"r870": {"name": "Remington 870", "dmg": 37.0, "rate": 0.6, "mag": 5, "reload": 3.2, "spread": 5.0, "range": 32.0, "pellets": 8, "head": 1.6, "zoom": 1.0, "recoil": 0.12, "len": 1.0, "type": "shotgun", "slot": 0, "ammo": "a12"},
	"m1014": {"name": "M1014", "dmg": 29.0, "rate": 1.05, "mag": 6, "reload": 3.4, "spread": 6.0, "range": 28.0, "pellets": 8, "head": 1.6, "zoom": 1.0, "recoil": 0.1, "len": 1.0, "type": "shotgun", "slot": 0, "ammo": "a12"},
	"kar98": {"name": "Kar98k", "dmg": 130.0, "rate": 0.65, "mag": 5, "reload": 3.2, "spread": 3.5, "range": 350.0, "pellets": 1, "head": 3.0, "zoom": 4.0, "recoil": 0.06, "len": 1.1, "type": "bolt", "slot": 0, "ammo": "a762"},
	"awm": {"name": "AWM", "dmg": 170.0, "rate": 0.5, "mag": 5, "reload": 4.2, "spread": 4.0, "range": 400.0, "pellets": 1, "head": 2.6, "zoom": 4.0, "recoil": 0.08, "len": 1.2, "type": "sniper", "slot": 0, "ammo": "a762"},
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


# Itens que não são armas. w = quanto cada unidade ocupa da mochila (espaço por quantidade, não por vaga);
# count = quanto vem no chão.
# Colete, capacete, mochila, coronha e carregador têm nível 1, 2 e 3 (cor diferente no chão).
const ITEMS := {
	# 4 munições: SMG/pistola, fuzil (M4, SCAR, AK), sniper (Kar98, AWM) e 12
	"a9": {"name": "Munição de SMG", "w": 0.25, "count": 30, "kind": "ammo"},
	"a556": {"name": "Munição de fuzil", "w": 0.3, "count": 30, "kind": "ammo"},
	"a762": {"name": "Munição de sniper", "w": 1.0, "count": 10, "kind": "ammo"},
	"a12": {"name": "Cartucho 12", "w": 0.8, "count": 12, "kind": "ammo"},
	"bandage": {"name": "Bandagem", "w": 2.0, "count": 4, "kind": "heal", "heal": 30.0, "time": 2.0},
	"med": {"name": "Kit médico", "w": 15.0, "count": 1, "kind": "heal", "heal": 100.0, "time": 4.5},
	"drink": {"name": "Energético", "w": 4.0, "count": 2, "kind": "heal", "heal": 50.0, "time": 2.5},
	"grenade": {"name": "Granada", "w": 6.0, "count": 1, "kind": "throw"},
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
const ATTS := ["stock1", "stock2", "stock3", "mag1", "mag2", "mag3", "scope2", "scope4", "silencer"]
# o que cada tipo de arma aceita (escopeta não tem mira nem silenciador)
const FITS := {
	"pistol": ["mag", "scope2", "muzzle"],
	"smg": ["stock", "mag", "scope2", "scope4", "muzzle"],
	"rifle": ["stock", "mag", "scope2", "scope4", "muzzle"],
	"scar": ["stock", "mag", "scope2", "scope4", "muzzle"],
	"ak": ["stock", "mag", "scope2", "scope4", "muzzle"],
	"shotgun": ["stock", "mag"],
	"bolt": ["mag", "muzzle"],     # luneta 4x própria
	"sniper": ["mag", "muzzle"],
}
const AMMO := ["a9", "a556", "a762", "a12"]
const BAGS := [80, 160, 240, 320]   # espaço sem mochila e com mochila nível 1, 2 e 3
const VEST_ABSORB := [0.0, 0.3, 0.42, 0.55]    # quanto do dano no corpo o colete segura
const HELMET_ABSORB := [0.0, 0.25, 0.38, 0.5]  # quanto do dano na cabeça o capacete segura
# cor de raridade (destaque no chão): nível 1 cáqui, 2 verde, 3 cinza-aço (cores de guerra, nada de roxo); armas dourado
const RARITY := [Color(0.9, 0.9, 0.9), Color(0.88, 0.8, 0.58), Color(0.45, 0.8, 0.33), Color(0.68, 0.74, 0.78)]

# Loot espalhado pelo mapa (repetido = mais comum)
const LOOT := [
	"mp5", "ump45", "m4a1", "scar", "ak47", "r870", "m1014", "kar98", "deagle", "glock", "glock",
	"med", "med", "med", "med", "med", "med", "med", "grenade", "grenade",
	"a9", "a9", "a9", "a556", "a556", "a556", "a556", "a762", "a762", "a12", "a12",
	"vest1", "vest1", "vest2", "vest3", "helmet1", "helmet1", "helmet2", "helmet3", "bag1", "bag1", "bag2", "bag3",
	"stock1", "stock2", "stock3", "mag1", "mag1", "mag2", "mag3", "scope2", "scope2", "scope2", "scope4", "scope4", "silencer",
]
const LOOT_GUNS := ["mp5", "ump45", "m4a1", "scar", "ak47", "r870", "m1014", "kar98", "deagle", "glock", "mp5", "m4a1", "ak47", "ump45", "glock"]
const LOOT_MILITARY := ["m4a1", "scar", "ak47", "kar98", "awm", "vest2", "vest3", "helmet2", "helmet3", "scope4", "scope4", "mag3", "stock3", "med", "bag2", "bag3", "a556", "a762"]

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


# munição que vem do lado de uma arma no chão: pistola 12 balas, o resto o pente padrão (30 fuzil/SMG)
static func ammo_pack(gun: String) -> int:
	if is_gun(gun) and get_w(gun)["type"] == "pistol":
		return 12
	return default_count(ammo_of(gun))


static func default_count(kind: String) -> int:
	if ITEMS.has(kind) and ITEMS[kind].has("count"):
		return int(ITEMS[kind]["count"])
	return 1


# quanto uma unidade ocupa da mochila
static func weight(kind: String) -> float:
	if ITEMS.has(kind) and ITEMS[kind].has("w"):
		return float(ITEMS[kind]["w"])
	return 5.0    # acessório


# espaço que um inventário ocupa (por quantidade: 100 balas ocupam mais que 10)
static func slots_used(inv: Dictionary) -> int:
	var n := 0.0
	for k in inv:
		var c: int = inv[k]
		if c > 0:
			n += c * weight(k)
	return ceili(n - 0.001)


# status da arma com os acessórios
static func stat(id: String, att: Array) -> Dictionary:
	var w: Dictionary = get_w(id).duplicate()
	w["id"] = id
	w["bloom"] = float(w.get("bloom", 0.0))
	w["bloom_max"] = float(w.get("bloom_max", 0.0))
	# segurando o dedo o tiro chega no máximo de espalhar em ~1,3 s; com coronha demora só um pouco mais
	var sl := att_level(att, "stock")
	if w["bloom_max"] > 0.0:
		w["bloom"] = w["bloom_max"] / (float(w["rate"]) * 1.3) * [1.0, 0.9, 0.82, 0.75][sl]
	if sl > 0:
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
const GUN_LO := 12.0    # a partir daqui a arma (no chão, na mão ou nas costas dos outros) é a simplificada


static func build_model(id: String, att: Array = [], lod := true) -> Node3D:
	var root := Node3D.new()
	var mesh := mesh_for(id, att)
	if mesh:
		var hi := U.mesh(root, mesh)
		# de longe a versão simplificada (cerca de metade dos triângulos), filha da malha completa
		if lod:
			hi.visibility_range_end = GUN_LO
			hi.set_meta("lod", true)
			var lo := MeshInstance3D.new()
			lo.mesh = U.cluster_mesh(mesh, 0.014)
			lo.material_override = hi.material_override
			lo.visibility_range_begin = GUN_LO
			lo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			hi.add_child(lo)
	var muzzle := Node3D.new()
	muzzle.name = "Muzzle"
	var my: float = GunInfo.INFO[id]["muzzle"].y if GunInfo.INFO.has(id) else 0.035
	muzzle.position = Vector3(0, my, -muzzle_len(id, att))
	root.add_child(muzzle)
	return root


# ---------------- colete, capacete e mochila ----------------
# Um desenho só (vestido no boneco); no chão o mesmo modelo aparece deitado/em pé.
# Cor por nível: 1 verde-oliva, 2 verde, 3 cinza-aço.
const LV_COL := [Color(0.46, 0.5, 0.32), Color(0.4, 0.6, 0.3), Color(0.5, 0.55, 0.58)]
const STRAP := Color(0.1, 0.1, 0.1)
const MIL_COL := [Color(0.56, 0.62, 0.4), Color(0.52, 0.58, 0.5), Color(0.5, 0.52, 0.54)]   # nível 1 verde-oliva, 2 verde-acinzentado, 3 cinza


static func gear(kind: String) -> Mesh:
	var key := "gear_" + kind
	if _cache.has(key):
		return _cache[key]
	var lv := clampi(level_of(kind), 1, 3)
	# cores de exército (verde-oliva, coiote, preto); o nível aparece num remendo colorido
	var c: Color = MIL_COL[lv - 1]
	var patch: Color = RARITY[lv]
	var m := MB.new()
	m.tex(U.FABRIC, 5.0)
	# medidas do corpo (espaço do boneco: pés em 0, frente = -Z): peito na frente em z≈-0.10..-0.13,
	# costas em z≈+0.11..+0.135, meia-largura do tronco ≈0.12, cabeça centrada em (0, 1.6, -0.025)
	# detalhes brilhantes (cor do nível e fivelas): vão numa segunda parte com material liso e brilhante
	var tm := MB.new()
	tm.tex(U.PLAIN, 4.0)
	if is_vest(kind):
		# colete porta-placas justo no corpo: placa da frente inclinada acompanhando o peito, placa das
		# costas, faixa lateral, alças nos ombros, porta-carregadores; nível = cor das bordas + listras
		var fr := Basis(Vector3.RIGHT, -0.12)
		m.box(Transform3D(fr, Vector3(0, 1.24, -0.145)), Vector3(0.245, 0.29, 0.03), c)
		m.box(Transform3D(Basis(), Vector3(0, 1.25, 0.152)), Vector3(0.245, 0.28, 0.03), c)
		for sx in [-1.0, 1.0]:
			# faixa lateral (cummerbund) e alças por cima do ombro
			m.box(Transform3D(Basis(), Vector3(sx * 0.128, 1.14, 0.0)), Vector3(0.02, 0.11, 0.27), c.darkened(0.12))
			m.box(Transform3D(Basis(), Vector3(sx * 0.085, 1.43, 0.004)), Vector3(0.05, 0.016, 0.25), c.darkened(0.08))
		# porta-carregadores na frente (mais a cada nível) com tampas
		var np := 2 + lv
		for k in np:
			var x := (k - (np - 1) / 2.0) * 0.055
			m.box(Transform3D(fr, Vector3(x, 1.15, -0.172)), Vector3(0.048, 0.09, 0.028), c.lightened(0.05))
			m.box(Transform3D(fr, Vector3(x, 1.2, -0.178)), Vector3(0.05, 0.018, 0.032), c.darkened(0.15))
		# tiras MOLLE na placa (faixas finas)
		m.tex(U.PLAIN, 4.0)
		for k in 3:
			m.box(Transform3D(fr, Vector3(0, 1.28 + k * 0.03, -0.162)), Vector3(0.23, 0.007, 0.005), c.darkened(0.3))
			m.box(Transform3D(Basis(), Vector3(0, 1.18 + k * 0.045, 0.169)), Vector3(0.23, 0.007, 0.005), c.darkened(0.3))
		if lv >= 2:
			m.tex(U.FABRIC, 5.0)
			m.box(Transform3D(fr, Vector3(0.06, 1.33, -0.166)), Vector3(0.08, 0.06, 0.016), c.darkened(0.06))
		if lv == 3:
			m.tex(U.PLAIN, 4.0)
			m.box(Transform3D(Basis(), Vector3(0.07, 1.27, 0.178)), Vector3(0.05, 0.1, 0.028), Color(0.12, 0.13, 0.11))
			m.cyl(Transform3D(Basis(), Vector3(0.085, 1.32, 0.178)), 0.004, 0.003, 0.18, 4, STRAP)
		# bordas da placa na cor do nível (brilhantes) e listras do nível (1, 2 ou 3) no peito e nas costas
		for zz in [-0.162, 0.168]:
			var bs: Basis = fr if zz < 0.0 else Basis()
			var zc: float = zz + (-0.001 if zz < 0.0 else 0.001)
			tm.box(Transform3D(bs, Vector3(0, 1.24 + 0.143, zc)), Vector3(0.25, 0.012, 0.006), patch)
			for sx in [-1.0, 1.0]:
				tm.box(Transform3D(bs, Vector3(sx * 0.122, 1.24, zc)), Vector3(0.01, 0.28, 0.006), patch)
			for k in lv:
				tm.box(Transform3D(bs, Vector3(-0.07, 1.345 - k * 0.022, zc - 0.002 * signf(zz))), Vector3(0.06, 0.012, 0.004), patch.lightened(0.15))
		# fivelas de metal
		for sx in [-1.0, 1.0]:
			tm.box(Transform3D(Basis(), Vector3(sx * 0.13, 1.14, -0.09)), Vector3(0.012, 0.04, 0.03), Color(0.55, 0.55, 0.56))
	elif is_helmet(kind):
		# capacete de combate: casco que cobre o topo e a nuca, aberto no rosto, com borda,
		# jugular, capa do nível e (nível 3) suporte de visão noturna e trilhos
		var hc := Vector3(0, 1.618, -0.022)
		var rr := Vector3(0.106, 0.098, 0.122)
		var seg := 16
		var rings := 7
		var pts := []
		for j in rings + 1:
			var row := []
			for i in seg + 1:
				var az := TAU * i / seg
				var front := maxf(0.0, -cos(az))      # 1 na frente (-Z), 0 dos lados/atrás
				var low := lerpf(-0.42, 0.18, front)   # na frente o casco termina acima da testa
				var el := lerpf(low, PI / 2.0, float(j) / rings)
				row.append(hc + Vector3(sin(az) * cos(el) * rr.x, sin(el) * rr.y, -cos(az) * cos(el) * rr.z))
			pts.append(row)
		var cc := c if lv >= 2 else c.lightened(0.05)
		for j in rings:
			for i in seg:
				var a0: Vector3 = pts[j][i]
				var a1: Vector3 = pts[j][i + 1]
				var b0: Vector3 = pts[j + 1][i]
				var b1: Vector3 = pts[j + 1][i + 1]
				var nrm := ((a0 + a1 + b0 + b1) / 4.0 - hc).normalized()
				m.quad(a0, a1, b1, b0, cc, nrm)
				m.quad(a1, a0, b0, b1, cc.darkened(0.5), -nrm)
		# borda (aba fina por fora)
		m.tex(U.PLAIN, 4.0)
		for i in seg:
			var e0: Vector3 = pts[0][i]
			var e1: Vector3 = pts[0][i + 1]
			var o0 := e0 + (e0 - hc) * Vector3(0.12, 0.0, 0.12)
			var o1 := e1 + (e1 - hc) * Vector3(0.12, 0.0, 0.12)
			m.quad(e0, e1, o1, o0, cc.darkened(0.25), Vector3.DOWN)
			m.quad(o0, o1, e1, e0, cc.darkened(0.25), Vector3.UP)
		# jugular (alças descendo até o queixo)
		for sx in [-1.0, 1.0]:
			m.box(Transform3D(Basis(Vector3.FORWARD, sx * 0.12), Vector3(sx * 0.093, 1.535, -0.03)), Vector3(0.008, 0.09, 0.016), STRAP)
		# faixa do nível em volta do capacete e listras atrás (brilhantes)
		for i in seg:
			var e0: Vector3 = pts[1][i]
			var e1: Vector3 = pts[1][i + 1]
			var o0 := e0 + (e0 - hc).normalized() * 0.004
			var o1 := e1 + (e1 - hc).normalized() * 0.004
			tm.quad(o0, o1, o1 + Vector3(0, 0.012, 0), o0 + Vector3(0, 0.012, 0), patch, (e0 - hc).normalized())
		for k in lv:
			tm.box(Transform3D(Basis(Vector3.RIGHT, 0.4), Vector3(0, 1.672 - k * 0.018, 0.108)), Vector3(0.05, 0.01, 0.004), patch.lightened(0.15))
		if lv == 3:
			m.box(Transform3D(Basis(Vector3.RIGHT, -0.35), Vector3(0, 1.665, -0.14)), Vector3(0.05, 0.04, 0.02), Color(0.12, 0.12, 0.12))
			m.box(Transform3D(Basis(Vector3.RIGHT, 0.2), Vector3(0, 1.66, -0.165)), Vector3(0.06, 0.03, 0.04), Color(0.2, 0.2, 0.22))
			for sx in [-1.0, 1.0]:
				m.box(Transform3D(Basis(), Vector3(sx * 0.108, 1.615, -0.02)), Vector3(0.012, 0.022, 0.12), Color(0.12, 0.12, 0.12))
	elif is_bag(kind):
		# mochila militar arredondada (lona estufada), colada nas costas, maior a cada nível:
		# corpo curvo, tampa abaulada, bolso da frente estufado, bolsos laterais, fitas de compressão
		var k: float = [0.0, 0.85, 1.0, 1.12][lv]
		var d := 0.12 * k
		var h := 0.37 * k
		var w := 0.28 * minf(k, 1.05)
		var z0 := 0.15     # encosta nas costas (o colete, se tiver, fica escondido atrás dela)
		var yc := 1.22
		var zc := z0 + d / 2.0
		# corpo: costas retas (encostam no corpo), resto estufado
		_pack(m, Vector3(0, yc, zc), Vector3(w / 2.0, h / 2.0, d / 2.0), c, 0.45, zc - d * 0.32)
		# tampa por cima, caindo um pouco pra trás
		_pack(m, Vector3(0, yc + h * 0.44, zc + 0.012), Vector3(w * 0.53, h * 0.11, d * 0.6), c.darkened(0.12), 0.5)
		# bolso da frente, estufado, na parte de baixo
		_pack(m, Vector3(0, yc - h * 0.14, z0 + d * 0.98), Vector3(w * 0.38, h * 0.26, 0.035 + 0.01 * lv), c.lightened(0.04), 0.5)
		if lv >= 2:
			# bolsos laterais (cantil/carregador)
			for sx in [-1.0, 1.0]:
				_pack(m, Vector3(sx * (w * 0.5 + 0.012), yc - h * 0.12, zc + 0.006), Vector3(0.026, h * 0.24, d * 0.36), c.darkened(0.06), 0.55)
		m.tex(U.PLAIN, 4.0)
		# fitas de compressão contornando as laterais e o bolso, e o remendo do nível
		for sx in [-1.0, 1.0]:
			m.box(Transform3D(Basis(), Vector3(sx * w * 0.3, yc + h * 0.02, z0 + d * 1.005)), Vector3(0.022, h * 0.86, 0.006), STRAP)
		for kk in 2:
			m.box(Transform3D(Basis(), Vector3(0, yc - h * 0.06 - kk * 0.045, z0 + d * 0.98 + 0.04 + 0.01 * lv)), Vector3(w * 0.6, 0.008, 0.005), c.darkened(0.32))
		for li in lv:
			tm.box(Transform3D(Basis(), Vector3(0, yc + h * 0.3 - li * 0.02, z0 + d * 1.0 + 0.003)), Vector3(0.07, 0.012, 0.004), patch)
		# alças por cima dos ombros
		for sx in [-1.0, 1.0]:
			m.box(Transform3D(Basis(Vector3.RIGHT, -0.4), Vector3(sx * 0.075, 1.44, 0.14)), Vector3(0.045, 0.02, 0.12), STRAP)
		if lv == 3:
			# isolante enrolado embaixo
			m.tex(U.FABRIC, 6.0)
			m.cyl(Transform3D(Basis(Vector3.FORWARD, PI / 2.0), Vector3(-w * 0.5, yc - h / 2.0 - 0.03, zc)), 0.04, 0.04, w, 12, Color(0.25, 0.27, 0.22))
	var mesh := m.commit()
	if tm.count > 0:
		# segunda parte: detalhes lisos e brilhantes
		var tmesh := tm.commit()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tmesh.surface_get_arrays(0))
		mesh.surface_set_material(mesh.get_surface_count() - 1, _shiny())
	_cache[key] = mesh
	return mesh


static var _shiny_mat: StandardMaterial3D


static func _shiny() -> StandardMaterial3D:
	if _shiny_mat == null:
		_shiny_mat = StandardMaterial3D.new()
		_shiny_mat.vertex_color_use_as_albedo = true
		_shiny_mat.vertex_color_is_srgb = true
		_shiny_mat.roughness = 0.22
		_shiny_mat.metallic = 0.25
		_shiny_mat.metallic_specular = 0.8
		_shiny_mat.rim_enabled = true
		_shiny_mat.rim = 0.4
	return _shiny_mat


# volume arredondado (superelipsoide): e ~0.4 = caixa de cantos bem redondos, 1 = elipsoide.
# flat_z: corta o lado de trás (z menor) reto nesse plano (encosta no corpo)
static func _pack(m: MB, ctr: Vector3, hs: Vector3, col: Color, e: float, flat_z := -INF) -> void:
	var seg := 14
	var rings := 8
	var pts := []
	for j in rings + 1:
		var el := lerpf(-PI / 2.0, PI / 2.0, float(j) / rings)
		var row := []
		for i in seg + 1:
			var az := TAU * i / seg
			var ce := _sp(cos(el), e)
			var p := ctr + Vector3(_sp(sin(az), e) * ce * hs.x, _sp(sin(el), e) * hs.y, -_sp(cos(az), e) * ce * hs.z)
			p.z = maxf(p.z, flat_z)
			row.append(p)
		pts.append(row)
	for j in rings:
		for i in seg:
			var a0: Vector3 = pts[j][i]
			var a1: Vector3 = pts[j][i + 1]
			var b0: Vector3 = pts[j + 1][i]
			var b1: Vector3 = pts[j + 1][i + 1]
			var mid := (a0 + a1 + b0 + b1) / 4.0 - ctr
			var nrm := Vector3(mid.x / (hs.x * hs.x), mid.y / (hs.y * hs.y), mid.z / (hs.z * hs.z)).normalized()
			m.quad(a0, a1, b1, b0, col, nrm)


static func _sp(v: float, e: float) -> float:
	return signf(v) * pow(absf(v), e)


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
			# caixa de quem morreu: pequena (não tampa o chão nem atrapalha)
			m.boxp(Vector3(0, 0.15, 0), Vector3(0.54, 0.3, 0.36), olive)
			m.boxp(Vector3(0, 0.315, 0), Vector3(0.57, 0.04, 0.39), olive.darkened(0.2))
			m.tex(U.PLAIN, 4.0)
			m.boxp(Vector3(0, 0.18, -0.19), Vector3(0.18, 0.07, 0.02), Color(0.9, 0.75, 0.2))
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
		var gm := gear(kind)
		for si in gm.get_surface_count():
			st.append_from(gm, si, xf)
		mesh = st.commit()
	_cache[key] = mesh
	return mesh


# brilho do item no chão na cor da raridade (nível 2 verde, 3 cinza-aço, armas dourado, resto branco fraco)
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
		for c in g.find_children("*", "MeshInstance3D", true, false):
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if not c.has_meta("lod"):
				c.visibility_range_end = 50.0
		if glow:
			_apply_glow(root, glow_mat(kind))
		return root
	var mi := U.mesh(root, item_mesh(kind))
	mi.visibility_range_end = 80.0 if kind == "box" else 40.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if glow and kind != "box":
		_apply_glow(root, glow_mat(kind))
	return root
