extends Node
## Drawing -> cast model checks: design codes, polygons, relief meshes, shapes.

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_codes()
	_test_garbage_codes()
	_test_budget()
	_test_polygons()
	_test_meshes()
	_test_determinism()
	_test_edge_cases()
	_test_fuzz()
	_test_heavy()
	await _test_pad()
	print("TESTS %s (%d failures)" % ["PASSED" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures else 0)


func _test_codes() -> void:
	var samples := DrawingSamples.all()
	for key in samples:
		var d: Drawing = samples[key]
		var code := d.to_code()
		var back := Drawing.from_code(code)
		_check(back != null, "%s: code decodes (%d chars)" % [key, code.length()])
		if back == null:
			continue
		_check(code.length() < 2048, "%s: code is compact" % key)
		_check(back.strokes == d.strokes and is_equal_approx(back.brush, d.brush), "%s: round trip is exact" % key)
		_check(back.to_code() == code, "%s: re-encoding is stable" % key)
	var empty := Drawing.from_code(Drawing.new().to_code())
	_check(empty != null and empty.is_empty(), "empty drawing round-trips")
	var thick := Drawing.new()
	thick.brush = 0.11
	thick.add_stroke(PackedVector2Array([Vector2(0.1, 0.1), Vector2(0.9, 0.95)]))
	var thick_back := Drawing.from_code(thick.to_code())
	_check(thick_back != null and is_equal_approx(thick_back.brush, 0.11), "brush width survives the code")


func _test_garbage_codes() -> void:
	var code := DrawingSamples.cat().to_code()
	var bad := ["", "abc", "!!!!!!!!", "hello world", "AAAAAAAAAAAA", "////////", code + "A", code.substr(1)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var alphabet := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
	for i in 200:
		var s := ""
		for k in rng.randi_range(4, 120):
			s += alphabet[rng.randi() % alphabet.length()]
		bad.append(s)
	for cut in range(0, code.length(), 3):
		bad.append(code.substr(0, cut))
	var accepted := 0
	for s in bad:
		if Drawing.from_code(s) != null:
			accepted += 1
	_check(accepted == 0, "garbage and truncated codes return null (%d of %d accepted)" % [accepted, bad.size()])
	var flips := 0
	for i in code.length():
		var c := alphabet.find(code[i])
		var mutated := code.substr(0, i) + alphabet[(c + 1 + i % 60) % 64] + code.substr(i + 1)
		if Drawing.from_code(mutated) != null:
			flips += 1
	_check(flips == 0, "every single-character change is rejected (%d slipped through)" % flips)


## Whatever a player draws must produce a code that every peer accepts.
func _test_budget() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var heavy := _scribble(rng, 12, 600, 0.008, 0.6)
	var code := heavy.to_code()
	var back := Drawing.from_code(code)
	_check(heavy.is_full() and heavy.point_count() <= Drawing.MAX_TOTAL_POINTS,
		"heavy scribble stops at the point budget (%d points)" % heavy.point_count())
	_check(back != null and back.strokes == heavy.strokes, "heavy scribble's code decodes (%d chars)" % code.length())
	# Worst case for the code: every delta spans the canvas, so each point costs 4 bytes.
	var worst := Drawing.new()
	for s in Drawing.MAX_STROKES + 6:
		var pts := PackedVector2Array()
		for i in 40:
			var y := rng.randf()
			pts.append(Vector2(float(i % 2), y))
		worst.add_stroke(pts)
	code = worst.to_code()
	back = Drawing.from_code(code)
	_check(worst.strokes.size() <= Drawing.MAX_STROKES and code.length() <= Drawing.MAX_CODE_LENGTH and back != null,
		"worst-case drawing still fits the code limit (%d strokes, %d points, %d chars)" % [
			worst.strokes.size(), worst.point_count(), code.length()])
	var before := worst.strokes.size()
	worst.add_stroke(PackedVector2Array([Vector2(0.5, 0.5)]))
	_check(worst.is_full() and worst.strokes.size() == before, "a full drawing ignores further strokes")
	# A hand-made code over the budget is refused even though it is short.
	var forged := Drawing.new()
	for s in 4:
		var pts := PackedVector2Array()
		for i in Drawing.MAX_POINTS:
			pts.append(Vector2(0.1 + i / Drawing.QUANT, 0.1 + s * 0.2))
		forged.strokes.append(pts)
	code = forged.to_code()
	_check(code.length() < Drawing.MAX_CODE_LENGTH and Drawing.from_code(code) == null,
		"codes over the point budget are rejected (%d chars)" % code.length())
	var nan := Drawing.new()
	nan.add_stroke(PackedVector2Array([Vector2(NAN, 0.5), Vector2(0.5, 0.5), Vector2(INF, 0.2)]))
	nan.add_stroke(PackedVector2Array([Vector2(NAN, NAN)]))
	back = Drawing.from_code(nan.to_code())
	_check(nan.strokes.size() == 1 and nan.strokes[0].size() == 1 and back != null and back.strokes == nan.strokes,
		"non-finite input points are dropped")


func _test_polygons() -> void:
	var expect := {letter_o = [1, 1], letter_b = [1, 2], smiley = [4, 1], spiral = [1, 0], star = [2, 1]}
	var samples := DrawingSamples.all()
	for key in samples:
		var polys: Array = samples[key].polygons()
		var holes := 0
		var oriented := true
		var verts := 0
		for p in polys:
			holes += p.holes.size()
			verts += p.outer.size()
			oriented = oriented and not Geometry2D.is_polygon_clockwise(p.outer)
			for h in p.holes:
				verts += h.size()
				oriented = oriented and Geometry2D.is_polygon_clockwise(h)
		print("  %s: %d shapes, %d holes, %d vertices" % [key, polys.size(), holes, verts])
		_check(not polys.is_empty() and oriented, "%s: outlines exist with outer/hole orientation" % key)
		if expect.has(key):
			_check(polys.size() == expect[key][0] and holes == expect[key][1],
				"%s: %d shapes with %d holes" % [key, expect[key][0], expect[key][1]])
	var dot := Drawing.new()
	dot.add_stroke(PackedVector2Array([Vector2(0.5, 0.5)]))
	var dot_polys := dot.polygons()
	var r := dot.brush * 0.5
	var dot_area := DrawingGeometry.shape_area(dot_polys[0]) if dot_polys.size() == 1 else 0.0
	_check(absf(dot_area / (PI * r * r) - 1.0) < 0.05, "a single click gives a round dot (area ratio %.3f)" % (dot_area / (PI * r * r)))


func _test_meshes() -> void:
	var samples := DrawingSamples.all()
	var total_ms := 0.0
	var runs := 0
	for key in samples:
		var d: Drawing = samples[key]
		var t0 := Time.get_ticks_usec()
		var res := CastMeshBuilder.build(d, 0.6, 0.08)
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		for i in 4:
			t0 = Time.get_ticks_usec()
			CastMeshBuilder.build(d, 0.6, 0.08)
			ms = minf(ms, (Time.get_ticks_usec() - t0) / 1000.0)
		total_ms += ms
		runs += 1
		var mesh: ArrayMesh = res.mesh
		var aabb: AABB = res.aabb
		print("  %s: %.1f ms, %d tris, %d shapes, area %.4f m², volume %.6f m³, aabb %s" % [
			key, ms, _tri_count(mesh), res.shapes.size(), res.area, res.volume, aabb.size])
		_check(mesh.get_surface_count() == 1 and _tri_count(mesh) > 20, "%s: mesh has triangles" % key)
		if mesh.get_surface_count() == 0:
			continue
		var longest := maxf(aabb.size.x, aabb.size.z)
		_check(absf(longest - 0.6) < 0.01 and absf(aabb.size.y - 0.08) < 1e-4, "%s: AABB fits size and thickness" % key)
		_check(aabb.get_center().length() < 0.01, "%s: centered at origin" % key)
		_check(_open_edges(mesh) == 0, "%s: mesh is watertight" % key)
		_check(_misoriented(mesh) == 0, "%s: faces wind outward" % key)
		var signed := _signed_volume(mesh)
		_check(absf(signed - res.volume) < res.volume * 0.03, "%s: volume %.6f matches mesh %.6f" % [key, res.volume, signed])
		_check(res.area > 0.0 and res.volume < res.area * 0.08 + 1e-9, "%s: area and volume are sane" % key)
		var shapes: Array = res.shapes
		var convex := shapes.all(func(s): return s is ConvexPolygonShape3D and s.points.size() >= 6)
		_check(not shapes.is_empty() and shapes.size() <= CastMeshBuilder.MAX_SHAPES and convex,
			"%s: %d convex collision shapes" % [key, shapes.size()])
	var avg := total_ms / runs
	print("  average build time %.1f ms" % avg)
	_check(avg < 30.0, "build stays under 30 ms on average (%.1f ms)" % avg)
	var empty := CastMeshBuilder.build(Drawing.new())
	_check(empty.mesh.get_surface_count() == 0 and empty.shapes.is_empty(), "empty drawing builds an empty result")


## Peers only exchange design codes, so a decoded code must rebuild the exact
## same mesh, collision and metal volume as the original drawing.
func _test_determinism() -> void:
	var samples := DrawingSamples.all()
	var same := 0
	for key in samples:
		var d: Drawing = samples[key]
		var a := CastMeshBuilder.build(d)
		var b := CastMeshBuilder.build(Drawing.from_code(d.to_code()))
		var c := CastMeshBuilder.build(d)
		if _same_build(a, b) and _same_build(a, c):
			same += 1
		else:
			print("  differs: ", key)
	_check(same == samples.size(), "decoded codes rebuild bit-identical casts (%d of %d)" % [same, samples.size()])


func _same_build(a: Dictionary, b: Dictionary) -> bool:
	if a.area != b.area or a.volume != b.volume or a.aabb != b.aabb or a.shapes.size() != b.shapes.size():
		return false
	var arr_a: Array = a.mesh.surface_get_arrays(0)
	var arr_b: Array = b.mesh.surface_get_arrays(0)
	for k in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_INDEX]:
		if arr_a[k] != arr_b[k]:
			return false
	for i in a.shapes.size():
		if a.shapes[i].points != b.shapes[i].points:
			return false
	return true


func _test_edge_cases() -> void:
	var cases := {}
	for b in [0.001, 0.255]:
		var o := DrawingSamples.letter_o()
		o.brush = b
		cases["letter_o with brush %.3f" % b] = o
	var twin := Drawing.new()
	twin.add_stroke(PackedVector2Array([Vector2(0.4, 0.4), Vector2(0.4, 0.4)]))
	cases["two identical points"] = twin
	var outside := Drawing.new()
	outside.add_stroke(PackedVector2Array([Vector2(-5, -5), Vector2(5, -5), Vector2(5, 5)]))
	cases["stroke clamped to the border"] = outside
	var filled := Drawing.new()
	filled.brush = 0.2
	for i in 8:
		filled.add_stroke(PackedVector2Array([Vector2(0, i / 7.0), Vector2(1, i / 7.0)]))
	cases["whole page inked"] = filled
	for key in cases:
		var res := CastMeshBuilder.build(cases[key])
		var ok: bool = res.mesh.get_surface_count() == 1 and not res.shapes.is_empty()
		ok = ok and _open_edges(res.mesh) == 0 and _misoriented(res.mesh) == 0
		_check(ok and absf(maxf(res.aabb.size.x, res.aabb.size.z) - 0.6) < 0.01, "%s: closed mesh at full size" % key)
	var dot := CastMeshBuilder.build(twin)
	_check(absf(dot.aabb.size.x - dot.aabb.size.z) < 0.01, "a dot casts as a round disc")


## Pathological but legal input (a full page of wild scribbles) must not freeze the game.
func _test_heavy() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var d := _scribble(rng, Drawing.MAX_STROKES, 100, 0.008, 0.6)
	var t0 := Time.get_ticks_usec()
	var res := CastMeshBuilder.build(d)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	_check(res.mesh.get_surface_count() == 1 and _open_edges(res.mesh) == 0 and ms < 200.0,
		"full page of scribbles builds a closed mesh in %.0f ms (%d points)" % [ms, d.point_count()])


func _scribble(rng: RandomNumberGenerator, strokes: int, length: int, step: float, wiggle: float) -> Drawing:
	var d := Drawing.new()
	for s in strokes:
		var pts := PackedVector2Array()
		var p := Vector2(rng.randf(), rng.randf())
		var heading := rng.randf() * TAU
		for i in length:
			heading += rng.randf_range(-wiggle, wiggle)
			p += Vector2.from_angle(heading) * step
			if p.x < 0.0 or p.x > 1.0:
				heading = PI - heading
			if p.y < 0.0 or p.y > 1.0:
				heading = -heading
			p = p.clamp(Vector2.ZERO, Vector2.ONE)
			pts.append(p)
		d.add_stroke(pts)
	return d


## Random scribbles must always triangulate (holes included) and stay closed.
func _test_fuzz() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var dropped := 0
	var leaky := 0
	var worst_ms := 0.0
	for n in 40:
		var d := Drawing.new()
		d.brush = rng.randf_range(0.03, 0.09)
		for s in rng.randi_range(1, 9):
			var pts := PackedVector2Array()
			var p := Vector2(rng.randf(), rng.randf())
			var heading := rng.randf() * TAU
			for i in rng.randi_range(1, 70):
				heading += rng.randf_range(-0.5, 0.5)
				p += Vector2.from_angle(heading) * 0.015
				pts.append(p)
			d.add_stroke(pts)
		for shape in d.polygons():
			var rings := [shape.outer]
			rings.append_array(shape.holes)
			if DrawingGeometry.triangulate(rings).is_empty():
				dropped += 1
		var t0 := Time.get_ticks_usec()
		var res := CastMeshBuilder.build(d)
		worst_ms = maxf(worst_ms, (Time.get_ticks_usec() - t0) / 1000.0)
		if res.mesh.get_surface_count() == 0 or _open_edges(res.mesh) > 0 or _misoriented(res.mesh) > 0:
			leaky += 1
	print("  fuzz: worst build %.1f ms" % worst_ms)
	_check(dropped == 0, "random scribbles triangulate with holes (%d failures)" % dropped)
	_check(leaky == 0, "random scribbles give closed, outward meshes (%d bad)" % leaky)


## Drives the DrawPad through real input events: draw, undo, finish, cancel, timeout.
func _test_pad() -> void:
	var orphans_before := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var layer := CanvasLayer.new()
	add_child(layer)
	var pad := DrawPad.new()
	pad.time_limit = 0.0
	layer.add_child(pad)
	var results := []
	pad.finished.connect(func(d: Drawing): results.append(d))
	pad.cancelled.connect(func(): results.append(&"cancelled"))
	pad.open("Zeichne: einen Test")
	await _frames(3)
	var canvas: Control = pad._canvas
	_check(pad.visible and canvas.size.x > 200.0 and is_equal_approx(canvas.size.x, canvas.size.y),
		"pad opens with a square canvas (%s)" % canvas.size)
	var rect := canvas.get_global_rect()
	_mouse_stroke(rect, [Vector2(0.2, 0.2), Vector2(0.5, 0.35), Vector2(0.8, 0.2)])
	await _frames(2)
	_check(pad.drawing.strokes.size() == 1 and pad.drawing.strokes[0].size() >= 2, "mouse drag draws a stroke")
	_mouse_stroke(rect, [Vector2(0.5, 0.7)])
	await _frames(2)
	_check(pad.drawing.strokes.size() == 2 and pad.drawing.strokes[1].size() == 1, "a click draws a dot")
	_key(KEY_Z, true, KEY_Y)
	await _frames(2)
	_check(pad.drawing.strokes.size() == 1, "Ctrl+Z undoes the last stroke (by key label, QWERTZ too)")
	_check(pad._preview_mesh.mesh.get_surface_count() == 1, "live preview shows the cast")
	_joy_button(JOY_BUTTON_A, true)
	_joy_axis(JOY_AXIS_LEFT_X, 1.0)
	await _frames(20)
	_joy_axis(JOY_AXIS_LEFT_X, 0.0)
	_joy_button(JOY_BUTTON_A, false)
	await _frames(2)
	_check(pad.drawing.strokes.size() == 2 and pad.drawing.strokes[1].size() >= 2, "gamepad: stick + A draws a stroke")
	_key(KEY_ENTER)
	await _frames(2)
	_check(results.size() == 1 and results[0] is Drawing and not pad.visible, "Enter finishes with the drawing")
	pad.open("Nochmal")
	await _frames(2)
	_key(KEY_ESCAPE)
	await _frames(2)
	_check(results.size() == 2 and results[1] == &"cancelled", "Esc cancels")
	pad.time_limit = 0.3
	pad.open("Schnell!")
	pad.add_stroke(PackedVector2Array([Vector2(0.3, 0.3), Vector2(0.7, 0.7)]))
	await get_tree().create_timer(0.6).timeout
	_check(results.size() == 3 and results[2] is Drawing, "countdown auto-finishes at zero")
	pad.open("Leer")
	await get_tree().create_timer(0.6).timeout
	_check(results.size() == 4 and results[3] == &"cancelled", "countdown on an empty page cancels")
	pad.time_limit = 0.0
	pad.open("Weiter")
	await _frames(2)
	# A press without a release (focus lost mid-stroke) must not lose the stroke.
	_mouse_press(rect, Vector2(0.2, 0.2), true)
	_mouse_press(rect, Vector2(0.6, 0.6), true)
	_mouse_press(rect, Vector2(0.6, 0.6), false)
	await _frames(2)
	_check(pad.drawing.strokes.size() == 2, "a new press keeps the unfinished stroke")
	var mat := StandardMaterial3D.new()
	pad.preview_material = mat
	_check(pad._preview_mesh.material_override == mat, "preview_material can be set while the pad is open")
	var full := Drawing.new()
	for s in Drawing.MAX_STROKES:
		full.add_stroke(PackedVector2Array([Vector2(s / 64.0, 0.2), Vector2(s / 64.0, 0.8)]))
	pad.drawing = full
	pad.add_stroke(PackedVector2Array([Vector2(0.5, 0.5)]))
	await _frames(2)
	_mouse_press(rect, Vector2(0.5, 0.5), true)
	_check(pad._hint_label.text == DrawPad.HINT_FULL and pad._stroke.is_empty(), "a full page tells the player and takes no ink")
	_mouse_press(rect, Vector2(0.5, 0.5), false)
	layer.queue_free()
	await _frames(2)
	var orphans := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT) - orphans_before
	_check(not is_instance_valid(pad) and orphans == 0, "pad frees cleanly while open (%d orphan nodes)" % orphans)


func _mouse_stroke(rect: Rect2, points: Array) -> void:
	var at := func(p: Vector2) -> Vector2: return rect.position + rect.size * (Vector2(0.06, 0.06) + p * 0.88)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = at.call(points[0])
	get_viewport().push_input(press, true)
	for p in points.slice(1):
		for k in 6:
			var move := InputEventMouseMotion.new()
			move.button_mask = MOUSE_BUTTON_MASK_LEFT
			move.position = at.call(points[0].lerp(p, (k + 1) / 6.0))
			get_viewport().push_input(move, true)
		points[0] = p
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = at.call(points[0])
	get_viewport().push_input(release, true)


func _mouse_press(rect: Rect2, p: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = rect.position + rect.size * (Vector2(0.06, 0.06) + p * 0.88)
	get_viewport().push_input(ev, true)


## `physical` differs from `code` on other layouts (QWERTZ: label Z sits where US has Y).
func _key(code: Key, ctrl := false, physical := KEY_NONE) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = physical if physical != KEY_NONE else code
	ev.keycode = code
	ev.ctrl_pressed = ctrl
	ev.pressed = true
	get_viewport().push_input(ev)


func _joy_button(button: JoyButton, pressed: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _joy_axis(axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	Input.parse_input_event(ev)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _tri_count(mesh: ArrayMesh) -> int:
	if mesh.get_surface_count() == 0:
		return 0
	return mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() / 3


## Edges (after welding equal positions) not shared by exactly two triangles.
func _open_edges(mesh: ArrayMesh) -> int:
	var arr := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var weld := {}
	var ids := PackedInt32Array()
	for v in verts:
		var key := Vector3i((v * 100000.0).round())
		if not weld.has(key):
			weld[key] = weld.size()
		ids.append(weld[key])
	var edges := {}
	for t in range(0, idx.size(), 3):
		for k in 3:
			var a := ids[idx[t + k]]
			var b := ids[idx[t + (k + 1) % 3]]
			if a == b:
				continue
			var e := Vector2i(mini(a, b), maxi(a, b))
			edges[e] = edges.get(e, 0) + (1 if a < b else -1) * 1000 + 1
	var bad := 0
	for e in edges:
		if edges[e] != 2:
			bad += 1
	return bad


## Triangles whose clockwise (Godot front face) winding disagrees with the normals.
func _misoriented(mesh: ArrayMesh) -> int:
	var arr := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var bad := 0
	for t in range(0, idx.size(), 3):
		var a := verts[idx[t]]
		var cross := (verts[idx[t + 1]] - a).cross(verts[idx[t + 2]] - a)
		var n := normals[idx[t]] + normals[idx[t + 1]] + normals[idx[t + 2]]
		if cross.length_squared() > 1e-14 and cross.dot(n) > 0.0:
			bad += 1
	return bad


func _signed_volume(mesh: ArrayMesh) -> float:
	var arr := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var vol := 0.0
	for t in range(0, idx.size(), 3):
		vol -= verts[idx[t]].dot(verts[idx[t + 1]].cross(verts[idx[t + 2]])) / 6.0
	return vol


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		_failures += 1
