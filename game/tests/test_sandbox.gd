extends SceneTree
## Headless gameplay checks: run with
## godot --headless --path game -s tests/test_sandbox.gd

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: Node3D = load("res://scenes/sandbox.tscn").instantiate()
	root.add_child(scene)
	await _frames(30)
	var player: Player = scene.player
	var start := player.global_position

	# Walk towards the crates (they are at z=2, player starts at z=5 facing -Z).
	Input.action_press(&"move_forward")
	await _frames(40)
	Input.action_release(&"move_forward")
	await _frames(20)
	_check(player.global_position.z < start.z - 1.0, "player walks forward (z %.2f -> %.2f)" % [start.z, player.global_position.z])

	Input.action_press(&"grab")
	await _frames(2)
	Input.action_release(&"grab")
	await _frames(40)
	_check(player.held != null, "player grabs a crate")
	if player.held:
		var body := player.held
		var hand := player._hand_target()
		_check(body.global_position.distance_to(hand) < 0.8, "held crate follows the hand (dist %.2f)" % body.global_position.distance_to(hand))
		var before := body.global_position
		Input.action_press(&"throw")
		await _frames(2)
		Input.action_release(&"throw")
		await _frames(45)
		_check(player.held == null, "throw releases the crate")
		_check(body.global_position.distance_to(before) > 1.5, "thrown crate flies away (%.2f m)" % body.global_position.distance_to(before))

	# Heavy crate (25 kg): one worker's arms are too weak to lift it, two together can.
	player.release()
	var heavy := Item.create(&"heavy", Color("#7a5c3e"), 0.6)
	heavy.mass = 25.0
	scene.add_child(heavy)
	heavy.global_position = Vector3(8, 0.3, 8)
	await _frames(30)
	var helper := Player.new()
	helper.name = "Helper"
	scene.add_child(helper)
	helper.global_position = heavy.global_position + Vector3(-0.5, -0.3, 0.9)
	helper.facing = PI
	await _frames(10)
	helper.grab(heavy)
	await _frames(90)
	var solo_height := heavy.global_position.y
	player.global_position = heavy.global_position + Vector3(0.5, -0.3, 0.9)
	player.global_position.y = 0.0
	player.facing = PI
	await _frames(5)
	player.grab(heavy)
	await _frames(120)
	var team_height := heavy.global_position.y
	print("heavy crate height solo=%.2f team=%.2f" % [solo_height, team_height])
	_check(solo_height < 0.45, "one worker cannot lift the heavy crate")
	_check(team_height > 0.55, "two workers lift the heavy crate together")

	print("TESTS %s (%d failures)" % ["PASSED" if _failures == 0 else "FAILED", _failures])
	quit(1 if _failures else 0)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		_failures += 1
