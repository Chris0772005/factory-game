class_name SourceMachine
extends Machine
## Produces raw material at a fixed rate.


func _ready() -> void:
	inputs_needed = 0


func accept_item(_type_id: StringName, _cell: Vector2i) -> bool:
	return false


func _physics_process(delta: float) -> void:
	_buffer = 1
	super(delta)
