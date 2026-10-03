extends Node
## Registers input actions in code so keyboard, mouse and gamepad bindings live in one place.

const BINDINGS := {
	&"move_forward": [{key = KEY_W}, {key = KEY_UP}, {axis = JOY_AXIS_LEFT_Y, dir = -1.0}],
	&"move_back": [{key = KEY_S}, {key = KEY_DOWN}, {axis = JOY_AXIS_LEFT_Y, dir = 1.0}],
	&"move_left": [{key = KEY_A}, {key = KEY_LEFT}, {axis = JOY_AXIS_LEFT_X, dir = -1.0}],
	&"move_right": [{key = KEY_D}, {key = KEY_RIGHT}, {axis = JOY_AXIS_LEFT_X, dir = 1.0}],
	&"jump": [{key = KEY_SPACE}, {joy = JOY_BUTTON_A}],
	&"sprint": [{key = KEY_SHIFT}, {joy = JOY_BUTTON_LEFT_STICK}],
	&"grab": [{mouse = MOUSE_BUTTON_LEFT}, {key = KEY_E}, {joy = JOY_BUTTON_X}, {axis = JOY_AXIS_TRIGGER_RIGHT, dir = 1.0}],
	&"throw": [{mouse = MOUSE_BUTTON_RIGHT}, {key = KEY_Q}, {joy = JOY_BUTTON_Y}],
	&"interact": [{key = KEY_F}, {joy = JOY_BUTTON_B}],
	&"cam_left": [{axis = JOY_AXIS_RIGHT_X, dir = -1.0}],
	&"cam_right": [{axis = JOY_AXIS_RIGHT_X, dir = 1.0}],
	&"cam_up": [{axis = JOY_AXIS_RIGHT_Y, dir = -1.0}],
	&"cam_down": [{axis = JOY_AXIS_RIGHT_Y, dir = 1.0}],
}


func _enter_tree() -> void:
	for action in BINDINGS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for binding in BINDINGS[action]:
			InputMap.action_add_event(action, _event_for(binding))


func _event_for(b: Dictionary) -> InputEvent:
	if b.has("key"):
		var key := InputEventKey.new()
		key.physical_keycode = b.key
		return key
	if b.has("mouse"):
		var mb := InputEventMouseButton.new()
		mb.button_index = b.mouse
		return mb
	if b.has("joy"):
		var jb := InputEventJoypadButton.new()
		jb.button_index = b.joy
		return jb
	var motion := InputEventJoypadMotion.new()
	motion.axis = b.axis
	motion.axis_value = b.dir
	return motion
