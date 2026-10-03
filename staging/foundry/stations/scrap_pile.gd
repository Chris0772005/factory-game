class_name ScrapPile
extends Node3D
## Heap of junk to melt. Using it hands the player a random piece of scrap.

const WEIGHTS := {&"scrap_can": 70, &"scrap_key": 15, &"scrap_pipe": 13, &"scrap_ring": 2}


func _ready() -> void:
	add_to_group(&"interactable")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 26:
		var kind: StringName = WEIGHTS.keys()[rng.randi() % 3]
		var info: Dictionary = FoundryRules.SCRAP[kind]
		var a := rng.randf() * TAU
		var r := rng.randf() * 0.7
		var box := WorldBuilder.add_box(self, info.size, Vector3(cos(a) * r, 0.05 + rng.randf() * 0.25 * (1.0 - r), sin(a) * r), info.color)
		box.rotation = Vector3(rng.randf(), rng.randf(), rng.randf()) * TAU


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
	var total := 0
	for k in WEIGHTS:
		total += WEIGHTS[k]
	var r := randi() % total
	for k in WEIGHTS:
		r -= WEIGHTS[k]
		if r < 0:
			return k
	return &"scrap_can"
