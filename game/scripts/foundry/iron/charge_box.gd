class_name ChargeBox
extends Item
## One charge for a furnace: a wire basket of broken cast iron from the
## scrap heap, or a strapped stack of bell-bronze ingots bought by the
## pallet. Thrown into the cupola's skip (or any furnace) it melts in whole.

const LOOKS := {
	&"iron": {name = "Eisenschrott-Korb", metal = &"iron", litres = 6.0, mass = 8.0, size = Vector3(0.5, 0.3, 0.4)},
	&"bronze": {name = "Glockenbronze", metal = &"copper", litres = 8.0, mass = 9.0, size = Vector3(0.46, 0.24, 0.32)},
}

var look := &"iron"


static func create_box(data: Dictionary) -> ChargeBox:
	var b := ChargeBox.new()
	b.kind = &"charge"
	b.look = StringName(data.get("look", "iron"))
	var info: Dictionary = LOOKS.get(b.look, LOOKS[&"iron"])
	b.mass = info.mass
	b.position = data.pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = info.size
	shape.shape = box
	shape.position.y = info.size.y * 0.5
	b.add_child(shape)
	b.physics_material_override = PhysicsMaterial.new()
	b.physics_material_override.friction = 0.9
	return b


func info() -> Dictionary:
	return LOOKS.get(look, LOOKS[&"iron"])


func melt_mix() -> Dictionary:
	return {info().metal: info().litres}


func held_hint(_player: Node) -> String:
	return "%s (%s l) – in den Gichtkübel am Kupolofen werfen   [RMB] Werfen" % [info().name, ("%.0f" % info().litres)]


func _ready() -> void:
	if not StationKit.visual():
		return
	if look == &"bronze":
		ChargeBox.build_ingots(self, 0)
	else:
		ChargeBox.build_basket(self, get_instance_id())


## Wire basket of rusty cast-iron chunks (also used as dressing).
static func build_basket(parent: Node3D, seed_value: int) -> void:
	var size: Vector3 = LOOKS[&"iron"].size
	var wire := StationKit.metal("basket_wire", {steel_color = Color("#4a4845"), rust = 0.55, metallic_steel = 0.6})
	var rods := []
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			rods.append(EnvMesh.piece(EnvMesh.box(Vector3(0.025, size.y, 0.025)), Transform3D(Basis(), Vector3(x * size.x * 0.5, size.y * 0.5, z * size.z * 0.5))))
	for y: float in [0.02, size.y * 0.5, size.y]:
		for z: float in [-1.0, 1.0]:
			rods.append(EnvMesh.piece(EnvMesh.box(Vector3(size.x, 0.018, 0.018)), Transform3D(Basis(), Vector3(0, y, z * size.z * 0.5))))
		for x: float in [-1.0, 1.0]:
			rods.append(EnvMesh.piece(EnvMesh.box(Vector3(0.018, 0.018, size.z)), Transform3D(Basis(), Vector3(x * size.x * 0.5, y, 0))))
	for k in 4:
		rods.append(EnvMesh.piece(EnvMesh.box(Vector3(0.012, 0.012, size.z)), Transform3D(Basis(), Vector3(-size.x * 0.3 + k * size.x * 0.2, 0.02, 0))))
	StationKit.add_merged(parent, rods, wire)
	var iron := StationKit.metal("cast_iron_scrap", {steel_color = Color("#5a514b"), rust = 0.85, dents = 0.5, metallic_steel = 0.35, roughness_steel = 0.8})
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var chunks := []
	for i in 9:
		var p := Vector3(rng.randf_range(-0.17, 0.17), rng.randf_range(0.08, 0.24), rng.randf_range(-0.12, 0.12))
		chunks.append(EnvMesh.piece(StationKit.chunk(rng.randf_range(0.07, 0.11), i + seed_value % 97, 0.6, 0.5),
			Transform3D(Basis.from_euler(Vector3(rng.randf() * 3.0, rng.randf() * 3.0, 0)), p)))
	StationKit.add_merged(parent, chunks, iron)


## Bell-bronze ingots strapped on a small skid.
static func build_ingots(parent: Node3D, _seed_value: int) -> void:
	var size: Vector3 = LOOKS[&"bronze"].size
	var skid := StationKit.wood("ingot_skid", {base_color = Color("#a8825a"), weathering = 0.3})
	var planks := []
	for z: float in [-0.11, 0.0, 0.11]:
		planks.append(EnvMesh.piece(EnvMesh.box(Vector3(size.x, 0.025, 0.08), 0.004), Transform3D(Basis(), Vector3(0, 0.05, z))))
	for x: float in [-0.17, 0.17]:
		planks.append(EnvMesh.piece(EnvMesh.box(Vector3(0.06, 0.04, size.z), 0.004), Transform3D(Basis(), Vector3(x, 0.02, 0))))
	StationKit.add_merged(parent, planks, skid)
	var bronze := MetalMaterial.create(&"bronze", 3)
	bronze.set_shader_parameter(&"crust", 0.15)
	var ingot := StationKit.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.06, 0.0), Vector2(0.05, 0.05), Vector2(0.0, 0.05)]), 4, 30.0)
	var bars := []
	for layer in 3:
		for k in 3:
			var p := Vector3(-0.13 + k * 0.13 + (0.03 if layer % 2 == 1 else 0.0), 0.065 + layer * 0.055, 0.0)
			bars.append(EnvMesh.piece(ingot, Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 2.2)) * Basis(Vector3.UP, PI * 0.25), p)))
	StationKit.add_merged(parent, bars, bronze)
	var strap := StationKit.metal("ingot_strap", {steel_color = Color("#3b3937"), rust = 0.3})
	StationKit.add(parent, EnvMesh.box(Vector3(size.x + 0.01, 0.012, 0.03)), strap, Transform3D(Basis(), Vector3(0, 0.235, 0)))
