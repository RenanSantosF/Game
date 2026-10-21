class_name U
extends RefCounted

static var _mats := {}
static var _boxes := {}


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
