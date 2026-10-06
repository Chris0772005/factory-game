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
## Default maximum force the player's arms can exert on a held object (N).
const STRENGTH := 160.0
const THROW_IMPULSE := 7.0
const INTERACT_RANGE := 2.2
## Footstep volume per ground (the dirt samples are louder), pitch spread.
const STEP_DB_DIRT := -22.0
const STEP_DB_GRASS := -17.0
const STEP_PITCH := 0.08

@export var color := Color("#3e7bd6")
@export var peer_id := 1

## Set on the simulating peer (host) only.
var held: RigidBody3D = null
## Replicated flag so every peer can animate reaching arms.
var holding := false
## Replicated node name of the held object (for hints on every peer).
var held_name := ""
## Arm strength in newtons; upgrades raise it.
var strength := STRENGTH
var held_local_point := Vector3.ZERO
## Host-side: the use button is held down (pouring, pumping).
var using := false
## Local-only: a UI (like the draw pad) has the input.
var ui_locked := false
var input_dir := Vector2.ZERO
var wants_sprint := false
var facing := 0.0

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _net_target := Vector3.ZERO
var _net_accum := 0.0
const NET_RATE := 30.0
## Remote workers are drawn this far in the past, interpolated between the
## buffered `_state` snapshots (Art Bible 9.1.3), so packet jitter never shows
## as stutter. The host keeps them fresher: it simulates what they carry.
const INTERP_DELAY := 0.1
const HOST_INTERP_DELAY := 0.05
## When snapshots run out, keep moving along the last velocity this long (s).
const MAX_EXTRAPOLATION := 0.15
const SNAPSHOT_CAP := 16
## Remote only: [local time (s), position, yaw, velocity], oldest first.
var _snapshots: Array = []
var _model: PlayerModel
var _camera_rig: CameraRig
## Holding as last seen (every peer), for grab and drop sounds.
var _was_holding := false
## Seconds since a throw animation started (throws whoosh instead of thud).
var _since_throw := 10.0
## Seconds left before an unexplained release plays the drop thud.
var _drop_pending := -1.0
var _yard: YardSet


func _ready() -> void:
	set_multiplayer_authority(peer_id)
	_net_target = position
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
	_model.footstep.connect(_on_footstep)
	floor_snap_length = 0.3
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	if world and world.has_upgrade(&"gloves"):
		strength = STRENGTH * 1.25
	if is_local():
		_camera_rig = CameraRig.new()
		_camera_rig.target = self
		add_child(_camera_rig)
		_camera_rig.top_level = true
		if DisplayServer.get_name() != "headless":
			var highlight := TargetHighlight.new()
			highlight.name = &"TargetHighlight"
			highlight.player = self
			add_child(highlight)


func is_local() -> bool:
	return not Network.is_online() or is_multiplayer_authority()


func _physics_process(delta: float) -> void:
	if is_local():
		_read_input()
		_move(delta)
		_broadcast_state(delta)
	else:
		_follow_network(delta)
	if held:
		_hold(delta)
		if using and Network.is_sim_authority() and held.has_method("use_tick"):
			held.use_tick(self, delta)
	_update_grips()
	_model.animate(delta, velocity, is_on_floor(), holding, _hand_target())
	_update_hold_sounds(delta)


## Hands go onto the handles of things that have them (crucible), on every peer.
func _update_grips() -> void:
	var grips: Array[Vector3] = []
	var item := held_item() if holding else null
	if item and item.has_method("grip_points"):
		grips = item.grip_points()
	_model.grips = grips
	_model.grips_on_handle = item is Hammer


func _read_input() -> void:
	if ui_locked:
		input_dir = Vector2.ZERO
		wants_sprint = false
		return
	input_dir = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	wants_sprint = Input.is_action_pressed(&"sprint")
	if Input.is_action_just_pressed(&"jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY * _load_factor()
		_model.squash(0.75)
	if Input.is_action_just_pressed(&"grab"):
		_request(&"release" if holding else &"grab")
	if Input.is_action_just_pressed(&"throw") and holding:
		_request(&"throw")
	if Input.is_action_just_pressed(&"interact"):
		_request(&"use_start")
	if Input.is_action_just_released(&"interact"):
		_request(&"use_end")


func _move(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	var yaw := _camera_rig.yaw if _camera_rig else 0.0
	var dir := Vector3(input_dir.x, 0, input_dir.y).rotated(Vector3.UP, yaw)
	var speed := (SPRINT_SPEED if wants_sprint and not holding else WALK_SPEED) * _load_factor()
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
		return 0.8 if holding else 1.0
	var share := held.mass * _gravity / strength
	return clampf(1.0 - share * 0.35, 0.45, 1.0)


## CharacterBody3D does not push rigid bodies on its own; nudge what we walk into.
func _push_bodies() -> void:
	if not Network.is_sim_authority():
		return
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var body := c.get_collider() as RigidBody3D
		if body and body != held:
			var push := -c.get_normal()
			push.y = 0
			body.apply_impulse(push * 0.6 * minf(velocity.length(), 4.0) * 0.1, c.get_position() - body.global_position)


## Where the held object's grab point is pulled to. Items may set their own carry
## pose with `carry_offset(player) -> Vector2(distance, height)` (the crucible is
## held low at the hips); everything else floats at HOLD_DISTANCE / HOLD_HEIGHT.
func _hand_target() -> Vector3:
	var carry := Vector2(HOLD_DISTANCE, HOLD_HEIGHT)
	var item := held_item()
	if item and item.has_method("carry_offset"):
		carry = item.carry_offset(self)
	return global_position + Vector3(0, carry.y, 0) + global_transform.basis.z * carry.x


## The object this worker carries, on every peer: the host knows `held`, other
## peers look it up by its replicated name.
func held_item() -> Node3D:
	if held:
		return held
	if not holding or held_name.is_empty():
		return null
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	if world == null or world.entities == null:
		return null
	return world.entities.get_node_or_null(held_name) as Node3D


func try_grab() -> void:
	var best := grab_candidate()
	if best == null:
		# A conveyor item under the hands (taking it off the belt spawns its body).
		var world := get_tree().get_first_node_in_group(&"world") as GameWorld
		if world and world.factory:
			best = world.factory.pick_item(_hand_target())
	if best:
		grab(best)


## The loose body a grab would take right now: the one nearest the hands in a
## sphere in front of the worker. No side effects, works on every peer (the
## local TargetHighlight outlines it); clients keep replicated bodies frozen,
## so only the simulating peer skips frozen ones.
func grab_candidate() -> RigidBody3D:
	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = GRAB_RANGE * 0.6
	query.shape = sphere
	query.transform = Transform3D(Basis(), global_position + Vector3(0, 0.9, 0) + global_transform.basis.z * 0.9)
	query.exclude = [get_rid()]
	var sim := Network.is_sim_authority()
	var best: RigidBody3D = null
	var best_dist := INF
	for hit in space.intersect_shape(query, 16):
		var body := hit.collider as RigidBody3D
		if body == null or (body.freeze and sim):
			continue
		var d := body.global_position.distance_to(_hand_target())
		if d < best_dist:
			best_dist = d
			best = body
	return best


func grab(body: RigidBody3D) -> void:
	held = body
	if body.has_method("hold_point"):
		# Tools are held by their grip.
		held_local_point = body.hold_point()
	else:
		# Grab at the point on the body closest to our hand so big objects can be held by an edge.
		var closest := _closest_point_on_body(body, _hand_target())
		held_local_point = body.to_local(closest)
	body.sleeping = false
	_set_holding(true, body.name)
	if body.has_method("on_grabbed"):
		body.on_grabbed(self)


func release() -> void:
	if held and held.has_method("on_released"):
		held.on_released(self)
	held = null
	_set_holding(false, "")


func throw() -> void:
	var body := held
	if body == null:
		return
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
	var lift := clampf(force.y, -strength, strength)
	var steer := Vector3(force.x, 0, force.z).limit_length(strength * 0.7)
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


## Closest station in reach that accepts `interact(player)`. Works on every peer
## so the local HUD can show a hint.
func nearest_interactable() -> Node3D:
	var best: Node3D = null
	var best_d := INTERACT_RANGE
	var probe := global_position + Vector3(0, 0.9, 0) + global_transform.basis.z * 0.6
	for node in get_tree().get_nodes_in_group(&"interactable"):
		var n := node as Node3D
		var point: Vector3 = n.interact_point() if n.has_method("interact_point") else n.global_position
		var d := probe.distance_to(point)
		if d < best_d:
			best_d = d
			best = n
	return best


## Moves the worker (e.g. respawn). Movement is owned by the controlling
## peer, so the host forwards the request there.
func teleport(pos: Vector3) -> void:
	release()
	if is_local():
		_do_teleport(pos)
	else:
		_teleport_remote.rpc_id(peer_id, pos)


@rpc("any_peer", "call_remote", "reliable")
func _teleport_remote(pos: Vector3) -> void:
	if multiplayer.get_remote_sender_id() == 1:
		_do_teleport(pos)


func _do_teleport(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	_net_target = pos
	reset_physics_interpolation()
	_model.squash(1.4)


## Hint text for the local HUD, e.g. "[F] Gießen".
func current_hint() -> String:
	if holding:
		var world := get_tree().get_first_node_in_group(&"world") as GameWorld
		return world.held_hint(self) if world else ""
	var target := nearest_interactable()
	if target and target.has_method("hint"):
		return target.hint(self)
	return ""


# --- Networking -------------------------------------------------------------

## Grab/release/throw run on the simulating peer; clients ask the host.
## The body animation starts right away on the acting peer and is mirrored to the others.
func _request(action: StringName) -> void:
	_show_action(_action_anim(action))
	if Network.is_sim_authority():
		_perform(action)
	else:
		_srv_request.rpc_id(1, action)


## One-shot body animation for a request (PlayerModel.ACTIONS), or "" for none.
## Evaluated before the request runs, while `holding` still says what is in hand.
func _action_anim(action: StringName) -> StringName:
	match action:
		&"grab":
			return &"pickup"
		&"throw":
			return &"throw" if holding else &""
		&"use_start":
			var item := held_item() if holding else null
			if item:
				return &"hammer" if item is Hammer else &""
			var target := nearest_interactable()
			if target is Furnace:
				return &"kick"
			if target is MoldBox and (target as MoldBox).state == MoldBox.State.PATTERNED:
				return &"ram"
			if target:
				return &"interact"
	return &""


func _show_action(anim: StringName) -> void:
	if anim.is_empty():
		return
	_play_action(anim)
	if Network.is_online():
		_action_remote.rpc(anim)


@rpc("authority", "call_remote", "unreliable")
func _action_remote(anim: StringName) -> void:
	_play_action(anim)


func _play_action(anim: StringName) -> void:
	_model.play_action(anim)
	if anim == &"throw":
		_since_throw = 0.0
		Sfx.play(&"throw_whoosh", _hand_target(), -6.0, 0.1)


## Grab, drop and throw sounds on every peer, from the replicated `holding`
## flag: a grab thumps, a release thuds unless it was a throw (whoosh, played
## with the throw animation), which may arrive a moment after the release.
func _update_hold_sounds(delta: float) -> void:
	_since_throw += delta
	if holding != _was_holding:
		_was_holding = holding
		if holding:
			Sfx.play(&"pickup", _hand_target(), -8.0)
			_drop_pending = -1.0
		elif _since_throw > 0.3:
			_drop_pending = 0.15
	if _drop_pending >= 0.0:
		_drop_pending -= delta
		if _since_throw < 0.45:
			_drop_pending = -1.0
		elif _drop_pending < 0.0:
			Sfx.play(&"drop_thud", _hand_target(), -14.0)


## A boot hits the ground: crunchy grass on the lawn, a duller thump on the
## worn dirt and sand of the work area (read from the yard's ground mask).
func _on_footstep(_foot: int) -> void:
	if _yard == null:
		var world := get_tree().get_first_node_in_group(&"world")
		_yard = world.get_node_or_null(^"YardSet") as YardSet if world else null
	var dirt := 1.0
	if _yard and _yard.layout:
		var zones := _yard.layout.zones_at(Vector2(global_position.x, global_position.z))
		dirt = maxf(zones.r, zones.a)
	if dirt > 0.5:
		Sfx.play(&"step_dirt", global_position, STEP_DB_DIRT, STEP_PITCH)
	else:
		Sfx.play(&"step_grass", global_position, STEP_DB_GRASS, STEP_PITCH)


@rpc("any_peer", "call_remote", "reliable")
func _srv_request(action: StringName) -> void:
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	_perform(action)


func _perform(action: StringName) -> void:
	match action:
		&"grab":
			if not held:
				try_grab()
		&"release":
			release()
		&"throw":
			throw()
		&"use_start":
			using = true
			if held and held.has_method("use_start"):
				held.use_start(self)
			elif not held:
				var target := nearest_interactable()
				if target:
					target.interact(self)
		&"use_end":
			using = false
			if held and held.has_method("use_end"):
				held.use_end(self)


func _set_holding(value: bool, item_name: String) -> void:
	holding = value
	held_name = item_name
	if Network.is_online() and multiplayer.is_server() and peer_id in multiplayer.get_peers():
		_set_holding_remote.rpc_id(peer_id, value, item_name)


## Sent by the host; the node's authority is the owning client, so allow any peer
## and check the sender instead.
@rpc("any_peer", "call_remote", "reliable")
func _set_holding_remote(value: bool, item_name: String) -> void:
	if multiplayer.get_remote_sender_id() == 1:
		holding = value
		held_name = item_name


func _broadcast_state(delta: float) -> void:
	if not Network.is_online():
		return
	_net_accum += delta
	if _net_accum < 1.0 / NET_RATE:
		return
	_net_accum = 0.0
	_state.rpc(global_position, facing, velocity, holding, held_name)


@rpc("authority", "call_remote", "unreliable_ordered")
func _state(pos: Vector3, yaw: float, vel: Vector3, is_holding: bool, item_name: String) -> void:
	_net_target = pos
	if not _snapshots.is_empty() and (_snapshots[-1][1] as Vector3).distance_to(pos) > 3.0:
		# Teleport or respawn: jump there instead of flying across the yard.
		_snapshots.clear()
	_snapshots.append([_snapshot_time(), pos, yaw, vel])
	if _snapshots.size() > SNAPSHOT_CAP:
		_snapshots.pop_front()
	if multiplayer.get_unique_id() != 1:
		holding = is_holding
		held_name = item_name


## Local timestamp for a snapshot arriving now. The sender ticks at a steady
## NET_RATE, so arrival jitter is filtered out: each snapshot is placed one
## (or, after a lost packet, several) send intervals after the previous one,
## drifting only slowly towards the real arrival time.
func _snapshot_time() -> float:
	var now := Time.get_ticks_usec() / 1000000.0
	if _snapshots.is_empty():
		return now
	var last: float = _snapshots[-1][0]
	var interval := 1.0 / NET_RATE
	var steps := maxf(1.0, roundf((now - last) / interval))
	var expected := last + steps * interval
	if absf(now - expected) > 0.25:
		# A stall or a clock jump: start over from real time.
		return now
	return maxf(expected + (now - expected) * 0.1, last + 0.001)


## Interpolated [position, yaw, velocity] of the remote worker at the delayed
## render time, extrapolated briefly past the newest snapshot; empty if none.
func _sample_snapshots() -> Array:
	if _snapshots.is_empty():
		return []
	var delay := HOST_INTERP_DELAY if multiplayer.is_server() else INTERP_DELAY
	var t := Time.get_ticks_usec() / 1000000.0 - delay
	var newest: Array = _snapshots[-1]
	if t >= newest[0]:
		var ahead := minf(t - float(newest[0]), MAX_EXTRAPOLATION)
		return [newest[1] + newest[3] * ahead, newest[2], newest[3]]
	# Drop snapshots that are no longer needed (keep the pair around t).
	while _snapshots.size() > 2 and float(_snapshots[1][0]) <= t:
		_snapshots.pop_front()
	var a: Array = _snapshots[0]
	if t <= a[0] or _snapshots.size() < 2:
		return [a[1], a[2], a[3]]
	var b: Array = _snapshots[1]
	var k := clampf((t - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.001), 0.0, 1.0)
	return [(a[1] as Vector3).lerp(b[1], k), lerp_angle(a[2], b[2], k), (a[3] as Vector3).lerp(b[3], k)]


## Remote workers follow their interpolated snapshot path with move_and_slide
## so they still collide with (and on the host, push) physics objects.
func _follow_network(delta: float) -> void:
	var sample := _sample_snapshots()
	if sample.is_empty():
		return
	var target: Vector3 = sample[0]
	facing = sample[1]
	var to_target := target - global_position
	if to_target.length() > 3.0:
		global_position = target
		rotation.y = facing
		reset_physics_interpolation()
		return
	velocity = to_target / maxf(delta, 0.001)
	move_and_slide()
	_push_bodies()
	# Animation reads the sender's velocity, not the catch-up step.
	velocity = sample[2]
	rotation.y = facing
