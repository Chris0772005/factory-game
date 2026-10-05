class_name BenchArt
extends Node3D
## Look of the pattern-maker's workbench (Art Bible 12 "DrawPad: Papierbogen
## auf Werkbank"): a laminated butcher-block top on square legs with aprons,
## stretchers and a slatted shelf, a bench vise, a taped-down sketch sheet
## with a real drawing on it, pencils, ruler, set square and eraser, crumpled
## failed attempts, a finished wooden star pattern, a beer mug and an
## anglepoise lamp whose warm spot light pools on the paper. Visual only:
## ModelBench keeps its top collider (1.4 x 0.08 x 0.8 at y 0.9).

const TOP := 0.94
const SIZE := Vector2(1.4, 0.8)
const PAPER_AT := Vector3(-0.12, TOP + 0.002, 0.03)
const PAPER_YAW := -0.1
const PAPER_SIZE := Vector2(0.56, 0.4)
const LAMP_LIGHT := Color("#ffd9a0")


func build() -> void:
	if not StationKit.visual():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 3141
	_frame(rng)
	_vise()
	_paper()
	_tools(rng)
	_lamp()
	_clutter(rng)


func _frame(rng: RandomNumberGenerator) -> void:
	var top_wood := StationKit.wood("bench_top", {base_color = Color("#b38a62"), grain_color = Color("#7a5638"), weathering = 0.12,
		variation = 0.2, grain_strength = 0.6})
	var frame_wood := StationKit.wood("bench_frame", {base_color = Color("#8a5f40"), grain_color = Color("#553826"), weathering = 0.25})
	var strips := []
	var n := 7
	var w := SIZE.y / n
	for i in n:
		var z := -SIZE.y * 0.5 + w * (i + 0.5)
		strips.append(EnvMesh.piece(EnvMesh.box(Vector3(SIZE.x, 0.08, w - 0.002), 0.008, 1), Transform3D(Basis(), Vector3(0, TOP - 0.04, z)), rng.randf(), Vector3.RIGHT))
	StationKit.add_merged(self, strips, top_wood)
	var parts := []
	for x: float in [-0.6, 0.6]:
		for z: float in [-0.31, 0.31]:
			parts.append(EnvMesh.piece(EnvMesh.box(Vector3(0.09, TOP - 0.08, 0.09), 0.012, 1), Transform3D(Basis(), Vector3(x, (TOP - 0.08) * 0.5, z)), rng.randf()))
	for z: float in [-0.31, 0.31]:
		parts.append(EnvMesh.piece(EnvMesh.box(Vector3(1.11, 0.1, 0.03), 0.008, 1), Transform3D(Basis(), Vector3(0, TOP - 0.13, z * 1.05)), rng.randf(), Vector3.RIGHT))
		parts.append(EnvMesh.piece(EnvMesh.box(Vector3(1.11, 0.06, 0.05), 0.008, 1), Transform3D(Basis(), Vector3(0, 0.17, z)), rng.randf(), Vector3.RIGHT))
	for x: float in [-0.6, 0.6]:
		parts.append(EnvMesh.piece(EnvMesh.box(Vector3(0.03, 0.1, 0.53), 0.008, 1), Transform3D(Basis(), Vector3(x * 1.04, TOP - 0.13, 0)), rng.randf(), Vector3.BACK))
		parts.append(EnvMesh.piece(EnvMesh.box(Vector3(0.05, 0.06, 0.53), 0.008, 1), Transform3D(Basis(), Vector3(x, 0.17, 0)), rng.randf(), Vector3.BACK))
	# Slatted shelf on the stretchers.
	for i in 5:
		var z := -0.24 + i * 0.12
		parts.append(EnvMesh.piece(EnvMesh.box(Vector3(1.11, 0.022, 0.1), 0.006, 1), Transform3D(Basis(Vector3.UP, StationKit.jitter(rng, 0.6)), Vector3(0, 0.211, z)), rng.randf(), Vector3.RIGHT))
	StationKit.add_merged(self, parts, frame_wood)


## Bench vise at the front-left corner.
func _vise() -> void:
	var iron := StationKit.metal("vise", {paint_color = Color("#3d5f6a"), paint = 0.8, rust = 0.3, dents = 0.2, roughness_paint = 0.5})
	var x := -0.5
	var z := SIZE.y * 0.5
	var parts := [
		EnvMesh.piece(EnvMesh.box(Vector3(0.16, 0.06, 0.12), 0.01, 1), Transform3D(Basis(), Vector3(x, TOP - 0.11, z - 0.02))),
		EnvMesh.piece(EnvMesh.box(Vector3(0.16, 0.12, 0.04), 0.01, 1), Transform3D(Basis(), Vector3(x, TOP - 0.03, z + 0.04))),
		EnvMesh.piece(EnvMesh.cylinder(0.012, 0.012, 0.16, 8), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(x, TOP - 0.06, z + 0.1))),
		EnvMesh.piece(EnvMesh.cylinder(0.025, 0.025, 0.03, 10), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(x, TOP - 0.06, z + 0.17))),
		EnvMesh.piece(EnvMesh.cylinder(0.007, 0.007, 0.22, 6), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(x, TOP - 0.06, z + 0.18))),
		EnvMesh.piece(EnvMesh.sphere(0.014, 8, 4), Transform3D(Basis(), Vector3(x - 0.11, TOP - 0.06, z + 0.18))),
		EnvMesh.piece(EnvMesh.sphere(0.014, 8, 4), Transform3D(Basis(), Vector3(x + 0.11, TOP - 0.06, z + 0.18))),
	]
	StationKit.add_merged(self, parts, iron)


## The sketch sheet, taped down, with a cat drawn on it in pencil.
func _paper() -> void:
	var basis := Basis(Vector3.UP, PAPER_YAW)
	var flat := StationKit.unique("station_paper", {flutter = 0.0})
	var sheet := StationKit.add(self, StationKit.sheet(PAPER_SIZE.x, PAPER_SIZE.y, 1), flat,
		Transform3D(basis * Basis(Vector3.RIGHT, -PI * 0.5), PAPER_AT))
	sheet.set_instance_shader_parameter(&"paper", Color("#f4ecdc"))
	sheet.set_instance_shader_parameter(&"pattern", 2.0)
	sheet.set_instance_shader_parameter(&"ink", Color("#c9d3dc"))
	sheet.set_instance_shader_parameter(&"phase", 0.3)
	var lines := []
	var drawing := DrawingSamples.cat()
	var span := 0.3
	for stroke in drawing.strokes:
		var pts := PackedVector3Array()
		for p in stroke:
			pts.append(PAPER_AT + basis * Vector3((p.x - 0.5) * span, 0.0015, (p.y - 0.5) * span))
		lines.append(EnvMesh.piece(StationKit.ribbon(pts, 0.006), Transform3D()))
	var graphite := StationKit.surface("graphite", {base_color = Color("#3b3a40"), roughness_base = 0.5, macro = 0.05, grain = 0.15,
		contact_dark = 0.0})
	StationKit.add_merged(self, lines, graphite, false)
	var tape := StationKit.surface("tape", {base_color = Color("#d8cba6"), roughness_base = 0.6, macro = 0.04, grain = 0.04,
		contact_dark = 0.0})
	var strips := []
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var c := Vector3(sx * PAPER_SIZE.x * 0.5, 0.003, sz * PAPER_SIZE.y * 0.5)
			strips.append(EnvMesh.piece(EnvMesh.box(Vector3(0.07, 0.002, 0.025), 0.0008, 1),
				Transform3D(basis * Basis(Vector3.UP, sx * sz * 0.785), PAPER_AT + basis * c)))
	StationKit.add_merged(self, strips, tape, false)


func _tools(rng: RandomNumberGenerator) -> void:
	var pencil_colors := [Color("#3f6b57"), Color("#8f3e35"), Color("#3e5d86")]
	var placements := [[Vector3(0.24, TOP + 0.005, 0.12), 1.2], [Vector3(0.21, TOP + 0.005, -0.04), 0.35], [Vector3(-0.42, TOP + 0.005, 0.27), -0.2]]
	var wood_tip := StationKit.wood("pencil_wood", {base_color = Color("#d4ad7f"), grain_color = Color("#a8825a"), weathering = 0.0})
	var lead := StationKit.surface("pencil_lead", {base_color = Color("#2b2a2e"), roughness_base = 0.4, contact_dark = 0.0})
	for i in placements.size():
		var at: Vector3 = placements[i][0]
		var b := Basis(Vector3.UP, float(placements[i][1])) * Basis(Vector3.BACK, PI * 0.5)
		var paint := StationKit.surface("pencil_%d" % i, {base_color = pencil_colors[i], roughness_base = 0.45, macro = 0.04, grain = 0.03,
			contact_dark = 0.0})
		StationKit.add(self, EnvMesh.cylinder(0.0045, 0.0045, 0.15, 6), paint, Transform3D(b, at), false)
		var axis := b * Vector3.UP
		StationKit.add(self, EnvMesh.cylinder(0.0012, 0.0045, 0.022, 6), wood_tip, Transform3D(b, at + axis * 0.086), false)
		StationKit.add(self, EnvMesh.cylinder(0.0, 0.0013, 0.006, 6), lead, Transform3D(b, at + axis * 0.1), false)
	var ruler_wood := StationKit.wood("ruler", {base_color = Color("#d6b98a"), grain_color = Color("#b0935f"), weathering = 0.0})
	StationKit.add(self, EnvMesh.box(Vector3(0.32, 0.004, 0.032), 0.001, 1), ruler_wood,
		Transform3D(Basis(Vector3.UP, -0.25), Vector3(0.05, TOP + 0.004, -0.24)))
	var ticks := []
	for k in 16:
		var tick := Vector3(-0.15 + k * 0.02, 0.0025, -0.012 + (0.003 if k % 5 == 0 else 0.0))
		ticks.append(EnvMesh.piece(EnvMesh.box(Vector3(0.0015, 0.001, 0.008 if k % 5 != 0 else 0.014), 0.0002, 1),
			Transform3D(Basis(Vector3.UP, -0.25), Vector3(0.05, TOP + 0.004, -0.24) + Basis(Vector3.UP, -0.25) * tick)))
	StationKit.add_merged(self, ticks, lead, false)
	var square := StationKit.surface("set_square", {base_color = Color("#5f8f8a"), roughness_base = 0.3, macro = 0.03, grain = 0.02,
		contact_dark = 0.0})
	StationKit.add(self, EnvMesh.cylinder(0.085, 0.085, 0.004, 3), square, Transform3D(Basis(Vector3.UP, 0.5), Vector3(0.36, TOP + 0.002, -0.1)))
	var eraser := StationKit.surface("eraser", {base_color = Color("#c9908a"), roughness_base = 0.8, contact_dark = 0.0})
	StationKit.add(self, EnvMesh.box(Vector3(0.05, 0.016, 0.022), 0.004, 1), eraser, Transform3D(Basis(Vector3.UP, 0.7), Vector3(0.27, TOP + 0.008, 0.26)))
	# A finished pattern: plywood star, ready to press into the sand.
	var built := CastMeshBuilder.build(DrawingSamples.star(), 0.17, 0.018)
	if not built.is_empty():
		var ply := StationKit.wood("pattern_ply", {base_color = Color("#cfa978"), grain_color = Color("#a8814f"), weathering = 0.05})
		StationKit.add(self, built.mesh, ply, Transform3D(Basis(Vector3.UP, 0.4), Vector3(0.43, TOP + 0.009, 0.17)))
	# Beer after work.
	PropKit.place(self, "kaykit_adventurers/mug_full.gltf", Vector3(-0.56, TOP, -0.26), 30.0, {solid = PropKit.Solid.NONE, scale = 0.42,
		tint = Color(0.95, 0.92, 0.88), desaturate = 0.2})


## Anglepoise lamp at the back-right, its head over the sheet.
func _lamp() -> void:
	var enamel := StationKit.metal("lamp", {paint_color = Color("#3f7f86"), paint = 0.92, rust = 0.1, dents = 0.0, roughness_paint = 0.4})
	var steel := StationKit.metal("lamp_steel", {steel_color = Color("#8d8f93"), rust = 0.05, dents = 0.0, metallic_steel = 0.85, roughness_steel = 0.3})
	var base := Vector3(0.5, TOP, -0.27)
	var elbow := Vector3(0.38, TOP + 0.44, -0.2)
	var head := Vector3(0.1, TOP + 0.44, -0.06)
	var target := PAPER_AT + Vector3(0.02, 0, 0.02)
	var dir := (target - head).normalized()
	var parts := [
		EnvMesh.piece(EnvMesh.cylinder(0.065, 0.075, 0.025, 16), Transform3D(Basis(), base + Vector3(0, 0.0125, 0))),
		EnvMesh.piece(EnvMesh.cylinder(0.018, 0.022, 0.04, 10), Transform3D(Basis(), base + Vector3(0, 0.045, 0))),
	]
	var shade_prof := PackedVector2Array([Vector2(0.078, 0.0), Vector2(0.073, 0.03), Vector2(0.042, 0.08), Vector2(0.024, 0.11),
		Vector2(0.0, 0.116), Vector2(0.0, 0.106), Vector2(0.019, 0.1), Vector2(0.037, 0.076), Vector2(0.068, 0.028),
		Vector2(0.073, 0.0), Vector2(0.078, -0.001)])
	parts.append(EnvMesh.piece(StationKit.lathe(shade_prof, 18, 50.0), Transform3D(StationKit.basis_y(-dir), head + dir * 0.02)))
	StationKit.add_merged(self, parts, enamel)
	var arm_parts := []
	var pivot := base + Vector3(0, 0.06, 0)
	for side: float in [-0.012, 0.012]:
		var off := Vector3(0, 0, side)
		arm_parts.append(EnvMesh.piece(StationKit.tube(PackedVector3Array([pivot + off, elbow + off]), 0.005, 6), Transform3D()))
		arm_parts.append(EnvMesh.piece(StationKit.tube(PackedVector3Array([elbow + off, head - dir * 0.03 + off]), 0.005, 6), Transform3D()))
	arm_parts.append(EnvMesh.piece(EnvMesh.cylinder(0.012, 0.012, 0.04, 8), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), elbow)))
	arm_parts.append(EnvMesh.piece(EnvMesh.cylinder(0.012, 0.012, 0.04, 8), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), pivot)))
	# Balance spring along the lower arm.
	var coil := PackedVector3Array()
	var along := elbow - pivot
	var u := along.normalized().cross(Vector3.BACK).normalized()
	var v := along.normalized().cross(u)
	for i in 121:
		var t := i / 120.0
		var a := t * TAU * 14.0
		coil.append(pivot + along * (0.2 + t * 0.55) + (u * cos(a) + v * sin(a)) * 0.007 + u * 0.022)
	arm_parts.append(EnvMesh.piece(StationKit.tube(coil, 0.0015, 4, false), Transform3D()))
	StationKit.add_merged(self, arm_parts, steel)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("#fff1d6")
	glow.emission_enabled = true
	glow.emission = Color("#ffd9a0")
	glow.emission_energy_multiplier = 2.5
	StationKit.add(self, EnvMesh.sphere(0.024, 10, 6), glow, Transform3D(Basis(), head - dir * 0.025), false)
	if EnvQuality.is_low():
		return
	var spot := SpotLight3D.new()
	spot.light_color = LAMP_LIGHT
	spot.light_energy = 2.2
	spot.spot_range = 1.4
	spot.spot_angle = 42.0
	spot.spot_attenuation = 0.8
	spot.shadow_enabled = false
	add_child(spot)
	spot.look_at_from_position(head + dir * 0.01, target + Vector3(0, -0.01, 0), Vector3.UP)


## Crumpled failed sketches (on the bench and on the ground), spare paper and
## a box of offcuts on the shelf.
func _clutter(rng: RandomNumberGenerator) -> void:
	var crumple := StationKit.surface("crumple", {base_color = Color("#e6dccb"), roughness_base = 0.92, macro = 0.08, grain = 0.06,
		contact_dark = 0.2})
	var balls := []
	var spots := [Vector3(0.52, TOP + 0.035, 0.24), Vector3(-0.38, 0.04, 0.62), Vector3(0.7, 0.035, 0.55), Vector3(-0.02, 0.24, 0.05)]
	for i in spots.size():
		balls.append(EnvMesh.piece(StationKit.chunk(rng.randf_range(0.035, 0.045), 20 + i, 0.85, 0.5), Transform3D(Basis.from_euler(Vector3(rng.randf(), rng.randf(), rng.randf()) * TAU), spots[i])))
	StationKit.add_merged(self, balls, crumple)
	var stack := []
	for i in 6:
		stack.append(EnvMesh.piece(EnvMesh.box(Vector3(0.3, 0.004, 0.21), 0.001, 1), Transform3D(Basis(Vector3.UP, rng.randf_range(-0.08, 0.08)), Vector3(-0.35, 0.225 + i * 0.005, -0.12))))
	StationKit.add_merged(self, stack, StationKit.surface("paper_stack", {base_color = Color("#efe7d6"), roughness_base = 0.9, macro = 0.03,
		grain = 0.03, contact_dark = 0.0}))
	PropKit.place(self, "kaykit_dungeon/box_small.gltf", Vector3(0.32, 0.222, -0.06), 12.0, {solid = PropKit.Solid.NONE, scale = 0.42,
		tint = Color(0.82, 0.76, 0.7), desaturate = 0.45})
	var offcut := StationKit.wood("offcuts", {base_color = Color("#c09868"), grain_color = Color("#8e6a45"), weathering = 0.1})
	var cuts := []
	for i in 5:
		var size := Vector3(rng.randf_range(0.08, 0.2), rng.randf_range(0.015, 0.03), rng.randf_range(0.04, 0.08))
		cuts.append(EnvMesh.piece(EnvMesh.box(size, 0.004, 1), Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.5, 0.5), rng.randf() * TAU, rng.randf_range(-0.5, 0.5))),
			Vector3(0.32 + rng.randf_range(-0.07, 0.07), 0.38 + i * 0.012, -0.06 + rng.randf_range(-0.06, 0.06))), rng.randf(), Vector3.RIGHT))
	StationKit.add_merged(self, cuts, offcut)
