extends Node
## Two-process co-op bell in the Glockengießerei. Host: `-- --host --role=host --no-save`,
## client: `-- --join=127.0.0.1 --role=client --no-save`. The client draws the
## profile and turns the strickle; the host pours; the client digs the bell
## out and hears it ring. Both sides check what they see.

var role := ""
var world: GameWorld
var _failures := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):
			role = arg.trim_prefix("--role=")
	world = load("res://scenes/bell_foundry.tscn").instantiate()
	add_child(world)
	_run.call_deferred()


func _run() -> void:
	if role == "host":
		await _host()
	else:
		await _client()
	print("[%s] NET BELLS %s (%d failures)" % [role, "PASSED" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures else 0)


## The pit next to the first profile bench (where its drawings go).
func _pit() -> BellPit:
	var bench: ModelBench = world.get_children().filter(func(n): return n is ModelBench and n.bell_mode)[0]
	var best: BellPit = null
	for p in get_tree().get_nodes_in_group(&"bell_pits"):
		if best == null or (p as Node3D).global_position.distance_to(bench.global_position) < best.global_position.distance_to(bench.global_position):
			best = p
	return best


func _host() -> void:
	_check(await _until(func(): return world.entities.get_children().filter(func(n): return n is Player).size() > 1, 20.0),
		"host: client's worker in the bell foundry")
	var pit := _pit()
	_check(await _until(func(): return pit.state == BellPit.State.PROFILED, 20.0), "host: client's profile is in the pit")
	_check(await _until(func(): return pit.state == BellPit.State.TURNED, 30.0), "host: client turned the strickle")
	# Two crucibles in one go.
	var half := pit.need * 0.5
	pit.receive_metal(half, 0.95, {&"copper": half}, 0.5, 1.0 / 60.0)
	await _frames(30)
	pit.receive_metal(pit.need, 0.95, {&"copper": half}, 0.5, 1.0 / 60.0)
	_check(pit.state == BellPit.State.COOLING, "host: poured and cooling")
	pit._cool_left = 1.0
	_check(await _until(func(): return get_tree().get_nodes_in_group(&"bells").size() > 0, 30.0), "host: client dug the bell out")
	await _frames(300)


func _client() -> void:
	_check(await _until(func(): return world.local_player() != null, 15.0), "client: own worker spawned")
	var me := world.local_player()
	var pit := _pit()
	var bench: ModelBench = world.get_children().filter(func(n): return n is ModelBench and n.bell_mode)[0]
	bench._submit_remote.rpc_id(1, DrawingSamples.bell().to_code())
	_check(await _until(func(): return pit.state == BellPit.State.PROFILED, 10.0), "client: sees the strickle in the pit")
	me._do_teleport(pit.global_position + Vector3(0, 0.05, pit.outer_radius() + 0.45))
	me.facing = PI
	await _frames(30)
	_check(me.nearest_interactable() == pit, "client: the pit is the station in front")
	for i in BellPit.TURNS_NEEDED:
		me._request(&"use_start")
		await _frames(2)
		me._request(&"use_end")
		await _frames(34)
	# The host may already be pouring by the time this lands: TURNED or later.
	_check(await _until(func(): return pit.state >= BellPit.State.TURNED, 5.0), "client: the mold is turned (%d turns)" % pit.turns)
	_check(await _until(func(): return pit.state == BellPit.State.READY, 40.0), "client: sees the pour, cooling and ready")
	for i in BellPit.DIG_HITS_BARE_HANDS:
		me._request(&"use_start")
		await _frames(2)
		me._request(&"use_end")
		await _frames(14)
	_check(await _until(func(): return get_tree().get_nodes_in_group(&"bells").size() > 0, 8.0), "client: the bell is replicated")
	var bells := get_tree().get_nodes_in_group(&"bells")
	if bells.is_empty():
		return
	var bell := bells[0] as Bell
	_check(bell.mouth_radius == pit.mouth_radius and bell.note() == BellTone.note_name(BellTone.prime(bell.profile, pit.mouth_radius, &"bronze")),
		"client: same note (%s)" % bell.note())
	# Headless peers skip meshes; the profile they are built from must be there.
	_check(bell.profile != null and bell.profile.mesh(bell.mouth_radius).get_surface_count() > 0, "client: bell shape rebuilt from the profile")
	_check(await _until(func(): return bell._player.stream != null, 5.0), "client: hears the bell ring")


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
