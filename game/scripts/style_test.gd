extends Node3D
## Visual style test: builds a small stylized factory scene from primitives.

const PALETTE := {
	"floor": Color("#e8dcc8"),
	"floor_line": Color("#d4c4a8"),
	"belt": Color("#3a3f4b"),
	"belt_edge": Color("#f2b134"),
	"machine": Color("#4fa3a5"),
	"machine_dark": Color("#2e6f73"),
	"accent": Color("#ef6b4f"),
	"item": Color("#f7d046"),
	"skin": Color("#ffd2a8"),
	"suit": Color("#3d7dd8"),
}


func _ready() -> void:
	_build_environment()
	_build_floor()
	for i in range(-6, 7):
		_add_belt(Vector3(i, 0, 0))
	_add_machine(Vector3(-7.5, 0, 0), PALETTE.machine)
	_add_machine(Vector3(7.5, 0, 0), PALETTE.accent)
	for i in range(9):
		_add_item(Vector3(-5.5 + i * 1.3, 0.55, randf_range(-0.15, 0.15)))
	_add_worker(Vector3(-2, 0, 2.2), 0.4)
	_add_worker(Vector3(3, 0, -2.4), PI + 0.3)
	var cam := Camera3D.new()
	cam.fov = 45
	add_child(cam)
	cam.look_at_from_position(Vector3(9, 11, 14), Vector3(0, 0, 0))
	var outline := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	outline.mesh = quad
	outline.extra_cull_margin = 16384.0
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/outline_post.gdshader")
	outline.material_override = sm
	cam.add_child(outline)


func _mat(color: Color, rough := 0.7, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m


func _box(size: Vector3, pos: Vector3, color: Color, parent: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = MeshFactory.rounded_box(size, minf(0.08, minf(size.x, minf(size.y, size.z)) * 0.3))
	mi.material_override = _mat(color)
	mi.position = pos
	parent.add_child(mi)
	return mi


func _build_environment() -> void:
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
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color("#fff1dc")
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60
	sun.rotation_degrees = Vector3(-55, 35, 0)
	add_child(sun)


func _build_floor() -> void:
	_box(Vector3(40, 0.2, 40), Vector3(0, -0.1, 0), PALETTE.floor)
	for i in range(-10, 11):
		_box(Vector3(40, 0.01, 0.05), Vector3(0, 0.005, i * 2), PALETTE.floor_line)
		_box(Vector3(0.05, 0.01, 40), Vector3(i * 2, 0.005, 0), PALETTE.floor_line)


func _add_belt(pos: Vector3) -> void:
	var belt := Node3D.new()
	belt.position = pos
	add_child(belt)
	_box(Vector3(1.0, 0.3, 1.0), Vector3(0, 0.15, 0), PALETTE.belt, belt)
	_box(Vector3(1.0, 0.12, 0.1), Vector3(0, 0.36, 0.48), PALETTE.belt_edge, belt)
	_box(Vector3(1.0, 0.12, 0.1), Vector3(0, 0.36, -0.48), PALETTE.belt_edge, belt)
	for leg_x in [-0.4, 0.4]:
		_box(Vector3(0.1, 0.3, 0.1), Vector3(leg_x, 0.0, 0.4), PALETTE.machine_dark, belt)


func _add_machine(pos: Vector3, color: Color) -> void:
	var m := Node3D.new()
	m.position = pos
	add_child(m)
	_box(Vector3(2.0, 2.0, 2.0), Vector3(0, 1.0, 0), color, m)
	_box(Vector3(2.1, 0.25, 2.1), Vector3(0, 2.1, 0), PALETTE.machine_dark, m)
	var chimney := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.25
	cyl.bottom_radius = 0.3
	cyl.height = 1.2
	chimney.mesh = cyl
	chimney.material_override = _mat(PALETTE.machine_dark)
	chimney.position = Vector3(0.5, 2.8, 0.5)
	m.add_child(chimney)
	var lamp := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	lamp.mesh = sphere
	var lamp_mat := _mat(Color("#ff4d3d"))
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color("#ff4d3d")
	lamp_mat.emission_energy_multiplier = 3.0
	lamp.material_override = lamp_mat
	lamp.position = Vector3(-0.6, 2.35, 0.6)
	m.add_child(lamp)


func _add_item(pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = MeshFactory.rounded_box(Vector3(0.45, 0.45, 0.45), 0.08)
	mi.material_override = _mat(PALETTE.item, 0.4)
	mi.position = pos
	mi.rotation.y = randf() * TAU
	add_child(mi)


func _add_worker(pos: Vector3, yaw: float) -> void:
	var w := Node3D.new()
	w.position = pos
	w.rotation.y = yaw
	add_child(w)
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.35
	cap.height = 1.1
	body.mesh = cap
	body.material_override = _mat(PALETTE.suit)
	body.position = Vector3(0, 0.55, 0)
	w.add_child(body)
	var head := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.3
	s.height = 0.6
	head.mesh = s
	head.material_override = _mat(PALETTE.skin)
	head.position = Vector3(0, 1.35, 0)
	w.add_child(head)
	var helmet := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.33
	hs.height = 0.36
	hs.is_hemisphere = true
	helmet.mesh = hs
	helmet.material_override = _mat(PALETTE.belt_edge, 0.4)
	helmet.position = Vector3(0, 1.45, 0)
	w.add_child(helmet)
