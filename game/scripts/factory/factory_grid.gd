class_name FactoryGrid
extends Node3D
## Grid-based conveyor simulation. Items riding belts are plain data and are
## drawn with one MultiMesh per item type, so thousands stay cheap. An item
## that runs off a belt end (or gets grabbed) turns into a physics body.
##
## Only the simulating peer (host) runs the simulation; clients receive
## compact snapshots.

signal item_spilled(item: Item)

const CELL := 1.0
const BELT_TOP := 0.32
const SPACING := 0.34
const DIRS := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
const SNAPSHOT_RATE := 10.0

## cell -> {dir:int, speed:float, items:Array[Dictionary{type, p}] }  p in [0,1] along the belt
var belts := {}
## cell -> machine node occupying that cell (machines may span several cells)
var machines := {}
var world: GameWorld

var _multimeshes := {}     # type_id -> MultiMeshInstance3D
var _snap_accum := 0.0


func _physics_process(delta: float) -> void:
	if Network.is_sim_authority():
		_step(delta)
		_absorb_dropped_items()
		if Network.is_online():
			_snap_accum += delta
			if _snap_accum >= 1.0 / SNAPSHOT_RATE:
				_snap_accum = 0.0
				_send_snapshot()
	else:
		_client_advance(delta)


func _process(_delta: float) -> void:
	_render()


# --- Building ---------------------------------------------------------------

func add_belt(cell: Vector2i, dir: int, speed := 1.2) -> void:
	belts[cell] = {dir = dir, speed = speed, items = []}
	var visual := Node3D.new()
	visual.name = "Belt_%d_%d" % [cell.x, cell.y]
	visual.position = cell_to_world(cell)
	visual.rotation.y = -dir * PI / 2.0
	add_child(visual)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(CELL, 0.3, CELL)
	shape.shape = box
	shape.position.y = 0.15
	body.add_child(shape)
	visual.add_child(body)
	WorldBuilder.add_box(visual, Vector3(CELL, 0.3, CELL * 0.98), Vector3(0, 0.15, 0), WorldBuilder.PALETTE.belt)
	for side in [-1, 1]:
		WorldBuilder.add_box(visual, Vector3(CELL, 0.1, 0.08), Vector3(0, 0.33, side * 0.47), WorldBuilder.PALETTE.belt_edge)
	var arrow := WorldBuilder.add_box(visual, Vector3(0.28, 0.02, 0.08), Vector3(-0.1, 0.305, 0), WorldBuilder.PALETTE.belt.lightened(0.25))
	arrow.rotation.y = 0.0


func register_machine(machine: Node3D, cells: Array) -> void:
	for c in cells:
		machines[c] = machine


func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * CELL, 0, cell.y * CELL)


func world_to_cell(pos: Vector3) -> Vector2i:
	return Vector2i(roundi(pos.x / CELL), roundi(pos.z / CELL))


## World position of an item at progress p on a belt (enters at the back edge).
func item_position(cell: Vector2i, belt: Dictionary, p: float) -> Vector3:
	var d: Vector2i = DIRS[belt.dir]
	var start := cell_to_world(cell) - Vector3(d.x, 0, d.y) * CELL * 0.5
	return start + Vector3(d.x, 0, d.y) * CELL * p + Vector3(0, BELT_TOP, 0)


## Try to place an item at the start of a belt cell; false if no room.
func insert(cell: Vector2i, type_id: StringName, p := 0.0) -> bool:
	var belt: Dictionary = belts.get(cell, {})
	if belt.is_empty():
		return false
	var items: Array = belt.items
	for it in items:
		if absf(it.p - p) < SPACING:
			return false
	var idx := 0
	while idx < items.size() and items[idx].p > p:
		idx += 1
	items.insert(idx, {type = type_id, p = p})
	return true


# --- Simulation -------------------------------------------------------------

func _step(delta: float) -> void:
	for cell in belts:
		var belt: Dictionary = belts[cell]
		var items: Array = belt.items
		if items.is_empty():
			continue
		var next_cell: Vector2i = cell + DIRS[belt.dir]
		# Items are sorted front (highest p) first.
		var limit := 1.0 + _room_ahead(next_cell, belt.dir)
		for i in items.size():
			var it: Dictionary = items[i]
			var cap: float = limit if i == 0 else items[i - 1].p - SPACING
			it.p = minf(it.p + belt.speed * delta / CELL, cap)
		var front: Dictionary = items[0]
		if front.p >= 1.0:
			if _hand_over(cell, belt, front, next_cell):
				items.pop_front()


## How far past the belt end the front item may move before blocking.
func _room_ahead(next_cell: Vector2i, dir: int) -> float:
	var nb: Dictionary = belts.get(next_cell, {})
	if not nb.is_empty() and nb.dir != (dir + 2) % 4:
		if nb.items.is_empty():
			return SPACING
		return clampf(nb.items[-1].p - SPACING, 0.0, SPACING)
	return SPACING


func _hand_over(cell: Vector2i, belt: Dictionary, it: Dictionary, next_cell: Vector2i) -> bool:
	var nb: Dictionary = belts.get(next_cell, {})
	if not nb.is_empty() and nb.dir != (belt.dir + 2) % 4:
		return insert(next_cell, it.type, maxf(it.p - 1.0, 0.0))
	var machine: Node = machines.get(next_cell)
	if machine:
		if machine.has_method("accept_item") and machine.accept_item(it.type, next_cell):
			return true
		it.p = 1.0
		return false
	_spill(cell, belt, it)
	return true


func _spill(cell: Vector2i, belt: Dictionary, it: Dictionary) -> void:
	var t := ItemType.get_type(it.type)
	if t == null or world == null:
		return
	var pos := item_position(cell, belt, 1.0) + Vector3(0, t.size.y * 0.5 + 0.02, 0)
	var item := world.spawn_item(t.id, t.color, t.size, t.mass, pos)
	var d: Vector2i = DIRS[belt.dir]
	item.linear_velocity = Vector3(d.x, 0, d.y) * belt.speed
	item_spilled.emit(item)


## Physics items that come to rest on a belt rejoin the data simulation.
func _absorb_dropped_items() -> void:
	if world == null or Engine.get_physics_frames() % 6 != 0:
		return
	for node in world.entities.get_children():
		var item := node as Item
		if item == null or item.is_held() or ItemType.get_type(item.kind) == null:
			continue
		if item.linear_velocity.length() > 2.0 or item.global_position.y > BELT_TOP + 0.6:
			continue
		var cell := world_to_cell(item.global_position)
		var belt: Dictionary = belts.get(cell, {})
		if belt.is_empty() or item.global_position.y < BELT_TOP:
			continue
		var d: Vector2i = DIRS[belt.dir]
		var local := (item.global_position - cell_to_world(cell)).dot(Vector3(d.x, 0, d.y)) / CELL + 0.5
		if insert(cell, item.kind, clampf(local, 0.0, 0.99)):
			item.queue_free()


## Remove the data item closest to `pos` (within range) and return it as a physics body.
func pick_item(pos: Vector3, max_dist := 1.3) -> Item:
	var best_cell = null
	var best_idx := -1
	var best_d := max_dist
	for cell in belts:
		var belt: Dictionary = belts[cell]
		for i in belt.items.size():
			var d := item_position(cell, belt, belt.items[i].p).distance_to(pos)
			if d < best_d:
				best_d = d
				best_cell = cell
				best_idx = i
	if best_cell == null:
		return null
	var belt: Dictionary = belts[best_cell]
	var it: Dictionary = belt.items[best_idx]
	belt.items.remove_at(best_idx)
	var t := ItemType.get_type(it.type)
	return world.spawn_item(t.id, t.color, t.size, t.mass,
		item_position(best_cell, belt, it.p) + Vector3(0, t.size.y * 0.5 + 0.02, 0))


func count_items() -> int:
	var n := 0
	for cell in belts:
		n += belts[cell].items.size()
	return n


# --- Rendering --------------------------------------------------------------

func _render() -> void:
	var per_type := {}
	for cell in belts:
		var belt: Dictionary = belts[cell]
		var yaw: float = -belt.dir * PI / 2.0
		for it in belt.items:
			var t := ItemType.get_type(it.type)
			if t == null:
				continue
			var xf := Transform3D(Basis(Vector3.UP, yaw), item_position(cell, belt, minf(it.p, 1.0)) + Vector3(0, t.size.y * 0.5, 0))
			if not per_type.has(it.type):
				per_type[it.type] = []
			per_type[it.type].append(xf)
	for type_id in _multimeshes:
		if not per_type.has(type_id):
			_multimeshes[type_id].multimesh.visible_instance_count = 0
	for type_id in per_type:
		var mmi := _multimesh_for(type_id)
		var list: Array = per_type[type_id]
		var mm := mmi.multimesh
		if mm.instance_count < list.size():
			mm.instance_count = maxi(list.size(), mm.instance_count * 2)
		mm.visible_instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])


func _multimesh_for(type_id: StringName) -> MultiMeshInstance3D:
	if _multimeshes.has(type_id):
		return _multimeshes[type_id]
	var t := ItemType.get_type(type_id)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = t.mesh
	mm.instance_count = 64
	mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = WorldBuilder.material(t.color, 0.45)
	add_child(mmi)
	_multimeshes[type_id] = mmi
	return mmi


# --- Networking -------------------------------------------------------------

func _send_snapshot() -> void:
	var cells := PackedInt32Array()
	var types := PackedStringArray()
	var progress := PackedFloat32Array()
	for cell in belts:
		for it in belts[cell].items:
			cells.append_array([cell.x, cell.y])
			types.append(it.type)
			progress.append(it.p)
	_receive_snapshot.rpc(cells, types, progress)


@rpc("authority", "call_remote", "unreliable_ordered")
func _receive_snapshot(cells: PackedInt32Array, types: PackedStringArray, progress: PackedFloat32Array) -> void:
	for cell in belts:
		belts[cell].items = []
	for i in types.size():
		var cell := Vector2i(cells[i * 2], cells[i * 2 + 1])
		if belts.has(cell):
			belts[cell].items.append({type = StringName(types[i]), p = progress[i]})
	for cell in belts:
		belts[cell].items.sort_custom(func(a, b): return a.p > b.p)


## Between snapshots clients move items along locally so motion stays smooth.
func _client_advance(delta: float) -> void:
	for cell in belts:
		var belt: Dictionary = belts[cell]
		var items: Array = belt.items
		for i in items.size():
			var cap: float = 1.0 if i == 0 else items[i - 1].p - SPACING
			items[i].p = minf(items[i].p + belt.speed * delta / CELL, cap)
