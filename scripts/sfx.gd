class_name Sfx
extends Node

# Toca os sons do jogo (arquivos em sounds/, gerados por tools/gen_assets.py).
# Sons no mundo são 3D (dá pra saber de onde vem); os do próprio jogador são 2D.

const NAMES := ["shot_pistol", "shot_deagle", "shot_smg", "shot_rifle", "shot_ak", "shot_shotgun", "shot_sniper",
	"shot_silenced", "step_grass0", "step_grass1", "step_grass2", "step_hard0", "step_hard1", "step_hard2", "jump",
	"land", "vault", "switch", "reload_out", "reload_in", "bolt", "pickup", "equip", "heal", "heal_done", "hit",
	"headshot", "kill", "punch_swing", "punch_hit", "chute", "zone", "click", "empty", "impact", "ricochet", "hurt"]
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
	match Weapons.get_w(wid)["type"]:
		"pistol":
			return "shot_deagle" if wid == "deagle" else "shot_pistol"
		"smg":
			return "shot_smg"
		"rifle", "scar":
			return "shot_rifle"
		"ak":
			return "shot_ak"
		"shotgun":
			return "shot_shotgun"
		"bolt", "sniper":
			return "shot_sniper"
	return "punch_swing"
