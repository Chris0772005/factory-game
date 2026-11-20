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
## under the counter, the police desk that pays a finder's reward, and the
## officer on the beat.
func _build_town() -> void:
	add_child(TownLaw.new())
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
	var cop := PolicePatrol.new()
	cop.name = "Patrol"
	cop.route = [Vector3(-23.0, 0, ScrapHallSet.BEAT_Z), Vector3(24.0, 0, ScrapHallSet.BEAT_Z)]
	cop.position = Vector3(14.0, 0.05, ScrapHallSet.BEAT_Z)
	cop.max_z = ScrapHallSet.FRONT_Z - 0.8
	add_child(cop)
	_build_walkers()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mates="):
			_debug_mates(arg.trim_prefix("--mates="))


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


## Three people who go about their business on the far pavement: from the station to the pawnbroker
## and the dealer and back, between the empty shop, the dealer and the bench, and from the kiosk to
## the pawnbroker's window.
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
	walkers.add_round("Casual_Woman", {}, [
		[Vector3(-21.0, 0, front - 1.0), 8.0, Vector3(-21.0, 0, front)],
		[Vector3(-20.0, 0, east), 0.0],
		[Vector3(-0.2, 0, east), 0.0],
		[Vector3(1.0, 0, front - 0.95), 6.0, Vector3(1.0, 0, front + 2.0)],
		[Vector3(2.2, 0, east), 0.0],
		[Vector3(13.0, 0, east), 0.0],
		[Vector3(14.0, 0, front - 1.25), 12.0, Vector3(14.0, 0, front - 6.0)],
		[Vector3(12.8, 0, west), 0.0],
		[Vector3(-20.0, 0, west), 0.0],
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
