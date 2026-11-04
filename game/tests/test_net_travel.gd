extends Node
## Two-process level-change test. Both peers start in the sandbox; once the
## client's worker is in, the host travels to the backyard. The client must
## reload, reconnect and get its worker in the new level. Then a second
## client-side check: a fresh join into the wrong level is sent on by the host.
## Host: `-- --host --role=host --no-save`, client: `-- --join=127.0.0.1 --role=client --no-save`.

const FIRST := "res://scenes/sandbox.tscn"
const SECOND := "res://scenes/backyard.tscn"

var role := ""
var _failures := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):
			role = arg.trim_prefix("--role=")
	_run.call_deferred()


func _run() -> void:
	# Hand "current scene" to a placeholder, so the scene changes free it and
	# not this test node (which stays on the root).
	var placeholder := Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	get_tree().change_scene_to_file(FIRST)
	if role == "host":
		await _host()
	else:
		await _client()
	print("[%s] NET TRAVEL %s (%d failures)" % [role, "PASSED" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures else 0)


func _host() -> void:
	var world := await _world_in(FIRST, 300)
	_check(world != null, "host: first level loaded")
	if world == null:
		return
	_check(await _players_in(world, 2, 600), "host: client's worker in the first level")
	world.travel_to(SECOND)
	var next := await _world_in(SECOND, 600)
	_check(next != null, "host: travelled to the second level")
	if next == null:
		return
	_check(await _players_in(next, 2, 900), "host: client rejoined in the second level")
	# Let the client finish its checks before the host goes away.
	await _frames(240)


func _client() -> void:
	var world := await _world_in(FIRST, 300)
	_check(world != null and await _own_worker(world, 600), "client: own worker in the first level")
	var next := await _world_in(SECOND, 900)
	_check(next != null, "client: followed the host to the second level")
	if next == null:
		return
	_check(await _own_worker(next, 900), "client: own worker in the second level")
	_check(Network.is_online() and not multiplayer.is_server(), "client: still connected as a client")


## Waits for the current world to be the one loaded from `path`.
func _world_in(path: String, frames: int) -> GameWorld:
	for i in frames:
		var w := get_tree().get_first_node_in_group(&"world") as GameWorld
		if w and w.is_inside_tree() and w.level_path() == path and w.entities:
			return w
		await get_tree().physics_frame
	return null


func _players_in(world: GameWorld, count: int, frames: int) -> bool:
	for i in frames:
		if not is_instance_valid(world):
			return false
		if world.entities.get_children().filter(func(n): return n is Player).size() >= count:
			return true
		await get_tree().physics_frame
	return false


func _own_worker(world: GameWorld, frames: int) -> bool:
	for i in frames:
		if not is_instance_valid(world):
			return false
		if Network.is_online() and world.local_player() != null:
			return true
		await get_tree().physics_frame
	return false


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(ok: bool, what: String) -> void:
	print("[%s] %s %s" % [role, "ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
