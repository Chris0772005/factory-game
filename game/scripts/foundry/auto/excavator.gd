class_name Excavator
extends Node3D
## The excavator at the heap (model and motion: DiggerRig): swings to the mountain, bites, swings to the
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
var _rig: DiggerRig
var _heap_yaw := 0.0
var _skip_yaw := 0.0
var _sent := false


func _init() -> void:
	name = "Excavator"


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_to_group(GROUP)
	add_to_group(&"interactable")
	StationKit.box_collider(self, Vector3(2.5, 2.5, 3.9), Transform3D(Basis(), Vector3(0, 1.25, 0)))
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
	return global_position + Vector3(0, 2.0, 0)


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


## Key frames of one cycle: time, boom, stick and bucket angle (degrees, as DiggerRig takes them) and
## how far the upper carriage has swung from the heap (0) to the skip (1). Reach into the flank of the
## heap, curl the bucket, lift, swing, tip, swing back.
const KEYS := [
	[0.0, -45.0, 120.0, 70.0, 0.0],
	[0.24, -25.0, 115.0, 20.0, 0.0],
	[0.34, -25.0, 112.0, 120.0, 0.0],
	[0.44, -45.0, 120.0, 125.0, 0.0],
	[0.68, -45.0, 120.0, 125.0, 1.0],
	[0.77, -45.0, 118.0, 15.0, 1.0],
	[0.84, -45.0, 120.0, 40.0, 1.0],
	[1.0, -45.0, 120.0, 70.0, 0.0],
]
## The machine in the hall is a size smaller than the 20 t original.
const MODEL_SCALE := 0.85


## Pose for cycle position `p` 0..1.
func _pose(p: float) -> void:
	if _rig == null:
		return
	var i := 0
	while i < KEYS.size() - 2 and p > float(KEYS[i + 1][0]):
		i += 1
	var a: Array = KEYS[i]
	var b: Array = KEYS[i + 1]
	var k := smoothstep(0.0, 1.0, clampf((p - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.001), 0.0, 1.0))
	var swing := lerp_angle(_heap_yaw, _skip_yaw, lerpf(a[4], b[4], k))
	_rig.set_pose(swing, lerpf(a[1], b[1], k), lerpf(a[2], b[2], k), lerpf(a[3], b[3], k))


func _build_art() -> void:
	if not StationKit.visual():
		return
	_rig = DiggerRig.new()
	_rig.scale = Vector3.ONE * MODEL_SCALE
	add_child(_rig)
	_pose(0.0)
