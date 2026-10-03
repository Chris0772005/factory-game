class_name BronzeStatue
extends Item
## A worker who got caught in a pour, frozen in metal mid-panic. Sellable.

const BASE_VALUE := 160

var pose := PackedFloat32Array()
var alloy := &"bronze"
var suit_color := Color.WHITE
var temperature := 0.4
var _materials: Array[ShaderMaterial] = []


static func from_data(data: Dictionary) -> BronzeStatue:
	var s := BronzeStatue.new()
	s.kind = &"statue"
	s.mass = 6.0
	s.position = data.pos
	s.rotation.y = data.get("yaw", 0.0)
	s.pose = data.get("pose", PlayerModel.panic_pose())
	s.alloy = data.get("alloy", &"bronze")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.75, 1.9, 0.55)
	shape.shape = box
	shape.position.y = 0.95
	s.add_child(shape)
	return s


func _ready() -> void:
	var model := PlayerModel.new()
	add_child(model)
	model.apply_pose(pose)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var mat := MetalMaterial.create(alloy)
		MetalMaterial.set_temperature(mat, temperature)
		(mi as MeshInstance3D).material_override = mat
		_materials.append(mat)
	# The model animates itself; a statue must stay frozen.
	model.set_process(false)
	model.set_physics_process(false)


func _physics_process(delta: float) -> void:
	if temperature > 0.0:
		temperature = maxf(0.0, temperature - delta / 10.0)
		for m in _materials:
			MetalMaterial.set_temperature(m, temperature)


func value() -> int:
	var mult: float = Alloys.TABLE.get(alloy, {}).get("value_mult", 1.0)
	return roundi(BASE_VALUE * mult)


func held_hint(_player: Node) -> String:
	return "Bronzefreund · %d $   [RMB] Werfen" % value()
