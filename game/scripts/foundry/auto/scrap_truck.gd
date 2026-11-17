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
	box.size = Vector3(2.5, 3.2, 7.4)
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


## Faces +Z. A three-axle tipper as on a building site (Construction
## Simulator's Scania-style tipper was the model): tall cab-over cab with a
## raked windscreen, dark bumper with the headlights in it, amber tipper body
## with ribs and a cab guard, round tyres on steel rims, fuel tank, exhaust
## stack, tail lights and mud flaps.
func _build_art() -> void:
	if not StationKit.visual():
		return
	var paint := StationKit.metal("truck_cab", {steel_color = Color("#1f3a63"), paint = 1.0, paint_color = Color("#2b5ea6"), rust = 0.03,
		metallic_steel = 0.35, roughness_steel = 0.42, roughness_paint = 0.38, grime = 0.06, dust = 0.18, dents = 0.04, edge_wear = 0.15})
	var amber := StationKit.metal("truck_body", {steel_color = Color("#7a5a22"), paint = 0.93, paint_color = Color("#d8911b"), rust = 0.3,
		dents = 0.3, metallic_steel = 0.4, roughness_steel = 0.55, grime = 0.16, dust = 0.3})
	var dark := StationKit.metal("truck_dark", {steel_color = Color("#24272b"), rust = 0.2, metallic_steel = 0.45, roughness_steel = 0.6})
	var alu := StationKit.metal("truck_rim", {steel_color = Color("#9aa0a5"), rust = 0.1, metallic_steel = 0.8, roughness_steel = 0.4})
	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color("#151617")
	rubber.roughness = 0.92
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color("#141d24")
	glass.metallic = 0.5
	glass.roughness = 0.06
	# --- Cab: side silhouette extruded across the width.
	var cab := []
	cab.append(EnvMesh.piece(_prism(PackedVector2Array([Vector2(1.5, 0.95), Vector2(3.6, 0.95), Vector2(3.6, 2.05), Vector2(3.42, 3.05),
		Vector2(3.28, 3.15), Vector2(1.5, 3.15)]), 2.45), Transform3D()))
	# Corner deflectors and the wheel-arch flare.
	for s: float in [-1.0, 1.0]:
		cab.append(EnvMesh.piece(EnvMesh.box(Vector3(0.1, 1.05, 0.12), 0.03), Transform3D(Basis(), Vector3(s * 1.2, 1.5, 3.58))))
		cab.append(EnvMesh.piece(EnvMesh.box(Vector3(0.14, 0.1, 1.35), 0.03), Transform3D(Basis(), Vector3(s * 1.24, 1.16, 2.75))))
	StationKit.add_merged(self, cab, paint)
	var panes := []
	panes.append(EnvMesh.piece(EnvMesh.box(Vector3(2.2, 0.9, 0.03)), Transform3D(Basis(Vector3.RIGHT, -0.178), Vector3(0, 2.55, 3.535))))
	for s: float in [-1.0, 1.0]:
		panes.append(EnvMesh.piece(EnvMesh.box(Vector3(0.03, 0.72, 1.15)), Transform3D(Basis(), Vector3(s * 1.228, 2.58, 2.72))))
	panes.append(EnvMesh.piece(EnvMesh.box(Vector3(1.5, 0.5, 0.03)), Transform3D(Basis(), Vector3(0, 2.6, 1.49))))
	StationKit.add_merged(self, panes, glass, false)
	# Dark trim: bumper, grille, sun visor, door seams and handles, steps, mirrors.
	var trim := []
	trim.append(EnvMesh.piece(EnvMesh.box(Vector3(2.52, 0.55, 0.45), 0.06), Transform3D(Basis(), Vector3(0, 0.82, 3.5))))
	trim.append(EnvMesh.piece(EnvMesh.box(Vector3(1.7, 0.62, 0.05)), Transform3D(Basis(), Vector3(0, 1.62, 3.605))))
	trim.append(EnvMesh.piece(EnvMesh.box(Vector3(2.3, 0.06, 0.34)), Transform3D(Basis(Vector3.RIGHT, 0.1), Vector3(0, 3.12, 3.5))))
	for s: float in [-1.0, 1.0]:
		for z: float in [1.95, 3.32]:
			trim.append(EnvMesh.piece(EnvMesh.box(Vector3(0.02, 1.85, 0.025)), Transform3D(Basis(), Vector3(s * 1.232, 2.05, z))))
		trim.append(EnvMesh.piece(EnvMesh.box(Vector3(0.03, 0.05, 0.2)), Transform3D(Basis(), Vector3(s * 1.24, 2.02, 2.1))))
		trim.append(EnvMesh.piece(EnvMesh.box(Vector3(0.3, 0.05, 0.42)), Transform3D(Basis(), Vector3(s * 1.12, 0.78, 1.95))))
		trim.append(EnvMesh.piece(EnvMesh.box(Vector3(0.3, 0.05, 0.42)), Transform3D(Basis(), Vector3(s * 1.16, 0.45, 1.95))))
		trim.append(EnvMesh.piece(EnvMesh.box(Vector3(0.3, 0.035, 0.035)), Transform3D(Basis(), Vector3(s * 1.38, 2.95, 3.3))))
		trim.append(EnvMesh.piece(EnvMesh.box(Vector3(0.07, 0.5, 0.24), 0.02), Transform3D(Basis(), Vector3(s * 1.52, 2.68, 3.3))))
	StationKit.add_merged(self, trim, dark)
	var chrome := []
	for i in 5:
		chrome.append(EnvMesh.piece(EnvMesh.box(Vector3(1.6, 0.035, 0.03)), Transform3D(Basis(), Vector3(0, 1.4 + i * 0.11, 3.635))))
	chrome.append(EnvMesh.piece(EnvMesh.box(Vector3(0.52, 0.13, 0.02)), Transform3D(Basis(), Vector3(0, 0.78, 3.735))))
	# --- Chassis: frame rails, cross members, fuel tank, exhaust, rear bar.
	var frame := []
	for s: float in [-1.0, 1.0]:
		frame.append(EnvMesh.piece(EnvMesh.box(Vector3(0.12, 0.3, 7.2)), Transform3D(Basis(), Vector3(s * 0.45, 0.88, -0.1))))
		frame.append(EnvMesh.piece(EnvMesh.box(Vector3(0.62, 0.05, 2.75)), Transform3D(Basis(), Vector3(s * 1.0, 1.16, -2.17))))
		frame.append(EnvMesh.piece(EnvMesh.box(Vector3(0.62, 0.05, 0.4)), Transform3D(Basis(Vector3.RIGHT, 0.6), Vector3(s * 1.0, 1.06, -0.66))))
		frame.append(EnvMesh.piece(EnvMesh.box(Vector3(0.56, 0.5, 0.03)), Transform3D(Basis(), Vector3(s * 1.0, 0.55, -3.58))))
	for z: float in [2.75, -1.5, -2.85]:
		frame.append(EnvMesh.piece(EnvMesh.cylinder(0.09, 0.09, 2.0, 10), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, 0.54, z))))
	for z: float in [1.2, -0.3, -3.5]:
		frame.append(EnvMesh.piece(EnvMesh.box(Vector3(1.0, 0.2, 0.12)), Transform3D(Basis(), Vector3(0, 0.88, z))))
	frame.append(EnvMesh.piece(EnvMesh.box(Vector3(2.4, 0.16, 0.12)), Transform3D(Basis(), Vector3(0, 0.92, -3.72))))
	frame.append(EnvMesh.piece(EnvMesh.box(Vector3(2.3, 0.1, 0.1)), Transform3D(Basis(), Vector3(0, 0.5, -3.7))))
	frame.append(EnvMesh.piece(EnvMesh.box(Vector3(0.5, 0.42, 0.6), 0.03), Transform3D(Basis(), Vector3(-1.0, 0.72, 0.55))))
	frame.append(EnvMesh.piece(EnvMesh.box(Vector3(0.2, 1.1, 0.22), 0.03), Transform3D(Basis(), Vector3(1.0, 1.75, 1.37))))
	StationKit.add_merged(self, frame, dark)
	chrome.append(EnvMesh.piece(EnvMesh.cylinder(0.3, 0.3, 1.25, 20), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(1.0, 0.74, 0.35))))
	chrome.append(EnvMesh.piece(EnvMesh.cylinder(0.06, 0.06, 1.5, 12), Transform3D(Basis(), Vector3(1.0, 2.85, 1.37))))
	# --- Wheels: front singles, rear twins.
	var tyres := []
	var rims := []
	for axle: Array in [[2.75, 0.34, 1.05], [-1.5, 0.6, 0.93], [-2.85, 0.6, 0.93]]:
		var w: float = axle[1] * 0.5
		var tyre := StationKit.lathe(PackedVector2Array([Vector2(0.3, -w), Vector2(0.46, -w), Vector2(0.52, -w * 0.78), Vector2(0.545, -w * 0.4),
			Vector2(0.545, w * 0.4), Vector2(0.52, w * 0.78), Vector2(0.46, w), Vector2(0.3, w)]), 28, 30.0)
		for s: float in [-1.0, 1.0]:
			var at := Vector3(s * float(axle[2]), 0.545, float(axle[0]))
			var turn := Basis(Vector3.BACK, PI * 0.5 * s)
			tyres.append(EnvMesh.piece(tyre, Transform3D(turn, at)))
			rims.append(EnvMesh.piece(EnvMesh.cylinder(0.31, 0.31, axle[1] * 0.86, 20), Transform3D(turn, at)))
			rims.append(EnvMesh.piece(EnvMesh.cylinder(0.12, 0.16, 0.14, 12), Transform3D(turn, at + Vector3(s * (w + 0.02), 0, 0))))
			for k in 8:
				var ang := k * TAU / 8.0
				rims.append(EnvMesh.piece(EnvMesh.cylinder(0.02, 0.02, 0.05, 6), Transform3D(turn, at + Vector3(s * (w - 0.03), sin(ang) * 0.22, cos(ang) * 0.22))))
	StationKit.add_merged(self, tyres, rubber)
	StationKit.add_merged(self, rims + chrome, alu)
	# --- Tipper body with ribs, top rail, tailgate and the guard over the cab.
	var body := []
	body.append(EnvMesh.piece(EnvMesh.box(Vector3(2.5, 0.1, 4.95)), Transform3D(Basis(), Vector3(0, 1.3, -1.22))))
	body.append(EnvMesh.piece(EnvMesh.box(Vector3(2.5, 1.95, 0.1)), Transform3D(Basis(), Vector3(0, 2.27, 1.2))))
	body.append(EnvMesh.piece(EnvMesh.box(Vector3(2.5, 0.08, 0.95)), Transform3D(Basis(), Vector3(0, 3.26, 1.62))))
	body.append(EnvMesh.piece(EnvMesh.box(Vector3(2.5, 1.3, 0.08)), Transform3D(Basis(), Vector3(0, 1.98, -3.68))))
	for s: float in [-1.0, 1.0]:
		body.append(EnvMesh.piece(EnvMesh.box(Vector3(0.08, 1.3, 4.95)), Transform3D(Basis(), Vector3(s * 1.21, 1.98, -1.22))))
		body.append(EnvMesh.piece(EnvMesh.box(Vector3(0.16, 0.1, 5.0), 0.02), Transform3D(Basis(), Vector3(s * 1.23, 2.66, -1.22))))
		body.append(EnvMesh.piece(EnvMesh.box(Vector3(0.14, 0.12, 4.95)), Transform3D(Basis(), Vector3(s * 1.24, 1.32, -1.22))))
		for i in 6:
			body.append(EnvMesh.piece(EnvMesh.box(Vector3(0.07, 1.26, 0.14)), Transform3D(Basis(), Vector3(s * 1.28, 1.98, -3.5 + i * 0.86))))
		body.append(EnvMesh.piece(EnvMesh.box(Vector3(0.08, 0.7, 0.1)), Transform3D(Basis(Vector3.RIGHT, -0.9), Vector3(s * 1.21, 2.95, 1.5))))
		body.append(EnvMesh.piece(EnvMesh.box(Vector3(0.1, 0.16, 0.16)), Transform3D(Basis(), Vector3(s * 1.12, 2.7, -3.7))))
	for x: float in [-0.6, 0.0, 0.6]:
		body.append(EnvMesh.piece(EnvMesh.box(Vector3(0.1, 1.24, 0.06)), Transform3D(Basis(), Vector3(x, 1.98, -3.74))))
	StationKit.add_merged(self, body, amber)
	# --- Lights.
	var white := StandardMaterial3D.new()
	white.albedo_color = Color("#f4eedc")
	white.emission_enabled = true
	white.emission = Color("#fff3d0")
	white.emission_energy_multiplier = 1.4
	var heads := []
	for s: float in [-1.0, 1.0]:
		heads.append(EnvMesh.piece(EnvMesh.box(Vector3(0.44, 0.2, 0.04), 0.02), Transform3D(Basis(), Vector3(s * 0.9, 0.9, 3.735))))
		heads.append(EnvMesh.piece(EnvMesh.box(Vector3(0.16, 0.09, 0.04)), Transform3D(Basis(), Vector3(s * 0.45, 0.64, 3.735))))
	StationKit.add_merged(self, heads, white, false)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color("#a8201a")
	red.emission_enabled = true
	red.emission = Color("#ff3020")
	red.emission_energy_multiplier = 0.8
	var tails := []
	for s: float in [-1.0, 1.0]:
		tails.append(EnvMesh.piece(EnvMesh.box(Vector3(0.36, 0.12, 0.03)), Transform3D(Basis(), Vector3(s * 0.95, 0.92, -3.79))))
	StationKit.add_merged(self, tails, red, false)
	var orange := StandardMaterial3D.new()
	orange.albedo_color = Color("#e8871a")
	orange.emission_enabled = true
	orange.emission = Color("#ff9a20")
	orange.emission_energy_multiplier = 1.0
	var beacons := []
	for s: float in [-1.0, 1.0]:
		beacons.append(EnvMesh.piece(EnvMesh.cylinder(0.07, 0.08, 0.14, 12), Transform3D(Basis(), Vector3(s * 0.75, 3.22, 2.4))))
		beacons.append(EnvMesh.piece(EnvMesh.box(Vector3(0.1, 0.09, 0.04)), Transform3D(Basis(), Vector3(s * 1.15, 0.9, 3.72))))
	StationKit.add_merged(self, beacons, orange, false)
	_load_mesh = MeshInstance3D.new()
	_load_mesh.mesh = EnvMesh.box(Vector3(2.2, 0.75, 4.5), 0.28, 2)
	_load_mesh.material_override = StationKit.metal("skip_load", {steel_color = Color("#6f6a66"), rust = 0.75, dents = 1.0, metallic_steel = 0.6, roughness_steel = 0.65})
	_load_mesh.position = Vector3(0, 2.4, -1.25)
	_load_mesh.visible = false
	add_child(_load_mesh)


## A convex side silhouette (points as (z, y)) extruded across `width` (x), flat shaded.
static func _prism(profile: PackedVector2Array, width: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hx := width * 0.5
	var centre := Vector3.ZERO
	for p in profile:
		centre += Vector3(0, p.y, p.x)
	centre /= profile.size()
	var tris: Array = []
	for i in range(1, profile.size() - 1):
		for s: float in [-1.0, 1.0]:
			tris.append([Vector3(s * hx, profile[0].y, profile[0].x), Vector3(s * hx, profile[i].y, profile[i].x), Vector3(s * hx, profile[i + 1].y, profile[i + 1].x)])
	for i in profile.size():
		var a := profile[i]
		var b := profile[(i + 1) % profile.size()]
		var a0 := Vector3(-hx, a.y, a.x)
		var a1 := Vector3(hx, a.y, a.x)
		var b0 := Vector3(-hx, b.y, b.x)
		var b1 := Vector3(hx, b.y, b.x)
		tris.append([a0, a1, b1])
		tris.append([a0, b1, b0])
	for t: Array in tris:
		var a: Vector3 = t[0]
		var b: Vector3 = t[1]
		var c: Vector3 = t[2]
		# Godot's front faces wind clockwise: the normal is (c - a) x (b - a).
		var n := (c - a).cross(b - a).normalized()
		if n.dot((a + b + c) / 3.0 - centre) < 0.0:
			var swap := b
			b = c
			c = swap
			n = -n
		for v: Vector3 in [a, b, c]:
			st.set_normal(n)
			st.set_uv(Vector2(v.z, v.y))
			st.add_vertex(v)
	return st.commit()
