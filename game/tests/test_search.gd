extends Node
## Suchaufträge, headless (garage): a hunt hides an item on free floor, the
## warmth hint follows the distance, walking onto it finds it (reward, tally),
## a hunt nobody solves times out, and every hall tier has its own items.

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var world: GameWorld = load("res://scenes/garage.tscn").instantiate()
	add_child(world)
	await _frames(10)
	var me := world.local_player()
	var hunt: SearchHunt = get_tree().get_first_node_in_group(&"search_hunts")
	_check(hunt != null and not hunt.active, "the hall has a search hunt, idle at first")
	if hunt == null:
		_finish()
		return
	for t in SearchHunt.ITEMS.size():
		_check(SearchHunt.ITEMS[t].size() >= 4 and SearchHunt.REWARD[t] > 0, "tier %d has its own lost things" % t)
	var spots := 0
	for i in 12:
		var p := hunt._pick_spot()
		if p != Vector3.INF and absf(p.y) < 0.15 and p.distance_to(me.global_position) > 1.0:
			spots += 1
	_check(spots >= 10, "finds free hiding places by the stations (%d/12)" % spots)
	_check(hunt.start(), "a hunt starts")
	_check(hunt.active and hunt.item().has("name") and hunt.time_left > 70.0, "something is lost: %s" % hunt.item().name)
	var far := hunt.warmth(hunt.item_pos + Vector3(20, 0, 0))
	var near := hunt.warmth(hunt.item_pos + Vector3(0.5, 0, 0))
	_check(far == "eiskalt" and near == "glühend heiß!", "warmth hint: %s far away, %s next to it" % [far, near])
	var full := hunt.reward()
	hunt.time_left = 1.0
	_check(hunt.reward() < full and hunt.reward() >= SearchHunt.REWARD[hunt.tier()] / 2, "slow finders get less (%d -> %d $)" % [full, hunt.reward()])
	hunt.time_left = 60.0
	var money := world.money
	me._do_teleport(hunt.item_pos + Vector3(0.2, 0.05, 0))
	await _frames(5)
	_check(not hunt.active and world.money > money, "walking onto it finds it (+%d $)" % (world.money - money))
	_check(hunt.scores[SearchHunt.colour_index(me)] == 1, "the find goes on the finder's tally")
	_check(hunt.next_in >= SearchHunt.PAUSE.x, "the next hunt waits a while")
	me._do_teleport(Vector3(0, 0.05, 3.5))
	await _frames(3)
	_check(hunt.start(Vector3(4.5, 0, -3.0)), "a second hunt at a given spot")
	hunt.time_left = 0.05
	money = world.money
	await _frames(10)
	_check(not hunt.active and world.money == money, "unsolved hunts time out without a reward")
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
	print("SEARCH TESTS %s (%d failures)" % ["PASSED" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures > 0 else 0)
