class_name BellHallSet
extends GarageSet
## Level 3 set: the old bell foundry, a tall hall of factory brick, limewashed above the shoulder,
## with timber posts under a boarded roof, a brick floor, a workshop window and a church of
## sandstone across the square (photo scans throughout, TECH_SPEC Modul Y). The front stands open
## like the garage's.
## Dressing: a wooden bell frame with three display bells (cast from the same
## BellProfile meshes), sacks of loam, strickle boards and lamps on the posts.

const FRAME_POS := Vector3(-6.2, 0.0, 3.4)


static func build_hall(world: Node3D, level_stations: Array) -> BellHallSet:
	var set := BellHallSet.new()
	set.name = "BellHallSet"
	set.key = "bellhall"
	set.wall_split = 1.5
	# (The brick of the floor is dark out of the sun: lifted a little, so small things on it show.)
	set.floor_tint = Vector3(1.3, 1.3, 1.3)
	set.ground_size = Vector2(90.0, 84.0)
	set.ground_z = 12.0
	set.stations = level_stations
	set.inner_min = Vector2(-8.0, -5.6)
	set.inner_max = Vector2(8.0, 5.4)
	set.height = 4.4
	set.window = Vector4(-2.2, 2.2, 1.7, 3.8)
	set.bay_line_x = -100.0
	# Rammed loam floor of an old foundry instead of garage concrete.
	set.floor_params = {concrete = Color("#8a7660"), concrete_dark = Color("#6a5946"), paver = Color("#8c8479")}
	world.add_child(set)
	set._build()
	return set


## Factory brick to the shoulder, limewashed brick above, weathered roof boards overhead; the timber
## is oak. (All brick and dark boards made the hall a cave: lime and pale wood give the light back.)
func _materials() -> void:
	_wall_low_mat = EnvMesh.scan("bellhall_plinth", "factory_brick", {foot = 0.5, drift = 0.18})
	_wall_high_mat = EnvMesh.scan("bellhall_wall", "painted_worn_brick", {drift = 0.14, tint = EnvMesh.toward("painted_worn_brick", Color("#d8cfba"), 0.7)})
	_wall_mat = _wall_high_mat
	_roof_mat = EnvMesh.repainted("bellhall_roof", "roof_planks", Color("#9c8b74"), {drift = 0.1})
	_trim_mat = EnvMesh.wood("bellhall_trim", {base_color = Color("#6d4c32"), grain_color = Color("#3f2b1c"),
		weathering = 0.35, roughness_base = 0.8})


## An old floor of brick laid on edge.
func _floor_scan() -> String:
	return "double_brick_floor"


func _extra_stains() -> PackedVector4Array:
	var out := PackedVector4Array()
	for s in stations:
		if s is BellPit:
			var p := (s as Node3D).position
			out.append(Vector4(p.x, p.z, (s as BellPit).outer_radius() + 0.7, 2.0))
	out.append(Vector4(FRAME_POS.x + 0.4, FRAME_POS.z, 0.8, 3.0))
	return out


func _sign() -> void:
	StationKit.label(self, "GLOCKENGIESSEREI · SEIT 1887", Transform3D(Basis(), Vector3(0.0, window.w + 0.3, inner_min.y + 0.012)), 120,
		Color("#5b2f22"), 800, 0.0018)


func _dressing() -> void:
	_timber_posts()
	_bell_frame(FRAME_POS)
	_loam_sacks(Vector3(-7.3, 0, 2.0))
	_strickle_boards(Vector3(inner_max.x - 0.1, 0, -4.4))
	PhotoProp.place(self, "hand_truck", Vector3(-4.6, 0, 1.2), 150.0)
	prop("kaykit_dungeon/barrel_large.gltf", Vector3(7.3, 0, 3.4), 10.0, {solid = PropKit.Solid.CYLINDER, tint = Color("#a99f94")})
	# Crates in the corner by the scrap.
	WorldBuilder.add_collider(self, Vector3(0.9, 1.05, 0.5), Transform3D(Basis(Vector3.UP, deg_to_rad(20.0)), Vector3(-7.1, 0.525, -4.7)))
	for i in 3:
		PhotoProp.stand(self, "wooden_crate_01", Vector3(-7.1, i * 0.35, -4.7), 20.0 + i * 7.0)
	_lamps()


## Timber posts along the side walls and the back, carrying the (shadow-only) roof.
func _timber_posts() -> void:
	var posts := []
	for x in [-4.0, 0.0, 4.0]:
		posts.append(Vector3(x, 0, inner_min.y + 0.14))
	for z in [-2.0, 1.6]:
		posts.append(Vector3(inner_min.x + 0.14, 0, z))
		posts.append(Vector3(inner_max.x - 0.14, 0, z))
	var pieces := []
	for p: Vector3 in posts:
		pieces.append(EnvMesh.piece(EnvMesh.box(Vector3(0.24, height, 0.24), 0.02), Transform3D(Basis(), p + Vector3(0, height * 0.5, 0))))
		WorldBuilder.add_collider(self, Vector3(0.24, height, 0.24), Transform3D(Basis(), p + Vector3(0, height * 0.5, 0)))
	EnvMesh.add(self, EnvMesh.merge(pieces), _trim_mat)


## Oak bell frame: two A-trestles, a yoke beam and three bells hanging in it.
func _bell_frame(base: Vector3) -> void:
	WorldBuilder.add_collider(self, Vector3(1.2, 2.8, 3.2), Transform3D(Basis(), base + Vector3(0, 1.4, 0)))
	if not EnvMesh.visual():
		return
	var oak := EnvMesh.wood("bell_frame", {base_color = Color("#5e4230"), grain_color = Color("#3a281b"), weathering = 0.3})
	var beams := []
	for s: float in [-1.4, 1.4]:
		for lean: float in [-0.25, 0.25]:
			beams.append(EnvMesh.piece(EnvMesh.box(Vector3(0.16, 2.9, 0.16), 0.02),
				Transform3D(Basis(Vector3.BACK, lean), base + Vector3(lean * 1.3, 1.4, s))))
		beams.append(EnvMesh.piece(EnvMesh.box(Vector3(1.4, 0.16, 0.18), 0.02), Transform3D(Basis(), base + Vector3(0, 0.5, s))))
	beams.append(EnvMesh.piece(EnvMesh.box(Vector3(0.22, 0.24, 3.2), 0.02), Transform3D(Basis(), base + Vector3(0, 2.78, 0))))
	EnvMesh.add(self, EnvMesh.merge(beams), oak)
	var profile := BellProfile.from_drawing(DrawingSamples.bell())
	var bronze := MetalMaterial.create(&"bronze", 7)
	bronze.set_shader_parameter(&"crust", 0.0)
	var patina := MetalMaterial.create(&"brass", 11)
	patina.set_shader_parameter(&"crust", 0.0)
	var iron := StationKit.metal("frame_iron", {steel_color = Color("#3b3937"), rust = 0.6})
	for i in 3:
		var r: float = [0.22, 0.32, 0.27][i]
		var z: float = [-1.0, 0.05, 1.05][i]
		var h := profile.height(r)
		var top := 2.62
		var mat: Material = patina if i == 1 else bronze
		EnvMesh.add(self, profile.mesh(r, 28), mat, Transform3D(Basis(), base + Vector3(0, top - h - 0.06, z)))
		EnvMesh.add(self, EnvMesh.box(Vector3(0.06, 0.12, 0.08), 0.01), iron, Transform3D(Basis(), base + Vector3(0, top - 0.02, z)))


## Sacks of loam for the molds, piled by the wall (scans).
func _loam_sacks(base: Vector3) -> void:
	WorldBuilder.add_collider(self, Vector3(1.5, 0.56, 0.8), Transform3D(Basis(), base + Vector3(0, 0.28, 0)))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 7:
		var row := i / 3
		var at := base + Vector3((i % 3) * 0.5 - 0.5 + row * 0.13, row * 0.175, rng.randf_range(-0.05, 0.05))
		PhotoProp.stand(self, "cement_bag", at, rng.randf_range(-12.0, 12.0))


## Old strickle boards leaning on the right wall: bell profiles in wood.
func _strickle_boards(base: Vector3) -> void:
	if not EnvMesh.visual():
		return
	var wood := EnvMesh.wood("old_strickle", {base_color = Color("#a8825a"), weathering = 0.5})
	var profile := BellProfile.from_drawing(DrawingSamples.bell())
	for i in 3:
		var r := 0.3 + i * 0.12
		var outline := profile.outline(r)
		var pts := PackedVector3Array()
		for p in outline:
			pts.append(Vector3(0, p.y + 0.05, -p.x))
		var board := EnvMesh.add(self, StationKit.ribbon(pts, 0.03), wood,
			Transform3D(Basis(Vector3.FORWARD, -0.18), base + Vector3(-0.08 - i * 0.07, 0, i * 0.55)))
		if board:
			board.scale = Vector3(1, 1, 1)


func _lamps() -> void:
	if not EnvMesh.visual():
		return
	# Caged lamps on the timber posts (scans). By day they only warm the corners.
	for spot: Array in [[Vector3(-4.0, 2.5, inner_min.y + 0.27), Vector3.BACK], [Vector3(4.0, 2.5, inner_min.y + 0.27), Vector3.BACK],
			[Vector3(inner_min.x + 0.27, 2.5, -2.0), Vector3.RIGHT], [Vector3(inner_max.x - 0.27, 2.5, 1.6), Vector3.LEFT]]:
		var at: Vector3 = spot[0]
		var out: Vector3 = spot[1]
		PhotoProp.mount(self, "industrial_wall_lamp", at, out)
		var l := OmniLight3D.new()
		l.light_color = Color("#ffc890")
		l.light_energy = 0.9
		l.omni_range = 6.0
		l.omni_attenuation = 1.2
		l.position = at + out * 0.35 + Vector3(0, 0.15, 0)
		add_child(l)


func _outside() -> void:
	var zf := inner_max.y + WALL * 0.5
	if EnvMesh.visual():
		# Photographed ground: old slabs on the square, worn concrete beside and behind the hall.
		var half := ground_size.x * 0.5
		var back := ground_z - ground_size.y * 0.5
		var front := ground_z + ground_size.y * 0.5
		var out_x := inner_max.x + WALL
		var yard := EnvMesh.scan(key + "_yard", "dirty_concrete", {drift = 0.2})
		_slab(EnvMesh.scan(key + "_square", "concrete_tiles_02", {drift = 0.16}), -half, half, zf, front)
		_slab(yard, -half, -out_x, back, zf)
		_slab(yard, out_x, half, back, zf)
		_slab(yard, -out_x, out_x, back, inner_min.y - WALL)
	# The town church across the square, for which the bells are cast: a stone tower with a slated spire
	# before a rendered nave. It stands to the right of the gate with its length running away from the
	# hall: the sun comes from the left, so the long flank is lit and the tower shows a lit and a shaded side.
	ChurchKit.church(self, Vector3(7.0, 0, zf + 16.0), {key = key + "_church"})
	TownBlock.street_tree(self, Vector3(-6.0, 0, zf + 19.0), 40.0, 1.1)
	TownBlock.street_tree(self, Vector3(-11.5, 0, zf + 24.5), 190.0, 0.95)
	# The houses round the square and behind the hall.
	TownBlock.block(self, Vector3(-22.0, 0, zf + 6.0), 11.0, 14.0, {key = key + "_n1", scan = "red_brick", storeys = 3})
	TownBlock.block(self, Vector3(23.0, 0, zf + 6.0), 11.0, 14.0, {key = key + "_n2", scan = "yellow_plaster", storeys = 3})
	TownBlock.block(self, Vector3(24.0, 0, zf + 24.0), 14.0, 9.0, {key = key + "_n3", scan = "painted_worn_brick", storeys = 3})
	TownBlock.block(self, Vector3(-24.0, 0, zf + 26.0), 12.0, 9.0, {key = key + "_n4", scan = "yellow_plaster", storeys = 4})
	TownBlock.block(self, Vector3(-13.0, 0, -22.0), 12.0, 8.0, {key = key + "_n5", scan = "red_brick_03", storeys = 3})
	TownBlock.block(self, Vector3(12.0, 0, -21.5), 12.0, 8.0, {key = key + "_n6", scan = "red_brick", storeys = 3})
	TownBlock.block(self, Vector3(-8.5, 0, zf + 30.0), 13.0, 9.0, {key = key + "_n7", scan = "red_brick", storeys = 3})
	prop("kaykit_city/streetlight.gltf", Vector3(-6.5, 0, zf + 5.0), 0.0, {scale = 0.95, solid = PropKit.Solid.CYLINDER})
	prop("kaykit_city/streetlight.gltf", Vector3(7.5, 0, zf + 5.0), 180.0, {scale = 0.95, solid = PropKit.Solid.CYLINDER})
	for i in 6:
		prop("kaykit_city/bush.gltf", Vector3(inner_min.x - 0.6, 0, zf + 0.5 + i * 0.9), i * 40.0, {scale = 1.1, solid = PropKit.Solid.NONE})
		prop("kaykit_city/bush.gltf", Vector3(inner_max.x + 0.6, 0, zf + 0.5 + i * 0.9), i * 55.0, {scale = 1.1, solid = PropKit.Solid.NONE})
	# The yard before the hall: brick walls and the foundry's iron gate to the square.
	_forecourt(8.2, 1.2, true)
