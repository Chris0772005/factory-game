class_name GroundScatter
## Small 3D clutter on the ground as two MultiMeshes: pebbles along the
## edges of the worn dirt and paths and in the gravel strip, plus a few
## stones in the lawn. Purely visual (no colliders), deterministic seed.

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
