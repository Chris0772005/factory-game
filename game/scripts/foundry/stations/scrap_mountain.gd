class_name ScrapMountain
extends ScrapPile
## The big heap of the scrap hall: a mountain of junk the game starts at.
## It is dug like the small heap (hold F, tools make it faster), from any
## side, but it does not grow back: every grab makes it visibly smaller.
## Most grabs bring junk for the scrap dealer, the rest metal for the
## furnace. When it is gone a new load is tipped in, with more metal in it.
## The node's origin is the heap's working face (where machines stand); the
## mound lies behind it along -X and shrinks towards the face.

const RADIUS := 5.2
const HEIGHT := 3.9
const GRABS := 240
const BONUS := 150
const RELOAD_TIME := 6.0

## Loads cleared so far (each new load holds less junk).
var loads := 0
var _core: CollisionShape3D
var _mound: Node3D
var _size := 1.0
var _reload := -1.0


func _init() -> void:
	stock_max = GRABS
	stock = GRABS
	restock_every = INF
	junk_share = 0.6


func _build_heap() -> void:
	var body := StaticBody3D.new()
	_core = CollisionShape3D.new()
	_core.shape = CylinderShape3D.new()
	body.add_child(_core)
	add_child(body)
	_mound = Node3D.new()
	add_child(_mound)
	_art = _mound
	if StationKit.visual():
		_build_art()
	_apply_size(1.0)


## Centre of the mound at size `s`, in local space.
func _centre_local(s: float) -> Vector3:
	return Vector3(-RADIUS * 0.92 * s, 0, 0)


func size_now() -> float:
	return lerpf(0.2, 1.0, pow(clampf(float(stock) / stock_max, 0.0, 1.0), 0.45))


func _apply_size(s: float) -> void:
	_size = s
	_mound.position = _centre_local(s)
	_mound.scale = Vector3.ONE * s
	var cyl := _core.shape as CylinderShape3D
	cyl.radius = RADIUS * 0.7 * s
	cyl.height = HEIGHT * 0.5 * s
	_core.position = _centre_local(s) + Vector3(0, cyl.height * 0.5, 0)


func _shrink(delta: float) -> void:
	var want := size_now()
	if absf(want - _size) > 0.0005:
		_apply_size(lerpf(_size, want, 1.0 - exp(-3.0 * delta)))


## The spot on the heap's edge nearest to `player`.
func interact_point_for(player: Node3D) -> Vector3:
	var centre := to_global(_centre_local(_size))
	var out := player.global_position - centre
	out.y = 0.0
	out = out.normalized() if out.length() > 0.05 else global_transform.basis.x
	return centre + out * (RADIUS * 0.86 * _size) + Vector3(0, 0.7, 0)


func interact_point() -> Vector3:
	return global_position + Vector3(0, 0.7, 0)


func _find_origin(p: Player) -> Vector3:
	return (interact_point_for(p) if p else interact_point()) + Vector3(0, 0.5, 0)


func _heap_centre() -> Vector3:
	return to_global(_centre_local(_size))


func hint(player: Node) -> String:
	if stock <= 0:
		return "Schrottberg abgetragen – die nächste Ladung kommt gleich!"
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	var tool := "mit der Schaufel" if world and world.has_upgrade(&"shovel") else ("mit Handschuhen" if world and world.has_upgrade(&"gloves") else "mit bloßen Händen")
	var left := roundi(100.0 * stock / stock_max)
	var text := "[F halten] Schrott abtragen (%s) · Berg noch %d %%" % [tool, left]
	if player is Node3D and ScrapBucket.near(get_tree(), (player as Node3D).global_position) == null:
		var full := false
		for b: ScrapBucket in get_tree().get_nodes_in_group(&"scrap_buckets"):
			full = full or (b.is_full() and b.global_position.distance_to((player as Node3D).global_position) < ScrapBucket.CATCH_RANGE)
		text += " · Eimer voll – ab zum Ankauf!" if full else " · Eimer danebenstellen!"
	return text


func _physics_process(delta: float) -> void:
	super(delta)
	if not Network.is_sim_authority():
		return
	if stock <= 0 and _reload < 0.0:
		_reload = RELOAD_TIME
		var world := get_tree().get_first_node_in_group(&"world") as GameWorld
		if world:
			world.add_money(BONUS)
			world.banner_all("BERG ABGETRAGEN!", UITheme.ACCENT, "+%d $ Prämie · neue Ladung Schrott rollt an" % BONUS)
	elif _reload >= 0.0:
		_reload -= delta
		if _reload < 0.0:
			loads += 1
			junk_share = maxf(0.3, 0.6 - 0.1 * loads)
			stock = stock_max
			_dirty = true


func _fx(kind: StringName) -> void:
	var top := _heap_centre() + Vector3(0, HEIGHT * 0.5 * _size, 0)
	var p := get_tree().get_first_node_in_group(&"world") as GameWorld
	var local := p.local_player() if p else null
	var at := interact_point_for(local) if local else interact_point()
	match kind:
		&"rummage":
			Sfx.play(&"dig_scrape", at, -8.0, 0.2)
			if randf() < 0.4:
				Sfx.play(&"plate_clang", at, -14.0, 0.25)
			FoundryFX.dust(get_parent(), at)
		&"find":
			Sfx.play(&"scrap_clatter", at, -2.0)
			Sfx.play(&"metal_tick", at, -6.0, 0.15)
		&"beep":
			Sfx.play(&"detector_beep", at, -5.0, 0.0)
		&"rare":
			Sfx.play(&"coin", at, 0.0)
			FoundryFX.sparks(get_parent(), top, 14)


# --- Look -------------------------------------------------------------------------

## Height of the mound at distance `r` from its centre (full size).
static func surface_y(r: float) -> float:
	var k := clampf(r / RADIUS, 0.0, 1.0)
	return HEIGHT * pow(1.0 - k * k, 0.85)


static func _lumps(pos: Vector3, angle: float) -> Vector3:
	var k := 1.0 + 0.09 * sin(angle * 3.0 + 1.0) + 0.05 * sin(angle * 7.0 + 2.0) + 0.03 * sin(angle * 13.0)
	var r := Vector2(pos.x, pos.z).length()
	var bump := 0.22 * sin(angle * 5.0 + r * 2.1) * sin(r / RADIUS * PI) + 0.1 * sin(angle * 11.0 + r * 4.3)
	return Vector3(pos.x * k, maxf(0.0, pos.y + bump * clampf(pos.y, 0.0, 1.0)), pos.z * k)


func _build_art() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	# The body of the heap: rusty, earthy rubble.
	var rubble := StationKit.surface("scrap_mountain", {base_color = Color("#3d3531"), stain_color = Color("#6a4630"), stains = 0.6,
		macro = 0.3, grain = 0.2, roughness_base = 0.95, noise_scale = 1.4, contact_dark = 0.1, bump = 0.8})
	var dome := PackedVector2Array()
	for i in 15:
		var r := RADIUS * (1.0 - i / 14.0)
		dome.append(Vector2(r, surface_y(r) - 0.05))
	StationKit.add(_mound, StationKit.lathe(dome, 48, 70.0, _lumps), rubble)
	# What sticks out of it: sheets, beams, drums, pipes, cans by the hundred.
	var rust := StationKit.metal("mountain_rust", {steel_color = Color("#6b6460"), rust = 0.75, dents = 0.8, metallic_steel = 0.6, roughness_steel = 0.55})
	var paint_a := StationKit.metal("mountain_teal", {steel_color = Color("#5c6468"), paint = 0.7, paint_color = Color("#3f6f78"), rust = 0.5, dents = 0.7})
	var paint_b := StationKit.metal("mountain_red", {steel_color = Color("#5c6468"), paint = 0.65, paint_color = Color("#9a3f2c"), rust = 0.5, dents = 0.7})
	var paint_c := StationKit.metal("mountain_ochre", {steel_color = Color("#5c6468"), paint = 0.6, paint_color = Color("#b38a34"), rust = 0.55, dents = 0.7})
	var sheet := EnvMesh.box(Vector3(1.1, 0.03, 0.7), 0.01)
	var beam := EnvMesh.box(Vector3(1.9, 0.12, 0.12), 0.02)
	var drum := EnvMesh.cylinder(0.29, 0.29, 0.88, 14)
	var pipe := EnvMesh.cylinder(0.05, 0.05, 1.5, 8)
	var plate := EnvMesh.box(Vector3(0.5, 0.06, 0.5), 0.02)
	_scatter(rng, sheet, rust, 120, 0.5, 1.6, true)
	_scatter(rng, sheet, paint_a, 40, 0.5, 1.3, true)
	_scatter(rng, sheet, paint_b, 34, 0.5, 1.3, true)
	_scatter(rng, beam, rust, 70, 0.6, 1.5, false)
	_scatter(rng, drum, paint_c, 9, 0.9, 1.1, false)
	_scatter(rng, drum, paint_a, 7, 0.9, 1.1, false)
	_scatter(rng, pipe, ScrapModels.material(Color("#b36a3a")), 60, 0.6, 1.4, false)
	_scatter(rng, plate, rust, 220, 0.5, 1.8, true)
	_scatter(rng, plate, paint_c, 50, 0.5, 1.4, true)
	_scatter(rng, ScrapModels.mesh(&"scrap_can"), ScrapModels.material(Color("#aeb6bd")), 420, 0.9, 1.3, false)
	_scatter(rng, ScrapModels.mesh(&"scrap_kettle"), ScrapModels.material(Color("#b8652f")), 26, 1.2, 2.0, false)
	_scatter(rng, ScrapModels.mesh(&"scrap_trophy"), ScrapModels.material(Color("#e2bd4f")), 12, 1.3, 2.0, false)
	_scatter(rng, ScrapModels.mesh(&"scrap_bikebell"), ScrapModels.material(Color("#dfe3e8")), 30, 1.5, 2.5, false)


## `count` copies of `mesh` lying on and half in the mound. `flat`: mostly
## lying on the slope; otherwise tumbled any way.
func _scatter(rng: RandomNumberGenerator, mesh: Mesh, mat: Material, count: int, scale_min: float, scale_max: float, flat: bool) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	for i in count:
		var a := rng.randf() * TAU
		# Area-uniform over the disc, a little denser towards the foot.
		var r := RADIUS * sqrt(rng.randf()) * 0.98
		var y := surface_y(r)
		var pos := Vector3(cos(a) * r, y + rng.randf_range(-0.08, 0.1), sin(a) * r)
		# Slope normal: the mound falls away from the centre.
		var slope := surface_y(maxf(r - 0.1, 0.0)) - surface_y(minf(r + 0.1, RADIUS))
		var normal := (Vector3.UP + Vector3(cos(a), 0, sin(a)) * slope * 2.5).normalized()
		var basis := Basis(Vector3.UP, rng.randf() * TAU)
		if flat:
			basis = Basis(Quaternion(Vector3.UP, normal)) * basis * Basis(Vector3.RIGHT, rng.randf_range(-0.35, 0.35))
		else:
			basis = Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU))
		mm.set_instance_transform(i, Transform3D(basis.scaled(Vector3.ONE * rng.randf_range(scale_min, scale_max)), pos))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	_mound.add_child(mmi)
