extends Node
## Bells, headless: profiles from drawings, the shell mesh and its metal, the
## pitch rule (size, alloy), note names, crooked profiles and the rendered tone.

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var bell := BellProfile.from_drawing(DrawingSamples.bell())
	_check(bell != null, "bell outline becomes a profile")
	var flat := Drawing.new()
	flat.add_stroke(PackedVector2Array([Vector2(0.2, 0.5), Vector2(0.8, 0.52)]))
	_check(BellProfile.from_drawing(flat) == null, "a flat line is not a bell")
	if bell == null:
		_finish()
		return
	_check(bell.radius[BellProfile.SAMPLES - 1] >= 0.99 and bell.radius[0] < 0.6, "crown narrow, mouth widest (%.2f / %.2f)" % [bell.radius[0], bell.radius[BellProfile.SAMPLES - 1]])
	var mesh := bell.mesh(0.35)
	_check(mesh != null and mesh.get_surface_count() > 0, "lathe shell mesh built")
	var litres := bell.litres(0.35)
	_check(litres > 3.0 and litres < 14.0, "a 70 cm bell needs a few crucibles (%.1f l)" % litres)
	_check(bell.litres(0.5) > litres * 2.0, "metal grows with the cube of the size (%.1f l at 1 m)" % bell.litres(0.5))
	var f := BellTone.prime(bell, 0.35, &"bronze")
	var f_big := BellTone.prime(bell, 0.7, &"bronze")
	_check(f > 250.0 and f < 1200.0, "a 70 cm bronze bell sings at %.0f Hz (%s)" % [f, BellTone.note_name(f)])
	_check(absf(f_big - f * 0.5) < 1.0, "twice as wide = one octave lower (%.0f Hz)" % f_big)
	_check(BellTone.prime(bell, 0.35, &"alu") > f, "aluminium rings higher than bronze")
	_check(BellTone.note_name(440.0) == "A4" and BellTone.note_name(523.25) == "C5" and BellTone.note_name(493.88) == "H4", "German note names (A4, C5, H4)")
	var crooked := BellProfile.from_drawing(DrawingSamples.crooked_bell())
	_check(crooked != null and crooked.irregularity > bell.irregularity + 0.3, "shaky outline is irregular (%.2f vs %.2f)" % [crooked.irregularity if crooked else -1.0, bell.irregularity])
	_check(BellTone.verdict(bell) == "rein", "clean bell sounds pure (%.2f)" % BellTone.purity(bell))
	_check(crooked != null and BellTone.verdict(crooked) != "rein", "shaky bell sounds crooked (%s)" % (BellTone.verdict(crooked) if crooked else "?"))
	var t0 := Time.get_ticks_msec()
	var wav := BellTone.stream(bell, 0.35, &"bronze")
	var ms := Time.get_ticks_msec() - t0
	_check(wav != null and wav.data.size() > BellTone.RATE * 2 * 2, "tone rendered (%.1f s, %d ms)" % [wav.data.size() / 2.0 / BellTone.RATE, ms])
	_check(BellTone.stream(bell, 0.35, &"bronze") == wav, "tone is cached")
	await _pit_round()
	await _hall_round()
	_finish()


## A full bell in a pit (staged in the garage): profile, turning, a pour in
## two crucibles with a short break, cooling, digging out, ringing, selling.
func _pit_round() -> void:
	var world: GameWorld = load("res://scenes/garage.tscn").instantiate()
	add_child(world)
	await _frames(10)
	var pit := BellPit.new()
	pit.position = Vector3(-1.0, 0, -1.2)
	world.add_child(pit)
	var bench := ModelBench.new()
	bench.bell_mode = true
	bench.position = Vector3(-1.0, 0, -3.6)
	world.add_child(bench)
	await _frames(5)
	var me := world.local_player()
	_check(not bench.submit(DrawingSamples.smiley().to_code()) or pit.state == BellPit.State.PROFILED, "bench sends drawings to the pit")
	if pit.state != BellPit.State.EMPTY:
		pit.state = BellPit.State.EMPTY
	_check(bench.submit(DrawingSamples.bell().to_code()) and pit.state == BellPit.State.PROFILED, "bell profile reaches the pit")
	for i in BellPit.TURNS_NEEDED:
		pit.interact(me)
	_check(pit.state == BellPit.State.TURNED and pit.need > 3.0, "turning the strickle shapes the mold (needs %.1f l)" % pit.need)
	var half := pit.need * 0.5
	pit.receive_metal(half, 0.95, {&"copper": half * 0.9, &"zinc_brass": half * 0.1}, 0.5, 1.0 / 60.0)
	_check(pit.state == BellPit.State.FILLING, "first crucible goes in")
	pit.receive_metal(pit.need - half + 0.01, 0.95, {&"copper": half}, 0.5, 1.0 / 60.0)
	_check(pit.state == BellPit.State.COOLING and pit.defects.get("cold_shut", 0.0) == 0.0, "a quick second crucible fills it without a cold shut")
	pit._cool_left = 0.01
	await _frames(3)
	_check(pit.state == BellPit.State.READY, "the bell cools")
	for i in BellPit.DIG_HITS:
		pit.hit(true)
	await _frames(5)
	var bells := get_tree().get_nodes_in_group(&"bells")
	_check(bells.size() == 1, "digging out lifts the bell")
	if bells.is_empty():
		return
	var b := bells[0] as Bell
	_check(b.alloy == &"bronze" and b.verdict() == "rein", "bronze bell, pure (%s %s)" % [b.alloy, b.verdict()])
	_check(b.note() == BellTone.note_name(BellTone.prime(bell_profile_of(b), 0.35, &"bronze")), "rings in %s" % b.note())
	_check(b.value() > 100, "worth %d $" % b.value())
	await _frames(40)
	_check(b._player.stream != null, "the bell rang at the reveal")
	var crate: SellCrate = world.find_children("*", "SellCrate", true, false)[0]
	var before := world.money
	b.global_position = crate.global_position + Vector3(0, 0.6, 0)
	b.linear_velocity = Vector3.ZERO
	await _frames(30)
	_check(world.money > before, "bell sold (+%d $)" % (world.money - before))
	# Quenched hot, a bell cracks.
	bench.submit(DrawingSamples.bell().to_code())
	for i in BellPit.TURNS_NEEDED:
		pit.interact(me)
	pit.receive_metal(pit.need + 0.01, 0.95, {&"copper": pit.need}, 0.5, 1.0 / 60.0)
	_check(pit.quench() and pit.cracked, "water on a hot bell cracks it")
	for i in BellPit.DIG_HITS_BARE_HANDS:
		pit.hit(false)
	await _frames(5)
	var cracked: Array = get_tree().get_nodes_in_group(&"bells").filter(func(n): return (n as Bell).cracked)
	_check(cracked.size() == 1 and (cracked[0] as Bell).verdict() == "gesprungen", "the cracked bell is 'gesprungen'")


## The Glockengießerei level: stations, unlock, bell orders and upgrades.
func _hall_round() -> void:
	for w in get_children():
		if w is GameWorld:
			w.queue_free()
	await _frames(3)
	var world: GameWorld = load("res://scenes/bell_foundry.tscn").instantiate()
	add_child(world)
	await _frames(10)
	var pits := get_tree().get_nodes_in_group(&"bell_pits")
	var benches := world.get_children().filter(func(n): return n is ModelBench and n.bell_mode)
	_check(pits.size() == 2 and benches.size() == 2, "hall has two pits and two profile benches")
	_check(get_tree().get_nodes_in_group(&"crucibles").size() == 2, "two crucibles for one long pour")
	_check(world.upgrade_tier() == 2 and Upgrades.catalog_for(1).any(func(u): return u.id == &"bell_foundry"), "the garage sells the bell foundry")
	_check(FoundryLevel.UNLOCKS.get(&"bell_foundry", "") == world.level_path(), "the unlock leads here")
	var board: OrderBoard = get_tree().get_first_node_in_group(&"order_boards")
	_check(board != null and board.slots[0] == &"church_bell", "first order: a church bell in G")
	# Order matching with real bells (big pit = deep bell).
	var big := pits.filter(func(p): return (p as BellPit).mouth_radius > 0.4)[0] as BellPit
	var deep: Bell = world.spawn_entity({type = "bell", code = DrawingSamples.bell().to_code(), alloy = "bronze", radius = big.mouth_radius,
		quality = 0.8, pos = Vector3(0, 0.6, 3.0)})
	var cracked: Bell = world.spawn_entity({type = "bell", code = DrawingSamples.bell().to_code(), alloy = "brass", radius = 0.35,
		quality = 0.8, cracked = true, pos = Vector3(1.5, 0.6, 3.0)})
	await _frames(3)
	_check(OrderBoard.matches(OrderBoard.template(&"deep_bell"), deep), "the big pit's bell is deep enough (%s, %.0f Hz)" % [deep.note(), deep.frequency()])
	_check(OrderBoard.matches(OrderBoard.template(&"museum_bell"), cracked) and not OrderBoard.matches(OrderBoard.template(&"ship_bell"), cracked),
		"a cracked bell suits the museum, not a ship")
	_check(not OrderBoard.matches(OrderBoard.template(&"church_bell"), deep) or deep.note().begins_with("G"), "church order wants the note G")
	# Upgrades: crank doubles turns, tuner makes a crooked bell sound better.
	var crooked: Bell = world.spawn_entity({type = "bell", code = DrawingSamples.crooked_bell().to_code(), alloy = "bronze", radius = 0.35,
		quality = 0.8, pos = Vector3(-1.5, 0.6, 3.0)})
	await _frames(2)
	var before := crooked.purity()
	world.upgrades.load_save(["strickle_crank", "bell_tuner"])
	_check(crooked.purity() > before, "Stimmbank: purer bell (%.2f -> %.2f)" % [before, crooked.purity()])
	var pit := pits[0] as BellPit
	pit.add_profile(DrawingSamples.bell().to_code())
	pit.interact(world.local_player())
	_check(pit.turns == 2, "Kurbel: one press turns twice")
	await _hoist_round(world, deep)


## One worker moves the heavy bell with the chain hoist and sells it.
func _hoist_round(world: GameWorld, bell: Bell) -> void:
	var hoist: ChainHoist = get_tree().get_first_node_in_group(&"hoists")
	var pendant: Item = get_tree().get_first_node_in_group(&"hoist_pendants")
	_check(hoist != null and pendant != null, "hall has a chain hoist with its pendant")
	if hoist == null or pendant == null:
		return
	var me := world.local_player()
	_check(bell.mass * 9.8 > Player.STRENGTH, "the big bell (%.0f kg) is too heavy for one worker" % bell.mass)
	# Stood next to the big pit, as if just dug out.
	bell.global_position = Vector3(1.2, 0.05, 1.4)
	bell.linear_velocity = Vector3.ZERO
	# Other loose bells from the earlier rounds would stand in the walkway.
	var parked := 0
	for other: Bell in get_tree().get_nodes_in_group(&"bells"):
		if other != bell and not other.freeze:
			other.global_position = Vector3(-4.0 - parked * 1.2, 0.05, 5.0)
			other.linear_velocity = Vector3.ZERO
			parked += 1
	await _frames(30)
	_check(absf(bell.rotation.x) < 0.01 and absf(bell.rotation.z) < 0.01, "the bell stays upright")
	# Take the pendant and walk to the bell.
	await _frames(60)
	await _walk(me, Vector3(pendant.global_position.x, 0.05, pendant.global_position.z + 0.7))
	me.facing = PI
	pendant.global_position = me._hand_target()
	await _frames(2)
	me.grab(pendant)
	await _frames(5)
	_check(me.held == pendant, "worker carries the pendant")
	# Around the bell, not through its rim (a teleport-walk would shove it).
	await _walk(me, Vector3(me.global_position.x, 0.05, bell.global_position.z + ChainHoist.HOOK_AHEAD))
	await _walk(me, Vector3(bell.global_position.x, 0.05, bell.global_position.z + ChainHoist.HOOK_AHEAD))
	await _frames(120)
	var h := hoist.hook_position()
	_check(Vector2(h.x - bell.global_position.x, h.z - bell.global_position.z).length() < ChainHoist.GRAB_RADIUS,
		"the hook followed the pendant over the bell")
	pendant.use_start(me)
	await _frames(240)
	_check(hoist.load == bell and bell.global_position.y > 0.5, "hook lifted the bell (y %.2f)" % bell.global_position.y)
	var crate: SellCrate = world.find_children("*", "SellCrate", true, false)[0]
	var before := world.money
	await _walk(me, Vector3(crate.global_position.x, 0.05, crate.global_position.z + ChainHoist.HOOK_AHEAD))
	await _frames(240)
	pendant.use_start(me)
	await _frames(300)
	_check(not is_instance_valid(bell) or bell.is_queued_for_deletion(), "the bell went into the sell crate")
	_check(world.money > before, "sold by crane (+%d $)" % (world.money - before))


func _walk(me: Player, to: Vector3) -> void:
	var from := me.global_position
	var steps := maxi(1, ceili(from.distance_to(to) / 0.12))
	var had := me.held
	for i in steps:
		me._do_teleport(from.lerp(to, float(i + 1) / steps))
		await _frames(2)
		if had and me.held == null:
			push_warning("lost the held item while walking")
			had = null


func bell_profile_of(b: Bell) -> BellProfile:
	return b.profile


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _finish() -> void:
	print("BELL TESTS %s (%d failures)" % ["PASSED" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures else 0)


func _check(ok: bool, what: String) -> void:
	print("%s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
