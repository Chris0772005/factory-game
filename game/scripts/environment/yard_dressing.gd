class_name YardDressing
## Hand-placed set dressing for the backyard (Art Bible 10): dense, storied
## edges along the house, the fences and the shed, open walkways around the
## stations, and a neighbourhood behind the fence (houses, trees, hedges,
## a utility pole) so the yard never ends in emptiness. Every solid prop is
## checked against the station keep-out zones and marked as covered so no
## grass grows through it.

const P := PropKit.Solid

var root: Node3D
var layout: YardLayout
var _warnings := 0


static func build(parent: Node3D, yard_layout: YardLayout) -> void:
	var d := YardDressing.new()
	d.layout = yard_layout
	d.root = Node3D.new()
	d.root.name = "Dressing"
	parent.add_child(d.root)
	d._house_strip()
	d._seating_corner()
	d._right_strip()
	d._junk_corner()
	d._shed_surroundings()
	d._front_lawn()
	d._work_area()
	d._background()


## A solid KayKit prop; warns if it ends up in a station's walk-around zone.
## Anything standing on the ground also keeps the grass from growing through it.
func prop(model: String, pos: Vector3, yaw := 0.0, opts := {}) -> void:
	var solid: int = opts.get("solid", P.BOX)
	var box := PropKit.bounds(model)
	var s: float = PropKit.PACK_SCALE.get(model.get_slice("/", 0), 1.0) * float(opts.get("scale", 1.0))
	var r := maxf(box.size.x, box.size.z) * s * 0.5
	if solid != P.NONE:
		_check(Vector2(pos.x, pos.z), r * 0.8, model)
	if pos.y < 0.2:
		layout.cover(Vector2(pos.x, pos.z), r * 0.8)
	PropKit.place(root, model, pos, yaw, opts)


func _check(p: Vector2, r: float, what: String) -> void:
	if not layout.is_free(p, r):
		_warnings += 1
		push_warning("YardDressing: %s at %s stands in a station's walkway" % [what, p])


## Along the back wall of the house: rain barrel, bench, stepping stones to
## the back door, bin bags, crates, a potting table, sacks, pots, a ladder.
func _house_strip() -> void:
	var z := YardLayout.HOUSE_FRONT_Z
	prop("kaykit_dungeon/barrel_small.gltf", Vector3(5.25, 0, z + 0.48), 20.0, {solid = P.CYLINDER, tint = Color("#c9c2b8")})
	prop("kaykit_halloween/bench.gltf", Vector3(-7.25, 0, z + 0.55), 0.0, {tilt = Vector3(0, 0, 1.2)})
	YardProps.pot(root, Vector3(-8.35, 0, z + 0.45), 0.42, 11)
	YardProps.pot(root, Vector3(-6.0, 0, z + 0.4), 0.32, 12, Color("#c8d8a8"))
	YardProps.pot(root, Vector3(-5.6, 0, z + 0.62), 0.24, 13)
	for i in 3:
		prop("kaykit_halloween/path_%s.gltf" % ["A", "C", "B"][i], Vector3(-4.0 + [0.0, 0.25, -0.1][i], 0.0, z + 1.55 + i * 1.05),
			[0.0, 40.0, 75.0][i], {solid = P.NONE, scale = 0.62, tint = Color("#c9c4bd")})
	prop("kaykit_city/trash_A.gltf", Vector3(-5.2, 0, z + 0.5), 30.0, {solid = P.NONE})
	prop("kaykit_city/trash_B.gltf", Vector3(-5.0, 0, z + 1.0), -20.0, {solid = P.NONE})
	prop("kaykit_hexagon/crate_open.gltf", Vector3(-2.55, 0, z + 0.6), 8.0, {scale = 0.8, desaturate = 0.45})
	prop("kaykit_hexagon/crate_A_big.gltf", Vector3(-2.25, 0, z + 1.05), -12.0, {scale = 0.55})
	prop("kaykit_dungeon/table_medium.gltf", Vector3(1.55, 0, z + 0.72), 90.0, {scale = 0.85, tilt = Vector3(0, 0, 0.8)})
	prop("kaykit_restaurant/pot_B.gltf", Vector3(1.3, 0.69, z + 0.75), 30.0, {solid = P.NONE, scale = 0.45, desaturate = 0.4,
		tint = Color("#9a8f86"), metallic = 0.4, rough = 0.5})
	prop("kaykit_restaurant/jar_A_large.gltf", Vector3(1.9, 0.69, z + 0.62), 0.0, {solid = P.NONE, scale = 0.5})
	prop("kaykit_dungeon/bottle_A_brown.gltf", Vector3(2.05, 0.69, z + 0.9), 0.0, {solid = P.NONE, scale = 0.35})
	YardProps.pot(root, Vector3(0.9, 0.69, z + 0.6), 0.22, 14)
	for i in 3:
		prop("kaykit_hexagon/sack.gltf", Vector3(-1.5 + i * 0.42, 0, z + 0.55 + (i % 2) * 0.12), 80.0 + i * 25.0,
			{solid = P.NONE, scale = 0.9, tint = Color("#b8a88c"), desaturate = 0.6})
	prop("kaykit_hexagon/sack.gltf", Vector3(-1.3, 0.28, z + 0.62), 95.0, {solid = P.NONE, scale = 0.9, tint = Color("#b8a88c"), desaturate = 0.6})
	layout.cover(Vector2(-1.1, z + 0.6), 0.8)
	prop("kaykit_hexagon/ladder.gltf", Vector3(3.9, 0, z + 0.42), 0.0, {solid = P.NONE, scale = 0.62, tilt = Vector3(-12, 0, 0)})
	YardProps.tool(root, Vector3(4.45, 0, z + 0.3), Vector3(0, 0, -1), false)


## Garden table with chairs and mugs right of the house: the after-work spot.
func _seating_corner() -> void:
	var c := Vector3(9.7, 0, -7.25)
	prop("kaykit_furniture/table_medium.gltf", c, 8.0, {scale = 0.9})
	prop("kaykit_furniture/chair_A_wood.gltf", c + Vector3(-0.95, 0, 0.1), 95.0, {tilt = Vector3(0, 0, 1.5)})
	prop("kaykit_furniture/chair_A_wood.gltf", c + Vector3(0.9, 0, -0.2), -70.0)
	prop("kaykit_adventurers/mug_full.gltf", c + Vector3(-0.25, 0.73, 0.1), 40.0, {solid = P.NONE, scale = 0.5})
	prop("kaykit_adventurers/mug_empty.gltf", c + Vector3(0.3, 0.73, -0.15), -20.0, {solid = P.NONE, scale = 0.5})
	prop("kaykit_halloween/lantern_standing.gltf", c + Vector3(0.05, 0.73, -0.35), 10.0, {solid = P.NONE, scale = 0.45})
	if EnvMesh.visual() and not EnvQuality.is_low():
		var lamp := OmniLight3D.new()
		lamp.light_color = Color("#ffbf73")
		lamp.light_energy = 0.8
		lamp.omni_range = 2.8
		lamp.position = c + Vector3(0.05, 0.95, -0.35)
		root.add_child(lamp)
	prop("kaykit_hexagon/crate_A_big.gltf", Vector3(11.85, 0, -8.35), 12.0, {scale = 0.85})
	prop("kaykit_hexagon/crate_A_big.gltf", Vector3(11.9, 0.68, -8.3), -8.0, {scale = 0.7, solid = P.NONE})
	prop("kaykit_prototype/Pallet_Small.gltf", Vector3(10.6, 0.0, -8.62), 0.0, {solid = P.NONE, tilt = Vector3(-78, 0, 0), scale = 0.75})
	YardProps.pot(root, Vector3(7.0, 0, -8.55), 0.5, 21)
	StylizedTree.bush(root, Vector3(8.0, 0, -8.4), 0.55, 22)


## Right side: clothes line, wheelbarrow, raised bed, pallets by the sell crate.
func _right_strip() -> void:
	YardProps.clothes_line(root, Vector3(11.3, 0, -5.1), Vector3(11.3, 0, 0.6), 31)
	layout.cover(Vector2(11.3, -5.1), 0.15)
	layout.cover(Vector2(11.3, 0.6), 0.15)
	prop("kaykit_hexagon/wheelbarrow.gltf", Vector3(9.3, 0, -2.4), 35.0, {scale = 0.7})
	YardProps.raised_bed(root, Vector3(10.4, 0, 6.2), 0.0, Vector2(2.6, 1.1), 32)
	_check(Vector2(10.4, 6.2), 1.3, "raised bed")
	layout.cover(Vector2(10.4, 6.2), 1.2)
	prop("kaykit_prototype/Pallet_Small.gltf", Vector3(8.9, 0, 4.1), 20.0, {scale = 0.8})
	prop("kaykit_prototype/Pallet_Small.gltf", Vector3(8.9, 0.32, 4.15), 26.0, {scale = 0.8, solid = P.NONE})
	prop("kaykit_restaurant/crate.gltf", Vector3(8.85, 0.62, 4.1), 14.0, {scale = 0.6, solid = P.NONE})
	prop("kaykit_hexagon/bucket_empty.gltf", Vector3(9.6, 0, 2.9), 0.0, {solid = P.CYLINDER, scale = 0.75})
	YardProps.tool(root, Vector3(12.25, 0, 3.3), Vector3(1, 0, 0), true)
	StylizedTree.bush(root, Vector3(11.8, 0, 8.2), 0.75, 33)
	StylizedTree.bush(root, Vector3(12.0, 0, -3.0), 0.6, 34)
	prop("kaykit_hexagon/rock_single_C.gltf", Vector3(9.0, 0, 7.6), 30.0, {scale = 0.32, solid = P.NONE})


## Left side behind the scrap heap: tyres, rusty drums, sheets, lumber.
func _junk_corner() -> void:
	YardProps.tyres(root, Vector3(-11.0, 0, -1.4), 3, 41)
	_check(Vector2(-11.0, -1.4), 0.42, "tyres")
	layout.cover(Vector2(-11.0, -1.4), 0.45)
	YardProps.tyres(root, Vector3(-10.2, 0, -2.3), 1, 42)
	prop("kaykit_prototype/Barrel_A.gltf", Vector3(-11.8, 0, -2.65), 15.0, {solid = P.CYLINDER, tint = Color("#9b8578"), desaturate = 0.65, dirt = 0.6})
	prop("kaykit_prototype/Barrel_C.gltf", Vector3(-11.75, 0, -3.5), -30.0, {solid = P.CYLINDER, tint = Color("#8c8f94"), desaturate = 0.6, dirt = 0.6})
	YardProps.scrap_lean(root, Vector3(-12.3, 0, 0.4), Vector3(1, 0, 0), 43)
	layout.cover(Vector2(-11.9, 0.6), 0.7)
	WorldBuilder.add_collider(root, Vector3(0.6, 1.2, 1.6), Transform3D(Basis(), Vector3(-12.0, 0.6, 0.7)))
	prop("kaykit_hexagon/resource_lumber.gltf", Vector3(-11.75, 0, 2.9), 90.0, {scale = 0.55})
	prop("kaykit_hexagon/crate_A_big.gltf", Vector3(-11.75, 0, 4.6), 14.0, {scale = 0.85})
	prop("kaykit_hexagon/crate_A_big.gltf", Vector3(-11.7, 0.68, 4.65), -6.0, {scale = 0.75, solid = P.NONE})
	prop("kaykit_hexagon/crate_long_empty.gltf", Vector3(-11.55, 0, 5.55), 85.0, {scale = 0.7})
	prop("kaykit_hexagon/wheelbarrow.gltf", Vector3(-8.7, 0, 3.0), -35.0, {scale = 0.7})
	prop("kaykit_prototype/Can_A.gltf", Vector3(-8.75, 0.42, 3.05), 0.0, {solid = P.NONE, scale = 0.6, desaturate = 0.5, tint = Color("#a9a39a")})
	prop("kaykit_prototype/Can_B.gltf", Vector3(-10.4, 0, -0.5), 60.0, {solid = P.NONE, scale = 0.6, tilt = Vector3(90, 0, 0), desaturate = 0.5, tint = Color("#a9a39a")})
	prop("kaykit_dungeon/sword_shield_broken.gltf", Vector3(-10.2, 0, 0.6), 110.0, {solid = P.NONE, scale = 0.5, desaturate = 0.4})


func _shed_surroundings() -> void:
	var c := YardLayout.SHED_CENTER
	var hs := YardLayout.SHED_SIZE * 0.5
	prop("kaykit_hexagon/barrel.gltf", Vector3(c.x + hs.x + 0.35, 0, c.y - hs.y + 0.2), 0.0, {solid = P.CYLINDER, scale = 0.9})
	prop("kaykit_hexagon/ladder.gltf", Vector3(c.x - 0.6, 0, c.y + hs.y + 0.22), 90.0, {solid = P.NONE, scale = 0.62, tilt = Vector3(0, 0, -14)})
	prop("kaykit_city/box_A.gltf", Vector3(c.x + 0.6, 0, c.y + hs.y + 0.4), 20.0, {scale = 0.6})
	prop("kaykit_city/box_B.gltf", Vector3(c.x + 0.55, 0.42, c.y + hs.y + 0.45), -10.0, {scale = 0.5, solid = P.NONE})
	YardProps.tool(root, Vector3(c.x + hs.x + 0.06, 0, c.y - hs.y + 0.75), Vector3(-1, 0, 0), false)
	YardProps.tool(root, Vector3(c.x + hs.x + 0.06, 0, c.y - hs.y + 1.0), Vector3(-1, 0, 0), true)
	# Lantern post lighting the shed path and the junk corner.
	_lantern_post(Vector3(-8.2, 0, -2.9), -90.0)
	StylizedTree.bush(root, Vector3(c.x - 0.5, 0, c.y - hs.y - 0.9), 0.7, 51)
	StylizedTree.bush(root, Vector3(-12.0, 0, -8.4), 0.6, 52)


## KayKit lantern post (arm towards local -z) with a warm unshadowed lamp.
func _lantern_post(post: Vector3, yaw: float) -> void:
	prop("kaykit_halloween/post_lantern.gltf", post, yaw, {solid = P.NONE, tint = Color("#b8aca0")})
	WorldBuilder.add_cylinder_collider(root, 0.14, 2.6, post)
	layout.cover(Vector2(post.x, post.z), 0.2)
	if EnvMesh.visual() and not EnvQuality.is_low():
		var lamp := OmniLight3D.new()
		lamp.light_color = Color("#ffc27a")
		lamp.light_energy = 1.1
		lamp.omni_range = 5.5
		lamp.omni_attenuation = 1.3
		lamp.position = post + Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0.0, 1.9, 0.5)
		root.add_child(lamp)


## The front lawn: big tree with a tyre swing, a garden bench, flower beds,
## a lantern post by the tree.
func _front_lawn() -> void:
	# In the corner, so its long dusk shadow falls on the fence and lawn
	# rather than across the molds.
	var tree_pos := Vector3(-10.7, 0, 7.5)
	_check(Vector2(tree_pos.x, tree_pos.z), 0.4, "tree")
	layout.cover(Vector2(tree_pos.x, tree_pos.z), 0.45)
	StylizedTree.tree(root, tree_pos, 6.2, 61)
	YardProps.tyre_swing(root, tree_pos + Vector3(1.15, 2.95, -0.25), 2.0)
	_lantern_post(Vector3(-6.9, 0, 7.9), 180.0)
	for i in 5:
		var x := -6.8 + i * 2.1 + (i % 2) * 0.4
		StylizedTree.bush(root, Vector3(x, 0, 8.45 + (i % 2) * 0.1), 0.38 + (i % 3) * 0.08, 70 + i, false,
			[Color.WHITE, Color("#dfe8c8"), Color("#c8d8b0")][i % 3])
	prop("kaykit_hexagon/rock_single_A.gltf", Vector3(-7.6, 0, 8.1), 20.0, {scale = 0.25, solid = P.NONE})
	prop("kaykit_hexagon/rock_single_D.gltf", Vector3(-2.8, 0, 8.3), 75.0, {scale = 0.2, solid = P.NONE})
	prop("kaykit_hexagon/rock_single_B.gltf", Vector3(5.3, 0, 8.25), 140.0, {scale = 0.22, solid = P.NONE})
	# A couple of late pumpkins by the lantern (muted: saturated orange means
	# heat). The rest of the front lawn stays calm: it is the foreground of the
	# wide shot, and anything here sits cut off at the frame's edge.
	prop("kaykit_halloween/pumpkin_orange.gltf", Vector3(-8.15, 0, 8.25), 40.0, {solid = P.NONE, scale = 0.55, desaturate = 0.55, tint = Color("#c9b08f")})
	prop("kaykit_halloween/pumpkin_orange_small.gltf", Vector3(-7.75, 0, 7.75), -20.0, {solid = P.NONE, scale = 0.6, desaturate = 0.55, tint = Color("#c9b08f")})
	if EnvMesh.visual():
		var ball := EnvMesh.surface("ball", {base_color = Color("#d9606a"), roughness_base = 0.5, contact_dark = 0.0})
		EnvMesh.add(root, EnvMesh.sphere(0.13, 14, 8), ball, Transform3D(Basis(), Vector3(-4.6, 0.13, 7.1)))


## Inside the work area only things that belong to the craft, at its rim.
func _work_area() -> void:
	YardProps.anvil(root, Vector3(-1.2, 0, -4.6), 15.0)
	_check(Vector2(-1.2, -4.6), 0.36, "anvil")
	layout.cover(Vector2(-1.2, -4.6), 0.4)
	YardProps.bricks(root, Vector3(-6.0, 0, -4.9), 25.0, 81)
	_check(Vector2(-6.0, -4.9), 0.45, "bricks")
	layout.cover(Vector2(-6.0, -4.9), 0.5)
	for i in 3:
		prop("kaykit_hexagon/sack.gltf", Vector3(-6.7 + i * 0.35, 0, -3.95 - (i % 2) * 0.25), 60.0 + i * 40.0,
			{solid = P.NONE, scale = 0.9, tint = Color("#5a5456"), desaturate = 0.8})
	prop("kaykit_hexagon/bucket_empty.gltf", Vector3(-5.35, 0, -4.15), 0.0, {solid = P.CYLINDER, scale = 0.7, tint = Color("#8f8a86"), desaturate = 0.5})


## Beyond the fence: neighbour houses, trees, hedges and a utility pole.
func _background() -> void:
	YardHouse.build(root, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-17.6, 0, -2.0)), {
		width = 10.0, depth = 7.0, wall_height = 3.0, pitch_deg = 38.0, plaster = Color("#a9b4be"), roof = Color("#55505a"),
		roof_light = Color("#6e6872"), detail = false, chimney_x = 2.6, seed = 7,
		windows = [[-3.2, 1.6, 1.0, 1.1, 1.0], [0.0, 1.6, 1.0, 1.1, 0.0], [3.0, 1.6, 1.0, 1.1, 0.7]]})
	YardHouse.build(root, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(19.0, 0, -5.0)), {
		width = 11.0, depth = 7.5, wall_height = 5.2, pitch_deg = 42.0, plaster = Color("#b8c2a4"), roof = Color("#6a4c46"),
		roof_light = Color("#84605a"), detail = false, chimney_x = -3.0, seed = 8,
		windows = [[-3.4, 1.6, 1.0, 1.2, 0.0], [0.4, 1.6, 1.0, 1.2, 1.0], [3.4, 1.6, 1.0, 1.2, 0.0],
			[-3.4, 4.0, 0.9, 1.0, 0.8], [3.4, 4.0, 0.9, 1.0, 0.0]]})
	YardHouse.build(root, Transform3D(Basis(), Vector3(15.5, 0, -19.0)), {
		width = 9.0, depth = 7.0, wall_height = 5.0, pitch_deg = 40.0, plaster = Color("#d9b8a0"), roof = Color("#5a5560"),
		roof_light = Color("#726c78"), detail = false, chimney_x = 2.0, seed = 9,
		windows = [[-2.5, 1.6, 1.0, 1.2, 1.0], [2.5, 1.6, 1.0, 1.2, 0.0], [-2.5, 3.9, 0.9, 1.0, 0.0], [2.5, 3.9, 0.9, 1.0, 1.0]]})
	YardHouse.build(root, Transform3D(Basis(Vector3.UP, PI), Vector3(-4.0, 0, 21.0)), {
		width = 12.0, depth = 7.0, wall_height = 5.2, pitch_deg = 40.0, plaster = Color("#c9b8a6"), roof = Color("#5e4a4e"),
		detail = false, chimney_x = 3.0, seed = 10,
		windows = [[-4.0, 1.6, 1.0, 1.2, 1.0], [0.0, 1.6, 1.0, 1.2, 0.0], [4.0, 1.6, 1.0, 1.2, 0.8], [-2.0, 3.9, 0.9, 1.0, 0.6]]})
	# Trees: tall ones peeking over the roof, others between the gardens.
	StylizedTree.tree(root, Vector3(-13.5, 0, -14.0), 10.5, 101, false)
	StylizedTree.tree(root, Vector3(9.0, 0, -13.5), 9.0, 102, false, Color("#d8e0c0"))
	StylizedTree.tree(root, Vector3(-15.5, 0, 3.5), 7.5, 103, false)
	StylizedTree.conifer(root, Vector3(16.6, 0, 2.6), 8.5, 104)
	StylizedTree.tree(root, Vector3(3.0, 0, -22.0), 10.0, 105, false)
	StylizedTree.conifer(root, Vector3(-15.2, 0, -7.8), 8.5, 111)
	StylizedTree.conifer(root, Vector3(15.0, 0, -11.0), 9.0, 112)
	StylizedTree.conifer(root, Vector3(15.6, 0, 9.5), 7.5, 113)
	StylizedTree.conifer(root, Vector3(-16.0, 0, 11.0), 8.0, 114)
	StylizedTree.conifer(root, Vector3(-9.0, 0, -20.0), 11.0, 115)
	StylizedTree.hedge(root, Vector3(-13.3, 0, -8.8), Vector3(-13.3, 0, 8.8), 1.7, 121)
	StylizedTree.hedge(root, Vector3(13.3, 0, -8.8), Vector3(13.3, 0, 0.6), 1.6, 122)
	StylizedTree.hedge(root, Vector3(13.3, 0, 3.4), Vector3(13.3, 0, 8.8), 1.6, 123)
	StylizedTree.hedge(root, Vector3(-12.5, 0, 11.0), Vector3(12.5, 0, 11.0), 1.3, 124)
	StylizedTree.hedge(root, Vector3(6.2, 0, -9.8), Vector3(12.8, 0, -9.8), 1.9, 125)
	_utility_pole()
	_neighbour_gardens()
	_far_ring()
	_woodland()


## A loose ring of tall trees 30-40 m out, so every horizon has silhouettes.
func _far_ring() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 131
	var a := 0.0
	var i := 0
	while a < TAU:
		var r := rng.randf_range(29.0, 38.0)
		var p := Vector3(sin(a) * r, 0, -2.0 + cos(a) * r)
		var h := rng.randf_range(8.0, 13.0)
		if i % 3 == 1:
			StylizedTree.tree(root, p, h, 140 + i, false, Color("#c8d0b8"))
		else:
			StylizedTree.conifer(root, p, h, 160 + i)
		a += rng.randf_range(0.22, 0.42)
		i += 1


## Shrubs in the neighbours' gardens, so the lawns between the fence and the
## far trees are not empty fields (and the tree trunks there have a base).
func _neighbour_gardens() -> void:
	var spots := [
		[Vector3(8.4, 0, -12.6), 1.1], [Vector3(10.2, 0, -14.4), 0.9], [Vector3(5.8, 0, -15.5), 1.3],
		[Vector3(-11.8, 0, -12.0), 1.2], [Vector3(-14.6, 0, -15.6), 1.0], [Vector3(-12.6, 0, -18.5), 1.4],
		[Vector3(18.0, 0, -12.5), 1.2], [Vector3(21.0, 0, 3.0), 1.3], [Vector3(-20.5, 0, -9.0), 1.2],
		[Vector3(-19.5, 0, 6.5), 1.1], [Vector3(10.0, 0, 15.0), 1.3], [Vector3(-12.0, 0, 15.5), 1.2],
	]
	for i in spots.size():
		StylizedTree.bush(root, spots[i][0], spots[i][1], 180 + i, false, [Color.WHITE, Color("#d8dcc4")][i % 2])
	StylizedTree.tree(root, Vector3(-5.5, 0, -25.5), 9.5, 191, false, Color("#d0d8bc"))
	StylizedTree.conifer(root, Vector3(22.5, 0, -16.0), 10.0, 192)
	StylizedTree.tree(root, Vector3(-23.0, 0, -11.5), 8.5, 193, false)


## A closed band of woodland 40 m out (one merged mesh): tall lumpy crowns
## hide the end of the ground from every camera height used in the game and
## menu, so the yard never ends at an edge, and the band fades into the dusk
## haze (aerial perspective).
func _woodland() -> void:
	if not EnvMesh.visual():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 151
	var parts := []
	var centre := Vector3(0, 0, -2.0)
	var a := 0.0
	while a < TAU:
		for row in 2:
			var r := 40.0 + row * 3.5 + rng.randf_range(-1.5, 1.5)
			var size := rng.randf_range(3.2, 4.6) * (1.25 if row == 1 else 1.0)
			var lift := rng.randf_range(0.6, 1.0) * size + row * 1.5
			var p := centre + Vector3(sin(a + row * 0.035), 0, cos(a + row * 0.035)) * r
			parts.append(EnvMesh.piece(EnvMesh.sphere(1.0, 10, 6), Transform3D(Basis().scaled(Vector3(1.0, rng.randf_range(0.9, 1.25), 1.0) * size),
				p + Vector3(0, lift, 0)), rng.randf()))
		a += rng.randf_range(0.06, 0.09)
	var mat := EnvMesh.foliage("woodland", {top_color = Color("#4d6f4f"), bottom_color = Color("#1d3532"), lumps = 0.3, clump_scale = 1.1,
		sway = 0.0, sway_base = 0.0})
	EnvMesh.add(root, EnvMesh.merge(parts), mat, Transform3D(), false)


## Wooden utility pole behind the back-right corner with sagging wires.
func _utility_pole() -> void:
	if not EnvMesh.visual():
		return
	var base := Vector3(13.4, 0, -10.6)
	var wood := EnvMesh.wood("utility", {base_color = Color("#5a4636"), weathering = 0.5})
	var parts := [
		EnvMesh.piece(EnvMesh.cylinder(0.11, 0.14, 8.0, 8), Transform3D(Basis(), base + Vector3(0, 4.0, 0))),
		EnvMesh.piece(EnvMesh.box(Vector3(1.6, 0.1, 0.1), 0.015, 1), Transform3D(Basis(), base + Vector3(0, 7.5, 0)), 0.3, Vector3.RIGHT),
	]
	EnvMesh.add(root, EnvMesh.merge(parts), wood)
	var cable := EnvMesh.material("cable", "res://shaders/env_lights.gdshader")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x: float in [-0.7, 0.7]:
		for f: Vector3 in [Vector3(13.6, 7.4, 24.0), Vector3(13.2, 7.6, -40.0)]:
			StringLights._cable(st, base + Vector3(x, 7.55, 0), f + Vector3(x, 0, 0), 1.0, 0.3, Vector2(1, 0))
	StringLights._cable(st, base + Vector3(-0.5, 7.5, 0), Vector3(5.7, 6.3, -12.0), 0.4, 0.6, Vector2(0, 1))
	EnvMesh.add(root, st.commit(), cable, Transform3D(), false)
