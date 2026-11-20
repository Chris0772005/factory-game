class_name PlayerModel
extends Node3D
## The worker other players see of a player (players see only their own hands and legs in first
## person; the full figure just casts their shadow): a generated figure of a real-looking person,
## like the townspeople (AI-generated, see assets/models/people/NOTICE.txt; put together by
## tools/people.py; docs/TECH_SPEC.md, Modul Y), with a hard hat in the player's colour.
## Faces +Z; Player rotates this node.
##
## `animate()` (called at physics rate) drives an AnimationTree: standing, one walking and one
## running step pair, kept in step with each other and played as fast as the ground speed asks
## (no sliding feet), and the pose of the run's flight while in the air.
## WorkerRig does the rest by aiming hands, back, head, hips and one foot: carrying (both hands on
## the load or on its handles, the body stepping in and bending over it), working with the bare
## hands (`working`), the short actions (`play_action`) and the dip of a landing. The body leans a
## little into acceleration and turns.
## `pose_data()` / `apply_pose()` snapshot and freeze bone rotations (bronze statues).

signal footstep(foot: int)

## Global positions of the two handles of the carried object (e.g. the crucible's
## grips), set by Player at physics rate; empty = hold the load's centre.
var grips: Array[Vector3] = []
## True when `grips` are two hand positions along one handle, [left, right]
## (the sledgehammer) rather than two handles either side of a load.
var grips_on_handle := false
## True while the worker works at something with the bare hands (digging in the heap): the hands
## go at what is in front, one after the other. Set by Player at physics rate.
var working := false

@export var suit_color := Color("#3e7bd6"):
	set(value):
		suit_color = value
		if is_node_ready():
			_apply_colors()

const BODY_DIR := "res://assets/models/people/"
## Who wears which player colour (GameWorld.PLAYER_COLORS in hex); any other colour gets DEFAULT_BODY.
const BODIES := {"3e7bd6": "mate_a", "26b5c4": "mate_b", "9b5bd0": "mate_a", "e26aa0": "mate_b"}
const DEFAULT_BODY := "mate_a"
## Per body: where the hard hat sits (middle of its rim and its three radii, in the figure's own
## space as it stands at rest, cm; fitted round the head by measuring it: 2 cm clear above the hair,
## 0.7 cm at the sides, the rim two fingers above the brows), and what it wears, for the player's
## own arms and legs in first person: shirt, vest, trousers and boots.
const LOOKS := {
	"mate_a": {hat_at = Vector3(0.0, 172.7, 0.95), hat_size = Vector3(10.45, 9.2, 11.9),
		shirt = Color("#27324a"), vest = Color("#e8641c"), trousers = Color("#45474b"), boots = Color("#27231f")},
	"mate_b": {hat_at = Vector3(0.6, 163.0, -1.1), hat_size = Vector3(9.3, 9.0, 10.6),
		shirt = Color("#6f7173"), vest = Color("#c9d32a"), trousers = Color("#2c3548"), boots = Color("#5a4230")},
}
## Ground speed (m/s) the walking and the running step pair are made for, for a figure whose hips
## stand HIPS_REF above the ground (measured from the planted foot); a taller figure covers more.
## They double as blend-space positions, so speed maps 1:1.
const HIPS_REF := 0.965
const WALK_PACE := 1.33
const RUN_PACE := 3.5
const LOOPED_CLIPS: Array[StringName] = [&"Idle_Neutral", &"WalkCycle", &"RunCycle"]
## The short actions of `play_action` and how long each takes (s). They are aimed, not played
## from clips: see `_action_pose`.
const ACTIONS := {
	&"pickup": 0.35,
	&"interact": 0.5,
	&"use": 0.5,
	&"throw": 0.42,
	&"hammer": 0.45,
	&"ram": 0.4,
	&"kick": 0.5,
	&"cheer": 1.3,
	&"hit": 0.45,
}
## Distance of each hand from the carry point, sideways (m).
const HAND_SPREAD := 0.19
## Bending forwards (carrying, working, the short actions): HINGE_SHARE of the angle is a tilt of
## the hips, as a person bends down, the rest a curve of the back.
const HINGE_SHARE := 0.6
## Carrying: the load floats ahead of the player (where the player aims, or at
## Player.HOLD_DISTANCE), further than bent arms reach from where the player stands, and often
## lower than the hands hang. So the body comes to the load: it bends over it by CARRY_BEND
## (rad); where the wrists have to go further below the shoulders than REACH_DOWN (m), it bends
## more (LOW_BEND rad per metre lacking, up to LOW_BEND_MAX) and the knees give for what is still
## missing (up to LOW_DIP_MAX, m); and the body steps in (up to CARRY_STEP_MAX, m) until the
## wrists are within the arms' easy reach (ARM_REACH, m from shoulder to wrist: the elbows stay
## bent) and at most WRIST_AHEAD in front of the shoulders. The head takes back HEAD_LEVELING of
## the bend, so the face looks ahead, not at the feet.
const CARRY_BEND := 0.2
const CARRY_STEP_MAX := 0.44
const ARM_REACH := 0.45
const WRIST_AHEAD := 0.22
const REACH_DOWN := 0.4
const LOW_BEND := 1.6
const LOW_BEND_MAX := 0.9
const LOW_DIP_MAX := 0.45
const HEAD_LEVELING := 0.6
## Where the knees give, the hips go back by this share of the way down (a squat, not a kneel).
const SQUAT_BACK := 0.45
## Working with the bare hands: how often a hand goes at it (per second), how far the body steps
## in (m), bends (rad) and the knees give (m), and the round the wrists make in front: its middle
## (to the side of the body's middle, below the shoulders and ahead of them, m) and its half
## height and depth (m); the two hands are half a round apart.
const WORK_RATE := 1.5
const WORK_STEP := 0.25
const WORK_BEND := 0.7
const WORK_DIP := 0.14
const WORK_AT := Vector3(0.16, -0.34, 0.22)
const WORK_ROUND := Vector2(0.08, 0.1)

## Bones captured by `pose_data()`: hips offset + 20 rotations (64 floats).
const POSE_BONES: Array[StringName] = [&"Hips", &"Spine02", &"Spine01", &"Spine", &"neck", &"Head",
	&"LeftShoulder", &"LeftArm", &"LeftForeArm", &"LeftHand", &"RightShoulder", &"RightArm", &"RightForeArm", &"RightHand",
	&"LeftUpLeg", &"LeftLeg", &"LeftFoot", &"RightUpLeg", &"RightLeg", &"RightFoot"]
## Format 3: [3, hips offset from their rest place in metres (x, y, z), then x, y, z of each
## POSE_BONES rotation]. Format 2 was the pose of the stylised figure before; it reads as the
## panic pose now.
const POSE_FORMAT := 3.0
const POSE_SIZE := 4 + 20 * 3
## Arms flung up and out in a Y beside the head, right knee kicked up, body leaning back: what a
## worker looks like when the metal arrives. Reads as a clear silhouette on the statue's plinth.
## Made by tools/panic_pose.gd.
const PANIC_POSE: Array[float] = [
	3.0, 0.00000, 0.00000, 0.00000,
	-0.07057, 0.00258, 0.00234,
	-0.02666, -0.00000, -0.00000,
	-0.02666, -0.00000, 0.00000,
	-0.02670, 0.00330, 0.00326,
	-0.07493, 0.00000, 0.00000,
	0.01670, -0.05409, -0.04751,
	-0.50775, -0.47042, -0.49645,
	0.48315, 0.15464, -0.13946,
	0.09950, 0.13189, -0.00874,
	-0.04954, -0.06451, -0.06707,
	-0.50770, 0.47047, 0.48459,
	0.48801, -0.15862, 0.13845,
	0.09952, -0.11568, 0.00932,
	0.00352, 0.05922, 0.08818,
	-0.99653, -0.04845, -0.06585,
	0.09944, -0.01737, 0.00960,
	-0.26111, 0.14849, -0.17329,
	0.77325, -0.09008, -0.09337,
	0.82611, -0.01016, -0.03263,
	-0.46752, -0.10486, 0.11318,
]

## Hard hat: tipped back a little (rad, about its rim's middle).
const HAT_TILT := -0.06

const P_LOCO := &"parameters/loco/blend_position"
const P_LOCO_SCALE := &"parameters/loco_speed/scale"
const P_AIR := &"parameters/air/blend_amount"

var _tilt: Node3D
var _body: Node3D
var _skeleton: Skeleton3D
var _tree: AnimationTree
var _rig: WorkerRig
var _dust: WorkerDust
var _hat_mat: StandardMaterial3D
var _frozen := false
var _pending_pose := PackedFloat32Array()
## Skeleton units per metre (the rig is built in centimetres).
var _unit := 100.0
var _walk_pace := WALK_PACE
var _run_pace := RUN_PACE

var _speed := 0.0
var _prev_speed := 0.0
var _accel := 0.0
var _prev_yaw := 0.0
var _lean := Vector2.ZERO
var _air_time := 0.0
var _fall_speed := 0.0
var _air_w := 0.0
var _carry_w := 0.0
var _reach_w := 0.0
var _reach_vel := 0.0
var _was_holding := false
var _carry_step := 0.0
var _low_bend := 0.0
var _low_dip := 0.0
## The back as the figure stands at rest (model space, m; x = 0): the hips' joint, the joints of
## the back's three bones from the lowest up, then the middle between the shoulders; and how far
## a shoulder is from that middle.
var _back: Array[Vector3] = []
var _shoulder_out := 0.2
var _bend := 0.0
var _work_w := 0.0
var _work_phase := 0.0
var _dip := 0.0
var _dip_goal := 0.0
var _dip_hold := 0.0
var _action := &""
var _action_t := 0.0
var _act := {}
var _look := Vector2.ZERO
var _glance := Vector2.ZERO
var _glance_timer := 2.0
var _idle_time := 0.0
var _step_phase := 0.0
var _rng := RandomNumberGenerator.new()


## The body that wears `color`, and what it looks like (a LOOKS entry).
static func body_of(color: Color) -> String:
	return BODIES.get(color.to_html(false), DEFAULT_BODY)


static func look_of(color: Color) -> Dictionary:
	return LOOKS[body_of(color)]


## How tall the worker of that colour stands, hard hat and all (m).
static func height_of(color: Color) -> float:
	var look := look_of(color)
	return ((look.hat_at as Vector3).y + (look.hat_size as Vector3).y) * 0.01


func _ready() -> void:
	_rng.seed = get_instance_id()
	_tilt = Node3D.new()
	_tilt.name = &"Tilt"
	add_child(_tilt)
	_body = (load(BODY_DIR + body_of(suit_color) + ".glb") as PackedScene).instantiate() as Node3D
	_tilt.add_child(_body)
	_skeleton = _body.find_child("Skeleton3D", true, false) as Skeleton3D
	var in_model := global_transform.affine_inverse() * _skeleton.global_transform
	_unit = 1.0 / maxf(in_model.basis.get_scale().y, 0.0001)
	for bone: StringName in [&"Hips", &"Spine02", &"Spine01", &"Spine", &"LeftArm"]:
		var joint := (in_model * _skeleton.get_bone_global_rest(_skeleton.find_bone(bone))).origin
		_shoulder_out = absf(joint.x)
		_back.append(joint * Vector3(0.0, 1.0, 1.0))
	# A taller figure covers more ground with the same step pair.
	var size := clampf(_back[0].y / HIPS_REF, 0.8, 1.2)
	_walk_pace = WALK_PACE * size
	_run_pace = RUN_PACE * size
	_dress(in_model)
	_apply_colors()
	if not _pending_pose.is_empty():
		# Posed before entering the tree (statues): no animation, IK or dust needed.
		apply_pose(_pending_pose)
		return
	_build_animation()
	_rig = WorkerRig.new()
	_rig.name = &"WorkerRig"
	_skeleton.add_child(_rig)
	_dust = WorkerDust.new()
	_dust.name = &"Dust"
	add_child(_dust)
	_prev_yaw = global_rotation.y


## A jolt through the body: below 1 the knees give (a landing, a grab), above 1 nothing shows
## (a real body does not stretch).
func squash(amount: float) -> void:
	if amount < 1.0:
		_dip_to((1.0 - clampf(amount, 0.6, 1.0)) * 0.4)


## Plays one of the short ACTIONS.
func play_action(action: StringName) -> void:
	if _frozen or _tree == null or not ACTIONS.has(action):
		return
	_action = action
	_action_t = 0.0


## Snapshot of the current bone rotations, small enough to send over the network (POSE_FORMAT):
## the pose of the clips, without what the rig aims on top of it.
func pose_data() -> PackedFloat32Array:
	if _skeleton == null:
		return panic_pose()
	var out := PackedFloat32Array()
	out.resize(POSE_SIZE)
	out[0] = POSE_FORMAT
	var hips := _skeleton.find_bone(&"Hips")
	var offset := (_skeleton.get_bone_pose_position(hips) - _skeleton.get_bone_rest(hips).origin) / _unit
	out[1] = offset.x
	out[2] = offset.y
	out[3] = offset.z
	for i in POSE_BONES.size():
		var q := _skeleton.get_bone_pose_rotation(_skeleton.find_bone(POSE_BONES[i])).normalized()
		if q.w < 0.0:
			q = -q
		out[4 + i * 3] = q.x
		out[5 + i * 3] = q.y
		out[6 + i * 3] = q.z
	return out


## Freezes the worker in a pose from `pose_data()` (animation and IK stop for good).
## Unknown or older pose formats fall back to the panic pose. Called before the
## model enters the tree, it skips building the animation rig altogether.
func apply_pose(pose: PackedFloat32Array) -> void:
	if not is_node_ready():
		_pending_pose = pose if not pose.is_empty() else panic_pose()
		return
	if pose.size() != POSE_SIZE or pose[0] != POSE_FORMAT:
		pose = panic_pose()
	_freeze()
	_skeleton.reset_bone_poses()
	var hips := _skeleton.find_bone(&"Hips")
	_skeleton.set_bone_pose_position(hips, _skeleton.get_bone_rest(hips).origin + Vector3(pose[1], pose[2], pose[3]) * _unit)
	for i in POSE_BONES.size():
		var x := pose[4 + i * 3]
		var y := pose[5 + i * 3]
		var z := pose[6 + i * 3]
		var w := sqrt(maxf(0.0, 1.0 - x * x - y * y - z * z))
		_skeleton.set_bone_pose_rotation(_skeleton.find_bone(POSE_BONES[i]), Quaternion(x, y, z, w).normalized())


## "Oh no" pose for someone caught in a pour: arms flung up, one knee kicked up.
static func panic_pose() -> PackedFloat32Array:
	return PackedFloat32Array(PANIC_POSE)


func animate(delta: float, velocity: Vector3, on_floor: bool, holding: bool, hand_target: Vector3) -> void:
	if _frozen or _tree == null or delta <= 0.0:
		return
	var planar := Vector2(velocity.x, velocity.z).length()
	_update_air(delta, velocity, on_floor)
	_update_locomotion(delta, planar)
	_act = _action_pose(delta)
	_update_hands(delta, holding, hand_target)
	_update_body(delta, planar)
	_update_look(delta, holding, hand_target)
	_update_steps(on_floor)


# --- Animation state ----------------------------------------------------------

func _update_air(delta: float, velocity: Vector3, on_floor: bool) -> void:
	if on_floor:
		if _air_time > 0.18:
			_on_land(_fall_speed)
		_air_time = 0.0
		_fall_speed = 0.0
	else:
		_air_time += delta
		_fall_speed = maxf(_fall_speed, -velocity.y)
	# Short drops (stairs, kerbs) keep the legs running; real jumps and falls take the flight pose.
	var airborne := not on_floor and (_air_time > 0.12 or velocity.y > 1.0)
	_air_w = _approach(_air_w, 1.0 if airborne else 0.0, 14.0 if airborne else 20.0, delta)
	_tree.set(P_AIR, _air_w)


func _on_land(impact: float) -> void:
	var hard := clampf((impact - 2.0) / 6.0, 0.0, 1.0)
	# The knees take the landing: deeper on the spot than on the run.
	_dip_to(lerpf(0.07, 0.2, hard) if _speed < 1.0 else lerpf(0.04, 0.11, hard))
	_dust.land(global_position, 0.4 + hard)
	if impact > 3.0:
		Sfx.play(&"drop_thud", global_position, lerpf(-16.0, -8.0, hard), 0.15)


## The hips sink by `depth` metres for a moment, then come back up.
func _dip_to(depth: float) -> void:
	_dip_goal = maxf(_dip_goal, depth)
	_dip_hold = 0.07


func _update_locomotion(delta: float, planar: float) -> void:
	# Settle the blend over ~0.1 s; the 0→4 m/s burst is 0.07 s, too fast to read.
	_speed = _approach(_speed, planar, 12.0, delta)
	_tree.set(P_LOCO, minf(_speed, _run_pace))
	# Above the running step pair's own speed the cycle plays faster instead of sliding.
	var rate := 1.0 if _speed <= _run_pace else _speed / _run_pace
	_tree.set(P_LOCO_SCALE, clampf(rate, 1.0, 2.2))
	if _speed < 0.15 and _air_w < 0.1:
		_idle_time += delta
	else:
		_idle_time = 0.0


## What the running short action asks for right now (empty when none runs): `bend` (rad,
## forwards), `dip` (m), `foot` (the right foot's way, model space, m), and for the hands
## `left` / `right` (model space, m) with their weights `wl` / `wr`.
func _action_pose(delta: float) -> Dictionary:
	if _action.is_empty():
		return {}
	_action_t += delta
	var k := _action_t / float(ACTIONS[_action])
	if k >= 1.0:
		_action = &""
		return {}
	# There and back again, and the same with a quick start.
	var arc := sin(PI * k)
	var snap := sin(PI * pow(k, 0.6))
	match _action:
		&"pickup":
			# Down to it with both hands (a load that is grabbed takes the hands at once).
			return {bend = 0.38 * arc, dip = 0.1 * arc, left = Vector3(0.15, 0.78, 0.5), right = Vector3(-0.15, 0.78, 0.5), wl = arc, wr = arc}
		&"interact":
			return {bend = 0.14 * arc, right = Vector3(-0.13, 1.08, 0.56), wr = snap}
		&"use":
			return {bend = 0.16 * arc, left = Vector3(0.15, 1.02, 0.5), right = Vector3(-0.15, 1.02, 0.5), wl = snap, wr = snap}
		&"throw":
			# Back a little, then both hands shove forwards and up.
			var push := smoothstep(0.15, 0.5, k) * (1.0 - smoothstep(0.7, 1.0, k))
			return {bend = -0.14 * sin(PI * minf(k / 0.3, 1.0)) + 0.3 * push, left = Vector3(0.17, 1.28, 0.74), right = Vector3(-0.17, 1.28, 0.74), wl = push, wr = push}
		&"hammer":
			# The hands follow the handle; the back swings out and comes down with the blow.
			var back := sin(PI * minf(k / 0.42, 1.0))
			var blow := smoothstep(0.38, 0.52, k) * (1.0 - smoothstep(0.6, 1.0, k))
			return {bend = -0.2 * back + 0.42 * blow, dip = 0.07 * blow}
		&"ram":
			var down := Vector3(0.1, lerpf(1.18, 0.78, snap), 0.44)
			return {bend = 0.3 * snap, dip = 0.08 * snap, left = down, right = Vector3(-down.x, down.y, down.z), wl = minf(arc * 3.0, 1.0), wr = minf(arc * 3.0, 1.0)}
		&"kick":
			return {bend = -0.1 * arc, foot = Vector3(0.0, 0.1, 0.36) * snap}
		&"cheer":
			var up := smoothstep(0.0, 0.2, k) * (1.0 - smoothstep(0.75, 1.0, k))
			return {bend = -0.08 * up, dip = 0.04 * up * absf(sin(TAU * 2.0 * k)), left = Vector3(0.3, 2.02, 0.1), right = Vector3(-0.3, 2.02, 0.1), wl = up, wr = up}
		&"hit":
			return {bend = -0.3 * arc, dip = 0.05 * arc}
	return {}


func _update_hands(delta: float, holding: bool, hand_target: Vector3) -> void:
	if holding and not _was_holding:
		# Grab: hands snap out to the load with a little overshoot, the knees give.
		_reach_vel = 9.0
		_dip_to(0.035)
	_was_holding = holding
	_carry_w = _approach(_carry_w, 1.0 if holding else 0.0, 9.0, delta)
	# Underdamped spring so the arms land on the handles instead of easing in flat.
	var goal := 1.0 if holding else 0.0
	_reach_vel += ((goal - _reach_w) * 260.0 - _reach_vel * 22.0) * delta
	_reach_w = clampf(_reach_w + _reach_vel * delta, 0.0, 1.15)
	var carry := minf(_reach_w, 1.0)
	_work_w = _approach(_work_w, 1.0 if working and not holding else 0.0, 7.0, delta)
	var left := Vector3.ZERO
	var right := Vector3.ZERO
	var wl := 0.0
	var wr := 0.0
	var step := 0.0
	var low_bend := 0.0
	var low_dip := 0.0
	if carry > 0.001:
		var handles := _grip_targets()
		if handles.is_empty():
			# Wrists sit a little below and a hand's width behind the grip point.
			var center := global_transform.affine_inverse() * hand_target
			left = center + Vector3(HAND_SPREAD, -0.05, -0.07)
			right = center + Vector3(-HAND_SPREAD, -0.05, -0.07)
		else:
			left = handles[0]
			right = handles[1]
		# The body comes to the load (see CARRY_BEND). What the wrists lack below: the back
		# bends for it, the knees give for the rest ...
		var wrist_y := (left.y + right.y) * 0.5
		var lack := maxf(_back[4].y - wrist_y - REACH_DOWN, 0.0)
		low_bend = minf(lack * LOW_BEND, LOW_BEND_MAX)
		var bend := CARRY_BEND + low_bend
		low_dip = clampf(_shoulders_at(bend, 0.0).y - wrist_y - REACH_DOWN, 0.0, LOW_DIP_MAX)
		# ... and the step that brings the wrists within easy reach of where the shoulders are
		# then (hands wider apart than the shoulders reach less far ahead).
		var shoulders := _shoulders_at(bend, low_dip)
		var drop := shoulders.y - wrist_y
		var out := maxf(absf(left.x - right.x) * 0.5 - _shoulder_out, 0.0)
		var ahead := minf(WRIST_AHEAD, sqrt(maxf(ARM_REACH * ARM_REACH - drop * drop - out * out, 0.01)))
		step = clampf((left.z + right.z) * 0.5 - ahead - shoulders.z, 0.0, CARRY_STEP_MAX)
		wl = carry
		wr = carry
	var settle := 1.0 - exp(-10.0 * delta)
	_carry_step = lerpf(_carry_step, step, settle)
	_low_bend = lerpf(_low_bend, low_bend * carry, settle)
	_low_dip = lerpf(_low_dip, low_dip * carry, settle)
	if _work_w > 0.01:
		# One hand reaches forwards and down into it while the other pulls back up.
		_work_phase = fmod(_work_phase + delta * TAU * WORK_RATE, TAU)
		var middle := _shoulders_at(WORK_BEND, WORK_DIP) + Vector3(0.0, WORK_AT.y, WORK_AT.z + WORK_STEP)
		for side: float in [1.0, -1.0]:
			var a := _work_phase + (0.0 if side > 0.0 else PI)
			var at := middle + Vector3(side * WORK_AT.x, WORK_ROUND.x * cos(a), WORK_ROUND.y * sin(a))
			# (A hand with no target yet goes straight for this one.)
			if side > 0.0:
				left = left.lerp(at, _work_w / maxf(maxf(wl, _work_w), 0.001))
				wl = maxf(wl, _work_w)
			else:
				right = right.lerp(at, _work_w / maxf(maxf(wr, _work_w), 0.001))
				wr = maxf(wr, _work_w)
	# A short action takes the free hands; hands on a load stay there.
	var free := 1.0 - carry
	if _act.has("left"):
		var w: float = float(_act.wl) * free
		left = left.lerp(_act.left, w / maxf(maxf(wl, w), 0.001))
		wl = maxf(wl, w)
	if _act.has("right"):
		var w: float = float(_act.wr) * free
		right = right.lerp(_act.right, w / maxf(maxf(wr, w), 0.001))
		wr = maxf(wr, w)
	var to_skel := _skeleton.global_transform.affine_inverse() * global_transform
	_rig.left_target = to_skel * left
	_rig.right_target = to_skel * right
	_rig.reach_left = wl
	_rig.reach_right = wr


## Where the middle between the shoulders is (model space, m) with the body bent forwards by
## `bend` (rad: HINGE_SHARE of it at the hips, the rest shared by the back's three bones, as
## WorkerRig does) and the hips sunk by `dip` (m).
func _shoulders_at(bend: float, dip: float) -> Vector3:
	var hinge := bend * HINGE_SHARE
	var at := _back[0] + (_back[1] - _back[0]).rotated(Vector3.RIGHT, hinge)
	for i in 3:
		at += (_back[i + 2] - _back[i + 1]).rotated(Vector3.RIGHT, hinge + (bend - hinge) * (i + 1) / 3.0)
	return at + Vector3(0.0, -dip, -dip * SQUAT_BACK)


## Wrist targets in the model's own space (left, right, metres) for a load carried by two
## handles, or empty when there are none or they are not either side of the worker (e.g. a
## second carrier standing at the pot's side).
func _grip_targets() -> Array[Vector3]:
	if grips.size() != 2:
		return []
	var to_model := global_transform.affine_inverse()
	var a := to_model * grips[0]
	var b := to_model * grips[1]
	if grips_on_handle:
		# Fists stacked along one handle (sledgehammer), each nudged to its own
		# side so they do not merge, wrists just behind the shaft.
		return [a + Vector3(0.05, 0.0, -0.06), b + Vector3(-0.05, 0.0, -0.06)]
	var lateral := a.x - b.x
	if absf(lateral) < absf(a.z - b.z):
		return []
	# The wrist sits just behind and below the grip, where the fist closes round it.
	var back := Vector3(0.0, -0.03, -0.1)
	return [(a if lateral > 0.0 else b) + back, (b if lateral > 0.0 else a) + back]


func _update_body(delta: float, planar: float) -> void:
	var accel := (planar - _prev_speed) / delta
	_prev_speed = planar
	_accel = _approach(_accel, accel, 8.0, delta)
	var yaw := global_rotation.y
	var yaw_rate := angle_difference(_prev_yaw, yaw) / delta
	_prev_yaw = yaw
	# Lean into acceleration (≤ 5°) and into turns (≤ 3.5°).
	var pitch := clampf(_accel * 0.004, -0.06, 0.09)
	var roll := clampf(-yaw_rate * planar * 0.008, -0.06, 0.06)
	_lean = _lean.lerp(Vector2(pitch, roll), 1.0 - exp(-10.0 * delta))
	_tilt.rotation = Vector3(_lean.x, 0.0, _lean.y)
	# Carrying: step into the load and bend the back over it.
	_tilt.position = Vector3(0.0, 0.0, _carry_step * _carry_w + WORK_STEP * _work_w)
	# The running step pair leans forward already, so bend less the faster the worker goes.
	var run := clampf((_speed - _walk_pace) / (_run_pace - _walk_pace), 0.0, 1.0)
	var bend := CARRY_BEND * _carry_w * (1.0 - 0.6 * run) + _low_bend + WORK_BEND * _work_w + _lean.x * 0.4 + float(_act.get("bend", 0.0))
	_bend = bend
	_rig.hinge = bend * HINGE_SHARE
	_rig.bend = Vector3(bend * (1.0 - HINGE_SHARE), 0.0, 0.0)
	# The knees: a landing or a grab sinks in fast and comes up slower.
	_dip_hold -= delta
	if _dip_hold <= 0.0:
		_dip_goal = 0.0
	_dip = _approach(_dip, _dip_goal, 26.0 if _dip_goal > _dip else 9.0, delta)
	var dip := (_dip + _low_dip + WORK_DIP * _work_w + float(_act.get("dip", 0.0))) * (1.0 - _air_w)
	var to_skel := _skeleton.global_transform.basis.inverse() * global_transform.basis
	_rig.hips_offset = to_skel * Vector3(0.0, -dip, -dip * SQUAT_BACK)
	var foot: Vector3 = _act.get("foot", Vector3.ZERO)
	_rig.right_foot_offset = to_skel * foot


func _update_look(delta: float, holding: bool, hand_target: Vector3) -> void:
	var goal := Vector2.ZERO
	if holding:
		# A glance down at the load, but the face stays up: the back does the bending
		# (CARRY_BEND) and the head levels most of it out.
		var local := global_transform.affine_inverse() * hand_target
		var eyes := _back[4].y + 0.22
		goal = Vector2(clampf(atan2(eyes - local.y, maxf(local.z, 0.3)) * 0.35, -0.2, 0.15), 0.0)
	elif _idle_time > 1.5:
		# Standing around: glance about every few seconds.
		_glance_timer -= delta
		if _glance_timer <= 0.0:
			_glance_timer = _rng.randf_range(2.0, 4.5)
			_glance = Vector2(_rng.randf_range(-0.1, 0.12), _rng.randf_range(-0.45, 0.45)) if _rng.randf() < 0.7 else Vector2.ZERO
		goal = _glance
	_look = _look.lerp(goal, 1.0 - exp(-5.0 * delta))
	_rig.look = _look - Vector2(HEAD_LEVELING * _bend, 0.0)


## Emits `footstep` when a foot plants, from the locomotion cycle's playback position.
func _update_steps(on_floor: bool) -> void:
	var length: float = _tree.get(&"parameters/loco/current_length")
	if length <= 0.0:
		return
	var phase := fmod(float(_tree.get(&"parameters/loco/current_position")) / length, 1.0)
	if on_floor and _speed > 0.4 and _air_w < 0.3:
		# Both step pairs start as the left heel comes down; the right follows half a pair later.
		for i in 2:
			var contact := 0.03 + 0.5 * i
			var crossed := (_step_phase < contact and phase >= contact) or (phase < _step_phase and (contact > _step_phase or contact <= phase))
			if crossed:
				_on_footstep(i)
	_step_phase = phase


func _on_footstep(foot: int) -> void:
	footstep.emit(foot)
	if _speed > 2.5:
		var toes := _skeleton.find_bone(&"LeftToeBase" if foot == 0 else &"RightToeBase")
		var at := _skeleton.global_transform * _skeleton.get_bone_global_pose(toes).origin
		_dust.step(foot, at, (_speed - 2.5) / 4.0)


static func _approach(from: float, to: float, rate: float, delta: float) -> float:
	return lerpf(from, to, 1.0 - exp(-rate * delta))


# --- Construction ---------------------------------------------------------------

## Puts the hard hat on: the figure brings its own clothes. `in_model` leads from the skeleton's
## space into this node's.
func _dress(in_model: Transform3D) -> void:
	var head := BoneAttachment3D.new()
	head.name = &"HeadGear"
	head.bone_name = "Head"
	_skeleton.add_child(head)
	var look: Dictionary = LOOKS[body_of(suit_color)]
	var hat := Node3D.new()
	hat.name = &"HardHat"
	# The hat is modelled round WorkerGear's shell (rim middle at `rim`, radii SHELL_RADII): that
	# shell brought to this head's size and place, tipped back a little, as the figure stands at
	# rest (metres) ...
	var rim := WorkerGear.SHELL_CENTER - Vector3(0, WorkerGear.HEAD_BONE_Y, 0)
	var size: Vector3 = look.hat_size * 0.01
	var fit := Basis.from_scale(size / WorkerGear.SHELL_RADII)
	var standing := Transform3D(Basis(Vector3.RIGHT, HAT_TILT) * fit, look.hat_at * 0.01) * Transform3D(Basis(), -rim)
	# ... and seen from the head bone, which carries it (the bone leans a little at rest).
	var head_rest := in_model * _skeleton.get_bone_global_rest(_skeleton.find_bone(&"Head"))
	hat.transform = head_rest.affine_inverse() * standing
	head.add_child(hat)
	# Glossy moulded plastic: a small, tight clear-coat highlight sells "hard hat"
	# (a matte shell reads as felt).
	_hat_mat = StandardMaterial3D.new()
	_hat_mat.vertex_color_use_as_albedo = true
	_hat_mat.roughness = 0.5
	_hat_mat.clearcoat_enabled = true
	_hat_mat.clearcoat = 0.55
	_hat_mat.clearcoat_roughness = 0.18
	var stripe := StandardMaterial3D.new()
	stripe.albedo_color = Color("#cdbf9f")
	stripe.roughness = 0.55
	stripe.metallic_specular = 0.2
	var clip := StandardMaterial3D.new()
	clip.albedo_color = Color("#2d2c33")
	clip.roughness = 0.5
	var parts := WorkerGear.hard_hat_parts()
	var mats: Array[Material] = [_hat_mat, stripe, clip]
	for i in parts.size():
		var mi := MeshInstance3D.new()
		mi.name = [&"Shell", &"Stripe", &"Clips"][i]
		mi.mesh = parts[i]
		mi.material_override = mats[i]
		hat.add_child(mi)


func _apply_colors() -> void:
	if _hat_mat:
		_hat_mat.albedo_color = suit_color.lightened(0.06)


func _build_animation() -> void:
	var player := _body.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for clip in LOOPED_CLIPS:
		var anim := player.get_animation(clip)
		if anim and anim.loop_mode != Animation.LOOP_LINEAR:
			anim.loop_mode = Animation.LOOP_LINEAR
	var bt := AnimationNodeBlendTree.new()
	var loco := AnimationNodeBlendSpace1D.new()
	loco.min_space = 0.0
	loco.max_space = _run_pace
	loco.sync_mode = AnimationNodeBlendSpace1D.SYNC_MODE_CYCLIC_MUTABLE
	loco.add_blend_point(_clip(&"Idle_Neutral"), 0.0, -1, &"idle")
	loco.add_blend_point(_clip(&"WalkCycle"), _walk_pace, -1, &"walk")
	loco.add_blend_point(_clip(&"RunCycle"), _run_pace, -1, &"run")
	bt.add_node(&"loco", loco)
	bt.add_node(&"loco_speed", AnimationNodeTimeScale.new())
	bt.connect_node(&"loco_speed", 0, &"loco")
	bt.add_node(&"air_clip", _clip(&"Air"))
	bt.add_node(&"air", AnimationNodeBlend2.new())
	bt.connect_node(&"air", 0, &"loco_speed")
	bt.connect_node(&"air", 1, &"air_clip")
	bt.connect_node(&"output", 0, &"air")
	_tree = AnimationTree.new()
	_tree.name = &"AnimationTree"
	_tree.tree_root = bt
	player.get_parent().add_child(_tree)
	_tree.anim_player = _tree.get_path_to(player)
	_tree.active = true


func _clip(anim_name: StringName) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = anim_name
	return node


func _freeze() -> void:
	_frozen = true
	if _tree:
		_tree.active = false
		_tree.queue_free()
		_tree = null
	var player := _body.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player:
		player.stop()
		player.get_parent().remove_child(player)
		player.queue_free()
	if _rig:
		_rig.active = false
	if _dust:
		_dust.queue_free()
		_dust = null
	_tilt.transform = Transform3D.IDENTITY
