class_name HammerArt
extends Node3D
## Look of the sledgehammer: a hickory handle that swells towards the head
## and ends in a knob, a leather-wrapped grip, an octagonal forged head with
## polished striking faces and the handle wedge showing through the eye.
## Stands on the handle end, head up (its collider is an upright box).
## `swing()` plays wind-up -> strike -> follow-through (Art Bible 9.3:
## 0.15 s up, 0.06 s down, 0.25 s rebound) on the pivot at the handle end.

const HEAD_Y := 0.755
const HEAD_LEN := 0.2
const HEAD_R := 0.046

var _t := 10.0


func build() -> void:
	if not StationKit.visual():
		return
	var hickory := StationKit.wood("hammer_handle", {base_color = Color("#b98a5c"), grain_color = Color("#80593a"), weathering = 0.05,
		grain_strength = 0.7})
	var ys := [0.0, 0.012, 0.03, 0.12, 0.4, 0.62, HEAD_Y - 0.03, HEAD_Y + HEAD_R + 0.004]
	var rs := [0.018, 0.026, 0.024, 0.019, 0.017, 0.019, 0.022, 0.021]
	var path := PackedVector3Array()
	var radii := PackedFloat32Array()
	for i in ys.size():
		path.append(Vector3(0, ys[i], 0))
		radii.append(rs[i])
	# Oval section: wider front to back.
	StationKit.add(self, StationKit.tube(path, 0.02, 10, true, radii), hickory, Transform3D(Basis().scaled(Vector3(1.0, 1.0, 1.22)), Vector3.ZERO))
	var grip := StationKit.leather("hammer_grip", {leather_color = Color("#3e2a20"), stitches = 0.0, pleats = 9.0})
	var wrap := PackedVector3Array()
	var wrap_r := PackedFloat32Array()
	for i in 9:
		var y := 0.035 + i * 0.022
		wrap.append(Vector3(0, y, 0))
		wrap_r.append(0.0235 - i * 0.0004 + (0.0012 if i % 2 == 0 else 0.0))
	StationKit.add(self, StationKit.tube(wrap, 0.023, 10, true, wrap_r), grip, Transform3D(Basis().scaled(Vector3(1.0, 1.0, 1.2)), Vector3.ZERO))
	var steel := StationKit.metal("sledge", {steel_color = Color("#30343a"), rust = 0.25, dents = 0.6, metallic_steel = 0.75,
		roughness_steel = 0.4, polish_x = HEAD_LEN * 0.5 - 0.006})
	var along := Basis(Vector3.BACK, PI * 0.5)
	var parts := [
		EnvMesh.piece(EnvMesh.cylinder(HEAD_R, HEAD_R, HEAD_LEN - 0.03, 8), Transform3D(along, Vector3(0, HEAD_Y, 0))),
	]
	for s: float in [-1.0, 1.0]:
		parts.append(EnvMesh.piece(EnvMesh.cylinder(HEAD_R - 0.006, HEAD_R, 0.012, 8), Transform3D(along if s < 0.0 else along * Basis(Vector3.RIGHT, PI), Vector3(s * (HEAD_LEN * 0.5 - 0.021), HEAD_Y, 0))))
		parts.append(EnvMesh.piece(EnvMesh.cylinder(HEAD_R - 0.01, HEAD_R - 0.006, 0.009, 8), Transform3D(along if s < 0.0 else along * Basis(Vector3.RIGHT, PI), Vector3(s * (HEAD_LEN * 0.5 - 0.0045), HEAD_Y, 0))))
	# Steel wedge across the handle end on top of the head.
	parts.append(EnvMesh.piece(EnvMesh.box(Vector3(0.006, 0.006, 0.034), 0.001, 1), Transform3D(Basis(), Vector3(0, HEAD_Y + HEAD_R + 0.005, 0))))
	StationKit.add_merged(self, parts, steel)


func swing() -> void:
	_t = 0.0


## Physics step, not frame: the hammer is a carried physics body, so its art is
## interpolated between ticks; posing it per frame would stutter above 60 Hz.
func _physics_process(delta: float) -> void:
	if _t > 1.0:
		return
	_t += delta
	rotation.x = _swing_angle(_t)


## Pitch of the hammer (radians) `t` seconds into a swing.
static func _swing_angle(t: float) -> float:
	if t < 0.15:
		var k := t / 0.15
		return -0.55 * (1.0 - (1.0 - k) * (1.0 - k))
	if t < 0.21:
		var k := (t - 0.15) / 0.06
		return lerpf(-0.55, 1.45, k * k)
	if t < 0.46:
		var k := (t - 0.21) / 0.25
		return 1.45 * (1.0 - k) * (1.0 - k) * (1.0 + 2.0 * k) - 0.12 * sin(k * PI)
	return 0.0
