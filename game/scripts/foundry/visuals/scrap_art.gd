class_name ScrapArt
extends Node3D
## Look of the scrap heap: a rusty mound of junk that shows what it yields
## (tin cans, copper pipes, brass keys) plus the stuff of every backyard
## (pans, pots, a bent bicycle wheel, sheet metal, a coil of wire) and a few
## retired adventurer weapons from the KayKit pack as an easter egg. A
## painted board on a stake says what it is. Seeded, so every peer sees the
## same heap. Visual only (ScrapPile adds the low collider).

const RADIUS := 0.78
const HEIGHT := 0.3


func build() -> void:
	if not StationKit.visual():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 1312
	var dirt := StationKit.surface("scrap_mound", {base_color = Color("#6e5745"), stain_color = Color("#83502f"), stains = 0.75,
		macro = 0.2, grain = 0.14, roughness_base = 0.95, noise_scale = 3.0, contact_dark = 0.05, bump = 0.6})
	var dome := PackedVector2Array()
	for i in 9:
		var r := RADIUS * (1.0 - i / 8.0)
		dome.append(Vector2(r, surface_y(r) - 0.02))
	StationKit.add(self, StationKit.lathe(dome, 28, 70.0, _lumps), dirt)
	_cans(rng)
	_pipes(rng)
	_keys(rng)
	_wheel()
	_sheets(rng)
	_kits(rng)
	_sign()


## Irregular outline and bumps for the mound.
static func _lumps(pos: Vector3, angle: float) -> Vector3:
	var k := 1.0 + 0.1 * sin(angle * 3.0 + 1.0) + 0.06 * sin(angle * 7.0 + 2.0)
	var r := Vector2(pos.x, pos.z).length()
	var bump := 0.03 * sin(angle * 5.0 + r * 9.0) * sin(r / RADIUS * PI)
	return Vector3(pos.x * k, pos.y + bump, pos.z * k)


## Height of the mound surface at distance `r` from the centre.
static func surface_y(r: float) -> float:
	var k := clampf(r / RADIUS, 0.0, 1.0)
	return HEIGHT * (1.0 - k * k) * 0.92


static func _spot(rng: RandomNumberGenerator, r_min: float, r_max: float, lift := 0.0) -> Vector3:
	var a := rng.randf() * TAU
	var r := rng.randf_range(r_min, r_max)
	return Vector3(cos(a) * r, surface_y(r) + lift, sin(a) * r)


## Tin cans with rolled rims and faded labels.
func _cans(rng: RandomNumberGenerator) -> void:
	var tin := StationKit.metal("scrap_tin", {steel_color = Color("#9a9ea3"), rust = 0.45, dents = 0.6, metallic_steel = 0.8,
		roughness_steel = 0.38})
	var labels := [Color("#9c4a3c"), Color("#466a8a"), Color("#c49a4a"), Color("#4f7a56")]
	var can := StationKit.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.036, 0.0), Vector2(0.04, 0.006), Vector2(0.038, 0.012),
		Vector2(0.038, 0.108), Vector2(0.04, 0.114), Vector2(0.036, 0.12), Vector2(0.0, 0.118)]), 14, 50.0)
	var label := StationKit.lathe(PackedVector2Array([Vector2(0.0386, 0.02), Vector2(0.0386, 0.1)]), 14, 50.0)
	var tins := []
	var wraps: Array = []
	for c in labels:
		wraps.append([])
	for i in 14:
		var p := _spot(rng, 0.1, 0.75, 0.02)
		var b := Basis.from_euler(Vector3(rng.randf_range(0.6, 1.9), rng.randf() * TAU, rng.randf_range(-0.4, 0.4)))
		var xf := Transform3D(b.scaled(Vector3.ONE * rng.randf_range(0.9, 1.25)), p)
		tins.append(EnvMesh.piece(can, xf, rng.randf()))
		wraps[i % labels.size()].append(EnvMesh.piece(label, xf, rng.randf()))
	StationKit.add_merged(self, tins, tin)
	for k in labels.size():
		var paper := StationKit.surface("can_label_%d" % k, {base_color = labels[k], stains = 0.5,
			stain_color = Color("#6b4a32"), roughness_base = 0.8, macro = 0.1, contact_dark = 0.0})
		StationKit.add_merged(self, wraps[k], paper)


## Copper pipes, straight and with elbows, some with a green patina.
func _pipes(rng: RandomNumberGenerator) -> void:
	var copper := StationKit.metal("scrap_copper", {steel_color = Color("#b4683f"), rust_color = Color("#5fa68a"), rust = 0.35,
		dents = 0.2, metallic_steel = 0.85, roughness_steel = 0.35})
	var parts := []
	for i in 8:
		var p := _spot(rng, 0.1, 0.7, 0.025)
		var yaw := rng.randf() * TAU
		var length := rng.randf_range(0.3, 0.6)
		var dir := Vector3(cos(yaw), rng.randf_range(-0.15, 0.25), sin(yaw)).normalized()
		var path := PackedVector3Array([p - dir * length * 0.5, p + dir * length * 0.5])
		if i % 3 == 0:
			var up := Vector3.UP.cross(dir).normalized()
			path.append_array(StationKit.arc_points(p + dir * length * 0.5 + up * 0.06, -up, dir, 0.06, 0.2, PI * 0.5, 4))
			path.append(p + dir * length * 0.5 + up * 0.25)
		parts.append(EnvMesh.piece(StationKit.tube(path, 0.022, 8), Transform3D(), rng.randf()))
	StationKit.add_merged(self, parts, copper)


## Big old brass keys: ring, shaft and bit.
func _keys(rng: RandomNumberGenerator) -> void:
	var brass := StationKit.metal("scrap_brass", {steel_color = Color("#c9a14c"), rust_color = Color("#6d5a2e"), rust = 0.3,
		dents = 0.15, metallic_steel = 0.9, roughness_steel = 0.3})
	var ring := TorusMesh.new()
	ring.inner_radius = 0.018
	ring.outer_radius = 0.03
	ring.rings = 12
	ring.ring_segments = 6
	var parts := []
	for i in 5:
		var p := _spot(rng, 0.05, 0.6, 0.012)
		var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3))
		var xf := Transform3D(b, p)
		parts.append(EnvMesh.piece(ring, xf * Transform3D(Basis(), Vector3(-0.06, 0, 0))))
		parts.append(EnvMesh.piece(EnvMesh.cylinder(0.007, 0.007, 0.1, 6), xf * Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.015, 0, 0))))
		parts.append(EnvMesh.piece(EnvMesh.box(Vector3(0.012, 0.006, 0.028), 0.002, 1), xf * Transform3D(Basis(), Vector3(0.05, 0, 0.016))))
		parts.append(EnvMesh.piece(EnvMesh.box(Vector3(0.01, 0.006, 0.02), 0.002, 1), xf * Transform3D(Basis(), Vector3(0.032, 0, 0.012))))
	StationKit.add_merged(self, parts, brass)


## A buckled bicycle wheel leaning against the back of the heap.
func _wheel() -> void:
	var xf := Transform3D(Basis(Vector3.UP, 0.5) * Basis(Vector3.RIGHT, -0.38) * Basis(Vector3.BACK, 0.12), Vector3(-0.15, 0.3, -0.55))
	var rim := TorusMesh.new()
	rim.inner_radius = 0.27
	rim.outer_radius = 0.295
	rim.rings = 28
	rim.ring_segments = 6
	var tyre := TorusMesh.new()
	tyre.inner_radius = 0.285
	tyre.outer_radius = 0.33
	tyre.rings = 28
	tyre.ring_segments = 8
	var steel := StationKit.metal("scrap_steel", {steel_color = Color("#8f9296"), rust = 0.6, dents = 0.2, metallic_steel = 0.8,
		roughness_steel = 0.4})
	var parts := [EnvMesh.piece(rim, xf * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO))]
	parts.append(EnvMesh.piece(EnvMesh.cylinder(0.025, 0.025, 0.07, 10), xf * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO)))
	for i in 16:
		var a := TAU * i / 16.0
		var side := 0.02 if i % 2 == 0 else -0.02
		var spoke := PackedVector3Array([Vector3(0, 0, side), Vector3(cos(a), sin(a), 0) * 0.275])
		parts.append(EnvMesh.piece(StationKit.tube(spoke, 0.0025, 4, false), xf))
	StationKit.add_merged(self, parts, steel)
	var rubber := StationKit.surface("scrap_tyre", {base_color = Color("#2a2728"), roughness_base = 0.85, macro = 0.08, grain = 0.1,
		stains = 0.3, stain_color = Color("#5a4a3c")})
	StationKit.add(self, tyre, rubber, xf * Transform3D(Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3(1, 1.6, 1)), Vector3.ZERO))


## Bent sheet-metal offcuts and a coil of wire.
func _sheets(rng: RandomNumberGenerator) -> void:
	var tin := StationKit.metal("scrap_sheet", {steel_color = Color("#878b8f"), paint_color = Color("#6f8a6a"), paint = 0.3,
		rust = 0.6, dents = 0.5, metallic_steel = 0.6, noise_scale = 3.0})
	var parts := []
	for i in 6:
		var p := _spot(rng, 0.2, 0.75, 0.03)
		var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.6, -0.2))
		parts.append(EnvMesh.piece(EnvMesh.box(Vector3(rng.randf_range(0.25, 0.4), 0.008, rng.randf_range(0.18, 0.3)), 0.003, 1), Transform3D(b, p), rng.randf()))
		var fold := b * Basis(Vector3.RIGHT, 0.9)
		parts.append(EnvMesh.piece(EnvMesh.box(Vector3(0.2, 0.008, 0.1), 0.003, 1), Transform3D(fold, p + b * Vector3(0, 0.03, 0.14)), rng.randf()))
	StationKit.add_merged(self, parts, tin)
	var copper := StationKit.metal("scrap_copper")
	var coil := PackedVector3Array()
	var c := Vector3(0.42, surface_y(0.45) + 0.04, 0.2)
	for i in 97:
		var t := i / 96.0
		var a := t * TAU * 6.0
		coil.append(c + Vector3(cos(a) * 0.1, t * 0.05 + sin(a * 0.5) * 0.008, sin(a) * 0.1))
	StationKit.add(self, StationKit.tube(coil, 0.005, 5, false), copper)


## Pans, pots and lids from the restaurant kit, rusty cans from the
## prototype kit and retired adventurer weapons.
func _kits(rng: RandomNumberGenerator) -> void:
	var rusty := Color(0.95, 0.84, 0.74)
	var items := [
		["kaykit_restaurant/pan_A.gltf", 0.45, 0.4, Vector3(0.6, 0.0, 0.3)],
		["kaykit_restaurant/pot_A.gltf", 0.4, 0.3, Vector3(-0.2, 0.0, 0.4)],
		["kaykit_restaurant/lid_large.gltf", 0.4, 0.25, Vector3(0.9, 0.0, -0.2)],
		["kaykit_adventurers/sword_1handed.gltf", 0.55, 0.15, Vector3(1.4, 0.0, 0.3)],
		["kaykit_adventurers/shield_round.gltf", 0.55, 0.45, Vector3(-0.4, 0.0, 0.6)],
		["kaykit_adventurers/axe_1handed.gltf", 0.5, 0.35, Vector3(1.2, 0.0, -0.6)],
		["kaykit_prototype/Can_A.gltf", 0.33, 0.55, Vector3(1.6, 0.0, 0.2)],
		["kaykit_prototype/Can_B.gltf", 0.33, 0.62, Vector3(-1.3, 0.0, 0.1)],
	]
	for it in items:
		var r: float = it[2]
		var a := rng.randf() * TAU
		var p := Vector3(cos(a) * r, surface_y(r) - 0.01, sin(a) * r)
		var tilt: Vector3 = it[3] * 45.0
		PropKit.place(self, it[0], p, rad_to_deg(a) + rng.randf_range(-40.0, 40.0), {solid = PropKit.Solid.NONE, scale = it[1],
			tilt = tilt, tint = rusty, desaturate = 0.55, metallic = 0.35, rough = 0.6, dirt = 0.5})


## "SCHROTT" painted on a weathered board nailed to a stake in the heap.
func _sign() -> void:
	var wood := StationKit.wood("scrap_sign", {base_color = Color("#8c6a4e"), grain_color = Color("#5a4232"), weathering = 0.6,
		paint_color = Color("#3f7f86"), paint = 0.0})
	var b := Basis(Vector3.UP, 0.35) * Basis(Vector3.BACK, 0.06) * Basis(Vector3.RIGHT, -0.08)
	var at := Vector3(0.18, 0.0, -0.32)
	var parts := [
		EnvMesh.piece(EnvMesh.box(Vector3(0.05, 0.95, 0.05), 0.008, 1), Transform3D(b, at + b * Vector3(0, 0.47, 0)), 0.3),
		EnvMesh.piece(EnvMesh.box(Vector3(0.56, 0.17, 0.025), 0.008, 1), Transform3D(b, at + b * Vector3(0, 0.82, 0.04)), 0.7, Vector3.RIGHT),
	]
	StationKit.add_merged(self, parts, wood)
	StationKit.label(self, "SCHROTT", Transform3D(b, at + b * Vector3(0, 0.82, 0.054)), 72, Color("#e9e0cc"), 700, 0.0015)
