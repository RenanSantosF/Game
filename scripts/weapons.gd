class_name Weapons
extends RefCounted

# dmg = dano por bala, rate = tiros por segundo, spread = dispersão em graus,
# head = multiplicador de tiro na cabeça, zoom = aumento da mira.
const DATA := {
	"glock": {"name": "Glock 17", "dmg": 20.0, "rate": 4.5, "mag": 17, "reload": 1.5, "spread": 1.6, "range": 60.0, "pellets": 1, "head": 1.8, "zoom": 1.0, "recoil": 0.012, "len": 0.22, "type": "pistol"},
	"mp5": {"name": "MP5", "dmg": 17.0, "rate": 12.0, "mag": 30, "reload": 2.2, "spread": 2.4, "range": 70.0, "pellets": 1, "head": 1.6, "zoom": 1.3, "recoil": 0.008, "len": 0.6, "type": "smg"},
	"m4a1": {"name": "M4A1", "dmg": 24.0, "rate": 10.0, "mag": 30, "reload": 2.4, "spread": 1.6, "range": 160.0, "pellets": 1, "head": 1.8, "zoom": 1.6, "recoil": 0.012, "len": 0.85, "type": "rifle"},
	"ak47": {"name": "AK-47", "dmg": 31.0, "rate": 8.5, "mag": 30, "reload": 2.6, "spread": 2.2, "range": 160.0, "pellets": 1, "head": 1.8, "zoom": 1.5, "recoil": 0.02, "len": 0.88, "type": "ak"},
	"r870": {"name": "Remington 870", "dmg": 13.0, "rate": 1.2, "mag": 6, "reload": 3.0, "spread": 5.5, "range": 32.0, "pellets": 8, "head": 1.5, "zoom": 1.0, "recoil": 0.05, "len": 1.0, "type": "shotgun"},
	"awm": {"name": "AWM", "dmg": 90.0, "rate": 0.75, "mag": 5, "reload": 3.4, "spread": 4.0, "range": 400.0, "pellets": 1, "head": 2.2, "zoom": 4.0, "recoil": 0.06, "len": 1.2, "type": "sniper"},
}

# Armas que aparecem no chão das casas (repetidas = mais comuns)
const LOOT := ["mp5", "mp5", "m4a1", "m4a1", "ak47", "ak47", "r870", "r870", "awm"]
const BOT_GUNS := ["mp5", "m4a1", "ak47", "r870"]

const METAL := Color(0.12, 0.12, 0.13)
const WOOD := Color(0.42, 0.26, 0.13)


static func get_w(id: String) -> Dictionary:
	if DATA.has(id):
		return DATA[id]
	return DATA["glock"]


# Modelo simples feito de blocos. Origem no cabo, cano apontando para -Z.
static func build_model(id: String) -> Node3D:
	var w := get_w(id)
	var root := Node3D.new()
	var L: float = w["len"]
	var t: String = w["type"]
	var wood := t == "ak" or t == "shotgun"
	# cabo
	U.box(root, Vector3(0.05, 0.13, 0.06), Vector3(0, -0.07, 0.02), METAL)
	# corpo
	var rec_len := L * 0.5 + 0.05
	U.box(root, Vector3(0.07, 0.09, rec_len), Vector3(0, 0.02, (0.05 - L * 0.5) / 2.0), METAL)
	# cano
	U.box(root, Vector3(0.035, 0.035, L * 0.5), Vector3(0, 0.035, -L * 0.75), METAL)
	if t != "pistol":
		# coronha
		U.box(root, Vector3(0.05, 0.1, 0.28), Vector3(0, -0.01, 0.18), WOOD if wood else METAL)
	if t == "smg" or t == "rifle" or t == "ak":
		var m := U.box(root, Vector3(0.05, 0.16, 0.07), Vector3(0, -0.08, -L * 0.3), METAL)
		if t == "ak":
			m.rotation.x = 0.3
	if t == "ak":
		U.box(root, Vector3(0.075, 0.07, L * 0.22), Vector3(0, 0.02, -L * 0.58), WOOD)
	if t == "shotgun":
		U.box(root, Vector3(0.06, 0.06, 0.2), Vector3(0, -0.01, -L * 0.62), WOOD)
	if t == "sniper":
		U.box(root, Vector3(0.05, 0.05, 0.26), Vector3(0, 0.1, -L * 0.22), METAL)
	elif t == "rifle":
		U.box(root, Vector3(0.04, 0.04, 0.12), Vector3(0, 0.09, -L * 0.2), METAL)
	var muzzle := Node3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, 0.035, -L)
	root.add_child(muzzle)
	return root
