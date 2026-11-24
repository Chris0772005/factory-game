extends Node
## The hands for hire, headless (scrap hall): three wait in the labour exchange beyond Mill Street.
## [F] hires for a fee; the hand walks to the yard on its own and works there for a wage per minute:
## the digger digs into the bucket by the heap, the runner empties the bucket and carries the load
## to the dealer (what is rare goes on the crew's stall; once the crew melts its own metal he takes
## the junk only), the stall keeper makes the customers buy more and pay more and lays out finds
## from a bucket beside the table. Without money for the wage a hand stops and waits; [F] twice
## sends it home. Who is hired goes into the save file.

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var world: FoundryLevel = load("res://scenes/scrap_hall.tscn").instantiate()
	add_child(world)
	await _frames(10)
	var me := world.local_player()
	var missions := Missions.of(get_tree())
	var digger := HiredHand.of(get_tree(), &"digger")
	var runner := HiredHand.of(get_tree(), &"runner")
	var keeper := HiredHand.of(get_tree(), &"keeper")
	var heap := get_tree().get_first_node_in_group(&"scrap_piles") as ScrapPile
	var bucket := get_tree().get_first_node_in_group(&"scrap_buckets") as ScrapBucket
	var stall := get_tree().get_first_node_in_group(YardStall.GROUP) as YardStall
	_check(me != null and missions != null and digger != null and runner != null and keeper != null and heap != null and bucket != null and stall != null,
		"the scrap hall has three hands for hire, a heap, a bucket and the crew's stall")
	if me == null or missions == null or digger == null or runner == null or keeper == null or heap == null or bucket == null or stall == null:
		_finish()
		return
	# Nothing drives, patrols or buys by chance in this test; no mission pays into the sums below.
	var traffic := get_tree().get_first_node_in_group(TownTraffic.GROUP) as TownTraffic
	if traffic:
		traffic.free()
	for cop in get_tree().get_nodes_in_group(PolicePatrol.GROUP):
		(cop as Node).set_physics_process(false)
	stall.set_physics_process(false)
	missions.done = [5, 4, 2] as Array[int]
	missions.progress = [0, 0, 0] as Array[int]
	await _hiring(world, me, digger, runner, keeper)
	await _digging(world, digger, heap, bucket)
	await _wages(world, digger, missions)
	await _going_home(world, me, digger)
	await _running(world, me, runner, bucket, stall)
	await _keeping(world, me, keeper, runner, bucket, stall)
	_saving(world, digger, runner, keeper)
	_finish()


func _hiring(world: FoundryLevel, me: Player, digger: HiredHand, runner: HiredHand, keeper: HiredHand) -> void:
	var lot := TownShops.labour_lot().affine_inverse()
	var inside := true
	for hand: HiredHand in [digger, runner, keeper]:
		var at := lot * hand.global_position
		inside = inside and hand.state == HiredHand.State.WAITING and absf(at.x) < 5.2 and at.z > 0.4 and at.z < 6.3
	_check(inside, "all three wait inside the labour exchange")
	_check(digger.name == &"Hand_digger" and runner.name == &"Hand_runner" and keeper.name == &"Hand_keeper",
		"each has a name of its own (the same path on every machine)")
	_check(digger.is_in_group(&"interactable") and digger.is_in_group(TownWalkers.GROUP), "they can be spoken to, and cars stop for them")
	_check("fehlen" in digger.hint(me) and "60 $" in digger.hint(me), "without money the hint says what is missing: %s" % digger.hint(me))
	digger.interact(me)
	_check(digger.state == HiredHand.State.WAITING and world.money == 0, "nobody is hired without the fee")
	world.add_money(500)
	_check(digger.hint(me).begins_with("[F] Hugo anheuern") and "8 $ pro Minute" in digger.hint(me), "with money: %s" % digger.hint(me))
	digger.interact(me)
	_check(digger.state == HiredHand.State.COMING and world.money == 440, "[F] hires Hugo for 60 $ and he sets off")
	_check(HiredHand.count(get_tree()) == 1 and HiredHand.to_save(get_tree()) == ["digger"], "he counts as hired at once (and goes into the save)")
	# The way: out of the door, over Mill Street, along the far pavement, over the zebra crossing.
	var frames := 0
	var furthest_north := 0.0
	while digger.state == HiredHand.State.COMING and frames < 60 * 70:
		await get_tree().physics_frame
		frames += 1
		furthest_north = maxf(furthest_north, digger.global_position.z)
	_check(digger.state == HiredHand.State.WORKING, "he arrives at the yard on his own (%.0f s)" % (frames / 60.0))
	_check(frames < 60 * 45 and furthest_north < 23.5, "in good time and along the street, not through the houses (%.1f)" % furthest_north)
	_check(digger.yard.has_point(Vector2(digger.global_position.x, digger.global_position.z)) or digger.global_position.z < 11.5,
		"he stands in the yard (%.1f, %.1f)" % [digger.global_position.x, digger.global_position.z])


func _digging(world: FoundryLevel, digger: HiredHand, heap: ScrapPile, bucket: ScrapBucket) -> void:
	# The bucket stands where the game puts it, by the heap's face.
	var before := bucket.count
	var stock := heap.stock
	await _until(func() -> bool: return digger.digging, 15.0)
	_check(digger.digging and digger.note == HiredHand.Note.DIGGING, "Hugo goes to the heap and digs")
	var from_middle := Vector2(digger.global_position.x - heap.centre().x, digger.global_position.z - heap.centre().z).length()
	_check(absf(from_middle - heap.foot() - 0.5) < 0.45, "he stands at the heap's foot (%.1f m from its middle, foot %.1f)" % [from_middle, heap.foot()])
	await _frames(60 * 12)
	var dug := bucket.count - before
	_check(dug >= 2 and dug <= 5 and heap.stock == stock - dug, "a find every few seconds goes into the bucket (%d in 12 s), out of the heap" % dug)
	_check(bucket.hot == 0, "hired hands never dig up hot goods")
	_check("wühlt" in digger.hint(null) and "entlassen" in digger.hint(null), "his hint says what he does: %s" % digger.hint(null))
	# No bucket by the heap: he waits. A full one: he says so.
	var home := bucket.global_position
	bucket.global_position = Vector3(10.0, 0.2, -6.0)
	await _frames(90)
	_check(not digger.digging and digger.note == HiredHand.Note.NO_BUCKET, "without a bucket by the heap he waits")
	bucket.global_position = home
	bucket.linear_velocity = Vector3.ZERO
	await _until(func() -> bool: return digger.digging, 10.0)
	_check(digger.digging, "the bucket is back: he digs again")
	while not bucket.is_full():
		bucket.add(&"junk_bolt")
	await _frames(30)
	_check(not digger.digging and digger.note == HiredHand.Note.BUCKET_FULL, "a full bucket: he waits and says so")
	bucket.empty()
	world.add_money(0)


func _wages(world: FoundryLevel, digger: HiredHand, missions: Missions) -> void:
	var money := world.money
	digger._wage_left = 0.05
	await _frames(10)
	_check(world.money == money - 8 and digger._wage_left > 59.0, "after a minute at work the wage is paid (8 $)")
	# No money: he stops, there is no debt; with money he takes his wage and goes on.
	world.add_money(-world.money)
	digger._wage_left = 0.05
	await _frames(10)
	_check(digger.state == HiredHand.State.UNPAID and world.money == 0 and not digger.digging, "without money he stops – no debt")
	_check("Lohn" in digger.hint(null), "the hint says he waits for his wage: %s" % digger.hint(null))
	await _frames(60)
	_check(digger.state == HiredHand.State.UNPAID, "he waits")
	world.add_money(30)
	await _frames(10)
	_check(digger.state == HiredHand.State.WORKING and world.money == 22, "as soon as the money is there he takes it and goes on")
	# Three minutes of wages are a mission of the business track.
	missions.done[1] = 5
	missions.progress[1] = 0
	_check(String(missions.current(1).get("stat", "")) == "wage", "the business track asks to keep hands at work")
	world.add_money(100)
	money = world.money
	for i in 3:
		digger._wage_left = 0.05
		await _frames(10)
	_check(world.money == money - 24 + 40 and missions.done[1] == 6, "three minutes of wages: the mission pays 40 $")
	missions.done[1] = 4
	missions.progress[1] = 0


func _going_home(world: FoundryLevel, me: Player, digger: HiredHand) -> void:
	digger.interact(me)
	_check(digger.state == HiredHand.State.WORKING, "one press of [F] does not send him home")
	await _frames(60 * 2)
	digger.interact(me)
	_check(digger.state == HiredHand.State.WORKING, "nor two presses far apart")
	digger.interact(me)
	_check(digger.state == HiredHand.State.LEAVING and not digger.hired(), "[F] twice in a row: Hugo goes home")
	_check(HiredHand.to_save(get_tree()).is_empty(), "he is off the pay roll at once")
	# Called back on his way home: he returns to work, and that costs no new fee.
	var money := world.money
	await _frames(60 * 3)
	_check("zurückrufen" in digger.hint(me), "on his way home the hint offers to call him back: %s" % digger.hint(me))
	digger._wage_left = 20.0
	digger.interact(me)
	_check(digger.state == HiredHand.State.COMING and digger.hired() and world.money == money, "[F] calls him back without a fee")
	await _until(func() -> bool: return digger.digging, 40.0)
	_check(digger.state == HiredHand.State.WORKING and digger.digging, "and he digs again")
	_check(digger._wage_left > 5.0 and digger._wage_left <= 20.0, "the minute that was running runs on: calling him back wins no fresh one (%.0f s left)" % digger._wage_left)
	digger.interact(me)
	digger.interact(me)
	_check(digger.state == HiredHand.State.LEAVING, "sent home once more")
	money = world.money
	await _until(func() -> bool: return digger.state == HiredHand.State.WAITING, 80.0)
	_check(digger.state == HiredHand.State.WAITING and digger.global_position.distance_to(digger.home) < 0.6,
		"he walks back to the labour exchange and can be hired again")
	_check(world.money == money, "on the way home he costs nothing")


func _running(world: FoundryLevel, me: Player, runner: HiredHand, bucket: ScrapBucket, stall: YardStall) -> void:
	world.add_money(1000 - world.money)
	runner.interact(me)
	_check(runner.state == HiredHand.State.COMING and world.money == 920, "Ede is hired for 80 $")
	# He, too, finds his way out of the exchange (from the back of the room) and to the yard.
	var steps := 0
	while runner.state == HiredHand.State.COMING and steps < 60 * 70:
		await get_tree().physics_frame
		steps += 1
	_check(runner.state == HiredHand.State.WORKING and steps < 60 * 45, "he walks to the yard on his own (%.0f s)" % (steps / 60.0))
	await _frames(30)
	_check(runner.state == HiredHand.State.WORKING and runner.note == HiredHand.Note.RESTING and not runner.carrying, "at work he waits for a bucket worth a trip")
	# Seven pieces are not worth the trip; with nine he comes.
	for kind: StringName in [&"junk_sheet", &"junk_gear", &"junk_bolt", &"junk_spring", &"junk_bolt", &"scrap_can", &"scrap_can"]:
		bucket.add(kind)
	await _frames(60 * 3)
	_check(runner.note == HiredHand.Note.RESTING and bucket.count == 7, "seven pieces: he lets the bucket stand")
	bucket.add(&"scrap_kettle")
	bucket.add(&"hot_plates")
	var money := world.money
	var worth := 2 + 3 + 1 + 2 + 1 + 2 + 2
	await _until(func() -> bool: return runner.carrying, 20.0)
	_check(runner.carrying and runner.loaded == 8 and bucket.count == 1 and bucket.hot == 1, "he takes the load out of the bucket; the hot goods stay in it")
	await _until(func() -> bool: return stall.goods().size() == 1, 25.0)
	var laid := stall.goods()
	_check(laid.size() == 1 and (laid[0] as Item).kind == &"scrap_kettle" and runner.loaded == 7, "the rare find goes on the crew's stall")
	var crossed := false
	var frames := 0
	while world.money == money and frames < 60 * 50:
		await get_tree().physics_frame
		frames += 1
		crossed = crossed or runner.global_position.z > 18.0
	_check(world.money == money + worth and crossed, "the rest he carries across the street: the dealer pays %d $" % worth)
	_check(runner.loaded == 0, "his crate is empty")
	await _until(func() -> bool: return runner.note == HiredHand.Note.RESTING and not runner.carrying, 40.0)
	_check(runner.note == HiredHand.Note.RESTING and runner.global_position.distance_to(runner.post) < 1.5, "he comes back and waits for the next load")
	# Once the crew melts its own metal he takes the junk only: the metal stays for the furnace.
	bucket.empty()
	for item: Item in stall.goods():
		item.free()
	world.add_money(300)
	_check(world.upgrades.buy(&"foundry_corner"), "the crew buys its foundry corner")
	await _frames(10)
	for kind: StringName in [&"junk_sheet", &"junk_gear", &"junk_bolt", &"junk_spring", &"junk_bolt", &"junk_gear", &"junk_sheet", &"junk_bolt",
			&"scrap_can", &"scrap_pipe", &"scrap_kettle"]:
		bucket.add(kind)
	await _until(func() -> bool: return runner.carrying, 20.0)
	_check(runner.loaded == 8 and bucket.count == 3 and bucket._metal_count() == 3, "with a furnace of their own he leaves the metal in the bucket")
	_check("Krempel" in runner._note_text() or runner.note != HiredHand.Note.RESTING, "and says so while he waits")
	# Sent home with a load in his crate: it is paid for at the dealer's price.
	money = world.money
	runner.interact(me)
	runner.interact(me)
	_check(runner.state == HiredHand.State.LEAVING and world.money == money + 2 + 3 + 1 + 2 + 1 + 3 + 2 + 1 and not runner.carrying,
		"sent home with a load: the crew gets the dealer's price for it")
	bucket.empty()


func _keeping(world: FoundryLevel, me: Player, keeper: HiredHand, runner: HiredHand, bucket: ScrapBucket, stall: YardStall) -> void:
	for item: Item in stall.goods():
		item.free()
	await _frames(3)
	var kettle := world.spawn_item(&"scrap_kettle", Color.WHITE, Vector3(0.3, 0.26, 0.3), 0.4, stall.to_global(stall.place_pos(0) + Vector3(0, 0.12, 0)))
	await _frames(20)
	_check(stall.price_now(kettle) == 30, "without a stall keeper a kettle costs 30 $ at the stall")
	# Without a stall keeper the bucket by the stall is the runner's like any other.
	var by_heap := bucket.global_position
	bucket.global_position = stall.global_position + Vector3(-2.0, 0.2, -0.3)
	for i in 9:
		bucket.add(&"junk_bolt")
	_check(runner._bucket_to_empty() == bucket, "without a stall keeper the runner would empty a bucket by the stall too")
	bucket.empty()
	bucket.global_position = by_heap
	bucket.linear_velocity = Vector3.ZERO
	world.add_money(1000 - world.money)
	keeper.interact(me)
	_check(keeper.state == HiredHand.State.COMING and world.money == 900, "Rosa is hired for 100 $")
	# She comes on foot, round the parasol's pole to her place behind the table.
	var frames := 0
	while not keeper.serving and frames < 60 * 70:
		await get_tree().physics_frame
		frames += 1
	_check(keeper.serving and HiredHand.serving_at(stall) == keeper, "she walks to the stall and serves behind the table (%.0f s)" % (frames / 60.0))
	var behind := stall.to_local(keeper.global_position)
	_check(behind.z < -YardStall.SIZE.y * 0.5 and absf(behind.x) < YardStall.SIZE.x * 0.5, "behind it, not in the customers' way")
	_check(Vector2(behind.x - 0.62, behind.z + YardStall.SIZE.y * 0.5 + 0.42).length() < 0.4 and frames < 60 * 50,
		"at her place beside the pole, not held up on the way (%.2f, %.2f)" % [behind.x, behind.z])
	_check(stall.price_now(kettle) == 36 and "Rosa" in stall.hint(me), "with her the kettle costs 36 $: %s" % stall.hint(me))
	_check("36 $" in stall.toss_hint(kettle), "and the hint for laying a piece down names that price: %s" % stall.toss_hint(kettle))
	# A customer takes two pieces instead of one.
	for i in 2:
		world.spawn_item(&"scrap_candle", Color.WHITE, Vector3(0.13, 0.24, 0.13), 0.4, stall.to_global(stall.place_pos(1 + i) + Vector3(0, 0.12, 0)))
	await _frames(20)
	var money := world.money
	var lying := stall.goods().size()
	stall._serve(0)
	await _frames(3)
	_check(lying == 3 and stall.goods().size() == 1 and world.money > money + 36, "a customer buys two pieces and pays more (+%d $)" % (world.money - money))
	# A bucket set down beside the table: she lays out the best of it. The runner leaves it alone.
	for item: Item in stall.goods():
		item.free()
	bucket.global_position = stall.global_position + Vector3(-2.0, 0.2, -0.3)
	bucket.linear_velocity = Vector3.ZERO
	for kind: StringName in [&"scrap_ring", &"scrap_coin", &"junk_bolt", &"junk_bolt", &"junk_bolt", &"junk_bolt", &"junk_bolt", &"junk_bolt", &"junk_bolt", &"junk_bolt"]:
		bucket.add(kind)
	runner.start_at_work()
	await _until(func() -> bool: return stall.goods().size() >= 2, 12.0)
	var kinds := stall.goods().map(func(item: Item) -> StringName: return item.kind)
	_check(kinds.has(&"scrap_ring") and kinds.has(&"scrap_coin"), "she lays out the best finds from the bucket beside the table")
	await _frames(60 * 4)
	_check(runner.note == HiredHand.Note.RESTING and not runner.carrying, "the runner leaves the bucket by the stall alone")
	# Without her wage she stops serving.
	world.add_money(-world.money)
	keeper._wage_left = 0.05
	await _frames(10)
	_check(keeper.state == HiredHand.State.UNPAID and not keeper.serving and HiredHand.serving_at(stall) == null, "without her wage nobody serves")
	world.add_money(500)
	await _until(func() -> bool: return keeper.serving, 5.0)
	_check(keeper.serving, "paid, she serves again")


func _saving(world: FoundryLevel, digger: HiredHand, runner: HiredHand, keeper: HiredHand) -> void:
	_check(HiredHand.to_save(get_tree()) == ["runner", "keeper"], "the save file names who is hired: %s" % str(HiredHand.to_save(get_tree())))
	runner.dismiss()
	keeper.dismiss()
	_check(HiredHand.count(get_tree()) == 0, "all sent home")
	var money := world.money
	HiredHand.load_save(get_tree(), ["digger", "keeper"])
	_check(digger.state == HiredHand.State.WORKING and keeper.state == HiredHand.State.WORKING and runner.state == HiredHand.State.LEAVING,
		"a saved game puts the hired hands back at their work")
	_check(digger.global_position.distance_to(digger.post) < 0.3 and world.money == money and digger._wage_left > 59.0, "at their places, without a new fee, a fresh minute ahead")
	HiredHand.load_save(get_tree(), "nonsense")
	_check(HiredHand.count(get_tree()) == 2, "a broken entry in the save changes nothing")
	# In another hall there are no hands: the save keeps those hired in the scrap hall.
	_check(HiredHand.to_save(get_tree()) == ["digger", "keeper"], "the pay roll as saved: %s" % str(HiredHand.to_save(get_tree())))
	for hand: HiredHand in [digger, runner, keeper]:
		hand.remove_from_group(HiredHand.GROUP)
	_check(HiredHand.to_save(get_tree()) == ["digger", "keeper"], "a hall without hands keeps the pay roll in the save")
	for hand: HiredHand in [digger, runner, keeper]:
		hand.add_to_group(HiredHand.GROUP)


func _until(done: Callable, seconds: float) -> void:
	var frames := 0
	while not done.call() and frames < seconds * 60.0:
		await get_tree().physics_frame
		frames += 1


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
	print("HANDS TESTS %s (%d failures)" % ["PASSED" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures > 0 else 0)
