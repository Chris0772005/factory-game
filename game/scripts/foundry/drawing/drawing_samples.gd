class_name DrawingSamples
## Hand-made sample drawings for tests, showcases and attract modes.


static func smiley() -> Drawing:
	var d := Drawing.new()
	d.add_stroke(_arc(Vector2(0.5, 0.5), Vector2(0.4, 0.4), -100.0, 268.0))
	d.add_stroke(_line([Vector2(0.37, 0.33), Vector2(0.37, 0.44)]))
	d.add_stroke(_line([Vector2(0.63, 0.33), Vector2(0.63, 0.44)]))
	d.add_stroke(_arc(Vector2(0.5, 0.52), Vector2(0.21, 0.17), 20.0, 160.0))
	return d


static func letter_o() -> Drawing:
	var d := Drawing.new()
	d.add_stroke(_arc(Vector2(0.5, 0.5), Vector2(0.3, 0.42), -90.0, 275.0))
	return d


static func letter_b() -> Drawing:
	var d := Drawing.new()
	d.add_stroke(_line([Vector2(0.3, 0.08), Vector2(0.3, 0.92)]))
	var top := _line([Vector2(0.3, 0.08), Vector2(0.5, 0.08)])
	top.append_array(_arc(Vector2(0.5, 0.29), Vector2(0.19, 0.21), -90.0, 90.0))
	top.append(Vector2(0.3, 0.5))
	d.add_stroke(top)
	var bottom := _line([Vector2(0.3, 0.5), Vector2(0.52, 0.5)])
	bottom.append_array(_arc(Vector2(0.52, 0.71), Vector2(0.23, 0.21), -90.0, 90.0))
	bottom.append(Vector2(0.3, 0.92))
	d.add_stroke(bottom)
	return d


static func star() -> Drawing:
	var d := Drawing.new()
	var pts := PackedVector2Array()
	for i in 11:
		var r := 0.46 if i % 2 == 0 else 0.2
		var t := deg_to_rad(-90.0 + 36.0 * i)
		pts.append(Vector2(0.5, 0.53) + Vector2(cos(t), sin(t)) * r)
	d.add_stroke(_densified(pts, 0.02))
	d.add_stroke(PackedVector2Array([Vector2(0.5, 0.53)]))
	return d


static func cat() -> Drawing:
	var d := Drawing.new()
	var c := Vector2(0.5, 0.58)
	var head := _arc(c, Vector2(0.34, 0.3), -30.0, 210.0)
	head.append(Vector2(0.22, 0.12))
	head.append_array(_arc(c, Vector2(0.34, 0.3), 245.0, 295.0))
	head.append(Vector2(0.78, 0.12))
	head.append(head[0])
	d.add_stroke(_densified(head, 0.02))
	d.add_stroke(PackedVector2Array([Vector2(0.38, 0.52)]))
	d.add_stroke(PackedVector2Array([Vector2(0.62, 0.52)]))
	d.add_stroke(_line([Vector2(0.46, 0.62), Vector2(0.54, 0.62), Vector2(0.5, 0.67), Vector2(0.46, 0.62)]))
	d.add_stroke(_line([Vector2(0.42, 0.74), Vector2(0.46, 0.77), Vector2(0.5, 0.71), Vector2(0.54, 0.77), Vector2(0.58, 0.74)]))
	for side in [-1.0, 1.0]:
		for k in 2:
			var y := 0.64 + k * 0.08
			d.add_stroke(_line([Vector2(0.5 + side * 0.36, y), Vector2(0.5 + side * 0.47, y - 0.03 + k * 0.06)]))
	return d


static func spiral() -> Drawing:
	var d := Drawing.new()
	var pts := PackedVector2Array()
	for i in 160:
		var t := i / 159.0 * TAU * 2.6
		var r := 0.03 + t / TAU * 0.16
		pts.append(Vector2(0.5, 0.5) + Vector2(cos(t), sin(t)) * r)
	d.add_stroke(pts)
	return d


static func gnome() -> Drawing:
	var d := Drawing.new()
	d.add_stroke(_line([Vector2(0.3, 0.42), Vector2(0.52, 0.06), Vector2(0.7, 0.42), Vector2(0.3, 0.42)]))
	d.add_stroke(_arc(Vector2(0.5, 0.5), Vector2(0.14, 0.1), 180.0, 360.0))
	d.add_stroke(PackedVector2Array([Vector2(0.45, 0.5)]))
	d.add_stroke(PackedVector2Array([Vector2(0.55, 0.5)]))
	d.add_stroke(_line([Vector2(0.37, 0.52), Vector2(0.4, 0.66), Vector2(0.45, 0.6), Vector2(0.5, 0.72),
		Vector2(0.55, 0.6), Vector2(0.6, 0.66), Vector2(0.63, 0.52)]))
	d.add_stroke(_line([Vector2(0.33, 0.6), Vector2(0.27, 0.92), Vector2(0.73, 0.92), Vector2(0.67, 0.6)]))
	d.add_stroke(_line([Vector2(0.33, 0.68), Vector2(0.2, 0.78)]))
	d.add_stroke(_line([Vector2(0.67, 0.68), Vector2(0.8, 0.78)]))
	return d


static func all() -> Dictionary:
	return {
		smiley = smiley(), letter_o = letter_o(), letter_b = letter_b(),
		star = star(), cat = cat(), spiral = spiral(), gnome = gnome(),
	}


## Elliptic arc from `from_deg` to `to_deg` (y down, 0° = right).
static func _arc(center: Vector2, radius: Vector2, from_deg: float, to_deg: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := maxi(8, int(absf(to_deg - from_deg) / 6.0))
	for i in steps + 1:
		var t := deg_to_rad(lerpf(from_deg, to_deg, float(i) / steps))
		pts.append(center + Vector2(cos(t), sin(t)) * radius)
	return pts


static func _line(points: Array) -> PackedVector2Array:
	return _densified(PackedVector2Array(points), 0.02)


## Inserts points so that no segment is longer than `step`, like mouse input.
static func _densified(points: PackedVector2Array, step: float) -> PackedVector2Array:
	var out := PackedVector2Array([points[0]])
	for i in range(1, points.size()):
		var a := points[i - 1]
		var b := points[i]
		var n := maxi(1, ceili(a.distance_to(b) / step))
		for k in range(1, n + 1):
			out.append(a.lerp(b, float(k) / n))
	return out
