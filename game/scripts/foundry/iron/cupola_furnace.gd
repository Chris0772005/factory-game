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
	# (The soot used to reach full strength at 0.8 m: by day the whole shaft was a black column. Now
	# the plates are rusty steel and the soot gathers toward the charging door and the cap.)
	var shell := StationKit.metal("cupola_shell", {steel_color = Color("#6a625b"), rust = 0.6, dents = 0.3,
		metallic_steel = 0.4, roughness_steel = 0.7, soot = 0.5, soot_bottom = 2.6, soot_top = 4.8})
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
	var paint := StationKit.metal("crane_paint", {paint_color = Color("#d9a521"), paint = 0.92, rust = 0.3, dents = 0.1,
		roughness_paint = 0.5})
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
	_build_details()


## The small parts of a riveted and bolted furnace (MachineDetail, TECH_SPEC Modul Y, Stufe U12):
## rivets round every hoop and down the lapped plate seams, bolts round the wind box and on its
## peep-hole covers, flanges on the blast main with a gauge at its bend, foot plates under the legs,
## a cast frame round the tap hole, rivets on the trough's cheeks and the charging box, bolts on the
## blower, welds where the shaft's parts meet, and the maker's plate.
func _build_details() -> void:
	var r := SHAFT_RADIUS
	var d := MachineDetail.Parts.new()
	var bands: Array[float] = [1.0, 1.9, 2.8, 3.7]
	for y in bands:
		MachineDetail.rivets_around(d, Vector3(0, y, 0), Vector3.UP, r + 0.025, 26, 0.022, true)
	# The courses of plate between the hoops (and the wind box): each lapped in three places, two rows
	# of rivets to a lap, the laps of one course standing between those of the next.
	var courses := [Vector2(0.74, 0.93), Vector2(1.54, 1.83), Vector2(1.97, 2.73), Vector2(2.87, 3.63), Vector2(3.77, SHAFT_HEIGHT - 0.36)]
	for i in courses.size():
		var course: Vector2 = courses[i]
		var count := maxi(roundi((course.y - course.x) / 0.1) + 1, 2)
		for k in 3:
			for row: float in [-0.028, 0.028]:
				var a := TAU * (k + 0.5 * (i % 2)) / 3.0 + 0.35 + row
				var dir := Vector3(sin(a), 0, cos(a))
				MachineDetail.rivet_row(d, dir * r + Vector3(0, course.x, 0), dir * r + Vector3(0, course.y, 0), count, dir, 0.02, true)
	# Wind box: its outer plate is bolted to the two rings, and four covers let one look at the tuyeres.
	for y: float in [1.235, 1.415]:
		MachineDetail.bolts_around(d, Vector3(0, y, 0), Vector3.UP, r + 0.2, 18, 0.024, true)
	for k in 4:
		var a := PI * 0.25 + k * PI * 0.5
		var dir := Vector3(sin(a), 0, cos(a))
		var at := dir * (r + 0.2) + Vector3(0, 1.325, 0)
		d.dark.append(EnvMesh.piece(EnvMesh.cylinder(0.062, 0.066, 0.018, 14), Transform3D(StationKit.basis_y(dir), at + dir * 0.009), 0.5))
		MachineDetail.bolt_circle(d, at + dir * 0.018, dir, 0.046, 4, 0.012, true, PI * 0.25)
	# Blast main: a flange where it leaves the blower and one where it enters the wind box.
	var p0 := BLOWER_POS + Vector3(0.3, 0.75, 0)
	var p1 := Vector3(-r - 0.3, 1.32, 0.15)
	var p2 := Vector3(-r - 0.1, 1.32, 0.1)
	MachineDetail.flange(d, p0.lerp(p1, 0.22), p1 - p0, 0.18, 0.018, 8, 0.02, true)
	MachineDetail.flange(d, p1.lerp(p2, 0.38), p2 - p1, 0.18, 0.018, 8, 0.02, true)
	# Legs: a foot plate with four anchor bolts, and two bolts each way into the shaft's bottom ring.
	for k in 4:
		var a := PI * 0.25 + k * PI * 0.5
		var foot := Vector3(sin(a), 0, cos(a)) * (r - 0.1)
		d.dark.append(EnvMesh.piece(EnvMesh.box(Vector3(0.27, 0.016, 0.27), 0.003), Transform3D(Basis(), foot + Vector3(0, 0.008, 0)), 0.3))
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				MachineDetail.bolt(d, foot + Vector3(sx * 0.1, 0.016, sz * 0.1), Vector3.UP, 0.024, true)
		for y: float in [0.6, 0.67]:
			MachineDetail.bolt(d, foot + Vector3(signf(foot.x) * 0.07, y, 0), Vector3(signf(foot.x), 0, 0), 0.02, true)
			MachineDetail.bolt(d, foot + Vector3(0, y, signf(foot.z) * 0.07), Vector3(0, 0, signf(foot.z)), 0.02, true)
	# Tap hole: a cast frame bolted over it (the glowing hole stands a little proud of it).
	d.dark.append(EnvMesh.piece(EnvMesh.box(Vector3(0.34, 0.3, 0.03), 0.006), Transform3D(Basis(), Vector3(0, 2.25, r + 0.005)), 0.6))
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			MachineDetail.bolt(d, Vector3(sx * 0.135, 2.25 + sy * 0.115, r + 0.02), Vector3.BACK, 0.022, true)
	# Trough: its iron cheeks are riveted along their length.
	var start := Vector3(0, 2.22, r)
	var run := TROUGH_END - start
	var along := run.normalized()
	var side := along.cross(Vector3.UP).normalized()
	for s: float in [-1.0, 1.0]:
		var cheek := (start + TROUGH_END) * 0.5 + Vector3(0, 0.08, 0) + side * s * 0.197
		MachineDetail.rivet_row(d, cheek - along * run.length() * 0.42, cheek + along * run.length() * 0.42, 6, side * s, 0.016, true)
	# Blower: the cover is bolted on all round, the foot is bolted down.
	var hub := BLOWER_POS + Vector3(0, 0.55, 0.171)
	MachineDetail.bolt_circle(d, hub, Vector3.BACK, 0.375, 12, 0.02)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			MachineDetail.bolt(d, BLOWER_POS + Vector3(sx * 0.31, 0.18, sz * 0.26), Vector3.UP, 0.024)
	# Charging box: riveted down its corners and along its rim on the two sides one sees.
	var front := SKIP_POS + Vector3(0, 0, SKIP_SIZE.z * 0.5 + 0.026)
	var flank := SKIP_POS + Vector3(SKIP_SIZE.x * 0.5 + 0.026, 0, 0)
	for s: float in [-1.0, 1.0]:
		MachineDetail.rivet_row(d, front + Vector3(s * (SKIP_SIZE.x * 0.5 - 0.02), 0.07, 0), front + Vector3(s * (SKIP_SIZE.x * 0.5 - 0.02), SKIP_SIZE.y - 0.1, 0), 5, Vector3.BACK, 0.016)
		MachineDetail.rivet_row(d, flank + Vector3(0, 0.07, s * (SKIP_SIZE.z * 0.5 - 0.02)), flank + Vector3(0, SKIP_SIZE.y - 0.1, s * (SKIP_SIZE.z * 0.5 - 0.02)), 5, Vector3.RIGHT, 0.016)
	MachineDetail.rivet_row(d, front + Vector3(-SKIP_SIZE.x * 0.5 + 0.1, SKIP_SIZE.y - 0.03, 0), front + Vector3(SKIP_SIZE.x * 0.5 - 0.1, SKIP_SIZE.y - 0.03, 0), 7, Vector3.BACK, 0.016)
	MachineDetail.rivet_row(d, flank + Vector3(0, SKIP_SIZE.y - 0.03, -SKIP_SIZE.z * 0.5 + 0.1), flank + Vector3(0, SKIP_SIZE.y - 0.03, SKIP_SIZE.z * 0.5 - 0.1), 6, Vector3.RIGHT, 0.016)
	# Welds: under the shaft where the legs carry it, and where the wind box is let into the shell.
	MachineDetail.weld_ring(d, Vector3(0, 0.702, 0), Vector3.UP, r + 0.002, 0.014)
	for y: float in [1.152, 1.498]:
		MachineDetail.weld_ring(d, Vector3(0, y, 0), Vector3.UP, r + 0.006, 0.012)
	MachineDetail.commit(self, d)
	# The gauge stands on the bend of the blast main and faces the crank.
	MachineDetail.gauge(self, Transform3D(Basis(), p1 + Vector3(0, 0.12 + 0.095, 0.02)), 0.05, 0.3)
	# The maker's plate: at eye height on the side of the tap, between the wind box and the next hoop.
	var pa := deg_to_rad(20.0)
	var pdir := Vector3(sin(pa), 0, cos(pa))
	MachineDetail.type_plate(self, Transform3D(Basis(Vector3.UP.cross(pdir), Vector3.UP, pdir), pdir * (r + 0.003) + Vector3(0, 1.685, 0)),
		"MM IRONWORKS", ["CUPOLA   TYPE K-3", "No. 1958-07   2500 kg/h"], Vector2(0.22, 0.14))


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
