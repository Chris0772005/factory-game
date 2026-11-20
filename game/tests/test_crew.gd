extends Node
## The players' workers, headless: every player colour brings its figure with the clips the model
## blends, the bones the rig aims and a hard hat in that colour on the head; running plants the
## feet in turn; the hands reach what is carried (in front, low, high, by two handles, on a
## shaft), with bent elbows where the load is at chest height, and what they dig at; a snapshot of
## the pose freezes a second worker the same way, and a snapshot of an older kind gives the pose
## of a worker caught by the metal.

var _failures := 0
var _steps: Array[int] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var crew: Array[PlayerModel] = []
	for i in GameWorld.PLAYER_COLORS.size():
		var model := PlayerModel.new()
		model.suit_color = GameWorld.PLAYER_COLORS[i]
		add_child(model)
		model.position = Vector3(i * 3.0, 0, 0)
		crew.append(model)
	await _frames(3)
	# Figures.
	var bodies := {}
	for i in crew.size():
		var model := crew[i]
		var body := PlayerModel.body_of(model.suit_color)
		bodies[body] = true
		var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
		var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var whole := skeleton != null and player != null and model.find_child("WorkerRig", true, false) is WorkerRig
		if whole:
			for bone in WorkerRig.NAMES:
				whole = whole and skeleton.find_bone(bone) >= 0
			for bone in PlayerModel.POSE_BONES:
				whole = whole and skeleton.find_bone(bone) >= 0
			for clip: StringName in [&"Idle_Neutral", &"WalkCycle", &"RunCycle", &"Air"]:
				whole = whole and player.has_animation(clip)
		_check(whole, "player %d is the figure %s with its bones, clips and rig" % [i + 1, body])
		# The hat: its rim's middle where the figure's head is, its shell in the player's colour.
		var hat := model.find_child("HardHat", true, false) as Node3D
		var shell := model.find_child("Shell", true, false) as MeshInstance3D
		var sits := false
		if hat and shell:
			var rim := WorkerGear.SHELL_CENTER - Vector3(0, WorkerGear.HEAD_BONE_Y, 0)
			var at := model.global_transform.affine_inverse() * (hat.global_transform * rim)
			var want: Vector3 = PlayerModel.LOOKS[body].hat_at * 0.01
			var paint := (shell.material_override as StandardMaterial3D).albedo_color
			var colour := model.suit_color.lightened(0.06)
			sits = at.distance_to(want) < 0.08 and absf(paint.r - colour.r) + absf(paint.g - colour.g) + absf(paint.b - colour.b) < 0.02
			if not sits:
				print("    hat rim at ", at, ", wanted ", want, ", paint ", paint)
		_check(sits, "player %d wears a hard hat in the player's colour" % (i + 1))
	_check(bodies.size() == 2, "the four colours share two figures, a man and a woman")
	var tall := PlayerModel.height_of(GameWorld.PLAYER_COLORS[0])
	var small := PlayerModel.height_of(GameWorld.PLAYER_COLORS[1])
	_check(tall > 1.75 and tall < 1.95 and small > 1.65 and small < tall, "with the hard hat they stand %.2f m and %.2f m tall" % [tall, small])
	# Running: the feet plant in turn.
	var runner := crew[0]
	runner.footstep.connect(func(foot: int) -> void: _steps.append(foot))
	for i in 150:
		runner.animate(1.0 / 60.0, Vector3(0, 0, Player.WALK_SPEED), true, false, Vector3.ZERO)
		await get_tree().physics_frame
	var in_turn := _steps.size() >= 6
	for i in range(1, _steps.size()):
		in_turn = in_turn and _steps[i] != _steps[i - 1]
	_check(in_turn, "running plants the feet in turn (%d steps in 2.5 s)" % _steps.size())
	# Carrying: the wrists come to where the load is held.
	var holds := {
		"a load held out at chest height": {at = Vector3(0, 1.14, 0.8), bent = true},
		"a load held low, the eyes down": {at = Vector3(0, 0.55, 0.72)},
		"a load held high, the eyes up": {at = Vector3(0, 1.59, 0.72)},
		"the crucible by its two handles": {at = Vector3(0, 0.55, 0.64), grips = [Vector3(-0.3715, 0.805, 0.64), Vector3(0.3715, 0.805, 0.64)]},
		"the sledgehammer by its shaft": {at = Vector3(0, 1.14, 0.8), grips = [Vector3(0, 1.22, 0.8), Vector3(0, 1.37, 0.8)], shaft = true},
	}
	for label: String in holds:
		var hold: Dictionary = holds[label]
		for model: PlayerModel in [crew[0], crew[1]]:
			var grips: Array[Vector3] = []
			for grip: Vector3 in hold.get("grips", []):
				grips.append(model.global_transform * grip)
			model.grips = grips
			model.grips_on_handle = hold.get("shaft", false)
			for i in 70:
				model.animate(1.0 / 60.0, Vector3.ZERO, true, true, model.global_transform * (hold.at as Vector3))
				await get_tree().physics_frame
			var arms := await _arms(model)
			var reached: bool = arms.size() == 2 and arms[0].miss < 0.03 and arms[1].miss < 0.03
			var bent: bool = not hold.get("bent", false) or (arms.size() == 2 and arms[0].bend > 0.35 and arms[1].bend > 0.35)
			if not (reached and bent):
				print("    ", PlayerModel.body_of(model.suit_color), ": ", arms)
			_check(reached and bent, "%s reaches %s" % [PlayerModel.body_of(model.suit_color), label])
			for i in 30:
				model.animate(1.0 / 60.0, Vector3.ZERO, true, false, Vector3.ZERO)
				await get_tree().physics_frame
	# Digging with the bare hands: both hands get to where they go round.
	for model: PlayerModel in [crew[0], crew[1]]:
		model.grips = [] as Array[Vector3]
		model.working = true
		# Into the stance first, then four looks a third of a round apart.
		for i in 60:
			model.animate(1.0 / 60.0, Vector3.ZERO, true, false, Vector3.ZERO)
			await get_tree().physics_frame
		var worst := 0.0
		for look in 4:
			for i in 13:
				model.animate(1.0 / 60.0, Vector3.ZERO, true, false, Vector3.ZERO)
				await get_tree().physics_frame
			var arms := await _arms(model)
			for arm: Dictionary in arms:
				worst = maxf(worst, arm.miss)
		model.working = false
		_check(worst < 0.03, "%s digs with both hands where it means to (%.3f m off at worst)" % [PlayerModel.body_of(model.suit_color), worst])
		for i in 30:
			model.animate(1.0 / 60.0, Vector3.ZERO, true, false, Vector3.ZERO)
			await get_tree().physics_frame
	# The far default hold of a worker who does not aim is beyond bent arms: straight ones nearly get there.
	crew[0].grips = [] as Array[Vector3]
	for i in 70:
		crew[0].animate(1.0 / 60.0, Vector3.ZERO, true, true, crew[0].global_transform * Vector3(0, Player.HOLD_HEIGHT, Player.HOLD_DISTANCE))
		await get_tree().physics_frame
	var far := await _arms(crew[0])
	_check(far.size() == 2 and far[0].miss < 0.22 and far[1].miss < 0.22, "the far hold is nearly reached with straight arms (%.2f m short)" % (far[0].miss if far.size() == 2 else 9.9))
	# Snapshot and statue.
	var pose := crew[0].pose_data()
	_check(pose.size() == PlayerModel.POSE_SIZE and pose[0] == PlayerModel.POSE_FORMAT, "a snapshot holds the hips and %d bones" % PlayerModel.POSE_BONES.size())
	var statue := PlayerModel.new()
	statue.suit_color = crew[0].suit_color
	statue.apply_pose(pose)
	add_child(statue)
	statue.position = Vector3(0, 0, 6)
	var caught := PlayerModel.new()
	caught.apply_pose(PlayerModel.panic_pose())
	add_child(caught)
	caught.position = Vector3(3, 0, 6)
	var old := PackedFloat32Array()
	old.resize(PlayerModel.POSE_SIZE)
	old[0] = 2.0
	var elder := PlayerModel.new()
	elder.apply_pose(old)
	add_child(elder)
	elder.position = Vector3(6, 0, 6)
	await _frames(3)
	_check(statue.find_child("AnimationTree", true, false) == null and statue.find_child("WorkerRig", true, false) == null, "a posed worker stands still: no animation, no rig")
	_check(_same_pose(statue.pose_data(), pose, 0.02), "the posed worker holds the snapshot's pose")
	_check(_same_pose(elder.pose_data(), PlayerModel.panic_pose(), 0.02) and _same_pose(caught.pose_data(), PlayerModel.panic_pose(), 0.02),
		"a snapshot of an older kind gives the pose of a worker caught by the metal")
	var raised := _hands_up(caught)
	_check(raised, "caught by the metal, both hands are flung up above the head")
	_finish()


## After the rig has aimed the arms: per arm how far the wrist is from its target (m) and how
## much the elbow is bent (rad). Left, then right.
func _arms(model: PlayerModel) -> Array:
	var rig := model.find_child("WorkerRig", true, false) as WorkerRig
	var skeleton := rig.get_skeleton()
	var metres := skeleton.global_transform.basis.get_scale().y / model.global_transform.basis.get_scale().y
	var out := []
	var read := func() -> void:
		out.clear()
		for side: String in ["Left", "Right"]:
			var shoulder := skeleton.get_bone_global_pose(skeleton.find_bone(side + "Arm")).origin
			var elbow := skeleton.get_bone_global_pose(skeleton.find_bone(side + "ForeArm")).origin
			var wrist := skeleton.get_bone_global_pose(skeleton.find_bone(side + "Hand")).origin
			var target := rig.left_target if side == "Left" else rig.right_target
			out.append({miss = snappedf(wrist.distance_to(target) * metres, 0.001), bend = snappedf((elbow - shoulder).angle_to(wrist - elbow), 0.01)})
	rig.modification_processed.connect(read)
	await get_tree().process_frame
	await get_tree().process_frame
	rig.modification_processed.disconnect(read)
	return out


func _same_pose(a: PackedFloat32Array, b: PackedFloat32Array, tolerance: float) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if absf(a[i] - b[i]) > tolerance:
			return false
	return true


func _hands_up(model: PlayerModel) -> bool:
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	var head := skeleton.get_bone_global_pose(skeleton.find_bone(&"Head")).origin.y
	var left := skeleton.get_bone_global_pose(skeleton.find_bone(&"LeftHand")).origin.y
	var right := skeleton.get_bone_global_pose(skeleton.find_bone(&"RightHand")).origin.y
	return left > head and right > head


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  ok   ", label)
	else:
		_failures += 1
		print("  FAIL ", label)


func _finish() -> void:
	print("CREW TESTS %s (%d failures)" % ["PASSED" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures > 0 else 0)
