class_name MoldLine
extends Node3D
## Formband: the Eisenhalle's mold line, where an approved pattern runs in
## series. Twelve flasks ride a loop: a forward run past the molding
## machine, the pouring place, the cooling hood and the shakeout grate, and
## a return run behind it. The line indexes one pitch at a time whenever the
## flask at the pouring place is not waiting for metal.
##   Molding: F at the machine (3 presses) or by itself with the Formautomat.
##   Pouring: from the ladle or a crucible straight into the flask, or by
##            itself from the Gießautomat's pouring box once it is filled.
##   Shakeout: automatic; the casting slides down the chute into the line's
##            own sell crate – passive income and series orders.
## The pattern comes from the pattern bench next to the machine
## (ModelBench.line_mode). Host simulates; peers get the flask states
## (reliable) and fills / belt phase (10 Hz).

enum Flask { EMPTY, MOLDED, FILLED }

const SLOTS := 12
const RUN := 6                  ## slots on the forward run (0..5)
const PITCH := 0.95
const RETURN_Z := -1.15
const MOLD_SLOT := 0
const POUR_SLOT := 2
const SHAKEOUT_SLOT := 5
const BELT_Y := 0.42
const FLASK := Vector3(0.74, 0.3, 0.58)
const CAST_SIZE := 0.42
const CAST_THICKNESS := 0.06
const INDEX_TIME := 1.1
const COOL_TIME := 8.0
const PRESSES := 3
const AUTO_MOLD_TIME := 1.6
const SHAKE_TIME := 0.8
## Gießautomat: pouring box beside the pouring place.
const TUNDISH_POS := Vector3(POUR_SLOT * PITCH, 0.0, 0.95)
const TUNDISH_CAPACITY := 30.0
const TUNDISH_TOP := 1.05
const AUTO_POUR_RATE := 0.7

var pattern := ""
var offset := 0                 ## flask f sits at slot (f + offset) % SLOTS
var phase := 0.0                ## 0..1 while indexing
var moving := false
var states: Array[int] = []
var fills: Array[float] = []
var needs: Array[float] = []
var codes: Array[String] = []
var temps: Array[float] = []
var cools: Array[float] = []
var mold_quality: Array[float] = []
var defects: Array[Dictionary] = []
var mixes: Array[Dictionary] = []
var tundish := 0.0
var tundish_mix := {}
var tundish_temp := 0.0
var auto_flow := 0.0

var _presses := 0
var _press_score := 0.0
var _last_press := 0.0
var _auto_mold := 0.0
var _shake := 0.0
var _last_pour := -10.0
var _gap_flagged := false
var _sync_accum := 0.0
var _built := {}
var _press_anim := 0.0
var _shake_anim := 0.0

var _flask_nodes: Array[Node3D] = []
var _flask_metal: Array[MeshInstance3D] = []
var _flask_imprint: Array[MeshInstance3D] = []
var _flask_codes: Array[String] = []
var _metal_mats: Array[ShaderMaterial] = []
var _press_head: Node3D
var _grate: Node3D
var _tundish_node: Node3D
var _tundish_melt: MeshInstance3D
var _tundish_mat: ShaderMaterial
var _auto_stream: PourStream
var crate: SellCrate
var _tundish_body: StaticBody3D


static func deliver_at(tree: SceneTree, point: Vector3, litres: float, temperature: float, mix: Dictionary, rate: float, delta: float) -> bool:
	for node in tree.get_nodes_in_group(&"mold_lines"):
		if (node as MoldLine).receive_at(point, litres, temperature, mix, rate, delta):
			return true
	return false


## Hint text for a pour landing at `point` ("" if not over a line).
static func describe_at(tree: SceneTree, point: Vector3) -> String:
	for node in tree.get_nodes_in_group(&"mold_lines"):
		var line := node as MoldLine
		var local := line.to_local(point)
		if line.has_tundish() and line._in_tundish(local):
			return "Gießautomat %s / %d l" % [roundi(line.tundish), roundi(TUNDISH_CAPACITY)]
		var f := line._flask_under(local)
		if f >= 0:
			if line.slot_of(f) == POUR_SLOT and line.states[f] == Flask.MOLDED and not line.moving:
				return "Formband: Kasten %d %%" % roundi(line.fills[f] * 100.0)
			return "Formband: hier nicht gießen!"
	return ""


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_to_group(&"interactable")
	add_to_group(&"mold_lines")
	for i in SLOTS:
		states.append(Flask.EMPTY)
		fills.append(0.0)
		needs.append(1.0)
		codes.append("")
		temps.append(0.0)
		cools.append(0.0)
		mold_quality.append(0.0)
		defects.append({})
		mixes.append({})
	# Belt bed (both runs) and the machines are solid; flasks ride on top.
	StationKit.box_collider(self, Vector3(RUN * PITCH + 0.3, BELT_Y, 2.0), Transform3D(Basis(), Vector3((RUN - 1) * PITCH * 0.5, BELT_Y * 0.5, RETURN_Z * 0.5)))
	StationKit.box_collider(self, Vector3(RUN * PITCH, 0.32, FLASK.z), Transform3D(Basis(), Vector3((RUN - 1) * PITCH * 0.5, BELT_Y + 0.16, 0)))
	StationKit.box_collider(self, Vector3(RUN * PITCH, 0.32, FLASK.z), Transform3D(Basis(), Vector3((RUN - 1) * PITCH * 0.5, BELT_Y + 0.16, RETURN_Z)))
	# The pouring box catches the stream (and blocks walkers) only once bought.
	_tundish_body = StationKit.box_collider(self, Vector3(0.7, TUNDISH_TOP, 0.56), Transform3D(Basis(), TUNDISH_POS + Vector3(0, TUNDISH_TOP * 0.5, 0)))
	crate = SellCrate.new()
	crate.position = Vector3(SHAKEOUT_SLOT * PITCH + 1.15, 0, 0.35)
	crate.rotation.y = PI * 0.5
	add_child(crate)
	Network.peer_ready.connect(_on_peer_ready)
	_build_art()
	_refresh_flasks()


func has_tundish() -> bool:
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld if is_inside_tree() else null
	return world != null and world.has_upgrade(&"auto_pourer")


func auto_molding() -> bool:
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld if is_inside_tree() else null
	return world != null and world.has_upgrade(&"auto_molder")


## Slot (0..SLOTS-1) flask `f` is at (or leaving, while indexing).
func slot_of(f: int) -> int:
	return (f + offset) % SLOTS


## Flask at slot `s`.
func flask_at(s: int) -> int:
	return posmod(s - offset, SLOTS)


## Local position of slot `s` (top of the belt).
func slot_position(s: int) -> Vector3:
	s = posmod(s, SLOTS)
	if s < RUN:
		return Vector3(s * PITCH, BELT_Y, 0)
	return Vector3((RUN - 1 - (s - RUN)) * PITCH, BELT_Y, RETURN_Z)


func flask_position(f: int) -> Vector3:
	var s := slot_of(f)
	var a := slot_position(s)
	if not moving:
		return a
	return a.lerp(slot_position(s + 1), smoothstep(0.0, 1.0, phase))


## Pattern from the pattern bench. Host only.
func set_pattern(code: String) -> bool:
	if Drawing.from_code(code) == null:
		return false
	pattern = code
	_broadcast_state()
	return true


# --- Molding machine (the line's interact point) -------------------------------

func interact_point() -> Vector3:
	return to_global(slot_position(MOLD_SLOT) + Vector3(-0.2, 0.75, 0.55))


func hint(_player: Node) -> String:
	if pattern == "":
		return "Formband · kein Muster – an der Musterbank zeichnen"
	var f := flask_at(MOLD_SLOT)
	var status := _status_text()
	if auto_molding():
		return "Formautomat läuft · " + status
	if moving:
		return "Formband taktet… · " + status
	if states[f] == Flask.EMPTY:
		return "[F] Formmaschine pressen (%d/%d) · %s" % [_presses, PRESSES, status]
	return status


func _status_text() -> String:
	var waiting := flask_at(POUR_SLOT)
	if states[waiting] == Flask.MOLDED and not moving:
		return "Kasten am Gießplatz wartet auf Metall (%s l)" % _l(needs[waiting] * (1.0 - fills[waiting]))
	var f := flask_at(SHAKEOUT_SLOT)
	if states[f] == Flask.FILLED and cools[f] > 0.0:
		return "Guss kühlt · %d s" % ceili(cools[f])
	return "läuft"


func interact(_player: Node) -> void:
	if not Network.is_sim_authority() or pattern == "" or moving or auto_molding():
		return
	var f := flask_at(MOLD_SLOT)
	if states[f] != Flask.EMPTY:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var interval := now - _last_press
	_last_press = now
	_press_score += 1.0 if _presses == 0 or (interval > 0.22 and interval < 0.9) else 0.5
	_presses += 1
	_press_fx_all()
	if _presses >= PRESSES:
		_mold(f, _press_score / PRESSES)


func _mold(f: int, quality: float) -> void:
	_presses = 0
	_press_score = 0.0
	states[f] = Flask.MOLDED
	codes[f] = pattern
	fills[f] = 0.0
	needs[f] = maxf(0.15, _build(pattern).get("volume", 0.003) * MoldBox.LITRES_PER_M3)
	mold_quality[f] = quality
	defects[f] = {}
	mixes[f] = {}
	temps[f] = 0.0
	_broadcast_state()


# --- Metal ----------------------------------------------------------------------

func _in_tundish(local: Vector3) -> bool:
	var p := local - TUNDISH_POS
	return absf(p.x) < 0.32 and absf(p.z) < 0.26 and p.y > 0.5 and p.y < TUNDISH_TOP + 0.6


func _flask_under(local: Vector3) -> int:
	for f in SLOTS:
		var p := local - flask_position(f)
		if absf(p.x) < FLASK.x * 0.5 and absf(p.z) < FLASK.z * 0.5 and p.y > -0.1 and p.y < FLASK.y + 1.0:
			return f
	return -1


## Melt landing at `point`. Host only. True if the line caught it.
func receive_at(point: Vector3, litres: float, temperature: float, mix: Dictionary, rate: float, delta: float) -> bool:
	var local := to_local(point)
	if has_tundish() and _in_tundish(local):
		var room := TUNDISH_CAPACITY - tundish
		var take := clampf(room, 0.0, litres)
		if take > 0.0:
			for k in mix:
				tundish_mix[k] = tundish_mix.get(k, 0.0) + mix[k] * take / maxf(litres, 0.0001)
			tundish_temp = (tundish_temp * tundish + temperature * take) / maxf(tundish + take, 0.0001)
			tundish += take
		if take < litres and randf() < delta * 4.0:
			_sparks_all(to_global(TUNDISH_POS + Vector3(0, TUNDISH_TOP, 0)))
		return true
	var f := _flask_under(local)
	if f < 0:
		return false
	if slot_of(f) != POUR_SLOT or moving or states[f] != Flask.MOLDED:
		if randf() < delta * 6.0:
			_sparks_all(point)
		if states[f] == Flask.FILLED:
			defects[f]["flash"] = minf(1.0, defects[f].get("flash", 0.0) + litres)
		return true
	_fill_flask(f, litres, temperature, mix, rate, delta)
	return true


func _fill_flask(f: int, litres: float, temperature: float, mix: Dictionary, rate: float, delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if fills[f] > 0.0 and now - _last_pour > 1.2 and not _gap_flagged:
		defects[f]["cold_shut"] = minf(1.0, defects[f].get("cold_shut", 0.0) + 0.5)
		_gap_flagged = true
	_last_pour = now
	if rate > MoldBox.SAFE_POUR_RATE:
		defects[f]["spatter"] = minf(1.0, defects[f].get("spatter", 0.0) + (rate - MoldBox.SAFE_POUR_RATE) * delta * 1.2)
		if randf() < delta * 8.0:
			_sparks_all(to_global(flask_position(f) + Vector3(0, FLASK.y, 0)))
	if temperature < 0.45:
		defects[f]["misrun"] = minf(1.0, defects[f].get("misrun", 0.0) + delta * 0.6)
	for k in mix:
		mixes[f][k] = mixes[f].get(k, 0.0) + mix[k]
	temps[f] = maxf(temps[f], temperature)
	fills[f] = minf(1.0, fills[f] + litres / needs[f])
	if fills[f] >= 0.999:
		states[f] = Flask.FILLED
		cools[f] = COOL_TIME
		_gap_flagged = false
		_broadcast_state()


func _physics_process(delta: float) -> void:
	if Network.is_sim_authority():
		_simulate(delta)
	_update_art(delta)


func _simulate(delta: float) -> void:
	if Network.is_online():
		_sync_accum += delta
		if _sync_accum > 0.1:
			_sync_accum = 0.0
			_sync_fill.rpc(PackedFloat32Array(fills), PackedFloat32Array(temps), tundish, tundish_temp, auto_flow)
	for f in SLOTS:
		if states[f] == Flask.FILLED and cools[f] > 0.0:
			cools[f] -= delta
			temps[f] = maxf(0.25, temps[f] - delta * 0.06)
	if moving:
		phase += delta / INDEX_TIME
		if phase >= 1.0:
			phase = 0.0
			moving = false
			offset = (offset + 1) % SLOTS
			_broadcast_state()
		return
	var mold_f := flask_at(MOLD_SLOT)
	if pattern != "" and states[mold_f] == Flask.EMPTY and auto_molding():
		_auto_mold += delta
		_press_anim = 1.0 if _auto_mold < 0.2 else _press_anim
		if _auto_mold >= AUTO_MOLD_TIME:
			_auto_mold = 0.0
			_mold(mold_f, 0.8)
	_auto_pour(delta)
	var shake_f := flask_at(SHAKEOUT_SLOT)
	if states[shake_f] == Flask.FILLED and cools[shake_f] <= 0.0:
		_shake += delta
		if _shake >= SHAKE_TIME:
			_shake = 0.0
			_shake_out(shake_f)
		return
	if _can_index():
		moving = true
		phase = 0.0
		_broadcast_state()


func _can_index() -> bool:
	var pour_f := flask_at(POUR_SLOT)
	if states[pour_f] == Flask.MOLDED:
		return false
	var shake_f := flask_at(SHAKEOUT_SLOT)
	if states[shake_f] == Flask.FILLED:
		return false
	if states[flask_at(MOLD_SLOT)] == Flask.MOLDED:
		return true
	if pattern == "":
		# No pattern: drain what is still on the forward run.
		for s in range(MOLD_SLOT + 1, SHAKEOUT_SLOT):
			if states[flask_at(s)] != Flask.EMPTY:
				return true
	return false


func _auto_pour(delta: float) -> void:
	auto_flow = 0.0
	if not has_tundish() or tundish <= 0.0:
		return
	var f := flask_at(POUR_SLOT)
	if states[f] != Flask.MOLDED:
		return
	var litres := minf(tundish, AUTO_POUR_RATE * delta)
	var share := {}
	for k in tundish_mix:
		share[k] = tundish_mix[k] / maxf(tundish, 0.0001) * litres
		tundish_mix[k] -= share[k]
	tundish -= litres
	if tundish <= 0.001:
		tundish = 0.0
		tundish_mix.clear()
	auto_flow = 1.0
	_fill_flask(f, litres, tundish_temp, share, AUTO_POUR_RATE, delta)


func _shake_out(f: int) -> void:
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	var top := to_global(flask_position(f) + Vector3(0, FLASK.y, 0))
	_fx_all(&"shake", top)
	if fills[f] >= 0.3 and world:
		var q := FoundryRules.score(mold_quality[f], fills[f], defects[f])
		var piece: Node = world.spawn_entity({type = "cast", code = codes[f], alloy = FoundryRules.alloy_for(mixes[f]), quality = q,
			defects = defects[f], temperature = 0.4, series = true, size = CAST_SIZE, thickness = CAST_THICKNESS,
			pos = to_global(slot_position(SHAKEOUT_SLOT) + Vector3(0.55, FLASK.y + 0.35, 0.2))})
		if piece is RigidBody3D:
			(piece as RigidBody3D).apply_central_impulse(global_basis * Vector3(2.4, 1.2, 0.6) * (piece as RigidBody3D).mass)
	states[f] = Flask.EMPTY
	fills[f] = 0.0
	codes[f] = ""
	temps[f] = 0.0
	_broadcast_state()


# --- Networking ---------------------------------------------------------------------

func _broadcast_state() -> void:
	_refresh_flasks()
	if Network.is_online() and multiplayer.is_server():
		_sync_state.rpc(pattern, offset, moving, phase, PackedInt32Array(states), PackedStringArray(codes), PackedFloat32Array(fills))


func _on_peer_ready(id: int, level: String) -> void:
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	if is_inside_tree() and multiplayer.is_server() and world and level == world.level_path():
		_sync_state.rpc_id(id, pattern, offset, moving, phase, PackedInt32Array(states), PackedStringArray(codes), PackedFloat32Array(fills))


@rpc("authority", "call_remote", "reliable")
func _sync_state(p: String, o: int, m: bool, ph: float, s: PackedInt32Array, c: PackedStringArray, f: PackedFloat32Array) -> void:
	pattern = p
	offset = o
	moving = m
	phase = ph
	for i in mini(SLOTS, s.size()):
		states[i] = s[i]
		codes[i] = c[i]
		fills[i] = f[i]
	_refresh_flasks()


@rpc("authority", "call_remote", "unreliable_ordered")
func _sync_fill(f: PackedFloat32Array, t: PackedFloat32Array, tun: float, tun_temp: float, flow: float) -> void:
	for i in mini(SLOTS, f.size()):
		fills[i] = f[i]
		temps[i] = t[i]
	tundish = tun
	tundish_temp = tun_temp
	auto_flow = flow


func _press_fx_all() -> void:
	_press_fx()
	if Network.is_online() and multiplayer.is_server():
		_press_fx_remote.rpc()


@rpc("authority", "call_remote", "unreliable")
func _press_fx_remote() -> void:
	_press_fx()


func _press_fx() -> void:
	_press_anim = 1.0
	Sfx.play(&"ram_thud", to_global(slot_position(MOLD_SLOT) + Vector3(0, 0.9, 0)))
	FoundryFX.dust(self, to_global(slot_position(MOLD_SLOT) + Vector3(0, FLASK.y + 0.05, 0)))


func _sparks_all(pos: Vector3) -> void:
	_fx_all(&"sparks", pos)


func _fx_all(kind: StringName, pos: Vector3) -> void:
	_fx(kind, pos)
	if Network.is_online() and multiplayer.is_server():
		_fx_remote.rpc(kind, pos)


@rpc("authority", "call_remote", "unreliable")
func _fx_remote(kind: StringName, pos: Vector3) -> void:
	_fx(kind, pos)


func _fx(kind: StringName, pos: Vector3) -> void:
	match kind:
		&"sparks":
			FoundryFX.sparks(get_parent(), pos, 8)
		&"shake":
			FoundryFX.sand_burst(get_parent(), pos, 0.6)
			Sfx.play(&"sand_burst", pos, -4.0)
			_shake_anim = 0.5


func _l(v: float) -> String:
	return ("%.1f" % v).replace(".", ",")


# --- Art -------------------------------------------------------------------------------

func _build(code: String) -> Dictionary:
	if not _built.has(code):
		var drawing := Drawing.from_code(code)
		_built[code] = CastMeshBuilder.build(drawing, CAST_SIZE, CAST_THICKNESS) if drawing else {}
	return _built[code]


func _build_art() -> void:
	var visual := StationKit.visual()
	var steel := StationKit.metal("line_frame", {steel_color = Color("#4b4a49"), rust = 0.35, metallic_steel = 0.55})
	var paint := StationKit.metal("line_paint", {steel_color = Color("#3f6f8f"), rust = 0.2, dents = 0.2, metallic_steel = 0.25, roughness_steel = 0.55})
	var sand := StationKit.surface("line_sand", {base_color = Color("#5b4a3a"), stain_color = Color("#3a2c22"), stains = 0.5,
		roughness_base = 0.95, macro = 0.25, grain = 0.6, noise_scale = 14.0})
	var imprint := StationKit.surface("line_imprint", {base_color = Color("#2e241c"), roughness_base = 0.95, macro = 0.2, grain = 0.5})
	for f in SLOTS:
		var n := Node3D.new()
		add_child(n)
		_flask_nodes.append(n)
		_flask_codes.append("")
		var metal := MeshInstance3D.new()
		var mat := MetalMaterial.create(&"iron", f)
		mat.set_shader_parameter(&"glow_scale", 1.7)
		metal.material_override = mat
		metal.visible = false
		n.add_child(metal)
		_flask_metal.append(metal)
		_metal_mats.append(mat)
		var imp := MeshInstance3D.new()
		imp.material_override = imprint
		imp.visible = false
		n.add_child(imp)
		_flask_imprint.append(imp)
		if visual:
			var frame := []
			for s: float in [-1.0, 1.0]:
				frame.append(EnvMesh.piece(EnvMesh.box(Vector3(FLASK.x, FLASK.y, 0.04), 0.01), Transform3D(Basis(), Vector3(0, FLASK.y * 0.5, s * (FLASK.z * 0.5 - 0.02)))))
				frame.append(EnvMesh.piece(EnvMesh.box(Vector3(0.04, FLASK.y, FLASK.z), 0.01), Transform3D(Basis(), Vector3(s * (FLASK.x * 0.5 - 0.02), FLASK.y * 0.5, 0))))
				frame.append(EnvMesh.piece(EnvMesh.box(Vector3(0.08, 0.05, 0.08), 0.01), Transform3D(Basis(), Vector3(s * (FLASK.x * 0.5 + 0.02), FLASK.y - 0.06, 0))))
			StationKit.add_merged(n, frame, steel)
			StationKit.add(n, EnvMesh.box(Vector3(FLASK.x - 0.06, 0.02, FLASK.z - 0.06)), sand, Transform3D(Basis(), Vector3(0, FLASK.y - 0.02, 0)))
	_press_head = Node3D.new()
	_press_head.position = slot_position(MOLD_SLOT) + Vector3(0, 1.45, 0)
	add_child(_press_head)
	_grate = Node3D.new()
	_grate.position = slot_position(SHAKEOUT_SLOT)
	add_child(_grate)
	_tundish_node = Node3D.new()
	_tundish_node.position = TUNDISH_POS
	add_child(_tundish_node)
	_tundish_melt = MeshInstance3D.new()
	var disc := BoxMesh.new()
	disc.size = Vector3(0.5, 0.02, 0.4)
	_tundish_melt.mesh = disc
	_tundish_mat = MetalMaterial.create(&"iron")
	_tundish_mat.set_shader_parameter(&"glow_scale", 1.5)
	_tundish_melt.material_override = _tundish_mat
	_tundish_node.add_child(_tundish_melt)
	_auto_stream = PourStream.new()
	_auto_stream.top_level = true
	add_child(_auto_stream)
	if not visual:
		return
	# Roller beds of both runs and the transfer ends.
	var bed := []
	var length := (RUN - 1) * PITCH + FLASK.x + 0.2
	for z: float in [0.0, RETURN_Z]:
		for s: float in [-1.0, 1.0]:
			bed.append(EnvMesh.piece(EnvMesh.box(Vector3(length, 0.12, 0.06), 0.01), Transform3D(Basis(), Vector3((RUN - 1) * PITCH * 0.5, BELT_Y - 0.06, z + s * 0.32))))
		for k in RUN * 3:
			bed.append(EnvMesh.piece(EnvMesh.cylinder(0.035, 0.035, 0.62, 8), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-FLASK.x * 0.5 + k * PITCH / 3.0, BELT_Y - 0.03, z))))
		for k in RUN:
			for s: float in [-1.0, 1.0]:
				bed.append(EnvMesh.piece(EnvMesh.box(Vector3(0.08, BELT_Y - 0.1, 0.08), 0.01), Transform3D(Basis(), Vector3(k * PITCH, (BELT_Y - 0.1) * 0.5, z + s * 0.32))))
	StationKit.add_merged(self, bed, steel)
	# Molding machine: a portal frame with a squeeze head over slot 0.
	var portal := []
	var m := slot_position(MOLD_SLOT)
	for s: float in [-1.0, 1.0]:
		portal.append(EnvMesh.piece(EnvMesh.box(Vector3(0.14, 2.0, 0.14), 0.01), Transform3D(Basis(), m + Vector3(0, 1.0 - BELT_Y, s * 0.5))))
	portal.append(EnvMesh.piece(EnvMesh.box(Vector3(0.5, 0.24, 1.14), 0.02), Transform3D(Basis(), m + Vector3(0, 2.0 - BELT_Y, 0))))
	portal.append(EnvMesh.piece(EnvMesh.box(Vector3(0.36, 0.5, 0.36), 0.02), Transform3D(Basis(), m + Vector3(-0.45, 0.85 - BELT_Y, 0.55))))
	StationKit.add_merged(self, portal, paint)
	StationKit.add(_press_head, EnvMesh.box(Vector3(FLASK.x - 0.04, 0.12, FLASK.z - 0.04), 0.01), steel)
	StationKit.add(_press_head, EnvMesh.cylinder(0.07, 0.07, 0.5, 10), steel, Transform3D(Basis(), Vector3(0, 0.3, 0)))
	StationKit.label(self, "FORMAUTOMAT", Transform3D(Basis(), m + Vector3(0, 2.0 - BELT_Y, 0.58)), 56, Color("#f0e2c4"), 800, 0.0012)
	# Cooling hood over slots 3-4 and the shakeout grate at slot 5.
	var hood := []
	var c := (slot_position(3) + slot_position(4)) * 0.5
	for s: float in [-1.0, 1.0]:
		hood.append(EnvMesh.piece(EnvMesh.box(Vector3(PITCH * 2.0, 0.9, 0.04), 0.01), Transform3D(Basis(), c + Vector3(0, 0.75, s * 0.42))))
	hood.append(EnvMesh.piece(EnvMesh.box(Vector3(PITCH * 2.0, 0.04, 0.88), 0.01), Transform3D(Basis(), c + Vector3(0, 1.2, 0))))
	hood.append(EnvMesh.piece(EnvMesh.cylinder(0.16, 0.16, 1.6, 12), Transform3D(Basis(), c + Vector3(0, 2.0, 0))))
	StationKit.add_merged(self, hood, steel)
	StationKit.label(self, "KÜHLSTRECKE", Transform3D(Basis(), c + Vector3(0, 0.85, 0.445)), 56, Color("#f0e2c4"), 800, 0.0012)
	var grate := []
	for k in 7:
		grate.append(EnvMesh.piece(EnvMesh.box(Vector3(0.04, 0.04, 0.7)), Transform3D(Basis(), Vector3(-0.36 + k * 0.12, 0.02, 0))))
	StationKit.add_merged(_grate, grate, steel)
	var chute := []
	var g := slot_position(SHAKEOUT_SLOT)
	chute.append(EnvMesh.piece(EnvMesh.box(Vector3(0.9, 0.04, 0.6), 0.01), Transform3D(Basis(Vector3.BACK, -0.45), g + Vector3(0.65, 0.1, 0.3))))
	for s: float in [-1.0, 1.0]:
		chute.append(EnvMesh.piece(EnvMesh.box(Vector3(0.9, 0.16, 0.03), 0.01), Transform3D(Basis(Vector3.BACK, -0.45), g + Vector3(0.65, 0.16, 0.3 + s * 0.3))))
	StationKit.add_merged(self, chute, paint)
	StationKit.label(self, "AUSLEERROST", Transform3D(Basis(), g + Vector3(0, -0.12, 0.36)), 48, Color("#f0e2c4"), 800, 0.0012)
	# Gießautomat: a lined pouring box on legs with a stopper arm.
	var box := []
	for s: float in [-1.0, 1.0]:
		box.append(EnvMesh.piece(EnvMesh.box(Vector3(0.7, 0.36, 0.05), 0.01), Transform3D(Basis(), Vector3(0, TUNDISH_TOP - 0.18, s * 0.27))))
		box.append(EnvMesh.piece(EnvMesh.box(Vector3(0.05, 0.36, 0.54), 0.01), Transform3D(Basis(), Vector3(s * 0.34, TUNDISH_TOP - 0.18, 0))))
		box.append(EnvMesh.piece(EnvMesh.box(Vector3(0.07, TUNDISH_TOP - 0.36, 0.07), 0.01), Transform3D(Basis(), Vector3(s * 0.3, (TUNDISH_TOP - 0.36) * 0.5, 0))))
	box.append(EnvMesh.piece(EnvMesh.box(Vector3(0.7, 0.05, 0.54), 0.01), Transform3D(Basis(), Vector3(0, TUNDISH_TOP - 0.36, 0))))
	box.append(EnvMesh.piece(EnvMesh.box(Vector3(0.12, 0.08, 0.6), 0.01), Transform3D(Basis(), Vector3(0, TUNDISH_TOP - 0.3, -0.5))))
	StationKit.add_merged(_tundish_node, box, paint)
	StationKit.label(_tundish_node, "GIESSAUTOMAT", Transform3D(Basis(), Vector3(0, TUNDISH_TOP - 0.18, 0.3)), 48, Color("#f0e2c4"), 800, 0.0011)


func _refresh_flasks() -> void:
	for f in _flask_nodes.size():
		if codes[f] != _flask_codes[f]:
			_flask_codes[f] = codes[f]
			var built := _build(codes[f]) if codes[f] != "" else {}
			var mesh: Mesh = built.get("mesh", null)
			_flask_metal[f].mesh = mesh
			_flask_imprint[f].mesh = mesh
		var top := FLASK.y - CAST_THICKNESS * 0.5 + 0.004
		_flask_metal[f].position = Vector3(0, top, 0)
		_flask_imprint[f].position = Vector3(0, top - 0.012, 0)
		_flask_imprint[f].visible = codes[f] != "" and states[f] == Flask.MOLDED and fills[f] < 0.05
	var owned := has_tundish()
	if _tundish_node:
		_tundish_node.visible = owned
	if _tundish_body and _tundish_body.get_child_count() > 0:
		(_tundish_body.get_child(0) as CollisionShape3D).disabled = not owned


func _update_art(delta: float) -> void:
	_press_anim = move_toward(_press_anim, 0.0, delta * 3.0)
	_shake_anim = move_toward(_shake_anim, 0.0, delta)
	if moving and not Network.is_sim_authority():
		phase = minf(phase + delta / INDEX_TIME, 1.0)
	if _tundish_node:
		_tundish_node.visible = has_tundish()
	if _press_head:
		_press_head.position.y = slot_position(MOLD_SLOT).y + 1.45 - sin(_press_anim * PI) * 0.62
	for f in _flask_nodes.size():
		_flask_nodes[f].position = flask_position(f)
		var shown := codes[f] != "" and fills[f] > 0.02
		_flask_metal[f].visible = shown
		if shown:
			MetalMaterial.set_fill(_metal_mats[f], fills[f], fills[f] < 0.999)
			MetalMaterial.set_temperature(_metal_mats[f], clampf(temps[f] * (0.5 + 0.5 * clampf(cools[f] / COOL_TIME, 0.0, 1.0)) if Network.is_sim_authority() else temps[f], 0.0, 1.0))
			var al := FoundryRules.alloy_for(mixes[f]) if Network.is_sim_authority() else &"iron"
			if _metal_mats[f].get_meta(&"alloy", &"") != al:
				MetalMaterial.set_alloy(_metal_mats[f], al)
		_flask_imprint[f].visible = codes[f] != "" and states[f] == Flask.MOLDED and fills[f] < 0.05
	if _grate:
		_grate.position = slot_position(SHAKEOUT_SLOT) + (Vector3(randf_range(-0.02, 0.02), 0, randf_range(-0.02, 0.02)) if _shake > 0.0 or _shake_anim > 0.0 else Vector3.ZERO)
	if _tundish_node and _tundish_node.visible:
		_tundish_melt.visible = tundish > 0.05
		_tundish_melt.position.y = TUNDISH_TOP - 0.33 + 0.28 * clampf(tundish / TUNDISH_CAPACITY, 0.0, 1.0)
		MetalMaterial.set_temperature(_tundish_mat, clampf(tundish_temp, 0.0, 1.0))
	_auto_stream.flow = auto_flow
	if auto_flow > 0.0:
		_auto_stream.set_endpoints(to_global(TUNDISH_POS + Vector3(0, TUNDISH_TOP - 0.32, -0.78)), to_global(slot_position(POUR_SLOT) + Vector3(0, FLASK.y, 0)))
