class_name PropArt
## Smooth stand-ins for the round kit props that look faceted up close in
## first person: steel drums, wooden barrels, paint tins, buckets. PropKit
## swaps them in by model name; size comes from the kit model's bounds, so
## colliders and placement stay as they were.

const DRUMS := {"kaykit_prototype/Barrel_A.gltf": Color("#3f6474"), "kaykit_prototype/Barrel_B.gltf": Color("#9a3f32"), "kaykit_prototype/Barrel_C.gltf": Color("#6b6f47")}
const CASKS := ["kaykit_dungeon/barrel_large.gltf", "kaykit_dungeon/barrel_small.gltf"]
const TINS := {"kaykit_prototype/Can_A.gltf": Color("#a33b2e"), "kaykit_prototype/Can_B.gltf": Color("#3f6f78")}
const BUCKETS := ["kaykit_hexagon/bucket_empty.gltf"]


static func has(model: String) -> bool:
	return DRUMS.has(model) or CASKS.has(model) or TINS.has(model) or BUCKETS.has(model)


## Builds the stand-in under `parent` at `xform` (no scale). `size` is the
## kit model's box in metres, `base` the height of its underside.
static func build(parent: Node3D, model: String, xform: Transform3D, size: Vector3, base: float, opts: Dictionary) -> Node3D:
	var node := Node3D.new()
	node.transform = xform
	parent.add_child(node)
	var r := maxf(size.x, size.z) * 0.5
	var h := size.y
	var at := Transform3D(Basis(), Vector3(0, base, 0))
	if DRUMS.has(model):
		_drum(node, at, r, h, opts.get("tint", DRUMS[model]))
	elif CASKS.has(model):
		_cask(node, at, r, h)
	elif TINS.has(model):
		_tin(node, at, r, h, opts.get("tint", TINS[model]))
	else:
		_bucket(node, at, r, h)
	return node


static func _steel() -> ShaderMaterial:
	return StationKit.metal("prop_steel", {steel_color = Color("#8d9298"), rust = 0.25, dents = 0.2, metallic_steel = 0.75, roughness_steel = 0.42})


## 200-litre steel drum: chimes, two rolling hoops, sunk lid with bungs.
static func _drum(node: Node3D, at: Transform3D, r: float, h: float, color: Color) -> void:
	var paint := StationKit.metal("prop_drum_" + color.to_html(false), {steel_color = Color("#6a6d70"), paint = 0.9, paint_color = color, rust = 0.3, dents = 0.3,
		metallic_steel = 0.5, roughness_paint = 0.5})
	var p := PackedVector2Array([Vector2(0, 0.012 * h), Vector2(r * 0.9, 0.012 * h), Vector2(r * 0.94, 0), Vector2(r, 0.006 * h), Vector2(r, 0.03 * h), Vector2(r * 0.965, 0.04 * h)])
	for y: float in [0.34, 0.66]:
		p.append_array([Vector2(r * 0.965, (y - 0.03) * h), Vector2(r, (y - 0.012) * h), Vector2(r, (y + 0.012) * h), Vector2(r * 0.965, (y + 0.03) * h)])
	p.append_array([Vector2(r * 0.965, 0.96 * h), Vector2(r, 0.97 * h), Vector2(r, 0.994 * h), Vector2(r * 0.95, h), Vector2(r * 0.92, 0.99 * h), Vector2(r * 0.91, 0.965 * h), Vector2(0, 0.965 * h)])
	StationKit.add(node, StationKit.lathe(p, 32, 50.0), paint, at)
	var bungs := [MachineArt.turned(MachineArt.cap(r * 0.16, 0.012 * h), Vector3.UP, Vector3(r * 0.55, 0.965 * h, 0), 14),
		MachineArt.turned(MachineArt.cap(r * 0.09, 0.01 * h), Vector3.UP, Vector3(-r * 0.6, 0.965 * h, r * 0.1), 12)]
	StationKit.add(node, EnvMesh.merge(bungs), _steel(), at)


## Wooden cask: bulging staves, four iron hoops, a sunk head.
static func _cask(node: Node3D, at: Transform3D, r: float, h: float) -> void:
	var wood := EnvMesh.wood("prop_cask", {base_color = Color("#8a623f"), grain_color = Color("#4f3423"), weathering = 0.3})
	var p := PackedVector2Array([Vector2(0, 0.03 * h), Vector2(r * 0.74, 0.03 * h), Vector2(r * 0.76, 0), Vector2(r * 0.8, 0)])
	for i in 9:
		var t := i / 8.0
		p.append(Vector2(r * (0.8 + 0.2 * sin(t * PI)), h * t))
	p.append_array([Vector2(r * 0.76, h), Vector2(r * 0.74, 0.97 * h), Vector2(0, 0.97 * h)])
	# Staves: the bulge is pinched a little at each joint.
	var staves := 14
	StationKit.add(node, StationKit.lathe(p, 56, 50.0, func(v: Vector3, a: float) -> Vector3:
		var groove := pow(absf(sin(a * staves * 0.5)), 0.25)
		return Vector3(v.x * (0.975 + 0.025 * groove), v.y, v.z * (0.975 + 0.025 * groove))), wood, at)
	var hoops := []
	for y: float in [0.08, 0.3, 0.7, 0.92]:
		var rr := r * (0.8 + 0.2 * sin(y * PI)) + 0.006
		hoops.append(EnvMesh.piece(StationKit.lathe(PackedVector2Array([Vector2(rr - 0.03, (y - 0.025) * h), Vector2(rr + 0.004, (y - 0.025) * h), Vector2(rr + 0.004, (y + 0.025) * h),
			Vector2(rr - 0.03, (y + 0.025) * h)]), 40, 50.0), Transform3D()))
	StationKit.add(node, EnvMesh.merge(hoops), StationKit.metal("prop_hoop", {steel_color = Color("#3d3b3a"), rust = 0.18, dents = 0.15, metallic_steel = 0.6}), at)


## Paint tin: beaded rim, pressed lid, a wire bail.
static func _tin(node: Node3D, at: Transform3D, r: float, h: float, color: Color) -> void:
	var paint := StationKit.metal("prop_tin_" + color.to_html(false), {steel_color = Color("#8d9298"), paint = 0.85, paint_color = color, rust = 0.2, dents = 0.25, roughness_paint = 0.45})
	StationKit.add(node, StationKit.lathe(PackedVector2Array([Vector2(0, 0), Vector2(r * 0.96, 0), Vector2(r, 0.02 * h), Vector2(r * 0.97, 0.05 * h), Vector2(r * 0.97, 0.93 * h),
		Vector2(r, 0.95 * h), Vector2(r, 0.985 * h), Vector2(r * 0.94, h), Vector2(r * 0.86, 0.985 * h), Vector2(r * 0.84, 0.95 * h), Vector2(r * 0.4, 0.95 * h),
		Vector2(r * 0.36, 0.965 * h), Vector2(0, 0.965 * h)]), 24, 50.0), paint, at)
	var bail := StationKit.tube(MachineArt.smooth(PackedVector3Array([Vector3(-r, 0.8 * h, 0), Vector3(-r * 1.06, 0.6 * h, r * 0.35), Vector3(0, 0.42 * h, r * 1.08), Vector3(r * 1.06, 0.6 * h, r * 0.35),
		Vector3(r, 0.8 * h, 0)]), 0.02), maxf(0.004, r * 0.035), 6)
	StationKit.add(node, bail, _steel(), at)


## Galvanised bucket: open, tapered, rolled rim, swing handle.
static func _bucket(node: Node3D, at: Transform3D, r: float, h: float) -> void:
	var zinc := StationKit.metal("prop_bucket", {steel_color = Color("#9aa0a6"), rust = 0.2, dents = 0.3, metallic_steel = 0.8, roughness_steel = 0.4})
	StationKit.add(node, StationKit.lathe(PackedVector2Array([Vector2(0, 0), Vector2(r * 0.7, 0), Vector2(r * 0.72, 0.03 * h), Vector2(r * 0.97, 0.95 * h), Vector2(r, 0.97 * h), Vector2(r, 0.99 * h),
		Vector2(r * 0.96, h), Vector2(r * 0.93, 0.97 * h), Vector2(r * 0.68, 0.05 * h), Vector2(0, 0.05 * h)]), 28, 50.0), zinc, at)
	var handle := StationKit.tube(MachineArt.smooth(PackedVector3Array([Vector3(-r, 0.93 * h, 0), Vector3(-r * 0.95, 1.2 * h, r * 0.3), Vector3(0, 1.32 * h, r * 0.42), Vector3(r * 0.95, 1.2 * h, r * 0.3),
		Vector3(r, 0.93 * h, 0)]), 0.02), maxf(0.004, r * 0.03), 6)
	StationKit.add(node, handle, _steel(), at)
