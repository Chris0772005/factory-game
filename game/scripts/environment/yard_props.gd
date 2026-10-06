class_name YardProps
## Procedural set-dressing pieces no CC0 pack covers: anvil on a stump, tyre
## stacks, rusty sheets, terracotta pots, a raised vegetable bed, a fire-brick
## stack, garden tools, a clothes line with fluttering laundry and a tyre
## swing. Each adds its own collider where people could bump into it.


static func anvil(parent: Node3D, pos: Vector3, yaw: float) -> void:
	WorldBuilder.add_cylinder_collider(parent, 0.36, 0.95, pos)
	if not EnvMesh.visual():
		return
	var root := _root(parent, pos, yaw)
	var bark := EnvMesh.wood("bark", {base_color = StylizedTree.BARK, grain_color = Color("#3a2c24"), weathering = 0.3, grain_strength = 0.8})
	var end_grain := EnvMesh.wood("stump_top", {base_color = Color("#a07a58"), grain_color = Color("#6e4f3a"), weathering = 0.2})
	EnvMesh.add(root, EnvMesh.cylinder(0.3, 0.34, 0.55, 12), bark, Transform3D(Basis(), Vector3(0, 0.275, 0)))
	EnvMesh.add(root, EnvMesh.cylinder(0.29, 0.29, 0.02, 12), end_grain, Transform3D(Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.FORWARD, 0.0), Vector3(0, 0.555, 0)))
	var iron := EnvMesh.surface("anvil", {base_color = Color("#3d3b3c"), metallic_base = 0.75, roughness_base = 0.42, macro = 0.06,
		stains = 0.3, stain_color = Color("#5b4232"), gradient = 0.35, grad_bottom = 0.56, grad_top = 0.95})
	var parts := [
		EnvMesh.piece(EnvMesh.box(Vector3(0.36, 0.08, 0.26), 0.02, 1), Transform3D(Basis(), Vector3(0, 0.6, 0))),
		EnvMesh.piece(EnvMesh.box(Vector3(0.18, 0.16, 0.14), 0.02, 1), Transform3D(Basis(), Vector3(0, 0.72, 0))),
		EnvMesh.piece(EnvMesh.box(Vector3(0.5, 0.12, 0.2), 0.025, 2), Transform3D(Basis(), Vector3(-0.04, 0.86, 0))),
		EnvMesh.piece(EnvMesh.cylinder(0.0, 0.09, 0.24, 8), Transform3D(Basis(Vector3.BACK, PI * 0.5).scaled(Vector3(1, 1, 0.75)), Vector3(0.32, 0.87, 0))),
	]
	EnvMesh.add(root, EnvMesh.merge(parts), iron)
	# A pair of tongs resting on it.
	var tongs := []
	for s: float in [-1.0, 1.0]:
		tongs.append(EnvMesh.piece(EnvMesh.box(Vector3(0.5, 0.018, 0.018), 0.005, 1),
			Transform3D(Basis(Vector3.UP, s * 0.06), Vector3(0.05, 0.93, 0.05 + s * 0.012)), 0.0, Vector3.RIGHT))
	EnvMesh.add(root, EnvMesh.merge(tongs), EnvMesh.surface("dark_iron", {base_color = Color("#2e2b2c"), metallic_base = 0.5, roughness_base = 0.5}))


static func tyres(parent: Node3D, pos: Vector3, count: int, seed: int) -> void:
	WorldBuilder.add_cylinder_collider(parent, 0.42, 0.24 * count, pos)
	if not EnvMesh.visual():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var tyre := TorusMesh.new()
	tyre.inner_radius = 0.2
	tyre.outer_radius = 0.4
	tyre.rings = 16
	tyre.ring_segments = 8
	var parts := []
	for i in count:
		var b := Basis(Vector3.RIGHT, rng.randf_range(-0.08, 0.08)) * Basis(Vector3.UP, rng.randf() * TAU)
		parts.append(EnvMesh.piece(tyre, Transform3D(b.scaled(Vector3(1, 1.3, 1)), pos + Vector3(rng.randf_range(-0.05, 0.05), 0.13 + i * 0.25, rng.randf_range(-0.05, 0.05))), rng.randf()))
	var rubber := EnvMesh.surface("rubber", {base_color = Color("#2b2829"), roughness_base = 0.85, macro = 0.08, grain = 0.08,
		stains = 0.3, stain_color = Color("#6b5a48")})
	EnvMesh.add(parent, EnvMesh.merge(parts), rubber)


## Rusty corrugated sheets and pipes leaning against a fence (facing `normal`).
static func scrap_lean(parent: Node3D, pos: Vector3, normal: Vector3, seed: int) -> void:
	if not EnvMesh.visual():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var along := Vector3.UP.cross(normal).normalized()
	var parts := []
	for i in 3:
		var w := rng.randf_range(0.6, 0.9)
		var h := rng.randf_range(1.0, 1.35)
		var c := pos + along * (i * 0.45 - 0.45) + normal * (0.18 + i * 0.05)
		var b := Basis(along, -0.22 - i * 0.04) * Basis.looking_at(-normal, Vector3.UP)
		parts.append(EnvMesh.piece(EnvMesh.box(Vector3(w, h, 0.02), 0.008, 1), Transform3D(b, c + Vector3(0, h * 0.48, 0)), rng.randf()))
	var tin := EnvMesh.surface("rust_sheet", {base_color = Color("#8e969c"), metallic_base = 0.25, roughness_base = 0.65,
		stains = 0.85, stain_color = Color("#8a4b2e"), noise_scale = 1.8})
	EnvMesh.add(parent, EnvMesh.merge(parts), tin)
	var pipes := []
	for i in 4:
		var c := pos + along * rng.randf_range(0.5, 1.1) + normal * rng.randf_range(0.5, 0.8)
		var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.BACK, PI * 0.5)
		pipes.append(EnvMesh.piece(EnvMesh.cylinder(0.04, 0.04, rng.randf_range(0.8, 1.4), 8), Transform3D(b, c + Vector3(0, 0.05 + i * 0.07, 0)), rng.randf()))
	EnvMesh.add(parent, EnvMesh.merge(pipes), EnvMesh.surface("pipe", {base_color = Color("#6d6a66"), metallic_base = 0.6,
		roughness_base = 0.5, stains = 0.6, stain_color = Color("#73472f")}))


## Terracotta pot with a little bush in it.
static func pot(parent: Node3D, pos: Vector3, size: float, seed: int, plant_tint := Color.WHITE) -> void:
	if not EnvMesh.visual():
		return
	var clay := EnvMesh.surface("terracotta", {base_color = Color("#a8705a"), roughness_base = 0.9, macro = 0.1, grain = 0.08,
		stains = 0.45, stain_color = Color("#6f7a5e"), gradient = 0.25, grad_bottom = 0.0, grad_top = 0.6})
	var parts := [
		EnvMesh.piece(EnvMesh.cylinder(size * 0.5, size * 0.36, size * 0.8, 12), Transform3D(Basis(), pos + Vector3(0, size * 0.4, 0))),
		EnvMesh.piece(EnvMesh.cylinder(size * 0.56, size * 0.54, size * 0.14, 12), Transform3D(Basis(), pos + Vector3(0, size * 0.78, 0))),
	]
	EnvMesh.add(parent, EnvMesh.merge(parts), clay)
	StylizedTree.bush(parent, pos + Vector3(0, size * 0.7, 0), size * 0.55, seed, false, plant_tint)


## Raised vegetable bed: board frame filled with soil and rows of plants.
static func raised_bed(parent: Node3D, pos: Vector3, yaw: float, size: Vector2, seed: int) -> void:
	var b := Basis(Vector3.UP, deg_to_rad(yaw))
	WorldBuilder.add_collider(parent, Vector3(size.x, 0.45, size.y), Transform3D(b, pos + Vector3(0, 0.225, 0)))
	if not EnvMesh.visual():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var root := _root(parent, pos, yaw)
	var boards := []
	for row in 2:
		var y := 0.1 + row * 0.2
		for s: float in [-1.0, 1.0]:
			boards.append(EnvMesh.piece(EnvMesh.box(Vector3(size.x, 0.19, 0.06), 0.015, 1), Transform3D(Basis(), Vector3(0, y, s * (size.y * 0.5 - 0.03))), rng.randf(), Vector3.RIGHT))
			boards.append(EnvMesh.piece(EnvMesh.box(Vector3(0.06, 0.19, size.y - 0.12), 0.015, 1), Transform3D(Basis(), Vector3(s * (size.x * 0.5 - 0.03), y, 0)), rng.randf(), Vector3.BACK))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			boards.append(EnvMesh.piece(EnvMesh.box(Vector3(0.09, 0.5, 0.09), 0.015, 1), Transform3D(Basis(), Vector3(sx * (size.x * 0.5 - 0.02), 0.25, sz * (size.y * 0.5 - 0.02))), rng.randf()))
	EnvMesh.add(root, EnvMesh.merge(boards), EnvMesh.wood("bed", {base_color = Color("#8a6448"), weathering = 0.5}))
	EnvMesh.add(root, EnvMesh.box(Vector3(size.x - 0.1, 0.06, size.y - 0.1), 0.02, 1),
		EnvMesh.surface("soil", {base_color = Color("#4a3a30"), roughness_base = 0.95, macro = 0.15, grain = 0.15, contact_dark = 0.0, bump = 1.0}),
		Transform3D(Basis(), Vector3(0, 0.38, 0)))
	var leaves := []
	var cols := int(size.x / 0.32)
	for i in cols:
		for j in 2:
			var c := Vector3(-size.x * 0.5 + 0.2 + i * (size.x - 0.4) / maxf(cols - 1, 1), 0.44, (j - 0.5) * size.y * 0.45)
			var r := rng.randf_range(0.12, 0.18)
			leaves.append(EnvMesh.piece(EnvMesh.sphere(1.0, 10, 6), Transform3D(Basis().scaled(Vector3(r, r * 0.8, r)), c + Vector3(0, r * 0.5, 0)), rng.randf()))
	EnvMesh.add(root, EnvMesh.merge(leaves), EnvMesh.foliage("veg", {top_color = Color("#7aa85a"), bottom_color = Color("#2f5a43"),
		lumps = 0.06, clump_scale = 9.0, sway = 0.03, sway_base = 0.35}))


static func bricks(parent: Node3D, pos: Vector3, yaw: float, seed: int) -> void:
	WorldBuilder.add_collider(parent, Vector3(0.9, 0.5, 0.5), Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), pos + Vector3(0, 0.25, 0)))
	if not EnvMesh.visual():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var root := _root(parent, pos, yaw)
	var parts := []
	for layer in 5:
		var along_x := layer % 2 == 0
		for i in 4:
			if layer == 4 and i > 1:
				continue
			var off := (i - 1.5) * (0.22 if along_x else 0.12)
			var y := 0.05 + layer * 0.1
			var p := Vector3(off, y, rng.randf_range(-0.01, 0.01)) if along_x else Vector3(rng.randf_range(-0.02, 0.02), y, off)
			var size := Vector3(0.2, 0.09, 0.42) if along_x else Vector3(0.84, 0.09, 0.11)
			parts.append(EnvMesh.piece(EnvMesh.box(size, 0.012, 1), Transform3D(Basis(Vector3.UP, rng.randf_range(-0.05, 0.05)), p), rng.randf()))
	EnvMesh.add(root, EnvMesh.merge(parts), EnvMesh.surface("firebrick", {base_color = Color("#b9a184"), roughness_base = 0.9,
		macro = 0.12, grain = 0.1, variation = 0.15, stains = 0.4, stain_color = Color("#5a4a40")}))


## Shovel or rake leaning on something at `pos`, falling towards `dir`.
static func tool(parent: Node3D, pos: Vector3, dir: Vector3, rake: bool) -> void:
	if not EnvMesh.visual():
		return
	var lean := Basis(Vector3.UP.cross(dir).normalized(), deg_to_rad(16.0))
	var handle := EnvMesh.wood("handle", {base_color = Color("#a07a58"), weathering = 0.1})
	var iron := EnvMesh.surface("tool_iron", {base_color = Color("#55585c"), metallic_base = 0.7, roughness_base = 0.45,
		stains = 0.45, stain_color = Color("#6e4630")})
	EnvMesh.add(parent, EnvMesh.cylinder(0.022, 0.022, 1.35, 6), handle, Transform3D(lean, pos + lean * Vector3(0, 0.85, 0)))
	if rake:
		EnvMesh.add(parent, EnvMesh.box(Vector3(0.42, 0.04, 0.04), 0.01, 1), iron, Transform3D(lean * Basis(Vector3.UP, PI * 0.5), pos + lean * Vector3(0, 0.16, 0)))
	else:
		EnvMesh.add(parent, EnvMesh.box(Vector3(0.22, 0.3, 0.02), 0.01, 1), iron, Transform3D(lean, pos + lean * Vector3(0, 0.12, 0)))


## Clothes line between two T-posts with a few pieces of laundry.
static func clothes_line(parent: Node3D, a: Vector3, b: Vector3, seed: int) -> void:
	for p: Vector3 in [a, b]:
		WorldBuilder.add_cylinder_collider(parent, 0.09, 1.9, p)
	if not EnvMesh.visual():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var dir := (b - a).normalized()
	var across := dir.cross(Vector3.UP).normalized()
	var posts := []
	for p: Vector3 in [a, b]:
		posts.append(EnvMesh.piece(EnvMesh.box(Vector3(0.09, 2.0, 0.09), 0.015, 1), Transform3D(Basis(), p + Vector3(0, 1.0, 0)), rng.randf()))
		posts.append(EnvMesh.piece(EnvMesh.box(Vector3(0.07, 0.07, 0.7), 0.012, 1), Transform3D(Basis.looking_at(across, Vector3.UP), p + Vector3(0, 1.88, 0)), rng.randf(), Vector3.BACK))
	EnvMesh.add(parent, EnvMesh.merge(posts), EnvMesh.wood("pole", {base_color = Color("#6e5240"), weathering = 0.4}))
	var line_mat := EnvMesh.surface("line", {base_color = Color("#d8d2c4"), roughness_base = 0.9, contact_dark = 0.0})
	var colors := [Color("#e8e2d4"), Color("#8fb3d9"), Color("#c7b2e6"), Color("#e9b7c9"), Color("#9fc6a8"), Color("#e8e2d4")]
	for side: float in [-1.0, 1.0]:
		var pa := a + Vector3(0, 1.86, 0) + across * side * 0.28
		var pb := b + Vector3(0, 1.86, 0) + across * side * 0.28
		var length := pa.distance_to(pb)
		var mid := (pa + pb) * 0.5 - Vector3(0, 0.12, 0)
		EnvMesh.add(parent, EnvMesh.cylinder(0.006, 0.006, length, 4), line_mat, Transform3D(Basis.looking_at(dir, Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5), mid), false)
		var t := 0.12
		while t < 0.88:
			var w := rng.randf_range(0.45, 0.8)
			var h := rng.randf_range(0.5, 0.85)
			if rng.randf() < 0.75:
				var p := pa.lerp(pb, t + w * 0.5 / length) - Vector3(0, 0.12 * 4.0 * t * (1.0 - t) / 1.0, 0)
				var cloth := MeshInstance3D.new()
				var plane := PlaneMesh.new()
				plane.size = Vector2(w, h)
				plane.subdivide_width = 4
				plane.subdivide_depth = 6
				plane.orientation = PlaneMesh.FACE_Z
				cloth.mesh = plane
				cloth.material_override = EnvMesh.material("cloth", "res://shaders/env_cloth.gdshader")
				var c: Color = colors[rng.randi() % colors.size()]
				cloth.set_instance_shader_parameter(&"cloth", c)
				cloth.set_instance_shader_parameter(&"stripe", c.lightened(0.25) if rng.randf() < 0.4 else c)
				cloth.set_instance_shader_parameter(&"phase", rng.randf())
				cloth.transform = Transform3D(Basis.looking_at(across, Vector3.UP), p - Vector3(0, h * 0.5, 0))
				parent.add_child(cloth)
			t += (w + 0.12) / length


## Tyre swing hanging from a branch at `hook`; sways slowly.
static func tyre_swing(parent: Node3D, hook: Vector3, length: float) -> void:
	if not EnvMesh.visual():
		return
	var pivot := Node3D.new()
	pivot.name = "TyreSwing"
	pivot.position = hook
	pivot.set_script(load("res://scripts/environment/swing_pivot.gd"))
	parent.add_child(pivot)
	var rope := EnvMesh.surface("rope", {base_color = Color("#b49a72"), roughness_base = 0.95, contact_dark = 0.0})
	EnvMesh.add(pivot, EnvMesh.cylinder(0.015, 0.015, length, 5), rope, Transform3D(Basis(), Vector3(0, -length * 0.5, 0)))
	var tyre := TorusMesh.new()
	tyre.inner_radius = 0.17
	tyre.outer_radius = 0.33
	tyre.rings = 16
	tyre.ring_segments = 8
	var rubber := EnvMesh.surface("rubber", {base_color = Color("#2b2829"), roughness_base = 0.85, macro = 0.08, grain = 0.08,
		stains = 0.3, stain_color = Color("#6b5a48")})
	EnvMesh.add(pivot, tyre, rubber, Transform3D(Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3(1, 1.2, 1)), Vector3(0, -length - 0.3, 0)))


static func _root(parent: Node3D, pos: Vector3, yaw: float) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = deg_to_rad(yaw)
	parent.add_child(root)
	return root
