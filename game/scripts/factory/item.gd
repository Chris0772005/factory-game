class_name Item
extends RigidBody3D
## A physical product that flows through the factory.

@export var kind := &"crate"
@export var value := 1


static func create(kind_name: StringName, color: Color, size := 0.4) -> Item:
	var item := Item.new()
	item.kind = kind_name
	item.mass = 0.5
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3.ONE * size
	shape.shape = box
	item.add_child(shape)
	var mi := MeshInstance3D.new()
	mi.mesh = MeshFactory.rounded_box(Vector3.ONE * size, size * 0.18)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.45
	mi.material_override = mat
	item.add_child(mi)
	item.physics_material_override = PhysicsMaterial.new()
	item.physics_material_override.friction = 0.9
	item.can_sleep = true
	return item
