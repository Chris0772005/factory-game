extends Node
## Schrotthalle, headless: the game starts at the scrap mountain. Digging
## fills the bucket and shrinks the heap, the dealer across the street buys
## the bucket, the money buys the foundry corner, which then stands in the
## hall with furnace, crucible and molds; the bucket tips its metal into
## the furnace and keeps the junk.

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var world: GameWorld = load("res://scenes/scrap_hall.tscn").instantiate()
	add_child(world)
	await _frames(10)
	# Mission rewards have their own test (test_missions); here they would blur the sums.
	Missions.of(get_tree()).free()
	var me := world.local_player()
	var heap := get_tree().get_first_node_in_group(&"scrap_piles") as ScrapMountain
	var bucket := get_tree().get_first_node_in_group(&"scrap_buckets") as ScrapBucket
	var shop := get_tree().get_first_node_in_group(&"scrap_shops") as ScrapShop
	_check(heap != null and bucket != null and shop != null and me != null, "the hall has the mountain, a bucket and the dealer")
	if heap == null or bucket == null or shop == null:
		_finish()
		return
	# Hot goods have their own test (test_town).
	heap.hot_share = 0.0
	_check(get_tree().get_nodes_in_group(&"furnaces").is_empty(), "no furnace before the foundry corner is bought")
	_check(world.guide.letter().id == &"dig", "first letter: dig")
	# Dig with the bucket standing by: finds go straight in, the heap shrinks.
	var spot := heap.interact_point_for(me)
	me._do_teleport(Vector3(spot.x, 0.05, spot.z) + (me.global_position - heap._heap_centre()).normalized() * Vector3(1, 0, 1) * 0.8)
	bucket.global_position = me.global_position + Vector3(0.8, 0.1, 0)
	await _frames(5)
	_check(me.nearest_interactable() == heap, "standing at the heap's edge, the heap is the target")
	var size_before := heap.size_now()
	for i in 8:
		heap._dig(me, ScrapPile.DIG_TIME + 0.01)
	await _frames(5)
	_check(bucket.count == 8 and heap.stock == ScrapMountain.GRABS - 8, "eight grabs land in the bucket (%d, heap %d)" % [bucket.count, heap.stock])
	_check(heap.size_now() < size_before, "the mountain gets smaller (%.3f -> %.3f)" % [size_before, heap.size_now()])
	_check(bucket.worth > 0, "the load is worth something (%d $)" % bucket.worth)
	# Sell at the dealer.
	var money := world.money
	var worth := bucket.worth
	shop.buy_bucket(bucket)
	_check(world.money == money + worth and bucket.count == 0, "the dealer pays for the bucket and empties it")
	await _frames(70)
	_check(world.guide.index >= 2, "letters: digging and the first sale are done (letter %d)" % world.guide.index)
	# The foundry corner.
	_check(not world.upgrades.can_buy(&"conveyor"), "foundry upgrades are not sold before the corner")
	world.add_money(1000)
	_check(world.upgrades.buy(&"foundry_corner"), "the foundry corner can be bought")
	await _frames(20)
	var furnace := get_tree().get_first_node_in_group(&"furnaces") as Furnace
	_check(furnace != null and get_tree().get_nodes_in_group(&"molds").size() == 2, "furnace and two molds stand in the hall")
	_check(get_tree().get_first_node_in_group(&"crucibles") != null and furnace != null and furnace.crucible != null, "the crucible sits in the furnace")
	_check(world.upgrades.can_buy(&"conveyor"), "now the conveyor is on sale")
	# Tip metal from the bucket into the furnace.
	bucket.contents = [&"scrap_can", &"junk_gear", &"scrap_pipe"] as Array[StringName]
	bucket._changed()
	me._do_teleport(furnace.global_position + Vector3(0, 0.05, 1.6))
	await _frames(3)
	bucket.use_start(me)
	_check(furnace.charge.size() == 2 and bucket.count == 1, "F at the furnace tips the metal in and keeps the junk")
	# A cleared heap is refilled.
	heap.stock = 0
	await _frames(int(ScrapMountain.RELOAD_TIME * 60) + 30)
	_check(heap.stock == heap.stock_max and heap.loads == 1, "a new load arrives when the mountain is gone")
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
	print("SCRAP HALL TESTS %s (%d failures)" % ["PASSED" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures > 0 else 0)
