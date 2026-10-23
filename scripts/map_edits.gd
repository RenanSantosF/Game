class_name MapEdits
extends RefCounted

# Ajustes feitos à mão no cenário (pelo editor dentro do jogo).
# O mapa é gerado por código; estes ajustes são aplicados por cima, objeto por objeto.
#   "e": chave do objeto -> {p: posição [x,y,z], r: giro extra, s: escala, d: apagado}
#   "a": objetos adicionados -> {k: tipo, p, r, s, n: semente, x: argumentos extras}
# A chave é tipo@posição original (em meio metro), então continua valendo enquanto o objeto
# for gerado no mesmo lugar.
# Arquivos: res://data/map_edits.json (vai junto no jogo) e user://map_edits.json (do aparelho).
# Quando o jogo atualiza com um map_edits.json diferente, as alterações do aparelho são zeradas.

const SHIPPED := "res://data/map_edits.json"
const LOCAL := "user://map_edits.json"


static func empty() -> Dictionary:
	return {"v": 1, "e": {}, "a": []}


# local = pode usar o arquivo do aparelho (treino e editor). Partida em rede usa só o que vai no jogo.
static func load_data(local: bool) -> Dictionary:
	if local and FileAccess.file_exists(LOCAL):
		var d := _read(LOCAL)
		# o jogo veio com um mapa novo (as alterações já foram pra dentro dele): zera as do aparelho
		if str(d.get("base", "")) != shipped_hash():
			clear_local()
		elif not d.is_empty():
			return d
	var s := _read(SHIPPED)
	return s if not s.is_empty() else empty()


static func has_local() -> bool:
	return FileAccess.file_exists(LOCAL)


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var txt := FileAccess.get_file_as_string(path)
	return parse(txt)


static func parse(txt: String) -> Dictionary:
	var d = JSON.parse_string(txt)
	if typeof(d) != TYPE_DICTIONARY:
		return {}
	if not d.has("e") or typeof(d["e"]) != TYPE_DICTIONARY:
		d["e"] = {}
	if not d.has("a") or typeof(d["a"]) != TYPE_ARRAY:
		d["a"] = []
	return d


# marca de qual mapa do jogo as alterações do aparelho partiram
static func shipped_hash() -> String:
	if not FileAccess.file_exists(SHIPPED):
		return "-"
	return FileAccess.get_file_as_string(SHIPPED).md5_text()


static func save_local(d: Dictionary) -> void:
	d["base"] = shipped_hash()
	var f := FileAccess.open(LOCAL, FileAccess.WRITE)
	if f:
		f.store_string(to_text(d))


static func clear_local() -> void:
	if FileAccess.file_exists(LOCAL):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LOCAL))


static func to_text(d: Dictionary) -> String:
	return JSON.stringify(d, "", true, false)


static func count(d: Dictionary) -> int:
	return (d["e"] as Dictionary).size() + (d["a"] as Array).size()


static func key(kind: String, pos: Vector3) -> String:
	return "%s@%d,%d" % [kind, roundi(pos.x * 2.0), roundi(pos.z * 2.0)]


static func v3(a) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


static func arr(v: Vector3) -> Array:
	return [snappedf(v.x, 0.01), snappedf(v.y, 0.01), snappedf(v.z, 0.01)]


# árvore, pedra, moita, tronco: transformação com o ajuste aplicado
static func nat_apply(xf: Transform3D, e: Dictionary) -> Transform3D:
	if e.is_empty():
		return xf
	var o := v3(e["p"]) if e.has("p") else xf.origin
	var s := float(e.get("s", 1.0))
	var tilt := Basis.from_euler(Vector3(float(e.get("tx", 0.0)), float(e.get("r", 0.0)), float(e.get("tz", 0.0))))
	return Transform3D(tilt * xf.basis.scaled(Vector3.ONE * s), o)
