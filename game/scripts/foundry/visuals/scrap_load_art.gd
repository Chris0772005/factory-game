class_name ScrapLoadArt
## A load of scrap as it lies in a skip or on a truck bed: sheets, beams, plates, pipes, a drum and
## cans heaped from the floor of the container to a crown over its rim, in the materials of the scrap
## mountain. The pieces lie where they are; filling the container shows more of them from the floor
## up (`reveal`). Looks only: the stations count the pieces.

## Pieces per cubic metre of load.
const DENSITY := 110.0

## A pile standing on y = 0, centred in x and z, for a container that is `bottom` wide and long (x, z)
## at its floor and `rim` at `height`; the full pile rises `crown` over that in the middle.
## The same `seed_value` gives the same pile. `from` (0..1) leaves out what lies deeper than that
## share of the fill: a load that is only ever seen full needs no more than its top.
static func pile(bottom: Vector2, rim: Vector2, height: float, crown: float, seed_value := 7, from := 0.0) -> Node3D:
	var root := Node3D.new()
	root.name = "ScrapLoad"
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var rust := StationKit.metal("mountain_rust", {steel_color = Color("#6b6460"), rust = 0.75, dents = 0.8, metallic_steel = 0.6, roughness_steel = 0.55})
	var teal := StationKit.metal("mountain_teal", {steel_color = Color("#5c6468"), paint = 0.7, paint_color = Color("#3f6f78"), rust = 0.5, dents = 0.7})
	var red := StationKit.metal("mountain_red", {steel_color = Color("#5c6468"), paint = 0.65, paint_color = Color("#9a3f2c"), rust = 0.5, dents = 0.7})
	var ochre := StationKit.metal("mountain_ochre", {steel_color = Color("#5c6468"), paint = 0.6, paint_color = Color("#b38a34"), rust = 0.55, dents = 0.7})
	var shape := {bottom = bottom, rim = rim, height = height, crown = crown, from = clampf(from, 0.0, 0.95)}
	# How many pieces: by the room the load takes, less what `from` leaves out.
	var room := (bottom.x * bottom.y + rim.x * rim.y) * 0.5 * height + rim.x * rim.y * crown * 0.45
	var pieces := room * DENSITY * (1.0 - float(shape.from))
	var sheet := EnvMesh.box(Vector3(1.1, 0.03, 0.7), 0.01)
	var beam := EnvMesh.box(Vector3(1.9, 0.12, 0.12), 0.02)
	var plate := EnvMesh.box(Vector3(0.5, 0.06, 0.5), 0.02)
	var bit := EnvMesh.box(Vector3(0.22, 0.05, 0.3), 0.01)
	var pipe := EnvMesh.cylinder(0.05, 0.05, 1.5, 8)
	var drum := EnvMesh.cylinder(0.29, 0.29, 0.88, 14)
	# Shares of the pile, in pieces out of a hundred.
	_scatter(root, rng, shape, sheet, rust, _count(pieces, 12.0), 0.45, 0.85, 0.6, &"flat")
	_scatter(root, rng, shape, sheet, teal, _count(pieces, 2.5), 0.45, 0.75, 0.6, &"flat")
	_scatter(root, rng, shape, sheet, red, _count(pieces, 2.0), 0.45, 0.75, 0.6, &"flat")
	_scatter(root, rng, shape, plate, rust, _count(pieces, 23.0), 0.5, 1.2, 0.33, &"flat")
	_scatter(root, rng, shape, plate, ochre, _count(pieces, 3.5), 0.5, 1.1, 0.33, &"flat")
	_scatter(root, rng, shape, bit, rust, _count(pieces, 34.0), 0.6, 1.4, 0.18, &"tumbled")
	_scatter(root, rng, shape, beam, rust, _count(pieces, 4.5), 0.5, 0.85, 0.95, &"long")
	_scatter(root, rng, shape, pipe, ScrapModels.material(Color("#b36a3a")), _count(pieces, 4.0), 0.6, 0.95, 0.75, &"pipe")
	_scatter(root, rng, shape, drum, ochre if rng.randf() < 0.5 else teal, 2, 0.8, 0.95, 0.5, &"tumbled")
	_scatter(root, rng, shape, ScrapModels.mesh(&"scrap_can"), ScrapModels.material(Color("#aeb6bd")), _count(pieces, 13.0), 0.9, 1.3, 0.09, &"tumbled")
	_scatter(root, rng, shape, ScrapModels.mesh(&"scrap_kettle"), ScrapModels.material(Color("#b8652f")), _count(pieces, 1.0), 1.2, 1.8, 0.16, &"tumbled")
	return root


## Shows `pile` filled to `k`: 0 is empty, 1 heaped over the rim.
static func reveal(pile_root: Node3D, k: float) -> void:
	for child in pile_root.get_children():
		var mmi := child as MultiMeshInstance3D
		if mmi == null or not mmi.has_meta(&"levels"):
			continue
		var levels: PackedFloat32Array = mmi.get_meta(&"levels")
		mmi.multimesh.visible_instance_count = -1 if k >= 1.0 else levels.bsearch(k, false)


static func _count(pieces: float, share: float) -> int:
	return maxi(int(round(pieces * share / 100.0)), 1)


## `count` copies of `mesh` in the pile. `reach` is half the piece's length (m): a piece keeps that far
## from the container's walls, so nothing pokes through them. `lie`: flat, long (along the container),
## pipe (a standing cylinder laid down along it) or tumbled any way.
## Each piece gets a level (0..1): the share of the fill at which the pile reaches it. They are stored
## in that order, so `reveal` only has to say how many to draw.
static func _scatter(root: Node3D, rng: RandomNumberGenerator, shape: Dictionary, mesh: Mesh, mat: Material, count: int,
		scale_min: float, scale_max: float, reach: float, lie: StringName) -> void:
	var bottom: Vector2 = shape.bottom
	var rim: Vector2 = shape.rim
	var height: float = shape.height
	var along_z := rim.y >= rim.x
	var entries: Array = []
	for i in count:
		var s := rng.randf_range(scale_min, scale_max)
		var u := rng.randf_range(-1.0, 1.0)
		var v := rng.randf_range(-1.0, 1.0)
		# The full pile's top over this spot: the rim's height at the walls, the crown in the middle.
		var top := height + float(shape.crown) * (1.0 - u * u) * (1.0 - v * v)
		var level := rng.randf_range(float(shape.from), 1.0)
		var y := level * top
		var room := bottom.lerp(rim, clampf(y / height, 0.0, 1.0)) * 0.5
		# Long pieces lie along the container: they need their length that way only.
		var keep := Vector2(reach * s, reach * s)
		if lie == &"long" or lie == &"pipe":
			keep = Vector2(reach * s * 0.5, reach * s) if along_z else Vector2(reach * s, reach * s * 0.5)
		var pos := Vector3(u * maxf(room.x - keep.x, 0.03), y + rng.randf_range(-0.03, 0.03), v * maxf(room.y - keep.y, 0.03))
		pos.y = maxf(pos.y, 0.03)
		var yaw := rng.randf_range(-0.45, 0.45) + (PI * 0.5 if along_z else 0.0) + (PI if rng.randf() < 0.5 else 0.0)
		var basis := Basis()
		match lie:
			&"flat":
				basis = Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3)) * Basis(Vector3.BACK, rng.randf_range(-0.3, 0.3))
			&"long":
				basis = Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, rng.randf_range(-0.22, 0.22))
			&"pipe":
				basis = Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, PI * 0.5 + rng.randf_range(-0.2, 0.2))
			_:
				basis = Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU))
		entries.append([level, Transform3D(basis.scaled(Vector3.ONE * s), pos)])
	entries.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	var levels := PackedFloat32Array()
	for i in count:
		mm.set_instance_transform(i, entries[i][1])
		levels.append(entries[i][0])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.set_meta(&"levels", levels)
	root.add_child(mmi)
