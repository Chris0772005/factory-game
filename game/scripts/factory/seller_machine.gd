class_name SellerMachine
extends Machine
## Delivery chute: every item that enters is sold.

signal sold(type_id: StringName, value: int)

var total_sold := 0


func accept_item(type_id: StringName, _cell: Vector2i) -> bool:
	var t := ItemType.get_type(type_id)
	var value := t.value if t else 1
	total_sold += 1
	_pulse = 1.0
	sold.emit(type_id, value)
	return true
