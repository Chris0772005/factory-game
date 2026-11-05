class_name BellPit
extends Node3D
## Casting pit for bells (Glockengießerei). The real loam method, as a game:
## the profile from the bench becomes a strickle board on a spindle; turning
## it (F, TURNS_NEEDED times) shapes the loam mold. Then one long pour, since
## a bell needs several crucibles and a pause makes a cold shut; it cools;
## knocking the loam open (hammer or hands) lifts the bell out, and it rings.
## Water on a hot bell cracks it. Host simulates, peers mirror the state.

enum State { EMPTY, PROFILED, TURNED, FILLING, COOLING, READY }

const TURNS_NEEDED := 8
const COOL_TIME := 16.0
const DIG_HITS := 2
const DIG_HITS_BARE_HANDS := 4
## Seconds without metal before the pour counts as interrupted (cold shut).
const POUR_GAP := 2.5
## Height of the brick rim; the loam floor inside sits at the same height.
const RIM := 0.45

## Mouth radius (m) of the bells this pit casts.
@export var mouth_radius := 0.35

var state := State.EMPTY
var code := ""
var turns := 0
var need := 1.0
var fill := 0.0
var metal_temperature := 0.0
var cast_mix := {}
var defects := {}
var cracked := false
var _cool_left := 0.0
var _hits := 0
var _last_pour := -10.0
var _gap_flagged := false
var _profile: BellProfile
var _sync_accum := 0.0
## Strickle rhythm: an even pace (0.3-1.0 s per turn) gives a clean mold.
var _turn_score := 0.0
var _last_turn_time := 0.0
var turn_quality := 0.0

var _spindle: Node3D
var _board: MeshInstance3D
var _form: MeshInstance3D
var _form_mat: ShaderMaterial
var _turn_anim := 0.0
var _shake := 0.0


static func find_at(tree: SceneTree, point: Vector3) -> BellPit:
	for node in tree.get_nodes_in_group(&"bell_pits"):
		var pit := node as BellPit
		var local := pit.to_local(point)
		if Vector2(local.x, local.z).length() <= pit.outer_radius() and local.y > 0.0 and local.y < RIM + 2.0:
			return pit
	return null


## The pit a worker is at: within `reach` of its rim.
static func near_worker(tree: SceneTree, body: Node3D, reach := 1.0) -> BellPit:
	var best: BellPit = null
	var best_d := reach
	for node in tree.get_nodes_in_group(&"bell_pits"):
		var pit := node as BellPit
		var p := pit.to_local(body.global_position)
		var d := maxf(Vector2(p.x, p.z).length() - pit.outer_radius(), 0.0)
		if d < best_d:
			best_d = d
			best = pit
	return best


func outer_radius() -> float:
	return mouth_radius + 0.45


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_to_group(&"interactable")
	add_to_group(&"bell_pits")
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = outer_radius()
	cyl.height = RIM
	shape.shape = cyl
	shape.position.y = RIM * 0.5
	body.add_child(shape)
	add_child(body)
	Network.peer_ready.connect(_on_peer_ready)
	_build_art()


func interact_point() -> Vector3:
	return global_position + Vector3(0, RIM + 0.3, 0)


func hint(_player: Node) -> String:
	match state:
		State.EMPTY:
			return "Leere Gießgrube – an der Profilbank eine Glocke zeichnen"
		State.PROFILED:
			return "[F] Schablone drehen (%d/%d)" % [turns, TURNS_NEEDED]
		State.TURNED:
			return "Lehmform fertig – %s l Metall in einem Zug gießen!" % _litres_text(need)
		State.FILLING:
			return "Gießen… %d %%  – nicht absetzen!" % roundi(fill / need * 100.0)
		State.COOLING:
			return "Glocke kühlt ab · %d s  (Wasser lässt sie springen!)" % ceili(maxf(_cool_left, 0.0))
		State.READY:
			return "[F] Lehmmantel aufschlagen (mit Hammer schneller)"
	return ""


func interact(_player: Node) -> void:
	if not Network.is_sim_authority():
		return
	match state:
		State.PROFILED:
			_turn()
		State.READY:
			hit(false)


## A profile from the bench. Host only. False if the pit is busy or the
## drawing is not a bell.
func add_profile(drawing_code: String) -> bool:
	if state != State.EMPTY:
		return false
	var profile := BellProfile.from_drawing(Drawing.from_code(drawing_code))
	if profile == null:
		return false
	code = drawing_code
	_profile = profile
	turns = 0
	_turn_score = 0.0
	state = State.PROFILED
	_rebuild_form()
	_broadcast_state()
	return true


func _turn() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var interval := now - _last_turn_time
	_last_turn_time = now
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	var step := 2 if world and world.has_upgrade(&"strickle_crank") else 1
	_turn_score += (1.0 if turns == 0 or (interval > 0.3 and interval < 1.0) else 0.45) * step
	turns = mini(turns + step, TURNS_NEEDED)
	_fx_all(&"turn")
	if turns >= TURNS_NEEDED:
		turn_quality = _turn_score / TURNS_NEEDED
		state = State.TURNED
		need = _profile.litres(mouth_radius)
		fill = 0.0
		cast_mix = {}
		defects = {}
		cracked = false
		_gap_flagged = false
		_last_pour = -10.0
	_broadcast_state()


## Melt from a crucible. Host only (Crucible._pour).
func receive_metal(litres: float, temperature: float, mix: Dictionary, rate: float, _delta: float) -> void:
	if state == State.COOLING or state == State.READY:
		defects["flash"] = minf(1.0, defects.get("flash", 0.0) + litres)
		return
	if state != State.TURNED and state != State.FILLING:
		_fx_all(&"spill")
		return
	var now := Time.get_ticks_msec() / 1000.0
	if state == State.FILLING and now - _last_pour > POUR_GAP and not _gap_flagged:
		defects["cold_shut"] = minf(1.0, defects.get("cold_shut", 0.0) + 0.6)
		_gap_flagged = true
	_last_pour = now
	state = State.FILLING
	if temperature < 0.45:
		defects["misrun"] = minf(1.0, defects.get("misrun", 0.0) + litres * 0.2)
	if rate > MoldBox.SAFE_POUR_RATE * 1.4:
		defects["spatter"] = minf(1.0, defects.get("spatter", 0.0) + litres * 0.1)
	for k in mix:
		cast_mix[k] = cast_mix.get(k, 0.0) + mix[k]
	metal_temperature = maxf(metal_temperature, temperature)
	fill = minf(need, fill + litres)
	if fill >= need * 0.999:
		state = State.COOLING
		_cool_left = COOL_TIME
		_broadcast_state()


## Water on the pit: a hot bell cracks. Host only.
func quench() -> bool:
	if state != State.COOLING:
		return false
	cracked = true
	state = State.READY
	_hits = 0
	metal_temperature = minf(metal_temperature, 0.12)
	_broadcast_state()
	_fx_all(&"quench")
	_popup(interact_point() + Vector3(0, 1.0, 0), "KNACK! Gesprungen…", Color("#ff6b5a"))
	return true


func quench_risk() -> float:
	return 1.0 if state == State.COOLING else 0.0


## Hammer or hands on the loam mantle. Host only.
func hit(with_hammer: bool) -> void:
	if state != State.READY:
		return
	_hits += 1
	_fx_all(&"hit")
	if _hits >= (DIG_HITS if with_hammer else DIG_HITS_BARE_HANDS):
		_dig_out()


func _dig_out() -> void:
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	var alloy := FoundryRules.alloy_for(cast_mix)
	var quality := FoundryRules.score(turn_quality, fill / maxf(need, 0.01), defects)
	_fx_all(&"burst")
	var bell: Bell = null
	if world:
		bell = world.spawn_entity({type = "bell", code = code, alloy = String(alloy), radius = mouth_radius,
			quality = quality, cracked = cracked, temperature = 0.5, pos = global_position + Vector3(0, RIM + 0.02, 0)})
	state = State.EMPTY
	code = ""
	turns = 0
	fill = 0.0
	_profile = null
	_rebuild_form()
	_broadcast_state()
	if bell:
		_present.call_deferred(bell)


## The reveal: a beat of silence, then the first stroke and the banner.
func _present(bell: Bell) -> void:
	await get_tree().create_timer(0.45).timeout
	if not is_instance_valid(bell):
		return
	bell.ring_all(1.0)
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	if world == null:
		return
	var good := not bell.cracked and bell.purity() >= 0.6
	var title := "GLOCKE IN %s!" % bell.note().to_upper() if not bell.cracked else "GESPRUNGEN!"
	world.banner_near(global_position, title, Color("#ffd75e") if good else Color("#ff6b5a"),
		"%s · %s · %d $" % [bell.verdict(), Alloys.display_name(bell.alloy), bell.value()], good)


func _physics_process(delta: float) -> void:
	if Network.is_sim_authority():
		if state == State.FILLING or state == State.COOLING:
			metal_temperature = maxf(0.0, metal_temperature - delta * 0.02)
		if state == State.COOLING:
			_cool_left -= delta
			if _cool_left <= 0.0:
				state = State.READY
				_hits = 0
				_broadcast_state()
				_fx_all(&"ready")
		if Network.is_online() and (state == State.FILLING or state == State.COOLING):
			_sync_accum += delta
			if _sync_accum > 1.0 / 10.0:
				_sync_accum = 0.0
				_sync_fill.rpc(fill, metal_temperature, _cool_left)
	_update_art(delta)


func _litres_text(l: float) -> String:
	return ("%.1f" % l).replace(".", ",")


# --- Networking ---------------------------------------------------------------

func _broadcast_state() -> void:
	if Network.is_online() and multiplayer.is_server():
		_sync_state.rpc(state, code, turns, need, fill, metal_temperature, cracked, _cool_left)


func _on_peer_ready(id: int, level: String) -> void:
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	if is_inside_tree() and multiplayer.is_server() and world and level == world.level_path():
		_sync_state.rpc_id(id, state, code, turns, need, fill, metal_temperature, cracked, _cool_left)


@rpc("authority", "call_remote", "reliable")
func _sync_state(s: int, c: String, t: int, n: float, f: float, temp: float, crack: bool, cool: float) -> void:
	state = s as State
	if c != code:
		code = c
		_profile = BellProfile.from_drawing(Drawing.from_code(c)) if c != "" else null
		_rebuild_form()
	turns = t
	need = n
	fill = f
	metal_temperature = temp
	cracked = crack
	_cool_left = cool


@rpc("authority", "call_remote", "unreliable_ordered")
func _sync_fill(f: float, temp: float, cool: float) -> void:
	fill = f
	metal_temperature = temp
	_cool_left = cool


func _fx_all(kind: StringName) -> void:
	_fx(kind)
	if Network.is_online() and multiplayer.is_server():
		_fx_remote.rpc(kind)


@rpc("authority", "call_remote", "unreliable")
func _fx_remote(kind: StringName) -> void:
	_fx(kind)


func _fx(kind: StringName) -> void:
	var top := global_position + Vector3(0, RIM + 0.2, 0)
	match kind:
		&"turn":
			_turn_anim = 1.0
			FoundryFX.dust(get_parent(), top)
			Sfx.play(&"ram_thud", top, -6.0)
		&"hit":
			_shake = 1.0
			FoundryFX.dust(get_parent(), top + Vector3(0, 0.3, 0))
			Sfx.play(&"hammer_clank", top, 0.0)
			Juice.impact(top, 0.35, 0.06)
		&"burst":
			FoundryFX.sand_burst(get_parent(), top + Vector3(0, 0.2, 0), mouth_radius * 3.0)
			Sfx.play(&"sand_burst", top, 2.0)
			Juice.reveal(top)
		&"ready":
			FoundryFX.steam_puff(get_parent(), top, 0.8)
			Sfx.play(&"pop", top, -2.0, 0.0)
		&"quench":
			for k in 5:
				FoundryFX.steam_puff(get_parent(), top + Vector3(randf_range(-0.3, 0.3), 0.2, randf_range(-0.3, 0.3)), 2.5)
			Sfx.play(&"steam_blast", top, 2.0)
			Sfx.play(&"hammer_clank", top, -2.0)
		&"spill":
			FoundryFX.sparks(get_parent(), top, 12)
			Sfx.play(&"sparks", top, -6.0)


func _popup(pos: Vector3, text: String, color: Color) -> void:
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	if world:
		world.popup_all(pos, text, color)


# --- Art ------------------------------------------------------------------------

func _build_art() -> void:
	if not StationKit.visual():
		return
	var brick := EnvMesh.material("pit_brick", "res://shaders/env_plaster.gdshader", {
		brick = Color("#9c553f"), mortar = Color("#bfae95"), brickwork = 1.0})
	var r := outer_radius()
	var ring := PackedVector2Array([Vector2(r - 0.18, RIM), Vector2(r - 0.18, 0.0), Vector2(r, 0.0), Vector2(r, RIM),
		Vector2(r - 0.02, RIM + 0.03), Vector2(r - 0.16, RIM + 0.03), Vector2(r - 0.18, RIM)])
	StationKit.add(self, StationKit.lathe(ring, 28, 40.0), brick)
	# Rammed loam floor inside the rim.
	var loam := StationKit.clay("pit_loam", {body_color = Color("#8a6a4a"), glaze_color = Color("#a0805c"), glaze = 0.2,
		cracks = 0.5, roughness_base = 0.95})
	StationKit.add(self, EnvMesh.cylinder(r - 0.18, r - 0.18, 0.04, 28), loam, Transform3D(Basis(), Vector3(0, RIM - 0.01, 0)))
	# Spindle with the strickle board (shaped like the profile once one arrives).
	var wood := StationKit.wood("strickle", {base_color = Color("#a8825a"), weathering = 0.2})
	var iron := StationKit.metal("spindle", {steel_color = Color("#4a4744"), rust = 0.4})
	_spindle = Node3D.new()
	_spindle.position.y = RIM
	add_child(_spindle)
	StationKit.add(_spindle, EnvMesh.cylinder(0.025, 0.025, 1.7, 8), iron, Transform3D(Basis(), Vector3(0, 0.85, 0)))
	_board = MeshInstance3D.new()
	_board.material_override = wood
	_spindle.add_child(_board)
	_form_mat = StationKit.unique("station_clay", {body_color = Color("#7d5d40"), glaze_color = Color("#9a7754"), glaze = 0.3,
		cracks = 0.6, roughness_base = 0.9, glow_from = 0.0})
	_form = MeshInstance3D.new()
	_form.material_override = _form_mat
	_form.position.y = RIM
	add_child(_form)
	_rebuild_form()


## The loam mantle (bell outline, a little fatter) and the strickle board.
func _rebuild_form() -> void:
	if _form == null:
		return
	if _profile == null:
		_form.mesh = null
		_board.mesh = null
		return
	var outline := _profile.outline(mouth_radius)
	var mantle := PackedVector2Array()
	for p in outline:
		mantle.append(Vector2(p.x + 0.06, p.y))
	var top := outline[outline.size() - 1]
	mantle.append(Vector2(0.06, top.y + 0.08))
	mantle.append(Vector2(0.0, top.y + 0.08))
	_form.mesh = StationKit.lathe(mantle, 28, 40.0)
	# Board: a flat plank whose inner edge follows the outline.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in outline.size() - 1:
		var a := outline[i]
		var b := outline[i + 1]
		var a0 := Vector3(a.x + 0.065, a.y, 0)
		var b0 := Vector3(b.x + 0.065, b.y, 0)
		var a1 := Vector3(a.x + 0.3, a.y, 0)
		var b1 := Vector3(b.x + 0.3, b.y, 0)
		for face: float in [1.0, -1.0]:
			var off := Vector3(0, 0, face * 0.015)
			st.set_normal(Vector3(0, 0, face))
			if face > 0.0:
				st.add_vertex(a0 + off); st.add_vertex(b0 + off); st.add_vertex(b1 + off)
				st.add_vertex(a0 + off); st.add_vertex(b1 + off); st.add_vertex(a1 + off)
			else:
				st.add_vertex(a0 + off); st.add_vertex(b1 + off); st.add_vertex(b0 + off)
				st.add_vertex(a0 + off); st.add_vertex(a1 + off); st.add_vertex(b1 + off)
	_board.mesh = st.commit()


func _update_art(delta: float) -> void:
	if _form == null:
		return
	var turning := state == State.PROFILED
	_board.visible = turning
	# The mantle grows as it is turned, and stays until the bell is dug out.
	var shaped := clampf(float(turns) / TURNS_NEEDED, 0.0, 1.0) if state == State.PROFILED else (1.0 if state >= State.TURNED else 0.0)
	_form.visible = shaped > 0.0
	_form.scale = Vector3(1.0, maxf(shaped, 0.05), 1.0)
	if _turn_anim > 0.0:
		_turn_anim = maxf(0.0, _turn_anim - delta * 2.5)
		_spindle.rotation.y += delta * 5.0
	_shake = maxf(0.0, _shake - delta * 4.0)
	_form.position.x = sin(_shake * 50.0) * _shake * 0.015
	var heat := metal_temperature if state >= State.FILLING else 0.0
	_form_mat.set_shader_parameter(&"heat", heat * 0.8)
	_form_mat.set_shader_parameter(&"cracks", 0.6 + (0.4 if state == State.READY else 0.0))
