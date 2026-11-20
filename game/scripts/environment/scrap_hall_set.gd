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
## The diner: ten metres of front, the door towards the pawnbroker's.
const DINER := Vector3(-21.0, 0, FRONT_Z)
const DINER_DOOR_X := 3.0
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
## The hall's walls: brick up to here, profiled sheet above.
const BRICK_TOP := 2.2
## What stands on the shelves of the two open houses (scans from Poly Haven; TownBlock.shelves).
const PAWN_GOODS := ["boombox", "brass_vase_02", "television_02", "american_football", "alarm_clock_01", "vintage_electric_kettle",
	"marble_bust_01", "Megaphone_01", "metal_toolbox", "Ukulele_01", "horse_statue_01", "Drill_01", "small_oil_can_01", "oil_tin"]
## What stands on the diner's shelf behind the counter.
## Where things are along the diner's counter (from its middle, m): the two places to order and Molly;
## and where its two tables stand along the front.
const DINER_COFFEE_X := 2.9
const DINER_MEAL_X := 1.7
const DINER_COOK_X := 2.2
const DINER_TABLES: Array[float] = [-3.3, 0.25]
## The diner's board on the pavement (from the middle of its front).
const DINER_SIGN := Vector3(1.25, 0, -0.48)
const DINER_GOODS := ["jug_01", "pot_enamel_01", "vintage_electric_kettle", "hamburger_buns", "carrot_cake", "brass_pan_01@90", "croissant"]
const POLICE_FILES := ["book_encyclopedia_set_01", "cardboard_box_01@90", "clipboard@90", "book_encyclopedia_set_01", "metal_toolbox",
	"cardboard_box_01@90", "book_encyclopedia_set_01"]
## Where the street is closed off, left and right.
const TOWN_X := 27.0
## Beyond the barriers the street meets a side street at each end (their middle, and how far they
## run): the cars of the town come up the western one, drive down the street and leave by the
## eastern one (TownTraffic), in the lane at TRAFFIC_LANE_Z, between the near kerb and the parked cars.
const SIDE_X := 44.5
const SIDE_END := 47.0
const TRAFFIC_LANE_Z := 12.9
## The pavement the patrol walks.
const BEAT_Z := 18.6


var _brick_mat: ShaderMaterial
var _sheet_mat: ShaderMaterial


static func build_hall(world: Node3D, level_stations: Array) -> ScrapHallSet:
	var set := ScrapHallSet.new()
	set.name = "ScrapHallSet"
	set.stations = level_stations
	set.inner_min = Vector2(-14.0, -10.0)
	set.inner_max = Vector2(14.0, 8.0)
	set.height = 8.5
	set.window = Vector4(-9.0, 9.0, 4.4, 7.4)
	set.bay_line_x = -100.0
	set.ground_size = Vector2(130.0, 80.0)
	set.ground_z = 8.0
	set.floor_params = {concrete = Color("#84807a"), concrete_dark = Color("#5a5650"), paver = Color("#77726a")}
	world.add_child(set)
	set._build()
	return set


func _exit_tree() -> void:
	EnvMesh.release_scans()


func _materials() -> void:
	_wall_mat = EnvMesh.material("scraphall_wall", "res://shaders/env_plaster.gdshader", {
		plaster = Color("#9aa3a6"), grime = Color("#4c4a47"), brick = Color("#8a4632"), mortar = Color("#b3a592"),
		chips = 0.55, streaks = 0.8, cutaway = true, brick_below = 2.2})
	_trim_mat = StationKit.metal("scraphall_trim", {steel_color = Color("#3f474c"), rust = 0.4, metallic_steel = 0.4})
	# Photographed surfaces (graphics standard, TECH_SPEC Modul Y): a brick plinth, profiled sheet above.
	_brick_mat = EnvMesh.scan("scraphall_brick", "red_brick_03", {foot = 0.5, drift = 0.2, cutaway = true})
	_sheet_mat = EnvMesh.repainted("scraphall_sheet", "box_profile_metal_sheet", Color("#7d8a8e"), {drift = 0.1, cutaway = true})


## Brick below, sheeting above: every wall is two boxes, split at BRICK_TOP.
func _wall_box(center: Vector3, size: Vector3) -> void:
	var body := WorldBuilder.add_collider(self, size, Transform3D(Basis(), center))
	body.add_to_group(CAMERA_PASSTHROUGH)
	_passthrough.append(body.get_rid())
	var bottom := center.y - size.y * 0.5
	var top := center.y + size.y * 0.5
	var split := clampf(BRICK_TOP, bottom, top)
	if split - bottom > 0.01:
		EnvMesh.add(self, EnvMesh.box(Vector3(size.x, split - bottom, size.z), 0.0), _brick_mat,
			Transform3D(Basis(), Vector3(center.x, (bottom + split) * 0.5, center.z)))
	if top - split > 0.01:
		# The sheet stands a little back from the face of the brick (across the wall only: along it,
		# the boxes of one wall must still meet).
		var thin_x := size.x < size.z
		EnvMesh.add(self, EnvMesh.box(Vector3(size.x - (0.04 if thin_x else 0.0), top - split, size.z - (0.0 if thin_x else 0.04)), 0.0), _sheet_mat,
			Transform3D(Basis(), Vector3(center.x, (split + top) * 0.5, center.z)))


func _pillar_material() -> ShaderMaterial:
	return _brick_mat


func _roof_material() -> ShaderMaterial:
	return EnvMesh.repainted("scraphall_roof", "box_profile_metal_sheet", Color("#8f989a"), {drift = 0.08})


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
		# The front stands open to the day: paint and glass inside mirror the sky through it.
		probe.interior = false


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
		var asphalt := EnvMesh.scan("street_asphalt", "asphalt_02", {drift = 0.22, tint = Vector3(0.7, 0.7, 0.72)})
		# The street runs on to the side streets at both ends, which lead away behind the far blocks.
		var roads := [EnvMesh.piece(EnvMesh.box(Vector3(SIDE_X * 2.0 + ROAD, 0.04, ROAD), 0.0), Transform3D(Basis(), Vector3(0, 0.0, road_z)))]
		var side_from := road_z + ROAD * 0.5
		var side_to := ground_z + ground_size.y * 0.5
		for s: float in [-1.0, 1.0]:
			roads.append(EnvMesh.piece(EnvMesh.box(Vector3(ROAD, 0.04, side_to - side_from), 0.0), Transform3D(Basis(), Vector3(s * SIDE_X, 0.0, (side_from + side_to) * 0.5))))
		EnvMesh.add(self, EnvMesh.merge(roads), asphalt, Transform3D(), false)
		var paint := EnvMesh.surface("street_paint", {base_color = Color("#d9d4c4"), roughness_base = 0.8})
		var marks := []
		for i in 14:
			marks.append(EnvMesh.piece(EnvMesh.box(Vector3(1.6, 0.012, 0.14)), Transform3D(Basis(), Vector3(-26.0 + i * 4.0, 0.025, road_z))))
		# Zebra crossing from the hall door to the shop.
		for i in 7:
			marks.append(EnvMesh.piece(EnvMesh.box(Vector3(0.5, 0.012, ROAD - 0.6)), Transform3D(Basis(), Vector3(0.2 + i * 0.95, 0.026, road_z))))
		EnvMesh.add(self, EnvMesh.merge(marks), paint, Transform3D(), false)
		var kerb := EnvMesh.scan("street_kerb", "dirty_concrete", {tile = 1.6, tint = Vector3(0.85, 0.85, 0.85)})
		var kerbs := []
		for z: float in [road_z - ROAD * 0.5 - 0.1, road_z + ROAD * 0.5 + 0.1]:
			kerbs.append(EnvMesh.piece(EnvMesh.box(Vector3(80.0, 0.12, 0.2)), Transform3D(Basis(), Vector3(0, 0.06, z))))
		EnvMesh.add(self, EnvMesh.merge(kerbs), kerb)
		_paving(zf)
		_shop(Vector3(3.0, 0, shop_z))
	prop("kaykit_city/streetlight.gltf", Vector3(-4.5, 0, zf + APRON - 0.6), 0.0, {scale = 1.0, solid = PropKit.Solid.CYLINDER})
	prop("kaykit_city/streetlight.gltf", Vector3(10.0, 0, zf + APRON + ROAD + 0.6), 180.0, {scale = 1.0, solid = PropKit.Solid.CYLINDER})
	prop("kaykit_city/streetlight.gltf", Vector3(-19.0, 0, zf + APRON + ROAD + 0.6), 180.0, {scale = 1.0, solid = PropKit.Solid.CYLINDER})
	prop("kaykit_city/streetlight.gltf", Vector3(21.0, 0, zf + APRON - 0.6), 0.0, {scale = 1.0, solid = PropKit.Solid.CYLINDER})
	prop("kaykit_city/firehydrant.gltf", Vector3(-4.0, 0, zf + APRON + ROAD + 0.7), 0.0, {scale = 0.9, solid = PropKit.Solid.CYLINDER})
	TownBlock.dumpster(self, Vector3(-4.6, 0, shop_z + 4.6), 90.0)
	_town()
	# The rest of the town, beyond the barriers and behind the yard walls.
	TownBlock.block(self, Vector3(-36.0, 0, FRONT_Z), 12.0, 9.0, {key = "far_a", scan = "red_brick", storeys = 3})
	TownBlock.block(self, Vector3(36.0, 0, FRONT_Z), 12.0, 9.0, {key = "far_b", scan = "yellow_plaster", storeys = 4})
	TownBlock.block(self, Vector3(-21.0, 0, -22.0), 11.0, 8.0, {key = "far_c", scan = "painted_worn_brick", storeys = 3})
	TownBlock.block(self, Vector3(20.0, 0, -22.0), 12.0, 8.0, {key = "far_d", scan = "red_brick_03", storeys = 4})
	TownBlock.block(self, Vector3(-24.5, 0, -4.0), 9.0, 9.0, {key = "far_e", plaster = Color("#b9b2a2"), storeys = 3})
	TownBlock.block(self, Vector3(25.0, 0, -4.0), 9.0, 9.0, {key = "far_f", scan = "red_brick", storeys = 3})
	# Round the two junctions: a house across each end of the street, one on the corner this side of
	# it and one down the side street, so that no view runs out into nothing.
	var beyond := SIDE_X + ROAD * 0.5 + 2.4
	TownBlock.block(self, Vector3(-(beyond + 6.5), 0, zf - 3.0), 13.0, 17.0, {key = "end_a", scan = "yellow_plaster", storeys = 4})
	TownBlock.block(self, Vector3(beyond + 6.5, 0, zf - 3.0), 13.0, 17.0, {key = "end_b", scan = "red_brick_03", storeys = 3})
	TownBlock.block(self, Vector3(-(beyond + 6.5), 0, FRONT_Z + 4.0), 13.0, 14.0, {key = "end_c", scan = "red_brick", storeys = 3})
	TownBlock.block(self, Vector3(beyond + 6.5, 0, FRONT_Z + 4.0), 13.0, 14.0, {key = "end_d", plaster = Color("#b9b2a2"), storeys = 4})
	TownBlock.block(self, Vector3(-35.4, 0, zf - 12.6), 12.4, 12.0, {key = "end_e", scan = "painted_worn_brick", storeys = 3})
	TownBlock.block(self, Vector3(35.4, 0, zf - 12.6), 12.4, 12.0, {key = "end_f", scan = "yellow_plaster", storeys = 3})


## Photographed paving over the plain ground outside: pavers on the apron, slabs on the pavement across
## the road, worn concrete in the yards beside and behind the hall.
func _paving(zf: float) -> void:
	var near := zf + APRON - 0.2
	var far := zf + APRON + ROAD + 0.2
	var half := ground_size.x * 0.5
	var back := ground_z - ground_size.y * 0.5
	var out_x := inner_max.x + WALL
	var concrete := EnvMesh.scan("yard_concrete", "dirty_concrete", {drift = 0.2})
	_slab(EnvMesh.scan("yard_pavers", "concrete_pavers", {drift = 0.18, tint = Vector3(0.84, 0.88, 0.94)}), -half, half, zf, near)
	_slab(EnvMesh.scan("street_slabs", "concrete_tiles_02", {drift = 0.16}), -half, half, far, ground_z + ground_size.y * 0.5)
	_slab(concrete, -half, -out_x, back, zf)
	_slab(concrete, out_x, half, back, zf)
	_slab(concrete, -out_x, out_x, back, inner_min.y - WALL)


## A thin slab of ground from x0 to x1 and z0 to z1, a finger's breadth above the base ground.
func _slab(mat: Material, x0: float, x1: float, z0: float, z1: float) -> void:
	EnvMesh.add(self, EnvMesh.box(Vector3(x1 - x0, 0.03, z1 - z0), 0.0), mat, Transform3D(Basis(), Vector3((x0 + x1) * 0.5, -0.003, (z0 + z1) * 0.5)), false)


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
	TownBlock.shelves(self, PAWN + Vector3(0, 0, HOUSE_D - TownBlock.WALL - 0.24), 6.8, "pawn_shelf", 7, PAWN_GOODS)
	# Polizeiwache: plastered, blue sign, the desk across the room.
	TownBlock.house(self, POLICE, 9.0, HOUSE_D, {key = "police", plaster = Color("#c9cdc6"), brick = Color("#6d7377"), door_x = 0.0,
		windows = [[-3.8, -2.2], [2.3, 3.8]], sign = "POLICE", sign_back = Color("#1f3f7a"), sign_color = Color("#f4f4f0"),
		floor = Color("#7a7468"), lining = Color("#d2d6cf"), trim = Color("#1f3f7a"), lamp = Color("#eef2ff")})
	TownBlock.counter(self, POLICE + Vector3(0, 0, COUNTER_Z), 8.4, "police_desk", Color("#5a5348"))
	TownBlock.shelves(self, POLICE + Vector3(1.6, 0, HOUSE_D - TownBlock.WALL - 0.24), 4.6, "police_shelf", 11, POLICE_FILES)
	WorldBuilder.add_collider(self, Vector3(0.5, 0.5, 2.0), Transform3D(Basis(), POLICE + Vector3(-3.9, 0.25, 1.7)))
	# The diner: cream render over a red brick foot, two wide windows, the door on the right.
	TownBlock.house(self, DINER, 10.0, HOUSE_D, {key = "diner", plaster = Color("#d9d0b8"), brick = Color("#7a3b30"), door_x = DINER_DOOR_X,
		windows = [[-4.3, -1.3], [-0.5, 1.9]], sign = "MOLLY'S DINER", sign_back = Color("#7a1f1c"), sign_color = Color("#f4e7c8"),
		floor_scan = "floor_tiles_06", floor_tile = 1.6, lining = Color("#e3dccb"), trim = Color("#7a1f1c"), lamp = Color("#ffe2b0"), strips = false})
	TownBlock.counter(self, DINER + Vector3(0, 0, COUNTER_Z), 9.4, "diner_counter", Color("#6a2a24"))
	TownBlock.shelves(self, DINER + Vector3(-1.9, 0, HOUSE_D - TownBlock.WALL - 0.24), 5.2, "diner_shelf", 5, DINER_GOODS)
	_diner_room()
	# Shut for now: the house that ends the row.
	TownBlock.closed(self, Vector3(24.3, 0, FRONT_Z), 4.6, HOUSE_D, {key = "kiosk", scan = "yellow_plaster", sign = "KIOSK"})
	# The yard wall behind the row and the walls beside the hall.
	var brick := EnvMesh.scan("town_yardwall", "red_brick_03", {foot = 0.6, drift = 0.22})
	var caps := []
	var runs := [[Vector3(0, 1.5, back_z + 0.15), Vector3(TOWN_X * 2.0, 3.0, 0.3)]]
	for s: float in [-1.0, 1.0]:
		var from := inner_max.x + WALL
		runs.append([Vector3(s * (from + TOWN_X) * 0.5, 1.2, zf - 0.15), Vector3(TOWN_X - from, 2.4, 0.3)])
	var walls := []
	for r: Array in runs:
		WorldBuilder.add_collider(self, r[1], Transform3D(Basis(), r[0]))
		walls.append(EnvMesh.piece(EnvMesh.box(r[1]), Transform3D(Basis(), r[0])))
		# A concrete coping keeps the rain out of the brickwork.
		caps.append(EnvMesh.piece(EnvMesh.box(Vector3(r[1].x + 0.06, 0.07, r[1].z + 0.1)), Transform3D(Basis(), r[0] + Vector3(0, r[1].y * 0.5 + 0.035, 0))))
	if EnvMesh.visual():
		EnvMesh.add(self, EnvMesh.merge(walls), brick)
		EnvMesh.add(self, EnvMesh.merge(caps), EnvMesh.scan("town_coping", "dirty_concrete", {tile = 1.6, tint = Vector3(0.8, 0.8, 0.8)}))
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
	_street_dressing(zf)
	# The station's desk against the back wall, a chair pushed up to it.
	var desk := POLICE + Vector3(-2.9, 0, HOUSE_D - TownBlock.WALL - 0.52)
	PhotoProp.place(self, "metal_office_desk", desk, 180.0)
	PhotoProp.place(self, "plastic_monobloc_chair_01", desk + Vector3(0.2, 0, -0.75), 10.0, false)
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
	for z: float in [1.1, 2.3]:
		PhotoProp.place(self, "painted_wooden_bench", POLICE + Vector3(-3.9, 0, z), 90.0, false)
	# On the counters: the till and an oil lamp at the pawnbroker's, the day's paperwork at the station.
	var top := 1.03
	PhotoProp.stand(self, "CashRegister_01", PAWN + Vector3(2.5, top, COUNTER_Z + 0.05), 0.0)
	PhotoProp.stand(self, "vintage_oil_lamp", PAWN + Vector3(-3.2, top, COUNTER_Z + 0.1), 25.0)
	PhotoProp.stand(self, "clipboard", POLICE + Vector3(1.7, top, COUNTER_Z - 0.05), 200.0)
	# (The scan of the laptop is twice life size.)
	PhotoProp.stand(self, "classic_laptop", POLICE + Vector3(-2.9, top, COUNTER_Z + 0.05), 15.0, 0.5)


## The diner's room: a chequered floor and tiled walls, stools at the counter and two tables by the
## windows, lamps hanging over the counter, the stove and a worktop behind it, cake and coffee on it,
## the day's menu on a blackboard, and Molly behind it all.
func _diner_room() -> void:
	var top := 1.03
	var back := HOUSE_D - TownBlock.WALL
	var side := 5.0 - TownBlock.WALL
	var wood := Color("#6a2a24")
	# What is solid first (colliders are wanted on a headless host too).
	for x: float in [-4.2, -3.25, -2.3, -1.35]:
		PhotoProp.place(self, "bar_chair_round_01", DINER + Vector3(x, 0, COUNTER_Z - 0.62), 180.0 + x * 9.0)
	PhotoProp.place(self, "electric_stove", DINER + Vector3(2.9, 0, back - 0.38), 180.0)
	TownBlock.counter(self, DINER + Vector3(1.6, 0, back - 0.37), 1.5, "diner_counter", wood)
	TownBlock.counter(self, DINER + Vector3(4.0, 0, back - 0.37), 1.2, "diner_counter", wood)
	for table: float in DINER_TABLES:
		WorldBuilder.add_collider(self, Vector3(0.9, 0.78, 0.9), Transform3D(Basis(), DINER + Vector3(table, 0.39, 1.25)))
		PhotoProp.place(self, "painted_wooden_chair_01", DINER + Vector3(table - 0.95, 0, 1.3), 90.0)
		PhotoProp.place(self, "painted_wooden_chair_01", DINER + Vector3(table + 0.95, 0, 1.2), -95.0)
	PhotoProp.place(self, "standing_chalkboard_01", DINER + DINER_SIGN, 170.0)
	if not EnvMesh.visual():
		return
	# Tiles up to the shoulder on the back and side walls, a painted rail on top.
	var tiles := EnvMesh.scan("diner_tiles", "long_white_tiles", {drift = 0.06})
	var rail := EnvMesh.wood("town_trim_diner", {})
	var tiled := []
	var rails := []
	var up := 1.42
	tiled.append(EnvMesh.piece(EnvMesh.box(Vector3(side * 2.0, up, 0.02)), Transform3D(Basis(), DINER + Vector3(0, up * 0.5, back - 0.04))))
	rails.append(EnvMesh.piece(EnvMesh.box(Vector3(side * 2.0, 0.07, 0.04)), Transform3D(Basis(), DINER + Vector3(0, up + 0.035, back - 0.05))))
	for s: float in [-1.0, 1.0]:
		tiled.append(EnvMesh.piece(EnvMesh.box(Vector3(0.02, up, back - TownBlock.WALL)), Transform3D(Basis(), DINER + Vector3(s * (side - 0.04), up * 0.5, (back + TownBlock.WALL) * 0.5))))
		rails.append(EnvMesh.piece(EnvMesh.box(Vector3(0.04, 0.07, back - TownBlock.WALL)), Transform3D(Basis(), DINER + Vector3(s * (side - 0.05), up + 0.035, (back + TownBlock.WALL) * 0.5))))
	EnvMesh.add(self, EnvMesh.merge(tiled), tiles)
	EnvMesh.add(self, EnvMesh.merge(rails), rail)
	# (The scan of the round table is a standing table of a metre: here it is one to sit at.)
	for table: float in DINER_TABLES:
		PhotoProp.stand(self, "round_wooden_table_01", DINER + Vector3(table, 0, 1.25), 20.0 + table * 30.0, 0.75)
	PhotoProp.stand(self, "croissant", DINER + Vector3(DINER_TABLES[0] + 0.15, 0.752, 1.15), 40.0)
	PhotoProp.stand(self, "jug_01", DINER + Vector3(DINER_TABLES[1] - 0.1, 0.752, 1.3), 120.0)
	# Along the counter, from the till: the coffee, the two places to order with their cards, the stew, cake and rolls.
	PhotoProp.stand(self, "CashRegister_01", DINER + Vector3(4.05, top, COUNTER_Z + 0.05), 0.0)
	PhotoProp.stand(self, "vintage_electric_kettle", DINER + Vector3(3.42, top, COUNTER_Z + 0.12), 200.0)
	_table_card(DINER + Vector3(DINER_COFFEE_X, top, COUNTER_Z - 0.2), "COFFEE", "4 $")
	_table_card(DINER + Vector3(DINER_MEAL_X, top, COUNTER_Z - 0.2), "HOT STEW", "12 $")
	PhotoProp.stand(self, "pot_enamel_01", DINER + Vector3(DINER_MEAL_X - 0.42, top, COUNTER_Z + 0.1), 30.0)
	PhotoProp.stand(self, "carrot_cake", DINER + Vector3(0.35, top, COUNTER_Z + 0.08), 0.0)
	PhotoProp.stand(self, "croissant", DINER + Vector3(-1.5, top, COUNTER_Z - 0.05), 70.0)
	PhotoProp.stand(self, "croissant", DINER + Vector3(-1.72, top, COUNTER_Z + 0.08), 15.0)
	PhotoProp.stand(self, "hamburger_buns", DINER + Vector3(-2.9, top, COUNTER_Z + 0.05), 0.0)
	PhotoProp.stand(self, "potted_plant_04", DINER + Vector3(-4.3, top, COUNTER_Z + 0.05), 40.0)
	# Behind the counter: the stew and a pan on the stove (its top is 0.86 m up), the worktop with
	# the coffee jug and the day's baking, the microwave on the cupboard.
	PhotoProp.stand(self, "pot_enamel_01", DINER + Vector3(2.75, 0.862, back - 0.42), 10.0)
	PhotoProp.stand(self, "brass_pan_01", DINER + Vector3(3.1, 0.862, back - 0.3), 150.0)
	PhotoProp.stand(self, "jug_01", DINER + Vector3(1.15, top, back - 0.34), 200.0)
	PhotoProp.stand(self, "hamburger_buns", DINER + Vector3(1.75, top, back - 0.36), 90.0)
	PhotoProp.stand(self, "croissant", DINER + Vector3(2.15, top, back - 0.28), 130.0)
	PhotoProp.stand(self, "vintage_microwave", DINER + Vector3(4.0, top, back - 0.34), 180.0)
	# Lamps hang over the counter (the house has no strip lights), a strip lights the tables.
	for x: float in [-3.6, -1.2, 1.2, 3.6]:
		PhotoProp.hang(self, "hanging_industrial_lamp", DINER + Vector3(x, TownBlock.ROOM_H, COUNTER_Z), x * 40.0)
	for x: float in [-2.4, 2.4]:
		var glow := OmniLight3D.new()
		glow.light_color = Color("#ffd9a0")
		glow.light_energy = 1.3
		glow.omni_range = 4.5
		glow.omni_attenuation = 1.2
		glow.shadow_enabled = false
		glow.position = DINER + Vector3(x, 2.0, COUNTER_Z - 0.2)
		add_child(glow)
	TownBlock.strip_light(self, DINER + Vector3(-1.5, TownBlock.ROOM_H - 0.02, 1.5), Color("#fff1d6"))
	# On the walls: the clock and a painting over the tables, darts by the door, a painting behind the counter.
	PhotoProp.mount(self, "wall_clock", DINER + Vector3(-side + 0.03, 2.2, 0.95), Vector3.RIGHT)
	PhotoProp.mount(self, "fancy_picture_frame_01", DINER + Vector3(-side + 0.03, 1.62, 2.05), Vector3.RIGHT)
	PhotoProp.mount(self, "hanging_picture_frame_02", DINER + Vector3(-side + 0.03, 1.7, 5.0), Vector3.RIGHT)
	PhotoProp.mount(self, "dartboard", DINER + Vector3(side - 0.03, 1.5, 1.75), Vector3.LEFT)
	var cook := TownNpc.make("Cook")
	cook.position = DINER + Vector3(DINER_COOK_X, 0, COUNTER_Z + 1.1)
	cook.rotation.y = PI
	add_child(cook)
	# The day's menu in chalk on a blackboard behind the counter.
	var board := DINER + Vector3(2.2, 2.3, back - 0.045)
	var slate := StandardMaterial3D.new()
	slate.albedo_color = Color("#1b2420")
	slate.roughness = 0.92
	EnvMesh.add(self, EnvMesh.box(Vector3(2.3, 1.08, 0.03)), slate, Transform3D(Basis(), board), false)
	var frame := []
	for s: float in [-1.0, 1.0]:
		frame.append(EnvMesh.piece(EnvMesh.box(Vector3(0.06, 1.2, 0.05)), Transform3D(Basis(), board + Vector3(s * 1.18, 0, -0.005))))
		frame.append(EnvMesh.piece(EnvMesh.box(Vector3(2.42, 0.06, 0.05)), Transform3D(Basis(), board + Vector3(0, s * 0.57, -0.005))))
	frame.append(EnvMesh.piece(EnvMesh.box(Vector3(2.3, 0.025, 0.09)), Transform3D(Basis(), board + Vector3(0, -0.6, -0.04))))
	EnvMesh.add(self, EnvMesh.merge(frame), EnvMesh.wood("diner_board_frame", {base_color = Color("#6b4a2f"), grain_color = Color("#3a2617"), weathering = 0.3, roughness_base = 0.6}))
	var wall := Transform3D(Basis(Vector3.UP, PI), board + Vector3(0, 0, -0.022))
	var chalk := Color(0.95, 0.93, 0.86)
	StationKit.label(self, "TODAY", wall * Transform3D(Basis(), Vector3(0, 0.36, 0)), 96, Color("#f0c05a"), 700, 0.0028, StationKit.chalk_font())
	StationKit.label(self, "COFFEE · 4 $", wall * Transform3D(Basis(), Vector3(0, 0.1, 0)), 78, chalk, 700, 0.0028, StationKit.chalk_font())
	StationKit.label(self, "HOT STEW · 12 $", wall * Transform3D(Basis(), Vector3(0, -0.15, 0)), 78, chalk, 700, 0.0028, StationKit.chalk_font())
	StationKit.label(self, "one order treats the whole crew", wall * Transform3D(Basis(), Vector3(0, -0.38, 0)), 44, chalk, 500, 0.0028, StationKit.hand_font())
	StationKit.label(self, "HOME COOKING · ALL DAY", Transform3D(Basis(Vector3.UP, PI), DINER + Vector3(-1.9, 2.72, back - 0.04)), 80, Color("#7a1f1c"), 700, 0.0032)
	# The board on the pavement by the door.
	var face := Transform3D(Basis(Vector3.UP, deg_to_rad(170.0)), DINER + DINER_SIGN) * Transform3D(Basis(Vector3.RIGHT, -0.21), Vector3(0.0, 0.88, 0.188))
	StationKit.label(self, "OPEN", face * Transform3D(Basis(), Vector3(0, 0.34, 0)), 112, Color(0.95, 0.82, 0.4, 0.92), 700, 0.0022, StationKit.chalk_font())
	StationKit.label(self, "COFFEE 4 $", face * Transform3D(Basis(), Vector3(0, 0.1, 0)), 72, Color(chalk, 0.92), 700, 0.0022, StationKit.chalk_font())
	StationKit.label(self, "HOT STEW 12 $", face * Transform3D(Basis(), Vector3(0, -0.1, 0)), 62, Color(chalk, 0.92), 700, 0.0022, StationKit.chalk_font())
	StationKit.label(self, "come in!", face * Transform3D(Basis(), Vector3(0, -0.3, 0)), 56, Color(chalk, 0.92), 500, 0.0022, StationKit.hand_font())
	# The awning over the two windows: striped cloth on two iron arms.
	var stripes := Image.create(2, 1, false, Image.FORMAT_RGB8)
	stripes.set_pixel(0, 0, Color("#a3221d"))
	stripes.set_pixel(1, 0, Color("#efe6d2"))
	var cloth := StandardMaterial3D.new()
	cloth.albedo_texture = ImageTexture.create_from_image(stripes)
	cloth.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	cloth.roughness = 0.92
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	var span := Vector2(-4.55, 2.15)
	var width := span.y - span.x
	var reach := 0.9
	var drop := 0.42
	var slope := Vector2(reach, drop).length()
	var top_y := 2.78
	var mid_x := (span.x + span.y) * 0.5
	var tilt := Basis(Vector3.RIGHT, -atan2(drop, reach))
	cloth.uv1_scale = Vector3(width / 0.5, 1.0, 1.0)
	var sheet := PlaneMesh.new()
	sheet.size = Vector2(width, slope)
	EnvMesh.add(self, sheet, cloth, Transform3D(tilt, DINER + Vector3(mid_x, top_y - drop * 0.5, -reach * 0.5)))
	var skirt := PlaneMesh.new()
	skirt.size = Vector2(width, 0.2)
	EnvMesh.add(self, skirt, cloth, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), DINER + Vector3(mid_x, top_y - drop - 0.1, -reach)))
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color("#2a2a2c")
	iron.roughness = 0.6
	iron.metallic = 0.6
	for x: float in [span.x + 0.02, span.y - 0.02]:
		EnvMesh.add(self, EnvMesh.box(Vector3(0.03, 0.03, slope)), iron, Transform3D(tilt, DINER + Vector3(x, top_y - drop * 0.5 - 0.025, -reach * 0.5)))


## A folded card on a counter at `at` (the middle of its foot), facing the customers: what is ordered
## here and what it costs.
func _table_card(at: Vector3, title: String, price: String) -> void:
	var size := Vector2(0.3, 0.19)
	var card := Transform3D(Basis(Vector3.UP, PI), at) * Transform3D(Basis(Vector3.RIGHT, -0.26), Vector3(0, size.y * 0.5, 0))
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color("#efe6cf")
	paper.roughness = 0.85
	EnvMesh.add(self, EnvMesh.box(Vector3(size.x, size.y, 0.006)), paper, card, false)
	# Its back leg.
	EnvMesh.add(self, EnvMesh.box(Vector3(size.x, size.y, 0.006)), paper,
		Transform3D(Basis(Vector3.UP, PI), at) * Transform3D(Basis(Vector3.RIGHT, 0.26), Vector3(0, size.y * 0.5, -0.05)), false)
	var ink := Color("#7a1f1c")
	StationKit.label(self, title, card * Transform3D(Basis(), Vector3(0, 0.042, 0.005)), 64, ink, 700, 0.0006)
	StationKit.label(self, price, card * Transform3D(Basis(), Vector3(0, -0.04, 0.005)), 84, ink, 800, 0.0006)


## What stands and hangs about the street: a van and three cars (ParkedVehicle), three trees and, all scanned
## (Poly Haven, CC0), bins and bags, a switch box, a bench, a car under a tarpaulin, the dealer's
## chalkboard, a barrel stove with cans, concrete blocks where the street ends, manhole covers, a lamp
## over the pawnbroker's door and air conditioners on the fronts.
func _street_dressing(zf: float) -> void:
	var road_z := zf + APRON + ROAD * 0.5
	# What is solid comes first: its colliders are wanted on a headless host too.
	PhotoProp.place(self, "metal_trash_can", Vector3(-6.2, 0, FRONT_Z - 0.55), 180.0)
	PhotoProp.place(self, "utility_box_01", Vector3(11.9, 0, FRONT_Z - 0.4), 180.0)
	PhotoProp.place(self, "painted_wooden_bench", Vector3(14.0, 0, FRONT_Z - 0.4), 180.0)
	PhotoProp.place(self, "covered_car", Vector3(18.4, 0, zf + 1.3), 90.0)
	# Parked at the far kerb, noses the way the street runs (the truck's lane stays free): a delivery
	# van, a small saloon and a big one. An estate car stands on the apron.
	var kerb := zf + APRON + ROAD - 0.15
	# (The van stands clear of the diner's door and its right window.)
	ParkedVehicle.place(self, ParkedVehicle.VAN, Vector3(-23.3, 0, kerb - 1.15), 0.0)
	ParkedVehicle.place(self, ParkedVehicle.CAR_SMALL, Vector3(13.4, 0, kerb - 0.9), 0.0)
	ParkedVehicle.place(self, ParkedVehicle.CAR_SALOON, Vector3(21.2, 0, kerb - 0.93), 0.0, Color("#1f2c47"))
	ParkedVehicle.place(self, ParkedVehicle.CAR_ESTATE, Vector3(24.1, 0, zf + 1.55), 180.0, Color("#b7ab8c"))
	# Trees along the far pavement, a step in from the kerb (clear of doors, lamps and the dealer's front).
	TownBlock.street_tree(self, Vector3(-25.3, 0, kerb + 0.95), 20.0, 1.0)
	TownBlock.street_tree(self, Vector3(-8.7, 0, kerb + 0.95), 150.0, 0.92)
	TownBlock.street_tree(self, Vector3(12.7, 0, kerb + 0.95), 260.0, 1.06)
	# The dealer's board on the pavement, and what stands about on the yard side.
	var board := Vector3(-2.5, 0, FRONT_Z - 0.8)
	PhotoProp.place(self, "standing_chalkboard_01", board, 196.0)
	PhotoProp.place(self, "barrel_stove", Vector3(15.1, 0, zf + 0.75), 40.0)
	if not EnvMesh.visual():
		return
	var chalk := Color(0.93, 0.92, 0.87, 0.92)
	# Chalk on the board's street side: its slate leans back by 12 degrees and is 0.77 m wide.
	var face := Transform3D(Basis(Vector3.UP, deg_to_rad(196.0)), board) * Transform3D(Basis(Vector3.RIGHT, -0.21), Vector3(0.0, 0.88, 0.188))
	StationKit.label(self, "WE BUY", face * Transform3D(Basis(), Vector3(0, 0.36, 0)), 84, chalk, 700, 0.0022, StationKit.chalk_font())
	StationKit.label(self, "SCRAP", face * Transform3D(Basis(), Vector3(0, 0.14, 0)), 112, chalk, 700, 0.0022, StationKit.chalk_font())
	StationKit.label(self, "copper & brass", face * Transform3D(Basis(), Vector3(0, -0.1, 0)), 44, chalk, 500, 0.0022, StationKit.hand_font())
	StationKit.label(self, "cash paid", face * Transform3D(Basis(), Vector3(0, -0.3, 0)), 56, Color(0.95, 0.82, 0.4, 0.92), 500, 0.0022, StationKit.hand_font())
	PhotoProp.place(self, "metal_jerrycan_green", Vector3(15.75, 0, zf + 0.5), 110.0, false)
	PhotoProp.place(self, "plastic_crate_02", Vector3(14.75, 0, zf + 0.42), 8.0, false)
	PhotoProp.stand(self, "oil_tin", Vector3(14.62, 0.03, zf + 0.42), 60.0)
	PhotoProp.stand(self, "small_oil_can_01", Vector3(14.85, 0.03, zf + 0.42), 100.0)
	for s: float in [-1.0, 1.0]:
		PhotoProp.place(self, "concrete_road_barrier", Vector3(s * (TOWN_X + 0.9), 0, zf + 1.5), 90.0, false)
		PhotoProp.place(self, "concrete_road_barrier", Vector3(s * (TOWN_X + 0.9), 0, FRONT_Z - 2.0), 90.0, false)
	PhotoProp.place(self, "trashbag", Vector3(-5.2, 0, FRONT_Z - 0.4), 40.0, false)
	PhotoProp.place(self, "trashbag", Vector3(-15.7, 0, FRONT_Z - 0.4), 200.0, false)
	PhotoProp.place(self, "trashbag", Vector3(-15.25, 0, FRONT_Z - 0.55), 75.0, false)
	PhotoProp.place(self, "water_manhole_cover", Vector3(-7.5, 0.021, road_z + 0.9), 0.0, false)
	PhotoProp.place(self, "water_manhole_cover", Vector3(11.0, 0.021, road_z - 1.1), 30.0, false)
	PhotoProp.mount(self, "industrial_wall_lamp", Vector3(PAWN.x - 2.6, TownBlock.DOOR_H + 0.1, FRONT_Z), Vector3.FORWARD)
	PhotoProp.mount(self, "exterior_aircon_unit:0", Vector3(PAWN.x + 3.0, 2.75, FRONT_Z), Vector3.FORWARD)
	PhotoProp.mount(self, "industrial_wall_lamp", Vector3(DINER.x + DINER_DOOR_X, TownBlock.DOOR_H + 0.1, FRONT_Z), Vector3.FORWARD)


## The dealer's shop: a small brick building with an open counter, an awning
## and a painted sign. The ScrapShop station (the bin) stands in front of it.
func _shop(base: Vector3) -> void:
	var brick := EnvMesh.scan("shop_brick", "red_brick", {foot = 0.5})
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
	if EnvMesh.visual():
		# Kowalski behind his counter, looking out at the street.
		var dealer := TownNpc.make("Dealer")
		dealer.position = base + Vector3(-1.1, 0, 2.25)
		dealer.rotation.y = PI
		add_child(dealer)
