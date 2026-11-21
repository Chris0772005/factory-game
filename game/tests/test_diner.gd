extends Node
## Molly's diner, headless: the house between the shops is walked into through its door; at the
## counter coffee and a hot stew are ordered for the whole crew. Coffee makes the heap give way
## faster, the stew makes everybody quicker on their feet, each for a while. Without the money
## nothing is served, nobody pays twice while plenty is left, and the first order ticks off a
## mission. The seven people of the quarter walk their rounds without passing through a wall,
## a counter, a stool or the furniture of the two new shops.

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var world: GameWorld = load("res://scenes/scrap_hall.tscn").instantiate()
	add_child(world)
	await _frames(10)
	var me := world.local_player()
	var boost := CrewBoost.of(get_tree())
	var heap := get_tree().get_first_node_in_group(&"scrap_piles") as ScrapMountain
	var missions := Missions.of(get_tree())
	var places := {}
	for node in get_tree().get_nodes_in_group(DinerCounter.GROUP):
		places[(node as DinerCounter).kind] = node
	_check(boost != null and me != null and heap != null and missions != null and places.size() == 2 and places.has(&"coffee") and places.has(&"meal"),
		"the quarter has a diner with a place for coffee and one for the stew")
	if boost == null or me == null or heap == null or missions == null or places.size() != 2:
		_finish()
		return
	# Nothing drives or patrols through this test.
	var traffic := get_tree().get_first_node_in_group(TownTraffic.GROUP) as TownTraffic
	if traffic:
		traffic.free()
	for cop in get_tree().get_nodes_in_group(PolicePatrol.GROUP):
		(cop as Node).set_physics_process(false)
	var coffee := places[&"coffee"] as DinerCounter
	var meal := places[&"meal"] as DinerCounter
	var diner := ScrapHallSet.DINER
	var door_x := diner.x + ScrapHallSet.DINER_DOOR_X
	# In through the door, not through the wall beside it.
	var outside := Transform3D(Basis(), Vector3(door_x, 0.06, ScrapHallSet.FRONT_Z - 1.3))
	_check(not me.test_move(outside, Vector3(0, 0, 2.6)), "the door is open: from the pavement straight into the room")
	var beside := Transform3D(Basis(), Vector3(diner.x - 2.0, 0.06, ScrapHallSet.FRONT_Z - 1.3))
	_check(me.test_move(beside, Vector3(0, 0, 2.6)), "beside the door the front wall is solid")
	var inside := Transform3D(Basis(), Vector3(door_x, 0.06, ScrapHallSet.FRONT_Z + 1.3))
	_check(not me.test_move(inside, Vector3(coffee.global_position.x - door_x, 0, 0)) and me.test_move(inside, Vector3(0, 0, ScrapHallSet.COUNTER_Z)),
		"inside, the way to the counter is free and the counter is solid")
	me._do_teleport(coffee.global_position + Vector3(0, 0.06, -0.75))
	await _frames(5)
	_check(coffee.in_reach(me) and meal.in_reach(me) and me.global_position.y < 0.3, "at the counter both orders are in reach")
	# Without the money nothing is served.
	world.add_money(-world.money)
	var base_dig := heap.dig_speed()
	coffee.interact(me)
	_check(boost.left.is_empty() and world.money == 0 and is_equal_approx(heap.dig_speed(), base_dig), "no money, no coffee")
	_check(coffee.hint(me).contains("reicht das Geld"), "the counter says so (%s)" % coffee.hint(me))
	# Coffee: paid once, the whole crew digs faster; the first order is a mission.
	missions.done[1] = 2
	missions.progress[1] = 0
	_check(missions.current(1).stat == &"diner", "after the first upgrade the missions send the crew to Molly")
	world.add_money(20)
	_check(coffee.hint(me).contains("[F]") and coffee.hint(me).contains("4 $"), "with money the counter offers the coffee (%s)" % coffee.hint(me))
	var done := missions.total
	coffee.interact(me)
	_check(is_equal_approx(float(boost.left.get(&"coffee", 0.0)), 180.0) and world.money == 20 - 4 + 15 and missions.total == done + 1,
		"coffee for the crew: 4 $ paid, three minutes on the clock, the mission pays 15 $ (%d $)" % world.money)
	_check(is_equal_approx(CrewBoost.dig(get_tree()), 1.35) and is_equal_approx(heap.dig_speed(), base_dig * 1.35) and is_equal_approx(CrewBoost.walk(get_tree()), 1.0),
		"with coffee the heap gives way a third faster, the legs are as before")
	var money := world.money
	coffee.interact(me)
	_check(world.money == money and coffee.hint(me).contains("wirkt noch"), "nobody pays twice while plenty is left (%s)" % coffee.hint(me))
	# The stew: quicker on the feet.
	var slow := await _walking_speed(me)
	me._do_teleport(meal.global_position + Vector3(0, 0.06, -0.75))
	await _frames(5)
	meal.interact(me)
	_check(world.money == money - 12 and is_equal_approx(float(boost.left.get(&"meal", 0.0)), 240.0), "the stew: 12 $ paid, four minutes on the clock")
	var fast := await _walking_speed(me)
	_check(is_equal_approx(CrewBoost.walk(get_tree()), 1.15) and absf(slow - Player.WALK_SPEED) < 0.05 and absf(fast - Player.WALK_SPEED * 1.15) < 0.06,
		"with the stew everybody walks faster (%.2f m/s, then %.2f m/s)" % [slow, fast])
	_check(is_equal_approx(CrewBoost.dig(get_tree()), 1.35), "coffee and stew work side by side")
	# Both run out.
	boost.left[&"coffee"] = 0.05
	await _frames(6)
	_check(not boost.left.has(&"coffee") and is_equal_approx(heap.dig_speed(), base_dig) and is_equal_approx(CrewBoost.walk(get_tree()), 1.15), "the coffee wears off, the stew is still in")
	boost.left[&"meal"] = 0.05
	await _frames(6)
	_check(boost.left.is_empty() and is_equal_approx(CrewBoost.walk(get_tree()), 1.0), "and then the stew")
	_check(coffee.hint(me).contains("[F]"), "the next coffee can be ordered")
	# The people of the quarter: seven rounds (five passers-by and the two who buy at the crew's stall),
	# none through a wall, a counter, a stool or a shop's furniture.
	var walkers := world.find_child("TownWalkers", true, false) as TownWalkers
	_check(walkers != null and walkers._rounds.size() == 7, "seven people walk their rounds")
	if walkers:
		var space := world.get_world_3d().direct_space_state
		var ball := SphereShape3D.new()
		ball.radius = 0.2
		var blocked := []
		var into_diner := 0
		# (Whoever walks about is given way to: only what stands for good counts here.)
		var others: Array[RID] = [me.get_rid()]
		for cop in get_tree().get_nodes_in_group(PolicePatrol.GROUP):
			if cop is CollisionObject3D:
				others.append((cop as CollisionObject3D).get_rid())
		for i in walkers._rounds.size():
			for leg: Array in walkers._rounds[i].legs:
				var from: Vector3 = leg[3]
				var to: Vector3 = leg[4]
				var query := PhysicsShapeQueryParameters3D.new()
				query.shape = ball
				query.transform = Transform3D(Basis(), from + Vector3(0, 0.9, 0))
				query.motion = to - from
				query.exclude = others
				var free: PackedFloat32Array = space.cast_motion(query)
				if free[0] < 1.0:
					blocked.append("round %d: %s -> %s stops at %.0f %%" % [i + 1, from, to, free[0] * 100.0])
				if absf(to.x - diner.x) < 4.5 and to.z > ScrapHallSet.FRONT_Z + 2.0:
					into_diner += 1
		for line: String in blocked:
			print("    ", line)
		_check(blocked.is_empty(), "every leg of every round is free (%d blocked)" % blocked.size())
		_check(into_diner == 3, "three of them come to the diner's counter")
	_finish()


## The speed the player reaches walking straight ahead on the apron (m/s).
func _walking_speed(me: Player) -> float:
	me._do_teleport(Vector3(3.0, 0.1, 5.0))
	await _frames(20)
	Input.action_press(&"move_forward")
	await _frames(24)
	var speed := Vector2(me.velocity.x, me.velocity.z).length()
	Input.action_release(&"move_forward")
	await _frames(12)
	return speed


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
	print("DINER TESTS %s (%d failures)" % ["PASSED" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures > 0 else 0)
