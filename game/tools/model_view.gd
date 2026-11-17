extends Node3D
## Art check: shows one model on a ground plane in daylight.
##   godot-render --path . res://tools/model_view.tscn -- --shot=out.png --model=res://... [--yaw=35] [--pitch=12] [--dist=9] [--h=1.4] [--dump]
##   ... --rig=0,-30,90,60 instead of --model shows the excavator rig posed (swing, boom, stick, bucket in degrees).

func _ready() -> void:
	var model := ""
	var yaw := 35.0
	var pitch := 12.0
	var dist := 9.0
	var h := 1.4
	var dump := false
	var rig := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--model="):
			model = arg.trim_prefix("--model=")
		elif arg.begins_with("--yaw="):
			yaw = float(arg.trim_prefix("--yaw="))
		elif arg.begins_with("--pitch="):
			pitch = float(arg.trim_prefix("--pitch="))
		elif arg.begins_with("--dist="):
			dist = float(arg.trim_prefix("--dist="))
		elif arg.begins_with("--h="):
			h = float(arg.trim_prefix("--h="))
		elif arg == "--dump":
			dump = true
		elif arg.begins_with("--rig="):
			rig = arg.trim_prefix("--rig=")
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#3f76c4")
	sky_mat.sky_horizon_color = Color("#bcd3ea")
	sky_mat.ground_horizon_color = Color("#8d8a84")
	sky_mat.ground_bottom_color = Color("#55524e")
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -38, 0)
	sun.light_energy = 2.2
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("#6b6964")
	gm.roughness = 0.95
	ground.material_override = gm
	add_child(ground)
	if rig != "":
		# --rig=swing_deg,boom,arm,bucket shows the excavator rig in that pose.
		var parts := rig.split(",")
		var digger := DiggerRig.new()
		add_child(digger)
		digger.set_pose(deg_to_rad(parts[0].to_float()), parts[1].to_float(), parts[2].to_float(), parts[3].to_float())
	elif model != "":
		var packed := load(model) as PackedScene
		if packed:
			var node := packed.instantiate()
			add_child(node)
			if dump:
				_dump(node, 0)
	var cam := Camera3D.new()
	cam.fov = 45.0
	var dir := Vector3(sin(deg_to_rad(yaw)) * cos(deg_to_rad(pitch)), sin(deg_to_rad(pitch)), cos(deg_to_rad(yaw)) * cos(deg_to_rad(pitch)))
	cam.position = Vector3(0, h, 0) + dir * dist
	add_child(cam)
	cam.look_at(Vector3(0, h, 0))
	cam.current = true


func _dump(n: Node, depth: int) -> void:
	if depth > 3 or n is MeshInstance3D:
		return
	var n3 := n as Node3D
	print("NODE ", "  ".repeat(depth), n.name, " pos=", n3.position.snapped(Vector3.ONE * 0.01) if n3 else "", " kids=", n.get_child_count())
	for c in n.get_children():
		_dump(c, depth + 1)
