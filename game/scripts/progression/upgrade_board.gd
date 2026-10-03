class_name UpgradeBoard
extends Node3D
## Pinboard with the upgrade catalogue. Opens a shop overlay for the local player.

var _layer: CanvasLayer


func _ready() -> void:
	add_to_group(&"interactable")
	var wood := Color("#7a5534")
	WorldBuilder.add_box(self, Vector3(0.1, 1.9, 0.1), Vector3(-0.7, 0.95, 0), wood.darkened(0.2), true)
	WorldBuilder.add_box(self, Vector3(0.1, 1.9, 0.1), Vector3(0.7, 0.95, 0), wood.darkened(0.2), true)
	WorldBuilder.add_box(self, Vector3(1.6, 1.0, 0.08), Vector3(0, 1.45, 0), Color("#c9a77b"))
	var colors := [Color("#fff8ec"), Color("#ffe08a"), Color("#bfe6f2"), Color("#ffc4b0")]
	for i in 6:
		var note := WorldBuilder.add_box(self, Vector3(0.36, 0.28, 0.02), Vector3(-0.5 + (i % 3) * 0.5, 1.68 - (i / 3) * 0.42, 0.05), colors[i % 4])
		note.rotation.z = (i * 0.37 - 0.9) * 0.1
	var title := Label3D.new()
	title.text = "KATALOG"
	title.font = UITheme.font(700)
	title.font_size = 64
	title.outline_size = 16
	title.outline_modulate = UITheme.INK
	title.modulate = UITheme.ACCENT
	title.pixel_size = 0.004
	title.position = Vector3(0, 2.15, 0.06)
	add_child(title)


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
