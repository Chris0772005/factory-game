class_name ScrapModels
## Real shapes for what a worker carries out of the scrap: the finds (can, key, copper pipe,
## kettle, gold tooth, ring ...), the plain junk (sheet, gear, bolts, spring) and the hot goods
## (stolen plates, cash box, old pistol, jewellery, and what the workbench makes of junk). One
## merged mesh per kind (cached), sized to fit the item's box collider and centred on it.

static var _cache := {}


const KINDS: Array[StringName] = [&"scrap_can", &"scrap_key", &"scrap_pipe", &"scrap_kettle", &"scrap_tooth", &"scrap_ring", &"scrap_trophy", &"scrap_candle", &"scrap_coin",
	&"scrap_bikebell", &"junk_sheet", &"junk_gear", &"junk_bolt", &"junk_spring", &"hot_plates", &"hot_cashbox", &"hot_pistol", &"hot_jewels", &"hot_shiv", &"hot_gearknuckle",
	&"hot_baton", &"hot_zipgun"]
## Painted or enamelled things: not bare metal.
const PAINTED: Array[StringName] = [&"hot_plates", &"hot_cashbox"]


static func has(kind: StringName) -> bool:
	return kind in KINDS


static func mesh(kind: StringName) -> ArrayMesh:
	if not _cache.has(kind):
		_cache[kind] = EnvMesh.merge(_pieces(kind))
	return _cache[kind]


## Worn metal in the scrap's colour (for a kind in PAINTED: worn paint). The bumps and the dull and
## bright patches come from a scan of rusty sheet (Poly Haven, CC0), laid on in the piece's own space.
static func material(color: Color, kind := &"") -> StandardMaterial3D:
	var painted := kind in PAINTED
	var key := "mat_" + color.to_html() + ("_paint" if painted else "")
	if not _cache.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.metallic = 0.25 if painted else 0.85
		mat.roughness = 0.75 if painted else 0.6
		var arm := load("res://assets/textures/pbr/metal_arm.jpg") as Texture2D
		mat.roughness_texture = arm
		mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		mat.normal_enabled = true
		mat.normal_texture = load("res://assets/textures/pbr/metal_n.jpg")
		mat.normal_scale = 0.45
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3.ONE * 4.0
		_cache[key] = mat
	return _cache[key]


## A coil of `turns` turns of wire along `axis` (unit X or Y) from `from` to `to`.
static func _coil(axis: Vector3, from: float, to: float, radius: float, wire: float, turns: float, at := Vector3.ZERO) -> Array:
	var path := PackedVector3Array()
	var steps := int(turns * 14.0)
	var u := Vector3.BACK
	var v := axis.cross(u)
	for i in steps + 1:
		var k := float(i) / steps
		var a := k * turns * TAU
		path.append(at + axis * lerpf(from, to, k) + (u * cos(a) + v * sin(a)) * radius)
	return EnvMesh.piece(StationKit.tube(path, wire, 6), Transform3D())


## A gear wheel lying flat at `at`: rim, web, hub with a bore, and `teeth` teeth.
static func _gear(at: Vector3, radius: float, thick: float, teeth: int, bore: float) -> Array:
	var out := []
	var h := thick * 0.5
	var hub := maxf(bore * 1.7, radius * 0.38)
	out.append(EnvMesh.piece(StationKit.lathe(PackedVector2Array([Vector2(bore, -h), Vector2(hub, -h), Vector2(hub + 0.004, -h * 0.5), Vector2(radius * 0.8, -h * 0.5),
		Vector2(radius * 0.84, -h * 0.85), Vector2(radius, -h * 0.85), Vector2(radius, h * 0.85), Vector2(radius * 0.84, h * 0.85), Vector2(radius * 0.8, h * 0.5),
		Vector2(hub + 0.004, h * 0.5), Vector2(hub, h), Vector2(bore, h), Vector2(bore, -h)]), 28, 40.0), Transform3D(Basis(), at)))
	var tooth := EnvMesh.box(Vector3(radius * 0.2, thick * 0.82, radius * 0.24), 0.0015)
	for i in teeth:
		var a := TAU * i / teeth
		out.append(EnvMesh.piece(tooth, Transform3D(Basis(Vector3.UP, a), at + Vector3(sin(a), 0, cos(a)) * radius * 1.07)))
	return out


static func _ring(radius: float, thick: float, at: Vector3, u: Vector3, v: Vector3, steps := 20) -> Array:
	return EnvMesh.piece(StationKit.tube(StationKit.arc_points(at, u, v, radius, 0.0, TAU, steps), thick, 8, false), Transform3D())


static func _pieces(kind: StringName) -> Array:
	var out := []
	match kind:
		&"scrap_can":
			# Dented can: rolled rims, three stiffening beads, a pushed-in lid.
			var p := PackedVector2Array([Vector2(0, -0.108), Vector2(0.058, -0.108), Vector2(0.066, -0.115), Vector2(0.068, -0.105), Vector2(0.063, -0.098)])
			for k in 3:
				var y := -0.05 + k * 0.05
				p.append_array([Vector2(0.063, y - 0.012), Vector2(0.066, y), Vector2(0.063, y + 0.012)])
			p.append_array([Vector2(0.063, 0.098), Vector2(0.068, 0.105), Vector2(0.066, 0.115), Vector2(0.058, 0.108), Vector2(0.03, 0.1), Vector2(0, 0.1)])
			out.append(EnvMesh.piece(StationKit.lathe(p, 20, 50.0, func(v: Vector3, a: float) -> Vector3:
				# One side is squashed.
				return v + Vector3(-sin(a), 0, -cos(a)) * 0.012 * maxf(0.0, cos(a - 0.8)) * (1.0 - absf(v.y) / 0.115)), Transform3D()))
		&"scrap_key":
			out.append(_ring(0.034, 0.009, Vector3(-0.06, 0, 0), Vector3.RIGHT, Vector3.BACK))
			out.append(MachineArt.turned(MachineArt.drum(0.009, 0.125, 0.002), Vector3.RIGHT, Vector3(-0.028, 0, 0), 10))
			out.append(MachineArt.turned(MachineArt.drum(0.013, 0.012, 0.002), Vector3.RIGHT, Vector3(-0.02, 0, 0), 10))
			for k in 2:
				out.append(EnvMesh.piece(EnvMesh.box(Vector3(0.016, 0.008, 0.03 - k * 0.008), 0.002), Transform3D(Basis(), Vector3(0.06 + k * 0.024, 0, 0.022 - k * 0.004))))
		&"scrap_pipe":
			# Hollow tube with a soldered coupling and a flared end.
			out.append(MachineArt.turned(PackedVector2Array([Vector2(0.03, 0), Vector2(0.037, 0), Vector2(0.037, 0.36), Vector2(0.044, 0.365), Vector2(0.044, 0.42), Vector2(0.037, 0.425),
				Vector2(0.037, 0.46), Vector2(0.042, 0.48), Vector2(0.036, 0.48), Vector2(0.03, 0.46), Vector2(0.03, 0)]), Vector3.RIGHT, Vector3(-0.24, 0, 0), 16))
		&"scrap_kettle":
			out.append(EnvMesh.piece(StationKit.lathe(PackedVector2Array([Vector2(0, -0.13), Vector2(0.085, -0.13), Vector2(0.1, -0.12), Vector2(0.118, -0.06), Vector2(0.12, -0.01),
				Vector2(0.105, 0.035), Vector2(0.07, 0.055), Vector2(0.062, 0.062), Vector2(0.055, 0.07), Vector2(0.03, 0.078), Vector2(0.012, 0.08), Vector2(0.014, 0.095),
				Vector2(0.02, 0.102), Vector2(0.012, 0.11), Vector2(0, 0.11)]), 24, 50.0), Transform3D()))
			out.append(EnvMesh.piece(StationKit.tube(MachineArt.smooth(PackedVector3Array([Vector3(0.1, -0.04, 0), Vector3(0.13, -0.01, 0), Vector3(0.14, 0.03, 0), Vector3(0.147, 0.06, 0)]), 0.015),
				0.016, 10, true, PackedFloat32Array([0.024, 0.022, 0.02, 0.018, 0.016, 0.015, 0.014, 0.013, 0.012, 0.012, 0.012, 0.012])), Transform3D()))
			out.append(EnvMesh.piece(StationKit.tube(MachineArt.smooth(PackedVector3Array([Vector3(-0.1, 0.03, 0), Vector3(-0.13, 0.07, 0), Vector3(-0.09, 0.122, 0), Vector3(0, 0.128, 0),
				Vector3(0.05, 0.115, 0), Vector3(0.062, 0.062, 0)]), 0.02), 0.009, 8), Transform3D()))
		&"scrap_tooth":
			out.append(EnvMesh.piece(StationKit.lathe(PackedVector2Array([Vector2(0, -0.002), Vector2(0.02, -0.004), Vector2(0.027, 0.006), Vector2(0.028, 0.02), Vector2(0.022, 0.031),
				Vector2(0.012, 0.033), Vector2(0.006, 0.028), Vector2(0, 0.029)]), 14, 60.0), Transform3D()))
			for s: float in [-1.0, 1.0]:
				out.append(EnvMesh.piece(StationKit.lathe(PackedVector2Array([Vector2(0, -0.033), Vector2(0.004, -0.03), Vector2(0.011, 0.0), Vector2(0, 0.0)]), 10, 60.0),
					Transform3D(Basis(Vector3.BACK, s * 0.18), Vector3(s * 0.011, -0.002, 0))))
		&"scrap_ring":
			out.append(_ring(0.034, 0.0075, Vector3.ZERO, Vector3.RIGHT, Vector3.BACK, 24))
			out.append(EnvMesh.piece(StationKit.lathe(PackedVector2Array([Vector2(0, -0.006), Vector2(0.01, -0.004), Vector2(0.012, 0.004), Vector2(0.006, 0.011), Vector2(0, 0.012)]), 8, 20.0),
				Transform3D(Basis(Vector3.BACK, -PI * 0.5), Vector3(0.036, 0, 0))))
		&"scrap_trophy":
			# Cup on a stem and foot, two ear handles.
			out.append(EnvMesh.piece(StationKit.lathe(PackedVector2Array([Vector2(0, -0.13), Vector2(0.06, -0.13), Vector2(0.062, -0.118), Vector2(0.03, -0.105), Vector2(0.014, -0.08),
				Vector2(0.012, -0.03), Vector2(0.022, -0.02), Vector2(0.05, 0.0), Vector2(0.066, 0.05), Vector2(0.072, 0.125), Vector2(0.076, 0.13), Vector2(0.068, 0.13),
				Vector2(0.06, 0.06), Vector2(0.04, 0.02), Vector2(0, 0.01)]), 22, 50.0), Transform3D()))
			for s: float in [-1.0, 1.0]:
				out.append(EnvMesh.piece(StationKit.tube(MachineArt.smooth(PackedVector3Array([Vector3(s * 0.068, 0.1, 0), Vector3(s * 0.085, 0.085, 0), Vector3(s * 0.08, 0.045, 0), Vector3(s * 0.055, 0.02, 0)]), 0.012),
					0.006, 8), Transform3D()))
		&"scrap_candle":
			out.append(EnvMesh.piece(StationKit.lathe(PackedVector2Array([Vector2(0, -0.12), Vector2(0.06, -0.12), Vector2(0.062, -0.11), Vector2(0.04, -0.095), Vector2(0.016, -0.08),
				Vector2(0.012, -0.04), Vector2(0.022, -0.025), Vector2(0.012, -0.01), Vector2(0.011, 0.05), Vector2(0.02, 0.065), Vector2(0.045, 0.078), Vector2(0.047, 0.085),
				Vector2(0.022, 0.085), Vector2(0.02, 0.12), Vector2(0.012, 0.12), Vector2(0.012, 0.09), Vector2(0, 0.09)]), 20, 50.0), Transform3D()))
		&"scrap_coin":
			out.append(EnvMesh.piece(StationKit.lathe(PackedVector2Array([Vector2(0, -0.005), Vector2(0.03, -0.005), Vector2(0.034, -0.003), Vector2(0.034, 0.003), Vector2(0.03, 0.005),
				Vector2(0.027, 0.003), Vector2(0.012, 0.003), Vector2(0.008, 0.006), Vector2(0, 0.006)]), 24, 30.0), Transform3D()))
		&"scrap_bikebell":
			out.append(EnvMesh.piece(StationKit.lathe(PackedVector2Array([Vector2(0, -0.035), Vector2(0.03, -0.035), Vector2(0.03, -0.022), Vector2(0.046, -0.018), Vector2(0.048, 0.0),
				Vector2(0.04, 0.02), Vector2(0.022, 0.032), Vector2(0.008, 0.034), Vector2(0.008, 0.04), Vector2(0, 0.04)]), 22, 50.0), Transform3D()))
			out.append(EnvMesh.piece(EnvMesh.box(Vector3(0.03, 0.006, 0.014), 0.002), Transform3D(Basis(), Vector3(0.055, -0.014, 0))))
		&"junk_sheet":
			# A sheet bent along its middle, one corner folded over.
			out.append(EnvMesh.piece(EnvMesh.box(Vector3(0.16, 0.004, 0.21), 0.0015), Transform3D(Basis(Vector3.BACK, 0.13), Vector3(-0.07, -0.006, 0))))
			out.append(EnvMesh.piece(EnvMesh.box(Vector3(0.145, 0.004, 0.2), 0.0015), Transform3D(Basis(Vector3.BACK, -0.17), Vector3(0.072, -0.004, 0.004))))
			out.append(EnvMesh.piece(EnvMesh.box(Vector3(0.05, 0.004, 0.06), 0.0015), Transform3D(Basis(Vector3.BACK, -0.17) * Basis(Vector3.RIGHT, 0.5), Vector3(0.118, 0.006, -0.076))))
			for k in 3:
				out.append(MachineArt.turned(MachineArt.drum(0.006, 0.005, 0.001), Vector3.UP, Vector3(-0.12 + k * 0.05, -0.012 + k * 0.0066, 0.085), 8))
		&"junk_gear":
			out.append_array(_gear(Vector3.ZERO, 0.075, 0.05, 14, 0.018))
		&"junk_bolt":
			# A handful of bolts and nuts.
			var head := PackedVector2Array([Vector2(0, 0), Vector2(0.014, 0), Vector2(0.014, 0.011), Vector2(0, 0.011)])
			var nut := PackedVector2Array([Vector2(0.007, 0), Vector2(0.014, 0), Vector2(0.014, 0.011), Vector2(0.007, 0.011), Vector2(0.007, 0)])
			for b: Array in [[Vector3.RIGHT, Vector3(-0.055, -0.026, -0.03), 0.075], [Vector3.BACK, Vector3(0.032, -0.026, -0.055), 0.07], [Vector3.RIGHT, Vector3(-0.03, -0.004, 0.012), 0.06]]:
				var axis: Vector3 = b[0]
				var at: Vector3 = b[1]
				var length: float = b[2]
				out.append(EnvMesh.piece(StationKit.lathe(head, 6, 20.0), Transform3D(Basis(Vector3.BACK, -PI * 0.5) if axis == Vector3.RIGHT else Basis(Vector3.RIGHT, PI * 0.5), at)))
				out.append(MachineArt.turned(MachineArt.drum(0.0068, length, 0.001), axis, at + axis * 0.011, 10))
			for at: Vector3 in [Vector3(0.035, -0.034, 0.032), Vector3(-0.04, -0.034, 0.042), Vector3(0.0, -0.034, -0.012)]:
				out.append(EnvMesh.piece(StationKit.lathe(nut, 6, 20.0), Transform3D(Basis(Vector3.UP, at.x * 9.0), at)))
		&"junk_spring":
			out.append(_coil(Vector3.UP, -0.088, 0.088, 0.046, 0.0075, 6.5))
		&"hot_plates":
			# Two number plates, one askew on the other: rim and raised signs, nothing to read.
			for k in 2:
				var plate := Transform3D(Basis(Vector3.UP, 0.09 * k), Vector3(0.004 * k, -0.007 + k * 0.011, -0.003 * k))
				out.append(EnvMesh.piece(EnvMesh.box(Vector3(0.325, 0.004, 0.108), 0.0015), plate))
				for z: float in [-0.05, 0.05]:
					out.append(EnvMesh.piece(EnvMesh.box(Vector3(0.325, 0.006, 0.006), 0.001), plate * Transform3D(Basis(), Vector3(0, 0.0015, z))))
				for x: float in [-0.159, 0.159]:
					out.append(EnvMesh.piece(EnvMesh.box(Vector3(0.006, 0.006, 0.1), 0.001), plate * Transform3D(Basis(), Vector3(x, 0.0015, 0))))
				for i in 7:
					var wide := 0.026 if i != 3 else 0.008
					out.append(EnvMesh.piece(EnvMesh.box(Vector3(wide, 0.0035, 0.058 if i != 3 else 0.012), 0.001), plate * Transform3D(Basis(), Vector3(-0.12 + i * 0.04, 0.003, 0))))
		&"hot_cashbox":
			# Steel cash box, the lid prised up at the front: handle folded flat, lock plate.
			out.append(EnvMesh.piece(EnvMesh.box(Vector3(0.25, 0.066, 0.168), 0.006), Transform3D(Basis(), Vector3(0, -0.015, 0))))
			var lid := Transform3D(Basis(Vector3.RIGHT, -0.07), Vector3(0, 0.031, 0.0))
			out.append(EnvMesh.piece(EnvMesh.box(Vector3(0.256, 0.02, 0.174), 0.006), lid))
			out.append(EnvMesh.piece(StationKit.tube(StationKit.arc_points(Vector3(0, 0.0125, 0.0), Vector3.RIGHT, Vector3.BACK, 0.032, 0.0, PI, 10), 0.0035, 6), lid))
			for x: float in [-0.032, 0.032]:
				out.append(EnvMesh.piece(EnvMesh.box(Vector3(0.012, 0.006, 0.014), 0.002), lid * Transform3D(Basis(), Vector3(x, 0.011, 0))))
			out.append(EnvMesh.piece(EnvMesh.box(Vector3(0.034, 0.03, 0.005), 0.002), Transform3D(Basis(), Vector3(0, -0.002, 0.0855))))
			out.append(MachineArt.turned(MachineArt.drum(0.006, 0.004, 0.001), Vector3.BACK, Vector3(0, -0.004, 0.0875), 10))
			for x: float in [-0.085, 0.085]:
				out.append(MachineArt.turned(MachineArt.drum(0.005, 0.02, 0.001), Vector3.RIGHT, Vector3(x - 0.01, 0.02, -0.087), 8))
		&"hot_pistol":
			# An old revolver: barrel, drum, frame, grip, trigger guard, hammer and front sight.
			out.append(MachineArt.turned(MachineArt.drum(0.0105, 0.104, 0.002), Vector3.RIGHT, Vector3(-0.008, 0.041, 0), 12))
			out.append(EnvMesh.piece(EnvMesh.box(Vector3(0.1, 0.008, 0.009), 0.002), Transform3D(Basis(), Vector3(0.044, 0.028, 0))))
			out.append(MachineArt.turned(MachineArt.drum(0.019, 0.042, 0.003), Vector3.RIGHT, Vector3(-0.05, 0.03, 0), 6))
			out.append(EnvMesh.piece(EnvMesh.box(Vector3(0.07, 0.016, 0.022), 0.004), Transform3D(Basis(), Vector3(-0.03, 0.054, 0))))
			out.append(EnvMesh.piece(EnvMesh.box(Vector3(0.075, 0.018, 0.022), 0.004), Transform3D(Basis(), Vector3(-0.03, 0.006, 0))))
			out.append(EnvMesh.piece(EnvMesh.box(Vector3(0.016, 0.06, 0.022), 0.004), Transform3D(Basis(), Vector3(-0.062, 0.03, 0))))
			out.append(EnvMesh.piece(MachineArt.loft([[-0.036, 0.03, 0.028, 0.0, 0.0, 2.6], [-0.01, 0.032, 0.03, 0.0, 0.0, 2.6], [0.03, 0.036, 0.03, 0.0, 0.0, 2.4], [0.04, 0.03, 0.024, 0.0, 0.0, 2.2]], 12),
				Transform3D(Basis(Vector3.BACK, -0.32) * Basis(Vector3.RIGHT, PI * 0.5), Vector3(-0.072, -0.024, 0))))
			out.append(EnvMesh.piece(StationKit.tube(StationKit.arc_points(Vector3(-0.022, -0.003, 0), Vector3.RIGHT, Vector3.UP, 0.016, PI, TAU, 8), 0.0028, 6), Transform3D()))
			out.append(EnvMesh.piece(EnvMesh.box(Vector3(0.004, 0.014, 0.005), 0.001), Transform3D(Basis(Vector3.BACK, 0.35), Vector3(-0.026, -0.008, 0))))
			out.append(EnvMesh.piece(EnvMesh.box(Vector3(0.008, 0.02, 0.008), 0.002), Transform3D(Basis(Vector3.BACK, 0.6), Vector3(-0.074, 0.056, 0))))
			out.append(EnvMesh.piece(EnvMesh.box(Vector3(0.006, 0.008, 0.003), 0.001), Transform3D(Basis(), Vector3(0.09, 0.055, 0))))
		&"hot_jewels":
			# A tangle of loot: a string of pearls, two rings, a brooch and a pendant on its chain.
			var loop := PackedVector3Array()
			for i in 33:
				var a := TAU * i / 32.0
				loop.append(Vector3(cos(a) * (0.058 + 0.008 * sin(a * 3.0)), -0.03 + 0.004 * sin(a * 2.0), sin(a) * (0.04 + 0.006 * cos(a * 2.0))))
			out.append(EnvMesh.piece(StationKit.tube(loop, 0.0016, 5, false), Transform3D()))
			var pearl := EnvMesh.sphere(0.0062, 10, 6)
			for i in 26:
				out.append(EnvMesh.piece(pearl, Transform3D(Basis(), loop[int(i * 32.0 / 26.0)])))
			out.append(_ring(0.011, 0.0026, Vector3(0.02, -0.03, 0.012), Vector3.RIGHT, Vector3.BACK, 16))
			out.append(EnvMesh.piece(EnvMesh.sphere(0.0055, 8, 5), Transform3D(Basis(), Vector3(0.032, -0.029, 0.012))))
			out.append(_ring(0.012, 0.0028, Vector3(-0.022, -0.02, -0.008), Vector3(0.9, 0.44, 0), Vector3.BACK, 16))
			out.append(EnvMesh.piece(StationKit.lathe(PackedVector2Array([Vector2(0, -0.004), Vector2(0.017, -0.004), Vector2(0.02, 0.0), Vector2(0.014, 0.004), Vector2(0.006, 0.008), Vector2(0, 0.009)]), 10, 30.0),
				Transform3D(Basis(Vector3.RIGHT, 0.5), Vector3(0.0, -0.022, -0.012))))
			out.append(EnvMesh.piece(StationKit.tube(MachineArt.smooth(PackedVector3Array([Vector3(-0.05, -0.032, 0.03), Vector3(-0.02, -0.03, 0.045), Vector3(0.02, -0.032, 0.036), Vector3(0.05, -0.03, 0.05)]), 0.006),
				0.0012, 4), Transform3D()))
			out.append(EnvMesh.piece(StationKit.lathe(PackedVector2Array([Vector2(0, -0.012), Vector2(0.007, -0.006), Vector2(0.009, 0.0), Vector2(0.006, 0.007), Vector2(0, 0.011)]), 8, 30.0),
				Transform3D(Basis(Vector3.BACK, 1.2), Vector3(0.06, -0.028, 0.05))))
		&"hot_shiv":
			# A strip of sheet ground to a point, the grip wound with tape.
			var along := Basis(Vector3.UP, PI * 0.5)
			out.append(EnvMesh.piece(MachineArt.loft([[-0.02, 0.046, 0.004, 0.0, 0.0, 4.0], [0.07, 0.04, 0.004, 0.003, 0.0, 4.0], [0.125, 0.02, 0.003, 0.008, 0.0, 3.0], [0.148, 0.004, 0.002, 0.014, 0.0, 2.0]], 10),
				Transform3D(along, Vector3.ZERO)))
			out.append(EnvMesh.piece(MachineArt.loft([[-0.148, 0.034, 0.014, 0.0, 0.0, 3.0], [-0.08, 0.037, 0.016, 0.0, 0.0, 3.0], [-0.02, 0.036, 0.015, 0.0, 0.0, 3.0]], 12), Transform3D(along, Vector3.ZERO)))
			for k in 6:
				out.append(EnvMesh.piece(EnvMesh.box(Vector3(0.011, 0.018, 0.04), 0.004), Transform3D(Basis(Vector3.UP, 0.18), Vector3(-0.135 + k * 0.021, 0, 0))))
		&"hot_gearknuckle":
			# Two gears to put the fingers through, bolted to a grip bar.
			for x: float in [-0.038, 0.038]:
				out.append_array(_gear(Vector3(x, 0, 0.014), 0.033, 0.03, 10, 0.0125))
				out.append(EnvMesh.piece(EnvMesh.box(Vector3(0.016, 0.02, 0.03), 0.004), Transform3D(Basis(), Vector3(x, 0, -0.025))))
				out.append(MachineArt.turned(MachineArt.drum(0.006, 0.006, 0.001), Vector3.UP, Vector3(x, 0.012, -0.04), 6))
			out.append(EnvMesh.piece(MachineArt.loft([[-0.074, 0.024, 0.026, 0.0, 0.0, 2.6], [0.0, 0.027, 0.028, 0.0, 0.0, 2.6], [0.074, 0.024, 0.026, 0.0, 0.0, 2.6]], 12),
				Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 0, -0.043))))
		&"hot_baton":
			# A spring on a rod: taped handle, a heavy nut at the tip.
			out.append(MachineArt.turned(MachineArt.drum(0.0165, 0.13, 0.004), Vector3.RIGHT, Vector3(-0.205, 0, 0), 12))
			for k in 5:
				out.append(MachineArt.turned(MachineArt.drum(0.0182, 0.008, 0.002), Vector3.RIGHT, Vector3(-0.192 + k * 0.026, 0, 0), 12))
			out.append(MachineArt.turned(MachineArt.drum(0.0055, 0.24, 0.001), Vector3.RIGHT, Vector3(-0.075, 0, 0), 8))
			out.append(_coil(Vector3.RIGHT, -0.073, 0.163, 0.0135, 0.0042, 15.0))
			out.append(EnvMesh.piece(StationKit.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.021, 0), Vector2(0.022, 0.004), Vector2(0.022, 0.026), Vector2(0.018, 0.032), Vector2(0, 0.032)]), 6, 20.0),
				Transform3D(Basis(Vector3.BACK, -PI * 0.5), Vector3(0.165, 0, 0))))
		&"hot_zipgun":
			# A pipe gun: barrel in a coupling, a block of a grip, a spring behind and a bent trigger.
			out.append(MachineArt.turned(PackedVector2Array([Vector2(0.009, 0), Vector2(0.0135, 0), Vector2(0.0135, 0.2), Vector2(0.009, 0.2), Vector2(0.009, 0)]), Vector3.RIGHT, Vector3(-0.055, 0.034, 0), 12))
			out.append(MachineArt.turned(MachineArt.drum(0.019, 0.044, 0.003), Vector3.RIGHT, Vector3(-0.088, 0.034, 0), 6))
			out.append(MachineArt.turned(MachineArt.drum(0.016, 0.012, 0.002), Vector3.RIGHT, Vector3(0.02, 0.034, 0), 10))
			out.append(EnvMesh.piece(EnvMesh.box(Vector3(0.14, 0.02, 0.03), 0.005), Transform3D(Basis(), Vector3(-0.03, 0.008, 0))))
			out.append(EnvMesh.piece(EnvMesh.box(Vector3(0.042, 0.078, 0.03), 0.008), Transform3D(Basis(Vector3.BACK, -0.26), Vector3(-0.098, -0.02, 0))))
			out.append(_coil(Vector3.RIGHT, -0.146, -0.09, 0.0075, 0.0022, 7.0, Vector3(0, 0.034, 0)))
			out.append(EnvMesh.piece(EnvMesh.box(Vector3(0.005, 0.03, 0.008), 0.001), Transform3D(Basis(Vector3.BACK, 0.3), Vector3(-0.06, -0.012, 0))))
			for x: float in [-0.005, 0.03]:
				out.append(EnvMesh.piece(EnvMesh.box(Vector3(0.008, 0.05, 0.034), 0.003), Transform3D(Basis(), Vector3(x, 0.022, 0))))
	return out
