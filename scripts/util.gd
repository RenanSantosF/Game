class_name U
extends RefCounted

# camadas do atlas de texturas (textures/atlas.png, gerado por tools/gen_assets.py)
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
		_atlas = load("res://textures/atlas.png")
	return _atlas


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
