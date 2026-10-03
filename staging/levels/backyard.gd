extends GameWorld
## Level 1 – Hinterhof: a bucket furnace, a scrap heap and two sand molds
## in a fenced backyard at dusk.

const GRASS := Color("#5d8a4e")
const DIRT := Color("#9a7b5c")
const FENCE := Color("#8a6243")


func build_level() -> void:
	register_entity("crucible", Crucible.create_crucible)
	register_entity("hammer", Hammer.create_hammer)
	register_entity("cast", CastPiece.from_data)
	_build_environment()
	WorldBuilder.add_box(self, Vector3(26, 0.2, 20), Vector3(0, -0.1, 0), GRASS, true)
	WorldBuilder.add_box(self, Vector3(12, 0.02, 8.5), Vector3(0, 0.01, -0.5), DIRT)
	_build_fence()
	_build_house()
	_build_string_lights()

	var furnace := Furnace.new()
	furnace.position = Vector3(-3.0, 0, -2.5)
	add_child(furnace)
	var scrap := ScrapPile.new()
	scrap.position = Vector3(-5.6, 0, 0.2)
	add_child(scrap)
	var bench := ModelBench.new()
	bench.position = Vector3(3.2, 0, -3.4)
	add_child(bench)
	for i in 2:
		var mold := MoldBox.new()
		mold.position = Vector3(0.2 + i * 2.6, 0, 0.6)
		add_child(mold)
	var crate := SellCrate.new()
	crate.position = Vector3(6.2, 0, 3.2)
	crate.rotation.y = -0.4
	add_child(crate)
	WorldBuilder.add_box(self, Vector3(0.7, 0.9, 0.7), Vector3(-1.2, 0.45, -4.6), Color("#5f7f95"))

	if Network.is_sim_authority():
		spawn_entity({type = "crucible", pos = furnace.global_position + Vector3(0, 0.15, 0)})
		spawn_entity({type = "hammer", pos = Vector3(1.5, 0.1, 2.6)})


func _build_environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#1b2347")
	sky_mat.sky_horizon_color = Color("#d9805a")
	sky_mat.ground_horizon_color = Color("#3a2f3a")
	sky_mat.ground_bottom_color = Color("#151320")
	sky_mat.sun_angle_max = 20.0
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	env.ssao_radius = 1.0
	env.ssao_intensity = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.1
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color("#6b5a73")
	env.fog_density = 0.012
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color("#ffb38a")
	moon.light_energy = 0.75
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 45
	moon.rotation_degrees = Vector3(-28, -60, 0)
	add_child(moon)


func _build_fence() -> void:
	for side in [-1, 1]:
		for i in 25:
			var x := -12.0 + i
			WorldBuilder.add_box(self, Vector3(0.18, 1.5, 0.08), Vector3(x, 0.75, side * 9.0), FENCE.darkened(0.08 * (i % 2)), true)
		for i in 18:
			var z := -8.5 + i
			WorldBuilder.add_box(self, Vector3(0.08, 1.5, 0.18), Vector3(side * 12.5, 0.75, z), FENCE.darkened(0.08 * (i % 2)), true)


func _build_house() -> void:
	WorldBuilder.add_box(self, Vector3(14, 5.5, 1.0), Vector3(-2, 2.75, -9.6), Color("#c9a487"), true)
	WorldBuilder.add_box(self, Vector3(1.4, 2.3, 0.1), Vector3(-4, 1.15, -9.05), Color("#5c3a26"))
	for x in [-7.0, 0.5, 3.5]:
		var win := WorldBuilder.add_box(self, Vector3(1.3, 1.1, 0.06), Vector3(x, 2.6, -9.05), Color("#ffcf7a"))
		var m := (win as MeshInstance3D).material_override as StandardMaterial3D
		m.emission_enabled = true
		m.emission = Color("#ffb54a")
		m.emission_energy_multiplier = 2.5
	# Shed on the left.
	WorldBuilder.add_box(self, Vector3(3.2, 2.6, 3.0), Vector3(-9.5, 1.3, -5.5), Color("#7d5a3f"), true)
	WorldBuilder.add_box(self, Vector3(3.6, 0.2, 3.4), Vector3(-9.5, 2.7, -5.5), Color("#4a3a35"))


func _build_string_lights() -> void:
	var poles := [Vector3(-6, 0, -6.5), Vector3(6, 0, -6.5), Vector3(6, 0, 5.5), Vector3(-6, 0, 5.5)]
	for p in poles:
		WorldBuilder.add_box(self, Vector3(0.14, 3.2, 0.14), p + Vector3(0, 1.6, 0), FENCE.darkened(0.3), true)
	for k in 4:
		var a: Vector3 = poles[k] + Vector3(0, 3.1, 0)
		var b: Vector3 = poles[(k + 1) % 4] + Vector3(0, 3.1, 0)
		for i in 12:
			var t := (i + 0.5) / 12.0
			var pos := a.lerp(b, t) + Vector3(0, -sin(t * PI) * 0.6, 0)
			var bulb := MeshInstance3D.new()
			var s := SphereMesh.new()
			s.radius = 0.06
			s.height = 0.12
			bulb.mesh = s
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color("#ffe2a8")
			mat.emission_enabled = true
			mat.emission = Color("#ffcf7a")
			mat.emission_energy_multiplier = 6.0
			bulb.material_override = mat
			bulb.position = pos
			add_child(bulb)
			if i % 4 == 2:
				var light := OmniLight3D.new()
				light.light_color = Color("#ffc27a")
				light.light_energy = 0.9
				light.omni_range = 5.5
				light.position = pos
				add_child(light)
