extends Node3D
## Showcase: the DrawPad open at the pattern bench in the real backyard (as a
## player sees it in game), with a gnome drawn in programmatically.


func _ready() -> void:
	# A staged shot: fresh-install state, never touches the player's save.
	SaveGame.disabled = true
	var world: GameWorld = load("res://scenes/backyard.tscn").instantiate()
	world.attract_mode = true
	add_child(world)
	var bench: Node3D = world.find_children("*", "ModelBench", true, false)[0]
	var cam := Camera3D.new()
	cam.fov = 50
	add_child(cam)
	cam.add_child(OutlinePass.create())
	# Over the worker's shoulder onto the bench, the yard and house behind it.
	var at := bench.global_position
	cam.look_at_from_position(at + Vector3(-0.9, 1.85, 2.3), at + Vector3(0.1, 0.8, 0.0))
	cam.make_current()
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var pad := DrawPad.new()
	layer.add_child(pad)
	pad.open("Zeichne: einen Gartenzwerg")
	for s in DrawingSamples.gnome().strokes:
		pad.add_stroke(s)
	pad.time_left = 17.4
	pad.finished.connect(func(d: Drawing): print("finished: ", d.to_code()))
