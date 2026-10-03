class_name DrawingGeometry
## 2D polygon helpers for drawings: stroke thickening, union, morphological
## closing/opening (Clipper via Geometry2D), outer/hole grouping, cleanup, and
## keyhole bridging so that polygons with holes fit Geometry2D's two-path boolean
## ops and Geometry2D.triangulate_polygon.
##
## A shape (island) is {outer: PackedVector2Array, holes: Array[PackedVector2Array]}.
## Outers have positive shoelace area (is_polygon_clockwise() == false), holes negative.

## Clipper's round joins use a fixed arc tolerance in input units, so strokes are
## offset in a space where the brush radius is this many units (~26 segments per circle).
const WORK_RADIUS := 28.0
const DOT_SEGMENTS := 28
## Morphological closing radius relative to the brush radius: concave corners get
## a fillet and nearly touching strokes fuse, like a real casting.
const FILLET := 0.25
## Morphological opening radius relative to the brush radius: necks thinner than
## twice this are cut, so the chamfer inset never folds over itself.
const MIN_NECK := 0.35
## Cleanup thresholds relative to the brush radius; areas relative to a dot's area.
const MIN_SPACING := 0.14
const COLLINEAR_TOLERANCE := 0.012
const MIN_OUTER_AREA := 0.35
const MIN_HOLE_AREA := 0.5
const MIN_HOLE_WIDTH := 0.4


## Union of all thickened strokes as clean, simplified shapes in input space.
static func outline(strokes: Array[PackedVector2Array], radius: float) -> Array:
	if strokes.is_empty() or radius <= 0.0:
		return []
	var k := WORK_RADIUS / radius
	var fillet := WORK_RADIUS * FILLET
	var neck := WORK_RADIUS * MIN_NECK
	var to_work := Transform2D().scaled(Vector2(k, k))
	var pieces := []
	for s in strokes:
		if not s.is_empty():
			pieces.append(group_rings(sanitized(_thicken(to_work * s, WORK_RADIUS + fillet))))
	# Closing then opening: dilate (above) and erode by the fillet, erode and
	# dilate by the neck radius.
	var opened := []
	for island in _union_all(pieces):
		for core in _eroded(island, fillet + neck):
			opened.append(_dilated(core, neck))
	var shapes := _cleaned(_union_all(opened), WORK_RADIUS)
	var back := Transform2D().scaled(Vector2.ONE / k)
	for s in shapes:
		s.outer = back * s.outer
		var holes: Array[PackedVector2Array] = []
		for h in s.holes:
			holes.append(back * h)
		s.holes = holes
	return shapes


## Splits rings into outers and holes, and assigns each hole to the smallest
## outer containing it. Returns shapes.
static func group_rings(rings: Array) -> Array:
	var outers := []
	var holes := []
	for r: PackedVector2Array in rings:
		if r.size() < 3:
			continue
		if Geometry2D.is_polygon_clockwise(r):
			holes.append(r)
		else:
			outers.append({outer = r, holes = [] as Array[PackedVector2Array], area = signed_area(r)})
	outers.sort_custom(func(a, b): return a.area < b.area)
	for h: PackedVector2Array in holes:
		for o in outers:
			if _contains_ring(o.outer, h):
				o.holes.append(h)
				break
	for o in outers:
		o.erase("area")
	return outers


## Clipper may return weakly simple rings (a hole joined to its outer by a
## zero-width slit, or spikes). Splits rings at repeated vertices and removes
## fold-backs so every ring is a plain simple loop.
static func sanitized(rings: Array) -> Array:
	var out := []
	var todo := rings.duplicate()
	while not todo.is_empty():
		var r := _without_folds(todo.pop_back())
		if r.size() < 3:
			continue
		var parts := _split_at_repeat(r)
		if not parts.is_empty():
			todo.append_array(parts)
		elif absf(signed_area(r)) > 1e-6:
			out.append(r)
	return out


## Shoelace area; positive for outers.
static func signed_area(ring: PackedVector2Array) -> float:
	var a := 0.0
	var n := ring.size()
	for i in n:
		a += ring[i].cross(ring[(i + 1) % n])
	return a * 0.5


static func shape_area(shape: Dictionary) -> float:
	var a := signed_area(shape.outer)
	for h in shape.holes:
		a += signed_area(h)
	return a


## Douglas-Peucker simplification of an open polyline.
static func simplify_open(points: PackedVector2Array, tolerance: float) -> PackedVector2Array:
	if points.size() < 3:
		return points
	var keep := PackedByteArray()
	keep.resize(points.size())
	keep[0] = 1
	keep[-1] = 1
	var stack := [Vector2i(0, points.size() - 1)]
	while not stack.is_empty():
		var span: Vector2i = stack.pop_back()
		var a := points[span.x]
		var b := points[span.y]
		var worst := -1
		var worst_d := tolerance
		for i in range(span.x + 1, span.y):
			var d := _segment_distance(points[i], a, b)
			if d > worst_d:
				worst_d = d
				worst = i
		if worst >= 0:
			keep[worst] = 1
			stack.append(Vector2i(span.x, worst))
			stack.append(Vector2i(worst, span.y))
	var out := PackedVector2Array()
	for i in points.size():
		if keep[i]:
			out.append(points[i])
	return out


## Douglas-Peucker for a closed ring, split at the vertex farthest from vertex 0.
static func simplify_closed(ring: PackedVector2Array, tolerance: float) -> PackedVector2Array:
	if ring.size() < 5:
		return ring
	var far := 0
	for i in ring.size():
		if ring[i].distance_squared_to(ring[0]) > ring[far].distance_squared_to(ring[0]):
			far = i
	var first := simplify_open(ring.slice(0, far + 1), tolerance)
	var second := ring.slice(far)
	second.append(ring[0])
	second = simplify_open(second, tolerance)
	first.append_array(second.slice(1, second.size() - 1))
	return first


## Single weakly simple ring of a shape: every hole is joined to the outer by a
## zero-width bridge that crosses nothing. Holes that cannot be bridged are left out.
static func keyhole(shape: Dictionary) -> PackedVector2Array:
	var rings := [shape.outer]
	rings.append_array(shape.holes)
	var k := _keyhole_ids(rings)
	if k.poly.is_empty():
		return shape.outer
	var pts := PackedVector2Array()
	for id in k.poly:
		pts.append(k.pos[id])
	return pts


## Triangulates an outer ring with holes (`rings[0]` is the outer) via keyhole
## bridging and ear clipping. Returns triangle indices into the rings
## concatenated in order, or an empty array on failure.
static func triangulate(rings: Array) -> PackedInt32Array:
	var k := _keyhole_ids(rings)
	var poly: PackedInt32Array = k.poly
	var pos: PackedVector2Array = k.pos
	if poly.is_empty():
		return PackedInt32Array()
	# The ear clipper uses an absolute epsilon, so work at a fixed scale where
	# slightly reflex vertices are not mistaken for ears.
	var box := Rect2(pos[0], Vector2.ZERO)
	for p in pos:
		box = box.expand(p)
	var s := 1000.0 / maxf(box.size.x, maxf(box.size.y, 1e-9))
	var pts := PackedVector2Array()
	for id in poly:
		pts.append((pos[id] - box.position) * s)
	var tris := Geometry2D.triangulate_polygon(pts)
	for i in tris.size():
		tris[i] = poly[tris[i]]
	return tris


## Counter-clockwise (positive area) regular polygon.
static func circle(center: Vector2, radius: float, segments: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in segments:
		var t := TAU * i / segments
		out.append(center + Vector2(cos(t), sin(t)) * radius)
	return out


static func _thicken(points: PackedVector2Array, radius: float) -> Array:
	var spread := Rect2(points[0], Vector2.ZERO)
	for p in points:
		spread = spread.expand(p)
	if spread.size.length() < WORK_RADIUS * 0.05:
		return [circle(spread.get_center(), radius, DOT_SEGMENTS)]
	return Geometry2D.offset_polyline(points, radius, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND)


## Union of lists of disjoint shapes, merged pairwise in a balanced tree so
## that big shapes take part in few boolean operations.
static func _union_all(groups: Array) -> Array:
	if groups.is_empty():
		return []
	while groups.size() > 1:
		var next := []
		for i in range(0, groups.size() - 1, 2):
			var merged: Array = groups[i]
			for piece in groups[i + 1]:
				merged = _with_island(merged, piece)
			next.append(merged)
		if groups.size() % 2 == 1:
			next.append(groups[-1])
		groups = next
	return groups[0]


## Adds `piece` to a list of disjoint shapes, fusing it with every shape it overlaps.
static func _with_island(islands: Array, piece: Dictionary) -> Array:
	var out := []
	var merged := piece
	for island in islands:
		var joined := _union(merged, island)
		if joined.size() == 1:
			merged = joined[0]
		else:
			out.append(island)
	out.append(merged)
	return out


## Union of two shapes; two separate shapes come back when they do not touch.
static func _union(a: Dictionary, b: Dictionary) -> Array:
	if not _box(a.outer).intersects(_box(b.outer), true):
		return [a, b]
	if Geometry2D.intersect_polygons(a.outer, b.outer).is_empty() or _in_hole(a, b) or _in_hole(b, a):
		return [a, b]
	return group_rings(sanitized(Geometry2D.merge_polygons(keyhole(a), keyhole(b))))


## True if `inner` lies entirely inside one of the holes of `shape`.
static func _in_hole(shape: Dictionary, inner: Dictionary) -> bool:
	var box := _box(inner.outer)
	for h in shape.holes:
		if _box(h).encloses(box) and Geometry2D.clip_polygons(inner.outer, h).is_empty():
			return true
	return false


## Shrinks one shape by `amount`: the outer moves in, the holes grow. Grown
## holes that stay inside the material become holes as they are; only those
## cutting through the outline need a boolean subtraction.
static func _eroded(island: Dictionary, amount: float) -> Array:
	var current := _offset_shapes(island.outer, -amount)
	var cuts := []
	for h in island.holes:
		for piece in _offset_shapes(_flipped(h), amount):
			cuts = _with_island(cuts, piece)
	var inner: Array[PackedVector2Array] = []
	var crossing := []
	for cut in cuts:
		if cut.holes.is_empty() and _inside_any(cut.outer, current):
			inner.append(_flipped(cut.outer))
		else:
			crossing.append(cut)
	for cut in crossing:
		current = _subtract(current, cut)
	for hole in inner:
		for shape in current:
			if _in_material(shape, hole[0]):
				shape.holes.append(hole)
				break
	return current


## Grows one shape by `amount`: the outer moves out, the holes shrink. Shrunk
## holes lie inside the old outer, so they cannot meet the new boundary.
static func _dilated(island: Dictionary, amount: float) -> Array:
	var rings := Geometry2D.offset_polygon(island.outer, amount, Geometry2D.JOIN_ROUND)
	for h in island.holes:
		for piece in Geometry2D.offset_polygon(_flipped(h), -amount, Geometry2D.JOIN_ROUND):
			if not Geometry2D.is_polygon_clockwise(piece):
				rings.append(_flipped(piece))
	return group_rings(sanitized(rings))


## True if `ring` lies inside the outer of one of `shapes`.
static func _inside_any(ring: PackedVector2Array, shapes: Array) -> bool:
	var box := _box(ring)
	for shape in shapes:
		if _box(shape.outer).encloses(box) and Geometry2D.clip_polygons(ring, shape.outer).is_empty():
			return true
	return false


## True if `p` lies inside the outer of `shape` but in none of its holes.
static func _in_material(shape: Dictionary, p: Vector2) -> bool:
	if not Geometry2D.is_point_in_polygon(p, shape.outer):
		return false
	for h in shape.holes:
		if Geometry2D.is_point_in_polygon(p, h):
			return false
	return true


static func _offset_shapes(ring: PackedVector2Array, amount: float) -> Array:
	return group_rings(sanitized(Geometry2D.offset_polygon(ring, amount, Geometry2D.JOIN_ROUND)))


static func _subtract(shapes: Array, cut: Dictionary) -> Array:
	var out := []
	var cut_box := _box(cut.outer)
	for shape in shapes:
		if _box(shape.outer).intersects(cut_box, true):
			out.append_array(group_rings(sanitized(Geometry2D.clip_polygons(keyhole(shape), keyhole(cut)))))
		else:
			out.append(shape)
	return out


static func _flipped(ring: PackedVector2Array) -> PackedVector2Array:
	var out := ring.duplicate()
	out.reverse()
	return out


## Thins vertices, drops slivers and specks. `radius` is the brush radius.
static func _cleaned(shapes: Array, radius: float) -> Array:
	var dot_area := PI * radius * radius
	var out := []
	for s in shapes:
		var outer := _decimated(s.outer, radius)
		if outer.size() < 3 or signed_area(outer) < dot_area * MIN_OUTER_AREA:
			continue
		var holes: Array[PackedVector2Array] = []
		for h in s.holes:
			var hole := _decimated(h, radius)
			var area := -signed_area(hole)
			if hole.size() < 3 or area < dot_area * MIN_HOLE_AREA:
				continue
			if area / _perimeter(hole) < radius * MIN_HOLE_WIDTH * 0.5:
				continue
			holes.append(hole)
		out.append({outer = outer, holes = holes})
	return out


## Distance-based decimation (drop vertices closer than MIN_SPACING to the last
## kept one), then removal of nearly collinear vertices.
static func _decimated(ring: PackedVector2Array, radius: float) -> PackedVector2Array:
	var spacing := radius * MIN_SPACING
	var kept := PackedVector2Array()
	for p in ring:
		if kept.is_empty() or p.distance_to(kept[-1]) >= spacing:
			kept.append(p)
	while kept.size() > 3 and kept[-1].distance_to(kept[0]) < spacing:
		kept.remove_at(kept.size() - 1)
	var tol := radius * COLLINEAR_TOLERANCE
	var out := PackedVector2Array()
	var n := kept.size()
	for i in n:
		var prev := out[-1] if not out.is_empty() else kept[(i - 1 + n) % n]
		if _segment_distance(kept[i], prev, kept[(i + 1) % n]) >= tol:
			out.append(kept[i])
	return out


static func _split_at_repeat(r: PackedVector2Array) -> Array:
	var sorted := r.duplicate()
	sorted.sort()
	var repeated := false
	for i in range(1, sorted.size()):
		if sorted[i].distance_squared_to(sorted[i - 1]) < 1e-6:
			repeated = true
			break
	if not repeated:
		return []
	var seen := {}
	for i in r.size():
		var key := Vector2i((r[i] * 1000.0).round())
		if seen.has(key):
			var j: int = seen[key]
			var rest := r.slice(i)
			rest.append_array(r.slice(0, j))
			return [r.slice(j, i), rest]
		seen[key] = i
	return []


static func _without_folds(r: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in r:
		if not out.is_empty() and out[-1].distance_squared_to(p) < 1e-8:
			continue
		out.append(p)
		while out.size() >= 3 and _is_fold(out[-3], out[-2], out[-1]):
			out.remove_at(out.size() - 2)
	var changed := true
	while changed and out.size() >= 3:
		changed = false
		if out[-1].distance_squared_to(out[0]) < 1e-8:
			out.remove_at(out.size() - 1)
			changed = true
		elif _is_fold(out[-2], out[-1], out[0]):
			out.remove_at(out.size() - 1)
			changed = true
		elif _is_fold(out[-1], out[0], out[1]):
			out.remove_at(0)
			changed = true
	return out


## True if the path a -> b -> c turns back on itself at b.
static func _is_fold(a: Vector2, b: Vector2, c: Vector2) -> bool:
	var u := b - a
	var v := c - b
	return u.dot(v) < 0.0 and absf(u.cross(v)) <= 1e-6 * u.length() * v.length() + 1e-9


static func _box(ring: PackedVector2Array) -> Rect2:
	var rect := Rect2(ring[0], Vector2.ZERO)
	for p in ring:
		rect = rect.expand(p)
	return rect


static func _perimeter(ring: PackedVector2Array) -> float:
	var length := 0.0
	for i in ring.size():
		length += ring[i].distance_to(ring[(i + 1) % ring.size()])
	return maxf(length, 0.0001)


static func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))


static func _contains_ring(outer: PackedVector2Array, ring: PackedVector2Array) -> bool:
	for i in [0, int(ring.size() / 3.0), int(ring.size() * 2 / 3.0)]:
		if Geometry2D.is_point_in_polygon(ring[i], outer):
			return true
	return false


## Joins holes into the outer (rings[0]) with Eberly's bridges, processing holes
## by decreasing max x. Returns {pos: all ring vertices, poly: vertex ids along
## the keyhole ring}; poly is empty if a hole cannot be bridged.
static func _keyhole_ids(rings: Array) -> Dictionary:
	var pos := PackedVector2Array()
	var starts := PackedInt32Array()
	for r: PackedVector2Array in rings:
		starts.append(pos.size())
		pos.append_array(r)
	var poly := PackedInt32Array(range(rings[0].size()))
	var order := range(1, rings.size())
	order.sort_custom(func(a, b): return _max_x(rings[a]) > _max_x(rings[b]))
	for h in order:
		var hole: PackedVector2Array = rings[h]
		var m := 0
		for i in hole.size():
			if hole[i].x > hole[m].x:
				m = i
		var target := _bridge_target(poly, pos, hole[m])
		if target < 0:
			return {pos = pos, poly = PackedInt32Array()}
		var spliced := poly.slice(0, target + 1)
		for j in hole.size() + 1:
			spliced.append(starts[h] + (m + j) % hole.size())
		spliced.append(poly[target])
		spliced.append_array(poly.slice(target + 1))
		poly = spliced
	return {pos = pos, poly = poly}


static func _max_x(ring: PackedVector2Array) -> float:
	var x := -INF
	for p in ring:
		x = maxf(x, p.x)
	return x


## Eberly's hole bridging: cast a ray from the hole's rightmost point `m` to +x,
## take the nearest boundary edge that faces the ray, then prefer a reflex vertex
## inside the triangle (m, hit, candidate) with the smallest angle to the ray.
static func _bridge_target(poly: PackedInt32Array, pos: PackedVector2Array, m: Vector2) -> int:
	var n := poly.size()
	var best_dx := INF
	var target := -1
	var hit := Vector2()
	for i in n:
		var a := pos[poly[i]]
		var b := pos[poly[(i + 1) % n]]
		if not (a.y <= m.y and m.y <= b.y and a.y < b.y):
			continue
		var x := a.x + (m.y - a.y) / (b.y - a.y) * (b.x - a.x)
		var dx := x - m.x
		if dx < -1e-9 or dx >= best_dx:
			continue
		best_dx = dx
		hit = Vector2(x, m.y)
		target = i if a.x > b.x else (i + 1) % n
	if target < 0:
		return -1
	var p := pos[poly[target]]
	if p.is_equal_approx(hit):
		return _pick_duplicate(poly, pos, target, m)
	var best_angle := INF
	var best_dist := INF
	var tri_box := Rect2(m, Vector2.ZERO).expand(hit).expand(p)
	for i in n:
		var v := pos[poly[i]]
		if v == p or not tri_box.has_point(v):
			continue
		if not Geometry2D.point_is_inside_triangle(v, m, hit, p) or not _is_reflex(poly, pos, i):
			continue
		var angle := absf((v - m).angle())
		var dist := v.distance_squared_to(m)
		if angle < best_angle - 1e-9 or (absf(angle - best_angle) <= 1e-9 and dist < best_dist):
			best_angle = angle
			best_dist = dist
			target = i
	return _pick_duplicate(poly, pos, target, m)


## A vertex can appear twice after earlier bridges; use the copy whose interior
## wedge contains the direction towards `m`.
static func _pick_duplicate(poly: PackedInt32Array, pos: PackedVector2Array, target: int, m: Vector2) -> int:
	var p := pos[poly[target]]
	var n := poly.size()
	for i in n:
		if pos[poly[i]] != p:
			continue
		var prev := pos[poly[(i - 1 + n) % n]]
		var next := pos[poly[(i + 1) % n]]
		var left_in := (p - prev).cross(m - prev) > 0.0
		var left_out := (next - p).cross(m - p) > 0.0
		var convex := (p - prev).cross(next - p) >= 0.0
		if (convex and left_in and left_out) or (not convex and (left_in or left_out)):
			return i
	return target


static func _is_reflex(poly: PackedInt32Array, pos: PackedVector2Array, i: int) -> bool:
	var n := poly.size()
	var prev := pos[poly[(i - 1 + n) % n]]
	var v := pos[poly[i]]
	var next := pos[poly[(i + 1) % n]]
	return (v - prev).cross(next - v) < 0.0
