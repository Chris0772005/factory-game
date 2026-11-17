class_name TownBlock
## Houses of the quarter that can be walked into. `house` builds the shell:
## brick or plaster walls with a door opening (and optional windows) in the
## front, lined inside, a floor, a ceiling with a lamp and a painted sign
## over the door. The front faces -Z (the street); `base` is the middle of
## the front at ground level. Whoever calls it furnishes the room.

const WALL := 0.25
const DOOR_W := 1.5
const DOOR_H := 2.3
const ROOM_H := 3.1
const HEIGHT := 4.3


## opts: key (material key), brick/mortar or plaster (colours), door_x,
## windows = [[x0, x1], ...] (offsets from the middle), sign, sign_color,
## sign_back, floor (colour), lining (colour), lamp (colour).
static func house(set: Node3D, base: Vector3, w: float, d: float, opts := {}) -> void:
	var key: String = opts.get("key", "house")
	var door_x: float = opts.get("door_x", 0.0)
	var openings := [[door_x - DOOR_W * 0.5, door_x + DOOR_W * 0.5, 0.0, DOOR_H]]
	for win: Array in opts.get("windows", []):
		openings.append([win[0], win[1], 0.95, 2.35])
	openings.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	# Front wall around the openings.
	var boxes: Array = []
	var x := -w * 0.5
	for o: Array in openings:
		if o[0] > x:
			boxes.append([Vector3((x + o[0]) * 0.5, HEIGHT * 0.5, WALL * 0.5), Vector3(o[0] - x, HEIGHT, WALL)])
		if o[2] > 0.0:
			boxes.append([Vector3((o[0] + o[1]) * 0.5, o[2] * 0.5, WALL * 0.5), Vector3(o[1] - o[0], o[2], WALL)])
		boxes.append([Vector3((o[0] + o[1]) * 0.5, (o[3] + HEIGHT) * 0.5, WALL * 0.5), Vector3(o[1] - o[0], HEIGHT - o[3], WALL)])
		x = o[1]
	if x < w * 0.5:
		boxes.append([Vector3((x + w * 0.5) * 0.5, HEIGHT * 0.5, WALL * 0.5), Vector3(w * 0.5 - x, HEIGHT, WALL)])
	# Sides and back.
	for s: float in [-1.0, 1.0]:
		boxes.append([Vector3(s * (w - WALL) * 0.5, HEIGHT * 0.5, d * 0.5), Vector3(WALL, HEIGHT, d)])
	boxes.append([Vector3(0, HEIGHT * 0.5, d - WALL * 0.5), Vector3(w, HEIGHT, WALL)])
	for b: Array in boxes:
		WorldBuilder.add_collider(set, b[1], Transform3D(Basis(), base + b[0]))
	# Glass in the windows keeps people out.
	for o: Array in openings:
		if o[2] > 0.0:
			WorldBuilder.add_collider(set, Vector3(o[1] - o[0], o[3] - o[2], 0.06), Transform3D(Basis(), base + Vector3((o[0] + o[1]) * 0.5, (o[2] + o[3]) * 0.5, WALL * 0.5)))
	if not EnvMesh.visual():
		return
	var wall_mat: ShaderMaterial
	if opts.has("plaster"):
		wall_mat = EnvMesh.material("town_wall_" + key, "res://shaders/env_plaster.gdshader", {
			plaster = opts.plaster, grime = Color("#5a554e"), brick = opts.get("brick", Color("#8f4a36")), mortar = Color("#c2b29a"),
			chips = 0.35, streaks = 0.45, brick_below = 0.7})
	else:
		wall_mat = EnvMesh.material("town_wall_" + key, "res://shaders/env_plaster.gdshader", {
			brick = opts.get("brick", Color("#9a5038")), mortar = opts.get("mortar", Color("#c4b49c")), brickwork = 1.0})
	var walls := []
	for b: Array in boxes:
		walls.append(EnvMesh.piece(EnvMesh.box(b[1]), Transform3D(Basis(), base + b[0])))
	# Flat roof with a parapet lip.
	walls.append(EnvMesh.piece(EnvMesh.box(Vector3(w + 0.3, 0.22, d + 0.3)), Transform3D(Basis(), base + Vector3(0, HEIGHT + 0.11, d * 0.5))))
	EnvMesh.add(set, EnvMesh.merge(walls), wall_mat)
	# Inside: lining on the back and side walls, the ceiling, the floor.
	var iw := w - WALL * 2.0
	var id := d - WALL * 2.0
	var lining := EnvMesh.material("town_lining_" + key, "res://shaders/env_plaster.gdshader", {
		plaster = opts.get("lining", Color("#cfc6b4")), grime = Color("#7a7166"), chips = 0.12, streaks = 0.3, brick_below = 0.0})
	var inner := []
	inner.append(EnvMesh.piece(EnvMesh.box(Vector3(iw, ROOM_H, 0.03)), Transform3D(Basis(), base + Vector3(0, ROOM_H * 0.5, d - WALL - 0.015))))
	for s: float in [-1.0, 1.0]:
		inner.append(EnvMesh.piece(EnvMesh.box(Vector3(0.03, ROOM_H, id)), Transform3D(Basis(), base + Vector3(s * (iw * 0.5 - 0.015), ROOM_H * 0.5, d * 0.5))))
	inner.append(EnvMesh.piece(EnvMesh.box(Vector3(iw, 0.08, id)), Transform3D(Basis(), base + Vector3(0, ROOM_H + 0.04, d * 0.5))))
	EnvMesh.add(set, EnvMesh.merge(inner), lining)
	var floor_mat := EnvMesh.wood("town_floor_" + key, {base_color = opts.get("floor", Color("#7a5a3c")), grain_color = Color("#4a3423"),
		weathering = 0.35, roughness_base = 0.6})
	EnvMesh.add(set, EnvMesh.box(Vector3(iw, 0.03, id), 0.0), floor_mat, Transform3D(Basis(), base + Vector3(0, 0.015, d * 0.5)), false)
	# Door frame, the door leaf standing open, window frames and glass.
	var trim := EnvMesh.wood("town_trim_" + key, {base_color = opts.get("trim", Color("#2f3a35")), grain_color = Color("#1c2320"),
		weathering = 0.3, paint = 0.9, paint_color = opts.get("trim", Color("#2f3a35")), roughness_base = 0.6})
	var frames := []
	for s: float in [-1.0, 1.0]:
		frames.append(EnvMesh.piece(EnvMesh.box(Vector3(0.09, DOOR_H, WALL + 0.06)), Transform3D(Basis(), base + Vector3(door_x + s * (DOOR_W * 0.5 - 0.045), DOOR_H * 0.5, WALL * 0.5))))
	frames.append(EnvMesh.piece(EnvMesh.box(Vector3(DOOR_W, 0.1, WALL + 0.06)), Transform3D(Basis(), base + Vector3(door_x, DOOR_H - 0.05, WALL * 0.5))))
	# The leaf stands wide open, flat against the front beside the door.
	frames.append(EnvMesh.piece(EnvMesh.box(Vector3(DOOR_W - 0.25, DOOR_H - 0.15, 0.05)),
		Transform3D(Basis(), base + Vector3(door_x + DOOR_W * 0.5 + (DOOR_W - 0.25) * 0.5 + 0.02, (DOOR_H - 0.15) * 0.5, -0.04))))
	frames.append(EnvMesh.piece(EnvMesh.box(Vector3(0.04, 0.14, 0.09)),
		Transform3D(Basis(), base + Vector3(door_x + DOOR_W * 0.5 + DOOR_W - 0.42, 1.05, -0.09))))
	frames.append(EnvMesh.piece(EnvMesh.box(Vector3(DOOR_W + 0.5, 0.16, 0.5)), Transform3D(Basis(), base + Vector3(door_x, 0.08, -0.2))))
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.62, 0.74, 0.8, 0.28)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.08
	glass.metallic_specular = 0.9
	for o: Array in openings:
		if o[2] <= 0.0:
			continue
		var mid := Vector3((o[0] + o[1]) * 0.5, (o[2] + o[3]) * 0.5, WALL * 0.5)
		var ow: float = o[1] - o[0]
		var oh: float = o[3] - o[2]
		for s: float in [-1.0, 1.0]:
			frames.append(EnvMesh.piece(EnvMesh.box(Vector3(0.07, oh, WALL + 0.04)), Transform3D(Basis(), base + mid + Vector3(s * (ow * 0.5 - 0.035), 0, 0))))
			frames.append(EnvMesh.piece(EnvMesh.box(Vector3(ow, 0.07, WALL + 0.04)), Transform3D(Basis(), base + mid + Vector3(0, s * (oh * 0.5 - 0.035), 0))))
		frames.append(EnvMesh.piece(EnvMesh.box(Vector3(ow + 0.2, 0.06, 0.2)), Transform3D(Basis(), base + mid + Vector3(0, -oh * 0.5 - 0.03, -0.1))))
		EnvMesh.add(set, EnvMesh.box(Vector3(ow, oh, 0.02), 0.0), glass, Transform3D(Basis(), base + mid), false)
	EnvMesh.add(set, EnvMesh.merge(frames), trim)
	# Painted sign board over the door.
	if opts.has("sign"):
		var board := StandardMaterial3D.new()
		board.albedo_color = opts.get("sign_back", Color("#23302b"))
		board.roughness = 0.7
		var sw := minf(w - 0.8, 0.6 + String(opts.sign).length() * 0.36)
		EnvMesh.add(set, EnvMesh.box(Vector3(sw, 0.78, 0.07), 0.02), board, Transform3D(Basis(), base + Vector3(0, DOOR_H + 0.95, -0.035)))
		StationKit.label(set, opts.sign, Transform3D(Basis(Vector3.UP, PI), base + Vector3(0, DOOR_H + 0.95, -0.08)), 150,
			opts.get("sign_color", Color("#f2e6c8")), 800, 0.0038)
	# Ceiling lamp.
	var shade := StandardMaterial3D.new()
	shade.albedo_color = Color("#f4ead2")
	shade.emission_enabled = true
	shade.emission = opts.get("lamp", Color("#ffdcae"))
	shade.emission_energy_multiplier = 2.2
	EnvMesh.add(set, EnvMesh.cylinder(0.2, 0.26, 0.1, 16), shade, Transform3D(Basis(), base + Vector3(0, ROOM_H - 0.06, d * 0.5)), false)
	var lamp := OmniLight3D.new()
	lamp.light_color = opts.get("lamp", Color("#ffdcae"))
	lamp.light_energy = 2.4
	lamp.omni_range = maxf(w, d) * 0.9
	lamp.omni_attenuation = 1.1
	lamp.position = base + Vector3(0, ROOM_H - 0.45, d * 0.5)
	set.add_child(lamp)


## A house that is shut: brick front, roller shutter down, a sign. Solid.
static func closed(set: Node3D, base: Vector3, w: float, d: float, opts := {}) -> void:
	WorldBuilder.add_collider(set, Vector3(w, HEIGHT, d), Transform3D(Basis(), base + Vector3(0, HEIGHT * 0.5, d * 0.5)))
	if not EnvMesh.visual():
		return
	var key: String = opts.get("key", "closed")
	var wall_mat := EnvMesh.material("town_wall_" + key, "res://shaders/env_plaster.gdshader", {
		brick = opts.get("brick", Color("#8c5a44")), mortar = Color("#bfae96"), brickwork = 1.0})
	var walls := []
	walls.append(EnvMesh.piece(EnvMesh.box(Vector3(w, HEIGHT, d)), Transform3D(Basis(), base + Vector3(0, HEIGHT * 0.5, d * 0.5))))
	walls.append(EnvMesh.piece(EnvMesh.box(Vector3(w + 0.3, 0.22, d + 0.3)), Transform3D(Basis(), base + Vector3(0, HEIGHT + 0.11, d * 0.5))))
	EnvMesh.add(set, EnvMesh.merge(walls), wall_mat)
	var shutter := StationKit.metal("town_shutter", {steel_color = Color("#7c8286"), rust = 0.35, metallic_steel = 0.5, roughness_steel = 0.55})
	var sw := minf(w - 1.2, 3.4)
	var slats := []
	for i in 13:
		slats.append(EnvMesh.piece(EnvMesh.box(Vector3(sw, 0.17, 0.05)), Transform3D(Basis(Vector3.RIGHT, -0.18), base + Vector3(0, 0.1 + i * 0.19, -0.02))))
	slats.append(EnvMesh.piece(EnvMesh.box(Vector3(sw + 0.2, 0.2, 0.14)), Transform3D(Basis(), base + Vector3(0, 2.62, -0.05))))
	EnvMesh.add(set, EnvMesh.merge(slats), shutter)
	if opts.has("sign"):
		var board := StandardMaterial3D.new()
		board.albedo_color = opts.get("sign_back", Color("#d8d2c2"))
		board.roughness = 0.7
		var bw := minf(w - 0.6, 0.6 + String(opts.sign).length() * 0.3)
		EnvMesh.add(set, EnvMesh.box(Vector3(bw, 0.62, 0.05), 0.02), board, Transform3D(Basis(), base + Vector3(0, 3.3, -0.03)))
		StationKit.label(set, opts.sign, Transform3D(Basis(Vector3.UP, PI), base + Vector3(0, 3.3, -0.065)), 120,
			opts.get("sign_color", Color("#3a3530")), 800, 0.0036)


## A shop counter across the room: panelled front, worn top. Blocks the way.
static func counter(set: Node3D, at: Vector3, width: float, key := "counter", front := Color("#5b4631")) -> void:
	WorldBuilder.add_collider(set, Vector3(width, 1.0, 0.7), Transform3D(Basis(), at + Vector3(0, 0.5, 0)))
	if not EnvMesh.visual():
		return
	var wood := EnvMesh.wood("town_" + key, {base_color = front, grain_color = front.darkened(0.45), weathering = 0.3, roughness_base = 0.6})
	var top := EnvMesh.wood("town_" + key + "_top", {base_color = front.lightened(0.18), grain_color = front.darkened(0.3), weathering = 0.5, roughness_base = 0.45})
	var body := []
	body.append(EnvMesh.piece(EnvMesh.box(Vector3(width, 0.96, 0.62)), Transform3D(Basis(), at + Vector3(0, 0.48, 0))))
	var panels := maxi(2, roundi(width / 0.9))
	for i in panels:
		var px := lerpf(-width * 0.5 + 0.45, width * 0.5 - 0.45, i / float(panels - 1))
		body.append(EnvMesh.piece(EnvMesh.box(Vector3(0.72, 0.66, 0.03)), Transform3D(Basis(), at + Vector3(px, 0.48, -0.32))))
	EnvMesh.add(set, EnvMesh.merge(body), wood)
	EnvMesh.add(set, EnvMesh.box(Vector3(width + 0.06, 0.06, 0.78), 0.01), top, Transform3D(Basis(), at + Vector3(0, 1.0, 0)))


## Shelves against the back wall with boxes, tins and odds and ends.
static func shelves(set: Node3D, at: Vector3, width: float, key := "shelf", seed_value := 1) -> void:
	WorldBuilder.add_collider(set, Vector3(width, 2.2, 0.4), Transform3D(Basis(), at + Vector3(0, 1.1, 0)))
	if not EnvMesh.visual():
		return
	var wood := EnvMesh.wood("town_" + key, {base_color = Color("#6a4e36"), grain_color = Color("#3b2a1c"), weathering = 0.4, roughness_base = 0.7})
	var rack := []
	for y: float in [0.35, 0.95, 1.55, 2.15]:
		rack.append(EnvMesh.piece(EnvMesh.box(Vector3(width, 0.04, 0.38)), Transform3D(Basis(), at + Vector3(0, y, 0))))
	for s: float in [-1.0, 0.0, 1.0]:
		rack.append(EnvMesh.piece(EnvMesh.box(Vector3(0.05, 2.25, 0.38)), Transform3D(Basis(), at + Vector3(s * (width * 0.5 - 0.025), 1.125, 0))))
	EnvMesh.add(set, EnvMesh.merge(rack), wood)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var tones := [Color("#7d6444"), Color("#5c5a50"), Color("#4c5546"), Color("#5a3d33"), Color("#3f4853"), Color("#8f8162")]
	var by_tone := {}
	for y: float in [0.37, 0.97, 1.57]:
		var x := -width * 0.5 + 0.2
		while x < width * 0.5 - 0.3:
			var size := Vector3(rng.randf_range(0.14, 0.42), rng.randf_range(0.12, 0.4), rng.randf_range(0.14, 0.3))
			var tone := rng.randi() % tones.size()
			if not by_tone.has(tone):
				by_tone[tone] = []
			(by_tone[tone] as Array).append(EnvMesh.piece(EnvMesh.box(size, 0.01), Transform3D(Basis(Vector3.UP, rng.randf_range(-0.15, 0.15)), at + Vector3(x + size.x * 0.5, y + size.y * 0.5 + 0.02, 0))))
			x += size.x + rng.randf_range(0.05, 0.3)
	for tone: int in by_tone:
		var m := StandardMaterial3D.new()
		m.albedo_color = tones[tone]
		m.roughness = 0.9
		m.metallic_specular = 0.2
		EnvMesh.add(set, EnvMesh.merge(by_tone[tone]), m, Transform3D(), false)


## Red-and-white barrier across the street: this far and no further (yet).
static func barrier(set: Node3D, at: Vector3, length: float, text := "") -> void:
	WorldBuilder.add_collider(set, Vector3(0.4, 2.4, length), Transform3D(Basis(), at + Vector3(0, 1.2, 0)))
	if not EnvMesh.visual():
		return
	var red := StandardMaterial3D.new()
	red.albedo_color = Color("#b8362c")
	red.roughness = 0.6
	var white := StandardMaterial3D.new()
	white.albedo_color = Color("#e6e1d4")
	white.roughness = 0.6
	var reds := []
	var whites := []
	var n := int(length / 0.5)
	for y: float in [0.55, 1.05]:
		for i in n:
			var piece := EnvMesh.piece(EnvMesh.box(Vector3(0.05, 0.2, length / n)), Transform3D(Basis(), at + Vector3(0, y, -length * 0.5 + (i + 0.5) * length / n)))
			if i % 2 == 0:
				reds.append(piece)
			else:
				whites.append(piece)
	for i in int(length / 2.5) + 1:
		whites.append(EnvMesh.piece(EnvMesh.box(Vector3(0.09, 1.25, 0.09)), Transform3D(Basis(), at + Vector3(0, 0.625, -length * 0.5 + i * (length / int(length / 2.5))))))
	EnvMesh.add(set, EnvMesh.merge(reds), red)
	EnvMesh.add(set, EnvMesh.merge(whites), white)
	if text != "":
		var side := -1.0 if at.x > 0.0 else 1.0
		StationKit.label(set, text, Transform3D(Basis(Vector3.UP, side * PI * 0.5), at + Vector3(side * 0.04, 1.62, 0)), 110, Color("#f2e6c8"), 800, 0.0034)
