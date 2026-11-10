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
