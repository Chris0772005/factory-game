class_name BellProfile
extends RefCounted
## A bell drawn as its silhouette. The longest stroke of a Drawing is read as
## the outline: distance from the pad's centre line (x = 0.5) is the radius,
## pad y is the height (crown at the top, mouth at the bottom). The outline is
## resampled from crown to mouth, turned on a lathe into a hollow shell, and
## gives the bell its size, the metal it needs and its tone (BellTone).

## Samples from crown (0) to mouth (SAMPLES - 1).
const SAMPLES := 28
## A profile must span at least this much of the pad's height.
const MIN_SPAN := 0.25
## Wall thickness as a share of the mouth radius (real bells: ~1/13 of the
## diameter at the sound bow).
const WALL := 0.16
## Game litres per cubic metre of metal (same scale as MoldBox.LITRES_PER_M3).
const LITRES_PER_M3 := 260.0

## Outer radius per sample, 0..1 of the mouth radius.
var radius := PackedFloat32Array()
## Height of the profile relative to the mouth radius.
var aspect := 1.0
## 0 = smooth curve, 1 = very lumpy (makes a crooked tone).
var irregularity := 0.0
## Raw mean second difference of the outline (relative to the mouth).
var lumpiness := 0.0
## Stable id of the drawing (detuning and sound cache).
var seed := 0


## Null if the drawing has no usable outline (too short or flat).
static func from_drawing(d: Drawing) -> BellProfile:
	if d == null or d.strokes.is_empty():
		return null
	var stroke: PackedVector2Array = d.strokes[0]
	for s in d.strokes:
		if s.size() > stroke.size():
			stroke = s
	if stroke.size() < 3:
		return null
	var y0 := INF
	var y1 := -INF
	for p in stroke:
		y0 = minf(y0, p.y)
		y1 = maxf(y1, p.y)
	if y1 - y0 < MIN_SPAN:
		return null
	var raw := PackedFloat32Array()
	raw.resize(SAMPLES)
	for i in SAMPLES:
		var y := lerpf(y0, y1, float(i) / (SAMPLES - 1))
		raw[i] = _radius_at(stroke, y)
	var mouth := 0.0
	for r in raw:
		mouth = maxf(mouth, r)
	if mouth < 0.05:
		return null
	var b := BellProfile.new()
	b.seed = hash(d.to_code())
	b.aspect = (y1 - y0) / mouth
	# Lumpiness: mean second difference of the raw outline (before smoothing).
	var bumps := 0.0
	for i in range(1, SAMPLES - 1):
		bumps += absf(raw[i - 1] - 2.0 * raw[i] + raw[i + 1])
	b.lumpiness = bumps / (SAMPLES - 2) / mouth
	# Calibrated on the samples: a calm hand stays below ~0.01 (pure), a
	# shaky +-10 % wobble reaches ~0.025 (crooked).
	b.irregularity = clampf((b.lumpiness - 0.008) / 0.025, 0.0, 1.0)
	b.radius.resize(SAMPLES)
	for i in SAMPLES:
		var a := raw[maxi(i - 1, 0)]
		var c := raw[mini(i + 1, SAMPLES - 1)]
		b.radius[i] = clampf((a + raw[i] * 2.0 + c) * 0.25 / mouth, 0.12, 1.0)
	# The mouth is the widest point of a bell: never narrower than the waist above.
	b.radius[SAMPLES - 1] = maxf(b.radius[SAMPLES - 1], b.radius[SAMPLES - 2])
	return b


## Widest crossing of the stroke with the horizontal line at `y` (0 if none).
static func _radius_at(stroke: PackedVector2Array, y: float) -> float:
	var best := -1.0
	for i in stroke.size() - 1:
		var a := stroke[i]
		var c := stroke[i + 1]
		if (a.y - y) * (c.y - y) > 0.0:
			continue
		var t := 0.0 if absf(c.y - a.y) < 1e-6 else (y - a.y) / (c.y - a.y)
		best = maxf(best, absf(lerpf(a.x, c.x, t) - 0.5) * 2.0)
	if best >= 0.0:
		return best
	# Between strokes' ends: nearest point.
	var nearest := stroke[0]
	for p in stroke:
		if absf(p.y - y) < absf(nearest.y - y):
			nearest = p
	return absf(nearest.x - 0.5) * 2.0


## Mouth radius and height in metres for a bell cast at `mouth_radius`.
func height(mouth_radius: float) -> float:
	return aspect * mouth_radius


func wall(mouth_radius: float) -> float:
	return WALL * mouth_radius


## Outer outline as Vector2(radius m, height m), mouth (y = 0) up to the crown.
func outline(mouth_radius: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var h := height(mouth_radius)
	for i in range(SAMPLES - 1, -1, -1):
		out.append(Vector2(radius[i] * mouth_radius, h * (1.0 - float(i) / (SAMPLES - 1))))
	return out


## Hollow shell for StationKit.lathe: up the outside, across the crown, down
## the inside, and the lip back to the start.
func lathe_profile(mouth_radius: float) -> PackedVector2Array:
	var t := wall(mouth_radius)
	var outer := outline(mouth_radius)
	var h := height(mouth_radius)
	var prof := PackedVector2Array()
	prof.append_array(outer)
	prof.append(Vector2(0.0, h))
	prof.append(Vector2(0.0, h - t))
	for i in range(outer.size() - 1, -1, -1):
		var p := outer[i]
		prof.append(Vector2(maxf(p.x - t * (0.7 + 0.3 * (1.0 - p.y / h)), 0.01), clampf(p.y, t * 0.5, h - t)))
	prof.append(outer[0])
	return prof


## Metal volume (m^3) of the shell: outline length x wall x circumference.
func volume(mouth_radius: float) -> float:
	var t := wall(mouth_radius)
	var outer := outline(mouth_radius)
	var v := 0.0
	for i in outer.size() - 1:
		var a := outer[i]
		var c := outer[i + 1]
		v += TAU * ((a.x + c.x) * 0.5 - t * 0.5) * a.distance_to(c) * t
	var top := outer[outer.size() - 1]
	v += PI * top.x * top.x * t
	return v


## Litres of melt the bell pit needs for this bell.
func litres(mouth_radius: float) -> float:
	return volume(mouth_radius) * LITRES_PER_M3


func mesh(mouth_radius: float, sides := 32) -> ArrayMesh:
	return StationKit.lathe(lathe_profile(mouth_radius), sides, 35.0)
