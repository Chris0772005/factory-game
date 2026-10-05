class_name WorkerRig
extends SkeletonModifier3D
## Procedural layer that runs after the worker's AnimationTree every frame:
## two-bone arm IK that puts the hands on what the worker carries, a spine
## bend and a head look. All inputs are in skeleton space (the rig's own,
## unscaled units) and are set by PlayerModel at physics rate. The skeleton
## restores the animated pose after skinning, so nothing here accumulates.

## 0 = animated arms, 1 = wrists on the targets.
var reach := 0.0
## Wrist targets in skeleton space.
var left_target := Vector3(0.25, 1.2, 1.0)
var right_target := Vector3(-0.25, 1.2, 1.0)
## Direction the elbows bend towards, for the left arm (mirrored for the right).
var elbow_hint := Vector3(0.9, -0.7, -0.35)
## Extra bend of spine + chest in radians: x = forward pitch, y = twist, z = side roll.
var bend := Vector3.ZERO
## Head offset in radians: x = nod down, y = turn left.
var look := Vector2.ZERO
## Cartoon reach: a straight arm may lengthen up to this factor to meet a far target.
var max_stretch := 1.35

var _bones := {}


func _process_modification_with_delta(_delta: float) -> void:
	var skel := get_skeleton()
	if skel == null:
		return
	if _bones.is_empty():
		for bone_name in [&"spine", &"chest", &"head", &"upperarm.l", &"lowerarm.l", &"wrist.l", &"upperarm.r", &"lowerarm.r", &"wrist.r"]:
			_bones[bone_name] = skel.find_bone(bone_name)
		if _bones.values().has(-1):
			push_warning("WorkerRig: skeleton is missing worker bones")
			active = false
			return
	if not bend.is_zero_approx():
		# Split the bend over the two torso bones so the back curves instead of hinging.
		var q := Quaternion.from_euler(bend * 0.5)
		for bone_name in [&"spine", &"chest"]:
			var b: int = _bones[bone_name]
			skel.set_bone_pose_rotation(b, q * skel.get_bone_pose_rotation(b))
	if reach > 0.001:
		_solve_arm(skel, _bones[&"upperarm.l"], _bones[&"lowerarm.l"], _bones[&"wrist.l"], left_target, elbow_hint)
		var hint_r := Vector3(-elbow_hint.x, elbow_hint.y, elbow_hint.z)
		_solve_arm(skel, _bones[&"upperarm.r"], _bones[&"lowerarm.r"], _bones[&"wrist.r"], right_target, hint_r)
	if not look.is_zero_approx():
		var h: int = _bones[&"head"]
		skel.set_bone_pose_rotation(h, Quaternion.from_euler(Vector3(look.x, look.y, 0.0)) * skel.get_bone_pose_rotation(h))


## Analytic two-bone IK in skeleton space: rotates the upper arm so the elbow
## lands in the plane of the hint, then the forearm so the wrist meets the target.
## A target out of reach straightens the arm and stretches it along the bone axis
## (up to `max_stretch`); the wrist is scaled back so the fist keeps its size.
func _solve_arm(skel: Skeleton3D, upper: int, lower: int, wrist: int, target: Vector3, hint: Vector3) -> void:
	var parent_g := skel.get_bone_global_pose(skel.get_bone_parent(upper))
	var upper_l := skel.get_bone_pose(upper)
	var lower_l := skel.get_bone_pose(lower)
	var wrist_l := skel.get_bone_pose(wrist)
	var upper_g := parent_g * upper_l
	var lower_g := upper_g * lower_l
	var s := upper_g.origin
	var e := lower_g.origin
	var w := (lower_g * wrist_l).origin
	var a := s.distance_to(e)
	var b := e.distance_to(w)
	var to_target := target - s
	var dist := to_target.length()
	if dist < 0.001 or a < 0.001 or b < 0.001:
		return
	var dir := to_target / dist
	var full := (a + b) * 0.995
	var stretch := clampf(dist / full, 1.0, maxf(max_stretch, 1.0))
	# Solve on the unstretched arm; the stretch then lengthens the (straight) chain.
	dist = clampf(dist / stretch, absf(a - b) + 0.01, full)
	var side := hint - dir * hint.dot(dir)
	if side.length_squared() < 0.0001:
		side = Vector3.DOWN - dir * Vector3.DOWN.dot(dir)
	side = side.normalized()
	var along := (a * a - b * b + dist * dist) / (2.0 * dist)
	var up := sqrt(maxf(a * a - along * along, 0.0))
	var elbow := s + dir * along + side * up
	var wrist_goal := s + dir * dist
	var swing_upper := Quaternion((e - s).normalized(), (elbow - s).normalized())
	var upper_g2 := Transform3D(Basis(swing_upper) * upper_g.basis, s)
	var lower_g2 := upper_g2 * lower_l
	var w2 := (lower_g2 * wrist_l).origin
	var swing_lower := Quaternion((w2 - lower_g2.origin).normalized(), (wrist_goal - lower_g2.origin).normalized())
	lower_g2.basis = Basis(swing_lower) * lower_g2.basis
	var upper_q := (parent_g.basis.inverse() * upper_g2.basis).get_rotation_quaternion()
	var lower_q := (upper_g2.basis.inverse() * lower_g2.basis).get_rotation_quaternion()
	var weight := clampf(reach, 0.0, 1.0)
	skel.set_bone_pose_rotation(upper, upper_l.basis.get_rotation_quaternion().slerp(upper_q, weight))
	skel.set_bone_pose_rotation(lower, lower_l.basis.get_rotation_quaternion().slerp(lower_q, weight))
	var length := lerpf(1.0, stretch, weight)
	skel.set_bone_pose_scale(upper, Vector3(1.0, length, 1.0))
	skel.set_bone_pose_scale(wrist, Vector3(1.0, 1.0 / length, 1.0))
