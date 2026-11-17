class_name Excavator
extends Node3D
## The excavator at the heap: swings to the mountain, bites, swings to the
## skip, dumps. Three pieces a scoop (bulk: scrap and junk, never hot goods).
## Stops while the skip is full or the heap is empty. The upgrade
## `excavator_fast` shortens the cycle. Host takes and loads; every peer
## plays the same cycle from the mirrored `working` flag.

const GROUP := &"excavators"
const SCOOP := 3
const CYCLE := 8.0
const CYCLE_FAST := 5.0

var heap: ScrapPile
var skip: ScrapSkip
var working := false
var phase := 0.0
var _carry: Array = []
var _upper: Node3D
var _boom: Node3D
var _stick: Node3D
var _bucket: Node3D
var _heap_yaw := 0.0
var _skip_yaw := 0.0
var _sent := false


func _init() -> void:
	name = "Excavator"


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_to_group(GROUP)
	add_to_group(&"interactable")
	StationKit.box_collider(self, Vector3(2.4, 1.6, 3.0), Transform3D(Basis(), Vector3(0, 0.8, 0)))
	_build_art()
	if heap:
		var to := to_local(heap._heap_centre())
		_heap_yaw = atan2(to.x, to.z)
	if skip:
		var to_skip := to_local(skip.global_position)
		_skip_yaw = atan2(to_skip.x, to_skip.z)


func cycle() -> float:
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	return CYCLE_FAST if world and world.has_upgrade(&"excavator_fast") else CYCLE


func interact_point() -> Vector3:
	return global_position + Vector3(0, 1.7, 0)


func hint(_player: Node) -> String:
	if skip and skip.is_full():
		return "Bagger wartet – die Mulde ist voll"
	if heap and heap.stock <= 0:
		return "Bagger wartet auf die nächste Ladung Schrott"
	return "Bagger lädt %d Teile je Schaufel in die Mulde" % SCOOP


func interact(_player: Node) -> void:
	pass


func _physics_process(delta: float) -> void:
	if Network.is_sim_authority():
		var can := heap != null and skip != null and (not _carry.is_empty() or (heap.stock > 0 and skip.room() >= SCOOP))
		if can != working and phase == 0.0:
			working = can
			if Network.is_online():
				_sync.rpc(working)
	if not working and phase == 0.0:
		_pose(0.0)
		return
	var before := phase
	phase += delta / cycle()
	if Network.is_sim_authority():
		# Bite at 30 % of the cycle, dump at 75 %.
		if before < 0.3 and phase >= 0.3 and heap:
			_carry = heap.take_bulk(SCOOP)
		if before < 0.75 and phase >= 0.75 and skip and not _carry.is_empty():
			skip.add(_carry)
			Missions.report(get_tree(), &"digger_grab", 1)
			_carry = []
	if phase >= 1.0:
		phase = 0.0
	_pose(phase)


@rpc("authority", "call_remote", "reliable")
func _sync(w: bool) -> void:
	working = w


## Arm pose for cycle position `p` 0..1: reach into the heap, lift, swing, dump, swing back.
func _pose(p: float) -> void:
	if _upper == null:
		return
	var swing := smoothstep(0.38, 0.68, p) - smoothstep(0.82, 1.0, p)
	_upper.rotation.y = lerp_angle(_heap_yaw, _skip_yaw, swing)
	var reach := smoothstep(0.0, 0.26, p) - smoothstep(0.3, 0.42, p)
	var dump := smoothstep(0.68, 0.76, p) - smoothstep(0.8, 0.9, p)
	_boom.rotation.x = lerpf(-0.75, -0.28, reach)
	_stick.rotation.x = lerpf(1.75, 1.05, reach)
	_bucket.rotation.x = lerpf(0.5, 1.3, reach) - dump * 1.6


func _build_art() -> void:
	if not StationKit.visual():
		return
	var yellow := MachineArt.yellow_mat()
	var dark := StationKit.metal("digger_dark", {steel_color = Color("#2b2e31"), rust = 0.25, metallic_steel = 0.5, roughness_steel = 0.6})
	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color("#191a1c")
	rubber.roughness = 0.95
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.5, 0.62, 0.68, 0.45)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.1
	# Undercarriage: two crawler tracks and the turntable.
	var tracks := []
	for s: float in [-1.0, 1.0]:
		tracks.append(EnvMesh.piece(EnvMesh.box(Vector3(0.5, 0.55, 3.0), 0.2, 3), Transform3D(Basis(), Vector3(s * 0.95, 0.3, 0))))
	StationKit.add_merged(self, tracks, rubber)
	var base := []
	base.append(EnvMesh.piece(EnvMesh.box(Vector3(1.5, 0.3, 1.9), 0.05), Transform3D(Basis(), Vector3(0, 0.45, 0))))
	base.append(EnvMesh.piece(EnvMesh.cylinder(0.62, 0.62, 0.22, 24), Transform3D(Basis(), Vector3(0, 0.7, 0))))
	for s: float in [-1.0, 1.0]:
		for z: float in [-1.15, 0.0, 1.15]:
			base.append(EnvMesh.piece(EnvMesh.cylinder(0.24, 0.24, 0.56, 14), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(s * 0.95, 0.3, z))))
	StationKit.add_merged(self, base, dark)
	# Upper carriage (turns): engine deck, cab, counterweight.
	_upper = Node3D.new()
	_upper.position.y = 0.82
	add_child(_upper)
	var body := []
	body.append(EnvMesh.piece(EnvMesh.box(Vector3(2.1, 0.25, 2.5), 0.06), Transform3D(Basis(), Vector3(0, 0.12, -0.35))))
	body.append(EnvMesh.piece(EnvMesh.box(Vector3(1.1, 0.75, 1.5), 0.1), Transform3D(Basis(), Vector3(0.45, 0.62, -0.75))))
	body.append(EnvMesh.piece(EnvMesh.box(Vector3(2.0, 0.6, 0.5), 0.16), Transform3D(Basis(), Vector3(0, 0.5, -1.5))))
	body.append(EnvMesh.piece(EnvMesh.box(Vector3(0.82, 0.12, 1.25), 0.03), Transform3D(Basis(), Vector3(-0.58, 1.72, 0.05))))
	for x: float in [-0.97, -0.19]:
		for z: float in [-0.52, 0.62]:
			body.append(EnvMesh.piece(EnvMesh.box(Vector3(0.07, 1.45, 0.07)), Transform3D(Basis(), Vector3(x, 0.97, z + 0.0))))
	body.append(EnvMesh.piece(EnvMesh.box(Vector3(0.82, 0.5, 1.2), 0.03), Transform3D(Basis(), Vector3(-0.58, 0.5, 0.05))))
	StationKit.add_merged(_upper, body, yellow)
	StationKit.add(_upper, EnvMesh.box(Vector3(0.74, 0.9, 1.12), 0.0), glass, Transform3D(Basis(), Vector3(-0.58, 1.2, 0.05)), false)
	var stack := []
	stack.append(EnvMesh.piece(EnvMesh.cylinder(0.05, 0.05, 0.6, 10), Transform3D(Basis(), Vector3(0.75, 1.25, -1.1))))
	stack.append(EnvMesh.piece(EnvMesh.box(Vector3(0.9, 0.06, 1.2)), Transform3D(Basis(), Vector3(0.45, 1.02, -0.75))))
	StationKit.add_merged(_upper, stack, dark)
	# Boom, stick and bucket, each on its own joint.
	_boom = Node3D.new()
	_boom.position = Vector3(0.2, 0.55, 0.75)
	_upper.add_child(_boom)
	StationKit.add(_boom, EnvMesh.box(Vector3(0.34, 0.42, 3.3), 0.08), yellow, Transform3D(Basis(), Vector3(0, 0, 1.65)))
	StationKit.add(_boom, EnvMesh.cylinder(0.07, 0.07, 1.6, 10), dark, Transform3D(Basis(Vector3.RIGHT, PI * 0.5 - 0.18), Vector3(0, -0.32, 1.0)))
	_stick = Node3D.new()
	_stick.position = Vector3(0, 0, 3.25)
	_boom.add_child(_stick)
	StationKit.add(_stick, EnvMesh.box(Vector3(0.26, 0.3, 2.1), 0.06), yellow, Transform3D(Basis(), Vector3(0, 0, 1.05)))
	StationKit.add(_stick, EnvMesh.cylinder(0.06, 0.06, 1.3, 10), dark, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.26, 0.6)))
	_bucket = Node3D.new()
	_bucket.position = Vector3(0, 0, 2.05)
	_stick.add_child(_bucket)
	var scoop := []
	scoop.append(EnvMesh.piece(EnvMesh.box(Vector3(0.9, 0.06, 0.75)), Transform3D(Basis(), Vector3(0, -0.02, 0.36))))
	scoop.append(EnvMesh.piece(EnvMesh.box(Vector3(0.9, 0.55, 0.06)), Transform3D(Basis(Vector3.RIGHT, -0.3), Vector3(0, 0.26, 0.02))))
	for s: float in [-1.0, 1.0]:
		scoop.append(EnvMesh.piece(EnvMesh.box(Vector3(0.05, 0.5, 0.72)), Transform3D(Basis(), Vector3(s * 0.45, 0.22, 0.36))))
	for i in 4:
		scoop.append(EnvMesh.piece(EnvMesh.box(Vector3(0.1, 0.05, 0.2)), Transform3D(Basis(), Vector3(-0.33 + i * 0.22, -0.02, 0.8))))
	StationKit.add_merged(_bucket, scoop, dark)
	_pose(0.0)
