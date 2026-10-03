class_name Belt
extends StaticBody3D
## Conveyor tile. Physics bodies resting on it are carried along
## via the static body's constant linear velocity.

const SIZE := Vector3(1.0, 0.3, 1.0)

@export var speed := 1.5:
	set(value):
		speed = value
		_update_velocity()


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SIZE
	shape.shape = box
	shape.position.y = SIZE.y * 0.5
	add_child(shape)
	var rail := BoxShape3D.new()
	rail.size = Vector3(SIZE.x, 0.25, 0.08)
	for side in [-1, 1]:
		var rs := CollisionShape3D.new()
		rs.shape = rail
		rs.position = Vector3(0, SIZE.y + 0.12, side * 0.48)
		add_child(rs)
	_update_velocity()
	set_physics_process(true)


func _update_velocity() -> void:
	if is_inside_tree():
		constant_linear_velocity = global_transform.basis.x * speed
