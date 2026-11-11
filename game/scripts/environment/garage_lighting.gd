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
