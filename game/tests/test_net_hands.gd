extends Node
## Two-process test of the hired hands. Host: `-- --host --role=host --no-save`, client:
## `-- --join=127.0.0.1 --role=client --no-save`. The host has hired the stall keeper before the
## client joins: he must find her at her table. The client hires the digger in the labour exchange
## with [F]: the host pays and sends him off, both see him walk to the yard and dig into the bucket.
## The host hires the runner and fills the bucket: the client sees him take the load. Then the
## client sends the digger home with two presses of [F].

var role := ""
var world: FoundryLevel
var _failures := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):
			role = arg.trim_prefix("--role=")
	world = load("res://scenes/scrap_hall.tscn").instantiate()
	add_child(world)
	_run.call_deferred()


func _run() -> void:
	var digger := HiredHand.of(get_tree(), &"digger")
	var runner := HiredHand.of(get_tree(), &"runner")
	var keeper := HiredHand.of(get_tree(), &"keeper")
	var stall := get_tree().get_first_node_in_group(YardStall.GROUP) as YardStall
	if digger == null or runner == null or keeper == null or stall == null:
		_check(false, "the quarter has three hands for hire and the crew's stall")
		_done()
		return
	# Nothing drives through this test, and no mission pays into its sums.
	var traffic := get_tree().get_first_node_in_group(TownTraffic.GROUP) as TownTraffic
	if traffic:
		traffic.free()
	Missions.of(get_tree()).free()
	if role == "host":
		stall.walkers = null
		var bucket := get_tree().get_first_node_in_group(&"scrap_buckets") as ScrapBucket
		# What the crew has before the mate joins: Rosa at the stall.
		world.add_money(500 - world.money)
		keeper.interact(world.local_player())
		keeper.start_at_work()
		_check(keeper.state == HiredHand.State.WORKING and world.money == 400, "host: Rosa is hired before the client joins (%d $)" % world.money)
		_check(await _until(func(): return world.entities.get_children().filter(func(n): return n is Player).size() > 1, 20.0),
			"host: client's worker in the hall")
		_check(await _until(func(): return digger.state == HiredHand.State.COMING, 40.0), "host: the client hired Hugo")
		_check(world.money == 340, "host: the fee came out of the crew's money (%d $)" % world.money)
		_check(await _until(func(): return digger.state == HiredHand.State.WORKING, 70.0), "host: Hugo reached the yard")
		_check(await _until(func(): return digger.digging, 20.0), "host: and digs")
		# Ede, and a bucket worth a trip.
		runner.interact(world.local_player())
		runner.start_at_work()
		while bucket.count < 9:
			bucket.add(&"junk_bolt")
		_check(await _until(func(): return runner.carrying and runner.loaded >= 9, 30.0), "host: Ede takes the load (%d pieces)" % runner.loaded)
		_check(await _until(func(): return digger.state == HiredHand.State.LEAVING, 60.0), "host: the client sent Hugo home")
		_check(HiredHand.to_save(get_tree()) == ["runner", "keeper"], "host: the pay roll names Ede and Rosa")
		await _frames(200)
	else:
		_check(await _until(func(): return world.local_player() != null, 15.0), "client: own worker spawned")
		var me := world.local_player()
		_check(await _until(func(): return world.money == 400, 20.0), "client: sees the crew's money as it stood when he joined")
		_check(await _until(func(): return keeper.state == HiredHand.State.WORKING and keeper.serving, 10.0), "client: finds Rosa at work, hired before he came")
		_check(keeper.global_position.distance_to(stall.global_position) < 2.5 and HiredHand.serving_at(stall) == keeper,
			"client: she stands at the stall (%.1f m)" % keeper.global_position.distance_to(stall.global_position))
		var paths_ok := true
		for hand: HiredHand in [digger, runner, keeper]:
			paths_ok = paths_ok and not ("@" in String(hand.get_path()))
		_check(paths_ok, "client: every hand has a name of its own (%s)" % digger.get_path())
		# Hugo in the labour exchange.
		_check(digger.state == HiredHand.State.WAITING, "client: Hugo waits to be hired")
		_stand_at(me, digger, 1.05)
		await _frames(40)
		_check(me.nearest_interactable() == digger and digger.hint(me).begins_with("[F] Hugo anheuern"), "client: stands in front of Hugo (%s)" % digger.hint(me))
		await _press()
		_check(await _until(func(): return digger.state == HiredHand.State.COMING and world.money == 340, 6.0), "client: F reaches the host, Hugo is hired (%d $)" % world.money)
		_check(digger.hint(me).contains("auf dem Weg"), "client: his hint says he is on his way (%s)" % digger.hint(me))
		_check(await _until(func(): return digger.state == HiredHand.State.WORKING, 70.0), "client: sees him arrive")
		_check(digger.global_position.z < 12.0 and absf(digger.global_position.x) < 14.0, "client: he stands in the yard here too (%.1f, %.1f)" % [digger.global_position.x, digger.global_position.z])
		_check(await _until(func(): return digger.digging, 20.0), "client: sees him dig")
		var bucket := get_tree().get_first_node_in_group(&"scrap_buckets") as ScrapBucket
		_check(await _until(func(): return bucket != null and bucket.count >= 1, 15.0), "client: and the bucket fill")
		_check(digger.hint(me).contains("wühlt"), "client: the hint says what he does (%s)" % digger.hint(me))
		# Ede with his load.
		_check(await _until(func(): return runner.state == HiredHand.State.WORKING and runner.carrying and runner.loaded >= 9, 40.0),
			"client: sees Ede carry the load (%d pieces)" % runner.loaded)
		# Hugo is sent home: two presses in a row.
		_stand_at(me, digger, -1.0)
		await _frames(40)
		_check(me.nearest_interactable() == digger, "client: stands by Hugo at the heap")
		await _press()
		await _press()
		_check(await _until(func(): return digger.state == HiredHand.State.LEAVING, 6.0), "client: F twice sends him home")
		_check(digger.hint(me).contains("Labour Exchange"), "client: the hint says where he goes (%s)" % digger.hint(me))
	_done()


## Puts `me` `ahead` metres in front of `hand` (behind it, if negative), looking at it.
func _stand_at(me: Player, hand: HiredHand, ahead: float) -> void:
	var front := hand.global_transform.basis.z
	me._do_teleport(Vector3(hand.global_position.x, 0.06, hand.global_position.z) + Vector3(front.x, 0, front.z) * ahead)
	me.facing = atan2(-front.x * signf(ahead), -front.z * signf(ahead))


## The local player presses [F] once.
func _press() -> void:
	Input.action_press(&"interact")
	await _frames(2)
	Input.action_release(&"interact")
	await _frames(2)


func _done() -> void:
	print("[%s] NET HANDS %s (%d failures)" % [role, "PASSED" if _failures == 0 else "FAILED", _failures])
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
