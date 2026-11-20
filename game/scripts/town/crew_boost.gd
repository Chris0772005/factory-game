class_name CrewBoost
extends Node
## What the crew has had at the diner: for a while everybody digs faster (coffee) or walks and
## runs faster (a hot meal). One order treats the whole crew. The host keeps the clocks and tells
## the others; every peer counts them down for its display.

const GROUP := &"crew_boosts"
## What is on the menu: price ($), how long it lasts (s), and what it does (`dig`: how much faster
## the heap is dug, `walk`: how much faster everybody goes).
const MENU := {
	&"coffee": {name = "Kaffee", price = 4, seconds = 180.0, dig = 1.35, text = "schneller wühlen"},
	&"meal": {name = "Eintopf", price = 12, seconds = 240.0, walk = 1.15, text = "schneller laufen"},
}
const SYNC_EVERY := 3.0

signal changed

## Seconds left of each thing on the menu (kind -> s).
var left := {}
var _sync_in := 0.0


static func of(tree: SceneTree) -> CrewBoost:
	return tree.get_first_node_in_group(GROUP) as CrewBoost


## How much faster the crew digs right now (1 = as always).
static func dig(tree: SceneTree) -> float:
	var boost := of(tree)
	return boost._factor(&"dig") if boost else 1.0


## How much faster the crew walks and runs right now (1 = as always).
static func walk(tree: SceneTree) -> float:
	var boost := of(tree)
	return boost._factor(&"walk") if boost else 1.0


func _init() -> void:
	name = "CrewBoost"


func _ready() -> void:
	add_to_group(GROUP)
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	if DisplayServer.get_name() != "headless" and not (world and world.attract_mode):
		add_child(BoostHud.new())
	Network.peer_ready.connect(_on_peer_ready)


func _factor(what: StringName) -> float:
	var out := 1.0
	for kind: StringName in left:
		if float(left[kind]) > 0.0:
			out *= float((MENU[kind] as Dictionary).get(what, 1.0))
	return out


## Host: the crew gets `kind` from the menu if it can pay. Says whether it did.
func order(kind: StringName) -> bool:
	if not Network.is_sim_authority() or not MENU.has(kind):
		return false
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	var item: Dictionary = MENU[kind]
	if world == null or world.money < int(item.price):
		return false
	world.add_money(-int(item.price))
	left[kind] = float(item.seconds)
	Missions.report(get_tree(), &"diner", 1)
	_publish()
	changed.emit()
	return true


func _physics_process(delta: float) -> void:
	var ran_out := false
	for kind: StringName in left.keys():
		left[kind] = float(left[kind]) - delta
		if float(left[kind]) <= 0.0:
			left.erase(kind)
			ran_out = true
	if ran_out:
		changed.emit()
	if Network.is_online() and multiplayer.is_server() and not left.is_empty():
		_sync_in -= delta
		if _sync_in <= 0.0:
			_publish()


func _publish() -> void:
	_sync_in = SYNC_EVERY
	if Network.is_online() and multiplayer.is_server():
		_sync.rpc(left.keys(), left.values())


## A player has arrived in the level: what the crew has in it goes to that one too.
func _on_peer_ready(id: int, _level: String) -> void:
	if Network.is_online() and multiplayer.is_server() and not left.is_empty():
		_sync.rpc_id(id, left.keys(), left.values())


@rpc("authority", "call_remote", "reliable")
func _sync(kinds: Array, seconds: Array) -> void:
	left.clear()
	for i in mini(kinds.size(), seconds.size()):
		if MENU.has(kinds[i]):
			left[StringName(kinds[i])] = float(seconds[i])
	changed.emit()
