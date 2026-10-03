class_name ModelBench
extends Node3D
## Workbench where a player draws a pattern. The finished drawing becomes a
## cavity in the nearest mold box that has room.

const PROMPTS := [
	"einen Gartenzwerg", "deinen Lieblingsfisch", "ein Herz", "deinen Mitspieler",
	"ein Pferd (viel Glück)", "eine Katze", "dein Haus", "einen Pokal", "einen Stern",
	"ein Monster", "deinen Namen", "eine Krone", "ein Auto", "einen Kaktus", "eine Ente",
]

var _pad_layer: CanvasLayer


func _ready() -> void:
	add_to_group(&"interactable")
	var wood := Color("#a8774b")
	WorldBuilder.add_box(self, Vector3(1.4, 0.08, 0.8), Vector3(0, 0.9, 0), wood, true)
	for x in [-0.62, 0.62]:
		for z in [-0.32, 0.32]:
			WorldBuilder.add_box(self, Vector3(0.08, 0.9, 0.08), Vector3(x, 0.45, z), wood.darkened(0.25))
	WorldBuilder.add_box(self, Vector3(0.7, 0.02, 0.5), Vector3(-0.1, 0.95, 0), Color("#fff8ec"))
	WorldBuilder.add_box(self, Vector3(0.04, 0.04, 0.3), Vector3(0.45, 0.96, 0.1), Color("#1f1b2d"))


func interact_point() -> Vector3:
	return global_position + Vector3(0, 1.0, 0)


func hint(_player: Node) -> String:
	return "[F] Modell zeichnen"


func interact(player: Node) -> void:
	var p := player as Player
	var prompt: String = "Zeichne: " + PROMPTS[randi() % PROMPTS.size()]
	if not Network.is_online() or p.peer_id == multiplayer.get_unique_id():
		_open_pad(prompt)
	else:
		_open_pad_remote.rpc_id(p.peer_id, prompt)


@rpc("authority", "call_remote", "reliable")
func _open_pad_remote(prompt: String) -> void:
	_open_pad(prompt)


func _open_pad(prompt: String) -> void:
	if _pad_layer:
		return
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	var me := world.local_player() if world else null
	if me:
		me.ui_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_pad_layer = CanvasLayer.new()
	_pad_layer.layer = 10
	add_child(_pad_layer)
	var pad := DrawPad.new()
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pad_layer.add_child(pad)
	pad.finished.connect(func(drawing: Drawing): _close_pad(drawing.to_code() if drawing and not drawing.is_empty() else ""))
	pad.cancelled.connect(func(): _close_pad(""))
	pad.open(prompt)


func _close_pad(code: String) -> void:
	if _pad_layer:
		_pad_layer.queue_free()
		_pad_layer = null
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	var me := world.local_player() if world else null
	if me:
		me.ui_locked = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if code.is_empty():
		return
	if Network.is_sim_authority():
		submit(code)
	else:
		_submit_remote.rpc_id(1, code)


@rpc("any_peer", "call_remote", "reliable")
func _submit_remote(code: String) -> void:
	submit(code)


## Places a drawing into the closest mold box with room. Host only.
func submit(code: String) -> bool:
	if Drawing.from_code(code) == null:
		return false
	var best: MoldBox = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group(&"molds"):
		var m := node as MoldBox
		var d := m.global_position.distance_to(global_position)
		if m.has_room() and d < best_d:
			best_d = d
			best = m
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	if best == null:
		if world:
			world.popup_all(interact_point() + Vector3(0, 0.6, 0), "Kein freier Formkasten!", Color("#ff6b5a"))
		return false
	best.add_pattern(code)
	if world:
		world.popup_all(best.interact_point() + Vector3(0, 0.6, 0), "Modell eingesetzt!", Color("#fff8ec"))
	return true
