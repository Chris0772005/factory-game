extends Node
## Two-process co-op round in the Eisenhalle. Host: `-- --host --role=host --no-save`,
## client: `-- --join=127.0.0.1 --role=client --no-save`. The client opens and
## plugs the cupola tap into the lowered ladle, sets the series pattern and
## presses two flasks at the molding machine; then host and client crank the
## ladle's handwheel together (crew of two) until the flask is full. Both
## sides check what they see.

var role := ""
var world: GameWorld
var _failures := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):
			role = arg.trim_prefix("--role=")
	world = load("res://scenes/iron_hall.tscn").instantiate()
	add_child(world)
	_run.call_deferred()


func _run() -> void:
	if role == "host":
		await _host()
	else:
		await _client()
	print("[%s] NET IRON %s (%d failures)" % [role, "PASSED" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures else 0)


func _cupola() -> CupolaFurnace:
	return get_tree().get_first_node_in_group(&"cupolas")


func _crane() -> HallCrane:
	return world.find_station(HallCrane) as HallCrane


func _line() -> MoldLine:
	return get_tree().get_first_node_in_group(&"mold_lines")


## Where a worker stands to crank the wheel (behind the ladle), `side` -1/1.
func _wheel_spot(side: float) -> Vector3:
	var w := _crane().ladle.interact_point()
	return Vector3(w.x + side * 0.35, 0.05, w.z - 0.75)


func _host() -> void:
	_check(await _until(func(): return world.entities.get_children().filter(func(n): return n is Player).size() > 1, 20.0),
		"host: client's worker in the Eisenhalle")
	var cupola := _cupola()
	var crane := _crane()
	var ladle := crane.ladle
	var line := _line()
	cupola.mix = {&"iron": 30.0}
	cupola.bath = 30.0
	cupola.heat = 1.0
	cupola.temperature = 1.0
	var tap := cupola.to_global(CupolaFurnace.TROUGH_END)
	crane.trolley_x = tap.x
	crane.bridge_z = tap.z
	crane.press()
	_check(await _until(func(): return ladle.lowered, 6.0), "host: ladle lowered under the tap")
	_check(await _until(func(): return cupola.tap_open, 25.0), "host: client opened the tap")
	_check(await _until(func(): return not cupola.tap_open and ladle.amount > 5.0, 25.0), "host: client plugged it, ladle has %.1f l" % ladle.amount)
	_check(await _until(func(): return line.pattern != "", 15.0), "host: client's series pattern on the line")
	var f := line.flask_at(MoldLine.POUR_SLOT)
	_check(await _until(func(): return line.states[line.flask_at(MoldLine.POUR_SLOT)] == MoldLine.Flask.MOLDED and not line.moving, 30.0),
		"host: client pressed two flasks, one waits at the pouring place")
	f = line.flask_at(MoldLine.POUR_SLOT)
	# Aim the lip (as tipped) over the waiting flask.
	var target := line.to_global(line.slot_position(MoldLine.POUR_SLOT) + Vector3(0, MoldLine.FLASK.y, 0))
	ladle.tilt = 0.6
	ladle._update_visuals(0.0)
	var off := ladle.lip_position() - ladle.global_position
	ladle.tilt = 0.0
	crane.press()
	await _until(func(): return crane.hook == ChainHoist.Hook.UP, 6.0)
	crane.trolley_x = target.x - off.x
	crane.bridge_z = target.z - off.z
	crane.press()
	_check(await _until(func(): return ladle.lowered, 6.0), "host: ladle over the line")
	var me := world.local_player()
	me._do_teleport(_wheel_spot(1.0))
	me.facing = 0.0
	await _frames(10)
	_check(me.nearest_interactable() == ladle, "host: the handwheel is the station in front")
	me._request(&"use_start")
	var crew := 0
	var t := 0
	while line.states[f] == MoldLine.Flask.MOLDED and t < 60 * 30:
		crew = maxi(crew, ladle._crew)
		await _frames(1)
		t += 1
	me._request(&"use_end")
	_check(crew == 2, "host: two workers on the wheel at once (%d)" % crew)
	_check(line.states[f] == MoldLine.Flask.FILLED, "host: the flask is full")
	await _frames(240)


func _client() -> void:
	_check(await _until(func(): return world.local_player() != null, 15.0), "client: own worker spawned")
	var me := world.local_player()
	var cupola := _cupola()
	var crane := _crane()
	var ladle := crane.ladle
	var line := _line()
	_check(await _until(func(): return ladle.lowered, 15.0), "client: sees the ladle lowered")
	var tap_node: Node3D = cupola.get_children().filter(func(n): return n is CupolaFurnace.TapHole)[0]
	me._do_teleport(tap_node.global_position + Vector3(0.6, -1.2, 0.5))
	me.facing = atan2(-0.6, -0.5)
	await _frames(20)
	_check(me.nearest_interactable() == tap_node, "client: the tap hole is the station in front")
	me._request(&"use_start")
	await _frames(2)
	me._request(&"use_end")
	_check(await _until(func(): return cupola.tap_open, 5.0), "client: sees the tap open")
	_check(await _until(func(): return ladle.amount > 8.0, 15.0), "client: the ladle fills (%.1f l)" % ladle.amount)
	me._request(&"use_start")
	await _frames(2)
	me._request(&"use_end")
	_check(await _until(func(): return not cupola.tap_open, 5.0), "client: tap plugged")
	var bench: ModelBench = world.get_children().filter(func(n): return n is ModelBench and n.line_mode)[0]
	bench._submit_remote.rpc_id(1, DrawingSamples.star().to_code())
	_check(await _until(func(): return line.pattern != "", 8.0), "client: sees the series pattern")
	me._do_teleport(line.interact_point() + Vector3(0.0, -0.7, 1.0))
	me.facing = PI
	await _frames(20)
	_check(me.nearest_interactable() == line, "client: the molding machine is the station in front")
	for k in 2:
		_check(await _until(func(): return not line.moving and line.states[line.flask_at(MoldLine.MOLD_SLOT)] == MoldLine.Flask.EMPTY, 8.0), "client: machine ready (%d)" % k)
		for i in MoldLine.PRESSES:
			me._request(&"use_start")
			await _frames(2)
			me._request(&"use_end")
			await _frames(28)
		await _frames(20)
	_check(await _until(func(): return not line.moving and line.states[line.flask_at(MoldLine.POUR_SLOT)] == MoldLine.Flask.MOLDED, 10.0),
		"client: a pressed flask waits at the pouring place")
	var f := line.flask_at(MoldLine.POUR_SLOT)
	# Wait for the host to bring the ladle over, then crank with them.
	_check(await _until(func(): return ladle.lowered and Vector2(ladle.global_position.x - line.to_global(line.slot_position(MoldLine.POUR_SLOT)).x, 0).length() < 0.8, 25.0),
		"client: ladle hangs over the line")
	me._do_teleport(_wheel_spot(-1.0))
	me.facing = 0.0
	await _frames(15)
	_check(me.nearest_interactable() == ladle, "client: the handwheel is the station in front")
	me._request(&"use_start")
	# Lambdas capture locals by value: keep the maximum in an array.
	var tipped := [0.0]
	_check(await _until(func():
		tipped[0] = maxf(tipped[0], ladle.tilt)
		return line.fills[f] > 0.99, 30.0), "client: sees the flask fill")
	me._request(&"use_end")
	_check(tipped[0] > 0.3, "client: sees the ladle tip (%.2f)" % tipped[0])


func _until(cond: Callable, timeout_s: float) -> bool:
	var frames := int(timeout_s * 60)
	for i in frames:
		if cond.call():
			return true
		await get_tree().physics_frame
	return cond.call()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(ok: bool, label: String) -> void:
	print("[%s] %s %s" % [role, "ok  " if ok else "FAIL", label])
	if not ok:
		_failures += 1
