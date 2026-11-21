extends Node
## The longer street and what stands on it, headless: the way is free where the barriers used to be
## and ends just before the two junctions. In the hardware store the hand tools lie on the bench and
## are bought there with [F]; the board in the hall no longer lists them, Onkel Heinz's letter and the
## "what now" card send the crew to the store. At the bank a loan is asked for, confirmed and paid out;
## a quarter of every income goes back until it is paid, or the rest is paid off at the counter; the
## next loan is bigger. On the crew's stall finds and castings are laid out by hand and from the
## bucket, hot goods are not; the two customers each take one piece per visit and pay more than the
## dealer or the sales crate.

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var world: FoundryLevel = load("res://scenes/scrap_hall.tscn").instantiate()
	add_child(world)
	await _frames(10)
	var me := world.local_player()
	var missions := Missions.of(get_tree())
	var stall := get_tree().get_first_node_in_group(YardStall.GROUP) as YardStall
	var loans := get_tree().get_first_node_in_group(BankCounter.GROUP) as BankCounter
	var offers := {}
	for node in get_tree().get_nodes_in_group(ToolOffer.GROUP):
		offers[(node as ToolOffer).upgrade] = node
	_check(me != null and missions != null and stall != null and loans != null and world.bank != null and offers.size() == 5,
		"the quarter has a hardware store with five tools, a bank counter and the crew's stall")
	if me == null or missions == null or stall == null or loans == null or world.bank == null or offers.size() != 5:
		_finish()
		return
	# Nothing drives or patrols through this test, and no mission pays into its sums by chance.
	var traffic := get_tree().get_first_node_in_group(TownTraffic.GROUP) as TownTraffic
	if traffic:
		traffic.free()
	for cop in get_tree().get_nodes_in_group(PolicePatrol.GROUP):
		(cop as Node).set_physics_process(false)
	missions.done[1] = 3
	missions.progress[1] = 0
	_check(missions.current(1).stat == &"stall_sold", "the missions know the stall (%s)" % missions.current(1).get("text", "?"))
	# A save from before the stall mission was slotted in keeps its mission, its progress and its round.
	var today: Dictionary = missions.to_save()
	missions.load_save({done = [2, 3, 1], progress = [4, 7, 0], total = 6})
	_check(missions.done[1] == 4 and missions.progress[1] == 7 and missions.current(1).stat == &"earned" and missions.done[0] == 2 and missions.done[2] == 1,
		"an older save that had the diner behind it goes on where it was (%s)" % missions.current(1).get("text", "?"))
	missions.load_save({done = [0, 8, 0], progress = [0, 0, 0], total = 8})
	_check(missions.done[1] == 9 and missions.round_of(1) == 1 and missions.current(1).stat == &"diner", "and keeps its round (%s)" % missions.current(1).get("text", "?"))
	missions.load_save(today)
	_check(missions.done[1] == 3 and missions.current(1).stat == &"stall_sold", "a save of today is read as it stands")
	await _street(me)
	await _hardware(world, me, offers)
	await _bank(world, me, loans, missions)
	await _stall(world, me, stall, missions)
	_finish()


## The streets: the main street free to the houses beyond both junctions, the side streets and the
## back street free round the block, two ways through the row, and the viaduct shut to people.
func _street(me: Player) -> void:
	var front := ScrapHallSet.FRONT_Z
	var side := ScrapHallSet.SIDE_X
	for dir: float in [-1.0, 1.0]:
		var name := "western" if dir < 0.0 else "eastern"
		var from := Transform3D(Basis(), Vector3(dir * 24.0, 0.06, front - 3.2))
		_check(not me.test_move(from, Vector3(dir * 23.5, 0, 0)), "the pavement is free past where the %s barrier stood, into the junction" % name)
		var at_end := Transform3D(Basis(), Vector3(dir * (TownStreets.FAR_X - 1.2), 0.06, front - 3.2))
		_check(me.test_move(at_end, Vector3(dir * 3.0, 0, 0)), "the houses beyond the junction stop people")
		var on_road := Transform3D(Basis(), Vector3(dir * (TownStreets.FAR_X - 1.2), 0.06, 14.1))
		_check(me.test_move(on_road, Vector3(dir * 3.0, 0, 0)), "at the end of the road too")
		var south := Transform3D(Basis(), Vector3(dir * side, 0.06, 9.4))
		_check(me.test_move(south, Vector3(0, 0, -3.0)), "the yard wall runs on along the junction")
		# Up the side street to the back street, and no further than the barrier under the viaduct.
		var corner := Transform3D(Basis(), Vector3(dir * (side - 3.6), 0.06, front - 2.0))
		_check(not me.test_move(corner, Vector3(0, 0, TownStreets.BACK_Z - front + 2.0)), "the %s side street is free up to the back street" % name)
		var under := Transform3D(Basis(), Vector3(dir * side, 0.06, TownStreets.VIADUCT_Z - 1.0))
		_check(me.test_move(under, Vector3(0, 0, 4.0)), "under the viaduct a barrier stops people")
		var pavement := Transform3D(Basis(), Vector3(dir * (TownStreets.GATE_X + TownStreets.GATE_W * 0.5 - 0.8), 0.06, TownStreets.VIADUCT_Z - 1.0))
		_check(me.test_move(pavement, Vector3(0, 0, 4.0)), "on the pavement beside the road too")
	# The back street, from one side street to the other (between the parked cars and the van).
	var back := Transform3D(Basis(), Vector3(-side + 3.6, 0.06, 34.0))
	_check(not me.test_move(back, Vector3(side * 2.0 - 7.2, 0, 0)), "the back street is free from end to end")
	var arch := Transform3D(Basis(), Vector3(TownStreets.bay_x(4), 0.06, TownStreets.VIADUCT_Z - 1.2))
	_check(me.test_move(arch, Vector3(0, 0, 3.0)), "the arches of the viaduct are shut")
	for index in TownStreets.lockups():
		var door := Transform3D(Basis(), Vector3(TownStreets.bay_x(index), 0.06, TownStreets.VIADUCT_Z - 1.2))
		_check(me.test_move(door, Vector3(0, 0, 3.0)), "lock-up %d is shut" % index)
	# Two ways through the row: the passage beside the dealer's and the alley beside the bank.
	var passage := Transform3D(Basis(), Vector3(TownStreets.PASSAGE.y - 1.5, 0.06, front - 1.0))
	_check(not me.test_move(passage, Vector3(0, 0, TownStreets.BACK_Z - front + 1.0)), "the passage beside the dealer's leads through to the back street")
	var alley := Transform3D(Basis(), Vector3((TownStreets.ALLEY_EAST.x + TownStreets.ALLEY_EAST.y) * 0.5, 0.06, front - 1.0))
	_check(not me.test_move(alley, Vector3(0, 0, TownStreets.BACK_Z - front + 1.0)), "the alley beside the bank too")
	var gate := Transform3D(Basis(), Vector3(-26.62, 0.06, front - 1.0))
	_check(me.test_move(gate, Vector3(0, 0, 3.0)), "the alley beside the hardware store is shut by its gate")
	var yard := Transform3D(Basis(), Vector3(10.0, 0.06, front + 4.0))
	_check(me.test_move(yard, Vector3(0, 0, 4.0)), "elsewhere the yard wall behind the row is solid")
	await _frames(1)


## The hardware store: in through the door, the tools on the bench, bought with [F].
func _hardware(world: FoundryLevel, me: Player, offers: Dictionary) -> void:
	var at := ScrapHallSet.HARDWARE
	var outside := Transform3D(Basis(), Vector3(at.x, 0.06, at.z - 1.3))
	_check(not me.test_move(outside, Vector3(0, 0, 2.6)), "the hardware store's door is open")
	var beside := Transform3D(Basis(), Vector3(at.x - 3.0, 0.06, at.z - 1.3))
	_check(me.test_move(beside, Vector3(0, 0, 2.6)), "beside it the front is solid")
	var gloves := offers[&"gloves"] as ToolOffer
	var shovel := offers[&"shovel"] as ToolOffer
	var inside := Transform3D(Basis(), Vector3(at.x, 0.06, at.z + 2.0))
	var to_bench := Vector3(gloves.global_position.x - at.x, 0, 0)
	_check(not me.test_move(inside, to_bench) and me.test_move(Transform3D(Basis(), inside.origin + to_bench), Vector3(0, 0, 5.0)),
		"inside, the way to the bench is free and the bench is solid")
	var behind := Transform3D(Basis(), Vector3(at.x + 0.2, 0.06, at.z + 3.0))
	_check(me.test_move(behind, Vector3(0, 0, 2.2)) and me.test_move(Transform3D(Basis(), Vector3(at.x - 1.3, 0.06, at.z + 4.9)), Vector3(1.6, 0, 0)),
		"nobody gets behind the clerk's counter")
	me._do_teleport(Vector3(gloves.global_position.x, 0.06, gloves.global_position.z - 1.15))
	await _frames(5)
	_check(gloves.in_reach(me) and me.global_position.y < 0.3, "standing at the bench, the gloves are in reach")
	_check(me.nearest_interactable() == gloves, "and they are what [F] means there")
	# Without the money nothing is sold.
	world.add_money(-world.money)
	gloves.interact(me)
	_check(not world.has_upgrade(&"gloves") and world.money == 0, "no money, no gloves")
	_check(gloves.hint(me).contains("fehlen noch 90 $"), "the bench says what is missing (%s)" % gloves.hint(me))
	# With the money: bought once, for the whole crew.
	world.add_money(100)
	_check(gloves.hint(me).begins_with("[F] Lederhandschuhe kaufen · 90 $"), "with money the gloves are offered (%s)" % gloves.hint(me))
	gloves.interact(me)
	_check(world.has_upgrade(&"gloves") and world.money == 10, "the gloves are bought: 90 $ paid")
	_check(is_equal_approx(me.strength, Player.STRENGTH * 1.25), "and they do what they did: a stronger grip")
	gloves.interact(me)
	_check(world.money == 10 and gloves.hint(me).contains("habt ihr schon"), "nobody pays twice (%s)" % gloves.hint(me))
	_check(shovel.hint(me).contains("150 $") and not shovel.hint(me).begins_with("[F]"), "the shovel waits for more money (%s)" % shovel.hint(me))
	# The board in the hall leaves the tools to the store.
	var shop := UpgradeShop.new()
	shop.upgrades = world.upgrades
	shop.world = world
	var listed := shop._ordered().map(func(u: Dictionary) -> StringName: return u.id)
	shop.free()
	_check(&"gloves" in listed and not (&"shovel" in listed) and not (&"detector" in listed) and not (&"magnet" in listed) and not (&"bucket_big" in listed),
		"the hall's board lists the gloves as owned and none of the store's other tools")
	_check(&"foundry_corner" in listed and &"excavator" in listed, "it still sells the machines")
	# Onkel Heinz and the card know the way.
	var guide := world.guide
	var asks := ""
	for i in guide.letters().size():
		if guide.letters()[i].id == &"shovel":
			asks = guide.letters()[i].goal
			guide.load_index(i)
	_check(asks.contains("HARDWARE"), "Onkel Heinz sends the crew to the store for the shovel (%s)" % asks)
	world.add_money(150 - world.money)
	me._do_teleport(Vector3(3.0, 0.1, 5.0))
	await _frames(5)
	var step := NextStepCard.next_step(world)
	_check(step.contains("HARDWARE") and NextStepCard.target == shovel, "the card points at the shovel on the bench (%s)" % step)
	world.add_money(-world.money)
	_check(not NextStepCard.next_step(world).contains("HARDWARE"), "and says nothing of it while the money is short")
	guide.load_index(0)


## The bank: ask, confirm, borrow; a quarter of every income goes back; the rest can be paid off.
func _bank(world: FoundryLevel, me: Player, loans: BankCounter, missions: Missions) -> void:
	var bank := world.bank
	var at := ScrapHallSet.BANK
	var outside := Transform3D(Basis(), Vector3(at.x, 0.06, at.z - 1.3))
	_check(not me.test_move(outside, Vector3(0, 0, 2.6)), "the bank's door is open")
	var inside := Transform3D(Basis(), Vector3(at.x, 0.06, at.z + 1.3))
	_check(me.test_move(inside, Vector3(0, 0, ScrapHallSet.COUNTER_Z)), "its counter is solid")
	me._do_teleport(loans.global_position + Vector3(0, 0.06, -0.55))
	await _frames(5)
	_check(loans.in_reach(me) and me.nearest_interactable() == loans, "standing at the counter, the loan is what [F] means")
	world.add_money(-world.money)
	_check(bank.debt == 0 and bank.next_sum() == 200 and loans.hint(me).contains("200 $ sofort, 230 $ zurück"), "the bank offers 200 $ for 230 $ (%s)" % loans.hint(me))
	# The first [F] only asks; the question runs out again.
	loans.interact(me)
	_check(bank.debt == 0 and world.money == 0 and loans.hint(me).begins_with("[F] Sicher?"), "the first [F] only asks (%s)" % loans.hint(me))
	loans._asked[me.peer_id] = [0.05, false]
	loans._confirm_left = 0.05
	await _frames(6)
	_check(not loans.hint(me).contains("Sicher"), "the question runs out")
	loans.interact(me)
	_check(bank.debt == 0, "after that, [F] asks anew")
	# The second [F] takes the loan. Borrowed money is not earned (the business track asks for earnings just now).
	missions.done[1] = 0
	missions.progress[1] = 0
	_check(missions.current(1).stat == &"earned", "a mission is counting what the crew earns")
	loans.interact(me)
	_check(bank.debt == 230 and bank.owed == 230 and world.money == 200, "the second [F] takes it: 200 $ in hand, 230 $ owed")
	_check(missions.progress[1] == 0, "the mission does not count borrowed money as earned")
	missions.done[1] = 3
	_check(loans.hint(me).contains("noch 230 $ offen"), "the counter says what is owed (%s)" % loans.hint(me))
	loans.interact(me)
	_check(bank.debt == 230 and world.money == 200, "too little money to pay it off: nothing happens")
	# A quarter of every income goes to the bank.
	world.add_money(100)
	_check(world.money == 275 and bank.debt == 205, "of 100 $ earned, 25 $ go to the bank (%d $ in hand, %d $ owed)" % [world.money, bank.debt])
	world.add_money(-40)
	_check(world.money == 235 and bank.debt == 205, "what is spent is spent in full")
	world.add_money(3)
	_check(world.money == 237 and bank.debt == 204, "small sums pay a full dollar each (%d $, %d $)" % [world.money, bank.debt])
	# The save file keeps the loan.
	var kept: Dictionary = bank.to_save()
	bank.load_save({})
	_check(bank.debt == 0 and bank.repaid == 0, "a save without a loan loads as none")
	bank.load_save(kept)
	_check(bank.debt == 204 and bank.owed == 230 and bank.repaid == 0 and bank.earned == 103, "the loan survives saving")
	# Paid off at the counter before the crew has earned what it owed: the bank lends no more than before.
	_check(loans.hint(me).begins_with("[F] Kredit ablösen · 204 $"), "with the money in hand the counter offers to pay it off (%s)" % loans.hint(me))
	loans.interact(me)
	_check(bank.debt == 204 and world.money == 237 and loans.hint(me).begins_with("[F] Sicher? 204 $ zahlen") and loans.hint(me).contains("größeren Kredit vorher noch 127 $ verdienen"),
		"paying off is asked first too, and the counter says that it comes too soon for a bigger loan (%s)" % loans.hint(me))
	loans.interact(me)
	_check(bank.debt == 0 and world.money == 33, "paid off: 204 $ gone, the books are clean")
	_check(bank.repaid == 0 and bank.next_sum() == 200, "handed straight back, the loan raises nothing: the bank lends 200 $ again")
	# A loan the crew has worked with (earned at least what it owed) raises the next one.
	loans.interact(me)
	loans.interact(me)
	_check(bank.debt == 230 and world.money == 233, "the same loan once more")
	world.add_money(240)
	_check(bank.debt == 170 and world.money == 413 and bank.trusts(), "240 $ earned with it: the bank will trust the crew (%d $ owed)" % bank.debt)
	loans.interact(me)
	_check(loans.hint(me).begins_with("[F] Sicher? 170 $ zahlen") and loans.hint(me).contains("abbezahlt"), "now the counter just asks (%s)" % loans.hint(me))
	loans.interact(me)
	_check(bank.debt == 0 and bank.repaid == 1 and world.money == 243, "paid off after working with it")
	_check(bank.next_sum() == 500 and loans.hint(me).contains("500 $ sofort, 575 $ zurück"), "the next loan is bigger (%s)" % loans.hint(me))
	# A slip of the finger after taking a loan does not pay it straight back with its interest.
	loans.interact(me)
	loans.interact(me)
	_check(bank.debt == 575 and world.money == 743, "the second loan: 500 $ for 575 $")
	loans.interact(me)
	_check(bank.debt == 575 and world.money == 743 and loans.hint(me).begins_with("[F] Sicher? 575 $ zahlen"), "a third [F] only asks whether to pay it back (%s)" % loans.hint(me))
	# The question was about paying off: once the loan is gone, the same [F] does not take a new one.
	bank._pay_down(575)
	_check(bank.debt == 0 and not loans.hint(me).contains("Sicher"), "a question about the old loan is closed when the loan is gone (%s)" % loans.hint(me))
	loans.interact(me)
	_check(bank.debt == 0 and bank.repaid == 1 and loans.hint(me).begins_with("[F] Sicher? 500 $ jetzt"), "and [F] asks anew for the next one (%s)" % loans.hint(me))
	loans._ask(me.peer_id, 0.0, false)
	# A loan paid off by the instalments alone.
	world.add_money(33 - world.money)
	loans.interact(me)
	loans.interact(me)
	_check(bank.debt == 575 and world.money == 533, "the second loan again: 500 $ for 575 $")
	world.add_money(4000)
	_check(bank.debt == 0 and bank.repaid == 2 and world.money == 533 + 4000 - 575, "one big income pays all of it and no more (%d $)" % world.money)
	world.add_money(100)
	_check(world.money == 533 + 4000 - 575 + 100, "after that, income is the crew's own again")


## The stall: laid out by hand and from the bucket, bought by the two customers.
func _stall(world: FoundryLevel, me: Player, stall: YardStall, missions: Missions) -> void:
	var walkers := stall.walkers
	_check(walkers != null and stall.customers.size() == 2, "two of the townspeople buy at the stall")
	if walkers == null or stall.customers.size() != 2:
		return
	# The walkers stand still for this: the test moves their clock by hand.
	walkers.set_physics_process(false)
	walkers.clock = walkers.time_at(int(stall.customers[0].round), 0) + 1.0
	_check(YardStall.find_price(&"scrap_kettle") == 30 and YardStall.find_price(&"scrap_ring") == 63 and YardStall.find_price(&"junk_bolt") == 3
		and YardStall.find_price(&"hot_pistol") == 0, "customers pay two and a half times the dealer's price, and nothing for hot goods")
	var bucket := get_tree().get_first_node_in_group(&"scrap_buckets") as ScrapBucket
	# While the crew saves for the furnace, the card names the bank, and the stall once something dear is in the bucket.
	var guide := world.guide
	for i in guide.letters().size():
		if guide.letters()[i].id == &"foundry_corner":
			guide.load_index(i)
	world.add_money(-world.money)
	bucket.contents = [&"junk_bolt", &"scrap_can"] as Array[StringName]
	bucket._changed()
	_check(NextStepCard.next_step(world).contains("Bank"), "saving for the furnace, the card names the bank (%s)" % NextStepCard.next_step(world))
	bucket.contents = [&"junk_bolt", &"scrap_ring"] as Array[StringName]
	bucket._changed()
	var nudge := NextStepCard.next_step(world)
	_check(nudge.contains("Verkaufstisch") and NextStepCard.target == stall, "with a ring in the bucket it points at the stall (%s)" % nudge)
	bucket.contents = [] as Array[StringName]
	bucket._changed()
	guide.load_index(0)
	var hot_info: Dictionary = FoundryRules.find_info(&"hot_pistol")
	var hot := world.spawn_item(&"hot_pistol", hot_info.color, hot_info.size, 0.4, Vector3(2.0, 0.3, 4.0))
	var kettle_info: Dictionary = FoundryRules.find_info(&"scrap_kettle")
	var kettle := world.spawn_item(&"scrap_kettle", kettle_info.color, kettle_info.size, 0.4, Vector3(2.5, 0.3, 4.0))
	var cast: CastPiece = world.spawn_entity({type = "cast", code = DrawingTemplates.drawing(&"house").to_code(), alloy = &"alu", quality = 0.6, pos = Vector3(3.0, 0.3, 4.0)})
	var glowing: CastPiece = world.spawn_entity({type = "cast", code = DrawingTemplates.drawing(&"house").to_code(), alloy = &"alu", quality = 0.6,
		temperature = 0.8, pos = Vector3(3.5, 0.3, 4.0)})
	await _frames(3)
	_check(stall.toss_accepts(kettle) and stall.toss_accepts(cast) and not stall.toss_accepts(hot) and not stall.toss_accepts(bucket) and not stall.toss_accepts(glowing),
		"the table takes finds and cold castings, no hot goods, no bucket, nothing that still glows")
	_check(YardStall.price_of(cast) == ceili(cast.value() * 1.3) and cast.value() > 0, "a casting brings 30 %% more than in the sales crate (%d $ for %d $)" % [YardStall.price_of(cast), cast.value()])
	_check(stall.toss_hint(kettle).contains("30 $"), "the hint says what the customers pay (%s)" % stall.toss_hint(kettle))
	glowing.free()
	_check(NextStepCard.next_step(world).contains("Verkaufskiste"), "a casting lying about: the card sends it to the sales crate")
	# By hand: let go in front of the table.
	me._do_teleport(stall.global_position + Vector3(-0.6, 0.06, -1.3))
	await _frames(5)
	me.facing = 0.0
	me.rotation.y = 0.0
	kettle.global_position = me.global_position + Vector3(0, 1.0, 0.7)
	kettle.linear_velocity = Vector3.ZERO
	await _frames(2)
	me.grab(kettle)
	await _frames(3)
	me.facing = 0.0
	me.rotation.y = 0.0
	_check(me.held == kettle and me.toss_target(kettle) == stall, "in front of the stall the table is where a find in the hands goes")
	me.release()
	await _frames(30)
	_check(kettle in stall.goods() and absf(kettle.global_position.y - (YardStall.TOP + 0.13)) < 0.12, "let go, the kettle lies on the table (%.2f m up)" % kettle.global_position.y)
	_check(stall.toss_place(cast), "the casting is laid beside it")
	await _frames(30)
	_check(stall.goods().size() == 2 and stall.free_places().size() == 6, "two pieces lie out, six places are free")
	_check(not NextStepCard.next_step(world).contains("Verkaufskiste"), "laid out on the stall it is where it belongs: the card goes on (%s)" % NextStepCard.next_step(world))
	# What a player holds over the table is not on it (peers know it from the carrier, not from the thing).
	_check(kettle in stall.goods(), "(the kettle lies out)")
	me.grab(kettle)
	var holders := kettle._holders
	kettle._holders = 0
	_check(me.held_item() == kettle and kettle not in stall.goods(), "a find in somebody's hands is not for sale, whoever looks")
	kettle._holders = holders
	me.release()
	await _frames(30)
	_check(kettle in stall.goods() and stall.goods().size() == 2, "let go again, it lies out again")
	# From the bucket: the dearest finds first, hot goods stay in it.
	bucket.contents = [&"junk_bolt", &"hot_pistol", &"scrap_ring", &"scrap_can"] as Array[StringName]
	bucket._changed()
	me.grab(bucket)
	await _frames(3)
	_check(bucket.held_hint(me).contains("3 besten Funde"), "with the bucket in hand the stall offers to lay out its finds (%s)" % bucket.held_hint(me))
	bucket.use_start(me)
	await _frames(30)
	_check(bucket.count == 1 and bucket.hot == 1 and stall.goods().size() == 5, "three finds go on the table, the pistol stays in the bucket (%d on the table)" % stall.goods().size())
	me.release()
	await _frames(3)
	# The collector comes: he looks first, then takes one piece, a find.
	var money := world.money
	var progress := missions.progress[1]
	var finds_sold := int(guide.stats.get("scrap_sold", 0))
	var casts_sold := int(guide.stats.get("sold", 0))
	var collector: Dictionary = stall.customers[0]
	var shopper: Dictionary = stall.customers[1]
	var cast_price := YardStall.price_of(cast)
	# (One customer at a time, so that the other does not happen to stand at the table too.)
	stall.customers = [collector]
	stall._laps.clear()
	walkers.clock = walkers.time_at(int(collector.round), int(collector.stop)) + 1.0
	await _frames(5)
	_check(world.money == money and stall.goods().size() == 5, "the collector looks the table over first")
	walkers.clock = walkers.time_at(int(collector.round), int(collector.stop)) + YardStall.LOOK_TIME + 0.3
	await _frames(5)
	var paid := world.money - money
	_check(stall.goods().size() == 4 and paid in [30, 63, 5, 3], "then he takes one piece and pays for it (%d $)" % paid)
	_check(is_instance_valid(cast) and not cast.is_queued_for_deletion(), "he likes old things: the casting stays")
	_check(missions.progress[1] == progress + 1, "the sale counts for the mission")
	_check(int(guide.stats.get("scrap_sold", 0)) == finds_sold + 1 and int(guide.stats.get("sold", 0)) == casts_sold, "and for Onkel Heinz as scrap sold")
	await _frames(20)
	_check(stall.goods().size() == 4, "one piece per visit")
	# The young woman likes castings.
	money = world.money
	stall.customers = [shopper]
	stall._laps.clear()
	walkers.clock = walkers.time_at(int(shopper.round), int(shopper.stop)) + YardStall.LOOK_TIME + 0.3
	await _frames(5)
	_check(not is_instance_valid(cast) and stall.goods().size() == 3, "the young woman takes the casting")
	_check(world.money - money == cast_price, "and pays what it is worth to her (%d $)" % (world.money - money))
	_check(int(guide.stats.get("sold", 0)) == casts_sold + 1, "a casting sold here is a casting sold: Onkel Heinz's letter counts it")
	# An empty table sells nothing.
	for item: Item in stall.goods():
		item.free()
	money = world.money
	stall.customers = [collector, shopper]
	stall._laps.clear()
	walkers.clock = walkers.time_at(int(collector.round), int(collector.stop)) + YardStall.LOOK_TIME + 0.3
	await _frames(5)
	_check(world.money == money and stall._laps.has(0), "nothing on the table, nothing sold")
	walkers.set_physics_process(true)


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
	print("SHOPS TESTS %s (%d failures)" % ["PASSED" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures > 0 else 0)
