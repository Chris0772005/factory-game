class_name YardAmbience
## Small always-on life in the scene (Art Bible rule 11): a lazy smoke plume
## from the house chimney and fireflies drifting over the lawn edges.
## GPU particles only; off on the LOW preset.


static func build(parent: Node3D, chimney_top: Vector3) -> void:
	if not EnvMesh.visual():
		return
	parent.add_child(_evening_sounds())
	if EnvQuality.is_low():
		return
	parent.add_child(_smoke(chimney_top))
	parent.add_child(_fireflies(Vector3(-6.0, 0.7, 7.2), Vector3(4.5, 0.45, 1.4), 18, 5))
	parent.add_child(_fireflies(Vector3(10.6, 0.8, 4.0), Vector3(1.4, 0.5, 3.2), 10, 6))
	parent.add_child(_fireflies(Vector3(-10.5, 1.0, -0.5), Vector3(1.2, 0.6, 3.0), 8, 7))


static func _smoke(pos: Vector3) -> GPUParticles3D:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.12
	m.direction = Vector3.UP
	m.spread = 8.0
	m.initial_velocity_min = 0.35
	m.initial_velocity_max = 0.55
	m.gravity = Vector3(0.14, 0.04, 0.05)
	m.angle_min = -180.0
	m.angle_max = 180.0
	m.angular_velocity_min = -12.0
	m.angular_velocity_max = 12.0
	m.scale_min = 0.5
	m.scale_max = 0.8
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.35))
	grow.add_point(Vector2(1.0, 1.0))
	var grow_tex := CurveTexture.new()
	grow_tex.curve = grow
	m.scale_curve = grow_tex
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.62, 0.58, 0.64, 0.0))
	ramp.set_color(1, Color(0.55, 0.52, 0.6, 0.0))
	ramp.add_point(0.12, Color(0.66, 0.62, 0.68, 0.32))
	ramp.add_point(0.6, Color(0.6, 0.57, 0.65, 0.18))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	m.color_ramp = ramp_tex
	var p := GPUParticles3D.new()
	p.name = "ChimneySmoke"
	p.amount = 12
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.process_material = m
	var quad := QuadMesh.new()
	quad.size = Vector2(1.6, 1.6)
	p.draw_pass_1 = quad
	p.material_override = FoundryFX.soft_material()
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(6, 7, 5))
	p.position = pos
	return p


static func _fireflies(center: Vector3, extents: Vector3, amount: int, seed: int) -> GPUParticles3D:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = extents
	m.direction = Vector3.UP
	m.spread = 180.0
	m.initial_velocity_min = 0.05
	m.initial_velocity_max = 0.2
	m.gravity = Vector3.ZERO
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 0.6
	m.turbulence_noise_scale = 2.5
	m.turbulence_noise_speed_random = 0.4
	m.turbulence_influence_min = 0.05
	m.turbulence_influence_max = 0.12
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.25, Color(1, 1, 1, 1))
	ramp.add_point(0.45, Color(1, 1, 1, 0.2))
	ramp.add_point(0.65, Color(1, 1, 1, 1))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	m.color_ramp = ramp_tex
	var p := GPUParticles3D.new()
	p.name = "Fireflies"
	p.amount = amount
	p.lifetime = 6.0
	p.preprocess = 6.0
	p.randomness = 0.6
	p.seed = seed
	p.use_fixed_seed = true
	p.process_material = m
	var quad := QuadMesh.new()
	quad.size = Vector2(0.07, 0.07)
	p.draw_pass_1 = quad
	p.material_override = _glow_material()
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(-extents - Vector3.ONE, (extents + Vector3.ONE) * 2.0)
	p.position = center
	return p


static func _glow_material() -> StandardMaterial3D:
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 32
	tex.height = 32
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	tex.gradient = g
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = tex
	mat.albedo_color = Color(0.85, 1.0, 0.55) * 2.2
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return mat


## Quiet looping crickets under everything (synthesized, see tools/sfx_gen.py).
static func _evening_sounds() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = "EveningAmbience"
	var stream: AudioStreamWAV = load("res://assets/sfx/evening_crickets.wav").duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	player.stream = stream
	player.volume_db = -20.0
	player.autoplay = true
	return player
