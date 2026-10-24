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
	"shadows": false,    # sombras (desligadas: mais leve, sem serrilhado e sem chão "estourado")
	"tex_detail": false, # textura do chão com mais detalhe
	"btn_alpha": 0.85,   # transparência dos botões (0.3 bem transparente .. 1 opaco)
	"view": 1,           # distância de visão: 0 perto, 1 média, 2 longe
	"grass": true,       # tufos de grama
	"music": true,       # música do lobby
	"music_vol": 0.7,    # volume da música (0 a 1)
	"ver": 3,            # versão das configurações (migra padrões novos)
	"calib": 0,          # 0 = ainda não ajustou pro aparelho, 1 = palpite pelo hardware, 2 = conferido jogando
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
	# versão 3: sem sombra e sem textura detalhada por padrão (mais leve e o clima fica melhor)
	if int(v.get("ver", 2)) < 3:
		v["shadows"] = false
		v["tex_detail"] = false
		v["ver"] = 3
		save()


# Nível do aparelho (0 fraco, 1 médio, 2 forte) pela placa de vídeo e pela memória.
static func device_tier() -> int:
	var gpu := RenderingServer.get_video_adapter_name().to_lower()
	var tier := 1
	var num := 0
	var rx := RegEx.new()
	rx.compile("(\\d{3,4})")
	var m := rx.search(gpu)
	if m:
		num = int(m.get_string(1))
	if "adreno" in gpu:
		tier = 2 if num >= 640 else (1 if num >= 616 else 0)
	elif "mali" in gpu:
		if "g31" in gpu or "g51" in gpu or "g52" in gpu or "g71" in gpu or "t8" in gpu or "t7" in gpu or "400" in gpu or "450" in gpu:
			tier = 0
		elif "g7" in gpu and ("g76" not in gpu and "g72" not in gpu) or "g610" in gpu or "g710" in gpu or "g715" in gpu or "g720" in gpu:
			tier = 2
		else:
			tier = 1
	elif "powervr" in gpu or "sgx" in gpu or "ge8" in gpu:
		tier = 0
	elif "immortalis" in gpu or "xclipse" in gpu:
		tier = 2
	var ram := float(OS.get_memory_info().get("physical", 0)) / 1073741824.0
	if ram > 0.1:
		if ram < 3.5:
			tier = mini(tier, 0)
		elif ram < 5.5:
			tier = mini(tier, 1)
	if OS.get_processor_count() <= 4:
		tier = mini(tier, 0)
	return tier


# primeira vez no aparelho: escolhe a qualidade pelo hardware (uma vez só; depois o jogador muda se quiser)
static func first_run_tier() -> void:
	load_cfg()
	if int(v.get("calib", 0)) != 0 or OS.get_name() != "Android":
		return
	apply_tier(device_tier())
	v["calib"] = 1
	save()


static func apply_tier(tier: int) -> void:
	v["quality"] = clampi(tier, 0, 2)
	v["grass"] = tier >= 1
	v["view"] = 0 if tier == 0 else 1
	v["fps"] = 30 if tier == 0 else 60


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
