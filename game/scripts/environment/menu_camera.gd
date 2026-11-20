class_name MenuCamera
extends Camera3D
## Title-screen camera: a slightly raised view that sweeps slowly back and forth (about 0.02 rad/s at
## its fastest) around a point of the level behind the menu, with a soft far depth of field. The
## values it starts with frame the backyard (Art Bible 12: from the yard's front-right corner around
## the furnace, never through the house, a pole or the big tree); `frame_scrap_hall` sets the view
## the menu uses now.

## Point the camera circles and looks at: above and behind the furnace.
var target := Vector3(-2.0, 2.4, -4.0)
var radius := 15.0
## Absolute eye height: low enough that the dusk sky shows above the roofs.
var eye_height := 3.6
## Sweep centre and half-width (rad around the yard's front axis, +x = right).
var sweep_center := 0.5
var sweep := 0.14
## Seconds for one full left-right-left sweep (peak 2 pi sweep / PERIOD rad/s).
const PERIOD := 45.0

var _t := 0.0


## The view for the scrap hall behind the menu: from the far pavement across the street into the open
## hall, the excavator and the skip in the middle, the truck's place on the left, daylight sky over
## the roof. The sweep stays between the tree and the dealer's shop.
func frame_scrap_hall() -> void:
	target = Vector3(-6.5, 2.3, 5.5)
	radius = 13.6
	eye_height = 3.0
	sweep_center = 0.2
	sweep = 0.15
	h_offset = -1.3
	var attrs := attributes as CameraAttributesPractical
	if attrs:
		attrs.dof_blur_far_distance = 36.0
		attrs.dof_blur_far_transition = 24.0
	_update()


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
	var a := sweep_center + sin(_t * TAU / PERIOD + 0.4) * sweep
	var bob := sin(_t * 0.21) * 0.12
	var pos := Vector3(target.x + sin(a) * radius, eye_height + bob, target.z + cos(a) * radius)
	look_at_from_position(pos, target + Vector3(0, bob * 0.5, 0))
