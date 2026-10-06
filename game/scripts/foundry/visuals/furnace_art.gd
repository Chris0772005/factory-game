class_name FurnaceArt
extends Node3D
## Look of the backyard bucket furnace, the hero prop of the yard (Art Bible
## 10.4): a scorched, re-used oil drum with rolled hoops, rivets and a weld
## seam; a cracked refractory lining that glows from the hearth up; a
## charcoal bed; a brick skirt; a stovepipe flue with rain cap and smoke; the
## lid leaning against the drum; and a pleated-leather foot bellows feeding
## the tuyere. Purely visual: Furnace keeps its collision ring and gameplay.
## `update()` drives glow, smoke and the bellows from the furnace state.

const DRUM_R := 0.5
const TOP := 0.766
const LINING_IN := 0.405
const HEARTH := 0.12
const STACK_TOP := 2.3
## Flue stack position (local x, z): it leaves the drum at the back (-z).
const STACK_XZ := Vector2(0.0, -0.84)
## Bellows (local to the bellows node): hinge line (x, y), resting open angle,
## top board size and leather width.
const HINGE := Vector2(-0.27, 0.085)
const OPEN_ANGLE := 0.36
const BOARD := Vector3(0.58, 0.03, 0.34)

var _lining: ShaderMaterial
var _coals: ShaderMaterial
var _leather: ShaderMaterial
var _top_board: Node3D
var _smoke: GPUParticles3D
var _glow := 0.0
var _press_t := 10.0
var _last_squash := 0.0


## Builds the furnace look under this node and the bellows under `bellows`.
func build(bellows: Node3D) -> void:
	if not StationKit.visual():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	_drum()
	_lining_and_coals(rng)
	_skirt(rng)
	_flue()
	_lid()
	_tuyere()
	_bellows_art(bellows)


## Called every frame by the furnace with its heat (0..1) and bellows squash
## (1 right after a pump, decaying to 0).
func update(delta: float, heat: float, squash: float) -> void:
	if _lining == null:
		return
	_glow = lerpf(_glow, heat, 1.0 - exp(-delta * 3.0))
	_lining.set_shader_parameter(&"heat", _glow)
	_coals.set_shader_parameter(&"heat", clampf(0.15 + _glow * 1.1, 0.0, 1.0) if _glow > 0.02 else 0.0)
	_smoke.emitting = _glow > 0.08
	_smoke.amount_ratio = clampf(0.25 + _glow, 0.0, 1.0)
	if squash > _last_squash + 0.05:
		_press_t = 0.0
	_last_squash = squash
	_press_t += delta
	var angle := OPEN_ANGLE * _press_curve(_press_t)
	_top_board.rotation.z = angle
	_leather.set_shader_parameter(&"open_angle", angle)


## Bellows board: slammed shut in 70 ms, then springs back with a little
## overshoot (ease-out-back, Art Bible 9.3). 1 = resting open.
static func _press_curve(t: float) -> float:
	if t < 0.07:
		var k := t / 0.07
		return 1.0 - 0.88 * k * k
	var u := clampf((t - 0.07) / 0.42, 0.0, 1.0) - 1.0
	var back := 1.0 + 2.70158 * u * u * u + 1.70158 * u * u
	return 0.12 + 0.88 * back


func _drum() -> void:
	var paint := StationKit.metal("drum", {paint_color = Color("#3e5862"), paint = 0.74, rust = 0.45, soot = 0.9,
		soot_bottom = 0.46, soot_top = 0.8, temper = 0.75, temper_bottom = 0.36, temper_top = 0.66, dents = 0.5,
		roughness_paint = 0.72})
	var prof := PackedVector2Array([
		Vector2(0.47, 0.0), Vector2(0.497, 0.012), Vector2(0.503, 0.03), Vector2(0.494, 0.046),
		Vector2(0.494, 0.22), Vector2(0.507, 0.236), Vector2(0.507, 0.264), Vector2(0.494, 0.28),
		Vector2(0.494, 0.47), Vector2(0.507, 0.486), Vector2(0.507, 0.514), Vector2(0.494, 0.53),
		Vector2(0.494, 0.728), Vector2(0.505, 0.738), Vector2(0.505, 0.756), Vector2(0.49, TOP)])
	var pieces := [EnvMesh.piece(StationKit.lathe(prof, 36, 55.0), Transform3D(), 0.3)]
	var rivet := EnvMesh.sphere(0.011, 6, 3)
	for i in 20:
		var a := TAU * (i + 0.5) / 20.0
		pieces.append(EnvMesh.piece(rivet, Transform3D(Basis(), Vector3(sin(a), 0, cos(a)) * 0.494 + Vector3(0, 0.69, 0)), 0.6))
	var seam_a := deg_to_rad(120.0)
	var sd := Vector3(sin(seam_a), 0, cos(seam_a))
	pieces.append(EnvMesh.piece(EnvMesh.box(Vector3(0.03, 0.17, 0.008), 0.003, 1), Transform3D(Basis(Vector3.UP, seam_a), sd * 0.497 + Vector3(0, 0.375, 0)), 0.2))
	pieces.append(EnvMesh.piece(EnvMesh.box(Vector3(0.03, 0.18, 0.008), 0.003, 1), Transform3D(Basis(Vector3.UP, seam_a), sd * 0.497 + Vector3(0, 0.625, 0)), 0.2))
	pieces.append(EnvMesh.piece(EnvMesh.box(Vector3(0.03, 0.16, 0.008), 0.003, 1), Transform3D(Basis(Vector3.UP, seam_a), sd * 0.497 + Vector3(0, 0.13, 0)), 0.2))
	for k in 8:
		pieces.append(EnvMesh.piece(rivet, Transform3D(Basis(), sd * 0.501 + Vector3(0, 0.08 + k * 0.085, 0)), 0.7))
	StationKit.add_merged(self, pieces, paint)
	# Two drooping lifting bails on the sides.
	var iron := _iron()
	var bails := []
	for s: float in [-1.0, 1.0]:
		var droop := Vector3(s * cos(0.6), -sin(0.6), 0.0)
		var path := StationKit.arc_points(Vector3(s * 0.5, 0.58, 0), Vector3(0, 0, 1), droop, 0.085, 0.0, PI, 10)
		bails.append(EnvMesh.piece(StationKit.tube(path, 0.011, 6), Transform3D()))
		for z: float in [-0.085, 0.085]:
			bails.append(EnvMesh.piece(EnvMesh.box(Vector3(0.02, 0.05, 0.035), 0.005, 1), Transform3D(Basis(), Vector3(s * 0.5, 0.585, z))))
	StationKit.add_merged(self, bails, iron)


func _iron() -> ShaderMaterial:
	return StationKit.metal("iron", {steel_color = Color("#3a3838"), rust = 0.55, dents = 0.2, metallic_steel = 0.55,
		roughness_steel = 0.55})


func _lining_and_coals(rng: RandomNumberGenerator) -> void:
	_lining = StationKit.unique("station_clay", {body_color = Color("#b3a089"), glaze = 0.0, cracks = 0.9, soot = 1.0,
		soot_from = 0.775, soot_to = 0.7, roughness_base = 0.92, glow_from = HEARTH, glow_to = 0.66, glow_radius = 0.43,
		glow_scale = 1.0})
	var prof := PackedVector2Array([
		Vector2(0.488, TOP - 0.004), Vector2(0.472, 0.776), Vector2(0.44, 0.781), Vector2(0.415, 0.775),
		Vector2(LINING_IN, 0.758), Vector2(LINING_IN, 0.6), Vector2(LINING_IN + 0.004, 0.3),
		Vector2(LINING_IN + 0.006, HEARTH + 0.03), Vector2(0.38, HEARTH + 0.004), Vector2(0.0, HEARTH)])
	StationKit.add(self, StationKit.lathe(prof, 36, 50.0), _lining)
	# The furnace mouth is the yard's second-hottest spot after the melt itself.
	_coals = StationKit.unique("station_ember", {glow_scale = 1.6})
	var pieces := []
	for i in 46:
		var r := sqrt(rng.randf()) * 0.37
		var a := rng.randf() * TAU
		var size := rng.randf_range(0.03, 0.055)
		var y := HEARTH + size * 0.45 + rng.randf() * 0.04 + (0.02 if r > 0.24 else 0.0)
		var b := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU))
		pieces.append(EnvMesh.piece(StationKit.chunk(size, i % 7, 0.7, 0.35), Transform3D(b, Vector3(sin(a) * r, y, cos(a) * r)), rng.randf()))
	StationKit.add_merged(self, pieces, _coals, false)


## A ring of loose bricks around the foot of the drum (and a few on top).
func _skirt(rng: RandomNumberGenerator) -> void:
	var brick := StationKit.clay("brick", {body_color = Color("#86594d"), glaze = 0.0, cracks = 0.25, soot = 0.55,
		soot_from = 0.02, soot_to = 0.16, roughness_base = 0.9, noise_scale = 2.0})
	var mesh := EnvMesh.box(Vector3(0.22, 0.065, 0.105), 0.01, 1)
	var pieces := []
	var count := 15
	for i in count:
		var a := TAU * (i + rng.randf_range(-0.12, 0.12)) / count
		var b := Basis(Vector3.UP, a + StationKit.jitter(rng, 5.0)) * Basis(Vector3.FORWARD, StationKit.jitter(rng, 2.0))
		var p := Vector3(sin(a), 0, cos(a)) * (0.567 + rng.randf_range(-0.01, 0.015)) + Vector3(0, 0.029 - rng.randf() * 0.01, 0)
		pieces.append(EnvMesh.piece(mesh, Transform3D(b, p), rng.randf(), Vector3.RIGHT))
	for i in 4:
		var a := PI + (i - 1.5) * 0.36
		var b := Basis(Vector3.UP, a + StationKit.jitter(rng, 6.0))
		pieces.append(EnvMesh.piece(mesh, Transform3D(b, Vector3(sin(a), 0, cos(a)) * 0.575 + Vector3(0, 0.094, 0)), rng.randf(), Vector3.RIGHT))
	# A spare stack behind the flue.
	for i in 3:
		var b := Basis(Vector3.UP, 0.3 + StationKit.jitter(rng, 8.0))
		pieces.append(EnvMesh.piece(mesh, Transform3D(b, Vector3(0.45, 0.033 + i * 0.066, -0.95)), rng.randf(), Vector3.RIGHT))
	StationKit.add_merged(self, pieces, brick)


## Stovepipe flue at the back: collar, elbow, stack with joint bands, a strut
## to the ground and a rain cap, with smoke puffs from the top.
func _flue() -> void:
	var pipe := StationKit.metal("flue", {paint_color = Color("#2c2a2c"), paint = 0.55, steel_color = Color("#4a4846"),
		rust = 0.6, soot = 0.5, soot_bottom = 1.2, soot_top = 2.3, temper = 0.8, temper_bottom = 0.55, temper_top = 1.1,
		dents = 0.25, roughness_paint = 0.75})
	var x := STACK_XZ.x
	var z := STACK_XZ.y
	var bend := 0.12
	var path := PackedVector3Array([Vector3(x, 0.6, -0.44), Vector3(x, 0.6, z + bend)])
	path.append_array(StationKit.arc_points(Vector3(x, 0.6 + bend, z + bend), Vector3.DOWN, Vector3.FORWARD, bend, 0.15, PI * 0.5, 6))
	path.append_array(PackedVector3Array([Vector3(x, 1.3, z), Vector3(x, 1.9, z), Vector3(x, STACK_TOP, z)]))
	var pieces := [EnvMesh.piece(StationKit.tube(path, 0.066, 14), Transform3D(), 0.4)]
	var band := TorusMesh.new()
	band.inner_radius = 0.062
	band.outer_radius = 0.08
	band.rings = 16
	band.ring_segments = 6
	for y: float in [1.15, 1.75, STACK_TOP - 0.02]:
		pieces.append(EnvMesh.piece(band, Transform3D(Basis().scaled(Vector3(1, 0.6, 1)), Vector3(x, y, z)), 0.8))
	var collar := TorusMesh.new()
	collar.inner_radius = 0.062
	collar.outer_radius = 0.095
	collar.rings = 16
	collar.ring_segments = 6
	pieces.append(EnvMesh.piece(collar, Transform3D(Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3(1, 0.5, 1)), Vector3(x, 0.6, -0.495)), 0.9))
	# Damper handle on the stack.
	pieces.append(EnvMesh.piece(EnvMesh.cylinder(0.009, 0.009, 0.2, 6), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(x, 1.0, z)), 0.1))
	pieces.append(EnvMesh.piece(EnvMesh.box(Vector3(0.012, 0.025, 0.07), 0.004, 1), Transform3D(Basis(), Vector3(x + 0.1, 1.0, z - 0.03)), 0.1))
	# Rain cap on three legs.
	pieces.append(EnvMesh.piece(EnvMesh.cylinder(0.0, 0.17, 0.1, 14), Transform3D(Basis(), Vector3(x, STACK_TOP + 0.17, z)), 0.5))
	pieces.append(EnvMesh.piece(EnvMesh.cylinder(0.17, 0.17, 0.012, 14), Transform3D(Basis(), Vector3(x, STACK_TOP + 0.115, z)), 0.5))
	for i in 3:
		var a := TAU * i / 3.0
		var leg := Vector3(sin(a), 0, cos(a)) * 0.07
		pieces.append(EnvMesh.piece(EnvMesh.box(Vector3(0.012, 0.13, 0.025), 0.003, 1), Transform3D(Basis(Vector3.UP, a), Vector3(x, STACK_TOP + 0.06, z) + leg), 0.5))
	StationKit.add_merged(self, pieces, pipe)
	_smoke = _make_smoke()
	_smoke.position = Vector3(x, STACK_TOP + 0.08, z)
	add_child(_smoke)


func _make_smoke() -> GPUParticles3D:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.05
	m.direction = Vector3(0.15, 1.0, 0.05)
	m.spread = 12.0
	m.initial_velocity_min = 0.45
	m.initial_velocity_max = 0.7
	m.gravity = Vector3(0.12, 0.08, 0.04)
	m.damping_min = 0.05
	m.damping_max = 0.1
	m.angle_min = -180.0
	m.angle_max = 180.0
	m.angular_velocity_min = -25.0
	m.angular_velocity_max = 25.0
	m.scale_min = 0.7
	m.scale_max = 1.0
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.25))
	sc.add_point(Vector2(0.4, 0.8))
	sc.add_point(Vector2(1.0, 1.6))
	var sct := CurveTexture.new()
	sct.curve = sc
	m.scale_curve = sct
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.5, 0.46, 0.48, 0.0))
	ramp.set_color(1, Color(0.82, 0.78, 0.76, 0.0))
	ramp.add_point(0.12, Color(0.42, 0.38, 0.4, 0.55))
	ramp.add_point(0.55, Color(0.68, 0.64, 0.64, 0.3))
	var rt := GradientTexture1D.new()
	rt.gradient = ramp
	m.color_ramp = rt
	m.lifetime_randomness = 0.3
	var p := GPUParticles3D.new()
	p.amount = 14
	p.lifetime = 4.0
	p.preprocess = 4.0
	p.process_material = m
	var quad := QuadMesh.new()
	quad.size = Vector2(0.42, 0.42)
	p.draw_pass_1 = quad
	p.material_override = FoundryFX.soft_material()
	p.layers = FoundryFX.FX_LAYER
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-2, -0.5, -2), Vector3(4, 5, 4))
	p.emitting = false
	return p


## The lid leans against the drum on the -x side, its cracked clay underside
## and vent hole facing out.
func _lid() -> void:
	var tilt := deg_to_rad(12.0)
	var n := Vector3(cos(tilt), -sin(tilt), 0)
	var up := Vector3(sin(tilt), cos(tilt), 0)
	var basis := Basis(-up, n, Vector3.BACK)
	var center := Vector3(-0.64, 0.48 * cos(tilt) + 0.004, 0.08)
	var xf := Transform3D(basis, center)
	var steel := PackedVector2Array([
		Vector2(0.45, 0.0), Vector2(0.48, 0.008), Vector2(0.482, 0.055), Vector2(0.47, 0.07),
		Vector2(0.3, 0.076), Vector2(0.09, 0.076), Vector2(0.075, 0.068), Vector2(0.075, 0.0)])
	var lid_paint := StationKit.metal("lid", {paint_color = Color("#3e5862"), paint = 0.6, rust = 0.35, soot = 0.75,
		soot_bottom = -0.02, soot_top = 0.06, dents = 0.5})
	var pieces := [EnvMesh.piece(StationKit.lathe(steel, 32, 50.0), xf, 0.35)]
	var handle := StationKit.arc_points(Vector3(0, 0.076, 0), Vector3(1, 0, 0), Vector3(0, 1, 0), 0.1, 0.0, PI, 10)
	pieces.append(EnvMesh.piece(StationKit.tube(handle, 0.012, 6), xf * Transform3D(Basis(Vector3.UP, 0.4), Vector3.ZERO), 0.1))
	StationKit.add_merged(self, pieces, lid_paint)
	var plug := PackedVector2Array([
		Vector2(0.075, 0.0), Vector2(0.08, -0.035), Vector2(0.1, -0.045), Vector2(0.42, -0.045),
		Vector2(0.44, -0.034), Vector2(0.445, 0.0)])
	var lid_clay := StationKit.clay("lid_lining", {body_color = Color("#b4a088"), glaze = 0.0, cracks = 1.0, soot = 0.7,
		soot_from = 0.0, soot_to = -0.05, roughness_base = 0.93, noise_scale = 1.5})
	StationKit.add(self, StationKit.lathe(plug, 32, 50.0), lid_clay, xf)


## Tuyere pipe from the bellows nozzle into the drum, with a flange and a
## blast gate.
func _tuyere() -> void:
	var path := PackedVector3Array([Vector3(0.86, 0.125, 0), Vector3(0.76, 0.125, 0), Vector3(0.69, 0.14, 0),
		Vector3(0.62, 0.185, 0), Vector3(0.55, 0.195, 0), Vector3(0.47, 0.195, 0)])
	var iron := _iron()
	var pieces := [EnvMesh.piece(StationKit.tube(path, 0.036, 10), Transform3D())]
	var flange := TorusMesh.new()
	flange.inner_radius = 0.034
	flange.outer_radius = 0.06
	flange.rings = 12
	flange.ring_segments = 6
	pieces.append(EnvMesh.piece(flange, Transform3D(Basis(Vector3.FORWARD, PI * 0.5).scaled(Vector3(1, 0.45, 1)), Vector3(0.5, 0.195, 0))))
	for i in 4:
		var a := TAU * (i + 0.5) / 4.0
		pieces.append(EnvMesh.piece(EnvMesh.sphere(0.009, 6, 3), Transform3D(Basis(), Vector3(0.505, 0.195 + sin(a) * 0.048, cos(a) * 0.048))))
	# Blast gate: slotted plate with a lever.
	pieces.append(EnvMesh.piece(EnvMesh.box(Vector3(0.016, 0.1, 0.1), 0.004, 1), Transform3D(Basis(), Vector3(0.79, 0.125, 0))))
	pieces.append(EnvMesh.piece(StationKit.tube(PackedVector3Array([Vector3(0.79, 0.17, 0.0), Vector3(0.79, 0.25, 0.05)]), 0.008, 6), Transform3D()))
	pieces.append(EnvMesh.piece(EnvMesh.sphere(0.016, 8, 4), Transform3D(Basis(), Vector3(0.79, 0.255, 0.053))))
	StationKit.add_merged(self, pieces, iron)


## Foot bellows: base board on battens, hinged top board with a rubber foot
## pad, pleated leather between them, nozzle towards the furnace.
func _bellows_art(bellows: Node3D) -> void:
	var wood := StationKit.wood("bellows", {base_color = Color("#8c5d40"), grain_color = Color("#5c3a28"), weathering = 0.2})
	var base := [
		EnvMesh.piece(EnvMesh.box(Vector3(0.06, 0.04, 0.42), 0.008, 1), Transform3D(Basis(), Vector3(-0.2, 0.02, 0)), 0.2, Vector3.BACK),
		EnvMesh.piece(EnvMesh.box(Vector3(0.06, 0.04, 0.42), 0.008, 1), Transform3D(Basis(), Vector3(0.22, 0.02, 0)), 0.7, Vector3.BACK),
		EnvMesh.piece(EnvMesh.box(Vector3(0.66, 0.045, 0.37), 0.01, 1), Transform3D(Basis(), Vector3(0.02, 0.0625, 0)), 0.4, Vector3.RIGHT),
	]
	StationKit.add_merged(bellows, base, wood)
	var iron := _iron()
	var fittings := [
		EnvMesh.piece(EnvMesh.cylinder(0.024, 0.05, 0.1, 10), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(-0.33, 0.125, 0))),
		EnvMesh.piece(EnvMesh.cylinder(0.011, 0.011, BOARD.z + 0.04, 8), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(HINGE.x, HINGE.y + 0.004, 0))),
	]
	for z: float in [-0.12, 0.12]:
		fittings.append(EnvMesh.piece(EnvMesh.box(Vector3(0.07, 0.006, 0.04), 0.002, 1), Transform3D(Basis(), Vector3(HINGE.x + 0.03, HINGE.y - 0.0, z))))
	StationKit.add_merged(bellows, fittings, iron)
	_leather = StationKit.unique("station_leather", {hinge = HINGE, open_angle = OPEN_ANGLE, pleats = 4.0})
	var bag := StationKit.add(bellows, _leather_mesh(), _leather)
	# Built flat; the shader opens it, so give culling the opened extent.
	bag.custom_aabb = AABB(Vector3(-0.35, 0.0, -0.25), Vector3(0.75, 0.4, 0.5))
	_top_board = Node3D.new()
	_top_board.position = Vector3(HINGE.x, HINGE.y, 0)
	_top_board.rotation.z = OPEN_ANGLE
	bellows.add_child(_top_board)
	var top := [EnvMesh.piece(EnvMesh.box(BOARD, 0.01, 1), Transform3D(Basis(), Vector3(BOARD.x * 0.5 + 0.005, BOARD.y * 0.5, 0)), 0.55, Vector3.RIGHT)]
	StationKit.add_merged(_top_board, top, wood)
	var rubber := StationKit.surface("rubber_pad", {base_color = Color("#2d2a2b"), roughness_base = 0.88, macro = 0.06, grain = 0.1})
	var pad := [EnvMesh.piece(EnvMesh.box(Vector3(0.17, 0.012, 0.27), 0.004, 1), Transform3D(Basis(), Vector3(0.47, BOARD.y + 0.006, 0)))]
	for i in 5:
		pad.append(EnvMesh.piece(EnvMesh.box(Vector3(0.014, 0.01, 0.25), 0.003, 1), Transform3D(Basis(), Vector3(0.405 + i * 0.032, BOARD.y + 0.016, 0))))
	StationKit.add_merged(_top_board, pad, rubber)
	StationKit.label(_top_board, "MM", Transform3D(Basis(Vector3.RIGHT, -PI * 0.5) * Basis(Vector3.FORWARD, PI * 0.5), Vector3(0.2, BOARD.y + 0.001, 0)),
		64, Color(0.22, 0.13, 0.08, 0.75), 700, 0.0012)


## Leather wedge, built closed (flat, rings stacked at the hinge height); the
## leather shader fans ring k open by `open_angle` * k / (rings - 1).
func _leather_mesh() -> ArrayMesh:
	var rings := 9
	var x0 := HINGE.x + 0.012
	var x1 := HINGE.x + BOARD.x - 0.03
	var half := BOARD.z * 0.5 - 0.02
	var outline: Array = []  # [x, z, normal x, normal z]
	for i in 7:
		outline.append([lerpf(x0, x1, i / 6.0), -half, 0.0, -1.0])
	for i in 5:
		var a := -PI * 0.5 + PI * i / 4.0
		outline.append([x1 + cos(a) * 0.02, sin(a) * half, cos(a), sin(a) * 0.4])
	for i in 7:
		outline.append([lerpf(x1, x0, i / 6.0), half, 0.0, 1.0])
	var grid: Array = []
	var perim := float(outline.size() - 1)
	for k in rings:
		var f := float(k) / (rings - 1)
		var push := 0.0
		if k == 0 or k == rings - 1:
			push = -0.008
		elif k % 2 == 1:
			push = 0.026
		else:
			push = -0.004
		var row := []
		for j in outline.size():
			var o: Array = outline[j]
			var nrm := Vector3(o[2], 0.0, o[3]).normalized()
			# Pleats taper to nothing at the hinge.
			var taper := clampf((float(o[0]) - x0) / 0.12, 0.15, 1.0)
			var pos := Vector3(o[0], HINGE.y, o[1]) + nrm * push * taper
			row.append([pos, nrm, Vector2(j / perim, f)])
		grid.append(row)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in rings - 1:
		for j in outline.size() - 1:
			var a: Array = grid[k][j]
			var b: Array = grid[k][j + 1]
			var c: Array = grid[k + 1][j + 1]
			var d: Array = grid[k + 1][j]
			# Rings coincide in the closed pose, so wind by index, not geometry.
			for v in [a, b, c, a, c, d]:
				st.set_normal(v[1])
				st.set_uv(v[2])
				st.add_vertex(v[0])
	return st.commit()
