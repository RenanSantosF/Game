class_name MB
extends RefCounted

# Monta várias peças (caixas, cilindros, bolhas) numa malha só.
# Uma malha só = uma chamada de desenho, o que faz muita diferença em celular fraco.

var st := SurfaceTool.new()
var count := 0
var uvs := 0.35


func _init() -> void:
	st.begin(Mesh.PRIMITIVE_TRIANGLES)


func _uv(p: Vector3, n: Vector3) -> Vector2:
	var a := n.abs()
	if a.y >= a.x and a.y >= a.z:
		return Vector2(p.x, p.z) * uvs
	if a.x >= a.z:
		return Vector2(p.z, p.y) * uvs
	return Vector2(p.x, p.y) * uvs


func _v(p: Vector3, n: Vector3, c: Color) -> void:
	st.set_color(c)
	st.set_normal(n)
	st.set_uv(_uv(p, n))
	st.add_vertex(p)


# Triângulo virado para "hint". Se não passar normais, fica facetado.
func tri(a: Vector3, b: Vector3, c: Vector3, col: Color, hint: Vector3, na := Vector3.ZERO, nb := Vector3.ZERO, nc := Vector3.ZERO) -> void:
	var fn := (b - a).cross(c - a)
	if fn.length_squared() < 1e-12:
		return
	# no Godot a frente é no sentido horário, cujo produto vetorial aponta pra trás
	if fn.dot(hint) > 0.0:
		var t := b
		b = c
		c = t
		var tn := nb
		nb = nc
		nc = tn
		fn = -fn
	var n := -fn.normalized()
	if na == Vector3.ZERO:
		na = n
		nb = n
		nc = n
	_v(a, na, col)
	_v(b, nb, col)
	_v(c, nc, col)
	count += 3


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, hint: Vector3) -> void:
	tri(a, b, c, col, hint)
	tri(a, c, d, col, hint)


func box(xf: Transform3D, size: Vector3, col: Color, shade := true) -> void:
	var h := size / 2.0
	var dirs := [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
	for nrm: Vector3 in dirs:
		var v := Vector3.UP if absf(nrm.y) < 0.5 else (Vector3.FORWARD if nrm.y > 0.0 else Vector3.BACK)
		var u := v.cross(nrm)
		var hn := absf(nrm.dot(h))
		var hu := absf(u.dot(h))
		var hv := absf(v.dot(h))
		var c0 := nrm * hn
		var p := [c0 - u * hu + v * hv, c0 + u * hu + v * hv, c0 + u * hu - v * hv, c0 - u * hu - v * hv]
		var cc := col
		if shade and nrm.y < -0.5:
			cc = col.darkened(0.25)
		var wn := (xf.basis * nrm).normalized()
		quad(xf * p[0], xf * p[1], xf * p[2], xf * p[3], cc, wn)


func boxp(pos: Vector3, size: Vector3, col: Color, rot_y := 0.0) -> void:
	box(Transform3D(Basis(Vector3.UP, rot_y), pos), size, col)


# Cilindro (ou cone, se rt = 0) em pé, com a base na origem do xf.
func cyl(xf: Transform3D, rb: float, rt: float, h: float, seg: int, col: Color, caps := true, smooth := true, top_col = null) -> void:
	var tc: Color = col if top_col == null else top_col
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var b0 := xf * (d0 * rb)
		var b1 := xf * (d1 * rb)
		var t0 := xf * (d0 * rt + Vector3(0, h, 0))
		var t1 := xf * (d1 * rt + Vector3(0, h, 0))
		var slope := (rb - rt) / maxf(h, 0.001)
		var n0 := (xf.basis * (d0 + Vector3(0, slope, 0))).normalized()
		var n1 := (xf.basis * (d1 + Vector3(0, slope, 0))).normalized()
		var hint := (n0 + n1).normalized()
		if smooth:
			_tri_s(b0, b1, t1, n0, n1, n1, col, tc, hint)
			if rt > 0.0001:
				_tri_s(b0, t1, t0, n0, n1, n0, col, tc, hint)
		else:
			tri(b0, b1, t1, col, hint)
			if rt > 0.0001:
				tri(b0, t1, t0, col, hint)
		if caps:
			var up := (xf.basis * Vector3.UP).normalized()
			if rt > 0.0001:
				tri(xf * Vector3(0, h, 0), t0, t1, tc, up)
			tri(xf.origin, b0, b1, col.darkened(0.2), -up)


func _tri_s(a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, ca: Color, ct: Color, hint: Vector3) -> void:
	# cor diferente embaixo e em cima (ca pros pontos de baixo); simplificado: usa a média
	tri(a, b, c, ca.lerp(ct, 0.5), hint, na, nb, nc)


# Esfera achatada/esticada, opcionalmente deformada (pedras, copas, moitas).
func blob(xf: Transform3D, seg: int, rings: int, col: Color, rng: RandomNumberGenerator = null, distort := 0.0, smooth := true, bottom_dark := 0.0) -> void:
	var pts := []
	for r in rings + 1:
		var row := []
		var th := PI * r / rings
		for s in seg:
			var ph := TAU * s / seg
			var d := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
			var k := 1.0
			if rng and distort > 0.0 and r > 0 and r < rings:
				k += rng.randf_range(-distort, distort)
			row.append(d * k)
		pts.append(row)
	for r in rings:
		for s in seg:
			var s1 := (s + 1) % seg
			var p00: Vector3 = pts[r][s]
			var p01: Vector3 = pts[r][s1]
			var p10: Vector3 = pts[r + 1][s]
			var p11: Vector3 = pts[r + 1][s1]
			var mid := (p00 + p01 + p10 + p11) / 4.0
			var cc := col
			if bottom_dark > 0.0:
				cc = col.darkened(clampf(-mid.y, 0.0, 1.0) * bottom_dark)
			var hint := (xf.basis * mid).normalized()
			if smooth:
				var bi := xf.basis.inverse().transposed()
				tri(xf * p00, xf * p01, xf * p11, cc, hint, (bi * p00).normalized(), (bi * p01).normalized(), (bi * p11).normalized())
				tri(xf * p00, xf * p11, xf * p10, cc, hint, (bi * p00).normalized(), (bi * p11).normalized(), (bi * p10).normalized())
			else:
				tri(xf * p00, xf * p01, xf * p11, cc, hint)
				tri(xf * p00, xf * p11, xf * p10, cc, hint)


func commit() -> ArrayMesh:
	if count == 0:
		return null
	st.index()
	return st.commit()


static func xf_at(pos: Vector3, scale := Vector3.ONE, rot_y := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, rot_y) * Basis.from_scale(scale), pos)
