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
	aim_grain(mi)
	parent.add_child(mi)
	return mi


## A wooden mesh that is one piece (no colours from merge()) gets its grain along its longest side;
## the wood shader reads that from the instance. Call again after swapping the mesh.
static func aim_grain(mi: MeshInstance3D) -> void:
	var mat := mi.material_override as ShaderMaterial
	if mat == null or mat.shader == null or not mat.shader.resource_path.ends_with("env_wood.gdshader") or mi.mesh == null:
		return
	var size := mi.mesh.get_aabb().size
	var axis := Vector3.UP
	if size.x >= size.y and size.x >= size.z:
		axis = Vector3.RIGHT
	elif size.z >= size.y:
		axis = Vector3.BACK
	mi.set_instance_shader_parameter(&"grain_axis", axis)


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
	if _materials.has("wood_" + key):
		return _materials["wood_" + key]
	# Sawn boards for worked wood, a cracked old beam for what has stood in the weather; `scan` names
	# another (a key of WOOD_SCANS).
	var scan: String = params.get("scan", "rough_wood" if float(params.get("weathering", 0.35)) >= 0.6 else "wood_planks")
	var all := scan_maps(scan)
	all.merge(WOOD_SCANS[scan], true)
	all.merge(params, true)
	all.erase("scan")
	return material("wood_" + key, "res://shaders/env_wood.gdshader", all)


## The three maps of a scan and its mean colour, as the parameters the scan-based shaders share.
static func scan_maps(scan_name: String) -> Dictionary:
	var mean: Color = SCANS[scan_name][1]
	return {
		albedo_map = load(SCAN_DIR + scan_name + "_d.jpg"),
		normal_map = load(SCAN_DIR + scan_name + "_n.jpg"),
		arm_map = load(SCAN_DIR + scan_name + "_arm.jpg"),
		tile = float(SCANS[scan_name][0]),
		scan_mean = Vector3(mean.r, mean.g, mean.b),
	}


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
	"green_metal_rust": [1.0, Color(0.05, 0.074, 0.034)],
	"floor_tiles_06": [3.0, Color(0.203, 0.168, 0.154)],
	"long_white_tiles": [1.27, Color(0.614, 0.57, 0.472)],
	"garage_floor": [1.9, Color(0.202, 0.154, 0.095)],
	"double_brick_floor": [2.2, Color(0.151, 0.058, 0.021)],
	"roof_planks": [1.5, Color(0.183, 0.069, 0.021)],
	"factory_brick": [1.5, Color(0.244, 0.154, 0.096)],
	"hangar_concrete_floor": [2.0, Color(0.034, 0.030, 0.026)],
	"large_sandstone_blocks": [3.0, Color(0.100, 0.093, 0.075)],
	"roof_slates_03": [3.0, Color(0.167, 0.160, 0.140)],
	"rusty_metal_sheet": [2.0, Color(0.186, 0.157, 0.092)],
	"rust_coarse_01": [2.2, Color(0.128, 0.043, 0.015)],
	"wood_planks": [1.5, Color(0.191, 0.099, 0.041)],
	"rough_wood": [0.5, Color(0.148, 0.124, 0.098)],
	"sand_02": [2.1, Color(0.119, 0.093, 0.064)],
	"clay_floor_001": [2.0, Color(0.195, 0.116, 0.047)],
}
## The scans wood is made of (shaders/env_wood.gdshader): edge length used (m; old timber is laid on
## larger than life, or a long beam repeats every half metre), the mean of the roughness map and
## whether the grain runs up the image.
const WOOD_SCANS := {
	"wood_planks": {tile = 1.5, rough_mean = 0.86, grain_up = false},
	"rough_wood": {tile = 1.0, rough_mean = 0.51, grain_up = true},
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


## Lets go of the scan materials (and with them their textures) once a level that used them is gone:
## the next level that asks for one builds it afresh.
static func release_scans() -> void:
	for key: String in _materials.keys():
		if key.begins_with("scan_"):
			_materials.erase(key)


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
