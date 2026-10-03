class_name ItemType
extends Resource
## Definition of a product kind: look, physics and value.

@export var id := &"crate"
@export var size := Vector3.ONE * 0.4
@export var color := Color.WHITE
@export var mass := 0.5
@export var value := 1
@export var mesh: Mesh


static var _registry := {}


static func register(t: ItemType) -> ItemType:
	if t.mesh == null:
		var smallest := minf(t.size.x, minf(t.size.y, t.size.z))
		t.mesh = MeshFactory.rounded_box(t.size, minf(smallest * 0.4, 0.09))
	_registry[t.id] = t
	return t


static func get_type(type_id: StringName) -> ItemType:
	return _registry.get(type_id)


static func define(type_id: StringName, type_size: Vector3, type_color: Color, type_mass := 0.5, type_value := 1) -> ItemType:
	var t := ItemType.new()
	t.id = type_id
	t.size = type_size
	t.color = type_color
	t.mass = type_mass
	t.value = type_value
	return register(t)
