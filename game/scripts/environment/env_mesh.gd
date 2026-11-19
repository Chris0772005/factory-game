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


## Photo scans in assets/textures/scan (Poly Haven, CC0): the edge length of one repeat in metres, as the
## scan was shot, and the scan's mean colour (linear), which `toward` uses to tint one to a wanted colour.
const SCAN_DIR := "res://assets/textures/scan/"
const SCANS := {
	"asphalt_02": [3.0, Color(0.104, 0.103, 0.091)],
	"concrete_pavers": [1.9, Color(0.139, 0.114, 0.088)],
	"concrete_tiles_02": [1.8, Color(0.137, 0.125, 0.108)],
	"dirty_concrete": [3.0, Color(0.252, 0.23, 0.19)],
	"red_brick_03": [1.0, Color(0.15, 0.095, 0.078)],
	"red_brick": [1.4, Color(0.275, 0.137, 0.084)],
	"painted_worn_brick": [1.8, Color(0.406, 0.338, 0.188)],
	"beige_wall_001": [3.0, Color(0.34, 0.262, 0.188)],
	"yellow_plaster": [2.0, Color(0.26, 0.188, 0.074)],
	"box_profile_metal_sheet": [2.0, Color(0.145, 0.019, 0.009)],
	"bitumen": [20.0, Color(0.043, 0.038, 0.035)],
}


## A surface straight from a photo scan (shaders/env_scan.gdshader): real colour, relief and roughness,
## laid on in world space at the scan's true size. `scan_name` is a key of SCANS.
## params: tint (factor), drift, foot, foot_height, normal_strength, roughness_scale, shift, tile.
static func scan(key: String, scan_name: String, params := {}) -> ShaderMaterial:
	if _materials.has("scan_" + key):
		return _materials["scan_" + key]
	var all := {
		albedo_map = load(SCAN_DIR + scan_name + "_d.jpg"),
		normal_map = load(SCAN_DIR + scan_name + "_n.jpg"),
		arm_map = load(SCAN_DIR + scan_name + "_arm.jpg"),
		tile = float(SCANS[scan_name][0]),
	}
	all.merge(params, true)
	return material("scan_" + key, "res://shaders/env_scan.gdshader", all)


## The tint that brings a scan's mean colour to `wanted` (`amount` 0..1: how far it goes there). For
## scans whose own colour is near that already; see `repainted` for a different paint.
static func toward(scan_name: String, wanted: Color, amount := 1.0) -> Vector3:
	var mean: Color = SCANS[scan_name][1]
	var lin := wanted.srgb_to_linear()
	return Vector3.ONE.lerp(Vector3(lin.r / maxf(mean.r, 0.02), lin.g / maxf(mean.g, 0.02), lin.b / maxf(mean.b, 0.02)), amount)


## The same scan in another paint: only its light and dark are kept and brought to `wanted`. For scans
## with a strong colour of their own (painted sheet), where a tint would only amplify one channel's noise.
static func repainted(key: String, scan_name: String, wanted: Color, params := {}) -> ShaderMaterial:
	var mean: Color = SCANS[scan_name][1]
	var light := maxf(mean.r * 0.2126 + mean.g * 0.7152 + mean.b * 0.0722, 0.005)
	var lin := wanted.srgb_to_linear()
	var all := {grey = 1.0, tint = Vector3(lin.r, lin.g, lin.b) / light}
	all.merge(params, true)
	return scan(key, scan_name, all)


static func foliage(key: String, params := {}) -> ShaderMaterial:
	return material("fol_" + key, "res://shaders/env_foliage.gdshader", params)


## Transform helper: position, yaw/pitch/roll in degrees, uniform scale.
static func xf(pos: Vector3, rot_deg := Vector3.ZERO, scale := 1.0) -> Transform3D:
	var b := Basis.from_euler(rot_deg * (PI / 180.0)).scaled(Vector3.ONE * scale)
	return Transform3D(b, pos)
