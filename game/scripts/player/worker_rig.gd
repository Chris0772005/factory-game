class_name WorkerRig
extends SkeletonModifier3D
## Procedural layer that runs after the worker's AnimationTree every frame, on the rig of the
## generated figures (24 joints: Hips, Spine02, Spine01, Spine, neck, Head, and per side
## Shoulder, Arm, ForeArm, Hand, UpLeg, Leg, Foot, ToeBase): two-bone IK that puts the hands on
## what the worker carries or works at, a bend of the back and a tilt of the hips, a look of the
## head, and a shift of the hips with the knees bending so the feet stay where they stand. All inputs are in skeleton
## space (the rig's own units: centimetres) and are set by PlayerModel at physics rate. The
## skeleton restores the animated pose after skinning, so nothing here accumulates.

## 0 = animated arm, 1 = wrist on its target; one weight per hand.
var reach_left := 0.0
var reach_right := 0.0
## Wrist targets in skeleton space.
var left_target := Vector3(25.0, 110.0, 50.0)
var right_target := Vector3(-25.0, 110.0, 50.0)
## Direction the elbows bend towards, for the left arm (mirrored for the right).
var elbow_hint := Vector3(0.9, -0.7, -0.35)
## Extra bend of the back in radians: x = forward pitch, y = twist, z = side roll.
var bend := Vector3.ZERO
## Forward tilt of the hips (rad): the whole upper body leans from the hip joints, as a person
## bends down; the legs stay where they are.
var hinge := 0.0
## Head offset in radians: x = nod down, y = turn left.
var look := Vector2.ZERO
## Where the hips go from their place in the clip (skeleton space): down for a dip, back for a
## squat. The knees bend and the feet stay put.
var hips_offset := Vector3.ZERO
## Where the right foot goes beyond its place (skeleton space), for a kick or a stamp.
var right_foot_offset := Vector3.ZERO
## A straight arm may lengthen up to this factor to meet a far target (1 = never).
var max_stretch := 1.04

const SPINE: Array[StringName] = [&"Spine02", &"Spine01", &"Spine"]
const NAMES: Array[StringName] = [&"Hips", &"Spine02", &"Spine01", &"Spine", &"neck", &"Head", &"LeftArm", &"LeftForeArm", &"LeftHand",
	&"RightArm", &"RightForeArm", &"RightHand", &"LeftUpLeg", &"LeftLeg", &"LeftFoot", &"RightUpLeg", &"RightLeg", &"RightFoot"]

var _bones := {}


func _process_modification_with_delta(_delta: float) -> void:
	var skel := get_skeleton()
	if skel == null:
		return
	if _bones.is_empty():
		for bone_name in NAMES:
			_bones[bone_name] = skel.find_bone(bone_name)
		if _bones.values().has(-1):
			push_warning("WorkerRig: skeleton is missing worker bones")
			active = false
			return
	if not hips_offset.is_zero_approx() or not right_foot_offset.is_zero_approx() or absf(hinge) > 0.001:
		# The feet's places first, then the hips move and the legs are solved back onto them.
		var left_foot := skel.get_bone_global_pose(_bones[&"LeftFoot"])
		var right_foot := skel.get_bone_global_pose(_bones[&"RightFoot"])
		var hips: int = _bones[&"Hips"]
		skel.set_bone_pose_position(hips, skel.get_bone_pose_position(hips) + hips_offset)
		if absf(hinge) > 0.001:
			skel.set_bone_pose_rotation(hips, Quaternion(Vector3.RIGHT, hinge) * skel.get_bone_pose_rotation(hips))
		_solve_leg(skel, _bones[&"LeftUpLeg"], _bones[&"LeftLeg"], _bones[&"LeftFoot"], left_foot)
		right_foot.origin += right_foot_offset
		_solve_leg(skel, _bones[&"RightUpLeg"], _bones[&"RightLeg"], _bones[&"RightFoot"], right_foot)
	if not bend.is_zero_approx():
		# Split the bend over the three bones of the back so it curves instead of hinging.
		var q := Quaternion.from_euler(bend / 3.0)
		for bone_name in SPINE:
			var b: int = _bones[bone_name]
			skel.set_bone_pose_rotation(b, q * skel.get_bone_pose_rotation(b))
	if reach_left > 0.001:
		_solve_limb(skel, _bones[&"LeftArm"], _bones[&"LeftForeArm"], _bones[&"LeftHand"], left_target, elbow_hint, reach_left, max_stretch)
	if reach_right > 0.001:
		var hint_r := Vector3(-elbow_hint.x, elbow_hint.y, elbow_hint.z)
		_solve_limb(skel, _bones[&"RightArm"], _bones[&"RightForeArm"], _bones[&"RightHand"], right_target, hint_r, reach_right, max_stretch)
	if not look.is_zero_approx():
		# Half on the neck, half on the head.
		var q := Quaternion.from_euler(Vector3(look.x, look.y, 0.0) * 0.5)
		for bone_name in [&"neck", &"Head"]:
			var b: int = _bones[bone_name]
			skel.set_bone_pose_rotation(b, q * skel.get_bone_pose_rotation(b))


## Puts the ankle back on `foot` (its place and turn in skeleton space) after the hips moved:
## the knee bends forwards, the sole keeps the angle it had.
func _solve_leg(skel: Skeleton3D, upper: int, lower: int, foot_bone: int, foot: Transform3D) -> void:
	_solve_limb(skel, upper, lower, foot_bone, foot.origin, Vector3(0.0, 0.0, 1.0), 1.0, 1.0)
	var lower_g := skel.get_bone_global_pose(lower)
	skel.set_bone_pose_rotation(foot_bone, (lower_g.basis.orthonormalized().inverse() * foot.basis.orthonormalized()).get_rotation_quaternion())


## Analytic two-bone IK in skeleton space: rotates the upper bone so the middle joint lands in
## the plane of the hint, then the lower bone so the end joint meets the target. A target out of
## reach straightens the limb and may stretch it along the bone axis (up to `stretch_limit`); the
## end bone is scaled back so the hand keeps its size.
func _solve_limb(skel: Skeleton3D, upper: int, lower: int, end: int, target: Vector3, hint: Vector3, weight: float, stretch_limit: float) -> void:
	var parent_g := skel.get_bone_global_pose(skel.get_bone_parent(upper))
	var upper_l := skel.get_bone_pose(upper)
	var lower_l := skel.get_bone_pose(lower)
	var end_l := skel.get_bone_pose(end)
	var upper_g := parent_g * upper_l
	var lower_g := upper_g * lower_l
	var s := upper_g.origin
	var e := lower_g.origin
	var w := (lower_g * end_l).origin
	var a := s.distance_to(e)
	var b := e.distance_to(w)
	var to_target := target - s
	var dist := to_target.length()
	if dist < 0.001 or a < 0.001 or b < 0.001:
		return
	var dir := to_target / dist
	var full := (a + b) * 0.995
	var stretch := clampf(dist / full, 1.0, maxf(stretch_limit, 1.0))
	# Solve on the unstretched limb; the stretch then lengthens the (straight) chain.
	dist = clampf(dist / stretch, absf(a - b) + 0.01, full)
	var side := hint - dir * hint.dot(dir)
	if side.length_squared() < 0.0001:
		side = Vector3.DOWN - dir * Vector3.DOWN.dot(dir)
	side = side.normalized()
	var along := (a * a - b * b + dist * dist) / (2.0 * dist)
	var up := sqrt(maxf(a * a - along * along, 0.0))
	var middle := s + dir * along + side * up
	var goal := s + dir * dist
	var swing_upper := Quaternion((e - s).normalized(), (middle - s).normalized())
	var upper_g2 := Transform3D(Basis(swing_upper) * upper_g.basis, s)
	var lower_g2 := upper_g2 * lower_l
	var w2 := (lower_g2 * end_l).origin
	var swing_lower := Quaternion((w2 - lower_g2.origin).normalized(), (goal - lower_g2.origin).normalized())
	lower_g2.basis = Basis(swing_lower) * lower_g2.basis
	var upper_q := (parent_g.basis.orthonormalized().inverse() * upper_g2.basis.orthonormalized()).get_rotation_quaternion()
	var lower_q := (upper_g2.basis.orthonormalized().inverse() * lower_g2.basis.orthonormalized()).get_rotation_quaternion()
	var k := clampf(weight, 0.0, 1.0)
	skel.set_bone_pose_rotation(upper, upper_l.basis.get_rotation_quaternion().slerp(upper_q, k))
	skel.set_bone_pose_rotation(lower, lower_l.basis.get_rotation_quaternion().slerp(lower_q, k))
	if stretch_limit > 1.0:
		var length := lerpf(1.0, stretch, k)
		skel.set_bone_pose_scale(upper, Vector3(1.0, length, 1.0))
		skel.set_bone_pose_scale(end, Vector3(1.0, 1.0 / length, 1.0))
