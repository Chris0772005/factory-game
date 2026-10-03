class_name Player
extends CharacterBody3D
## Co-op worker. Movement is owned by the controlling peer; grabbing forces
## are applied by whoever simulates physics (the host).

const WALK_SPEED := 4.2
const SPRINT_SPEED := 6.6
const ACCEL := 14.0
const AIR_ACCEL := 4.0
const JUMP_VELOCITY := 5.2
const GRAB_RANGE := 1.9
const HOLD_DISTANCE := 1.05
const HOLD_HEIGHT := 1.05
## Maximum force the player's arms can exert on a held object (N).
const STRENGTH := 160.0
const THROW_IMPULSE := 7.0

@export var color := Color("#3d7dd8")

var held: RigidBody3D = null
var held_local_point := Vector3.ZERO
var input_dir := Vector2.ZERO
var wants_sprint := false
var facing := 0.0

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _model: PlayerModel
var _camera_rig: CameraRig


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.6
	shape.shape = capsule
	shape.position.y = 0.8
	add_child(shape)
	_model = PlayerModel.new()
	_model.suit_color = color
	add_child(_model)
	floor_snap_length = 0.3
	if is_local():
		_camera_rig = CameraRig.new()
		_camera_rig.target = self
		add_child(_camera_rig)
		_camera_rig.top_level = true


func is_local() -> bool:
	return not multiplayer.has_multiplayer_peer() or is_multiplayer_authority()


func _physics_process(delta: float) -> void:
	if is_local():
		_read_input()
	_move(delta)
	if held:
		_hold(delta)
	_model.animate(delta, velocity, is_on_floor(), held != null, _hand_target())


func _read_input() -> void:
	input_dir = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	wants_sprint = Input.is_action_pressed(&"sprint")
	if Input.is_action_just_pressed(&"jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY * _load_factor()
		_model.squash(0.75)
	if Input.is_action_just_pressed(&"grab"):
		if held:
			release()
		else:
			try_grab()
	if Input.is_action_just_pressed(&"throw") and held:
		throw()


func _move(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	var yaw := _camera_rig.yaw if _camera_rig else 0.0
	var dir := Vector3(input_dir.x, 0, input_dir.y).rotated(Vector3.UP, yaw)
	var speed := (SPRINT_SPEED if wants_sprint and not held else WALK_SPEED) * _load_factor()
	var target := dir * speed
	var accel := ACCEL if is_on_floor() else AIR_ACCEL
	var horizontal := Vector3(velocity.x, 0, velocity.z).move_toward(target, accel * speed * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if dir.length_squared() > 0.01:
		facing = lerp_angle(facing, atan2(dir.x, dir.z), 1.0 - exp(-12.0 * delta))
	rotation.y = facing
	var was_airborne := not is_on_floor()
	move_and_slide()
	if was_airborne and is_on_floor():
		_model.squash(1.25)
	_push_bodies()


## Heavier loads slow the worker down.
func _load_factor() -> float:
	if not held:
		return 1.0
	var share := held.mass * _gravity / STRENGTH
	return clampf(1.0 - share * 0.35, 0.45, 1.0)


## CharacterBody3D does not push rigid bodies on its own; nudge what we walk into.
func _push_bodies() -> void:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var body := c.get_collider() as RigidBody3D
		if body and body != held:
			var push := -c.get_normal()
			push.y = 0
			body.apply_impulse(push * 0.6 * minf(velocity.length(), 4.0) * 0.1, c.get_position() - body.global_position)


func _hand_target() -> Vector3:
	return global_position + Vector3(0, HOLD_HEIGHT, 0) + global_transform.basis.z * HOLD_DISTANCE


func try_grab() -> void:
	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = GRAB_RANGE * 0.6
	query.shape = sphere
	query.transform = Transform3D(Basis(), global_position + Vector3(0, 0.9, 0) + global_transform.basis.z * 0.9)
	query.exclude = [get_rid()]
	var best: RigidBody3D = null
	var best_dist := INF
	for hit in space.intersect_shape(query, 16):
		var body := hit.collider as RigidBody3D
		if body == null or body.freeze:
			continue
		var d := body.global_position.distance_to(_hand_target())
		if d < best_dist:
			best_dist = d
			best = body
	if best:
		grab(best)


func grab(body: RigidBody3D) -> void:
	held = body
	# Grab at the point on the body closest to our hand so big objects can be held by an edge.
	var closest := _closest_point_on_body(body, _hand_target())
	held_local_point = body.to_local(closest)
	body.sleeping = false
	if body.has_method("on_grabbed"):
		body.on_grabbed(self)


func release() -> void:
	if held and held.has_method("on_released"):
		held.on_released(self)
	held = null


func throw() -> void:
	var body := held
	release()
	var dir := global_transform.basis.z + Vector3(0, 0.45, 0)
	body.apply_central_impulse(dir.normalized() * THROW_IMPULSE * minf(body.mass, 3.0))


## Spring-damper pull from the grab point towards the hand, capped by arm strength.
## Several players holding one object simply add their forces.
func _hold(delta: float) -> void:
	if not is_instance_valid(held):
		held = null
		return
	var point := held.to_global(held_local_point)
	var to_target := _hand_target() - point
	if to_target.length() > 2.6:
		release()
		return
	var offset := point - held.global_position
	var point_vel := held.linear_velocity + held.angular_velocity.cross(offset)
	var rel_vel := point_vel - velocity
	var force := to_target * 420.0 * held.mass - rel_vel * 38.0 * held.mass
	force += Vector3.UP * held.mass * _gravity / maxf(1.0, _holders(held))
	# Lifting and steering draw on separate budgets so sideways tugging
	# between two carriers does not eat the strength needed to hold the load up.
	var lift := clampf(force.y, -STRENGTH, STRENGTH)
	var steer := Vector3(force.x, 0, force.z).limit_length(STRENGTH * 0.7)
	held.apply_force(steer + Vector3.UP * lift, offset)
	held.angular_velocity *= 1.0 - minf(1.0, 6.0 * delta)


func _holders(body: RigidBody3D) -> float:
	var n := 0
	for p in get_tree().get_nodes_in_group(&"players"):
		if p.held == body:
			n += 1
	return float(n)


func _closest_point_on_body(body: RigidBody3D, world_point: Vector3) -> Vector3:
	for child in body.get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			var half: Vector3 = child.shape.size * 0.5
			var local := (child as CollisionShape3D).global_transform.affine_inverse() * world_point
			return child.global_transform * local.clamp(-half, half)
	return body.global_position


func _enter_tree() -> void:
	add_to_group(&"players")
