extends FoundryLevel
## Level 4 – Eisenhalle, the last hall. Iron and bell bronze are melted in
## the cupola (skip, blower, tap); the hall crane carries the teeming ladle
## to the mold line (series castings, passive income with the automats),
## a mold box, or the Kaisergrube for the finale: the Kaiserglocke, 100 l of
## bronze in two ladles, delivered to the cathedral across the yard.
## Set: IronHallSet, light: GarageLighting.

const SPAWN := Vector3(0.0, 0.2, 4.9)
const CREW_COLOURS := ["Blau", "Türkis", "Lila", "Rosa"]


func build_level() -> void:
	register_entity("charge", ChargeBox.create_box)
	register_entity("pendant", ChainHoist.Pendant.create_pendant)
	super()


func build_stations() -> void:
	GarageLighting.build(self)
	var cupola := CupolaFurnace.new()
	cupola.position = Vector3(-7.2, 0, -4.4)
	add_child(cupola)
	var iron := ChargeSupply.new()
	iron.look = &"iron"
	iron.position = Vector3(-3.7, 0, -5.2)
	add_child(iron)
	var bronze := ChargeSupply.new()
	bronze.look = &"bronze"
	bronze.price = 240
	bronze.position = Vector3(-8.7, 0, -0.6)
	bronze.rotation.y = PI * 0.5
	add_child(bronze)
	var line := MoldLine.new()
	line.position = Vector3(-2.2, 0, 1.6)
	add_child(line)
	var pattern_bench := ModelBench.new()
	pattern_bench.line_mode = true
	pattern_bench.position = Vector3(-4.2, 0, 2.6)
	pattern_bench.rotation.y = PI * 0.5
	add_child(pattern_bench)
	var pit := BellPit.new()
	pit.position = Vector3(5.4, 0, -2.6)
	pit.mouth_radius = 0.8
	# Time for a ladle change: back to the cupola, tap, back.
	pit.pour_gap = 40.0
	add_child(pit)
	var bell_bench := ModelBench.new()
	bell_bench.bell_mode = true
	bell_bench.position = Vector3(5.6, 0, -5.75)
	add_child(bell_bench)
	var mold := MoldBox.new()
	mold.position = Vector3(1.2, 0, -3.4)
	mold.cool_time = 12.0
	add_child(mold)
	var bench := ModelBench.new()
	bench.position = Vector3(1.2, 0, -5.75)
	add_child(bench)
	var orders := OrderBoard.new()
	orders.first_order = &"kaiser_bell"
	orders.position = Vector3(9.99, 0, -1.6)
	orders.rotation.y = -PI * 0.5
	add_child(orders)
	var board := UpgradeBoard.new()
	board.position = Vector3(9.6, 0, 0.9)
	board.rotation.y = -PI * 0.5
	add_child(board)
	var crate := SellCrate.new()
	crate.position = Vector3(8.4, 0, 3.0)
	crate.rotation.y = -0.2
	add_child(crate)
	var crane := HallCrane.new()
	crane.x_range = Vector2(-8.6, 8.6)
	crane.z_range = Vector2(-4.8, 4.6)
	crane.rail_height = 5.4
	add_child(crane)
	var stations: Array = get_children().filter(func(n: Node) -> bool: return n is Node3D and not n is WorldEnvironment and not n is Light3D)
	IronHallSet.build_hall(self, stations)
	AutoIron.build_for(self)


func spawn_items() -> void:
	# A crucible to fill from the ladle for the mold box, and the hammer.
	spawn_entity({type = "crucible", pos = Vector3(-0.6, 0.1, -3.6)})
	spawn_entity({type = "hammer", pos = hammer_spot()})
	var crane := find_station(HallCrane) as HallCrane
	if crane:
		spawn_entity({type = "pendant", pos = crane.pendant_rest()})


func upgrade_tier() -> int:
	return 3


func hammer_spot() -> Vector3:
	return Vector3(3.4, 0.1, -1.0)


func spawn_position(index: int) -> Vector3:
	return SPAWN + Vector3(index * 1.1 - 1.6, 0, 0)


func respawn_point(_player: Player) -> Vector3:
	return SPAWN + Vector3(randf_range(-1.2, 1.2), 0.1, 0)


## Host: the Kaiserglocke went to the cathedral. With its order: the end.
func on_great_bell_delivered(_bell: Bell, fulfilled: bool) -> void:
	if not fulfilled:
		banner_all("AUSGELIEFERT!", UITheme.ACCENT, "Eine Riesenglocke – aber nicht die bestellte Kaiserglocke")
		return
	guide.note(&"great_bell")
	banner_all("DIE KAISERGLOCKE LÄUTET!", Color("#ffd75e"), "Der Dom hat seine Glocke")
	var crew: Array[String] = []
	var count := get_tree().get_nodes_in_group(&"players").size()
	for i in clampi(count, 1, CREW_COLOURS.size()):
		crew.append("Gießer %s" % CREW_COLOURS[i])
	await get_tree().create_timer(4.5).timeout
	if not is_inside_tree():
		return
	_show_finale(crew)
	if Network.is_online():
		_finale_remote.rpc(crew)


@rpc("authority", "call_remote", "reliable")
func _finale_remote(crew: Array) -> void:
	var names: Array[String] = []
	for c in crew:
		names.append(str(c))
	_show_finale(names)


func _show_finale(crew: Array[String]) -> void:
	if attract_mode:
		return
	FinaleScreen.open(self, crew)
