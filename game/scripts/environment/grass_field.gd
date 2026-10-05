class_name GrassField
extends Node3D
## Grass tufts as MultiMesh chunks (8 x 8 m, culled per chunk): short lawn
## tufts, tall wild tufts along fences and walls, and a few flowering tufts.
## Density follows the ground zone mask (no grass on dirt, gravel, sand, soot
## or under buildings). Every frame the workers' positions are passed to the
## shared material so the blades bend away from their feet.

const CHUNK := 8.0
## Candidate spacing on the jittered grid (m): ~31 candidates per m².
const SPACING := 0.18
## How far beyond the fence grass keeps growing (m); hedges hide the rest.
const OUTSIDE_BAND := 3.0
## Flower colours: no saturated orange/yellow (reserved for heat).
const FLOWERS := [Color("#f4efe4"), Color("#c7b2e6"), Color("#9fc6ea"), Color("#e9b7c9"), Color("#f0e6a8")]
const TRAMPLE_RADIUS := 0.65

var layout: YardLayout
var material: ShaderMaterial
var tuft_count := 0
var _meshes: Array[ArrayMesh] = []
var _trample: Array[Vector4] = [Vector4.ZERO, Vector4.ZERO, Vector4.ZERO, Vector4.ZERO]


static func create(yard_layout: YardLayout) -> GrassField:
	var g := GrassField.new()
	g.name = "Grass"
	g.layout = yard_layout
	g._build()
	return g


func _process(_delta: float) -> void:
	var i := 0
	for p in get_tree().get_nodes_in_group(&"players"):
		if i >= 4:
			break
		var pos: Vector3 = (p as Node3D).global_position
		_trample[i] = Vector4(pos.x, pos.y, pos.z, TRAMPLE_RADIUS)
		i += 1
	while i < 4:
		_trample[i] = Vector4.ZERO
		i += 1
	material.set_shader_parameter(&"trample", _trample)


func _build() -> void:
	material = ShaderMaterial.new()
	material.shader = load("res://shaders/env_grass.gdshader")
	material.set_shader_parameter(&"trample", _trample)
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	# 0 lawn, 1 lawn variant, 2 wild/tall, 3 flowering.
	_meshes = [
		_tuft_mesh(rng, 8, 0.17, 0.55, 0, 2),
		_tuft_mesh(rng, 6, 0.14, 0.8, 0, 2),
		_tuft_mesh(rng, 11, 0.42, 0.45, 0, 3),
		_tuft_mesh(rng, 9, 0.3, 0.5, 3, 2),
	]
	var patch := FastNoiseLite.new()
	patch.seed = 77
	patch.frequency = 0.35
	var flower_noise := FastNoiseLite.new()
	flower_noise.seed = 78
	flower_noise.frequency = 0.22
	var density := EnvQuality.grass_density()
	var lo := YardLayout.YARD_MIN - Vector2(OUTSIDE_BAND, OUTSIDE_BAND)
	var hi := YardLayout.YARD_MAX + Vector2(OUTSIDE_BAND, OUTSIDE_BAND)
	# chunk key -> variant -> [transforms, customs]
	var chunks := {}
	var y := lo.y
	while y < hi.y:
		var x := lo.x
		while x < hi.x:
			var p := Vector2(x, y) + Vector2(rng.randf(), rng.randf()) * SPACING
			x += SPACING
			var roll := rng.randf()
			var w := _weight(p, patch)
			if roll > w * density:
				continue
			var edge := _edge_distance(p)
			var variant := 0 if rng.randf() < 0.6 else 1
			var wild := edge < 0.9 or patch.get_noise_2d(p.x * 0.7, p.y * 0.7 + 50.0) > 0.55
			if wild and rng.randf() < 0.75:
				variant = 2
			elif flower_noise.get_noise_2d(p.x, p.y) > 0.35 and rng.randf() < 0.22:
				variant = 3
			var s := rng.randf_range(0.75, 1.25)
			if edge < -0.5:
				s *= 1.25
			# Uniform scale only: the shader's world -> local bend relies on it.
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s)
			var pos := Vector3(p.x, YardGround.height_at(p, layout) - 0.01, p.y)
			var zones := layout.zones_at(p)
			var dry := clampf(zones.r * 1.5 + rng.randf() * 0.25 + maxf(patch.get_noise_2d(p.x + 30.0, p.y), 0.0) * 0.5, 0.0, 1.0)
			var key := Vector2i(floori(p.x / CHUNK), floori(p.y / CHUNK))
			if not chunks.has(key):
				chunks[key] = [[[], []], [[], []], [[], []], [[], []]]
			chunks[key][variant][0].append(Transform3D(basis, pos))
			chunks[key][variant][1].append(Color(rng.randf(), dry * 0.3, rng.randf(), 0.0))
		y += SPACING
	for key in chunks:
		for v in 4:
			var xs: Array = chunks[key][v][0]
			if xs.is_empty():
				continue
			add_child(_chunk(_meshes[v], xs, chunks[key][v][1]))
			tuft_count += xs.size()


## Probability of a tuft at `p` before the quality scale.
func _weight(p: Vector2, patch: FastNoiseLite) -> float:
	if layout.is_covered(p):
		return 0.0
	var z := layout.zones_at(p)
	var w := clampf(1.0 - z.r * 1.8, 0.0, 1.0) * (1.0 - z.g) * (1.0 - z.a) * (1.0 - z.b)
	var det := layout.detail_at(p)
	w *= (1.0 - det.r) * (1.0 - det.b)
	if w <= 0.0:
		return 0.0
	w *= clampf(0.75 + patch.get_noise_2d(p.x, p.y) * 0.6, 0.25, 1.0)
	var edge := _edge_distance(p)
	if edge < 0.0:
		# Outside the fence: denser near it, thinning out into the dark.
		w *= clampf(1.0 + edge / OUTSIDE_BAND, 0.0, 1.0) * 0.8
	return w


## Distance to the nearest fence line, negative outside the yard.
func _edge_distance(p: Vector2) -> float:
	var d := minf(minf(p.x - YardLayout.YARD_MIN.x, YardLayout.YARD_MAX.x - p.x), minf(p.y - YardLayout.YARD_MIN.y, YardLayout.YARD_MAX.y - p.y))
	return d


func _chunk(mesh: ArrayMesh, xs: Array, customs: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = xs.size()
	for i in xs.size():
		mm.set_instance_transform(i, xs[i])
		mm.set_instance_custom_data(i, customs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = EnvQuality.grass_distance()
	mmi.visibility_range_end_margin = 4.0
	return mmi


## One tuft: `blades` tapered, curved blades fanning out from the centre,
## each with `segments` (2 or 3) sections. `mode` 3 adds small flower heads.
static func _tuft_mesh(rng: RandomNumberGenerator, blades: int, height: float, spread: float, mode: int, segments: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var T: Array = [0.0, 0.38, 0.72, 1.0] if segments == 3 else [0.0, 0.55, 1.0]
	var W: Array = [1.0, 0.78, 0.45, 0.0] if segments == 3 else [1.0, 0.62, 0.0]
	for b in blades:
		var yaw := TAU * (b + rng.randf() * 0.6) / blades
		var out := Vector3(cos(yaw), 0.0, sin(yaw))
		var root := out * rng.randf_range(0.0, 0.05)
		var h := height * rng.randf_range(0.6, 1.0)
		var lean := rng.randf_range(0.15, spread)
		var width := rng.randf_range(0.022, 0.034) * (1.0 + height)
		# Blade plane: across = horizontal, slightly rotated off the radial direction.
		var across := out.rotated(Vector3.UP, PI * 0.5 + rng.randf_range(-0.5, 0.5))
		var pts := []
		for k in T.size():
			var t: float = T[k]
			var c := root + Vector3.UP * (h * t) + out * (h * lean * pow(t, 1.6))
			pts.append([c - across * width * W[k] * 0.5, c + across * width * W[k] * 0.5, t])
		var normal := across.cross(Vector3.UP + out * lean).normalized()
		if normal.dot(out) < 0.0:
			normal = -normal
		for k in segments:
			var a: Array = pts[k]
			var n: Array = pts[k + 1]
			_vert(st, a[0], normal, Vector2(0.0, a[2]), Color(1, 1, 1, 0))
			_vert(st, n[0], normal, Vector2(0.0, n[2]), Color(1, 1, 1, 0))
			_vert(st, a[1], normal, Vector2(1.0, a[2]), Color(1, 1, 1, 0))
			if k < segments - 1:
				_vert(st, a[1], normal, Vector2(1.0, a[2]), Color(1, 1, 1, 0))
				_vert(st, n[0], normal, Vector2(0.0, n[2]), Color(1, 1, 1, 0))
				_vert(st, n[1], normal, Vector2(1.0, n[2]), Color(1, 1, 1, 0))
		if mode == 3 and b % 3 == 0:
			var tip: Vector3 = (pts[segments][0] + pts[segments][1]) * 0.5
			var col: Color = (FLOWERS[rng.randi() % FLOWERS.size()] as Color).srgb_to_linear()
			var r := rng.randf_range(0.03, 0.045)
			for petal in 2:
				var a2 := petal * PI * 0.5 + rng.randf() * 0.3
				var u := Vector3(cos(a2), 0.0, sin(a2)) * r
				var v := Vector3(-sin(a2), 0.0, cos(a2)) * r
				var up := Vector3.UP * 0.008
				for tri in [[tip - u, tip + v + up, tip + u], [tip - u, tip + u, tip - v + up]]:
					for p in tri:
						_vert(st, p, Vector3.UP, Vector2(0.5, 1.0), col)
	return st.commit()


static func _vert(st: SurfaceTool, p: Vector3, n: Vector3, uv: Vector2, c: Color) -> void:
	st.set_normal(n)
	st.set_uv(uv)
	st.set_color(c)
	st.add_vertex(p)
