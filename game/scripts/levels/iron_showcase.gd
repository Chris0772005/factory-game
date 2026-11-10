extends Node
## Stages the Eisenhalle for screenshots. `-- --cam=hall|tap|kaiser|line|finale`.
## hall: wide, the tap running into the ladle, the line glowing, the crew.
## tap: close on the cupola tap. kaiser: two workers on the wheel, the ladle
## tipped into the Kaisergrube. line: the mold line with hot flasks and the
## pouring box. finale: the ending screen over the hall.

var world: GameWorld
var _cam_name := "hall"
var _crew: Array[PlayerModel] = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cam="):
			_cam_name = arg.trim_prefix("--cam=")
	SaveGame.disabled = true
	world = load("res://scenes/iron_hall.tscn").instantiate()
	add_child(world)
	_stage.call_deferred()


func _stage() -> void:
	await get_tree().physics_frame
	var me := world.local_player()
	var cupola: CupolaFurnace = get_tree().get_first_node_in_group(&"cupolas")
	var crane := world.find_station(HallCrane) as HallCrane
	var ladle := crane.ladle
	var line: MoldLine = get_tree().get_first_node_in_group(&"mold_lines")
	var pit: BellPit = get_tree().get_first_node_in_group(&"bell_pits")
	world.upgrades.load_save(["auto_molder", "auto_pourer"])
	world.money = 14280
	world.money_changed.emit(world.money)
	cupola.heat = 0.95
	cupola.temperature = 0.95
	cupola.mix = {&"iron": 60.0}
	cupola.bath = 60.0
	# The line: a pattern, several flasks poured and cooling, the box full.
	line.set_pattern(DrawingSamples.star().to_code())
	for s in [0, 1, 2, 3, 4]:
		var f := line.flask_at(s)
		line._mold(f, 0.85)
		if s >= 2:
			line.fills[f] = 1.0 if s > 2 else 0.6
			line.states[f] = MoldLine.Flask.FILLED if s > 2 else MoldLine.Flask.MOLDED
			line.temps[f] = 0.95
			line.cools[f] = MoldLine.COOL_TIME * (0.9 if s == 3 else 0.5)
			line.mixes[f] = {&"iron": 1.0}
	line.tundish = 22.0
	line.tundish_mix = {&"iron": 22.0}
	line.tundish_temp = 0.95
	line._broadcast_state()
	# The Kaisergrube turned and half poured.
	pit.add_profile(DrawingSamples.bell().to_code())
	for i in BellPit.TURNS_NEEDED:
		pit._turn()
	pit.receive_metal(pit.need * 0.45, 0.95, {&"copper": pit.need * 0.45}, 2.0, 1.0 / 60.0)
	ladle.mix = {&"copper": 40.0}
	ladle.amount = 40.0
	ladle.temperature = 0.95
	match _cam_name:
		"kaiser":
			_aim(crane, pit.global_position + Vector3(0.0, 0.5, pit.mouth_radius * 0.6))
		"line":
			_aim(crane, line.to_global(MoldLine.TUNDISH_POS + Vector3(0, MoldLine.TUNDISH_TOP, 0)))
		_:
			ladle.mix = {&"iron": 12.0}
			ladle.amount = 12.0
			var tap := cupola.to_global(CupolaFurnace.TROUGH_END)
			crane.trolley_x = tap.x
			crane.bridge_z = tap.z
			crane.hook = ChainHoist.Hook.LOW
			crane.hook_y = crane.hook_low
			cupola.tap_open = true
	var cam := Camera3D.new()
	cam.fov = 50
	add_child(cam)
	cam.add_child(OutlinePass.create())
	match _cam_name:
		"tap":
			var t := cupola.to_global(CupolaFurnace.TROUGH_END)
			cam.look_at_from_position(t + Vector3(3.4, 1.2, 3.4), t + Vector3(-0.4, -0.5, -0.4))
			_add_worker(cupola.to_global(Vector3(0.9, 0, 1.6)), -2.4, &"cheer")
			_add_worker(cupola.to_global(CupolaFurnace.BLOWER_POS + Vector3(0.0, 0, 0.9)), PI, &"")
		"kaiser":
			var w := ladle.interact_point()
			_add_worker(Vector3(w.x + 0.35, 0, w.z - 0.75), 0.0, &"")
			_add_worker(Vector3(w.x - 0.35, 0, w.z - 0.75), 0.0, &"")
			_add_worker(pit.global_position + Vector3(pit.outer_radius() + 0.6, 0, 0.9), -2.0, &"cheer")
			cam.look_at_from_position(pit.global_position + Vector3(3.6, 2.6, 4.2), pit.global_position + Vector3(-0.3, 0.8, -0.3))
		"line":
			var c := line.to_global(Vector3(2.4, 0.6, 0.0))
			cam.look_at_from_position(c + Vector3(1.4, 2.6, 4.6), c + Vector3(0, 0, -0.4))
			_add_worker(line.interact_point() + Vector3(0.1, -0.75, 0.75), PI, &"")
		_:
			cam.look_at_from_position(Vector3(0.5, 10.5, 15.5), Vector3(-0.8, 1.2, -0.8))
			_add_worker(cupola.to_global(Vector3(0.9, 0, 1.6)), -2.4, &"cheer")
			_add_worker(cupola.to_global(CupolaFurnace.BLOWER_POS + Vector3(0.0, 0, 0.9)), PI, &"")
			_add_worker(line.interact_point() + Vector3(0.1, -0.75, 0.75), PI, &"")
	if _cam_name == "hall":
		var hunt: SearchHunt = get_tree().get_first_node_in_group(&"search_hunts")
		hunt.scores = [2, 1, 0, 3]
		hunt.start(Vector3(4.0, 0.0, 1.2))
	me.global_position = Vector3(2.2, 0.05, 3.6)
	me.facing = PI * 0.8
	cam.make_current()
	RenderingServer.global_shader_parameter_set(&"cutaway_target", Vector4(0, -100, 0, 0))
	if _cam_name == "finale":
		await get_tree().create_timer(0.2).timeout
		# The software renderer is slow: skip the fade-in for the shot.
		FinaleScreen.open(world, ["Gießer Blau", "Gießer Türkis", "Gießer Lila"], true)
	var frame := 0
	while true:
		await get_tree().physics_frame
		frame += 1
		if _cam_name == "kaiser":
			ladle.tilt = minf(0.85, ladle.tilt + 0.02)
			ladle._cranks[1] = Time.get_ticks_msec()
		for w in _crew:
			w.animate(1.0 / 60.0, Vector3.ZERO, true, false, Vector3.ZERO)
		if frame % 120 == 20 and _crew.size() > 0 and _crew[0].has_meta(&"anim"):
			_crew[0].play_action(_crew[0].get_meta(&"anim"))


## Moves the lowered ladle so its tipped lip is over `target`.
func _aim(crane: HallCrane, target: Vector3) -> void:
	var ladle := crane.ladle
	crane.hook = ChainHoist.Hook.LOW
	crane.hook_y = crane.hook_low
	crane._place_ladle()
	ladle.tilt = 0.8
	ladle._update_visuals(0.0)
	var off := ladle.lip_position() - ladle.global_position
	crane.trolley_x = target.x - off.x
	crane.bridge_z = target.z - off.z
	crane._place_ladle()


func _add_worker(pos: Vector3, yaw: float, anim: StringName) -> void:
	var w := PlayerModel.new()
	w.suit_color = GameWorld.PLAYER_COLORS[1 + _crew.size() % 3]
	world.add_child(w)
	w.global_position = pos
	w.rotation.y = yaw
	if anim != &"":
		w.set_meta(&"anim", anim)
	_crew.append(w)
