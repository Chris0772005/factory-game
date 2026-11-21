class_name TownTraffic
extends Node3D
## Cars that drive through the quarter. The street is one-way, west to east: they come along the
## cross road beyond the viaduct, turn into the western side street and under the viaduct, drive
## down the street in the lane the scrap truck uses, and leave up the eastern side street, under
## the viaduct and away along the cross road. They keep their distance from each
## other and stop for people (players, the people on the pavement, the officer on the beat) and
## for the scrap truck. The boom gates lift for them, and their wheels turn with the way they go.
## The host drives them and tells the others a few times a second where each one is; in between
## every peer drives them on by the same rules, so a car stops for a player on every screen.

const GROUP := &"town_traffic"
## Every car's node is in this group (the boom gates and the scrap truck look for them).
const CAR_GROUP := &"traffic_cars"
## Speeds (m/s): down the street, in the side streets, round the corners (their radius in m).
const CRUISE := 7.5
const SIDE_STREET := 5.5
const CORNER := 3.6
const CORNER_RADIUS := 5.0
## Speeding up, braking in good time, and braking for what steps out in front (m/s²).
const ACCEL := 2.4
const BRAKE := 3.0
const HARD_BRAKE := 9.0
## Standing: this far from what is in the way (m). Looking this far ahead (m).
const GAP := 1.8
const LOOK := 28.0
## A person counts as in the way within this distance of the car's side (m): on the road, not on
## the kerb.
const PERSON_MARGIN := 0.6
## At most this many cars at once, a new one every so many seconds (from, to).
const MAX_CARS := 4
const SPAWN_EVERY := Vector2(6.0, 15.0)
## The host says where the cars are this often (s); a car further off than SNAP (m) jumps there.
const SYNC_EVERY := 0.25
const SNAP := 5.0
## A car held up by a player this long sounds its horn (s), and again after HONK_AGAIN.
const HONK_AFTER := 3.5
const HONK_AGAIN := 7.0
## The models: file, wheel radius (m) and how often it comes (a share).
const MODELS := [
	[ParkedVehicle.CAR_SMALL, 0.286, 3],
	[ParkedVehicle.CAR_SALOON, 0.303, 3],
	[ParkedVehicle.CAR_ESTATE, 0.303, 2],
	[ParkedVehicle.VAN, 0.394, 1],
]
## Body colours of the cars (the van keeps its own).
const PAINTS: Array[Color] = [Color("#7d8a94"), Color("#22304a"), Color("#8a2f28"), Color("#d6d2c6"), Color("#3f4a3a"),
	Color("#c39a34"), Color("#1c1d20"), Color("#5c7b93"), Color("#6d2f3c")]


class Car:
	var id := 0
	var kind := 0
	var paint := 0
	## Way along the path (m) and speed (m/s).
	var s := 0.0
	var v := 0.0
	## This driver's own pace on the open street (a share of CRUISE).
	var temper := 1.0
	var stood := 0.0
	var honk_in := 0.0
	var roll := 0.0
	## Length, height, width (m).
	var size := Vector3.ZERO
	var radius := 0.3
	var node: Node3D
	var wheels: Array = []
	var loop: AudioStreamPlayer3D


## Art checks: the cars stand where they were put, and no new ones come.
var frozen := false

var _points := PackedVector3Array()
var _along := PackedFloat32Array()
## Where the four corners begin and end along the path (m), and the stretch down the street between
## the second and the third.
var _corners: Array[Vector2] = []
var _cruise := Vector2.ZERO
var _total := 0.0
var _cars: Array[Car] = []
var _next_id := 1
var _spawn_in := 2.0
var _sync_in := 0.0
var _told_empty := false
var _rng := RandomNumberGenerator.new()
var _kinds: Array[int] = []
var _paints: Array[int] = []


func _init() -> void:
	name = "TownTraffic"
	_rng.randomize()


func _ready() -> void:
	add_to_group(GROUP)


## The way the cars take: east along the cross road at z = `north` from `run` metres west of the
## western side street (x = -`far`), round the corner and south down it to the street's lane at
## z = `lane`, east along that to x = `far`, north up the eastern side street, round the corner and
## away along the cross road for `run` metres.
func setup(lane: float, far: float, north: float, run: float) -> void:
	var r := CORNER_RADIUS
	# Each corner is a quarter circle: its middle, and the angles it runs from and to.
	var turns := [
		[Vector3(-far - r, 0, north - r), PI * 0.5, 0.0],
		[Vector3(-far + r, 0, lane + r), PI, PI * 1.5],
		[Vector3(far - r, 0, lane + r), -PI * 0.5, 0.0],
		[Vector3(far + r, 0, north - r), PI, PI * 0.5],
	]
	var points: Array[Vector3] = [Vector3(-far - run, 0, north)]
	var marks: Array[Vector2i] = []
	for turn: Array in turns:
		var mid: Vector3 = turn[0]
		var from: float = turn[1]
		var to: float = turn[2]
		var first := points.size()
		for i in 9:
			var a := lerpf(from, to, i / 8.0)
			points.append(mid + Vector3(r * cos(a), 0, r * sin(a)))
		marks.append(Vector2i(first, points.size() - 1))
	points.append(Vector3(far + run, 0, north))
	_points = PackedVector3Array(points)
	_along.resize(points.size())
	_along[0] = 0.0
	for i in range(1, points.size()):
		_along[i] = _along[i - 1] + points[i - 1].distance_to(points[i])
	_total = _along[points.size() - 1]
	_corners.clear()
	for mark in marks:
		_corners.append(Vector2(_along[mark.x], _along[mark.y]))
	_cruise = Vector2(_corners[1].y, _corners[2].x)


## How many cars are on their way.
func count() -> int:
	return _cars.size()


## Where each car is: [position, way along the path (m), speed (m/s)] (for tests).
func cars() -> Array:
	var out := []
	for car in _cars:
		out.append([_point(car.s), car.s, car.v])
	return out


## Host: sends a car on its way now (for tests and pictures); `at` metres along the path.
func send_car(kind := -1, at := 0.0) -> void:
	if not Network.is_sim_authority() or _points.is_empty():
		return
	# Models and paints are drawn like lots from a bag that is refilled when it is empty: the street
	# never sees the same colour three times running.
	if kind < 0:
		if _kinds.is_empty():
			for i in MODELS.size():
				for n in int(MODELS[i][2]):
					_kinds.append(i)
		kind = _kinds.pop_at(_rng.randi_range(0, _kinds.size() - 1))
	if _paints.is_empty():
		_paints.assign(range(PAINTS.size()))
	var car := _add_car(_next_id, kind, _paints.pop_at(_rng.randi_range(0, _paints.size() - 1)), at, SIDE_STREET)
	car.temper = _rng.randf_range(0.82, 1.08)
	_next_id += 1


func _physics_process(delta: float) -> void:
	if _points.is_empty():
		return
	if frozen:
		for car in _cars:
			_show(car, 0.0)
		return
	if Network.is_sim_authority():
		_spawn_in -= delta
		if _spawn_in <= 0.0:
			_spawn_in = _rng.randf_range(SPAWN_EVERY.x, SPAWN_EVERY.y)
			if _cars.size() < MAX_CARS and _entry_clear() and not _truck_out():
				send_car()
	var people := get_tree().get_nodes_in_group(&"players") + get_tree().get_nodes_in_group(PolicePatrol.GROUP) \
		+ get_tree().get_nodes_in_group(TownWalkers.GROUP)
	var trucks := get_tree().get_nodes_in_group(ScrapTruck.GROUP)
	for car in _cars.duplicate():
		_drive(car, delta, people, trucks)
		if car.s >= _total:
			_remove_car(car)
	if Network.is_online() and multiplayer.is_server():
		_sync_in -= delta
		# (An empty street is told once, not four times a second.)
		if _sync_in <= 0.0 and not (_cars.is_empty() and _told_empty):
			_sync_in = SYNC_EVERY
			_told_empty = _cars.is_empty()
			var data := PackedFloat32Array()
			for car in _cars:
				data.append_array([float(car.id), float(car.kind), float(car.paint), car.s, car.v, car.temper])
			_state.rpc(data)


# --- Driving --------------------------------------------------------------------

func _drive(car: Car, delta: float, people: Array, trucks: Array) -> void:
	var place := _point(car.s)
	var dir := _heading(car.s)
	var nose := car.s + car.size.x * 0.5
	# The speed of this stretch, and down to a corner's speed by the time the nose gets there.
	var want := _limit(car.s) * car.temper
	for corner in _corners:
		if corner.x > nose:
			want = minf(want, sqrt(CORNER * CORNER + 2.0 * BRAKE * (corner.x - nose)))
		elif corner.y > car.s - car.size.x * 0.5:
			want = minf(want, CORNER)
	# What is in the way: the car in front, people on the road, the scrap truck.
	var room := INF
	var by_player := false
	for other in _cars:
		if other != car and other.s > car.s:
			room = minf(room, other.s - other.size.x * 0.5 - nose)
	var right := dir.cross(Vector3.UP)
	for node in people:
		var rel := (node as Node3D).global_position - place
		rel.y = 0.0
		var ahead := rel.dot(dir) - car.size.x * 0.5
		if ahead > -1.0 and ahead < LOOK and absf(rel.dot(right)) < car.size.z * 0.5 + PERSON_MARGIN:
			if maxf(ahead, 0.0) - 0.4 < room:
				room = maxf(ahead, 0.0) - 0.4
				by_player = node is Player
	for node in trucks:
		var truck := node as ScrapTruck
		# (On its way round the block it is not there.)
		if not truck.busy() or not truck.visible:
			continue
		var rel := truck.global_position - place
		rel.y = 0.0
		var ahead := rel.dot(dir) - car.size.x * 0.5 - 3.9
		if ahead > -6.0 and ahead < LOOK and absf(rel.dot(right)) < car.size.z * 0.5 + 2.1:
			if maxf(ahead, 0.0) < room:
				room = maxf(ahead, 0.0)
				by_player = false
	if room < INF:
		want = minf(want, sqrt(maxf(0.0, 2.0 * BRAKE * (room - GAP))))
	car.v = move_toward(car.v, want, (ACCEL if want > car.v else HARD_BRAKE) * delta)
	car.s += car.v * delta
	# Held up by a player: the horn, after a while.
	if car.v < 0.1 and by_player:
		car.stood += delta
		car.honk_in -= delta
		if car.stood > HONK_AFTER and car.honk_in <= 0.0:
			car.honk_in = HONK_AGAIN
			Sfx.play(&"car_horn", place + Vector3(0, 1.0, 0), -3.0, 0.04)
	else:
		car.stood = 0.0
		car.honk_in = 0.0
	_show(car, delta)


## Puts the car's node where the car is, turns its wheels and sets its sound.
func _show(car: Car, delta: float) -> void:
	var dir := _heading(car.s)
	car.node.global_transform = Transform3D(Basis(dir, Vector3.UP, dir.cross(Vector3.UP)), _point(car.s))
	car.roll += car.v * delta / car.radius
	for entry: Array in car.wheels:
		# The wheels' axles lie along their own Z, which points to the car's right.
		(entry[0] as Node3D).transform = (entry[1] as Transform3D) * Transform3D(Basis(Vector3(0, 0, 1), -car.roll), Vector3.ZERO)
	if car.loop:
		var pace := clampf(car.v / CRUISE, 0.0, 1.2)
		car.loop.pitch_scale = 0.72 + 0.5 * pace
		car.loop.volume_db = lerpf(-22.0, -8.0, minf(pace, 1.0))


func _limit(s: float) -> float:
	for corner in _corners:
		if s >= corner.x and s <= corner.y:
			return CORNER
	return CRUISE if s > _cruise.x and s < _cruise.y else SIDE_STREET


## The place `s` metres along the path.
func _point(s: float) -> Vector3:
	s = clampf(s, 0.0, _total)
	for i in range(1, _points.size()):
		if s <= _along[i] or i == _points.size() - 1:
			var seg := _along[i] - _along[i - 1]
			return _points[i - 1].lerp(_points[i], clampf((s - _along[i - 1]) / maxf(seg, 0.001), 0.0, 1.0))
	return _points[_points.size() - 1]


## The way the path runs there (over a car's length, so a corner turns the car smoothly).
func _heading(s: float) -> Vector3:
	var along := _point(minf(s + 1.3, _total)) - _point(maxf(s - 1.3, 0.0))
	along.y = 0.0
	return along.normalized() if along.length() > 0.001 else Vector3.RIGHT


func _entry_clear() -> bool:
	for car in _cars:
		if car.s < 16.0:
			return false
	return true


## The scrap truck is on its trip: it comes back in at the street's western end, so nobody new
## sets off meanwhile.
func _truck_out() -> bool:
	for node in get_tree().get_nodes_in_group(ScrapTruck.GROUP):
		if (node as ScrapTruck).busy():
			return true
	return false


# --- Cars -----------------------------------------------------------------------

func _add_car(id: int, kind: int, paint: int, s: float, v: float) -> Car:
	var car := Car.new()
	car.id = id
	car.kind = clampi(kind, 0, MODELS.size() - 1)
	car.paint = clampi(paint, 0, PAINTS.size() - 1)
	car.s = s
	car.v = v
	var model: String = MODELS[car.kind][0]
	car.radius = MODELS[car.kind][1]
	car.size = ParkedVehicle.BODY[model]
	car.node = Node3D.new()
	car.node.name = "Car%d" % id
	add_child(car.node)
	car.node.add_to_group(CAR_GROUP)
	# Nobody walks through a car.
	var solid := AnimatableBody3D.new()
	solid.sync_to_physics = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = car.size
	shape.shape = box
	shape.position = Vector3(0, car.size.y * 0.5, 0)
	solid.add_child(shape)
	car.node.add_child(solid)
	if EnvMesh.visual():
		var packed := load(model) as PackedScene
		if packed:
			var art := packed.instantiate() as Node3D
			car.node.add_child(art)
			# The finish wants the car standing level as it rests; then it goes to its place.
			ParkedVehicle.dress(art, model, Color(0, 0, 0, 0) if model == ParkedVehicle.VAN else PAINTS[car.paint])
			for wheel in art.find_children("wheel_*", "Node3D", true, false):
				car.wheels.append([wheel, (wheel as Node3D).transform])
		car.loop = Sfx.make_loop(car.node, &"car_loop")
		car.loop.position = Vector3(0.6, 0.6, 0)
		car.loop.volume_db = -22.0
		car.loop.play()
	_cars.append(car)
	_show(car, 0.0)
	car.node.reset_physics_interpolation()
	return car


func _remove_car(car: Car) -> void:
	_cars.erase(car)
	car.node.queue_free()


## From the host: the cars on their way, six numbers each (id, model, paint, way, speed, temper).
@rpc("authority", "call_remote", "unreliable_ordered")
func _state(data: PackedFloat32Array) -> void:
	var listed := {}
	for i in range(0, data.size() - 5, 6):
		var id := int(data[i])
		listed[id] = true
		var car: Car = null
		for known in _cars:
			if known.id == id:
				car = known
		if car == null:
			car = _add_car(id, int(data[i + 1]), int(data[i + 2]), data[i + 3], data[i + 4])
		car.temper = data[i + 5]
		car.v = data[i + 4]
		if absf(car.s - data[i + 3]) > SNAP:
			car.s = data[i + 3]
			_show(car, 0.0)
			car.node.reset_physics_interpolation()
		else:
			car.s = lerpf(car.s, data[i + 3], 0.3)
	for car in _cars.duplicate():
		if not listed.has(car.id):
			_remove_car(car)
