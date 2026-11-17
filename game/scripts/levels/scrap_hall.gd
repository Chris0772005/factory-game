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
		_announce("DER BAGGER IST DA!", "Er lädt den Berg in die Mulde – an der Mulde F drücken, dann holt Kowalski sie ab")
	if not _truck_built and has_upgrade(&"truck"):
		_truck_built = true
		var truck := ScrapTruck.new()
		truck.park = ScrapHallSet.TRUCK_PARK
		truck.dock = ScrapHallSet.TRUCK_DOCK
		truck.lane_z = ScrapHallSet.TRUCK_LANE_Z
		truck.skip = get_tree().get_first_node_in_group(ScrapSkip.GROUP) as ScrapSkip
		add_child(truck)
		_announce("DEIN LKW STEHT VOR DER HALLE!", "Er fährt jede volle Mulde von selbst weg – Großhandelspreis")


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
