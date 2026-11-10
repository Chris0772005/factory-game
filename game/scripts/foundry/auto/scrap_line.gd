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
		_fingers[i].rotation.x = (0.5 - grip * 0.42) * (1.0 if i == 0 else -1.0)
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
	var paint := StationKit.metal("line_blue", {steel_color = Color("#56606a"), paint = 0.92, paint_color = Color("#2f6f8f"), rust = 0.25, dents = 0.2,
		metallic_steel = 0.45, roughness_steel = 0.5})
	var steel := StationKit.metal("line_steel", {steel_color = Color("#8a9097"), rust = 0.15, metallic_steel = 0.8, roughness_steel = 0.35})
	var dark := StationKit.metal("line_dark", {steel_color = Color("#2c2d30"), rust = 0.2, metallic_steel = 0.5})
	var yellow := StationKit.metal("crane_paint", {steel_color = Color("#d9a521"), rust = 0.25, dents = 0.2, metallic_steel = 0.3, roughness_steel = 0.55})
	var half := BELT_WIDTH * 0.5
	# Belt surface with running chevron cleats (UV.x in metres).
	_belt_mat = ShaderMaterial.new()
	_belt_mat.shader = load("res://shaders/fx_belt.gdshader")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := [[Vector3(0, 0.04, -half), Vector2(0, 0)], [Vector3(length, 0.04, -half), Vector2(length, 0)],
		[Vector3(length, 0.04, half), Vector2(length, 1)], [Vector3(0, 0.04, half), Vector2(0, 1)]]
	for idx in [0, 1, 2, 0, 2, 3]:
		st.set_normal(Vector3.UP)
		st.set_uv(corners[idx][1])
		st.add_vertex(corners[idx][0])
	var surface := MeshInstance3D.new()
	surface.mesh = st.commit()
	surface.material_override = _belt_mat
	_belt.add_child(surface)
	# Side channels, guard rails, end drums, idler rollers.
	var frame := []
	var rails := []
	var rollers := []
	for s: float in [-1.0, 1.0]:
		frame.append(EnvMesh.piece(EnvMesh.box(Vector3(length + 0.1, 0.12, 0.035), 0.008), Transform3D(Basis(), Vector3(length * 0.5, -0.03, s * (half + 0.03)))))
		frame.append(EnvMesh.piece(EnvMesh.box(Vector3(length + 0.1, 0.02, 0.07), 0.004), Transform3D(Basis(), Vector3(length * 0.5, -0.1, s * (half + 0.01)))))
		rails.append(EnvMesh.piece(EnvMesh.box(Vector3(length - 0.5, 0.025, 0.025), 0.006), Transform3D(Basis(), Vector3(length * 0.5 + 0.2, 0.2, s * (half + 0.05)))))
		var posts := maxi(2, int(length / 0.7))
		for k in posts:
			var px := 0.5 + (length - 0.75) * k / maxf(posts - 1, 1)
			rails.append(EnvMesh.piece(EnvMesh.box(Vector3(0.022, 0.2, 0.022)), Transform3D(Basis(), Vector3(px, 0.1, s * (half + 0.05)))))
	for end_x: float in [0.0, length]:
		rollers.append(EnvMesh.piece(EnvMesh.cylinder(0.07, 0.07, BELT_WIDTH, 16), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(end_x, -0.03, 0))))
	var idlers := int(length / 0.24)
	for k in idlers:
		rollers.append(EnvMesh.piece(EnvMesh.cylinder(0.028, 0.028, BELT_WIDTH - 0.02, 10), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.12 + k * 0.24, 0.0, 0))))
	StationKit.add_merged(_belt, frame, paint)
	StationKit.add_merged(_belt, rails, yellow)
	StationKit.add_merged(_belt, rollers, steel)
	# Drive at the top end: gear motor with cooling fins, a guard and a bolt circle.
	var drive := []
	var mz := half + 0.16
	drive.append(EnvMesh.piece(EnvMesh.cylinder(0.085, 0.085, 0.22, 16), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(length - 0.02, -0.03, mz + 0.08))))
	for k in 6:
		drive.append(EnvMesh.piece(EnvMesh.cylinder(0.098, 0.098, 0.008, 16), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(length - 0.02, -0.03, mz + 0.01 + k * 0.03))))
	drive.append(EnvMesh.piece(EnvMesh.box(Vector3(0.16, 0.16, 0.09), 0.015), Transform3D(Basis(), Vector3(length - 0.02, -0.03, mz - 0.06))))
	StationKit.add_merged(_belt, drive, dark)
	StationKit.add(_belt, EnvMesh.box(Vector3(0.3, 0.2, 0.02), 0.01), yellow, Transform3D(Basis(), Vector3(length - 0.05, 0.02, -half - 0.06)))
	# Legs (vertical in the world): two trestles with cross braces and foot plates.
	var legs := []
	for u: float in [0.22, 0.9]:
		var top := _start + (_belt.global_basis.x * length * u) + Vector3(0, -0.12, 0)
		var across := _belt.global_basis.z
		for s: float in [-1.0, 1.0]:
			var p := top + across * s * (half + 0.03)
			legs.append(EnvMesh.piece(EnvMesh.box(Vector3(0.05, p.y, 0.05), 0.006), Transform3D(Basis(), Vector3(p.x, p.y * 0.5, p.z))))
			legs.append(EnvMesh.piece(EnvMesh.box(Vector3(0.14, 0.015, 0.14)), Transform3D(Basis(), Vector3(p.x, 0.008, p.z))))
		var mid := top + Vector3(0, -top.y * 0.55, 0)
		legs.append(EnvMesh.piece(EnvMesh.box(Vector3(0.03, 0.03, BELT_WIDTH + 0.06)), Transform3D(Basis.looking_at(across, Vector3.UP), mid)))
	StationKit.add_merged(self, legs, paint)
	# Hopper: four sloped plates over the belt foot, hazard edge, stencil.
	var hopper := []
	var hb := _start + Vector3(0, 0.1, 0)
	var basis := Basis.looking_at(-_dir, Vector3.UP)
	for k in 4:
		var side := Basis(Vector3.UP, k * PI * 0.5)
		var plate := Transform3D(basis * side * Basis(Vector3.RIGHT, -0.38), hb + basis * side * Vector3(0, 0.2, -HOPPER.x * 0.5 + 0.06))
		hopper.append(EnvMesh.piece(EnvMesh.box(Vector3(HOPPER.x - 0.02, 0.46, 0.015), 0.004), plate))
	StationKit.add_merged(self, hopper, paint)
	var edge := []
	for k in 4:
		var side := Basis(Vector3.UP, k * PI * 0.5)
		edge.append(EnvMesh.piece(EnvMesh.box(Vector3(HOPPER.x + 0.14, 0.03, 0.03), 0.006), Transform3D(basis * side, hb + basis * side * Vector3(0, 0.42, -HOPPER.x * 0.5 - 0.02))))
	StationKit.add_merged(self, edge, yellow)
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
	if not StationKit.visual():
		return
	var orange := StationKit.metal("arm_orange", {steel_color = Color("#6a6d70"), paint = 0.94, paint_color = Color("#e0701f"), rust = 0.15, dents = 0.15,
		metallic_steel = 0.4, roughness_steel = 0.45})
	var dark := StationKit.metal("line_dark", {steel_color = Color("#2c2d30"), rust = 0.2, metallic_steel = 0.5})
	var steel := StationKit.metal("line_steel", {steel_color = Color("#8a9097"), rust = 0.15, metallic_steel = 0.8, roughness_steel = 0.35})
	# Pedestal: floor plate with bolts, column, slewing ring.
	var ped := []
	ped.append(EnvMesh.piece(EnvMesh.cylinder(0.36, 0.38, 0.04, 20), Transform3D(Basis(), Vector3(0, 0.02, 0))))
	ped.append(EnvMesh.piece(EnvMesh.cylinder(0.2, 0.27, SHOULDER_HEIGHT - 0.2, 16), Transform3D(Basis(), Vector3(0, (SHOULDER_HEIGHT - 0.2) * 0.5 + 0.04, 0))))
	ped.append(EnvMesh.piece(EnvMesh.cylinder(0.28, 0.28, 0.07, 20), Transform3D(Basis(), Vector3(0, SHOULDER_HEIGHT - 0.16, 0))))
	StationKit.add_merged(_arm, ped, dark)
	var bolts := []
	for k in 8:
		var a := TAU * k / 8.0
		bolts.append(EnvMesh.piece(EnvMesh.cylinder(0.022, 0.022, 0.03, 6), Transform3D(Basis(), Vector3(sin(a) * 0.31, 0.05, cos(a) * 0.31))))
	StationKit.add_merged(_arm, bolts, steel)
	StationKit.label(_arm, "GREIFER 01", Transform3D(Basis(Vector3.UP, atan2(-_arm_base.x, -_arm_base.z)), Vector3(0, 0.4, 0) + Basis(Vector3.UP, atan2(-_arm_base.x, -_arm_base.z)) * Vector3(0, 0, 0.25)),
		40, Color("#f0e2c4"), 800, 0.001)
	# Turret with the shoulder joint housings.
	var turret := []
	turret.append(EnvMesh.piece(EnvMesh.cylinder(0.24, 0.26, 0.14, 18), Transform3D(Basis(), Vector3(0, -0.06, 0))))
	for s: float in [-1.0, 1.0]:
		turret.append(EnvMesh.piece(EnvMesh.box(Vector3(0.05, 0.26, 0.22), 0.02), Transform3D(Basis(), Vector3(s * 0.15, 0.04, 0))))
	StationKit.add_merged(_turret, turret, orange)
	StationKit.add(_turret, EnvMesh.cylinder(0.11, 0.11, 0.36, 16), dark, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3.ZERO))
	# Upper arm: two side plates, a hydraulic ram, a cable run.
	var upper := []
	for s: float in [-1.0, 1.0]:
		upper.append(EnvMesh.piece(EnvMesh.box(Vector3(0.035, 0.17, UPPER + 0.1), 0.012), Transform3D(Basis(), Vector3(s * 0.09, 0, UPPER * 0.5))))
	upper.append(EnvMesh.piece(EnvMesh.box(Vector3(0.18, 0.05, UPPER * 0.6), 0.012), Transform3D(Basis(), Vector3(0, 0.085, UPPER * 0.5))))
	StationKit.add_merged(_shoulder, upper, orange)
	var ram := []
	ram.append(EnvMesh.piece(EnvMesh.cylinder(0.035, 0.035, UPPER * 0.5, 10), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, -0.11, UPPER * 0.35))))
	ram.append(EnvMesh.piece(EnvMesh.cylinder(0.018, 0.018, UPPER * 0.45, 8), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, -0.11, UPPER * 0.75))))
	StationKit.add_merged(_shoulder, ram, steel)
	StationKit.add(_shoulder, StationKit.tube(PackedVector3Array([Vector3(0.12, 0.05, 0.1), Vector3(0.14, 0.12, UPPER * 0.4), Vector3(0.13, 0.06, UPPER * 0.8), Vector3(0.12, 0.04, UPPER)]), 0.014, 6), dark)
	# Elbow joint, forearm, wrist.
	StationKit.add(_elbow, EnvMesh.cylinder(0.085, 0.085, 0.3, 16), dark, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3.ZERO))
	var fore := []
	fore.append(EnvMesh.piece(EnvMesh.box(Vector3(0.11, 0.12, FORE - 0.1), 0.02), Transform3D(Basis(), Vector3(0, 0, FORE * 0.5))))
	fore.append(EnvMesh.piece(EnvMesh.box(Vector3(0.14, 0.14, 0.14), 0.03), Transform3D(Basis(), Vector3(0, 0, FORE * 0.22))))
	StationKit.add_merged(_elbow, fore, orange)
	StationKit.add(wrist, EnvMesh.cylinder(0.07, 0.07, 0.1, 14), dark, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO))
	# Gripper: two fingers with claw tips.
	for i in 2:
		var claw := []
		var s := 1.0 if i == 0 else -1.0
		claw.append(EnvMesh.piece(EnvMesh.box(Vector3(0.09, 0.022, 0.2), 0.006), Transform3D(Basis(), Vector3(0, 0, 0.1))))
		claw.append(EnvMesh.piece(EnvMesh.box(Vector3(0.09, 0.022, 0.09), 0.006), Transform3D(Basis(Vector3.RIGHT, s * 0.9), Vector3(0, -s * 0.03, 0.23))))
		StationKit.add_merged(_fingers[i], claw, steel)
	# Beacon on the turret.
	var beacon := MeshInstance3D.new()
	beacon.mesh = EnvMesh.cylinder(0.03, 0.035, 0.05, 12)
	var amber := StandardMaterial3D.new()
	amber.albedo_color = Color("#d98a1f")
	amber.emission_enabled = true
	amber.emission = Color("#ffb347")
	amber.emission_energy_multiplier = 1.4
	beacon.material_override = amber
	beacon.position = Vector3(0, 0.2, -0.12)
	_turret.add_child(beacon)
