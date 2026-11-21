extends Node
## Two-process test of the hardware store, the bank and the stall. Host: `-- --host --role=host
## --no-save`, client: `-- --join=127.0.0.1 --role=client --no-save`. The client buys the gloves at
## the bench with [F] and takes a loan at the bank's counter (asked, then confirmed): the host pays
## and books, both see the tool, the money and the debt. The host lays a find on the stall and lets
## the first customer buy it: the client sees the piece come and go, and a quarter of the price goes
## to the bank on both screens.

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
	var stall := get_tree().get_first_node_in_group(YardStall.GROUP) as YardStall
	var loans := get_tree().get_first_node_in_group(BankCounter.GROUP) as BankCounter
	var gloves: ToolOffer = null
	for node in get_tree().get_nodes_in_group(ToolOffer.GROUP):
		if (node as ToolOffer).upgrade == &"gloves":
			gloves = node
	var bank := world.bank
	var unit := world.get_node_or_null(^"Lockup_1") as StorageLockup
	var post := get_tree().get_first_node_in_group(PostOffice.GROUP) as PostOffice
	if stall == null or loans == null or gloves == null or bank == null or unit == null or post == null:
		_check(false, "the quarter has the store's bench, the bank's counter and the stall")
		_done()
		return
	# Nothing drives through this test, and no mission pays into its sums.
	var traffic := get_tree().get_first_node_in_group(TownTraffic.GROUP) as TownTraffic
	if traffic:
		traffic.free()
	Missions.of(get_tree()).free()
	if role == "host":
		# The townspeople do not buy by themselves here: the sale below is the only one.
		stall.walkers = null
		# What the crew has before the mate joins: he must find it as it is, not only hear of the next change.
		var bucket := get_tree().get_first_node_in_group(&"scrap_buckets") as ScrapBucket
		world.upgrades.owned[&"bucket_big"] = true
		world.add_money(120 - world.money)
		bucket.contents = [&"junk_bolt", &"scrap_can", &"hot_pistol"] as Array[StringName]
		bucket._changed()
		# A lot the test knows behind the first shutter (nobody else bids), and three mail orders.
		unit.stock(1, 9)
		unit._rival_limit = 0
		post.set_orders([&"scrap_kettle", &"scrap_can", &"scrap_ring"])
		if world.entities.get_children().filter(func(n): return n is Player).size() > 1:
			# He was quicker than this test: tell him the usual way.
			world.upgrades._broadcast()
		_check(await _until(func(): return world.entities.get_children().filter(func(n): return n is Player).size() > 1, 20.0),
			"host: client's worker in the hall")
		_check(await _until(func(): return world.has_upgrade(&"gloves"), 25.0), "host: the client bought the gloves")
		_check(world.money == 30, "host: paid from the crew's money (%d $)" % world.money)
		_check(await _until(func(): return bank.debt == 230, 30.0), "host: the client took the loan")
		_check(world.money == 230 and bank.owed == 230, "host: 200 $ paid out, 230 $ owed (%d $)" % world.money)
		# The client bids at the lock-up; the test calls the lot back before the hammer falls.
		_check(await _until(func(): return unit.state == StorageLockup.State.BIDDING and unit.ours, 30.0), "host: the client's bid is in (%d $)" % unit.bid)
		_check(world.money == 230, "host: nothing is paid before the hammer falls")
		await _frames(30)
		unit.rest(1000.0)
		# A kettle on the stall, and the first customer takes it.
		await _frames(30)
		var info: Dictionary = FoundryRules.find_info(&"scrap_kettle")
		var kettle := world.spawn_item(&"scrap_kettle", info.color, info.size, 0.4, stall.to_global(stall.place_pos(5) + Vector3(0, 0.14, 0)))
		await _frames(90)
		_check(kettle in stall.goods(), "host: the kettle lies on the stall")
		stall._serve(0)
		await _frames(5)
		_check(world.money == 252 and bank.debt == 222 and stall.goods().is_empty(), "host: sold for 30 $, of which 8 $ went to the bank (%d $, %d $ owed)" % [world.money, bank.debt])
		await _frames(200)
	else:
		_check(await _until(func(): return world.local_player() != null, 15.0), "client: own worker spawned")
		var me := world.local_player()
		_check(await _until(func(): return world.money == 120, 20.0), "client: sees the crew's money as it stood when he joined")
		_check(await _until(func(): return world.has_upgrade(&"bucket_big"), 6.0), "client: knows what the crew owned before he came")
		var bucket := get_tree().get_first_node_in_group(&"scrap_buckets") as ScrapBucket
		_check(await _until(func(): return bucket != null and bucket.count == 3 and bucket.hot == 1, 6.0), "client: and what lay in the bucket (%d finds)" % (bucket.count if bucket else -1))
		# The gloves at the bench.
		me._do_teleport(Vector3(gloves.global_position.x, 0.06, gloves.global_position.z - 1.15))
		me.facing = 0.0
		await _frames(40)
		_check(me.nearest_interactable() == gloves and gloves.hint(me).begins_with("[F]"), "client: stands at the gloves (%s)" % gloves.hint(me))
		await _press()
		_check(await _until(func(): return world.has_upgrade(&"gloves") and world.money == 30, 6.0), "client: F at the bench reaches the host, the gloves are the crew's")
		_check(gloves.hint(me).contains("habt ihr schon"), "client: the bench says so (%s)" % gloves.hint(me))
		# The loan: asked, then confirmed.
		me._do_teleport(loans.global_position + Vector3(0, 0.06, -0.55))
		me.facing = 0.0
		await _frames(40)
		_check(me.nearest_interactable() == loans and loans.hint(me).contains("200 $ sofort"), "client: stands at the bank's counter (%s)" % loans.hint(me))
		await _press()
		_check(await _until(func(): return loans.hint(me).begins_with("[F] Sicher?"), 6.0), "client: the first F only asks (%s)" % loans.hint(me))
		_check(bank.debt == 0 and world.money == 30, "client: nothing is borrowed yet")
		await _frames(20)
		await _press()
		_check(await _until(func(): return bank.debt == 230 and world.money == 230, 6.0), "client: the second F takes the loan: 230 $ in hand, 230 $ owed")
		# With 230 $ in hand the counter offers to pay it straight back, and a third F only asks.
		_check(loans.hint(me).begins_with("[F] Kredit ablösen · 230 $"), "client: the counter shows the debt (%s)" % loans.hint(me))
		await _press()
		_check(await _until(func(): return loans.hint(me).begins_with("[F] Sicher? 230 $ zahlen"), 6.0), "client: a third F only asks whether to pay it back (%s)" % loans.hint(me))
		_check(bank.debt == 230 and world.money == 230, "client: the loan stands")
		# What he found when he came: the lot behind the first shutter and the mail orders.
		_check(unit.state == StorageLockup.State.SHUT and unit.pieces == 9 and unit.theme == 1, "client: sees the lot that waited when he joined (%d pieces)" % unit.pieces)
		_check(post.orders.size() == 3 and post.orders[0].kind == &"scrap_kettle" and int(post.orders[1].count) == 3, "client: and the three mail orders")
		me._do_teleport(unit.global_position + Vector3(0, 0.06, -1.6))
		me.facing = 0.0
		await _frames(40)
		_check(me.nearest_interactable() == unit and unit.hint(me).begins_with("[F] Mitbieten"), "client: stands at the lock-up (%s)" % unit.hint(me))
		await _press()
		_check(await _until(func(): return unit.state == StorageLockup.State.BIDDING and unit.ours and unit.bid == unit.opening, 6.0),
			"client: F at the shutter reaches the host, the crew leads with %d $" % unit.bid)
		_check(unit.hint(me).begins_with("Ihr bietet") and world.money == 230, "client: the sign says so, nothing is paid yet (%s)" % unit.hint(me))
		_check(await _until(func(): return unit.state == StorageLockup.State.RESTING, 15.0), "client: sees the lot called back")
		# The host's sale at the stall.
		_check(await _until(func(): return stall.goods().size() == 1, 15.0), "client: sees the kettle on the stall")
		_check(await _until(func(): return world.money == 252 and bank.debt == 222, 15.0), "client: sees the sale and the bank's share (%d $, %d $ owed)" % [world.money, bank.debt])
		_check(await _until(func(): return stall.goods().is_empty(), 6.0), "client: the kettle is gone")
	_done()


## The local player presses [F] once.
func _press() -> void:
	Input.action_press(&"interact")
	await _frames(2)
	Input.action_release(&"interact")
	await _frames(2)


func _done() -> void:
	print("[%s] NET SHOPS %s (%d failures)" % [role, "PASSED" if _failures == 0 else "FAILED", _failures])
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
