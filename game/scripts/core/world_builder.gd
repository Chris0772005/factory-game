class_name WorldBuilder
## Shared helpers for lighting, environment and simple level geometry.

const PALETTE := {
	"floor": Color("#e8dcc8"),
	"floor_line": Color("#d4c4a8"),
	"belt": Color("#3a3f4b"),
	"belt_edge": Color("#f2b134"),
	"machine": Color("#4fa3a5"),
	"machine_dark": Color("#2e6f73"),
	"accent": Color("#ef6b4f"),
	"item": Color("#f7d046"),
}


static func add_environment(parent: Node) -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#7fb8e6")
	sky_mat.sky_horizon_color = Color("#f4e1c6")
	sky_mat.ground_horizon_color = Color("#f4e1c6")
	sky_mat.ground_bottom_color = Color("#b49a7a")
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 2.0
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_light_color = Color("#f4e1c6")
	env.fog_density = 0.004
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("#fff1dc")
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60
	sun.rotation_degrees = Vector3(-55, 35, 0)
	parent.add_child(sun)


static func material(color: Color, rough := 0.7) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m


static func add_box(parent: Node, size: Vector3, pos: Vector3, color: Color, solid := false) -> Node3D:
	var mi := MeshInstance3D.new()
	mi.mesh = MeshFactory.rounded_box(size, minf(0.08, minf(size.x, minf(size.y, size.z)) * 0.3))
	mi.material_override = material(color)
	if not solid:
		mi.position = pos
		parent.add_child(mi)
		return mi
	var body := StaticBody3D.new()
	body.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.add_child(mi)
	parent.add_child(body)
	return body


static func add_floor(parent: Node, size := 40.0) -> void:
	add_box(parent, Vector3(size, 0.2, size), Vector3(0, -0.1, 0), PALETTE.floor, true)


static func add_belt(parent: Node, pos: Vector3, yaw: float, speed := 1.5) -> Belt:
	var belt := Belt.new()
	belt.position = pos
	belt.rotation.y = yaw
	belt.speed = speed
	parent.add_child(belt)
	belt._update_velocity()
	add_box(belt, Vector3(1.0, 0.3, 1.0), Vector3(0, 0.15, 0), PALETTE.belt)
	add_box(belt, Vector3(1.0, 0.12, 0.1), Vector3(0, 0.36, 0.48), PALETTE.belt_edge)
	add_box(belt, Vector3(1.0, 0.12, 0.1), Vector3(0, 0.36, -0.48), PALETTE.belt_edge)
	return belt


## Invisible static box collider (set dressing: fences, walls, props).
static func add_collider(parent: Node, size: Vector3, xform: Transform3D) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.transform = xform
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)
	return body


## Invisible static upright cylinder collider standing on `pos`.
static func add_cylinder_collider(parent: Node, radius: float, height: float, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos + Vector3(0, height * 0.5, 0)
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	shape.shape = cyl
	body.add_child(shape)
	parent.add_child(body)
	return body
