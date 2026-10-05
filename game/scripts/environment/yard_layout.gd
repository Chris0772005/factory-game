class_name YardLayout
extends RefCounted
## Floor plan of the backyard, shared by the ground, the grass and the set
## dressing: fence and house lines, station keep-out zones (read from the real
## station nodes, so moving a station moves its worn dirt and keeps props away)
## and the ground zone mask (R dirt, G gravel, B soot, A moulding sand).

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
var mask: Image

var _wear: Array = []
## 1 m cell -> [[centre, radius], ...] of covered round footprints.
var _cover_grid := {}
var _w := 0
var _h := 0
var _ch: Array[PackedFloat32Array] = []


## `stations`: the gameplay station nodes (furnace, scrap pile, bench, molds,
## sell crate, upgrade board). Their positions drive wear, soot and sand.
func _init(stations: Array) -> void:
	for s in stations:
		if not (s is Node3D):
			continue
		var p := Vector2(s.position.x, s.position.z)
		var r := 1.6
		if s is Furnace:
			furnace = p
			r = 2.0
		elif s is MoldBox:
			molds.append(p)
			r = 1.5
		keep_out.append([p, r])
		_wear.append([p, r])
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
	var q := (p - MASK_ORIGIN) * MASK_PPM - Vector2(0.5, 0.5)
	if q.x < 0.0 or q.y < 0.0 or q.x >= _w - 1 or q.y >= _h - 1:
		return Color(0, 0, 0, 0)
	var x := int(q.x)
	var y := int(q.y)
	var fx := q.x - x
	var fy := q.y - y
	var out := [0.0, 0.0, 0.0, 0.0]
	for c in 4:
		var a := lerpf(_ch[c][y * _w + x], _ch[c][y * _w + x + 1], fx)
		var b := lerpf(_ch[c][(y + 1) * _w + x], _ch[c][(y + 1) * _w + x + 1], fx)
		out[c] = lerpf(a, b, fy)
	return Color(out[0], out[1], out[2], out[3])


## Shader parameter for the ground: mask origin and size.
func mask_rect() -> Vector4:
	return Vector4(MASK_ORIGIN.x, MASK_ORIGIN.y, MASK_SIZE.x, MASK_SIZE.y)


func _paint_mask() -> void:
	_w = int(MASK_SIZE.x * MASK_PPM)
	_h = int(MASK_SIZE.y * MASK_PPM)
	for c in 4:
		var arr := PackedFloat32Array()
		arr.resize(_w * _h)
		_ch.append(arr)
	var bytes := PackedByteArray()
	bytes.resize(_w * _h * 4)
	for y in _h:
		for x in _w:
			var p := MASK_ORIGIN + (Vector2(x, y) + Vector2(0.5, 0.5)) / MASK_PPM
			var v := _zones(p)
			var i := y * _w + x
			for c in 4:
				_ch[c][i] = v[c]
				bytes[i * 4 + c] = int(clampf(v[c], 0.0, 1.0) * 255.0)
	mask = Image.create_from_data(_w, _h, false, Image.FORMAT_RGBA8, bytes)


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
