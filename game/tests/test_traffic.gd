extends Node
## The town's traffic, headless: cars come up the western side street, drive down the street from
## west to east in their lane and leave by the eastern side street; they keep their distance from
## the car in front, stop for a player who stands in the road and drive on when the way is free;
## the truck waits for a car right in front of it.

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var world: GameWorld = load("res://scenes/scrap_hall.tscn").instantiate()
	add_child(world)
	await _frames(10)
	var me := world.local_player()
	var traffic := get_tree().get_first_node_in_group(TownTraffic.GROUP) as TownTraffic
	_check(traffic != null and me != null, "the quarter has traffic")
	if traffic == null or me == null:
		_finish()
		return
	# No cars of chance in this test: only the ones sent here.
	traffic._spawn_in = 100000.0
	for car: TownTraffic.Car in traffic._cars.duplicate():
		traffic._remove_car(car)
	me._do_teleport(Vector3(3.0, 0.1, 5.0))
	await _frames(5)
	# One car, the whole way.
	traffic.send_car(0)
	_check(traffic.count() == 1 and get_tree().get_nodes_in_group(TownTraffic.CAR_GROUP).size() == 1, "a car sets off")
	var start: Vector3 = traffic.cars()[0][0]
	_check(start.x < -ScrapHallSet.TOWN_X and start.z > ScrapHallSet.FRONT_Z, "out of sight, down the western side street (%.1f, %.1f)" % [start.x, start.z])
	var fastest := 0.0
	var seen_on_street := false
	var off_lane := 0.0
	var steps := 0
	while traffic.count() > 0 and steps < 3600:
		await get_tree().physics_frame
		steps += 1
		if traffic.count() == 0:
			break
		var at: Vector3 = traffic.cars()[0][0]
		fastest = maxf(fastest, float(traffic.cars()[0][2]))
		if absf(at.x) < ScrapHallSet.TOWN_X:
			seen_on_street = true
			off_lane = maxf(off_lane, absf(at.z - ScrapHallSet.TRAFFIC_LANE_Z))
	_check(seen_on_street and off_lane < 0.05, "it drives down the street in its lane (%.2f m off at most)" % off_lane)
	_check(traffic.count() == 0 and steps < 3600, "and is gone round the eastern corner after %.0f s" % (steps / 60.0))
	_check(fastest > 5.0 and fastest <= TownTraffic.CRUISE * 1.1, "never faster than the street allows (%.1f m/s)" % fastest)
	# Two cars: the second keeps its distance, even when the first has to stop for the player.
	traffic.send_car(1)
	await _frames(240)
	traffic.send_car(2)
	me._do_teleport(Vector3(6.0, 0.1, ScrapHallSet.TRAFFIC_LANE_Z))
	var closest := INF
	var stopped := false
	var nearest_to_me := INF
	for i in 1500:
		await get_tree().physics_frame
		var cars := traffic.cars()
		if cars.size() == 2:
			closest = minf(closest, absf(float(cars[0][1]) - float(cars[1][1])))
		for car: Array in cars:
			var at: Vector3 = car[0]
			if at.x < me.global_position.x:
				nearest_to_me = minf(nearest_to_me, me.global_position.x - at.x)
		if cars.size() == 2 and float(cars[0][2]) < 0.01 and float(cars[1][2]) < 0.01:
			stopped = true
			break
	_check(stopped, "both cars stop for a player who stands in the road")
	# The first car is 4.3 m long: its nose stays clear of the player.
	_check(nearest_to_me > 2.15 + 1.0, "the first one's nose stays clear of the player (%.1f m from its middle)" % nearest_to_me)
	_check(closest > 4.6 + 1.0, "the second keeps its distance (%.1f m between their middles at least)" % closest)
	# The truck waits for a car in its way.
	var truck := ScrapTruck.new()
	truck.park = Vector3(-6.0, 0, ScrapHallSet.TRAFFIC_LANE_Z)
	add_child(truck)
	truck.global_position = Vector3(-6.0, 0, ScrapHallSet.TRAFFIC_LANE_Z)
	truck.rotation.y = PI * 0.5
	var held := truck._held_up()
	truck.global_position = Vector3(-6.0, 0, ScrapHallSet.TRAFFIC_LANE_Z - 8.0)
	_check(held and not truck._held_up(), "the truck sees a car right in front of it, and none from the apron")
	truck.free()
	# The player steps off the road: they drive on and leave.
	me._do_teleport(Vector3(3.0, 0.1, 5.0))
	var gone := false
	for i in 2400:
		await get_tree().physics_frame
		if traffic.count() == 0:
			gone = true
			break
	_check(gone, "with the road free they drive on and leave")
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
	print("TRAFFIC TESTS %s (%d failures)" % ["PASSED" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures > 0 else 0)
