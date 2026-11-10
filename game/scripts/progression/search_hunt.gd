class_name SearchHunt
extends Node3D
## Suchaufträge: every hall's hide-and-find contest. Every minute or two a
## customer has lost something small in the workshop (a ring, a key, a
## needle …). It lies hidden next to some station, glinting now and then and
## ticking faintly. The first worker to walk onto it finds it: the reward
## (higher the faster) goes into the till and the find onto that worker's
## tally – the crew races each other for the title of best nose. The HUD
## tells each worker how warm they are. Host runs it; peers mirror the
## state and build the same little prop.

signal changed

const FIRST_DELAY := 50.0
const PAUSE := Vector2(70.0, 120.0)
const DURATION := 75.0
const FIND_RADIUS := 0.75
## Reward at full time per hall tier; it shrinks to half as the time runs out.
const REWARD := [60, 140, 300, 600]
## Lost things per hall tier: name (as in "… ist weg!"), shape and colour.
const ITEMS := [
	[{name = "Omas Ehering", shape = &"ring", color = Color("#ffcf3f")},
		{name = "Der Schuppenschlüssel", shape = &"key", color = Color("#c9a24a")},
		{name = "Opas Taschenuhr", shape = &"disc", color = Color("#e6c36a")},
		{name = "Die Stopfnadel", shape = &"rod", color = Color("#d7dde3")}],
	[{name = "Die 10er-Nuss", shape = &"nut", color = Color("#c7ccd2")},
		{name = "Der Autoschlüssel", shape = &"key", color = Color("#aeb6bd")},
		{name = "Der Glückspfennig", shape = &"disc", color = Color("#c8763f")},
		{name = "Die Zündkerze", shape = &"rod", color = Color("#e9e4d8")}],
	[{name = "Der Klöppel der Kuhglocke", shape = &"rod", color = Color("#c98a55")},
		{name = "Der Taler von 1887", shape = &"disc", color = Color("#dfe3e6")},
		{name = "Der Siegelring des Glockengießers", shape = &"ring", color = Color("#ffcf3f")},
		{name = "Der Schlüssel zum Kirchturm", shape = &"key", color = Color("#6f6a64")}],
	[{name = "Die Kranmutter M30", shape = &"nut", color = Color("#8f979d")},
		{name = "Der Füllfederhalter des Direktors", shape = &"rod", color = Color("#ffcf3f")},
		{name = "Die Werksmarke Nr. 1", shape = &"disc", color = Color("#c9a24a")},
		{name = "Der Spindschlüssel", shape = &"key", color = Color("#c7ccd2")}],
]
const WARMTH := [[1.2, "glühend heiß!"], [2.2, "heiß"], [3.8, "warm"], [6.0, "lauwarm"], [9.0, "kalt"]]

var world: GameWorld
var active := false
var item_index := 0
var item_pos := Vector3.ZERO
var time_left := 0.0
## Finds per worker colour (index into GameWorld.PLAYER_COLORS).
var scores := [0, 0, 0, 0]
## Host: seconds until the next hunt. Tests set it.
var next_in := FIRST_DELAY

var _prop: Node3D
var _glint := 0.0
var _tick := 0.0


func _ready() -> void:
	add_to_group(&"search_hunts")
	Network.peer_ready.connect(_on_peer_ready)


func tier() -> int:
	return clampi(world.upgrade_tier() if world else 0, 0, ITEMS.size() - 1)


func item() -> Dictionary:
	var list: Array = ITEMS[tier()]
	return list[item_index % list.size()]


func reward() -> int:
	return int(round(REWARD[tier()] * (0.5 + 0.5 * clampf(time_left / DURATION, 0.0, 1.0)) / 5.0)) * 5


## "heiß", "kalt" … for a worker at `pos` ("" when no hunt runs).
func warmth(pos: Vector3) -> String:
	if not active:
		return ""
	var d := Vector2(pos.x - item_pos.x, pos.z - item_pos.z).length()
	for w in WARMTH:
		if d < w[0]:
			return w[1]
	return "eiskalt"


static func colour_index(p: Player) -> int:
	var i := GameWorld.PLAYER_COLORS.find(p.color)
	return maxi(i, 0)


static func worker_name(index: int) -> String:
	return "Gießer %s" % ["Blau", "Türkis", "Lila", "Rosa"][clampi(index, 0, 3)]


func _physics_process(delta: float) -> void:
	_animate(delta)
	if not Network.is_sim_authority():
		time_left = maxf(0.0, time_left - delta)
		return
	if world == null or world.attract_mode:
		return
	if not active:
		next_in -= delta
		if next_in <= 0.0:
			start()
		return
	time_left -= delta
	for node in get_tree().get_nodes_in_group(&"players"):
		var p := node as Player
		var d := p.global_position - item_pos
		if Vector2(d.x, d.z).length() < FIND_RADIUS and absf(d.y) < 1.2:
			_found(p)
			return
	if time_left <= 0.0:
		active = false
		next_in = randf_range(PAUSE.x, PAUSE.y)
		world.banner_all("NIEMAND HAT'S GEFUNDEN", Color("#ff6b5a"), "%s bleibt verschwunden" % item().name)
		_broadcast()


## Host: hides a new item. `at` forces the spot (tests). False if no spot.
func start(at := Vector3.INF) -> bool:
	var pos := at if at != Vector3.INF else _pick_spot()
	if pos == Vector3.INF:
		next_in = 10.0
		return false
	item_index = randi() % 1000
	item_pos = pos
	time_left = DURATION
	active = true
	world.banner_all("SUCHAUFTRAG!", UITheme.ACCENT, "%s ist weg – wer findet's zuerst? Bis zu %d $" % [item().name, REWARD[tier()]])
	_broadcast()
	return true


func _found(p: Player) -> void:
	var pay := reward()
	var who := SearchHunt.colour_index(p)
	scores[who] += 1
	active = false
	next_in = randf_range(PAUSE.x, PAUSE.y)
	world.add_money(pay)
	world.popup_all(item_pos + Vector3(0, 1.2, 0), "+%d $" % pay, UITheme.ACCENT)
	world.banner_all("GEFUNDEN!", Color("#7fd3a8"), "%s: %s · +%d $ · Fund Nr. %d" % [SearchHunt.worker_name(who), item().name, pay, scores[who]])
	_found_fx_all(item_pos)
	_broadcast()


## A free bit of floor next to a station, away from every worker.
func _pick_spot() -> Vector3:
	var anchors := get_tree().get_nodes_in_group(&"interactable").filter(func(n: Node) -> bool: return n is Node3D and not n is RigidBody3D)
	if anchors.is_empty():
		return Vector3.INF
	var space := get_world_3d().direct_space_state
	var probe := SphereShape3D.new()
	probe.radius = 0.22
	for attempt in 40:
		var a := (anchors[randi() % anchors.size()] as Node3D).global_position
		var ang := randf() * TAU
		var p := Vector3(a.x + sin(ang) * randf_range(0.8, 1.9), 0.0, a.z + cos(ang) * randf_range(0.8, 1.9))
		var ray := PhysicsRayQueryParameters3D.create(p + Vector3(0, 2.2, 0), p + Vector3(0, -0.5, 0))
		var hit := space.intersect_ray(ray)
		if hit.is_empty() or hit.position.y > 0.12 or hit.position.y < -0.1:
			continue
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = probe
		q.transform = Transform3D(Basis(), p + Vector3(0, 0.36, 0))
		if not space.intersect_shape(q, 1).is_empty():
			continue
		var near_worker := false
		for node in get_tree().get_nodes_in_group(&"players"):
			if (node as Node3D).global_position.distance_to(p) < 4.0:
				near_worker = true
		if near_worker and attempt < 30:
			continue
		return Vector3(p.x, hit.position.y, p.z)
	return Vector3.INF


# --- Networking -----------------------------------------------------------------

func _broadcast() -> void:
	_rebuild_prop()
	changed.emit()
	if Network.is_online() and multiplayer.is_server():
		_sync.rpc(active, item_index, item_pos, time_left, PackedInt32Array(scores))


func _on_peer_ready(id: int, level: String) -> void:
	if is_inside_tree() and multiplayer.is_server() and world and level == world.level_path():
		_sync.rpc_id(id, active, item_index, item_pos, time_left, PackedInt32Array(scores))


@rpc("authority", "call_remote", "reliable")
func _sync(a: bool, index: int, pos: Vector3, left: float, s: PackedInt32Array) -> void:
	active = a
	item_index = index
	item_pos = pos
	time_left = left
	for i in mini(s.size(), scores.size()):
		scores[i] = s[i]
	_rebuild_prop()
	changed.emit()


func _found_fx_all(pos: Vector3) -> void:
	_found_fx(pos)
	if Network.is_online() and multiplayer.is_server():
		_found_fx_remote.rpc(pos)


@rpc("authority", "call_remote", "unreliable")
func _found_fx_remote(pos: Vector3) -> void:
	_found_fx(pos)


func _found_fx(pos: Vector3) -> void:
	Sfx.play(&"coin", pos, 2.0)
	Sfx.play(&"grade_good", pos, -4.0)
	FoundryFX.sparks(get_parent(), pos + Vector3(0, 0.2, 0), 24)


# --- The little prop ---------------------------------------------------------------

func _rebuild_prop() -> void:
	if _prop:
		_prop.queue_free()
		_prop = null
	if not active:
		return
	_prop = Node3D.new()
	_prop.position = item_pos + Vector3(0, 0.03, 0)
	_prop.rotation.y = float(item_index) * 1.7
	add_child(_prop)
	_glint = 1.5
	if not StationKit.visual():
		return
	var info := item()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = info.color
	mat.metallic = 0.9
	mat.roughness = 0.25
	mat.emission_enabled = true
	mat.emission = info.color
	mat.emission_energy_multiplier = 0.0
	_prop.set_meta(&"mat", mat)
	for piece: Array in _shape(info.shape):
		var mi := MeshInstance3D.new()
		mi.mesh = piece[0]
		mi.transform = piece[1]
		mi.material_override = mat
		_prop.add_child(mi)


## Mesh pieces [mesh, transform] of a lost thing, lying flat, 6-14 cm.
func _shape(shape: StringName) -> Array:
	var flat := Basis(Vector3.RIGHT, PI * 0.5)
	match shape:
		&"ring":
			var t := TorusMesh.new()
			t.inner_radius = 0.022
			t.outer_radius = 0.034
			return [[t, Transform3D(Basis(), Vector3(0, 0.006, 0))]]
		&"key":
			var bow := TorusMesh.new()
			bow.inner_radius = 0.016
			bow.outer_radius = 0.03
			return [[bow, Transform3D(Basis(), Vector3(-0.05, 0.005, 0))],
				[EnvMesh.box(Vector3(0.09, 0.008, 0.012)), Transform3D(Basis(), Vector3(0.02, 0.005, 0))],
				[EnvMesh.box(Vector3(0.012, 0.008, 0.026)), Transform3D(Basis(), Vector3(0.055, 0.005, 0.012))]]
		&"disc":
			return [[EnvMesh.cylinder(0.04, 0.04, 0.008, 20), Transform3D(Basis(), Vector3(0, 0.005, 0))]]
		&"nut":
			var hole := TorusMesh.new()
			hole.inner_radius = 0.016
			hole.outer_radius = 0.034
			return [[EnvMesh.cylinder(0.036, 0.036, 0.026, 6), Transform3D(Basis(), Vector3(0, 0.013, 0))],
				[hole, Transform3D(Basis(), Vector3(0, 0.027, 0))]]
		_:
			return [[EnvMesh.cylinder(0.006, 0.009, 0.13, 8), Transform3D(flat, Vector3(0, 0.008, 0))]]


func _animate(delta: float) -> void:
	if not active or _prop == null:
		return
	# A glint every few seconds and a faint positional tick: eyes and ears.
	_glint -= delta
	var mat: StandardMaterial3D = _prop.get_meta(&"mat") if _prop.has_meta(&"mat") else null
	if mat:
		mat.emission_energy_multiplier = maxf(0.0, 2.5 * (1.0 - absf(_glint) / 0.25)) if absf(_glint) < 0.25 else 0.0
	if _glint < -0.25:
		_glint = randf_range(2.2, 3.6)
	_tick -= delta
	if _tick <= 0.0:
		_tick = 1.6
		Sfx.play(&"pop", item_pos, -16.0, 0.02)
