class_name CrucibleArt
extends Node3D
## Look of the carryable crucible: a bellied clay-graphite pot with a rolled
## rim and a pulled pouring spout (towards +z, matching Crucible.lip_position),
## pale glaze drips, a light steel shank band with two hinged handles that hang
## upright while the pot rests and swing out level as trunnions when someone
## carries it, a dial thermometer on the band (Art Bible 12: diegetic
## temperature) and a warm light over hot melt. Lives under the crucible's
## tilt pivot, so it tips with the pour; visual only.

## Outline of the pot (radius, y). The inner wall is part of it, so the
## inside reads as a vessel when it is empty.
const PROFILE := [
	Vector2(0.0, 0.0), Vector2(0.12, 0.0), Vector2(0.145, 0.008), Vector2(0.16, 0.03), Vector2(0.18, 0.12),
	Vector2(0.198, 0.22), Vector2(0.211, 0.32), Vector2(0.218, 0.38), Vector2(0.227, 0.39), Vector2(0.233, 0.405),
	Vector2(0.231, 0.422), Vector2(0.219, 0.431), Vector2(0.2, 0.432), Vector2(0.191, 0.42), Vector2(0.187, 0.33),
	Vector2(0.171, 0.2), Vector2(0.15, 0.1), Vector2(0.12, 0.057), Vector2(0.0, 0.052)]
## Inner wall (y, radius), for sizing the melt disc at a fill height.
const INNER := [Vector2(0.052, 0.11), Vector2(0.1, 0.15), Vector2(0.2, 0.171), Vector2(0.33, 0.187),
	Vector2(0.42, 0.191)]
const BAND_Y := 0.255
const LUG_X := 0.222
const HANDLE_LEN := 0.23
const SPOUT := 0.055

var _shell: ShaderMaterial
var _handles: Array[Node3D] = []
var _grips: Array[Node3D] = []
var _needle: Node3D
var _light: OmniLight3D
var _swing := 0.0
var _swing_vel := 0.0
var _needle_angle := 0.0


func build() -> void:
	if not StationKit.visual():
		return
	_shell = StationKit.unique("station_clay", {body_color = Color("#4a4447"), glaze_color = Color("#8f877c"), glaze = 0.45,
		glaze_top = 0.43, cracks = 0.3, soot = 0.5, soot_from = 0.22, soot_to = 0.0, roughness_base = 0.84,
		glow_from = 0.0, glow_to = 0.16, glow_scale = 0.35, inner_dark = 0.65})
	StationKit.add(self, StationKit.lathe(PackedVector2Array(PROFILE), 30, 48.0, _spout), _shell)
	# Pale steel shank and handles: the frame reads apart from the dark graphite pot.
	var iron := StationKit.metal("shank", {steel_color = Color("#8e969c"), rust = 0.2, dents = 0.3, metallic_steel = 0.6,
		roughness_steel = 0.5, soot = 0.25, soot_bottom = 0.0, soot_top = 0.35})
	var band := PackedVector2Array([Vector2(0.203, BAND_Y - 0.02), Vector2(0.21, BAND_Y - 0.016), Vector2(0.212, BAND_Y + 0.016),
		Vector2(0.206, BAND_Y + 0.02)])
	var pieces := [EnvMesh.piece(StationKit.lathe(band, 30, 60.0), Transform3D(), 0.3)]
	for s: float in [-1.0, 1.0]:
		# Trunnion lug with a bolt.
		pieces.append(EnvMesh.piece(EnvMesh.box(Vector3(0.03, 0.06, 0.05), 0.006, 1), Transform3D(Basis(), Vector3(s * 0.214, BAND_Y, 0))))
		pieces.append(EnvMesh.piece(EnvMesh.cylinder(0.014, 0.014, 0.03, 8), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(s * 0.229, BAND_Y, 0))))
	# Thermometer housing on the back.
	pieces.append(EnvMesh.piece(EnvMesh.box(Vector3(0.03, 0.04, 0.03), 0.005, 1), Transform3D(Basis(), Vector3(0, BAND_Y + 0.01, -0.222))))
	pieces.append(EnvMesh.piece(EnvMesh.cylinder(0.034, 0.034, 0.02, 14), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, BAND_Y + 0.045, -0.24))))
	StationKit.add_merged(self, pieces, iron)
	var grip_wood := StationKit.wood("crucible_grip", {base_color = Color("#6e4630"), grain_color = Color("#3e271a"), weathering = 0.1})
	var bar := StationKit.tube(PackedVector3Array([Vector3(0.0, 0, 0), Vector3(0.1, 0, 0)]), 0.011, 8)
	var grip := StationKit.tube(PackedVector3Array([Vector3(0.09, 0, 0), Vector3(0.105, 0, 0), Vector3(HANDLE_LEN - 0.012, 0, 0), Vector3(HANDLE_LEN, 0, 0)]),
		0.02, 10, true, PackedFloat32Array([0.014, 0.021, 0.021, 0.016]))
	for s: float in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(s * LUG_X, BAND_Y, 0)
		add_child(pivot)
		var arm := Node3D.new()
		arm.rotation.y = 0.0 if s > 0.0 else PI
		pivot.add_child(arm)
		StationKit.add(arm, bar, iron)
		StationKit.add(arm, grip, grip_wood)
		var g := Node3D.new()
		g.position = Vector3(HANDLE_LEN * 0.65, 0, 0)
		arm.add_child(g)
		_grips.append(g)
		_handles.append(pivot)
	var face := StationKit.surface("dial_face", {base_color = Color("#ece4d2"), roughness_base = 0.35, macro = 0.03, grain = 0.02,
		contact_dark = 0.0})
	StationKit.add(self, EnvMesh.cylinder(0.028, 0.028, 0.004, 14), face, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, BAND_Y + 0.045, -0.2505)))
	_needle = Node3D.new()
	_needle.position = Vector3(0, BAND_Y + 0.045, -0.254)
	add_child(_needle)
	var red := StationKit.surface("dial_needle", {base_color = Color("#a3352a"), roughness_base = 0.4, contact_dark = 0.0})
	StationKit.add(_needle, EnvMesh.box(Vector3(0.005, 0.024, 0.002), 0.001, 1), red, Transform3D(Basis(), Vector3(0, 0.01, 0)))
	_light = OmniLight3D.new()
	_light.light_color = Color("#ff8a3a")
	_light.omni_range = 2.2
	_light.omni_attenuation = 1.4
	_light.shadow_enabled = false
	_light.position = Vector3(0, 0.75, 0)
	_light.visible = false
	add_child(_light)


## Pulls the rim (inner and outer) out into a pouring spout around +z.
static func _spout(pos: Vector3, angle: float) -> Vector3:
	var w := smoothstep(0.33, 0.43, pos.y)
	var g := pow(maxf(cos(angle), 0.0), 8.0)
	var k := w * g
	return pos + Vector3(sin(angle), 0.0, cos(angle)) * SPOUT * k + Vector3(0, 0.012 * k, 0)


## Inner radius of the pot at height `y` (for the melt surface).
static func inner_radius(y: float) -> float:
	if y <= INNER[0].x:
		return INNER[0].y
	for i in INNER.size() - 1:
		var a: Vector2 = INNER[i]
		var b: Vector2 = INNER[i + 1]
		if y <= b.x:
			return lerpf(a.y, b.y, (y - a.x) / (b.x - a.x))
	return INNER[-1].y


## Per frame: `temperature` 0..1, `fill` 0..1, `held` swings the handles out.
func update(delta: float, temperature: float, fill: float, held: bool) -> void:
	if _shell == null:
		return
	# The shell glows faintly at the foot when hot, less once carried away.
	_shell.set_shader_parameter(&"heat", clampf((temperature - 0.35) / 0.65, 0.0, 1.0) * (0.3 if held else 0.85))
	# Handles: damped spring between upright (0) and level (1).
	var target := 1.0 if held else 0.0
	_swing_vel += ((target - _swing) * 160.0 - _swing_vel * 14.0) * delta
	_swing += _swing_vel * delta
	var a := (1.0 - clampf(_swing, -0.15, 1.15)) * PI * 0.5
	# Pivots were built for x < 0 first, then x > 0.
	for i in _handles.size():
		_handles[i].rotation.z = -a if i == 0 else a
	var needle_target := lerpf(-2.2, 2.2, clampf(temperature, 0.0, 1.0))
	_needle_angle = lerpf(_needle_angle, needle_target, 1.0 - exp(-delta * 5.0))
	_needle.rotation.z = -_needle_angle
	var hot := clampf((temperature - 0.25) / 0.75, 0.0, 1.0) * (1.0 if fill > 0.02 else 0.0)
	_light.visible = hot > 0.01
	_light.light_energy = 1.3 * hot
	_light.position.y = 0.75


## Global centres of the two grips (for hand IK).
func grip_points() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for g in _grips:
		out.append(g.global_position)
	return out
