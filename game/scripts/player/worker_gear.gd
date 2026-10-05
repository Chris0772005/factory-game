class_name WorkerGear
extends RefCounted
## Procedural safety gear for the rigged worker: a hard hat built around the
## KayKit head (bone space of the shared rig, unscaled units, faces +Z).
## The meshes are cached and shared by every worker; only materials differ.

## Head bone height in the rig's rest pose; the hat is modelled in rest space and shifted by it.
const HEAD_BONE_Y := 1.241
## Shell ellipsoid: centre and radii (x, y, z), sized to clear the cranium by 5–7 cm.
const SHELL_CENTER := Vector3(0.0, 1.78, -0.02)
const SHELL_RADII := Vector3(0.5, 0.5, 0.53)
## Brim widths: sides, front peak, back.
const BRIM_SIDE := 0.028
const BRIM_FRONT := 0.19
const BRIM_BACK := 0.06
const BRIM_THICKNESS := 0.03
## Height band (polar angle from the top, radians) of the reflective stripe.
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
	_add_band(stripe, STRIPE_FROM, STRIPE_TO, 0.012)
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


## A raised ridge over the crown from the front to the back, typical of a hard hat.
static func _add_crest(st: SurfaceTool) -> void:
	var steps := 28
	var half_width := 0.075
	var height := 0.035
	# Profile across the ridge: (side offset, lift) from left foot to right foot.
	var profile := [Vector2(-1.0, -0.4), Vector2(-0.75, 0.55), Vector2(-0.35, 0.95), Vector2(0.0, 1.0),
		Vector2(0.35, 0.95), Vector2(0.75, 0.55), Vector2(1.0, -0.4)]
	var rows: Array[PackedVector3Array] = []
	var normals: Array[PackedVector3Array] = []
	for s in steps + 1:
		# Arc in the YZ plane from the front edge (theta 1.25) over the crown to the back edge.
		var a := lerpf(-1.25, 1.25, float(s) / steps)
		var theta := absf(a)
		var phi := 0.0 if a < 0.0 else PI
		var center := shell_point(theta, phi)
		var n := shell_normal(theta, phi)
		var side := Vector3.RIGHT
		var row := PackedVector3Array()
		var nrow := PackedVector3Array()
		# Taper the ridge into the brim at both ends.
		var taper := clampf((1.25 - theta) / 0.35, 0.0, 1.0)
		for k in profile.size():
			var pr: Vector2 = profile[k]
			row.append(center + side * pr.x * half_width + n * pr.y * height * taper)
			var slope := -pr.x * 1.2 if absf(pr.x) > 0.2 else 0.0
			nrow.append((n + side * slope).normalized())
		rows.append(row)
		normals.append(nrow)
	for s in steps:
		var shade := 1.0 - absf(lerpf(-1.25, 1.25, (s + 0.5) / steps)) * 0.08
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
	return p + dir * width + Vector3(0, -0.04 * pow(front, 2.0) + 0.018 * side - 0.006, 0)


## Band hugging the shell between two polar angles (used for the reflective stripe).
static func _add_band(st: SurfaceTool, from: float, to: float, grow: float) -> void:
	var steps := 3
	for i in steps:
		var t0 := lerpf(from, to, float(i) / steps)
		var t1 := lerpf(from, to, float(i + 1) / steps)
		for j in SEG:
			_quad_on_shell(st, t0, t1, TAU * j / SEG, TAU * (j + 1) / SEG, grow)


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
