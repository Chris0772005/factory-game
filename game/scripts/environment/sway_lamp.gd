class_name SwayLamp
extends Node3D
## A work lamp on a long cable that is alive: it idles in a faint draught,
## swings away when a worker jumps or runs into it, and shivers when
## something heavy lands nearby (hammer, bellows, break-open). Its light
## moves with it. Local presentation only, no collider.

const STIFFNESS := 9.0
const DAMPING := 0.9
const BUMP_RADIUS := 0.42

var drop := 0.7
var _tilt := Vector2.ZERO        ## radians about X (x) and Z (y)
var _vel := Vector2.ZERO
var _pivot: Node3D
var _t := 0.0


## Hangs a lamp from `ceiling` so that its shade sits `drop` metres below.
static func hang(parent: Node3D, ceiling: Vector3, drop_length: float) -> SwayLamp:
	var lamp := SwayLamp.new()
	lamp.drop = drop_length
	lamp.position = ceiling
	parent.add_child(lamp)
	return lamp


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_t = position.x * 1.7 + position.z
	_pivot = Node3D.new()
	add_child(_pivot)
	Juice.impacted.connect(_on_impact)
	if not EnvMesh.visual():
		return
	var dark := MachineArt.black_mat()
	var enamel := StationKit.metal("lamp_enamel", {steel_color = Color("#6a6d70"), paint = 0.96, paint_color = Color("#2f5d4a"), rust = 0.12, dents = 0.1, roughness_paint = 0.35})
	StationKit.add(self, MachineArt.turned(MachineArt.drum(0.05, 0.03, 0.006), Vector3.DOWN, Vector3.ZERO, 14)[0], dark, Transform3D(Basis(Vector3.RIGHT, PI), Vector3.ZERO))
	StationKit.add(_pivot, EnvMesh.cylinder(0.006, 0.006, drop - 0.1, 6), dark, Transform3D(Basis(), Vector3(0, -(drop - 0.1) * 0.5, 0)), false)
	# Enamel shade: socket, neck, wide skirt with a rolled rim; white inside.
	var shade := StationKit.lathe(PackedVector2Array([Vector2(0, 0.0), Vector2(0.03, 0.0), Vector2(0.034, -0.05), Vector2(0.05, -0.075), Vector2(0.16, -0.14), Vector2(0.2, -0.185),
		Vector2(0.206, -0.19), Vector2(0.2, -0.195)]), 28, 50.0)
	StationKit.add(_pivot, shade, enamel, Transform3D(Basis(), Vector3(0, -drop + 0.19, 0)))
	var inside := StandardMaterial3D.new()
	inside.albedo_color = Color("#f3ead8")
	inside.emission_enabled = true
	inside.emission = Color("#ffd9a0")
	inside.emission_energy_multiplier = 0.9
	inside.cull_mode = BaseMaterial3D.CULL_FRONT
	StationKit.add(_pivot, shade, inside, Transform3D(Basis().scaled(Vector3(0.97, 0.97, 0.97)), Vector3(0, -drop + 0.188, 0)), false)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("#fff1d0")
	glow.emission_enabled = true
	glow.emission = Color("#ffd28a")
	glow.emission_energy_multiplier = 4.0
	StationKit.add(_pivot, EnvMesh.sphere(0.045, 14, 8), glow, Transform3D(Basis(), Vector3(0, -drop + 0.07, 0)), false)
	var light := OmniLight3D.new()
	light.light_color = Color("#ffd9a8")
	light.light_energy = 1.4
	light.omni_range = 5.5
	light.omni_attenuation = 1.3
	light.shadow_enabled = not EnvQuality.is_low()
	light.position = Vector3(0, -drop - 0.02, 0)
	_pivot.add_child(light)


func bob_position() -> Vector3:
	return _pivot.global_transform * Vector3(0, -drop, 0)


func _on_impact(world_pos: Vector3, strength: float) -> void:
	var to := global_position - world_pos
	var d := to.length()
	if d > 7.0:
		return
	var push := Vector2(to.z, -to.x).normalized() if Vector2(to.x, to.z).length() > 0.05 else Vector2(1, 0)
	_vel += push * strength * 2.2 / (1.0 + d * 0.5)


func _process(delta: float) -> void:
	delta = minf(delta, 0.05)
	_t += delta
	var bob := bob_position()
	for p in get_tree().get_nodes_in_group(&"players"):
		var body := p as CharacterBody3D
		if body == null:
			continue
		# Head and shoulders: a jump or a carried pot knocks the shade.
		var head := body.global_position + Vector3(0, 1.75, 0)
		var away := bob - head
		if away.length() < BUMP_RADIUS:
			var v := body.velocity
			var kick := Vector3(away.x, 0, away.z).normalized() * 1.2 + Vector3(v.x, 0, v.z) * 0.9
			_vel += Vector2(kick.z, -kick.x) * delta * 14.0
	# Pendulum with a faint draught so it never hangs dead still.
	var draught := Vector2(sin(_t * 0.7), cos(_t * 0.53 + 1.0)) * 0.012
	_vel += (-(_tilt - draught) * STIFFNESS - _vel * DAMPING) * delta
	_tilt += _vel * delta
	_tilt = _tilt.limit_length(1.1)
	_pivot.rotation = Vector3(_tilt.x, 0, _tilt.y)
