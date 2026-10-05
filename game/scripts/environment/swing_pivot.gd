extends Node3D
## Slow pendulum for hanging set dressing (tyre swing): a few degrees of sway
## with a little twist, purely visual.

@export var amplitude := 0.07
@export var period := 3.4

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	var w := TAU / period
	rotation = Vector3(sin(_t * w) * amplitude, sin(_t * w * 0.37) * 0.25, sin(_t * w * 0.71 + 1.3) * amplitude * 0.4)
