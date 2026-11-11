class_name AutoFoundry
extends Node3D
## The machines that take the hand work out of a furnace-and-sand-mold hall,
## one upgrade each, until the foundry runs by itself:
##   auto_bellows  blower keeps the furnace hot while there is work
##   auto_rammer   molds re-form their last patterns and ram themselves
##   auto_pour     an overhead rail ladle carries melt from the docked
##                 crucible to every rammed mold and pours it
##   auto_breaker  shake-out: finished molds break open by themselves
##   auto_ship     resting castings are flung into the sell crate
## Host simulates; stations sync their own state, the ladle its position.

enum Trip { IDLE, FILL, GO, POUR, BACK }

const RAIL_HEIGHT := 2.25
const LADLE_DROP := 0.95          ## ladle hangs this far under the rail
const LADLE_SPEED := 1.5
const POUR_RATE := 0.6
const POUR_TEMP := 0.55
const RAM_TIME := 4.0
const REPATTERN_TIME := 3.0
const BREAK_DELAY := 1.2
const SHIP_REST := 2.0
const SHIP_TRIES := 4

var furnace: Furnace
var molds: Array[MoldBox] = []
var crate: SellCrate

var ladle_state := Trip.IDLE
var ladle_mold := -1
var ladle_t := 0.0                ## 0 = over the furnace, 1 = over the mold
var ladle_amount := 0.0
var ladle_mix := {}
var ladle_temp := 0.0

## Per mold: automation switched on (AutoSwitch on the cabinet).
var enabled: Array[bool] = []

var _timer := 0.0
var _memory: Array = []           ## per mold: {patterns, wait, ram, ready, count}
var _rest := {}                   ## casting instance id -> [rest seconds, tries]
var _sync_accum := 0.0
var _hub := Vector3.ZERO
var _rails: Array[Node3D] = []
var _trolley: Node3D
var _bucket: Node3D
var _pot: Node3D
var _melt: MeshInstance3D
var _stream: PourStream
var _blower: Node3D
var _fan: Node3D
var _units: Array[Node3D] = []
var _lamps: Array = []            ## per mold: [ram lamp material, break lamp material]
var _colliders: Array[CollisionShape3D] = []
var _tilt := 0.0
var _dust := 0.0


## Builds the automation for a hall with a Furnace and sand molds (else null).
static func build_for(world: Node3D) -> AutoFoundry:
	var f := world.get_tree().get_first_node_in_group(&"furnaces") as Furnace
	var found: Array[MoldBox] = []
	for m in world.get_tree().get_nodes_in_group(&"molds"):
		if m is MoldBox and world.is_ancestor_of(m):
			found.append(m)
	if f == null or not world.is_ancestor_of(f) or found.is_empty():
		return null
	var auto := AutoFoundry.new()
	auto.name = "AutoFoundry"
	auto.furnace = f
	auto.molds = found
	for c in world.get_children():
		if c is SellCrate:
			auto.crate = c
	world.add_child(auto)
	return auto


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_to_group(&"auto_foundries")
	_hub = furnace.global_position + Vector3(0, RAIL_HEIGHT, 0)
	for m in molds:
		_memory.append({patterns = [], wait = 0.0, ram = 0.0, ready = 0.0, count = 0})
		enabled.append(true)
	Network.peer_ready.connect(_on_peer_ready)
	_build()


func has_cabinet() -> bool:
	return has(&"auto_rammer") or has(&"auto_breaker") or has(&"auto_pour")


## Host: switches one mold's automation. Off also forgets its pattern.
func set_enabled(i: int, on: bool) -> void:
	enabled[i] = on
	if not on:
		_memory[i].patterns = []
	if Network.is_online():
		_enabled_sync.rpc(i, on)


@rpc("authority", "call_remote", "reliable")
func _enabled_sync(i: int, on: bool) -> void:
	enabled[i] = on


func _on_peer_ready(id: int) -> void:
	if not Network.is_sim_authority():
		return
	for i in enabled.size():
		if not enabled[i]:
			_enabled_sync.rpc_id(id, i, false)


func has(id: StringName) -> bool:
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	return world != null and world.has_upgrade(id)


func _physics_process(delta: float) -> void:
	_show_upgrades()
	if Network.is_sim_authority():
		_run_bellows(delta)
		_run_molds(delta)
		_run_ladle(delta)
		_run_shipping(delta)
		if Network.is_online() and has(&"auto_pour"):
			_sync_accum += delta
			if _sync_accum > 0.1:
				_sync_accum = 0.0
				_ladle_sync.rpc(ladle_state, ladle_mold, ladle_t, ladle_amount, ladle_temp)
	_animate(delta)


@rpc("authority", "call_remote", "unreliable_ordered")
func _ladle_sync(state: int, mold: int, t: float, amount: float, temp: float) -> void:
	ladle_state = state as Trip
	ladle_mold = mold
	ladle_t = t
	ladle_amount = amount
	ladle_temp = temp


# --- Simulation (host) -----------------------------------------------------------

func _run_bellows(delta: float) -> void:
	if not has(&"auto_bellows") or furnace.crucible == null:
		return
	if not furnace.charge.is_empty() or furnace.crucible.amount > 0.05 or ladle_state != Trip.IDLE:
		furnace.heat = maxf(furnace.heat, move_toward(furnace.heat, 0.92, delta * 0.4))


func _run_molds(delta: float) -> void:
	var ram := has(&"auto_rammer")
	var shake := has(&"auto_breaker")
	for i in molds.size():
		var mold := molds[i]
		var mem: Dictionary = _memory[i]
		if enabled[i] and mold.state >= MoldBox.State.RAMMED and not mold.patterns.is_empty():
			mem.patterns = mold.patterns.duplicate()
		# Switched off: no re-forming and no ramming; a started piece is still finished.
		var forms: bool = ram and enabled[i]
		if not enabled[i]:
			mem.patterns = []
		if forms and mold.state == MoldBox.State.EMPTY and not (mem.patterns as Array).is_empty():
			mem.wait += delta
			if mem.wait >= REPATTERN_TIME:
				mem.wait = 0.0
				for code: String in mem.patterns:
					mold.add_pattern(code)
		else:
			mem.wait = 0.0
		if forms and mold.state == MoldBox.State.PATTERNED:
			# A worker adding one more pattern restarts the press.
			if mem.count != mold.patterns.size():
				mem.count = mold.patterns.size()
				mem.ram = 0.0
			mem.ram += delta
			if mem.ram >= RAM_TIME:
				mem.ram = 0.0
				mold.ram_quality = 0.82
				mold.state = MoldBox.State.RAMMED
				mold._prepare_fill()
				mold._fx_all(&"dust", mold.interact_point())
				mold._broadcast_state()
		else:
			mem.ram = 0.0
			mem.count = mold.patterns.size()
		if shake and mold.state == MoldBox.State.READY:
			mem.ready += delta
			if mem.ready >= BREAK_DELAY:
				mem.ready = 0.0
				mold._break_open()
		else:
			mem.ready = 0.0


## Litres a mold still needs to be full.
func _need(mold: MoldBox) -> float:
	var total := 0.0
	for i in mold.needs.size():
		total += mold.needs[i] * (1.0 - (mold.fills[i] if i < mold.fills.size() else 0.0))
	return total


func _run_ladle(delta: float) -> void:
	if not has(&"auto_pour"):
		ladle_state = Trip.IDLE
		ladle_t = 0.0
		return
	var pot := furnace.crucible
	match ladle_state:
		Trip.IDLE:
			if pot == null or pot.temperature < POUR_TEMP:
				return
			for i in molds.size():
				var mold := molds[i]
				if mold.state != MoldBox.State.RAMMED and mold.state != MoldBox.State.FILLING:
					continue
				var need := _need(mold) * 1.03
				if need < 0.01 or pot.amount < minf(need, pot.capacity() * 0.97):
					continue
				var take := minf(need, pot.amount)
				ladle_mix = {}
				for k in pot.mix:
					var part: float = pot.mix[k] / maxf(pot.amount, 0.0001) * take
					ladle_mix[k] = part
					pot.mix[k] -= part
				pot.amount -= take
				if pot.amount <= 0.001:
					pot.amount = 0.0
					pot.mix.clear()
				ladle_amount = take
				ladle_temp = pot.temperature
				ladle_mold = i
				ladle_state = Trip.FILL
				_timer = 0.9
				return
		Trip.FILL:
			_timer -= delta
			if _timer <= 0.0:
				ladle_state = Trip.GO
		Trip.GO:
			ladle_t = minf(1.0, ladle_t + delta * LADLE_SPEED / _rail_length(ladle_mold))
			if ladle_t >= 1.0:
				ladle_state = Trip.POUR
				_timer = 0.5
		Trip.POUR:
			_timer -= delta
			if _timer > 0.0:
				return
			var mold := molds[ladle_mold]
			var open := mold.state == MoldBox.State.RAMMED or mold.state == MoldBox.State.FILLING
			if ladle_amount <= 0.001 or not open:
				ladle_state = Trip.BACK
				return
			var out := minf(ladle_amount, POUR_RATE * delta)
			var share := {}
			for k in ladle_mix:
				share[k] = ladle_mix[k] / maxf(ladle_amount, 0.0001) * out
				ladle_mix[k] -= share[k]
			ladle_amount -= out
			mold.receive_metal(out, ladle_temp, share, POUR_RATE, delta)
		Trip.BACK:
			ladle_t = maxf(0.0, ladle_t - delta * LADLE_SPEED / _rail_length(ladle_mold))
			if ladle_t <= 0.0:
				# What is left goes back into the pot.
				if pot and ladle_amount > 0.001:
					for k in ladle_mix:
						pot.add_melt(k, ladle_mix[k])
				ladle_amount = 0.0
				ladle_mix = {}
				ladle_state = Trip.IDLE


func _rail_length(i: int) -> float:
	var to := molds[i].global_position - furnace.global_position
	return maxf(0.5, Vector2(to.x, to.z).length())


func _run_shipping(delta: float) -> void:
	if not has(&"auto_ship") or crate == null:
		return
	var seen := {}
	for node in get_tree().get_nodes_in_group(&"castings"):
		var piece := node as CastPiece
		if piece == null or piece.is_held() or piece.is_queued_for_deletion():
			continue
		var id := piece.get_instance_id()
		var entry: Array = _rest.get(id, [0.0, 0])
		seen[id] = entry
		if entry[1] >= SHIP_TRIES:
			continue
		if piece.linear_velocity.length() > 0.2:
			entry[0] = 0.0
			continue
		entry[0] += delta
		if entry[0] < SHIP_REST:
			continue
		entry[0] = 0.0
		entry[1] += 1
		var target := crate.global_position + Vector3(0, SellCrate.SIZE.y + 0.35, 0)
		var d := target - piece.global_position
		var flight := clampf(Vector2(d.x, d.z).length() / 6.5, 0.75, 1.4)
		var g: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
		piece.sleeping = false
		piece.linear_velocity = Vector3(d.x / flight, (d.y + 0.5 * g * flight * flight) / flight, d.z / flight)
		piece.angular_velocity = Vector3(randf_range(-3, 3), randf_range(-3, 3), randf_range(-3, 3))
		_ship_fx.rpc(piece.global_position)
	_rest = seen


@rpc("authority", "call_local", "unreliable")
func _ship_fx(pos: Vector3) -> void:
	Sfx.play(&"throw_whoosh", pos, -2.0, 0.1)
	FoundryFX.dust(self, pos)


# --- Presentation -------------------------------------------------------------------

func _show_upgrades() -> void:
	var pour := has(&"auto_pour")
	for r in _rails:
		r.visible = pour
	if _trolley:
		_trolley.visible = pour
	if _blower:
		_blower.visible = has(&"auto_bellows")
	var unit := has_cabinet()
	for u in _units:
		u.visible = unit
	for i in _colliders.size():
		# Blower first, then one per mold unit, then the rail posts.
		var on := has(&"auto_bellows") if i == 0 else (unit if i <= molds.size() else pour)
		if _colliders[i].disabled == on:
			_colliders[i].disabled = not on


func _ladle_point() -> Vector3:
	if ladle_mold < 0 or ladle_mold >= molds.size():
		return _hub
	var end := molds[ladle_mold].global_position
	return _hub.lerp(Vector3(end.x, _hub.y, end.z), ladle_t)


func _animate(delta: float) -> void:
	if _fan and _blower.visible:
		_fan.rotate_object_local(Vector3.UP, delta * (4.0 + furnace.heat * 30.0))
	for i in _lamps.size():
		var mold := molds[i]
		# Green: running. Amber: working on the mold. Both dark: switched off.
		var busy := (has(&"auto_rammer") and mold.state == MoldBox.State.PATTERNED) or (has(&"auto_breaker") and mold.state == MoldBox.State.READY)
		(_lamps[i][0] as StandardMaterial3D).emission_energy_multiplier = 2.4 if enabled[i] else 0.05
		(_lamps[i][1] as StandardMaterial3D).emission_energy_multiplier = 2.6 if enabled[i] and busy else 0.1
		if enabled[i] and has(&"auto_rammer") and mold.state == MoldBox.State.PATTERNED and _units[i].visible:
			_units[i].position.y = absf(sin(Time.get_ticks_msec() * 0.03)) * 0.012
	if _trolley == null or not _trolley.visible:
		return
	var p := _ladle_point()
	_trolley.global_position = p
	var pouring := ladle_state == Trip.POUR and ladle_amount > 0.001
	_tilt = move_toward(_tilt, 1.0 if pouring else 0.0, delta * 2.5)
	# Dip into the furnace mouth to fill, hang level to travel, tip to pour.
	var dip := 0.25 if ladle_state == Trip.FILL else 0.0
	_bucket.position.y = move_toward(_bucket.position.y, -LADLE_DROP - dip, delta * 0.8)
	_pot.rotation.x = _tilt * 1.15
	_melt.visible = ladle_amount > 0.01
	if _stream:
		_stream.flow = 0.55 if pouring and _tilt > 0.6 else 0.0
		_stream.temperature = maxf(0.6, ladle_temp)
		if ladle_mold >= 0 and ladle_mold < molds.size():
			var lip := _pot.global_transform * Vector3(0, 0.13, 0.2)
			_stream.set_endpoints(lip, Vector3(lip.x, molds[ladle_mold].global_position.y + MoldBox.BED.y, lip.z))


func _build() -> void:
	# Colliders exist headless too: blower, mold units, rail posts.
	var away := Vector3(1, 0, 0)
	var heap := get_tree().get_first_node_in_group(&"scrap_piles") as Node3D
	if heap:
		away = (furnace.global_position - heap.global_position)
		away.y = 0.0
		away = away.normalized()
	var blower_at := furnace.global_position + away * 1.05
	_add_collider(Vector3(0.5, 0.6, 0.45), blower_at + Vector3(0, 0.3, 0))
	var unit_at: Array[Vector3] = []
	for m in molds:
		var at := m.to_global(Vector3(MoldBox.BED.x * 0.5 + 0.32, 0, -MoldBox.BED.z * 0.5 + 0.25))
		unit_at.append(at)
		var sw := AutoSwitch.new()
		sw.auto = self
		sw.index = unit_at.size() - 1
		sw.position = at
		add_child(sw)
		_add_collider(Vector3(0.36, 1.0, 0.3), at + Vector3(0, 0.5, 0))
	var post_at: Array[Vector3] = []
	for m in molds:
		var dir := m.global_position - furnace.global_position
		dir.y = 0.0
		var at := m.global_position + dir.normalized() * (MoldBox.BED.x * 0.5 + 0.35)
		at.y = 0.0
		post_at.append(at)
		_add_collider(Vector3(0.14, RAIL_HEIGHT, 0.14), at + Vector3(0, RAIL_HEIGHT * 0.5, 0))
	# One hub post beside the furnace, on the side away from the molds.
	var side := Vector3(-away.z, 0, away.x)
	if side.dot(molds[0].global_position - furnace.global_position) > 0.0:
		side = -side
	var hub_post := furnace.global_position + side * 0.85
	hub_post.y = 0.0
	_add_collider(Vector3(0.14, RAIL_HEIGHT, 0.14), hub_post + Vector3(0, RAIL_HEIGHT * 0.5, 0))
	_trolley = Node3D.new()
	add_child(_trolley)
	_bucket = Node3D.new()
	_bucket.position.y = -LADLE_DROP
	_trolley.add_child(_bucket)
	_pot = Node3D.new()
	_pot.position.y = 0.13
	_bucket.add_child(_pot)
	_melt = MeshInstance3D.new()
	_pot.add_child(_melt)
	if not StationKit.visual():
		return
	AutoArt.blower(self, blower_at, furnace.global_position)
	_blower = get_node(^"Blower")
	_fan = _blower.get_node(^"Fan")
	for i in molds.size():
		var res := AutoArt.mold_unit(self, unit_at[i], molds[i].global_position)
		_units.append(res[0])
		_lamps.append([res[1], res[2]])
		_rails.append(AutoArt.rail(self, _hub, post_at[i], hub_post, i == 0))
	AutoArt.trolley(_trolley, _bucket, _pot, _melt, LADLE_DROP)
	_stream = PourStream.new()
	_stream.top_level = true
	add_child(_stream)


func _add_collider(size: Vector3, at: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.disabled = true
	body.position = at
	body.add_child(shape)
	add_child(body)
	_colliders.append(shape)
