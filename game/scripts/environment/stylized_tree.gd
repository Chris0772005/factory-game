class_name StylizedTree
## Chunky stylized trees and bushes: a tapered, slightly crooked trunk with a
## few branches and a crown of lumpy foliage blobs (env_foliage: lumps, leaf
## clumps, wrap shading and a slow height-weighted sway). Also round
## conifers and hedge rows for the background.

const BARK := Color("#5c4636")


## Broad-leaf tree at `pos` (ground). `height` ~ crown top. Returns the root.
## Trees outside the yard (`solid` false) cast no shadows: at dusk their
## 20 m shadows would otherwise darken the whole work area.
static func tree(parent: Node3D, pos: Vector3, height: float, seed: int, solid := true, crown_tint := Color.WHITE) -> Node3D:
	var root := Node3D.new()
	root.name = "Tree"
	root.position = pos
	parent.add_child(root)
	var trunk_h := height * 0.48
	var trunk_r := height * 0.045
	if solid:
		WorldBuilder.add_cylinder_collider(root, trunk_r * 1.2, trunk_h, Vector3.ZERO)
	if not EnvMesh.visual():
		return root
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var wood := []
	var lean := Basis(Vector3.BACK, rng.randf_range(-0.08, 0.08)) * Basis(Vector3.RIGHT, rng.randf_range(-0.08, 0.08))
	wood.append(EnvMesh.piece(EnvMesh.cylinder(trunk_r * 0.62, trunk_r, trunk_h, 9), Transform3D(lean, lean * Vector3(0, trunk_h * 0.5, 0)), 0.2))
	wood.append(EnvMesh.piece(EnvMesh.cylinder(trunk_r * 0.9, trunk_r * 1.7, trunk_h * 0.16, 9), Transform3D(Basis(), Vector3(0, trunk_h * 0.07, 0)), 0.3))
	var top := lean * Vector3(0, trunk_h, 0)
	var blobs := []
	var crown_c := top + Vector3(0, height * 0.22, 0)
	var crown_r := height * 0.3
	# Branches fanning out from the top of the trunk, a crown blob on each.
	var branches := 4
	for i in branches:
		var yaw := TAU * (i + rng.randf() * 0.5) / branches
		var out := Vector3(cos(yaw), 0, sin(yaw))
		var dir := (out * 0.75 + Vector3.UP).normalized()
		var blen := height * rng.randf_range(0.22, 0.3)
		var b := Basis(Vector3.UP.cross(dir).normalized(), Vector3.UP.angle_to(dir)) if dir != Vector3.UP else Basis()
		var start := top - Vector3(0, height * 0.06, 0)
		wood.append(EnvMesh.piece(EnvMesh.cylinder(trunk_r * 0.28, trunk_r * 0.5, blen, 7), Transform3D(b, start + dir * blen * 0.5), 0.5 + i * 0.1))
		blobs.append([start + dir * blen + Vector3(0, crown_r * 0.25, 0), crown_r * rng.randf_range(0.62, 0.8)])
	blobs.append([crown_c + Vector3(0, crown_r * 0.35, 0), crown_r * 0.85])
	for i in 4:
		var yaw := rng.randf() * TAU
		blobs.append([crown_c + Vector3(cos(yaw), rng.randf_range(-0.3, 0.6), sin(yaw)) * crown_r * 0.7, crown_r * rng.randf_range(0.45, 0.65)])
	var bark := EnvMesh.wood("bark", {base_color = BARK, grain_color = Color("#3a2c24"), weathering = 0.3, grain_strength = 0.8})
	EnvMesh.add(root, EnvMesh.merge(wood), bark, Transform3D(), solid)
	var leaves := []
	for bl in blobs:
		leaves.append(EnvMesh.piece(EnvMesh.sphere(1.0, 14, 8), Transform3D(Basis().scaled(Vector3(1.0, 0.82, 1.0) * float(bl[1])), bl[0]), rng.randf()))
	var key := "crown_%s" % crown_tint.to_html()
	var mat := EnvMesh.foliage(key, {top_color = Color("#6f9e52"), bottom_color = Color("#24483a"), tint = crown_tint,
		lumps = 0.22, clump_scale = 1.6, sway = 0.008, sway_base = pos.y + trunk_h * 0.6})
	EnvMesh.add(root, EnvMesh.merge(leaves), mat, Transform3D(), solid)
	return root


## Round-topped conifer for the background (stacked lumpy cones, no shadows).
static func conifer(parent: Node3D, pos: Vector3, height: float, seed: int) -> void:
	if not EnvMesh.visual():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	var bark := EnvMesh.wood("bark", {base_color = BARK, grain_color = Color("#3a2c24"), weathering = 0.3, grain_strength = 0.8})
	EnvMesh.add(root, EnvMesh.cylinder(height * 0.03, height * 0.05, height * 0.3, 7), bark, Transform3D(Basis(), Vector3(0, height * 0.15, 0)), false)
	var parts := []
	var tiers := 4
	for i in tiers:
		var t := float(i) / tiers
		var r := height * (0.28 - t * 0.17)
		var h := height * 0.34
		var y := height * (0.22 + t * 0.6)
		parts.append(EnvMesh.piece(EnvMesh.cylinder(r * 0.12, r, h, 12), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(0, y + h * 0.5, 0)), rng.randf()))
	var mat := EnvMesh.foliage("conifer", {top_color = Color("#4f7f58"), bottom_color = Color("#1d3a33"), lumps = 0.25, clump_scale = 2.2,
		sway = 0.004, sway_base = 0.0})
	EnvMesh.add(root, EnvMesh.merge(parts), mat, Transform3D(), false)


## Low round bush (a few merged blobs). `solid` adds a small collider.
static func bush(parent: Node3D, pos: Vector3, radius: float, seed: int, solid := false, tint := Color.WHITE) -> void:
	if solid:
		WorldBuilder.add_cylinder_collider(parent, radius * 0.8, radius * 1.2, pos)
	if not EnvMesh.visual():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var parts := []
	var n := rng.randi_range(3, 5)
	for i in n:
		var a := rng.randf() * TAU
		var r := radius * rng.randf_range(0.55, 0.8)
		var off := Vector3(cos(a), 0, sin(a)) * radius * rng.randf_range(0.2, 0.5)
		parts.append(EnvMesh.piece(EnvMesh.sphere(1.0, 12, 7), Transform3D(Basis().scaled(Vector3(1, 0.85, 1) * r), pos + off + Vector3(0, r * 0.7, 0)), rng.randf()))
	var key := "bush_%s" % tint.to_html()
	var mat := EnvMesh.foliage(key, {top_color = Color("#6a9a55"), bottom_color = Color("#244a3a"), tint = tint, lumps = 0.12,
		clump_scale = 3.2, sway = 0.02, sway_base = pos.y})
	EnvMesh.add(parent, EnvMesh.merge(parts), mat)


## Hedge along a line from `a` to `b` (blobs in a row, slightly uneven).
static func hedge(parent: Node3D, a: Vector3, b: Vector3, height: float, seed: int) -> void:
	if not EnvMesh.visual():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var parts := []
	var length := a.distance_to(b)
	var n := int(length / (height * 0.6)) + 1
	for i in n:
		var p := a.lerp(b, float(i) / maxf(n - 1, 1))
		var r := height * rng.randf_range(0.5, 0.62)
		parts.append(EnvMesh.piece(EnvMesh.sphere(1.0, 12, 7), Transform3D(Basis().scaled(Vector3(1.0, 1.1, 1.0) * r), p + Vector3(rng.randf_range(-0.2, 0.2), r * 0.9, rng.randf_range(-0.2, 0.2))), rng.randf()))
	var mat := EnvMesh.foliage("hedge", {top_color = Color("#557f4a"), bottom_color = Color("#1f3d33"), lumps = 0.18, clump_scale = 2.8,
		sway = 0.006, sway_base = 0.0})
	EnvMesh.add(parent, EnvMesh.merge(parts), mat)
