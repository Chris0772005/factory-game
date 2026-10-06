class_name HammerArt
extends Node3D
## Look of the sledgehammer: a hickory handle that swells towards the head
## and ends in a knob, a leather-wrapped grip, a chunky octagonal forged head
## with polished striking faces and the handle wedge showing through the eye.
## Stands on the handle end, head up (its collider is an upright box).
## `swing()` plays a two-handed overhead blow in the carrier's frame (Art
## Bible 9.3: 0.15 s heave up, 0.06 s strike, 0.25 s rebound): the hands lift
## the hammer over the shoulder, bring it down onto the mold in front and
## settle back. Visual only; the physics body stays where the carrier holds it.
## `grip_points()` gives the two hand positions on the handle for hand IK.

const HEAD_Y := 0.755
const HEAD_LEN := 0.26
const HEAD_R := 0.062
## Where the hands hold the handle (local, up from the handle end): left hand
## low, right hand higher; the carrier holds the body at Hammer.GRIP between them.
const GRIP_LOW := 0.08
const GRIP_HIGH := 0.23
const SWING_TIME := 0.46
## Swing keys: [time, pitch (rad, + = head forward), hand lift (m), hand reach (m)].
const SWING_KEYS := [
	[0.0, 0.0, 0.0, 0.0],
	[0.15, -1.2, 0.38, -0.2],
	[0.21, 1.7, 0.06, 0.12],
	[0.3, 1.45, 0.03, 0.08],
	[0.46, 0.0, 0.0, 0.0],
]

var _t := 10.0


func build() -> void:
	if not StationKit.visual():
		return
	var hickory := StationKit.wood("hammer_handle", {base_color = Color("#b98a5c"), grain_color = Color("#80593a"), weathering = 0.05,
		grain_strength = 0.7})
	var ys := [0.0, 0.012, 0.03, 0.12, 0.4, 0.62, HEAD_Y - 0.03, HEAD_Y + HEAD_R + 0.004]
	var rs := [0.0225, 0.0325, 0.03, 0.024, 0.021, 0.024, 0.0275, 0.026]
	var path := PackedVector3Array()
	var radii := PackedFloat32Array()
	for i in ys.size():
		path.append(Vector3(0, ys[i], 0))
		radii.append(rs[i])
	# Oval section: wider front to back.
	StationKit.add(self, StationKit.tube(path, 0.025, 10, true, radii), hickory, Transform3D(Basis().scaled(Vector3(1.0, 1.0, 1.22)), Vector3.ZERO))
	var grip := StationKit.leather("hammer_grip", {leather_color = Color("#3e2a20"), stitches = 0.0, pleats = 9.0})
	var wrap := PackedVector3Array()
	var wrap_r := PackedFloat32Array()
	for i in 12:
		var y := 0.035 + i * 0.022
		wrap.append(Vector3(0, y, 0))
		wrap_r.append(0.029 - i * 0.0004 + (0.0014 if i % 2 == 0 else 0.0))
	StationKit.add(self, StationKit.tube(wrap, 0.029, 10, true, wrap_r), grip, Transform3D(Basis().scaled(Vector3(1.0, 1.0, 1.2)), Vector3.ZERO))
	var steel := StationKit.metal("sledge", {steel_color = Color("#30343a"), rust = 0.25, dents = 0.6, metallic_steel = 0.75,
		roughness_steel = 0.4, polish_x = HEAD_LEN * 0.5 - 0.008})
	var along := Basis(Vector3.BACK, PI * 0.5)
	var parts := [
		EnvMesh.piece(EnvMesh.cylinder(HEAD_R, HEAD_R, HEAD_LEN - 0.04, 8), Transform3D(along, Vector3(0, HEAD_Y, 0))),
		# Forged collar round the eye.
		EnvMesh.piece(EnvMesh.cylinder(HEAD_R + 0.008, HEAD_R + 0.008, 0.05, 8), Transform3D(along, Vector3(0, HEAD_Y, 0))),
	]
	for s: float in [-1.0, 1.0]:
		var flip := along if s < 0.0 else along * Basis(Vector3.RIGHT, PI)
		parts.append(EnvMesh.piece(EnvMesh.cylinder(HEAD_R - 0.008, HEAD_R, 0.016, 8), Transform3D(flip, Vector3(s * (HEAD_LEN * 0.5 - 0.028), HEAD_Y, 0))))
		parts.append(EnvMesh.piece(EnvMesh.cylinder(HEAD_R - 0.014, HEAD_R - 0.008, 0.012, 8), Transform3D(flip, Vector3(s * (HEAD_LEN * 0.5 - 0.006), HEAD_Y, 0))))
	# Steel wedge across the handle end on top of the head.
	parts.append(EnvMesh.piece(EnvMesh.box(Vector3(0.008, 0.008, 0.042), 0.001, 1), Transform3D(Basis(), Vector3(0, HEAD_Y + HEAD_R + 0.007, 0))))
	StationKit.add_merged(self, parts, steel)


func swing() -> void:
	_t = 0.0


## Global positions of the two hands on the handle (low = left, high = right).
func grip_points() -> Array[Vector3]:
	return [global_transform * Vector3(0, GRIP_LOW, 0), global_transform * Vector3(0, GRIP_HIGH, 0)]


## Physics step, not frame: the hammer is a carried physics body, so its art is
## interpolated between ticks; posing it per frame would stutter above 60 Hz.
func _physics_process(delta: float) -> void:
	if _t > SWING_TIME:
		return
	_t += delta
	var body := get_parent() as Node3D
	if _t > SWING_TIME or body == null:
		transform = Transform3D.IDENTITY
		return
	# The blow follows whoever carries the hammer (the body's own yaw drifts),
	# and the hands turn the head in line with it on the way up (it is built
	# across local x), so a striking face comes down on the mold.
	var yaw := body.global_rotation.y
	var twist := 0.0
	var carrier := _carrier()
	if carrier:
		var k_in := clampf(_t / 0.12, 0.0, 1.0)
		yaw = lerp_angle(yaw, carrier.global_rotation.y, k_in)
		var settle := clampf((SWING_TIME - _t) / 0.1, 0.0, 1.0)
		twist = -PI * 0.5 * minf(k_in, settle)
	var k := swing_pose(_t)
	var facing := Basis(Vector3.UP, yaw)
	var hands := body.global_transform * Hammer.GRIP + Vector3(0, k.y, 0) + facing * Vector3(0, 0, k.z)
	var b := facing * Basis(Vector3.RIGHT, k.x) * Basis(Vector3.UP, twist)
	global_transform = Transform3D(b, hands - b * Hammer.GRIP)


## Swing pose `t` seconds in: x = pitch, y = hand lift, z = hand reach.
## Heave eases out, the strike eases in (accelerates into the mold).
static func swing_pose(t: float) -> Vector3:
	for i in SWING_KEYS.size() - 1:
		var a: Array = SWING_KEYS[i]
		var b: Array = SWING_KEYS[i + 1]
		if t <= b[0]:
			var k := clampf((t - a[0]) / (b[0] - a[0]), 0.0, 1.0)
			match i:
				0:
					k = 1.0 - (1.0 - k) * (1.0 - k)
				1:
					k = k * k
				_:
					k = k * k * (3.0 - 2.0 * k)
			return Vector3(lerpf(a[1], b[1], k), lerpf(a[2], b[2], k), lerpf(a[3], b[3], k))
	return Vector3.ZERO


func _carrier() -> Node3D:
	for p in get_tree().get_nodes_in_group(&"players"):
		if p.holding and p.held_item() == get_parent():
			return p
	return null
