extends Node3D
## Close-up gallery of the foundry stations for art iteration: every station
## on a patch of yard dirt under the backyard's dusk lighting, staged hot
## (furnace pumped, crucible pouring into a rammed mold). Pick the shot with
## `-- --cam=furnace|crucible|mold|mold_empty|bench|scrap|crate|board|hammer|row`,
## or several in one run: `-- --shots=furnace,mold,bench --out=/abs/dir` (one
## PNG per shot, named st_<shot>.png). `--force-visual` builds the art headless
## as a quick smoke test.

var _cam_name := "row"
var _shots: PackedStringArray = []
var _out := ""
var _cam: Camera3D
var _mold: MoldBox
var _pourer: Crucible
## Station positions by gallery name.
var _at := {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cam="):
			_cam_name = arg.trim_prefix("--cam=")
		elif arg == "--force-visual":
			StationKit.force = true
		elif arg.begins_with("--shots="):
			_shots = arg.trim_prefix("--shots=").split(",")
		elif arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	YardLighting.build(self)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	ground.mesh = plane
	ground.material_override = EnvMesh.surface("gallery_dirt", {base_color = Color("#8a6a4f"), macro = 0.16, grain = 0.1,
		contact_dark = 0.0, roughness_base = 0.95})
	add_child(ground)
	StationKit.box_collider(self, Vector3(40, 1, 40), Transform3D(Basis(), Vector3(0, -0.5, 0)))
	var furnace := Furnace.new()
	add_child(furnace)
	furnace.heat = 0.9
	var docked := Crucible.create_crucible({pos = Vector3(0, 0.13, 0)})
	add_child(docked)
	docked.add_melt(&"copper", 2.2)
	docked.temperature = 0.9
	_mold = MoldBox.new()
	_mold.position = Vector3(3.2, 0, 0.2)
	add_child(_mold)
	var empty_mold := MoldBox.new()
	empty_mold.position = Vector3(3.2, 0, 2.6)
	add_child(empty_mold)
	_at["empty_mold"] = empty_mold.position
	var bench := ModelBench.new()
	bench.position = Vector3(-3.0, 0, -0.4)
	add_child(bench)
	_at["bench"] = bench.position
	var scrap := ScrapPile.new()
	scrap.position = Vector3(-0.2, 0, 3.4)
	add_child(scrap)
	_at["scrap"] = scrap.position
	var crate := SellCrate.new()
	crate.position = Vector3(-3.2, 0, 3.0)
	crate.rotation.y = -0.3
	add_child(crate)
	_at["crate"] = crate.position
	var board := UpgradeBoard.new()
	board.position = Vector3(6.4, 0, -1.2)
	board.rotation.y = -0.4
	add_child(board)
	_at["board"] = board.position
	var hammer := Hammer.create_hammer({pos = Vector3(1.6, 0.02, 2.4)})
	add_child(hammer)
	var cold := Crucible.create_crucible({pos = Vector3(1.1, 0.02, 1.1)})
	add_child(cold)
	cold.pour_yaw = 0.6
	_stage.call_deferred()


func _stage() -> void:
	await get_tree().physics_frame
	for d in [DrawingSamples.smiley(), DrawingSamples.cat()]:
		_mold.add_pattern(d.to_code())
	for i in MoldBox.RAMS_NEEDED:
		_mold._ram()
	_pourer = Crucible.create_crucible({pos = _mold.global_position + Vector3(-0.36, 1.05, 0.62)})
	_pourer.freeze = true
	add_child(_pourer)
	_pourer.add_melt(&"copper", 2.4)
	_pourer.add_melt(&"zinc_brass", 0.4)
	_pourer.temperature = 0.95
	_pourer.pour_yaw = PI
	_pourer.on_grabbed(self)
	_pourer.use_start(self)
	_cam = Camera3D.new()
	_cam.fov = 45
	add_child(_cam)
	_cam.add_child(OutlinePass.create())
	var shots := {
		"furnace": [Vector3(2.0, 1.9, 2.3), Vector3(0.1, 0.55, -0.1)],
		"furnace_back": [Vector3(-2.2, 2.0, -2.0), Vector3(0.1, 0.8, -0.3)],
		"crucible": [Vector3(0.75, 1.75, 1.05), Vector3(0, 0.45, 0)],
		"crucible_cold": [Vector3(1.75, 0.95, 1.95), Vector3(1.1, 0.25, 1.1)],
		"mold": [_mold.position + Vector3(1.4, 1.7, 1.9), _mold.position + Vector3(0, 0.4, 0)],
		"mold_top": [_mold.position + Vector3(0.3, 2.3, 1.0), _mold.position + Vector3(0, 0.4, 0)],
		"mold_empty": [_at.empty_mold + Vector3(1.3, 1.5, 1.6), _at.empty_mold + Vector3(0, 0.4, 0)],
		"bench": [_at.bench + Vector3(1.0, 1.7, 1.7), _at.bench + Vector3(0, 0.8, 0)],
		"scrap": [_at.scrap + Vector3(1.4, 1.3, 1.6), _at.scrap + Vector3(0, 0.3, 0)],
		"crate": [_at.crate + Vector3(1.3, 1.5, 2.0), _at.crate + Vector3(0, 0.5, 0)],
		"board": [_at.board + Vector3(0.6, 1.5, 2.6), _at.board + Vector3(0, 1.3, 0)],
		"hammer": [Vector3(1.6, 0.9, 3.3), Vector3(1.6, 0.4, 2.4)],
		"row": [Vector3(1.5, 5.5, 9.5), Vector3(1.5, 0.4, 0.8)],
	}
	var s: Array = shots.get(_cam_name, shots["row"])
	_cam.look_at_from_position(s[0], s[1])
	_cam.make_current()
	_watch_pour()
	if not _shots.is_empty():
		await _frames(100)
		for name in _shots:
			var shot: Array = shots.get(name, shots["row"])
			_cam.look_at_from_position(shot[0], shot[1])
			await _frames(12)
			var img := get_viewport().get_texture().get_image()
			img.save_png(_out.path_join("st_%s.png" % name))
			print("Saved shot ", name)
		get_tree().quit()
	elif StationKit.force:
		await _frames(120)
		print("gallery ok: mold fill %.2f, pour flow %.2f" % [_mold._total_fill(), _pourer.flow])
		get_tree().quit()


func _watch_pour() -> void:
	while true:
		await get_tree().physics_frame
		if _mold._total_fill() > 0.6:
			_pourer.use_end(self)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
