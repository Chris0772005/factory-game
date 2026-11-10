extends Node
## Two-process Suchauftrag in the garage. Host: `-- --host --role=host --no-save`,
## client: `-- --join=127.0.0.1 --role=client --no-save`. The host hides an
## item, the client sees the hunt, walks onto it first and gets the find.

var role := ""
var world: GameWorld
var _failures := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):
			role = arg.trim_prefix("--role=")
	world = load("res://scenes/garage.tscn").instantiate()
	add_child(world)
	_run.call_deferred()


func _run() -> void:
	var hunt: SearchHunt = get_tree().get_first_node_in_group(&"search_hunts")
	if role == "host":
		_check(await _until(func(): return world.entities.get_children().filter(func(n): return n is Player).size() > 1, 20.0),
			"host: client's worker in the garage")
		await _frames(60)
		_check(hunt.start(Vector3(4.5, 0.0, -3.0)), "host: hunt started")
		_check(await _until(func(): return not hunt.active, 20.0), "host: someone found it")
		_check(hunt.scores[1] == 1 and hunt.scores[0] == 0, "host: the find is the client's (%s)" % [hunt.scores])
		await _frames(120)
	else:
		_check(await _until(func(): return world.local_player() != null, 15.0), "client: own worker spawned")
		var me := world.local_player()
		_check(await _until(func(): return hunt.active, 20.0), "client: sees the hunt (%s)" % (hunt.item().name if hunt.active else "-"))
		_check(hunt.warmth(me.global_position) != "", "client: warmth hint (%s)" % hunt.warmth(me.global_position))
		me._do_teleport(hunt.item_pos + Vector3(0.2, 0.05, 0.0))
		_check(await _until(func(): return not hunt.active and hunt.scores[1] == 1, 8.0), "client: found it, tally synced (%s)" % [hunt.scores])
	print("[%s] NET SEARCH %s (%d failures)" % [role, "PASSED" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures else 0)


func _until(cond: Callable, timeout_s: float) -> bool:
	for i in int(timeout_s * 60):
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
