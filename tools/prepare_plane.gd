extends SceneTree

# Avião do salto (models_src/plane/plane.obj, CC0, ver LICENCA.txt) -> models/plane.scn
# Pintura militar (cinza-oliva por cima, claro por baixo), hélices separadas (PropL/PropR) pra girar.
# Uso: godot --headless -s tools/prepare_plane.gd

const SRC := "res://models_src/plane/plane.obj"
const OUT := "res://models/plane.scn"
const SCALE := 1.6

const PAINT := {
	"fus": Color(0.42, 0.45, 0.38), "fus.003": Color(0.42, 0.45, 0.38), "tail": Color(0.38, 0.41, 0.35),
	"eng": Color(0.36, 0.38, 0.33), "eng.001": Color(0.36, 0.38, 0.33), "stab": Color(0.3, 0.32, 0.28),
	"tire": Color(0.06, 0.06, 0.06), "Anizotrop": Color(0.25, 0.27, 0.3), "props": Color(0.08, 0.08, 0.08),
	"gear": Color(0.3, 0.3, 0.3),
}


func _initialize() -> void:
	var src: Mesh = load(SRC)
	var root := Node3D.new()
	root.name = "Plane"
	var body := SurfaceTool.new()
	body.begin(Mesh.PRIMITIVE_TRIANGLES)
	var props := [[], []]
	var ab := src.get_aabb()
	var ctr := ab.get_center()
	# o arquivo aponta o nariz pra +Z; o jogo usa -Z como frente
	var flip := Basis(Vector3.UP, PI)
	for s in src.get_surface_count():
		var mat := src.surface_get_material(s)
		var mname := mat.resource_name if mat else ""
		var col: Color = PAINT.get(mname, Color(0.42, 0.45, 0.38))
		var a := src.surface_get_arrays(s)
		var pos: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var nrm: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var idx = a[Mesh.ARRAY_INDEX]
		var n: int = idx.size() if idx != null else pos.size()
		for t in range(0, n, 3):
			var ids := [idx[t], idx[t + 1], idx[t + 2]] if idx != null else [t, t + 1, t + 2]
			var p0: Vector3 = flip * ((pos[ids[0]] - Vector3(ctr.x, ab.position.y, ctr.z)) * SCALE)
			if mname == "props":
				var side := 0 if p0.x < 0.0 else 1
				for k in ids:
					props[side].append([flip * ((pos[k] - Vector3(ctr.x, ab.position.y, ctr.z)) * SCALE), flip * nrm[k]])
				continue
			for k in ids:
				var p: Vector3 = flip * ((pos[k] - Vector3(ctr.x, ab.position.y, ctr.z)) * SCALE)
				var nn: Vector3 = flip * nrm[k]
				# barriga mais clara (camuflagem de avião: escuro em cima, claro embaixo)
				var c := col
				if mname in ["fus", "fus.003", "tail"]:
					c = col.lerp(Color(0.62, 0.64, 0.6), clampf(-nn.y, 0.0, 1.0) * 0.8)
				body.set_color(c)
				body.set_normal(nn)
				body.add_vertex(p)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.6
	mat.metallic = 0.15
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED   # vidros e hélices são faces finas
	body.set_material(mat)
	var bm := MeshInstance3D.new()
	bm.name = "Body"
	bm.mesh = body.commit()
	root.add_child(bm)
	bm.owner = root
	for side in 2:
		var tris: Array = props[side]
		if tris.is_empty():
			continue
		var c := Vector3.ZERO
		for e in tris:
			c += e[0]
		c /= tris.size()
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for e in tris:
			st.set_color(PAINT["props"])
			st.set_normal(e[1])
			st.add_vertex((e[0] as Vector3) - c)
		st.set_material(mat)
		var pm := MeshInstance3D.new()
		pm.name = "PropL" if side == 0 else "PropR"
		pm.mesh = st.commit()
		pm.position = c
		root.add_child(pm)
		pm.owner = root
		print(pm.name, " em ", c)
	var ps := PackedScene.new()
	ps.pack(root)
	ResourceSaver.save(ps, OUT)
	print("avião: ", (ab.size * SCALE), " salvo")
	quit()
