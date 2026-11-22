extends FoundryLevel
## Level 1 – Schrotthalle: the game starts in front of a mountain of scrap in
## Onkel Heinz's old shed. First by hand: dig, fill the bucket, carry it
## across the street to the scrap dealer. The money buys gloves, a shovel, a
## bigger bucket – and then the foundry corner (furnace, molds, drawing
## bench), where the metal from the heap becomes castings worth many times
## the scrap price. Conveyor and grab arm follow; the garage is the next plot.
## Set: ScrapHallSet, light: GarageLighting in its daylight grade.

const SPAWN := Vector3(3.2, 0.2, 5.6)
const FURNACE_POS := Vector3(6.6, 0, -4.8)

var _corner_built := false
var _bench_built := false
var _digger_built := false
var _truck_built := false
var _items_spawned := false


func build_level() -> void:
	register_entity("scrap_bucket", ScrapBucket.create_bucket)
	super()


func build_stations() -> void:
	GarageLighting.build(self)
	GarageLighting.daylight(self)
	var heap := ScrapMountain.new()
	heap.position = Vector3(-1.2, 0, -2.0)
	add_child(heap)
	var shop := ScrapShop.new()
	# The bin stands at the dealer's counter across the street, open side to the hall.
	shop.position = Vector3(3.0, 0, 8.12 + ScrapHallSet.SHOP_Z + 0.4)
	shop.rotation.y = PI
	add_child(shop)
	var board := UpgradeBoard.new()
	board.position = Vector3(13.6, 0, 2.0)
	board.rotation.y = -PI * 0.5
	add_child(board)
	ScrapHallSet.build_hall(self, [heap, shop, board])
	_build_town()
	for at: Vector3 in [Vector3(-4.0, 7.2, 3.0), Vector3(5.0, 7.2, -1.0)]:
		SwayLamp.hang(self, at, 1.6)


## The quarter across the street: the law, the pawnbroker who buys hot goods
## under the counter, the police desk that pays a finder's reward, the
## officer on the beat, the hardware store's tools, the bank's loans and the
## crew's own stall with the people who buy there.
func _build_town() -> void:
	add_child(TownLaw.new())
	add_child(CrewBoost.new())
	# The diner's two places to order: coffee by the till, the stew next to it.
	for order: Array in [[&"coffee", ScrapHallSet.DINER_COFFEE_X], [&"meal", ScrapHallSet.DINER_MEAL_X]]:
		var place := DinerCounter.new()
		place.kind = order[0]
		place.position = ScrapHallSet.DINER + Vector3(order[1], 0, ScrapHallSet.COUNTER_Z - 0.3)
		add_child(place)
	add_child(Missions.new())
	var fence := FenceCounter.new()
	fence.position = ScrapHallSet.PAWN + Vector3(0, 0, ScrapHallSet.COUNTER_Z)
	add_child(fence)
	var dark := OrderBoard.new()
	dark.name = "DarkBoard"
	dark.dark = true
	dark.first_order = &"dark_knuckles"
	dark.position = ScrapHallSet.PAWN + Vector3(-4.0 + TownBlock.WALL + 0.03, 0, 1.95)
	dark.rotation.y = PI * 0.5
	add_child(dark)
	var desk := PoliceDesk.new()
	desk.position = ScrapHallSet.POLICE + Vector3(0, 0, ScrapHallSet.COUNTER_Z)
	add_child(desk)
	# The hardware store's bench: the hand tools, each bought where it lies. The bank's counter: loans.
	for i in TownShops.OFFERS.size():
		var offer := ToolOffer.new()
		offer.upgrade = TownShops.OFFERS[i][0]
		offer.name = "Offer_%s" % offer.upgrade
		offer.position = TownShops.offer_spot(i)
		offer.rotation.y = PI
		add_child(offer)
	var loans := BankCounter.new()
	loans.position = TownShops.loan_spot()
	add_child(loans)
	# The storage auctions under the viaduct: four lock-ups and the auctioneer in front of them. Two
	# lots wait from the start, the others come one after the other.
	var bays := TownStreets.lockups()
	for i in bays.size():
		var unit := StorageLockup.new()
		unit.bay = bays[i]
		unit.number = i + 1
		unit.name = "Lockup_%d" % (i + 1)
		unit.position = TownStreets.door_spot(bays[i])
		add_child(unit)
		if Network.is_sim_authority() and not attract_mode:
			if i < 2:
				unit.stock()
			else:
				unit.rest(45.0 * (i - 1))
	# The post office beyond the eastern side street: mail orders, handed over at its counter. The
	# board hangs on the wall behind the postmistress.
	var post := PostOffice.new()
	post.transform = TownShops.post_spot()
	post.board_at = Vector3(0, 1.92, ScrapHallSet.HOUSE_D - TownBlock.WALL - 0.03 - (ScrapHallSet.COUNTER_Z - 0.3))
	post.board_yaw = 180.0
	add_child(post)
	var auction := StorageAuction.new()
	auction.position = Vector3(-TownStreets.ARCADE + TownStreets.pitch() * (bays[1] + 1), 0, TownStreets.VIADUCT_Z - 1.25)
	add_child(auction)
	var cop := PolicePatrol.new()
	cop.name = "Patrol"
	cop.route = [Vector3(-ScrapHallSet.BEAT_X, 0, ScrapHallSet.BEAT_Z), Vector3(ScrapHallSet.BEAT_X, 0, ScrapHallSet.BEAT_Z)]
	cop.position = Vector3(14.0, 0.05, ScrapHallSet.BEAT_Z)
	# He follows round the block and through the two passages, but not into the houses of the row.
	var row := ScrapHallSet.BANK.x + ScrapHallSet.SHOP_W * 0.5 + 0.4
	cop.keep_out = Rect2(-row, ScrapHallSet.FRONT_Z - 0.8, row * 2.0, TownStreets.BACK_NEAR + 0.5 - ScrapHallSet.FRONT_Z + 0.8)
	# (The ways as wide as a worker can stand in them; the lines he walks: past the dumpster in the
	# passage and between the pillars at its far end, and down the middle of the alley.)
	cop.ways = [Vector2(TownStreets.PASSAGE.x + 0.3, TownStreets.PASSAGE.y - 0.3), Vector2(TownStreets.ALLEY_EAST.x + 0.3, TownStreets.ALLEY_EAST.y - 0.3)]
	cop.lanes = [-3.1, (TownStreets.ALLEY_EAST.x + TownStreets.ALLEY_EAST.y) * 0.5] as Array[float]
	add_child(cop)
	_build_walkers()
	# The town's cars drive down the street.
	var traffic := TownTraffic.new()
	add_child(traffic)
	traffic.setup(ScrapHallSet.TRAFFIC_LANE_Z, ScrapHallSet.SIDE_X, TownStreets.NORTH_Z, TownStreets.NORTH_RUN)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mates="):
			_debug_mates(arg.trim_prefix("--mates="))
		elif arg.begins_with("--cars="):
			# Art check: cars standing on the street, each so many metres along their way (TownTraffic).
			traffic.frozen = true
			var parked := 0
			for at in arg.trim_prefix("--cars=").split_floats(","):
				traffic.send_car(parked % TownTraffic.MODELS.size(), at)
				parked += 1
		elif arg.begins_with("--walk="):
			# Art check: the people on the pavement as they are that many seconds into their rounds
			# (a picture is taken some twenty seconds of play later).
			(get_node(^"TownWalkers") as TownWalkers).clock = float(arg.trim_prefix("--walk="))
		elif arg.begins_with("--stall="):
			# Art check: so many finds lie on the stall's table, and its first customer stands at it.
			_debug_stall(int(arg.trim_prefix("--stall=")))
		elif arg.begins_with("--lot="):
			# Art check: lock-up N stands open with a won lot of that kind in it ("2,1": lock-up 2, workshop);
			# with "bid" as a third part the crew has just bid on it instead and the auctioneer calls it out.
			var lot := arg.trim_prefix("--lot=").split(",")
			var unit := get_node_or_null("Lockup_%d" % int(lot[0])) as StorageLockup
			if unit and lot.size() > 2 and lot[2] == "bid":
				unit.stock(int(lot[1]), 9)
				add_money(500)
				_debug_bid.call_deferred(unit)
			elif unit:
				unit.stock(int(lot[1]) if lot.size() > 1 else 0, 11)
				unit.bid = unit.opening
				unit._lay_out()
				unit.state = StorageLockup.State.WON
				unit._publish()
		elif arg.begins_with("--debt="):
			# Art check: the crew owes the bank so much (the pill on the HUD).
			bank.owed = maxi(int(arg.trim_prefix("--debt=")) * 2, 1)
			bank.debt = int(arg.trim_prefix("--debt="))
		elif arg == "--boost":
			# Art check: the crew has had coffee and stew at the diner (the pills on the HUD).
			CrewBoost.of(get_tree()).left = {&"coffee": 152.0, &"meal": 221.0}


## Art check: the crew has just bid on `unit`'s lot; the count stands still and the auctioneer's call
## stays up, however long the picture takes.
func _debug_bid(unit: StorageLockup) -> void:
	unit.place_bid()
	unit.set_physics_process(false)
	var auction := StorageAuction.of(get_tree())
	if auction:
		auction._bubble_left = 100000.0


## Art check: `count` finds on the stall's table (the dearest kinds first) and the first customer in
## front of it, looking them over.
func _debug_stall(count: int) -> void:
	await get_tree().create_timer(1.0).timeout
	var stall := get_tree().get_first_node_in_group(YardStall.GROUP) as YardStall
	if stall == null:
		return
	var kinds := FoundryRules.SCRAP.keys()
	kinds.sort_custom(func(a: StringName, b: StringName) -> bool: return FoundryRules.raw_price(a) > FoundryRules.raw_price(b))
	var free := stall.free_places()
	for i in mini(count, free.size()):
		var kind: StringName = kinds[i % kinds.size()]
		var info: Dictionary = FoundryRules.find_info(kind)
		var item := spawn_item(kind, info.color, info.size, 0.4, stall.to_global(stall.place_pos(free[i]) + Vector3(0, 0.12, 0)))
		item.rotation.y = i * 1.3
	if not stall.customers.is_empty():
		var who: Dictionary = stall.customers[0]
		stall.walkers.clock = stall.walkers.time_at(int(who.round), int(who.stop)) - 16.0


## Art check: `--mates=x,z,yaw,x,z,yaw` stands two fellow players' workers there (place and turn in
## degrees of each), as the others see them: the first digs with the bare hands, the second
## carries a find at a walk.
func _debug_mates(spots: String) -> void:
	_stand_mates(spots.split_floats(","), 1.33)


## Two workers without players (WorkerStandIn), for pictures: `spots` holds place (x, z) and turn
## (degrees) of each; the first digs in the heap, the second holds a find and goes at `pace` m/s
## on the spot (0: stands).
func _stand_mates(spots: Array, pace: float) -> void:
	var states := [{working = true}, {hold = Vector3(0, 1.14, 0.8), find = &"scrap_kettle", vel = pace}]
	for i in mini(states.size(), spots.size() / 3):
		var mate := WorkerStandIn.new()
		mate.color = GameWorld.PLAYER_COLORS[i + 1]
		mate.state = states[i]
		mate.position = Vector3(spots[i * 3], 0.0, spots[i * 3 + 1])
		mate.rotation.y = deg_to_rad(spots[i * 3 + 2])
		add_child(mate)


## The people of the quarter (the two who buy at the crew's stall follow in `_build_stall`).
## Five people who go about their business on the far pavement: from the station to the pawnbroker
## and the dealer and back, between the diner, the dealer and the bench, from the kiosk to the
## pawnbroker's window, an old woman from the corner to the diner and the pawnbroker's window, and a
## mechanic from the dealer's to his coffee.
func _build_walkers() -> void:
	var walkers := TownWalkers.new()
	walkers.name = "TownWalkers"
	add_child(walkers)
	var front := ScrapHallSet.FRONT_Z
	var pawn := ScrapHallSet.PAWN
	var police := ScrapHallSet.POLICE
	var pawn_door := pawn.x - 2.6
	var counter := ScrapHallSet.COUNTER_Z
	# Two lanes on the pavement, so those who meet pass each other: westwards nearer the kerb.
	var west := front - 2.9
	var east := front - 1.9
	walkers.add_round("Casual", {}, [
		[Vector3(police.x - 3.0, 0, front + 1.7), 7.0, police + Vector3(0, 0, counter)],
		[Vector3(police.x, 0, front + 1.3), 0.0],
		[Vector3(police.x, 0, front - 0.6), 0.0],
		[Vector3(police.x - 1.4, 0, west), 0.0],
		[Vector3(pawn_door + 1.4, 0, west), 0.0],
		[Vector3(pawn_door, 0, front - 0.6), 0.0],
		[Vector3(pawn_door, 0, front + 1.0), 0.0],
		[Vector3(pawn.x + 0.4, 0, front + counter - 0.85), 9.0, pawn + Vector3(0.7, 0, counter + 1.1)],
		[Vector3(pawn_door, 0, front + 1.0), 0.0],
		[Vector3(pawn_door, 0, front - 0.6), 0.0],
		[Vector3(pawn_door + 1.4, 0, east), 0.0],
		[Vector3(4.2, 0, east), 0.0],
		[Vector3(5.4, 0, front - 0.95), 7.0, Vector3(5.4, 0, front + 2.0)],
		[Vector3(6.8, 0, east), 0.0],
		[Vector3(police.x - 1.4, 0, east), 0.0],
		[Vector3(police.x, 0, front - 0.6), 0.0],
		[Vector3(police.x, 0, front + 1.3), 0.0],
	])
	var diner := ScrapHallSet.DINER
	var diner_door := diner.x + ScrapHallSet.DINER_DOOR_X
	walkers.add_round("Casual_Woman", {}, [
		[Vector3(diner.x + 0.95, 0, front + counter - 0.85), 10.0, diner + Vector3(ScrapHallSet.DINER_COOK_X, 0, counter + 1.1)],
		[Vector3(diner_door, 0, front + 1.0), 0.0],
		[Vector3(diner_door, 0, front - 0.6), 0.0],
		[Vector3(-16.0, 0, east), 0.0],
		[Vector3(-0.2, 0, east), 0.0],
		[Vector3(1.0, 0, front - 0.95), 6.0, Vector3(1.0, 0, front + 2.0)],
		[Vector3(2.2, 0, east), 0.0],
		[Vector3(13.0, 0, east), 0.0],
		[Vector3(14.0, 0, front - 1.25), 12.0, Vector3(14.0, 0, front - 6.0)],
		[Vector3(12.8, 0, west), 0.0],
		[Vector3(diner_door + 1.2, 0, west), 0.0],
		[Vector3(diner_door, 0, front - 0.6), 0.0],
		[Vector3(diner_door, 0, front + 1.0), 0.0],
	], 30.0)
	# The old man strolls. He keeps to a lane of his own along the tree pits, so nobody has to pass
	# through him.
	var slow := front - 3.5
	walkers.add_round("Worker", {}, [
		[Vector3(24.3, 0, front - 0.9), 10.0, Vector3(24.3, 0, front)],
		[Vector3(23.2, 0, slow), 0.0],
		[Vector3(-7.4, 0, slow), 0.0],
		[Vector3(-9.0, 0, front - 0.85), 6.0, Vector3(-9.0, 0, front + 2.0)],
		[Vector3(-7.4, 0, slow), 0.0],
		[Vector3(23.2, 0, slow), 0.0],
	], 55.0, 0.75)
	# The old woman: from the hardware store's window to her coffee at the diner, a look into the
	# pawnbroker's window and back again, slowly, along the houses.
	var hardware := ScrapHallSet.HARDWARE
	var by_wall := front - 1.45
	walkers.add_round("Granny", {}, [
		[Vector3(hardware.x - 2.9, 0, front - 1.0), 7.0, Vector3(hardware.x - 2.9, 0, front + 2.0)],
		[Vector3(hardware.x - 1.5, 0, by_wall), 0.0],
		[Vector3(diner_door - 1.0, 0, by_wall), 0.0],
		[Vector3(diner_door, 0, front - 0.6), 0.0],
		[Vector3(diner_door, 0, front + 1.0), 0.0],
		[Vector3(diner.x - 0.6, 0, front + counter - 0.85), 14.0, diner + Vector3(ScrapHallSet.DINER_COOK_X, 0, counter + 1.1)],
		[Vector3(diner_door, 0, front + 1.0), 0.0],
		[Vector3(diner_door, 0, front - 0.6), 0.0],
		[Vector3(-13.0, 0, by_wall), 0.0],
		[Vector3(-10.2, 0, front - 0.85), 7.0, Vector3(-10.2, 0, front + 2.0)],
		[Vector3(-13.0, 0, by_wall), 0.0],
		[Vector3(diner_door + 1.0, 0, by_wall), 0.0],
		[Vector3(hardware.x - 1.5, 0, by_wall), 0.0],
	], 12.0, 0.7)
	# The mechanic from the workshop under the viaduct: a look at its shutter, through the alley beside
	# the bank, something for the dealer, then his coffee, and back the same way.
	var alley := (TownStreets.ALLEY_EAST.x + TownStreets.ALLEY_EAST.y) * 0.5
	var garage := Vector3(TownStreets.bay_x(13), 0, TownStreets.VIADUCT_Z - 1.0)
	walkers.add_round("Mechanic", {}, [
		[garage, 8.0, garage + Vector3(0, 0, 2.0)],
		[Vector3(alley, 0, TownStreets.BACK_KERB_N + 0.6), 0.0],
		[Vector3(alley, 0, TownStreets.BACK_NEAR + 0.9), 0.0],
		[Vector3(alley, 0, front - 0.6), 0.0],
		[Vector3(alley - 1.6, 0, west), 0.0],
		[Vector3(8.0, 0, west), 0.0],
		[Vector3(4.4, 0, front - 0.95), 8.0, Vector3(4.4, 0, front + 2.0)],
		[Vector3(3.0, 0, west), 0.0],
		[Vector3(diner_door + 1.2, 0, west), 0.0],
		[Vector3(diner_door, 0, front - 0.6), 0.0],
		[Vector3(diner_door, 0, front + 1.0), 0.0],
		[Vector3(diner.x + 0.2, 0, front + counter - 0.85), 12.0, diner + Vector3(ScrapHallSet.DINER_COOK_X, 0, counter + 1.1)],
		[Vector3(diner_door, 0, front + 1.0), 0.0],
		[Vector3(diner_door, 0, front - 0.6), 0.0],
		[Vector3(diner_door + 1.4, 0, east), 0.0],
		[Vector3(alley - 1.6, 0, east), 0.0],
		[Vector3(alley, 0, front - 0.6), 0.0],
		[Vector3(alley, 0, TownStreets.BACK_NEAR + 0.9), 0.0],
		[Vector3(alley, 0, TownStreets.BACK_KERB_N + 0.6), 0.0],
	], 80.0)
	_build_stall(walkers, west, east)


## The crew's stall on the apron and the two who buy there: an old collector who comes from the
## hardware store, and a young woman from the bank. Both cross at the zebra, look the table over,
## take one piece if there is one, and go back the way they came.
func _build_stall(walkers: TownWalkers, west: float, east: float) -> void:
	var stall := YardStall.new()
	stall.position = ScrapHallSet.STALL
	add_child(stall)
	stall.walkers = walkers
	var front := ScrapHallSet.FRONT_Z
	var zf := 8.125
	# The two ends of the zebra crossing: on the far pavement and on the apron.
	var far_end := zf + ScrapHallSet.APRON + ScrapHallSet.ROAD + 0.4
	var near_end := zf + ScrapHallSet.APRON - 0.4
	var at_table := ScrapHallSet.STALL.z + YardStall.SIZE.y * 0.5 + 0.52
	var hardware := ScrapHallSet.HARDWARE
	var bank := ScrapHallSet.BANK
	var collector_at := Vector3(ScrapHallSet.STALL.x - 0.45, 0, at_table)
	var collector := walkers.add_round("Collector", {}, [
		[hardware + TownShops.HW_CUSTOMER, 8.0, hardware + TownShops.CLERK],
		[Vector3(hardware.x, 0, front + 1.0), 0.0],
		[Vector3(hardware.x, 0, front - 0.6), 0.0],
		[Vector3(hardware.x + 1.4, 0, east), 0.0],
		[Vector3(2.9, 0, east), 0.0],
		[Vector3(3.9, 0, far_end), 0.0],
		[Vector3(3.9, 0, near_end), 0.0],
		[collector_at, 9.0, ScrapHallSet.STALL + Vector3(-0.45, 0, 0)],
		[Vector3(4.5, 0, near_end), 0.0],
		[Vector3(4.5, 0, far_end), 0.0],
		[Vector3(3.5, 0, west), 0.0],
		[Vector3(hardware.x + 1.4, 0, west), 0.0],
		[Vector3(hardware.x, 0, front - 0.6), 0.0],
		[Vector3(hardware.x, 0, front + 1.0), 0.0],
	], 20.0, 1.0)
	var shopper_at := Vector3(ScrapHallSet.STALL.x + 0.5, 0, at_table)
	var shopper := walkers.add_round("Shopper", {}, [
		[bank + Vector3(TownShops.QUEUE_X, 0, ScrapHallSet.COUNTER_Z - 0.85), 9.0, bank + Vector3(TownShops.QUEUE_X, 0, ScrapHallSet.COUNTER_Z + 1.0)],
		[Vector3(bank.x, 0, front + 1.0), 0.0],
		[Vector3(bank.x, 0, front - 0.6), 0.0],
		[Vector3(bank.x - 1.4, 0, west), 0.0],
		[Vector3(6.6, 0, west), 0.0],
		[Vector3(5.6, 0, far_end), 0.0],
		[Vector3(5.6, 0, near_end), 0.0],
		[shopper_at, 9.0, ScrapHallSet.STALL + Vector3(0.5, 0, 0)],
		[Vector3(5.0, 0, near_end), 0.0],
		[Vector3(5.0, 0, far_end), 0.0],
		[Vector3(6.0, 0, east), 0.0],
		[Vector3(bank.x - 1.4, 0, east), 0.0],
		[Vector3(bank.x, 0, front - 0.6), 0.0],
		[Vector3(bank.x, 0, front + 1.0), 0.0],
	], 70.0)
	stall.customers = [
		{round = collector, stop = 7, taste = &"finds", at = collector_at},
		{round = shopper, stop = 7, taste = &"castings", at = shopper_at},
	]


func is_scrap_hall() -> bool:
	return true


func _apply_upgrades() -> void:
	super()
	_ensure_foundry()
	_ensure_machines()


## Workbench, excavator with its skip, and the truck arrive when they are bought.
func _ensure_machines() -> void:
	if not _bench_built and has_upgrade(&"workbench"):
		_bench_built = true
		var bench := Workbench.new()
		bench.position = ScrapHallSet.WORKBENCH_POS
		add_child(bench)
		_announce("WERKBANK STEHT!", "Hinten links in der Halle: Eimer mit Altblech, Federn, Schrauben hinbringen und F")
	if not _digger_built and has_upgrade(&"excavator"):
		_add_digger()
		_announce("DER BAGGER IST DA!", "Er lädt den Berg in die Mulde – an der Mulde F drücken, dann holt Kowalski sie ab")
	if not _truck_built and has_upgrade(&"truck"):
		_add_truck()
		_announce("DEIN LKW STEHT VOR DER HALLE!", "Er fährt jede volle Mulde von selbst weg – Großhandelspreis")


## The skip by the hall door and the excavator that loads it.
func _add_digger() -> ScrapSkip:
	_digger_built = true
	var skip := ScrapSkip.new()
	skip.position = ScrapHallSet.SKIP_POS
	add_child(skip)
	var digger := Excavator.new()
	digger.heap = get_tree().get_first_node_in_group(&"scrap_piles") as ScrapPile
	digger.skip = skip
	digger.position = ScrapHallSet.DIGGER_POS
	# Tracks towards the heap.
	digger.rotation.y = PI
	add_child(digger)
	return skip


func _add_truck() -> void:
	_truck_built = true
	var truck := ScrapTruck.new()
	truck.park = ScrapHallSet.TRUCK_PARK
	truck.dock = ScrapHallSet.TRUCK_DOCK
	truck.lane_z = ScrapHallSet.TRUCK_LANE_Z
	truck.turn_x = ScrapHallSet.SIDE_X
	truck.turn_z = TownStreets.NORTH_Z
	truck.turn_run = TownStreets.NORTH_RUN
	truck.skip = get_tree().get_first_node_in_group(ScrapSkip.GROUP) as ScrapSkip
	add_child(truck)


## The hall behind the main menu (attract mode): mid-shift, as it looks once the machines are
## bought. The excavator loads the skip, which starts two thirds full, and the truck hauls it
## away when it is full. Nothing here is saved or announced.
func attract_show() -> void:
	if _digger_built or _truck_built:
		return
	var skip := _add_digger()
	skip.count = 40
	skip.worth = 40 * FoundryRules.raw_price(&"scrap")
	skip._update_look()
	_add_truck()
	# Two mates at the heap: one digs with the bare hands, one has found a copper kettle.
	_stand_mates([0.9, 1.5, 212.0, -1.4, 3.8, -9.0], 0.0)


func _announce(title: String, subtitle: String) -> void:
	if _items_spawned and Network.is_sim_authority():
		banner_all(title, UITheme.ACCENT, subtitle)


## The foundry corner arrives when it is bought (or with a save that owns it).
func _ensure_foundry() -> void:
	if _corner_built or not has_upgrade(&"foundry_corner"):
		return
	_corner_built = true
	var furnace := Furnace.new()
	furnace.position = FURNACE_POS
	add_child(furnace)
	var bench := ModelBench.new()
	bench.position = Vector3(10.6, 0, -8.6)
	add_child(bench)
	for i in 2:
		var mold := MoldBox.new()
		mold.position = Vector3(6.4 + i * 2.8, 0, -0.9)
		add_child(mold)
	var orders := OrderBoard.new()
	orders.first_order = &"motif_house"
	orders.position = Vector3(13.99, 0, -3.2)
	orders.rotation.y = -PI * 0.5
	add_child(orders)
	if get_node_or_null(^"ScrapLine") == null:
		ScrapLine.build_for(self)
	if get_node_or_null(^"AutoFoundry") == null:
		AutoFoundry.build_for(self)
	if _items_spawned and Network.is_sim_authority():
		_spawn_foundry_items()
		banner_all("GIESSEREI-ECKE STEHT!", UITheme.ACCENT, "Metall aus dem Eimer in den Ofen kippen – dann gießen")


func _spawn_foundry_items() -> void:
	spawn_entity({type = "crucible", pos = FURNACE_POS + Vector3(0, 0.15, 0)})
	spawn_entity({type = "hammer", pos = hammer_spot()})


func spawn_items() -> void:
	_items_spawned = true
	spawn_entity({type = "scrap_bucket", pos = Vector3(1.4, 0.1, 0.4)})
	if _corner_built:
		_spawn_foundry_items()


func hammer_spot() -> Vector3:
	return Vector3(7.8, 0.1, 0.9)


func spawn_position(index: int) -> Vector3:
	return SPAWN + Vector3(index * 1.2 - 1.2, 0, 0)


func respawn_point(_player: Player) -> Vector3:
	return SPAWN + Vector3(randf_range(-1.0, 1.0), 0.1, 0)


## Beyond the viaduct (and under the ground) nobody gets back in on foot.
func out_of_bounds(at: Vector3) -> bool:
	return at.y < -6.0 or at.z > TownStreets.VIADUCT_Z + TownStreets.VIADUCT_D + 0.5
