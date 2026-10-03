extends Node
## Plays one full casting round in the backyard, headless:
## draw -> ram -> melt -> pour -> cool -> smash -> sell, plus a bronze buddy.

var _failures := 0
var world: GameWorld


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	world = load("res://scenes/backyard.tscn").instantiate()
	add_child(world)
	await _frames(20)
	var me := world.local_player()
	var bench: ModelBench = _first(ModelBench)
	var furnace: Furnace = _first(Furnace)
	var crucible: Crucible = get_tree().get_first_node_in_group(&"crucibles")
	var molds := get_tree().get_nodes_in_group(&"molds")
	var mold: MoldBox = molds[0]
	_check(bench != null and furnace != null and crucible != null and mold != null, "backyard has bench, furnace, crucible and molds")

	# 1. Draw: a smiley with a ring and two eyes.
	var d := Drawing.new()
	var ring := PackedVector2Array()
	for i in 25:
		var a := TAU * i / 24.0
		ring.append(Vector2(0.5, 0.5) + Vector2(cos(a), sin(a)) * 0.38)
	d.add_stroke(ring)
	d.add_stroke(PackedVector2Array([Vector2(0.38, 0.4)]))
	d.add_stroke(PackedVector2Array([Vector2(0.62, 0.4)]))
	d.add_stroke(PackedVector2Array([Vector2(0.32, 0.6), Vector2(0.5, 0.72), Vector2(0.68, 0.6)]))
	_check(bench.submit(d.to_code()), "bench places the drawing into a mold")
	_check(mold.state == MoldBox.State.PATTERNED and mold.patterns.size() == 1, "mold now has one pattern")

	# 2. Ram with a steady rhythm.
	for i in MoldBox.RAMS_NEEDED:
		mold.interact(me)
		await _frames(24)
	_check(mold.state == MoldBox.State.RAMMED, "six good rams make the mold ready (quality %.2f)" % mold.ram_quality)

	# 3. Melt scrap: drop cans into the furnace and pump the bellows.
	await _frames(30)
	_check(furnace.crucible == crucible, "crucible is docked in the furnace")
	for i in 8:
		var info: Dictionary = FoundryRules.SCRAP[&"scrap_can"]
		world.spawn_item(&"scrap_can", info.color, info.size, 0.4, furnace.global_position + Vector3(0, 1.0 + i * 0.3, 0))
	for i in 40:
		furnace.interact(me)
		await _frames(12)
	_check(crucible.amount > 2.0, "melted cans fill the crucible (%.2f l, %.0f%% heat)" % [crucible.amount, crucible.temperature * 100])

	# 4. Carry the crucible to the mold and pour.
	me.global_position = mold.global_position + Vector3(0, 0.1, 1.6)
	me.facing = PI
	await _frames(5)
	crucible.global_position = me._hand_target()
	await _frames(5)
	me.grab(crucible)
	await _frames(30)
	me.using = true
	me._perform(&"use_start")
	var waited := 0
	while mold.state == MoldBox.State.RAMMED or mold.state == MoldBox.State.FILLING:
		await _frames(1)
		me.using = true
		waited += 1
		if waited > 60 * 25:
			break
	me._perform(&"use_end")
	print("pour: fills=%s defects=%s amount_left=%.2f" % [mold.fills, mold.defects, crucible.amount])
	_check(mold.state == MoldBox.State.COOLING, "pouring fills the cavity")
	me.release()

	# 5. Cool and smash.
	await _frames(int(60 * (MoldBox.COOL_TIME + 0.5)))
	_check(mold.state == MoldBox.State.READY, "casting cools down")
	for i in MoldBox.HITS_TO_BREAK_BARE_HANDS:
		mold.interact(me)
	await _frames(10)
	var pieces := world.entities.get_children().filter(func(n): return n is CastPiece)
	_check(pieces.size() == 1, "smashing the mold reveals the casting")
	_check(mold.state == MoldBox.State.EMPTY, "mold is empty again")

	# 6. Sell.
	if pieces.size() > 0:
		var piece: CastPiece = pieces[0]
		print("cast: alloy=%s grade=%s value=%d" % [piece.alloy, piece.grade_name(), piece.value()])
		var crate: SellCrate = _first(SellCrate)
		var before := world.money
		piece.global_position = crate.global_position + Vector3(0, 0.4, 0)
		piece.linear_velocity = Vector3.ZERO
		await _frames(10)
		_check(world.money > before, "sell crate pays for the casting (+%d)" % (world.money - before))

	# 7. Bronze buddy: someone standing in the mold while metal pours in.
	var mold2: MoldBox = molds[1]
	mold2.add_pattern(d.to_code())
	for i in MoldBox.RAMS_NEEDED:
		mold2.interact(me)
		await _frames(24)
	var buddy := world.spawn_player(77)
	buddy.global_position = mold2.global_position + Vector3(0, MoldBox.BED.y + 0.05, 0)
	await _frames(10)
	mold2.receive_metal(0.2, 0.9, {&"copper": 0.2}, 0.5, 1.0 / 60.0)
	await _frames(5)
	var statues := world.entities.get_children().filter(func(n): return n is BronzeStatue)
	_check(statues.size() == 1, "worker in the mold becomes a bronze statue")
	_check(buddy.global_position.distance_to(mold2.global_position) > 2.0, "caught worker respawns away from the mold")

	print("TESTS %s (%d failures)" % ["PASSED" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures else 0)


func _first(type: Variant) -> Node:
	for n in world.find_children("*", "", true, false):
		if is_instance_of(n, type):
			return n
	return null


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		_failures += 1
