class_name GroundScatter
## Small 3D clutter on the ground as MultiMeshes: pebbles along the edges of
## the worn dirt and paths and in the gravel strip, plus a few stones in the
## lawn; and the debris the work leaves behind (Art Bible 10.3): charcoal and
## brick crumbs round the furnace, moulding-sand clumps and cold metal drips
## round the molds, wood shavings under the workbench. Purely visual (no
## colliders, a few cm high, so walkways stay walkable), fixed seeds.

const SPACING := 0.25


static func build(parent: Node3D, layout: YardLayout) -> void:
	if not EnvMesh.visual():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var density := EnvQuality.grass_density()
	var stones := []
	var lo := YardLayout.YARD_MIN
	var hi := YardLayout.YARD_MAX
	var y := lo.y
	while y < hi.y:
		var x := lo.x
		while x < hi.x:
			var p := Vector2(x, y) + Vector2(rng.randf(), rng.randf()) * SPACING
			x += SPACING
			var z := layout.zones_at(p)
			var edge := z.r * (1.0 - z.r) * 4.0
			var chance := edge * 0.22 * (0.5 + rng.randf()) + z.g * 0.7 + 0.03
			if z.r > 0.85:
				chance = 0.006
			if layout.is_covered(p) or rng.randf() > chance * density:
				continue
			var s := rng.randf_range(0.018, 0.045) * (1.4 if z.g > 0.5 else 1.0)
			var basis := Basis.from_euler(Vector3(rng.randf_range(-0.15, 0.15), rng.randf() * TAU, rng.randf_range(-0.15, 0.15)))
			basis = basis.scaled(Vector3(s * rng.randf_range(0.9, 1.4), s * rng.randf_range(0.3, 0.45), s))
			stones.append(Transform3D(basis, Vector3(p.x, YardGround.height_at(p, layout) + s * 0.15, p.y)))
		y += SPACING
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = EnvMesh.merge([EnvMesh.piece(EnvMesh.sphere(1.0, 7, 4), Transform3D(), 0.5)])
	mm.instance_count = stones.size()
	for i in stones.size():
		mm.set_instance_transform(i, stones[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Pebbles"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.material_override = EnvMesh.surface("pebble", {base_color = Color("#9a8f82"), variation = 0.3, macro = 0.12,
		grain = 0.1, roughness_base = 0.85, contact_dark = 0.0, gradient = 0.0})
	mmi.visibility_range_end = EnvQuality.grass_distance()
	parent.add_child(mmi)
	_debris(parent, layout, density)


## Work debris around the stations (positions from the layout, so it follows
## the stations when they move).
static func _debris(parent: Node3D, layout: YardLayout, density: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5151
	var charcoal := []
	var bricks := []
	var sand := []
	var drips := []
	var shavings := []
	var f := layout.furnace
	for i in int(90 * density):
		var p := _around(rng, f, 0.95, 2.1, 1.6)
		if _keep(layout, p, rng):
			charcoal.append(_chip(rng, p, Vector3(0.035, 0.022, 0.03), 0.6))
	for i in int(16 * density):
		var p := _around(rng, f, 1.0, 1.9, 1.0)
		if _keep(layout, p, rng):
			bricks.append(_chip(rng, p, Vector3(0.07, 0.035, 0.045), 0.5))
	for m in layout.molds:
		for i in int(45 * density):
			var p := _around(rng, m, 0.75, 1.5, 1.4)
			if absf(p.x - m.x) < 0.88 and absf(p.y - m.y) < 0.66:
				continue
			if _keep(layout, p, rng):
				sand.append(_chip(rng, p, Vector3(0.06, 0.03, 0.05), 0.4))
		for i in int(7 * density):
			var p := _around(rng, m, 0.8, 1.3, 1.0)
			if absf(p.x - m.x) < 0.88 and absf(p.y - m.y) < 0.66:
				continue
			if _keep(layout, p, rng):
				drips.append(_chip(rng, p, Vector3(0.04, 0.008, 0.032), 0.0))
	for s in layout.station_spots:
		# Wood shavings under the workbench, a few splinters at the crate and board.
		var count: int = {&"bench": 40, &"other": 8}.get(s[3], 0)
		for i in int(count * density):
			var p := _around(rng, s[0], 0.2, 1.2, 1.2)
			if _keep(layout, p, rng):
				shavings.append(_chip(rng, p, Vector3(0.07, 0.006, 0.018), 0.0))
	_layer(parent, "Charcoal", EnvMesh.box(Vector3.ONE, 0.18, 1), charcoal,
		EnvMesh.surface("charcoal", {base_color = Color("#2b2626"), variation = 0.3, roughness_base = 0.75, contact_dark = 0.0, gradient = 0.0}))
	_layer(parent, "BrickCrumbs", EnvMesh.box(Vector3.ONE, 0.12, 1), bricks,
		EnvMesh.surface("brick_crumb", {base_color = Color("#9e5844"), variation = 0.25, roughness_base = 0.9, contact_dark = 0.0, gradient = 0.0}))
	_layer(parent, "SandClumps", EnvMesh.sphere(0.5, 7, 4), sand,
		EnvMesh.surface("sand_clump", {base_color = Color("#d4b884"), variation = 0.2, grain = 0.12, roughness_base = 0.95, contact_dark = 0.0, gradient = 0.0}))
	_layer(parent, "MetalDrips", EnvMesh.sphere(0.5, 8, 4), drips,
		EnvMesh.surface("metal_drip", {base_color = Color("#b9b4ad"), variation = 0.35, metallic_base = 0.85, roughness_base = 0.35,
			contact_dark = 0.0, gradient = 0.0}))
	_layer(parent, "Shavings", EnvMesh.box(Vector3.ONE, 0.003, 1), shavings,
		EnvMesh.surface("shaving", {base_color = Color("#c9a275"), variation = 0.3, roughness_base = 0.8, contact_dark = 0.0, gradient = 0.0}))


## Random point in a ring around `c`, biased towards the inside by `bias`.
static func _around(rng: RandomNumberGenerator, c: Vector2, r0: float, r1: float, bias: float) -> Vector2:
	var a := rng.randf() * TAU
	return c + Vector2(cos(a), sin(a)) * lerpf(r0, r1, pow(rng.randf(), bias))


## Debris stays off buildings, props and puddles; walkways keep only some.
static func _keep(layout: YardLayout, p: Vector2, rng: RandomNumberGenerator) -> bool:
	if layout.is_covered(p):
		return false
	var det := layout.detail_at(p)
	return det.b < 0.2 and rng.randf() > det.r * 0.55


## One crumb: random yaw, a little tilt, `size` +-35 %, lying on the ground.
static func _chip(rng: RandomNumberGenerator, p: Vector2, size: Vector3, tilt: float) -> Transform3D:
	var k := rng.randf_range(0.65, 1.35)
	var b := Basis.from_euler(Vector3(rng.randf_range(-tilt, tilt), rng.randf() * TAU, rng.randf_range(-tilt, tilt)))
	b = b.scaled(Vector3(size.x * k * rng.randf_range(0.8, 1.2), size.y * k, size.z * k))
	return Transform3D(b, Vector3(p.x, size.y * k * 0.3, p.y))


static func _layer(parent: Node3D, name: String, mesh: Mesh, xs: Array, mat: Material) -> void:
	if xs.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = EnvMesh.merge([EnvMesh.piece(mesh, Transform3D(), 0.5)])
	mm.instance_count = xs.size()
	for i in xs.size():
		mm.set_instance_transform(i, xs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = name
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.material_override = mat
	mmi.visibility_range_end = EnvQuality.grass_distance()
	parent.add_child(mmi)
