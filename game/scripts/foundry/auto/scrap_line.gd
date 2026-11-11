class_name ScrapLine
extends Node3D
## The first step from hand work to a hall that runs itself: a conveyor from
## the scrap heap up to the furnace mouth (upgrade "conveyor") and a robot
## grab arm at the heap that digs and loads it (upgrade "robot_arm").
##   Belt only: workers drop scrap into the hopper, it rides into the furnace.
##   Belt + arm: the arm takes a find from the heap every few seconds.
## Belt pieces are data with a small mesh each, not physics bodies. Host
## simulates; peers get "piece added" and "arm cycle" events and animate the
## same motion.

const BELT_SPEED := 0.75
const BELT_WIDTH := 0.52
const START_HEIGHT := 0.72
const END_HEIGHT := 1.18
const HOPPER := Vector3(0.7, 0.5, 0.7)
const ARM_CYCLE := 3.4
const UPPER := 1.05
const FORE := 1.0
const SHOULDER_HEIGHT := 0.82

var pile: ScrapPile
var furnace: Furnace
## Pieces on the belt: [kind or mix, metres along, mesh node].
var pieces: Array = []
var length := 1.0

var _start := Vector3.ZERO
var _dir := Vector3.RIGHT
var _slope := 0.0
var _belt: Node3D
var _belt_mat: ShaderMaterial
var _offset := 0.0
var _colliders: Array[CollisionShape3D] = []
var _arm_base := Vector3.ZERO
var _arm: Node3D
var _turret: Node3D
var _shoulder: Node3D
var _elbow: Node3D
var _fingers: Array[Node3D] = []
var _held_mesh: MeshInstance3D
var _lamp_mat: StandardMaterial3D
var _cycle := 0.0
var _cycle_kind := &""
var _has_grabbed := false
var _hum: AudioStreamPlayer3D


## Builds the line between the hall's heap and its nearest furnace (null if
## the hall has no such pair).
static func build_for(world: Node3D) -> ScrapLine:
	var heap := world.get_tree().get_first_node_in_group(&"scrap_piles") as ScrapPile
	if heap == null:
		return null
	var best: Furnace = null
	for f in world.get_tree().get_nodes_in_group(&"furnaces"):
		if f is Furnace and (best == null or (f as Node3D).global_position.distance_to(heap.global_position) < best.global_position.distance_to(heap.global_position)):
			best = f
	if best == null:
		return null
	var line := ScrapLine.new()
	line.name = "ScrapLine"
	line.pile = heap
	line.furnace = best
	world.add_child(line)
	return line


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_to_group(&"scrap_lines")
	var a := pile.global_position
	var b := furnace.global_position
	_dir = Vector3(b.x - a.x, 0, b.z - a.z).normalized()
	_start = a + _dir * 1.0 + Vector3(0, START_HEIGHT, 0)
	var end := b - _dir * (Furnace.MOUTH_RADIUS - 0.12) + Vector3(0, END_HEIGHT, 0)
	length = _start.distance_to(end)
	_slope = asin((END_HEIGHT - START_HEIGHT) / length)
	# Belt frame: local +X runs up the belt.
	_belt = Node3D.new()
	var x := (end - _start).normalized()
	var z := x.cross(Vector3.UP).normalized()
	_belt.transform = Transform3D(Basis(x, z.cross(x), z), _start)
	add_child(_belt)
	var perp := Vector3(-_dir.z, 0, _dir.x)
	if perp.dot(-a) < 0.0:
		perp = -perp
	_arm_base = a + perp * 1.3 + _dir * 0.35
	_arm_base.y = 0.0
	_build_colliders()
	_build_belt_art()
	_build_arm_art()
	_hum = Sfx.make_loop(self, &"furnace_loop")
	_hum.position = _start
	_hum.pitch_scale = 1.6
	_hum.volume_db = -22.0
	_apply_upgrades()


func has_belt() -> bool:
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld if is_inside_tree() else null
	return world != null and world.has_upgrade(&"conveyor")


func has_arm() -> bool:
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld if is_inside_tree() else null
	return world != null and world.has_upgrade(&"conveyor") and world.has_upgrade(&"robot_arm")


## World position of the hopper mouth (where scrap is dropped in).
func hopper_position() -> Vector3:
	return _start + Vector3(0, 0.25, 0)


func _apply_upgrades() -> void:
	var belt := has_belt()
	var arm := has_arm()
	_belt.visible = belt
	if _arm:
		_arm.visible = arm
	for i in _colliders.size():
		_colliders[i].disabled = not (belt if i < 2 else arm)
	if belt and not _hum.playing:
		_hum.play()
	elif not belt and _hum.playing:
		_hum.stop()


func _physics_process(delta: float) -> void:
	_apply_upgrades()
	if not _belt.visible:
		return
	_offset += BELT_SPEED * delta
	if _belt_mat:
		_belt_mat.set_shader_parameter(&"offset", _offset)
	var sim := Network.is_sim_authority()
	for i in range(pieces.size() - 1, -1, -1):
		var p: Array = pieces[i]
		p[1] += BELT_SPEED * delta
		var node := p[2] as Node3D
		if p[1] >= length:
			if node:
				node.queue_free()
			pieces.remove_at(i)
			if sim:
				_deliver(p[0])
		elif node:
			node.position = Vector3(p[1], 0.07, 0)
	if sim:
		_intake()
		if has_arm():
			_run_arm(delta)
	elif _cycle > 0.0:
		_cycle = maxf(0.0, _cycle - delta)
	_pose_arm()


## Scrap dropped into the hopper goes onto the belt. Host only.
func _intake() -> void:
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	if world == null:
		return
	for node in world.entities.get_children():
		var item := node as Item
		if item == null or item.is_held() or item.is_queued_for_deletion():
			continue
		var mixed := item.has_method(&"melt_mix")
		if not mixed and not FoundryRules.SCRAP.has(item.kind):
			continue
		var d := item.global_position - _start
		if Vector2(d.x, d.z).length() < HOPPER.x * 0.5 and d.y > -0.3 and d.y < HOPPER.y + 0.3:
			add_piece(item.melt_mix() if mixed else item.kind)
			item.queue_free()


## Host: puts a piece on the belt start (kind StringName or mix Dictionary).
func add_piece(what: Variant) -> void:
	_add(what)
	if Network.is_online() and multiplayer.is_server():
		_add_remote.rpc(String(what) if what is StringName else "")


@rpc("authority", "call_remote", "unreliable")
func _add_remote(kind: String) -> void:
	_add(StringName(kind) if kind != "" else &"scrap_pipe")


func _add(what: Variant) -> void:
	var node: MeshInstance3D = null
	if StationKit.visual():
		var kind: StringName = what if what is StringName else &"scrap_pipe"
		node = _piece_mesh(kind)
		node.rotation.y = randf() * TAU
		_belt.add_child(node)
	pieces.append([what, 0.05, node])
	Sfx.play(&"scrap_clatter", _start, -8.0, 0.2)


func _piece_mesh(kind: StringName) -> MeshInstance3D:
	var info: Dictionary = FoundryRules.SCRAP.get(kind, FoundryRules.SCRAP[&"scrap_can"])
	var mi := MeshInstance3D.new()
	var size: Vector3 = info.size
	mi.mesh = MeshFactory.rounded_box(size, minf(minf(size.x, minf(size.y, size.z)) * 0.4, 0.09))
	var mat := StandardMaterial3D.new()
	mat.albedo_color = info.color
	mat.metallic = 0.6
	mat.roughness = 0.4
	mi.material_override = mat
	return mi


func _deliver(what: Variant) -> void:
	if furnace == null or not is_instance_valid(furnace):
		return
	furnace.charge.append(what)
	var mouth := furnace.global_position + Vector3(0, Furnace.HEIGHT, 0)
	Sfx.play(&"scrap_clatter", mouth, -4.0)
	FoundryFX.sparks(furnace, mouth, 6)


# --- Robot arm --------------------------------------------------------------------

func _run_arm(delta: float) -> void:
	if _cycle <= 0.0:
		if pile.stock <= 0 or pieces.size() >= 6 or furnace.charge.size() >= 8:
			return
		_cycle = ARM_CYCLE
		_has_grabbed = false
		_cycle_kind = &""
		if Network.is_online():
			_arm_remote.rpc()
	_cycle -= delta
	var t := 1.0 - _cycle / ARM_CYCLE
	if t >= 0.3 and not _has_grabbed:
		_has_grabbed = true
		_cycle_kind = pile.take_one()
		var guide := get_tree().get_first_node_in_group(&"guides") as Guide
		if guide and _cycle_kind != &"":
			guide.note(&"dig")
	if t >= 0.78 and _cycle_kind != &"":
		add_piece(_cycle_kind)
		_cycle_kind = &""


@rpc("authority", "call_remote", "unreliable")
func _arm_remote() -> void:
	_cycle = ARM_CYCLE


## Arm pose from the cycle: rest -> heap (grab at 0.3) -> hopper (drop at 0.78) -> rest.
func _pose_arm() -> void:
	if _arm == null or not _arm.visible:
		return
	var heap_point := pile.global_position + Vector3(0, 0.38, 0)
	var drop_point := hopper_position() + Vector3(0, 0.55, 0)
	var rest := _arm_base + (heap_point - _arm_base).normalized() * 0.9 + Vector3(0, 1.45, 0)
	var t := 1.0 - _cycle / ARM_CYCLE if _cycle > 0.0 else 0.0
	var target := rest
	var grip := 0.0
	if _cycle > 0.0:
		if t < 0.3:
			target = rest.lerp(heap_point, smoothstep(0.0, 1.0, t / 0.3))
		elif t < 0.42:
			target = heap_point
			grip = 1.0
		elif t < 0.78:
			var k := smoothstep(0.0, 1.0, (t - 0.42) / 0.36)
			target = heap_point.lerp(drop_point, k) + Vector3(0, sin(k * PI) * 0.7, 0)
			grip = 1.0
		else:
			target = drop_point.lerp(rest, smoothstep(0.0, 1.0, (t - 0.78) / 0.22))
	_held_mesh.visible = _cycle > 0.0 and t >= 0.3 and t < 0.78
	# Two-bone reach in the turret's plane.
	var shoulder := _arm_base + Vector3(0, SHOULDER_HEIGHT, 0)
	var to := target - shoulder
	_turret.rotation.y = atan2(to.x, to.z)
	var flat := Vector2(Vector2(to.x, to.z).length(), to.y)
	var d := clampf(flat.length(), 0.25, UPPER + FORE - 0.02)
	var base := atan2(flat.y, flat.x)
	var a := acos(clampf((UPPER * UPPER + d * d - FORE * FORE) / (2.0 * UPPER * d), -1.0, 1.0))
	var b := acos(clampf((UPPER * UPPER + FORE * FORE - d * d) / (2.0 * UPPER * FORE), -1.0, 1.0))
	_shoulder.rotation.x = -(base + a)
	_elbow.rotation.x = PI - b
	for i in 2:
		_fingers[i].rotation.x = (grip * 0.4 - 0.45) * (1.0 if i == 0 else -1.0)
	if _lamp_mat:
		_lamp_mat.emission_energy_multiplier = 2.5 if _cycle > 0.0 else 0.6


# --- Collision and art --------------------------------------------------------------

func _build_colliders() -> void:
	var body := StaticBody3D.new()
	add_child(body)
	# 0: belt run, 1: hopper, 2: arm pedestal.
	var run := CollisionShape3D.new()
	var run_box := BoxShape3D.new()
	run_box.size = Vector3(length, 0.3, BELT_WIDTH + 0.16)
	run.shape = run_box
	run.transform = _belt.transform * Transform3D(Basis(), Vector3(length * 0.5, -0.1, 0))
	body.add_child(run)
	var hop := CollisionShape3D.new()
	var hop_box := BoxShape3D.new()
	hop_box.size = Vector3(HOPPER.x, START_HEIGHT, HOPPER.z)
	hop.shape = hop_box
	hop.position = Vector3(_start.x, START_HEIGHT * 0.5, _start.z)
	body.add_child(hop)
	var ped := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.34
	cyl.height = SHOULDER_HEIGHT
	ped.shape = cyl
	ped.position = _arm_base + Vector3(0, SHOULDER_HEIGHT * 0.5, 0)
	body.add_child(ped)
	_colliders = [run, hop, ped]


func _build_belt_art() -> void:
	if not StationKit.visual():
		return
	var paint := MachineArt.blue_mat()
	var steel := MachineArt.steel_mat()
	var dark := MachineArt.graphite_mat()
	var yellow := MachineArt.yellow_mat()
	var half := BELT_WIDTH * 0.5
	_belt_mat = MachineArt.conveyor(_belt, length, BELT_WIDTH)
	# A work light over the line so the machines read in dim halls.
	var glow := OmniLight3D.new()
	glow.light_color = Color("#ffe2b8")
	glow.light_energy = 1.1
	glow.omni_range = 4.5
	glow.position = Vector3(length * 0.3, 1.5, 0.9)
	_belt.add_child(glow)
	# Legs (vertical in the world): two trestles with cross braces and foot plates.
	var legs := []
	var feet := []
	var across := _belt.global_basis.z
	var tops: Array[Vector3] = []
	for u: float in [0.2, 0.88]:
		var top := _start + (_belt.global_basis.x * length * u) + Vector3(0, -0.12, 0)
		tops.append(top)
		for s: float in [-1.0, 1.0]:
			var p := top + across * s * (half + 0.03)
			legs.append(EnvMesh.piece(EnvMesh.box(Vector3(0.055, p.y - 0.06, 0.055), 0.012, 2), Transform3D(Basis(), Vector3(p.x, (p.y + 0.06) * 0.5, p.z))))
			feet.append(MachineArt.turned(MachineArt.foot_pad(), Vector3.UP, Vector3(p.x, 0, p.z), 16))
		legs.append(EnvMesh.piece(EnvMesh.box(Vector3(0.035, 0.035, BELT_WIDTH + 0.06), 0.008), Transform3D(Basis.looking_at(across, Vector3.UP), Vector3(top.x, 0.2, top.z))))
		StationKit.add(self, MachineArt.pipe(PackedVector3Array([top + across * (half + 0.03) + Vector3(0, -0.06, 0), Vector3(top.x, 0.2, top.z) - across * (half + 0.03)]), 0.011, 8), paint)
	legs.append(EnvMesh.piece(EnvMesh.box(Vector3(0.035, 0.035, tops[0].distance_to(tops[1])), 0.008), Transform3D(Basis.looking_at(Vector3(tops[1].x - tops[0].x, 0, tops[1].z - tops[0].z), Vector3.UP),
		Vector3((tops[0].x + tops[1].x) * 0.5, 0.2, (tops[0].z + tops[1].z) * 0.5))))
	StationKit.add_merged(self, legs, paint)
	StationKit.add_merged(self, feet, steel)
	# Hopper: four sloped plates over the belt foot, hazard edge, stencil.
	var hopper := []
	var hb := _start + Vector3(0, 0.1, 0)
	var basis := Basis.looking_at(-_dir, Vector3.UP)
	for k in 4:
		var side := Basis(Vector3.UP, k * PI * 0.5)
		var plate := Transform3D(basis * side * Basis(Vector3.RIGHT, -0.38), hb + basis * side * Vector3(0, 0.2, -HOPPER.x * 0.5 + 0.06))
		hopper.append(EnvMesh.piece(EnvMesh.box(Vector3(HOPPER.x - 0.02, 0.46, 0.015), 0.004), plate))
	var black_bits := []
	var edge := []
	for k in 4:
		var side := Basis(Vector3.UP, k * PI * 0.5)
		var tilt := basis * side * Basis(Vector3.RIGHT, -0.38)
		for r: float in [-0.22, 0.0, 0.22]:
			hopper.append(EnvMesh.piece(EnvMesh.box(Vector3(0.025, 0.4, 0.02), 0.006), Transform3D(tilt, hb + basis * side * Vector3(r, 0.2, -HOPPER.x * 0.5 + 0.045))))
		# Striped rim: seven yellow and black blocks per side.
		for q in 7:
			var seg := EnvMesh.piece(EnvMesh.box(Vector3((HOPPER.x + 0.14) / 7.0 + 0.002, 0.034, 0.034), 0.008), Transform3D(basis * side,
				hb + basis * side * Vector3((q - 3) * (HOPPER.x + 0.14) / 7.0, 0.42, -HOPPER.x * 0.5 - 0.02)))
			if q % 2 == 0:
				edge.append(seg)
			else:
				black_bits.append(seg)
		# A strut from the rim corner down to the floor.
		var corner := hb + basis * side * Vector3(HOPPER.x * 0.5 + 0.03, 0.4, -HOPPER.x * 0.5 - 0.03)
		StationKit.add(self, MachineArt.pipe(PackedVector3Array([corner, Vector3(corner.x, 0.03, corner.z)]), 0.016, 8), paint)
		black_bits.append(MachineArt.turned(MachineArt.foot_pad(), Vector3.UP, Vector3(corner.x, 0, corner.z), 14))
	StationKit.add_merged(self, hopper, paint)
	StationKit.add_merged(self, edge, yellow)
	StationKit.add_merged(self, black_bits, dark)
	StationKit.label(self, "SCHROTT", Transform3D(basis * Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, 0.38), hb + basis * Vector3(0, 0.2, HOPPER.x * 0.5 - 0.05)), 48, Color("#f0e2c4"), 800, 0.0012)
	# Control box on a post with a status lamp, a stop button and a cable.
	var post := _start + _belt.global_basis.z * (half + 0.45) + _dir * 0.55
	post.y = 0.0
	var box := []
	box.append(EnvMesh.piece(EnvMesh.box(Vector3(0.04, 1.05, 0.04)), Transform3D(Basis(), post + Vector3(0, 0.525, 0))))
	box.append(EnvMesh.piece(EnvMesh.box(Vector3(0.2, 0.28, 0.1), 0.012), Transform3D(basis, post + Vector3(0, 1.1, 0))))
	StationKit.add_merged(self, box, dark)
	_lamp_mat = StandardMaterial3D.new()
	_lamp_mat.albedo_color = Color("#3f8f55")
	_lamp_mat.emission_enabled = true
	_lamp_mat.emission = Color("#59e07e")
	_lamp_mat.emission_energy_multiplier = 0.6
	var lamp := MeshInstance3D.new()
	lamp.mesh = EnvMesh.cylinder(0.022, 0.022, 0.02, 12)
	lamp.material_override = _lamp_mat
	lamp.transform = Transform3D(basis * Basis(Vector3.RIGHT, PI * 0.5), post + Vector3(0, 1.18, 0) + basis * Vector3(0.04, 0, -0.055))
	add_child(lamp)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color("#c0392b")
	red.roughness = 0.4
	var stop := MeshInstance3D.new()
	stop.mesh = EnvMesh.cylinder(0.03, 0.03, 0.03, 14)
	stop.material_override = red
	stop.transform = Transform3D(basis * Basis(Vector3.RIGHT, PI * 0.5), post + Vector3(0, 1.06, 0) + basis * Vector3(-0.03, 0, -0.06))
	add_child(stop)
	var cable := PackedVector3Array([post + Vector3(0, 0.96, 0), post + Vector3(0, 0.3, 0) + _dir * 0.1, post + Vector3(0, 0.03, 0) + _dir * 0.4,
		_start + Vector3(0, -START_HEIGHT + 0.03, 0) + _dir * 0.6])
	StationKit.add(self, StationKit.tube(cable, 0.012, 6), dark)


func _build_arm_art() -> void:
	_arm = Node3D.new()
	_arm.position = _arm_base
	add_child(_arm)
	_turret = Node3D.new()
	_turret.position.y = SHOULDER_HEIGHT
	_arm.add_child(_turret)
	_shoulder = Node3D.new()
	_turret.add_child(_shoulder)
	_elbow = Node3D.new()
	_elbow.position.z = UPPER
	_shoulder.add_child(_elbow)
	var wrist := Node3D.new()
	wrist.position.z = FORE
	_elbow.add_child(wrist)
	for i in 2:
		var f := Node3D.new()
		f.position = Vector3(0, 0.05 if i == 0 else -0.05, 0.06)
		wrist.add_child(f)
		_fingers.append(f)
	_held_mesh = _piece_mesh(&"scrap_pipe")
	_held_mesh.position = Vector3(0, 0, 0.22)
	_held_mesh.visible = false
	wrist.add_child(_held_mesh)
	if StationKit.visual():
		MachineArt.arm({base = _arm, turret = _turret, shoulder = _shoulder, elbow = _elbow, wrist = wrist, fingers = _fingers}, UPPER, FORE, SHOULDER_HEIGHT)
