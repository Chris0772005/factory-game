class_name CastPiece
extends Item
## A finished casting: a relief built from a player's drawing in some alloy.
## Rebuilt identically on every peer from its replicated data.

const COOL_TIME := 9.0

var drawing_code := ""
var alloy := &"alu"
var quality := 0.5
var defects := {}
var area := 0.0
var temperature := 0.0
var _material: ShaderMaterial


static func from_data(data: Dictionary) -> CastPiece:
	var piece := CastPiece.new()
	piece.kind = &"cast"
	piece.drawing_code = data.code
	piece.alloy = data.alloy
	piece.quality = data.quality
	piece.defects = data.get("defects", {})
	piece.temperature = data.get("temperature", 0.0)
	piece.position = data.pos
	var drawing := Drawing.from_code(piece.drawing_code)
	var built := CastMeshBuilder.build(drawing, data.get("size", 0.5), data.get("thickness", 0.07)) if drawing else {}
	piece.area = built.get("area", 0.05)
	var density: float = 2.7 if piece.alloy == &"alu" else 8.5
	piece.mass = clampf(built.get("volume", 0.002) * density * 1000.0 * 0.25, 0.4, 12.0)
	for shape in built.get("shapes", []):
		var cs := CollisionShape3D.new()
		cs.shape = shape
		piece.add_child(cs)
	if piece.get_child_count() == 0:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.3, 0.07, 0.3)
		cs.shape = box
		piece.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = built.get("mesh", MeshFactory.rounded_box(Vector3(0.3, 0.07, 0.3), 0.02))
	piece._material = MetalMaterial.create(piece.alloy)
	MetalMaterial.set_temperature(piece._material, piece.temperature)
	piece._material.set_shader_parameter("defect_amount", FoundryRules.defect_amount(piece.defects))
	mi.material_override = piece._material
	piece.add_child(mi)
	piece.physics_material_override = PhysicsMaterial.new()
	piece.physics_material_override.friction = 0.8
	piece.physics_material_override.bounce = 0.1
	return piece


func _physics_process(delta: float) -> void:
	if temperature > 0.0:
		temperature = maxf(0.0, temperature - delta / COOL_TIME)
		MetalMaterial.set_temperature(_material, temperature)


func value() -> int:
	return FoundryRules.price(area, alloy, quality)


func grade_name() -> String:
	return FoundryRules.grade(quality).name


func held_hint(_player: Node) -> String:
	return "%s · %s · %d $   [RMB] Werfen" % [Alloys.TABLE.get(alloy, {}).get("name", alloy), grade_name(), value()]
