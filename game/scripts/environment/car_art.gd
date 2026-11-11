class_name CarArt
## The family station wagon in the garage, modelled from smooth lofts: body,
## glass house, roof with rack, wheels in arches, bumpers, lamps, plates.
## Visual only (the set keeps the collider). Nose points along local +Z.


static func station_wagon(parent: Node3D, xform: Transform3D, length: float, width: float, paint_color: Color) -> Node3D:
	var car := Node3D.new()
	car.transform = xform
	parent.add_child(car)
	var l := length * 0.5
	var w := width
	var paint := StationKit.metal("car_paint", {steel_color = Color("#6a6d70"), paint = 0.96, paint_color = paint_color, rust = 0.1, dents = 0.08,
		metallic_steel = 0.5, roughness_steel = 0.4, roughness_paint = 0.28})
	var dark := MachineArt.black_mat()
	var chrome := MachineArt.steel_mat()
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color("#1c2630")
	glass.metallic = 0.6
	glass.roughness = 0.12
	# Body: nose, long flank, upright tail.
	var body := [EnvMesh.piece(MachineArt.loft([
		[-l, w * 0.84, 0.4, 0.0, 0.63, 4.0], [-l + 0.1, w * 0.96, 0.56, 0.0, 0.6, 4.5], [-l + 0.5, w, 0.62, 0.0, 0.59, 5.0],
		[l - 1.0, w, 0.62, 0.0, 0.59, 5.0], [l - 0.35, w * 0.99, 0.58, 0.0, 0.575, 5.0], [l - 0.08, w * 0.97, 0.5, 0.0, 0.56, 5.0], [l, w * 0.92, 0.42, 0.0, 0.55, 5.0]], 32), Transform3D())]
	# Roof slab and the pillars around the glass.
	var roof_from := -l + 0.2
	var roof_to := l - 1.85
	body.append(EnvMesh.piece(MachineArt.loft([[roof_from - 0.06, w * 0.7, 0.03, 0.0, 1.385, 4.0], [roof_from + 0.1, w * 0.8, 0.07, 0.0, 1.39, 4.5], [roof_to - 0.1, w * 0.8, 0.07, 0.0, 1.39, 4.5],
		[roof_to + 0.08, w * 0.72, 0.03, 0.0, 1.38, 4.0]], 24), Transform3D()))
	for s: float in [-1.0, 1.0]:
		for z: float in [roof_from + 0.02, -l + 1.45, -l + 2.35]:
			body.append(EnvMesh.piece(EnvMesh.box(Vector3(0.05, 0.5, 0.07), 0.015, 2), Transform3D(Basis(), Vector3(s * w * 0.395, 1.14, z))))
		# Windscreen pillar leans back.
		body.append(EnvMesh.piece(EnvMesh.box(Vector3(0.05, 0.7, 0.06), 0.015, 2), Transform3D(Basis(Vector3.RIGHT, -0.86), Vector3(s * w * 0.378, 1.15, roof_to + 0.29))))
		# Wing mirror.
		body.append(EnvMesh.piece(MachineArt.loft([[-0.05, 0.1, 0.07, 0.0, 0.0, 3.0], [0.0, 0.13, 0.09, 0.0, 0.0, 3.0], [0.03, 0.08, 0.05, 0.0, 0.0, 3.0]], 12),
			Transform3D(Basis(), Vector3(s * (w * 0.5 + 0.07), 0.98, roof_to + 0.5))))
	StationKit.add_merged(car, body, paint)
	# Glass house.
	StationKit.add(car, MachineArt.loft([[-l + 0.17, w * 0.7, 0.1, 0.0, 0.95, 4.0], [-l + 0.3, w * 0.78, 0.5, 0.0, 1.13, 4.5], [roof_to - 0.1, w * 0.78, 0.5, 0.0, 1.13, 4.5],
		[roof_to + 0.55, w * 0.75, 0.06, 0.0, 0.91, 4.0]], 24), glass)
	# Trim: bumpers, grille, wheel arches, door seams and handles, sills.
	var trim := []
	for z: float in [l - 0.03, -l + 0.02]:
		trim.append(EnvMesh.piece(EnvMesh.box(Vector3(w * 0.97, 0.11, 0.14), 0.04, 3), Transform3D(Basis(), Vector3(0, 0.36, z))))
	trim.append(EnvMesh.piece(EnvMesh.box(Vector3(w * 0.42, 0.13, 0.03), 0.01, 2), Transform3D(Basis(), Vector3(0, 0.6, l - 0.008))))
	for s: float in [-1.0, 1.0]:
		for z: float in [l - 0.82, -l + 0.9]:
			trim.append(MachineArt.turned(MachineArt.drum(0.37, 0.03, 0.01), Vector3.RIGHT if s > 0.0 else Vector3.LEFT, Vector3(s * (w * 0.5 - 0.022), 0.33, z), 28))
		for z: float in [-l + 1.45, -l + 2.35, roof_to + 0.62]:
			trim.append(EnvMesh.piece(EnvMesh.box(Vector3(0.006, 0.58, 0.012)), Transform3D(Basis(), Vector3(s * (w * 0.5 + 0.001), 0.6, z))))
		trim.append(EnvMesh.piece(EnvMesh.box(Vector3(0.03, 0.05, length - 2.0), 0.012, 2), Transform3D(Basis(), Vector3(s * (w * 0.5 - 0.02), 0.3, 0.04))))
	StationKit.add_merged(car, trim, dark)
	var bright := []
	for s: float in [-1.0, 1.0]:
		for z: float in [-l + 1.65, -l + 2.55]:
			bright.append(EnvMesh.piece(EnvMesh.box(Vector3(0.016, 0.022, 0.11), 0.006), Transform3D(Basis(), Vector3(s * (w * 0.5 + 0.006), 0.8, z))))
		# Roof rack rail with feet.
		bright.append(EnvMesh.piece(StationKit.tube(MachineArt.smooth(PackedVector3Array([Vector3(s * w * 0.33, 1.42, roof_from + 0.2), Vector3(s * w * 0.33, 1.475, roof_from + 0.3),
			Vector3(s * w * 0.33, 1.475, roof_to - 0.3), Vector3(s * w * 0.33, 1.42, roof_to - 0.2)]), 0.03), 0.012, 8), Transform3D()))
	for z: float in [roof_from + 0.55, (roof_from + roof_to) * 0.5, roof_to - 0.55]:
		bright.append(MachineArt.turned(MachineArt.drum(0.01, w * 0.66, 0.002), Vector3.RIGHT, Vector3(-w * 0.33, 1.475, z), 8))
	for z: float in [l - 0.82, -l + 0.9]:
		for s: float in [-1.0, 1.0]:
			bright.append(MachineArt.turned(MachineArt.cap(0.17, 0.03), Vector3.RIGHT if s > 0.0 else Vector3.LEFT, Vector3(s * (w * 0.5 + 0.012), 0.33, z), 24))
	for z: float in [l + 0.035, -l - 0.045]:
		bright.append(EnvMesh.piece(EnvMesh.box(Vector3(0.36, 0.09, 0.008), 0.004), Transform3D(Basis(), Vector3(0, 0.36, z))))
	StationKit.add_merged(car, bright, chrome)
	# Tyres.
	var tyre := StandardMaterial3D.new()
	tyre.albedo_color = Color("#17171a")
	tyre.roughness = 0.85
	var wheels := []
	for z: float in [l - 0.82, -l + 0.9]:
		for s: float in [-1.0, 1.0]:
			wheels.append(MachineArt.turned(PackedVector2Array([Vector2(0, 0), Vector2(0.27, 0), Vector2(0.31, 0.03), Vector2(0.325, 0.08), Vector2(0.325, 0.14), Vector2(0.31, 0.19),
				Vector2(0.27, 0.22), Vector2(0.19, 0.22), Vector2(0.18, 0.2), Vector2(0, 0.2)]), Vector3.RIGHT if s > 0.0 else Vector3.LEFT, Vector3(s * (w * 0.5 - 0.205), 0.325, z), 28))
	StationKit.add_merged(car, wheels, tyre)
	# Lamps: warm headlights, red tail lamps, amber indicators.
	var front := StandardMaterial3D.new()
	front.albedo_color = Color("#f4ecd6")
	front.roughness = 0.1
	front.emission_enabled = true
	front.emission = Color("#fff0c8")
	front.emission_energy_multiplier = 0.35
	var rear := StandardMaterial3D.new()
	rear.albedo_color = Color("#a8231c")
	rear.roughness = 0.2
	rear.emission_enabled = true
	rear.emission = Color("#ff3a2a")
	rear.emission_energy_multiplier = 0.25
	var lens := StationKit.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.085, 0), Vector2(0.085, 0.012), Vector2(0.06, 0.03), Vector2(0, 0.036)]), 20, 50.0)
	for s: float in [-1.0, 1.0]:
		StationKit.add(car, lens, front, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(s * w * 0.33, 0.6, l - 0.012)), false)
		StationKit.add(car, EnvMesh.box(Vector3(0.2, 0.13, 0.03), 0.012, 2), rear, Transform3D(Basis(), Vector3(s * w * 0.35, 0.66, -l + 0.012)), false)
	StationKit.label(car, "MM·G 1887", Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0.36, -l - 0.051)), 34, Color("#1a1a1a"), 800, 0.0011)
	StationKit.label(car, "MM·G 1887", Transform3D(Basis(), Vector3(0, 0.36, l + 0.041)), 34, Color("#1a1a1a"), 800, 0.0011)
	return car
