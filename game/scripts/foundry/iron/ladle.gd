class_name Ladle
extends Node3D
## The Eisenhalle's big teeming ladle. It hangs on the hall crane for good:
## the cupola's tap fills it, the crane carries it, and it is tipped by a
## handwheel on its side. Hold F at the wheel to crank it over; every worker
## cranking at the same time makes it tip faster (a solo worker can pour,
## a crew of four pours a bell in one go). Let go and the counterweighted
## worm gear rights it again. Host simulates, peers mirror at 15 Hz.

const RADIUS := 0.5
const HEIGHT := 0.9
## Trunnion height above the ladle's base: the tilt axis.
const PIVOT := 0.55
## Hook eye above the base (top of the bail).
const HANG := 1.45
const CAPACITY := 50.0
const CAPACITY_BIG := 75.0
const MAX_POUR_RATE := 4.5      ## litres per second at full tilt
## Tilt per second for one cranking worker, and the bonus per extra one.
const TILT_SPEED := 0.17
const CREW_BONUS := 0.6
const RETURN_SPEED := 0.4
## A crank tick older than this no longer counts as "still cranking".
const CRANK_WINDOW_MS := 140
const COOL_RATE := 0.006
const MELT_RADIUS := 0.44
## Handwheel position (ladle space): on a shaft back from the gearbox.
const WHEEL := Vector3(RADIUS + 0.24, PIVOT, -0.95)

var amount := 0.0
var temperature := 0.0
var mix := {}
var tilt := 0.0
var flow := 0.0
## Set by the crane: hanging at pouring height and not moving up or down.
var lowered := false
var pour_target := Vector3.ZERO
## Workers cranking (instance id -> msec of their last tick). Host only.
var _cranks := {}
var _crew := 0
var _sync_accum := 0.0
var _overflow_note := 0.0
var _wheel_angle := 0.0

var _body: AnimatableBody3D
var _pivot: Node3D
var _wheel: Node3D
var _melt: MeshInstance3D
var _melt_mat: ShaderMaterial
var _stream: PourStream
var _hiss: AudioStreamPlayer3D


## The ladle whose mouth `point` falls into, or null.
static func find_at(tree: SceneTree, point: Vector3) -> Ladle:
	for node in tree.get_nodes_in_group(&"ladles"):
		var l := node as Ladle
		var local := point - l.global_position
		if Vector2(local.x, local.z).length() < RADIUS * 0.95 and local.y > 0.0 and local.y < HEIGHT + 0.6:
			return l
	return null


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_to_group(&"interactable")
	add_to_group(&"ladles")
	_body = AnimatableBody3D.new()
	_body.sync_to_physics = false
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = RADIUS
	cyl.height = HEIGHT
	shape.shape = cyl
	shape.position.y = HEIGHT * 0.5
	_body.add_child(shape)
	add_child(_body)
	_pivot = Node3D.new()
	_pivot.position.y = PIVOT
	add_child(_pivot)
	_build_art()
	_hiss = Sfx.make_loop(self, &"pour_loop")
	_stream = PourStream.new()
	_stream.top_level = true
	_stream.max_radius = 0.1
	add_child(_stream)


func capacity() -> float:
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	return CAPACITY_BIG if world and world.has_upgrade(&"big_ladle") else CAPACITY


func alloy() -> StringName:
	return FoundryRules.alloy_for(mix)


## Melt from the cupola tap (or a crucible poured into it). Host only.
func receive(litres: float, temp: float, in_mix: Dictionary) -> void:
	var room := capacity() - amount
	var take := clampf(room, 0.0, litres)
	if take > 0.0:
		var f := take / maxf(litres, 0.0001)
		for k in in_mix:
			mix[k] = mix.get(k, 0.0) + in_mix[k] * f
		temperature = (temperature * amount + temp * take) / maxf(amount + take, 0.0001)
		amount += take
	if take < litres:
		if randf() < 0.2:
			FoundryFX.sparks(get_parent(), global_position + Vector3(0, HEIGHT, 0), 10)
		var now := Time.get_ticks_msec() / 1000.0
		if now - _overflow_note > 3.0:
			_overflow_note = now
			var world := get_tree().get_first_node_in_group(&"world") as GameWorld
			if world:
				world.popup_all(global_position + Vector3(0, HEIGHT + 1.0, 0), "Pfanne voll – Abstich zu!", Color("#ff6b5a"))


# --- Handwheel ------------------------------------------------------------------

func interact_point() -> Vector3:
	return _wheel.global_position


func hint(_player: Node) -> String:
	var contents := "leer" if amount < 0.05 else "%s l %s · %d °C" % [_l(amount), Alloys.display_name(alloy()), roundi(200 + temperature * 1300)]
	if not lowered:
		return "Gießpfanne (%s) – mit dem Kran absenken, dann kurbeln" % contents
	if amount < 0.05:
		return "Gießpfanne leer – unter den Abstich am Kupolofen fahren"
	var line := "[F halten] Kurbeln = kippen · %s" % contents
	if _crew > 1:
		line += " · %d Leute kurbeln!" % _crew
	var target := _target_text()
	return line + (" · " + target if target != "" else "")


## What the stream would land in, for the hint.
func _target_text() -> String:
	var probe := lip_position()
	probe.y = 0.7
	var tree := get_tree()
	var mold := MoldBox.find_at(tree, probe)
	if mold:
		return "Formkasten %d %%" % roundi(mold._total_fill() * 100.0)
	var pit := BellPit.find_at(tree, Vector3(probe.x, 0.8, probe.z))
	if pit and pit.state in [BellPit.State.TURNED, BellPit.State.FILLING]:
		return "Glockenform %d %%" % roundi(pit.fill / maxf(pit.need, 0.01) * 100.0)
	var line := MoldLine.describe_at(tree, probe)
	if line != "":
		return line
	return "nichts drunter!"


func interact(player: Node) -> void:
	interact_tick(player, 0.0)


## F held at the wheel. Host only.
func interact_tick(player: Node, _delta: float) -> void:
	if not lowered or amount < 0.01:
		return
	_cranks[player.get_instance_id()] = Time.get_ticks_msec()


func _physics_process(delta: float) -> void:
	if Network.is_sim_authority():
		_simulate(delta)
	_update_visuals(delta)


func _simulate(delta: float) -> void:
	var now := Time.get_ticks_msec()
	_crew = 0
	for id in _cranks.keys():
		if now - int(_cranks[id]) <= CRANK_WINDOW_MS:
			_crew += 1
		else:
			_cranks.erase(id)
	if _crew > 0 and lowered:
		tilt = move_toward(tilt, 1.0, delta * TILT_SPEED * (1.0 + CREW_BONUS * (_crew - 1)))
	else:
		tilt = move_toward(tilt, 0.0, delta * RETURN_SPEED * (1.0 if lowered else 3.0))
	flow = clampf((tilt - 0.3) / 0.7, 0.0, 1.0) if amount > 0.0 else 0.0
	if amount > 0.0:
		temperature = maxf(0.0, temperature - COOL_RATE * delta)
	if flow > 0.0:
		_pour(minf(amount, flow * MAX_POUR_RATE * delta), flow * MAX_POUR_RATE, delta)
	if Network.is_online():
		_sync_accum += delta
		if _sync_accum >= 1.0 / 15.0:
			_sync_accum = 0.0
			_sync.rpc(amount, temperature, tilt, flow, alloy(), pour_target, _crew)


func _pour(litres: float, rate: float, delta: float) -> void:
	var lip := lip_position()
	var query := PhysicsRayQueryParameters3D.create(lip, lip + Vector3.DOWN * 5.0)
	query.exclude = [_body.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	pour_target = hit.position if hit else lip + Vector3.DOWN * 1.5
	var share := {}
	for k in mix:
		share[k] = mix[k] / maxf(amount, 0.0001) * litres
		mix[k] -= share[k]
	amount -= litres
	MeltTargets.deliver(get_tree(), pour_target, litres, temperature, share, rate, delta, self)
	if amount <= 0.001:
		amount = 0.0
		mix.clear()


## World position of the pouring lip (it faces the ladle's +Z).
func lip_position() -> Vector3:
	return _pivot.global_transform * Vector3(0, HEIGHT - PIVOT, RADIUS + 0.1)


## Can the crane hoist it now? Not while it is tipped.
func upright() -> bool:
	return tilt < 0.08


@rpc("authority", "call_remote", "unreliable_ordered")
func _sync(a: float, t: float, ti: float, f: float, al: StringName, target: Vector3, crew: int) -> void:
	amount = a
	temperature = t
	tilt = ti
	flow = f
	pour_target = target
	_crew = crew
	mix = {al: a}


func _l(v: float) -> String:
	return ("%.0f" % v) if v >= 10.0 else ("%.1f" % v).replace(".", ",")


# --- Art --------------------------------------------------------------------------

func _build_art() -> void:
	_melt = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = MELT_RADIUS
	disc.bottom_radius = MELT_RADIUS
	disc.height = 0.03
	disc.radial_segments = 32
	_melt.mesh = disc
	_melt_mat = MetalMaterial.create(&"iron")
	_melt_mat.set_shader_parameter(&"env_brightness", 0.35)
	_melt_mat.set_shader_parameter(&"glow_scale", 1.6)
	_melt.material_override = _melt_mat
	_melt.visible = false
	_pivot.add_child(_melt)
	# The handwheel sits behind the ladle (opposite the lip): the crew cranks
	# from behind the mold line or the pit, never standing on it.
	_wheel = Node3D.new()
	_wheel.position = WHEEL
	add_child(_wheel)
	if not StationKit.visual():
		return
	var shell := StationKit.metal("ladle_shell", {steel_color = Color("#3d3a38"), rust = 0.35, dents = 0.35,
		metallic_steel = 0.5, roughness_steel = 0.6, soot = 0.5, soot_bottom = 0.0, soot_top = 0.6})
	var lining := StationKit.clay("ladle_lining", {body_color = Color("#8a7a68"), soot = 0.6, cracks = 0.4})
	var p := -PIVOT
	var outside := PackedVector2Array([Vector2(0.0, p), Vector2(0.4, p), Vector2(0.44, p + 0.04), Vector2(RADIUS, p + HEIGHT - 0.06),
		Vector2(RADIUS + 0.04, p + HEIGHT - 0.04), Vector2(RADIUS + 0.04, p + HEIGHT)])
	StationKit.add(_pivot, StationKit.lathe(outside, 32, 40.0, _spout), shell)
	var inside := PackedVector2Array([Vector2(RADIUS + 0.04, p + HEIGHT), Vector2(RADIUS - 0.07, p + HEIGHT),
		Vector2(0.4, p + 0.12), Vector2(0.0, p + 0.12)])
	StationKit.add(_pivot, StationKit.lathe(inside, 32, 40.0, _spout), lining)
	var steel := StationKit.metal("ladle_rig", {steel_color = Color("#56544f"), rust = 0.3, metallic_steel = 0.6})
	var paint := StationKit.metal("crane_paint", {steel_color = Color("#d9a521"), rust = 0.25, dents = 0.2,
		metallic_steel = 0.3, roughness_steel = 0.55})
	var bands := []
	for y: float in [0.25, 0.62]:
		var r := lerpf(0.44, RADIUS, y / (HEIGHT - 0.06)) + 0.015
		bands.append(EnvMesh.piece(StationKit.lathe(PackedVector2Array([Vector2(r, p + y - 0.04), Vector2(r + 0.01, p + y - 0.03),
			Vector2(r + 0.01, p + y + 0.03), Vector2(r, p + y + 0.04)]), 32, 60.0), Transform3D()))
	for s: float in [-1.0, 1.0]:
		bands.append(EnvMesh.piece(EnvMesh.cylinder(0.07, 0.07, 0.16, 12), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(s * (RADIUS + 0.08), 0, 0))))
	StationKit.add_merged(_pivot, bands, steel)
	# Bail: hangs from the hook, does not tip (child of the ladle, not the pivot).
	var bail := PackedVector3Array()
	var top := HANG - 0.08
	var w := RADIUS + 0.2
	for pt: Vector3 in [Vector3(-w, PIVOT, 0), Vector3(-w, top - 0.35, 0), Vector3(-0.25, top, 0), Vector3(0.25, top, 0),
			Vector3(w, top - 0.35, 0), Vector3(w, PIVOT, 0)]:
		bail.append(pt)
	StationKit.add(self, StationKit.tube(bail, 0.045, 8), paint)
	StationKit.add(self, EnvMesh.box(Vector3(0.18, 0.12, 0.12), 0.02), paint, Transform3D(Basis(), Vector3(0, top + 0.05, 0)))
	# Worm gearbox on the bail; a shaft runs back to the handwheel.
	StationKit.add(self, EnvMesh.box(Vector3(0.16, 0.3, 0.24), 0.02), paint, Transform3D(Basis(), Vector3(w + 0.04, PIVOT, 0)))
	StationKit.add(self, StationKit.tube(PackedVector3Array([Vector3(WHEEL.x, PIVOT, -0.1), WHEEL + Vector3(0, 0, 0.04)]), 0.03, 8), steel)
	var rim := TorusMesh.new()
	rim.inner_radius = 0.2
	rim.outer_radius = 0.235
	rim.rings = 24
	StationKit.add(_wheel, rim, steel, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO))
	var spokes := []
	for k in 3:
		spokes.append(EnvMesh.piece(EnvMesh.box(Vector3(0.025, 0.42, 0.02)), Transform3D(Basis(Vector3.BACK, k * PI / 3.0), Vector3.ZERO)))
	spokes.append(EnvMesh.piece(EnvMesh.cylinder(0.04, 0.04, 0.08, 10), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO)))
	StationKit.add_merged(_wheel, spokes, steel)
	var knob := StationKit.wood("ladle_knob", {base_color = Color("#6e4630")})
	StationKit.add(_wheel, EnvMesh.cylinder(0.025, 0.025, 0.12, 8), knob, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.2, -0.06)))


## Pouring lip: the rim pulls out into a spout towards +Z.
func _spout(v: Vector3, a: float) -> Vector3:
	var top := -PIVOT + HEIGHT
	var near := maxf(0.0, cos(a))
	near = near * near * near * near
	var up := clampf((v.y - (top - 0.25)) / 0.25, 0.0, 1.0)
	return v + Vector3(0, 0, near * up * 0.12)


func _update_visuals(delta: float) -> void:
	_pivot.rotation.x = tilt * 1.15
	var fill := clampf(amount / capacity(), 0.0, 1.0)
	_melt.visible = amount > 0.05
	_melt.position.y = -PIVOT + 0.14 + (HEIGHT - 0.24) * fill
	var r := lerpf(0.4, RADIUS - 0.07, clampf((_melt.position.y + PIVOT - 0.12) / (HEIGHT - 0.12), 0.0, 1.0)) - 0.01
	_melt.scale = Vector3(r / MELT_RADIUS, 1.0, r / MELT_RADIUS)
	MetalMaterial.set_temperature(_melt_mat, clampf(temperature, 0.0, 1.0))
	if _melt.visible:
		var al := alloy()
		if _melt_mat.get_meta(&"alloy", &"") != al:
			MetalMaterial.set_alloy(_melt_mat, al)
	_wheel_angle += (tilt - _wheel.get_meta(&"last_tilt", tilt)) * 18.0
	_wheel.set_meta(&"last_tilt", tilt)
	_wheel.rotation.z = _wheel_angle
	_stream.flow = flow
	if flow > 0.0:
		_stream.set_endpoints(lip_position(), pour_target)
		_hiss.global_position = pour_target
		_hiss.volume_db = linear_to_db(flow) + 1.0
		if not _hiss.playing:
			_hiss.play()
	elif _hiss.playing:
		_hiss.stop()
