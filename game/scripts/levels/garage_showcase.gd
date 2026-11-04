extends Node
## Stages a busy garage moment for screenshots: the furnace roaring, a crew
## of three, one worker tipping a bucket over a hot mold (steam blast), the
## second mold rammed, a sealed crate waiting and a bronze buddy for the
## order board. `-- --cam=wide|quench`; the quench happens at QUENCH_FRAME.

const QUENCH_FRAME := 70

var world: GameWorld
var _cam_name := "wide"
var _crew: Array[PlayerModel] = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cam="):
			_cam_name = arg.trim_prefix("--cam=")
	SaveGame.disabled = true
	world = load("res://scenes/garage.tscn").instantiate()
	add_child(world)
	_stage.call_deferred()


func _stage() -> void:
	await get_tree().physics_frame
	var me := world.local_player()
	var molds := get_tree().get_nodes_in_group(&"molds")
	var mold: MoldBox = molds[0]
	var mold2: MoldBox = molds[1]
	var furnace: Furnace = world.find_children("*", "Furnace", true, false)[0]
	var bucket: WaterBucket = get_tree().get_first_node_in_group(&"buckets")
	furnace.heat = 0.95
	world.money = 2380
	world.money_changed.emit(world.money)
	for d in [DrawingSamples.star(), DrawingSamples.cat()]:
		mold.add_pattern(d.to_code())
	_ram(mold)
	var litres := 0.0
	for need in mold.needs:
		litres += need
	mold.receive_metal(litres + 0.01, 0.95, {&"copper": litres * 0.85, &"zinc_brass": litres * 0.15}, 0.5, 1.0 / 60.0)
	for d in [DrawingSamples.smiley(), DrawingSamples.letter_b()]:
		mold2.add_pattern(d.to_code())
	_ram(mold2)
	# The worker stands at the front of the hot mold with a full bucket.
	me.global_position = mold.global_position + Vector3(0.0, 0.05, 1.25)
	me.facing = PI
	bucket.full = true
	bucket.global_position = me._hand_target()
	await get_tree().physics_frame
	me.grab(bucket)
	world.spawn_entity({type = "sealed_crate", pos = Vector3(3.9, 0.1, 2.3), contents = "roof"})
	world.spawn_entity({type = "statue", pos = Vector3(4.9, 0.05, -1.4), yaw = -1.2, pose = PlayerModel.panic_pose(), alloy = &"bronze"})
	_add_crew(furnace, mold2)
	var cam := Camera3D.new()
	cam.fov = 50
	add_child(cam)
	cam.add_child(OutlinePass.create())
	match _cam_name:
		"quench":
			cam.look_at_from_position(mold.global_position + Vector3(2.0, 2.3, 3.3), mold.global_position + Vector3(-0.2, 0.7, 0.2))
		_:
			cam.look_at_from_position(Vector3(1.2, 6.4, 9.6), Vector3(0.4, 0.4, -0.6))
	cam.make_current()
	# Keep the line of sight clear of the walls like the game camera does.
	RenderingServer.global_shader_parameter_set(&"cutaway_target", Vector4(0, -100, 0, 0))
	var frame := 0
	while true:
		await get_tree().physics_frame
		frame += 1
		for w in _crew:
			w.animate(1.0 / 60.0, Vector3.ZERO, true, false, Vector3.ZERO)
		if frame % 80 == 10:
			_crew[0].play_action(&"kick")
		if frame % 80 == 30:
			furnace.pump_fx()
		if frame % 120 == 20:
			_crew[1].play_action(&"cheer")
		if frame == QUENCH_FRAME:
			me._show_action(&"interact")
			bucket.use_start(me)


func _ram(m: MoldBox) -> void:
	for i in MoldBox.RAMS_NEEDED:
		m._rams = i
		m._ram()


func _add_crew(furnace: Furnace, mold2: MoldBox) -> void:
	var stoker := PlayerModel.new()
	stoker.suit_color = GameWorld.PLAYER_COLORS[1]
	world.add_child(stoker)
	stoker.global_position = furnace.global_position + Vector3(1.78, 0.0, 0.08)
	stoker.rotation.y = -PI * 0.5
	_crew.append(stoker)
	var fan := PlayerModel.new()
	fan.suit_color = GameWorld.PLAYER_COLORS[2]
	world.add_child(fan)
	fan.global_position = mold2.global_position + Vector3(0.4, 0.0, 1.3)
	fan.rotation.y = 2.6
	_crew.append(fan)
