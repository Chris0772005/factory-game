class_name SellCrate
extends Node3D
## Throw finished castings in here to sell them.

const SIZE := Vector3(1.2, 0.7, 0.9)

signal sold(piece_value: int)

var _art: CrateArt


func _ready() -> void:
	# The station never moves but its art is animated per frame (Art Bible 9.1):
	# without interpolation it shows each frame's pose instead of lagging a tick.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_to_group(&"interactable")
	# Four walls and a floor: thrown castings land inside and are sold.
	for side in [-1, 1]:
		StationKit.box_collider(self, Vector3(SIZE.x, SIZE.y, 0.08), Transform3D(Basis(), Vector3(0, SIZE.y * 0.5, side * SIZE.z * 0.5)))
		StationKit.box_collider(self, Vector3(0.08, SIZE.y, SIZE.z), Transform3D(Basis(), Vector3(side * SIZE.x * 0.5, SIZE.y * 0.5, 0)))
	StationKit.box_collider(self, Vector3(SIZE.x, 0.08, SIZE.z), Transform3D(Basis(), Vector3(0, 0.04, 0)))
	_art = CrateArt.new()
	add_child(_art)
	_art.build(SIZE)


func interact_point() -> Vector3:
	return global_position + Vector3(0, SIZE.y, 0)


func hint(_player: Node) -> String:
	return "Gussstücke hier hineinwerfen"


func interact(_player: Node) -> void:
	pass


@rpc("authority", "call_local", "reliable")
func _cha_ching() -> void:
	Sfx.play(&"coin", interact_point(), 0.0, 0.03)
	_art.pop()


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
			var v: int = piece.value()
			world.add_money(v)
			world.popup_all(piece.global_position + Vector3(0, 0.8, 0), "+%d $" % v, UITheme.ACCENT)
			if Network.is_online():
				_cha_ching.rpc()
			else:
				_cha_ching()
			sold.emit(v)
			piece.queue_free()
