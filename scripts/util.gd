class_name U
extends RefCounted

static var _mats := {}
static var _boxes := {}
static var _detail: Texture2D
static var _vmat: StandardMaterial3D


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
	mi.material_override = vmat()
	mi.position = pos
	parent.add_child(mi)
	return mi


# Textura de ruído em tons de cinza. Multiplica a cor dos vértices e tira a cara de "plástico".
static func detail_tex() -> Texture2D:
	if _detail:
		return _detail
	var n := FastNoiseLite.new()
	n.seed = 77
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX
	n.frequency = 0.06
	n.fractal_octaves = 4
	var src := n.get_seamless_image(128, 128, false, false, 0.1, true)
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	for y in 128:
		for x in 128:
			var v := 0.74 + src.get_pixel(x, y).r * 0.3
			img.set_pixel(x, y, Color(v, v, v))
	img.generate_mipmaps()
	_detail = ImageTexture.create_from_image(img)
	return _detail


# Material único usado por quase tudo: cor no vértice + textura de detalhe.
static func vmat() -> StandardMaterial3D:
	if _vmat:
		return _vmat
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.albedo_texture = detail_tex()
	m.roughness = 0.92
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_vmat = m
	return m
