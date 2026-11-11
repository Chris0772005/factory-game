class_name PhotoProp
## Scanned stand-ins for kit props: CC0 models from Poly Haven (1k textures,
## assets/models/polyhaven, see CREDITS.md) keep their own photo materials.
## PropKit swaps them in by kit model name and fits them to the kit model's
## bounds, so placement and colliders stay as they were.

const ROOT := "res://assets/models/polyhaven/"
## kit model -> scans to pick from (by position, so a level always looks the same).
const SWAPS := {
	"kaykit_prototype/Barrel_A.gltf": ["Barrel_02", "barrel_03"],
	"kaykit_prototype/Barrel_B.gltf": ["Barrel_01"],
	"kaykit_prototype/Barrel_C.gltf": ["barrel_03", "Barrel_02"],
	"kaykit_dungeon/barrel_large.gltf": ["wine_barrel_01"],
	"kaykit_dungeon/barrel_small.gltf": ["wine_barrel_01"],
	"kaykit_hexagon/barrel.gltf": ["wine_barrel_01"],
	"kaykit_dungeon/keg.gltf": ["wine_barrel_01"],
	"kaykit_hexagon/crate_A_big.gltf": ["wooden_crate_01", "wooden_crate_02"],
	"kaykit_restaurant/crate.gltf": ["wooden_crate_02", "wooden_crate_01"],
	"kaykit_dungeon/box_small.gltf": ["wooden_crate_01"],
	"kaykit_city/box_A.gltf": ["cardboard_box_01"],
	"kaykit_city/box_B.gltf": ["cardboard_box_01"],
	"kaykit_hexagon/bucket_empty.gltf": ["wooden_bucket_01"],
	"kaykit_hexagon/sack.gltf": ["cement_bag"],
	"kaykit_city/bush.gltf": ["shrub_02:0", "shrub_02:1", "shrub_02:3"],
	"kaykit_furniture/chair_A_wood.gltf": ["painted_wooden_chair_01"],
}

static var _scenes := {}
static var _bounds := {}


static func has(model: String) -> bool:
	return SWAPS.has(model)


## Builds the scan under `parent` at `xform` (no scale). `size` is the kit
## model's box in metres, `base` the height of its underside.
static func build(parent: Node3D, model: String, xform: Transform3D, size: Vector3, base: float) -> Node3D:
	var options: Array = SWAPS[model]
	var pick: String = options[absi(int(xform.origin.x * 7.0) + int(xform.origin.z * 13.0)) % options.size()]
	# "name:2" picks the third variant of a model that ships several in a row.
	var variant := -1
	if ":" in pick:
		variant = int(pick.get_slice(":", 1))
		pick = pick.get_slice(":", 0)
	var scene := _scene(pick)
	var box := _box(pick, variant)
	# Same height as the kit prop, but never much wider than its footprint.
	var s := size.y / maxf(box.size.y, 0.001)
	var wide := maxf(box.size.x, box.size.z) * s
	var room := maxf(size.x, size.z) * 1.2
	if wide > room:
		s *= room / wide
	var node: Node3D = scene.instantiate()
	if variant >= 0:
		var parts := node.find_children("*", "MeshInstance3D", true, false)
		for i in parts.size():
			(parts[i] as Node3D).visible = i == variant
	var centre := box.get_center()
	node.transform = xform * Transform3D(Basis().scaled(Vector3.ONE * s), Vector3(-centre.x * s, base - box.position.y * s, -centre.z * s))
	parent.add_child(node)
	return node


static func _scene(name: String) -> PackedScene:
	if not _scenes.has(name):
		_scenes[name] = load(ROOT + "%s/%s_1k.gltf" % [name, name])
	return _scenes[name]


static func _box(name: String, variant := -1) -> AABB:
	var key := "%s:%d" % [name, variant]
	if _bounds.has(key):
		return _bounds[key]
	var node: Node3D = _scene(name).instantiate()
	var box := AABB()
	var first := true
	var parts := node.find_children("*", "MeshInstance3D", true, false)
	for i in parts.size():
		var m := parts[i] as MeshInstance3D
		if m.mesh == null or (variant >= 0 and i != variant):
			continue
		var b := PropKit._relative(node, m) * m.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	node.free()
	_bounds[key] = box
	return box
