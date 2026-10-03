extends Node
## Factory simulation checks (offline).

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var world: GameWorld = load("res://scenes/factory_test.tscn").instantiate()
	add_child(world)
	await _frames(60 * 12)
	var f := world.factory
	print("money=%d items_on_belts=%d" % [world.money, f.count_items()])
	_check(world.money > 0, "smelted ingots get sold (money %d)" % world.money)
	var spilled := world.entities.get_children().filter(func(n): return n is Item and n.kind == &"ore")
	_check(spilled.size() >= 4, "overflow belt spills ore as physics items (%d)" % spilled.size())
	var player := world.local_player()
	player.global_position = Vector3(-3, 0.1, 1.2)
	player.facing = PI
	await _frames(5)
	var before := f.count_items()
	player.try_grab()
	await _frames(5)
	_check(player.held != null and player.held.kind == &"ore", "worker picks an ore off a running belt")
	_check(f.count_items() < before + 2, "picked item left the belt simulation")
	var held := player.held
	player.release()
	held.global_position = f.item_position(Vector2i(2, 0), f.belts[Vector2i(2, 0)], 0.5) + Vector3(0, 0.4, 0)
	held.linear_velocity = Vector3.ZERO
	await _frames(40)
	_check(not is_instance_valid(held), "ore dropped onto a belt rejoins the simulation")
	# Stress: fill many belts and measure the simulation cost.
	for y in range(10, 40):
		for x in range(-15, 15):
			f.add_belt(Vector2i(x, y), 0)
	for y in range(10, 40):
		for x in range(-15, 15):
			for p in [0.0, 0.34, 0.68]:
				f.insert(Vector2i(x, y), &"ore", p)
	await _frames(10)
	var t0 := Time.get_ticks_usec()
	for i in 30:
		f._step(1.0 / 60.0)
	var step_ms := (Time.get_ticks_usec() - t0) / 30000.0
	t0 = Time.get_ticks_usec()
	for i in 10:
		f._render()
	var render_ms := (Time.get_ticks_usec() - t0) / 10000.0
	print("stress: %d items, step %.2f ms, render prep %.2f ms" % [f.count_items(), step_ms, render_ms])
	_check(step_ms < 8.0, "belt step stays cheap with %d items" % f.count_items())
	print("TESTS %s (%d failures)" % ["PASSED" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures else 0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		_failures += 1
