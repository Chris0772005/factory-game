class_name DrawingTemplates
## Ready-made motifs for the drawing pad and for orders that ask for one
## ("gieß ein Haus"). On the pad a motif is one click: it lands on the sheet
## as ordinary strokes and can be drawn over. `score` says how well any
## drawing matches a motif, so a hand-drawn house counts for a house order
## as well as the template does.

const GRID := 44
## A casting counts as the motif from this score up (0..1).
const MATCH := 0.56

const MOTIFS := {
	&"house": {name = "ein Haus", label = "Haus"},
	&"star": {name = "einen Stern", label = "Stern"},
	&"heart": {name = "ein Herz", label = "Herz"},
	&"key": {name = "einen Schlüssel", label = "Schlüssel"},
	&"fish": {name = "einen Fisch", label = "Fisch"},
	&"crown": {name = "eine Krone", label = "Krone"},
	&"gear": {name = "ein Zahnrad", label = "Zahnrad"},
	&"anchor": {name = "einen Anker", label = "Anker"},
	# Weapons: only the pawnbroker asks for these (dark = true). A casting in
	# one of these shapes is contraband (TownLaw.weapon_of).
	&"knuckles": {name = "einen Schlagring", label = "Schlagring", dark = true},
	&"dagger": {name = "einen Dolch", label = "Dolch", dark = true},
	&"pistol": {name = "eine Pistole", label = "Pistole", dark = true},
}

static var _rasters := {}


static func drawing(id: StringName) -> Drawing:
	var d := Drawing.new()
	for stroke in _strokes(id):
		d.add_stroke(stroke)
	return d


static func _strokes(id: StringName) -> Array:
	match id:
		&"house":
			return [
				_line([Vector2(0.2, 0.9), Vector2(0.2, 0.46), Vector2(0.5, 0.14), Vector2(0.8, 0.46), Vector2(0.8, 0.9), Vector2(0.2, 0.9)]),
				_line([Vector2(0.12, 0.5), Vector2(0.5, 0.1), Vector2(0.88, 0.5)]),
				_line([Vector2(0.43, 0.9), Vector2(0.43, 0.64), Vector2(0.57, 0.64), Vector2(0.57, 0.9)]),
				_line([Vector2(0.62, 0.52), Vector2(0.72, 0.52), Vector2(0.72, 0.62), Vector2(0.62, 0.62), Vector2(0.62, 0.52)]),
				_line([Vector2(0.66, 0.3), Vector2(0.66, 0.16), Vector2(0.74, 0.16), Vector2(0.74, 0.38)]),
			]
		&"star":
			var pts := []
			for i in 11:
				var a := -PI * 0.5 + i * TAU / 10.0
				pts.append(Vector2(0.5, 0.52) + Vector2(cos(a), sin(a)) * (0.42 if i % 2 == 0 else 0.18))
			return [_line(pts)]
		&"heart":
			var left := _arc(Vector2(0.32, 0.36), Vector2(0.2, 0.2), 160.0, 360.0)
			var right := _arc(Vector2(0.68, 0.36), Vector2(0.2, 0.2), 180.0, 380.0)
			var out := PackedVector2Array([Vector2(0.5, 0.88)])
			out.append_array(_line([Vector2(0.5, 0.88), Vector2(0.13, 0.43)]))
			out.append_array(left)
			out.append_array(right)
			out.append_array(_line([Vector2(0.87, 0.43), Vector2(0.5, 0.88)]))
			return [out]
		&"key":
			return [
				_arc(Vector2(0.27, 0.5), Vector2(0.17, 0.2), 0.0, 360.0),
				_line([Vector2(0.44, 0.5), Vector2(0.9, 0.5)]),
				_line([Vector2(0.72, 0.5), Vector2(0.72, 0.68)]),
				_line([Vector2(0.86, 0.5), Vector2(0.86, 0.72)]),
			]
		&"fish":
			var body := _arc(Vector2(0.43, 0.5), Vector2(0.31, 0.21), 0.0, 360.0)
			return [
				body,
				_line([Vector2(0.72, 0.5), Vector2(0.92, 0.3), Vector2(0.92, 0.7), Vector2(0.72, 0.5)]),
				_line([Vector2(0.26, 0.44), Vector2(0.27, 0.45)]),
				_arc(Vector2(0.47, 0.5), Vector2(0.08, 0.14), -70.0, 70.0),
			]
		&"crown":
			return [
				_line([Vector2(0.14, 0.8), Vector2(0.14, 0.3), Vector2(0.32, 0.54), Vector2(0.5, 0.2), Vector2(0.68, 0.54), Vector2(0.86, 0.3), Vector2(0.86, 0.8), Vector2(0.14, 0.8)]),
				_line([Vector2(0.14, 0.68), Vector2(0.86, 0.68)]),
			]
		&"gear":
			var rim := []
			for i in 33:
				var a := i * TAU / 32.0
				var r := 0.4 if (i / 2) % 2 == 0 else 0.3
				rim.append(Vector2(0.5, 0.5) + Vector2(cos(a), sin(a)) * r)
			return [_line(rim), _arc(Vector2(0.5, 0.5), Vector2(0.11, 0.11), 0.0, 360.0)]
		&"anchor":
			return [
				_arc(Vector2(0.5, 0.17), Vector2(0.08, 0.08), 0.0, 360.0),
				_line([Vector2(0.5, 0.25), Vector2(0.5, 0.88)]),
				_line([Vector2(0.3, 0.38), Vector2(0.7, 0.38)]),
				_arc(Vector2(0.5, 0.58), Vector2(0.34, 0.3), 10.0, 170.0),
				_line([Vector2(0.84, 0.63), Vector2(0.78, 0.5), Vector2(0.92, 0.52)]),
				_line([Vector2(0.16, 0.63), Vector2(0.22, 0.5), Vector2(0.08, 0.52)]),
			]
		&"knuckles":
			var rings := []
			for x: float in [0.2, 0.4, 0.6, 0.8]:
				rings.append(_arc(Vector2(x, 0.36), Vector2(0.075, 0.1), 0.0, 360.0))
			rings.append(_line([Vector2(0.08, 0.22), Vector2(0.92, 0.22), Vector2(0.92, 0.52), Vector2(0.8, 0.78), Vector2(0.2, 0.78), Vector2(0.08, 0.52), Vector2(0.08, 0.22)]))
			return rings
		&"dagger":
			return [
				_line([Vector2(0.5, 0.05), Vector2(0.59, 0.6), Vector2(0.41, 0.6), Vector2(0.5, 0.05)]),
				_line([Vector2(0.27, 0.6), Vector2(0.73, 0.6), Vector2(0.73, 0.66), Vector2(0.27, 0.66), Vector2(0.27, 0.6)]),
				_line([Vector2(0.45, 0.66), Vector2(0.45, 0.88), Vector2(0.55, 0.88), Vector2(0.55, 0.66)]),
				_arc(Vector2(0.5, 0.92), Vector2(0.06, 0.05), 0.0, 360.0),
			]
		&"pistol":
			return [
				_line([Vector2(0.08, 0.28), Vector2(0.88, 0.28), Vector2(0.88, 0.46), Vector2(0.08, 0.46), Vector2(0.08, 0.28)]),
				_line([Vector2(0.62, 0.46), Vector2(0.7, 0.88), Vector2(0.9, 0.88), Vector2(0.84, 0.46)]),
				_arc(Vector2(0.5, 0.48), Vector2(0.12, 0.14), 0.0, 180.0),
				_line([Vector2(0.53, 0.46), Vector2(0.5, 0.56)]),
			]
	return []


## How well `d` matches motif `id`, 0..1: the smaller of "how much of the
## motif is drawn" and "how much of the drawing belongs to the motif", both
## with a little slack, so shaky hands and other sizes of line still count.
static func score(d: Drawing, id: StringName) -> float:
	if d == null or d.is_empty() or not MOTIFS.has(id):
		return 0.0
	if not _rasters.has(id):
		_rasters[id] = _fitted_raster(drawing(id))
	var want: PackedByteArray = _rasters[id]
	var got := _fitted_raster(d)
	return minf(_covered(want, got), _covered(got, want))


## The motif `d` matches best, &"" if none reaches MATCH.
static func best(d: Drawing) -> StringName:
	var top := &""
	var top_score := MATCH
	for id: StringName in MOTIFS:
		var s := score(d, id)
		if s >= top_score:
			top_score = s
			top = id
	return top


## Share of the cells set in `a` that have a set cell of `b` on or next to them.
static func _covered(a: PackedByteArray, b: PackedByteArray) -> float:
	var total := 0
	var hit := 0
	for y in GRID:
		for x in GRID:
			if a[y * GRID + x] == 0:
				continue
			total += 1
			var found := false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var nx := x + dx
					var ny := y + dy
					if nx >= 0 and ny >= 0 and nx < GRID and ny < GRID and b[ny * GRID + nx] != 0:
						found = true
						break
				if found:
					break
			if found:
				hit += 1
	return float(hit) / maxf(float(total), 1.0)


## `d` scaled to fill the sheet like the motifs do, then rastered: a small
## house in a corner is still a house.
static func _fitted_raster(d: Drawing) -> PackedByteArray:
	var lo := Vector2(1, 1)
	var hi := Vector2(0, 0)
	for s in d.strokes:
		for p in s:
			lo = lo.min(p)
			hi = hi.max(p)
	var span := maxf(maxf(hi.x - lo.x, hi.y - lo.y), 0.05)
	var centre := (lo + hi) * 0.5
	var fitted := Drawing.new()
	for s in d.strokes:
		var pts := PackedVector2Array()
		for p in s:
			pts.append(Vector2(0.5, 0.5) + (p - centre) * (0.8 / span))
		fitted.add_stroke(pts)
	return _raster(fitted)


## Cells the strokes of `d` pass through.
static func _raster(d: Drawing) -> PackedByteArray:
	var grid := PackedByteArray()
	grid.resize(GRID * GRID)
	for s in d.strokes:
		for i in s.size():
			var a: Vector2 = s[maxi(i - 1, 0)]
			var b: Vector2 = s[i]
			var steps := maxi(1, ceili(a.distance_to(b) * GRID * 2.0))
			for k in steps + 1:
				var p := a.lerp(b, float(k) / steps)
				var x := clampi(int(p.x * GRID), 0, GRID - 1)
				var y := clampi(int(p.y * GRID), 0, GRID - 1)
				grid[y * GRID + x] = 1
	return grid


static func _arc(center: Vector2, radius: Vector2, from_deg: float, to_deg: float) -> PackedVector2Array:
	return DrawingSamples._arc(center, radius, from_deg, to_deg)


static func _line(points: Array) -> PackedVector2Array:
	return DrawingSamples._line(points)
