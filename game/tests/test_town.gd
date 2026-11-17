extends Node
## The quarter, headless: hot goods come out of the heap, the dealer will not
## touch them, the pawnbroker pays the black-market price and raises the
## heat, the police desk pays a finder's reward and cools it. The officer on
## the beat sees hot goods carried openly from afar and under the scrap in a
## bucket only from close up; caught means goods gone and a fine; dropping
## the goods saves the fine.

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var world: GameWorld = load("res://scenes/scrap_hall.tscn").instantiate()
	add_child(world)
	await _frames(10)
	var me := world.local_player()
	var law := TownLaw.of(get_tree())
	var heap := get_tree().get_first_node_in_group(&"scrap_piles") as ScrapMountain
	var bucket := get_tree().get_first_node_in_group(&"scrap_buckets") as ScrapBucket
	var shop := get_tree().get_first_node_in_group(&"scrap_shops") as ScrapShop
	var fence := get_tree().get_first_node_in_group(&"town_counters") as FenceCounter
	var desk: PoliceDesk = null
	for node in get_tree().get_nodes_in_group(&"town_counters"):
		if node is PoliceDesk:
			desk = node
		if node is FenceCounter:
			fence = node
	var cop := get_tree().get_first_node_in_group(&"police_patrols") as PolicePatrol
	_check(law != null and fence != null and desk != null and cop != null, "the quarter has the law, a pawnbroker, a police desk and a patrol")
	if law == null or fence == null or desk == null or cop == null or me == null:
		_finish()
		return
	# Keep the officer out of the way until he is wanted.
	cop.set_physics_process(false)
	# The heap gives up hot goods to hands, never to machines.
	heap.hot_share = 1.0
	_check(FoundryRules.is_hot(heap._roll()), "a grab by hand can be hot goods")
	_check(not FoundryRules.is_hot(heap._roll(false)), "machines pass hot goods over")
	heap.hot_share = 0.0
	# Bucket: the dealer buys the scrap and leaves the hot goods.
	bucket.contents = [&"junk_gear", &"hot_pistol", &"scrap_pipe", &"hot_plates"] as Array[StringName]
	bucket._changed()
	_check(bucket.hot == 2 and bucket.worth == 8, "the bucket counts hot goods apart (%d hot, %d $)" % [bucket.hot, bucket.worth])
	var money := world.money
	shop.buy_bucket(bucket)
	_check(world.money == money + 8 and bucket.count == 2 and bucket.hot == 2, "Kowalski buys the scrap and leaves the hot goods in the bucket")
	# Pawnbroker: black-market price, heat goes up.
	money = world.money
	me._do_teleport(fence.global_position + Vector3(0, 0.05, -1.4))
	await _frames(3)
	_check(fence.in_reach(me), "standing at the pawnbroker's counter")
	me.grab(bucket)
	await _frames(3)
	bucket.use_start(me)
	_check(world.money == money + 85 + 30 and bucket.hot == 0, "F with the bucket at the pawnbroker sells the hot goods (%d $)" % (world.money - money))
	_check(is_equal_approx(law.heat, 2 * TownLaw.SALE_HEAT) and law.stars() == 1, "two shady sales raise the heat (%.2f, %d star)" % [law.heat, law.stars()])
	me.release()
	# Police desk: finder's reward, heat goes down.
	var item := world.spawn_item(&"hot_jewels", Color.WHITE, Vector3(0.16, 0.08, 0.12), 0.4, desk.global_position + Vector3(0, 1.3, -1.0))
	money = world.money
	_check(desk.toss_accepts(item) and not shop.toss_accepts(item), "the police desk takes hot goods, the scrap dealer does not")
	_check(desk.toss_place(item), "handing in at the desk")
	await _frames(2)
	_check(world.money == money + 22 and not is_instance_valid(item), "the desk pays the finder's reward")
	_check(law.heat < 2 * TownLaw.SALE_HEAT, "handing in cools the heat (%.2f)" % law.heat)
	# The officer: open carry is seen from afar, the bucket only from close up.
	law.heat = 0.0
	var beat := Vector3(0.0, 0.05, ScrapHallSet.BEAT_Z)
	cop.global_position = beat
	cop.rotation.y = PI * 0.5
	var pistol := world.spawn_item(&"hot_pistol", Color.WHITE, Vector3(0.2, 0.13, 0.04), 0.4, beat + Vector3(8.0, 1.0, 0))
	me._do_teleport(beat + Vector3(8.0, 0, 0))
	await _frames(3)
	me.grab(pistol)
	await _frames(3)
	_check(TownLaw.carried_hot(me).get("open", false), "a pistol in the hands is carried openly")
	_check(cop.sees(me, PolicePatrol.SIGHT_OPEN, PolicePatrol.FOV_OPEN), "the officer sees the player eight metres ahead")
	cop.rotation.y = -PI * 0.5
	_check(not cop.sees(me, PolicePatrol.SIGHT_OPEN, PolicePatrol.FOV_OPEN), "not with his back turned")
	cop.rotation.y = PI * 0.5
	me.release()
	pistol.queue_free()
	bucket.contents = [&"junk_gear", &"hot_pistol"] as Array[StringName]
	bucket._changed()
	bucket.global_position = me.global_position + Vector3(0, 0.3, 0.6)
	await _frames(2)
	me.grab(bucket)
	await _frames(3)
	var load := TownLaw.carried_hot(me)
	_check(not load.is_empty() and not load.open, "hot goods in the bucket are hidden")
	_check(not cop.sees(me, PolicePatrol.SIGHT_BUCKET, PolicePatrol.FOV_BUCKET), "eight metres away the officer does not see into the bucket")
	# Let him walk: nothing happens at a distance.
	cop.route = [beat, beat + Vector3(0.5, 0, 0)] as Array[Vector3]
	cop.set_physics_process(true)
	await _frames(90)
	_check(cop.alert < 0.05 and cop.state != PolicePatrol.State.CHASE, "the bucket passes at a distance")
	# Close up he looks into the bucket, gets suspicious, gives chase and arrests.
	cop.set_physics_process(false)
	cop.global_position = beat
	cop.rotation.y = PI * 0.5
	me._do_teleport(beat + Vector3(2.2, 0, 0))
	bucket.global_position = me.global_position + Vector3(0.5, 0.3, 0)
	await _frames(3)
	world.add_money(100)
	money = world.money
	cop.set_physics_process(true)
	var caught := false
	for i in 400:
		await get_tree().physics_frame
		if bucket.hot == 0:
			caught = true
			break
	_check(caught, "close up the officer finds the hot goods in the bucket")
	_check(world.money == money - 43 and bucket.count == 1, "caught: the pistol is gone, the fine is half its black-market value (%d $)" % (money - world.money))
	_check(law.heat >= TownLaw.CAUGHT_HEAT - 0.01, "an arrest raises the heat")
	_check(cop.state == PolicePatrol.State.RETURN or cop.state == PolicePatrol.State.PATROL or cop.state == PolicePatrol.State.LOOK, "then he goes back to his beat")
	# Dropping the goods during the chase: goods gone, no fine.
	cop.set_physics_process(false)
	cop._blind = 0.0
	cop.global_position = beat
	cop.rotation.y = PI * 0.5
	me.release()
	me._do_teleport(beat + Vector3(9.0, 0, 0))
	var plates := world.spawn_item(&"hot_plates", Color.WHITE, Vector3(0.34, 0.03, 0.12), 0.4, beat + Vector3(9.0, 1.0, 0))
	await _frames(3)
	me.grab(plates)
	await _frames(3)
	money = world.money
	cop.set_physics_process(true)
	var chased := false
	for i in 300:
		await get_tree().physics_frame
		if cop.state == PolicePatrol.State.CHASE:
			chased = true
			break
	_check(chased, "carried openly in his view: the officer gives chase")
	me.release()
	for i in 400:
		await get_tree().physics_frame
		if cop.state != PolicePatrol.State.CHASE:
			break
	await _frames(3)
	_check(cop.state != PolicePatrol.State.CHASE and not is_instance_valid(plates), "he collects the dropped goods and breaks off")
	_check(world.money == money, "no fine without the goods on you")
	# Weapons: a casting in the shape of a weapon is contraband. The pawnbroker
	# pays three times its value plus the bonus of his order.
	var dark := get_tree().root.find_child("DarkBoard", true, false) as OrderBoard
	_check(dark != null and dark.dark and dark.slots[0] == &"dark_knuckles", "the pawnbroker's board asks for weapons")
	var at := fence.global_position + Vector3(0, 1.3, -1.2)
	var honest: CastPiece = world.spawn_entity({type = "cast", code = DrawingTemplates.drawing(&"house").to_code(), alloy = &"alu", quality = 0.6, pos = at})
	var weapon: CastPiece = world.spawn_entity({type = "cast", code = DrawingTemplates.drawing(&"knuckles").to_code(), alloy = &"alu", quality = 0.6, pos = at + Vector3(0.8, 0, 0)})
	var dagger: CastPiece = world.spawn_entity({type = "cast", code = DrawingTemplates.drawing(&"dagger").to_code(), alloy = &"alu", quality = 0.6, pos = at + Vector3(-0.8, 0, 0)})
	await _frames(2)
	_check(TownLaw.weapon_of(honest) == &"" and TownLaw.weapon_of(weapon) == &"knuckles" and TownLaw.weapon_of(dagger) == &"dagger", "a cast house is honest, knuckles and dagger are weapons")
	_check(fence.toss_accepts(weapon) and not fence.toss_accepts(honest) and not desk.toss_accepts(weapon), "only the pawnbroker takes weapons")
	_check(OrderBoard.fulfil(world, weapon) == 0, "the honest sell crate knows no dark orders")
	money = world.money
	var expect := weapon.value() * TownLaw.WEAPON_MULT + 160
	law.heat = 0.0
	_check(fence.toss_place(weapon), "the weapon changes hands at the counter")
	await _frames(2)
	_check(world.money == money + expect and dark.slots[0] == &"", "he pays triple plus the order's bonus (%d $)" % (world.money - money))
	_check(absf(law.heat - TownLaw.WEAPON_HEAT) < 0.01, "a weapon sold raises the heat")
	me._do_teleport(Vector3(dagger.global_position.x, 0.05, dagger.global_position.z - 0.5))
	await _frames(3)
	me.grab(dagger)
	await _frames(3)
	var armed := TownLaw.carried_hot(me)
	_check(not armed.is_empty() and armed.open and armed.value == dagger.value() * TownLaw.WEAPON_MULT, "a weapon in the hands is carried openly")
	me.release()
	var wanted := OrderBoard.wanted_motif(get_tree())
	_check(wanted.is_empty() or not wanted.get("dark", false), "the drawing bench never suggests a weapon by itself")
	# Heat cools off by itself.
	law.heat = 0.5
	await _frames(120)
	_check(law.heat < 0.5, "heat cools off over time")
	_finish()


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
	print("TOWN TESTS %s (%d failures)" % ["PASSED" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures > 0 else 0)
