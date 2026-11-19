class_name ScrapTruck
extends Node3D
## The truck: when the skip is full it backs up to the hall, takes the load,
## drives off down the street through the gate and comes back empty. The
## load is paid at wholesale price when it leaves. Host decides when a trip
## starts; every peer drives the same path from the trip clock.

const GROUP := &"scrap_trucks"
const SPEED := 7.0
const LOAD_TIME := 3.0
const AWAY_TIME := 8.0
const MODEL := "res://assets/models/machinery/dump_truck.glb"
const WHEEL_RADIUS := 0.554

## Parking spot, the spot at the skip, the lane on the street and how far
## out the street leaves the map (the truck goes out one end and comes back
## in at the other: round the block).
var park := Vector3.ZERO
var dock := Vector3.ZERO
var lane_z := 0.0
var far_x := 42.0
var skip: ScrapSkip
## Trip clock in seconds, < 0 = parked.
var trip := -1.0
var loaded := false
var _path: Array[Vector3] = []
var _load_mesh: MeshInstance3D
var _wheels: Array = []
var _roll := 0.0
var _last_pos := Vector3.ZERO
var _paid := false
var _lamps: Array[BaseMaterial3D] = []
var _beams: Array[SpotLight3D] = []
var _lit := false


func _init() -> void:
	name = "ScrapTruck"


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_to_group(GROUP)
	global_position = park
	rotation.y = PI * 0.5
	_last_pos = global_position
	_build_art()
	# People do not walk through a truck.
	var solid := AnimatableBody3D.new()
	solid.sync_to_physics = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.6, 3.3, 7.8)
	shape.shape = box
	shape.position = Vector3(0, 1.65, 0)
	solid.add_child(shape)
	add_child(solid)


func busy() -> bool:
	return trip >= 0.0


func _out_path() -> Array[Vector3]:
	return [dock, Vector3(dock.x + 6.5, 0, lane_z), Vector3(far_x, 0, lane_z)]


func _back_path() -> Array[Vector3]:
	return [Vector3(-far_x, 0, lane_z), Vector3(park.x - 7.0, 0, lane_z), park]


static func _length(path: Array[Vector3]) -> float:
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total


## Seconds for each leg: to the skip, loading, out of the quarter, away, back to the parking spot.
func _legs() -> Array[float]:
	return [park.distance_to(dock) / SPEED, LOAD_TIME, _length(_out_path()) / SPEED, AWAY_TIME, _length(_back_path()) / SPEED]


func _physics_process(delta: float) -> void:
	if Network.is_sim_authority() and not busy() and skip and skip.is_full():
		_start()
		if Network.is_online():
			_start_remote.rpc()
	if not busy():
		return
	trip += delta
	var legs := _legs()
	var t := trip
	if t < legs[0]:
		_drive([park, dock] as Array[Vector3], t / legs[0])
	elif t < legs[0] + legs[1]:
		global_position = dock
		if not _paid and t > legs[0] + legs[1] * 0.6:
			_paid = true
			loaded = true
			if Network.is_sim_authority() and skip:
				skip.haul(ScrapSkip.TRUCK_SHARE)
				Missions.report(get_tree(), &"truck_load", 1)
			Sfx.play(&"scrap_clatter", global_position + Vector3(0, 1.4, 0), 0.0, 0.1)
	elif t < legs[0] + legs[1] + legs[2]:
		_drive(_out_path(), (t - legs[0] - legs[1]) / legs[2])
	elif t < legs[0] + legs[1] + legs[2] + legs[3]:
		global_position = Vector3(-far_x, 0, lane_z)
		loaded = false
	elif t < legs[0] + legs[1] + legs[2] + legs[3] + legs[4]:
		_drive(_back_path(), (t - legs[0] - legs[1] - legs[2] - legs[3]) / legs[4])
	else:
		trip = -1.0
		global_position = park
		rotation.y = PI * 0.5
	if _load_mesh:
		_load_mesh.visible = loaded
	_light(busy())
	_roll_wheels()


func _start() -> void:
	trip = 0.0
	_paid = false
	loaded = false


@rpc("authority", "call_remote", "reliable")
func _start_remote() -> void:
	_start()


## Position `k` (0..1) along `path`, easing in and out; the nose follows the road.
func _drive(path: Array[Vector3], k: float) -> void:
	k = clampf(k, 0.0, 1.0)
	var e := k * k * (3.0 - 2.0 * k)
	var want := e * _length(path)
	for i in range(1, path.size()):
		var seg := path[i - 1].distance_to(path[i])
		if want <= seg or i == path.size() - 1:
			global_position = path[i - 1].lerp(path[i], clampf(want / maxf(seg, 0.01), 0.0, 1.0))
			var dir := path[i] - path[i - 1]
			if Vector2(dir.x, dir.z).length() > 0.1:
				rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), 0.1)
			return
		want -= seg


## The model (tools/blender/dump_truck.py -> dump_truck.glb, from a CC-BY model, see CREDITS.md) faces +X; the truck faces +Z.
func _build_art() -> void:
	if not StationKit.visual():
		return
	var packed := load(MODEL) as PackedScene
	if packed == null:
		return
	var model := packed.instantiate() as Node3D
	model.rotation.y = -PI * 0.5
	add_child(model)
	# Paint, glass and road dirt (the project's vehicle finish); headlamps that come on for the trip.
	VehicleFinish.apply(model, {mud = 0.7, mud_height = 0.9, dust = 0.3})
	_lamps = VehicleFinish.lamps(model)
	var heads := model.find_child("head_lamps", true, false) as MeshInstance3D
	if heads:
		var box := (global_transform.affine_inverse() * heads.global_transform) * heads.get_aabb()
		for side: float in [-1.0, 1.0]:
			var at := Vector3(box.get_center().x + side * (box.size.x * 0.5 - 0.18), box.get_center().y, box.end.z + 0.05)
			_beams.append(VehicleFinish.beam(self, at, Vector3(0.0, -0.13, 1.0)))
	_lit = true
	_light(false)
	for node in model.find_children("wheel_*", "Node3D", true, false):
		var wheel := node as Node3D
		if wheel is MeshInstance3D:
			continue
		# The file's wheel nodes all stand the same way: their local Z points to the truck's right.
		_wheels.append([wheel, wheel.transform, -1.0])
	_load_mesh = MeshInstance3D.new()
	_load_mesh.mesh = EnvMesh.box(Vector3(1.8, 0.9, 4.6), 0.3, 2)
	_load_mesh.material_override = StationKit.metal("skip_load", {steel_color = Color("#6f6a66"), rust = 0.75, dents = 1.0, metallic_steel = 0.6, roughness_steel = 0.65})
	_load_mesh.position = Vector3(0, 2.05, -0.95)
	_load_mesh.visible = false
	add_child(_load_mesh)


## Lamps and beams: on while the truck is on its trip.
func _light(on: bool) -> void:
	if on == _lit:
		return
	_lit = on
	VehicleFinish.light(_lamps, on)
	for spot in _beams:
		spot.visible = on


## The wheels roll with the distance driven.
func _roll_wheels() -> void:
	var step := global_position - _last_pos
	_last_pos = global_position
	if _wheels.is_empty() or step.length() < 0.0001 or step.length() > 5.0:
		return
	var forward := global_transform.basis.z
	_roll += step.dot(forward) / WHEEL_RADIUS
	for entry: Array in _wheels:
		(entry[0] as Node3D).transform = (entry[1] as Transform3D) * Transform3D(Basis(Vector3(0, 0, 1), _roll * float(entry[2])), Vector3.ZERO)
