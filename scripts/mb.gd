class_name MB
extends RefCounted

# Monta várias peças (caixas, cilindros, bolhas) numa malha só.
# Uma malha só = uma chamada de desenho, o que faz muita diferença em celular fraco.
# Cada peça escolhe a textura (camada do atlas) com tex() antes de ser adicionada.

var st := SurfaceTool.new()
var count := 0
var uvs := 0.35
var layer := 15
var sway := 0.0


func _init() -> void:
	st.begin(Mesh.PRIMITIVE_TRIANGLES)


func tex(l: int, scale := 0.35, sw := 0.0) -> MB:
	layer = l
	uvs = scale
	sway = sw
	return self


func _uv(p: Vector3, n: Vector3) -> Vector2:
	var a := n.abs()
	if a.y >= a.x and a.y >= a.z:
		return Vector2(p.x, p.z) * uvs
	if a.x >= a.z:
		return Vector2(p.z, -p.y) * uvs
	return Vector2(p.x, -p.y) * uvs


func _v(p: Vector3, n: Vector3, c: Color, uv: Vector2) -> void:
	st.set_color(c)
	st.set_normal(n)
	st.set_uv(uv)
	st.set_uv2(Vector2(layer, sway))
	st.add_vertex(p)


# Triângulo virado para "hint". Sem normais = facetado. Sem uv = projeção plana.
func tri(a: Vector3, b: Vector3, c: Vector3, col: Color, hint: Vector3, na := Vector3.ZERO, nb := Vector3.ZERO, nc := Vector3.ZERO, ua = null, ub = null, uc = null) -> void:
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
		var tu = ub
		ub = uc
		uc = tu
		fn = -fn
	var n := -fn.normalized()
	if na == Vector3.ZERO:
		na = n
		nb = n
		nc = n
	if ua == null:
		ua = _uv(a, n)
		ub = _uv(b, n)
		uc = _uv(c, n)
	_v(a, na, col, ua)
	_v(b, nb, col, ub)
	_v(c, nc, col, uc)
	count += 3


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, hint: Vector3) -> void:
	tri(a, b, c, col, hint)
	tri(a, c, d, col, hint)


# Caixa. A textura segue os eixos da própria caixa (telha acompanha o telhado).
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
			cc = col.darkened(0.2)
		var wn := (xf.basis * nrm).normalized()
		var wu := (xf.basis * u).normalized()
		var wv := (xf.basis * v).normalized()
		var w: Array = []
		var uv: Array = []
		for q: Vector3 in p:
			var wp: Vector3 = xf * q
			w.append(wp)
			uv.append(Vector2(wp.dot(wu), -wp.dot(wv)) * uvs)
		tri(w[0], w[1], w[2], cc, wn, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, uv[0], uv[1], uv[2])
		tri(w[0], w[2], w[3], cc, wn, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, uv[0], uv[2], uv[3])


func boxp(pos: Vector3, size: Vector3, col: Color, rot_y := 0.0) -> void:
	box(Transform3D(Basis(Vector3.UP, rot_y), pos), size, col)


# Cilindro (ou cone, se rt = 0) em pé, com a base na origem do xf.
func cyl(xf: Transform3D, rb: float, rt: float, h: float, seg: int, col: Color, caps := true, smooth := true, top_col = null, jag := 0.0, rng: RandomNumberGenerator = null) -> void:
	var tc: Color = col if top_col == null else top_col
	var circ := TAU * (rb + rt) * 0.5
	var rings := []
	for i in seg + 1:
		var a := TAU * i / seg
		var k := 1.0
		if jag > 0.0 and rng and i < seg:
			k = 1.0 + rng.randf_range(-jag, jag)
		rings.append([a, k])
	rings[seg][1] = rings[0][1]
	for i in seg:
		var a0: float = rings[i][0]
		var a1: float = rings[i + 1][0]
		var k0: float = rings[i][1]
		var k1: float = rings[i + 1][1]
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var b0 := xf * (d0 * rb * k0)
		var b1 := xf * (d1 * rb * k1)
		var t0 := xf * (d0 * rt + Vector3(0, h, 0))
		var t1 := xf * (d1 * rt + Vector3(0, h, 0))
		var slope := (rb - rt) / maxf(h, 0.001)
		var n0 := (xf.basis * (d0 + Vector3(0, slope, 0))).normalized()
		var n1 := (xf.basis * (d1 + Vector3(0, slope, 0))).normalized()
		var hint := (n0 + n1).normalized()
		var u0 := float(i) / seg * circ * uvs
		var u1 := float(i + 1) / seg * circ * uvs
		var vb := 0.0
		var vt := -h * uvs
		var cc := col.lerp(tc, 0.5)
		if smooth:
			tri(b0, b1, t1, cc, hint, n0, n1, n1, Vector2(u0, vb), Vector2(u1, vb), Vector2(u1, vt))
			if rt > 0.0001:
				tri(b0, t1, t0, cc, hint, n0, n1, n0, Vector2(u0, vb), Vector2(u1, vt), Vector2(u0, vt))
		else:
			tri(b0, b1, t1, cc, hint, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector2(u0, vb), Vector2(u1, vb), Vector2(u1, vt))
			if rt > 0.0001:
				tri(b0, t1, t0, cc, hint, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector2(u0, vb), Vector2(u1, vt), Vector2(u0, vt))
		if caps:
			var up := (xf.basis * Vector3.UP).normalized()
			if rt > 0.0001:
				tri(xf * Vector3(0, h, 0), t0, t1, tc, up)
			tri(xf.origin, b0, b1, col.darkened(0.25), -up)


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
	var bi := xf.basis.inverse().transposed()
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
