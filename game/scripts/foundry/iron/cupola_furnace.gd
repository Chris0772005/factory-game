class_name CupolaFurnace
extends Node3D
## Kupolofen: the Eisenhalle's shaft furnace. Charges (iron baskets, bronze
## ingots, any scrap) go into the skip at its foot and are hoisted to the
## charging door; the blower (hold F, more hands = more wind) keeps the
## fire hot; the melt collects in the hearth. At the tap hole F opens the
## tap ("Abstich!") and a thick stream runs down the trough into whatever
## stands below – the lowered ladle, a crucible or the floor. F again
## plugs it. Host simulates, peers mirror at 10 Hz. Faces +Z (the trough).

const SHAFT_RADIUS := 0.72
const SHAFT_HEIGHT := 4.6
const BATH_CAPACITY := 120.0
const TAP_RATE := 3.2           ## litres per second through the open tap
const MELT_TIME := 1.1          ## seconds per charge at full heat
const HEAT_PER_SECOND := 0.16   ## per worker on the blower
const HEAT_DECAY := 0.028
const CRANK_WINDOW_MS := 140
## Skip (charging bucket) at the foot, in local space: centre and inner size.
const SKIP_POS := Vector3(1.35, 0.0, -0.1)
const SKIP_SIZE := Vector3(0.95, 0.55, 0.8)
## End of the tap trough (where the stream leaves it), local.
const TROUGH_END := Vector3(0.0, 2.05, 1.42)
const BLOWER_POS := Vector3(-1.45, 0.0, 0.25)

var heat := 0.0
var bath := 0.0
var mix := {}
var temperature := 0.0
var tap_open := false
var charge: Array = []          ## melt mixes (Dictionary) waiting in the shaft
var pour_target := Vector3.ZERO
var _melt_progress := 0.0
var _blowers := {}
var _crew := 0
var _sync_accum := 0.0
var _skip_anim := 0.0
var _remote_charges := 0

var _tap: TapHole
var _stream: PourStream
var _roar: AudioStreamPlayer3D
var _hiss: AudioStreamPlayer3D
var _fire: FurnaceFire
var _glow: OmniLight3D
var _tap_glow_mat: StandardMaterial3D
var _skip_bucket: Node3D
var _fan: Node3D


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_to_group(&"interactable")
	add_to_group(&"cupolas")
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = SHAFT_RADIUS + 0.05
	cyl.height = SHAFT_HEIGHT
	shape.shape = cyl
	shape.position.y = SHAFT_HEIGHT * 0.5
	body.add_child(shape)
	add_child(body)
	# Skip walls (open top) and the blower box.
	for side: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var size := Vector3(0.06, SKIP_SIZE.y, SKIP_SIZE.z) if side.x != 0.0 else Vector3(SKIP_SIZE.x, SKIP_SIZE.y, 0.06)
		var off := Vector3(side.x * SKIP_SIZE.x * 0.5, SKIP_SIZE.y * 0.5, side.z * SKIP_SIZE.z * 0.5)
		StationKit.box_collider(self, size, Transform3D(Basis(), SKIP_POS + off))
	StationKit.box_collider(self, Vector3(0.8, 1.0, 0.7), Transform3D(Basis(), BLOWER_POS + Vector3(0, 0.5, 0)))
	_tap = TapHole.new()
	_tap.cupola = self
	_tap.position = Vector3(0.6, 1.25, 1.15)
	add_child(_tap)
	_roar = Sfx.make_loop(self, &"furnace_loop")
	_roar.position.y = 1.5
	_roar.pitch_scale = 0.7
	_hiss = Sfx.make_loop(self, &"pour_loop")
	_stream = PourStream.new()
	_stream.top_level = true
	_stream.max_radius = 0.085
	add_child(_stream)
	_build_art()


# --- Blower (the furnace's own interact point) -----------------------------------

func interact_point() -> Vector3:
	return to_global(BLOWER_POS + Vector3(0, 1.0, 0.45))


func hint(_player: Node) -> String:
	var line := "[F halten] Gebläse kurbeln · Hitze %d %%" % roundi(heat * 100)
	if _crew > 1:
		line += " · %d Leute!" % _crew
	line += " · Bad %s l" % roundi(bath)
	if bath > 0.05:
		line += " %s" % Alloys.display_name(alloy())
	var waiting := charge.size() if Network.is_sim_authority() else _remote_charges
	if waiting > 0:
		line += " · %d Ladungen im Schacht" % waiting
	return line


func interact(player: Node) -> void:
	interact_tick(player, 0.0)


func interact_tick(player: Node, _delta: float) -> void:
	if not Network.is_sim_authority():
		return
	_blowers[player.get_instance_id()] = Time.get_ticks_msec()


## Tap hole: F toggles the tap. Host only.
func toggle_tap() -> void:
	if not Network.is_sim_authority():
		return
	if not tap_open and bath < 0.05:
		return
	tap_open = not tap_open
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	if tap_open:
		Sfx.play(&"sparks", to_global(TROUGH_END))
		if world:
			world.popup_all(to_global(TROUGH_END) + Vector3(0, 1.0, 0), "ABSTICH!", Color("#ffb347"))
	else:
		Sfx.play(&"hammer_clank", to_global(TROUGH_END), -4.0)
	_sync_now()


func tap_hint() -> String:
	if tap_open:
		return "[F] Stopfen – Abstich schließen · %s l im Bad" % roundi(bath)
	if bath < 0.05:
		return "Abstich · noch keine Schmelze (Gichtkübel beschicken, Gebläse kurbeln)"
	var below := "Pfanne drunter ✓" if Ladle.find_at(get_tree(), _probe_below()) else "nichts drunter!"
	return "[F] Abstich öffnen · %s l %s, %d °C · %s" % [roundi(bath), Alloys.display_name(alloy()), roundi(200 + temperature * 1300), below]


func alloy() -> StringName:
	return FoundryRules.alloy_for(mix)


func _probe_below() -> Vector3:
	var p := to_global(TROUGH_END)
	p.y = 1.5
	return p


func _physics_process(delta: float) -> void:
	_skip_anim = move_toward(_skip_anim, 0.0, delta * 0.8)
	_update_art(delta)
	if not Network.is_sim_authority():
		return
	var now := Time.get_ticks_msec()
	_crew = 0
	for id in _blowers.keys():
		if now - int(_blowers[id]) <= CRANK_WINDOW_MS:
			_crew += 1
		else:
			_blowers.erase(id)
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	var decay := HEAT_DECAY * (0.5 if world and world.has_upgrade(&"hot_blast") else 1.0)
	heat = clampf(heat + HEAT_PER_SECOND * _crew * delta - decay * delta, 0.0, 1.0)
	_take_charges(world)
	_melt(delta)
	if tap_open:
		if bath <= 0.001:
			tap_open = false
			_sync_now()
		else:
			_tap_flow(delta)
	if Network.is_online():
		_sync_accum += delta
		if _sync_accum > 0.1:
			_sync_accum = 0.0
			_sync_now()


func _take_charges(world: GameWorld) -> void:
	if world == null:
		return
	for node in world.entities.get_children():
		var item := node as Item
		if item == null or item.is_held() or item.is_queued_for_deletion():
			continue
		var mixed := item.has_method(&"melt_mix")
		if not mixed and not FoundryRules.SCRAP.has(item.kind):
			continue
		var p := to_local(item.global_position) - SKIP_POS
		if absf(p.x) < SKIP_SIZE.x * 0.5 and absf(p.z) < SKIP_SIZE.z * 0.5 and p.y > -0.05 and p.y < SKIP_SIZE.y + 0.5:
			var m: Dictionary = item.melt_mix() if mixed else {FoundryRules.SCRAP[item.kind].metal: FoundryRules.SCRAP[item.kind].amount}
			charge.append(m)
			_skip_anim = 1.0
			Sfx.play(&"scrap_clatter", to_global(SKIP_POS + Vector3(0, 0.5, 0)))
			item.queue_free()
			_skip_fx_all()


func _melt(delta: float) -> void:
	temperature = move_toward(temperature, heat, delta * 0.12)
	if charge.is_empty() or heat < 0.35 or bath >= BATH_CAPACITY:
		return
	_melt_progress += delta * heat / MELT_TIME
	if _melt_progress >= 1.0:
		_melt_progress = 0.0
		var next: Dictionary = charge.pop_front()
		for metal in next:
			var add := minf(next[metal], BATH_CAPACITY - bath)
			mix[metal] = mix.get(metal, 0.0) + add
			bath += add


func _tap_flow(delta: float) -> void:
	var litres := minf(bath, TAP_RATE * delta)
	var from := to_global(TROUGH_END)
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 3.0)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	pour_target = hit.position if hit else from + Vector3.DOWN * 1.7
	var share := {}
	for k in mix:
		share[k] = mix[k] / maxf(bath, 0.0001) * litres
		mix[k] -= share[k]
	bath -= litres
	MeltTargets.deliver(get_tree(), pour_target, litres, temperature, share, TAP_RATE, delta, self)
	if bath <= 0.001:
		bath = 0.0
		mix.clear()


func _sync_now() -> void:
	if Network.is_online() and multiplayer.is_server():
		_sync.rpc(heat, bath, temperature, alloy(), tap_open, charge.size(), pour_target, _crew)


@rpc("authority", "call_remote", "unreliable_ordered")
func _sync(h: float, b: float, t: float, al: StringName, open: bool, charges: int, target: Vector3, crew: int) -> void:
	heat = h
	bath = b
	temperature = t
	mix = {al: b}
	tap_open = open
	pour_target = target
	_crew = crew
	_remote_charges = charges


func _skip_fx_all() -> void:
	if Network.is_online() and multiplayer.is_server():
		_skip_fx.rpc()


@rpc("authority", "call_remote", "unreliable")
func _skip_fx() -> void:
	_skip_anim = 1.0
	Sfx.play(&"scrap_clatter", to_global(SKIP_POS + Vector3(0, 0.5, 0)))


# --- Art -----------------------------------------------------------------------------

func _build_art() -> void:
	_fire = FurnaceFire.new()
	_fire.radius = 0.5
	_fire.height = 1.1
	_fire.light_energy = 2.2
	_fire.light_range = 7.0
	_fire.position.y = SHAFT_HEIGHT - 0.2
	add_child(_fire)
	_glow = OmniLight3D.new()
	_glow.light_color = Color("#ff8a3a")
	_glow.omni_range = 4.5
	_glow.light_energy = 0.0
	_glow.position = TROUGH_END + Vector3(0, -0.4, 0.2)
	add_child(_glow)
	_skip_bucket = Node3D.new()
	add_child(_skip_bucket)
	_fan = Node3D.new()
	_fan.position = BLOWER_POS + Vector3(0, 0.55, 0.38)
	add_child(_fan)
	if not StationKit.visual():
		return
	var shell := StationKit.metal("cupola_shell", {steel_color = Color("#3f3b38"), rust = 0.55, dents = 0.3,
		metallic_steel = 0.45, roughness_steel = 0.7, soot = 0.6, soot_bottom = 0.2, soot_top = 0.8})
	var brick := StationKit.clay("cupola_brick", {body_color = Color("#8c4a35"), soot = 0.5, cracks = 0.3})
	var r := SHAFT_RADIUS
	# Shaft on four legs over a sand bed, banded, with a spark arrester cap.
	var outline := PackedVector2Array([Vector2(0.0, 0.7), Vector2(r, 0.7), Vector2(r, SHAFT_HEIGHT - 0.3),
		Vector2(r - 0.1, SHAFT_HEIGHT), Vector2(r - 0.18, SHAFT_HEIGHT)])
	StationKit.add(self, StationKit.lathe(outline, 28, 40.0), shell)
	var rig := []
	for k in 4:
		var a := PI * 0.25 + k * PI * 0.5
		rig.append(EnvMesh.piece(EnvMesh.box(Vector3(0.14, 0.72, 0.14), 0.01), Transform3D(Basis(), Vector3(sin(a) * (r - 0.1), 0.36, cos(a) * (r - 0.1)))))
	for y: float in [1.0, 1.9, 2.8, 3.7]:
		rig.append(EnvMesh.piece(StationKit.lathe(PackedVector2Array([Vector2(r, y - 0.05), Vector2(r + 0.025, y - 0.04),
			Vector2(r + 0.025, y + 0.04), Vector2(r, y + 0.05)]), 28, 60.0), Transform3D()))
	# Wind box ring with tuyere pipes and the blast main to the blower.
	rig.append(EnvMesh.piece(StationKit.lathe(PackedVector2Array([Vector2(r, 1.15), Vector2(r + 0.2, 1.2), Vector2(r + 0.2, 1.45), Vector2(r, 1.5)]), 28, 50.0), Transform3D()))
	rig.append(EnvMesh.piece(StationKit.tube(PackedVector3Array([BLOWER_POS + Vector3(0.3, 0.75, 0), Vector3(-r - 0.3, 1.32, 0.15), Vector3(-r - 0.1, 1.32, 0.1)]), 0.12, 10), Transform3D()))
	StationKit.add_merged(self, rig, shell)
	# Brick-lined tap trough and the glowing tap hole.
	var trough := []
	var mid := (Vector3(0, 2.22, r) + TROUGH_END) * 0.5
	var dir := (TROUGH_END - Vector3(0, 2.22, r))
	var basis := Basis.looking_at(dir.normalized(), Vector3.UP)
	trough.append(EnvMesh.piece(EnvMesh.box(Vector3(0.36, 0.14, dir.length() + 0.1), 0.02), Transform3D(basis, mid)))
	StationKit.add_merged(self, trough, brick)
	var rails := []
	for s: float in [-1.0, 1.0]:
		rails.append(EnvMesh.piece(EnvMesh.box(Vector3(0.05, 0.12, dir.length() + 0.1), 0.01), Transform3D(basis, mid + basis.x * 0.17 * s + Vector3(0, 0.08, 0))))
	# Brace from the shaft under the trough (the ladle goes under its end).
	rails.append(EnvMesh.piece(StationKit.tube(PackedVector3Array([Vector3(0, 1.55, r), mid + Vector3(0, -0.08, 0)]), 0.04, 6), Transform3D()))
	StationKit.add_merged(self, rails, shell)
	_tap_glow_mat = StandardMaterial3D.new()
	_tap_glow_mat.albedo_color = Color("#2a1a12")
	_tap_glow_mat.emission_enabled = true
	_tap_glow_mat.emission = Color("#ff6a1a")
	_tap_glow_mat.emission_energy_multiplier = 0.0
	var hole := MeshInstance3D.new()
	hole.mesh = EnvMesh.cylinder(0.08, 0.08, 0.05, 12)
	hole.material_override = _tap_glow_mat
	hole.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 2.25, r + 0.01))
	add_child(hole)
	StationKit.label(self, "KUPOLOFEN", Transform3D(Basis(), Vector3(0, 3.25, r + 0.04)), 96, Color("#f0e2c4"), 800, 0.0018)
	# Skip: an inclined rail up to the charging door, the bucket rides it.
	var paint := StationKit.metal("crane_paint", {steel_color = Color("#d9a521"), rust = 0.25, dents = 0.2,
		metallic_steel = 0.3, roughness_steel = 0.55})
	var skip_rig := []
	var door := Vector3(r + 0.05, SHAFT_HEIGHT - 0.7, -0.1)
	for s: float in [-1.0, 1.0]:
		var foot := SKIP_POS + Vector3(SKIP_SIZE.x * 0.5 + 0.08, 0.0, s * 0.34)
		var top := door + Vector3(0.12, 0.3, s * 0.34)
		skip_rig.append(EnvMesh.piece(StationKit.tube(PackedVector3Array([foot, top]), 0.035, 6), Transform3D()))
	skip_rig.append(EnvMesh.piece(EnvMesh.box(Vector3(0.12, 0.3, 0.5), 0.01), Transform3D(Basis(), door + Vector3(0.05, 0.1, 0))))
	StationKit.add_merged(self, skip_rig, steel_dark())
	var hopper := []
	for side: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var size := Vector3(0.05, SKIP_SIZE.y, SKIP_SIZE.z + 0.05) if side.x != 0.0 else Vector3(SKIP_SIZE.x + 0.05, SKIP_SIZE.y, 0.05)
		hopper.append(EnvMesh.piece(EnvMesh.box(size, 0.01), Transform3D(Basis(), SKIP_POS + Vector3(side.x * SKIP_SIZE.x * 0.5, SKIP_SIZE.y * 0.5, side.z * SKIP_SIZE.z * 0.5))))
	hopper.append(EnvMesh.piece(EnvMesh.box(Vector3(SKIP_SIZE.x, 0.04, SKIP_SIZE.z), 0.01), Transform3D(Basis(), SKIP_POS + Vector3(0, 0.02, 0))))
	StationKit.add_merged(self, hopper, paint)
	StationKit.label(self, "GICHTKÜBEL", Transform3D(Basis(), SKIP_POS + Vector3(0, SKIP_SIZE.y * 0.55, SKIP_SIZE.z * 0.5 + 0.03)), 56, Color("#2a2522"), 800, 0.0012)
	StationKit.add(_skip_bucket, EnvMesh.box(Vector3(0.5, 0.3, 0.55), 0.03), steel_dark(), Transform3D())
	# Blower: a cast housing with a big hand crank.
	var housing := []
	housing.append(EnvMesh.piece(EnvMesh.cylinder(0.42, 0.42, 0.34, 20), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), BLOWER_POS + Vector3(0, 0.55, 0))))
	housing.append(EnvMesh.piece(EnvMesh.box(Vector3(0.7, 0.18, 0.6), 0.02), Transform3D(Basis(), BLOWER_POS + Vector3(0, 0.09, 0))))
	StationKit.add_merged(self, housing, paint)
	var crank := []
	crank.append(EnvMesh.piece(EnvMesh.box(Vector3(0.05, 0.34, 0.04), 0.01), Transform3D(Basis(), Vector3(0, 0.17, 0))))
	crank.append(EnvMesh.piece(EnvMesh.cylinder(0.025, 0.025, 0.16, 8), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.32, 0.08))))
	StationKit.add_merged(_fan, crank, steel_dark())
	StationKit.label(self, "GEBLÄSE", Transform3D(Basis(), BLOWER_POS + Vector3(0, 0.12, 0.31)), 48, Color("#2a2522"), 800, 0.0012)


func steel_dark() -> ShaderMaterial:
	return StationKit.metal("cupola_rig", {steel_color = Color("#2f2d2b"), rust = 0.4, metallic_steel = 0.5})


func _update_art(delta: float) -> void:
	_fire.heat = heat
	_roar.volume_db = linear_to_db(maxf(0.001, heat)) - 1.0
	if heat > 0.02 and not _roar.playing:
		_roar.play()
	elif heat <= 0.02 and _roar.playing:
		_roar.stop()
	_fan.rotation.z -= delta * (2.0 + 9.0 * minf(_crew, 3)) if _crew > 0 else 0.0
	var door := Vector3(SHAFT_RADIUS + 0.25, SHAFT_HEIGHT - 0.55, -0.1)
	var foot := SKIP_POS + Vector3(0, 0.2, 0)
	var u := sin(_skip_anim * PI)
	_skip_bucket.position = foot.lerp(door, u)
	_skip_bucket.visible = _skip_anim > 0.0
	var flowing := tap_open and bath > 0.0
	if _tap_glow_mat:
		_tap_glow_mat.emission_energy_multiplier = (3.0 if flowing else 0.6 * temperature) if bath > 0.0 else 0.0
	_glow.light_energy = 2.4 if flowing else 0.0
	_stream.flow = 1.0 if flowing else 0.0
	if flowing:
		_stream.set_endpoints(to_global(TROUGH_END), pour_target)
		_hiss.global_position = pour_target
		if not _hiss.playing:
			_hiss.play()
	elif _hiss.playing:
		_hiss.stop()


## The tap hole by the trough: its own interact point.
class TapHole:
	extends Node3D

	var cupola: CupolaFurnace

	func _ready() -> void:
		add_to_group(&"interactable")

	func interact_point() -> Vector3:
		return global_position

	func hint(_player: Node) -> String:
		return cupola.tap_hint()

	func interact(_player: Node) -> void:
		cupola.toggle_tap()
