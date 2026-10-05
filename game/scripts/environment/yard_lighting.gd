class_name YardLighting
## Dusk lighting for the backyard (Art Bible 6 + 7): stylized sky shader, AgX
## with a lower white point, glow only for HDR emission, SSAO (+ SSIL on
## HIGH), depth fog with aerial perspective, a low warm key from the front-left
## with soft shadows and a cool violet fill from behind that tints the shadows.

const SUN_COLOR := Color("#ffa36b")
const SUN_ENERGY := 1.2
## Key light: 20 deg above the horizon from the left, shining towards +x and
## a little towards the house: long shadows across the yard (short enough to
## keep the work area readable), warm grazing light on the facade.
const SUN_ROTATION := Vector3(-20.0, -68.0, 0.0)
const FILL_COLOR := Color("#7f8fd8")
const FILL_ENERGY := 0.32
const FILL_ROTATION := Vector3(-38.0, 120.0, 0.0)
const FOG_COLOR := Color("#a88a9e")


## Adds WorldEnvironment, key and fill lights under `parent`.
static func build(parent: Node) -> void:
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = create_environment()
	parent.add_child(we)
	parent.add_child(create_sun())
	parent.add_child(create_fill())


static func create_sky_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/env_sky.gdshader")
	return mat


static func create_environment() -> Environment:
	var low := EnvQuality.is_low()
	var high := EnvQuality.level() == EnvQuality.Level.HIGH
	var env := Environment.new()
	var sky := Sky.new()
	sky.sky_material = create_sky_material()
	sky.radiance_size = Sky.RADIANCE_SIZE_128 if low else Sky.RADIANCE_SIZE_256
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color("#4a4f86")
	env.ambient_light_sky_contribution = 0.75
	env.ambient_light_energy = 0.78
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_agx_white = 6.0
	env.tonemap_agx_contrast = 1.3
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_intensity = 0.6
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.2
	env.glow_hdr_scale = 2.0
	var levels := [0.0, 0.6, 0.8, 0.4, 0.2 if not low else 0.0, 0.0, 0.0]
	for i in levels.size():
		env.set_glow_level(i, levels[i])
	env.ssao_enabled = not EnvQuality.disabled("ssao")
	env.ssao_radius = 0.6
	env.ssao_intensity = 1.4
	env.ssao_power = 1.5
	env.ssao_detail = 0.5
	env.ssao_light_affect = 0.1
	env.ssil_enabled = high and not EnvQuality.disabled("ssil")
	env.ssil_radius = 3.0
	env.ssil_intensity = 0.8
	env.fog_enabled = true
	env.fog_light_color = FOG_COLOR
	env.fog_light_energy = 1.0
	env.fog_density = 0.007
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.65
	env.volumetric_fog_enabled = high and not EnvQuality.disabled("vol")
	env.volumetric_fog_density = 0.006
	env.volumetric_fog_albedo = Color("#d9c2b5")
	env.volumetric_fog_anisotropy = 0.3
	env.volumetric_fog_length = 40.0
	env.volumetric_fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.05
	env.adjustment_saturation = 1.1
	return env


static func create_sun() -> DirectionalLight3D:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = SUN_COLOR
	sun.light_energy = SUN_ENERGY
	sun.rotation_degrees = SUN_ROTATION
	sun.shadow_enabled = not EnvQuality.disabled("shadows")
	sun.shadow_blur = 1.0
	sun.light_angular_distance = 0.0 if EnvQuality.is_low() else 1.5
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 30.0 if EnvQuality.is_low() else 40.0
	sun.directional_shadow_blend_splits = true
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
	return sun


static func create_fill() -> DirectionalLight3D:
	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.light_color = FILL_COLOR
	fill.light_energy = FILL_ENERGY
	fill.light_specular = 0.0
	fill.rotation_degrees = FILL_ROTATION
	fill.shadow_enabled = false
	fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	return fill
