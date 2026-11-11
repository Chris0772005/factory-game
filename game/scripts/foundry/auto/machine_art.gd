class_name MachineArt
## Mesh helpers and finished art for the automation machines: smooth cast
## housings (loft), ribbed hoses, finned servo motors, bolt circles, and the
## complete six-axis style grab arm. Pure presentation.


## Smooth housing swept along +Z. Each section is [z, width, height, x, y,
## power]: a superellipse (power 2 = ellipse, 4 = soft box) centred on (x, y).
## Normals are smooth across the whole skin; both ends are capped.
static func loft(sections: Array, sides := 24) -> ArrayMesh:
	var rings: Array = []
	for s: Array in sections:
		var ring := PackedVector3Array()
		var e := 2.0 / float(s[5])
		for j in sides:
			var t := TAU * j / sides
			var c := cos(t)
			var sn := sin(t)
			ring.append(Vector3(s[3] + s[1] * 0.5 * signf(c) * pow(absf(c), e), s[4] + s[2] * 0.5 * signf(sn) * pow(absf(sn), e), s[0]))
		rings.append(ring)
	var n := rings.size()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for k in n:
		var ring: PackedVector3Array = rings[k]
		var prev: PackedVector3Array = rings[maxi(k - 1, 0)]
		var next: PackedVector3Array = rings[mini(k + 1, n - 1)]
		var centre := Vector3(sections[k][3], sections[k][4], sections[k][0])
		for j in sides:
			var around := ring[(j + 1) % sides] - ring[(j + sides - 1) % sides]
			var along := next[j] - prev[j]
			var nrm := along.cross(around).normalized()
			if nrm.dot(ring[j] - centre) < 0.0:
				nrm = -nrm
			verts.append(ring[j])
			normals.append(nrm)
			uvs.append(Vector2(float(j) / sides, sections[k][0]))
	for k in n - 1:
		for j in sides:
			var a := k * sides + j
			var b := k * sides + (j + 1) % sides
			var c := (k + 1) * sides + (j + 1) % sides
			var d := (k + 1) * sides + j
			_face(indices, verts, normals[a], a, b, c)
			_face(indices, verts, normals[a], a, c, d)
	for end in [0, n - 1]:
		var out := Vector3(0, 0, -1.0 if end == 0 else 1.0)
		var base := verts.size()
		verts.append(Vector3(sections[end][3], sections[end][4], sections[end][0]))
		normals.append(out)
		uvs.append(Vector2(0.5, 0.5))
		for j in sides:
			verts.append((rings[end] as PackedVector3Array)[j])
			normals.append(out)
			uvs.append(Vector2(0.5, 0.5))
		for j in sides:
			_face(indices, verts, out, base, base + 1 + j, base + 1 + (j + 1) % sides)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Adds triangle a-b-c wound so that its front faces along `out`.
static func _face(indices: PackedInt32Array, verts: PackedVector3Array, out: Vector3, a: int, b: int, c: int) -> void:
	if (verts[c] - verts[a]).cross(verts[b] - verts[a]).dot(out) < 0.0:
		indices.append_array([a, c, b])
	else:
		indices.append_array([a, b, c])


## Catmull-Rom resample of `points`, about `step` metres between samples.
static func smooth(points: PackedVector3Array, step := 0.012) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n := points.size()
	for i in n - 1:
		var p0 := points[maxi(i - 1, 0)]
		var p1 := points[i]
		var p2 := points[i + 1]
		var p3 := points[mini(i + 2, n - 1)]
		var count := maxi(2, int(p1.distance_to(p2) / step))
		for k in count:
			var t := float(k) / count
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
	out.append(points[n - 1])
	return out


## Corrugated protective hose through `points` (ribs every other sample).
static func hose(points: PackedVector3Array, radius: float, sides := 10) -> ArrayMesh:
	var path := smooth(points, radius * 0.55)
	var radii := PackedFloat32Array()
	for i in path.size():
		radii.append(radius * (1.0 if i % 2 == 0 else 0.8))
	return StationKit.tube(path, radius, sides, true, radii)


## Plain smooth pipe through `points`.
static func pipe(points: PackedVector3Array, radius: float, sides := 10) -> ArrayMesh:
	return StationKit.tube(smooth(points, 0.012), radius, sides)


## Lathe turned so that its axis runs along `axis` (unit X, Y or Z), placed at `at`.
static func turned(profile: PackedVector2Array, axis: Vector3, at: Vector3, sides := 28) -> Array:
	var basis := Basis()
	if axis.is_equal_approx(Vector3.RIGHT):
		basis = Basis(Vector3.BACK, -PI * 0.5)
	elif axis.is_equal_approx(Vector3.LEFT):
		basis = Basis(Vector3.BACK, PI * 0.5)
	elif axis.is_equal_approx(Vector3.BACK):
		basis = Basis(Vector3.RIGHT, PI * 0.5)
	elif axis.is_equal_approx(Vector3.FORWARD):
		basis = Basis(Vector3.RIGHT, -PI * 0.5)
	elif axis.is_equal_approx(Vector3.DOWN):
		basis = Basis(Vector3.RIGHT, PI)
	return EnvMesh.piece(StationKit.lathe(profile, sides, 50.0), Transform3D(basis, at))


## Solid drum of `radius` and `length` with chamfered rims (profile from y=0).
static func drum(radius: float, length: float, chamfer := 0.012) -> PackedVector2Array:
	return PackedVector2Array([Vector2(0, 0), Vector2(radius - chamfer, 0), Vector2(radius, chamfer), Vector2(radius, length - chamfer),
		Vector2(radius - chamfer, length), Vector2(0, length)])


## Gearbox cover: a low dome with a raised rim and a centre boss (from y=0).
static func cap(radius: float, height: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(0, 0), Vector2(radius, 0), Vector2(radius, height * 0.45), Vector2(radius * 0.93, height * 0.7),
		Vector2(radius * 0.8, height * 0.7), Vector2(radius * 0.74, height * 0.5), Vector2(radius * 0.36, height * 0.5), Vector2(radius * 0.3, height),
		Vector2(0, height)])


## Servo motor body with cooling fins, a rear brake cover (profile from y=0).
static func motor(radius: float, length: float) -> PackedVector2Array:
	var p := PackedVector2Array([Vector2(0, 0), Vector2(radius * 1.12, 0), Vector2(radius * 1.12, length * 0.1), Vector2(radius * 0.86, length * 0.12)])
	var fins := 7
	var from := length * 0.14
	var span := length * 0.5
	for i in fins:
		var y := from + span * i / fins
		var h := span / fins
		p.append(Vector2(radius * 0.86, y))
		p.append(Vector2(radius, y + h * 0.15))
		p.append(Vector2(radius, y + h * 0.55))
		p.append(Vector2(radius * 0.86, y + h * 0.7))
	p.append_array([Vector2(radius * 0.86, length * 0.66), Vector2(radius * 0.95, length * 0.68), Vector2(radius * 0.95, length * 0.94),
		Vector2(radius * 0.8, length), Vector2(0, length)])
	return p


## Hex bolt heads with washers on a circle around `axis` (unit X, Y or Z) at `at`.
static func bolt_circle(axis: Vector3, at: Vector3, radius: float, count: int, size := 0.014) -> Array:
	var out := []
	var u := Vector3.UP if absf(axis.y) < 0.5 else Vector3.RIGHT
	var v := axis.cross(u)
	for k in count:
		var a := TAU * (k + 0.5) / count
		var p := at + (u * cos(a) + v * sin(a)) * radius
		out.append(turned(PackedVector2Array([Vector2(0, 0), Vector2(size * 1.5, 0), Vector2(size * 1.5, size * 0.25), Vector2(size, size * 0.25),
			Vector2(size, size * 1.1), Vector2(size * 0.8, size * 1.3), Vector2(0, size * 1.3)]), axis, p, 6))
	return out


static func black_mat() -> ShaderMaterial:
	return StationKit.metal("arm_black", {steel_color = Color("#1d1e21"), rust = 0.03, dents = 0.04, metallic_steel = 0.35, roughness_steel = 0.5})


static func graphite_mat() -> ShaderMaterial:
	return StationKit.metal("arm_graphite", {steel_color = Color("#3a3c41"), rust = 0.06, dents = 0.05, metallic_steel = 0.5, roughness_steel = 0.45})


static func steel_mat() -> ShaderMaterial:
	return StationKit.metal("arm_steel", {steel_color = Color("#aab0b8"), rust = 0.04, dents = 0.05, metallic_steel = 0.9, roughness_steel = 0.28})


static func blue_mat() -> ShaderMaterial:
	return StationKit.metal("line_paint", {steel_color = Color("#56606a"), paint = 0.9, paint_color = Color("#2d6480"), rust = 0.22, dents = 0.12,
		metallic_steel = 0.4, roughness_steel = 0.45, roughness_paint = 0.5})


static func yellow_mat() -> ShaderMaterial:
	return StationKit.metal("line_yellow", {steel_color = Color("#6a6d70"), paint = 0.88, paint_color = Color("#d3a01e"), rust = 0.2, dents = 0.1, roughness_paint = 0.5})


# --- The grab arm --------------------------------------------------------------

## Dresses the arm rig. `rig` = {base, turret, shoulder, elbow, wrist,
## fingers: Array[Node3D]}; the shoulder and elbow turn about X and their
## links run along +Z (`upper`, `fore` long); the turret sits `height` up.
static func arm(rig: Dictionary, upper: float, fore: float, height: float) -> void:
	var base: Node3D = rig.base
	var turret: Node3D = rig.turret
	var shoulder: Node3D = rig.shoulder
	var elbow: Node3D = rig.elbow
	var wrist: Node3D = rig.wrist
	var paint := StationKit.metal("arm_cast", {steel_color = Color("#6a6d70"), paint = 0.985, paint_color = Color("#d4401c"), rust = 0.04, dents = 0.04,
		metallic_steel = 0.35, roughness_steel = 0.4, roughness_paint = 0.24, dust = 0.2, grime = 0.22})
	var black := black_mat()
	var graphite := graphite_mat()
	var steel := steel_mat()
	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color("#141416")
	rubber.roughness = 0.75

	# -- Base: floor flange, cast foot, slewing ring, plug box, supply hoses.
	var ring_y := height - 0.2
	var foot := [turned(PackedVector2Array([Vector2(0, 0), Vector2(0.4, 0), Vector2(0.4, 0.03), Vector2(0.385, 0.045), Vector2(0.33, 0.05), Vector2(0.29, 0.075),
		Vector2(0.255, 0.16), Vector2(0.24, ring_y - 0.16), Vector2(0.25, ring_y - 0.09), Vector2(0.285, ring_y - 0.06), Vector2(0.285, ring_y - 0.012),
		Vector2(0, ring_y - 0.012)]), Vector3.UP, Vector3.ZERO, 40)]
	for k in 4:
		var a := TAU * (k + 0.5) / 4.0
		foot.append(EnvMesh.piece(EnvMesh.box(Vector3(0.04, 0.1, 0.13), 0.014, 2), Transform3D(Basis(Vector3.UP, a), Vector3(sin(a), 0, cos(a)) * 0.3 + Vector3(0, 0.085, 0))))
	StationKit.add_merged(base, foot, graphite)
	# Floor plate the robot is bolted to, with a painted safety edge.
	StationKit.add(base, EnvMesh.box(Vector3(1.05, 0.03, 1.05), 0.008, 2), graphite, Transform3D(Basis(), Vector3(0, 0.015, 0)))
	var plate_hw := []
	for k in 4:
		var pa := TAU * (k + 0.5) / 4.0
		plate_hw.append_array(bolt_circle(Vector3.UP, Vector3(sin(pa), 0, cos(pa)) * 0.66 + Vector3(0, 0.03, 0), 0.0, 1, 0.02))
	StationKit.add_merged(base, plate_hw, steel)
	var seam := [turned(drum(0.268, 0.024, 0.004), Vector3.UP, Vector3(0, ring_y - 0.012, 0), 40)]
	seam.append(EnvMesh.piece(EnvMesh.box(Vector3(0.24, 0.17, 0.1), 0.02, 2), Transform3D(Basis(), Vector3(0, 0.3, -0.27))))
	StationKit.add_merged(base, seam, graphite)
	var hardware := bolt_circle(Vector3.UP, Vector3(0, 0.045, 0), 0.355, 8, 0.017)
	for k in 3:
		hardware.append(turned(drum(0.024, 0.035, 0.004), Vector3.FORWARD, Vector3(-0.075 + k * 0.075, 0.3, -0.32), 12))
	StationKit.add_merged(base, hardware, steel)
	for k in 3:
		var x := -0.075 + k * 0.075
		StationKit.add(base, hose(PackedVector3Array([Vector3(x, 0.3, -0.35), Vector3(x * 1.3, 0.27, -0.45), Vector3(x * 1.8, 0.07, -0.52), Vector3(x * 2.4, 0.022, -0.7),
			Vector3(x * 2.6, 0.022, -0.95)]), 0.02), rubber)
	var yaw := atan2(-base.position.x, -base.position.z)
	StationKit.label(base, "MM · GREIFER 01", Transform3D(Basis(Vector3.UP, yaw), Vector3(0, 0.4, 0) + Basis(Vector3.UP, yaw) * Vector3(0, 0, 0.252)), 30, Color("#2a2320"), 800, 0.001)

	# -- Turret: carousel, two keyhole cheeks, gearbox covers, drive motors.
	var body := [turned(PackedVector2Array([Vector2(0, -0.188), Vector2(0.262, -0.188), Vector2(0.27, -0.15), Vector2(0.25, -0.1), Vector2(0.21, -0.07), Vector2(0.0, -0.07)]),
		Vector3.UP, Vector3.ZERO, 40)]
	for s: float in [-1.0, 1.0]:
		body.append(turned(drum(0.175, 0.075, 0.016), Vector3.RIGHT, Vector3(s * 0.172 - 0.0375, 0, 0), 36))
		body.append(EnvMesh.piece(EnvMesh.box(Vector3(0.075, 0.2, 0.3), 0.022, 3), Transform3D(Basis(), Vector3(s * 0.172, -0.1, 0))))
	body.append(EnvMesh.piece(EnvMesh.box(Vector3(0.3, 0.07, 0.34), 0.025, 3), Transform3D(Basis(), Vector3(0, -0.11, 0))))
	StationKit.add_merged(turret, body, paint)
	var covers := []
	covers.append(turned(cap(0.135, 0.035), Vector3.LEFT, Vector3(-0.21, 0, 0), 32))
	covers.append(turned(drum(0.1, 0.06, 0.01), Vector3.RIGHT, Vector3(0.2, 0, 0), 28))
	covers.append(turned(motor(0.082, 0.3), Vector3.RIGHT, Vector3(0.255, 0, 0), 28))
	covers.append(EnvMesh.piece(EnvMesh.box(Vector3(0.1, 0.06, 0.09), 0.012, 2), Transform3D(Basis(), Vector3(0.44, 0.095, 0))))
	covers.append(turned(motor(0.07, 0.26), Vector3.UP, Vector3(0, -0.08, -0.2), 28))
	covers.append(EnvMesh.piece(EnvMesh.box(Vector3(0.09, 0.08, 0.06), 0.012, 2), Transform3D(Basis(), Vector3(0, 0.1, -0.285))))
	StationKit.add_merged(turret, covers, black)
	var t_hw := bolt_circle(Vector3.LEFT, Vector3(-0.232, 0, 0), 0.115, 10, 0.011)
	t_hw.append_array(bolt_circle(Vector3.RIGHT, Vector3(0.2105, 0, 0), 0.15, 8, 0.011))
	StationKit.add_merged(turret, t_hw, steel)
	StationKit.add(turret, hose(PackedVector3Array([Vector3(0.44, 0.125, 0.0), Vector3(0.43, 0.2, -0.05), Vector3(0.3, 0.22, -0.2), Vector3(0.1, 0.19, -0.3), Vector3(0.03, 0.14, -0.3)]), 0.017), rubber)

	# -- Upper arm: one cast link, drifting to the left towards the elbow.
	var e_x := -0.085
	var link := [EnvMesh.piece(loft([
		[-0.17, 0.1, 0.1, 0.0, 0.0, 2.6], [-0.13, 0.2, 0.24, 0.0, 0.0, 3.0], [-0.03, 0.24, 0.31, 0.0, 0.0, 3.2], [0.1, 0.235, 0.3, 0.0, 0.0, 3.2],
		[0.26, 0.19, 0.23, -0.02, 0.0, 3.4], [0.46, 0.15, 0.175, -0.05, 0.0, 3.6], [upper - 0.36, 0.14, 0.165, e_x, 0.0, 3.6],
		[upper - 0.2, 0.145, 0.2, e_x, 0.0, 3.4], [upper - 0.06, 0.15, 0.255, e_x, 0.0, 3.2], [upper + 0.06, 0.15, 0.25, e_x, 0.0, 3.0],
		[upper + 0.13, 0.13, 0.18, e_x, 0.0, 2.8], [upper + 0.155, 0.07, 0.08, e_x, 0.0, 2.6]], 28), Transform3D())]
	# A stiffening rib along the spine and a pad for the hose clamps.
	link.append(EnvMesh.piece(loft([[0.2, 0.03, 0.03, -0.02, 0.12, 3.0], [0.3, 0.04, 0.06, -0.03, 0.105, 3.0], [upper - 0.4, 0.04, 0.06, e_x, 0.08, 3.0],
		[upper - 0.28, 0.03, 0.03, e_x, 0.09, 3.0]], 12), Transform3D()))
	StationKit.add_merged(shoulder, link, paint)
	var s_cov := [turned(cap(0.115, 0.03), Vector3.LEFT, Vector3(e_x - 0.075, 0, upper), 32)]
	s_cov.append(EnvMesh.piece(EnvMesh.box(Vector3(0.05, 0.06, 0.09), 0.012, 2), Transform3D(Basis(), Vector3(0.1, 0.13, 0.08))))
	s_cov.append(EnvMesh.piece(EnvMesh.box(Vector3(0.05, 0.05, 0.08), 0.012, 2), Transform3D(Basis(), Vector3(e_x + 0.045, 0.12, upper - 0.13))))
	StationKit.add_merged(shoulder, s_cov, black)
	StationKit.add_merged(shoulder, bolt_circle(Vector3.LEFT, Vector3(e_x - 0.094, 0, upper), 0.098, 8, 0.01), steel)
	StationKit.add(shoulder, hose(PackedVector3Array([Vector3(0.1, 0.16, 0.1), Vector3(0.085, 0.2, 0.22), Vector3(0.04, 0.165, 0.42), Vector3(e_x + 0.07, 0.15, upper - 0.45),
		Vector3(e_x + 0.06, 0.17, upper - 0.25), Vector3(e_x + 0.045, 0.145, upper - 0.15)]), 0.019), rubber)
	for off: float in [-0.034, 0.034]:
		StationKit.add(shoulder, hose(PackedVector3Array([Vector3(0.1 + off, 0.15, 0.1), Vector3(0.085 + off, 0.185, 0.22), Vector3(0.04 + off, 0.15, 0.42),
			Vector3(e_x + 0.07 + off, 0.135, upper - 0.45), Vector3(e_x + 0.06 + off, 0.155, upper - 0.25), Vector3(e_x + 0.045 + off, 0.13, upper - 0.15)]), 0.014), rubber)
	var clamps := []
	for z: float in [0.42, upper - 0.45]:
		var x := 0.04 if z < 0.5 else e_x + 0.07
		var y := 0.165 if z < 0.5 else 0.15
		clamps.append(turned(drum(0.026, 0.02, 0.003), Vector3.BACK, Vector3(x, y, z - 0.01), 14))
		clamps.append(EnvMesh.piece(EnvMesh.box(Vector3(0.02, 0.07, 0.02), 0.004), Transform3D(Basis(), Vector3(x, y - 0.04, z))))
	StationKit.add_merged(shoulder, clamps, steel)
	for s: float in [-1.0, 1.0]:
		StationKit.label(shoulder, "MM-60", Transform3D(Basis(Vector3.UP, s * PI * 0.5), Vector3(e_x + s * 0.0735, 0, upper - 0.28)), 34,
			Color("#2a2320"), 800, 0.0011)

	# -- Elbow and forearm: drum through both links, forearm on the right.
	var f_x := 0.08
	var arm_parts := [turned(drum(0.118, 0.19, 0.014), Vector3.RIGHT, Vector3(-0.01, 0, 0), 32)]
	arm_parts.append(EnvMesh.piece(loft([
		[-0.2, 0.1, 0.11, f_x, 0.0, 3.0], [-0.17, 0.15, 0.19, f_x, 0.0, 3.4], [-0.06, 0.16, 0.25, f_x, 0.0, 3.2], [0.07, 0.16, 0.245, f_x, 0.0, 3.2],
		[0.2, 0.145, 0.185, f_x * 0.8, 0.0, 3.4], [0.4, 0.12, 0.14, f_x * 0.4, 0.0, 3.6], [fore - 0.32, 0.105, 0.115, 0.0, 0.0, 3.4],
		[fore - 0.2, 0.11, 0.12, 0.0, 0.0, 3.0], [fore - 0.13, 0.125, 0.13, 0.0, 0.0, 2.6], [fore - 0.1, 0.1, 0.1, 0.0, 0.0, 2.4]], 28), Transform3D()))
	StationKit.add_merged(elbow, arm_parts, paint)
	var f_black := [turned(cap(0.1, 0.03), Vector3.RIGHT, Vector3(0.18, 0, 0), 32)]
	for s: float in [-1.0, 1.0]:
		f_black.append(turned(motor(0.043, 0.2), Vector3.FORWARD, Vector3(f_x + s * 0.048, 0.03, -0.19), 20))
	f_black.append(turned(motor(0.04, 0.17), Vector3.FORWARD, Vector3(f_x, -0.055, -0.19), 20))
	f_black.append(turned(drum(0.062, 0.15, 0.008), Vector3.RIGHT, Vector3(-0.075, 0, fore - 0.045), 24))
	f_black.append(EnvMesh.piece(EnvMesh.box(Vector3(0.045, 0.04, 0.06), 0.01, 2), Transform3D(Basis(), Vector3(0.0, 0.065, fore - 0.17))))
	f_black.append(EnvMesh.piece(EnvMesh.box(Vector3(0.05, 0.05, 0.06), 0.01, 2), Transform3D(Basis(), Vector3(f_x - 0.02, 0.1, -0.13))))
	StationKit.add_merged(elbow, f_black, black)
	var f_hw := bolt_circle(Vector3.RIGHT, Vector3(0.196, 0, 0), 0.085, 8, 0.01)
	f_hw.append(turned(drum(0.068, 0.02, 0.004), Vector3.BACK, Vector3(0, 0, fore - 0.105), 24))
	StationKit.add_merged(elbow, f_hw, steel)
	StationKit.add(elbow, hose(PackedVector3Array([Vector3(f_x - 0.02, 0.1, -0.12), Vector3(f_x - 0.03, 0.175, -0.02), Vector3(f_x * 0.8, 0.14, 0.2), Vector3(f_x * 0.4, 0.1, 0.42),
		Vector3(0.0, 0.085, fore - 0.3), Vector3(0.0, 0.07, fore - 0.18)]), 0.016), rubber)
	StationKit.label(elbow, "400 V", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(f_x + 0.081, 0.0, 0.0)), 22, Color("#2a2320"), 800, 0.001)

	# -- Wrist flange and gripper.
	var hand := [turned(PackedVector2Array([Vector2(0, -0.02), Vector2(0.05, -0.02), Vector2(0.05, 0.01), Vector2(0.075, 0.015), Vector2(0.075, 0.035), Vector2(0, 0.035)]),
		Vector3.BACK, Vector3.ZERO, 28)]
	hand.append_array(bolt_circle(Vector3.BACK, Vector3(0, 0, 0.035), 0.06, 6, 0.008))
	hand.append(turned(drum(0.02, 0.2, 0.004), Vector3.UP, Vector3(0.0, -0.1, 0.085), 14))
	StationKit.add_merged(wrist, hand, steel)
	var palm := [EnvMesh.piece(EnvMesh.box(Vector3(0.13, 0.17, 0.075), 0.02, 3), Transform3D(Basis(), Vector3(0, 0, 0.075)))]
	palm.append(EnvMesh.piece(EnvMesh.box(Vector3(0.05, 0.05, 0.05), 0.012, 2), Transform3D(Basis(), Vector3(0.085, 0, 0.07))))
	StationKit.add_merged(wrist, palm, graphite)
	StationKit.add(wrist, hose(PackedVector3Array([Vector3(0.1, 0, 0.05), Vector3(0.12, 0.02, -0.02), Vector3(0.07, 0.06, -0.1), Vector3(0.02, 0.07, -0.16)]), 0.011, 8), rubber)
	var fingers: Array = rig.fingers
	for i in fingers.size():
		var s := 1.0 if i == 0 else -1.0
		var claw := [EnvMesh.piece(loft([[0.0, 0.085, 0.035, 0.0, 0.0, 3.5], [0.1, 0.08, 0.03, 0.0, 0.0, 3.5], [0.17, 0.075, 0.026, 0.0, -s * 0.012, 3.5],
			[0.23, 0.07, 0.022, 0.0, -s * 0.04, 3.5], [0.27, 0.06, 0.014, 0.0, -s * 0.065, 3.0]], 16), Transform3D())]
		for k in 4:
			claw.append(EnvMesh.piece(EnvMesh.box(Vector3(0.07, 0.008, 0.012), 0.002), Transform3D(Basis(), Vector3(0, -s * 0.02, 0.07 + k * 0.03))))
		claw.append(turned(drum(0.014, 0.1, 0.003), Vector3.RIGHT, Vector3(-0.05, 0, 0.0), 12))
		StationKit.add_merged(fingers[i], claw, steel)

	# -- Beacon: amber dome on a stem on the turret.
	var stem := [turned(drum(0.012, 0.1, 0.002), Vector3.UP, Vector3(-0.172, 0.17, -0.05), 10), turned(drum(0.034, 0.014, 0.003), Vector3.UP, Vector3(-0.172, 0.27, -0.05), 16)]
	StationKit.add_merged(turret, stem, black)
	var amber := StandardMaterial3D.new()
	amber.albedo_color = Color("#e09324")
	amber.roughness = 0.25
	amber.emission_enabled = true
	amber.emission = Color("#ffb347")
	amber.emission_energy_multiplier = 1.6
	var dome := StationKit.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.03, 0), Vector2(0.03, 0.035), Vector2(0.026, 0.05), Vector2(0.016, 0.06), Vector2(0, 0.063)]), 16, 70.0)
	StationKit.add(turret, dome, amber, Transform3D(Basis(), Vector3(-0.172, 0.284, -0.05)), false)


# --- The conveyor --------------------------------------------------------------

## Dresses a belt frame: local +X runs up the belt (`length`), +Y is the
## belt normal, Z across (`width`). Returns the belt's scrolling material.
static func conveyor(belt: Node3D, length: float, width: float) -> ShaderMaterial:
	var half := width * 0.5
	var paint := blue_mat()
	var steel := steel_mat()
	var graphite := graphite_mat()
	var black := black_mat()
	var yellow := yellow_mat()
	# The belt runs around both drums and back underneath.
	var drum_r := 0.07
	var loop: Array[Vector2] = [Vector2(0, 0.04)]
	var steps := maxi(4, int(length / 0.25))
	for i in steps:
		loop.append(Vector2(length * (i + 1) / steps, 0.04))
	for i in range(1, 11):
		var a := PI * i / 10.0
		loop.append(Vector2(length + drum_r * sin(a), -0.03 + drum_r * cos(a)))
	for i in steps:
		loop.append(Vector2(length * (1.0 - float(i + 1) / steps), -0.1))
	for i in range(1, 11):
		var a := PI * i / 10.0
		loop.append(Vector2(-drum_r * sin(a), -0.03 - drum_r * cos(a)))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dist := 0.0
	var bw := half - 0.025
	for i in loop.size() - 1:
		var p := loop[i]
		var q := loop[i + 1]
		var d := (q - p).normalized()
		var nrm := Vector3(-d.y, d.x, 0)
		var seg := p.distance_to(q)
		var v := [[Vector3(p.x, p.y, -bw), Vector2(dist, 0)], [Vector3(q.x, q.y, -bw), Vector2(dist + seg, 0)],
			[Vector3(q.x, q.y, bw), Vector2(dist + seg, 1)], [Vector3(p.x, p.y, bw), Vector2(dist, 1)]]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_normal(nrm)
			st.set_uv(v[idx][1])
			st.add_vertex(v[idx][0])
		dist += seg
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/fx_belt.gdshader")
	StationKit.add(belt, st.commit(), mat)
	# Drums with shafts, return rollers, the discharge lip.
	var turning := []
	for x: float in [0.0, length]:
		turning.append(turned(drum(drum_r - 0.004, width - 0.03, 0.006), Vector3.BACK, Vector3(x, -0.03, -half + 0.015), 24))
		turning.append(turned(drum(0.02, width + 0.17, 0.004), Vector3.BACK, Vector3(x, -0.03, -half - 0.085), 12))
	for k in int(length / 0.42):
		turning.append(turned(drum(0.022, width - 0.03, 0.004), Vector3.BACK, Vector3(0.3 + k * 0.42, -0.128, -half + 0.015), 12))
	turning.append(EnvMesh.piece(EnvMesh.box(Vector3(0.2, 0.012, width - 0.05), 0.004), Transform3D(Basis(Vector3.BACK, -0.75), Vector3(length + 0.13, -0.06, 0))))
	# Side channels: web, two flanges, bolts; bearing blocks at the drums.
	var frame := []
	var blocks := []
	for s: float in [-1.0, 1.0]:
		frame.append(EnvMesh.piece(EnvMesh.box(Vector3(length + 0.3, 0.19, 0.014), 0.005, 2), Transform3D(Basis(), Vector3(length * 0.5, -0.03, s * (half + 0.012)))))
		for y: float in [0.058, -0.118]:
			frame.append(EnvMesh.piece(EnvMesh.box(Vector3(length + 0.3, 0.014, 0.055), 0.005, 2), Transform3D(Basis(), Vector3(length * 0.5, y, s * (half + 0.032)))))
		var axis := Vector3.BACK if s > 0.0 else Vector3.FORWARD
		for k in int(length / 0.3):
			turning.append_array(bolt_circle(axis, Vector3(0.42 + k * 0.3, -0.03, s * (half + 0.019)), 0.0, 1, 0.011))
		for x: float in [0.0, length]:
			blocks.append(EnvMesh.piece(EnvMesh.box(Vector3(0.13, 0.11, 0.045), 0.015, 3), Transform3D(Basis(), Vector3(x, -0.03, s * (half + 0.042)))))
			turning.append(turned(cap(0.038, 0.014), axis, Vector3(x, -0.03, s * (half + 0.064)), 20))
	StationKit.add_merged(belt, frame, paint)
	StationKit.add_merged(belt, blocks, graphite)
	StationKit.add_merged(belt, turning, steel)
	# Guard rails: round tube with bent ends on round posts.
	for s: float in [-1.0, 1.0]:
		var z := s * (half + 0.055)
		var from := minf(0.75, length * 0.5)
		StationKit.add(belt, pipe(PackedVector3Array([Vector3(from, 0.06, z), Vector3(from, 0.17, z), Vector3(from + 0.03, 0.225, z), Vector3(from + 0.09, 0.25, z), Vector3(length - 0.21, 0.25, z),
			Vector3(length - 0.15, 0.225, z), Vector3(length - 0.12, 0.17, z), Vector3(length - 0.12, 0.06, z)]), 0.014), yellow)
		var mid := (from + length - 0.12) * 0.5
		if length - from > 1.0:
			StationKit.add(belt, pipe(PackedVector3Array([Vector3(mid, 0.06, z), Vector3(mid, 0.25, z)]), 0.012), yellow)
	# Drive: gearbox on the head shaft, finned motor, terminal box, conduit.
	var drive := [turned(motor(0.062, 0.23), Vector3.BACK, Vector3(length, -0.03, half + 0.17), 28)]
	drive.append(EnvMesh.piece(EnvMesh.box(Vector3(0.08, 0.045, 0.08), 0.012, 2), Transform3D(Basis(), Vector3(length, 0.05, half + 0.28))))
	StationKit.add_merged(belt, drive, black)
	StationKit.add(belt, EnvMesh.box(Vector3(0.15, 0.16, 0.11), 0.028, 3), graphite, Transform3D(Basis(), Vector3(length, -0.03, half + 0.12)))
	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color("#141416")
	rubber.roughness = 0.75
	StationKit.add(belt, hose(PackedVector3Array([Vector3(length - 0.04, 0.05, half + 0.28), Vector3(length - 0.16, 0.045, half + 0.26), Vector3(length - 0.3, -0.05, half + 0.12),
		Vector3(length - 0.45, -0.14, half + 0.06), Vector3(length - 0.8, -0.15, half + 0.05)]), 0.014, 8), rubber)
	# Loading end: sloped skirt boards with rubber wipers keep the scrap on the belt.
	var skirts := []
	var wipers := []
	var skirt_len := minf(0.62, length * 0.35)
	for s: float in [-1.0, 1.0]:
		var lean := Basis(Vector3.RIGHT, s * 0.38)
		skirts.append(EnvMesh.piece(EnvMesh.box(Vector3(skirt_len, 0.17, 0.008), 0.003), Transform3D(lean, Vector3(skirt_len * 0.5 + 0.06, 0.15, s * (half + 0.012)))))
		wipers.append(EnvMesh.piece(EnvMesh.box(Vector3(skirt_len - 0.03, 0.05, 0.007), 0.002), Transform3D(lean, Vector3(skirt_len * 0.5 + 0.06, 0.066, s * (half - 0.03)))))
		for k in 3:
			skirts.append(EnvMesh.piece(EnvMesh.box(Vector3(0.03, 0.06, 0.012), 0.003), Transform3D(lean, Vector3(0.12 + k * (skirt_len - 0.12) * 0.5, 0.095, s * (half - 0.012)))))
		# Take-up screws at the tail keep the belt tight.
		turning = [turned(drum(0.008, 0.2, 0.002), Vector3.RIGHT, Vector3(-0.22, -0.03, s * (half + 0.042)), 10),
			turned(drum(0.016, 0.014, 0.003), Vector3.RIGHT, Vector3(-0.1, -0.03, s * (half + 0.042)), 6)]
		StationKit.add_merged(belt, turning, steel)
	StationKit.add_merged(belt, skirts, paint)
	StationKit.add_merged(belt, wipers, rubber)
	# Emergency stop on the walkway side, nip guard with warning stripes at the head drum.
	var red := StationKit.metal("line_red", {steel_color = Color("#5a5d60"), paint = 0.95, paint_color = Color("#b3261c"), rust = 0.05, dents = 0.03, roughness_paint = 0.35, dust = 0.2})
	StationKit.add(belt, EnvMesh.box(Vector3(0.08, 0.1, 0.05), 0.008, 2), yellow, Transform3D(Basis(), Vector3(0.34, -0.03, -(half + 0.045))))
	StationKit.add_merged(belt, [turned(PackedVector2Array([Vector2(0, 0), Vector2(0.012, 0), Vector2(0.012, 0.012), Vector2(0.026, 0.014), Vector2(0.028, 0.022), Vector2(0.02, 0.03), Vector2(0, 0.032)]),
		Vector3.FORWARD, Vector3(0.34, -0.02, -(half + 0.07)), 18)], red)
	var guard := [EnvMesh.piece(EnvMesh.box(Vector3(0.26, 0.2, 0.006), 0.003), Transform3D(Basis(), Vector3(length + 0.01, -0.03, -(half + 0.07))))]
	StationKit.add_merged(belt, guard, yellow)
	var bars := []
	for k in 4:
		bars.append(EnvMesh.piece(EnvMesh.box(Vector3(0.03, 0.27, 0.002)), Transform3D(Basis(Vector3.BACK, 0.7), Vector3(length - 0.085 + k * 0.065, -0.03, -(half + 0.0745)))))
	StationKit.add_merged(belt, bars, black)
	return mat


## Machine foot: threaded stem with a round pad (lathe profile from y=0).
static func foot_pad() -> PackedVector2Array:
	return PackedVector2Array([Vector2(0, 0), Vector2(0.055, 0), Vector2(0.055, 0.012), Vector2(0.03, 0.022), Vector2(0.012, 0.026), Vector2(0.012, 0.07), Vector2(0, 0.07)])
