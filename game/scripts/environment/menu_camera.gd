class_name MenuCamera
extends Camera3D
## Title-screen camera: a slow, eased sweep from the yard's front-right corner
## across the work area towards the lit house, low enough to show the dusk sky
## over the roofs (it never passes through the house or the big tree). The
## yard sits right of the menu column; soft far depth of field on the
## neighbourhood.

const TARGET := Vector3(-2.0, 2.3, -4.0)
const RADIUS := 15.0
## Absolute eye height: low enough that the dusk sky shows above the roofs.
const EYE_HEIGHT := 3.6
## Sweep centre and half-width (rad around the yard's front axis, +x = right):
## from the front-right corner across the work area towards the house.
const SWEEP_CENTER := 0.55
const SWEEP := 0.18
## Seconds for one full left-right-left sweep.
const PERIOD := 90.0

var _t := 0.0


func _ready() -> void:
	fov = 46.0
	# Pushes the yard to the right so the menu column has calm ground behind it.
	h_offset = -1.6
	var attrs := CameraAttributesPractical.new()
	attrs.dof_blur_far_enabled = true
	attrs.dof_blur_far_distance = 24.0
	attrs.dof_blur_far_transition = 14.0
	attrs.dof_blur_amount = 0.06
	attributes = attrs
	_update()


func _process(delta: float) -> void:
	_t += delta
	_update()


func _update() -> void:
	var a := SWEEP_CENTER + sin(_t * TAU / PERIOD + 0.4) * SWEEP
	var bob := sin(_t * 0.21) * 0.15
	var pos := Vector3(TARGET.x + sin(a) * RADIUS, EYE_HEIGHT + bob, TARGET.z + cos(a) * RADIUS)
	look_at_from_position(pos, TARGET)
