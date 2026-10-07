class_name WorkerGear
extends RefCounted
## Procedural safety gear for the rigged worker: a hard hat built around the
## KayKit head (bone space of the shared rig, unscaled units, faces +Z) and a
## leather apron skinned to the body. The meshes are cached and shared by
## every worker; only materials differ.

## Head bone height in the rig's rest pose; the hat is modelled in rest space and shifted by it.
const HEAD_BONE_Y := 1.241
## Shell ellipsoid: centre and radii (x, y, z). The tightest dome that still
## clears the boxy chibi cranium (fitted against the head mesh, 1–2.5 cm) when
## the hat is tipped back by PlayerModel.HAT_TILT: it sits high on the head, so
## the brow, eyes and cheeks stay free from the high game camera.
const SHELL_CENTER := Vector3(0.0, 1.88, -0.04)
const SHELL_RADII := Vector3(0.48, 0.37, 0.49)
## Brim widths: sides, front peak, back.
const BRIM_SIDE := 0.034
const BRIM_FRONT := 0.15
const BRIM_BACK := 0.07
const BRIM_THICKNESS := 0.03
## Height band (polar angle from the top, radians) of the reflective stickers.
const STRIPE_FROM := 1.18
const STRIPE_TO := 1.33

const SEG := 40
const RINGS := 14

## Short hair: how far the copied back-of-head surface sits off the skin (rig units).
const HAIR_LIFT := 0.014

## Leather apron (rest space, rig units; 0.8 m per unit in the game): from
## under the beard down to just below the skirt's hem.
const APRON_TOP := 1.11
const APRON_BOTTOM := 0.33
## Depth of the apron's centre line (y, z): over the chest, round the belly
## (2.5–3.5 cm clear of the body), then hanging straight in front of the skirt.
const APRON_DEPTH: Array[Vector2] = [Vector2(1.11, 0.3), Vector2(1.0, 0.305), Vector2(0.92, 0.325), Vector2(0.84, 0.355),
	Vector2(0.75, 0.38), Vector2(0.62, 0.39), Vector2(0.42, 0.388), Vector2(0.33, 0.384)]
## Half width (y, half width): a narrow bib that flares out at the waist.
const APRON_HALF_WIDTH: Array[Vector2] = [Vector2(1.11, 0.15), Vector2(0.98, 0.17), Vector2(0.86, 0.26),
	Vector2(0.7, 0.29), Vector2(0.33, 0.3)]
## The apron wraps round the barrel-shaped body: cross-section ellipse rx / rz.
const APRON_WRAP := 1.2
## Rolled, stitched hem along every edge.
const APRON_HEM := 0.028
## Height of the waist ties that run round the back.
const APRON_TIE_Y := 0.83

static var _hat_parts: Array[ArrayMesh] = []
static var _hair: ArrayMesh
static var _apron: ArrayMesh


## Hard hat as three single-surface meshes: [shell with crest and brim, reflective
## stripe, dark harness clips]. Separate meshes let every part take its own
## `material_override` (player colour, or the bronze of a statue).
## Vertex colours shade the shell (lighter crown, darker brim underside) so it is
## never one flat colour.
static func hard_hat_parts() -> Array[ArrayMesh]:
	if not _hat_parts.is_empty():
		return _hat_parts
	var shell := SurfaceTool.new()
	shell.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_shell(shell)
	_add_crest(shell)
	_add_brim(shell)
	var stripe := SurfaceTool.new()
	stripe.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Reflective stickers on both sides and the back – a full ring band would
	# read as a bowler hat.
	for span in [Vector2(0.95, 1.95), Vector2(-1.95, -0.95), Vector2(PI - 0.5, PI + 0.5)]:
		_add_band(stripe, STRIPE_FROM, STRIPE_TO, 0.012, span.x, span.y)
	var clips := SurfaceTool.new()
	clips.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0, 1.0]:
		_add_clip(clips, side)
	for st in [shell, stripe, clips]:
		_hat_parts.append((st as SurfaceTool).commit())
	return _hat_parts


## Point on the shell ellipsoid at polar angle `theta` (0 = crown) and azimuth `phi` (0 = front, +Z).
static func shell_point(theta: float, phi: float, grow := 0.0) -> Vector3:
	var r := SHELL_RADII + Vector3.ONE * grow
	var p := SHELL_CENTER + Vector3(r.x * sin(theta) * sin(phi), r.y * cos(theta), r.z * sin(theta) * cos(phi))
	return p - Vector3(0, HEAD_BONE_Y, 0)


static func shell_normal(theta: float, phi: float) -> Vector3:
	var r := SHELL_RADII
	var d := Vector3(sin(theta) * sin(phi) / r.x, cos(theta) / r.y, sin(theta) * cos(phi) / r.z)
	return d.normalized()


static func _add_shell(st: SurfaceTool) -> void:
	var half_pi := PI * 0.5
	for i in RINGS:
		var t0 := half_pi * i / RINGS
		var t1 := half_pi * (i + 1) / RINGS
		for j in SEG:
			var p0 := TAU * j / SEG
			var p1 := TAU * (j + 1) / SEG
			_quad_on_shell(st, t0, t1, p0, p1, 0.0)


## Raised ribs over the crown from the front to the back – the signature of a
## hard hat: a tall centre ridge flanked by two lower, shorter ribs.
static func _add_crest(st: SurfaceTool) -> void:
	_add_rib(st, 0.0, 1.3, 0.12, 0.042)
	for side in [-1.0, 1.0]:
		_add_rib(st, side * 0.17, 1.12, 0.06, 0.024)


## One rib running front to back in the plane x = `offset` (shell space), over
## the arc |a| <= `reach` (a = polar angle in that plane; 0 = top), tapering
## into the shell at both ends.
static func _add_rib(st: SurfaceTool, offset: float, reach: float, half_width: float, height: float) -> void:
	var steps := 30
	# Rounded profile across the rib: (side offset, lift) from left foot to right foot.
	var profile := [Vector2(-1.0, -0.3), Vector2(-0.8, 0.5), Vector2(-0.45, 0.92), Vector2(0.0, 1.0),
		Vector2(0.45, 0.92), Vector2(0.8, 0.5), Vector2(1.0, -0.3)]
	var r := SHELL_RADII
	var squeeze := sqrt(maxf(0.0, 1.0 - pow(offset / r.x, 2.0)))
	var rows: Array[PackedVector3Array] = []
	var normals: Array[PackedVector3Array] = []
	for s in steps + 1:
		var a := lerpf(-reach, reach, float(s) / steps)
		var local := Vector3(offset, r.y * squeeze * cos(a), -r.z * squeeze * sin(a))
		var center := SHELL_CENTER + local - Vector3(0, HEAD_BONE_Y, 0)
		var n := Vector3(local.x / (r.x * r.x), local.y / (r.y * r.y), local.z / (r.z * r.z)).normalized()
		var side := (Vector3.RIGHT - n * n.dot(Vector3.RIGHT)).normalized()
		var taper := smoothstep(0.0, 0.3, reach - absf(a))
		var row := PackedVector3Array()
		var nrow := PackedVector3Array()
		for k in profile.size():
			var pr: Vector2 = profile[k]
			row.append(center + side * pr.x * half_width + n * pr.y * height * taper)
			var slope := -pr.x * 1.4 if absf(pr.x) > 0.2 else 0.0
			nrow.append((n + side * slope * taper).normalized())
		rows.append(row)
		normals.append(nrow)
	for s in steps:
		var shade := 1.0 - absf(lerpf(-1.0, 1.0, (s + 0.5) / steps)) * 0.12
		for k in profile.size() - 1:
			_tri_strip(st, rows[s][k], rows[s][k + 1], rows[s + 1][k + 1], rows[s + 1][k],
				normals[s][k], normals[s][k + 1], normals[s + 1][k + 1], normals[s + 1][k], Color(shade, shade, shade))


## Brim ring around the shell base, wide peak at the front, drooping slightly at the edge.
static func _add_brim(st: SurfaceTool) -> void:
	var base := PI * 0.5
	for j in SEG:
		var p0 := TAU * j / SEG
		var p1 := TAU * (j + 1) / SEG
		var in0 := shell_point(base, p0, -0.01)
		var in1 := shell_point(base, p1, -0.01)
		var out0 := _brim_outer(p0)
		var out1 := _brim_outer(p1)
		var down := Vector3(0, -BRIM_THICKNESS, 0)
		var up_n0 := (Vector3.UP * 3.0 + (out0 - in0).normalized()).normalized()
		var up_n1 := (Vector3.UP * 3.0 + (out1 - in1).normalized()).normalized()
		# Top face (lit), underside (shaded), outer lip.
		_tri_strip(st, in0, in1, out1, out0, up_n0, up_n1, up_n1, up_n0, Color(0.93, 0.93, 0.93))
		_tri_strip(st, out0 + down, out1 + down, in1 + down, in0 + down, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN, Color(0.45, 0.45, 0.45))
		var o0 := Vector3(sin(p0), 0, cos(p0))
		var o1 := Vector3(sin(p1), 0, cos(p1))
		_tri_strip(st, out0, out1, out1 + down, out0 + down, o0, o1, o1, o0, Color(0.72, 0.72, 0.72))


static func _brim_outer(phi: float) -> Vector3:
	var front := maxf(cos(phi), 0.0)
	var back := maxf(-cos(phi), 0.0)
	var width := BRIM_SIDE + BRIM_FRONT * pow(front, 2.5) + BRIM_BACK * back * back
	var p := shell_point(PI * 0.5, phi)
	var dir := Vector3(sin(phi), 0, cos(phi))
	# The peak tips down to shade the brow; the sides curl up like a rain gutter.
	var side := absf(sin(phi))
	return p + dir * width + Vector3(0, -0.05 * pow(front, 2.0) + 0.022 * side - 0.006, 0)


## Band hugging the shell between two polar angles and two azimuths (a sticker).
static func _add_band(st: SurfaceTool, from: float, to: float, grow: float, phi_from: float, phi_to: float) -> void:
	var steps := 3
	var segs := maxi(2, ceili((phi_to - phi_from) / TAU * SEG))
	for i in steps:
		var t0 := lerpf(from, to, float(i) / steps)
		var t1 := lerpf(from, to, float(i + 1) / steps)
		for j in segs:
			_quad_on_shell(st, t0, t1, lerpf(phi_from, phi_to, float(j) / segs), lerpf(phi_from, phi_to, float(j + 1) / segs), grow)


## Small dark harness clip on each side of the shell.
static func _add_clip(st: SurfaceTool, side: float) -> void:
	var phi := side * PI * 0.5
	var center := shell_point(1.42, phi, 0.006)
	var n := shell_normal(1.42, phi)
	var t := Vector3.FORWARD.cross(n).normalized()
	var b := n.cross(t).normalized()
	var w := 0.05
	var h := 0.035
	var d := 0.018
	var corners := [Vector2(-w, -h), Vector2(w, -h), Vector2(w, h), Vector2(-w, h)]
	var outer := PackedVector3Array()
	var inner := PackedVector3Array()
	for c in corners:
		var v: Vector2 = c
		outer.append(center + t * v.x + b * v.y + n * d)
		inner.append(center + t * v.x * 0.8 + b * v.y * 0.8 - n * 0.01)
	_tri_strip(st, outer[0], outer[1], outer[2], outer[3], n, n, n, n, Color.WHITE)
	for k in 4:
		var k2 := (k + 1) % 4
		var sn := ((outer[k] + outer[k2]) * 0.5 - center).normalized()
		_tri_strip(st, inner[k], inner[k2], outer[k2], outer[k], sn, sn, sn, sn, Color.WHITE)


static func _quad_on_shell(st: SurfaceTool, t0: float, t1: float, p0: float, p1: float, grow: float) -> void:
	var a := shell_point(t0, p0, grow)
	var b := shell_point(t0, p1, grow)
	var c := shell_point(t1, p1, grow)
	var d := shell_point(t1, p0, grow)
	# Crown is lighter than the rim: a painted top-down gradient (art bible rule 1).
	var ca := Color.WHITE * lerpf(1.0, 0.8, t0 / (PI * 0.5))
	var cd := Color.WHITE * lerpf(1.0, 0.8, t1 / (PI * 0.5))
	ca.a = 1.0
	cd.a = 1.0
	_vert(st, a, shell_normal(t0, p0), ca)
	_vert(st, b, shell_normal(t0, p1), ca)
	_vert(st, c, shell_normal(t1, p1), cd)
	_vert(st, a, shell_normal(t0, p0), ca)
	_vert(st, c, shell_normal(t1, p1), cd)
	_vert(st, d, shell_normal(t1, p0), cd)


## Quad a-b-c-d as two triangles. The winding is flipped when needed so the
## face points along the given normals (Godot front faces wind clockwise).
static func _tri_strip(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		na: Vector3, nb: Vector3, nc: Vector3, nd: Vector3, color: Color) -> void:
	if (b - a).cross(c - a).dot(na + nb + nc + nd) > 0.0:
		_vert(st, a, na, color)
		_vert(st, c, nc, color)
		_vert(st, b, nb, color)
		_vert(st, a, na, color)
		_vert(st, d, nd, color)
		_vert(st, c, nc, color)
		return
	_vert(st, a, na, color)
	_vert(st, b, nb, color)
	_vert(st, c, nc, color)
	_vert(st, a, na, color)
	_vert(st, c, nc, color)
	_vert(st, d, nd, color)


static func _vert(st: SurfaceTool, p: Vector3, n: Vector3, color: Color) -> void:
	st.set_color(color)
	st.set_normal(n)
	st.add_vertex(p)


## Short hair under the hat (rest space, like the head mesh it is built from):
## the back half of the KayKit `head` mesh lifted HAIR_LIFT along its normals so
## it hugs the skull exactly. worker_hair.gdshader cuts the smooth hairline.
static func hair_mesh(head: Mesh) -> ArrayMesh:
	if _hair:
		return _hair
	var arrays := head.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for t in range(0, indices.size(), 3):
		var centre := (verts[indices[t]] + verts[indices[t + 1]] + verts[indices[t + 2]]) / 3.0
		if centre.z > 0.1 or centre.y < 1.3 or centre.y > 2.0:
			continue
		for k in 3:
			var i := indices[t + k]
			st.set_normal(normals[i])
			st.add_vertex(verts[i] + normals[i] * HAIR_LIFT)
	_hair = st.commit()
	return _hair



## Leather work apron in the rig's rest space, skinned to the shared rig so it
## bends, breathes and strides with the body: a bib under the beard that
## flares over the belly and hangs free in front of the skirt, a rolled hem
## with stitching, a belly pocket, straps up to the neck, waist ties round the
## back with hanging ends, and steel rivets. Bone weights are blended from the
## nearest vertices of `body` (the KayKit torso mesh), so the apron uses its
## Skin. Vertex colours for worker_apron.gdshader: r = hem, g = position
## across the hem (stitches at 0.5), b = rivet. UV = arc lengths (x, down).
static func apron_mesh(body: Mesh) -> ArrayMesh:
	if _apron:
		return _apron
	var g := _Geo.new()
	_apron_sheet(g, -1.0, 1.0, APRON_TOP, APRON_BOTTOM, 0.0, APRON_HEM, 10, 13)
	# Belly pocket, its opening at the top.
	_apron_sheet(g, -0.38, 0.38, 0.68, 0.5, 0.009, 0.02, 4, 3)
	for s: float in [-1.0, 1.0]:
		var corner := _apron_point(s * 0.8, APRON_TOP - 0.03, 0.004)
		_ribbon(g, PackedVector3Array([corner, Vector3(s * 0.13, 1.18, 0.275), Vector3(s * 0.15, 1.25, 0.2),
			Vector3(s * 0.16, 1.31, 0.07)]), 0.036, Vector3(0, 0.6, 1.0))
		_rivet(g, s * 0.8, APRON_TOP - 0.03)
		_rivet(g, s * 0.34, 0.665)
		# Hanging tie end at the back knot.
		_ribbon(g, PackedVector3Array([Vector3(s * 0.02, APRON_TIE_Y, -0.36), Vector3(s * 0.05, APRON_TIE_Y - 0.1, -0.375),
			Vector3(s * 0.07, APRON_TIE_Y - 0.2, -0.37)]), 0.03, Vector3(0, 0, -1))
	_waist_tie(g)
	g.skin_from(body)
	_apron = g.commit()
	return _apron


## Point on the apron at `s` (-1 left edge .. 1 right edge) and height `y`,
## pushed `lift` along the surface normal (pocket, rivets).
static func _apron_point(s: float, y: float, lift := 0.0) -> Vector3:
	var rz := _table(APRON_DEPTH, y)
	var rx := rz * APRON_WRAP
	var x := s * _table(APRON_HALF_WIDTH, y)
	var z := rz * sqrt(maxf(1.0 - (x / rx) * (x / rx), 0.0))
	if lift == 0.0:
		return Vector3(x, y, z)
	return Vector3(x, y, z) + _apron_normal(s, y) * lift


static func _apron_normal(s: float, y: float) -> Vector3:
	var e := 0.004
	var ds := _apron_point(s + e, y) - _apron_point(s - e, y)
	var dy := _apron_point(s, y + e) - _apron_point(s, y - e)
	var n := ds.cross(dy).normalized()
	return n if n.z >= 0.0 else -n


## Piecewise-linear lookup in a (y, value) table sorted top to bottom.
static func _table(table: Array[Vector2], y: float) -> float:
	if y >= table[0].x:
		return table[0].y
	for i in table.size() - 1:
		var a := table[i]
		var b := table[i + 1]
		if y >= b.x:
			return lerpf(a.y, b.y, (y - a.x) / (b.x - a.x))
	return table[-1].y


## Hemmed leather panel on the apron surface between s0..s1 and y0 (top)..y1.
## Each edge gets a hem band `hem` wide with a crisp inner line.
static func _apron_sheet(g: _Geo, s0: float, s1: float, y0: float, y1: float, lift: float, hem: float, cols: int, rows: int) -> void:
	var ys := _hem_steps(y0, y1, hem, rows)
	var grid: Array[PackedInt32Array] = []
	for i in ys.size():
		var y: float = ys[i][0]
		var half := _table(APRON_HALF_WIDTH, y)
		var ss := _hem_steps(s0, s1, hem / half, cols)
		var row := PackedInt32Array()
		for j in ss.size():
			var s: float = ss[j][0]
			var across := minf(ys[i][1], ss[j][1])
			var p := _apron_point(s, y, lift)
			row.append(g.add(p, _apron_normal(s, y), Vector2(p.x, APRON_TOP - y), Color(1.0 if across < 1.5 else 0.0, minf(across, 1.0), 0.0)))
		grid.append(row)
	for i in grid.size() - 1:
		for j in grid[i].size() - 1:
			g.quad(grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j])


## Steps from a to b: the outer edge, the hem line, a crisp line just inside it,
## `inner` even steps, and the same mirrored at b. Each entry is
## [value, across]: across 0 at the edge, 1 on the hem line, 2 inside.
static func _hem_steps(a: float, b: float, hem: float, inner: int) -> Array:
	var dir := signf(b - a)
	var eps := 0.004 * dir
	var h := hem * dir
	var out := [[a, 0.0], [a + h, 1.0]]
	var from := a + h + eps
	var to := b - h - eps
	for k in inner + 1:
		out.append([lerpf(from, to, float(k) / inner), 2.0])
	out.append_array([[b - h, 1.0], [b, 0.0]])
	return out


## Flat leather strap along `path`, `width` wide, facing away from the body
## (`out` is the general outward direction); stitched down its middle.
static func _ribbon(g: _Geo, path: PackedVector3Array, width: float, out: Vector3) -> void:
	var length := 0.0
	var prev := PackedInt32Array()
	for i in path.size():
		var along := (path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]).normalized()
		var side := along.cross(out).normalized()
		var n := side.cross(along).normalized()
		if n.dot(out) < 0.0:
			n = -n
		if i > 0:
			length += path[i].distance_to(path[i - 1])
		var a := g.add(path[i] - side * width * 0.5, n, Vector2(length, length), Color(1, 0, 0))
		var b := g.add(path[i] + side * width * 0.5, n, Vector2(length, length), Color(1, 1, 0))
		if i > 0:
			g.quad(prev[0], prev[1], b, a)
		prev = PackedInt32Array([a, b])


## Waist ties: a strap round the back from one side of the apron to the other.
static func _waist_tie(g: _Geo) -> void:
	var rx := 0.395
	var rz := 0.345
	var edge := asin(clampf(_table(APRON_HALF_WIDTH, APRON_TIE_Y) * 0.92 / rx, 0.0, 1.0))
	var path := PackedVector3Array()
	var steps := 18
	for k in steps + 1:
		var a := lerpf(edge, TAU - edge, float(k) / steps)
		path.append(Vector3(rx * sin(a), APRON_TIE_Y + 0.012 * cos(a), rz * cos(a)))
	var length := 0.0
	var prev := PackedInt32Array()
	for i in path.size():
		var n := Vector3(path[i].x / (rx * rx), 0.0, path[i].z / (rz * rz)).normalized()
		if i > 0:
			length += path[i].distance_to(path[i - 1])
		var a := g.add(path[i] + Vector3(0, 0.015, 0), n, Vector2(length, length), Color(1, 0, 0))
		var b := g.add(path[i] - Vector3(0, 0.015, 0), n, Vector2(length, length), Color(1, 1, 0))
		if i > 0:
			g.quad(prev[0], prev[1], b, a)
		prev = PackedInt32Array([a, b])


## Small domed steel rivet on the apron surface.
static func _rivet(g: _Geo, s: float, y: float) -> void:
	var n := _apron_normal(s, y)
	var c := _apron_point(s, y, 0.004)
	var t := n.cross(Vector3.UP).normalized()
	var b := t.cross(n).normalized()
	var apex := g.add(c + n * 0.01, n, Vector2.ZERO, Color(0, 0, 1))
	var ring := PackedInt32Array()
	for k in 8:
		var a := TAU * k / 8.0
		var d := t * cos(a) + b * sin(a)
		ring.append(g.add(c + d * 0.014, (n + d).normalized(), Vector2.ZERO, Color(0, 0, 1)))
	for k in 8:
		g.tri(apex, ring[k], ring[(k + 1) % 8])


## Indexed mesh under construction, with skin weights copied from a body mesh.
class _Geo:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()

	func add(p: Vector3, n: Vector3, uv: Vector2, color: Color) -> int:
		verts.append(p)
		normals.append(n)
		uvs.append(uv)
		colors.append(color)
		return verts.size() - 1

	## Triangle facing along its vertices' normals (Godot fronts wind clockwise).
	func tri(a: int, b: int, c: int) -> void:
		var n := normals[a] + normals[b] + normals[c]
		if (verts[b] - verts[a]).cross(verts[c] - verts[a]).dot(n) > 0.0:
			indices.append_array([a, c, b])
		else:
			indices.append_array([a, b, c])

	func quad(a: int, b: int, c: int, d: int) -> void:
		tri(a, b, c)
		tri(a, c, d)

	## Inverse-distance blend of the bone weights of the 8 nearest body
	## vertices (rest space), reduced to the 4 strongest bones.
	func skin_from(body: Mesh) -> void:
		var arrays := body.surface_get_arrays(0)
		var bv: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bb: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var bw: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var per := bb.size() / bv.size()
		for p in verts:
			# Running top-8 by insertion (cheaper than sorting every body vertex).
			var best_d := PackedFloat32Array()
			var best_i := PackedInt32Array()
			best_d.resize(8)
			best_d.fill(INF)
			best_i.resize(8)
			for i in bv.size():
				var d := p.distance_squared_to(bv[i])
				if d >= best_d[7]:
					continue
				var k := 7
				while k > 0 and best_d[k - 1] > d:
					best_d[k] = best_d[k - 1]
					best_i[k] = best_i[k - 1]
					k -= 1
				best_d[k] = d
				best_i[k] = i
			var sum := {}
			for k in 8:
				var i: int = best_i[k]
				var w := 1.0 / pow(sqrt(best_d[k]) + 0.02, 2.0)
				for j in per:
					if bw[i * per + j] > 0.0:
						sum[bb[i * per + j]] = sum.get(bb[i * per + j], 0.0) + bw[i * per + j] * w
			var ranked := sum.keys()
			ranked.sort_custom(func(x: int, y: int) -> bool: return sum[x] > sum[y])
			var total := 0.0
			for k in mini(4, ranked.size()):
				total += sum[ranked[k]]
			for k in 4:
				bones.append(ranked[k] if k < ranked.size() else 0)
				weights.append(sum[ranked[k]] / total if k < ranked.size() else 0.0)

	func commit() -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices
		if not bones.is_empty():
			arrays[Mesh.ARRAY_BONES] = bones
			arrays[Mesh.ARRAY_WEIGHTS] = weights
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh
