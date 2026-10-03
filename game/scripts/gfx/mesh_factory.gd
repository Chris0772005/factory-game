class_name MeshFactory
## Procedural meshes for the stylized look. Results are cached by parameters.

static var _cache := {}


## Box with rounded edges: each face is a grid whose outer rows are pushed
## onto a sphere of `radius` around the shrunken inner box.
static func rounded_box(size: Vector3, radius := 0.08, segments := 3) -> ArrayMesh:
	var key := "rb_%s_%s_%s" % [size, radius, segments]
	if _cache.has(key):
		return _cache[key]
	var half := size * 0.5
	radius = minf(radius, minf(half.x, minf(half.y, half.z)) * 0.999)
	var inner := half - Vector3.ONE * radius
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := [
		[Vector3.RIGHT, Vector3.BACK, Vector3.UP],
		[Vector3.LEFT, Vector3.BACK, Vector3.UP],
		[Vector3.UP, Vector3.RIGHT, Vector3.BACK],
		[Vector3.DOWN, Vector3.RIGHT, Vector3.BACK],
		[Vector3.BACK, Vector3.RIGHT, Vector3.UP],
		[Vector3.FORWARD, Vector3.RIGHT, Vector3.UP],
	]
	for f in faces:
		var normal: Vector3 = f[0]
		var u_axis: Vector3 = f[1]
		var v_axis: Vector3 = f[2]
		var us := _params(radius / absf(u_axis.dot(half)), segments)
		var vs := _params(radius / absf(v_axis.dot(half)), segments)
		var grid := []
		for v in vs:
			var row := []
			for u in us:
				var p: Vector3 = (normal + u_axis * u + v_axis * v) * half
				var c := p.clamp(-inner, inner)
				var dir := p - c
				var nrm := dir.normalized() if dir.length_squared() > 1e-12 else normal
				row.append([c + nrm * radius, nrm])
			grid.append(row)
		for j in range(vs.size() - 1):
			for i in range(us.size() - 1):
				_quad(st, grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i], normal)
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh


## Grid coordinates in [-1, 1]: `segments` steps across each rounded band,
## one step across the flat middle.
static func _params(band: float, segments: int) -> Array:
	var out := []
	for k in range(segments + 1):
		out.append(-1.0 + band * k / segments)
	for k in range(segments + 1):
		out.append(1.0 - band + band * k / segments)
	return out


static func _quad(st: SurfaceTool, a: Array, b: Array, c: Array, d: Array, normal: Vector3) -> void:
	# Godot treats clockwise triangles (seen from outside) as front faces.
	var tris := [[a, b, c], [a, c, d]]
	for t in tris:
		var e1: Vector3 = t[1][0] - t[0][0]
		var e2: Vector3 = t[2][0] - t[0][0]
		var cross := e1.cross(e2)
		if cross.length_squared() < 1e-14:
			continue
		if cross.dot(normal) > 0.0:
			t = [t[0], t[2], t[1]]
		for vtx in t:
			st.set_normal(vtx[1])
			st.add_vertex(vtx[0])
