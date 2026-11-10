class_name FoundryLevel
extends GameWorld
## Shared base of the playable foundry levels (Hinterhof, Garage, ...): the
## networked foundry entities, upgrades, the save file and the hall unlocks.
## A level overrides `build_stations()` (and optionally `spawn_items()`).

const BACKYARD := "res://scenes/backyard.tscn"
const GARAGE := "res://scenes/garage.tscn"
const BELL_FOUNDRY := "res://scenes/bell_foundry.tscn"
const IRON_HALL := "res://scenes/iron_hall.tscn"
## Unlock upgrade id -> level it opens.
const UNLOCKS := {&"garage": GARAGE, &"bell_foundry": BELL_FOUNDRY, &"iron_hall": IRON_HALL}
## Seconds between "freigeschaltet" and the move, so everyone sees the banner.
const TRAVEL_DELAY := 3.5

var _save_pending := false


func build_level() -> void:
	register_entity("crucible", Crucible.create_crucible)
	register_entity("hammer", Hammer.create_hammer)
	register_entity("cast", CastPiece.from_data)
	register_entity("statue", BronzeStatue.from_data)
	register_entity("bell", Bell.from_data)
	upgrades = Upgrades.new()
	upgrades.name = "Upgrades"
	upgrades.world = self
	add_child(upgrades)
	upgrades.changed.connect(_apply_upgrades)
	build_stations()
	var hunt := SearchHunt.new()
	hunt.name = "SearchHunt"
	hunt.world = self
	add_child(hunt)
	if Network.is_sim_authority():
		# Menu backgrounds show the level as on a fresh install and never save.
		if not attract_mode:
			SaveGame.load_into(self)
			money_changed.connect(func(_m): _autosave())
			upgrades.changed.connect(_autosave)
		spawn_items()


## Override: stations, set and lighting.
func build_stations() -> void:
	pass


## Override: loose items at the start (host only). Default: crucible in the
## furnace and the hammer at `hammer_spot()`.
func spawn_items() -> void:
	var furnace := find_station(Furnace) as Node3D
	if furnace:
		spawn_entity({type = "crucible", pos = furnace.global_position + Vector3(0, 0.15, 0)})
	spawn_entity({type = "hammer", pos = hammer_spot()})


func hammer_spot() -> Vector3:
	return Vector3(1.5, 0.1, 2.6)


## First direct child of the given script class (e.g. Furnace), or null.
func find_station(type: Variant) -> Node:
	for n in get_children():
		if is_instance_of(n, type):
			return n
	return null


func _apply_upgrades() -> void:
	for p in get_tree().get_nodes_in_group(&"players"):
		p.strength = Player.STRENGTH * (1.25 if has_upgrade(&"gloves") else 1.0)


## Host: an unlock upgrade was bought. Everyone sees the banner, then the
## whole crew moves to the new hall.
func on_unlock(id: StringName) -> void:
	if not UNLOCKS.has(id) or not Network.is_sim_authority():
		return
	var info: Dictionary = upgrades.info(id)
	banner_all("NEUE HALLE!", UITheme.ACCENT, "%s – gleich geht's los" % info.get("name", ""))
	await get_tree().create_timer(TRAVEL_DELAY).timeout
	if is_inside_tree():
		travel_to(UNLOCKS[id])


func _autosave() -> void:
	if _save_pending:
		return
	_save_pending = true
	await get_tree().create_timer(1.0).timeout
	_save_pending = false
	if is_inside_tree():
		SaveGame.save(self)
