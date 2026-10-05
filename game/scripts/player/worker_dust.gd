class_name WorkerDust
extends Node3D
## Little dust puffs kicked up by a worker's boots: one burst per footstep while
## running and a ring of dust on landing. Purely cosmetic and local to each peer
## (driven by the replicated movement every peer already animates).

const DUST_COLOR := Color("#c9ad86")

static var _puff_mesh: QuadMesh

var _steps: Array[CPUParticles3D] = []
var _land: CPUParticles3D


func _ready() -> void:
	for i in 2:
		var p := _make(5, 0.45, 0.55)
		_steps.append(p)
	_land = _make(14, 0.6, 1.25)
	_land.spread = 85.0
	_land.direction = Vector3(0, 0.25, 0)


## Burst at a foot (world position). `strength` 0–1 scales how much dust flies.
func step(foot: int, at: Vector3, strength: float) -> void:
	var p := _steps[foot % 2]
	p.global_position = at
	_scale(p, clampf(strength, 0.25, 1.0))
	p.restart()


func land(at: Vector3, strength: float) -> void:
	_land.global_position = at
	_scale(_land, clampf(strength, 0.3, 1.2))
	_land.restart()


## Bigger, faster puffs for harder steps and landings.
func _scale(p: CPUParticles3D, strength: float) -> void:
	var base: float = p.get_meta(&"speed")
	p.initial_velocity_min = base * 0.5 * strength
	p.initial_velocity_max = base * strength
	p.scale_amount_min = 0.5 + 0.3 * strength
	p.scale_amount_max = 0.8 + 0.5 * strength


func _make(amount: int, lifetime: float, speed: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.set_meta(&"speed", speed)
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.92
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	p.mesh = _mesh()
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.06
	p.direction = Vector3(0, 1, -0.6)
	p.spread = 55.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -1.2, 0)
	p.damping_min = 2.5
	p.damping_max = 3.5
	p.angle_min = -180.0
	p.angle_max = 180.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.2
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.35))
	grow.add_point(Vector2(0.35, 1.0))
	grow.add_point(Vector2(1.0, 1.25))
	p.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(DUST_COLOR, 0.55))
	fade.set_color(1, Color(DUST_COLOR, 0.0))
	p.color_ramp = fade
	add_child(p)
	return p


static func _mesh() -> QuadMesh:
	if _puff_mesh:
		return _puff_mesh
	var tex := GradientTexture2D.new()
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var g := Gradient.new()
	g.set_color(0, Color.WHITE)
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.55, Color(1, 1, 1, 0.6))
	tex.gradient = g
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = tex
	mat.roughness = 1.0
	mat.disable_receive_shadows = true
	var quad := QuadMesh.new()
	quad.size = Vector2(0.22, 0.22)
	quad.material = mat
	_puff_mesh = quad
	return quad
