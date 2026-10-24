class_name U
extends RefCounted

# camadas do atlas de texturas (textures/atlas2d.png, gerado por tools/gen_assets.py)
const GRASS := 0
const DIRT := 1
const ROCK := 2
const SAND := 3
const PLASTER := 4
const BRICK := 5
const ROOF := 6
const WOOD := 7
const METAL := 8
const CONCRETE := 9
const ASPHALT := 10
const BARK := 11
const PINE := 12
const LEAVES := 13
const FABRIC := 14
const PLAIN := 15

static var _mats := {}
static var _boxes := {}
static var _wmat: ShaderMaterial
static var _tmat: ShaderMaterial
static var _atlas: Texture


static func mat(c: Color, unshaded := false) -> StandardMaterial3D:
	var key := "%s_%s" % [c.to_html(), unshaded]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.95
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mats[key] = m
	return m


static func box_mesh(size: Vector3) -> BoxMesh:
	var key := "%.3f_%.3f_%.3f" % [size.x, size.y, size.z]
	if _boxes.has(key):
		return _boxes[key]
	var bm := BoxMesh.new()
	bm.size = size
	_boxes[key] = bm
	return bm


static func box(parent: Node, size: Vector3, pos: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = box_mesh(size)
	mi.material_override = mat(c)
	mi.position = pos
	parent.add_child(mi)
	return mi


static func mesh(parent: Node, m: Mesh, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = wmat()
	mi.position = pos
	parent.add_child(mi)
	return mi


static func atlas() -> Texture:
	if _atlas == null:
		_atlas = load("res://textures/atlas2d.png")
	return _atlas


# Corta uma malha grande (espalhada pelo mapa) em pedaços de "cell" metros pelo centro de cada
# triângulo: cada pedaço some sozinho pela distância e pelo campo de visão (antes a malha do
# tamanho do mapa era desenhada inteira de qualquer lugar perto do meio).
static func split_mesh(m: ArrayMesh, cell: float) -> Array:
	var out := []
	if m == null:
		return out
	for si in m.get_surface_count():
		var arr := m.surface_get_arrays(si)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(vs.size()))
		var buckets := {}
		for t in range(0, idx.size(), 3):
			var cpos := (vs[idx[t]] + vs[idx[t + 1]] + vs[idx[t + 2]]) / 3.0
			var key := Vector2i(floori(cpos.x / cell), floori(cpos.z / cell))
			if not buckets.has(key):
				buckets[key] = PackedInt32Array()
			var b: PackedInt32Array = buckets[key]
			b.append(idx[t])
			b.append(idx[t + 1])
			b.append(idx[t + 2])
			buckets[key] = b
		for key in buckets:
			var tri: PackedInt32Array = buckets[key]
			var remap := {}
			var na := []
			na.resize(Mesh.ARRAY_MAX)
			var order := PackedInt32Array()
			var nidx := PackedInt32Array()
			nidx.resize(tri.size())
			for k in tri.size():
				var o: int = tri[k]
				if not remap.has(o):
					remap[o] = order.size()
					order.append(o)
				nidx[k] = remap[o]
			for a in Mesh.ARRAY_MAX:
				if a == Mesh.ARRAY_INDEX or arr[a] == null or arr[a].size() != vs.size():
					continue
				var src = arr[a]
				var dst = src.duplicate()
				dst.resize(order.size())
				for k in order.size():
					dst[k] = src[order[k]]
				na[a] = dst
			na[Mesh.ARRAY_INDEX] = nidx
			var nm := ArrayMesh.new()
			nm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, na)
			out.append(nm)
	return out


# Material único usado por quase tudo: textura do atlas + cor do vértice.
static func wmat() -> ShaderMaterial:
	if _wmat:
		return _wmat
	_wmat = ShaderMaterial.new()
	_wmat.shader = load("res://shaders/world.gdshader")
	_wmat.set_shader_parameter("tex", atlas())
	return _wmat


static func tmat() -> ShaderMaterial:
	if _tmat:
		return _tmat
	_tmat = ShaderMaterial.new()
	_tmat.shader = load("res://shaders/terrain.gdshader")
	_tmat.set_shader_parameter("tex", atlas())
	return _tmat


# compatibilidade com código antigo
static func vmat() -> ShaderMaterial:
	return wmat()
