extends Node
## Eisenhalle hands off: feeder belt, blower control and floor channel keep
## the mold line casting series by itself; bronze in the hearth is left alone.

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var world: GameWorld = load("res://scenes/iron_hall.tscn").instantiate()
	add_child(world)
	await _frames(10)
	var auto: AutoIron = get_tree().get_first_node_in_group(&"auto_irons")
	_check(auto != null, "the iron hall has its automation")
	if auto == null:
		_finish()
		return
	var cupola := auto.cupola
	var line := auto.line
	world.add_money(60000)
	for id in [&"auto_molder", &"auto_pourer"]:
		world.upgrades.buy(id)
	line.set_pattern(DrawingSamples.star().to_code())
	await _frames(60 * 8)
	_check(cupola.charge.is_empty() and cupola.bath == 0.0 and cupola.heat < 0.05, "nothing happens before the machines are bought")
	_check(world.upgrades.buy(&"auto_charger"), "feeder belt bought")
	await _frames(60 * 7)
	_check(cupola.charge.size() >= 1, "the belt charges the cupola (%d charges)" % cupola.charge.size())
	_check(world.upgrades.buy(&"auto_blast"), "blower control bought")
	await _frames(60 * 12)
	_check(cupola.heat > 0.8 and cupola.bath > 1.0, "the blower runs and iron melts (heat %.2f, %.0f l)" % [cupola.heat, cupola.bath])
	_check(line.tundish < 0.1, "without the channel the pouring box stays empty")
	_check(world.upgrades.buy(&"auto_tap"), "floor channel bought")
	await _frames(60 * 6)
	_check(line.tundish > 1.0, "the channel fills the pouring box (%.1f l)" % line.tundish)
	var money := world.money
	var waited := 0
	while world.money < money + 100 and waited < 60 * 180:
		await _frames(60)
		waited += 60
	_check(world.money >= money + 100, "hands off: the line casts and sells (+%d $ in %d s)" % [world.money - money, waited / 60])
	# Bronze for a bell: the automation must not touch it.
	auto.interact(null)
	_check(not auto.enabled, "the cabinet switches the iron automation off")
	cupola.mix = {&"copper": 30.0}
	cupola.bath = 30.0
	auto.interact(null)
	await _frames(60 * 4)
	_check(auto.enabled and cupola.bath > 29.9, "bronze in the hearth is not pumped into the line (%.1f l)" % cupola.bath)
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
	print("AUTOIRON TESTS %s (%d failures)" % ["PASSED" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures > 0 else 0)
