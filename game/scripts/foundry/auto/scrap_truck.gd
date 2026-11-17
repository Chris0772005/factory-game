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
var _paid := false


func _init() -> void:
	name = "ScrapTruck"


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_to_group(GROUP)
	global_position = park
	rotation.y = PI * 0.5
	_build_art()
	# People do not walk through a truck.
	var solid := AnimatableBody3D.new()
	solid.sync_to_physics = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.4, 2.6, 7.0)
	shape.shape = box
	shape.position = Vector3(0, 1.4, 0)
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


## Faces +Z. Cab in front, open tipper body behind, six wheels.
func _build_art() -> void:
	if not StationKit.visual():
		return
	var paint := StationKit.metal("truck_cab", {steel_color = Color("#5a2a20"), paint = 1.0, paint_color = Color("#a8432a"), rust = 0.04,
		metallic_steel = 0.35, roughness_steel = 0.5})
	var dark := StationKit.metal("truck_dark", {steel_color = Color("#2a2c2f"), rust = 0.3, metallic_steel = 0.5, roughness_steel = 0.6})
	var body := StationKit.metal("truck_body", {steel_color = Color("#50565a"), paint = 0.85, paint_color = Color("#4b5358"), rust = 0.45,
		dents = 0.5, metallic_steel = 0.5})
	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color("#161718")
	rubber.roughness = 0.95
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.45, 0.58, 0.66, 0.5)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.1
	var cab := []
	cab.append(EnvMesh.piece(EnvMesh.box(Vector3(2.3, 1.2, 1.7), 0.05), Transform3D(Basis(), Vector3(0, 1.45, 2.55))))
	cab.append(EnvMesh.piece(EnvMesh.box(Vector3(2.3, 0.9, 1.6), 0.07), Transform3D(Basis(), Vector3(0, 2.45, 2.5))))
	# Mudguards over the front wheels.
	for s: float in [-1.0, 1.0]:
		cab.append(EnvMesh.piece(EnvMesh.box(Vector3(0.5, 0.1, 1.3), 0.03), Transform3D(Basis(), Vector3(s * 1.0, 1.08, 2.6))))
	StationKit.add_merged(self, cab, paint)
	# Dark glass: windscreen and side windows.
	var panes := []
	panes.append(EnvMesh.piece(EnvMesh.box(Vector3(2.0, 0.62, 0.05)), Transform3D(Basis(), Vector3(0, 2.5, 3.29))))
	for s: float in [-1.0, 1.0]:
		panes.append(EnvMesh.piece(EnvMesh.box(Vector3(0.05, 0.56, 1.0)), Transform3D(Basis(), Vector3(s * 1.14, 2.5, 2.6))))
	glass.albedo_color = Color("#17232b")
	glass.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	glass.metallic = 0.4
	glass.roughness = 0.08
	StationKit.add_merged(self, panes, glass, false)
	# Grille, mirrors, exhaust stack.
	var trim := []
	trim.append(EnvMesh.piece(EnvMesh.box(Vector3(1.5, 0.5, 0.06)), Transform3D(Basis(), Vector3(0, 1.4, 3.41))))
	for i in 5:
		trim.append(EnvMesh.piece(EnvMesh.box(Vector3(1.56, 0.03, 0.09)), Transform3D(Basis(), Vector3(0, 1.2 + i * 0.1, 3.42))))
	for s: float in [-1.0, 1.0]:
		trim.append(EnvMesh.piece(EnvMesh.box(Vector3(0.06, 0.4, 0.2)), Transform3D(Basis(), Vector3(s * 1.36, 2.45, 3.1))))
		trim.append(EnvMesh.piece(EnvMesh.box(Vector3(0.24, 0.04, 0.04)), Transform3D(Basis(), Vector3(s * 1.25, 2.6, 3.1))))
	trim.append(EnvMesh.piece(EnvMesh.cylinder(0.07, 0.07, 1.9, 12), Transform3D(Basis(), Vector3(1.0, 2.2, 1.55))))
	StationKit.add_merged(self, trim, dark)
	var lights := StandardMaterial3D.new()
	lights.albedo_color = Color("#f2ecd8")
	lights.emission_enabled = true
	lights.emission = Color("#fff1c9")
	lights.emission_energy_multiplier = 1.2
	var lamps := []
	for s: float in [-1.0, 1.0]:
		lamps.append(EnvMesh.piece(EnvMesh.box(Vector3(0.3, 0.18, 0.05), 0.02), Transform3D(Basis(), Vector3(s * 0.92, 1.0, 3.42))))
	StationKit.add_merged(self, lamps, lights, false)
	var frame := []
	frame.append(EnvMesh.piece(EnvMesh.box(Vector3(1.1, 0.28, 7.0)), Transform3D(Basis(), Vector3(0, 0.78, 0.1))))
	frame.append(EnvMesh.piece(EnvMesh.box(Vector3(2.35, 0.3, 0.22), 0.05), Transform3D(Basis(), Vector3(0, 0.72, 3.5))))
	frame.append(EnvMesh.piece(EnvMesh.box(Vector3(0.5, 0.4, 0.9), 0.08), Transform3D(Basis(), Vector3(-0.95, 0.8, 1.2))))
	for z: float in [2.6, -1.0, -2.3]:
		frame.append(EnvMesh.piece(EnvMesh.cylinder(0.08, 0.08, 2.2, 10), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, 0.5, z))))
	StationKit.add_merged(self, frame, dark)
	var wheels := []
	for z: float in [2.6, -1.0, -2.3]:
		for s: float in [-1.0, 1.0]:
			wheels.append(EnvMesh.piece(EnvMesh.cylinder(0.5, 0.5, 0.42, 20), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(s * 1.02, 0.5, z))))
	StationKit.add_merged(self, wheels, rubber)
	var hubs := []
	for z: float in [2.6, -1.0, -2.3]:
		for s: float in [-1.0, 1.0]:
			hubs.append(EnvMesh.piece(EnvMesh.cylinder(0.26, 0.26, 0.46, 16), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(s * 1.02, 0.5, z))))
			hubs.append(EnvMesh.piece(EnvMesh.cylinder(0.1, 0.1, 0.52, 10), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(s * 1.02, 0.5, z))))
	var rim := StationKit.metal("truck_rim", {steel_color = Color("#8a8f93"), rust = 0.2, metallic_steel = 0.7, roughness_steel = 0.45})
	StationKit.add_merged(self, hubs, rim)
	var tipper := []
	tipper.append(EnvMesh.piece(EnvMesh.box(Vector3(2.4, 0.1, 4.6)), Transform3D(Basis(), Vector3(0, 1.0, -1.2))))
	for s: float in [-1.0, 1.0]:
		tipper.append(EnvMesh.piece(EnvMesh.box(Vector3(0.09, 1.15, 4.6)), Transform3D(Basis(), Vector3(s * 1.16, 1.58, -1.2))))
		for z: float in [-3.0, -1.2, 0.6]:
			tipper.append(EnvMesh.piece(EnvMesh.box(Vector3(0.07, 1.1, 0.12)), Transform3D(Basis(), Vector3(s * 1.23, 1.58, z))))
	tipper.append(EnvMesh.piece(EnvMesh.box(Vector3(2.4, 1.4, 0.1)), Transform3D(Basis(), Vector3(0, 1.7, 1.08))))
	tipper.append(EnvMesh.piece(EnvMesh.box(Vector3(2.4, 1.15, 0.09)), Transform3D(Basis(), Vector3(0, 1.58, -3.48))))
	StationKit.add_merged(self, tipper, body)
	_load_mesh = MeshInstance3D.new()
	_load_mesh.mesh = EnvMesh.box(Vector3(2.1, 0.7, 4.2), 0.25, 2)
	_load_mesh.material_override = StationKit.metal("skip_load", {steel_color = Color("#6f6a66"), rust = 0.75, dents = 1.0, metallic_steel = 0.6, roughness_steel = 0.65})
	_load_mesh.position = Vector3(0, 1.75, -1.2)
	_load_mesh.visible = false
	add_child(_load_mesh)
	# People do not walk through a truck.
