extends SceneTree
# Arte da tela de carregamento: monta o mapa, põe soldados armados na subida de uma cidade
# alta ao pôr do sol e tira a foto. Depois tools/keyart_post.py faz o tratamento de cor.
# Uso: xvfb-run godot --rendering-driver opengl3 --resolution 1600x900 --script tools/render_keyart.gd -- --out=arquivo.png

var world: World
var cam: Camera3D
var sols := []
var f := 0
var out := "keyart.png"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.get_slice("=", 1)
	world = World.new()
	root.add_child(world)
	world.build(false, 2)
	world.show_grass(false)
	# pôr do sol
	var sun: DirectionalLight3D = world.get_node("Sun")
	sun.rotation_degrees = Vector3(-14, -150, 0)
	sun.light_color = Color(1.0, 0.68, 0.4)
	sun.light_energy = 1.35
	var env: Environment = (world.get_node("Env") as WorldEnvironment).environment
	var sm: ProceduralSkyMaterial = env.sky.sky_material
	sm.sky_top_color = Color(0.22, 0.28, 0.55)
	sm.sky_horizon_color = Color(1.0, 0.6, 0.35)
	sm.ground_horizon_color = Color(0.8, 0.55, 0.38)
	env.ambient_light_color = Color(0.85, 0.65, 0.55)
	env.fog_light_color = Color(1.0, 0.68, 0.45)
	env.fog_density = 0.006
	# encosta de Vila Ferrugem, de baixo olhando morro acima pra cidade
	var c := Vector2(-250, -245)
	var dir := Vector2(1, 0.75).normalized()
	var side := Vector2(-dir.y, dir.x)
	var up := -dir
	var yaw_up := atan2(-up.x, -up.y)
	var cpos := c + dir * 73.5
	var p0 := c + dir * 69.0
	cam = Camera3D.new()
	cam.fov = 55
	root.add_child(cam)
	var cp3 := Vector3(cpos.x, world.height(cpos.x, cpos.y) + 0.8, cpos.y)
	var look := c + dir * 59.0
	var lk3 := Vector3(look.x, world.height(look.x, look.y) + 0.4, look.y)
	cam.transform = Transform3D(Basis.looking_at(lk3 - cp3, Vector3.UP), cp3)
	cam.current = true
	print("cam h=", cam.position.y, " look h=", world.height(look.x, look.y), " town h=", world.height(c.x, c.y))
	print("p0 h=", world.height(p0.x, p0.y))
	# soldados: um correndo perto, um agachado mirando, um subindo lá atrás
	_soldier(p0 - side * 0.9, yaw_up + PI - 0.95, "Running", 0.0, 0.31, 0)
	_soldier(p0 + up * 2.5 + side * 2.3, yaw_up + PI * 0.5 + 0.2, "Idle", 1.0, 0.0, 1)
	_soldier(p0 + up * 7.0 - side * 3.6, yaw_up + PI - 0.6, "Running", 0.0, 0.62, 2)


func _soldier(p: Vector2, yaw: float, anim: String, crouch: float, t0: float, k: int) -> void:
	var s := Soldier.new()
	root.add_child(s)
	s.setup(Player.SKINS[[1, 3, 0][k]], Player.SHIRTS[[0, 2, 1][k]], Player.PANTS[[1, 2, 3][k]], Player.BOOTS[0], Player.HAIRS[[0, 3, 1][k]])
	s.position = Vector3(p.x, world.height(p.x, p.y), p.y)
	s.rotation.y = yaw
	s.play(anim, 0.0)
	var aim := Node3D.new()
	aim.position = Vector3(0, 1.36 - crouch * 0.42, 0)
	aim.rotation.x = 0.05 if crouch > 0.0 else -0.1
	s.add_child(aim)
	var gun := Weapons.build_model(["ak47", "m4a1", "scar"][k], ["scope2"] if k == 1 else [])
	gun.position = Vector3(0.13, -0.02, -0.36)
	aim.add_child(gun)
	sols.append([s, aim, gun, crouch, t0])


func _process(d: float) -> bool:
	f += 1
	for e in sols:
		var s: Soldier = e[0]
		var aim: Node3D = e[1]
		var gun: Node3D = e[2]
		var gp := gun.position
		var grip := aim.global_transform * (gp + Vector3(0, -0.05, 0.03))
		var fore := aim.global_transform * (gp + Vector3(-0.02, -0.03, -0.26))
		s.tick(float(e[4]) if f == 1 else 0.0, false, aim.rotation.x, float(e[3]), [fore, grip])
	if f == 11:
		print("cam ", cam.global_position, " fwd ", -cam.global_transform.basis.z)
		for e in sols:
			print("sol ", (e[0] as Node3D).global_position, " na tela=", cam.is_position_in_frustum((e[0] as Node3D).global_position + Vector3(0, 1, 0)))
	if f == 12:
		root.get_viewport().get_texture().get_image().save_png(out)
		return true
	return false
