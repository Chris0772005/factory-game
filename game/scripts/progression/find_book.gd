class_name FindBook
extends Node
## The "Fundbuch": every rare treasure dug out of the scrap for the first
## time is entered, pays a growing bonus, and the full book pays a big one.
## Host tracks it, peers mirror; the list is part of the savegame.

signal changed

const BONUS := 40
const FULL_BONUS := 600

var world: GameWorld
var found: Array[StringName] = []


func _ready() -> void:
	add_to_group(&"find_books")
	Network.peer_ready.connect(_on_peer_ready)


static func total() -> int:
	return ScrapPile.RARE.size()


## Host: a rare `kind` came out of the heap at `pos`.
func note(kind: StringName, pos: Vector3) -> void:
	if not Network.is_sim_authority() or found.has(kind) or not ScrapPile.RARE.has(kind):
		return
	found.append(kind)
	var bonus := BONUS * found.size()
	var full := found.size() >= total()
	if full:
		bonus += FULL_BONUS
	world.add_money(bonus)
	var info: Dictionary = FoundryRules.SCRAP[kind]
	world.banner_near(pos, "FUNDBUCH KOMPLETT!" if full else "NEU IM FUNDBUCH", Color("#ffcf3f"),
		"%s · %d von %d · +%d $" % [info.name, found.size(), total(), bonus], true)
	changed.emit()
	if Network.is_online():
		_sync.rpc(to_save())


func to_save() -> Array:
	return found.map(func(k: StringName) -> String: return String(k))


func load_save(list: Array) -> void:
	found.clear()
	for k in list:
		if ScrapPile.RARE.has(StringName(str(k))) and not found.has(StringName(str(k))):
			found.append(StringName(str(k)))
	changed.emit()


@rpc("authority", "call_remote", "reliable")
func _sync(list: Array) -> void:
	load_save(list)


func _on_peer_ready(id: int) -> void:
	if Network.is_sim_authority() and not found.is_empty():
		_sync.rpc_id(id, to_save())
