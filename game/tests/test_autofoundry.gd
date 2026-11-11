extends Node
## Full automation, headless (garage): blower, self-ramming molds, the rail
## ladle, shake-out and shipping - bought one by one, each takes over its
## step, and in the end the hall earns money with nobody touching anything.

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var world: GameWorld = load("res://scenes/garage.tscn").instantiate()
	add_child(world)
	await _frames(10)
	var auto: AutoFoundry = get_tree().get_first_node_in_group(&"auto_foundries")
	_check(auto != null and auto.molds.size() == 2 and auto.crate != null, "the garage has its automation (2 molds, crate)")
	if auto == null:
		_finish()
		return
	var furnace := auto.furnace
	var mold := auto.molds[0]
	var pot: Crucible = get_tree().get_first_node_in_group(&"crucibles")
	pot.global_position = furnace.global_position + Vector3(0, 0.35, 0)
	pot.linear_velocity = Vector3.ZERO
	for i in 8:
		furnace.charge.append(&"scrap_can")
	await _frames(90)
	_check(furnace.crucible == pot, "crucible sits in the furnace")
	_check(furnace.heat < 0.05 and pot.amount == 0.0, "without the blower nothing heats")
	world.add_money(30000)
	_check(world.upgrades.buy(&"auto_bellows"), "blower bought")
	await _frames(60 * 14)
	_check(furnace.heat > 0.8 and pot.amount > 0.5, "blower heats and the scrap melts (heat %.2f, %.1f l)" % [furnace.heat, pot.amount])
	mold.add_pattern(DrawingSamples.star().to_code())
	await _frames(60 * 6)
	_check(mold.state == MoldBox.State.PATTERNED, "without the rammer the mold waits")
	_check(world.upgrades.buy(&"auto_rammer"), "rammer bought")
	await _frames(int(AutoFoundry.RAM_TIME * 60.0) + 30)
	_check(mold.state == MoldBox.State.RAMMED, "the mold rams itself")
	_check(world.upgrades.buy(&"auto_pour"), "rail ladle bought")
	var waited := 0
	while mold.state < MoldBox.State.COOLING and waited < 60 * 40:
		await _frames(10)
		waited += 10
	_check(mold.state == MoldBox.State.COOLING, "the ladle fetches melt and fills the mold (%.1f s)" % (waited / 60.0))
	await _frames(int(mold.cool_time * 60.0) + 120)
	_check(mold.state == MoldBox.State.READY, "cooled, waits for the hammer")
	_check(world.upgrades.buy(&"auto_breaker"), "shake-out bought")
	await _frames(int(AutoFoundry.BREAK_DELAY * 60.0) + 60)
	var castings := get_tree().get_nodes_in_group(&"castings").size()
	_check(castings >= 1, "the mold shakes itself out (%d casting)" % castings)
	var money := world.money
	_check(world.upgrades.buy(&"auto_ship"), "shipping bought")
	money = world.money
	await _frames(60 * 12)
	_check(world.money > money, "the casting flies into the crate and is sold (+%d $)" % (world.money - money))
	# The whole loop with the scrap line: hands off.
	world.upgrades.buy(&"conveyor")
	world.upgrades.buy(&"robot_arm")
	await _frames(60 * 5)
	money = world.money
	var cycles := 0
	var was_cooling := false
	waited = 0
	while cycles < 2 and waited < 60 * 240:
		await _frames(30)
		waited += 30
		var cooling := mold.state == MoldBox.State.COOLING
		if cooling and not was_cooling:
			cycles += 1
		was_cooling = cooling
	await _frames(60 * 25)
	# Switch the first mold off: it stops re-forming, so a new pattern fits.
	var sw: AutoSwitch = auto.get_children().filter(func(n: Node) -> bool: return n is AutoSwitch)[0]
	sw.interact(null)
	while mold.state != MoldBox.State.EMPTY and waited < 60 * 400:
		await _frames(30)
		waited += 30
	await _frames(int(AutoFoundry.REPATTERN_TIME * 60.0) + 120)
	_check(not auto.enabled[0] and mold.state == MoldBox.State.EMPTY, "switched off: the mold stays empty for a new pattern")
	sw.interact(null)
	mold.add_pattern(DrawingSamples.smiley().to_code())
	await _frames(int(AutoFoundry.RAM_TIME * 60.0) + 60)
	_check(auto.enabled[0] and mold.state >= MoldBox.State.RAMMED, "switched on again: the new pattern is rammed")
	_check(cycles >= 2 and world.money >= money + 50, "hands off: %d more casts, +%d $ in %.0f s" % [cycles, world.money - money, waited / 60.0 + 25.0])
	_finish()


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
	print("AUTOFOUNDRY TESTS %s (%d failures)" % ["PASSED" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures > 0 else 0)
