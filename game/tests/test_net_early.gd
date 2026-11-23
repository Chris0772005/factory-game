extends Node
## Two-process check of a join that comes too early. Host: `-- --host --role=host --no-save`,
## client: `-- --join=127.0.0.1 --role=client --no-save`. In the game the server opens when "Hosten"
## is pressed and the hall loads a moment later; a mate who pressed "Beitreten" first can connect in
## between. Here the host's server is open from the start, but its hall only comes up after the
## client has connected and said which level it has loaded. The client must get its worker all
## the same (Network.replay_ready).

var role := ""
var world: GameWorld
var _failures := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):
			role = arg.trim_prefix("--role=")
	_run.call_deferred()


func _run() -> void:
	if role == "host":
		# No hall yet: wait for the client's hello, which nobody answers.
		_check(await _until(func(): return not Network._levels.is_empty(), 30.0), "host: the client said hello before the hall stood (%s)" % [Network._levels.values()])
		await _frames(30)
		world = load("res://scenes/garage.tscn").instantiate()
		add_child(world)
		_check(await _until(func(): return world.entities.get_children().filter(func(n): return n is Player).size() > 1, 20.0),
			"host: the client's worker is in the garage all the same")
		await _frames(240)
	else:
		world = load("res://scenes/garage.tscn").instantiate()
		add_child(world)
		_check(await _until(func(): return world.local_player() != null, 40.0), "client: got its worker although it came before the host's hall")
		await _frames(60)
	print("[%s] NET EARLY %s (%d failures)" % [role, "PASSED" if _failures == 0 else "FAILED", _failures])
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
