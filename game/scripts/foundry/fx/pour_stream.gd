class_name PourStream
extends Node3D
## Glowing molten-metal stream between two global points: a tapering tube on a
## gravity arc with flowing emission, a splash blob, sparks and a glow light at
## the impact. Endpoints are global, so the node ignores its parent's transform.
## Starting a pour lets the front fall down; stopping lets the tail fall after it.

const SIDES := 10
const RINGS := 22
const SHADER_PATH := "res://shaders/fx_stream.gdshader"

## 0 = off (hidden), 1 = full pour: thickness, sparks and light scale with it.
var flow := 0.0:
	set(value):
		flow = clampf(value, 0.0, 1.0)
## Tube radius at the lip for flow = 1.
var max_radius := 0.045
## Heat of the metal (0..1, same scale as MetalMaterial): colour of the stream.
var temperature := 0.88:
	set(value):
		temperature = value
		if _mat:
			_mat.set_shader_parameter(&"temperature", value)

var _from := Vector3.ZERO
var _to := Vector3(0, -1, 0)
var _head := 0.0
var _tail := 0.0
var _shown_flow := 0.0
var _time := 0.0
var _built_key := []
var _mesh := ArrayMesh.new()
var _mat: ShaderMaterial
var _tube: MeshInstance3D
var _splash: MeshInstance3D
var _sparks: GPUParticles3D
var _light: OmniLight3D


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_mat = ShaderMaterial.new()
	_mat.shader = load(SHADER_PATH)
	_mat.render_priority = 1
	_mat.set_shader_parameter(&"temperature", temperature)
	_tube = MeshInstance3D.new()
	_tube.mesh = _mesh
	_tube.material_override = _mat
	_tube.layers = FoundryFX.FX_LAYER
	_tube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_tube)
	_splash = MeshInstance3D.new()
	var blob := SphereMesh.new()
	blob.radius = 1.0
	blob.height = 2.0
	blob.radial_segments = 16
	blob.rings = 8
	_splash.mesh = blob
	_splash.material_override = _mat
	_splash.layers = FoundryFX.FX_LAYER
	_splash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_splash)
	_sparks = FoundryFX.make_sparks(40, 0.6)
	_sparks.emitting = false
	add_child(_sparks)
	_light = OmniLight3D.new()
	_light.light_color = Color("#ff7428")
	_light.omni_range = 2.6
	_light.omni_attenuation = 0.8
	add_child(_light)
	_update(0.0)


## Global start (crucible lip) and end (impact point) of the stream.
func set_endpoints(from: Vector3, to: Vector3) -> void:
	_from = from
	_to = to


## True while any part of the stream is visible.
func is_pouring() -> bool:
	return _head > 0.0


func _process(delta: float) -> void:
	_update(delta)


func _update(delta: float) -> void:
	_time += delta
	var fall_time := clampf(sqrt(2.0 * maxf(_from.y - _to.y, 0.05) / 9.8), 0.08, 0.6)
	if flow > 0.0:
		if _tail > 0.0:
			_tail = 0.0
		_head = minf(_head + delta / fall_time, 1.0)
		_shown_flow = move_toward(_shown_flow, flow, delta * 4.0)
	elif _head > 0.0:
		_tail = minf(_tail + delta / fall_time, 1.0)
		if _tail >= 1.0:
			_head = 0.0
			_tail = 0.0
			_shown_flow = 0.0
	# Only the tube hides: sparks already in flight finish their arcs.
	var shown := _head > 0.0
	_tube.visible = shown
	var impact := shown and _head >= 1.0 and _tail < 0.9
	_sparks.emitting = impact and flow > 0.05
	_sparks.amount_ratio = clampf(_shown_flow, 0.2, 1.0)
	_sparks.global_position = _to
	var radius := max_radius * lerpf(0.35, 1.0, sqrt(_shown_flow))
	_update_impact(impact, radius)
	if not shown:
		return
	var key := [_from, _to, _head, _tail, radius]
	if key != _built_key:
		_built_key = key
		_rebuild(radius)


func _update_impact(active: bool, radius: float) -> void:
	_splash.visible = active
	_light.visible = active
	if not active:
		return
	var wobble := sin(_time * 23.0) * 0.12 + sin(_time * 37.0) * 0.08
	_splash.global_transform = Transform3D(Basis.from_scale(Vector3(1.9, 0.75 + wobble, 1.9) * radius), _to)
	_light.global_position = _to + Vector3(0, 0.3, 0)
	var flicker := 0.85 + 0.1 * sin(_time * 17.0) + 0.05 * sin(_time * 41.0)
	_light.light_energy = 0.9 * sqrt(_shown_flow) * flicker


## Point on the arc for s in [0, 1]: horizontal travel is linear, the drop
## mostly quadratic, like a jet leaving the lip and accelerating down.
func _point(s: float) -> Vector3:
	var p := _from.lerp(_to, s)
	p.y = _from.y + (_to.y - _from.y) * lerpf(s, s * s, 0.7)
	return p


func _rebuild(radius: float) -> void:
	var length := 0.0
	var prev := _from
	for i in range(1, 9):
		var q := _point(i / 8.0)
		length += prev.distance_to(q)
		prev = q
	var cap := clampf(radius * 1.2 / maxf(length, 0.01), 0.01, 0.3)
	var horizontal := Vector3(_to.x - _from.x, 0.0, _to.z - _from.z)
	var side := horizontal.cross(Vector3.UP)
	side = side.normalized() if side.length_squared() > 1e-6 else Vector3.RIGHT
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	for i in RINGS + 1:
		# Rings bunch up at both ends where the rounded caps need them.
		var u := 0.5 - 0.5 * cos(PI * i / RINGS)
		var s := lerpf(_tail, _head, u)
		var center := _point(s)
		var tangent := (_point(minf(s + 0.01, 1.0)) - _point(maxf(s - 0.01, 0.0))).normalized()
		var bin := tangent.cross(side).normalized()
		var r := radius * _profile(s, cap)
		for j in SIDES + 1:
			var a := TAU * j / SIDES
			var n := side * cos(a) + bin * sin(a)
			verts.append(center + n * r)
			normals.append(n)
			uvs.append(Vector2(float(j) / SIDES, s * length))
			uv2s.append(Vector2(r, 0.0))
	var indices := PackedInt32Array()
	var row := SIDES + 1
	for i in RINGS:
		for j in SIDES:
			var a := i * row + j
			var c := a + row
			indices.append_array([a, c, a + 1, a + 1, c, c + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_INDEX] = indices
	_mesh.clear_surfaces()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


## Relative radius along the stream: a lip bulge, thinning as the metal speeds
## up, and rounded ends while the front or the tail is falling.
func _profile(s: float, cap: float) -> float:
	var r := lerpf(1.0, 0.62, sqrt(s)) * (1.0 + 0.25 * exp(-s * 25.0))
	if _head < 1.0:
		r *= sqrt(clampf((_head - s) / cap, 0.0, 1.0))
	if _tail > 0.0:
		r *= sqrt(clampf((s - _tail) / cap, 0.0, 1.0))
	return r
