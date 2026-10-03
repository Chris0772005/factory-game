class_name FurnaceFire
extends Node3D
## Stylised furnace fire: toon flame billboards, a flickering warm light and
## rising embers. `heat` (0..1) scales all of it; 0 puts the fire out.
## The node origin is the base of the flames.

const SHADER_PATH := "res://shaders/fx_flame.gdshader"
## [offset x, offset z, relative size] of each flame tongue.
const TONGUES := [[0.0, -0.1, 0.95], [0.7, 0.3, 0.6], [-0.65, 0.4, 0.55], [0.45, -0.55, 0.7], [-0.5, -0.5, 0.75], [0.05, 0.65, 0.5]]

## Footprint radius of the fire bed. Set the exports before adding the node:
## the flame layout, light range and shadows are applied in `_ready`.
@export var radius := 0.22
## Flame height at full heat.
@export var height := 0.75
@export var light_energy := 1.6
@export var light_range := 3.5
@export var cast_shadows := false

var heat := 0.0:
	set(value):
		heat = clampf(value, 0.0, 1.0)
		_apply_heat()

var _mat: ShaderMaterial
var _flames: Array[MeshInstance3D] = []
var _light: OmniLight3D
var _embers: GPUParticles3D
var _time := 0.0


func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = load(SHADER_PATH)
	_mat.render_priority = 1
	var quad := QuadMesh.new()
	quad.center_offset = Vector3(0, 0.5, 0)
	for i in TONGUES.size():
		var t: Array = TONGUES[i]
		var flame := MeshInstance3D.new()
		flame.position = Vector3(t[0], 0.0, t[1]) * radius
		flame.mesh = quad
		flame.material_override = _mat
		flame.layers = FoundryFX.FX_LAYER
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# The shader turns and tilts the flat quad towards the camera.
		flame.extra_cull_margin = height * 0.7
		flame.set_instance_shader_parameter(&"seed", i * 1.618 + randf())
		add_child(flame)
		_flames.append(flame)
	_light = OmniLight3D.new()
	_light.light_color = Color("#ff8c3a")
	_light.omni_range = light_range
	_light.omni_attenuation = 0.7
	_light.shadow_enabled = cast_shadows
	add_child(_light)
	_embers = FoundryFX.make_embers(28, Vector3(radius * 0.7, 0.05, radius * 0.7))
	_embers.position = Vector3(0, height * 0.3, 0)
	add_child(_embers)
	_apply_heat()


func _process(delta: float) -> void:
	_time += delta
	if heat <= 0.0:
		return
	var flicker := 0.82 + 0.1 * sin(_time * 11.3) + 0.06 * sin(_time * 23.7 + 1.3) + 0.05 * sin(_time * 5.1)
	_light.light_energy = light_energy * heat * flicker
	_light.position = Vector3(sin(_time * 7.0) * 0.03, height * (0.6 + 0.3 * heat), cos(_time * 9.0) * 0.03)
	for i in _flames.size():
		var t: Array = TONGUES[i]
		var pulse := 1.0 + 0.08 * sin(_time * (5.0 + i) + i * 2.0)
		var h := height * float(t[2]) * lerpf(0.35, 1.0, heat) * pulse
		_flames[i].scale = Vector3(radius * 2.1 * float(t[2]) * lerpf(0.7, 1.0, heat), h, 1.0)


func _apply_heat() -> void:
	if not is_node_ready():
		return
	var on := heat > 0.0
	_mat.set_shader_parameter(&"heat", heat)
	for flame in _flames:
		flame.visible = on
	_light.visible = on
	_light.light_energy = light_energy * heat
	_embers.emitting = heat > 0.15
	_embers.amount_ratio = clampf(heat, 0.1, 1.0)
	_process(0.0)
