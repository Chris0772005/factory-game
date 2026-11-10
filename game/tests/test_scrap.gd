extends Node
## Schrottberg, headless (garage): digging by holding F throws finds out,
## tools speed it up, the magnet doubles the haul, the detector favours rare
## finds, the heap runs low and restocks; an aiming worker grabs what they
## look at.

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _scrap(world: GameWorld) -> int:
	return world.entities.get_children().filter(func(n): return n is Item and FoundryRules.SCRAP.has((n as Item).kind)).size()


func _run() -> void:
	var world: GameWorld = load("res://scenes/garage.tscn").instantiate()
	add_child(world)
	await _frames(10)
	var me := world.local_player()
	var pile: ScrapPile = get_tree().get_first_node_in_group(&"scrap_piles")
	_check(pile != null and pile.stock == ScrapPile.STOCK_MAX, "the hall has a full scrap heap")
	if pile == null:
		_finish()
		return
	me._do_teleport(pile.global_position + Vector3(0, 0.05, 1.3))
	await _frames(3)
	var before := _scrap(world)
	pile.interact(me)
	_check(pile.progress > 0.0 and _scrap(world) == before, "one press only starts a dig (%d %%)" % roundi(pile.progress * 100))
	var bare := 0
	while _scrap(world) == before and bare < 400:
		pile.interact_tick(me, 1.0 / 60.0)
		bare += 1
	_check(_scrap(world) == before + 1 and pile.stock == ScrapPile.STOCK_MAX - 1, "bare hands dig one find out (%d ticks)" % bare)
	world.upgrades.load_save(["gloves", "shovel", "magnet"])
	before = _scrap(world)
	var tooled := 0
	while _scrap(world) == before and tooled < 400:
		pile.interact_tick(me, 1.0 / 60.0)
		tooled += 1
	_check(tooled < bare * 0.55, "gloves and shovel dig much faster (%d vs %d ticks)" % [tooled, bare])
	_check(_scrap(world) == before + 2, "the magnet pulls two pieces per dig")
	var rare := 0
	var rare_detector := 0
	for i in 3000:
		if ScrapPile.RARE.has(pile._roll()):
			rare += 1
	world.upgrades.load_save(["detector"])
	for i in 3000:
		if ScrapPile.RARE.has(pile._roll()):
			rare_detector += 1
	_check(rare_detector > rare * 1.6, "the detector finds rare things more often (%d vs %d of 3000)" % [rare_detector, rare])
	for kind in ScrapPile.WEIGHTS:
		_check(FoundryRules.SCRAP.has(kind), "%s is a known scrap kind" % kind)
	pile.stock = 0
	before = _scrap(world)
	for i in 200:
		pile.interact_tick(me, 1.0 / 60.0)
	_check(_scrap(world) == before and pile.hint(me).contains("Nachschub"), "a dug-through heap gives nothing")
	pile._restock = ScrapPile.RESTOCK_EVERY - 0.05
	await _frames(10)
	_check(pile.stock == 1, "the heap is restocked over time")
	# Aiming: look down at a piece on the floor and grab it.
	await _frames(60)
	var piece := world.spawn_item(&"scrap_can", Color.WHITE, Vector3(0.14, 0.24, 0.14), 0.4, Vector3(0, 0.15, 2.0))
	me._do_teleport(Vector3(0, 0.05, 3.2))
	me.facing = PI
	me.rotation.y = PI
	await _frames(30)
	me.aims = true
	me.look_pitch = -0.9
	var want := me.eye_position() + me.look_direction() * 1.15
	_check(want.distance_to(piece.global_position) < 0.9, "looking down points at the floor in front (%.2f m off)" % want.distance_to(piece.global_position))
	_check(me.grab_candidate() == piece, "an aiming worker grabs what they look at")
	me.grab(piece)
	await _frames(60)
	_check(me.global_position.y < 0.2 and piece.global_position.y > 0.4, "carried low, it never gets under the carrier's feet")
	me.look_pitch = 0.2
	await _frames(60)
	_check(piece.global_position.y > 1.0 and piece.global_position.y < 2.0 and me.global_position.y < 0.2,
		"the held piece follows the view up (y %.2f)" % piece.global_position.y)
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
	print("SCRAP TESTS %s (%d failures)" % ["PASSED" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures > 0 else 0)
