class_name CameraRig
extends Node3D
## Third-person orbit camera for the local worker (Art Bible 8).
##
## Runs in `_process` on the worker's *interpolated* transform with its own physics
## interpolation off, so it is smooth at any refresh rate (rule 8). The pivot
## (worker + 1.1 m + up to 0.5 m velocity look-ahead) follows on damped springs
## (half-life 0.08 s horizontal, 0.18 s vertical, so jumps don't yank the view);
## landings dip it on a spring. Mouse orbit is direct with a 25 ms settle, the
## gamepad stick uses a 1.6 response curve with a 0.12 s ramp. A sphere probe pulls
## the camera in front of walls instantly and lets it back out softly; workers, loose
## objects and thin `camera_passthrough` set pieces never push it.
## Mouse wheel / shoulder buttons zoom 4.5–9 m. Sprinting widens the FOV a little.
## Zoom-ins: pouring from a held crucible and UI at a station (drawing, shop) lean the
## camera in automatically; `Juice.focus()` / `Juice.zoom()` request more. Shake,
## hitstop and FOV punches come from the Juice autoload.

const MOUSE_SENSITIVITY := 0.0028
const PAD_CURVE := 1.6
const PAD_YAW_SPEED := deg_to_rad(180.0)
const PAD_PITCH_SPEED := deg_to_rad(110.0)
const PAD_RAMP := 0.12
const PITCH_MIN := deg_to_rad(-65.0)
const PITCH_MAX := deg_to_rad(-12.0)
const DISTANCE := 7.0
const ZOOM_MIN := 4.5
const ZOOM_MAX := 9.0
const ZOOM_STEP := 0.6
const FOV := 50.0
const SPRINT_FOV := 5.0
const PIVOT_HEIGHT := 1.1
## Look-ahead: this many seconds of velocity, at most LOOK_AHEAD_MAX metres, eased at 3/s.
const LOOK_AHEAD_TIME := 0.12
const LOOK_AHEAD_MAX := 0.5
const LOOK_AHEAD_RATE := 3.0
const HALF_LIFE_H := 0.08
const HALF_LIFE_V := 0.18
const ORBIT_HALF_LIFE := 0.025
const ZOOM_HALF_LIFE := 0.1
const PROBE_RADIUS := 0.25
const PROBE_MARGIN := 0.2
## Arm length back out after a collision: settles in ~0.25 s.
const EXTEND_HALF_LIFE := 0.07
const MIN_ARM := 0.8
## Further than this from the pivot (respawn, teleport) the camera cuts instead of flying.
const SNAP_DISTANCE := 8.0

var target: Node3D
## Orbit angles the worker steers by (the view settles onto them).
var yaw := 0.0
var pitch := deg_to_rad(-35.0)
var camera: Camera3D
## Player-chosen arm length (zoom).
var distance := DISTANCE

var _view_yaw := 0.0
var _view_pitch := pitch
var _view_distance := DISTANCE
var _pivot := Vector3.ZERO
var _has_pivot := false
var _ahead := Vector3.ZERO
var _arm := DISTANCE
var _pad_vel := Vector2.ZERO
var _sprint := 0.0
var _focus := 0.0
var _focus_point := Vector3.ZERO
var _was_on_floor := true
var _fall_speed := 0.0
var _dip := 0.0
var _dip_vel := 0.0
var _query := PhysicsShapeQueryParameters3D.new()
var _excluded: Array[RID] = []
var _exclude_age := 0.0


func _ready() -> void:
	# Moved in _process from interpolated data: render it exactly where we put it.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera = Camera3D.new()
	camera.fov = FOV
	add_child(camera)
	camera.add_child(OutlinePass.create())
	var probe := SphereShape3D.new()
	probe.radius = PROBE_RADIUS
	_query.shape = probe
	_query.collide_with_areas = false
	_view_yaw = yaw
	_view_pitch = pitch
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _enter_tree() -> void:
	Juice.register_rig(self)


func _exit_tree() -> void:
	Juice.unregister_rig(self)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		var k := MOUSE_SENSITIVITY * GameSettings.mouse_sensitivity
		yaw -= motion.relative.x * k
		pitch = clampf(pitch - motion.relative.y * k, PITCH_MIN, PITCH_MAX)
	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = clampf(distance - ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = clampf(distance + ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
		elif Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not get_tree().paused and not _ui_locked():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		# Only reached when no pause menu took the key (levels without a HUD).
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target) or delta <= 0.0:
		return
	_orbit_from_pad(delta)
	var k_orbit := _smooth(ORBIT_HALF_LIFE, delta)
	_view_yaw = lerp_angle(_view_yaw, yaw, k_orbit)
	_view_pitch = lerpf(_view_pitch, pitch, k_orbit)
	_view_distance = lerpf(_view_distance, distance, _smooth(ZOOM_HALF_LIFE, delta))

	var body := target as CharacterBody3D
	var velocity := body.velocity if body else Vector3.ZERO
	var planar := Vector3(velocity.x, 0.0, velocity.z)
	var anchor := target.get_global_transform_interpolated().origin + Vector3.UP * PIVOT_HEIGHT
	if not _has_pivot or _pivot.distance_to(anchor) > SNAP_DISTANCE:
		_has_pivot = true
		_pivot = anchor
		_ahead = Vector3.ZERO
		_arm = _view_distance
	elif not Juice.is_hitstopped():
		var ahead_goal := (planar * LOOK_AHEAD_TIME).limit_length(LOOK_AHEAD_MAX)
		_ahead = _ahead.lerp(ahead_goal, 1.0 - exp(-LOOK_AHEAD_RATE * delta))
		var goal := anchor + _ahead
		var kh := _smooth(HALF_LIFE_H, delta)
		_pivot.x = lerpf(_pivot.x, goal.x, kh)
		_pivot.z = lerpf(_pivot.z, goal.z, kh)
		_pivot.y = lerpf(_pivot.y, goal.y, _smooth(HALF_LIFE_V, delta))
	_update_landing(body, velocity, delta)
	var sprint_goal := clampf((planar.length() - Player.WALK_SPEED * 1.05) / (Player.SPRINT_SPEED - Player.WALK_SPEED * 1.05), 0.0, 1.0)
	_sprint = lerpf(_sprint, sprint_goal, 1.0 - exp(-5.0 * delta))

	# Zoom-ins: automatic (pouring, station UI) blended with Juice.focus requests.
	_update_auto_focus(body, anchor, delta)
	var jw := Juice.focus_weight()
	var w := maxf(jw, _focus)
	var point := _focus_point.lerp(Juice.focus_point(), jw / maxf(jw + _focus, 0.0001))
	var zoom := Juice.zoom_amount()
	var pivot := _pivot.lerp(point + Vector3.UP * 0.3, 0.35 * w) + Vector3.UP * _dip
	var want := _view_distance * (1.0 - 0.2 * w) * (1.0 - 0.15 * zoom) * (1.0 + 0.05 * _sprint)

	var basis := Basis.from_euler(Vector3(_view_pitch, _view_yaw, 0.0))
	var reach := _probe(pivot, basis.z, want)
	if reach < _arm:
		_arm = reach
	else:
		_arm = lerpf(_arm, reach, _smooth(EXTEND_HALF_LIFE, delta))
	global_transform = Transform3D(basis, pivot)
	camera.transform = Transform3D(Basis.from_euler(Juice.shake_angles()), Vector3(0.0, 0.0, _arm) + Juice.shake_offset())
	camera.fov = FOV + SPRINT_FOV * _sprint - 8.0 * w - 4.0 * zoom + Juice.fov_offset()


## Gamepad orbit: response curve, max speeds and a short ramp so it never jerks.
func _orbit_from_pad(delta: float) -> void:
	if _ui_locked():
		_pad_vel = Vector2.ZERO
		return
	var stick := Input.get_vector(&"cam_left", &"cam_right", &"cam_up", &"cam_down")
	var curved := Vector2(signf(stick.x) * pow(absf(stick.x), PAD_CURVE), signf(stick.y) * pow(absf(stick.y), PAD_CURVE))
	var goal := Vector2(curved.x * PAD_YAW_SPEED, curved.y * PAD_PITCH_SPEED)
	_pad_vel = _pad_vel.move_toward(goal, maxf(PAD_YAW_SPEED, PAD_PITCH_SPEED) / PAD_RAMP * delta)
	yaw -= _pad_vel.x * delta
	pitch = clampf(pitch - _pad_vel.y * delta, PITCH_MIN, PITCH_MAX)
	var pad := _first_pad()
	if pad >= 0:
		if Input.is_joy_button_pressed(pad, JOY_BUTTON_LEFT_SHOULDER):
			distance = clampf(distance - 4.0 * delta, ZOOM_MIN, ZOOM_MAX)
		elif Input.is_joy_button_pressed(pad, JOY_BUTTON_RIGHT_SHOULDER):
			distance = clampf(distance + 4.0 * delta, ZOOM_MIN, ZOOM_MAX)


## Landing weight: the pivot dips on a spring (more for harder landings).
func _update_landing(body: CharacterBody3D, velocity: Vector3, delta: float) -> void:
	if body:
		var on_floor := body.is_on_floor()
		if not on_floor:
			_fall_speed = maxf(_fall_speed, -velocity.y)
		elif not _was_on_floor:
			if _fall_speed > 2.5:
				_dip_vel -= clampf(_fall_speed * 0.08, 0.0, 0.8)
				if _fall_speed > 6.0:
					Juice.shake(0.15, 0.25)
			_fall_speed = 0.0
		_was_on_floor = on_floor
	_dip_vel += (-_dip * 160.0 - _dip_vel * 15.0) * delta
	_dip += _dip_vel * delta


## Leans in while the worker pours from a held crucible or uses a station UI.
func _update_auto_focus(body: Node3D, anchor: Vector3, delta: float) -> void:
	var goal := 0.0
	var point := anchor
	var held := _held_node()
	if held is Crucible and (held as Crucible).flow > 0.05:
		var crucible := held as Crucible
		goal = 0.55
		point = crucible.pour_target if crucible.pour_target != Vector3.ZERO else crucible.global_position
		Juice.rumble(0.14 * clampf(crucible.flow, 0.0, 1.0))
	elif _ui_locked() and body is Player and not Juice.menu_open:
		var station := (body as Player).nearest_interactable()
		if station:
			goal = 0.45
			point = station.interact_point() if station.has_method("interact_point") else station.global_position
	_focus = lerpf(_focus, goal, 1.0 - exp(-4.0 * delta))
	if goal > 0.0:
		_focus_point = _focus_point.lerp(point, 1.0 - exp(-6.0 * delta)) if _focus > 0.02 else point


## Distance the camera can back away from `from` along `dir` without entering a
## wall; ignores workers, loose physics objects and camera_passthrough pieces.
func _probe(from: Vector3, dir: Vector3, want: float) -> float:
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	if space == null:
		return want
	_exclude_age += get_process_delta_time()
	if _exclude_age > 2.0:
		_exclude_age = 0.0
		_excluded.clear()
	if target is CollisionObject3D and not _excluded.has((target as CollisionObject3D).get_rid()):
		_excluded.append((target as CollisionObject3D).get_rid())
	var travel := want + PROBE_MARGIN
	_query.transform = Transform3D(Basis(), from)
	_query.motion = dir * travel
	for i in 6:
		_query.exclude = _excluded
		var res := space.cast_motion(_query)
		if res.is_empty() or res[1] >= 1.0:
			return want
		var hit_query := PhysicsShapeQueryParameters3D.new()
		hit_query.shape = _query.shape
		hit_query.exclude = _excluded
		hit_query.transform = Transform3D(Basis(), from + dir * travel * res[1])
		var info := space.get_rest_info(hit_query)
		var collider: Object = instance_from_id(info.collider_id) if info.has("collider_id") else null
		if collider and _passes_through(collider):
			_excluded.append(info.rid)
			continue
		return clampf(travel * res[0] - PROBE_MARGIN, MIN_ARM, want)
	return want


func _passes_through(collider: Object) -> bool:
	if collider is RigidBody3D or collider is CharacterBody3D:
		return true
	return collider is Node and (collider as Node).is_in_group(&"camera_passthrough")


func _held_node() -> Node:
	if not target is Player:
		return null
	var p := target as Player
	if not p.holding or p.held_name.is_empty():
		return null
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	return world.entities.get_node_or_null(p.held_name) if world and world.entities else null


func _ui_locked() -> bool:
	return target is Player and (target as Player).ui_locked


static func _first_pad() -> int:
	var pads := Input.get_connected_joypads()
	return pads[0] if not pads.is_empty() else -1


## Exponential smoothing factor for a half-life (frame-rate independent).
static func _smooth(half_life: float, delta: float) -> float:
	return 1.0 - pow(2.0, -delta / maxf(half_life, 0.0001))
