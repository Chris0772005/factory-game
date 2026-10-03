class_name Item
extends RigidBody3D
## A physical product that flows through the factory.

@export var kind := &"crate"


static func create(kind_name: StringName, color: Color, size: Vector3 = Vector3.ONE * 0.4, item_mass := 0.5) -> Item:
	var item := Item.new()
	item.kind = kind_name
	item.mass = item_mass
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	item.add_child(shape)
	var mi := MeshInstance3D.new()
	var smallest := minf(size.x, minf(size.y, size.z))
	mi.mesh = MeshFactory.rounded_box(size, minf(smallest * 0.4, 0.09))
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.45
	mi.material_override = mat
	item.add_child(mi)
	item.physics_material_override = PhysicsMaterial.new()
	item.physics_material_override.friction = 0.9
	return item


var _holders := 0


func on_grabbed(_by: Node) -> void:
	_holders += 1


func on_released(_by: Node) -> void:
	_holders = maxi(0, _holders - 1)


func is_held() -> bool:
	return _holders > 0
