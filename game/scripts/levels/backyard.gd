extends GameWorld
## Level 1 – Hinterhof: a bucket furnace, a scrap heap and two sand molds
## in a fenced backyard at dusk. The set (ground, grass, fences, house, shed,
## string lights, props, neighbourhood) is built by YardSet, the lighting by
## YardLighting (scripts/environment/).


func build_level() -> void:
	register_entity("crucible", Crucible.create_crucible)
	register_entity("hammer", Hammer.create_hammer)
	register_entity("cast", CastPiece.from_data)
	register_entity("statue", BronzeStatue.from_data)
	upgrades = Upgrades.new()
	upgrades.name = "Upgrades"
	upgrades.world = self
	add_child(upgrades)
	upgrades.changed.connect(_apply_upgrades)
	_build_environment()

	var furnace := Furnace.new()
	furnace.position = Vector3(-3.0, 0, -2.5)
	add_child(furnace)
	var scrap := ScrapPile.new()
	scrap.position = Vector3(-5.6, 0, 0.2)
	add_child(scrap)
	var bench := ModelBench.new()
	bench.position = Vector3(3.2, 0, -3.4)
	add_child(bench)
	for i in 2:
		var mold := MoldBox.new()
		mold.position = Vector3(0.2 + i * 2.6, 0, 0.6)
		add_child(mold)
	var crate := SellCrate.new()
	crate.position = Vector3(6.2, 0, 3.2)
	crate.rotation.y = -0.4
	add_child(crate)
	var board := UpgradeBoard.new()
	board.position = Vector3(5.6, 0, -5.2)
	board.rotation.y = -0.5
	add_child(board)
	var stations: Array = [furnace, scrap, bench, crate, board]
	stations.append_array(get_children().filter(func(n: Node) -> bool: return n is MoldBox))
	YardSet.build(self, stations)

	if Network.is_sim_authority():
		SaveGame.load_into(self)
		money_changed.connect(func(_m): _autosave())
		upgrades.changed.connect(_autosave)
		spawn_entity({type = "crucible", pos = furnace.global_position + Vector3(0, 0.15, 0)})
		spawn_entity({type = "hammer", pos = Vector3(1.5, 0.1, 2.6)})


func _apply_upgrades() -> void:
	for p in get_tree().get_nodes_in_group(&"players"):
		p.strength = Player.STRENGTH * (1.25 if has_upgrade(&"gloves") else 1.0)


var _save_pending := false


func _autosave() -> void:
	if _save_pending:
		return
	_save_pending = true
	await get_tree().create_timer(1.0).timeout
	_save_pending = false
	SaveGame.save(self)


## Sky, post-processing, key and fill light (also used by the asset contact sheet).
func _build_environment() -> void:
	YardLighting.build(self)
