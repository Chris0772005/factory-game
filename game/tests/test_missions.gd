extends Node
## Growing the yard, headless: missions that never run out (three tracks,
## rewards, rising goals), the workbench that turns junk into weapons, the
## excavator that loads the skip, Kowalski's cart and the truck that hauls
## full skips away.

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var world: GameWorld = load("res://scenes/scrap_hall.tscn").instantiate()
	add_child(world)
	await _frames(10)
	var me := world.local_player()
	var missions := Missions.of(get_tree())
	var heap := get_tree().get_first_node_in_group(&"scrap_piles") as ScrapMountain
	var bucket := get_tree().get_first_node_in_group(&"scrap_buckets") as ScrapBucket
	_check(missions != null and heap != null and bucket != null and me != null, "the hall has missions, the heap and a bucket")
	if missions == null or heap == null or bucket == null:
		_finish()
		return
	heap.hot_share = 0.0
	# No cars on the street here: the truck's trip is timed below.
	var traffic := get_tree().get_first_node_in_group(TownTraffic.GROUP) as TownTraffic
	if traffic:
		traffic.free()
	# Three missions run side by side.
	var first := missions.current(0)
	_check(first.stat == &"dig" and first.goal == 15 and missions.current(1).stat == &"earned" and missions.current(2).stat == &"hot_sold", "three tracks: dig, earn, sell under the counter")
	var money := world.money
	missions.note(&"dig", 14)
	_check(missions.current(0).progress == 14 and world.money == money, "progress counts, nothing paid yet")
	missions.note(&"dig", 1)
	_check(world.money == money + 20 and missions.total == 1 and missions.current(0).is_empty(), "the mission pays its reward and the next one is on its way")
	await _frames(int(Missions.NEXT_DELAY * 60) + 10)
	_check(missions.current(0).stat == &"scrap_sold", "next on the track: sell scrap")
	# What needs an upgrade is skipped until it is owned; rounds ask for more.
	missions.done[0] = 3
	_check(missions.current(0).stat == &"parcel", "after the police the post office's mail orders")
	missions.done[0] = 4
	_check(missions.current(0).stat == &"heap", "no foundry yet: the casting mission is skipped")
	missions.done[0] = 6
	missions.progress[0] = 0
	var again := missions.current(0)
	_check(again.stat == &"dig" and again.goal == 24 and again.reward == 30, "second round: more to do, more pay (%d, %d $)" % [again.goal, again.reward])
	# Saving and loading.
	var saved := missions.to_save()
	missions.done[0] = 0
	missions.load_save(saved)
	_check(missions.done[0] == 6, "missions survive saving")
	# Workbench: recipes.
	var plan := Workbench.plan([&"junk_sheet", &"junk_sheet", &"junk_sheet", &"scrap_pipe", &"junk_spring", &"junk_bolt", &"scrap_can"])
	_check(plan.made == [&"hot_zipgun", &"hot_shiv"] and plan.rest == [&"junk_sheet", &"scrap_can"], "the bench builds a pipe gun and a blade, the rest stays (%s)" % str(plan.made))
	_check(not world.upgrades.can_buy(&"truck"), "no truck without the excavator")
	world.add_money(5000)
	_check(world.upgrades.buy(&"workbench"), "the workbench can be bought")
	await _frames(5)
	var bench := get_tree().get_first_node_in_group(Workbench.GROUP) as Workbench
	_check(bench != null, "the workbench stands in the hall")
	bucket.contents = [&"junk_gear", &"junk_gear", &"junk_bolt"] as Array[StringName]
	bucket._changed()
	me._do_teleport(bench.global_position + Vector3(0, 0.05, 1.4))
	bucket.global_position = me.global_position + Vector3(0.5, 0.3, 0)
	await _frames(3)
	me.grab(bucket)
	await _frames(3)
	bucket.use_start(me)
	_check(bucket.hot == 1 and bucket.count == 2 and bucket.contents.has(&"hot_gearknuckle"), "F with the bucket at the bench: two gears become a knuckle duster")
	_check(not TownLaw.carried_hot(me).is_empty(), "what the bench makes is contraband")
	me.release()
	# Excavator and skip.
	_check(world.upgrades.buy(&"excavator"), "the excavator can be bought")
	await _frames(5)
	var skip := get_tree().get_first_node_in_group(ScrapSkip.GROUP) as ScrapSkip
	var digger := get_tree().get_first_node_in_group(Excavator.GROUP) as Excavator
	_check(skip != null and digger != null, "excavator and skip stand in the hall")
	var stock := heap.stock
	await _frames(int(Excavator.CYCLE * 60) + 30)
	_check(skip.count == Excavator.SCOOP and heap.stock == stock - Excavator.SCOOP, "one cycle: a scoop from the heap lands in the skip (%d)" % skip.count)
	# The bucket can be tipped in; hot goods stay out.
	bucket.contents = [&"junk_gear", &"hot_pistol", &"scrap_pipe"] as Array[StringName]
	bucket._changed()
	me._do_teleport(skip.global_position + Vector3(0, 0.05, 2.0))
	bucket.global_position = me.global_position + Vector3(0.5, 0.3, 0)
	await _frames(3)
	me.grab(bucket)
	await _frames(3)
	var in_skip := skip.count
	bucket.use_start(me)
	_check(skip.count == in_skip + 2 and bucket.count == 1 and bucket.hot == 1, "tipping the bucket into the skip keeps the hot goods")
	me.release()
	# Kowalski's cart: F at the skip, he keeps a fifth.
	digger.set_physics_process(false)
	money = world.money
	var worth := skip.worth
	skip.interact(me)
	_check(skip.count == 0 and world.money >= money + roundi(worth * ScrapSkip.CART_SHARE), "without a truck Kowalski fetches the load for 80 %")
	# The truck hauls a full skip by itself, at wholesale.
	_check(world.upgrades.buy(&"truck"), "with the excavator the truck is on sale")
	await _frames(5)
	var truck := get_tree().get_first_node_in_group(ScrapTruck.GROUP) as ScrapTruck
	_check(truck != null and not truck.busy(), "the truck is parked in front of the hall")
	var load := []
	for i in ScrapSkip.CAPACITY:
		load.append(&"junk_gear")
	skip.add(load)
	money = world.money
	await _frames(5)
	_check(truck.busy(), "a full skip sends the truck on its way")
	var legs := truck._legs()
	await _frames(int((legs[0] + legs[1]) * 60) + 20)
	_check(skip.count == 0 and world.money >= money + roundi(180 * ScrapSkip.TRUCK_SHARE), "it takes the load and pays wholesale (+%d $)" % (world.money - money))
	await _frames(int((legs[2] + legs[3] + legs[4]) * 60) + 30)
	_check(not truck.busy() and truck.global_position.distance_to(ScrapHallSet.TRUCK_PARK) < 0.1, "and comes back to its parking spot")
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
	print("MISSIONS TESTS %s (%d failures)" % ["PASSED" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures > 0 else 0)
