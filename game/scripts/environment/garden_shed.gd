class_name GardenShed
## Board-walled garden shed with a lean-to corrugated roof, a small window and
## a double door facing the yard: one leaf stands open on a dim, warmly lit
## inside with shelves and hanging tools. Local frame: centre of the
## footprint on the ground, doors face +x.

const PAINT := Color("#5f7f78")
const WALL_FRONT := 2.45
const WALL_BACK := 2.05

var root: Node3D
var rng := RandomNumberGenerator.new()
var size := Vector2(2.8, 3.4)
var _wood: Array = []
var _painted: Array = []
var _dark: Array = []


static func build(parent: Node3D, center: Vector2, footprint: Vector2) -> Node3D:
	var s := GardenShed.new()
	s.size = footprint
	s.rng.seed = 2718
	s.root = Node3D.new()
	s.root.name = "Shed"
	s.root.position = Vector3(center.x, 0, center.y)
	parent.add_child(s.root)
	WorldBuilder.add_collider(s.root, Vector3(footprint.x, WALL_FRONT, footprint.y), Transform3D(Basis(), Vector3(0, WALL_FRONT * 0.5, 0)))
	# The open door leaf.
	WorldBuilder.add_collider(s.root, Vector3(0.75, 1.95, 0.08),
		Transform3D(Basis(Vector3.UP, deg_to_rad(70.0)), Vector3(footprint.x * 0.5 + 0.32, 1.0, 0.77)))
	if EnvMesh.visual():
		s._build()
	return s.root


func _build() -> void:
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	# Floor platform on low stones.
	_wood.append(EnvMesh.piece(EnvMesh.box(Vector3(size.x + 0.1, 0.1, size.y + 0.1), 0.02, 1), Transform3D(Basis(), Vector3(0, 0.12, 0)), 0.3, Vector3.RIGHT))
	# Back (-x) and side walls of vertical boards.
	_board_wall(Vector3(-hx, 0, 0), Vector3(0, 0, 1), size.y, WALL_BACK, WALL_BACK, [])
	_board_wall(Vector3(0, 0, hz), Vector3(1, 0, 0), size.x, WALL_BACK, WALL_FRONT, [[0.15, 0.94, 0.72, 0.52]])
	_board_wall(Vector3(0, 0, -hz), Vector3(1, 0, 0), size.x, WALL_BACK, WALL_FRONT, [])
	# Front wall with the door opening (local z -0.75 .. 0.65 on the front face).
	_board_wall(Vector3(hx, 0, 0), Vector3(0, 0, 1), size.y, WALL_FRONT, WALL_FRONT, [[-0.05, 0.12, 1.4, 1.95]])
	# Corner posts and trims.
	for cx: float in [-hx, hx]:
		for cz: float in [-hz, hz]:
			var h := WALL_FRONT if cx > 0.0 else WALL_BACK
			_painted.append(EnvMesh.piece(EnvMesh.box(Vector3(0.12, h, 0.12), 0.02, 1), Transform3D(Basis(), Vector3(cx, h * 0.5 + 0.1, cz)), rng.randf()))
	# Doors: the left leaf closed, the right one swung open.
	var door := EnvMesh.box(Vector3(0.05, 1.9, 0.68), 0.015, 1)
	_painted.append(EnvMesh.piece(door, Transform3D(Basis(), Vector3(hx + 0.04, 1.12, -0.4)), 0.2))
	var open_basis := Basis(Vector3.UP, deg_to_rad(70.0))
	_painted.append(EnvMesh.piece(door, Transform3D(open_basis, Vector3(hx + 0.32, 1.12, 0.77)), 0.7))
	for leaf in [[Basis(), Vector3(hx + 0.08, 0, -0.4)], [open_basis, Vector3(hx + 0.32, 0, 0.77)]]:
		var b: Basis = leaf[0]
		var c: Vector3 = leaf[1]
		for by: float in [0.5, 1.7]:
			_wood.append(EnvMesh.piece(EnvMesh.box(Vector3(0.04, 0.1, 0.64), 0.01, 1), Transform3D(b, c + b * Vector3(0.02, by, 0)), rng.randf(), Vector3.BACK))
		_wood.append(EnvMesh.piece(EnvMesh.box(Vector3(0.04, 1.32, 0.09), 0.01, 1),
			Transform3D(b * Basis(Vector3.RIGHT, -0.42), c + b * Vector3(0.02, 1.1, 0)), rng.randf()))
	_dark.append(EnvMesh.piece(EnvMesh.box(Vector3(0.05, 0.05, 0.18), 0.01, 1), Transform3D(Basis(), Vector3(hx + 0.1, 1.1, -0.1)), 0.0, Vector3.BACK))
	# Lintel over the door, window frame on the +z side.
	_painted.append(EnvMesh.piece(EnvMesh.box(Vector3(0.1, 0.14, 1.6), 0.02, 1), Transform3D(Basis(), Vector3(hx + 0.04, 2.14, -0.05)), 0.5, Vector3.BACK))
	_window(Vector3(0.15, 1.2, hz + 0.03))
	_interior()
	_roof()
	var wood := EnvMesh.wood("shed", {base_color = Color("#6e5a4a"), weathering = 0.45})
	var painted := EnvMesh.wood("shed_paint", {base_color = Color("#6a5a4e"), weathering = 0.5, paint_color = PAINT, paint = 0.7})
	var dark := EnvMesh.surface("dark_iron", {base_color = Color("#2e2b2c"), metallic_base = 0.5, roughness_base = 0.5})
	EnvMesh.add(root, EnvMesh.merge(_wood), wood)
	EnvMesh.add(root, EnvMesh.merge(_painted), painted)
	EnvMesh.add(root, EnvMesh.merge(_dark), dark)


## A wall of vertical boards from `c` along `along` (length), height ramping
## from h0 to h1 along it. `holes`: [centre along, bottom y, width, height].
func _board_wall(c: Vector3, along: Vector3, length: float, h0: float, h1: float, holes: Array) -> void:
	var normal := Vector3(along.z, 0, -along.x)
	var basis := Basis(along, Vector3.UP, along.cross(Vector3.UP))
	var pitch := 0.22
	var n := int(length / pitch)
	for i in n:
		var t := -length * 0.5 + (i + 0.5) * length / n
		var h := lerpf(h0, h1, (t + length * 0.5) / length)
		var lo := 0.08
		var hi := h + 0.1
		var segments := [[lo, hi]]
		for hole in holes:
			if absf(t - hole[0]) < hole[2] * 0.5:
				segments = [[lo, hole[1]], [hole[1] + hole[3], hi]]
		for seg in segments:
			var len: float = seg[1] - seg[0]
			if len < 0.05:
				continue
			var pos: Vector3 = c + along * t + Vector3(0, (seg[0] + seg[1]) * 0.5, 0) + normal * 0.0
			_painted.append(EnvMesh.piece(EnvMesh.box(Vector3(length / n, len, 0.04), 0.008, 1), Transform3D(basis, pos), rng.randf()))
	# Horizontal batten inside at mid height.
	_wood.append(EnvMesh.piece(EnvMesh.box(Vector3(length - 0.1, 0.08, 0.04), 0.01, 1),
		Transform3D(basis, c + Vector3(0, 1.2, 0) - normal.normalized() * 0.04 * signf(c.dot(normal) + 0.001)), rng.randf(), Vector3.RIGHT))


func _window(c: Vector3) -> void:
	var glass := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.62, 0.48)
	glass.mesh = quad
	glass.material_override = EnvMesh.material("window", "res://shaders/env_window.gdshader")
	glass.position = c + Vector3(0, 0, 0.005)
	glass.set_instance_shader_parameter(&"lit", 0.35)
	glass.set_instance_shader_parameter(&"seed", 0.62)
	root.add_child(glass)
	for sy: float in [-1.0, 1.0]:
		_painted.append(EnvMesh.piece(EnvMesh.box(Vector3(0.78, 0.07, 0.07), 0.01, 1), Transform3D(Basis(), c + Vector3(0, sy * 0.27, 0.02)), 0.4, Vector3.RIGHT))
	for sx: float in [-1.0, 1.0, 0.0]:
		var w := 0.07 if sx != 0.0 else 0.035
		_painted.append(EnvMesh.piece(EnvMesh.box(Vector3(w, 0.5, 0.06), 0.01, 1), Transform3D(Basis(), c + Vector3(sx * 0.35, 0, 0.02)), 0.4))


## What you see through the open door: shelves with tins, tools on the wall
## and a bare bulb.
func _interior() -> void:
	var hx := size.x * 0.5
	for sy: float in [0.9, 1.5]:
		_wood.append(EnvMesh.piece(EnvMesh.box(Vector3(0.4, 0.04, size.y - 0.3), 0.01, 1), Transform3D(Basis(), Vector3(-hx + 0.25, sy, 0)), rng.randf(), Vector3.BACK))
		for i in 6:
			var z := -size.y * 0.5 + 0.35 + i * 0.45 + rng.randf() * 0.1
			var hgt := rng.randf_range(0.12, 0.22)
			_dark.append(EnvMesh.piece(EnvMesh.cylinder(0.06, 0.06, hgt, 8), Transform3D(Basis(), Vector3(-hx + 0.25, sy + 0.02 + hgt * 0.5, z)), rng.randf()))
	# Spade and rake hanging on the back wall.
	for i in 2:
		var z := -0.5 + i * 0.6
		_wood.append(EnvMesh.piece(EnvMesh.cylinder(0.02, 0.02, 1.3, 6), Transform3D(Basis(), Vector3(-hx + 0.08, 1.15, z)), rng.randf()))
		_dark.append(EnvMesh.piece(EnvMesh.box(Vector3(0.03, 0.26, 0.2 if i == 0 else 0.34), 0.01, 1), Transform3D(Basis(), Vector3(-hx + 0.08, 0.42, z)), 0.0))
	if not EnvQuality.is_low():
		var bulb := OmniLight3D.new()
		bulb.light_color = Color("#ffbf73")
		bulb.light_energy = 0.9
		bulb.omni_range = 2.6
		bulb.position = Vector3(0.1, 2.0, 0)
		root.add_child(bulb)
	var glow := MeshInstance3D.new()
	glow.mesh = EnvMesh.sphere(0.05, 8, 4)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#5a4a3a")
	m.emission_enabled = true
	m.emission = Color("#ffc27a")
	m.emission_energy_multiplier = 1.4
	glow.material_override = m
	glow.position = Vector3(0.1, 2.05, 0)
	root.add_child(glow)


## Corrugated sheet roof, falling from the front (+x) to the back.
func _roof() -> void:
	var over := 0.25
	var x0 := -size.x * 0.5 - over
	var x1 := size.x * 0.5 + over
	var y0 := WALL_BACK + 0.12 - over * (WALL_FRONT - WALL_BACK) / size.x
	var y1 := WALL_FRONT + 0.12 + over * (WALL_FRONT - WALL_BACK) / size.x
	var z0 := -size.y * 0.5 - over
	var z1 := size.y * 0.5 + over
	var waves := int((z1 - z0) / 0.12)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := waves * 4
	var slope := Vector3(x1 - x0, y1 - y0, 0).normalized()
	for side: float in [1.0, -1.0]:
		for i in cols:
			var za := lerpf(z0, z1, float(i) / cols)
			var zb := lerpf(z0, z1, float(i + 1) / cols)
			var ya := sin(float(i) / cols * waves * TAU) * 0.009
			var yb := sin(float(i + 1) / cols * waves * TAU) * 0.009
			var e := Vector3(0, yb - ya, zb - za).normalized()
			var n := slope.cross(e).normalized()
			if n.y < 0.0:
				n = -n
			n *= side
			var off := Vector3(0, -0.006 if side < 0.0 else 0.0, 0)
			var q := [Vector3(x0, y0 + ya, za) + off, Vector3(x1, y1 + ya, za) + off, Vector3(x1, y1 + yb, zb) + off, Vector3(x0, y0 + yb, zb) + off]
			var order := [0, 1, 2, 0, 2, 3] if side > 0.0 else [0, 2, 1, 0, 3, 2]
			for k in order:
				st.set_normal(n)
				st.set_color(Color(0.5, 1.0, 0.5, 0.5))
				st.add_vertex(q[k])
	var mesh := st.commit()
	var tin := EnvMesh.surface("corrugated", {base_color = Color("#a3a7a8"), metallic_base = 0.25, roughness_base = 0.6,
		stains = 0.65, stain_color = Color("#7a4e36"), gradient = 0.15, grad_bottom = 2.0, grad_top = 2.7, noise_scale = 1.6})
	EnvMesh.add(root, mesh, tin)
	# Rafters under the sheet.
	for z: float in [z0 + 0.2, 0.0, z1 - 0.2]:
		var mid := Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5 - 0.06, z)
		var b := Basis(Vector3.BACK, atan2(y1 - y0, x1 - x0))
		_wood.append(EnvMesh.piece(EnvMesh.box(Vector3(x1 - x0 - 0.1, 0.09, 0.06), 0.01, 1), Transform3D(b, mid), rng.randf(), Vector3.RIGHT))
