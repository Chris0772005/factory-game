extends Node
## Garage (level 2), headless: the stations and loose items are there, the
## bucket fills at the trough, a hot mold quenched with it is ready at once
## and its castings may crack, and a hot casting thrown in the trough cools.

var _failures := 0
var world: GameWorld


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	world = load("res://scenes/garage.tscn").instantiate()
	add_child(world)
	await _frames(20)
	var me := world.local_player()
	var molds := get_tree().get_nodes_in_group(&"molds")
	var trough: QuenchTrough = get_tree().get_first_node_in_group(&"quench_troughs")
	var bucket: WaterBucket = get_tree().get_first_node_in_group(&"buckets")
	_check(me != null, "garage spawns the local worker")
	_check(_count(ModelBench) == 2 and molds.size() == 2 and _count(Furnace) == 1, "garage has two benches, two molds and a furnace")
	_check(trough != null and bucket != null, "quench trough and bucket are there")
	_check(get_tree().get_first_node_in_group(&"crucibles") != null, "crucible spawned in the furnace")
	if me == null or trough == null or bucket == null:
		_finish()
		return
	var mold: MoldBox = molds[0]
	_check(mold.cool_time > MoldBox.COOL_TIME, "garage molds cool longer (%.0f s)" % mold.cool_time)

	# A filled, still very hot mold.
	for code in [DrawingSamples.star().to_code(), DrawingSamples.smiley().to_code()]:
		mold.add_pattern(code)
	for i in MoldBox.RAMS_NEEDED:
		mold._rams = i
		mold._ram()
	var litres := 0.0
	for need in mold.needs:
		litres += need
	mold.receive_metal(litres + 0.01, 0.95, {&"copper": litres}, 0.5, 1.0 / 60.0)
	_check(mold.state == MoldBox.State.COOLING, "mold is cooling after the pour")

	# Empty bucket away from the trough does nothing; at the trough it fills.
	me.global_position = trough.global_position + Vector3(0, 0.1, 3.0)
	bucket.use_start(me)
	_check(not bucket.full, "bucket stays empty away from the trough")
	me.global_position = trough.global_position + Vector3(-0.9, 0.1, 0.0)
	bucket.use_start(me)
	_check(bucket.full, "bucket fills at the trough")

	# Tip it over the cooling mold.
	seed(7)
	var risk := mold.quench_risk()
	me.global_position = mold.global_position + Vector3(0, 0.1, 1.2)
	bucket.use_start(me)
	_check(not bucket.full, "bucket is empty after tipping")
	_check(mold.state == MoldBox.State.READY, "quenched mold is ready at once")
	_check(risk > 0.7, "quenching right after the pour is risky (%.0f %%)" % (risk * 100))
	var cracked := 0
	for c in mold._cracks:
		if c > 0.0:
			cracked += 1
	_check(mold._cracks.size() == 2, "a crack roll for every cavity")

	# Smash it: cracked cavities give castings with the crack defect.
	for i in MoldBox.HITS_TO_BREAK:
		mold.hit(true)
	await _frames(10)
	var with_crack := 0
	var pieces := get_tree().get_nodes_in_group(&"castings")
	for p in pieces:
		if (p as CastPiece).defects.get("crack", 0.0) > 0.0:
			with_crack += 1
	_check(pieces.size() == 2, "both castings came out")
	_check(with_crack == cracked, "castings carry the rolled cracks (%d of 2)" % cracked)

	# A hot casting dropped into the trough is cold at once.
	var hot: CastPiece = world.spawn_entity({type = "cast", code = DrawingSamples.star().to_code(), alloy = &"bronze",
		quality = 0.8, defects = {}, temperature = 0.9, pos = trough.global_position + Vector3(0, 1.0, 0), size = 0.5,
		thickness = 0.07})
	await _frames(90)
	_check(hot.temperature == 0.0, "hot casting quenched in the trough (temp %.2f)" % hot.temperature)

	# Sealed crates: too poor first, then buy one and melt it.
	var delivery: CrateDelivery = _first(CrateDelivery)
	_check(delivery != null, "crate delivery is there")
	if delivery:
		world.money = 10
		me.global_position = delivery.global_position + Vector3(-1.0, 0.1, 0)
		delivery.interact(me)
		await _frames(5)
		_check(me.held == null and world.money == 10, "no crate without the money")
		world.money = 100
		delivery.interact(me)
		await _frames(5)
		var crate := me.held as SealedCrate
		_check(crate != null and world.money == 100 - FoundryRules.CRATE_PRICE, "bought a sealed crate (%d $ left)" % world.money)
		_check(crate != null and FoundryRules.CRATES.has(crate.contents), "crate has rolled contents")
		var furnace: Furnace = _first(Furnace)
		var crucible: Crucible = get_tree().get_first_node_in_group(&"crucibles")
		if crate and furnace and crucible:
			var expect := 0.0
			for k in crate.melt_mix():
				expect += crate.melt_mix()[k]
			var before := crucible.amount
			me.release()
			crate.global_position = furnace.global_position + Vector3(0, 1.0, 0)
			crate.linear_velocity = Vector3.ZERO
			await _frames(30)
			_check(not is_instance_valid(crate) or crate.is_queued_for_deletion(), "furnace swallowed the crate")
			for i in 60:
				furnace.interact(me)
				await _frames(6)
			_check(absf(crucible.amount - before - expect) < 0.05, "crate melts into the crucible (+%.2f l of %.2f)" % [crucible.amount - before, expect])
	# The verdigris roof copper makes Grünspan.
	_check(FoundryRules.alloy_for(FoundryRules.CRATES[&"roof"].mix) == &"verdigris", "church-roof copper casts as Grünspan")
	_check(FoundryRules.alloy_for(FoundryRules.CRATES[&"watchmaker"].mix) == &"rotgold", "watchmaker's estate casts as Rotgold")
	_finish()


func _finish() -> void:
	print("GARAGE TESTS %s (%d failures)" % ["PASSED" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures else 0)


func _first(type: Variant) -> Node:
	for n in world.get_children():
		if is_instance_of(n, type):
			return n
	return null


func _count(type: Variant) -> int:
	return world.get_children().filter(func(n: Node) -> bool: return is_instance_of(n, type)).size()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(ok: bool, what: String) -> void:
	print("%s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
