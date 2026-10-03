class_name Machine
extends Node3D
## Base for factory machines placed on the grid. A machine occupies cells,
## takes items from belts that run into it and pushes products onto its
## output belt cell.

@export var input_types: Array[StringName] = []
@export var output_type: StringName = &""
@export var process_time := 1.0
@export var inputs_needed := 1
@export var buffer_size := 4

var grid: FactoryGrid
var cells: Array = []
var output_cell := Vector2i.ZERO
var has_output := false

var _buffer := 0
var _progress := 0.0
var _pending_output := 0
var _pulse := 0.0
var _visual: Node3D


func setup(factory: FactoryGrid, origin: Vector2i, footprint: Vector2i, out_cell = null) -> void:
	grid = factory
	for x in footprint.x:
		for y in footprint.y:
			cells.append(origin + Vector2i(x, y))
	grid.register_machine(self, cells)
	if out_cell != null:
		output_cell = out_cell
		has_output = true
	var center := Vector3.ZERO
	for c in cells:
		center += grid.cell_to_world(c)
	position = center / cells.size()
	_build_visual(footprint)


func _build_visual(footprint: Vector2i) -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var size := Vector3(footprint.x * FactoryGrid.CELL * 0.92, 1.4, footprint.y * FactoryGrid.CELL * 0.92)
	var body := WorldBuilder.add_box(_visual, size, Vector3(0, size.y * 0.5, 0), WorldBuilder.PALETTE.machine, true)
	body.name = "Body"
	WorldBuilder.add_box(_visual, Vector3(size.x + 0.08, 0.18, size.z + 0.08), Vector3(0, size.y + 0.09, 0), WorldBuilder.PALETTE.machine_dark)


func accept_item(type_id: StringName, _cell: Vector2i) -> bool:
	if not input_types.is_empty() and not type_id in input_types:
		return false
	if _buffer >= buffer_size:
		return false
	_buffer += 1
	return true


func _physics_process(delta: float) -> void:
	_pulse = maxf(0.0, _pulse - delta * 4.0)
	if _visual:
		_visual.scale = Vector3.ONE * (1.0 + _pulse * 0.06)
	if not Network.is_sim_authority():
		return
	if _pending_output > 0 and _try_output():
		_pending_output -= 1
	if _buffer >= inputs_needed and _pending_output == 0:
		_progress += delta
		if _progress >= process_time:
			_progress = 0.0
			_buffer -= inputs_needed
			_pulse = 1.0
			_on_processed()


## Default: turn inputs into one output item.
func _on_processed() -> void:
	if output_type != &"":
		_pending_output += 1


func _try_output() -> bool:
	if not has_output:
		return true
	return grid.insert(output_cell, output_type, 0.0)
