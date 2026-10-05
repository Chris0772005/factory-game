class_name StationKit
## Building blocks for the foundry station props (Art Bible 3 + 5): surfaces
## of revolution, swept tubes, lumpy chunks, painted labels and the station
## materials (worked metal, fired clay, moulding sand, embers, leather, paper,
## chalk). Wood and generic surfaces reuse the environment shaders, so the
## stations and the yard share one look. Small pieces are merged per material
## with EnvMesh.merge, which also writes the per-piece seed the shaders read.
## Nothing visual is built headless (tests, dedicated servers).

const SHADER_DIR := "res://scripts/foundry/visuals/shaders/"
## Handwriting (notes, chalk) and sketchy chalk capitals, both SIL OFL 1.1
## (licence files next to them).
const HAND_FONT := "res://assets/models/props/fonts/PatrickHand-Regular.ttf"
const CHALK_FONT := "res://assets/models/props/fonts/CabinSketch-Bold.ttf"

static var _meshes := {}
## Builds the visuals even headless (art smoke tests without a GPU); also on
## when the environment variable MM_FORCE_VISUAL=1 is set, e.g. to run the
## gameplay tests through the station art code.
static var force := OS.get_environment("MM_FORCE_VISUAL") == "1"


## False headless: callers then only build what gameplay needs.
static func visual() -> bool:
	return force or EnvMesh.visual()


# --- Materials -------------------------------------------------------------

## Shared worked-iron material (station_metal.gdshader), cached by `key`.
static func metal(key: String, params := {}) -> ShaderMaterial:
	return EnvMesh.material("st_metal_" + key, SHADER_DIR + "station_metal.gdshader", params)


## Shared fired-clay / clay-graphite / brick material, cached by `key`.
static func clay(key: String, params := {}) -> ShaderMaterial:
	return EnvMesh.material("st_clay_" + key, SHADER_DIR + "station_clay.gdshader", params)


static func wood(key: String, params := {}) -> ShaderMaterial:
	return EnvMesh.wood("st_" + key, params)


static func surface(key: String, params := {}) -> ShaderMaterial:
	return EnvMesh.surface("st_" + key, params)


static func leather(key: String, params := {}) -> ShaderMaterial:
	return EnvMesh.material("st_leather_" + key, SHADER_DIR + "station_leather.gdshader", params)


static func paper() -> ShaderMaterial:
	return EnvMesh.material("st_paper", SHADER_DIR + "station_paper.gdshader")


## A material of its own (not shared), for per-station animated uniforms.
static func unique(shader: String, params := {}) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(SHADER_DIR + shader + ".gdshader")
	for p in params:
		mat.set_shader_parameter(p, params[p])
	return mat


# --- Meshes ------------------------------------------------------------------

## Surface of revolution about +Y. `profile` holds Vector2(radius, y) points
## in order; faces point to the right of the walking direction in the (r, y)
## plane, so walk up the outside and down the inside. Corners sharper than
## `crease_deg` stay hard. `deform` (optional) maps (pos: Vector3, angle:
## float) -> Vector3 for asymmetric details such as a pouring spout. Angle 0
## is +Z. UV = (angle / arc, distance along the profile).
static func lathe(profile: PackedVector2Array, sides := 24, crease_deg := 40.0, deform := Callable(), arc := TAU) -> ArrayMesh:
	var n := profile.size()
	var seg_n: Array[Vector2] = []
	for i in n - 1:
		var d := profile[i + 1] - profile[i]
		seg_n.append(Vector2(d.y, -d.x).normalized())
	var limit := cos(deg_to_rad(crease_deg))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dist := 0.0
	for i in n - 1:
		var na := seg_n[i]
		var nb := seg_n[i]
		if i > 0 and seg_n[i - 1].dot(seg_n[i]) > limit:
			na = (seg_n[i - 1] + seg_n[i]).normalized()
		if i < n - 2 and seg_n[i + 1].dot(seg_n[i]) > limit:
			nb = (seg_n[i + 1] + seg_n[i]).normalized()
		var seg := profile[i].distance_to(profile[i + 1])
		for k in sides:
			var a0 := arc * k / sides
			var a1 := arc * (k + 1) / sides
			var v := [
				[_rev(profile[i], a0, deform), _rev_n(na, a0), Vector2(a0 / arc, dist)],
				[_rev(profile[i], a1, deform), _rev_n(na, a1), Vector2(a1 / arc, dist)],
				[_rev(profile[i + 1], a1, deform), _rev_n(nb, a1), Vector2(a1 / arc, dist + seg)],
				[_rev(profile[i + 1], a0, deform), _rev_n(nb, a0), Vector2(a0 / arc, dist + seg)],
			]
			_tri(st, v[0], v[1], v[2])
			_tri(st, v[0], v[2], v[3])
		dist += seg
	return st.commit()


static func _rev(p: Vector2, a: float, deform: Callable) -> Vector3:
	var v := Vector3(p.x * sin(a), p.y, p.x * cos(a))
	return deform.call(v, a) if deform.is_valid() else v


static func _rev_n(n: Vector2, a: float) -> Vector3:
	return Vector3(n.x * sin(a), n.y, n.x * cos(a)).normalized()


## One triangle of [pos, normal, uv] corners, wound so Godot sees its front
## on the side the normals point to. Degenerate triangles are dropped.
static func _tri(st: SurfaceTool, a: Array, b: Array, c: Array) -> void:
	var pa: Vector3 = a[0]
	var pb: Vector3 = b[0]
	var pc: Vector3 = c[0]
	var cross := (pb - pa).cross(pc - pa)
	if cross.length_squared() < 1e-16:
		return
	var nsum: Vector3 = a[1] + b[1] + c[1]
	var order := [a, b, c] if cross.dot(nsum) < 0.0 else [a, c, b]
	for vtx in order:
		st.set_normal(vtx[1])
		st.set_uv(vtx[2])
		st.add_vertex(vtx[0])


## Round tube along `path` with parallel-transport frames (no twisting).
## `radii` (optional) sets the radius per path point. Ends get flat caps.
static func tube(path: PackedVector3Array, radius: float, sides := 8, caps := true, radii := PackedFloat32Array()) -> ArrayMesh:
	var n := path.size()
	var tangents: Array[Vector3] = []
	for i in n:
		var t := Vector3.ZERO
		if i < n - 1:
			t += (path[i + 1] - path[i]).normalized()
		if i > 0:
			t += (path[i] - path[i - 1]).normalized()
		tangents.append(t.normalized())
	var ref := Vector3.UP if absf(tangents[0].dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var nrm := tangents[0].cross(ref).normalized()
	var rings: Array = []
	var dist := 0.0
	for i in n:
		if i > 0:
			var axis := tangents[i - 1].cross(tangents[i])
			if axis.length_squared() > 1e-10:
				nrm = nrm.rotated(axis.normalized(), tangents[i - 1].angle_to(tangents[i]))
			dist += path[i].distance_to(path[i - 1])
		var bin := tangents[i].cross(nrm).normalized()
		var r := radii[i] if i < radii.size() else radius
		var ring := []
		for k in sides + 1:
			var a := TAU * k / sides
			var dir := nrm * cos(a) + bin * sin(a)
			ring.append([path[i] + dir * r, dir, Vector2(float(k) / sides, dist)])
		rings.append(ring)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n - 1:
		for k in sides:
			_tri(st, rings[i][k], rings[i][k + 1], rings[i + 1][k + 1])
			_tri(st, rings[i][k], rings[i + 1][k + 1], rings[i + 1][k])
	if caps:
		for end in [0, n - 1]:
			var out: Vector3 = -tangents[0] if end == 0 else tangents[n - 1]
			var c := [path[end], out, Vector2(0.5, 0.5)]
			for k in sides:
				var a: Array = rings[end][k]
				var b: Array = rings[end][k + 1]
				_tri(st, c, [a[0], out, a[2]], [b[0], out, b[2]])
	return st.commit()


## Points along a circular arc in the plane spanned by `u` and `v` around `center`.
static func arc_points(center: Vector3, u: Vector3, v: Vector3, radius: float, from: float, to: float, steps: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in steps + 1:
		var a := lerpf(from, to, float(i) / steps)
		out.append(center + (u * cos(a) + v * sin(a)) * radius)
	return out


## Flat strip of `width` along `path` (nearly horizontal), facing up: pencil
## lines, chalk strokes, ink.
static func ribbon(path: PackedVector3Array, width: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := path.size()
	if n == 1:
		path = PackedVector3Array([path[0] + Vector3(-width * 0.5, 0, 0), path[0] + Vector3(width * 0.5, 0, 0)])
		n = 2
	var left: Array[Vector3] = []
	for i in n:
		var t := Vector3.ZERO
		if i < n - 1:
			t += path[i + 1] - path[i]
		if i > 0:
			t += path[i] - path[i - 1]
		t.y = 0.0
		var side := t.cross(Vector3.UP).normalized() * width * 0.5 if t.length_squared() > 1e-12 else Vector3(width * 0.5, 0, 0)
		left.append(side)
	for i in n - 1:
		var a := [path[i] - left[i], Vector3.UP, Vector2(0, i)]
		var b := [path[i] + left[i], Vector3.UP, Vector2(1, i)]
		var c := [path[i + 1] + left[i + 1], Vector3.UP, Vector2(1, i + 1)]
		var d := [path[i + 1] - left[i + 1], Vector3.UP, Vector2(0, i + 1)]
		_tri(st, a, b, c)
		_tri(st, a, c, d)
	return st.commit()


## Lumpy faceted chunk (coal, clods, rubble), about `radius` across, flattened
## by `squash`. Cached per parameter set.
static func chunk(radius: float, seed: int, squash := 0.75, rough := 0.35) -> ArrayMesh:
	var key := "chunk_%s_%s_%s_%s" % [radius, seed, squash, rough]
	if _meshes.has(key):
		return _meshes[key]
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 7
	sphere.rings = 4
	var arr := sphere.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = 0.9
	var moved := PackedVector3Array()
	for v in verts:
		var d := 1.0 + noise.get_noise_3dv(v * 1.7) * rough * 2.0
		moved.append(v * d * radius * Vector3(1.0, squash, 1.0))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, idx.size(), 3):
		var a := moved[idx[i]]
		var b := moved[idx[i + 1]]
		var c := moved[idx[i + 2]]
		var nrm := (b - a).cross(c - a)
		if nrm.length_squared() < 1e-14:
			continue
		nrm = nrm.normalized()
		if nrm.dot(a + b + c) < 0.0:
			nrm = -nrm
		_tri(st, [a, nrm, Vector2.ZERO], [b, nrm, Vector2.ZERO], [c, nrm, Vector2.ZERO])
	var mesh := st.commit()
	_meshes[key] = mesh
	return mesh


## Flat rectangle (w x h) in the XY plane facing +Z, centred, with UV (0,0) at
## the top-left; subdivided so vertex shaders can bend it.
static func sheet(w: float, h: float, subdiv := 4) -> PlaneMesh:
	var key := "sheet_%s_%s_%s" % [w, h, subdiv]
	if not _meshes.has(key):
		var m := PlaneMesh.new()
		m.size = Vector2(w, h)
		m.orientation = PlaneMesh.FACE_Z
		m.subdivide_width = subdiv
		m.subdivide_depth = subdiv
		_meshes[key] = m
	return _meshes[key]


# --- Helpers -----------------------------------------------------------------

## Invisible static box collider (built headless too: gameplay needs it).
static func box_collider(parent: Node, size: Vector3, xform: Transform3D) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.transform = xform
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)
	return body


## Adds a mesh instance under `parent` (callers check visual() first).
static func add(parent: Node3D, mesh: Mesh, material: Material, xform := Transform3D(), shadows := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.transform = xform
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Merges `pieces` (EnvMesh.piece) and adds them under `parent` with `material`.
static func add_merged(parent: Node3D, pieces: Array, material: Material, shadows := true) -> MeshInstance3D:
	if pieces.is_empty():
		return null
	return add(parent, EnvMesh.merge(pieces), material, Transform3D(), shadows)


## Painted or chalked lettering lying on a surface: a shaded Label3D whose
## front faces +Z of `xform`. Not UI: no outline, lit like the surface.
## `font` overrides the Fredoka `weight` (e.g. hand_font()).
static func label(parent: Node3D, text: String, xform: Transform3D, size := 48, color := Color.WHITE, weight := 700, pixel := 0.002, font: Font = null) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = font if font else UITheme.font(weight)
	l.font_size = size
	l.outline_size = 0
	l.modulate = color
	l.pixel_size = pixel
	l.shaded = true
	l.double_sided = false
	l.transform = xform
	parent.add_child(l)
	return l


## Basis whose local Y points along `axis` (for cylinders along a direction).
static func basis_y(axis: Vector3) -> Basis:
	var y := axis.normalized()
	var ref := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := y.cross(ref).normalized()
	return Basis(x, y, x.cross(y))


static func hand_font() -> Font:
	return load(HAND_FONT)


static func chalk_font() -> Font:
	return load(CHALK_FONT)


## Deterministic tilt (radians) for "nothing is perfectly straight" (Art Bible 3.1).
static func jitter(rng: RandomNumberGenerator, degrees := 2.0) -> float:
	return deg_to_rad(rng.randf_range(-degrees, degrees))
