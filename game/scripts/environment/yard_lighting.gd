class_name YardLighting
## Dusk lighting for the backyard (Art Bible 6 + 7): stylized sky shader, AgX
## with a lower white point, glow only for HDR emission, SSAO (+ SSIL on
## HIGH), depth fog with aerial perspective, a low warm key from the front-left
## with soft shadows and a cool violet fill from behind that tints the shadows.

const SUN_COLOR := Color("#ffbe8e")
const SUN_ENERGY := 1.1
## Key light: 20 deg above the horizon from the left, shining towards +x and
## a little towards the house: long shadows across the yard (short enough to
## keep the work area readable), warm grazing light on the facade.
const SUN_ROTATION := Vector3(-20.0, -68.0, 0.0)
const FILL_COLOR := Color("#6f84e0")
const FILL_ENERGY := 0.5
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
	if DisplayServer.get_name() != "headless":
		parent.add_child(create_vignette())


## Dusk colour grade as a 32³ 3D LUT: cool blue-violet shadows, warm highlights,
## gentle S-curve (ART_BIBLE §7). Built in code so it needs no asset file.
static func create_grade_lut() -> Texture3D:
	const N := 32
	var shadow_tint := Color("#3b3f6b")
	var light_tint := Color("#ffd9a0")
	var images: Array[Image] = []
	for b in N:
		var img := Image.create(N, N, false, Image.FORMAT_RGB8)
		for g in N:
			for r in N:
				var c := Color(r / float(N - 1), g / float(N - 1), b / float(N - 1))
				var luma := c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
				c = c.lerp(c * 0.6 + shadow_tint * 0.4, 0.15 * (1.0 - smoothstep(0.0, 0.5, luma)))
				c = c.lerp(c * 0.7 + light_tint * 0.3, 0.10 * smoothstep(0.5, 1.0, luma))
				for i in 3:
					var v := c[i]
					c[i] = clampf(v + (v - 0.5) * 0.12 * (1.0 - absf(v - 0.5) * 2.0), 0.0, 1.0)
				img.set_pixel(r, g, c)
		images.append(img)
	var tex := ImageTexture3D.new()
	tex.create(Image.FORMAT_RGB8, N, N, N, false, images)
	return tex


## Soft screen-edge darkening on a canvas layer below the HUD.
static func create_vignette() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = "Vignette"
	layer.layer = -1
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform float strength = 0.18;
uniform float radius = 0.75;
uniform float softness = 0.45;
void fragment() {
	vec2 d = (UV - 0.5) * vec2(1.6, 1.0);
	float v = smoothstep(radius - softness, radius, length(d));
	COLOR = vec4(0.04, 0.03, 0.08, v * strength);
}"""
	mat.shader = sh
	rect.material = mat
	layer.add_child(rect)
	return layer


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
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = 0.7
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
	env.adjustment_saturation = 1.0
	if DisplayServer.get_name() != "headless":
		env.adjustment_color_correction = create_grade_lut()
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
