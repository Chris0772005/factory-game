class_name MenuCamera
extends Camera3D
## Title-screen camera (Art Bible 12): a slightly raised diorama view from
## the yard's front-right corner that sweeps slowly back and forth (about
## 0.02 rad/s at its fastest) around the furnace: molds in the foreground,
## the lit house and the string lights behind, the dusk sky and the moon over
## the roofs, the calm front lawn on the left under the menu column. It moves
## between the front lawn and the space above the low front fence and never
## passes through the house, a pole or the big tree, nor shows a string-light
## pole close up. Soft far depth of field on the neighbourhood.

## Point the camera circles and looks at: above and behind the furnace.
const TARGET := Vector3(-2.0, 2.4, -4.0)
const RADIUS := 15.0
## Absolute eye height: low enough that the dusk sky shows above the roofs.
const EYE_HEIGHT := 3.6
## Sweep centre and half-width (rad around the yard's front axis, +x = right).
const SWEEP_CENTER := 0.5
const SWEEP := 0.14
## Seconds for one full left-right-left sweep (peak 2 pi SWEEP / PERIOD rad/s).
const PERIOD := 45.0

var _t := 0.0


func _ready() -> void:
	# Moved per frame in _process: no physics interpolation (smooth at any refresh rate).
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	fov = 46.0
	# Pushes the yard to the right so the menu column has calm ground behind it.
	h_offset = -1.6
	var attrs := CameraAttributesPractical.new()
	attrs.dof_blur_far_enabled = true
	attrs.dof_blur_far_distance = 26.0
	attrs.dof_blur_far_transition = 16.0
	attrs.dof_blur_amount = 0.05
	attributes = attrs
	# Preview aid: `-- --menu-cam-t=<s>` starts the sweep at that time.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--menu-cam-t="):
			_t = float(arg.trim_prefix("--menu-cam-t="))
	_update()


func _process(delta: float) -> void:
	_t += delta
	_update()


func _update() -> void:
	var a := SWEEP_CENTER + sin(_t * TAU / PERIOD + 0.4) * SWEEP
	var bob := sin(_t * 0.21) * 0.12
	var pos := Vector3(TARGET.x + sin(a) * RADIUS, EYE_HEIGHT + bob, TARGET.z + cos(a) * RADIUS)
	look_at_from_position(pos, TARGET + Vector3(0, bob * 0.5, 0))
