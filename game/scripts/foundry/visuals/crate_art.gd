class_name CrateArt
extends Node3D
## Look of the sell crate: a slatted produce crate (corner posts, gappy slats,
## floor boards, iron corner caps, stencilled "VERKAUF"), bedded with wood
## wool, and a chalkboard on two stakes behind it that reads like a market
## stall sign (Art Bible 12: signs are painted/chalked boards, not floating
## UI). `pop()` gives the elastic 1.15 -> 1.0 bounce on a sale (Art Bible
## 9.3). Visual only: SellCrate keeps its wall and floor colliders.

var _root: Node3D
var _pop := 0.0
var _pop_vel := 0.0


func build(size: Vector3) -> void:
	_root = Node3D.new()
	add_child(_root)
	if not StationKit.visual():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var wood := StationKit.wood("crate", {base_color = Color("#a57a4f"), grain_color = Color("#6e4d31"), weathering = 0.45, variation = 0.16})
	var dark := StationKit.wood("crate_posts", {base_color = Color("#7d5a3d"), grain_color = Color("#4f3725"), weathering = 0.35})
	var slats := []
	var posts := []
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			posts.append(EnvMesh.piece(EnvMesh.box(Vector3(0.075, size.y, 0.075), 0.01, 1), Transform3D(Basis(), Vector3(sx * (hx - 0.04), size.y * 0.5, sz * (hz - 0.04))), rng.randf()))
	var rows := [0.11, 0.34, 0.585]
	for y: float in rows:
		for s: float in [-1.0, 1.0]:
			var b := Basis(Vector3.BACK, StationKit.jitter(rng, 0.8))
			slats.append(EnvMesh.piece(EnvMesh.box(Vector3(size.x + 0.02, 0.17, 0.028), 0.008, 1), Transform3D(b, Vector3(0, y, s * (hz + 0.006))), rng.randf(), Vector3.RIGHT))
			var e := Basis(Vector3.RIGHT, StationKit.jitter(rng, 0.8))
			slats.append(EnvMesh.piece(EnvMesh.box(Vector3(0.028, 0.17, size.z - 0.03), 0.008, 1), Transform3D(e, Vector3(s * (hx + 0.006), y, 0)), rng.randf(), Vector3.BACK))
	for i in 4:
		slats.append(EnvMesh.piece(EnvMesh.box(Vector3(size.x - 0.06, 0.03, size.z / 4.0 - 0.012), 0.006, 1), Transform3D(Basis(), Vector3(0, 0.05, -hz + size.z / 8.0 * (2 * i + 1))), rng.randf(), Vector3.RIGHT))
	# Skids.
	for x: float in [-hx + 0.12, hx - 0.12]:
		posts.append(EnvMesh.piece(EnvMesh.box(Vector3(0.08, 0.035, size.z + 0.04), 0.008, 1), Transform3D(Basis(), Vector3(x, 0.0175, 0)), rng.randf(), Vector3.BACK))
	StationKit.add_merged(_root, slats, wood)
	StationKit.add_merged(_root, posts, dark)
	var iron := StationKit.metal("crate_caps", {steel_color = Color("#3d3b39"), rust = 0.55, dents = 0.2, metallic_steel = 0.5})
	var caps := []
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var c := Vector3(sx * (hx + 0.012), size.y - 0.04, sz * (hz + 0.012))
			caps.append(EnvMesh.piece(EnvMesh.box(Vector3(0.1, 0.08, 0.006), 0.002, 1), Transform3D(Basis(), c + Vector3(-sx * 0.04, 0, 0))))
			caps.append(EnvMesh.piece(EnvMesh.box(Vector3(0.006, 0.08, 0.1), 0.002, 1), Transform3D(Basis(), c + Vector3(0, 0, -sz * 0.04))))
	StationKit.add_merged(_root, caps, iron)
	# Wood wool bedding.
	var straw := StationKit.surface("woodwool", {base_color = Color("#cfb07a"), macro = 0.2, grain = 0.3, roughness_base = 0.97,
		noise_scale = 6.0, contact_dark = 0.0})
	var fluff := []
	for i in 9:
		var p := Vector3(rng.randf_range(-hx + 0.2, hx - 0.2), 0.12, rng.randf_range(-hz + 0.18, hz - 0.18))
		fluff.append(EnvMesh.piece(StationKit.chunk(rng.randf_range(0.17, 0.24), 30 + i, 0.4, 0.3), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p)))
	StationKit.add_merged(_root, fluff, straw)
	var ink := Color(0.13, 0.12, 0.13, 0.78)
	StationKit.label(_root, "VERKAUF", Transform3D(Basis(), Vector3(0, 0.34, hz + 0.022)), 84, ink, 700, 0.0019)
	StationKit.label(_root, "MOLTEN MATES  ·  GIESSEREI", Transform3D(Basis(), Vector3(0, 0.585, hz + 0.022)), 40, ink, 600, 0.0019)
	_chalkboard(size)


## Market-stall chalkboard on two stakes behind the crate.
func _chalkboard(size: Vector3) -> void:
	var z := -size.z * 0.5 - 0.09
	var frame_wood := StationKit.wood("chalk_frame", {base_color = Color("#8a6446"), grain_color = Color("#5a3f2c"), weathering = 0.35})
	var w := 0.78
	var h := 0.5
	var cy := 1.12
	var b := Basis(Vector3.RIGHT, -0.08)
	var parts := []
	for x: float in [-w * 0.5 + 0.03, w * 0.5 - 0.03]:
		parts.append(EnvMesh.piece(EnvMesh.box(Vector3(0.05, cy + h * 0.5 + 0.06, 0.05), 0.008, 1), Transform3D(Basis(), Vector3(x, (cy + h * 0.5 + 0.06) * 0.5, z - 0.03)), 0.2))
	parts.append(EnvMesh.piece(EnvMesh.box(Vector3(w, 0.05, 0.035), 0.008, 1), Transform3D(b, Vector3(0, cy + h * 0.5, z)), 0.4, Vector3.RIGHT))
	parts.append(EnvMesh.piece(EnvMesh.box(Vector3(w, 0.05, 0.035), 0.008, 1), Transform3D(b, Vector3(0, cy - h * 0.5, z) + b * Vector3(0, 0, 0)), 0.6, Vector3.RIGHT))
	for x: float in [-w * 0.5, w * 0.5]:
		parts.append(EnvMesh.piece(EnvMesh.box(Vector3(0.05, h + 0.05, 0.035), 0.008, 1), Transform3D(b, Vector3(x, cy, z)), 0.8))
	# Chalk ledge.
	parts.append(EnvMesh.piece(EnvMesh.box(Vector3(w * 0.6, 0.015, 0.05), 0.004, 1), Transform3D(b, Vector3(0, cy - h * 0.5 - 0.02, z + 0.035)), 0.5, Vector3.RIGHT))
	StationKit.add_merged(_root, parts, frame_wood)
	var slate := StationKit.unique("station_chalk")
	var face := Transform3D(b, Vector3(0, cy, z + 0.006))
	StationKit.add(_root, StationKit.sheet(w - 0.03, h - 0.03, 1), slate, face)
	var chalk := Color(0.93, 0.92, 0.87, 0.92)
	var lift := Vector3(0, 0, 0.004)
	var hand := StationKit.hand_font()
	var gold := Color(0.96, 0.85, 0.55, 0.92)
	StationKit.label(_root, "VERKAUF", face * Transform3D(Basis(), Vector3(-0.07, 0.13, 0) + lift), 110, chalk, 700, 0.0011, StationKit.chalk_font())
	StationKit.label(_root, "Gussteile aller Art", face * Transform3D(Basis(), Vector3(-0.07, 0.03, 0) + lift), 64, chalk, 500, 0.0011, hand)
	StationKit.label(_root, "Bar auf die Hand!", face * Transform3D(Basis(Vector3.BACK, 0.05), Vector3(-0.08, -0.06, 0) + lift), 64, gold, 600, 0.0011, hand)
	StationKit.label(_root, "$", face * Transform3D(Basis(), Vector3(0.27, 0.07, 0) + lift), 120, gold, 700, 0.0011, StationKit.chalk_font())
	# Chalk doodles: a circle round the coin and an arrow down into the crate.
	var circle := PackedVector3Array()
	for i in 25:
		var a := TAU * i / 23.0
		circle.append(Vector3(0.27 + cos(a) * 0.075, 0.075 + sin(a) * 0.075, 0))
	var arrow := [PackedVector3Array([Vector3(0.25, -0.05, 0), Vector3(0.28, -0.11, 0), Vector3(0.27, -0.19, 0)]),
		PackedVector3Array([Vector3(0.22, -0.15, 0), Vector3(0.27, -0.2, 0), Vector3(0.32, -0.14, 0)]),
		PackedVector3Array([Vector3(-0.3, -0.12, 0), Vector3(-0.05, -0.115, 0), Vector3(0.12, -0.125, 0)])]
	var strokes := [circle]
	strokes.append_array(arrow)
	var lines := []
	for stroke: PackedVector3Array in strokes:
		var pts := PackedVector3Array()
		for p in stroke:
			pts.append(Vector3(p.x, 0.0, -p.y))
		lines.append(EnvMesh.piece(StationKit.ribbon(pts, 0.008), face * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), lift)))
	var chalk_mat := StationKit.surface("chalk_line", {base_color = Color("#e6e3da"), roughness_base = 0.95, macro = 0.2, grain = 0.4,
		noise_scale = 8.0, contact_dark = 0.0})
	StationKit.add_merged(_root, lines, chalk_mat, false)


## Elastic bounce on a sale.
func pop() -> void:
	_pop_vel += 3.2


func _process(delta: float) -> void:
	if _root == null or (absf(_pop) < 0.0005 and absf(_pop_vel) < 0.001):
		return
	_pop_vel += (-_pop * 300.0 - _pop_vel * 9.0) * delta
	_pop += _pop_vel * delta
	_root.scale = Vector3(1.0 + _pop, 1.0 + _pop * 1.4, 1.0 + _pop)
