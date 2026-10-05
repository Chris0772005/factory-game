class_name PropKit
## Places imported KayKit (CC0) models as set dressing: game scale per pack,
## the env_atlas material (shared per atlas + tint, so props batch well and
## get world-space variation, grime and rougher surfaces) and an optional box
## or cylinder collider fitted to the model's bounds.

const ROOT := "res://assets/models/"
## Uniform scale that brings each pack to game metres (see docs/ASSETS.md).
const PACK_SCALE := {
	"kaykit_adventurers": 0.8,
	"kaykit_dungeon": 0.8,
	"kaykit_restaurant": 0.8,
	"kaykit_furniture": 0.8,
	"kaykit_halloween": 0.8,
	"kaykit_prototype": 0.8,
	"kaykit_hexagon": 4.0,
	"kaykit_city": 4.0,
	"kenney_platformer": 1.0,
}

enum Solid { NONE, BOX, CYLINDER }

## KayKit's painted woods are bright orange; calmed by default so props never
## compete with the glow of hot metal (Art Bible 4.5).
const DEFAULT_TINT := Color(0.93, 0.89, 0.86)
const DEFAULT_DESATURATE := 0.3

static var _scenes := {}
static var _bounds := {}
static var _materials := {}


## Places `model` ("pack/file.gltf") at `pos` with `yaw` (deg). `opts`:
## scale (multiplies the pack scale), tilt (deg, random-ish lean), tint
## (Color), desaturate (0..1), solid (Solid), dirt, metallic, rough.
static func place(parent: Node3D, model: String, pos: Vector3, yaw := 0.0, opts := {}) -> Node3D:
	var pack := model.get_slice("/", 0)
	var s: float = PACK_SCALE.get(pack, 1.0) * float(opts.get("scale", 1.0))
	var tilt: Vector3 = opts.get("tilt", Vector3.ZERO)
	var basis := Basis.from_euler(Vector3(deg_to_rad(tilt.x), deg_to_rad(yaw), deg_to_rad(tilt.z))).scaled(Vector3.ONE * s)
	var xform := Transform3D(basis, pos)
	var solid: int = opts.get("solid", Solid.BOX)
	if solid != Solid.NONE:
		var box := bounds(model)
		var size := box.size * s
		if solid == Solid.CYLINDER:
			var r := maxf(size.x, size.z) * 0.5
			WorldBuilder.add_cylinder_collider(parent, r, size.y, pos + Vector3(0, box.position.y * s, 0))
		else:
			var c := box.get_center() * s
			var b := Basis.from_euler(Vector3(deg_to_rad(tilt.x), deg_to_rad(yaw), deg_to_rad(tilt.z)))
			WorldBuilder.add_collider(parent, size, Transform3D(b, pos + b * c))
	if not EnvMesh.visual():
		return null
	var node: Node3D = _scene(model).instantiate()
	node.transform = xform
	parent.add_child(node)
	_restyle(node, opts)
	return node


## Bounding box of the model at pack scale 1 (cached).
static func bounds(model: String) -> AABB:
	if _bounds.has(model):
		return _bounds[model]
	var node: Node3D = _scene(model).instantiate()
	var box := AABB()
	var first := true
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var xf := _relative(node, m)
		var b := xf * m.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	node.free()
	_bounds[model] = box
	return box


static func _relative(root: Node3D, n: Node3D) -> Transform3D:
	var xf := Transform3D()
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


static func _scene(model: String) -> PackedScene:
	if not _scenes.has(model):
		_scenes[model] = load(ROOT + model)
	return _scenes[model]


static func _restyle(node: Node3D, opts: Dictionary) -> void:
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for i in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(i)
			var tex: Texture2D = null
			if src is BaseMaterial3D:
				tex = (src as BaseMaterial3D).albedo_texture
			if tex == null:
				continue
			m.set_surface_override_material(i, _material(tex, opts))


static func _material(tex: Texture2D, opts: Dictionary) -> ShaderMaterial:
	var tint: Color = opts.get("tint", DEFAULT_TINT)
	var key := "%s|%s|%s|%s|%s|%s" % [tex.resource_path, tint.to_html(), opts.get("desaturate", DEFAULT_DESATURATE), opts.get("dirt", 0.25),
		opts.get("metallic", 0.0), opts.get("rough", 0.78)]
	if _materials.has(key):
		return _materials[key]
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/env_atlas.gdshader")
	mat.set_shader_parameter(&"atlas", tex)
	mat.set_shader_parameter(&"tint", tint)
	mat.set_shader_parameter(&"desaturate", opts.get("desaturate", DEFAULT_DESATURATE))
	mat.set_shader_parameter(&"dirt", opts.get("dirt", 0.25))
	mat.set_shader_parameter(&"metallic_base", opts.get("metallic", 0.0))
	mat.set_shader_parameter(&"roughness_base", opts.get("rough", 0.78))
	_materials[key] = mat
	return mat
