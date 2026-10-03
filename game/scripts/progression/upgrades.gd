class_name Upgrades
extends Node
## Purchasable upgrades. The host owns the truth; peers get the owned list.
## Effects are read by stations through `level(id)` / `has(id)`.

signal changed

const CATALOG := [
	{id = &"bellows_foot", name = "Fußblasebalg", desc = "Jeder Tritt bringt 50 % mehr Hitze.", cost = 120, tier = 0},
	{id = &"crucible_big", name = "Großer Tiegel", desc = "Fasst 5 statt 3 Liter.", cost = 180, tier = 0},
	{id = &"mold_slot", name = "Dritte Kavität", desc = "Jeder Formkasten nimmt ein Modell mehr.", cost = 220, tier = 0},
	{id = &"gloves", name = "Lederhandschuhe", desc = "25 % mehr Kraft beim Tragen.", cost = 150, tier = 0},
	{id = &"scrap_premium", name = "Schrott vom Wertstoffhof", desc = "Mehr Kupfer und Messing im Schrott.", cost = 260, tier = 0},
	{id = &"garage", name = "Garage freischalten", desc = "Mehr Platz, Mehrfach-Gießbaum, Abschrecken.", cost = 900, tier = 0, unlock = true},
]

var owned := {}
var world: GameWorld


func has(id: StringName) -> bool:
	return owned.has(id)


func info(id: StringName) -> Dictionary:
	for u in CATALOG:
		if u.id == id:
			return u
	return {}


func can_buy(id: StringName) -> bool:
	var u := info(id)
	return not u.is_empty() and not has(id) and world and world.money >= u.cost


## Client entry point; forwards to the host.
func request_buy(id: StringName) -> void:
	if Network.is_sim_authority():
		buy(id)
	else:
		_buy_remote.rpc_id(1, id)


@rpc("any_peer", "call_remote", "reliable")
func _buy_remote(id: StringName) -> void:
	buy(id)


func buy(id: StringName) -> bool:
	if not can_buy(id):
		return false
	var u := info(id)
	world.add_money(-u.cost)
	owned[id] = true
	world.popup_all(world.local_player().global_position + Vector3(0, 2.4, 0) if world.local_player() else Vector3.ZERO,
		"%s gekauft!" % u.name, UITheme.ACCENT)
	_broadcast()
	changed.emit()
	return true


func _broadcast() -> void:
	if Network.is_online() and multiplayer.is_server():
		_sync.rpc(PackedStringArray(owned.keys()))


@rpc("authority", "call_remote", "reliable")
func _sync(ids: PackedStringArray) -> void:
	owned.clear()
	for id in ids:
		owned[StringName(id)] = true
	changed.emit()


func to_save() -> Array:
	return owned.keys().map(func(k): return String(k))


func load_save(ids: Array) -> void:
	owned.clear()
	for id in ids:
		owned[StringName(id)] = true
	changed.emit()
