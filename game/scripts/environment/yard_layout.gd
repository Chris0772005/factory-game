class_name YardLayout
extends RefCounted
## Floor plan of the backyard, shared by the ground, the grass and the set
## dressing: fence and house lines, station keep-out zones (read from the real
## station nodes, so moving a station moves its worn dirt and keeps props away),
## the ground zone mask (R dirt, G gravel, B soot, A moulding sand) and the
## detail mask (R trodden walkways between the stations, G damp, B puddles).

## Inside of the fence (x, z).
const YARD_MIN := Vector2(-12.5, -9.0)
const YARD_MAX := Vector2(12.5, 9.0)
## Front face of the house and its extent along x.
const HOUSE_FRONT_Z := -9.1
const HOUSE_X := Vector2(-9.6, 5.6)
const DOOR_X := -4.0
## Gate in the right-hand fence (z of its centre).
const GATE_Z := 2.0
## Garden shed: centre and footprint (x, z); its doors face +x.
const SHED_CENTER := Vector2(-10.6, -5.4)
const SHED_SIZE := Vector2(2.8, 3.4)
## Worn work area: rounded rectangle centre, half extents and corner radius.
const WORK_CENTER := Vector2(-0.2, -1.2)
const WORK_HALF := Vector2(7.2, 4.7)
const WORK_CORNER := 2.8
## Where workers spawn and respawn (GameWorld.spawn_player / respawn_point).
const SPAWN_CENTER := Vector2(1.2, 5.0)
## Damp ground: [centre, radius, puddle (0..1)] - under the rain barrel's
## overflow, and where the quench bucket in the work area gets sloshed.
const DAMP_SPOTS := [
	[Vector2(4.75, -8.15), 0.85, 1.0],
	[Vector2(-5.1, -3.75), 0.75, 0.0],
	[Vector2(-5.45, -3.6), 0.32, 0.8],
]

## Zone mask: world rectangle and resolution.
const MASK_ORIGIN := Vector2(-14.0, -10.5)
const MASK_SIZE := Vector2(28.0, 21.0)
const MASK_PPM := 4

## [Vector2 centre, radius] areas that must stay walkable (stations, spawn).
var keep_out: Array = []
## Rect2 areas covered by buildings (no grass); round footprints live in a grid.
var covered: Array[Rect2] = []
var furnace := Vector2(-3.0, -2.5)
var molds: Array[Vector2] = []
## Every station: [centre, keep-out radius, yaw, kind] (kind: &"furnace",
## &"mold", &"scrap", &"bench" or &"other").
var station_spots: Array = []
var mask: Image
var detail: Image

var _wear: Array = []
## 1 m cell -> [[centre, radius], ...] of covered round footprints.
var _cover_grid := {}
var _w := 0
var _h := 0
## Mask channels as floats: zones r g b a, then detail r g b a.
var _ch: Array[PackedFloat32Array] = []


## `stations`: the gameplay station nodes (furnace, scrap pile, bench, molds,
## sell crate, upgrade board). Their positions drive wear, soot and sand.
func _init(stations: Array) -> void:
	for s in stations:
		if not (s is Node3D):
			continue
		var p := Vector2(s.position.x, s.position.z)
		var r := 1.6
		var kind := &"other"
		if s is Furnace:
			furnace = p
			r = 2.0
			kind = &"furnace"
		elif s is MoldBox:
			molds.append(p)
			r = 1.5
			kind = &"mold"
		elif s is ScrapPile:
			kind = &"scrap"
		elif s is ModelBench:
			kind = &"bench"
		keep_out.append([p, r])
		_wear.append([p, r])
		station_spots.append([p, r, (s as Node3D).rotation.y, kind])
	keep_out.append([SPAWN_CENTER, 2.4])
	keep_out.append([Vector2(1.5, 2.6), 0.9])
	covered.append(Rect2(HOUSE_X.x - 0.3, HOUSE_FRONT_Z - 10.0, HOUSE_X.y - HOUSE_X.x + 0.6, 10.3))
	covered.append(Rect2(SHED_CENTER - SHED_SIZE * 0.5 - Vector2(0.1, 0.1), SHED_SIZE + Vector2(0.2, 0.2)))
	_paint_mask()


## True when a prop of radius `r` at `p` stays clear of every station's
## walk-around zone (and, with `inside`, inside the fence).
func is_free(p: Vector2, r: float, inside := false) -> bool:
	if inside and (p.x - r < YARD_MIN.x or p.x + r > YARD_MAX.x or p.y - r < YARD_MIN.y or p.y + r > YARD_MAX.y):
		return false
	for k in keep_out:
		if p.distance_to(k[0]) < k[1] + r:
			return false
	return true


## True when `p` is under a building or a prop (no grass there).
func is_covered(p: Vector2) -> bool:
	for c in covered:
		if (c as Rect2).has_point(p):
			return true
	var cell := Vector2i(floori(p.x), floori(p.y))
	for c in _cover_grid.get(cell, []):
		if p.distance_to(c[0]) < c[1]:
			return true
	return false


## Marks a round footprint as covered (grass will not grow there).
func cover(p: Vector2, r: float) -> void:
	for x in range(floori(p.x - r), floori(p.x + r) + 1):
		for y in range(floori(p.y - r), floori(p.y + r) + 1):
			var cell := Vector2i(x, y)
			if not _cover_grid.has(cell):
				_cover_grid[cell] = []
			_cover_grid[cell].append([p, r])


## Bilinear mask sample at a world position: r dirt, g gravel, b soot, a sand.
func zones_at(p: Vector2) -> Color:
	return _sample(p, 0)


## Bilinear detail-mask sample: r trodden walkway, g damp, b puddle.
func detail_at(p: Vector2) -> Color:
	return _sample(p, 4)


func _sample(p: Vector2, first: int) -> Color:
	var q := (p - MASK_ORIGIN) * MASK_PPM - Vector2(0.5, 0.5)
	if q.x < 0.0 or q.y < 0.0 or q.x >= _w - 1 or q.y >= _h - 1:
		return Color(0, 0, 0, 0)
	var x := int(q.x)
	var y := int(q.y)
	var fx := q.x - x
	var fy := q.y - y
	var out := [0.0, 0.0, 0.0, 0.0]
	for c in 4:
		var ch := _ch[first + c]
		var a := lerpf(ch[y * _w + x], ch[y * _w + x + 1], fx)
		var b := lerpf(ch[(y + 1) * _w + x], ch[(y + 1) * _w + x + 1], fx)
		out[c] = lerpf(a, b, fy)
	return Color(out[0], out[1], out[2], out[3])


## Shader parameter for the ground: mask origin and size.
func mask_rect() -> Vector4:
	return Vector4(MASK_ORIGIN.x, MASK_ORIGIN.y, MASK_SIZE.x, MASK_SIZE.y)


func _paint_mask() -> void:
	_w = int(MASK_SIZE.x * MASK_PPM)
	_h = int(MASK_SIZE.y * MASK_PPM)
	for c in 8:
		var arr := PackedFloat32Array()
		arr.resize(_w * _h)
		_ch.append(arr)
	var walks := _walkways()
	# Only the visuals read the detail mask: headless runs (tests, servers) skip it.
	var with_details := EnvMesh.visual()
	var bytes := PackedByteArray()
	bytes.resize(_w * _h * 4)
	var detail_bytes := PackedByteArray()
	detail_bytes.resize(_w * _h * 4)
	for y in _h:
		for x in _w:
			var p := MASK_ORIGIN + (Vector2(x, y) + Vector2(0.5, 0.5)) / MASK_PPM
			var v := _zones(p)
			var i := y * _w + x
			for c in 4:
				_ch[c][i] = v[c]
				bytes[i * 4 + c] = int(clampf(v[c], 0.0, 1.0) * 255.0)
			if with_details:
				var dv := _details(p, v[0], walks)
				for c in 4:
					_ch[4 + c][i] = dv[c]
					detail_bytes[i * 4 + c] = int(clampf(dv[c], 0.0, 1.0) * 255.0)
	mask = Image.create_from_data(_w, _h, false, Image.FORMAT_RGBA8, bytes)
	detail = Image.create_from_data(_w, _h, false, Image.FORMAT_RGBA8, detail_bytes)


## Walkway segments [a, b, half width] the workers wear into the dirt: from
## every station and the spawn to the nearest mold, from the furnace to each
## mold, and the gate path.
func _walkways() -> Array:
	var out := []
	var hub := SPAWN_CENTER
	if not molds.is_empty():
		hub = Vector2.ZERO
		for m in molds:
			hub += m
		hub /= molds.size()
	for s in station_spots:
		var p: Vector2 = s[0]
		if p in molds:
			continue
		var target := hub
		var best := INF
		for m in molds:
			if p.distance_to(m) < best:
				best = p.distance_to(m)
				target = m
		out.append([p, target, 0.55])
	for m in molds:
		out.append([furnace, m, 0.5])
	out.append([SPAWN_CENTER, hub, 0.5])
	out.append([Vector2(6.0, 1.6), Vector2(YARD_MAX.x, GATE_Z), 0.45])
	return out


## Detail weights at a world point: [trodden, damp, puddle, 0]. Walkways only
## exist where the ground is dirt; each station gets a worn ring where people
## stand to work it.
func _details(p: Vector2, dirt: float, walks: Array) -> Array:
	var trod := 0.0
	# Most of the mask is lawn: skip the walkway maths there.
	if dirt > 0.35:
		for w in walks:
			trod = maxf(trod, _capsule(p, w[0], w[1], w[2]))
		for s in station_spots:
			var d := p.distance_to(s[0])
			var r: float = s[1]
			if d < r * 1.3:
				trod = maxf(trod, 0.8 * (1.0 - smoothstep(0.25, 0.6, absf(d - r * 0.62) / r)))
		trod *= smoothstep(0.35, 0.8, dirt)
	var damp := 0.0
	var puddle := 0.0
	for spot in DAMP_SPOTS:
		var r: float = spot[1]
		if p.distance_squared_to(spot[0]) < r * r:
			damp = maxf(damp, _disc(p, spot[0], r))
			puddle = maxf(puddle, float(spot[2]) * _disc(p, spot[0], r * 0.62))
	return [trod, damp, puddle, 0.0]


## Zone weights at a world point: [dirt, gravel, soot, sand].
func _zones(p: Vector2) -> Array:
	# Worn work area with soft, wide borders (the shader breaks them up).
	var q := (p - WORK_CENTER).abs() - WORK_HALF + Vector2(WORK_CORNER, WORK_CORNER)
	var sd := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - WORK_CORNER
	var dirt := 1.0 - smoothstep(-0.6, 0.7, sd)
	# Paths: to the gate, to the shed doors, trodden lawn at the spawn.
	dirt = maxf(dirt, _capsule(p, Vector2(6.0, 1.6), Vector2(YARD_MAX.x + 0.5, GATE_Z), 0.75))
	dirt = maxf(dirt, _capsule(p, Vector2(-6.8, -4.2), Vector2(SHED_CENTER.x + SHED_SIZE.x * 0.5, SHED_CENTER.y + 0.3), 0.7))
	dirt = maxf(dirt, 0.45 * _disc(p, SPAWN_CENTER + Vector2(0.0, -0.4), 1.3))
	for k in _wear:
		dirt = maxf(dirt, 0.8 * _disc(p, k[0], k[1] * 0.55))
	# Gravel drip strip along the house and the stone landing at the back door.
	var gravel := 0.0
	if p.x > HOUSE_X.x - 0.2 and p.x < HOUSE_X.y + 0.2:
		gravel = 1.0 - smoothstep(0.55, 0.95, p.y - HOUSE_FRONT_Z)
	gravel = maxf(gravel, _disc(p, Vector2(DOOR_X, HOUSE_FRONT_Z + 0.8), 1.1))
	# Soot ring around the furnace, moulding sand spilled around the molds.
	var soot := _disc(p, furnace, 1.7)
	var sand := 0.0
	for m in molds:
		sand = maxf(sand, 0.85 * _disc(p, m, 1.25))
	if molds.size() >= 2:
		sand = maxf(sand, 0.6 * _capsule(p, molds[0], molds[1], 0.9))
	return [dirt, gravel, soot, sand]


## 1 inside the disc, fading to 0 over the outer 40 %.
func _disc(p: Vector2, c: Vector2, r: float) -> float:
	return 1.0 - smoothstep(r * 0.6, r, p.distance_to(c))


func _capsule(p: Vector2, a: Vector2, b: Vector2, r: float) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return _disc(p, a + ab * t, r)
