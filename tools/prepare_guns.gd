extends SceneTree
# Converte o "Ultimate Gun Pack" da Quaternius (CC0, models_src/guns) para as armas do jogo:
#   models/guns/<arma>.res  (malha única com cor por vértice, cano apontando pra -Z, origem no cabo)
#   models/guns/acc_<peça>.res  (lunetas e silenciador)
#   scripts/gun_info.gd     (ponta do cano e altura do trilho de cada arma, gerado aqui)
# Uso: godot --headless --script tools/prepare_guns.gd

const SRC := "res://models_src/guns/"
const TAN := Color(0.62, 0.53, 0.38)
# arma do jogo: [modelo, comprimento total real (m), troca de cor por nome do material]
const GUNS := {
	"glock": ["Pistol_1", 0.19, {}],
	"deagle": ["Pistol_4", 0.27, {"Metal": Color(0.62, 0.62, 0.64), "LightMetal": Color(0.75, 0.75, 0.77)}],
	"mp5": ["SubmachineGun_2", 0.68, {}],
	"ump45": ["SubmachineGun_5", 0.69, {}],
	"m4a1": ["AssaultRifle2_1", 0.84, {}],
	"scar": ["AssaultRifle2_2", 0.9, {"Main": TAN, "MainLight": Color(0.7, 0.62, 0.46), "MainDark": Color(0.2, 0.2, 0.2)}],
	"ak47": ["AssaultRifle_2", 0.88, {}],
	"r870": ["Shotgun_1", 1.0, {}],
	"m1014": ["Shotgun_3", 1.0, {"Wood": Color(0.17, 0.17, 0.18), "DarkWood": Color(0.13, 0.13, 0.14)}],
	"kar98": ["SniperRifle_6", 1.1, {}],
	"awm": ["SniperRifle_3", 1.2, {}],
}
# alça de mira alta (M4/SCAR): a luneta encaixa mais embaixo, no trilho
const RAIL_FIX := {"m4a1": -0.038, "scar": -0.04}
const ACC := {"scope2": ["acc/Scope_1", 0.16], "scope4": ["acc/Scope_2", 0.26], "scope8": ["acc/Scope_3", 0.34],
	"silencer": ["acc/Silencer_1", 0.17], "stock": ["acc/Stock", 0.2]}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://models/guns"))
	var info := {}
	for id in GUNS:
		var g: Array = GUNS[id]
		var src: Mesh = load(SRC + g[0] + ".obj")
		var ab := src.get_aabb()
		var s: float = float(g[1]) / ab.size.x
		var xf := Transform3D(Basis(Vector3.UP, PI / 2.0).scaled(Vector3.ONE * s), Vector3.ZERO)
		var mesh := _convert(src, xf, g[2])
		ResourceSaver.save(mesh, "res://models/guns/%s.res" % id)
		# ponta do cano: vértices do fim (+X no modelo); trilho: topo da parte do meio
		var xmax := ab.end.x
		var bore := 0.0
		var nb := 0
		var rail := -99.0
		for si in src.get_surface_count():
			for v: Vector3 in (src.surface_get_arrays(si)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				if v.x > xmax - 0.06:
					bore += v.y
					nb += 1
				if v.x > xmax * 0.05 and v.x < xmax * 0.45:
					rail = maxf(rail, v.y)
		bore /= maxi(nb, 1)
		info[id] = {"muzzle": Vector3(0, bore * s, -xmax * s), "rail": rail * s + float(RAIL_FIX.get(id, 0.0)), "len": xmax * s}
		print(id, " escala=%.3f cano=%s trilho=%.3f" % [s, info[id]["muzzle"], info[id]["rail"]])
	for a in ACC:
		var src: Mesh = load(SRC + ACC[a][0] + ".obj")
		var ab := src.get_aabb()
		var s: float = float(ACC[a][1]) / ab.size.x
		# centrado embaixo (onde encaixa), apontando pra -Z
		var c := ab.get_center()
		var xf := Transform3D(Basis(Vector3.UP, PI / 2.0).scaled(Vector3.ONE * s), Vector3.ZERO) * Transform3D(Basis(), -Vector3(c.x, ab.position.y, c.z))
		ResourceSaver.save(_convert(src, xf, {}), "res://models/guns/acc_%s.res" % a)
	# informações pro jogo
	var txt := "class_name GunInfo\nextends RefCounted\n\n# Gerado por tools/prepare_guns.gd (não editar à mão).\n# muzzle = ponta do cano, rail = altura do trilho (onde vai a mira), len = do cabo até a ponta\nconst INFO := {\n"
	for id in info:
		var m: Vector3 = info[id]["muzzle"]
		txt += "\t\"%s\": {\"muzzle\": Vector3(%.4f, %.4f, %.4f), \"rail\": %.4f, \"len\": %.4f},\n" % [id, m.x, m.y, m.z, info[id]["rail"], info[id]["len"]]
	txt += "}\n"
	var f := FileAccess.open("res://scripts/gun_info.gd", FileAccess.WRITE)
	f.store_string(txt)
	f.close()
	quit()


# junta as partes numa malha só: cor do material (convertida pra sRGB) no vértice, camada lisa do atlas
func _convert(src: Mesh, xf: Transform3D, recolor: Dictionary) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for si in src.get_surface_count():
		var mat := src.surface_get_material(si)
		var col := Color(0.2, 0.2, 0.2)
		var nm := ""
		if mat is BaseMaterial3D:
			col = (mat as BaseMaterial3D).albedo_color.linear_to_srgb()
			nm = mat.resource_name
		if recolor.has(nm):
			col = recolor[nm]
		# metal um pouco mais claro pra aparecer no celular
		col = col.lightened(0.13)
		var a := src.surface_get_arrays(si)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var idx = a[Mesh.ARRAY_INDEX]
		var order: Array = range(v.size()) if idx == null or (idx as PackedInt32Array).is_empty() else Array(idx)
		for t in order:
			st.set_color(col)
			st.set_uv(Vector2.ZERO)
			st.set_uv2(Vector2(15, 0))
			st.set_normal((xf.basis * n[t]).normalized())
			st.add_vertex(xf * v[t])
	st.index()
	return st.commit()
