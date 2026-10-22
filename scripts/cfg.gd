class_name Cfg
extends RefCounted

# Configurações do jogador (salvas no aparelho).
const PATH := "user://config.cfg"
const AIM_NAMES := ["CONTROLE TOTAL", "GRUDA SEM MIRA", "GRUDA SEMPRE"]
const QUALITY_NAMES := ["BAIXA", "MÉDIA", "ALTA"]

static var v := {
	"nick": "",
	"ip": "",
	"quality": 1,
	"fps": 60,
	"show_fps": true,
	"sens": 1.0,         # multiplicador da sensibilidade geral
	"sens_ads": 1.0,     # multiplicador quando está mirando
	"aim_assist": 2,     # 0 = controle total, 1 = gruda só sem mira, 2 = gruda sempre
	"volume": 0.9,
	"layout": {},        # botão -> [x (fração da tela), y (fração), escala]
	"invert": false,
	"blood": true,       # respingo de sangue no acerto
	"shadows": true,     # sombras
	"tex_detail": 1,     # 0 = textura simples, 1 = detalhada
	"grass": true,       # tufos de grama
	"ver": 2,            # versão das configurações (migra padrões novos)
}
static var _loaded := false


static func load_cfg() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for k in v:
		if cfg.has_section_key("jogo", k):
			v[k] = cfg.get_value("jogo", k)
	# versão nova: mira grudando sempre e botões no lugar novo
	if not cfg.has_section_key("jogo", "ver") or int(cfg.get_value("jogo", "ver")) < 2:
		v["aim_assist"] = 2
		v["layout"] = {}
		v["ver"] = 2
		save()


static func save() -> void:
	var cfg := ConfigFile.new()
	for k in v:
		cfg.set_value("jogo", k, v[k])
	cfg.save(PATH)


static func get_v(k: String):
	load_cfg()
	return v[k]


static func set_v(k: String, val) -> void:
	load_cfg()
	v[k] = val
	save()
