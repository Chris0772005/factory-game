extends Node
## Stages the bell foundry for screenshots. `-- --cam=hall|pour|reveal`.
## hall: crew at work, the crane carrying a big bell, a pit glowing mid-pour.
## pour: close on the pit being filled. reveal: a bell just dug out, ringing,
## with its banner (taken ~1 s after the dig at REVEAL_FRAME).

const REVEAL_FRAME := 40

var world: GameWorld
var _cam_name := "hall"
var _crew: Array[PlayerModel] = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cam="):
			_cam_name = arg.trim_prefix("--cam=")
	SaveGame.disabled = true
	world = load("res://scenes/bell_foundry.tscn").instantiate()
	add_child(world)
	_stage.call_deferred()


func _stage() -> void:
	await get_tree().physics_frame
	var me := world.local_player()
	var pits := get_tree().get_nodes_in_group(&"bell_pits")
	var small: BellPit = pits.filter(func(p): return (p as BellPit).mouth_radius < 0.4)[0]
	var big: BellPit = pits.filter(func(p): return (p as BellPit).mouth_radius > 0.4)[0]
	var furnaces := world.get_children().filter(func(n): return n is Furnace)
	for f in furnaces:
		(f as Furnace).heat = 0.95
	world.money = 6420
	world.money_changed.emit(world.money)
	# The big pit: mid-pour, glowing.
	big.add_profile(DrawingSamples.bell().to_code())
	for i in BellPit.TURNS_NEEDED:
		big._turn()
	big.receive_metal(big.need * 0.6, 0.95, {&"copper": big.need * 0.6}, 0.5, 1.0 / 60.0)
	# The small pit: cooled, ready to dig (reveal) or turned (hall).
	small.add_profile(DrawingSamples.bell().to_code())
	for i in BellPit.TURNS_NEEDED:
		small._turn()
	small.receive_metal(small.need + 0.01, 0.95, {&"copper": small.need * 0.9, &"zinc_brass": small.need * 0.1}, 0.5, 1.0 / 60.0)
	small._cool_left = 0.01
	# A finished bell hanging from the crane over the floor.
	var hoist: ChainHoist = get_tree().get_first_node_in_group(&"hoists")
	var hung: Bell = world.spawn_entity({type = "bell", code = DrawingSamples.bell().to_code(), alloy = "bronze", radius = 0.5,
		quality = 0.85, pos = Vector3(-1.6, 1.0, 2.2)})
	hoist.trolley_x = -1.6
	hoist.bridge_z = 2.2
	await get_tree().physics_frame
	hoist.load = hung
	hoist._load_offset = hoist._attach_height(hung)
	hoist.hook_y = ChainHoist.HOOK_TOP - 0.4
	_add_crew(furnaces[0], big)
	me.global_position = small.global_position + Vector3(0.0, 0.05, small.outer_radius() + 0.5)
	me.facing = PI
	var hammer: Hammer = world.entities.get_children().filter(func(n): return n is Hammer)[0]
	hammer.global_position = me._hand_target()
	await get_tree().physics_frame
	me.grab(hammer)
	var cam := Camera3D.new()
	cam.fov = 50
	add_child(cam)
	cam.add_child(OutlinePass.create())
	match _cam_name:
		"pour":
			cam.look_at_from_position(big.global_position + Vector3(1.6, 2.4, 2.6), big.global_position + Vector3(0, 0.7, 0))
		"reveal":
			cam.look_at_from_position(small.global_position + Vector3(1.8, 2.0, 3.0), small.global_position + Vector3(0, 0.9, 0))
		_:
			cam.look_at_from_position(Vector3(1.0, 8.2, 12.5), Vector3(0.0, 0.8, -0.6))
	cam.make_current()
	RenderingServer.global_shader_parameter_set(&"cutaway_target", Vector4(0, -100, 0, 0))
	var frame := 0
	while true:
		await get_tree().physics_frame
		frame += 1
		for w in _crew:
			w.animate(1.0 / 60.0, Vector3.ZERO, true, false, Vector3.ZERO)
		if frame % 80 == 10:
			_crew[0].play_action(&"kick")
			(furnaces[0] as Furnace).pump_fx()
		if frame % 120 == 20:
			_crew[1].play_action(&"cheer")
		if _cam_name == "reveal" and frame in [REVEAL_FRAME - 20, REVEAL_FRAME]:
			me._show_action(&"hammer")
			hammer.use_start(me)


func _add_crew(furnace: Node3D, big: BellPit) -> void:
	var stoker := PlayerModel.new()
	stoker.suit_color = GameWorld.PLAYER_COLORS[1]
	world.add_child(stoker)
	stoker.global_position = furnace.global_position + Vector3(1.78, 0.0, 0.08)
	stoker.rotation.y = -PI * 0.5
	_crew.append(stoker)
	var fan := PlayerModel.new()
	fan.suit_color = GameWorld.PLAYER_COLORS[2]
	world.add_child(fan)
	fan.global_position = big.global_position + Vector3(big.outer_radius() + 0.5, 0.0, 0.6)
	fan.rotation.y = -2.2
	_crew.append(fan)
