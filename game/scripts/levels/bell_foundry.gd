extends FoundryLevel
## Level 3 – Glockengießerei: an old bell foundry hall. Bells are drawn as
## silhouettes at the profile benches, turned in loam in the casting pits,
## poured in one go from two furnaces' worth of crucibles, dug out and rung.
## The garage stations stay (mold box, trough, crates) for small castings.
## Set: BellHallSet, light: GarageLighting.

const SPAWN := Vector3(0.6, 0.2, 4.4)


func build_level() -> void:
	register_entity("bucket", WaterBucket.create_bucket)
	register_entity("sealed_crate", SealedCrate.create_crate)
	register_entity("pendant", ChainHoist.Pendant.create_pendant)
	super()


func build_stations() -> void:
	GarageLighting.build(self)
	for p: Vector3 in [Vector3(-5.6, 0, -3.7), Vector3(-3.0, 0, -4.0)]:
		var furnace := Furnace.new()
		furnace.position = p
		add_child(furnace)
	var scrap := ScrapPile.new()
	scrap.position = Vector3(-7.0, 0, -1.6)
	add_child(scrap)
	var crates := CrateDelivery.new()
	crates.position = Vector3(-6.9, 0, 0.5)
	crates.rotation.y = PI * 0.5
	add_child(crates)
	for i in 2:
		var bench := ModelBench.new()
		bench.bell_mode = true
		bench.position = Vector3(3.8 + i * 2.3, 0, -4.85)
		add_child(bench)
	var small_bench := ModelBench.new()
	small_bench.position = Vector3(1.0, 0, -4.85)
	add_child(small_bench)
	var pit := BellPit.new()
	pit.position = Vector3(-1.3, 0, -0.7)
	pit.mouth_radius = 0.35
	add_child(pit)
	var big_pit := BellPit.new()
	big_pit.position = Vector3(2.9, 0, -1.0)
	big_pit.mouth_radius = 0.5
	add_child(big_pit)
	var mold := MoldBox.new()
	mold.position = Vector3(-3.9, 0, 2.3)
	mold.cool_time = 14.0
	add_child(mold)
	var trough := QuenchTrough.new()
	trough.position = Vector3(5.9, 0, 1.9)
	trough.rotation.y = PI * 0.5
	add_child(trough)
	var orders := OrderBoard.new()
	orders.first_order = &"church_bell"
	orders.position = Vector3(7.99, 0, -2.9)
	orders.rotation.y = -PI * 0.5
	add_child(orders)
	var board := UpgradeBoard.new()
	board.position = Vector3(7.6, 0, -0.4)
	board.rotation.y = -PI * 0.5
	add_child(board)
	# Inside by the door, where the crane can still set a bell into it.
	var crate := SellCrate.new()
	crate.position = Vector3(5.4, 0, 4.3)
	crate.rotation.y = -0.15
	add_child(crate)
	var hoist := ChainHoist.new()
	add_child(hoist)
	var stations: Array = get_children().filter(func(n: Node) -> bool: return n is Node3D and not n is WorldEnvironment and not n is Light3D)
	BellHallSet.build_hall(self, stations)


func spawn_items() -> void:
	super()
	# A second crucible: one bell takes two or three of them.
	var furnaces := get_children().filter(func(n: Node) -> bool: return n is Furnace)
	if furnaces.size() > 1:
		spawn_entity({type = "crucible", pos = (furnaces[1] as Node3D).global_position + Vector3(0, 0.15, 0)})
	var trough := find_station(QuenchTrough) as Node3D
	if trough:
		spawn_entity({type = "bucket", pos = trough.global_position + Vector3(-0.2, 0.05, 1.2)})
	var hoist := find_station(ChainHoist) as ChainHoist
	if hoist:
		spawn_entity({type = "pendant", pos = hoist.pendant_rest()})


func upgrade_tier() -> int:
	return 2


func hammer_spot() -> Vector3:
	return Vector3(0.9, 0.1, 1.6)


func spawn_position(index: int) -> Vector3:
	return SPAWN + Vector3(index * 1.1 - 1.6, 0, 0)


func respawn_point(_player: Player) -> Vector3:
	return SPAWN + Vector3(randf_range(-1.0, 1.0), 0.1, 0)
