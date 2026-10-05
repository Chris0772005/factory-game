extends Node
## Autoload "Juice": local-only game feel (Art Bible 8.3, 8.4, 10).
##   Juice.shake(strength, duration)       camera trauma (0..1), linear falloff over `duration`
##   Juice.shake_at(pos, strength, ...)    same, scaled by distance (full ≤ 3 m, none ≥ 12 m)
##   Juice.hitstop(seconds, [nodes])       freezes the local worker's animation, the camera
##                                         follow and `nodes` for 60–110 ms, plus an FOV punch
##   Juice.punch(node, scale)              elastic scale pop on a Node3D or CanvasItem
##   Juice.impact(pos, trauma, stop)       shake_at + hitstop when the local worker is close
##   Juice.reveal(pos)                     mold break: big shake, 110 ms hitstop, focus zoom
##   Juice.focus(pos, seconds) / zoom(amount, seconds)   camera zoom-ins (CameraRig reads them)
## Nothing here touches gameplay, the network or Engine.time_scale (that would slow the
## host's physics for every player): each peer only moves its own camera and visuals.
## It also tracks the last used input device (key-prompt glyphs) and applies the saved
## GameSettings at boot. Everything is safe headless.

signal device_changed(gamepad: bool)
signal hitstop_started(seconds: float)

## Translation / rotation at trauma 1 (offset = max × trauma² × noise).
const MAX_OFFSET := 0.12
const MAX_ROLL := deg_to_rad(1.5)
const MAX_TILT := deg_to_rad(2.4)
const NOISE_HZ := 18.0
## Distance falloff for positional shakes (m).
const SHAKE_NEAR := 3.0
const SHAKE_FAR := 12.0
## Hitstop only plays for the worker standing at the hit (he is the one swinging).
const HITSTOP_RANGE := 2.6
## Players within this range get the reveal zoom (Art Bible 8.5).
const REVEAL_RANGE := 6.0
const FOCUS_BLEND := 0.35

## True after gamepad input, false after keyboard/mouse input.
var using_gamepad := false
## A full-screen menu (pause) is open; the camera skips its station lean-in.
var menu_open := false

var _shakes: Array[Vector3] = []      # x = strength, y = age (s), z = duration (s)
var _rumble := 0.0
var _rumble_frame := -1
var _trauma := 0.0
var _offset := Vector3.ZERO
var _angles := Vector3.ZERO
var _noise := FastNoiseLite.new()
var _time := 0.0
var _hitstop_left := 0.0
var _frozen := {}                     # Node -> [restore process_mode, seconds left]
var _fov_kick := 0.0
var _fov_kick_rate := 0.0
var _focus_point := Vector3.ZERO
var _focus_age := INF
var _focus_length := 0.0
var _focus_strength := 1.0
var _zoom := 0.0
var _zoom_left := 0.0
var _rigs: Array[Node3D] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0
	_noise.seed = 7
	GameSettings.load_saved()
	if GameSettings.uses_saved_file():
		GameSettings.apply_all(get_tree())


func _input(event: InputEvent) -> void:
	var pad := using_gamepad
	if event is InputEventJoypadButton:
		pad = true
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) > 0.4:
			pad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		pad = false
	elif event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length() > 3.0:
		pad = false
	if pad != using_gamepad:
		using_gamepad = pad
		device_changed.emit(pad)


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_time += delta
	# Hitstop and frozen nodes run on real time, even while their nodes are frozen.
	_hitstop_left = maxf(0.0, _hitstop_left - delta)
	for node in _frozen.keys():
		var entry: Array = _frozen[node]
		entry[1] -= delta
		if not is_instance_valid(node):
			_frozen.erase(node)
		elif entry[1] <= 0.0:
			(node as Node).process_mode = entry[0]
			_frozen.erase(node)
	_fov_kick = move_toward(_fov_kick, 0.0, _fov_kick_rate * delta)
	_focus_age += delta
	if _zoom_left > 0.0:
		_zoom_left -= delta
		if _zoom_left <= 0.0:
			_zoom = 0.0
	# Trauma = strongest live shake (each falls off linearly), or the sustained rumble.
	var trauma := 0.0
	for i in range(_shakes.size() - 1, -1, -1):
		var s := _shakes[i]
		s.y += delta
		if s.y >= s.z:
			_shakes.remove_at(i)
			continue
		_shakes[i] = s
		trauma = maxf(trauma, s.x * (1.0 - s.y / s.z))
	if _rumble_frame >= Engine.get_process_frames() - 1:
		trauma = maxf(trauma, _rumble)
	_trauma = clampf(trauma * GameSettings.screen_shake, 0.0, 1.0)
	var k := _trauma * _trauma
	var t := _time * NOISE_HZ
	_offset = Vector3(_noise.get_noise_2d(t, 11.0), _noise.get_noise_2d(t, 23.0), 0.0) * MAX_OFFSET * k
	_angles = Vector3(_noise.get_noise_2d(t, 37.0) * MAX_TILT, _noise.get_noise_2d(t, 51.0) * MAX_TILT,
		_noise.get_noise_2d(t, 67.0) * MAX_ROLL) * k


# --- Camera shake -------------------------------------------------------------

## Adds camera trauma (0..1) that falls off linearly over `duration` seconds.
## Reference values (Art Bible 8.3): hammer 0.35, reveal 0.5, gong 0.4, steam 0.6, heavy drop 0.15.
func shake(strength: float, duration := 0.35) -> void:
	if strength <= 0.0 or duration <= 0.0:
		return
	_shakes.append(Vector3(clampf(strength, 0.0, 1.0), 0.0, duration))
	if _shakes.size() > 16:
		_shakes.remove_at(0)


## `shake` scaled by the distance from `world_pos` to the local worker (or camera).
func shake_at(world_pos: Vector3, strength: float, duration := 0.35) -> void:
	shake(strength * _falloff(world_pos), duration)


## Sustained low shake while something is going on (pouring); call every frame.
func rumble(strength: float) -> void:
	_rumble = strength if _rumble_frame < Engine.get_process_frames() else maxf(_rumble, strength)
	_rumble_frame = Engine.get_process_frames()


## Current trauma after settings (0..1).
func trauma() -> float:
	return _trauma


## Positional shake for the camera (local space, metres).
func shake_offset() -> Vector3:
	return _offset


## Rotational shake for the camera (pitch, yaw, roll in radians).
func shake_angles() -> Vector3:
	return _angles


# --- Hitstop ------------------------------------------------------------------

## Local visual freeze for `seconds` (hammer 0.07, mold break 0.11, perfect stop 0.09):
## the local worker's animation and the camera follow hold still, `freeze` nodes stop
## processing, and the camera FOV punches in by 2° and returns over 0.2 s.
## Never changes Engine.time_scale or physics.
func hitstop(seconds: float, freeze: Array = []) -> void:
	if seconds <= 0.0:
		return
	_hitstop_left = maxf(_hitstop_left, seconds)
	kick_fov(-2.0, 0.2 + seconds)
	var nodes := freeze.duplicate()
	var tree := _local_anim_tree()
	if tree:
		nodes.append(tree)
	for n in nodes:
		var node := n as Node
		if node == null or not is_instance_valid(node):
			continue
		if _frozen.has(node):
			_frozen[node][1] = maxf(_frozen[node][1], seconds)
		else:
			_frozen[node] = [node.process_mode, seconds]
			node.process_mode = Node.PROCESS_MODE_DISABLED
	hitstop_started.emit(seconds)


func is_hitstopped() -> bool:
	return _hitstop_left > 0.0


## Temporary FOV change in degrees that eases back to 0 over `return_time`.
func kick_fov(degrees: float, return_time := 0.25) -> void:
	_fov_kick = degrees
	_fov_kick_rate = absf(degrees) / maxf(return_time, 0.01)


func fov_offset() -> float:
	return _fov_kick


# --- Punch --------------------------------------------------------------------

## Elastic scale pop: grows by `scale` (0.15 = +15 %) in 60 ms, springs back over
## `duration`. Works on Node3D (visual nodes only – never on physics bodies) and
## CanvasItem; repeated punches restart from the node's resting scale.
func punch(node: Node, scale := 0.15, duration := 0.4) -> void:
	if node == null or not is_instance_valid(node) or not node.is_inside_tree():
		return
	if not (node is Node3D or node is Node2D or node is Control):
		return
	var old: Tween = node.get_meta(&"juice_punch") if node.has_meta(&"juice_punch") else null
	if old and old.is_valid():
		old.kill()
	else:
		node.set_meta(&"juice_rest", node.get(&"scale"))
	var rest: Variant = node.get_meta(&"juice_rest")
	if node is Control:
		(node as Control).pivot_offset = (node as Control).size * 0.5
	var tw := node.create_tween()
	tw.tween_property(node, "scale", rest * (1.0 + scale), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", rest, duration).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		if is_instance_valid(node):
			node.remove_meta(&"juice_punch")
	)
	node.set_meta(&"juice_punch", tw)


# --- Combined events ----------------------------------------------------------

## A hit at `world_pos`: distance-scaled shake, plus `stop` seconds of hitstop when the
## local worker is the one at the hit (within 2.6 m).
func impact(world_pos: Vector3, strength: float, stop := 0.0) -> void:
	shake_at(world_pos, strength)
	if stop > 0.0 and _distance(world_pos) < HITSTOP_RANGE:
		hitstop(stop)


## Mold break-open: trauma 0.5, 110 ms hitstop for the hitter and a 1.2 s focus zoom
## on the casting for everyone within 6 m.
func reveal(world_pos: Vector3) -> void:
	impact(world_pos, 0.5, 0.11)
	if _distance(world_pos) < REVEAL_RANGE:
		focus(world_pos, 1.2)


# --- Camera zoom requests -----------------------------------------------------

## Soft camera zoom towards `world_pos` (FOV 50 → 42, distance −20 %) held for
## `seconds`, eased in and out over 0.35 s. Never takes control away.
func focus(world_pos: Vector3, seconds := 1.2, strength := 1.0) -> void:
	_focus_point = world_pos
	_focus_age = 0.0
	_focus_length = seconds
	_focus_strength = clampf(strength, 0.0, 1.0)


## Weight (0..1) and point of the current focus request.
func focus_weight() -> float:
	if _focus_age > _focus_length + FOCUS_BLEND * 2.0:
		return 0.0
	var w_in := clampf(_focus_age / FOCUS_BLEND, 0.0, 1.0)
	var w_out := clampf((_focus_length + FOCUS_BLEND * 2.0 - _focus_age) / FOCUS_BLEND, 0.0, 1.0)
	return smoothstep(0.0, 1.0, minf(w_in, w_out)) * _focus_strength


func focus_point() -> Vector3:
	return _focus_point


## Slight zoom-in (0..1) without moving the pivot, e.g. for drawing or aiming.
## `seconds` = 0 keeps it until `zoom(0)`.
func zoom(amount: float, seconds := 0.0) -> void:
	_zoom = clampf(amount, 0.0, 1.0)
	_zoom_left = seconds


func zoom_amount() -> float:
	return _zoom


# --- Camera registry ----------------------------------------------------------

## CameraRig registers itself so positional effects know where the local worker is.
func register_rig(rig: Node3D) -> void:
	if not _rigs.has(rig):
		_rigs.append(rig)


func unregister_rig(rig: Node3D) -> void:
	_rigs.erase(rig)


## The rig whose camera is current (or the newest one).
func active_rig() -> Node3D:
	for rig in _rigs:
		var cam: Camera3D = rig.get(&"camera")
		if cam and cam.current:
			return rig
	return _rigs.back() if not _rigs.is_empty() else null


func _listener() -> Variant:
	var rig := active_rig()
	if rig:
		var target: Node3D = rig.get(&"target")
		if target and is_instance_valid(target):
			return target.global_position
	var vp := get_viewport()
	var cam := vp.get_camera_3d() if vp else null
	return cam.global_position if cam else null


func _distance(world_pos: Vector3) -> float:
	var at: Variant = _listener()
	return world_pos.distance_to(at) if at != null else 0.0


func _falloff(world_pos: Vector3) -> float:
	var d := _distance(world_pos)
	return clampf(1.0 - (d - SHAKE_NEAR) / (SHAKE_FAR - SHAKE_NEAR), 0.0, 1.0)


func _local_anim_tree() -> AnimationTree:
	var rig := active_rig()
	if rig == null:
		return null
	var target: Node3D = rig.get(&"target")
	if target == null or not is_instance_valid(target):
		return null
	var found := target.find_children("*", "AnimationTree", true, false)
	return found[0] if not found.is_empty() else null
