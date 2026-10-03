extends "res://scripts/style_test.gd"
## Physics conveyor test: a spawner feeds items onto a belt loop that
## ends at a drop-off, so items pile up on the floor.

var _spawned := 0
var _timer := 0.0
@export var max_items := 400


func _ready() -> void:
	_build_environment()
	_build_floor_body()
	for i in range(-6, 6):
		_place_belt(Vector3(i, 0, 0), 0.0)
	for j in range(0, 5):
		_place_belt(Vector3(6, 0, j), -PI / 2)
	var cam := Camera3D.new()
	cam.fov = 45
	add_child(cam)
	cam.look_at_from_position(Vector3(10, 10, 14), Vector3(2, 0, 2))


func _build_floor_body() -> void:
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 0.2, 40)
	shape.shape = box
	shape.position.y = -0.1
	floor_body.add_child(shape)
	add_child(floor_body)
	_build_floor()


func _place_belt(pos: Vector3, yaw: float) -> void:
	var belt := Belt.new()
	belt.position = pos
	belt.rotation.y = yaw
	add_child(belt)
	belt._update_velocity()
	_box(Vector3(1.0, 0.3, 1.0), Vector3(0, 0.15, 0), PALETTE.belt, belt)
	_box(Vector3(1.0, 0.12, 0.1), Vector3(0, 0.36, 0.48), PALETTE.belt_edge, belt)
	_box(Vector3(1.0, 0.12, 0.1), Vector3(0, 0.36, -0.48), PALETTE.belt_edge, belt)


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0 and _spawned < max_items:
		_timer = 0.12
		_spawned += 1
		var colors := [PALETTE.item, PALETTE.accent, PALETTE.machine, Color("#9b6fd1")]
		var item := Item.create(&"crate", colors[_spawned % colors.size()], randf_range(0.3, 0.45))
		item.position = Vector3(-6, 1.2, randf_range(-0.2, 0.2))
		item.rotation = Vector3(randf(), randf(), randf()) * TAU
		add_child(item)
	if Engine.get_physics_frames() % 120 == 0:
		print("items=%d fps=%d physics_ms=%.2f" % [_spawned, Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
