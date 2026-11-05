extends Node
## Two-process co-op round in the garage. Host: `-- --host --role=host --no-save`,
## client: `-- --join=127.0.0.1 --role=client --no-save`. The client picks up
## the bucket, scoops it full at the trough, quenches the mold the host just
## poured, then buys a sealed crate. Both sides check what they see.

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
	if role == "host":
		await _host()
	else:
		await _client()
	print("[%s] NET GARAGE %s (%d failures)" % [role, "PASSED" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures else 0)


func _bucket() -> WaterBucket:
	return get_tree().get_first_node_in_group(&"buckets") as WaterBucket


func _mold() -> MoldBox:
	return get_tree().get_nodes_in_group(&"molds")[0] as MoldBox


func _host() -> void:
	world.money = 200
	world.add_money(0)
	_check(await _until(func(): return world.entities.get_children().filter(func(n): return n is Player).size() > 1, 20.0),
		"host: client's worker in the garage")
	_check(await _until(func(): return _bucket() != null and _bucket().full, 30.0), "host: client scooped the bucket full")
	# Pour the mold now, so it is hot when the client tips the bucket.
	var mold := _mold()
	for code in [DrawingSamples.star().to_code(), DrawingSamples.cat().to_code()]:
		mold.add_pattern(code)
	for i in MoldBox.RAMS_NEEDED:
		mold._rams = i
		mold._ram()
	var litres := 0.0
	for need in mold.needs:
		litres += need
	mold.receive_metal(litres + 0.01, 0.95, {&"copper": litres}, 0.5, 1.0 / 60.0)
	_check(mold.state == MoldBox.State.COOLING, "host: mold poured and cooling")
	_check(await _until(func(): return mold.state == MoldBox.State.READY, 20.0), "host: client's bucket quenched the mold")
	_check(mold._cracks.size() == 2, "host: crack rolls for both cavities")
	_check(await _until(func(): return world.money == 200 - FoundryRules.CRATE_PRICE, 20.0), "host: client bought a crate (%d $)" % world.money)
	var buyers := world.entities.get_children().filter(func(n): return n is Player and n.peer_id != 1)
	_check(not buyers.is_empty() and await _until(func(): return buyers[0].held is SealedCrate, 5.0), "host: the crate is in the client's hands")
	await _frames(240)


func _client() -> void:
	_check(await _until(func(): return world.local_player() != null, 15.0), "client: own worker spawned")
	var me := world.local_player()
	var bucket := _bucket()
	var trough: QuenchTrough = get_tree().get_first_node_in_group(&"quench_troughs")
	_check(bucket != null and trough != null, "client: bucket and trough replicated")
	if me == null or bucket == null or trough == null:
		return
	# Pick the bucket up (it stands in front of the worker).
	me._do_teleport(bucket.global_position + Vector3(0, 0.05, 0.75))
	me.facing = PI
	await _frames(20)
	me._request(&"grab")
	_check(await _until(func(): return me.holding and me.held_name == String(bucket.name), 5.0), "client: grabbed the bucket")
	# Scoop at the trough (walking: a carried bucket stays on its leash).
	await _walk(me, trough.global_position + Vector3(-0.2, 0.05, 1.8))
	await _frames(20)
	me._request(&"use_start")
	await _frames(2)
	me._request(&"use_end")
	_check(await _until(func(): return bucket.full, 5.0), "client: bucket shows full")
	# Wait for the host's pour, then tip the bucket over the mold.
	var mold := _mold()
	_check(await _until(func(): return mold.state == MoldBox.State.COOLING, 20.0), "client: sees the hot mold")
	await _walk(me, mold.global_position + Vector3(0, 0.05, 1.25))
	me.facing = PI
	_check(me.holding, "client: still carries the bucket at the mold")
	await _frames(20)
	me._request(&"use_start")
	await _frames(2)
	me._request(&"use_end")
	_check(await _until(func(): return mold.state == MoldBox.State.READY, 5.0), "client: quenched mold is ready")
	_check(await _until(func(): return not bucket.full, 3.0), "client: bucket shows empty again")
	_check(mold.metal_temperature <= 0.15, "client: the glow died with the quench (%.2f)" % mold.metal_temperature)
	# Put it down and buy a crate.
	me._request(&"release")
	_check(await _until(func(): return not me.holding, 5.0), "client: bucket put down")
	var delivery: CrateDelivery = world.find_children("*", "CrateDelivery", true, false)[0]
	var face := delivery.global_transform.basis.z
	me._do_teleport(delivery.global_position + face * 1.0 + Vector3(0, 0.05, 0))
	me.facing = atan2(-face.x, -face.z)
	await _frames(20)
	me._request(&"use_start")
	await _frames(2)
	me._request(&"use_end")
	_check(await _until(func(): return me.holding and world.entities.get_node_or_null(me.held_name) is SealedCrate, 8.0),
		"client: holds the sealed crate")
	_check(await _until(func(): return world.money == 200 - FoundryRules.CRATE_PRICE, 5.0), "client: money synced (%d $)" % world.money)


## Moves the worker in short steps, like walking, so held items follow.
func _walk(me: Player, to: Vector3) -> void:
	var from := me.global_position
	var steps := maxi(1, ceili(from.distance_to(to) / 0.12))
	for i in steps:
		me._do_teleport(from.lerp(to, float(i + 1) / steps))
		await _frames(2)
	await _frames(20)


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
