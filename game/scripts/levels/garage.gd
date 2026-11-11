extends FoundryLevel
## Level 2 – Garage: the foundry moves into a brick double garage. More room
## (two model benches, two molds), the family car in the left bay, and the
## garage's new systems (quench trough, sealed scrap crates, orders) next to
## the stations the crew already knows. Set: GarageSet, light: GarageLighting.

const SPAWN := Vector3(0.6, 0.2, 3.4)
## Mold cooling in the garage (the backyard's is MoldBox.COOL_TIME = 4.5 s).
const COOL_TIME := 14.0


func build_stations() -> void:
	GarageLighting.build(self)

	var furnace := Furnace.new()
	furnace.position = Vector3(-2.6, 0, -2.7)
	add_child(furnace)
	var scrap := ScrapPile.new()
	scrap.position = Vector3(-4.9, 0, -2.6)
	add_child(scrap)
	for i in 2:
		var bench := ModelBench.new()
		bench.position = Vector3(1.4 + i * 2.2, 0, -3.65)
		add_child(bench)
	for i in 2:
		var mold := MoldBox.new()
		mold.position = Vector3(-0.9 + i * 2.7, 0, 0.3)
		# Bigger pour trees hold their heat: wait, or quench (and risk cracks).
		mold.cool_time = COOL_TIME
		add_child(mold)
	var crates := CrateDelivery.new()
	crates.position = Vector3(4.85, 0, 3.35)
	crates.rotation.y = -0.35
	add_child(crates)
	var orders := OrderBoard.new()
	orders.position = Vector3(5.99, 0, -2.35)
	orders.rotation.y = -PI * 0.5
	add_child(orders)
	var trough := QuenchTrough.new()
	trough.position = Vector3(4.0, 0, 1.0)
	trough.rotation.y = PI * 0.5
	add_child(trough)
	var crate := SellCrate.new()
	# Pickup is out on the driveway, in the evening sun.
	crate.position = Vector3(3.7, 0, 5.5)
	crate.rotation.y = 0.25
	add_child(crate)
	var board := UpgradeBoard.new()
	board.position = Vector3(5.65, 0, -0.5)
	board.rotation.y = -PI * 0.5
	add_child(board)
	var stations: Array = get_children().filter(func(n: Node) -> bool: return n is Node3D and not n is WorldEnvironment and not n is Light3D)
	GarageSet.build(self, stations)
	for at: Vector3 in [Vector3(2.5, 2.9, -2.8), Vector3(4.3, 2.9, 2.0), Vector3(-4.3, 2.9, 1.7)]:
		SwayLamp.hang(self, at, 0.75)


func build_level() -> void:
	register_entity("bucket", WaterBucket.create_bucket)
	register_entity("sealed_crate", SealedCrate.create_crate)
	super()


func spawn_items() -> void:
	super()
	var trough := find_station(QuenchTrough) as Node3D
	if trough:
		spawn_entity({type = "bucket", pos = trough.global_position + Vector3(-0.2, 0.05, 1.0)})


func upgrade_tier() -> int:
	return 1


func hammer_spot() -> Vector3:
	return Vector3(0.5, 0.1, 1.9)


func spawn_position(index: int) -> Vector3:
	return SPAWN + Vector3(index * 1.1 - 1.6, 0, 0)


func respawn_point(_player: Player) -> Vector3:
	return SPAWN + Vector3(randf_range(-1.0, 1.0), 0.1, 0)
