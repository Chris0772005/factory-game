class_name Drawing
extends RefCounted
## A player's drawing: brush strokes in normalized [0,1]² canvas space (y down).
## Points are stored on the 12-bit grid of the design code, so a drawing and its
## decoded code are identical and every peer builds the same mesh from it.

const CODE_VERSION := 1
const MAX_STROKES := 64
## Per stroke and per drawing. A full drawing's code stays below
## MAX_CODE_LENGTH (at most 4 bytes per point), so every code decodes on every peer.
const MAX_POINTS := 400
const MAX_TOTAL_POINTS := 1500
const MAX_CODE_LENGTH := 8192
const QUANT := 4095.0
## Input points closer than this to the previous one are dropped.
const MIN_SPACING := 0.003
const SIMPLIFY_TOLERANCE := 0.0012
const _B64 := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"

static var _b64_lookup := PackedInt32Array()

var strokes: Array[PackedVector2Array] = []
## Stroke width relative to the canvas, snapped to the code's 1/1000 steps.
var brush := 0.06:
	set(value):
		brush = clampf(snappedf(value, 0.001), 0.001, 0.255)


## Adds a stroke after clamping, thinning and simplifying its points. Strokes
## are thinned further to fit the point budget and dropped once it is used up
## (see is_full()).
func add_stroke(points: PackedVector2Array) -> void:
	if is_full():
		return
	var clean := PackedVector2Array()
	var last := Vector2(-1, -1)
	for p in points:
		if not p.is_finite():
			continue
		last = p.clamp(Vector2.ZERO, Vector2.ONE)
		if clean.is_empty() or last.distance_to(clean[-1]) >= MIN_SPACING:
			clean.append(last)
	if clean.is_empty():
		return
	if clean.size() > 1 and clean[-1] != last:
		clean[-1] = last
	clean = DrawingGeometry.simplify_open(clean, SIMPLIFY_TOLERANCE)
	var room := mini(MAX_POINTS, MAX_TOTAL_POINTS - point_count())
	if clean.size() > room and room < 2:
		return
	while clean.size() > room:
		clean = _every_other(clean)
	strokes.append(_quantized(clean))


func is_empty() -> bool:
	return strokes.is_empty()


## True when no further stroke fits (stroke count or point budget used up).
func is_full() -> bool:
	return strokes.size() >= MAX_STROKES or point_count() >= MAX_TOTAL_POINTS


func point_count() -> int:
	var total := 0
	for s in strokes:
		total += s.size()
	return total


## Removes the most recent stroke (undo).
func remove_last_stroke() -> void:
	if not strokes.is_empty():
		strokes.pop_back()


func clear() -> void:
	strokes.clear()


## Compact URL-safe design code: version, brush, strokes as 12-bit start
## points plus zigzag-varint deltas, Fletcher-16 checksum, base64url.
func to_code() -> String:
	var bytes := PackedByteArray([CODE_VERSION, clampi(roundi(brush * 1000.0), 1, 255)])
	_put_varint(bytes, strokes.size())
	for s in strokes:
		_put_varint(bytes, s.size())
		var prev := Vector2i.ZERO
		for i in s.size():
			var q := Vector2i(roundi(s[i].x * QUANT), roundi(s[i].y * QUANT))
			if i == 0:
				bytes.append(q.x >> 4)
				bytes.append(((q.x & 15) << 4) | (q.y >> 8))
				bytes.append(q.y & 255)
			else:
				_put_varint(bytes, _zigzag(q.x - prev.x))
				_put_varint(bytes, _zigzag(q.y - prev.y))
			prev = q
	var sum := _checksum(bytes)
	bytes.append(sum >> 8)
	bytes.append(sum & 255)
	return _b64_encode(bytes)


## Parses a design code; returns null for anything malformed.
static func from_code(code: String) -> Drawing:
	code = code.strip_edges()
	if code.length() < 6 or code.length() > MAX_CODE_LENGTH:
		return null
	var bytes := _b64_decode(code)
	if bytes.size() < 5:
		return null
	var n := bytes.size() - 2
	if _checksum(bytes.slice(0, n)) != (bytes[n] << 8 | bytes[n + 1]):
		return null
	if bytes[0] != CODE_VERSION or bytes[1] == 0:
		return null
	var r := _Reader.new(bytes.slice(0, n), 2)
	var d := Drawing.new()
	d.brush = bytes[1] / 1000.0
	var count := r.varint()
	if count > MAX_STROKES:
		return null
	var budget := MAX_TOTAL_POINTS
	for k in count:
		var size := r.varint()
		budget -= size
		if size < 1 or size > MAX_POINTS or budget < 0 or r.failed:
			return null
		var b0 := r.byte()
		var b1 := r.byte()
		var b2 := r.byte()
		var q := Vector2i((b0 << 4) | (b1 >> 4), ((b1 & 15) << 8) | b2)
		var pts := PackedVector2Array([Vector2(q) / QUANT])
		for i in size - 1:
			q += Vector2i(_unzigzag(r.varint()), _unzigzag(r.varint()))
			if q.x < 0 or q.y < 0 or q.x > QUANT or q.y > QUANT:
				return null
			pts.append(Vector2(q) / QUANT)
		if r.failed:
			return null
		d.strokes.append(pts)
	if r.failed or not r.at_end():
		return null
	return d


## Clean outline: [{outer: PackedVector2Array, holes: Array[PackedVector2Array]}]
## in [0,1]² canvas space; ink at the border reaches past it by half a brush.
## Outers are counter-clockwise (positive area), holes clockwise. Costs 2–40 ms
## depending on the amount of ink, so cache the result instead of calling it per frame.
func polygons() -> Array:
	return DrawingGeometry.outline(strokes, brush * 0.5)


static func _quantized(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		var q := (p * QUANT).round() / QUANT
		if out.is_empty() or out[-1] != q:
			out.append(q)
	return out


static func _every_other(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(0, points.size() - 1, 2):
		out.append(points[i])
	out.append(points[-1])
	return out


static func _zigzag(v: int) -> int:
	return (v << 1) if v >= 0 else ((-v << 1) - 1)


static func _unzigzag(v: int) -> int:
	return (v >> 1) if v & 1 == 0 else -((v + 1) >> 1)


static func _put_varint(bytes: PackedByteArray, v: int) -> void:
	while v >= 128:
		bytes.append((v & 127) | 128)
		v >>= 7
	bytes.append(v)


static func _checksum(bytes: PackedByteArray) -> int:
	var a := 0
	var b := 0
	for v in bytes:
		a = (a + v) % 255
		b = (b + a) % 255
	return (b << 8) | a


static func _b64_encode(bytes: PackedByteArray) -> String:
	var out := PackedStringArray()
	var i := 0
	while i < bytes.size():
		var chunk := bytes.slice(i, i + 3)
		var v := chunk[0] << 16
		if chunk.size() > 1:
			v |= chunk[1] << 8
		if chunk.size() > 2:
			v |= chunk[2]
		for k in chunk.size() + 1:
			out.append(_B64[(v >> (18 - 6 * k)) & 63])
		i += 3
	return "".join(out)


static func _b64_decode(code: String) -> PackedByteArray:
	if _b64_lookup.is_empty():
		_b64_lookup.resize(128)
		_b64_lookup.fill(-1)
		for k in _B64.length():
			_b64_lookup[_B64.unicode_at(k)] = k
	var out := PackedByteArray()
	if code.length() % 4 == 1:
		return out
	var v := 0
	var bits := 0
	for k in code.length():
		var c := code.unicode_at(k)
		var six := _b64_lookup[c] if c < 128 else -1
		if six < 0:
			return PackedByteArray()
		v = ((v << 6) | six) & 0xFFFFFF
		bits += 6
		if bits >= 8:
			bits -= 8
			out.append((v >> bits) & 255)
	if v & ((1 << bits) - 1) != 0:
		return PackedByteArray()
	return out


## Bounds-checked byte cursor; sets `failed` instead of reading past the end.
class _Reader:
	var bytes: PackedByteArray
	var pos := 0
	var failed := false

	func _init(data: PackedByteArray, start: int) -> void:
		bytes = data
		pos = start

	func byte() -> int:
		if pos >= bytes.size():
			failed = true
			return 0
		pos += 1
		return bytes[pos - 1]

	func varint() -> int:
		var v := 0
		for shift in [0, 7, 14]:
			var b := byte()
			v |= (b & 127) << shift
			if b < 128:
				return v
		failed = true
		return 0

	func at_end() -> bool:
		return pos == bytes.size()
