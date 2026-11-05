class_name BellHallSet
extends GarageSet
## Level 3 set: the old bell foundry, a tall brick hall with timber posts,
## an arched workshop window and a church tower across the square. Same
## dollhouse rules as the garage (open front, shadow-only roof, cutaway walls).
## Dressing: a wooden bell frame with three display bells (cast from the same
## BellProfile meshes), loam sacks, strickle boards and warm lanterns.

const FRAME_POS := Vector3(-6.2, 0.0, 3.4)


static func build_hall(world: Node3D, level_stations: Array) -> BellHallSet:
	var set := BellHallSet.new()
	set.name = "BellHallSet"
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


func _materials() -> void:
	_wall_mat = EnvMesh.material("bellhall_wall", "res://shaders/env_plaster.gdshader", {
		plaster = Color("#cdb99c"), grime = Color("#655a50"), brick = Color("#9a5440"), mortar = Color("#bfae95"),
		chips = 0.8, streaks = 0.45, cutaway = true, brick_below = 1.5})
	_trim_mat = EnvMesh.wood("bellhall_trim", {base_color = Color("#6d4c32"), grain_color = Color("#3f2b1c"),
		weathering = 0.35, roughness_base = 0.8})


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
	prop("kaykit_hexagon/wheelbarrow.gltf", Vector3(-4.6, 0, 1.2), 60.0, {scale = 0.9})
	prop("kaykit_dungeon/barrel_large.gltf", Vector3(7.3, 0, 3.4), 10.0, {solid = PropKit.Solid.CYLINDER, tint = Color("#a99f94")})
	prop("kaykit_dungeon/crates_stacked.gltf", Vector3(-7.1, 0, -4.7), 20.0, {scale = 0.75})
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


func _loam_sacks(base: Vector3) -> void:
	var sack := EnvMesh.surface("loam_sack", {base_color = Color("#b9a27c"), roughness_base = 0.95, macro = 0.15, contact_dark = 0.3})
	var pieces := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 7:
		var p := base + Vector3((i % 3) * 0.42 - 0.4, 0.17 + (i / 3) * 0.26, rng.randf_range(-0.1, 0.1))
		pieces.append(EnvMesh.piece(EnvMesh.box(Vector3(0.4, 0.24, 0.62), 0.09), Transform3D(Basis(Vector3.UP, rng.randf_range(-0.3, 0.3)), p)))
	EnvMesh.add(self, EnvMesh.merge(pieces), sack)
	WorldBuilder.add_collider(self, Vector3(1.3, 0.8, 0.8), Transform3D(Basis(), base + Vector3(0, 0.4, 0)))


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
	# Warm lanterns on the timber posts and a cool window light.
	var bulb := EnvMesh.material("hall_bulb", "res://shaders/env_bulb.gdshader", {energy = 2.4})
	for p: Vector3 in [Vector3(-4.0, 2.6, inner_min.y + 0.32), Vector3(4.0, 2.6, inner_min.y + 0.32),
			Vector3(inner_min.x + 0.32, 2.6, -2.0), Vector3(inner_max.x - 0.32, 2.6, 1.6)]:
		EnvMesh.add(self, EnvMesh.sphere(0.1, 10, 6), bulb, Transform3D(Basis(), p), false)
		var l := OmniLight3D.new()
		l.light_color = Color("#ffb877")
		l.light_energy = 1.3
		l.omni_range = 7.0
		l.omni_attenuation = 1.2
		l.position = p + Vector3(0, -0.1, 0)
		l.shadow_enabled = p.x < -3.0 and not EnvQuality.disabled("shadows")
		add_child(l)
	for p: Vector3 in [Vector3(-2.5, 4.0, 0.0), Vector3(2.5, 4.0, 0.0)]:
		var fill := OmniLight3D.new()
		fill.light_color = Color("#ffe1bf")
		fill.light_energy = 0.8
		fill.omni_range = 9.0
		fill.position = p
		add_child(fill)
	var window_light := SpotLight3D.new()
	window_light.light_color = Color("#b9c4ff")
	window_light.light_energy = 2.0
	window_light.spot_range = 9.0
	window_light.spot_angle = 35.0
	window_light.position = Vector3(0, window.w, inner_min.y - 0.5)
	window_light.rotation_degrees = Vector3(-35, 180, 0)
	add_child(window_light)


func _outside() -> void:
	var zf := inner_max.y + WALL * 0.5
	# Church across the square: nave, tower with a pointed spire and a louvre.
	if EnvMesh.visual():
		var stone := EnvMesh.material("church_stone", "res://shaders/env_plaster.gdshader", {
			plaster = Color("#d9cbb2"), brick = Color("#a09382"), mortar = Color("#c4b8a4"), chips = 0.6})
		var roof := EnvMesh.material("church_roof", "res://shaders/env_plaster.gdshader", {
			plaster = Color("#3f4a55"), grime = Color("#2c333a"), chips = 0.0, streaks = 0.6})
		var c := Vector3(3.0, 0, zf + 17.0)
		EnvMesh.add(self, EnvMesh.box(Vector3(4.0, 14.0, 4.0), 0.05), stone, Transform3D(Basis(), c + Vector3(0, 7.0, 0)))
		var spire := EnvMesh.cylinder(0.0, 2.9, 7.0, 4)
		EnvMesh.add(self, spire, roof, Transform3D(Basis(Vector3.UP, PI * 0.25), c + Vector3(0, 17.5, 0)))
		EnvMesh.add(self, EnvMesh.box(Vector3(12.0, 9.0, 7.0), 0.05), stone, Transform3D(Basis(), c + Vector3(-8.0, 4.5, 1.5)))
		var louvre := EnvMesh.material("church_louvre", "res://shaders/env_window.gdshader", {energy = 0.6, glow = Color("#ffb877")})
		EnvMesh.add(self, EnvMesh.box(Vector3(1.4, 2.0, 0.05), 0.0), louvre, Transform3D(Basis(), c + Vector3(0, 11.0, -2.03)), false)
	prop("kaykit_city/streetlight.gltf", Vector3(-6.5, 0, zf + 5.0), 0.0, {scale = 0.95, solid = PropKit.Solid.CYLINDER})
	prop("kaykit_city/streetlight.gltf", Vector3(7.5, 0, zf + 5.0), 180.0, {scale = 0.95, solid = PropKit.Solid.CYLINDER})
	for i in 6:
		prop("kaykit_city/bush.gltf", Vector3(inner_min.x - 1.2, 0, zf + 0.5 + i * 0.9), i * 40.0, {scale = 1.1, solid = PropKit.Solid.NONE})
		prop("kaykit_city/bush.gltf", Vector3(inner_max.x + 1.2, 0, zf + 0.5 + i * 0.9), i * 55.0, {scale = 1.1, solid = PropKit.Solid.NONE})
	prop("kaykit_city/building_C_withoutBase.gltf", Vector3(-11.0, 0, -12.5), 0.0, {solid = PropKit.Solid.NONE, desaturate = 0.5})
	prop("kaykit_city/building_F_withoutBase.gltf", Vector3(11.0, 0, -12.0), 0.0, {solid = PropKit.Solid.NONE, desaturate = 0.5})
	for x: float in [inner_min.x - 1.2, inner_max.x + 1.2]:
		WorldBuilder.add_collider(self, Vector3(0.4, 1.2, 8.0), Transform3D(Basis(), Vector3(x, 0.6, zf + 4.0)))
	WorldBuilder.add_collider(self, Vector3(20.0, 1.2, 0.4), Transform3D(Basis(), Vector3(0, 0.6, zf + 8.2)))
