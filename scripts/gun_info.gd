class_name GunInfo
extends RefCounted

# Gerado por tools/prepare_guns.gd (não editar à mão).
# muzzle = ponta do cano, rail = altura do trilho (onde vai a mira), len = do cabo até a ponta
const INFO := {
	"glock": {"muzzle": Vector3(0.0000, 0.0599, -0.1545), "rail": 0.0735, "len": 0.1545},
	"deagle": {"muzzle": Vector3(0.0000, 0.1249, -0.2200), "rail": 0.1443, "len": 0.2200},
	"mp5": {"muzzle": Vector3(0.0000, 0.0954, -0.3782), "rail": 0.1520, "len": 0.3782},
	"ump45": {"muzzle": Vector3(0.0000, 0.0785, -0.4444), "rail": 0.1247, "len": 0.4444},
	"m4a1": {"muzzle": Vector3(0.0000, 0.1041, -0.5865), "rail": 0.1163, "len": 0.5865},
	"scar": {"muzzle": Vector3(0.0000, 0.1217, -0.6085), "rail": 0.1393, "len": 0.6085},
	"ak47": {"muzzle": Vector3(0.0000, 0.0939, -0.6195), "rail": 0.1325, "len": 0.6195},
	"r870": {"muzzle": Vector3(0.0000, 0.0357, -0.7288), "rail": 0.0803, "len": 0.7288},
	"m1014": {"muzzle": Vector3(0.0000, 0.0372, -0.7447), "rail": 0.0656, "len": 0.7447},
	"kar98": {"muzzle": Vector3(0.0000, 0.0454, -0.8009), "rail": 0.1160, "len": 0.8009},
	"awm": {"muzzle": Vector3(0.0000, 0.0667, -0.8798), "rail": 0.1354, "len": 0.8798},
}
