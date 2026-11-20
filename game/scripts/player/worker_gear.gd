class_name WorkerGear
extends RefCounted
## The hard hat of the players' workers, built procedurally round a shell (half an ellipsoid over
## the rim, faces +Z). PlayerModel brings that shell to each figure's head: its size and place.
## The meshes are cached and shared by every worker; only materials differ.

## The shell's own measures (the units of the stylised figure the hat was first made for; only
## their proportions matter now). The rim's middle is SHELL_CENTER less HEAD_BONE_Y in height.
const HEAD_BONE_Y := 1.241
## Shell ellipsoid: centre and radii (x, y, z).
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

static var _hat_parts: Array[ArrayMesh] = []


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
