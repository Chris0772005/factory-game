extends Node
## Eisenhalle, headless: cupola (charges, blower, tap), hall crane with the
## ladle (lower, fill at the tap, crank – faster with more hands), the mold
## line (pattern, molding, pouring, automats, shakeout, series order), melt
## on a worker (bronze buddy), and the Kaiserglocke finale.

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var world: GameWorld = load("res://scenes/iron_hall.tscn").instantiate()
	add_child(world)
	await _frames(10)
	var me := world.local_player()
	var cupola: CupolaFurnace = get_tree().get_first_node_in_group(&"cupolas")
	var crane := world.find_station(HallCrane) as HallCrane
	var line: MoldLine = get_tree().get_first_node_in_group(&"mold_lines")
	var pit: BellPit = get_tree().get_first_node_in_group(&"bell_pits")
	var board: OrderBoard = get_tree().get_first_node_in_group(&"order_boards")
	_check(cupola != null and crane != null and crane.ladle != null and line != null and pit != null, "hall has cupola, crane with ladle, mold line, Kaisergrube")
	if cupola == null or crane == null or line == null or pit == null:
		_finish()
		return
	_check(world.upgrade_tier() == 3 and Upgrades.catalog_for(2).any(func(u): return u.id == &"iron_hall"), "the bell foundry sells the Eisenhalle")
	_check(FoundryLevel.UNLOCKS.get(&"iron_hall", "") == world.level_path(), "the unlock leads here")
	_check(board.slots[0] == &"kaiser_bell" and board.slots.slice(1).all(func(s): return OrderBoard.template(s).get("kind") in [&"series", &"statue"]),
		"first order: the Kaiserglocke, then series orders (%s)" % [board.slots])
	_check(get_tree().get_first_node_in_group(&"hoist_pendants") != null, "crane pendant is there")
	for n in get_tree().get_nodes_in_group(&"interactable"):
		if n.has_method("hint"):
			n.hint(me)
	await _cupola_round(world, me, cupola)
	await _ladle_round(world, me, cupola, crane)
	await _line_round(world, me, crane, line, board)
	await _buddy_round(world, me)
	await _kaiser_round(world, me, pit)
	_finish()


## Charges into the skip, the blower held by one worker, then by two.
func _cupola_round(world: GameWorld, me: Player, cupola: CupolaFurnace) -> void:
	var skip := cupola.to_global(CupolaFurnace.SKIP_POS + Vector3(0, 0.4, 0))
	for i in 4:
		world.spawn_entity({type = "charge", look = "iron", pos = skip + Vector3(0, i * 0.35, 0)})
	await _frames(40)
	_check(cupola.charge.size() == 4, "four iron baskets went into the skip (%d)" % cupola.charge.size())
	var other := Player.new()
	for i in 90:
		cupola.interact_tick(me, 1.0 / 60.0)
		await _frames(1)
	var solo := cupola.heat
	for i in 60:
		cupola.interact_tick(me, 1.0 / 60.0)
		cupola.interact_tick(other, 1.0 / 60.0)
		await _frames(1)
	other.free()
	_check(solo > 0.15 and cupola.heat > solo + 0.1, "the blower heats, two workers faster (%.2f -> %.2f)" % [solo, cupola.heat])
	cupola.heat = 1.0
	await _frames(400)
	_check(cupola.bath >= 23.0 and cupola.alloy() == &"iron", "the charges melt into an iron bath (%.1f l %s)" % [cupola.bath, cupola.alloy()])
	_check(cupola.tap_hint().contains("nichts drunter"), "tap warns when no ladle stands below")


## Ladle under the tap, tapped full, then cranked by one and by two.
func _ladle_round(world: GameWorld, me: Player, cupola: CupolaFurnace, crane: HallCrane) -> void:
	var ladle := crane.ladle
	var tap := cupola.to_global(CupolaFurnace.TROUGH_END)
	crane.trolley_x = tap.x
	crane.bridge_z = tap.z
	crane.press()
	await _frames(160)
	_check(ladle.lowered and crane.hook == ChainHoist.Hook.LOW, "the crane lowers the ladle")
	_check(cupola.tap_hint().contains("Pfanne drunter"), "tap sees the ladle below")
	cupola.heat = 1.0
	var before := cupola.bath
	cupola.toggle_tap()
	_check(cupola.tap_open, "Abstich!")
	await _frames(300)
	cupola.toggle_tap()
	_check(not cupola.tap_open and ladle.amount > 12.0 and absf(ladle.amount + cupola.bath - before) < 0.2 and ladle.alloy() == &"iron",
		"the tap fills the ladle, nothing spilt (%.1f l of %.1f)" % [ladle.amount, before])
	crane.press()
	await _frames(10)
	_check(crane.hook == ChainHoist.Hook.LIFTING or crane.hook == ChainHoist.Hook.UP, "an upright ladle hoists")
	await _frames(150)
	crane.press()
	await _frames(160)
	# One worker cranks: slow; two: faster.
	var other := Player.new()
	for i in 60:
		ladle.interact_tick(me, 1.0 / 60.0)
		await _frames(1)
	var solo := ladle.tilt
	_check(not ladle.upright(), "cranking tips the ladle")
	crane.press()
	await _frames(2)
	_check(crane.hook == ChainHoist.Hook.LOW, "a tipped ladle does not hoist")
	await _frames(120)
	_check(ladle.tilt < 0.05, "let go: the worm gear rights it")
	for i in 60:
		ladle.interact_tick(me, 1.0 / 60.0)
		ladle.interact_tick(other, 1.0 / 60.0)
		await _frames(1)
	other.free()
	_check(ladle.tilt > solo * 1.4, "two on the wheel tip it faster (%.2f vs %.2f)" % [ladle.tilt, solo])
	await _frames(120)


## Pattern, manual molding, pouring from the ladle, then both automats
## running a series from the pouring box into the line's crate.
func _line_round(world: GameWorld, me: Player, crane: HallCrane, line: MoldLine, board: OrderBoard) -> void:
	var bench: ModelBench = world.get_children().filter(func(n): return n is ModelBench and n.line_mode)[0]
	_check(bench.submit(DrawingSamples.star().to_code()), "pattern bench sets the series pattern")
	for k in 2:
		for i in MoldLine.PRESSES:
			line.interact(me)
		await _frames(100)
	var f := line.flask_at(MoldLine.POUR_SLOT)
	_check(line.states[f] == MoldLine.Flask.MOLDED and not line.moving, "two pressed flasks: the first waits at the pouring place")
	_check(MoldLine.describe_at(get_tree(), line.to_global(line.slot_position(MoldLine.POUR_SLOT) + Vector3(0, 0.8, 0))).contains("Kasten"), "ladle hint knows the flask")
	await _aim_ladle(crane, line.to_global(line.slot_position(MoldLine.POUR_SLOT) + Vector3(0, MoldLine.FLASK.y, 0)))
	var ladle := crane.ladle
	var t := 0
	while line.states[f] == MoldLine.Flask.MOLDED and t < 600:
		ladle.interact_tick(me, 1.0 / 60.0)
		await _frames(1)
		t += 1
	_check(line.states[f] == MoldLine.Flask.FILLED, "the ladle fills the flask (%d frames)" % t)
	await _frames(120)
	# Automats: the line molds itself, the pouring box gets the rest of the ladle.
	world.add_money(20000)
	_check(world.upgrades.buy(&"auto_molder") and world.upgrades.buy(&"auto_pourer"), "Formautomat and Gießautomat bought")
	await _frames(5)
	await _aim_ladle(crane, line.to_global(MoldLine.TUNDISH_POS + Vector3(0, MoldLine.TUNDISH_TOP, 0)))
	t = 0
	while line.tundish < 6.0 and ladle.amount > 0.5 and t < 900:
		ladle.interact_tick(me, 1.0 / 60.0)
		await _frames(1)
		t += 1
	_check(line.tundish > 3.0, "the ladle fills the pouring box (%.1f l)" % line.tundish)
	var money := world.money
	var series_slot := board.slots.find(board.slots.filter(func(s): return OrderBoard.template(s).get("kind") == &"series")[0])
	var series_id: StringName = board.slots[series_slot]
	await _frames(60 * 24)
	_check(world.money > money + 20, "series castings sell themselves (+%d $)" % (world.money - money))
	_check(board._progress[series_slot] > 0 or board.slots[series_slot] != series_id,
		"series order counts the pieces (%d)" % board._progress[series_slot])
	for n in get_tree().get_nodes_in_group(&"castings"):
		_check((n as CastPiece).series, "line castings are series pieces")
		break


## Melt landing on a worker makes a bronze buddy.
func _buddy_round(world: GameWorld, me: Player) -> void:
	await _walk(me, Vector3(0.0, 0.05, 4.0))
	var statues := world.entities.get_children().filter(func(n): return n is BronzeStatue).size()
	MeltTargets.deliver(get_tree(), me.global_position + Vector3(0, 1.7, 0), 0.5, 0.9, {&"iron": 0.5}, 2.0, 1.0 / 60.0)
	await _frames(5)
	_check(world.entities.get_children().filter(func(n): return n is BronzeStatue).size() == statues + 1, "melt on a worker: bronze buddy")


## The Kaiserglocke: profile, two ladle loads with a ladle change, dig out,
## deliver to the cathedral, finale.
func _kaiser_round(world: GameWorld, me: Player, pit: BellPit) -> void:
	_check(pit.add_profile(DrawingSamples.bell().to_code()), "Kaiserglocke profile in the pit")
	for i in BellPit.TURNS_NEEDED:
		pit.interact(me)
	_check(pit.need > 80.0 and pit.need < 130.0, "the Kaiserglocke takes two ladles (%.0f l)" % pit.need)
	var half := pit.need * 0.5
	pit.receive_metal(half, 0.95, {&"copper": half}, 2.0, 1.0 / 60.0)
	await _frames(240)
	pit.receive_metal(pit.need - half + 0.01, 0.95, {&"copper": half}, 2.0, 1.0 / 60.0)
	_check(pit.state == BellPit.State.COOLING and pit.defects.get("cold_shut", 0.0) == 0.0, "a ladle change is no cold shut here")
	pit._cool_left = 0.01
	await _frames(3)
	for i in BellPit.DIG_HITS:
		pit.hit(true)
	await _frames(10)
	var bell: Bell = null
	for b in get_tree().get_nodes_in_group(&"bells"):
		bell = b
	_check(bell != null and bell.is_great() and bell.alloy == &"bronze", "the Kaiserglocke rises (%s)" % (bell.note() if bell else "?"))
	if bell == null:
		return
	_check(OrderBoard.matches(OrderBoard.template(&"kaiser_bell"), bell), "it is the bell the cathedral ordered")
	bell.interact(me)
	_check(not bell.freeze, "too hot to deliver at once")
	bell.temperature = 0.0
	var money := world.money
	bell.interact(me)
	_check(world.money >= money + 8000, "delivered: order and bell paid (+%d $)" % (world.money - money))
	await _frames(60 * 6)
	_check(world.get_node_or_null(^"FinaleLayer") != null, "the finale opens")
	_check(not is_instance_valid(bell), "the low loader took the bell")


## Moves the crane so the ladle's lip (as tipped for a pour) is over `target`.
func _aim_ladle(crane: HallCrane, target: Vector3) -> void:
	var ladle := crane.ladle
	if crane.hook != ChainHoist.Hook.LOW:
		crane.press()
		await _frames(170)
	ladle.tilt = 0.6
	ladle._update_visuals(0.0)
	var off := ladle.lip_position() - ladle.global_position
	ladle.tilt = 0.0
	crane.trolley_x = target.x - off.x
	crane.bridge_z = target.z - off.z
	await _frames(3)


func _walk(me: Player, to: Vector3) -> void:
	var from := me.global_position
	var steps := maxi(1, ceili(from.distance_to(to) / 0.12))
	for i in steps:
		me._do_teleport(from.lerp(to, float(i + 1) / steps))
		await _frames(2)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  ok   ", label)
	else:
		_failures += 1
		print("  FAIL ", label)


func _finish() -> void:
	print("IRON HALL TESTS %s (%d failures)" % ["PASSED" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures > 0 else 0)
