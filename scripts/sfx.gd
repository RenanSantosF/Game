class_name Sfx
extends Node

# Toca os sons do jogo (arquivos em sounds/: gravações CC0 tratadas por tools/prepare_sounds.py
# e sons sintetizados por tools/synth_sounds.py; créditos em sounds/CREDITOS.txt).
# Sons no mundo são 3D (dá pra saber de onde vem); os do próprio jogador são 2D.

const NAMES := ["shot_pistol", "shot_deagle", "shot_smg", "shot_ump", "shot_rifle", "shot_scar", "shot_ak", "shot_shotgun",
	"shot_m1014", "shot_bolt", "shot_sniper", "shot_silenced",
	"step_grass0", "step_grass1", "step_grass2", "step_grass3", "step_grass4", "step_grass5",
	"step_hard0", "step_hard1", "step_hard2", "step_hard3", "step_hard4", "step_hard5",
	"step_gravel0", "step_gravel1", "step_gravel2", "step_gravel3", "step_gravel4", "step_gravel5", "jump",
	"land", "vault", "switch", "reload_out", "reload_in", "bolt", "pickup", "equip", "heal", "heal_done", "hit",
	"headshot", "kill", "punch_swing", "punch_hit", "chute", "zone", "click", "empty", "impact", "ricochet", "hurt",
	"wind_fall", "wind_chute", "plane", "pain0", "pain1", "pain2", "door"]
const MAX_3D := 20

var streams := {}
var volume := 1.0
var listener_pos := Vector3.ZERO
var _active3d := 0


func _ready() -> void:
	for n in NAMES:
		var s = load("res://sounds/%s.wav" % n)
		if s:
			streams[n] = s


func db(extra: float) -> float:
	return linear_to_db(maxf(volume, 0.001)) + extra


func play(n: String, vol := 0.0, pitch := 1.0) -> void:
	if not streams.has(n) or volume <= 0.0:
		return
	var ap := AudioStreamPlayer.new()
	ap.stream = streams[n]
	ap.volume_db = db(vol)
	ap.pitch_scale = pitch * randf_range(0.96, 1.04)
	add_child(ap)
	ap.play()
	ap.finished.connect(ap.queue_free)


func play_at(n: String, pos: Vector3, vol := 0.0, max_d := 60.0, pitch := 1.0, unit := 6.0) -> void:
	if not streams.has(n) or volume <= 0.0:
		return
	if listener_pos.distance_to(pos) > max_d or _active3d >= MAX_3D:
		return
	var ap := AudioStreamPlayer3D.new()
	ap.stream = streams[n]
	ap.volume_db = db(vol)
	ap.pitch_scale = pitch * randf_range(0.95, 1.05)
	ap.unit_size = unit
	ap.max_distance = max_d
	ap.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	add_child(ap)
	ap.global_position = pos
	ap.play()
	_active3d += 1
	ap.finished.connect(func():
		_active3d -= 1
		ap.queue_free())


func shot_name(wid: String, silenced: bool) -> String:
	if silenced:
		return "shot_silenced"
	match wid:
		"glock":
			return "shot_pistol"
		"deagle":
			return "shot_deagle"
		"mp5":
			return "shot_smg"
		"ump45":
			return "shot_ump"
		"m4a1":
			return "shot_rifle"
		"scar":
			return "shot_scar"
		"ak47":
			return "shot_ak"
		"r870":
			return "shot_shotgun"
		"m1014":
			return "shot_m1014"
		"kar98":
			return "shot_bolt"
		"awm":
			return "shot_sniper"
	return "punch_swing"
