extends Node
## Two-process check in the scrap hall that every node RPCs travel to has the same path on both
## peers. Host: `-- --host --role=host --no-save`, client: `-- --join=127.0.0.1 --role=client
## --no-save --shift-names=37`. The engine numbers nodes without a name through per process
## ("@Node3D@57"), and the client has made others before the level loads (--shift-names), as a
## player has who sat in the menu for a while: a station that relied on such a number would be
## somebody else on the other side. The host buys the foundry corner while the client is in, so
## its stations are built at another moment there than here. Then the client sends the paths it
## has, the host compares them with its own, and the furnace's heat has to arrive.

var role := ""
var world: GameWorld
var _failures := 0
var _theirs := PackedStringArray()
var _got := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):
			role = arg.trim_prefix("--role=")
	world = load("res://scenes/scrap_hall.tscn").instantiate()
	add_child(world)
	_run.call_deferred()


func _run() -> void:
	if role == "host":
		_check(await _until(func(): return world.entities.get_children().filter(func(n): return n is Player).size() > 1, 20.0),
			"host: client's worker in the hall")
		await _frames(60)
		world.add_money(1000)
		_check(world.upgrades.buy(&"foundry_corner"), "host: buys the foundry corner while the client is in")
		await _frames(30)
		var furnace := get_tree().get_first_node_in_group(&"furnaces") as Furnace
		_check(furnace != null and not String(furnace.name).begins_with("@"), "host: the furnace has a name of its own (%s)" % (String(furnace.name) if furnace else "-"))
		_check(await _until(func(): return _got, 25.0), "host: the client sent its paths")
		var mine := _paths()
		var missing := PackedStringArray()
		var extra := PackedStringArray()
		var numbered := PackedStringArray()
		for path in mine:
			if not path in _theirs:
				missing.append(path)
			if "@" in path:
				numbered.append(path)
		for path in _theirs:
			if not path in mine:
				extra.append(path)
		_check(mine.size() >= 30, "host: the hall has many nodes that RPCs travel to (%d)" % mine.size())
		_check(numbered.is_empty(), "host: none of them goes by a number of the engine (%s)" % [numbered])
		_check(missing.is_empty() and extra.is_empty(), "host: the client has them under the same paths (only here: %s, only there: %s)" % [missing, extra])
		# The corner's furnace, built late on the other side, still hears the host.
		for i in 90:
			if furnace:
				furnace.heat = 0.7
			await get_tree().physics_frame
	else:
		_check(await _until(func(): return world.local_player() != null, 15.0), "client: own worker spawned")
		_check(await _until(func(): return get_tree().get_first_node_in_group(&"furnaces") != null, 25.0), "client: the foundry corner arrives")
		await _frames(20)
		_report.rpc_id(1, _paths())
		var furnace := get_tree().get_first_node_in_group(&"furnaces") as Furnace
		_check(await _until(func(): return furnace != null and furnace.heat > 0.4, 15.0), "client: the furnace's heat comes over (%.2f)" % (furnace.heat if furnace else -1.0))
	print("[%s] NET NAMES %s (%d failures)" % [role, "PASSED" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures else 0)


@rpc("any_peer", "call_remote", "reliable")
func _report(paths: PackedStringArray) -> void:
	_theirs = paths
	_got = true


## The paths (from the level) of all nodes whose script declares RPCs. What comes and goes through
## the spawner (workers, things) is left out: it has its names from there.
func _paths() -> PackedStringArray:
	var out := PackedStringArray()
	var todo: Array[Node] = [world]
	while not todo.is_empty():
		var node: Node = todo.pop_back()
		if node == world.entities:
			continue
		if node != world and _has_rpcs(node):
			out.append(String(world.get_path_to(node)))
		for child in node.get_children():
			todo.append(child)
	out.sort()
	return out


func _has_rpcs(node: Node) -> bool:
	var s := node.get_script() as Script
	while s:
		var config: Variant = s.get_rpc_config()
		if config is Dictionary and not (config as Dictionary).is_empty():
			return true
		s = s.get_base_script()
	return false


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
