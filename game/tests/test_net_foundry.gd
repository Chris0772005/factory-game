extends Node
## Two-process co-op round in the backyard. Host: `-- --host --role=host`,
## client: `-- --join=127.0.0.1 --role=client`. The client draws, rams and
## smashes; the host melts and pours. Both sides check what they see.

var role := ""
var world: GameWorld
var _failures := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):
			role = arg.trim_prefix("--role=")
	world = load("res://scenes/backyard.tscn").instantiate()
	add_child(world)
	_run.call_deferred()


func _run() -> void:
	if role == "host":
		await _host()
	else:
		await _client()
	print("[%s] NET FOUNDRY %s (%d failures)" % [role, "PASSED" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures else 0)


func _molds() -> Array:
	return get_tree().get_nodes_in_group(&"molds")


func _patterned_mold() -> MoldBox:
	for m in _molds():
		if not m.patterns.is_empty():
			return m
	return null


func _host() -> void:
	_check(await _until(func(): return _patterned_mold() != null and _patterned_mold().state == MoldBox.State.RAMMED, 40.0),
		"host: client's drawing arrives and the client rams the mold")
	var mold := _patterned_mold()
	if mold == null:
		return
	var me := world.local_player()
	var crucible: Crucible = get_tree().get_first_node_in_group(&"crucibles")
	crucible.add_melt(&"copper", 2.0)
	crucible.add_melt(&"zinc_brass", 0.6)
	crucible.temperature = 0.95
	me.global_position = mold.global_position + Vector3(0, 0.05, 1.35)
	me.facing = PI
	crucible.global_position = me._hand_target()
	await _frames(5)
	me.grab(crucible)
	me._perform(&"use_start")
	await _until(func():
		me.using = true
		return mold.state == MoldBox.State.COOLING, 25.0)
	me._perform(&"use_end")
	me.release()
	_check(mold.state == MoldBox.State.COOLING, "host: pouring fills the client's cavity")
	_check(await _until(func(): return world.entities.get_children().any(func(n): return n is CastPiece), 30.0),
		"host: client smashes the mold and the casting appears")
	await _frames(240)
	var piece: CastPiece = world.entities.get_children().filter(func(n): return n is CastPiece)[0]
	var crate: SellCrate = world.find_children("*", "SellCrate", true, false)[0]
	piece.global_position = crate.global_position + Vector3(0, 0.4, 0)
	piece.linear_velocity = Vector3.ZERO
	await _frames(20)
	_check(world.money > 0, "host: casting sold (%d $)" % world.money)
	await _frames(180)


func _client() -> void:
	_check(await _until(func(): return world.local_player() != null, 10.0), "client: own worker spawned")
	var me := world.local_player()
	_check(get_tree().get_first_node_in_group(&"crucibles") != null, "client: crucible replicated")
	_check(world.entities.get_children().any(func(n): return n is Hammer), "client: hammer replicated")
	var bench: ModelBench = world.find_children("*", "ModelBench", true, false)[0]
	bench._submit_remote.rpc_id(1, DrawingSamples.cat().to_code())
	_check(await _until(func(): return _patterned_mold() != null and _patterned_mold().state == MoldBox.State.PATTERNED, 5.0),
		"client: mold shows the submitted drawing")
	var mold := _patterned_mold()
	if mold == null:
		return
	me._do_teleport(mold.global_position + Vector3(0, 0.05, 1.3))
	me.facing = PI
	await _frames(30)
	for i in MoldBox.RAMS_NEEDED:
		Input.action_press(&"interact")
		await _frames(2)
		Input.action_release(&"interact")
		await _frames(22)
	_check(await _until(func(): return mold.state == MoldBox.State.RAMMED, 3.0), "client: ramming via F reaches the host")
	_check(await _until(func(): return mold.state == MoldBox.State.READY, 40.0), "client: sees the pour, cooling and ready state")
	var max_fill := 0.0
	for f in mold.fills:
		max_fill = maxf(max_fill, f)
	for i in MoldBox.HITS_TO_BREAK_BARE_HANDS:
		Input.action_press(&"interact")
		await _frames(2)
		Input.action_release(&"interact")
		await _frames(10)
	_check(await _until(func(): return world.entities.get_children().any(func(n): return n is CastPiece), 5.0),
		"client: casting replicated with its mesh")
	var pieces := world.entities.get_children().filter(func(n): return n is CastPiece)
	if pieces.size() > 0:
		var mi: Array = pieces[0].find_children("*", "MeshInstance3D", true, false)
		_check(mi.size() > 0 and mi[0].mesh.get_surface_count() > 0, "client: casting mesh rebuilt from the design code")
	_check(await _until(func(): return world.money > 0, 10.0), "client: money synced (%d $)" % world.money)


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
