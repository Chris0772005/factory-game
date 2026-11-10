class_name IronHallSet
extends GarageSet
## Level 4 set: the Eisenhalle, a tall steel-framed works hall. Brick below,
## painted sheeting above, a long band of factory windows, steel columns
## carrying the crane runway, high-bay lamps. Same dollhouse rules as the
## garage (open front, shadow-only roof, cutaway walls). Across the yard
## through the open front: the cathedral the Kaiserglocke is for.

const COLUMN_Z := [-4.5, -0.5, 3.5]


static func build_hall(world: Node3D, level_stations: Array) -> IronHallSet:
	var set := IronHallSet.new()
	set.name = "IronHallSet"
	set.stations = level_stations
	set.inner_min = Vector2(-10.0, -6.5)
	set.inner_max = Vector2(10.0, 6.0)
	set.height = 6.4
	set.window = Vector4(-6.0, 6.0, 3.3, 5.6)
	set.bay_line_x = -100.0
	set.floor_params = {concrete = Color("#7d7a76"), concrete_dark = Color("#55524e"), paver = Color("#6e6a64")}
	world.add_child(set)
	set._build()
	return set


func _materials() -> void:
	_wall_mat = EnvMesh.material("ironhall_wall", "res://shaders/env_plaster.gdshader", {
		plaster = Color("#8f9aa0"), grime = Color("#4a4846"), brick = Color("#7e3d2c"), mortar = Color("#a99a88"),
		chips = 0.5, streaks = 0.7, cutaway = true, brick_below = 2.6})
	_trim_mat = StationKit.metal("ironhall_trim", {steel_color = Color("#3d4a52"), rust = 0.35, metallic_steel = 0.4})


func _extra_stains() -> PackedVector4Array:
	var out := PackedVector4Array()
	for s in stations:
		var p := (s as Node3D).position
		if s is CupolaFurnace:
			out.append(Vector4(p.x, p.z + 0.6, 2.2, 1.0))
		elif s is BellPit:
			out.append(Vector4(p.x, p.z, (s as BellPit).outer_radius() + 0.8, 2.0))
		elif s is MoldLine:
			out.append(Vector4(p.x + 2.4, p.z - 0.5, 2.6, 2.0))
		elif s is ChargeSupply and (s as ChargeSupply).look == &"iron":
			out.append(Vector4(p.x, p.z, 1.4, 3.0))
	return out


func _sign() -> void:
	StationKit.label(self, "EISENHALLE · WERK II", Transform3D(Basis(), Vector3(0.0, window.z - 0.35, inner_min.y + 0.012)), 140,
		Color("#e8dcc4"), 800, 0.0022)


func _dressing() -> void:
	_columns()
	_hazard_stripes()
	_finished_covers(Vector3(7.6, 0, 4.4))
	_sand_silo(Vector3(-8.7, 0, 3.8))
	_pattern_shelf(Vector3(-2.0, 0, inner_min.y + 0.3))
	prop("kaykit_dungeon/barrel_large.gltf", Vector3(9.2, 0, -5.7), 10.0, {solid = PropKit.Solid.CYLINDER, tint = Color("#7f8a90")})
	prop("kaykit_dungeon/barrel_large.gltf", Vector3(8.4, 0, -5.9), 70.0, {solid = PropKit.Solid.CYLINDER, tint = Color("#8a5a40")})
	prop("kaykit_hexagon/wheelbarrow.gltf", Vector3(-3.2, 0, -3.0), 120.0, {scale = 0.9})
	_signs()
	_lamps()


## Steel columns along both side walls carrying the crane runway (the
## crane draws its own rails), with knee braces.
func _columns() -> void:
	var steel := StationKit.metal("ironhall_column", {steel_color = Color("#3d4a52"), paint = 0.9, paint_color = Color("#2f5a73"),
		rust = 0.3, metallic_steel = 0.4})
	var pieces := []
	var top := height - 0.6
	for z: float in COLUMN_Z:
		for x: float in [inner_min.x + 0.2, inner_max.x - 0.2]:
			var base := Vector3(x, 0, z)
			# I-section: web and two flanges.
			pieces.append(EnvMesh.piece(EnvMesh.box(Vector3(0.06, top, 0.3)), Transform3D(Basis(), base + Vector3(0, top * 0.5, 0))))
			for s: float in [-1.0, 1.0]:
				pieces.append(EnvMesh.piece(EnvMesh.box(Vector3(0.28, top, 0.03)), Transform3D(Basis(), base + Vector3(0, top * 0.5, s * 0.15))))
			pieces.append(EnvMesh.piece(EnvMesh.box(Vector3(0.4, 0.05, 0.4)), Transform3D(Basis(), base + Vector3(0, 0.025, 0))))
			WorldBuilder.add_collider(self, Vector3(0.3, top, 0.32), Transform3D(Basis(), base + Vector3(0, top * 0.5, 0)))
	EnvMesh.add(self, EnvMesh.merge(pieces), steel)


## Yellow-black floor stripes round the cupola and along the mold line.
func _hazard_stripes() -> void:
	if not EnvMesh.visual():
		return
	var yellow := StandardMaterial3D.new()
	yellow.albedo_color = Color("#d9a521")
	yellow.roughness = 0.8
	for s in stations:
		if s is MoldLine:
			var p := (s as Node3D).position
			var stripes := []
			for k in 14:
				stripes.append(EnvMesh.piece(EnvMesh.box(Vector3(0.18, 0.004, 0.06)), Transform3D(Basis(Vector3.UP, 0.6), p + Vector3(-0.6 + k * 0.48, 0.003, 0.72))))
			EnvMesh.add(self, EnvMesh.merge(stripes), yellow, Transform3D(), false)
		elif s is CupolaFurnace:
			var c := (s as Node3D).position
			var ring := []
			for k in 20:
				var a := TAU * k / 20.0
				ring.append(EnvMesh.piece(EnvMesh.box(Vector3(0.2, 0.004, 0.07)), Transform3D(Basis(Vector3.UP, a + 0.6), c + Vector3(sin(a), 0, cos(a)) * 1.25 + Vector3(0, 0.003, 0))))
			EnvMesh.add(self, EnvMesh.merge(ring), yellow, Transform3D(), false)


## Stack of finished manhole covers on a pallet: what the line makes.
func _finished_covers(base: Vector3) -> void:
	WorldBuilder.add_collider(self, Vector3(1.2, 0.7, 1.2), Transform3D(Basis(), base + Vector3(0, 0.35, 0)))
	if not EnvMesh.visual():
		return
	PropKit.place(self, "kaykit_hexagon/pallet.gltf", base, 0.0, {solid = PropKit.Solid.NONE, scale = 1.0})
	var iron := MetalMaterial.create(&"iron", 21)
	iron.set_shader_parameter(&"crust", 0.1)
	var covers := []
	for i in 8:
		var y := 0.16 + i * 0.065
		covers.append(EnvMesh.piece(EnvMesh.cylinder(0.42, 0.42, 0.055, 24), Transform3D(Basis(Vector3.UP, i * 0.4), base + Vector3(sin(i * 1.7) * 0.02, y, cos(i * 2.3) * 0.02))))
	EnvMesh.add(self, EnvMesh.merge(covers), iron)
	var face := StationKit.label(self, "STADT", Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), base + Vector3(0, 0.16 + 7 * 0.065 + 0.03, 0)), 90, Color("#2b2b2e"), 900, 0.0022)
	if face:
		face.modulate = Color(0.25, 0.25, 0.27, 0.85)


## Tall molding-sand silo with its chute.
func _sand_silo(base: Vector3) -> void:
	WorldBuilder.add_collider(self, Vector3(1.6, 4.2, 1.6), Transform3D(Basis(), base + Vector3(0, 2.1, 0)))
	if not EnvMesh.visual():
		return
	var paint := StationKit.metal("silo_paint", {steel_color = Color("#5d6a70"), paint = 0.85, paint_color = Color("#9aa7ad"), rust = 0.4})
	var outline := PackedVector2Array([Vector2(0.0, 1.0), Vector2(0.15, 1.0), Vector2(0.75, 1.9), Vector2(0.75, 4.0), Vector2(0.55, 4.3), Vector2(0.0, 4.3)])
	StationKit.add(self, StationKit.lathe(outline, 24, 40.0), paint, Transform3D(Basis(), base))
	var legs := []
	for k in 4:
		var a := PI * 0.25 + k * PI * 0.5
		legs.append(EnvMesh.piece(EnvMesh.box(Vector3(0.1, 1.95, 0.1)), Transform3D(Basis(), base + Vector3(sin(a) * 0.65, 0.97, cos(a) * 0.65))))
	EnvMesh.add(self, EnvMesh.merge(legs), paint)
	StationKit.label(self, "FORMSAND", Transform3D(Basis(), base + Vector3(0, 3.0, 0.76)), 72, Color("#2a2522"), 800, 0.0016)


## Wooden patterns on a shelf by the back wall: old series patterns.
func _pattern_shelf(base: Vector3) -> void:
	WorldBuilder.add_collider(self, Vector3(2.4, 2.0, 0.5), Transform3D(Basis(), base + Vector3(0, 1.0, 0)))
	if not EnvMesh.visual():
		return
	var wood := StationKit.wood("pattern_shelf", {base_color = Color("#7a5a3c"), weathering = 0.3})
	var boards := []
	for y: float in [0.05, 0.7, 1.35, 1.95]:
		boards.append(EnvMesh.piece(EnvMesh.box(Vector3(2.4, 0.04, 0.45), 0.005), Transform3D(Basis(), base + Vector3(0, y, 0))))
	for x: float in [-1.18, 1.18]:
		boards.append(EnvMesh.piece(EnvMesh.box(Vector3(0.05, 2.0, 0.45)), Transform3D(Basis(), base + Vector3(x, 1.0, 0))))
	EnvMesh.add(self, EnvMesh.merge(boards), wood)
	var pattern := StationKit.wood("old_pattern", {base_color = Color("#c9a46a"), weathering = 0.15, paint = 0.6, paint_color = Color("#b8452f")})
	var pieces := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for row in 3:
		for k in 4:
			var p := base + Vector3(-0.85 + k * 0.56, 0.1 + row * 0.65 + 0.2, 0.0)
			if (row + k) % 2 == 0:
				pieces.append(EnvMesh.piece(EnvMesh.cylinder(0.2, 0.2, 0.05, 16), Transform3D(Basis(Vector3.RIGHT, PI * 0.5 - 0.2), p)))
			else:
				pieces.append(EnvMesh.piece(EnvMesh.box(Vector3(0.36, 0.3, 0.05), 0.02), Transform3D(Basis(Vector3.RIGHT, -0.2), p + Vector3(0, 0, 0.02))))
	EnvMesh.add(self, EnvMesh.merge(pieces), pattern)


func _signs() -> void:
	if not EnvMesh.visual():
		return
	var plate := EnvMesh.surface("warn_plate", {base_color = Color("#d9a521"), roughness_base = 0.5, macro = 0.05})
	for spec: Array in [[Vector3(inner_min.x + 0.03, 2.2, -2.0), PI * 0.5, "ACHTUNG\nHÄNGENDE LAST"],
			[Vector3(inner_max.x - 0.03, 2.2, 2.6), -PI * 0.5, "FLÜSSIGES EISEN\nABSTAND HALTEN"]]:
		var basis := Basis(Vector3.UP, spec[1])
		EnvMesh.add(self, EnvMesh.box(Vector3(0.9, 0.55, 0.015), 0.005), plate, Transform3D(basis, spec[0]))
		StationKit.label(self, spec[2], Transform3D(basis, spec[0] + basis * Vector3(0, 0, 0.012)), 44, Color("#1f1b17"), 900, 0.0012)


func _lamps() -> void:
	if not EnvMesh.visual():
		return
	# High-bay lamps under the roof: cones over warm-white pools.
	var shade := StationKit.metal("highbay", {steel_color = Color("#3b4248"), paint = 0.9, paint_color = Color("#2d3439"), rust = 0.1})
	var bulb := EnvMesh.material("highbay_bulb", "res://shaders/env_bulb.gdshader", {energy = 2.6})
	var spots := [Vector3(-6.0, 5.7, -3.0), Vector3(0.0, 5.7, -3.0), Vector3(6.0, 5.7, -3.0), Vector3(-6.0, 5.7, 2.5), Vector3(0.0, 5.7, 2.5), Vector3(6.0, 5.7, 2.5)]
	for i in spots.size():
		var p: Vector3 = spots[i]
		EnvMesh.add(self, EnvMesh.cylinder(0.12, 0.42, 0.3, 16), shade, Transform3D(Basis(), p), false)
		EnvMesh.add(self, EnvMesh.sphere(0.12, 10, 6), bulb, Transform3D(Basis(), p + Vector3(0, -0.12, 0)), false)
		var l := OmniLight3D.new()
		l.light_color = Color("#ffe2b8")
		l.light_energy = 1.5
		l.omni_range = 9.5
		l.omni_attenuation = 1.1
		l.position = p + Vector3(0, -0.4, 0)
		l.shadow_enabled = (i == 1 or i == 4) and not EnvQuality.disabled("shadows")
		add_child(l)
	var window_light := SpotLight3D.new()
	window_light.light_color = Color("#aebcff")
	window_light.light_energy = 2.6
	window_light.spot_range = 14.0
	window_light.spot_angle = 45.0
	window_light.position = Vector3(0, window.w, inner_min.y - 0.5)
	window_light.rotation_degrees = Vector3(-38, 180, 0)
	add_child(window_light)


func _outside() -> void:
	var zf := inner_max.y + WALL * 0.5
	if EnvMesh.visual():
		# The cathedral across the yard: nave and two spired towers.
		var stone := EnvMesh.material("dom_stone", "res://shaders/env_plaster.gdshader", {
			plaster = Color("#cbbfae"), brick = Color("#9a8e7f"), mortar = Color("#b9ad9b"), chips = 0.6, streaks = 0.8})
		var roof := EnvMesh.material("dom_roof", "res://shaders/env_plaster.gdshader", {
			plaster = Color("#3a4650"), grime = Color("#283038"), chips = 0.0, streaks = 0.6})
		var c := Vector3(-2.0, 0, zf + 24.0)
		for s: float in [-1.0, 1.0]:
			var t := c + Vector3(s * 3.6, 0, 0)
			EnvMesh.add(self, EnvMesh.box(Vector3(4.0, 18.0, 4.0), 0.05), stone, Transform3D(Basis(), t + Vector3(0, 9.0, 0)))
			EnvMesh.add(self, EnvMesh.cylinder(0.0, 2.8, 9.0, 8), roof, Transform3D(Basis(Vector3.UP, PI / 8.0), t + Vector3(0, 22.5, 0)))
		EnvMesh.add(self, EnvMesh.box(Vector3(11.0, 11.0, 14.0), 0.05), stone, Transform3D(Basis(), c + Vector3(0, 5.5, 8.0)))
		var louvre := EnvMesh.material("dom_louvre", "res://shaders/env_window.gdshader", {energy = 0.7, glow = Color("#ffb877")})
		for s: float in [-1.0, 1.0]:
			EnvMesh.add(self, EnvMesh.box(Vector3(1.4, 2.6, 0.05), 0.0), louvre, Transform3D(Basis(), c + Vector3(s * 3.6, 14.0, -2.03)), false)
		# Works chimney behind the hall.
		var brick := EnvMesh.material("chimney_brick", "res://shaders/env_plaster.gdshader", {
			brick = Color("#7e3d2c"), mortar = Color("#a99a88"), brickwork = 1.0})
		EnvMesh.add(self, EnvMesh.cylinder(0.8, 1.3, 22.0, 16), brick, Transform3D(Basis(), Vector3(-12.0, 11.0, -12.0)))
	prop("kaykit_city/streetlight.gltf", Vector3(-8.0, 0, zf + 5.0), 0.0, {scale = 0.95, solid = PropKit.Solid.CYLINDER})
	prop("kaykit_city/streetlight.gltf", Vector3(8.0, 0, zf + 5.0), 180.0, {scale = 0.95, solid = PropKit.Solid.CYLINDER})
	prop("kaykit_city/building_C_withoutBase.gltf", Vector3(-14.0, 0, -13.0), 0.0, {solid = PropKit.Solid.NONE, desaturate = 0.5})
	prop("kaykit_city/building_F_withoutBase.gltf", Vector3(14.0, 0, -12.5), 0.0, {solid = PropKit.Solid.NONE, desaturate = 0.5})
	for x: float in [inner_min.x - 1.2, inner_max.x + 1.2]:
		WorldBuilder.add_collider(self, Vector3(0.4, 1.2, 8.0), Transform3D(Basis(), Vector3(x, 0.6, zf + 4.0)))
	WorldBuilder.add_collider(self, Vector3(24.0, 1.2, 0.4), Transform3D(Basis(), Vector3(0, 0.6, zf + 8.2)))
