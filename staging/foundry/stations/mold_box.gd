class_name MoldBox
extends Node3D
## Open-face sand mold. Patterns from the model bench are pressed into the
## sand, players ram it firm, pour metal in, let it cool and smash it open.
## All gameplay runs on the host; peers mirror state for visuals.

enum State { EMPTY, PATTERNED, RAMMED, FILLING, COOLING, READY }

const BED := Vector3(1.5, 0.45, 1.1)
const CAST_SIZE := 0.5
const CAST_THICKNESS := 0.07
## Gameplay litres of melt per cubic metre of casting.
const LITRES_PER_M3 := 260.0
const RAMS_NEEDED := 6
const COOL_TIME := 4.5
const HITS_TO_BREAK := 3
const HITS_TO_BREAK_BARE_HANDS := 6
const SAFE_POUR_RATE := 0.75

@export var capacity := 2

var state := State.EMPTY
var patterns: Array[String] = []
var fills: Array[float] = []
var needs: Array[float] = []
var ram_quality := 0.0
var defects := {}
var cast_mix := {}
var metal_temperature := 0.0

var _rams := 0
var _ram_score := 0.0
var _last_ram_time := 0.0
var _last_pour_time := -10.0
var _pour_gap_flagged := false
var _cool_left := 0.0
var _hits := 0
var _built := {}               ## code -> CastMeshBuilder result
var _imprints: Array[MeshInstance3D] = []
var _metals: Array[MeshInstance3D] = []
var _sand: MeshInstance3D
var _sync_accum := 0.0


static func find_at(tree: SceneTree, point: Vector3) -> MoldBox:
	for node in tree.get_nodes_in_group(&"molds"):
		var m := node as MoldBox
		var local := m.to_local(point)
		if absf(local.x) <= BED.x * 0.5 + 0.05 and absf(local.z) <= BED.z * 0.5 + 0.05 \
				and local.y > BED.y - 0.6 and local.y < BED.y + 0.6:
			return m
	return null


func _ready() -> void:
	add_to_group(&"interactable")
	add_to_group(&"molds")
	var wood := Color("#9b6b43")
	_sand = WorldBuilder.add_box(self, BED, Vector3(0, BED.y * 0.5, 0), Color("#d8c194"), true).get_child(1) as MeshInstance3D
	for side in [-1, 1]:
		WorldBuilder.add_box(self, Vector3(BED.x + 0.12, BED.y + 0.06, 0.08), Vector3(0, (BED.y + 0.06) * 0.5, side * (BED.z * 0.5 + 0.04)), wood)
		WorldBuilder.add_box(self, Vector3(0.08, BED.y + 0.06, BED.z), Vector3(side * (BED.x * 0.5 + 0.04), (BED.y + 0.06) * 0.5, 0), wood)


func interact_point() -> Vector3:
	return global_position + Vector3(0, BED.y, 0)


func hint(_player: Node) -> String:
	match state:
		State.EMPTY:
			return "Leerer Formkasten – an der Werkbank ein Modell zeichnen"
		State.PATTERNED:
			return "[F] Sand stampfen (%d/%d)" % [_rams, RAMS_NEEDED]
		State.RAMMED:
			return "Bereit zum Gießen – Tiegel holen!"
		State.FILLING:
			return "Gießen… %d %%" % roundi(_total_fill() * 100)
		State.COOLING:
			return "Kühlt ab…"
		State.READY:
			return "[F] Form zerschlagen (mit Hammer schneller)"
	return ""


func interact(_player: Node) -> void:
	match state:
		State.PATTERNED:
			_ram()
		State.READY:
			hit(false)


func has_room() -> bool:
	return state in [State.EMPTY, State.PATTERNED] and patterns.size() < capacity


## Adds a drawing as a new cavity. Host only.
func add_pattern(code: String) -> bool:
	if not has_room():
		return false
	patterns.append(code)
	state = State.PATTERNED
	_rams = 0
	_ram_score = 0.0
	_broadcast_state()
	return true


func _ram() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var interval := now - _last_ram_time
	_last_ram_time = now
	_ram_score += 1.0 if _rams == 0 or (interval > 0.22 and interval < 0.9) else 0.45
	_rams += 1
	_fx_all(&"dust", interact_point())
	if _rams >= RAMS_NEEDED:
		ram_quality = _ram_score / RAMS_NEEDED
		state = State.RAMMED
		_prepare_fill()
	_broadcast_state()


func _prepare_fill() -> void:
	fills.clear()
	needs.clear()
	defects = {}
	cast_mix = {}
	for code in patterns:
		var built := _build(code)
		fills.append(0.0)
		needs.append(maxf(0.15, built.get("volume", 0.004) * LITRES_PER_M3))


## Melt arriving from a crucible. Host only.
func receive_metal(litres: float, temperature: float, mix: Dictionary, rate: float, delta: float) -> void:
	if state == State.EMPTY or state == State.PATTERNED:
		_fx_all(&"sparks", interact_point())
		if state == State.PATTERNED and not patterns.is_empty():
			# Pouring into loose sand: works, but ruins the surface.
			ram_quality = _ram_score / RAMS_NEEDED * 0.5
			state = State.RAMMED
			_prepare_fill()
		else:
			return
	if state == State.COOLING or state == State.READY:
		defects["flash"] = minf(1.0, defects.get("flash", 0.0) + litres)
		_fx_all(&"sparks", interact_point())
		return
	var now := Time.get_ticks_msec() / 1000.0
	if state == State.FILLING and now - _last_pour_time > 1.2 and not _pour_gap_flagged:
		defects["cold_shut"] = minf(1.0, defects.get("cold_shut", 0.0) + 0.5)
		_pour_gap_flagged = true
	_last_pour_time = now
	state = State.FILLING
	if rate > SAFE_POUR_RATE:
		defects["spatter"] = minf(1.0, defects.get("spatter", 0.0) + (rate - SAFE_POUR_RATE) * delta * 2.5)
		if randf() < delta * 10.0:
			_fx_all(&"sparks", interact_point())
	if temperature < 0.45:
		defects["misrun"] = minf(1.0, defects.get("misrun", 0.0) + delta * 0.6)
	for k in mix:
		cast_mix[k] = cast_mix.get(k, 0.0) + mix[k]
	metal_temperature = maxf(metal_temperature, temperature)
	_distribute(litres)
	if _total_fill() >= 0.999:
		state = State.COOLING
		_cool_left = COOL_TIME
		_broadcast_state()


## Gating tree: melt flows to every cavity in proportion to what it still needs.
func _distribute(litres: float) -> void:
	var missing := 0.0
	for i in fills.size():
		missing += (1.0 - fills[i]) * needs[i]
	if missing <= 0.0:
		return
	for i in fills.size():
		var share := litres * (1.0 - fills[i]) * needs[i] / missing
		fills[i] = minf(1.0, fills[i] + share / needs[i])


func _total_fill() -> float:
	var need := 0.0
	var have := 0.0
	for i in fills.size():
		need += needs[i]
		have += fills[i] * needs[i]
	return have / need if need > 0.0 else 0.0


func _physics_process(delta: float) -> void:
	if Network.is_sim_authority():
		_simulate(delta)
	_update_visuals()


func _simulate(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if state == State.FILLING and now - _last_pour_time > 1.2:
		_pour_gap_flagged = false
	if state == State.FILLING or state == State.COOLING:
		metal_temperature = maxf(0.0, metal_temperature - delta * 0.04)
	if state == State.COOLING:
		_cool_left -= delta
		if _cool_left <= 0.0:
			state = State.READY
			_hits = 0
			_broadcast_state()
	if Network.is_online() and (state == State.FILLING or state == State.COOLING):
		_sync_accum += delta
		if _sync_accum > 1.0 / 15.0:
			_sync_accum = 0.0
			_sync_fill.rpc(PackedFloat32Array(fills), metal_temperature, FoundryRules.alloy_for(cast_mix))


## Hammer (or bare hands) hit on a ready mold. Host only.
func hit(with_hammer: bool) -> void:
	if state != State.READY:
		return
	_hits += 1
	_fx_all(&"dust", interact_point())
	if _hits >= (HITS_TO_BREAK if with_hammer else HITS_TO_BREAK_BARE_HANDS):
		_break_open()


func _break_open() -> void:
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	var alloy := FoundryRules.alloy_for(cast_mix)
	_fx_all(&"sand_burst", interact_point())
	for i in patterns.size():
		var fill := fills[i] if i < fills.size() else 0.0
		var slot := to_global(_slot_position(i) + Vector3(0, 0.25, 0))
		if fill < 0.3:
			_popup_all(slot + Vector3(0, 0.6, 0), "Fehlguss!", Color("#ff6b5a"))
			continue
		var q := FoundryRules.score(ram_quality, fill, defects)
		var data := {type = "cast", code = patterns[i], alloy = alloy, quality = q, defects = defects.duplicate(),
			temperature = 0.45, pos = slot, size = CAST_SIZE, thickness = CAST_THICKNESS}
		var piece: CastPiece = world.spawn_entity(data) if world else null
		if piece:
			piece.apply_central_impulse(Vector3(randf_range(-0.6, 0.6), 3.2, randf_range(-0.6, 0.6)) * piece.mass)
			piece.apply_torque_impulse(Vector3(randf(), randf(), randf()) * 0.4 * piece.mass)
			var g := FoundryRules.grade(q)
			_popup_all(slot + Vector3(0, 0.8 + i * 0.25, 0), "%s!  %d $" % [g.name.to_upper(), piece.value()], g.color)
	patterns.clear()
	fills.clear()
	needs.clear()
	cast_mix = {}
	defects = {}
	metal_temperature = 0.0
	state = State.EMPTY
	_broadcast_state()


# --- Visuals ------------------------------------------------------------------

func _slot_position(i: int) -> Vector3:
	var top := BED.y
	match capacity:
		1:
			return Vector3(0, top, 0)
		2:
			return Vector3(-0.36 + 0.72 * i, top, 0)
		_:
			return Vector3(-0.36 + 0.72 * (i % 2), top, -0.27 + 0.54 * (i / 2))


func _build(code: String) -> Dictionary:
	if not _built.has(code):
		var drawing := Drawing.from_code(code)
		_built[code] = CastMeshBuilder.build(drawing, CAST_SIZE, CAST_THICKNESS) if drawing else {}
	return _built[code]


func _rebuild_cavities() -> void:
	for m in _imprints + _metals:
		m.queue_free()
	_imprints.clear()
	_metals.clear()
	for i in patterns.size():
		var built := _build(patterns[i])
		if built.is_empty():
			continue
		var imprint := MeshInstance3D.new()
		imprint.mesh = built.mesh
		imprint.material_override = WorldBuilder.material(Color("#8c7553"), 1.0)
		imprint.scale = Vector3(1, 0.06, 1)
		imprint.position = _slot_position(i) + Vector3(0, 0.002, 0)
		add_child(imprint)
		_imprints.append(imprint)
		var metal := MeshInstance3D.new()
		metal.mesh = built.mesh
		metal.material_override = MetalMaterial.create(&"alu")
		metal.position = _slot_position(i) + Vector3(0, CAST_THICKNESS * 0.5 - 0.02, 0)
		metal.visible = false
		add_child(metal)
		_metals.append(metal)


func _update_visuals() -> void:
	if _metals.size() != patterns.size():
		_rebuild_cavities()
	var alloy := FoundryRules.alloy_for(cast_mix)
	for i in _metals.size():
		var fill := fills[i] if i < fills.size() else 0.0
		var metal := _metals[i]
		metal.visible = fill > 0.001
		var mat := metal.material_override as ShaderMaterial
		mat.set_shader_parameter("base_color", Alloys.TABLE.get(alloy, Alloys.TABLE[&"alu"]).color)
		MetalMaterial.set_temperature(mat, metal_temperature)
		MetalMaterial.set_fill(mat, lerpf(-CAST_THICKNESS * 0.5, CAST_THICKNESS * 0.5, fill), fill < 0.999)


# --- Networking ---------------------------------------------------------------

func _broadcast_state() -> void:
	if Network.is_online() and multiplayer.is_server():
		_sync_state.rpc(state, PackedStringArray(patterns), PackedFloat32Array(fills), _rams, metal_temperature, FoundryRules.alloy_for(cast_mix))


@rpc("authority", "call_remote", "reliable")
func _sync_state(s: int, p: PackedStringArray, f: PackedFloat32Array, rams: int, temp: float, alloy: StringName) -> void:
	state = s as State
	patterns.assign(Array(p))
	fills.assign(Array(f))
	_rams = rams
	metal_temperature = temp
	cast_mix = {alloy: 1.0}


@rpc("authority", "call_remote", "unreliable_ordered")
func _sync_fill(f: PackedFloat32Array, temp: float, alloy: StringName) -> void:
	fills.assign(Array(f))
	metal_temperature = temp
	cast_mix = {alloy: 1.0}


func _fx_all(kind: StringName, pos: Vector3) -> void:
	_fx(kind, pos)
	if Network.is_online() and multiplayer.is_server():
		_fx_remote.rpc(kind, pos)


@rpc("authority", "call_remote", "unreliable")
func _fx_remote(kind: StringName, pos: Vector3) -> void:
	_fx(kind, pos)


func _fx(kind: StringName, pos: Vector3) -> void:
	match kind:
		&"dust":
			FoundryFX.dust(get_parent(), pos)
		&"sparks":
			FoundryFX.sparks(get_parent(), pos, 10)
		&"sand_burst":
			FoundryFX.sand_burst(get_parent(), pos, BED.x)


func _popup_all(pos: Vector3, text: String, color: Color) -> void:
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	if world:
		world.popup_all(pos, text, color)
