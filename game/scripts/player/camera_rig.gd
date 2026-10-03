class_name CameraRig
extends Node3D
## Third-person orbit camera with collision-aware spring arm.

const MOUSE_SENSITIVITY := 0.0028
const PAD_SENSITIVITY := 2.6

var target: Node3D
var yaw := 0.0
var pitch := -0.55
var camera: Camera3D
var _arm: SpringArm3D


func _ready() -> void:
	_arm = SpringArm3D.new()
	_arm.spring_length = 6.5
	_arm.margin = 0.3
	add_child(_arm)
	camera = Camera3D.new()
	camera.fov = 55
	_arm.add_child(camera)
	camera.add_child(OutlinePass.create())
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * MOUSE_SENSITIVITY
		pitch = clampf(pitch - event.relative.y * MOUSE_SENSITIVITY, -1.3, 0.35)
	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	if not target:
		return
	var pad := Input.get_vector(&"cam_left", &"cam_right", &"cam_up", &"cam_down")
	yaw -= pad.x * PAD_SENSITIVITY * delta
	pitch = clampf(pitch - pad.y * PAD_SENSITIVITY * delta, -1.3, 0.35)
	global_position = global_position.lerp(target.global_position + Vector3(0, 1.4, 0), 1.0 - exp(-14.0 * delta))
	rotation = Vector3(pitch, yaw, 0)
