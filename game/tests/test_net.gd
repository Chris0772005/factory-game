extends Node
## Two-process network test. Start one instance with `-- --host --role=host`
## and one with `-- --join=127.0.0.1 --role=client`. The client walks to the
## crates and grabs one; both sides check what they see.

var role := ""
var world: GameWorld
var _failures := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):
			role = arg.trim_prefix("--role=")
	world = load("res://scenes/sandbox.tscn").instantiate()
	add_child(world)
	_run.call_deferred()


func _run() -> void:
	if role == "host":
		await _host()
	else:
		await _client()
	print("[%s] NET TESTS %s (%d failures)" % [role, "PASSED" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures else 0)


func _host() -> void:
	var waited := 0
	while world.entities.get_node_or_null("2") == null and waited < 600:
		var ids := world.entities.get_children().filter(func(n): return n is Player)
		if ids.size() > 1:
			break
		await get_tree().physics_frame
		waited += 1
	var remote: Player = null
	for n in world.entities.get_children():
		if n is Player and n.peer_id != 1:
			remote = n
	_check(remote != null, "host sees the client's worker")
	if remote == null:
		return
	var start := remote.global_position
	var max_dist := 0.0
	var grabbed := false
	for i in 420:
		await get_tree().physics_frame
		if not is_instance_valid(remote):
			break
		max_dist = maxf(max_dist, remote.global_position.distance_to(start))
		grabbed = grabbed or remote.held != null
	_check(max_dist > 1.0, "host sees the client walk (%.2f m)" % max_dist)
	_check(grabbed, "host simulates the client's grab")


func _client() -> void:
	var waited := 0
	while world.local_player() == null and waited < 600:
		await get_tree().physics_frame
		waited += 1
	var me := world.local_player()
	_check(me != null, "client receives its own worker")
	if me == null:
		return
	var items := world.entities.get_children().filter(func(n): return n is Item)
	_check(items.size() >= 13, "client receives replicated items (%d)" % items.size())
	_check(items.size() > 0 and items[0].freeze, "client copies of items are frozen")
	await _frames(20)
	var start := me.global_position
	Input.action_press(&"move_forward")
	await _frames(40)
	Input.action_release(&"move_forward")
	await _frames(20)
	_check(me.global_position.z < start.z - 1.0, "client walks locally")
	Input.action_press(&"grab")
	await _frames(2)
	Input.action_release(&"grab")
	await _frames(60)
	_check(me.holding, "client is told it holds an item")
	var nearest: Item = null
	for it in items:
		if nearest == null or it.global_position.distance_to(me._hand_target()) < nearest.global_position.distance_to(me._hand_target()):
			nearest = it
	_check(nearest and nearest.global_position.distance_to(me._hand_target()) < 1.0,
		"replicated crate is at the client's hands (%.2f m)" % nearest.global_position.distance_to(me._hand_target()))
	await _frames(240)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(ok: bool, label: String) -> void:
	print("[%s] %s %s" % [role, "ok  " if ok else "FAIL", label])
	if not ok:
		_failures += 1
