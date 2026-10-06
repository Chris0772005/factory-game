class_name PlayerModel
extends Node3D
## Rigged foundry worker: the KayKit Adventurers "Barbarian" body (shared 41-bone
## rig, 76 clips) with props and fur hat removed, a player-coloured shirt, leather
## gloves, boots and apron, and a procedural hard hat tipped back on the head
## bone so the face shows. Faces +Z; Player rotates this node.
##
## `animate()` (called at physics rate) drives an AnimationTree:
##   locomotion blend space idle → walk → jog → run, cycle-synced so the feet stay in
##   phase, playback scaled to the ground speed (no foot sliding) → airborne pose →
##   landing layer → carry layer on the arms → one-shot actions (`play_action`).
## WorkerRig then bends the spine, turns the head and puts the hands on the held
## object with two-bone IK. The whole body leans into acceleration and turns, and
## squash & stretch runs on a spring.
## `pose_data()` / `apply_pose()` snapshot and freeze bone rotations (bronze statues).

signal footstep(foot: int)

## Global positions of the two handles of the carried object (e.g. the crucible's
## grips), set by Player at physics rate; empty = hold the load's centre.
var grips: Array[Vector3] = []
## True when `grips` are two hand positions along one handle, [left, right]
## (the sledgehammer) rather than two handles either side of a load.
var grips_on_handle := false

@export var suit_color := Color("#3e7bd6"):
	set(value):
		suit_color = value
		if is_node_ready():
			_apply_colors()

const BODY_SCENE := preload("res://assets/models/kaykit_adventurers/Barbarian.glb")
const OUTFIT_SHADER := preload("res://assets/models/characters/worker_outfit.gdshader")
const HAIR_SHADER := preload("res://assets/models/characters/worker_hair.gdshader")
const APRON_SHADER := preload("res://assets/models/characters/worker_apron.gdshader")
## Base hair colour (the atlas' beard cell); per-player LOOKS tints multiply it.
const HAIR_BASE := Color(0.5, 0.36, 0.26)
## KayKit units → metres: the worker stands ~1.75 m (2.0 m with the hat).
const MODEL_SCALE := 0.8
## Meshes baked into the KayKit file that do not belong on a foundry worker.
const HIDDEN_PARTS: Array[String] = ["Axe", "Shield", "Mug", "Hat", "Cape"]
## Natural ground speed of each locomotion clip at MODEL_SCALE (m/s), measured from
## the planted foot. They double as blend-space positions, so speed maps 1:1.
const WALK_SPEED := 0.59
const JOG_SPEED := 1.82
const RUN_SPEED := 3.58
const LOOPED_CLIPS: Array[StringName] = [&"Idle", &"Walking_A", &"Running_A", &"Running_B", &"Jump_Idle", &"2H_Melee_Idle"]
## Action name → clip for `play_action`.
const ACTIONS := {
	&"pickup": &"PickUp",
	&"interact": &"Interact",
	&"use": &"Use_Item",
	&"throw": &"Throw",
	&"hammer": &"2H_Melee_Attack_Chop",
	&"ram": &"2H_Melee_Attack_Stab",
	&"kick": &"Unarmed_Melee_Attack_Kick",
	&"cheer": &"Cheer",
	&"hit": &"Hit_A",
}
## Per action: Vector2(start offset in the clip (s), playback speed). Gameplay
## happens on the button press, so the clips skip their slow wind-ups and play
## faster to land their key frame within ~0.1–0.2 s: the sledge chop strikes
## with HammerArt's blow (0.21 s), the pickup bottoms out at 0.19 s, the throw
## lets go at 0.13 s, the rammer stab hits the sand at 0.16 s.
const ACTION_TIMING := {
	&"hammer": Vector2(0.6, 1.45),
	&"ram": Vector2(0.25, 1.6),
	&"pickup": Vector2(0.15, 1.8),
	&"throw": Vector2(0.55, 1.6),
}
## Upper-body bones used by the carry layer and moving one-shots.
const UPPER_BONES: Array[String] = ["spine", "chest", "head", "upperarm.l", "lowerarm.l", "wrist.l", "hand.l", "handslot.l",
	"upperarm.r", "lowerarm.r", "wrist.r", "hand.r", "handslot.r"]
const ARM_BONES: Array[String] = ["upperarm.l", "lowerarm.l", "wrist.l", "hand.l", "handslot.l",
	"upperarm.r", "lowerarm.r", "wrist.r", "hand.r", "handslot.r"]
## Distance of each hand from the carry point, sideways (m).
const HAND_SPREAD := 0.21
## Carrying: the body steps this far towards the load (m) and bends over it (rad),
## so the short chibi arms meet things held at Player.HOLD_DISTANCE. The head
## takes back HEAD_LEVELING of the bend, so the face looks ahead, not at the feet.
const CARRY_STEP := 0.24
const CARRY_BEND := 0.28
const HEAD_LEVELING := 0.6
## Loads held by their handles (`grips`): the body steps in so the shoulders end
## up about this far behind the handles (m), up to CARRY_STEP_MAX.
const GRIP_REACH := 0.45
const CARRY_STEP_MAX := 0.3

## Bones captured by `pose_data()`: hips position + 16 rotations (52 floats).
const POSE_BONES: Array[StringName] = [&"hips", &"spine", &"chest", &"head", &"upperarm.l", &"lowerarm.l", &"hand.l",
	&"upperarm.r", &"lowerarm.r", &"hand.r", &"upperleg.l", &"lowerleg.l", &"foot.l", &"upperleg.r", &"lowerleg.r", &"foot.r"]
const POSE_FORMAT := 2.0
const POSE_SIZE := 4 + 16 * 3
## Arms flung up and out in a Y beside the head (the face stays free), right
## knee kicked up, body leaning back: what a worker looks like when the metal
## arrives. Reads as a clear silhouette on the statue's plinth.
const PANIC_POSE: Array[float] = [
	2.0, 0.0, 0.39, -0.03,
	0.0, 0.0, 0.0,
	-0.06, 0.0, 0.0,
	-0.0499, 0.0599, 0.003,
	-0.0417, -0.0587, 0.0275,
	-0.3547, -0.6229, -0.531,
	0.3577, -0.0198, -0.1187,
	0.0823, 0.0, -0.0189,
	-0.4142, 0.5757, 0.4742,
	0.3544, 0.0196, 0.128,
	0.0825, 0.0, 0.021,
	-0.9985, -0.0503, 0.0009,
	-0.0602, -0.0032, 0.0303,
	-0.4552, 0.0, 0.0,
	0.7902, -0.0497, 0.0009,
	0.7061, 0.0027, -0.0253,
	-0.4674, -0.0115, -0.0225,
]

## Multiplier that turns the barbarian's white fur trim (skirt hem, cuffs, boot
## tops) into dark leather, and the glove, boot and apron leathers (Art Bible 4.2).
const TRIM_TINT := Color("#5a4636")
const GLOVE_COLOR := Color("#5a4636")
const BOOT_COLOR := Color("#3a2f2b")
const APRON_COLOR := Color("#5a4636")
## Hard hat tipped back (rad, about its own centre) so the brim clears the brow.
const HAT_TILT := -0.22
## Skin and beard tints (multipliers on the atlas) per default player colour
## (keys are GameWorld.PLAYER_COLORS in hex), so the four workers also differ by
## face, not only by shirt.
const LOOKS := {
	"3e7bd6": [Color(1.0, 1.0, 1.0), Color(0.62, 0.42, 0.3)],
	"26b5c4": [Color(0.9, 0.78, 0.7), Color(1.3, 0.62, 0.32)],
	"9b5bd0": [Color(0.6, 0.47, 0.4), Color(0.32, 0.29, 0.29)],
	"e26aa0": [Color(0.82, 0.68, 0.58), Color(1.4, 1.38, 1.36)],
}

const P_LOCO := &"parameters/loco/blend_position"
const P_LOCO_SCALE := &"parameters/loco_speed/scale"
const P_AIR := &"parameters/air/blend_amount"
const P_LAND := &"parameters/land/blend_amount"
const P_LAND_SEEK := &"parameters/land_seek/seek_request"
const P_CARRY := &"parameters/carry/blend_amount"
const P_ACTION_CLIP := &"parameters/action_clip/transition_request"
const P_ACTION_SEEK := &"parameters/action_seek/seek_request"
const P_ACTION_SPEED := &"parameters/action_speed/scale"
const P_ACTION := &"parameters/action/request"

## Squash spring: 4 Hz, damping ratio 0.45 (overshoots once, then settles).
const SPRING_K := 631.0
const SPRING_D := 22.6

var _tilt: Node3D
var _squash_node: Node3D
var _body: Node3D
var _skeleton: Skeleton3D
var _tree: AnimationTree
var _rig: WorkerRig
var _dust: WorkerDust
var _outfit: ShaderMaterial
var _apron_mat: ShaderMaterial
var _hat_mat: StandardMaterial3D
var _hair_mat: ShaderMaterial
var _action_node: AnimationNodeOneShot
var _frozen := false
var _pending_pose := PackedFloat32Array()

var _speed := 0.0
var _prev_speed := 0.0
var _accel := 0.0
var _prev_yaw := 0.0
var _lean := Vector2.ZERO
var _air_time := 0.0
var _fall_speed := 0.0
var _air_w := 0.0
var _land_w := 0.0
var _land_decay := 5.0
var _carry_w := 0.0
var _reach_w := 0.0
var _reach_vel := 0.0
var _was_holding := false
var _carry_step := CARRY_STEP
var _squash := 1.0
var _squash_vel := 0.0
var _look := Vector2.ZERO
var _glance := Vector2.ZERO
var _glance_timer := 2.0
var _idle_time := 0.0
var _step_phase := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = get_instance_id()
	_tilt = Node3D.new()
	_tilt.name = &"Tilt"
	add_child(_tilt)
	_squash_node = Node3D.new()
	_squash_node.name = &"Squash"
	_tilt.add_child(_squash_node)
	_body = BODY_SCENE.instantiate() as Node3D
	_body.scale = Vector3.ONE * MODEL_SCALE
	_squash_node.add_child(_body)
	_skeleton = _body.get_node(^"Rig/Skeleton3D") as Skeleton3D
	_dress()
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


## Spring kick for squash & stretch: < 1 squashes, > 1 stretches, then springs back.
func squash(amount: float) -> void:
	_squash = clampf(amount, 0.6, 1.5)
	_squash_vel = 0.0


## Plays a one-shot body animation (see ACTIONS), upper body only while moving.
func play_action(action: StringName) -> void:
	if _frozen or _tree == null or not ACTIONS.has(action):
		return
	_action_node.filter_enabled = _speed > 0.5 or _air_w > 0.5
	var timing: Vector2 = ACTION_TIMING.get(action, Vector2(0.0, 1.0))
	_tree.set(P_ACTION_CLIP, String(action))
	_tree.set(P_ACTION_SEEK, timing.x)
	_tree.set(P_ACTION_SPEED, timing.y)
	_tree.set(P_ACTION, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


## Snapshot of the current bone rotations, small enough to send over the network:
## [format, hips position xyz, then x, y, z of each POSE_BONES rotation (w >= 0)].
func pose_data() -> PackedFloat32Array:
	if _skeleton == null:
		return panic_pose()
	var out := PackedFloat32Array()
	out.resize(POSE_SIZE)
	out[0] = POSE_FORMAT
	var hips := _skeleton.get_bone_pose_position(_skeleton.find_bone(&"hips"))
	out[1] = hips.x
	out[2] = hips.y
	out[3] = hips.z
	for i in POSE_BONES.size():
		var q := _skeleton.get_bone_pose_rotation(_skeleton.find_bone(POSE_BONES[i])).normalized()
		if q.w < 0.0:
			q = -q
		out[4 + i * 3] = q.x
		out[5 + i * 3] = q.y
		out[6 + i * 3] = q.z
	return out


## Freezes the worker in a pose from `pose_data()` (animation and IK stop for good).
## Unknown or legacy pose formats fall back to the panic pose. Called before the
## model enters the tree, it skips building the animation rig altogether.
func apply_pose(pose: PackedFloat32Array) -> void:
	if not is_node_ready():
		_pending_pose = pose if not pose.is_empty() else panic_pose()
		return
	if pose.size() != POSE_SIZE or pose[0] != POSE_FORMAT:
		pose = panic_pose()
	_freeze()
	_skeleton.reset_bone_poses()
	if pose.size() != POSE_SIZE:
		return
	var hips := _skeleton.find_bone(&"hips")
	_skeleton.set_bone_pose_position(hips, Vector3(pose[1], pose[2], pose[3]))
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
	_update_carry(delta, holding, hand_target)
	_update_lean(delta, planar)
	_update_squash(delta)
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
		if _air_time == 0.0 and velocity.y > 1.5:
			# Take-off: stretch up (the spring overshoots back through a small squash).
			_squash = 1.13
			_squash_vel = 0.0
		_air_time += delta
		_fall_speed = maxf(_fall_speed, -velocity.y)
	# Short drops (stairs, kerbs) keep the legs running; real jumps and falls tuck them.
	var airborne := not on_floor and (_air_time > 0.12 or velocity.y > 1.0)
	_air_w = _approach(_air_w, 1.0 if airborne else 0.0, 16.0 if airborne else 22.0, delta)
	_land_w = _approach(_land_w, 0.0, _land_decay + _speed * 3.0, delta)
	_tree.set(P_AIR, _air_w)
	_tree.set(P_LAND, _land_w)


func _on_land(impact: float) -> void:
	var hard := clampf((impact - 2.0) / 6.0, 0.0, 1.0)
	_squash = lerpf(0.9, 0.76, hard)
	_squash_vel = 0.0
	# Full crouch when landing on the spot, a light dip when landing on the run.
	_land_w = lerpf(0.55, 1.0, hard) if _speed < 1.0 else lerpf(0.25, 0.5, hard)
	_land_decay = lerpf(5.0, 3.2, hard)
	_tree.set(P_LAND_SEEK, 0.1)
	_dust.land(global_position, 0.4 + hard)
	if impact > 3.0:
		Sfx.play(&"drop_thud", global_position, lerpf(-16.0, -8.0, hard), 0.15)


func _update_locomotion(delta: float, planar: float) -> void:
	# Settle the blend over ~0.1 s; the 0→4 m/s burst is 0.07 s, too fast to read.
	_speed = _approach(_speed, planar, 12.0, delta)
	var blend := minf(_speed, RUN_SPEED)
	_tree.set(P_LOCO, blend)
	# Above the run clip's natural speed the cycle plays faster instead of sliding.
	var rate := 1.0 if _speed <= RUN_SPEED else _speed / RUN_SPEED
	_tree.set(P_LOCO_SCALE, clampf(rate, 1.0, 2.2))
	if _speed < 0.15 and _air_w < 0.1:
		_idle_time += delta
	else:
		_idle_time = 0.0


func _update_carry(delta: float, holding: bool, hand_target: Vector3) -> void:
	if holding and not _was_holding:
		# Grab: hands snap out to the load with a little overshoot, body dips.
		_reach_vel = 9.0
		squash(0.92)
	_was_holding = holding
	_carry_w = _approach(_carry_w, 1.0 if holding else 0.0, 9.0, delta)
	_tree.set(P_CARRY, _carry_w)
	# Underdamped spring so the arms land on the handles instead of easing in flat.
	var goal := 1.0 if holding else 0.0
	_reach_vel += ((goal - _reach_w) * 260.0 - _reach_vel * 22.0) * delta
	_reach_w = clampf(_reach_w + _reach_vel * delta, 0.0, 1.15)
	_rig.reach = minf(_reach_w, 1.0)
	var step := CARRY_STEP
	if _reach_w > 0.001:
		var to_skel := _skeleton.global_transform.affine_inverse()
		var handles := _grip_targets(to_skel)
		if handles.is_empty():
			var center := to_skel * hand_target
			var side := (to_skel.basis * global_transform.basis.x).normalized() * HAND_SPREAD / MODEL_SCALE
			# Wrists sit a hand's width below and behind the grip point.
			var drop := Vector3(0, -0.1, -0.08)
			_rig.left_target = center + side + drop
			_rig.right_target = center - side + drop
		else:
			_rig.left_target = handles[0]
			_rig.right_target = handles[1]
			# Close loads (the crucible at the hips) need less of a step than far ones.
			var ahead := (global_transform.affine_inverse() * ((grips[0] + grips[1]) * 0.5)).z
			step = clampf(ahead - GRIP_REACH, 0.0, CARRY_STEP_MAX)
	_carry_step = lerpf(_carry_step, step, 1.0 - exp(-10.0 * delta))


## Wrist targets in skeleton space (left, right) for a load carried by two
## handles, or empty when there are none or they are not either side of the
## worker (e.g. a second carrier standing at the pot's side).
func _grip_targets(to_skel: Transform3D) -> Array[Vector3]:
	if grips.size() != 2:
		return []
	var a := to_skel * grips[0]
	var b := to_skel * grips[1]
	var side := (to_skel.basis * global_transform.basis.x).normalized()
	var ahead := (to_skel.basis * global_transform.basis.z).normalized()
	if grips_on_handle:
		# Fists stacked along one handle (sledgehammer), each nudged to its own
		# side so they do not merge, wrists just behind the shaft.
		return [a - ahead * 0.06 + side * 0.05, b - ahead * 0.06 - side * 0.05]
	var lateral := (a - b).dot(side)
	if absf(lateral) < absf((a - b).dot(ahead)):
		return []
	# The wrist sits just behind and below the grip, where the fist closes round it.
	var back := -ahead * 0.1 + (to_skel.basis * global_transform.basis.y).normalized() * -0.03
	return [(a if lateral > 0.0 else b) + back, (b if lateral > 0.0 else a) + back]


func _update_lean(delta: float, planar: float) -> void:
	var accel := (planar - _prev_speed) / delta
	_prev_speed = planar
	_accel = _approach(_accel, accel, 8.0, delta)
	var yaw := global_rotation.y
	var yaw_rate := angle_difference(_prev_yaw, yaw) / delta
	_prev_yaw = yaw
	# Lean into acceleration (≤ 8°) and into turns (≤ 6°), from the feet like a toy.
	var pitch := clampf(_accel * 0.006, -0.1, 0.14)
	var roll := clampf(-yaw_rate * planar * 0.012, -0.1, 0.1)
	_lean = _lean.lerp(Vector2(pitch, roll), 1.0 - exp(-10.0 * delta))
	_tilt.rotation = Vector3(_lean.x, 0.0, _lean.y)
	# Carrying: step into the load and bend the back over it.
	_tilt.position = Vector3(0.0, 0.0, _carry_step * _carry_w)
	# The run clips already lean forward, so bend less the faster the worker goes.
	var run := clampf((_speed - JOG_SPEED) / (RUN_SPEED - JOG_SPEED), 0.0, 1.0)
	_rig.bend = Vector3(CARRY_BEND * _carry_w * (1.0 - 0.7 * run) + _lean.x * 0.5, 0.0, 0.0)


func _update_squash(delta: float) -> void:
	var force := -SPRING_K * (_squash - 1.0) - SPRING_D * _squash_vel
	_squash_vel += force * delta
	_squash += _squash_vel * delta
	var s := clampf(_squash, 0.6, 1.5)
	var w := 1.0 / sqrt(s)
	_squash_node.scale = Vector3(w, s, w)


func _update_look(delta: float, holding: bool, hand_target: Vector3) -> void:
	var goal := Vector2.ZERO
	if holding:
		# A glance down at the load, but the face stays up for the camera: the
		# back does the bending (CARRY_BEND) and the head levels most of it out.
		var local := global_transform.affine_inverse() * hand_target
		goal = Vector2(clampf(atan2(1.45 - local.y, maxf(local.z, 0.3)) * 0.35, -0.2, 0.15), 0.0)
	elif _idle_time > 1.5:
		# Standing around: glance about every few seconds.
		_glance_timer -= delta
		if _glance_timer <= 0.0:
			_glance_timer = _rng.randf_range(2.0, 4.5)
			_glance = Vector2(_rng.randf_range(-0.12, 0.15), _rng.randf_range(-0.5, 0.5)) if _rng.randf() < 0.7 else Vector2.ZERO
		goal = _glance
	_look = _look.lerp(goal, 1.0 - exp(-5.0 * delta))
	_rig.look = _look - Vector2(HEAD_LEVELING * _rig.bend.x, 0.0)


## Emits `footstep` when a foot plants, from the locomotion cycle's playback position.
func _update_steps(on_floor: bool) -> void:
	var length: float = _tree.get(&"parameters/loco/current_length")
	if length <= 0.0:
		return
	var phase := fmod(float(_tree.get(&"parameters/loco/current_position")) / length, 1.0)
	if on_floor and _speed > 0.4 and _air_w < 0.3:
		# Toes plant at ~13 % and ~63 % of every locomotion clip of this rig.
		for i in 2:
			var contact := 0.13 + 0.5 * i
			var crossed := (_step_phase < contact and phase >= contact) or (phase < _step_phase and (contact > _step_phase or contact <= phase))
			if crossed:
				_on_footstep(i)
	_step_phase = phase


func _on_footstep(foot: int) -> void:
	footstep.emit(foot)
	if _speed > 2.5:
		var toes := _skeleton.find_bone(&"toes.l" if foot == 0 else &"toes.r")
		var at := _skeleton.global_transform * _skeleton.get_bone_global_pose(toes).origin
		_dust.step(foot, at, (_speed - 2.5) / 4.0)


static func _approach(from: float, to: float, rate: float, delta: float) -> float:
	return lerpf(from, to, 1.0 - exp(-rate * delta))


# --- Construction ---------------------------------------------------------------

## Removes the adventurer props and adds the hard hat and the leather apron.
func _dress() -> void:
	for node in _body.find_children("*", "MeshInstance3D", true, false):
		for part in HIDDEN_PARTS:
			if part in String(node.name):
				node.get_parent().remove_child(node)
				node.free()
				break
	for mi in _body.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if _outfit == null:
			var source := m.mesh.surface_get_material(0) as BaseMaterial3D
			_outfit = ShaderMaterial.new()
			_outfit.shader = OUTFIT_SHADER
			if source:
				_outfit.set_shader_parameter(&"atlas", source.albedo_texture)
		m.material_override = _outfit
	var head := _skeleton.get_node_or_null(^"head") as BoneAttachment3D
	if head == null:
		head = BoneAttachment3D.new()
		head.bone_name = "head"
		_skeleton.add_child(head)
	# Short hair at the back of the head, so the high camera never sees a bald dome.
	var head_mesh := _body.find_child("Barbarian_Head", true, false) as MeshInstance3D
	if head_mesh:
		var hair := MeshInstance3D.new()
		hair.name = &"Hair"
		hair.mesh = WorkerGear.hair_mesh(head_mesh.mesh)
		hair.position.y = -WorkerGear.HEAD_BONE_Y
		_hair_mat = ShaderMaterial.new()
		_hair_mat.shader = HAIR_SHADER
		hair.material_override = _hair_mat
		head.add_child(hair)
	var body_mesh := _body.find_child("Barbarian_Body", true, false) as MeshInstance3D
	if body_mesh:
		var apron := MeshInstance3D.new()
		apron.name = &"Apron"
		apron.mesh = WorkerGear.apron_mesh(body_mesh.mesh)
		apron.skin = body_mesh.skin
		apron.transform = body_mesh.transform
		_apron_mat = ShaderMaterial.new()
		_apron_mat.shader = APRON_SHADER
		apron.material_override = _apron_mat
		body_mesh.get_parent().add_child(apron)
		apron.skeleton = apron.get_path_to(_skeleton)
	var hat := Node3D.new()
	hat.name = &"HardHat"
	# Tipped back into the neck so the face shows from the high game camera.
	var pivot := WorkerGear.SHELL_CENTER - Vector3(0, WorkerGear.HEAD_BONE_Y, 0)
	hat.transform = Transform3D(Basis(Vector3.RIGHT, HAT_TILT), pivot) * Transform3D(Basis(), -pivot)
	head.add_child(hat)
	# Matte plastic: a broad soft sheen that reads as a helmet, but never a
	# highlight that competes with the molten metal (Art Bible 4.2 / rule 2).
	_hat_mat = StandardMaterial3D.new()
	_hat_mat.vertex_color_use_as_albedo = true
	_hat_mat.roughness = 0.6
	_hat_mat.clearcoat_enabled = true
	_hat_mat.clearcoat = 0.1
	_hat_mat.clearcoat_roughness = 0.5
	_hat_mat.rim_enabled = true
	_hat_mat.rim = 0.05
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
	if _outfit == null:
		return
	_outfit.set_shader_parameter(&"suit_color", suit_color)
	var look: Array = LOOKS.get(suit_color.to_html(false), [Color.WHITE, Color(0.62, 0.42, 0.3)])
	_outfit.set_shader_parameter(&"skin_tint", look[0])
	_outfit.set_shader_parameter(&"hair_tint", look[1])
	if _hair_mat:
		var tint: Color = look[1]
		_hair_mat.set_shader_parameter(&"hair_color", Color(HAIR_BASE.r * tint.r, HAIR_BASE.g * tint.g, HAIR_BASE.b * tint.b).clamp())
	# The adventurer's white fur trim becomes leather, the bare fists gloves.
	_outfit.set_shader_parameter(&"trim_tint", TRIM_TINT)
	_outfit.set_shader_parameter(&"glove_color", GLOVE_COLOR)
	_outfit.set_shader_parameter(&"boot_color", BOOT_COLOR)
	if _apron_mat:
		_apron_mat.set_shader_parameter(&"leather_color", APRON_COLOR)
	_hat_mat.albedo_color = suit_color.lightened(0.06)


func _build_animation() -> void:
	var player := _body.get_node(^"AnimationPlayer") as AnimationPlayer
	for clip in LOOPED_CLIPS:
		var anim := player.get_animation(clip)
		if anim and anim.loop_mode != Animation.LOOP_LINEAR:
			anim.loop_mode = Animation.LOOP_LINEAR
	var bt := AnimationNodeBlendTree.new()
	var loco := AnimationNodeBlendSpace1D.new()
	loco.min_space = 0.0
	loco.max_space = RUN_SPEED
	loco.sync_mode = AnimationNodeBlendSpace1D.SYNC_MODE_CYCLIC_MUTABLE
	loco.add_blend_point(_clip(&"Idle"), 0.0, -1, &"idle")
	loco.add_blend_point(_clip(&"Walking_A"), WALK_SPEED, -1, &"walk")
	loco.add_blend_point(_clip(&"Running_B"), JOG_SPEED, -1, &"jog")
	loco.add_blend_point(_clip(&"Running_A"), RUN_SPEED, -1, &"run")
	bt.add_node(&"loco", loco)
	bt.add_node(&"loco_speed", AnimationNodeTimeScale.new())
	bt.connect_node(&"loco_speed", 0, &"loco")
	bt.add_node(&"air_clip", _clip(&"Jump_Idle"))
	bt.add_node(&"air", AnimationNodeBlend2.new())
	bt.connect_node(&"air", 0, &"loco_speed")
	bt.connect_node(&"air", 1, &"air_clip")
	bt.add_node(&"land_clip", _clip(&"Jump_Land"))
	bt.add_node(&"land_seek", AnimationNodeTimeSeek.new())
	bt.connect_node(&"land_seek", 0, &"land_clip")
	bt.add_node(&"land", AnimationNodeBlend2.new())
	bt.connect_node(&"land", 0, &"air")
	bt.connect_node(&"land", 1, &"land_seek")
	var carry := AnimationNodeBlend2.new()
	_filter(carry, ARM_BONES)
	bt.add_node(&"carry_clip", _clip(&"2H_Melee_Idle"))
	bt.add_node(&"carry", carry)
	bt.connect_node(&"carry", 0, &"land")
	bt.connect_node(&"carry", 1, &"carry_clip")
	var actions := AnimationNodeTransition.new()
	actions.xfade_time = 0.0
	actions.input_count = ACTIONS.size()
	var names := ACTIONS.keys()
	for i in names.size():
		actions.set_input_name(i, String(names[i]))
		actions.set_input_reset(i, true)
		bt.add_node(StringName("act_%s" % names[i]), _clip(ACTIONS[names[i]]))
	bt.add_node(&"action_clip", actions)
	for i in names.size():
		bt.connect_node(&"action_clip", i, StringName("act_%s" % names[i]))
	# Start offset and speed per action (ACTION_TIMING), set on every fire.
	bt.add_node(&"action_seek", AnimationNodeTimeSeek.new())
	bt.connect_node(&"action_seek", 0, &"action_clip")
	bt.add_node(&"action_speed", AnimationNodeTimeScale.new())
	bt.connect_node(&"action_speed", 0, &"action_seek")
	_action_node = AnimationNodeOneShot.new()
	_action_node.fadein_time = 0.08
	_action_node.fadeout_time = 0.2
	_filter(_action_node, UPPER_BONES)
	_action_node.filter_enabled = false
	bt.add_node(&"action", _action_node)
	bt.connect_node(&"action", 0, &"carry")
	bt.connect_node(&"action", 1, &"action_speed")
	bt.connect_node(&"output", 0, &"action")
	_tree = AnimationTree.new()
	_tree.name = &"AnimationTree"
	_tree.tree_root = bt
	_body.add_child(_tree)
	_tree.anim_player = _tree.get_path_to(player)
	_tree.active = true


func _clip(anim_name: StringName) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = anim_name
	return node


func _filter(node: AnimationNode, bones: Array[String]) -> void:
	node.filter_enabled = true
	for bone in bones:
		node.set_filter_path(NodePath("Rig/Skeleton3D:%s" % bone), true)


func _freeze() -> void:
	_frozen = true
	if _tree:
		_tree.active = false
		_tree.queue_free()
		_tree = null
	var player := _body.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
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
	_squash_node.scale = Vector3.ONE
