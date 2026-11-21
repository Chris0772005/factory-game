class_name DinerCounter
extends Node3D
## A place at the diner's counter where one thing from the menu is ordered (CrewBoost.MENU):
## [F] pays for it and the whole crew has it. Stands on the counter's customer side.

const GROUP := &"diner_counters"
## As far as a player is offered the counter (Player.nearest_interactable), so [F] never falls flat.
const USE_RANGE := 3.5

## What is ordered here: a key of CrewBoost.MENU.
var kind := &"coffee"


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(&"interactable")


func interact_point() -> Vector3:
	return global_position + Vector3(0, TownCounter.TOP, 0)


func in_reach(player: Node3D) -> bool:
	return interact_point().distance_to(player.global_position + Vector3(0, 0.9, 0)) < USE_RANGE


func hint(_player: Node) -> String:
	var item: Dictionary = CrewBoost.MENU[kind]
	var boost := CrewBoost.of(get_tree())
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	var minutes := int(float(item.seconds) / 60.0)
	if boost and float(boost.left.get(kind, 0.0)) > 20.0:
		return "%s wirkt noch (%d:%02d)" % [item.name, int(boost.left[kind]) / 60, int(boost.left[kind]) % 60]
	if world and world.money < int(item.price):
		return "%s · %d $ – dafür reicht das Geld noch nicht" % [item.name, item.price]
	return "[F] %s für alle · %d $ – %d Minuten %s" % [item.name, item.price, minutes, item.text]


## Host: the player orders.
func interact(player: Node) -> void:
	if not Network.is_sim_authority() or not (player is Node3D) or not in_reach(player as Node3D):
		return
	var boost := CrewBoost.of(get_tree())
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	if boost == null or world == null:
		return
	# Still plenty left: nobody pays twice by mistake.
	if float(boost.left.get(kind, 0.0)) > 20.0:
		return
	var item: Dictionary = CrewBoost.MENU[kind]
	if boost.order(kind):
		world.popup_all(interact_point() + Vector3(0, 0.5, 0), "%s! %d Min. %s" % [item.name, int(float(item.seconds) / 60.0), item.text], UITheme.ACCENT)
		if Network.is_online():
			_fx.rpc()
		else:
			_fx()
	else:
		world.popup_all(interact_point() + Vector3(0, 0.5, 0), "Zu wenig Geld", Color("#e5533d"))


@rpc("authority", "call_local", "unreliable")
func _fx() -> void:
	Sfx.play(&"coin", interact_point(), -6.0)
	Sfx.play(&"bucket_fill" if kind == &"coffee" else &"pickup", interact_point(), -8.0)
