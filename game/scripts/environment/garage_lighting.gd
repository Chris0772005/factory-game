class_name GarageLighting
## Lighting for the garage (level 2): the backyard's dusk sky, grade and
## post-processing, but with the low sun raking in through the open roller
## door (the roof and walls shade the rest), a weaker sky fill and ambient,
## so the interior lamps and the furnace carry the room.

## Low sun from the front-left: a warm shaft through the door across the floor.
const SUN_ROTATION := Vector3(-17.0, -32.0, 0.0)
const SUN_ENERGY := 1.25
const FILL_ENERGY := 0.2
const AMBIENT_ENERGY := 0.38


static func build(parent: Node3D) -> void:
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	var env := YardLighting.create_environment()
	env.ambient_light_energy = AMBIENT_ENERGY
	env.ambient_light_sky_contribution = 0.6
	env.ambient_light_color = Color("#5a5578")
	env.fog_density = 0.004
	# Workshop haze: the lamps and the door light draw visible cones in the air.
	env.volumetric_fog_density = 0.022
	env.volumetric_fog_albedo = Color("#c9c4bc")
	env.volumetric_fog_anisotropy = 0.55
	env.volumetric_fog_length = 28.0
	env.volumetric_fog_ambient_inject = 0.25
	env.ssao_intensity = 1.8
	env.ssao_radius = 0.8
	we.environment = env
	parent.add_child(we)
	var sun := YardLighting.create_sun()
	sun.rotation_degrees = SUN_ROTATION
	sun.light_energy = SUN_ENERGY
	sun.directional_shadow_max_distance = 30.0
	parent.add_child(sun)
	var fill := YardLighting.create_fill()
	fill.light_energy = FILL_ENERGY
	parent.add_child(fill)
	if DisplayServer.get_name() != "headless":
		parent.add_child(YardLighting.create_vignette())


## The day sky: a photographed panorama for the view and its HDR original for the light (see
## shaders/env_sky_photo.gdshader). The panorama's sun stands 47.9 degrees up; DAY_SUN points the sun
## light the same way, so the shadows fall where the sky says they should.
const DAY_SKY_VIEW := "res://assets/sky/day_sky_view.jpg"
const DAY_SKY_LIGHT := "res://assets/sky/day_sky_light.hdr"
const DAY_SUN := Vector3(-47.9, -34.2, 0.0)


## Turns a hall built with `build` from dusk to a clear working day in the open: a photographed sky
## that lights the scene and mirrors in paint and glass, a hard high sun with crisp shadows, clear air
## instead of workshop haze, and a grade with punch (the project's graphics standard, TECH_SPEC Modul Y).
## The scrap hall uses it.
static func daylight(parent: Node3D) -> void:
	var low := EnvQuality.is_low()
	var we := parent.get_node_or_null(^"WorldEnvironment") as WorldEnvironment
	if we:
		var env := we.environment
		var sky_mat := ShaderMaterial.new()
		sky_mat.shader = load("res://shaders/env_sky_photo.gdshader")
		sky_mat.set_shader_parameter(&"view_panorama", load(DAY_SKY_VIEW))
		sky_mat.set_shader_parameter(&"light_panorama", load(DAY_SKY_LIGHT))
		sky_mat.set_shader_parameter(&"view_energy", 1.2)
		sky_mat.set_shader_parameter(&"light_energy", 1.0)
		var sky := Sky.new()
		sky.sky_material = sky_mat
		sky.radiance_size = Sky.RADIANCE_SIZE_256 if low else Sky.RADIANCE_SIZE_512
		sky.process_mode = Sky.PROCESS_MODE_QUALITY
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_sky_contribution = 1.0
		env.ambient_light_energy = 1.0
		env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		# Clear air: only a breath of distance haze, no lit dust in the room.
		env.fog_light_color = Color("#b4c8de")
		env.fog_density = 0.0012
		env.fog_aerial_perspective = 0.0
		env.fog_sky_affect = 0.0
		env.volumetric_fog_enabled = false
		# Grade: no dusk tint; sunlit surfaces bright, shadows deep, colours full.
		env.tonemap_exposure = 1.0
		env.tonemap_agx_white = 8.0
		env.tonemap_agx_contrast = 1.35
		env.adjustment_color_correction = null
		env.adjustment_contrast = 1.08
		env.adjustment_saturation = 1.2
		env.ssao_radius = 1.0
		env.ssao_intensity = 2.2
		env.ssao_power = 1.6
		env.ssao_light_affect = 0.0
		env.glow_intensity = 0.5
		env.glow_hdr_threshold = 1.6
	var sun := parent.get_node_or_null(^"Sun") as DirectionalLight3D
	if sun:
		sun.light_color = Color("#fff4e2")
		sun.light_energy = 3.0
		sun.rotation_degrees = DAY_SUN
		# The real sun's disc is half a degree wide: shadows are sharp at the foot and soften with distance.
		sun.light_angular_distance = 0.0 if low else 0.55
		sun.shadow_blur = 0.8
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if low else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		sun.directional_shadow_max_distance = 45.0 if low else 80.0
		sun.directional_shadow_fade_start = 0.9
	# The sky is the fill now.
	var fill := parent.get_node_or_null(^"Fill") as DirectionalLight3D
	if fill:
		fill.visible = false
	var vignette := parent.get_node_or_null(^"Vignette")
	if vignette:
		vignette.queue_free()
