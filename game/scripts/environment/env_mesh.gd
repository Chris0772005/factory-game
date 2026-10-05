class_name EnvMesh
## Mesh and material helpers for the environment builders. Many small pieces
## (boards, trims, bricks) are merged into one mesh per material so the yard
## stays at a few hundred draw calls; every piece writes its random seed and
## wood-grain axis into vertex COLOR for the env shaders. Shared materials are
## cached by name.

static var _materials := {}
static var _meshes := {}


## False in headless runs (tests, servers): builders then add collisions only.
static func visual() -> bool:
	return DisplayServer.get_name() != "headless"


## A piece for merge(): mesh, transform, seed (0..1), grain axis in piece space.
static func piece(mesh: Mesh, xform: Transform3D, seed := 0.0, axis := Vector3.UP) -> Array:
	return [mesh, xform, seed, axis]


## Merges pieces into one single-surface mesh (vertex, normal, uv, colour).
## Transforms must not mirror (negative scale flips the winding).
static func merge(pieces: Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for pc in pieces:
		var mesh: Mesh = pc[0]
		var xf: Transform3D = pc[1]
		var axis: Vector3 = (xf.basis * (pc[3] as Vector3)).normalized()
		var col := Color(pc[2], axis.x * 0.5 + 0.5, axis.y * 0.5 + 0.5, axis.z * 0.5 + 0.5)
		var nb := xf.basis.inverse().transposed()
		for s in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var uv: Variant = arr[Mesh.ARRAY_TEX_UV]
			var idx: Variant = arr[Mesh.ARRAY_INDEX]
			var base := verts.size()
			var has_uv: bool = uv != null and (uv as PackedVector2Array).size() == v.size()
			for i in v.size():
				verts.append(xf * v[i])
				normals.append((nb * n[i]).normalized())
				colors.append(col)
				uvs.append((uv as PackedVector2Array)[i] if has_uv else Vector2.ZERO)
			if idx == null or (idx as PackedInt32Array).is_empty():
				for i in v.size():
					indices.append(base + i)
			else:
				for i in (idx as PackedInt32Array):
					indices.append(base + i)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var out := ArrayMesh.new()
	if not verts.is_empty():
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


## Adds a mesh instance (skipped headless). Returns it, or null.
static func add(parent: Node3D, mesh: Mesh, material: Material, xform := Transform3D(), shadows := true) -> MeshInstance3D:
	if not visual() or mesh == null or mesh.get_surface_count() == 0:
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.transform = xform
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Chamfered box (MeshFactory.rounded_box), cached.
static func box(size: Vector3, radius := -1.0, segments := 1) -> ArrayMesh:
	if radius < 0.0:
		radius = minf(0.03, minf(size.x, minf(size.y, size.z)) * 0.25)
	return MeshFactory.rounded_box(size, radius, segments)


static func cylinder(top: float, bottom: float, height: float, sides := 10) -> Mesh:
	var key := "cyl_%s_%s_%s_%s" % [top, bottom, height, sides]
	if not _meshes.has(key):
		var m := CylinderMesh.new()
		m.top_radius = top
		m.bottom_radius = bottom
		m.height = height
		m.radial_segments = sides
		m.rings = 1
		_meshes[key] = m
	return _meshes[key]


static func sphere(radius: float, segments := 10, rings := 6) -> Mesh:
	var key := "sph_%s_%s_%s" % [radius, segments, rings]
	if not _meshes.has(key):
		var m := SphereMesh.new()
		m.radius = radius
		m.height = radius * 2.0
		m.radial_segments = segments
		m.rings = rings
		_meshes[key] = m
	return _meshes[key]


## Shared ShaderMaterial `key` using `shader` (res path), created on first use
## with `params`.
static func material(key: String, shader: String, params := {}) -> ShaderMaterial:
	if _materials.has(key):
		return _materials[key]
	var mat := ShaderMaterial.new()
	mat.shader = load(shader)
	for p in params:
		mat.set_shader_parameter(p, params[p])
	_materials[key] = mat
	return mat


static func wood(key: String, params := {}) -> ShaderMaterial:
	return material("wood_" + key, "res://shaders/env_wood.gdshader", params)


static func surface(key: String, params := {}) -> ShaderMaterial:
	return material("surf_" + key, "res://shaders/env_surface.gdshader", params)


static func foliage(key: String, params := {}) -> ShaderMaterial:
	return material("fol_" + key, "res://shaders/env_foliage.gdshader", params)


## Transform helper: position, yaw/pitch/roll in degrees, uniform scale.
static func xf(pos: Vector3, rot_deg := Vector3.ZERO, scale := 1.0) -> Transform3D:
	var b := Basis.from_euler(rot_deg * (PI / 180.0)).scaled(Vector3.ONE * scale)
	return Transform3D(b, pos)
