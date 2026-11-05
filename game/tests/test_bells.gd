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
