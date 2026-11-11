class_name FirstPersonHands
extends Node3D
## The local worker's two gloved hands in first person, parented to the
## lens. Every finger has three joints, so the hands really open, reach and
## close: grabbing reaches out to the thing and closes around it, letting go
## opens them, working at a station digs hand over hand, a throw shoves
## forward. They sway with the steps, lag a little behind quick turns and
## drop on landings. Pure presentation, local only.

## Poses: [position (right hand, mirrored for the left), euler rotation, curl].
## Rotation x tips the fingers up, y turns them inward, z rolls the palm in.
const REST := [Vector3(0.25, -0.27, -0.44), Vector3(0.3, 0.3, 0.95), 0.45]
const REACH := [Vector3(0.14, -0.2, -0.82), Vector3(0.05, 0.2, 0.55), 0.05]
const CARRY := [Vector3(0.21, -0.2, -0.58), Vector3(0.25, 0.25, 1.25), 0.85]
const PRESS := [Vector3(0.2, -0.2, -0.74), Vector3(0.2, 0.1, 0.3), 0.3]
const DIG_NEAR := [Vector3(0.2, -0.27, -0.46), Vector3(0.1, 0.2, 0.3), 1.15]
const DIG_FAR := [Vector3(0.1, -0.33, -0.82), Vector3(-0.22, 0.12, 0.12), 0.08]
const GRAB_TIME := 0.38
const FINGER_LENGTHS := [0.95, 1.06, 0.98, 0.78]

var player: Player
var _hands: Array[Node3D] = []
## Per hand: 14 joints (4 fingers x 3, thumb x 2).
var _joints: Array = []
var _pose: Array = []
var _curl: Array[float] = [0.45, 0.45]
var _grab := 1.0
var _grabbed := false
var _press := 0.0
var _throw := 0.0
var _work := 0.0
var _phase := 0.0
var _step := 0.0
var _sway := Vector2.ZERO
var _prev_euler := Vector3.ZERO
var _was_using := false
var _was_holding := false


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var leather := StationKit.leather("fp_glove2", {leather_color = Color("#8a5a34"), pleats = 0.0, stitches = 0.0, grain = 0.12})
	var palm_mat := StationKit.leather("fp_palm2", {leather_color = Color("#b98d5c"), pleats = 0.0, stitches = 0.0, grain = 0.12})
	var cuff := StationKit.leather("fp_cuff2", {leather_color = Color("#6f4426"), pleats = 2.0, grain = 0.2})
	var sleeve := StandardMaterial3D.new()
	sleeve.albedo_color = (player.color if player else Color("#3e7bd6")).darkened(0.2)
	sleeve.roughness = 0.9
	sleeve.cull_mode = BaseMaterial3D.CULL_DISABLED
	for side: float in [-1.0, 1.0]:
		var hand := Node3D.new()
		add_child(hand)
		_hands.append(hand)
		_pose.append([Vector3(REST[0].x * side, REST[0].y, REST[0].z), REST[1], REST[2]])
		var geo := Node3D.new()
		geo.scale = Vector3(side, 1, 1)
		hand.add_child(geo)
		# Back of the hand and palm: arched across the knuckles, narrower at the wrist.
		StationKit.add(geo, MachineArt.loft([[-0.1, 0.086, 0.026, 0.0, 0.002, 2.8], [-0.085, 0.09, 0.034, 0.0, 0.003, 3.0], [-0.05, 0.088, 0.038, -0.002, 0.002, 2.8],
			[-0.015, 0.078, 0.04, -0.003, 0.0, 2.6], [0.012, 0.064, 0.042, 0.0, 0.0, 2.4], [0.03, 0.058, 0.044, 0.0, 0.0, 2.2]], 20), leather, Transform3D(), false)
		# Lighter palm patch underneath, knuckle guard and a seam strap on top.
		StationKit.add(geo, MachineArt.loft([[-0.094, 0.078, 0.012, 0.0, -0.012, 3.0], [-0.05, 0.08, 0.016, -0.002, -0.014, 3.0], [-0.005, 0.066, 0.014, -0.003, -0.016, 2.8]], 14), palm_mat, Transform3D(), false)
		StationKit.add(geo, MachineArt.loft([[-0.097, 0.082, 0.012, 0.0, 0.017, 3.4], [-0.08, 0.086, 0.017, 0.0, 0.021, 3.2], [-0.062, 0.08, 0.012, 0.0, 0.02, 3.4]], 14), cuff, Transform3D(), false)
		StationKit.add(geo, MachineArt.loft([[-0.005, 0.07, 0.01, 0.0, 0.021, 3.4], [0.012, 0.066, 0.01, 0.0, 0.022, 3.4]], 12), cuff, Transform3D(), false)
		var joints: Array[Node3D] = []
		for k in 4:
			var scale_k: float = FINGER_LENGTHS[k]
			var parent: Node3D = geo
			var at := Vector3((k - 1.5) * 0.0215, 0.0, -0.096 + absf(k - 1.4) * 0.004)
			var lens := [0.04 * scale_k, 0.027 * scale_k, 0.022 * scale_k]
			var radius := 0.0108 if k < 3 else 0.0095
			for j in 3:
				var joint := Node3D.new()
				joint.position = at
				parent.add_child(joint)
				joints.append(joint)
				StationKit.add(joint, _segment(lens[j], radius * (1.0 - j * 0.07)), leather, Transform3D(), false)
				if j == 2:
					# Stitched finger tip cap.
					StationKit.add(joint, _segment(lens[j] * 0.45, radius * 0.9), palm_mat, Transform3D(Basis(), Vector3(0, -0.0015, -lens[j] * 0.56)), false)
				parent = joint
				at = Vector3(0, 0, -lens[j])
		# Thumb: sits low on the inner edge and points forward and inward.
		var thumb_root := Node3D.new()
		thumb_root.transform = Transform3D(Basis.from_euler(Vector3(-0.25, 0.75, 0.5)), Vector3(-0.036, -0.008, -0.03))
		geo.add_child(thumb_root)
		var t_parent := thumb_root
		var t_at := Vector3.ZERO
		for j in 2:
			var joint := Node3D.new()
			joint.position = t_at
			t_parent.add_child(joint)
			joints.append(joint)
			var l := 0.04 if j == 0 else 0.032
			StationKit.add(joint, _segment(l, 0.0128 - j * 0.0012), leather, Transform3D(), false)
			t_parent = joint
			t_at = Vector3(0, 0, -l)
		_joints.append(joints)
		# Gauntlet cuff with a strap, then the overall sleeve.
		StationKit.add(geo, StationKit.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.034, 0), Vector2(0.037, 0.012), Vector2(0.044, 0.05), Vector2(0.053, 0.085), Vector2(0.057, 0.094),
			Vector2(0.055, 0.101), Vector2(0.047, 0.101), Vector2(0, 0.094)]), 20, 50.0), cuff, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, 0.02)), false)
		StationKit.add(geo, StationKit.lathe(PackedVector2Array([Vector2(0.038, 0.0), Vector2(0.041, 0.002), Vector2(0.042, 0.014), Vector2(0.039, 0.016)]), 20, 30.0), palm_mat,
			Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, 0.04)), false)
		StationKit.add(geo, StationKit.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.04, 0), Vector2(0.045, 0.04), Vector2(0.042, 0.09), Vector2(0.048, 0.15), Vector2(0.047, 0.22),
			Vector2(0.056, 0.34), Vector2(0.062, 0.6), Vector2(0.066, 0.95), Vector2(0, 0.95)]), 18, 50.0), sleeve, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, -0.003, 0.095)), false)
		_set_curl(_hands.size() - 1, 0.45)


## One finger bone along -Z from the joint, rounded at both ends.
static func _segment(length: float, radius: float) -> ArrayMesh:
	var d := radius * 2.0
	return MachineArt.loft([[-length - radius * 0.55, d * 0.45, d * 0.4, 0.0, 0.0, 2.2], [-length - radius * 0.1, d * 0.86, d * 0.8, 0.0, 0.0, 2.4],
		[-length * 0.55, d * 0.97, d * 0.92, 0.0, 0.0, 2.6], [0.0, d, d * 0.96, 0.0, 0.0, 2.6], [radius * 0.7, d * 0.6, d * 0.58, 0.0, 0.0, 2.2]], 12)


## Curls the fingers of hand `i`: 0 flat and open, 1 closed around a handle.
func _set_curl(i: int, curl: float) -> void:
	var joints: Array = _joints[i]
	for k in 4:
		var c := curl * (0.92 + k * 0.06)
		(joints[k * 3] as Node3D).rotation.x = -c * 1.05 - 0.08
		(joints[k * 3 + 1] as Node3D).rotation.x = -c * 1.25 - 0.1
		(joints[k * 3 + 2] as Node3D).rotation.x = -c * 0.75 - 0.06
	(joints[12] as Node3D).rotation = Vector3(-curl * 0.25, -curl * 0.55, 0)
	(joints[13] as Node3D).rotation.x = -curl * 0.7 - 0.1


## Freezes both hands in `pose` (art checks without a worker).
func show_pose(pose: Array, spread := 1.0) -> void:
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var pos: Vector3 = pose[0]
		var rot: Vector3 = pose[1]
		_hands[i].position = Vector3(pos.x * side * spread, pos.y, pos.z)
		_hands[i].rotation = Vector3(rot.x, rot.y * side, rot.z * -side)
		_set_curl(i, pose[2])


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var locked := player.ui_locked
	var using := Input.is_action_pressed(&"interact") and not locked
	if using and not _was_using and not player.holding:
		_press = 1.0
	_was_using = using
	if not locked:
		if Input.is_action_just_pressed(&"grab") and not player.holding:
			_grab = 0.0
			_grabbed = false
		if Input.is_action_just_pressed(&"throw") and player.holding:
			_throw = 1.0
	if player.holding and not _was_holding and _grab >= 1.0:
		# Picked up without a key press of ours (handed over): still close in.
		_grab = 0.45
	_was_holding = player.holding
	_grab = minf(_grab + delta / GRAB_TIME, 1.0)
	_press = move_toward(_press, 0.0, delta * 4.0)
	_throw = move_toward(_throw, 0.0, delta * 3.2)
	var working := using and not player.holding and player.nearest_interactable() != null
	_work = move_toward(_work, 1.0 if working else 0.0, delta * 5.0)
	_phase += delta * 6.4
	# Steps, turn lag and vertical speed move both hands together.
	var planar := Vector2(player.velocity.x, player.velocity.z).length()
	var walk := clampf(planar / Player.WALK_SPEED, 0.0, 1.4) * (1.0 if player.is_on_floor() else 0.0)
	_step += delta * (4.0 + planar * 1.55)
	var e := global_transform.basis.get_euler()
	var turn := Vector2(wrapf(e.y - _prev_euler.y, -PI, PI), e.x - _prev_euler.x) / maxf(delta, 0.0001)
	_prev_euler = e
	_sway = _sway.lerp(Vector2(clampf(turn.x * 0.012, -0.05, 0.05), clampf(turn.y * 0.012, -0.04, 0.04)), 1.0 - exp(-9.0 * delta))
	var drift := Vector3(_sway.x, -_sway.y - clampf(player.velocity.y * 0.012, -0.05, 0.07), 0.0)
	var reach := sin(clampf(_grab / 0.55, 0.0, 1.0) * PI * 0.5) if _grab < 0.55 else 1.0 - smoothstep(0.55, 1.0, _grab)
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var pose: Array = CARRY if player.holding else REST
		var pos: Vector3 = pose[0]
		var rot: Vector3 = pose[1]
		var curl: float = pose[2]
		# Grab: out to the thing with open fingers, then close and bring it in.
		if _grab < 1.0:
			pos = pos.lerp(REACH[0], reach)
			rot = rot.lerp(REACH[1], reach)
			curl = lerpf(curl, REACH[2], reach) if _grab < 0.55 else lerpf(REACH[2], curl, smoothstep(0.5, 0.8, _grab))
		# A tap of F: the right hand presses forward.
		if i == 1 and _press > 0.0 and _work < 0.5:
			var w := sin(_press * PI)
			pos = pos.lerp(PRESS[0], w)
			rot = rot.lerp(PRESS[1], w)
			curl = lerpf(curl, PRESS[2], w)
		if _throw > 0.0:
			var w := sin(_throw * PI)
			pos += Vector3(0, 0.05, -0.3) * w
			curl = lerpf(curl, 0.1, w)
		if _work > 0.0:
			# Hand over hand: reach in open, close, pull back, let go.
			var p := fposmod(_phase / TAU + (0.5 if i == 1 else 0.0), 1.0)
			var out := smoothstep(0.0, 0.38, p) - smoothstep(0.52, 0.92, p)
			var grip := smoothstep(0.34, 0.5, p) - smoothstep(0.9, 1.0, p)
			var d_pos: Vector3 = (DIG_NEAR[0] as Vector3).lerp(DIG_FAR[0], out) + Vector3(0, grip * (1.0 - out) * 0.05, 0)
			var d_rot: Vector3 = (DIG_NEAR[1] as Vector3).lerp(DIG_FAR[1], out)
			pos = pos.lerp(d_pos, _work)
			rot = rot.lerp(d_rot, _work)
			curl = lerpf(curl, lerpf(DIG_FAR[2], DIG_NEAR[2], grip), _work)
		var bob := sin(_step + (PI if i == 1 else 0.0))
		pos += Vector3(0, absf(bob) * -0.012, bob * 0.014) * walk
		var goal := Vector3(pos.x * side, pos.y, pos.z) + drift
		var k := 1.0 - exp(-16.0 * delta)
		var cur: Array = _pose[i]
		cur[0] = (cur[0] as Vector3).lerp(goal, k)
		cur[1] = (cur[1] as Vector3).lerp(Vector3(rot.x, rot.y * side, rot.z * -side), k)
		_curl[i] = lerpf(_curl[i], curl, 1.0 - exp(-22.0 * delta))
		var hand := _hands[i]
		hand.position = cur[0]
		hand.rotation = cur[1]
		_set_curl(i, _curl[i])
