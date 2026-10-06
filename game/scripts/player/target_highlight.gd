class_name TargetHighlight
extends Node
## Outline on whatever the local worker would grab or use next (Art Bible 5.4):
## the body `Player.grab_candidate()` returns, else the station from
## `Player.nearest_interactable()` that has something to say. A warm paper-white
## contour (#FFF3D6, 2 cm) with a 0.2 s pulse when the target changes, so in a
## crowd of four you see what your hands are about to take.
##
## Works on any material, shared or not: every mesh of the target gets a
## `material_overlay` that writes the stencil buffer where the target is visible
## (transparent pass, invisible), and its `next_pass` draws a hull grown along
## the normals only where the stencil is not set: a clean silhouette ring.
## The target's own materials are never touched. Local player only.

const OUTLINE_COLOR := Color("#fff3d6")
const THICKNESS := 0.02
## Pulse on a new target: the ring starts this much thicker and settles in PULSE_TIME.
const PULSE_THICKNESS := 0.045
const PULSE_TIME := 0.2
const OPACITY := 0.9
## Stencil reference; sorted after other transparent effects, before HUD labels.
const STENCIL_REF := 1
const MASK_PRIORITY := 7
const OUTLINE_PRIORITY := 8

const MASK_CODE := """
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_back, shadows_disabled, fog_disabled, blend_mix;
stencil_mode write, compare_always, %d;

void fragment() {
	ALBEDO = vec3(0.0);
	ALPHA = 0.0;
}
"""
const OUTLINE_CODE := """
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_back, shadows_disabled, fog_disabled, blend_mix, world_vertex_coords;
stencil_mode read, compare_not_equal, %d;

uniform vec4 outline_color : source_color = vec4(1.0);
uniform float thickness = 0.02;

void vertex() {
	VERTEX += normalize(NORMAL) * thickness;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a;
}
"""

var player: Player
var target: Node3D = null

var _mask: ShaderMaterial
var _outline: ShaderMaterial
var _meshes: Array[GeometryInstance3D] = []
var _pulse := 1.0


func _ready() -> void:
	var mask_shader := Shader.new()
	mask_shader.code = MASK_CODE % STENCIL_REF
	_mask = ShaderMaterial.new()
	_mask.shader = mask_shader
	_mask.render_priority = MASK_PRIORITY
	var outline_shader := Shader.new()
	outline_shader.code = OUTLINE_CODE % STENCIL_REF
	_outline = ShaderMaterial.new()
	_outline.shader = outline_shader
	_outline.render_priority = OUTLINE_PRIORITY
	_mask.next_pass = _outline
	_apply_style()


func _physics_process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_set_target(_pick())


func _process(delta: float) -> void:
	if _pulse < 1.0:
		_pulse = minf(1.0, _pulse + delta / PULSE_TIME)
		_apply_style()


func _exit_tree() -> void:
	_set_target(null)


## What the worker's hands would take (or use) right now.
func _pick() -> Node3D:
	if player.holding or player.ui_locked:
		return null
	var body := player.grab_candidate()
	if body:
		return body
	var station := player.nearest_interactable()
	if station and station.has_method("hint") and not String(station.hint(player)).is_empty():
		return station
	return null


func _set_target(node: Node3D) -> void:
	if node == target and (node == null or is_instance_valid(node)):
		return
	for mi in _meshes:
		if is_instance_valid(mi) and mi.material_overlay == _mask:
			mi.material_overlay = null
	_meshes.clear()
	target = node if node and is_instance_valid(node) else null
	if target == null:
		return
	for child in target.find_children("*", "GeometryInstance3D", true, false):
		var gi := child as GeometryInstance3D
		if gi is MeshInstance3D and _outlinable(gi as MeshInstance3D):
			gi.material_overlay = _mask
			_meshes.append(gi)
	_pulse = 0.0
	_apply_style()


## Solid, visible meshes only: no flames, smoke, glow cards, pour streams or
## other blended effects (their hull would draw a ring round the fire).
static func _outlinable(mi: MeshInstance3D) -> bool:
	if not mi.is_visible_in_tree() or mi.mesh == null or mi.material_overlay != null:
		return false
	var mat := mi.material_override
	if mat == null and mi.mesh.get_surface_count() > 0:
		mat = mi.get_active_material(0)
	if mat is BaseMaterial3D:
		var base := mat as BaseMaterial3D
		return base.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and base.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED
	if mat is ShaderMaterial:
		var shader := (mat as ShaderMaterial).shader
		if shader == null:
			return false
		var code := shader.code
		return not ("unshaded" in code or "blend_" in code or "depth_draw_never" in code)
	return true


func _apply_style() -> void:
	if _outline == null:
		return
	var k := 1.0 - (1.0 - _pulse) * (1.0 - _pulse)
	_outline.set_shader_parameter(&"thickness", lerpf(PULSE_THICKNESS, THICKNESS, k))
	var c := OUTLINE_COLOR
	c.a = OPACITY * lerpf(0.6, 1.0, k)
	_outline.set_shader_parameter(&"outline_color", c)
