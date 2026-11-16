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


## Turns a hall built with `build` from dusk to a bright working day: blue
## sky with white clouds, a high pale sun through the door, more sky light
## inside. The scrap hall uses it (the first hall should read clean and clear).
static func daylight(parent: Node3D) -> void:
	var we := parent.get_node_or_null(^"WorldEnvironment") as WorldEnvironment
	if we:
		var env := we.environment
		env.ambient_light_color = Color("#aab6c8")
		env.ambient_light_energy = 0.8
		env.ambient_light_sky_contribution = 0.75
		env.volumetric_fog_density = 0.012
		env.volumetric_fog_albedo = Color("#dfe3e6")
		var sky := env.sky.sky_material as ShaderMaterial if env.sky else null
		if sky:
			sky.set_shader_parameter(&"zenith", Color(0.16, 0.38, 0.74))
			sky.set_shader_parameter(&"upper", Color(0.36, 0.58, 0.88))
			sky.set_shader_parameter(&"horizon", Color(0.74, 0.84, 0.94))
			sky.set_shader_parameter(&"afterglow", Color(0.86, 0.9, 0.95))
			sky.set_shader_parameter(&"venus_belt", Color(0.78, 0.86, 0.95))
			sky.set_shader_parameter(&"earth_shadow", Color(0.68, 0.78, 0.9))
			sky.set_shader_parameter(&"below", Color(0.36, 0.37, 0.4))
			sky.set_shader_parameter(&"star_amount", 0.0)
			sky.set_shader_parameter(&"moon_size", 0.0)
			sky.set_shader_parameter(&"cloud_lit", Color(1.0, 1.0, 1.0))
			sky.set_shader_parameter(&"cloud_shade", Color(0.7, 0.75, 0.84))
			sky.set_shader_parameter(&"energy", 1.15)
	var sun := parent.get_node_or_null(^"Sun") as DirectionalLight3D
	if sun:
		sun.light_color = Color("#fff1d8")
		sun.light_energy = 2.3
		sun.rotation_degrees = Vector3(-46.0, -34.0, 0.0)
