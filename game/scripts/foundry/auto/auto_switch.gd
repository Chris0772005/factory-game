class_name AutoSwitch
extends Node3D
## The switch on a mold's control cabinet: F turns that mold's re-forming
## and ramming off and on, so a worker can put in a new pattern by hand. A
## piece already in the mold is still poured, shaken out and shipped. Only reachable once a mold machine is owned.

var auto: AutoFoundry
var index := 0


func _ready() -> void:
	add_to_group(&"interactable")


func interact_point() -> Vector3:
	# Out of reach while the cabinet does not exist yet.
	return global_position + Vector3(0, 1.0 if auto.has_cabinet() else -50.0, 0)


func hint(_player: Node) -> String:
	if auto.enabled[index]:
		return "[F] Nachformen an dieser Form AUS (für ein neues Modell)"
	return "[F] Nachformen an dieser Form wieder AN"


func interact(_player: Node) -> void:
	auto.set_enabled(index, not auto.enabled[index])
	Sfx.play(&"pop", interact_point(), -2.0)
