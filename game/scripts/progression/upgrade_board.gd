class_name UpgradeBoard
extends Node3D
## Pinboard with the upgrade catalogue. Opens a shop overlay for the local player.

var _layer: CanvasLayer
var _art: BoardArt


func _ready() -> void:
	add_to_group(&"interactable")
	for x: float in [-0.7, 0.7]:
		StationKit.box_collider(self, Vector3(0.1, 1.9, 0.1), Transform3D(Basis(), Vector3(x, 0.95, 0)))
	_art = BoardArt.new()
	add_child(_art)
	_art.build()
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	if world and world.upgrades:
		world.upgrades.changed.connect(func() -> void: _art.set_owned(world.upgrades.owned))
		_art.set_owned(world.upgrades.owned)


func interact_point() -> Vector3:
	return global_position + Vector3(0, 1.3, 0.3)


func hint(_player: Node) -> String:
	return "[F] Upgrades ansehen"


func interact(player: Node) -> void:
	var p := player as Player
	if not Network.is_online() or p.peer_id == multiplayer.get_unique_id():
		_open()
	else:
		_open_remote.rpc_id(p.peer_id)


@rpc("authority", "call_remote", "reliable")
func _open_remote() -> void:
	_open()


func _open() -> void:
	if _layer:
		return
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	if world == null or world.upgrades == null:
		return
	var me := world.local_player()
	if me:
		me.ui_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_layer = CanvasLayer.new()
	_layer.layer = 10
	add_child(_layer)
	var shop := UpgradeShop.new()
	shop.upgrades = world.upgrades
	shop.world = world
	shop.closed.connect(_close)
	_layer.add_child(shop)


func _close() -> void:
	if _layer:
		_layer.queue_free()
		_layer = null
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	var me := world.local_player() if world else null
	if me:
		me.ui_locked = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
