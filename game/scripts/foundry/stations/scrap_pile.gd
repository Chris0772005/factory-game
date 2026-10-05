class_name ScrapPile
extends Node3D
## Heap of junk to melt. Using it hands the player a random piece of scrap.

const WEIGHTS := {&"scrap_can": 70, &"scrap_key": 15, &"scrap_pipe": 13, &"scrap_ring": 2}
const PREMIUM_WEIGHTS := {&"scrap_can": 35, &"scrap_key": 28, &"scrap_pipe": 32, &"scrap_ring": 5}


func _ready() -> void:
	add_to_group(&"interactable")
	# Low solid core so workers stand at the heap instead of inside it.
	var core := StaticBody3D.new()
	core.position.y = 0.14
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.55
	cyl.height = 0.28
	shape.shape = cyl
	core.add_child(shape)
	add_child(core)
	var art := ScrapArt.new()
	add_child(art)
	art.build()


func interact_point() -> Vector3:
	return global_position + Vector3(0, 0.4, 0)


func hint(_player: Node) -> String:
	return "[F] Schrott nehmen"


func interact(player: Node) -> void:
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	if world == null:
		return
	var kind := _roll()
	var info: Dictionary = FoundryRules.SCRAP[kind]
	var p := player as Player
	var item := world.spawn_item(kind, info.color, info.size, 0.4, p._hand_target())
	p.grab(item)
	Sfx.play(&"scrap_clatter", interact_point(), -4.0)
	if kind == &"scrap_ring":
		world.popup_all(p._hand_target() + Vector3(0, 0.6, 0), "Omas Ring! ✨", Color("#ffcf3f"))


func _roll() -> StringName:
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	var weights := PREMIUM_WEIGHTS if world and world.has_upgrade(&"scrap_premium") else WEIGHTS
	var total := 0
	for k in weights:
		total += weights[k]
	var r := randi() % total
	for k in weights:
		r -= weights[k]
		if r < 0:
			return k
	return &"scrap_can"
