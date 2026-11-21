extends Node
## The storage auctions under the viaduct, headless: four lock-ups, two with a lot from the start.
## The sign says what kind of lot waits and what the bidding starts at; [F] bids, the other bidder
## raises, [F] raises again; at the hammer the crew pays and the shutter opens, the pieces lie in
## the room and go into the bucket with one [F]. A lot the crew lets go, or cannot pay, is gone.
## Afterwards the lock-up rests and a new lot comes.
## And the post office on Bank Street: its door, its counter, three mail orders on the board; a
## piece that is asked for is handed over by hand or out of the bucket and paid at four times the
## dealer's price; a filled order makes room for a new one.

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var world: FoundryLevel = load("res://scenes/scrap_hall.tscn").instantiate()
	add_child(world)
	await _frames(10)
	var me := world.local_player()
	var missions := Missions.of(get_tree())
	var units: Array[StorageLockup] = []
	for node in get_tree().get_nodes_in_group(StorageLockup.GROUP):
		units.append(node as StorageLockup)
	units.sort_custom(func(a: StorageLockup, b: StorageLockup) -> bool: return a.number < b.number)
	_check(me != null and missions != null and units.size() == 4 and StorageAuction.of(get_tree()) != null,
		"under the viaduct are four lock-ups and the auctioneer")
	if me == null or missions == null or units.size() != 4:
		_finish()
		return
	# Nothing drives or patrols through this test.
	var traffic := get_tree().get_first_node_in_group(TownTraffic.GROUP) as TownTraffic
	if traffic:
		traffic.free()
	for cop in get_tree().get_nodes_in_group(PolicePatrol.GROUP):
		(cop as Node).set_physics_process(false)
	# No mission pays into the sums below by chance: the business track waits for a lot.
	missions.done[1] = 4
	missions.progress[1] = 0
	await _lots(world, me, units, missions)
	await _post(world, me, missions)
	_finish()


func _lots(world: FoundryLevel, me: Player, units: Array[StorageLockup], missions: Missions) -> void:
	_check(units[0].state == StorageLockup.State.SHUT and units[1].state == StorageLockup.State.SHUT
		and units[2].state == StorageLockup.State.RESTING and units[3].state == StorageLockup.State.RESTING,
		"two lots wait from the start, the other two lock-ups are empty for now")
	_check(units[0].pieces >= 5 and units[0].pieces <= 15 and units[0].opening >= 10 and units[0].opening % 5 == 0,
		"a lot has five to fifteen pieces and a round opening bid (%d pieces, %d $)" % [units[0].pieces, units[0].opening])
	# What is in a lot: only things the heap gives up too; an estate now and then holds hot goods.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var known := true
	var hot_lots := 0
	for i in 200:
		var lot := StorageLockup.draw(2, 9, rng)
		known = known and lot.size() == 9
		var hot := false
		for kind in lot:
			known = known and not FoundryRules.find_info(kind).is_empty()
			hot = hot or FoundryRules.is_hot(kind)
		if hot:
			hot_lots += 1
	_check(known, "every piece of a lot is a find the game knows")
	_check(hot_lots > 25 and hot_lots < 110, "about three estates in ten hold something hot (%d of 200)" % hot_lots)
	var none := true
	for i in 100:
		for kind in StorageLockup.draw(0, 9, rng):
			none = none and not FoundryRules.is_hot(kind)
	_check(none, "a household clear-out never does")
	_check(StorageLockup.raise_of(30) == 35 and StorageLockup.raise_of(50) == 60 and StorageLockup.raise_of(200) == 225, "bids rise by 5, 10 and 25 $")
	# A workshop lot of nine pieces in the first lock-up.
	var unit := units[0]
	unit.stock(1, 9)
	var value := StorageLockup.worth(unit._lot)
	_check(unit.pieces == 9 and unit.theme == 1 and value > 0 and unit.opening == maxi(10, roundi(value * 0.3 / 5.0) * 5),
		"the opening bid is three tenths of what the pieces bring at the stall (%d $ of %d $)" % [unit.opening, value])
	var door := unit.global_position
	me._do_teleport(Vector3(door.x, 0.06, door.z - 1.6))
	me.facing = 0.0
	await _frames(20)
	# While the crew saves for the furnace and has never bid, the card points at a lot it can afford.
	var guide := world.guide
	for i in guide.letters().size():
		if guide.letters()[i].id == &"foundry_corner":
			guide.load_index(i)
	for other in units:
		if other != unit:
			other.rest(1000.0)
	var bucket_now := get_tree().get_first_node_in_group(&"scrap_buckets") as ScrapBucket
	bucket_now.contents = [] as Array[StringName]
	bucket_now._changed()
	world.add_money(80 - world.money)
	var tip := NextStepCard.next_step(world)
	_check(tip.contains("Lager-Auktion") and tip.contains("Los 1 ab %d $" % unit.opening) and NextStepCard.target == unit, "with money to spare the card names the auction (%s)" % tip)
	world.add_money(-world.money)
	_check(unit.in_reach(me) and unit.hint(me).contains("es fehlen noch"), "without money the sign only says what is missing (%s)" % unit.hint(me))
	unit.interact(me)
	_check(unit.state == StorageLockup.State.SHUT, "and [F] bids nothing")
	world.add_money(1000)
	_check(me.nearest_interactable() == unit and unit.hint(me).begins_with("[F] Mitbieten") and unit.hint(me).contains("Werkstattauflösung, 9 Teile"),
		"with money [F] offers to bid (%s)" % unit.hint(me))
	var shut := Transform3D(Basis(), Vector3(door.x, 0.06, door.z - 1.3))
	_check(me.test_move(shut, Vector3(0, 0, 3.0)), "the shutter is down")
	# The crew opens the bidding; nothing is paid yet.
	unit._rival_limit = 100000
	unit.interact(me)
	var first := unit.opening
	_check(unit.state == StorageLockup.State.BIDDING and unit.ours and unit.bid == first and world.money == 1000 and absf(unit.time_left - StorageLockup.COUNT) < 0.2,
		"the first [F] bids the opening bid; the hammer falls in six seconds")
	_check(unit.hint(me).begins_with("Ihr bietet"), "while the crew leads there is nothing to press (%s)" % unit.hint(me))
	_check(not NextStepCard.next_step(world).contains("Lager-Auktion"), "once the crew has bid, the card lets the auctions be")
	unit.interact(me)
	_check(unit.bid == first, "the crew does not outbid itself")
	# The other bidder raises; the crew raises again.
	unit._rival_in = 0.05
	await _frames(8)
	_check(not unit.ours and unit.bid == StorageLockup.raise_of(first) and unit.hint(me).begins_with("[F] %d $ bieten" % StorageLockup.raise_of(unit.bid)),
		"the other bidder raises, and [F] offers the next step (%s)" % unit.hint(me))
	unit.interact(me)
	var price := StorageLockup.raise_of(StorageLockup.raise_of(first))
	_check(unit.ours and unit.bid == price, "the crew raises to %d $" % price)
	# He gives up: the hammer falls, the crew pays, the mission counts it.
	_check(missions.current(1).get("stat", &"") == &"lot_won", "a mission asks for a lot (%s)" % missions.current(1).get("text", "?"))
	unit._rival_in = -1.0
	unit.time_left = 0.05
	await _frames(8)
	_check(unit.state == StorageLockup.State.WON and world.money == 1000 - price + 40, "knocked down to the crew: %d $ paid, the mission's 40 $ on top (%d $ left)" % [price, world.money])
	_check(missions.done[1] == 5, "the mission is done")
	await _frames(40)
	_check(unit.goods_inside().size() == 9, "the nine pieces lie in the room (%d)" % unit.goods_inside().size())
	_check(not me.test_move(shut, Vector3(0, 0, 3.6)), "the shutter is up, and the way down the middle of the room is free")
	_check(unit.hint(me).contains("noch 9 Teile"), "the sign counts what is left (%s)" % unit.hint(me))
	# With the bucket in hand one [F] sweeps the room.
	var bucket := get_tree().get_first_node_in_group(&"scrap_buckets") as ScrapBucket
	bucket.contents = [] as Array[StringName]
	bucket._changed()
	bucket.global_position = me.global_position + Vector3(0, 1.0, 0.7)
	bucket.linear_velocity = Vector3.ZERO
	await _frames(2)
	me.grab(bucket)
	await _frames(3)
	_check(me.held == bucket and bucket.held_hint(me).begins_with("[F] Alles in den Eimer (9 Teile)"), "with the bucket [F] offers to take it all (%s)" % bucket.held_hint(me))
	bucket.use_start(me)
	await _frames(3)
	_check(bucket.count == 9 and unit.goods_inside().is_empty(), "nine pieces in the bucket, the room is empty (%d in the bucket)" % bucket.count)
	_check(bucket.worth > 0 and not bucket.held_hint(me).begins_with("[F] Alles"), "and the bucket is its old self again (%s)" % bucket.held_hint(me))
	me.release()
	# Empty for a while and nobody inside: the shutter comes down and the lock-up rests.
	unit._empty_for = 5.9
	me._do_teleport(Vector3(door.x, 0.06, door.z + 1.5))
	await _frames(20)
	_check(unit.state == StorageLockup.State.WON, "nobody is shut in: the shutter waits for whoever stands inside")
	me._do_teleport(Vector3(door.x, 0.06, door.z - 2.2))
	await _frames(20)
	_check(unit.state == StorageLockup.State.RESTING and unit.hint(me).contains("nächste Los"), "then it comes down (%s)" % unit.hint(me))
	await _frames(10)
	_check(me.test_move(shut, Vector3(0, 0, 3.0)), "and the lock-up is shut again")
	unit._clock = 0.05
	await _frames(8)
	_check(unit.state == StorageLockup.State.SHUT and unit.pieces >= 5, "after a while a new lot waits (%d pieces)" % unit.pieces)
	# A lot the crew lets go: the other bidder takes it, nothing is paid.
	var money := world.money
	unit.stock(0, 6)
	unit._rival_limit = 100000
	unit.interact(me)
	unit._rival_in = 0.05
	await _frames(8)
	unit.time_left = 0.05
	await _frames(8)
	_check(unit.state == StorageLockup.State.RESTING and world.money == money and unit.goods_inside().is_empty(), "let go, the lot goes to the other bidder and costs nothing")
	# A bid the crew cannot pay when the hammer falls.
	unit.stock(0, 6)
	unit._rival_limit = 0
	unit.interact(me)
	_check(unit.ours and unit._rival_in < 0.0, "a lot the other bidder does not want: nobody raises")
	world.add_money(-world.money)
	unit.time_left = 0.05
	await _frames(8)
	_check(unit.state == StorageLockup.State.RESTING and world.money == 0, "no money at the hammer: no lot")
	# What an open lock-up still holds goes with the clearance.
	world.add_money(500)
	unit.stock(2, 7)
	unit._rival_limit = 0
	unit.interact(me)
	unit.time_left = 0.05
	await _frames(40)
	_check(unit.state == StorageLockup.State.WON and unit.goods_inside().size() == 7, "another lot won, seven pieces")
	unit._clock = StorageLockup.CLEAR_AFTER
	await _frames(20)
	_check(unit.state == StorageLockup.State.RESTING, "left lying too long, the lock-up is cleared")
	await _frames(5)
	var left := 0
	for node in world.entities.get_children():
		var item := node as Item
		if item and not item.is_queued_for_deletion() and absf(item.global_position.x - door.x) < 1.9 and item.global_position.z > door.z - 0.2 and item.global_position.z < door.z + 5.6:
			left += 1
	_check(left == 0, "nothing is left in it (%d)" % left)


func _post(world: FoundryLevel, me: Player, missions: Missions) -> void:
	var post := get_tree().get_first_node_in_group(PostOffice.GROUP) as PostOffice
	_check(post != null and post.orders.size() == PostOffice.SLOTS, "the post office has three mail orders on its board")
	if post == null:
		return
	var kinds := {}
	var fair := true
	for o in post.orders:
		kinds[o.kind] = true
		fair = fair and int(o.pay) == PostOffice.pay_for(o.kind) and int(o.count) >= 1 and not FoundryRules.find_info(o.kind).is_empty()
	_check(kinds.size() == PostOffice.SLOTS and fair, "three different finds, each at the post's price")
	_check(PostOffice.pay_for(&"scrap_kettle") == 50 and PostOffice.pay_for(&"scrap_can") == 10 and PostOffice.pay_for(&"scrap_ring") == 100,
		"the post pays four times the dealer's price, and never less than 10 $")
	# The house stands in a frame of its own, turned to the side street: door, wall and counter.
	var lot := TownShops.post_lot()
	var into := lot.basis * Vector3(0, 0, 1)
	# (The probes start clear of the mail box and the street lamp on the pavement.)
	var outside := Transform3D(Basis(), lot * Vector3(TownShops.POST_DOOR_X, 0.06, -0.9))
	_check(not me.test_move(outside, into * 2.1), "the post office's door is open")
	var wall := Transform3D(Basis(), lot * Vector3(-0.3, 0.06, -0.9))
	_check(me.test_move(wall, into * 2.1), "beside it the front is solid")
	var inside := Transform3D(Basis(), lot * Vector3(TownShops.POST_DOOR_X, 0.06, 1.2))
	_check(me.test_move(inside, into * ScrapHallSet.COUNTER_Z), "its counter is solid")
	# Three orders the test knows.
	post.set_orders([&"scrap_kettle", &"scrap_can", &"scrap_ring"])
	me._do_teleport(post.to_global(Vector3(0, 0.06, -0.8)))
	me.facing = PI * 0.5
	me.rotation.y = PI * 0.5
	await _frames(20)
	var says := post.hint(me)
	_check(post.in_reach(me) and me.nearest_interactable() == post and says.contains("Kupferkessel (50 $)") and says.contains("3× Dose (10 $)") and says.contains("Omas Ring (100 $)"),
		"at the counter the hint lists what is asked for (%s)" % says)
	# With something in the bucket that is on order, the card sends the crew here (before the stall).
	var pail := get_tree().get_first_node_in_group(&"scrap_buckets") as ScrapBucket
	pail.contents = [&"junk_bolt", &"scrap_kettle"] as Array[StringName]
	pail._changed()
	world.add_money(-world.money)
	var tip := NextStepCard.next_step(world)
	_check(tip.contains("POST OFFICE") and NextStepCard.target == post, "with an ordered find in the bucket the card names the post office (%s)" % tip)
	pail.contents = [] as Array[StringName]
	pail._changed()
	missions.done[0] = 3
	missions.progress[0] = 0
	_check(missions.current(0).get("stat", &"") == &"parcel", "a mission asks for mail orders (%s)" % missions.current(0).get("text", "?"))
	# By hand: a kettle goes over the counter.
	var info: Dictionary = FoundryRules.find_info(&"scrap_kettle")
	var kettle := world.spawn_item(&"scrap_kettle", info.color, info.size, 0.4, me.global_position + Vector3(0.7, 1.0, 0))
	await _frames(2)
	me.grab(kettle)
	await _frames(3)
	me.facing = PI * 0.5
	me.rotation.y = PI * 0.5
	_check(me.held == kettle and me.toss_target(kettle) == post and post.toss_hint(kettle).contains("50 $"), "with an ordered find in hand the counter is where it goes (%s)" % post.toss_hint(kettle))
	me.release()
	await _frames(10)
	_check(world.money == 50 and (not is_instance_valid(kettle) or kettle.is_queued_for_deletion()), "handed over: 50 $ (%d $)" % world.money)
	_check(missions.progress[0] == 1 and post.order_for(&"scrap_kettle") < 0 and not post.hint(me).contains("Kupferkessel"), "the order is filled and off the list (%s)" % post.hint(me))
	var key_info: Dictionary = FoundryRules.find_info(&"scrap_key")
	var key := world.spawn_item(&"scrap_key", key_info.color, key_info.size, 0.4, me.global_position + Vector3(-1.5, 0.3, 0))
	await _frames(3)
	_check(not post.toss_accepts(key) and post.deliver(&"scrap_key") == 0, "what nobody ordered is not taken")
	key.free()
	# Out of the bucket: every piece that is asked for, and only those.
	var bucket := get_tree().get_first_node_in_group(&"scrap_buckets") as ScrapBucket
	bucket.contents = [&"scrap_can", &"scrap_can", &"scrap_key", &"scrap_can", &"scrap_can", &"scrap_ring", &"hot_pistol"] as Array[StringName]
	bucket._changed()
	bucket.global_position = me.global_position + Vector3(0.7, 1.0, 0)
	bucket.linear_velocity = Vector3.ZERO
	await _frames(2)
	me.grab(bucket)
	await _frames(3)
	_check(me.held == bucket and bucket.held_hint(me).begins_with("[F] 4 bestellte Stücke"), "with the bucket [F] offers to hand over what is ordered (%s)" % bucket.held_hint(me))
	bucket.use_start(me)
	await _frames(3)
	_check(bucket.count == 3 and bucket.hot == 1, "three cans and the ring are gone, a can, the key and the pistol stay (%d left)" % bucket.count)
	# 50 $ for the kettle, 30 $ for three cans, 100 $ for the ring, and 45 $ for the mission (two pieces).
	_check(world.money == 50 + 30 + 100 + 45, "paid: 130 $ more, and the mission's 45 $ (%d $)" % world.money)
	_check(post.hint(me).contains("alles verschickt") and bucket.held_hint(me).contains("nichts"), "all three orders are filled (%s)" % post.hint(me))
	# [F] with nothing on order in the bucket takes nothing (a line at the counter says so).
	var before := world.money
	bucket.use_start(me)
	await _frames(2)
	_check(bucket.count == 3 and world.money == before, "[F] with nothing ordered in the bucket takes nothing")
	me.release()
	# After a while new orders hang on the board.
	for o in post.orders:
		o.rest = 0.05
	await _frames(8)
	var open := 0
	var again := {}
	for o in post.orders:
		if float(o.rest) <= 0.0 and int(o.done) == 0:
			open += 1
		again[o.kind] = true
	_check(open == PostOffice.SLOTS and again.size() == PostOffice.SLOTS, "then three new orders hang there, each for something else")


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
	print("LOTS TESTS %s (%d failures)" % ["PASSED" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures > 0 else 0)
