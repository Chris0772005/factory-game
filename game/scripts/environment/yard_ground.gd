class_name YardGround
## Ground of the backyard: one mesh that is flat wherever people work and
## gently lumpy on the lawn (never below y = 0, so nothing seems to float),
## rolling softly beyond the fence; the zone-mask ground shader; and a flat
## collision slab whose top is y = 0.

## Ground mesh size and centre (x, z) in metres; vertex spacing.
const SIZE := Vector2(100.0, 92.0)
const CENTER := Vector2(0.0, -4.0)
const STEP := 0.6

static var _noise: FastNoiseLite


## Builds the ground under `parent` and returns its mesh instance (null headless).
static func build(parent: Node3D, layout: YardLayout) -> MeshInstance3D:
	var mi: MeshInstance3D = null
	if EnvMesh.visual():
		mi = MeshInstance3D.new()
		mi.name = "Ground"
		mi.mesh = _build_mesh(layout)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/env_ground.gdshader")
		mat.set_shader_parameter(&"zone_mask", ImageTexture.create_from_image(layout.mask))
		mat.set_shader_parameter(&"mask_rect", layout.mask_rect())
		mi.material_override = mat
		parent.add_child(mi)
	var body := StaticBody3D.new()
	body.name = "GroundCollision"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(SIZE.x, 1.0, SIZE.y)
	shape.shape = box
	body.position = Vector3(CENTER.x, -0.5, CENTER.y)
	body.add_child(shape)
	parent.add_child(body)
	return mi


## Visual ground height at a world (x, z): 0 on dirt, gravel and sand, small
## bumps on the lawn, slow rolling hills outside the fence.
static func height_at(p: Vector2, layout: YardLayout) -> float:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = 1307
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_noise.frequency = 1.0
	var z := layout.zones_at(p)
	var worked := clampf(z.r * 1.6 + z.g + z.a + z.b, 0.0, 1.0)
	var bumps := (_noise.get_noise_2d(p.x * 0.45, p.y * 0.45) * 0.5 + 0.5) * 0.06
	bumps += (_noise.get_noise_2d(p.x * 1.7 + 40.0, p.y * 1.7) * 0.5 + 0.5) * 0.02
	var outside := _distance_outside_yard(p)
	var hills := smoothstep(1.5, 9.0, outside) * (_noise.get_noise_2d(p.x * 0.06 + 9.0, p.y * 0.06) * 0.5 + 0.5) * 0.7
	return bumps * (1.0 - worked) + hills


static func _distance_outside_yard(p: Vector2) -> float:
	var dx := maxf(YardLayout.YARD_MIN.x - p.x, p.x - YardLayout.YARD_MAX.x)
	var dz := maxf(YardLayout.YARD_MIN.y - p.y, p.y - YardLayout.YARD_MAX.y)
	return Vector2(maxf(dx, 0.0), maxf(dz, 0.0)).length()


static func _build_mesh(layout: YardLayout) -> ArrayMesh:
	var nx := int(SIZE.x / STEP) + 1
	var nz := int(SIZE.y / STEP) + 1
	var origin := CENTER - SIZE * 0.5
	var heights := PackedFloat32Array()
	heights.resize(nx * nz)
	for j in nz:
		for i in nx:
			heights[j * nx + i] = height_at(origin + Vector2(i, j) * STEP, layout)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	verts.resize(nx * nz)
	normals.resize(nx * nz)
	for j in nz:
		for i in nx:
			var h := heights[j * nx + i]
			var p := origin + Vector2(i, j) * STEP
			verts[j * nx + i] = Vector3(p.x, h, p.y)
			var hl := heights[j * nx + maxi(i - 1, 0)]
			var hr := heights[j * nx + mini(i + 1, nx - 1)]
			var hd := heights[maxi(j - 1, 0) * nx + i]
			var hu := heights[mini(j + 1, nz - 1) * nx + i]
			normals[j * nx + i] = Vector3(hl - hr, 2.0 * STEP, hd - hu).normalized()
	var indices := PackedInt32Array()
	indices.resize((nx - 1) * (nz - 1) * 6)
	var k := 0
	for j in nz - 1:
		for i in nx - 1:
			var a := j * nx + i
			var b := a + 1
			var c := a + nx
			var d := c + 1
			# Clockwise seen from above (Godot front faces).
			indices[k] = a
			indices[k + 1] = b
			indices[k + 2] = c
			indices[k + 3] = b
			indices[k + 4] = d
			indices[k + 5] = c
			k += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
