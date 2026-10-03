class_name CastMeshBuilder
## Relief: the drawing lies flat (drawing XY -> world XZ), thickness along Y,
## centered at the origin (y from -thickness/2 to +thickness/2). The top edge
## gets a chamfer so the piece reads as a cast relief.

const MAX_SHAPES := 24
## Chamfer width relative to the stroke width, capped by the thickness.
const BEVEL := 0.14
## Chamfer height / width: a bit steeper than 45° so it reads from the side too.
const BEVEL_SLOPE := 1.4
## Wall normals are smoothed across vertices that turn less than this.
const SMOOTH_ANGLE := deg_to_rad(42.0)


## Returns {mesh: ArrayMesh, shapes: Array[Shape3D], aabb: AABB, area: float (m²), volume: float (m³)}.
static func build(drawing: Drawing, size := 0.6, thickness := 0.08) -> Dictionary:
	var shapes: Array[Shape3D] = []
	var result := {mesh = ArrayMesh.new(), shapes = shapes, aabb = AABB(), area = 0.0, volume = 0.0}
	if drawing == null or drawing.is_empty():
		return result
	var polys := drawing.polygons()
	if polys.is_empty():
		return result
	var box := _bounds(polys)
	var scale := size / maxf(box.size.x, box.size.y)
	var to_local := Transform2D().scaled(Vector2(scale, scale)) * Transform2D(0.0, -box.get_center())
	var bevel := minf(drawing.brush * scale * BEVEL, thickness * 0.3 / BEVEL_SLOPE)
	var data := _MeshData.new()
	data.size = size
	var area := 0.0
	var volume := 0.0
	var outers: Array[PackedVector2Array] = []
	for shape in polys:
		var rings: Array = [to_local * shape.outer]
		for h in shape.holes:
			rings.append(to_local * h)
		var tris := DrawingGeometry.triangulate(rings)
		if tris.is_empty() and rings.size() > 1:
			rings = [rings[0]]
			tris = DrawingGeometry.triangulate(rings)
		if tris.is_empty():
			continue
		var top := _chamfered_top(rings, tris, bevel)
		_add_island(data, rings, tris, top, thickness)
		var base_area := 0.0
		var top_area := 0.0
		for i in rings.size():
			base_area += DrawingGeometry.signed_area(rings[i])
			top_area += DrawingGeometry.signed_area(top.insets[i])
		area += base_area
		var h: float = top.bevel * BEVEL_SLOPE
		volume += base_area * (thickness - h) + h * (base_area + top_area) * 0.5
		outers.append(rings[0])
	if data.indices.is_empty():
		return result
	var mesh: ArrayMesh = result.mesh
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data.arrays())
	result.aabb = mesh.get_aabb()
	result.area = area
	result.volume = volume
	shapes.append_array(_collision_shapes(outers, thickness, drawing.brush * scale))
	return result


static func _bounds(polys: Array) -> Rect2:
	var rect := Rect2(polys[0].outer[0], Vector2.ZERO)
	for shape in polys:
		for p in shape.outer:
			rect = rect.expand(p)
	return rect


## Moves each vertex into the material by `amount` along the corner bisector,
## keeping a 1:1 vertex correspondence for the chamfer band. Convex corners get
## a clamped miter; concave ones none, so insets facing each other across a
## narrow neck do not cross.
static func _inset(ring: PackedVector2Array, amount: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := ring.size()
	for i in n:
		var prev := ring[(i - 1 + n) % n]
		var p := ring[i]
		var next := ring[(i + 1) % n]
		var n0 := (p - prev).orthogonal().normalized()
		var n1 := (next - p).orthogonal().normalized()
		var dir := (n0 + n1)
		dir = dir.normalized() if dir.length_squared() > 1e-6 else n1
		var convex := (p - prev).cross(next - p) > 0.0
		var miter := amount / maxf(dir.dot(n1), 0.7) if convex else amount
		out.append(p - dir * miter)
	return out


## Inset rings and their triangulation for the top face. The inset keeps the
## base's vertex order, so the base triangulation usually still fits. Falls back
## to half the chamfer, then none, if the inset folds over itself somewhere.
static func _chamfered_top(rings: Array, base_tris: PackedInt32Array, bevel: float) -> Dictionary:
	for b in [bevel, bevel * 0.5]:
		var insets := []
		for r in rings:
			insets.append(_inset(r, b))
		var tris := base_tris
		if not _covers(insets, tris):
			tris = DrawingGeometry.triangulate(insets)
		if _covers(insets, tris):
			return {insets = insets, tris = tris, bevel = b}
	return {insets = rings, tris = base_tris, bevel = 0.0}


## True if the triangles all wind the same way (up to float noise; a flipped
## triangle would be culled and leave a pinhole) and add up to the rings' area.
static func _covers(rings: Array, tris: PackedInt32Array) -> bool:
	if tris.is_empty():
		return false
	var pos := PackedVector2Array()
	var expected := 0.0
	for r in rings:
		pos.append_array(r)
		expected += DrawingGeometry.signed_area(r)
	var ccw := 0.0
	var cw := 0.0
	for i in range(0, tris.size(), 3):
		var a := pos[tris[i]]
		var c := (pos[tris[i + 1]] - a).cross(pos[tris[i + 2]] - a) * 0.5
		if c > 0.0:
			ccw += c
		else:
			cw -= c
	return minf(ccw, cw) < expected * 1e-6 and absf(maxf(ccw, cw) - expected) < expected * 1e-3


static func _add_island(data: _MeshData, rings: Array, tris: PackedInt32Array, top: Dictionary, t: float) -> void:
	var base := PackedVector2Array()
	var top_pts := PackedVector2Array()
	for i in rings.size():
		base.append_array(rings[i])
		top_pts.append_array(top.insets[i])
	var y0 := -t * 0.5
	var y1: float = t * 0.5 - top.bevel * BEVEL_SLOPE
	var y2 := t * 0.5
	data.add_face(base, tris, y0, false)
	data.add_face(top_pts, top.tris, y2, true)
	for i in rings.size():
		var ring: PackedVector2Array = rings[i]
		var wall_n := _wall_normals(ring)
		data.add_band(ring, ring, y0, y1, wall_n, 0.0)
		if top.bevel > 0.0:
			data.add_band(ring, top.insets[i], y1, y2, wall_n, 1.0 / BEVEL_SLOPE)


## Per edge [normal at start, normal at end]: outward, smoothed across gentle corners.
static func _wall_normals(ring: PackedVector2Array) -> Array:
	var n := ring.size()
	var edge := []
	for i in n:
		var d := ring[(i + 1) % n] - ring[i]
		edge.append(d.orthogonal().normalized())
	var limit := cos(SMOOTH_ANGLE)
	var out := []
	for i in n:
		var e: Vector2 = edge[i]
		var prev: Vector2 = edge[(i - 1 + n) % n]
		var next: Vector2 = edge[(i + 1) % n]
		var start := (e + prev).normalized() if e.dot(prev) > limit else e
		var end := (e + next).normalized() if e.dot(next) > limit else e
		out.append([start, end])
	return out


## Convex prisms from a coarse convex decomposition of the outer rings, with the
## smallest pieces merged into neighbours until at most MAX_SHAPES remain.
static func _collision_shapes(outers: Array[PackedVector2Array], t: float, stroke: float) -> Array[Shape3D]:
	var pieces: Array[PackedVector2Array] = []
	for outer in outers:
		var coarse := DrawingGeometry.simplify_closed(outer, stroke * 0.12)
		var parts := Geometry2D.decompose_polygon_in_convex(coarse) if coarse.size() >= 3 else []
		if parts.is_empty():
			parts = Geometry2D.decompose_polygon_in_convex(outer)
		if parts.is_empty():
			parts = [_hull(outer)]
		for p in parts:
			pieces.append(p)
	var min_area := stroke * stroke * 0.2
	while pieces.size() > 1:
		var small := 0
		for i in pieces.size():
			if absf(DrawingGeometry.signed_area(pieces[i])) < absf(DrawingGeometry.signed_area(pieces[small])):
				small = i
		if pieces.size() <= MAX_SHAPES and absf(DrawingGeometry.signed_area(pieces[small])) >= min_area:
			break
		var other := _merge_partner(pieces, small)
		var joined := pieces[small].duplicate()
		joined.append_array(pieces[other])
		pieces[other] = _hull(joined)
		pieces.remove_at(small)
	var shapes: Array[Shape3D] = []
	for piece in pieces:
		var pts := PackedVector3Array()
		for p in piece:
			pts.append(Vector3(p.x, -t * 0.5, p.y))
			pts.append(Vector3(p.x, t * 0.5, p.y))
		var shape := ConvexPolygonShape3D.new()
		shape.points = pts
		shape.margin = minf(0.004, t * 0.1)
		shapes.append(shape)
	return shapes


## Prefers the piece sharing most vertices with `i`, else the nearest centroid.
static func _merge_partner(pieces: Array[PackedVector2Array], i: int) -> int:
	var best := -1
	var best_score := -INF
	var c := _centroid(pieces[i])
	for j in pieces.size():
		if j == i:
			continue
		var shared := 0
		for p in pieces[i]:
			for q in pieces[j]:
				if p.distance_squared_to(q) < 1e-10:
					shared += 1
		var score := shared * 1000.0 - c.distance_to(_centroid(pieces[j]))
		if score > best_score:
			best_score = score
			best = j
	return best


static func _centroid(points: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for p in points:
		sum += p
	return sum / maxf(points.size(), 1)


static func _hull(points: PackedVector2Array) -> PackedVector2Array:
	var hull := Geometry2D.convex_hull(points)
	if hull.size() > 1 and hull[0] == hull[-1]:
		hull.remove_at(hull.size() - 1)
	return hull


## Vertex/index buffers for one surface.
class _MeshData:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var size := 1.0

	## Adds a horizontal face's vertices; returns the first vertex index.
	func add_flat(points: PackedVector2Array, y: float, normal: Vector3) -> int:
		var start := verts.size()
		for p in points:
			verts.append(Vector3(p.x, y, p.y))
			normals.append(normal)
			uvs.append(p / size + Vector2(0.5, 0.5))
		return start

	## Horizontal face from 2D triangles. Godot front faces wind clockwise seen
	## from outside, which for +Y is a positive 2D cross product in drawing space.
	## The winding is decided once for all triangles so near-degenerate slivers
	## keep the topology consistent.
	func add_face(points: PackedVector2Array, tris: PackedInt32Array, y: float, up: bool) -> void:
		var start := add_flat(points, y, Vector3.UP if up else Vector3.DOWN)
		var total := 0.0
		for i in range(0, tris.size(), 3):
			var a := points[tris[i]]
			total += (points[tris[i + 1]] - a).cross(points[tris[i + 2]] - a)
		var keep := (total > 0.0) == up
		for i in range(0, tris.size(), 3):
			if keep:
				indices.append_array([start + tris[i], start + tris[i + 1], start + tris[i + 2]])
			else:
				indices.append_array([start + tris[i], start + tris[i + 2], start + tris[i + 1]])

	## Quad strip between ring `lower` at y0 and ring `upper` at y1. `tilt` is the
	## upward part of the normal: 0 for vertical walls, width/height for a chamfer.
	func add_band(lower: PackedVector2Array, upper: PackedVector2Array, y0: float, y1: float, wall_n: Array, tilt: float) -> void:
		var n := lower.size()
		var dist := 0.0
		for i in n:
			var j := (i + 1) % n
			var seg := lower[i].distance_to(lower[j])
			var start := verts.size()
			var corners := [
				[Vector3(lower[i].x, y0, lower[i].y), wall_n[i][0], Vector2(dist, y0)],
				[Vector3(lower[j].x, y0, lower[j].y), wall_n[i][1], Vector2(dist + seg, y0)],
				[Vector3(upper[j].x, y1, upper[j].y), wall_n[i][1], Vector2(dist + seg, y1)],
				[Vector3(upper[i].x, y1, upper[i].y), wall_n[i][0], Vector2(dist, y1)],
			]
			for c in corners:
				var n2: Vector2 = c[1]
				verts.append(c[0])
				normals.append((Vector3(n2.x, 0.0, n2.y) + Vector3.UP * tilt).normalized())
				uvs.append(c[2] / size)
			dist += seg
			var out := (lower[j] - lower[i]).orthogonal()
			var e1: Vector3 = corners[1][0] - corners[0][0]
			var e2: Vector3 = corners[2][0] - corners[0][0]
			if e1.cross(e2).dot(Vector3(out.x, 0.0, out.y)) < 0.0:
				indices.append_array([start, start + 1, start + 2, start, start + 2, start + 3])
			else:
				indices.append_array([start, start + 2, start + 1, start, start + 3, start + 2])

	func arrays() -> Array:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_NORMAL] = normals
		arr[Mesh.ARRAY_TEX_UV] = uvs
		arr[Mesh.ARRAY_INDEX] = indices
		return arr
