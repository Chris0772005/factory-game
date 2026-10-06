extends Node
## Stages a busy backyard moment for screenshots and trailer frames:
## a pour in progress, a hot furnace, fresh castings and a bronze buddy.
## Camera via `-- --cam=wide|pour|side|reveal`. `reveal` stages the hammer
## blow instead: the worker smashes the second mold and the castings fly out.

## Physics frame of the final hammer blow in the reveal staging; screenshots are
## taken at frame ~150, so the castings are in the air with the sand burst.
const REVEAL_FRAME := 126

var world: GameWorld
var _cam_name := "pour"
## Extra workers so every shot shows the co-op promise (rigged models, no physics).
var _crew: Array[PlayerModel] = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cam="):
			_cam_name = arg.trim_prefix("--cam=")
	# Staged shots start from a fresh install (0 $) and never touch the player's save.
	SaveGame.disabled = true
	world = load("res://scenes/backyard.tscn").instantiate()
	add_child(world)
	_stage.call_deferred()


func _stage() -> void:
	await get_tree().physics_frame
	var me := world.local_player()
	var molds := get_tree().get_nodes_in_group(&"molds")
	var furnace: Furnace = world.find_children("*", "Furnace", true, false)[0]
	var crucible: Crucible = get_tree().get_first_node_in_group(&"crucibles")
	var hammer: Hammer = world.entities.get_children().filter(func(n: Node) -> bool: return n is Hammer)[0]
	var mold: MoldBox = molds[0]
	var mold2: MoldBox = molds[1]
	furnace.heat = 0.95
	# A mid-session wallet instead of a fresh install's 0 $ (nothing is saved here).
	world.money = 1240
	world.money_changed.emit(world.money)
	_pattern_and_ram(mold, [DrawingSamples.smiley(), DrawingSamples.cat()])
	crucible.add_melt(&"copper", 2.4)
	crucible.add_melt(&"zinc_brass", 0.4)
	crucible.temperature = 0.95
	# The hammer leans by the second mold, out of the pour shots' foreground.
	hammer.global_position = mold2.global_position + Vector3(0.98, 0.05, -0.25)
	var reveal := _cam_name == "reveal"
	if reveal:
		# First mold already poured and glowing; the worker is at the second with the hammer.
		_fill(mold, 0.95)
		_pattern_and_ram(mold2, [DrawingSamples.star(), DrawingSamples.letter_b()])
		_fill(mold2, 0.95)
		mold2._cool_left = 0.0
		me.global_position = mold2.global_position + Vector3(-1.45, 0.05, 0.3)
		me.facing = PI * 0.5
		hammer.global_position = me._hand_target()
		await get_tree().physics_frame
		me.grab(hammer)
	else:
		# Pouring across the mold from its left end, face towards the shot cameras;
		# the stream lands in the first (smiley) cavity.
		me.global_position = mold.global_position + Vector3(-1.56, 0.05, 0.0)
		me.facing = PI * 0.5
		crucible.global_position = me._hand_target()
		await get_tree().physics_frame
		me.grab(crucible)
		# Straight into the carry pose (in front of the hips, above the mold's rim).
		crucible.global_position = me._hand_target()
		me.using = true
		crucible.use_start(me)
		# Fresh castings in front of the second mold.
		for i in 2:
			world.spawn_entity({type = "cast", code = [DrawingSamples.star(), DrawingSamples.letter_b()][i].to_code(),
				alloy = [&"gold", &"bronze"][i], quality = 0.9, defects = {}, temperature = 0.35,
				pos = mold2.global_position + Vector3(-0.4 + i * 0.9, 0.6, 1.3), size = 0.5, thickness = 0.07})
	_add_crew(furnace, mold2, reveal)
	# Fully in frame next to the furnace (never cut by the left edge of the pour/side shots).
	var statue_pos := mold2.global_position + Vector3(-1.75, 0.05, -1.0) if reveal else mold2.global_position + Vector3(-1.2, 0.05, -2.2)
	world.spawn_entity({type = "statue", pos = statue_pos, yaw = 0.6, pose = PlayerModel.panic_pose(), alloy = &"bronze"})
	var cam := Camera3D.new()
	cam.fov = 50
	add_child(cam)
	cam.add_child(OutlinePass.create())
	var chest := me.global_position + Vector3(0, 0.75, 0)
	var ahead := Vector3(sin(me.facing), 0.0, cos(me.facing))
	var right := Vector3(-ahead.z, 0.0, ahead.x)
	match _cam_name:
		"side":
			# From the worker's right, a little ahead: profile, crucible and stream in front of him.
			cam.look_at_from_position(me.global_position + right * 3.0 + ahead * 0.9 + Vector3(0, 1.4, 0), me.global_position + ahead * 0.6 + Vector3(0, 0.8, 0))
		"wide":
			cam.look_at_from_position(Vector3(6.2, 5.6, 8.0), Vector3(-0.3, 0.6, -0.8))
		"reveal":
			cam.look_at_from_position(mold2.global_position + Vector3(1.0, 1.6, 2.9), mold2.global_position + Vector3(-0.3, 0.9, 0.0))
		_:
			# Front-right of the worker: his face, the tipped pot's glowing mouth and the stream.
			cam.look_at_from_position(mold.global_position + Vector3(1.7, 1.6, 2.0), mold.global_position + Vector3(-0.75, 0.68, 0.0))
	cam.make_current()
	var frame := 0
	while true:
		await get_tree().physics_frame
		frame += 1
		_animate_crew(frame, furnace)
		if reveal:
			# Two blows to crack it, the third (with the body swing) breaks it open.
			if frame == 60 or frame == 95 or frame == REVEAL_FRAME:
				me._show_action(&"hammer")
				hammer.use_start(me)
			continue
		me.using = true
		if mold._total_fill() > 0.85:
			crucible.use_end(me)
			me.using = false


func _pattern_and_ram(mold: MoldBox, drawings: Array) -> void:
	for d: Drawing in drawings:
		mold.add_pattern(d.to_code())
	for i in MoldBox.RAMS_NEEDED:
		mold._rams = i
		mold._ram()


## Pours a full, clean melt straight into a rammed mold.
func _fill(mold: MoldBox, temperature: float) -> void:
	var litres := 0.0
	for need in mold.needs:
		litres += need
	mold.receive_metal(litres + 0.01, temperature, {&"copper": litres * 0.85, &"zinc_brass": litres * 0.15}, 0.5, 1.0 / 60.0)


## Teal works the bellows, violet cheers over a fresh casting.
func _add_crew(furnace: Furnace, mold2: MoldBox, reveal: bool) -> void:
	var stoker := PlayerModel.new()
	stoker.suit_color = GameWorld.PLAYER_COLORS[1]
	world.add_child(stoker)
	stoker.global_position = furnace.global_position + Vector3(1.78, 0.0, 0.08)
	stoker.rotation.y = -PI * 0.5
	_crew.append(stoker)
	var fan := PlayerModel.new()
	fan.suit_color = GameWorld.PLAYER_COLORS[2]
	world.add_child(fan)
	fan.global_position = mold2.global_position + (Vector3(0.9, 0.0, 1.6) if reveal else Vector3(0.7, 0.0, -1.3))
	fan.rotation.y = PI * 0.85 if reveal else 0.3
	_crew.append(fan)


func _animate_crew(frame: int, furnace: Furnace) -> void:
	for worker in _crew:
		worker.animate(1.0 / 60.0, Vector3.ZERO, true, false, Vector3.ZERO)
	if _crew.size() < 2:
		return
	if frame % 80 == 10:
		_crew[0].play_action(&"kick")
	if frame % 80 == 30:
		furnace.pump_fx()
	if frame % 120 == 20:
		_crew[1].play_action(&"cheer")
