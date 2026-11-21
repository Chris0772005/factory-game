class_name ChurchKit
## The churches across the yards of the bell foundry and the iron hall, for which the bells are cast:
## a west tower (or two) with a portal, a clock, louvred bell openings and a slated spire, and behind
## it a nave with pointed windows between stepped buttresses under a steep slate roof. Stone, plaster
## and slate are photo scans (TECH_SPEC Modul Y); the shapes follow the comparison pictures of U10
## (the monastery church of Kingdom Come: Deliverance, the gothic fronts of Assassin's Creed Unity).
## Scenery only: nothing here is solid, and nothing is built headless.
##
## A church runs along +z from `base`, the middle of its west front at ground level; the front looks
## along -z. Parts on a wall are placed in the wall's own frame: x along the wall, y up, z out of it.

const PITCH := 54.0
## Thickness and depth of the stone surround of a window.
const SURROUND := 0.26
const REVEAL := 0.24


## Flat-shaded triangles, each turned to face the way it should (Godot's front faces run clockwise).
class Soup:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()

	## `toward` only has to point to the outer side of the face; the true normal is worked out.
	func tri(a: Vector3, b: Vector3, c: Vector3, toward: Vector3) -> void:
		var n := (b - a).cross(c - a)
		if n.length_squared() < 1e-12:
			return
		n = n.normalized()
		if n.dot(toward) < 0.0:
			n = -n
		else:
			var t := b
			b = c
			c = t
		for p: Vector3 in [a, b, c]:
			verts.push_back(p)
			normals.push_back(n)

	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, toward: Vector3) -> void:
		tri(a, b, c, toward)
		tri(a, c, d, toward)

	func mesh() -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		var out := ArrayMesh.new()
		if not verts.is_empty():
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return out


## A church. opts: key ("church"), towers (1 or 2), tower_w, tower_h (to the cornice), spire_h,
## nave_w, nave_h (to the eaves), nave_len, bays, plaster (true: rendered walls with stone dressings;
## false: stone throughout), rose (a rose window over the portal of a front with two towers).
static func church(set: Node3D, base: Vector3, opts := {}) -> void:
	if not EnvMesh.visual():
		return
	var key: String = opts.get("key", "church")
	var towers: int = opts.get("towers", 1)
	var tw: float = opts.get("tower_w", 5.0)
	var th: float = opts.get("tower_h", 17.0)
	var sh: float = opts.get("spire_h", 13.0)
	var nw: float = opts.get("nave_w", 9.5)
	var nh: float = opts.get("nave_h", 7.5)
	var nl: float = opts.get("nave_len", 16.0)
	var bays: int = opts.get("bays", 4)
	var parts := {wall = [], stone = [], trim = [], slate = [], glass = [], hole = [], slat = [], oak = [], iron = [], gold = [], dial = []}
	# The nave: walls on a plinth, gables, the steep roof with its ridge and the cornice under the eaves.
	var z0 := (tw - 0.2) if towers == 1 else 0.9
	var z1 := tw + nl
	var run := z1 - z0
	var mid := (z0 + z1) * 0.5
	parts.wall.append(EnvMesh.piece(EnvMesh.box(Vector3(nw, nh, run)), Transform3D(Basis(), base + Vector3(0, nh * 0.5, mid))))
	parts.stone.append(EnvMesh.piece(EnvMesh.box(Vector3(nw + 0.3, 1.0, run + 0.3)), Transform3D(Basis(), base + Vector3(0, 0.5, mid))))
	parts.trim.append(EnvMesh.piece(EnvMesh.box(Vector3(nw + 0.42, 0.12, run + 0.42)), Transform3D(Basis(), base + Vector3(0, 1.04, mid))))
	var pitch := deg_to_rad(PITCH)
	var half := nw * 0.5 + 0.35
	var rise := half * tan(pitch)
	var shoulder := 0.35 * tan(pitch) - 0.1
	var gable := PackedVector2Array([Vector2(-nw * 0.5, 0), Vector2(nw * 0.5, 0), Vector2(nw * 0.5, shoulder), Vector2(0, rise - 0.1), Vector2(-nw * 0.5, shoulder)])
	for z: float in [z0, z1 - 0.4]:
		parts.wall.append(EnvMesh.piece(prism(gable, 0.4, true), Transform3D(Basis(), base + Vector3(0, nh, z))))
	for s: float in [-1.0, 1.0]:
		parts.slate.append(EnvMesh.piece(EnvMesh.box(Vector3(half / cos(pitch) + 0.15, 0.16, run + 0.5), 0.0),
			Transform3D(Basis(Vector3.BACK, -s * pitch), base + Vector3(s * half * 0.5, nh + rise * 0.5 + 0.05, mid))))
		parts.trim.append(EnvMesh.piece(EnvMesh.box(Vector3(0.34, 0.3, run + 0.2)), Transform3D(Basis(), base + Vector3(s * (nw * 0.5 + 0.12), nh - 0.15, mid))))
	parts.slate.append(EnvMesh.piece(EnvMesh.box(Vector3(0.32, 0.14, run + 0.5), 0.0), Transform3D(Basis(), base + Vector3(0, nh + rise + 0.1, mid))))
	# A slender ridge turret two thirds along the roof.
	var turret := base + Vector3(0, nh + rise, z0 + run * 0.68)
	parts.slat.append(EnvMesh.piece(EnvMesh.cylinder(0.4, 0.46, 1.5, 8), Transform3D(Basis(Vector3.UP, PI / 8.0), turret + Vector3(0, 0.6, 0))))
	parts.slate.append(EnvMesh.piece(pyramid(8, 0.6, 3.6, PI / 8.0), Transform3D(Basis(), turret + Vector3(0, 1.35, 0))))
	parts.gold.append(EnvMesh.piece(EnvMesh.sphere(0.13), Transform3D(Basis(), turret + Vector3(0, 5.0, 0))))
	# Bays along both flanks: a pointed window in each, a stepped buttress between and at the ends.
	var first := z0 + (1.2 if towers == 1 else tw - z0 + 0.7)
	var bay := (z1 - 0.9 - first) / bays
	var sill := 2.4
	var window_w := 1.2
	var window_h := nh - sill - 1.25 - window_w * 0.866
	for s: float in [-1.0, 1.0]:
		var out := Vector3(s, 0, 0)
		for i in bays + 1:
			buttress(parts, base + Vector3(s * nw * 0.5, 0, first + i * bay), out, nh - 0.5)
		for i in bays:
			window(parts, base + Vector3(s * nw * 0.5, sill, first + (i + 0.5) * bay), out, window_w, window_h)
	# The west front.
	if towers == 1:
		_tower(parts, base, tw, th, sh, true)
	else:
		var off := nw * 0.5 + 0.8 - tw * 0.5
		for s: float in [-1.0, 1.0]:
			_tower(parts, base + Vector3(s * off, 0, 0), tw, th, sh, false, Vector3(-s, 0, 0))
		# Between the towers: the great portal, the rose over it, a gallery of small pointed openings.
		var front := base + Vector3(0, 0, z0)
		var gap := 2.0 * off - tw
		portal(parts, front, Vector3.FORWARD, minf(2.6, gap - 1.5), 3.2)
		if opts.get("rose", false):
			rose(parts, front + Vector3(0, nh * 0.72, 0), Vector3.FORWARD, minf(1.7, gap * 0.5 - 0.45))
		parts.trim.append(EnvMesh.piece(EnvMesh.box(Vector3(gap, 0.24, 0.3)), Transform3D(Basis(), front + Vector3(0, nh - 0.12, -0.1))))
	# Materials. (The stone scan is a dark, weathered block: lifted to a pale sandstone, the more so as the
	# fronts toward the halls lie in shade all day. The slates are kept matt, or a whole roof glares in the sun.)
	var stone := EnvMesh.scan(key + "_stone", "large_sandstone_blocks", {drift = 0.12, foot = 0.3, foot_height = 1.4,
		tint = EnvMesh.toward("large_sandstone_blocks", Color("#c6b693"), 0.88)})
	var trim := EnvMesh.scan(key + "_trim", "large_sandstone_blocks", {drift = 0.06, shift = Vector3(0.37, 0.21, 0.53),
		tint = EnvMesh.toward("large_sandstone_blocks", Color("#d9cdae"), 0.92)})
	var wall := stone
	if opts.get("plaster", true):
		wall = EnvMesh.repainted(key + "_plaster", "beige_wall_001", Color("#dcd4c2"), {drift = 0.1, foot = 0.4, foot_height = 1.8})
	var slate := EnvMesh.scan(key + "_slate", "roof_slates_03", {drift = 0.1, tint = Vector3(0.5, 0.53, 0.6), roughness_scale = 2.5})
	var oak := EnvMesh.wood(key + "_oak", {base_color = Color("#4b3524"), grain_color = Color("#2a1c12"), weathering = 0.35, roughness_base = 0.65})
	EnvMesh.add(set, EnvMesh.merge(parts.wall), wall)
	EnvMesh.add(set, EnvMesh.merge(parts.stone), stone)
	EnvMesh.add(set, EnvMesh.merge(parts.trim), trim)
	EnvMesh.add(set, EnvMesh.merge(parts.slate), slate)
	EnvMesh.add(set, EnvMesh.merge(parts.oak), oak)
	# Old glass is nearly black from outside by day and mirrors the sky.
	EnvMesh.add(set, EnvMesh.merge(parts.glass), _plain(Color("#141922"), 0.1, 0.0, 0.9), Transform3D(), false)
	EnvMesh.add(set, EnvMesh.merge(parts.hole), _plain(Color("#0d0c0b"), 0.9), Transform3D(), false)
	EnvMesh.add(set, EnvMesh.merge(parts.slat), _plain(Color("#3a352e"), 0.8))
	EnvMesh.add(set, EnvMesh.merge(parts.iron), _plain(Color("#1c1b1a"), 0.55, 0.6), Transform3D(), false)
	EnvMesh.add(set, EnvMesh.merge(parts.gold), _plain(Color("#c9a13a"), 0.3, 1.0))
	EnvMesh.add(set, EnvMesh.merge(parts.dial), _plain(Color("#e6dfcc"), 0.6), Transform3D(), false)


## One tower from `origin`, the middle of its front at ground level: four stages parted by string
## courses (door or window, a tall window, the clock, the bell openings), angle buttresses, a cornice
## with four pinnacles and an eight-sided spire of slate with a gilded ball and cross. The flank that
## looks along `bare` (toward a twin) gets no buttress.
static func _tower(parts: Dictionary, origin: Vector3, tw: float, th: float, sh: float, door: bool, bare := Vector3.ZERO) -> void:
	var c := origin + Vector3(0, 0, tw * 0.5)
	parts.stone.append(EnvMesh.piece(EnvMesh.box(Vector3(tw, th, tw)), Transform3D(Basis(), c + Vector3(0, th * 0.5, 0))))
	parts.stone.append(EnvMesh.piece(EnvMesh.box(Vector3(tw + 0.3, 1.0, tw + 0.3)), Transform3D(Basis(), c + Vector3(0, 0.5, 0))))
	parts.trim.append(EnvMesh.piece(EnvMesh.box(Vector3(tw + 0.42, 0.12, tw + 0.42)), Transform3D(Basis(), c + Vector3(0, 1.04, 0))))
	var belfry := 4.4
	var y_bells := th - belfry - 0.5
	var y_clock := y_bells - 2.9
	var y_first := 5.6
	for y: float in [y_first, y_clock, y_bells]:
		parts.trim.append(EnvMesh.piece(EnvMesh.box(Vector3(tw + 0.26, 0.24, tw + 0.26)), Transform3D(Basis(), c + Vector3(0, y, 0))))
	parts.trim.append(EnvMesh.piece(EnvMesh.box(Vector3(tw + 0.3, 0.2, tw + 0.3)), Transform3D(Basis(), c + Vector3(0, th - 0.55, 0))))
	parts.trim.append(EnvMesh.piece(EnvMesh.box(Vector3(tw + 0.62, 0.36, tw + 0.62)), Transform3D(Basis(), c + Vector3(0, th - 0.18, 0))))
	for out: Vector3 in [Vector3.FORWARD, Vector3.LEFT, Vector3.RIGHT]:
		var face := wall_frame(out)
		var o := c + out * tw * 0.5
		for u: float in [-0.78, 0.78]:
			louvre(parts, o + face.x * u + Vector3.UP * (th - belfry), out, 0.86, belfry - 0.86 * 0.866 - 1.3)
		clock(parts, o + Vector3.UP * (y_clock + 1.45), out, 0.98)
		var corner := tw * 0.5 - 0.42
		if out == Vector3.FORWARD:
			for u: float in [-corner, corner]:
				buttress(parts, o + face.x * u, out, y_clock - 0.2, 0.9, 0.72)
			var tall := 1.1 if not door else 0.95
			window(parts, o + Vector3.UP * (y_first + 0.6), out, tall, y_clock - 0.7 - (y_first + 0.6) - tall * 0.866)
			if door:
				portal(parts, o, out, 2.1, 2.7)
			else:
				window(parts, o + Vector3.UP * 2.2, out, 1.1, 1.8)
		else:
			# The buttress at the front corner of a flank.
			if out != bare:
				buttress(parts, o + face.x * corner * signf(face.x.dot(Vector3.FORWARD)), out, y_clock - 0.2, 0.9, 0.72)
			window(parts, o + Vector3.UP * (y_first + 0.6), out, 0.95, y_clock - 0.7 - (y_first + 0.6) - 0.95 * 0.866, false)
	var top := c + Vector3(0, th, 0)
	parts.slate.append(EnvMesh.piece(pyramid(8, (tw * 0.5 - 0.06) / cos(PI / 8.0), sh, PI / 8.0), Transform3D(Basis(), top)))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var p := top + Vector3(sx * (tw * 0.5 - 0.32), 0, sz * (tw * 0.5 - 0.32))
			parts.trim.append(EnvMesh.piece(EnvMesh.box(Vector3(0.64, 1.1, 0.64)), Transform3D(Basis(), p + Vector3(0, 0.55, 0))))
			parts.trim.append(EnvMesh.piece(pyramid(4, 0.52, 1.9, PI / 4.0), Transform3D(Basis(), p + Vector3(0, 1.1, 0))))
	parts.gold.append(EnvMesh.piece(EnvMesh.sphere(0.26), Transform3D(Basis(), top + Vector3(0, sh + 0.12, 0))))
	parts.gold.append(EnvMesh.piece(EnvMesh.box(Vector3(0.08, 1.5, 0.08)), Transform3D(Basis(), top + Vector3(0, sh + 1.0, 0))))
	parts.gold.append(EnvMesh.piece(EnvMesh.box(Vector3(0.8, 0.08, 0.08)), Transform3D(Basis(), top + Vector3(0, sh + 1.25, 0))))


## The frame of a wall that looks along `out` (level): x along the wall, y up, z out.
static func wall_frame(out: Vector3) -> Basis:
	return Basis(Vector3.UP.cross(out), Vector3.UP, out)


## A pointed window: `origin` is the middle of its sill on the wall, `h` the height up to where the
## arch springs. A stone surround stands proud of the wall, the glass lies deep in it; with `tracery`
## a mullion parts two lights and branches into the arch.
static func window(parts: Dictionary, origin: Vector3, out: Vector3, w: float, h: float, tracery := true) -> void:
	var face := wall_frame(out)
	var at := Transform3D(face, origin)
	var inner := lancet(w, h)
	parts.trim.append(EnvMesh.piece(ring(inner, lancet(w, h, SURROUND), REVEAL), at))
	parts.glass.append(EnvMesh.piece(prism(inner, 0.04), at))
	parts.trim.append(EnvMesh.piece(EnvMesh.box(Vector3(w + 0.8, 0.16, 0.42)), at * Transform3D(Basis(), Vector3(0, -0.08, 0.18))))
	if not tracery:
		return
	parts.trim.append(EnvMesh.piece(EnvMesh.box(Vector3(0.09, h, 0.12), 0.0), at * Transform3D(Basis(), Vector3(0, h * 0.5, 0.08))))
	# Each branch keeps the curve of the arch and runs from the mullion's head into the arch.
	var reach := acos(0.75)
	for s: float in [-1.0, 1.0]:
		var centre := Vector2(s * w, h)
		var last := Vector2(0, h)
		for k in range(1, 6):
			var a := reach * k / 5.0
			var p := centre + Vector2(-s * cos(a), sin(a)) * w
			var d := p - last
			parts.trim.append(EnvMesh.piece(EnvMesh.box(Vector3(d.length() + 0.03, 0.08, 0.12), 0.0),
				at * Transform3D(Basis(Vector3.BACK, d.angle()), Vector3((p.x + last.x) * 0.5, (p.y + last.y) * 0.5, 0.08))))
			last = p


## A bell opening: a pointed surround, darkness behind and sloping boards across it.
static func louvre(parts: Dictionary, origin: Vector3, out: Vector3, w: float, h: float) -> void:
	var at := Transform3D(wall_frame(out), origin)
	var inner := lancet(w, h)
	parts.trim.append(EnvMesh.piece(ring(inner, lancet(w, h, 0.2), 0.2), at))
	parts.hole.append(EnvMesh.piece(prism(inner, 0.03), at))
	parts.trim.append(EnvMesh.piece(EnvMesh.box(Vector3(w + 0.6, 0.14, 0.36)), at * Transform3D(Basis(), Vector3(0, -0.07, 0.15))))
	var count := int((h + w * 0.4) / 0.27)
	for i in count:
		var y := 0.16 + i * 0.27
		# (Above the springing the opening narrows: the boards follow.)
		var width := w - 0.03
		if y > h:
			width = 2.0 * (sqrt(maxf(w * w - (y - h) * (y - h), 0.0)) - w * 0.5) - 0.05
		if width > 0.12:
			parts.slat.append(EnvMesh.piece(EnvMesh.box(Vector3(width, 0.03, 0.22), 0.0), at * Transform3D(Basis(Vector3.RIGHT, 0.6), Vector3(0, y, 0.1))))


## A church door: a deep pointed surround in two orders, two leaves of oak with iron bands, and two
## steps up to it, `lift` high together. `origin` is the middle of the door on the wall at ground level.
static func portal(parts: Dictionary, origin: Vector3, out: Vector3, w: float, h: float, lift := 0.3) -> void:
	var at := Transform3D(wall_frame(out), origin + Vector3.UP * lift)
	var inner := lancet(w, h)
	parts.trim.append(EnvMesh.piece(ring(lancet(w, h, 0.2), lancet(w, h, 0.62), 0.55), at))
	parts.trim.append(EnvMesh.piece(ring(inner, lancet(w, h, 0.2), 0.3), at))
	parts.oak.append(EnvMesh.piece(prism(inner, 0.07), at))
	parts.iron.append(EnvMesh.piece(EnvMesh.box(Vector3(0.035, h + w * 0.8, 0.02), 0.0), at * Transform3D(Basis(), Vector3(0, (h + w * 0.8) * 0.5, 0.075))))
	for s: float in [-1.0, 1.0]:
		for y: float in [0.45, h * 0.5, h - 0.35]:
			parts.iron.append(EnvMesh.piece(EnvMesh.box(Vector3(w * 0.5 - 0.22, 0.07, 0.02), 0.0), at * Transform3D(Basis(), Vector3(s * (w * 0.25 + 0.06), y, 0.08))))
		parts.iron.append(EnvMesh.piece(EnvMesh.cylinder(0.07, 0.07, 0.04, 10), at * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(s * 0.16, h * 0.42, 0.09))))
	parts.stone.append(EnvMesh.piece(EnvMesh.box(Vector3(w + 2.0, lift * 0.5, 1.5)), at * Transform3D(Basis(), Vector3(0, -lift * 0.75, 0.75))))
	parts.stone.append(EnvMesh.piece(EnvMesh.box(Vector3(w + 1.3, lift * 0.5, 0.95)), at * Transform3D(Basis(), Vector3(0, -lift * 0.25, 0.475))))


## A tower clock: a pale dial in a dark ring, twelve marks and two gilded hands (at ten past ten).
static func clock(parts: Dictionary, centre: Vector3, out: Vector3, r: float) -> void:
	var at := Transform3D(wall_frame(out), centre)
	var flat := Basis(Vector3.RIGHT, PI * 0.5)
	parts.iron.append(EnvMesh.piece(EnvMesh.cylinder(r + 0.1, r + 0.1, 0.08, 28), at * Transform3D(flat, Vector3(0, 0, 0.04))))
	parts.dial.append(EnvMesh.piece(EnvMesh.cylinder(r, r, 0.03, 28), at * Transform3D(flat, Vector3(0, 0, 0.085))))
	for k in 12:
		var turn := Basis(Vector3.BACK, k * TAU / 12.0)
		var long := 0.2 if k % 3 == 0 else 0.12
		parts.iron.append(EnvMesh.piece(EnvMesh.box(Vector3(0.05, long, 0.012), 0.0), at * Transform3D(turn, turn * Vector3(0, r - 0.06 - long * 0.5, 0.105))))
	# (Angles run anticlockwise from twelve as seen from outside.)
	for hand: Array in [[deg_to_rad(55.0), r * 0.5, 0.075], [deg_to_rad(-60.0), r * 0.8, 0.05]]:
		var turn := Basis(Vector3.BACK, hand[0])
		parts.gold.append(EnvMesh.piece(EnvMesh.box(Vector3(hand[2], hand[1], 0.014), 0.0), at * Transform3D(turn, turn * Vector3(0, hand[1] * 0.42, 0.118))))
	parts.gold.append(EnvMesh.piece(EnvMesh.cylinder(0.06, 0.06, 0.03, 10), at * Transform3D(flat, Vector3(0, 0, 0.125))))


## A rose window: a stone ring, dark glass, spokes and an inner ring.
static func rose(parts: Dictionary, centre: Vector3, out: Vector3, r: float) -> void:
	var at := Transform3D(wall_frame(out), centre)
	parts.trim.append(EnvMesh.piece(ring(circle(r), circle(r + 0.36), 0.3), at))
	parts.glass.append(EnvMesh.piece(prism(circle(r), 0.04), at))
	parts.trim.append(EnvMesh.piece(ring(circle(r * 0.45 - 0.04), circle(r * 0.45 + 0.04), 0.12), at))
	for k in 12:
		var turn := Basis(Vector3.BACK, k * TAU / 12.0)
		parts.trim.append(EnvMesh.piece(EnvMesh.box(Vector3(0.07, r * 0.57, 0.12), 0.0), at * Transform3D(turn, turn * Vector3(0, r * 0.73, 0.06))))
	parts.trim.append(EnvMesh.piece(EnvMesh.cylinder(0.2, 0.2, 0.14, 12), at * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, 0.07))))


## A buttress against a wall at `origin` (ground level): two stages, each ending in a slope.
static func buttress(parts: Dictionary, origin: Vector3, out: Vector3, h: float, reach := 0.95, width := 0.7) -> void:
	var side := PackedVector2Array([Vector2(0, 0), Vector2(reach, 0), Vector2(reach, h * 0.42), Vector2(reach * 0.64, h * 0.42 + 0.5),
		Vector2(reach * 0.64, h * 0.84), Vector2(0, h)])
	var b := Basis(out, Vector3.UP, out.cross(Vector3.UP))
	parts.stone.append(EnvMesh.piece(prism(side, width, true), Transform3D(b, origin - b.z * width * 0.5)))


## The outline of a pointed arch over a rectangle, anticlockwise from the lower left: `w` wide, `h`
## up to the springing, the arch struck from the opposite springing points (an equilateral arch).
## `grow` widens it all round by that much (the arcs stay concentric), but not at the foot.
static func lancet(w: float, h: float, grow := 0.0, steps := 7) -> PackedVector2Array:
	var half := w * 0.5
	var r := w + grow
	var top := acos(half / r)
	var out := PackedVector2Array([Vector2(-half - grow, 0), Vector2(half + grow, 0)])
	for k in steps + 1:
		var a := top * k / steps
		out.append(Vector2(-half + r * cos(a), h + r * sin(a)))
	for k in range(1, steps + 1):
		var a := PI - top + top * k / steps
		out.append(Vector2(half + r * cos(a), h + r * sin(a)))
	return out


static func circle(r: float, steps := 28) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in steps:
		out.append(Vector2(cos(k * TAU / steps), sin(k * TAU / steps)) * r)
	return out


## The shape `points` (in x and y) pushed out along z from 0 to `depth`: its front and sides, with
## `back` also the face at z = 0.
static func prism(points: PackedVector2Array, depth: float, back := false) -> ArrayMesh:
	var soup := Soup.new()
	var tris := Geometry2D.triangulate_polygon(points)
	for i in range(0, tris.size(), 3):
		var a := points[tris[i]]
		var b := points[tris[i + 1]]
		var c := points[tris[i + 2]]
		soup.tri(Vector3(a.x, a.y, depth), Vector3(b.x, b.y, depth), Vector3(c.x, c.y, depth), Vector3.BACK)
		if back:
			soup.tri(Vector3(a.x, a.y, 0), Vector3(b.x, b.y, 0), Vector3(c.x, c.y, 0), Vector3.FORWARD)
	var turn := _winding(points)
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		# (The side of an outline that runs anticlockwise looks to the right of its direction.)
		var away := Vector2(b.y - a.y, a.x - b.x) * turn
		soup.quad(Vector3(a.x, a.y, 0), Vector3(b.x, b.y, 0), Vector3(b.x, b.y, depth), Vector3(a.x, a.y, depth), Vector3(away.x, away.y, 0))
	return soup.mesh()


## A frame between two outlines with the same number of points, `depth` proud of the wall: its face,
## the reveal inside and the sides outside. With `open` the outlines are lines that do not close (the
## band round an arch, from one springing to the other): no stretch from the last point back to the
## first, and a face across either end instead.
static func ring(inner: PackedVector2Array, outer: PackedVector2Array, depth: float, open := false) -> ArrayMesh:
	var soup := Soup.new()
	var turn := _winding(inner)
	if open:
		for end: int in [0, inner.size() - 1]:
			var a := inner[end]
			var d := outer[end]
			var off := inner[end] - inner[1 if end == 0 else end - 1]
			soup.quad(Vector3(a.x, a.y, 0), Vector3(d.x, d.y, 0), Vector3(d.x, d.y, depth), Vector3(a.x, a.y, depth), Vector3(off.x, off.y, 0))
	for i in (inner.size() - 1 if open else inner.size()):
		var j := (i + 1) % inner.size()
		var a := inner[i]
		var b := inner[j]
		var c := outer[j]
		var d := outer[i]
		soup.quad(Vector3(a.x, a.y, depth), Vector3(b.x, b.y, depth), Vector3(c.x, c.y, depth), Vector3(d.x, d.y, depth), Vector3.BACK)
		var into := Vector2(b.y - a.y, a.x - b.x) * -turn
		soup.quad(Vector3(a.x, a.y, 0), Vector3(b.x, b.y, 0), Vector3(b.x, b.y, depth), Vector3(a.x, a.y, depth), Vector3(into.x, into.y, 0))
		var away := Vector2(c.y - d.y, d.x - c.x) * turn
		soup.quad(Vector3(d.x, d.y, 0), Vector3(c.x, c.y, 0), Vector3(c.x, c.y, depth), Vector3(d.x, d.y, depth), Vector3(away.x, away.y, 0))
	return soup.mesh()


## A pointed roof with flat sides: `sides` corners at `radius` round the foot, the first at the angle
## `turn`, the point `height` above the middle of the foot. Closed underneath (where the foot
## overhangs what it stands on, one looks at it from below).
static func pyramid(sides: int, radius: float, height: float, turn := 0.0) -> ArrayMesh:
	var soup := Soup.new()
	var tip := Vector3(0, height, 0)
	for k in sides:
		var a := turn + k * TAU / sides
		var b := turn + (k + 1) * TAU / sides
		var p := Vector3(cos(a), 0, sin(a)) * radius
		var q := Vector3(cos(b), 0, sin(b)) * radius
		soup.tri(p, q, tip, p + q)
		soup.tri(p, q, Vector3.ZERO, Vector3.DOWN)
	return soup.mesh()


## 1 for an outline that runs anticlockwise, -1 for one that runs clockwise.
static func _winding(points: PackedVector2Array) -> float:
	var area := 0.0
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		area += a.x * b.y - b.x * a.y
	return 1.0 if area >= 0.0 else -1.0


static func _plain(colour: Color, roughness: float, metallic := 0.0, specular := 0.5) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = roughness
	mat.metallic = metallic
	mat.metallic_specular = specular
	return mat
