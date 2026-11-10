extends Node
## Automation and guide, headless (garage): the conveyor carries scrap from
## its hopper into the furnace, the robot arm digs and loads it by itself,
## and Onkel Heinz's letters advance with what the crew does.

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var world: GameWorld = load("res://scenes/garage.tscn").instantiate()
	add_child(world)
	await _frames(10)
	var me := world.local_player()
	var line: ScrapLine = get_tree().get_first_node_in_group(&"scrap_lines")
	var guide: Guide = get_tree().get_first_node_in_group(&"guides")
	var pile: ScrapPile = get_tree().get_first_node_in_group(&"scrap_piles")
	_check(line != null and guide != null and pile != null, "the hall has a scrap line and a guide")
	if line == null or guide == null:
		_finish()
		return
	_check(not line.has_belt() and line.length > 1.0, "no belt before it is bought (%.1f m planned)" % line.length)
	_check(guide.index == 0 and guide.letter().goal.contains("Schrottberg"), "first letter: dig in the heap")
	var money := world.money
	for i in 3:
		guide.note(&"dig")
	await _frames(40)
	_check(guide.index == 1 and world.money > money, "three digs: goal reached, bonus paid, next letter")
	var gloves: Dictionary = world.upgrades.info(&"gloves")
	var shovel: Dictionary = world.upgrades.info(&"shovel")
	_check(gloves.cost < shovel.cost, "gloves are cheaper than the shovel (%d < %d $)" % [gloves.cost, shovel.cost])
	world.add_money(5000)
	_check(world.upgrades.buy(&"conveyor"), "conveyor bought")
	await _frames(3)
	_check(line.has_belt() and not line.has_arm(), "belt runs, no arm yet")
	var charge := line.furnace.charge.size()
	world.spawn_item(&"scrap_pipe", Color.WHITE, Vector3(0.5, 0.09, 0.09), 0.4, line.hopper_position() + Vector3(0, 0.4, 0))
	await _frames(40)
	_check(line.pieces.size() == 1, "scrap dropped into the hopper rides the belt")
	await _frames(int(line.length / ScrapLine.BELT_SPEED * 60.0) + 30)
	_check(line.pieces.is_empty() and line.furnace.charge.size() == charge + 1, "and falls into the furnace")
	_check(world.upgrades.buy(&"robot_arm"), "grab arm bought")
	var stock := pile.stock
	charge = line.furnace.charge.size()
	await _frames(60 * 9)
	_check(pile.stock < stock and line.furnace.charge.size() + line.pieces.size() > charge,
		"the arm digs and loads by itself (heap %d -> %d, furnace +%d)" % [stock, pile.stock, line.furnace.charge.size() - charge])
	_check(me.global_position.distance_to(line.hopper_position()) > 0.5, "worker is not stuck in the line")
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
	print("AUTO TESTS %s (%d failures)" % ["PASSED" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures > 0 else 0)
