class_name PlankFence
## Weathered wooden fences around the yard: tall privacy boards on the sides
## and back, a low painted picket fence at the front (the camera looks over
## it), a closed board gate on the right. Boards are one MultiMesh per kind
## (each board slightly different in height and tilt, the odd one missing or
## crooked); posts and rails on the yard side are merged into one mesh.
## Each straight run gets one box collider.

enum Kind { PRIVACY, PICKET }

const PRIVACY_HEIGHT := 1.55
const PICKET_HEIGHT := 0.95
const POST_SPACING := 2.4


## Builds every fence line of the backyard under `parent`.
static func build_yard(parent: Node3D) -> void:
	var lo := YardLayout.YARD_MIN
	var hi := YardLayout.YARD_MAX
	var gate_half := 0.7
	var lines := [
		# [from, to, kind, inward normal (x, z)]
		[Vector2(lo.x, lo.y), Vector2(YardLayout.HOUSE_X.x, lo.y), Kind.PRIVACY, Vector2(0, 1)],
		[Vector2(YardLayout.HOUSE_X.y, lo.y), Vector2(hi.x, lo.y), Kind.PRIVACY, Vector2(0, 1)],
		[Vector2(lo.x, lo.y), Vector2(lo.x, hi.y), Kind.PRIVACY, Vector2(1, 0)],
		[Vector2(hi.x, lo.y), Vector2(hi.x, YardLayout.GATE_Z - gate_half), Kind.PRIVACY, Vector2(-1, 0)],
		[Vector2(hi.x, YardLayout.GATE_Z + gate_half), Vector2(hi.x, hi.y), Kind.PRIVACY, Vector2(-1, 0)],
		[Vector2(lo.x, hi.y), Vector2(hi.x, hi.y), Kind.PICKET, Vector2(0, -1)],
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	var boards := {Kind.PRIVACY: [], Kind.PICKET: []}
	var frame := {Kind.PRIVACY: [], Kind.PICKET: []}
	for line in lines:
		_line(parent, line[0], line[1], line[2], line[3], rng, boards[line[2]], frame[line[2]])
	_gate(parent, Vector2(hi.x, YardLayout.GATE_Z), gate_half * 2.0, rng, boards[Kind.PRIVACY], frame[Kind.PRIVACY])
	if not EnvMesh.visual():
		return
	var weathered := EnvMesh.wood("fence", {base_color = Color("#7f6d5d"), weathering = 0.5})
	var painted := EnvMesh.wood("picket", {base_color = Color("#8c6a4e"), weathering = 0.3,
		paint_color = Color("#e6dccb"), paint = 0.78})
	_board_multimesh(parent, _board_mesh(Vector3(0.14, PRIVACY_HEIGHT, 0.045)), boards[Kind.PRIVACY], weathered)
	_board_multimesh(parent, _picket_mesh(0.11, PICKET_HEIGHT, 0.04), boards[Kind.PICKET], painted)
	EnvMesh.add(parent, EnvMesh.merge(frame[Kind.PRIVACY]), weathered)
	EnvMesh.add(parent, EnvMesh.merge(frame[Kind.PICKET]), painted)


static func _line(parent: Node3D, a: Vector2, b: Vector2, kind: Kind, inward: Vector2, rng: RandomNumberGenerator,
		boards: Array, frame: Array) -> void:
	var height := PRIVACY_HEIGHT if kind == Kind.PRIVACY else PICKET_HEIGHT
	var pitch := 0.175 if kind == Kind.PRIVACY else 0.2
	var thick := 0.045 if kind == Kind.PRIVACY else 0.04
	var dir := (b - a).normalized()
	var length := a.distance_to(b)
	var yaw := atan2(-dir.y, dir.x)
	var basis := Basis(Vector3.UP, yaw)
	var mid := (a + b) * 0.5
	WorldBuilder.add_collider(parent, Vector3(length, height + 0.05, 0.22),
		Transform3D(basis, Vector3(mid.x, (height + 0.05) * 0.5, mid.y)))
	var n3 := Vector3(inward.x, 0, inward.y)
	# Boards.
	var count := int(length / pitch)
	var start := (length - (count - 1) * pitch) * 0.5
	for i in count:
		var t := start + i * pitch
		var p := a + dir * t
		var roll := rng.randf()
		if roll < 0.025:
			continue
		var tilt := rng.randf_range(-1.2, 1.2) + (rng.randf_range(-7.0, 7.0) if roll > 0.985 else 0.0)
		var h := rng.randf_range(-0.035, 0.025)
		var b3 := basis * Basis(Vector3.BACK, deg_to_rad(tilt)) * Basis(Vector3.UP, deg_to_rad(rng.randf_range(-2.0, 2.0)))
		boards.append(Transform3D(b3, Vector3(p.x, height * 0.5 + h, p.y)))
	# Posts (yard side) with caps, and two rails.
	var posts := int(ceil(length / POST_SPACING))
	for i in posts + 1:
		var p := a + dir * (length * i / posts)
		var c := Vector3(p.x, 0, p.y) + n3 * (thick * 0.5 + 0.06)
		var ph := height + 0.08
		frame.append(EnvMesh.piece(EnvMesh.box(Vector3(0.11, ph, 0.11), 0.02, 1),
			Transform3D(basis * Basis(Vector3.BACK, deg_to_rad(rng.randf_range(-1.0, 1.0))), c + Vector3(0, ph * 0.5, 0)), rng.randf()))
		frame.append(EnvMesh.piece(EnvMesh.box(Vector3(0.15, 0.035, 0.15), 0.012, 1),
			Transform3D(basis, c + Vector3(0, ph + 0.015, 0)), rng.randf(), Vector3.RIGHT))
	var rails := [0.28, height - 0.3] if kind == Kind.PRIVACY else [0.22, height - 0.28]
	for ry in rails:
		var c := Vector3(mid.x, ry, mid.y) + n3 * (thick * 0.5 + 0.025)
		frame.append(EnvMesh.piece(EnvMesh.box(Vector3(length, 0.085, 0.045), 0.012, 1),
			Transform3D(basis, c), rng.randf(), Vector3.RIGHT))


## Closed board gate with a Z brace and a latch, centred at `c` on the right fence.
static func _gate(parent: Node3D, c: Vector2, width: float, rng: RandomNumberGenerator, boards: Array, frame: Array) -> void:
	var basis := Basis(Vector3.UP, PI * 0.5)
	WorldBuilder.add_collider(parent, Vector3(width, PRIVACY_HEIGHT, 0.22), Transform3D(basis, Vector3(c.x, PRIVACY_HEIGHT * 0.5, c.y)))
	var inward := Vector3(-1, 0, 0)
	var count := 7
	for i in count:
		var z := c.y - width * 0.5 + 0.12 + i * (width - 0.24) / (count - 1)
		var b3 := basis * Basis(Vector3.BACK, deg_to_rad(rng.randf_range(-0.8, 0.8)))
		boards.append(Transform3D(b3, Vector3(c.x, PRIVACY_HEIGHT * 0.5 - 0.06, z)))
	for side: float in [-1.0, 1.0]:
		var p := Vector3(c.x, 0, c.y + side * (width * 0.5 + 0.02)) + inward * 0.08
		frame.append(EnvMesh.piece(EnvMesh.box(Vector3(0.14, PRIVACY_HEIGHT + 0.16, 0.14), 0.02, 1),
			Transform3D(basis, p + Vector3(0, (PRIVACY_HEIGHT + 0.16) * 0.5, 0)), rng.randf()))
		frame.append(EnvMesh.piece(EnvMesh.box(Vector3(0.19, 0.04, 0.19), 0.015, 1),
			Transform3D(basis, p + Vector3(0, PRIVACY_HEIGHT + 0.18, 0)), rng.randf(), Vector3.RIGHT))
	var span := width - 0.2
	for ry: float in [0.32, PRIVACY_HEIGHT - 0.42]:
		frame.append(EnvMesh.piece(EnvMesh.box(Vector3(span, 0.1, 0.045), 0.012, 1),
			Transform3D(basis, Vector3(c.x, ry, c.y) + inward * 0.045), rng.randf(), Vector3.RIGHT))
	var diag_len := Vector2(span, PRIVACY_HEIGHT - 0.74).length()
	var diag_angle := atan2(PRIVACY_HEIGHT - 0.74, span)
	frame.append(EnvMesh.piece(EnvMesh.box(Vector3(diag_len, 0.09, 0.04), 0.012, 1),
		Transform3D(basis * Basis(Vector3.BACK, diag_angle), Vector3(c.x, (0.32 + PRIVACY_HEIGHT - 0.42) * 0.5, c.y) + inward * 0.05),
		rng.randf(), Vector3.RIGHT))
	if EnvMesh.visual():
		var metal := EnvMesh.surface("iron", {base_color = Color("#3a3634"), metallic_base = 0.6, roughness_base = 0.5,
			stains = 0.5, stain_color = Color("#6b4a36")})
		EnvMesh.add(parent, EnvMesh.box(Vector3(0.05, 0.05, 0.28), 0.01, 1), metal,
			Transform3D(Basis(), Vector3(c.x - 0.09, 1.0, c.y - width * 0.5 + 0.12)))
		EnvMesh.add(parent, EnvMesh.box(Vector3(0.07, 0.08, 0.06), 0.01, 1), metal,
			Transform3D(Basis(), Vector3(c.x - 0.1, 1.0, c.y - width * 0.5 - 0.02)))


static func _board_multimesh(parent: Node3D, mesh: Mesh, xs: Array, mat: Material) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xs.size()
	for i in xs.size():
		mm.set_instance_transform(i, xs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	parent.add_child(mmi)


## Board with chamfered edges; grain runs along local y.
static func _board_mesh(size: Vector3) -> ArrayMesh:
	return EnvMesh.merge([EnvMesh.piece(EnvMesh.box(size, 0.014, 2), Transform3D(), 0.5)])


## Picket: flat board with a pointed top (extruded pentagon), centred on its height.
static func _picket_mesh(width: float, height: float, thick: float) -> ArrayMesh:
	var w := width * 0.5
	var h := height * 0.5
	var tip := width * 0.55
	var profile := [Vector2(-w, -h), Vector2(w, -h), Vector2(w, h - tip), Vector2(0, h), Vector2(-w, h - tip)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(Color(0.5, 0.5, 1.0, 0.5))
	var zf := thick * 0.5
	# Front (+z) and back (-z) caps as triangle fans.
	for side: float in [1.0, -1.0]:
		var n := Vector3(0, 0, side)
		for i in range(1, profile.size() - 1):
			var tri := [profile[0], profile[i], profile[i + 1]]
			if side > 0.0:
				tri = [tri[0], tri[2], tri[1]]
			for p in tri:
				st.set_normal(n)
				st.add_vertex(Vector3(p.x, p.y, zf * side))
	# Sides.
	for i in profile.size():
		var p0: Vector2 = profile[i]
		var p1: Vector2 = profile[(i + 1) % profile.size()]
		var e := (p1 - p0).normalized()
		var n := Vector3(e.y, -e.x, 0)
		var quad := [Vector3(p0.x, p0.y, zf), Vector3(p1.x, p1.y, zf), Vector3(p1.x, p1.y, -zf), Vector3(p0.x, p0.y, -zf)]
		for k: int in [0, 1, 2, 0, 2, 3]:
			st.set_normal(n)
			st.add_vertex(quad[k])
	return st.commit()
