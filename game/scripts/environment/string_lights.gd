class_name StringLights
## Festoon lights strung over the work area like a ceiling: wooden poles and
## wall hooks, sagging cables (catenary) with a warm bulb every half metre.
## Cables and bulbs sway together in the shaders (env_lights / env_bulb), so
## nothing moves on the CPU. A few unshadowed omni lights give the warm pool.

const BULB_SPACING := 0.55
const POLE_HEIGHT := 3.5
const LIGHT_COLOR := Color("#ffc27a")


## `anchors`: name -> Vector3 (top of a pole or a wall hook). `poles`: names
## that need a pole. `spans`: [from name, to name] pairs.
static func build(parent: Node3D, anchors: Dictionary, poles: Array, spans: Array) -> Node3D:
	var root := Node3D.new()
	root.name = "StringLights"
	parent.add_child(root)
	for name in poles:
		var top: Vector3 = anchors[name]
		WorldBuilder.add_cylinder_collider(root, 0.12, top.y, Vector3(top.x, 0, top.z))
	if not EnvMesh.visual():
		return root
	var rng := RandomNumberGenerator.new()
	rng.seed = 1999
	var frame := []
	for name in poles:
		_pole(anchors[name], rng, frame)
	var cable_st := SurfaceTool.new()
	cable_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bulbs := []
	var customs := []
	var lights := 0
	var max_lights := 2 if EnvQuality.is_low() else 5
	for s in spans:
		var a: Vector3 = anchors[s[0]]
		var b: Vector3 = anchors[s[1]]
		var length := a.distance_to(b)
		var sag := clampf(length * 0.05, 0.3, 0.75)
		var phase := rng.randf()
		var flat := Vector2(b.x - a.x, b.z - a.z).normalized()
		var perp := Vector2(-flat.y, flat.x)
		_cable(cable_st, a, b, sag, phase, perp)
		var n := int(length / BULB_SPACING)
		for i in range(1, n):
			var t := float(i) / n
			var p := _catenary(a, b, sag, t)
			bulbs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p))
			customs.append(Color(t, phase, perp.x * 0.5 + 0.5, perp.y * 0.5 + 0.5))
		if lights < max_lights and length > 7.0:
			var light := OmniLight3D.new()
			light.light_color = LIGHT_COLOR
			light.light_energy = 1.1
			light.omni_range = 7.0
			light.omni_attenuation = 1.2
			light.shadow_enabled = false
			light.position = _catenary(a, b, sag, 0.5) + Vector3(0, -0.25, 0)
			root.add_child(light)
			lights += 1
	var cable_mat := EnvMesh.material("cable", "res://shaders/env_lights.gdshader")
	EnvMesh.add(root, cable_st.commit(), cable_mat, Transform3D(), false)
	var socket_mat := EnvMesh.material("socket", "res://shaders/env_lights.gdshader", {instanced = true})
	var bulb_mat := EnvMesh.material("bulb", "res://shaders/env_bulb.gdshader")
	_bulbs(root, EnvMesh.cylinder(0.02, 0.016, 0.06, 8), Transform3D(Basis(), Vector3(0, -0.045, 0)), bulbs, customs, socket_mat)
	_bulbs(root, EnvMesh.sphere(0.036, 10, 6), Transform3D(Basis().scaled(Vector3(1, 1.3, 1)), Vector3(0, -0.1, 0)), bulbs, customs, bulb_mat)
	var wood := EnvMesh.wood("pole", {base_color = Color("#6e5240"), weathering = 0.4})
	EnvMesh.add(root, EnvMesh.merge(frame), wood)
	return root


## Point on a span at fraction t, sagging by a parabola (close to a catenary).
static func _catenary(a: Vector3, b: Vector3, sag: float, t: float) -> Vector3:
	return a.lerp(b, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0)


static func _cable(st: SurfaceTool, a: Vector3, b: Vector3, sag: float, phase: float, perp: Vector2) -> void:
	var steps := int(a.distance_to(b) / 0.25) + 2
	var r := 0.008
	var sides := 5
	var col := Color(0.0, phase, perp.x * 0.5 + 0.5, perp.y * 0.5 + 0.5)
	var rings := []
	for i in steps + 1:
		var t := float(i) / steps
		var p := _catenary(a, b, sag, t)
		var tangent := (_catenary(a, b, sag, minf(t + 0.01, 1.0)) - _catenary(a, b, sag, maxf(t - 0.01, 0.0))).normalized()
		var side := tangent.cross(Vector3.UP).normalized()
		var up := side.cross(tangent).normalized()
		var ring := []
		for k in sides:
			var ang := TAU * k / sides
			var n := side * cos(ang) + up * sin(ang)
			ring.append([p + n * r, n, t])
		rings.append(ring)
	for i in steps:
		for k in sides:
			var q := [rings[i][k], rings[i + 1][k], rings[i + 1][(k + 1) % sides], rings[i][(k + 1) % sides]]
			for idx: int in [0, 2, 1, 0, 3, 2]:
				st.set_normal(q[idx][1])
				st.set_uv(Vector2(q[idx][2], 0.0))
				st.set_color(col)
				st.add_vertex(q[idx][0])


static func _bulbs(root: Node3D, mesh: Mesh, offset: Transform3D, xs: Array, customs: Array, mat: Material) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _baked(mesh, offset)
	mm.instance_count = xs.size()
	for i in xs.size():
		mm.set_instance_transform(i, xs[i])
		mm.set_instance_custom_data(i, customs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mmi)


static func _baked(mesh: Mesh, offset: Transform3D) -> ArrayMesh:
	return EnvMesh.merge([EnvMesh.piece(mesh, offset, 0.5)])


## Square timber pole with a short cross-arm, a hook and a wedge of stones at the foot.
static func _pole(top: Vector3, rng: RandomNumberGenerator, frame: Array) -> void:
	var h := top.y + 0.15
	var base := Vector3(top.x, 0, top.z)
	var lean := Basis(Vector3.BACK, deg_to_rad(rng.randf_range(-1.5, 1.5))) * Basis(Vector3.RIGHT, deg_to_rad(rng.randf_range(-1.5, 1.5)))
	frame.append(EnvMesh.piece(EnvMesh.box(Vector3(0.13, h, 0.13), 0.02, 1), Transform3D(lean, base + Vector3(0, h * 0.5, 0)), rng.randf()))
	frame.append(EnvMesh.piece(EnvMesh.box(Vector3(0.55, 0.08, 0.08), 0.015, 1),
		Transform3D(lean * Basis(Vector3.UP, rng.randf() * PI), base + Vector3(0, h - 0.25, 0)), rng.randf(), Vector3.RIGHT))
	frame.append(EnvMesh.piece(EnvMesh.box(Vector3(0.2, 0.06, 0.2), 0.015, 1), Transform3D(lean, base + Vector3(0, h + 0.03, 0)), rng.randf(), Vector3.RIGHT))
	frame.append(EnvMesh.piece(EnvMesh.box(Vector3(0.26, 0.12, 0.26), 0.03, 1),
		Transform3D(Basis(Vector3.UP, rng.randf() * PI), base + Vector3(0, 0.05, 0)), rng.randf(), Vector3.RIGHT))
