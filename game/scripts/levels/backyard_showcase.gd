extends Node
## Stages a busy backyard moment for screenshots and trailer frames:
## a pour in progress, a hot furnace, fresh castings and a bronze buddy.
## Camera via `-- --cam=wide|pour|reveal`.

var world: GameWorld
var _cam_name := "pour"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cam="):
			_cam_name = arg.trim_prefix("--cam=")
	world = load("res://scenes/backyard.tscn").instantiate()
	add_child(world)
	_stage.call_deferred()


func _stage() -> void:
	await get_tree().physics_frame
	var me := world.local_player()
	var molds := get_tree().get_nodes_in_group(&"molds")
	var furnace: Furnace = world.find_children("*", "Furnace", true, false)[0]
	var crucible: Crucible = get_tree().get_first_node_in_group(&"crucibles")
	furnace.heat = 0.95
	var samples := [DrawingSamples.smiley(), DrawingSamples.cat()]
	var mold: MoldBox = molds[0]
	for d in samples:
		mold.add_pattern(d.to_code())
	for i in MoldBox.RAMS_NEEDED:
		mold._rams = i
		mold._ram()
	crucible.add_melt(&"copper", 2.4)
	crucible.add_melt(&"zinc_brass", 0.4)
	crucible.temperature = 0.95
	me.global_position = mold.global_position + Vector3(-0.2, 0.05, 1.35)
	me.facing = PI
	crucible.global_position = me._hand_target()
	await get_tree().physics_frame
	me.grab(crucible)
	me.using = true
	crucible.use_start(me)
	# Fresh castings and a statue for the reveal shots.
	var mold2: MoldBox = molds[1]
	for i in 2:
		world.spawn_entity({type = "cast", code = [DrawingSamples.star(), DrawingSamples.letter_b()][i].to_code(),
			alloy = [&"gold", &"bronze"][i], quality = 0.9, defects = {}, temperature = 0.35,
			pos = mold2.global_position + Vector3(-0.4 + i * 0.9, 0.6, 1.3), size = 0.5, thickness = 0.07})
	world.spawn_entity({type = "statue", pos = Vector3(-1.4, 0.05, 2.6), yaw = 0.6, pose = PlayerModel.panic_pose(), alloy = &"bronze"})
	var cam := Camera3D.new()
	cam.fov = 50
	add_child(cam)
	cam.add_child(OutlinePass.create())
	match _cam_name:
		"side":
			cam.look_at_from_position(me.global_position + Vector3(3.0, 1.6, 0.4), me._hand_target())
		"wide":
			cam.look_at_from_position(Vector3(7.5, 6.5, 9.5), Vector3(0, 0.6, -0.5))
		"reveal":
			cam.look_at_from_position(mold2.global_position + Vector3(0.6, 1.7, 3.6), mold2.global_position + Vector3(-0.6, 0.6, 1.2))
		_:
			cam.look_at_from_position(mold.global_position + Vector3(2.6, 2.0, 2.4), mold.global_position + Vector3(0, 0.5, 0.3))
	cam.make_current()
	var frame := 0
	while true:
		await get_tree().physics_frame
		frame += 1
		if frame == 100:
			for mi in crucible.find_children("*", "MeshInstance3D", true, false):
				print("crucible mesh ", mi.name, " visible=", mi.is_visible_in_tree(), " pos=", mi.global_position)
			for n in world.find_children("*", "", true, false):
				if n is Node3D and n.global_position.distance_to(furnace.global_position + Vector3(1.2, 0, 0.6)) < 0.9 and n is MeshInstance3D:
					print("near furnace: ", n.get_path(), " ", n.global_position)
		if frame % 30 == 0 and false:
			print("crucible=%s hand=%s held=%s lip=%s target=%s flow=%.2f" % [crucible.global_position, me._hand_target(), me.held, crucible.lip_position(), crucible.pour_target, crucible.flow])
		me.using = true
		if mold._total_fill() > 0.55:
			crucible.use_end(me)
			me.using = false
