class_name MoldArt
extends Node3D
## Look of the open sand mold (Art Bible 3.1 example, 5.3 "Formsand"): a
## plank flask with iron corner angles, bolts, carry handles and a burnt-in
## brand; moulding sand whose top surface is rebuilt around the real
## imprints, so every pattern is an actual recess (dark parting-dust walls
## and floor) that the metal fills from the bottom up; raked furrows when
## fresh, loose lumps after a pattern goes in, rammer stamps and darker damp
## sand as it is rammed, scorched and glowing sand around a hot casting.
## The flask hops and squashes when rammed and shakes when struck. A rammer
## or a shovel in a spare sand heap sits beside it. Visual only: MoldBox
## keeps its sand collider (top at BED.y) and gameplay.

const WALL := 0.08
const RIM := 0.06
## Depth of an imprint below the sand top (cast thickness + a hair).
const DEPTH := 0.072
## Edge distance field over the bed: pixels per metre and range (m).
const FIELD_PPM := 100.0
const FIELD_RANGE := 0.1

## Everything that hops with the flask (castings go in here too).
var root: Node3D

var _bed := Vector3.ONE
var _sand: ShaderMaterial
var _cavity: ShaderMaterial
var _sand_top: MeshInstance3D
var _pits: MeshInstance3D
var _signature := "-"
var _hop := 0.0
var _hop_vel := 0.0
var _shake := 0.0
var _burn := 0.0
var _params := {firm = 0.45, rake = 1.0, loose = 0.0, stamps = 0.0}


func build(bed: Vector3, variant: int) -> void:
	_bed = bed
	root = Node3D.new()
	add_child(root)
	if not StationKit.visual():
		return
	var seed := float(variant) * 3.17
	_sand = StationKit.unique("station_sand", {bed_top = bed.y, bed_half = Vector2(bed.x, bed.z) * 0.5,
		field_range = FIELD_RANGE, seed = seed})
	_cavity = StationKit.unique("station_sand", {bed_top = bed.y, bed_half = Vector2(bed.x, bed.z) * 0.5,
		field_range = FIELD_RANGE, is_cavity = true, seed = seed})
	_flask(variant)
	_sand_top = StationKit.add(root, _top_mesh([]), _sand)
	_dressing(variant)


## Rebuilds the sand surface around `cavities`: Array of [slot centre
## (Vector3, local), shapes (Array of rings: outer first, then holes, in
## slot-local 2D, x -> x and y -> z)]. Cheap to call every frame: only
## rebuilds when `signature` changes.
func set_cavities(signature: String, cavities: Array) -> void:
	if _sand == null or signature == _signature:
		return
	_signature = signature
	_sand_top.mesh = _top_mesh(cavities)
	if _pits:
		_pits.queue_free()
		_pits = null
	if not cavities.is_empty():
		_pits = StationKit.add(root, _pit_mesh(cavities), _cavity)
	var tex := _edge_field(cavities)
	_sand.set_shader_parameter(&"edge_field", tex)
	_cavity.set_shader_parameter(&"edge_field", tex)


## Juice: a ram squashes the flask and makes it hop; a hammer blow shakes it.
func bump(strike: bool) -> void:
	if strike:
		_shake = 1.0
		_hop_vel -= 1.2
	else:
		_hop_vel -= 2.2


## Per frame from MoldBox: state, rams so far, fill 0..1, metal temperature 0..1.
func update(delta: float, state: int, rams: int, fill: float, temperature: float) -> void:
	if _sand == null:
		return
	_hop_vel += (-_hop * 520.0 - _hop_vel * 16.0) * delta
	_hop += _hop_vel * delta
	_shake = maxf(0.0, _shake - delta * 4.0)
	var sq := clampf(_hop, -0.12, 0.12)
	root.scale = Vector3(1.0 - sq * 0.35, 1.0 + sq, 1.0 - sq * 0.35)
	root.position.y = maxf(0.0, _hop) * 0.5
	root.rotation.z = sin(_shake * 40.0) * _shake * 0.02
	var target := {}
	match state:
		MoldBox.State.EMPTY:
			target = {firm = 0.45, rake = 1.0, loose = 0.0, stamps = 0.0}
		MoldBox.State.PATTERNED:
			var k := float(rams) / MoldBox.RAMS_NEEDED
			target = {firm = k * 0.9, rake = 0.0, loose = 1.0 - k, stamps = k}
		_:
			target = {firm = 1.0, rake = 0.0, loose = 0.0, stamps = 1.0}
	var blend := 1.0 - exp(-delta * 6.0)
	for key in target:
		_params[key] = lerpf(_params[key], target[key], blend)
		_sand.set_shader_parameter(key, _params[key])
	_cavity.set_shader_parameter(&"firm", _params.firm)
	if state == MoldBox.State.EMPTY:
		_burn = 0.0
	else:
		_burn = maxf(_burn, clampf(fill * 1.5, 0.0, 1.0))
	var glow := temperature * smoothstep(0.0, 0.2, fill) if state >= MoldBox.State.FILLING else 0.0
	for m in [_sand, _cavity]:
		m.set_shader_parameter(&"burn", _burn)
		m.set_shader_parameter(&"glow", glow)


## Imprint outlines of `drawing` as a cast of `size`: Array of shapes, each an
## Array of rings (outer first, then holes) in slot-local 2D. Mirrors the
## transform and the shape filter of CastMeshBuilder.build, so the recess
## matches the metal exactly.
static func outlines(drawing: Drawing, size: float) -> Array:
	if drawing == null or drawing.is_empty():
		return []
	var polys := drawing.polygons()
	if polys.is_empty():
		return []
	var box := Rect2(polys[0].outer[0], Vector2.ZERO)
	for shape in polys:
		for p in shape.outer:
			box = box.expand(p)
	var scale := size / maxf(box.size.x, box.size.y)
	var to_local := Transform2D().scaled(Vector2(scale, scale)) * Transform2D(0.0, -box.get_center())
	var out := []
	for shape in polys:
		var rings: Array = [to_local * shape.outer]
		for hole in shape.holes:
			rings.append(to_local * hole)
		var tris := DrawingGeometry.triangulate(rings)
		if tris.is_empty() and rings.size() > 1:
			rings = [rings[0]]
			tris = DrawingGeometry.triangulate(rings)
		if not tris.is_empty():
			out.append(rings)
	return out


# --- Flask -------------------------------------------------------------------

func _flask(variant: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + variant
	var hx := _bed.x * 0.5
	var hz := _bed.z * 0.5
	var h := _bed.y + RIM
	var wood := StationKit.wood("flask", {base_color = Color("#9a6a46"), grain_color = Color("#5e3d29"), weathering = 0.3,
		variation = 0.14})
	var boards := []
	var low := 0.26
	for s: float in [-1.0, 1.0]:
		for b in 2:
			var bh := low if b == 0 else h - low
			var y := bh * 0.5 if b == 0 else low + bh * 0.5
			var size := Vector3(_bed.x + WALL * 2.0, bh - 0.006, WALL)
			var basis := Basis(Vector3.UP, StationKit.jitter(rng, 0.4)) * Basis(Vector3.RIGHT, StationKit.jitter(rng, 0.6))
			boards.append(EnvMesh.piece(EnvMesh.box(size, 0.012, 1), Transform3D(basis, Vector3(0, y, s * (hz + WALL * 0.5))), rng.randf(), Vector3.RIGHT))
			var end_size := Vector3(WALL, bh - 0.006, _bed.z)
			boards.append(EnvMesh.piece(EnvMesh.box(end_size, 0.012, 1), Transform3D(Basis(Vector3.FORWARD, StationKit.jitter(rng, 0.6)), Vector3(s * (hx + WALL * 0.5), y, 0)), rng.randf(), Vector3.BACK))
	# Skids underneath, sticking out a little at the ends.
	for z: float in [-hz + 0.1, hz - 0.1]:
		boards.append(EnvMesh.piece(EnvMesh.box(Vector3(_bed.x + 0.3, 0.05, 0.08), 0.01, 1), Transform3D(Basis(), Vector3(0, 0.025, z)), rng.randf(), Vector3.RIGHT))
	StationKit.add_merged(root, boards, wood)
	var iron := StationKit.metal("flask_iron", {steel_color = Color("#3b3937"), rust = 0.6, dents = 0.3, metallic_steel = 0.55,
		roughness_steel = 0.55})
	var irons := []
	var bolt := EnvMesh.sphere(0.012, 6, 3)
	var ch := h - 0.06
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var corner := Vector3(sx * (hx + WALL), 0, sz * (hz + WALL))
			irons.append(EnvMesh.piece(EnvMesh.box(Vector3(0.09, ch, 0.006), 0.002, 1), Transform3D(Basis(), corner + Vector3(-sx * 0.045, h * 0.5, sz * 0.003))))
			irons.append(EnvMesh.piece(EnvMesh.box(Vector3(0.006, ch, 0.09), 0.002, 1), Transform3D(Basis(), corner + Vector3(sx * 0.003, h * 0.5, -sz * 0.045))))
			for k in 3:
				var y := 0.08 + k * (ch - 0.06) * 0.5
				irons.append(EnvMesh.piece(bolt, Transform3D(Basis(), corner + Vector3(-sx * 0.05, y, sz * 0.008))))
				irons.append(EnvMesh.piece(bolt, Transform3D(Basis(), corner + Vector3(sx * 0.008, y, -sz * 0.05))))
	# Carry handles on both ends.
	for s: float in [-1.0, 1.0]:
		var path := PackedVector3Array()
		for i in 11:
			var t := PI * i / 10.0
			path.append(Vector3(s * (hx + WALL + 0.012 + sin(t) * 0.075), 0.35, cos(t) * 0.16))
		irons.append(EnvMesh.piece(StationKit.tube(path, 0.014, 8), Transform3D()))
		for z: float in [-0.16, 0.16]:
			irons.append(EnvMesh.piece(EnvMesh.box(Vector3(0.01, 0.07, 0.05), 0.003, 1), Transform3D(Basis(), Vector3(s * (hx + WALL + 0.005), 0.35, z))))
	StationKit.add_merged(root, irons, iron)
	var brand := Color(0.2, 0.11, 0.06, 0.7)
	StationKit.label(root, "MM", Transform3D(Basis(), Vector3(-hx * 0.55, 0.15, hz + WALL + 0.007)), 96, brand, 700, 0.0013)
	StationKit.label(root, "Nr. %d" % (variant + 1), Transform3D(Basis(), Vector3(hx * 0.55, 0.13, hz + WALL + 0.007)), 64, brand, 600, 0.0011)


## Spare sand on the ground with a shovel stuck in it, or a rammer leaning on
## the flask, and a few crumbs on the rim.
func _dressing(variant: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77 + variant * 13
	var hx := _bed.x * 0.5
	var hz := _bed.z * 0.5
	var loose := StationKit.surface("loose_sand", {base_color = Color("#c9a774"), macro = 0.12, grain = 0.12, contact_dark = 0.15,
		roughness_base = 0.97, noise_scale = 3.0})
	var crumbs := []
	for i in 14:
		var side := rng.randi() % 4
		var t := rng.randf_range(-0.9, 0.9)
		var p := Vector3(t * hx, _bed.y + RIM + 0.004, (hz + WALL * 0.5) * (1.0 if side % 2 == 0 else -1.0))
		if side >= 2:
			p = Vector3((hx + WALL * 0.5) * (1.0 if side == 2 else -1.0), _bed.y + RIM + 0.004, t * hz)
		crumbs.append(EnvMesh.piece(StationKit.chunk(rng.randf_range(0.01, 0.022), i % 5, 0.5, 0.3), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p)))
	var wood := StationKit.wood("tool_handle", {base_color = Color("#a27a52"), grain_color = Color("#6b4b32"), weathering = 0.15})
	var iron := StationKit.metal("tool_iron", {steel_color = Color("#454341"), rust = 0.5, dents = 0.2, metallic_steel = 0.6})
	if variant % 2 == 0:
		# Sand heap at the front-left corner with a shovel stuck in it.
		var heap := Vector3(-hx - 0.32, 0.0, hz + 0.22)
		var dome := PackedVector2Array()
		for i in 7:
			var k := 1.0 - i / 6.0
			dome.append(Vector2(0.3 * k, 0.17 * (1.0 - k * k) - 0.005))
		crumbs.append(EnvMesh.piece(StationKit.lathe(dome, 18, 80.0, _heap_lumps), Transform3D(Basis(Vector3.UP, 0.4), heap)))
		for i in 8:
			var a := rng.randf() * TAU
			crumbs.append(EnvMesh.piece(StationKit.chunk(rng.randf_range(0.02, 0.05), i % 5, 0.5, 0.3),
				Transform3D(Basis(Vector3.UP, a), heap + Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.25, 0.42) + Vector3(0, 0.008, 0))))
		var lean := Basis(Vector3.UP, 0.5) * Basis(Vector3.RIGHT, -0.32)
		var tip := heap + Vector3(0.02, 0.05, -0.02)
		var axis := lean * Vector3.UP
		StationKit.add_merged(self, [
			EnvMesh.piece(StationKit.tube(PackedVector3Array([tip + axis * 0.2, tip + axis * 1.02]), 0.017, 8), Transform3D()),
			EnvMesh.piece(StationKit.tube(PackedVector3Array([tip + axis * 1.02 + lean * Vector3(-0.07, 0, 0), tip + axis * 1.02 + lean * Vector3(0.07, 0, 0)]), 0.016, 8), Transform3D()),
		], wood)
		StationKit.add_merged(self, [
			EnvMesh.piece(EnvMesh.box(Vector3(0.22, 0.26, 0.012), 0.01, 1), Transform3D(lean, tip + axis * 0.06)),
			EnvMesh.piece(EnvMesh.cylinder(0.02, 0.024, 0.1, 8), Transform3D(lean, tip + axis * 0.22)),
		], iron)
	else:
		# Rammer leaning against the right end of the flask.
		var foot := Vector3(hx + WALL + 0.27, 0.0, -hz + 0.1)
		var rest := Vector3(hx + WALL + 0.016, _bed.y + RIM, -hz + 0.2)
		var axis := (rest - foot).normalized()
		StationKit.add_merged(self, [
			EnvMesh.piece(StationKit.tube(PackedVector3Array([foot + axis * 0.06, foot + axis * 1.0]), 0.018, 8), Transform3D()),
			EnvMesh.piece(StationKit.tube(PackedVector3Array([foot + axis * 1.0 + Vector3(0, 0, -0.06), foot + axis * 1.0 + Vector3(0, 0, 0.06)]), 0.016, 8), Transform3D()),
		], wood)
		StationKit.add_merged(self, [
			EnvMesh.piece(EnvMesh.cylinder(0.045, 0.05, 0.07, 12), Transform3D(StationKit.basis_y(axis), foot + axis * 0.035)),
		], iron)
	StationKit.add_merged(self, crumbs, loose)


## Irregular outline for the spare sand heap.
static func _heap_lumps(pos: Vector3, angle: float) -> Vector3:
	var k := 1.0 + 0.12 * sin(angle * 3.0 + 0.7) + 0.06 * sin(angle * 5.0)
	return Vector3(pos.x * k, pos.y * (1.0 + 0.1 * sin(angle * 2.0)), pos.z * k)


# --- Sand surface ----------------------------------------------------------

## Sand top: the bed rectangle minus every imprint outline (islands inside a
## shape's holes come back as sand). Built from 5 cm cells clipped against
## the outlines (subdivided where a small hole would fall inside a cell), as
## the ear clipper cannot take many holes at once.
func _top_mesh(cavities: Array) -> ArrayMesh:
	var hx := _bed.x * 0.5
	var hz := _bed.z * 0.5
	var holes: Array[PackedVector2Array] = []
	var boxes: Array[Rect2] = []
	var islands: Array[PackedVector2Array] = []
	for c in cavities:
		var off := Vector2(c[0].x, c[0].z)
		for shape: Array in c[1]:
			var outer := _moved(shape[0], off)
			holes.append(outer)
			boxes.append(_bounds(outer))
			for i in range(1, shape.size()):
				islands.append(_reversed(_moved(shape[i], off)))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cell := 0.05
	var nx := ceili(_bed.x / cell)
	var nz := ceili(_bed.z / cell)
	for iz in nz:
		for ix in nx:
			var r := Rect2(Vector2(-hx + ix * cell, -hz + iz * cell), Vector2(cell, cell))
			r = r.intersection(Rect2(-hx, -hz, _bed.x, _bed.z))
			var touching: Array[PackedVector2Array] = []
			for k in holes.size():
				if boxes[k].intersects(r):
					touching.append(holes[k])
			_add_cell(st, r, touching, 0)
	for island in islands:
		var tris := DrawingGeometry.triangulate([island])
		_add_flat(st, [island], tris, _bed.y)
	return st.commit()


## One cell of the sand top minus `holes`; splits into quarters (up to three
## times) where a hole sits entirely inside it.
func _add_cell(st: SurfaceTool, r: Rect2, holes: Array[PackedVector2Array], depth: int) -> void:
	var quad := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	if holes.is_empty():
		_add_flat(st, [quad], PackedInt32Array([0, 1, 2, 0, 2, 3]), _bed.y)
		return
	var parts: Array = [quad]
	for h in holes:
		var next: Array = []
		for p: PackedVector2Array in parts:
			next.append_array(Geometry2D.clip_polygons(p, h))
		parts = next
	var enclosed := false
	for p: PackedVector2Array in parts:
		if Geometry2D.is_polygon_clockwise(p):
			enclosed = true
	if enclosed and depth < 3:
		var half := r.size * 0.5
		for q in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
			var sub := Rect2(r.position + half * q, half)
			var touching: Array[PackedVector2Array] = []
			for h in holes:
				if _bounds(h).intersects(sub):
					touching.append(h)
			_add_cell(st, sub, touching, depth + 1)
		return
	for p: PackedVector2Array in parts:
		if Geometry2D.is_polygon_clockwise(p) or p.size() < 3:
			continue
		_add_flat(st, [p], DrawingGeometry.triangulate([p]), _bed.y)


static func _bounds(ring: PackedVector2Array) -> Rect2:
	var box := Rect2(ring[0], Vector2.ZERO)
	for p in ring:
		box = box.expand(p)
	return box


## Imprint walls (facing into the recess) and floors.
func _pit_mesh(cavities: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y0 := _bed.y - DEPTH
	var y1 := _bed.y
	for c in cavities:
		var off := Vector2(c[0].x, c[0].z)
		for shape: Array in c[1]:
			var rings: Array = []
			for r in shape:
				rings.append(_moved(r, off))
			var tris := DrawingGeometry.triangulate(rings)
			if tris.is_empty():
				tris = DrawingGeometry.triangulate([rings[0]])
				_add_flat(st, [rings[0]], tris, y0)
			else:
				_add_flat(st, rings, tris, y0)
			for ring: PackedVector2Array in rings:
				var n := ring.size()
				for i in n:
					var a := ring[i]
					var b := ring[(i + 1) % n]
					var d := b - a
					if d.length_squared() < 1e-12:
						continue
					var nrm := Vector3(-d.y, 0.0, d.x).normalized()
					var p := [Vector3(a.x, y0, a.y), Vector3(b.x, y0, b.y), Vector3(b.x, y1, b.y), Vector3(a.x, y1, a.y)]
					var q := []
					for k in 4:
						q.append([p[k], nrm, Vector2(0, p[k].y)])
					StationKit._tri(st, q[0], q[1], q[2])
					StationKit._tri(st, q[0], q[2], q[3])
	return st.commit()


## Up-facing face from rings + triangles (indices into the concatenated
## rings), wound as one so slivers keep a consistent side.
func _add_flat(st: SurfaceTool, rings: Array, tris: PackedInt32Array, y: float) -> void:
	var pts := PackedVector2Array()
	for r: PackedVector2Array in rings:
		pts.append_array(r)
	var total := 0.0
	for i in range(0, tris.size(), 3):
		var a := pts[tris[i]]
		total += (pts[tris[i + 1]] - a).cross(pts[tris[i + 2]] - a)
	var flip := total < 0.0
	for i in range(0, tris.size(), 3):
		var ids := [tris[i], tris[i + 1], tris[i + 2]] if not flip else [tris[i], tris[i + 2], tris[i + 1]]
		for id in ids:
			var p := pts[id]
			st.set_normal(Vector3.UP)
			st.set_uv(p)
			st.add_vertex(Vector3(p.x, y, p.y))


static func _moved(ring: PackedVector2Array, off: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in ring:
		out.append(p + off)
	return out


static func _reversed(ring: PackedVector2Array) -> PackedVector2Array:
	var out := ring.duplicate()
	out.reverse()
	return out


## Distance (scaled to 0..1 over FIELD_RANGE) from each bed pixel to the
## nearest imprint, via a two-pass chamfer transform.
func _edge_field(cavities: Array) -> ImageTexture:
	var w := int(_bed.x * FIELD_PPM)
	var h := int(_bed.z * FIELD_PPM)
	var far := FIELD_RANGE * FIELD_PPM * 2.0
	var dist := PackedFloat32Array()
	dist.resize(w * h)
	dist.fill(far)
	var origin := Vector2(-_bed.x * 0.5, -_bed.z * 0.5)
	for c in cavities:
		var off := Vector2(c[0].x, c[0].z)
		for shape: Array in c[1]:
			var outer := _moved(shape[0], off)
			var box := Rect2(outer[0], Vector2.ZERO)
			for p in outer:
				box = box.expand(p)
			var holes: Array = []
			for i in range(1, shape.size()):
				holes.append(_moved(shape[i], off))
			var x0 := clampi(int((box.position.x - origin.x) * FIELD_PPM), 0, w - 1)
			var x1 := clampi(int((box.end.x - origin.x) * FIELD_PPM) + 1, 0, w - 1)
			var z0 := clampi(int((box.position.y - origin.y) * FIELD_PPM), 0, h - 1)
			var z1 := clampi(int((box.end.y - origin.y) * FIELD_PPM) + 1, 0, h - 1)
			for z in range(z0, z1 + 1):
				for x in range(x0, x1 + 1):
					var p := origin + (Vector2(x, z) + Vector2(0.5, 0.5)) / FIELD_PPM
					if Geometry2D.is_point_in_polygon(p, outer):
						var in_hole := false
						for hr: PackedVector2Array in holes:
							if Geometry2D.is_point_in_polygon(p, hr):
								in_hole = true
								break
						if not in_hole:
							dist[z * w + x] = 0.0
	var diag := 1.4142
	for z in h:
		for x in w:
			var i := z * w + x
			var d := dist[i]
			if x > 0:
				d = minf(d, dist[i - 1] + 1.0)
			if z > 0:
				d = minf(d, dist[i - w] + 1.0)
				if x > 0:
					d = minf(d, dist[i - w - 1] + diag)
				if x < w - 1:
					d = minf(d, dist[i - w + 1] + diag)
			dist[i] = d
	for z in range(h - 1, -1, -1):
		for x in range(w - 1, -1, -1):
			var i := z * w + x
			var d := dist[i]
			if x < w - 1:
				d = minf(d, dist[i + 1] + 1.0)
			if z < h - 1:
				d = minf(d, dist[i + w] + 1.0)
				if x < w - 1:
					d = minf(d, dist[i + w + 1] + diag)
				if x > 0:
					d = minf(d, dist[i + w - 1] + diag)
			dist[i] = d
	var bytes := PackedByteArray()
	bytes.resize(w * h)
	var scale := 255.0 / (FIELD_RANGE * FIELD_PPM)
	for i in w * h:
		bytes[i] = clampi(int(dist[i] * scale), 0, 255)
	return ImageTexture.create_from_image(Image.create_from_data(w, h, false, Image.FORMAT_L8, bytes))
