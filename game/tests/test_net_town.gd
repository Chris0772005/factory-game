extends Node
## Two-process test of the quarter's life. Host: `-- --host --role=host --no-save`, client:
## `-- --join=127.0.0.1 --role=client --no-save`. The client orders coffee at Molly's counter with
## [F]: the host pays from the crew's money and both have the coffee in them. The host sends a car
## down the street: the client sees it come, drive and leave.

var role := ""
var world: GameWorld
var _failures := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):
			role = arg.trim_prefix("--role=")
	world = load("res://scenes/scrap_hall.tscn").instantiate()
	add_child(world)
	_run.call_deferred()


func _run() -> void:
	var boost := CrewBoost.of(get_tree())
	var traffic := get_tree().get_first_node_in_group(TownTraffic.GROUP) as TownTraffic
	var coffee: DinerCounter = null
	for node in get_tree().get_nodes_in_group(DinerCounter.GROUP):
		if (node as DinerCounter).kind == &"coffee":
			coffee = node
	if boost == null or traffic == null or coffee == null:
		_check(false, "the quarter has a diner and traffic")
		_done()
		return
	if role == "host":
		# No cars of chance: only the one sent below.
		traffic._spawn_in = 100000.0
		for car: TownTraffic.Car in traffic._cars.duplicate():
			traffic._remove_car(car)
		_check(await _until(func(): return world.entities.get_children().filter(func(n): return n is Player).size() > 1, 20.0),
			"host: client's worker in the hall")
		world.add_money(30 - world.money)
		_check(await _until(func(): return boost.left.has(&"coffee"), 25.0), "host: the client's order came in")
		_check(world.money == 26 and is_equal_approx(CrewBoost.dig(get_tree()), 1.35), "host: paid from the crew's money, the coffee works (%d $)" % world.money)
		await _frames(60)
		traffic.send_car(0)
		_check(traffic.count() == 1, "host: a car sets off")
		_check(await _until(func(): return traffic.count() == 0, 70.0), "host: it has driven through")
		await _frames(150)
	else:
		_check(await _until(func(): return world.local_player() != null, 15.0), "client: own worker spawned")
		var me := world.local_player()
		_check(await _until(func(): return world.money == 30, 20.0), "client: sees the crew's money")
		me._do_teleport(coffee.global_position + Vector3(0, 0.05, -0.75))
		me.facing = 0.0
		await _frames(40)
		_check(me.nearest_interactable() == coffee, "client: stands at the coffee (%s)" % coffee.hint(me))
		Input.action_press(&"interact")
		await _frames(2)
		Input.action_release(&"interact")
		_check(await _until(func(): return boost.left.has(&"coffee"), 6.0), "client: F at the counter reaches the host, the coffee is in")
		_check(await _until(func(): return world.money == 26, 4.0) and is_equal_approx(CrewBoost.dig(get_tree()), 1.35),
			"client: 4 $ gone from the crew's money, digging is faster")
		_check(coffee.hint(me).contains("wirkt noch"), "client: the counter shows the time left (%s)" % coffee.hint(me))
		# The host's car.
		_check(await _until(func(): return traffic.count() == 1, 15.0), "client: sees the host's car")
		if traffic.count() == 1:
			var from: float = traffic.cars()[0][1]
			await _frames(90)
			var moved := traffic.count() == 1 and float(traffic.cars()[0][1]) > from + 3.0
			_check(moved and get_tree().get_nodes_in_group(TownTraffic.CAR_GROUP).size() == 1, "client: it drives on between the host's reports")
		_check(await _until(func(): return traffic.count() == 0, 70.0), "client: it leaves when the host's does")
	_done()


func _done() -> void:
	print("[%s] NET TOWN %s (%d failures)" % [role, "PASSED" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures else 0)


func _until(cond: Callable, timeout_s: float) -> bool:
	for i in int(timeout_s * 60):
		if cond.call():
			return true
		await get_tree().physics_frame
	return cond.call()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(ok: bool, label: String) -> void:
	print("[%s] %s %s" % [role, "ok  " if ok else "FAIL", label])
	if not ok:
		_failures += 1
