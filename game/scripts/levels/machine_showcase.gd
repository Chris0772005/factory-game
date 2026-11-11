extends Node3D
## Studio shot of the automation machines for judging the art alone.
## `-- --cam=arm|close|grip`

func _ready() -> void:
	var cam_name := "arm"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cam="):
			cam_name = arg.trim_prefix("--cam=")
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#2b2a33")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8a90a8")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 35, 0)
	sun.light_energy = 1.5
	sun.light_color = Color("#fff0dc")
	sun.shadow_enabled = true
	add_child(sun)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-2.5, 1.6, 1.5)
	fill.light_energy = 1.2
	fill.light_color = Color("#9fc4e8")
	fill.omni_range = 7.0
	add_child(fill)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color("#6e6a66")
	floor_mat.roughness = 0.85
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(14, 14)
	floor_mesh.mesh = plane
	floor_mesh.material_override = floor_mat
	add_child(floor_mesh)
	var base := Node3D.new()
	add_child(base)
	var turret := Node3D.new()
	turret.position.y = ScrapLine.SHOULDER_HEIGHT
	turret.rotation.y = 0.5
	base.add_child(turret)
	var shoulder := Node3D.new()
	shoulder.rotation.x = -1.05
	turret.add_child(shoulder)
	var elbow := Node3D.new()
	elbow.position.z = ScrapLine.UPPER
	elbow.rotation.x = 1.45
	shoulder.add_child(elbow)
	var wrist := Node3D.new()
	wrist.position.z = ScrapLine.FORE
	elbow.add_child(wrist)
	var fingers: Array[Node3D] = []
	for i in 2:
		var f := Node3D.new()
		f.position = Vector3(0, 0.05 if i == 0 else -0.05, 0.06)
		f.rotation.x = -0.4 * (1.0 if i == 0 else -1.0)
		wrist.add_child(f)
		fingers.append(f)
	MachineArt.arm({base = base, turret = turret, shoulder = shoulder, elbow = elbow, wrist = wrist, fingers = fingers}, ScrapLine.UPPER, ScrapLine.FORE, ScrapLine.SHOULDER_HEIGHT)
	var belt := Node3D.new()
	var bx := Vector3(1.0, 0.18, 0.0).normalized()
	var bz := bx.cross(Vector3.UP).normalized()
	belt.transform = Transform3D(Basis(bx, bz.cross(bx), bz), Vector3(-3.2, 0.72, 1.4))
	add_child(belt)
	MachineArt.conveyor(belt, 2.4, ScrapLine.BELT_WIDTH)
	var kinds := [&"scrap_can", &"scrap_key", &"scrap_pipe", &"scrap_kettle", &"scrap_tooth", &"scrap_ring", &"scrap_trophy", &"scrap_candle", &"scrap_coin", &"scrap_bikebell"]
	for i in kinds.size():
		var info: Dictionary = FoundryRules.SCRAP[kinds[i]]
		StationKit.add(self, ScrapModels.mesh(kinds[i]), ScrapModels.material(info.color), Transform3D(Basis(Vector3.UP, 0.4), Vector3(3.0 + (i % 5) * 0.42, 0.16, 3.0 - (i / 5) * 0.45)))
	# AutoFoundry machines in a row.
	AutoArt.blower(self, Vector3(-1.0, 0, 6.0), Vector3(-1.0, 0, 4.9))
	AutoArt.mold_unit(self, Vector3(0.2, 0, 6.0), Vector3(0.2, 0, 7.0))
	AutoArt.rail(self, Vector3(1.2, 2.25, 6.0), Vector3(3.6, 0, 6.0), Vector3(1.2, 0, 5.2), true)
	var carriage := Node3D.new()
	carriage.position = Vector3(2.2, 2.25, 6.0)
	add_child(carriage)
	var hanger := Node3D.new()
	hanger.position.y = -AutoFoundry.LADLE_DROP
	carriage.add_child(hanger)
	var pot := Node3D.new()
	pot.position.y = 0.13
	pot.rotation.x = 0.5
	hanger.add_child(pot)
	var melt := MeshInstance3D.new()
	pot.add_child(melt)
	AutoArt.trolley(carriage, hanger, pot, melt, AutoFoundry.LADLE_DROP)
	var hands := FirstPersonHands.new()
	hands.position = Vector3(5.0, 1.0, 3.0)
	hands.set_process(false)
	add_child(hands)
	for i in hands.get_child_count():
		(hands.get_child(i) as Node3D).position = Vector3(-0.12 + i * 0.24, 0, 0)
	var cam := Camera3D.new()
	cam.fov = 45
	add_child(cam)
	cam.add_child(OutlinePass.create())
	match cam_name:
		"close":
			cam.look_at_from_position(Vector3(1.5, 1.35, 1.3), Vector3(0.1, 0.95, 0.15))
		"grip":
			cam.look_at_from_position(wrist.global_position + Vector3(0.9, 0.35, 0.5), wrist.global_position + Vector3(0, -0.02, -0.1))
		"blower":
			cam.look_at_from_position(Vector3(1.3, 1.25, 7.9), Vector3(-0.35, 0.45, 5.9))
		"trolley":
			cam.look_at_from_position(Vector3(3.3, 1.9, 8.0), Vector3(2.2, 1.7, 6.0))
		"hands":
			cam.look_at_from_position(Vector3(5.0, 1.32, 3.42), Vector3(5.0, 1.0, 2.96))
		"scrap":
			cam.look_at_from_position(Vector3(3.85, 0.95, 4.1), Vector3(3.85, 0.14, 2.8))
		"belt":
			cam.look_at_from_position(Vector3(-0.6, 1.5, 3.6), Vector3(-1.9, 0.85, 1.4))
		"drive":
			cam.look_at_from_position(Vector3(0.1, 1.5, 2.6), Vector3(-0.85, 1.05, 1.6))
		"back":
			cam.look_at_from_position(Vector3(-2.2, 1.7, -2.4), Vector3(0.2, 1.0, 0.4))
		_:
			cam.look_at_from_position(Vector3(2.6, 1.7, 3.0), Vector3(0.25, 1.05, 0.55))
	cam.make_current()
	RenderingServer.global_shader_parameter_set(&"cutaway_target", Vector4(0, -100, 0, 0))
