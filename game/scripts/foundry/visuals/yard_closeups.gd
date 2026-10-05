extends Node
## Station art in the real backyard: stages the same busy moment as
## backyard_showcase (a pour into a rammed mold, fresh castings, a bronze
## buddy, a hot furnace) and saves several shots in one run (one shader
## warm-up): `-- --shots=wide,pour,reveal,side,furnace,bench,scrap,crate,board
## --out=/abs/dir` -> yard_<shot>.png.

var world: GameWorld
var _shots: PackedStringArray = ["wide", "pour", "reveal", "side"]
var _out := "."


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots = arg.trim_prefix("--shots=").split(",")
		elif arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
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
	var mold: MoldBox = molds[0]
	for d in [DrawingSamples.smiley(), DrawingSamples.cat()]:
		mold.add_pattern(d.to_code())
	for i in MoldBox.RAMS_NEEDED:
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
	var mold2: MoldBox = molds[1]
	mold2.add_pattern(DrawingSamples.gnome().to_code())
	for i in 3:
		mold2._ram()
	for i in 2:
		world.spawn_entity({type = "cast", code = [DrawingSamples.star(), DrawingSamples.letter_b()][i].to_code(),
			alloy = [&"gold", &"bronze"][i], quality = 0.9, defects = {}, temperature = 0.35,
			pos = mold2.global_position + Vector3(-0.4 + i * 0.9, 0.6, 1.3), size = 0.5, thickness = 0.07})
	world.spawn_entity({type = "statue", pos = Vector3(-1.4, 0.05, 2.6), yaw = 0.6, pose = PlayerModel.panic_pose(), alloy = &"bronze"})
	var cam := Camera3D.new()
	cam.fov = 50
	add_child(cam)
	cam.add_child(OutlinePass.create())
	cam.make_current()
	var at := func(n: Node3D) -> Vector3: return n.global_position
	var bench: Node3D = world.find_children("*", "ModelBench", true, false)[0]
	var scrap: Node3D = world.find_children("*", "ScrapPile", true, false)[0]
	var crate: Node3D = world.find_children("*", "SellCrate", true, false)[0]
	var board: Node3D = world.find_children("*", "UpgradeBoard", true, false)[0]
	var views := {
		"wide": [Vector3(7.5, 6.5, 9.5), Vector3(0, 0.6, -0.5)],
		"pour": [at.call(mold) + Vector3(2.6, 2.0, 2.4), at.call(mold) + Vector3(0, 0.5, 0.3)],
		"reveal": [at.call(mold2) + Vector3(0.6, 1.7, 3.6), at.call(mold2) + Vector3(-0.6, 0.6, 1.2)],
		"side": [me.global_position + Vector3(3.0, 1.6, 0.4), me._hand_target()],
		"furnace": [at.call(furnace) + Vector3(2.4, 2.2, 2.6), at.call(furnace) + Vector3(0.2, 0.6, 0)],
		"mold": [at.call(mold) + Vector3(1.2, 1.9, -1.6), at.call(mold) + Vector3(0, 0.4, 0.1)],
		"mold2": [at.call(mold2) + Vector3(0.9, 1.8, 1.7), at.call(mold2) + Vector3(0, 0.4, 0)],
		"bench": [at.call(bench) + Vector3(1.1, 1.8, 2.0), at.call(bench) + Vector3(0, 0.85, 0)],
		"scrap": [at.call(scrap) + Vector3(1.8, 1.6, 2.0), at.call(scrap) + Vector3(0, 0.3, 0)],
		"crate": [at.call(crate) + Vector3(-1.2, 1.7, 2.4), at.call(crate) + Vector3(0, 0.6, 0)],
		"board": [at.call(board) + Vector3(-0.6, 1.6, 3.0), at.call(board) + Vector3(0, 1.4, 0)],
	}
	_keep_pouring(me, crucible, mold)
	await _frames(110)
	for name in _shots:
		var v: Array = views.get(name, views["wide"])
		cam.look_at_from_position(v[0], v[1])
		await _frames(12)
		get_viewport().get_texture().get_image().save_png(_out.path_join("yard_%s.png" % name))
		print("Saved shot ", name)
	get_tree().quit()


func _keep_pouring(me: Player, crucible: Crucible, mold: MoldBox) -> void:
	while true:
		await get_tree().physics_frame
		me.using = mold._total_fill() <= 0.55
		if not me.using:
			crucible.use_end(me)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
