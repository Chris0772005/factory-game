class_name ScrapHallSet
extends GarageSet
## Level 1 set: the Schrotthalle, a big open-fronted steel shed with the
## scrap mountain inside. Brick below, sheeting above, steel columns and
## high-bay lamps. Out of the open front: the yard apron, the street, and
## across it the scrap dealer's shop (Schrott-Ankauf) where everything is
## sold. Same rules as the other halls (GarageSet).

const COLUMN_Z := [-7.0, -1.0, 5.0]
## Distance from the door line to the near kerb, the road width, and the shop front.
const APRON := 3.2
const ROAD := 5.6
const SHOP_Z := 12.4
## The row of houses across the street: front line, depth, and the fronts
## (middle of the front, ground level) of the two that are open.
const FRONT_Z := 22.12
const HOUSE_D := 6.6
const PAWN := Vector3(-11.0, 0, FRONT_Z)
const POLICE := Vector3(17.0, 0, FRONT_Z)
## Depth of the counters inside, from the front.
const COUNTER_Z := 3.5
## The scrap truck: lane on the street, parking spot and the spot at the
## skip (both on the apron), the skip and the excavator inside the hall.
const TRUCK_LANE_Z := 13.0
const TRUCK_PARK := Vector3(-21.0, 0, 9.8)
const TRUCK_DOCK := Vector3(-11.5, 0, 9.7)
const SKIP_POS := Vector3(-10.4, 0, 6.3)
const DIGGER_POS := Vector3(-6.0, 0, 5.4)
const WORKBENCH_POS := Vector3(-12.2, 0, -9.3)
## Where the street is closed off, left and right.
const TOWN_X := 27.0
## The pavement the patrol walks.
const BEAT_Z := 18.6


static func build_hall(world: Node3D, level_stations: Array) -> ScrapHallSet:
	var set := ScrapHallSet.new()
	set.name = "ScrapHallSet"
	set.stations = level_stations
	set.inner_min = Vector2(-14.0, -10.0)
	set.inner_max = Vector2(14.0, 8.0)
	set.height = 8.5
	set.window = Vector4(-9.0, 9.0, 4.4, 7.4)
	set.bay_line_x = -100.0
	set.ground_size = Vector2(80.0, 80.0)
	set.ground_z = 8.0
	set.floor_params = {concrete = Color("#84807a"), concrete_dark = Color("#5a5650"), paver = Color("#77726a")}
	world.add_child(set)
	set._build()
	return set


func _materials() -> void:
	_wall_mat = EnvMesh.material("scraphall_wall", "res://shaders/env_plaster.gdshader", {
		plaster = Color("#9aa3a6"), grime = Color("#4c4a47"), brick = Color("#8a4632"), mortar = Color("#b3a592"),
		chips = 0.55, streaks = 0.8, cutaway = true, brick_below = 2.2})
	_trim_mat = StationKit.metal("scraphall_trim", {steel_color = Color("#3f474c"), rust = 0.4, metallic_steel = 0.4})


## Daylight in the window band instead of the dusk glow of the other halls.
func _window(center: Vector3, size: Vector2) -> void:
	super(center, size)
	var glass := EnvMesh.material("garage_glass", "res://shaders/env_window.gdshader")
	if glass and EnvMesh.visual():
		var day := glass.duplicate() as ShaderMaterial
		day.set_shader_parameter(&"glow", Color("#dfeaf6"))
		day.set_shader_parameter(&"room", Color("#9fb4cc"))
		day.set_shader_parameter(&"glass_dark", Color("#6f8298"))
		day.set_shader_parameter(&"glass_sky", Color("#cfe0f2"))
		# No curtains in a works hall: the panes show pale sky.
		day.set_shader_parameter(&"curtain", Color("#c3d2e2"))
		day.set_shader_parameter(&"energy", 0.9)
		for child in get_children():
			var mi := child as MeshInstance3D
			if mi and mi.material_override == glass:
				mi.material_override = day


func _extra_stains() -> PackedVector4Array:
	var out := PackedVector4Array()
	for s in stations:
		if s is ScrapMountain:
			var p := (s as Node3D).position
			out.append(Vector4(p.x - ScrapMountain.RADIUS * 0.9, p.z, ScrapMountain.RADIUS + 1.2, 3.0))
	return out


func _sign() -> void:
	StationKit.label(self, "SCRAPYARD · HEINZ & NEPHEW", Transform3D(Basis(), Vector3(0.0, window.z - 0.5, inner_min.y + 0.012)), 150,
		Color("#e8dcc4"), 800, 0.0026)


func _dressing() -> void:
	_columns()
	prop("kaykit_prototype/Barrel_A.gltf", Vector3(12.9, 0.4, 6.6), 15.0, {solid = PropKit.Solid.CYLINDER, tint = Color("#3f5f8a"), desaturate = 0.3})
	prop("kaykit_prototype/Barrel_B.gltf", Vector3(12.8, 0.4, 5.7), -30.0, {solid = PropKit.Solid.CYLINDER, tint = Color("#8a4b2e"), desaturate = 0.3})
	prop("kaykit_hexagon/wheelbarrow.gltf", Vector3(4.2, 0, -8.6), 200.0, {scale = 0.9})
	_tyres(Vector3(-13.0, 0, 6.8), 4)
	_tyres(Vector3(-12.1, 0, 7.1), 2)
	_lamps()


## In daylight the hall's own bounce is neutral (the other halls stand in dusk).
func _reflection_probe() -> void:
	super()
	var probe := get_node_or_null(^"GarageReflections") as ReflectionProbe
	if probe:
		probe.ambient_color = Color("#77736c")
		probe.ambient_color_energy = 0.55


## The corner for the foundry stays clear until it is bought.
func _workshop_gear() -> void:
	pass


func _columns() -> void:
	var steel := StationKit.metal("scraphall_column", {steel_color = Color("#3d4a52"), paint = 0.9, paint_color = Color("#3a4a44"),
		rust = 0.35, metallic_steel = 0.4})
	var pieces := []
	var top := height - 0.5
	for z: float in COLUMN_Z:
		for x: float in [inner_min.x + 0.22, inner_max.x - 0.22]:
			var base := Vector3(x, 0, z)
			pieces.append(EnvMesh.piece(EnvMesh.box(Vector3(0.07, top, 0.34)), Transform3D(Basis(), base + Vector3(0, top * 0.5, 0))))
			for s: float in [-1.0, 1.0]:
				pieces.append(EnvMesh.piece(EnvMesh.box(Vector3(0.32, top, 0.035)), Transform3D(Basis(), base + Vector3(0, top * 0.5, s * 0.17))))
			pieces.append(EnvMesh.piece(EnvMesh.box(Vector3(0.46, 0.05, 0.46)), Transform3D(Basis(), base + Vector3(0, 0.025, 0))))
			WorldBuilder.add_collider(self, Vector3(0.34, top, 0.36), Transform3D(Basis(), base + Vector3(0, top * 0.5, 0)))
		# Roof truss across the hall at every column pair.
		pieces.append(EnvMesh.piece(EnvMesh.box(Vector3(inner_max.x - inner_min.x - 0.4, 0.3, 0.12)), Transform3D(Basis(), Vector3(0, top - 0.15, z))))
		pieces.append(EnvMesh.piece(EnvMesh.box(Vector3(inner_max.x - inner_min.x - 0.4, 0.08, 0.2)), Transform3D(Basis(), Vector3(0, top - 0.9, z))))
		for k in 14:
			var x := lerpf(inner_min.x + 1.0, inner_max.x - 1.0, k / 13.0)
			pieces.append(EnvMesh.piece(EnvMesh.box(Vector3(0.05, 0.75, 0.05)), Transform3D(Basis(Vector3.BACK, 0.5 if k % 2 == 0 else -0.5), Vector3(x, top - 0.52, z))))
	if EnvMesh.visual():
		EnvMesh.add(self, EnvMesh.merge(pieces), steel)


func _lamps() -> void:
	if not EnvMesh.visual():
		return
	var shade := StationKit.metal("highbay", {steel_color = Color("#3b4248"), paint = 0.9, paint_color = Color("#2d3439"), rust = 0.1})
	var bulb := EnvMesh.material("highbay_bulb", "res://shaders/env_bulb.gdshader", {energy = 2.6})
	var y := height - 1.3
	var spots := [Vector3(-8.5, y, -5.0), Vector3(0.0, y, -5.0), Vector3(8.5, y, -5.0), Vector3(-8.5, y, 2.5), Vector3(0.0, y, 2.5), Vector3(8.5, y, 2.5)]
	for i in spots.size():
		var p: Vector3 = spots[i]
		EnvMesh.add(self, EnvMesh.cylinder(0.14, 0.5, 0.34, 16), shade, Transform3D(Basis(), p), false)
		EnvMesh.add(self, EnvMesh.sphere(0.14, 10, 6), bulb, Transform3D(Basis(), p + Vector3(0, -0.13, 0)), false)
		var l := OmniLight3D.new()
		l.light_color = Color("#ffe6c4")
		l.light_energy = 2.1
		l.omni_range = 13.0
		l.omni_attenuation = 1.0
		l.position = p + Vector3(0, -0.45, 0)
		l.shadow_enabled = (i == 0 or i == 4) and not EnvQuality.disabled("shadows")
		add_child(l)
	var window_light := SpotLight3D.new()
	window_light.light_color = Color("#b9c6ff")
	window_light.light_energy = 3.0
	window_light.spot_range = 20.0
	window_light.spot_angle = 50.0
	window_light.position = Vector3(0, window.w, inner_min.y - 0.5)
	window_light.rotation_degrees = Vector3(-40, 180, 0)
	add_child(window_light)


## Apron, street and the scrap dealer's shop across it.
func _outside() -> void:
	var zf := inner_max.y + WALL * 0.5
	var road_z := zf + APRON + ROAD * 0.5
	var shop_z := zf + SHOP_Z
	if EnvMesh.visual():
		var asphalt := EnvMesh.surface("street_asphalt", {base_color = Color("#2f3033"), stain_color = Color("#1f2022"), stains = 0.5,
			macro = 0.25, grain = 0.3, roughness_base = 0.92, noise_scale = 2.5, bump = 0.5})
		EnvMesh.add(self, EnvMesh.box(Vector3(80.0, 0.04, ROAD), 0.0), asphalt, Transform3D(Basis(), Vector3(0, 0.0, road_z)), false)
		var paint := EnvMesh.surface("street_paint", {base_color = Color("#d9d4c4"), roughness_base = 0.8})
		var marks := []
		for i in 14:
			marks.append(EnvMesh.piece(EnvMesh.box(Vector3(1.6, 0.012, 0.14)), Transform3D(Basis(), Vector3(-26.0 + i * 4.0, 0.025, road_z))))
		# Zebra crossing from the hall door to the shop.
		for i in 7:
			marks.append(EnvMesh.piece(EnvMesh.box(Vector3(0.5, 0.012, ROAD - 0.6)), Transform3D(Basis(), Vector3(0.2 + i * 0.95, 0.026, road_z))))
		EnvMesh.add(self, EnvMesh.merge(marks), paint, Transform3D(), false)
		var kerb := EnvMesh.surface("street_kerb", {base_color = Color("#a39e94"), roughness_base = 0.85, contact_dark = 0.2})
		var kerbs := []
		for z: float in [road_z - ROAD * 0.5 - 0.1, road_z + ROAD * 0.5 + 0.1]:
			kerbs.append(EnvMesh.piece(EnvMesh.box(Vector3(80.0, 0.12, 0.2)), Transform3D(Basis(), Vector3(0, 0.06, z))))
		EnvMesh.add(self, EnvMesh.merge(kerbs), kerb)
		_shop(Vector3(3.0, 0, shop_z))
	prop("kaykit_city/streetlight.gltf", Vector3(-4.5, 0, zf + APRON - 0.6), 0.0, {scale = 1.0, solid = PropKit.Solid.CYLINDER})
	prop("kaykit_city/streetlight.gltf", Vector3(10.0, 0, zf + APRON + ROAD + 0.6), 180.0, {scale = 1.0, solid = PropKit.Solid.CYLINDER})
	prop("kaykit_city/streetlight.gltf", Vector3(-19.0, 0, zf + APRON + ROAD + 0.6), 180.0, {scale = 1.0, solid = PropKit.Solid.CYLINDER})
	prop("kaykit_city/streetlight.gltf", Vector3(21.0, 0, zf + APRON - 0.6), 0.0, {scale = 1.0, solid = PropKit.Solid.CYLINDER})
	prop("kaykit_city/firehydrant.gltf", Vector3(-4.0, 0, zf + APRON + ROAD + 0.7), 0.0, {scale = 0.9, solid = PropKit.Solid.CYLINDER})
	prop("kaykit_city/dumpster.gltf", Vector3(-4.6, 0, shop_z + 4.6), 90.0, {scale = 0.85})
	_town()
	# The rest of the town, beyond the barriers and behind the yard walls.
	prop("kaykit_city/building_A_withoutBase.gltf", Vector3(-35.0, 0, FRONT_Z + 4.0), 180.0, {solid = PropKit.Solid.NONE, desaturate = 0.5})
	prop("kaykit_city/building_F_withoutBase.gltf", Vector3(35.0, 0, FRONT_Z + 4.0), 180.0, {solid = PropKit.Solid.NONE, desaturate = 0.5})
	prop("kaykit_city/building_C_withoutBase.gltf", Vector3(-20.0, 0, -16.0), 0.0, {solid = PropKit.Solid.NONE, desaturate = 0.5})
	prop("kaykit_city/building_F_withoutBase.gltf", Vector3(20.0, 0, -15.5), 0.0, {solid = PropKit.Solid.NONE, desaturate = 0.5})
	prop("kaykit_city/building_C_withoutBase.gltf", Vector3(-22.0, 0, 0.5), 0.0, {solid = PropKit.Solid.NONE, desaturate = 0.5})
	prop("kaykit_city/building_A_withoutBase.gltf", Vector3(22.5, 0, 0.5), 0.0, {solid = PropKit.Solid.NONE, desaturate = 0.5})


## The quarter around the hall: the pawnbroker and the police station, both
## open to walk into, a shuttered shop and a kiosk, the yard walls beside the
## hall and the barriers where the street ends for now.
func _town() -> void:
	var zf := inner_max.y + WALL * 0.5
	var back_z := FRONT_Z + HOUSE_D
	# Pfandhaus: the door on the left, a shop window on the right.
	TownBlock.house(self, PAWN, 8.0, HOUSE_D, {key = "pawn", brick = Color("#7d4a3a"), mortar = Color("#b9a88f"), door_x = -2.6,
		windows = [[-0.4, 3.2]], sign = "PAWN SHOP", sign_back = Color("#3a2a20"), sign_color = Color("#e8c66a"),
		floor = Color("#6a4a30"), lining = Color("#b8ab8f"), trim = Color("#3a2a20"), lamp = Color("#ffd49a")})
	TownBlock.counter(self, PAWN + Vector3(0, 0, COUNTER_Z), 7.4, "pawn_counter", Color("#4f3a28"))
	TownBlock.shelves(self, PAWN + Vector3(0, 0, HOUSE_D - TownBlock.WALL - 0.24), 6.8, "pawn_shelf", 7)
	# Polizeiwache: plastered, blue sign, the desk across the room.
	TownBlock.house(self, POLICE, 9.0, HOUSE_D, {key = "police", plaster = Color("#c9cdc6"), brick = Color("#6d7377"), door_x = 0.0,
		windows = [[-3.8, -2.2], [2.3, 3.8]], sign = "POLICE", sign_back = Color("#1f3f7a"), sign_color = Color("#f4f4f0"),
		floor = Color("#7a7468"), lining = Color("#d2d6cf"), trim = Color("#1f3f7a"), lamp = Color("#eef2ff")})
	TownBlock.counter(self, POLICE + Vector3(0, 0, COUNTER_Z), 8.4, "police_desk", Color("#5a5348"))
	TownBlock.shelves(self, POLICE + Vector3(1.6, 0, HOUSE_D - TownBlock.WALL - 0.24), 4.6, "police_shelf", 11)
	WorldBuilder.add_collider(self, Vector3(0.5, 0.5, 2.0), Transform3D(Basis(), POLICE + Vector3(-3.9, 0.25, 1.7)))
	# Shut for now: the houses that fill the row.
	TownBlock.closed(self, Vector3(-21.0, 0, FRONT_Z), 10.0, HOUSE_D, {key = "let", brick = Color("#8c5a44"), sign = "FOR RENT"})
	TownBlock.closed(self, Vector3(24.3, 0, FRONT_Z), 4.6, HOUSE_D, {key = "kiosk", brick = Color("#6f6a62"), sign = "KIOSK"})
	# The yard wall behind the row and the walls beside the hall.
	var brick := EnvMesh.material("town_yardwall", "res://shaders/env_plaster.gdshader", {
		brick = Color("#84503c"), mortar = Color("#b6a58d"), brickwork = 1.0})
	var runs := [[Vector3(0, 1.5, back_z + 0.15), Vector3(TOWN_X * 2.0, 3.0, 0.3)]]
	for s: float in [-1.0, 1.0]:
		var from := inner_max.x + WALL
		runs.append([Vector3(s * (from + TOWN_X) * 0.5, 1.2, zf - 0.15), Vector3(TOWN_X - from, 2.4, 0.3)])
	var walls := []
	for r: Array in runs:
		WorldBuilder.add_collider(self, r[1], Transform3D(Basis(), r[0]))
		walls.append(EnvMesh.piece(EnvMesh.box(r[1]), Transform3D(Basis(), r[0])))
	if EnvMesh.visual():
		EnvMesh.add(self, EnvMesh.merge(walls), brick)
	# Barriers on the pavements, a boom across the road: it lifts for the truck.
	var road_from := zf + APRON
	for s: float in [-1.0, 1.0]:
		WorldBuilder.add_collider(self, Vector3(0.4, 2.4, back_z - zf), Transform3D(Basis(), Vector3(s * TOWN_X, 1.2, (zf + back_z) * 0.5)))
		TownBlock.barrier(self, Vector3(s * TOWN_X, 0, (zf + road_from) * 0.5), road_from - zf - 0.3)
		TownBlock.barrier(self, Vector3(s * TOWN_X, 0, (road_from + ROAD + back_z) * 0.5), back_z - road_from - ROAD - 0.3, "ROAD CLOSED")
		var gate := BoomGate.new()
		gate.length = ROAD
		gate.position = Vector3(s * TOWN_X, 0, road_from + ROAD * 0.5)
		add_child(gate)
	if not EnvMesh.visual():
		return
	# Who stands behind the counters.
	var broker := TownNpc.make("Suit", {"Suit": Color("#4a4038"), "Tie": Color("#7a2f2a")})
	broker.position = PAWN + Vector3(0.7, 0, COUNTER_Z + 1.1)
	broker.rotation.y = PI
	add_child(broker)
	var officer := TownNpc.make("Swat", PolicePatrol.UNIFORM)
	officer.position = POLICE + Vector3(-0.9, 0, COUNTER_Z + 1.1)
	officer.rotation.y = PI
	add_child(officer)
	StationKit.label(self, "BUY & SELL · CASH NOW · NO QUESTIONS", Transform3D(Basis(Vector3.UP, PI),
		PAWN + Vector3(0, 2.72, HOUSE_D - TownBlock.WALL - 0.04)), 80, Color("#3a2a20"), 700, 0.0032)
	StationKit.label(self, "LOST & FOUND · Reward for honest finders", Transform3D(Basis(Vector3.UP, PI),
		POLICE + Vector3(0, 2.72, HOUSE_D - TownBlock.WALL - 0.04)), 80, Color("#1f3f7a"), 700, 0.0032)
	# The blue lamp by the station door, and the bench for those who wait.
	var blue := StandardMaterial3D.new()
	blue.albedo_color = Color("#2a5fd0")
	blue.emission_enabled = true
	blue.emission = Color("#3f7bff")
	blue.emission_energy_multiplier = 2.5
	EnvMesh.add(self, EnvMesh.box(Vector3(0.24, 0.34, 0.24), 0.04), blue, Transform3D(Basis(), POLICE + Vector3(-1.25, 2.75, -0.2)), false)
	var bench := EnvMesh.wood("town_bench", {base_color = Color("#6f563c"), grain_color = Color("#3d2c1d"), weathering = 0.4, roughness_base = 0.6})
	var seat := []
	seat.append(EnvMesh.piece(EnvMesh.box(Vector3(0.45, 0.06, 2.0)), Transform3D(Basis(), POLICE + Vector3(-3.9, 0.46, 1.7))))
	for z: float in [-0.85, 0.85]:
		seat.append(EnvMesh.piece(EnvMesh.box(Vector3(0.4, 0.44, 0.06)), Transform3D(Basis(), POLICE + Vector3(-3.9, 0.22, 1.7 + z))))
	EnvMesh.add(self, EnvMesh.merge(seat), bench)


## The dealer's shop: a small brick building with an open counter, an awning
## and a painted sign. The ScrapShop station (the bin) stands in front of it.
func _shop(base: Vector3) -> void:
	var brick := EnvMesh.material("shop_brick", "res://shaders/env_plaster.gdshader", {
		brick = Color("#9a5038"), mortar = Color("#c4b49c"), brickwork = 1.0})
	var wood := EnvMesh.wood("shop_wood", {base_color = Color("#6b4a32"), grain_color = Color("#3e2a1c"), weathering = 0.4, roughness_base = 0.75})
	var w := 9.0
	var h := 4.2
	var d := 5.0
	var walls := []
	# Back and sides, a low front wall under the counter, pillars and a lintel.
	walls.append(EnvMesh.piece(EnvMesh.box(Vector3(w, h, 0.3)), Transform3D(Basis(), base + Vector3(0, h * 0.5, 1.6 + d))))
	for s: float in [-1.0, 1.0]:
		walls.append(EnvMesh.piece(EnvMesh.box(Vector3(0.3, h, d)), Transform3D(Basis(), base + Vector3(s * (w * 0.5 - 0.15), h * 0.5, 1.6 + d * 0.5))))
		walls.append(EnvMesh.piece(EnvMesh.box(Vector3(1.2, h, 0.3)), Transform3D(Basis(), base + Vector3(s * (w * 0.5 - 0.6), h * 0.5, 1.6))))
	walls.append(EnvMesh.piece(EnvMesh.box(Vector3(w - 2.4, 1.0, 0.3)), Transform3D(Basis(), base + Vector3(0, 0.5, 1.6))))
	walls.append(EnvMesh.piece(EnvMesh.box(Vector3(w, 1.1, 0.3)), Transform3D(Basis(), base + Vector3(0, h - 0.55, 1.6))))
	walls.append(EnvMesh.piece(EnvMesh.box(Vector3(w + 0.4, 0.25, d + 0.6)), Transform3D(Basis(), base + Vector3(0, h + 0.12, 1.6 + d * 0.5))))
	EnvMesh.add(self, EnvMesh.merge(walls), brick)
	WorldBuilder.add_collider(self, Vector3(w, h, d), Transform3D(Basis(), base + Vector3(0, h * 0.5, 1.6 + d * 0.5)))
	# Counter top, shelves with boxes behind it, the awning.
	var timber := []
	timber.append(EnvMesh.piece(EnvMesh.box(Vector3(w - 2.2, 0.08, 0.7)), Transform3D(Basis(), base + Vector3(0, 1.04, 1.5))))
	for y: float in [1.6, 2.3]:
		timber.append(EnvMesh.piece(EnvMesh.box(Vector3(w - 1.2, 0.05, 0.4)), Transform3D(Basis(), base + Vector3(0, y, 1.4 + d))))
	EnvMesh.add(self, EnvMesh.merge(timber), wood)
	var awning := EnvMesh.surface("shop_awning", {base_color = Color("#3f6f58"), roughness_base = 0.8})
	EnvMesh.add(self, EnvMesh.box(Vector3(w + 0.6, 0.06, 2.2), 0.0), awning, Transform3D(Basis(Vector3.RIGHT, 0.22), base + Vector3(0, h - 1.75, 0.55)))
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("#16181c")
	dark.roughness = 1.0
	EnvMesh.add(self, EnvMesh.box(Vector3(w - 2.5, h - 2.2, 0.05), 0.0), dark, Transform3D(Basis(), base + Vector3(0, 2.0, 1.6 + d - 0.2)), false)
	StationKit.label(self, "SCRAP DEALER", Transform3D(Basis(Vector3.UP, PI), base + Vector3(0, h - 0.55, 1.44)), 150, Color("#f2e6c8"), 800, 0.0042)
	StationKit.label(self, "Kowalski · cash paid", Transform3D(Basis(Vector3.UP, PI), base + Vector3(0, h - 1.02, 1.44)), 80, Color("#e0c88a"), 600, 0.003)
	# Warm light under the awning: the shop is the brightest thing on the street.
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("#ffcf8a")
	lamp.light_energy = 2.6
	lamp.omni_range = 9.0
	lamp.position = base + Vector3(0, 2.6, 0.4)
	add_child(lamp)
