extends Node3D
## Close-up of the players' workers for judging figure, hard hat and poses without staging a whole
## level, in the daylight of the first level.
##   godot-render --path . res://scenes/crew_closeup.tscn -- --shot=out.png [--set=look|move|carry|act1|act2] [--cam=front|side|back|high|face] [--at=0.5]
## look: the four player colours standing. move: standing, walking, jogging, running, sprinting,
## in the air. carry: a box at arm's length, a box far ahead, the crucible by its handles, the
## sledgehammer, digging with the bare hands, running with a box. act1 / act2: the short actions,
## held at `--at` of their length (0..1), and the pose of a statue.

const SETS := {
	"look": [{}, {}, {}, {}],
	"move": [{}, {vel = 1.33}, {vel = 2.4}, {vel = 4.2}, {vel = 6.6}, {air = true}],
	"carry": [
		{hold = Vector3(0, 1.14, 0.8), box = true},
		{hold = Vector3(0, 1.05, 1.05), box = true},
		{hold = Vector3(0, 0.55, 0.64), pot = true},
		{hold = Vector3(0, 1.14, 0.8), hammer = true},
		{working = true},
		{hold = Vector3(0, 1.14, 0.8), box = true, vel = 4.2},
	],
	"act1": [{action = &"pickup"}, {action = &"interact"}, {action = &"use"}, {action = &"throw"},
		{action = &"hammer", hold = Vector3(0, 1.14, 0.8), hammer = true}],
	"act2": [{action = &"ram"}, {action = &"kick"}, {action = &"cheer"}, {action = &"hit"}, {pose = true}],
}


func _ready() -> void:
	var set_name := "look"
	var cam_name := "front"
	var at := 0.5
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--set="):
			set_name = arg.trim_prefix("--set=")
		elif arg.begins_with("--cam="):
			cam_name = arg.trim_prefix("--cam=")
		elif arg.begins_with("--at="):
			at = clampf(float(arg.trim_prefix("--at=")), 0.0, 1.0)
	GarageLighting.build(self)
	GarageLighting.daylight(self)
	EnvMesh.add(self, EnvMesh.box(Vector3(60.0, 0.04, 60.0), 0.0),
		EnvMesh.scan("street_asphalt", "asphalt_02", {drift = 0.22, tint = Vector3(0.7, 0.7, 0.72)}), Transform3D(Basis(), Vector3(0, -0.02, 0)), false)
	var states: Array = SETS.get(set_name, SETS["look"])
	var side := cam_name == "side"
	# From the side the workers stand one behind the other, far enough apart for what they carry.
	var gap := 1.7 if side else (1.0 if set_name == "look" else 1.05)
	var span := gap * (states.size() - 1)
	for i in states.size():
		var worker := WorkerStandIn.new()
		worker.color = GameWorld.PLAYER_COLORS[i % GameWorld.PLAYER_COLORS.size()]
		worker.state = states[i]
		worker.at = at
		add_child(worker)
		worker.position = Vector3(0, 0, span * 0.5 - i * gap) if side else Vector3(-span * 0.5 + i * gap, 0, 0)
		if set_name == "look":
			worker.rotation.y = [0.5, 0.15, -0.15, PI * 0.9][i]
	var cam := Camera3D.new()
	cam.fov = 40
	add_child(cam)
	var far := maxf(3.4, span * 0.5 / 0.6 + 2.2)
	match cam_name:
		"side":
			cam.look_at_from_position(Vector3(far, 1.3, 0.3), Vector3(0, 0.95, 0.3))
		"back":
			cam.look_at_from_position(Vector3(0, 1.5, -far), Vector3(0, 0.95, 0))
		"high":
			cam.look_at_from_position(Vector3(0, 5.0, far), Vector3(0, 0.9, 0))
		"face":
			cam.fov = 22
			cam.look_at_from_position(Vector3(0, 1.72, far), Vector3(0, 1.58, 0))
		_:
			cam.look_at_from_position(Vector3(0, 1.5, far), Vector3(0, 0.95, 0))
	cam.make_current()
