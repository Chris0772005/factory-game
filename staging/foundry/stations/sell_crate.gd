class_name SellCrate
extends Node3D
## Throw finished castings in here to sell them.

const SIZE := Vector3(1.2, 0.7, 0.9)

signal sold(piece_value: int)


func _ready() -> void:
	add_to_group(&"interactable")
	var wood := Color("#b07a45")
	for side in [-1, 1]:
		WorldBuilder.add_box(self, Vector3(SIZE.x, SIZE.y, 0.08), Vector3(0, SIZE.y * 0.5, side * SIZE.z * 0.5), wood, true)
		WorldBuilder.add_box(self, Vector3(0.08, SIZE.y, SIZE.z), Vector3(side * SIZE.x * 0.5, SIZE.y * 0.5, 0), wood, true)
	WorldBuilder.add_box(self, Vector3(SIZE.x, 0.08, SIZE.z), Vector3(0, 0.04, 0), wood.darkened(0.2), true)
	var sign := Label3D.new()
	sign.text = "VERKAUF"
	sign.font = UITheme.font(700)
	sign.font_size = 72
	sign.outline_size = 18
	sign.outline_modulate = UITheme.INK
	sign.modulate = UITheme.ACCENT
	sign.pixel_size = 0.004
	sign.position = Vector3(0, SIZE.y + 0.25, 0)
	sign.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	add_child(sign)


func interact_point() -> Vector3:
	return global_position + Vector3(0, SIZE.y, 0)


func hint(_player: Node) -> String:
	return "Gussstücke hier hineinwerfen"


func interact(_player: Node) -> void:
	pass


@rpc("authority", "call_local", "reliable")
func _cha_ching() -> void:
	Sfx.play(&"coin", interact_point(), 0.0, 0.03)


func _physics_process(_delta: float) -> void:
	if not Network.is_sim_authority():
		return
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	if world == null:
		return
	for node in world.entities.get_children():
		var piece := node as Item
		if piece == null or not piece.has_method("value") or piece.is_held() or piece.is_queued_for_deletion():
			continue
		var local := to_local(piece.global_position)
		if absf(local.x) < SIZE.x * 0.5 and absf(local.z) < SIZE.z * 0.5 and local.y < SIZE.y and local.y > -0.1:
			var v := piece.value()
			world.add_money(v)
			world.popup_all(piece.global_position + Vector3(0, 0.8, 0), "+%d $" % v, UITheme.ACCENT)
			_cha_ching.rpc() if Network.is_online() else _cha_ching()
			sold.emit(v)
			piece.queue_free()
