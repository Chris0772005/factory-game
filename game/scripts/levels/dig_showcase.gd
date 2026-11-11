extends Node
## First-person screenshot of digging at the scrap heap (garage).

func _ready() -> void:
	SaveGame.disabled = true
	var world: GameWorld = load("res://scenes/garage.tscn").instantiate()
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var me := world.local_player()
	var pile: ScrapPile = get_tree().get_first_node_in_group(&"scrap_piles")
	var cam_name := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cam="):
			cam_name = arg.trim_prefix("--cam=")
	if cam_name == "auto":
		# The whole automation: blower, mold units, rail ladle pouring.
		world.upgrades.load_save(["conveyor", "robot_arm", "auto_bellows", "auto_rammer", "auto_pour", "auto_breaker", "auto_ship"])
		var auto: AutoFoundry = get_tree().get_first_node_in_group(&"auto_foundries")
		var pot: Crucible = get_tree().get_first_node_in_group(&"crucibles")
		pot.global_position = auto.furnace.global_position + Vector3(0, 0.35, 0)
		auto.furnace.heat = 0.9
		var m := auto.molds[0]
		m.add_pattern(DrawingSamples.star().to_code())
		m.ram_quality = 0.8
		m.state = MoldBox.State.RAMMED
		m._prepare_fill()
		auto.ladle_mold = 0
		auto.ladle_t = 1.0
		auto.ladle_state = AutoFoundry.Trip.POUR
		auto.ladle_amount = 30.0
		auto.ladle_mix = {&"alu": 30.0}
		auto.ladle_temp = 0.9
		var c := Camera3D.new()
		c.fov = 62
		add_child(c)
		c.add_child(OutlinePass.create())
		c.look_at_from_position(Vector3(2.6, 2.0, 3.4), Vector3(-1.6, 0.9, -1.4))
		c.make_current()
		me.global_position = Vector3(4.5, 0.1, 3.0)
		RenderingServer.global_shader_parameter_set(&"cutaway_target", Vector4(0, -100, 0, 0))
		return
	if cam_name != "":
		# The scrap line: belt and grab arm running. line = wide, arm = close.
		world.upgrades.load_save(["magnet", "conveyor", "robot_arm"])
		var line: ScrapLine = get_tree().get_first_node_in_group(&"scrap_lines")
		var mid := (pile.global_position + line.furnace.global_position) * 0.5 + Vector3(0, 0.9, 0)
		var side := (line.furnace.global_position - pile.global_position).normalized().cross(Vector3.UP)
		if side.dot(-mid) < 0.0:
			side = -side
		var cam := Camera3D.new()
		cam.fov = 60
		add_child(cam)
		cam.add_child(OutlinePass.create())
		var back := 3.4 if cam_name == "line" else 2.0
		cam.look_at_from_position(mid + side * back + Vector3(0, 0.75, 0), mid + (Vector3(0, -0.2, 0) if cam_name == "line" else (pile.global_position - mid) * 0.6))
		cam.make_current()
		me.global_position = mid - side * 2.0
		RenderingServer.global_shader_parameter_set(&"cutaway_target", Vector4(0, -100, 0, 0))
		return
	world.upgrades.load_save(["magnet"])
	me.global_position = pile.global_position + Vector3(0.9, 0.05, 1.5)
	var to := pile.global_position - me.global_position
	me._camera_rig.yaw = atan2(to.x, to.z) + PI
	me._camera_rig.pitch = -0.42
	Input.action_press(&"interact")
	while true:
		await get_tree().physics_frame
		pile.interact_tick(me, 1.0 / 60.0 * 2.0)
