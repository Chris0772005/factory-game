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
## "Tree Small 02" from Poly Haven (CC0), thinned for the game (tools/blender/tree.py, see CREDITS.md).
const TREE := "res://assets/models/nature/street_tree.glb"


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
	var wall_mat := wall_material(key, opts)
	var walls := []
	for b: Array in boxes:
		walls.append(EnvMesh.piece(EnvMesh.box(b[1]), Transform3D(Basis(), base + b[0])))
	_crown(set, base, w, d, HEIGHT, walls)
	EnvMesh.add(set, EnvMesh.merge(walls), wall_mat)
	_stonework(set, base, w, [[door_x - DOOR_W * 0.5 - 0.12, door_x + DOOR_W * 0.5 + 0.12]])
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
	# Strip lights under the ceiling (scans), and the light they give.
	for lamp_x: float in [-iw * 0.28, 0.0, iw * 0.28]:
		strip_light(set, base + Vector3(lamp_x, ROOM_H, d * 0.5), opts.get("lamp", Color("#ffdcae")))
	var lamp := OmniLight3D.new()
	lamp.light_color = opts.get("lamp", Color("#ffdcae"))
	lamp.light_energy = 2.4
	lamp.omni_range = maxf(w, d) * 0.9
	lamp.omni_attenuation = 1.1
	lamp.position = base + Vector3(0, ROOM_H - 0.45, d * 0.5)
	set.add_child(lamp)


## The wall of a house, a photo scan (EnvMesh.scan): `scan` names it and `tone` may tint it; without a
## scan, `plaster` gives a rendered wall in that colour and anything else dark red brick.
static func wall_material(key: String, opts: Dictionary) -> ShaderMaterial:
	if opts.has("scan"):
		var params := {foot = 0.45}
		if opts.has("tone"):
			params["tint"] = EnvMesh.toward(opts.scan, opts.tone, 0.8)
		return EnvMesh.scan("town_wall_" + key, opts.scan, params)
	if opts.has("plaster"):
		# A shade under the wanted colour: in full sun a pale render would burn out to white.
		return EnvMesh.scan("town_wall_" + key, "beige_wall_001", {tint = EnvMesh.toward("beige_wall_001", (opts.plaster as Color).darkened(0.3)), foot = 0.5})
	return EnvMesh.scan("town_wall_" + key, "red_brick_03", {foot = 0.45})


## The top of a house `h` high: the walls run on as a parapet (added to `walls`), with a concrete coping
## on it and roofing felt behind.
static func _crown(set: Node3D, base: Vector3, w: float, d: float, h: float, walls: Array) -> void:
	var rise := 0.32
	var coping := []
	for z: float in [WALL * 0.5, d - WALL * 0.5]:
		walls.append(EnvMesh.piece(EnvMesh.box(Vector3(w, rise, WALL)), Transform3D(Basis(), base + Vector3(0, h + rise * 0.5, z))))
		coping.append(EnvMesh.piece(EnvMesh.box(Vector3(w + 0.12, 0.07, WALL + 0.12)), Transform3D(Basis(), base + Vector3(0, h + rise + 0.035, z))))
	for s: float in [-1.0, 1.0]:
		walls.append(EnvMesh.piece(EnvMesh.box(Vector3(WALL, rise, d - WALL * 2.0)), Transform3D(Basis(), base + Vector3(s * (w - WALL) * 0.5, h + rise * 0.5, d * 0.5))))
		coping.append(EnvMesh.piece(EnvMesh.box(Vector3(WALL + 0.12, 0.07, d - WALL * 2.0)), Transform3D(Basis(), base + Vector3(s * (w - WALL) * 0.5, h + rise + 0.035, d * 0.5))))
	EnvMesh.add(set, EnvMesh.merge(coping), stone())
	EnvMesh.add(set, EnvMesh.box(Vector3(w - WALL, 0.1, d - WALL), 0.0), EnvMesh.scan("town_roof", "bitumen", {drift = 0.3}),
		Transform3D(Basis(), base + Vector3(0, h + 0.05, d * 0.5)))


## Cast stone on a front: a plinth along the foot, broken at `gaps` ([x0, x1] from the middle), and a
## string course under the top.
static func _stonework(set: Node3D, base: Vector3, w: float, gaps: Array) -> void:
	var pieces := []
	var x := -w * 0.5
	var runs := gaps.duplicate()
	runs.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	runs.append([w * 0.5, w * 0.5])
	for gap: Array in runs:
		if gap[0] - x > 0.05:
			pieces.append(EnvMesh.piece(EnvMesh.box(Vector3(gap[0] - x, 0.55, 0.06)), Transform3D(Basis(), base + Vector3((x + gap[0]) * 0.5, 0.275, -0.03))))
		x = maxf(x, gap[1])
	pieces.append(EnvMesh.piece(EnvMesh.box(Vector3(w + 0.08, 0.11, 0.07)), Transform3D(Basis(), base + Vector3(0, HEIGHT - 0.42, -0.035))))
	EnvMesh.add(set, EnvMesh.merge(pieces), stone())


## Grey cast stone: plinths, copings, sills and lintels.
static func stone() -> ShaderMaterial:
	return EnvMesh.scan("town_stone", "dirty_concrete", {tile = 1.6, tint = Vector3(0.78, 0.78, 0.78), drift = 0.1})


## A house of the town beyond: storeys of brick or render with rows of windows on every side, a door,
## a plinth, a string course and a flat roof behind a parapet. Seen from the street and over the yard
## walls only: there is no way in and nothing solid. `base` is the middle of the front at ground level.
## opts: key, scan / tone / plaster (see wall_material), storeys (3).
static func block(set: Node3D, base: Vector3, w: float, d: float, opts := {}) -> void:
	if not EnvMesh.visual():
		return
	var key: String = opts.get("key", "block")
	var storeys: int = opts.get("storeys", 3)
	var foot := 0.6
	var floor_h := 3.0
	var h := foot + storeys * floor_h
	var walls := [EnvMesh.piece(EnvMesh.box(Vector3(w, h, d)), Transform3D(Basis(), base + Vector3(0, h * 0.5, d * 0.5)))]
	_crown(set, base, w, d, h, walls)
	EnvMesh.add(set, EnvMesh.merge(walls), wall_material(key, opts))
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color("#18222b")
	glass.roughness = 0.05
	glass.metallic_specular = 0.9
	var drawn := StandardMaterial3D.new()
	drawn.albedo_color = Color("#8d8a80")
	drawn.roughness = 0.9
	var frame := StandardMaterial3D.new()
	frame.albedo_color = Color("#d8d4c9")
	frame.roughness = 0.55
	var door := EnvMesh.wood("town_block_door", {base_color = Color("#3a2d24"), grain_color = Color("#221a14"), weathering = 0.3, roughness_base = 0.6})
	var panes := []
	var curtains := []
	var frames := []
	var stones := []
	var doors := []
	# Each face: its middle at the ground, the way it looks and the way its width runs.
	var faces := [
		[Vector3(0, 0, 0), Vector3.FORWARD, Vector3.LEFT, w],
		[Vector3(0, 0, d), Vector3.BACK, Vector3.RIGHT, w],
		[Vector3(-w * 0.5, 0, d * 0.5), Vector3.LEFT, Vector3.BACK, d],
		[Vector3(w * 0.5, 0, d * 0.5), Vector3.RIGHT, Vector3.FORWARD, d],
	]
	var pick := hash(key)
	for f in faces.size():
		var face: Array = faces[f]
		var out: Vector3 = face[1]
		var along: Vector3 = face[2]
		var width: float = face[3]
		var turn := Basis(along, Vector3.UP, out)
		var origin: Vector3 = base + face[0]
		var bays := maxi(int(width / 2.7), 1)
		var pitch := width / bays
		var front_door := f == 0
		for s in storeys:
			for b in bays:
				var u := (b + 0.5 - bays * 0.5) * pitch
				var sill := foot + s * floor_h + 0.95
				if front_door and s == 0 and b == bays / 2:
					# The house door instead of a window.
					doors.append(EnvMesh.piece(EnvMesh.box(Vector3(1.05, 2.15, 0.06)), Transform3D(turn, origin + along * u + Vector3.UP * (foot * 0.3 + 1.075) + out * 0.01)))
					frames.append(EnvMesh.piece(EnvMesh.box(Vector3(1.25, 0.1, 0.09)), Transform3D(turn, origin + along * u + Vector3.UP * (foot * 0.3 + 2.2) + out * 0.03)))
					for side: float in [-1.0, 1.0]:
						frames.append(EnvMesh.piece(EnvMesh.box(Vector3(0.1, 2.15, 0.09)), Transform3D(turn, origin + along * (u + side * 0.575) + Vector3.UP * (foot * 0.3 + 1.075) + out * 0.03)))
					stones.append(EnvMesh.piece(EnvMesh.box(Vector3(1.6, foot * 0.3, 0.5)), Transform3D(turn, origin + along * u + Vector3.UP * foot * 0.15 + out * 0.25)))
					continue
				var mid := origin + along * u + Vector3.UP * (sill + 0.75)
				pick = (pick * 1103515245 + 12345) & 0x7fffffff
				var target := curtains if pick % 10 < 3 else panes
				target.append(EnvMesh.piece(EnvMesh.box(Vector3(1.1, 1.5, 0.03)), Transform3D(turn, mid + out * 0.005)))
				for side: float in [-1.0, 1.0]:
					frames.append(EnvMesh.piece(EnvMesh.box(Vector3(0.07, 1.5, 0.06)), Transform3D(turn, mid + along * side * 0.585 + out * 0.03)))
					frames.append(EnvMesh.piece(EnvMesh.box(Vector3(1.24, 0.07, 0.06)), Transform3D(turn, mid + Vector3.UP * side * 0.785 + out * 0.03)))
				frames.append(EnvMesh.piece(EnvMesh.box(Vector3(0.05, 1.5, 0.05)), Transform3D(turn, mid + out * 0.03)))
				stones.append(EnvMesh.piece(EnvMesh.box(Vector3(1.4, 0.07, 0.16)), Transform3D(turn, mid - Vector3.UP * 0.855 + out * 0.08)))
				stones.append(EnvMesh.piece(EnvMesh.box(Vector3(1.4, 0.16, 0.05)), Transform3D(turn, mid + Vector3.UP * 0.9 + out * 0.025)))
		# Plinth (on the front it stops either side of the door) and the string course over the ground floor.
		var door_u := (bays / 2 + 0.5 - bays * 0.5) * pitch
		var runs := [[-width * 0.5 - 0.05, door_u - 0.63], [door_u + 0.63, width * 0.5 + 0.05]] if front_door else [[-width * 0.5 - 0.05, width * 0.5 + 0.05]]
		for run: Array in runs:
			if run[1] - run[0] > 0.05:
				stones.append(EnvMesh.piece(EnvMesh.box(Vector3(run[1] - run[0], foot, 0.06)), Transform3D(turn, origin + along * ((run[0] + run[1]) * 0.5) + Vector3.UP * foot * 0.5 + out * 0.03)))
		stones.append(EnvMesh.piece(EnvMesh.box(Vector3(width + 0.12, 0.12, 0.08)), Transform3D(turn, origin + Vector3.UP * (foot + floor_h - 0.1) + out * 0.04)))
	EnvMesh.add(set, EnvMesh.merge(panes), glass, Transform3D(), false)
	if not curtains.is_empty():
		EnvMesh.add(set, EnvMesh.merge(curtains), drawn, Transform3D(), false)
	EnvMesh.add(set, EnvMesh.merge(frames), frame, Transform3D(), false)
	EnvMesh.add(set, EnvMesh.merge(stones), stone())
	if not doors.is_empty():
		EnvMesh.add(set, EnvMesh.merge(doors), door, Transform3D(), false)


## A house that is shut: brick front, roller shutter down, a sign. Solid.
static func closed(set: Node3D, base: Vector3, w: float, d: float, opts := {}) -> void:
	WorldBuilder.add_collider(set, Vector3(w, HEIGHT, d), Transform3D(Basis(), base + Vector3(0, HEIGHT * 0.5, d * 0.5)))
	if not EnvMesh.visual():
		return
	var key: String = opts.get("key", "closed")
	var wall_mat := wall_material(key, opts)
	var walls := []
	walls.append(EnvMesh.piece(EnvMesh.box(Vector3(w, HEIGHT, d)), Transform3D(Basis(), base + Vector3(0, HEIGHT * 0.5, d * 0.5))))
	_crown(set, base, w, d, HEIGHT, walls)
	EnvMesh.add(set, EnvMesh.merge(walls), wall_mat)
	# The roller shutter is down: a scanned one, stretched to the width of the shop front.
	var sw := minf(w - 1.2, 3.4)
	_stonework(set, base, w, [[-sw * 0.5 - 0.2, sw * 0.5 + 0.2]])
	PhotoProp.mount(set, "rollershutter_door:" + ("1" if opts.get("graffiti", false) else "0"), base, Vector3.FORWARD, Vector2(sw, 2.7))
	if opts.has("sign"):
		var board := StandardMaterial3D.new()
		board.albedo_color = opts.get("sign_back", Color("#d8d2c2"))
		board.roughness = 0.7
		var bw := minf(w - 0.6, 0.6 + String(opts.sign).length() * 0.3)
		EnvMesh.add(set, EnvMesh.box(Vector3(bw, 0.62, 0.05), 0.02), board, Transform3D(Basis(), base + Vector3(0, 3.3, -0.03)))
		StationKit.label(set, opts.sign, Transform3D(Basis(Vector3.UP, PI), base + Vector3(0, 3.3, -0.065)), 120,
			opts.get("sign_color", Color("#3a3530")), 800, 0.0036)


## A wheeled refuse container of painted steel (a photographed plate): body, two lids, rim and castors.
## `at` is the middle of its foot, `yaw` in degrees turns its long side. Solid.
static func dumpster(set: Node3D, at: Vector3, yaw := 0.0) -> void:
	var turn := Basis(Vector3.UP, deg_to_rad(yaw))
	WorldBuilder.add_collider(set, Vector3(1.9, 1.25, 1.05), Transform3D(turn, at + Vector3(0, 0.625, 0)))
	if not EnvMesh.visual():
		return
	var steel := EnvMesh.scan("town_dumpster", "green_metal_rust", {drift = 0.12})
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("#1b1c1d")
	dark.roughness = 0.85
	var body := []
	var black := []
	body.append(EnvMesh.piece(EnvMesh.box(Vector3(1.8, 0.95, 0.95), 0.03), Transform3D(turn, at + turn * Vector3(0, 0.64, 0))))
	body.append(EnvMesh.piece(EnvMesh.box(Vector3(1.9, 0.07, 1.05), 0.02), Transform3D(turn, at + turn * Vector3(0, 1.12, 0))))
	for side: float in [-1.0, 1.0]:
		# Lids, one a little open; a rib down each end; a lifting pocket.
		var lift := 0.12 if side > 0.0 else 0.0
		body.append(EnvMesh.piece(EnvMesh.box(Vector3(0.9, 0.035, 1.02), 0.01), Transform3D(turn * Basis(Vector3.RIGHT, -lift), at + turn * Vector3(side * 0.47, 1.18 + lift * 0.45, 0.0))))
		body.append(EnvMesh.piece(EnvMesh.box(Vector3(0.06, 0.8, 1.0), 0.01), Transform3D(turn, at + turn * Vector3(side * 0.93, 0.66, 0))))
		body.append(EnvMesh.piece(EnvMesh.box(Vector3(0.1, 0.12, 0.5), 0.01), Transform3D(turn, at + turn * Vector3(side * 0.97, 0.9, 0))))
		for z: float in [-0.36, 0.36]:
			black.append(EnvMesh.piece(EnvMesh.cylinder(0.08, 0.08, 0.05, 12), Transform3D(turn * Basis(Vector3.BACK, PI * 0.5), at + turn * Vector3(side * 0.74, 0.085, z))))
			body.append(EnvMesh.piece(EnvMesh.box(Vector3(0.07, 0.1, 0.07)), Transform3D(turn, at + turn * Vector3(side * 0.74, 0.15, z))))
	EnvMesh.add(set, EnvMesh.merge(body), steel)
	EnvMesh.add(set, EnvMesh.merge(black), dark)


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


## A fluorescent strip (scan) under the ceiling at `at`, its tubes lit in `colour`.
static func strip_light(set: Node3D, at: Vector3, colour := Color("#f4f6ff")) -> void:
	var node := PhotoProp.hang(set, "mounted_fluorescent_lights:_f", at)
	if node == null:
		return
	var tube := StandardMaterial3D.new()
	tube.albedo_color = Color("#f2f2ee")
	tube.emission_enabled = true
	tube.emission = colour.lerp(Color.WHITE, 0.5)
	tube.emission_energy_multiplier = 3.0
	for part in node.find_children("*", "MeshInstance3D", true, false):
		var mi := part as MeshInstance3D
		if not mi.visible or mi.mesh == null:
			continue
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i)
			if mat and mat.resource_name.to_lower().contains("glass"):
				mi.set_surface_override_material(i, tube)


## Shelves against the back wall. Without `goods`: boxes, tins and odds and ends. With `goods` (names of
## Poly Haven scans, "name@90" turns one by that many degrees): those stand on the boards, in that
## order and again from the start, each where it fits under the board above.
static func shelves(set: Node3D, at: Vector3, width: float, key := "shelf", seed_value := 1, goods := []) -> void:
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
	if not goods.is_empty():
		_stock(set, at, width, goods, rng)
		return
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


## Scanned goods along the four boards of `shelves`: they face the room (-z) and stand at the back of
## their board; what is deeper than the board sticks out in front.
static func _stock(set: Node3D, at: Vector3, width: float, goods: Array, rng: RandomNumberGenerator) -> void:
	var next := 0
	for y: float in [0.37, 0.97, 1.57, 2.17]:
		# Room under the next board; on the top one, under the writing on the wall.
		var room := 0.54 if y < 2.0 else 0.4
		var x := -width * 0.5 + 0.1 + rng.randf_range(0.0, 0.15)
		var passed := 0
		while x < width * 0.5 - 0.25 and passed < goods.size():
			var entry: String = goods[next % goods.size()]
			next += 1
			var turn := float(entry.get_slice("@", 1)) if "@" in entry else 0.0
			var pick := entry.get_slice("@", 0)
			var size := PhotoProp.box(pick).size
			if absf(fmod(turn, 180.0)) > 45.0:
				size = Vector3(size.z, size.y, size.x)
			if size.y > room or x + size.x > width * 0.5 - 0.08:
				passed += 1
				continue
			passed = 0
			var z := 0.17 - size.z * 0.5 - rng.randf_range(0.0, 0.04)
			PhotoProp.stand(set, pick, at + Vector3(x + size.x * 0.5, y, z), 180.0 + turn + rng.randf_range(-7.0, 7.0))
			x += size.x + rng.randf_range(0.07, 0.24)


## A street tree (a scanned tree thinned for the game, tools/blender/tree.py) in a pit of soil framed
## with stone, cut into the paving at `at`. Its trunk stops people. `size` scales it (6.2 m at 1).
static func street_tree(set: Node3D, at: Vector3, yaw := 0.0, size := 1.0) -> void:
	WorldBuilder.add_collider(set, Vector3(0.3, 2.6, 0.3), Transform3D(Basis(), at + Vector3(0, 1.3, 0)))
	if not EnvMesh.visual():
		return
	var packed := load(TREE) as PackedScene
	if packed:
		var tree := packed.instantiate() as Node3D
		tree.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)).scaled(Vector3.ONE * size), at)
		set.add_child(tree)
	var soil := EnvMesh.surface("soil", {base_color = Color("#4a3a30"), roughness_base = 0.95, macro = 0.15, grain = 0.15, contact_dark = 0.0, bump = 1.0})
	EnvMesh.add(set, EnvMesh.box(Vector3(1.3, 0.04, 1.3), 0.0), soil, Transform3D(Basis(), at + Vector3(0, 0.022, 0)), false)
	var frame := []
	for s: float in [-1.0, 1.0]:
		frame.append(EnvMesh.piece(EnvMesh.box(Vector3(1.5, 0.07, 0.1), 0.01), Transform3D(Basis(), at + Vector3(0, 0.035, s * 0.7))))
		frame.append(EnvMesh.piece(EnvMesh.box(Vector3(0.1, 0.07, 1.3), 0.01), Transform3D(Basis(), at + Vector3(s * 0.7, 0.035, 0))))
	EnvMesh.add(set, EnvMesh.merge(frame), stone(), Transform3D(), false)


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
