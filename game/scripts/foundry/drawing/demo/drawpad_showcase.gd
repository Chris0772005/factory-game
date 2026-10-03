extends Node3D
## Showcase: the DrawPad over a 3D scene with a gnome drawn in programmatically.


func _ready() -> void:
	WorldBuilder.add_environment(self)
	WorldBuilder.add_floor(self)
	WorldBuilder.add_box(self, Vector3(1.6, 0.9, 0.9), Vector3(0, 0.45, -0.6), WorldBuilder.PALETTE.machine)
	var cam := Camera3D.new()
	cam.fov = 45
	add_child(cam)
	cam.look_at_from_position(Vector3(0, 2.2, 2.6), Vector3(0, 0.6, 0))
	var layer := CanvasLayer.new()
	add_child(layer)
	var pad := DrawPad.new()
	layer.add_child(pad)
	pad.open("Zeichne: einen Gartenzwerg")
	for s in DrawingSamples.gnome().strokes:
		pad.add_stroke(s)
	pad.time_left = 17.4
	pad.finished.connect(func(d: Drawing): print("finished: ", d.to_code()))
