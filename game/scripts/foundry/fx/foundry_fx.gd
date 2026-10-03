class_name FoundryFX
## One-shot foundry effects. Each helper adds a self-freeing FxBurst to `parent`
## at the global position `pos` and returns it. Also hands out the shared spark
## and puff building blocks used by PourStream and FurnaceFire.

## Visual layer of all effect geometry; ground-collision heightfields skip it.
const FX_LAYER := 1 << 19
const GLOW_SHADER := "res://shaders/fx_glow_particle.gdshader"
const SOFT_SHADER := "res://shaders/fx_soft_particle.gdshader"

static var _cache := {}


## Chunky sand clods flying out with a dust cloud, e.g. when a mold is smashed.
static func sand_burst(parent: Node, pos: Vector3, size := 1.0) -> FxBurst:
	var fx := FxBurst.new()
	var chunks := _emitter(fx, maxi(6, roundi(26 * size)), 1.7, _chunk_process(size), _chunk_mesh())
	chunks.explosiveness = 0.92
	chunks.collision_base_size = 0.05
	var dust_mat := _puff_process(Color("#e8d4ac"), 0.7, 0.25 * size, Vector2(0.6, 1.8) * sqrt(size))
	dust_mat.damping_min = 2.5
	dust_mat.damping_max = 3.5
	_emitter(fx, maxi(4, roundi(14 * size)), 1.8, dust_mat, _puff_mesh(0.6 * sqrt(size))).explosiveness = 0.85
	_add_ground_collision(fx, 2.5 * size)
	return _spawn(parent, fx, pos)


## White billowing steam, e.g. when hot metal is quenched. `strength` 1 = small hiss.
static func steam_puff(parent: Node, pos: Vector3, strength := 1.0) -> FxBurst:
	var fx := FxBurst.new()
	var s := maxf(strength, 0.2)
	var mat := _puff_process(Color("#f6f3ee"), 0.4, 0.14 * sqrt(s), Vector2(0.8, 2.2) * sqrt(s))
	mat.spread = 28.0
	mat.gravity = Vector3(0, 0.9, 0)
	mat.damping_min = 1.0
	mat.damping_max = 1.6
	mat.turbulence_enabled = true
	mat.turbulence_noise_strength = 0.6
	mat.turbulence_noise_scale = 2.5
	mat.turbulence_influence_min = 0.04
	mat.turbulence_influence_max = 0.1
	var puff := _emitter(fx, maxi(8, roundi(32 * s)), 2.4, mat, _puff_mesh(0.5 * sqrt(s)))
	puff.explosiveness = 0.55
	return _spawn(parent, fx, pos)


## Bright orange spark streaks that bounce off the ground, with a short flash.
static func sparks(parent: Node, pos: Vector3, amount := 30) -> FxBurst:
	var fx := FxBurst.new()
	var p := make_sparks(maxi(1, amount), 0.8)
	p.one_shot = true
	p.explosiveness = 0.9
	p.emitting = false
	fx.add_child(p)
	_add_ground_collision(fx, 2.0)
	var light := OmniLight3D.new()
	light.light_color = Color("#ffa040")
	light.light_energy = 2.0 * clampf(amount / 30.0, 0.4, 2.0)
	light.omni_range = 2.5
	light.position = Vector3(0, 0.15, 0)
	fx.add_child(light)
	fx.light = light
	return _spawn(parent, fx, pos)


## Small sandy dust puff for footsteps, drops and hammer blows.
static func dust(parent: Node, pos: Vector3) -> FxBurst:
	var fx := FxBurst.new()
	var mat := _puff_process(Color("#d9c6a0"), 0.55, 0.08, Vector2(0.4, 1.1))
	mat.flatness = 0.75
	mat.damping_min = 2.0
	mat.damping_max = 3.0
	_emitter(fx, 8, 1.2, mat, _puff_mesh(0.35)).explosiveness = 0.9
	return _spawn(parent, fx, pos)


## Continuous-capable spark emitter (velocity-aligned HDR streaks with gravity
## and ground bounce). Callers toggle `emitting` or set `one_shot`.
static func make_sparks(amount: int, lifetime := 0.6) -> GPUParticles3D:
	var p := _particles(amount, lifetime, _spark_process(), _spark_mesh())
	p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	p.collision_base_size = 0.01
	return p


## Rising glowing embers (camera-facing dots) for fires and hot metal.
static func make_embers(amount: int, area: Vector3) -> GPUParticles3D:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = area
	m.direction = Vector3.UP
	m.spread = 25.0
	m.initial_velocity_min = 0.5
	m.initial_velocity_max = 1.3
	m.gravity = Vector3(0, 0.5, 0)
	m.damping_min = 0.3
	m.damping_max = 0.6
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 1.4
	m.turbulence_noise_scale = 1.6
	m.turbulence_influence_min = 0.06
	m.turbulence_influence_max = 0.16
	m.scale_min = 0.5
	m.scale_max = 1.2
	m.lifetime_randomness = 0.5
	m.color_ramp = _gradient(&"ember", [
		[0.0, Color(1.0, 0.85, 0.5, 0.0)], [0.08, Color(1.0, 0.75, 0.35, 1.0)],
		[0.6, Color(1.0, 0.35, 0.06, 0.9)], [1.0, Color(0.6, 0.06, 0.01, 0.0)]])
	var quad := QuadMesh.new()
	quad.size = Vector2(0.035, 0.035)
	quad.material = glow_material(true)
	var p := _particles(amount, 2.2, m, quad)
	p.one_shot = false
	return p


## Additive HDR material for spark streaks (billboard = false) or round embers.
static func glow_material(billboard: bool) -> ShaderMaterial:
	var key := &"glow_bb" if billboard else &"glow"
	if not _cache.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = load(GLOW_SHADER)
		mat.set_shader_parameter(&"billboard", billboard)
		mat.set_shader_parameter(&"energy", 4.0 if billboard else 5.0)
		mat.render_priority = 1
		_cache[key] = mat
	return _cache[key]


## Soft camera-facing puff material (colour from the particles).
static func soft_material() -> ShaderMaterial:
	if not _cache.has(&"soft"):
		var mat := ShaderMaterial.new()
		mat.shader = load(SOFT_SHADER)
		mat.render_priority = 1
		_cache[&"soft"] = mat
	return _cache[&"soft"]


## Bursts are top-level: `pos` stays global and a scaled or rotated parent
## does not distort the effect.
static func _spawn(parent: Node, fx: FxBurst, pos: Vector3) -> FxBurst:
	fx.top_level = true
	fx.position = pos
	parent.add_child(fx)
	return fx


static func _particles(amount: int, lifetime: float, process: ParticleProcessMaterial, mesh: Mesh) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.process_material = process
	p.draw_pass_1 = mesh
	p.local_coords = false
	p.layers = FX_LAYER
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	return p


static func _emitter(fx: FxBurst, amount: int, lifetime: float, process: ParticleProcessMaterial, mesh: Mesh) -> GPUParticles3D:
	var p := _particles(amount, lifetime, process, mesh)
	p.one_shot = true
	p.emitting = false
	fx.add_child(p)
	return p


## Heightfield collider rendered from the scene below the effect, so debris and
## sparks land on floors, molds and tables alike (rendering only, not physics).
## `cull_mask` picks the particles it affects (all, FX ones included);
## `heightfield_mask` keeps effect geometry out of the rendered height map.
static func _add_ground_collision(fx: FxBurst, extent: float) -> void:
	var hf := GPUParticlesCollisionHeightField3D.new()
	hf.size = Vector3(extent * 2.0, 4.0, extent * 2.0)
	hf.position = Vector3(0, -1.0, 0)
	hf.resolution = GPUParticlesCollisionHeightField3D.RESOLUTION_256
	hf.update_mode = GPUParticlesCollisionHeightField3D.UPDATE_MODE_WHEN_MOVED
	hf.heightfield_mask = ~FX_LAYER & 0xFFFFF
	fx.add_child(hf)


static func _chunk_process(size: float) -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.18 * size
	m.direction = Vector3.UP
	m.spread = 70.0
	m.initial_velocity_min = 1.8 * sqrt(size)
	m.initial_velocity_max = 4.2 * sqrt(size)
	m.gravity = Vector3(0, -9.8, 0)
	m.use_rotation_3d = true
	m.rotation_3d_min = Vector3(-180, -180, -180)
	m.rotation_3d_max = Vector3(180, 180, 180)
	m.use_rotation_velocity_3d = true
	m.rotation_velocity_3d_min = Vector3(-540, -540, -540)
	m.rotation_velocity_3d_max = Vector3(540, 540, 540)
	m.scale_min = 0.55 * size
	m.scale_max = 1.35 * size
	m.scale_curve = _curve(&"chunk_scale", [Vector2(0, 1), Vector2(0.75, 1), Vector2(1, 0)])
	m.color_initial_ramp = _gradient(&"sand", [
		[0.0, Color("#e2c595")], [0.35, Color("#d2ac74")], [0.7, Color("#bb8f58")], [1.0, Color("#9c7347")]])
	m.collision_mode = ParticleProcessMaterial.COLLISION_RIGID
	m.collision_bounce = 0.25
	m.collision_friction = 0.7
	m.lifetime_randomness = 0.2
	return m


static func _puff_process(color: Color, alpha: float, radius: float, speed: Vector2) -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = radius
	m.direction = Vector3.UP
	m.spread = 180.0
	m.initial_velocity_min = speed.x
	m.initial_velocity_max = speed.y
	m.gravity = Vector3(0, 0.15, 0)
	m.angle_min = -180.0
	m.angle_max = 180.0
	m.angular_velocity_min = -40.0
	m.angular_velocity_max = 40.0
	m.scale_min = 0.6
	m.scale_max = 1.1
	m.scale_curve = _curve(&"puff_scale", [Vector2(0, 0.35), Vector2(0.3, 0.85), Vector2(1, 1.3)])
	m.color = Color(color, alpha)
	m.alpha_curve = _curve(&"puff_alpha", [Vector2(0, 0), Vector2(0.12, 1), Vector2(0.5, 0.75), Vector2(1, 0)])
	m.lifetime_randomness = 0.3
	return m


static func _spark_process() -> ParticleProcessMaterial:
	if _cache.has(&"spark_process"):
		return _cache[&"spark_process"]
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.04
	m.direction = Vector3.UP
	m.spread = 75.0
	m.initial_velocity_min = 2.0
	m.initial_velocity_max = 5.5
	m.gravity = Vector3(0, -9.8, 0)
	m.damping_min = 0.2
	m.damping_max = 0.8
	m.scale_min = 0.6
	m.scale_max = 1.3
	m.lifetime_randomness = 0.5
	m.color_ramp = _gradient(&"spark", [
		[0.0, Color(1.0, 0.62, 0.25, 1.0)], [0.3, Color(1.0, 0.4, 0.08, 1.0)],
		[0.7, Color(1.0, 0.18, 0.02, 0.8)], [1.0, Color(0.6, 0.05, 0.0, 0.0)]])
	m.collision_mode = ParticleProcessMaterial.COLLISION_RIGID
	m.collision_bounce = 0.35
	m.collision_friction = 0.3
	_cache[&"spark_process"] = m
	return m


static func _spark_mesh() -> QuadMesh:
	if not _cache.has(&"spark_mesh"):
		var quad := QuadMesh.new()
		quad.size = Vector2(0.018, 0.12)
		quad.material = glow_material(false)
		_cache[&"spark_mesh"] = quad
	return _cache[&"spark_mesh"]


## Lumpy, slightly flattened low-poly clod with smooth normals.
static func _chunk_mesh() -> ArrayMesh:
	if _cache.has(&"chunk_mesh"):
		return _cache[&"chunk_mesh"]
	var sphere := SphereMesh.new()
	sphere.radius = 0.045
	sphere.height = 0.07
	sphere.radial_segments = 7
	sphere.rings = 4
	var arrays := sphere.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in verts.size():
		var v := verts[i]
		var h := hash(Vector3i((v * 1000.0).round()))
		verts[i] = v * (0.75 + 0.5 * float(h % 1000) / 1000.0)
	var bare := []
	bare.resize(Mesh.ARRAY_MAX)
	bare[Mesh.ARRAY_VERTEX] = verts
	bare[Mesh.ARRAY_INDEX] = arrays[Mesh.ARRAY_INDEX]
	var raw := ArrayMesh.new()
	raw.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, bare)
	# Re-index so the sphere's UV seam vertices merge and the normals stay smooth.
	var st := SurfaceTool.new()
	st.create_from(raw, 0)
	st.deindex()
	st.index()
	st.generate_normals()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 1.0
	st.set_material(mat)
	var mesh := st.commit()
	_cache[&"chunk_mesh"] = mesh
	return mesh


static func _puff_mesh(size: float) -> QuadMesh:
	var key := StringName("puff_%.2f" % size)
	if not _cache.has(key):
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * size
		quad.material = soft_material()
		_cache[key] = quad
	return _cache[key]


static func _curve(key: StringName, points: Array) -> CurveTexture:
	if not _cache.has(key):
		var c := Curve.new()
		c.max_value = 2.0
		for pt: Vector2 in points:
			c.add_point(pt)
		var tex := CurveTexture.new()
		tex.curve = c
		_cache[key] = tex
	return _cache[key]


static func _gradient(key: StringName, stops: Array) -> GradientTexture1D:
	if not _cache.has(key):
		var g := Gradient.new()
		g.offsets = PackedFloat32Array(stops.map(func(s: Array) -> float: return s[0]))
		g.colors = PackedColorArray(stops.map(func(s: Array) -> Color: return s[1]))
		var tex := GradientTexture1D.new()
		tex.gradient = g
		_cache[key] = tex
	return _cache[key]
