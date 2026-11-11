class_name ScrapModels
## Real shapes for the scrap a worker carries: can, key, copper pipe, kettle,
## gold tooth, ring. One merged mesh per kind (cached), sized to fit the
## item's box collider and centred on it.

static var _cache := {}


static func has(kind: StringName) -> bool:
	return kind in [&"scrap_can", &"scrap_key", &"scrap_pipe", &"scrap_kettle", &"scrap_tooth", &"scrap_ring", &"scrap_trophy", &"scrap_candle", &"scrap_coin", &"scrap_bikebell"]


static func mesh(kind: StringName) -> ArrayMesh:
	if not _cache.has(kind):
		_cache[kind] = EnvMesh.merge(_pieces(kind))
	return _cache[kind]


## Worn metal in the scrap's colour.
static func material(color: Color) -> StandardMaterial3D:
	var key := "mat_" + color.to_html()
	if not _cache.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.metallic = 0.85
		mat.roughness = 0.36
		_cache[key] = mat
	return _cache[key]


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
	return out
