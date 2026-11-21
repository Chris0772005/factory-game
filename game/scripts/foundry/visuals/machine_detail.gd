class_name MachineDetail
## The small parts that make a machine look built rather than modelled (TECH_SPEC Modul Y, Stufe U12;
## comparison pictures: the workshop of Tank Mechanic Simulator, the steelwork of Ship Graveyard
## Simulator 2): hex bolts and rivets singly, in rows and in circles, weld beads, pipe flanges, cables
## with clips, grab handles, hinges, hand wheels, lifting eyes, and as whole things a type plate, a
## switch box, a pressure gauge and an electric motor.
##
## The parts of one machine are collected in a `Parts` and added in one go with `commit`, merged per
## material: a few hundred bolts cost a handful of draw calls. All positions are in the space of the
## node the parts are committed to; a part that moves (a lid, a trolley, a ladle) gets a Parts and a
## commit of its own under the node that moves. Directions (`out`, `axis`) need not be unit length.
## Nothing here is solid. Callers build it only where StationKit.visual() holds.

## What `commit` adds, one merged mesh per list.
class Parts:
	## Bright fasteners and fittings (zinc-plated bolts, clips, flanges, hand wheels).
	var steel := []
	## Blackened fasteners and fittings for dark iron.
	var dark := []
	## Weld beads.
	var weld := []
	## Rubber cable.
	var rubber := []
	## Brass fittings.
	var brass := []

	func into(blackened: bool) -> Array:
		return dark if blackened else steel


static var _plain := {}


# --- Fasteners ---------------------------------------------------------------------------------

## A hex bolt head on a washer at `at`, standing along `out`. `size` is the width across the flats
## (an M10 bolt: 0.016). Every head is turned a little differently.
static func bolt(parts: Parts, at: Vector3, out: Vector3, size := 0.016, blackened := false) -> void:
	var up := out.normalized()
	var turn := Basis(up, fposmod(at.x * 73.1 + at.y * 37.7 + at.z * 51.3, 1.0) * TAU / 6.0) * StationKit.basis_y(up)
	var list := parts.into(blackened)
	var seed := fposmod(at.x * 3.1 + at.y * 7.7 + at.z * 5.3, 1.0)
	list.append(EnvMesh.piece(EnvMesh.cylinder(size * 0.86, size * 0.9, size * 0.12, 12), Transform3D(turn, at + up * size * 0.06), seed))
	list.append(EnvMesh.piece(EnvMesh.cylinder(size * 0.53, size * 0.577, size * 0.6, 6), Transform3D(turn, at + up * size * 0.42), seed))


## A rivet's round head at `at`, standing along `out`; `size` is its diameter.
static func rivet(parts: Parts, at: Vector3, out: Vector3, size := 0.014, blackened := false) -> void:
	var b := StationKit.basis_y(out.normalized())
	var seed := fposmod(at.x * 3.1 + at.y * 7.7 + at.z * 5.3, 1.0)
	parts.into(blackened).append(EnvMesh.piece(EnvMesh.sphere(size * 0.5, 6, 3), Transform3D(b * Basis.from_scale(Vector3(1.0, 0.62, 1.0)), at), seed))


## `count` brass tacks evenly from `from` to `to` (both ends included), heads along `out`: what holds
## leather or canvas to a board.
static func tack_row(parts: Parts, from: Vector3, to: Vector3, count: int, out: Vector3, size := 0.009) -> void:
	var b := StationKit.basis_y(out.normalized()) * Basis.from_scale(Vector3(1.0, 0.5, 1.0))
	for i in count:
		var at := from.lerp(to, float(i) / maxf(count - 1, 1.0))
		parts.brass.append(EnvMesh.piece(EnvMesh.sphere(size * 0.5, 6, 3), Transform3D(b, at), fposmod(at.x * 3.1 + at.z * 5.3, 1.0)))


## `count` bolts evenly from `from` to `to` (both ends included), heads along `out`.
static func bolt_row(parts: Parts, from: Vector3, to: Vector3, count: int, out: Vector3, size := 0.016, blackened := false) -> void:
	for i in count:
		bolt(parts, from.lerp(to, float(i) / maxf(count - 1, 1.0)), out, size, blackened)


## `count` rivets evenly from `from` to `to` (both ends included), heads along `out`.
static func rivet_row(parts: Parts, from: Vector3, to: Vector3, count: int, out: Vector3, size := 0.014, blackened := false) -> void:
	for i in count:
		rivet(parts, from.lerp(to, float(i) / maxf(count - 1, 1.0)), out, size, blackened)


## `count` bolts on a circle of `radius` round `center` in the plane across `axis`, heads along
## `axis`: the face of a flange or a cover. `phase` (radians) turns the first one.
static func bolt_circle(parts: Parts, center: Vector3, axis: Vector3, radius: float, count: int, size := 0.016, blackened := false, phase := 0.0) -> void:
	var b := StationKit.basis_y(axis.normalized())
	for i in count:
		var a := phase + TAU * i / count
		bolt(parts, center + (b.x * cos(a) + b.z * sin(a)) * radius, b.y, size, blackened)


## The same with rivets.
static func rivet_circle(parts: Parts, center: Vector3, axis: Vector3, radius: float, count: int, size := 0.014, blackened := false, phase := 0.0) -> void:
	var b := StationKit.basis_y(axis.normalized())
	for i in count:
		var a := phase + TAU * i / count
		rivet(parts, center + (b.x * cos(a) + b.z * sin(a)) * radius, b.y, size, blackened)


## `count` bolts round a drum: on its surface at `radius` from the `axis` through `center`, heads
## pointing away from the axis (a band, a hoop, a seam round a shell). `arc` limits them to part of
## the round, starting at `phase`.
static func bolts_around(parts: Parts, center: Vector3, axis: Vector3, radius: float, count: int, size := 0.016, blackened := false, phase := 0.0, arc := TAU) -> void:
	var b := StationKit.basis_y(axis.normalized())
	for i in count:
		var a := phase + arc * i / (count if is_equal_approx(arc, TAU) else maxi(count - 1, 1))
		var dir := b.x * cos(a) + b.z * sin(a)
		bolt(parts, center + dir * radius, dir, size, blackened)


## The same with rivets.
static func rivets_around(parts: Parts, center: Vector3, axis: Vector3, radius: float, count: int, size := 0.014, blackened := false, phase := 0.0, arc := TAU) -> void:
	var b := StationKit.basis_y(axis.normalized())
	for i in count:
		var a := phase + arc * i / (count if is_equal_approx(arc, TAU) else maxi(count - 1, 1))
		var dir := b.x * cos(a) + b.z * sin(a)
		rivet(parts, center + dir * radius, dir, size, blackened)


# --- Welds, flanges, pipes ---------------------------------------------------------------------

## A weld bead along `path` (points on the surface, in order), `width` across: a rippled string of
## metal, half sunk into what it joins.
static func weld(parts: Parts, path: PackedVector3Array, width := 0.012) -> void:
	if path.size() < 2:
		return
	var fine := PackedVector3Array()
	var radii := PackedFloat32Array()
	var step := width * 0.9
	var n := 0
	for i in path.size() - 1:
		var count := maxi(int(ceil(path[i].distance_to(path[i + 1]) / step)), 1)
		for k in count:
			fine.append(path[i].lerp(path[i + 1], float(k) / count))
			radii.append(width * 0.5 * (0.78 + 0.3 * absf(sin(n * 1.9)) + 0.12 * sin(n * 0.37)))
			n += 1
	fine.append(path[path.size() - 1])
	radii.append(width * 0.4)
	parts.weld.append(EnvMesh.piece(StationKit.tube(fine, width * 0.5, 5, true, radii), Transform3D(), fposmod(path[0].x * 9.1 + path[0].y * 4.3, 1.0)))


## A weld bead all the way round a pipe or drum: a circle of `radius` round `center` across `axis`.
static func weld_ring(parts: Parts, center: Vector3, axis: Vector3, radius: float, width := 0.012) -> void:
	var b := StationKit.basis_y(axis.normalized())
	weld(parts, StationKit.arc_points(center, b.x, b.z, radius, 0.0, TAU, maxi(int(TAU * radius / (width * 3.0)), 12)), width)


## A pipe flange: a disc of `radius` and `thick` round `center` across `axis`, bolted through with
## `bolts` bolts (heads on the side `axis` points to, nuts on the other).
static func flange(parts: Parts, center: Vector3, axis: Vector3, radius: float, thick := 0.014, bolts := 8, size := 0.016, blackened := false) -> void:
	var up := axis.normalized()
	parts.into(blackened).append(EnvMesh.piece(EnvMesh.cylinder(radius, radius, thick, 20), Transform3D(StationKit.basis_y(up), center), fposmod(center.x * 2.3 + center.z * 6.1, 1.0)))
	bolt_circle(parts, center + up * thick * 0.5, up, radius - size * 1.1, bolts, size, blackened)
	bolt_circle(parts, center - up * thick * 0.5, -up, radius - size * 1.1, bolts, size, blackened)


## A steel pipe or conduit through `points` (straight runs, mitred corners).
static func conduit(parts: Parts, points: PackedVector3Array, radius := 0.012, blackened := false) -> void:
	if points.size() >= 2:
		parts.into(blackened).append(EnvMesh.piece(StationKit.tube(points, radius, 8), Transform3D(), fposmod(points[0].x * 5.7 + points[0].y * 3.3, 1.0)))


# --- Cables --------------------------------------------------------------------------------------

## A rubber cable through `points`, rounded at the corners. With `out` (the way the surface it runs
## along looks) it gets a steel clip about every `clip_every` metres.
static func cable(parts: Parts, points: PackedVector3Array, radius := 0.01, out := Vector3.ZERO, clip_every := 0.45) -> void:
	if points.size() < 2:
		return
	var smooth := _rounded(points, 5)
	parts.rubber.append(EnvMesh.piece(StationKit.tube(smooth, radius, 6), Transform3D(), 0.5))
	if out == Vector3.ZERO:
		return
	var walked := clip_every * 0.5
	for i in smooth.size() - 1:
		var seg := smooth[i].distance_to(smooth[i + 1])
		walked += seg
		if walked >= clip_every and seg > 1e-4:
			walked = 0.0
			clip(parts, (smooth[i] + smooth[i + 1]) * 0.5, smooth[i + 1] - smooth[i], out, radius)


## Points of a cable that hangs free from `a` to `b` and sags `drop` in the middle: for `cable`.
static func sag(a: Vector3, b: Vector3, drop: float, steps := 10) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in steps + 1:
		var t := float(i) / steps
		out.append(a.lerp(b, t) + Vector3.DOWN * drop * 4.0 * t * (1.0 - t))
	return out


## A saddle clip holding a cable or pipe of `radius` that runs `along` on a surface looking `out`.
static func clip(parts: Parts, at: Vector3, along: Vector3, out: Vector3, radius := 0.01) -> void:
	var y := out.normalized()
	var z := (along - y * along.dot(y)).normalized()
	if z.length_squared() < 0.5:
		return
	var b := Basis(y.cross(z), y, z)
	parts.steel.append(EnvMesh.piece(EnvMesh.box(Vector3(radius * 5.2, radius * 0.5, radius * 1.6), 0.001), Transform3D(b, at - y * radius * 0.85), 0.3))
	parts.steel.append(EnvMesh.piece(EnvMesh.box(Vector3(radius * 2.5, radius * 2.3, radius * 1.6), radius * 0.6), Transform3D(b, at + y * radius * 0.1), 0.3))
	for s: float in [-1.0, 1.0]:
		rivet(parts, at + b.x * s * radius * 2.0 - y * radius * 0.6, y, radius * 0.9)


# --- Fittings ------------------------------------------------------------------------------------

## A grab handle: a bent rod from `a` to `b`, standing `depth` off the surface along `out`.
static func handle(parts: Parts, a: Vector3, b: Vector3, out: Vector3, depth := 0.045, radius := 0.007, blackened := false) -> void:
	var up := out.normalized() * depth
	var along := (b - a).normalized() * minf(depth * 0.6, a.distance_to(b) * 0.25)
	var path := _rounded(PackedVector3Array([a, a + up, b + up, b]), 4, along.length())
	var list := parts.into(blackened)
	list.append(EnvMesh.piece(StationKit.tube(path, radius, 6), Transform3D(), 0.4))
	for foot: Vector3 in [a, b]:
		list.append(EnvMesh.piece(EnvMesh.cylinder(radius * 2.2, radius * 2.4, radius * 0.8, 10), Transform3D(StationKit.basis_y(out.normalized()), foot + out.normalized() * radius * 0.4), 0.4))


## A hinge at `at`: its pin along `axis`, on a surface looking `out`; two leaves with two rivets each.
static func hinge(parts: Parts, at: Vector3, axis: Vector3, out: Vector3, length := 0.09, radius := 0.01, blackened := false) -> void:
	var y := axis.normalized()
	var z := out.normalized()
	var b := Basis(y.cross(z), y, z)
	var list := parts.into(blackened)
	list.append(EnvMesh.piece(EnvMesh.cylinder(radius, radius, length, 10), Transform3D(b, at + z * radius), 0.6))
	for s: float in [-1.0, 1.0]:
		list.append(EnvMesh.piece(EnvMesh.box(Vector3(radius * 4.0, length * 0.9, radius * 0.45), 0.001), Transform3D(b, at + b.x * s * radius * 2.4 + z * radius * 0.22), 0.6))
		for k: float in [-0.3, 0.3]:
			rivet(parts, at + b.x * s * radius * 3.0 + y * length * k + z * radius * 0.45, z, radius * 1.1, blackened)


## A hand wheel: a rim of `radius` round `center` across `axis`, four spokes and a hub.
static func handwheel(parts: Parts, center: Vector3, axis: Vector3, radius := 0.11, blackened := false) -> void:
	var b := StationKit.basis_y(axis.normalized())
	var list := parts.into(blackened)
	var rod := maxf(radius * 0.085, 0.006)
	list.append(EnvMesh.piece(StationKit.tube(StationKit.arc_points(center, b.x, b.z, radius, 0.0, TAU, 20), rod, 6, false), Transform3D(), 0.7))
	for k in 4:
		var a := PI * 0.25 + k * PI * 0.5
		var dir := b.x * cos(a) + b.z * sin(a)
		list.append(EnvMesh.piece(EnvMesh.cylinder(rod * 0.8, rod * 0.8, radius, 6), Transform3D(StationKit.basis_y(dir), center + dir * radius * 0.5), 0.7))
	list.append(EnvMesh.piece(EnvMesh.cylinder(radius * 0.2, radius * 0.24, rod * 3.0, 10), Transform3D(b, center), 0.7))


## A lifting eye screwed in at `at`, standing along `out`: a ring of `radius` on a stud.
static func lifting_eye(parts: Parts, at: Vector3, out: Vector3, radius := 0.03, blackened := false) -> void:
	var up := out.normalized()
	var b := StationKit.basis_y(up)
	var list := parts.into(blackened)
	var rod := radius * 0.28
	list.append(EnvMesh.piece(EnvMesh.cylinder(rod * 1.6, rod * 1.9, radius * 0.5, 8), Transform3D(b, at + up * radius * 0.25), 0.2))
	list.append(EnvMesh.piece(StationKit.tube(StationKit.arc_points(at + up * (radius * 0.5 + radius), b.x, up, radius, 0.0, TAU, 14), rod, 6, false), Transform3D(), 0.2))


# --- Whole things --------------------------------------------------------------------------------

## A maker's plate riveted on: `xform` is its middle on the surface (+Z out of the surface, +Y up).
## `title` in capitals on top, `lines` smaller below. Brass, or aluminium with `brass` false.
static func type_plate(parent: Node3D, xform: Transform3D, title: String, lines: Array = [], size := Vector2(0.17, 0.1), brass := true) -> Node3D:
	var holder := Node3D.new()
	holder.name = "TypePlate"
	holder.transform = xform
	parent.add_child(holder)
	var parts := Parts.new()
	(parts.brass if brass else parts.steel).append(EnvMesh.piece(EnvMesh.box(Vector3(size.x, size.y, 0.003), 0.001), Transform3D(Basis(), Vector3(0, 0, 0.0015)), 0.35))
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			rivet(parts, Vector3(sx * (size.x * 0.5 - 0.009), sy * (size.y * 0.5 - 0.009), 0.003), Vector3.BACK, 0.007)
	commit(holder, parts)
	var ink := Color("#14110e")
	var pixel := size.x / 760.0
	var rows := lines.size()
	var top := size.y * (0.24 if rows > 0 else 0.0)
	StationKit.label(holder, title, Transform3D(Basis(), Vector3(0, top, 0.0036)), 72, ink, 800, pixel)
	for i in rows:
		StationKit.label(holder, String(lines[i]), Transform3D(Basis(), Vector3(0, top - size.y * (0.27 + 0.2 * i), 0.0036)), 46, ink, 700, pixel)
	return holder


## A switch box on a wall or a column: `xform` is the middle of its back (+Z out of the wall, +Y up).
## A painted steel box with a door on two hinges, a green and a red push button and a turn switch.
static func switch_box(parent: Node3D, xform: Transform3D, size := Vector3(0.24, 0.32, 0.11), paint := Color("#7c8789")) -> Node3D:
	var holder := Node3D.new()
	holder.name = "SwitchBox"
	holder.transform = xform
	parent.add_child(holder)
	var body := StationKit.metal("detail_box_" + paint.to_html(false), {paint_color = paint, paint = 0.95, rust = 0.25, dents = 0.05, roughness_paint = 0.5})
	var shell := [
		EnvMesh.piece(EnvMesh.box(size, 0.006), Transform3D(Basis(), Vector3(0, 0, size.z * 0.5)), 0.2),
		EnvMesh.piece(EnvMesh.box(Vector3(size.x - 0.03, size.y - 0.03, 0.008), 0.003), Transform3D(Basis(), Vector3(0, 0, size.z + 0.003)), 0.6),
	]
	StationKit.add_merged(holder, shell, body)
	var parts := Parts.new()
	var front := size.z + 0.007
	for sy: float in [-0.3, 0.3]:
		hinge(parts, Vector3(-size.x * 0.5 + 0.004, size.y * sy, size.z * 0.82), Vector3.UP, Vector3.LEFT, 0.04, 0.005)
	# The turn switch: a round base and a bar across it.
	var knob := Vector3(size.x * 0.2, size.y * 0.18, front)
	parts.dark.append(EnvMesh.piece(EnvMesh.cylinder(0.026, 0.03, 0.012, 16), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), knob + Vector3(0, 0, 0.006)), 0.3))
	parts.dark.append(EnvMesh.piece(EnvMesh.box(Vector3(0.012, 0.05, 0.016), 0.003), Transform3D(Basis(Vector3.BACK, 0.5), knob + Vector3(0, 0, 0.02)), 0.3))
	# The latch on the free side.
	parts.steel.append(EnvMesh.piece(EnvMesh.cylinder(0.011, 0.012, 0.01, 10), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(size.x * 0.5 - 0.028, 0, front + 0.004)), 0.5))
	commit(holder, parts)
	for button: Array in [[Color("#2f8a45"), -0.2], [Color("#b3322b"), 0.02]]:
		var ring := StationKit.add(holder, EnvMesh.cylinder(0.019, 0.021, 0.008, 14), steel_mat(), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-size.x * 0.18, size.y * float(button[1]) + size.y * 0.16, front + 0.004)), false)
		ring.name = "ButtonRing"
		StationKit.add(holder, EnvMesh.cylinder(0.013, 0.014, 0.012, 14), _flat(button[0] as Color, 0.45), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-size.x * 0.18, size.y * float(button[1]) + size.y * 0.16, front + 0.012)), false)
	type_plate(holder, Transform3D(Basis(), Vector3(0, -size.y * 0.3, front)), "0 – I", [], Vector2(0.07, 0.028), false)
	return holder


## A pressure gauge: `xform` is the middle of its back (+Z toward the reader, +Y up); it stands on a
## short stem that points down. `value` (0..1) sets the needle.
static func gauge(parent: Node3D, xform: Transform3D, radius := 0.045, value := 0.35) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Gauge"
	holder.transform = xform
	parent.add_child(holder)
	var flat := Basis(Vector3.RIGHT, PI * 0.5)
	var parts := Parts.new()
	parts.brass.append(EnvMesh.piece(EnvMesh.cylinder(radius, radius * 1.04, radius * 0.5, 20), Transform3D(flat, Vector3(0, 0, radius * 0.25)), 0.5))
	parts.brass.append(EnvMesh.piece(EnvMesh.cylinder(radius * 0.16, radius * 0.16, radius * 0.9, 8), Transform3D(Basis(), Vector3(0, -radius * 1.4, radius * 0.25)), 0.5))
	parts.brass.append(EnvMesh.piece(EnvMesh.cylinder(radius * 0.3, radius * 0.3, radius * 0.3, 6), Transform3D(Basis(), Vector3(0, -radius * 1.75, radius * 0.25)), 0.5))
	commit(holder, parts)
	StationKit.add(holder, EnvMesh.cylinder(radius * 0.88, radius * 0.88, 0.002, 20), _flat(Color("#e9e4d6"), 0.5), Transform3D(flat, Vector3(0, 0, radius * 0.5 + 0.001)), false)
	var ink := _flat(Color("#1b1917"), 0.6)
	# Marks round three quarters of the dial, and the needle.
	var marks := []
	for k in 9:
		var a := deg_to_rad(225.0 - k * 33.75)
		var dir := Vector3(cos(a), sin(a), 0)
		marks.append(EnvMesh.piece(EnvMesh.box(Vector3(radius * 0.16, radius * 0.035, 0.001), 0.0), Transform3D(Basis(Vector3.BACK, a), dir * radius * 0.72 + Vector3(0, 0, radius * 0.5 + 0.0025)), 0.0))
	var at := deg_to_rad(225.0 - clampf(value, 0.0, 1.0) * 270.0)
	marks.append(EnvMesh.piece(EnvMesh.box(Vector3(radius * 0.75, radius * 0.05, 0.0012), 0.0), Transform3D(Basis(Vector3.BACK, at), Vector3(cos(at), sin(at), 0) * radius * 0.3 + Vector3(0, 0, radius * 0.5 + 0.004)), 0.0))
	marks.append(EnvMesh.piece(EnvMesh.cylinder(radius * 0.1, radius * 0.1, 0.003, 10), Transform3D(flat, Vector3(0, 0, radius * 0.5 + 0.005)), 0.0))
	StationKit.add_merged(holder, marks, ink, false)
	return holder


## An electric motor lying along +X of `xform`, which is the middle of its foot on the ground or a
## bracket (+Y up): a ribbed body `length` long and `radius` thick, end shields, a shaft stub, a
## terminal box, four bolted feet and a type plate.
static func motor(parent: Node3D, xform: Transform3D, length := 0.42, radius := 0.13, paint := Color("#3c5868")) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Motor"
	holder.transform = xform
	parent.add_child(holder)
	var body := StationKit.metal("detail_motor_" + paint.to_html(false), {paint_color = paint, paint = 0.92, rust = 0.3, dents = 0.05, roughness_paint = 0.5})
	var along := Basis(Vector3.BACK, -PI * 0.5)
	var mid := Vector3(0, radius + 0.03, 0)
	var shell := [EnvMesh.piece(EnvMesh.cylinder(radius * 0.92, radius * 0.92, length, 20), Transform3D(along, mid), 0.3)]
	# Cooling ribs along the body.
	for k in 14:
		var a := TAU * k / 14.0
		var dir := Vector3(0, cos(a), sin(a))
		if dir.y < -0.75:
			continue
		shell.append(EnvMesh.piece(EnvMesh.box(Vector3(length * 0.82, radius * 0.16, 0.008), 0.002), Transform3D(Basis(Vector3.RIGHT, a), mid + dir * radius * 0.96), 0.3))
	for s: float in [-1.0, 1.0]:
		shell.append(EnvMesh.piece(EnvMesh.cylinder(radius * 0.8, radius, length * 0.1, 20), Transform3D(Basis(Vector3.BACK, -s * PI * 0.5), mid + Vector3(s * length * 0.55, 0, 0)), 0.5))
		shell.append(EnvMesh.piece(EnvMesh.box(Vector3(length * 0.16, 0.03, radius * 2.3), 0.004), Transform3D(Basis(), Vector3(s * length * 0.3, 0.015, 0)), 0.6))
	shell.append(EnvMesh.piece(EnvMesh.box(Vector3(length * 0.3, radius * 0.36, radius * 0.7), 0.006), Transform3D(Basis(), mid + Vector3(-length * 0.08, radius * 1.05, 0)), 0.7))
	StationKit.add_merged(holder, shell, body)
	var parts := Parts.new()
	parts.steel.append(EnvMesh.piece(EnvMesh.cylinder(radius * 0.16, radius * 0.16, length * 0.22, 12), Transform3D(along, mid + Vector3(length * 0.7, 0, 0)), 0.4))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			bolt(parts, Vector3(sx * length * 0.3, 0.03, sz * radius * 0.98), Vector3.UP, 0.016)
		bolt_circle(parts, mid + Vector3(sx * length * 0.6, 0, 0), Vector3(sx, 0, 0), radius * 0.72, 4, 0.012, false, PI * 0.25)
	commit(holder, parts)
	type_plate(holder, Transform3D(Basis(), mid + Vector3(length * 0.14, 0, radius * 1.05)), "MM", ["3~ 4 kW"], Vector2(0.09, 0.05), false)
	return holder


## Adds everything collected in `parts` under `parent`, one merged mesh per material. The small parts
## cast no shadows of their own (`shadows` to change that); cables always do. With `cutaway` the metal
## parts dissolve in the outside camera's line of sight, as the crane girder they sit on does.
static func commit(parent: Node3D, parts: Parts, shadows := false, cutaway := false) -> void:
	if not parts.steel.is_empty():
		StationKit.add_merged(parent, parts.steel, steel_mat(cutaway), shadows).name = "DetailSteel"
	if not parts.dark.is_empty():
		StationKit.add_merged(parent, parts.dark, dark_mat(cutaway), shadows).name = "DetailDark"
	if not parts.weld.is_empty():
		StationKit.add_merged(parent, parts.weld, weld_mat(cutaway), false).name = "DetailWeld"
	if not parts.rubber.is_empty():
		StationKit.add_merged(parent, parts.rubber, rubber_mat(), true).name = "DetailCable"
	if not parts.brass.is_empty():
		StationKit.add_merged(parent, parts.brass, brass_mat(cutaway), shadows).name = "DetailBrass"


# --- Materials -----------------------------------------------------------------------------------

## Zinc-plated steel of bolts, clips and fittings.
static func steel_mat(cutaway := false) -> ShaderMaterial:
	return StationKit.metal("detail_steel" + ("_cut" if cutaway else ""), {steel_color = Color("#8f9499"), rust = 0.3, dents = 0.0,
		metallic_steel = 0.8, roughness_steel = 0.38, dust = 0.25, grime = 0.25, edge_wear = 0.15, cutaway = cutaway})


## Blackened iron of fasteners on dark machinery.
static func dark_mat(cutaway := false) -> ShaderMaterial:
	return StationKit.metal("detail_dark" + ("_cut" if cutaway else ""), {steel_color = Color("#3d3c3b"), rust = 0.5, dents = 0.0,
		metallic_steel = 0.6, roughness_steel = 0.5, dust = 0.25, grime = 0.2, edge_wear = 0.2, cutaway = cutaway})


## The grey-blue of a weld bead.
static func weld_mat(cutaway := false) -> ShaderMaterial:
	return StationKit.metal("detail_weld" + ("_cut" if cutaway else ""), {steel_color = Color("#5a5e64"), rust = 0.4, dents = 0.0,
		metallic_steel = 0.7, roughness_steel = 0.5, dust = 0.1, grime = 0.3, edge_wear = 0.0, cutaway = cutaway})


## Old brass with a little verdigris.
static func brass_mat(cutaway := false) -> ShaderMaterial:
	return StationKit.metal("detail_brass" + ("_cut" if cutaway else ""), {steel_color = Color("#b08d4a"), rust_color = Color("#6b6a45"),
		rust = 0.25, patina = 1.0, dents = 0.0, metallic_steel = 0.9, roughness_steel = 0.38, dust = 0.15, grime = 0.25, edge_wear = 0.15,
		cutaway = cutaway})


## Black rubber of cables.
static func rubber_mat() -> StandardMaterial3D:
	return _flat(Color("#141414"), 0.8)


## A plain coloured material (buttons, dials, ink), shared per colour and roughness.
static func _flat(colour: Color, roughness: float) -> StandardMaterial3D:
	var key := colour.to_html(false) + str(roughness)
	if not _plain.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = colour
		mat.roughness = roughness
		_plain[key] = mat
	return _plain[key]


## `points` with every inner corner rounded: `steps` points on a curve that leaves the corner
## `reach` before it and meets the next run `reach` after it (0: a third of the shorter run).
static func _rounded(points: PackedVector3Array, steps := 5, reach := 0.0) -> PackedVector3Array:
	if points.size() < 3:
		return points
	var out := PackedVector3Array([points[0]])
	for i in range(1, points.size() - 1):
		var before := points[i - 1] - points[i]
		var after := points[i + 1] - points[i]
		var r := reach if reach > 0.0 else minf(before.length(), after.length()) / 3.0
		r = minf(r, minf(before.length(), after.length()) * 0.5)
		var a := points[i] + before.normalized() * r
		var b := points[i] + after.normalized() * r
		for k in steps + 1:
			var t := float(k) / steps
			out.append(a.lerp(points[i], t).lerp(points[i].lerp(b, t), t))
	out.append(points[points.size() - 1])
	return out
