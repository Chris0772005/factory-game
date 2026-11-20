class_name ScrapPile
extends Node3D
## Schrottberg: the heap every casting starts in. Hold F to dig through it
## (several workers dig faster together); every finished dig throws a find
## out at your feet – mostly cans, now and then copper, rarely gold. It starts
## with bare hands and gets better with tools: gloves and shovel dig faster,
## the magnet pulls two pieces per dig, the detector makes rare finds more
## likely. The heap runs low when dug through and is restocked over time.
## Host simulates; peers get progress and stock for the hint and the look.

const WEIGHTS := {&"scrap_can": 62, &"scrap_key": 14, &"scrap_pipe": 13, &"scrap_kettle": 7, &"scrap_tooth": 2, &"scrap_ring": 2,
	&"scrap_trophy": 2, &"scrap_candle": 3, &"scrap_coin": 1, &"scrap_bikebell": 3}
const PREMIUM_WEIGHTS := {&"scrap_can": 30, &"scrap_key": 26, &"scrap_pipe": 28, &"scrap_kettle": 10, &"scrap_tooth": 3, &"scrap_ring": 3,
	&"scrap_trophy": 3, &"scrap_candle": 4, &"scrap_coin": 2, &"scrap_bikebell": 4}
const RARE := [&"scrap_kettle", &"scrap_bikebell", &"scrap_candle", &"scrap_trophy", &"scrap_tooth", &"scrap_ring", &"scrap_coin"]
## Seconds of digging per find with bare hands.
const DIG_TIME := 2.2
## One short press digs this much (holding is smoother).
const PRESS_STEP := 0.3
const STOCK_MAX := 30
const RESTOCK_EVERY := 7.0
const DETECTOR_BOOST := 2.5

var progress := 0.0
var stock := STOCK_MAX
## Grabs in a full heap, and seconds per grab that grows back (INF: never).
var stock_max := STOCK_MAX
var restock_every := RESTOCK_EVERY
## Share of grabs that bring plain junk (FoundryRules.JUNK) instead of metal.
var junk_share := 0.0
## Chance per grab by hand that the find is hot goods (FoundryRules.HOT).
var hot_share := 0.0
var _restock := 0.0
var _sync_accum := 0.0
var _dirty := false
var _art: Node3D
var _dig_fx := 0.0


var _next := &""
var _beep := 0.0


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_to_group(&"interactable")
	add_to_group(&"scrap_piles")
	_build_heap()


## Collider and look of the heap (the big hall heap overrides this).
func _build_heap() -> void:
	# Low solid core so workers stand at the heap instead of inside it.
	var core := StaticBody3D.new()
	core.position.y = 0.14
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.55
	cyl.height = 0.28
	shape.shape = cyl
	core.add_child(shape)
	add_child(core)
	var art := ScrapArt.new()
	add_child(art)
	art.build()
	_art = art


## Where a find comes out of the heap for `p`.
func _find_origin(_p: Player) -> Vector3:
	return global_position + Vector3(0, 0.75, 0)


## The heap centre a find flies away from.
func _heap_centre() -> Vector3:
	return global_position


func interact_point() -> Vector3:
	return global_position + Vector3(0, 0.4, 0)


## Digging speed factor from the tools owned.
func dig_speed() -> float:
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	if world == null:
		return 1.0
	# Tools, and what the crew has had at the diner.
	return (1.3 if world.has_upgrade(&"gloves") else 1.0) * (2.0 if world.has_upgrade(&"shovel") else 1.0) * CrewBoost.dig(get_tree())


func hint(_player: Node) -> String:
	if stock <= 0:
		return "Schrottberg durchwühlt – Nachschub kommt gleich"
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	var tool := "mit der Schaufel" if world and world.has_upgrade(&"shovel") else ("mit Handschuhen" if world and world.has_upgrade(&"gloves") else "mit bloßen Händen")
	if progress > 0.02:
		return "[F halten] Wühlen %s … %d %%" % [tool, roundi(progress * 100.0)]
	return "[F halten] Im Schrott wühlen (%s) · noch %d Griffe" % [tool, stock]


func interact(player: Node) -> void:
	_dig(player, PRESS_STEP)


func interact_tick(player: Node, delta: float) -> void:
	_dig(player, delta)


func _dig(player: Node, seconds: float) -> void:
	if not Network.is_sim_authority() or stock <= 0:
		return
	progress += seconds * dig_speed() / DIG_TIME
	_dirty = true
	_dig_fx -= seconds
	if _dig_fx <= 0.0:
		_dig_fx = 0.35
		_fx_all(&"rummage")
	# The detector knows what the next grab brings: it beeps faster and
	# faster while a rare find is coming up.
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	if world and world.has_upgrade(&"detector"):
		if _next == &"":
			_next = _roll()
		if RARE.has(_next):
			_beep -= seconds
			if _beep <= 0.0:
				_beep = lerpf(0.55, 0.11, clampf(progress, 0.0, 1.0))
				_fx_all(&"beep")
	if progress >= 1.0:
		progress = 0.0
		_find(player as Player)


## One dig is through: the find flies out towards the digger.
func _find(p: Player) -> void:
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	if world == null:
		return
	stock -= 1
	var guide := get_tree().get_first_node_in_group(&"guides") as Guide
	if guide:
		guide.note(&"dig")
	Missions.report(get_tree(), &"dig", 1)
	var count := 2 if world.has_upgrade(&"magnet") else 1
	var top := _find_origin(p)
	var out := (p.global_position - _heap_centre()) if p else Vector3.BACK
	out.y = 0.0
	out = out.normalized() if out.length() > 0.1 else Vector3.BACK
	for i in count:
		var kind := _next if i == 0 and _next != &"" else _roll()
		_next = &""
		if FoundryRules.is_hot(kind):
			TownLaw.hot_found(world, kind, top)
		# A bucket standing by takes the find straight away.
		var bucket := ScrapBucket.near(get_tree(), p.global_position if p else top)
		if bucket and bucket.add(kind):
			if RARE.has(kind):
				world.popup_all(top + Vector3(0, 0.6, 0), "%s! ✨" % FoundryRules.find_info(kind).name, Color("#ffcf3f"))
				_fx_all(&"rare")
				var found := get_tree().get_first_node_in_group(&"find_books") as FindBook
				if found:
					found.note(kind, top)
			continue
		var info: Dictionary = FoundryRules.find_info(kind)
		var item := world.spawn_item(kind, info.color, info.size, 0.4, top + Vector3(randf_range(-0.15, 0.15), i * 0.2, randf_range(-0.15, 0.15)))
		if item:
			item.apply_central_impulse((out * randf_range(1.2, 1.8) + Vector3(randf_range(-0.4, 0.4), 2.6, randf_range(-0.4, 0.4))) * item.mass)
			item.apply_torque_impulse(Vector3(randf(), randf(), randf()) * 0.05)
		if RARE.has(kind):
			world.popup_all(top + Vector3(0, 0.6, 0), "%s! ✨" % info.name, Color("#ffcf3f"))
			_fx_all(&"rare")
			var book := get_tree().get_first_node_in_group(&"find_books") as FindBook
			if book:
				book.note(kind, top)
	_fx_all(&"find")


## Host: a machine takes one find out of the heap (&"" when it is empty).
func take_one() -> StringName:
	if stock <= 0:
		return &""
	stock -= 1
	_dirty = true
	_fx_all(&"rummage")
	return _roll(false)


## Host: a machine takes up to `n` pieces in bulk – scrap and junk as they
## come, but never the hot goods only hands find.
func take_bulk(n: int) -> Array:
	var out := []
	while n > 0 and stock > 0:
		stock -= 1
		n -= 1
		if junk_share > 0.0 and randf() < junk_share:
			out.append(FoundryRules.JUNK.keys()[randi() % FoundryRules.JUNK.size()])
		else:
			out.append(_roll(false))
	if not out.is_empty():
		_dirty = true
		_fx_all(&"rummage")
	return out


func _roll(junk_ok := true) -> StringName:
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	var detector := world and world.has_upgrade(&"detector")
	# Only hands find what somebody hid in the heap; machines pass it over.
	if junk_ok and hot_share > 0.0 and randf() < hot_share:
		return FoundryRules.roll_hot()
	# The detector also sorts out half the junk.
	if junk_ok and junk_share > 0.0 and randf() < junk_share * (0.5 if detector else 1.0):
		return FoundryRules.JUNK.keys()[randi() % FoundryRules.JUNK.size()]
	var weights: Dictionary = PREMIUM_WEIGHTS if world and world.has_upgrade(&"scrap_premium") else WEIGHTS
	var boost := DETECTOR_BOOST if world and world.has_upgrade(&"detector") else 1.0
	var total := 0.0
	for k in weights:
		total += weights[k] * (boost if RARE.has(k) else 1.0)
	var r := randf() * total
	for k in weights:
		r -= weights[k] * (boost if RARE.has(k) else 1.0)
		if r < 0.0:
			return k
	return &"scrap_can"


func _physics_process(delta: float) -> void:
	if _art:
		# The heap sinks as it is dug through.
		_shrink(delta)
	if not Network.is_sim_authority():
		return
	if stock < stock_max:
		_restock += delta
		if _restock >= restock_every:
			_restock = 0.0
			stock += 1
			_dirty = true
	if Network.is_online() and _dirty:
		_sync_accum += delta
		if _sync_accum > 0.2:
			_sync_accum = 0.0
			_dirty = false
			_sync.rpc(progress, stock)


## The heap sinks as it is dug through.
func _shrink(delta: float) -> void:
	_art.scale.y = lerpf(_art.scale.y, 0.45 + 0.55 * float(stock) / stock_max, 1.0 - exp(-4.0 * delta))


@rpc("authority", "call_remote", "unreliable_ordered")
func _sync(p: float, s: int) -> void:
	progress = p
	stock = s


func _fx_all(kind: StringName) -> void:
	_fx(kind)
	if Network.is_online() and multiplayer.is_server():
		_fx_remote.rpc(kind)


@rpc("authority", "call_remote", "unreliable")
func _fx_remote(kind: StringName) -> void:
	_fx(kind)


func _fx(kind: StringName) -> void:
	var top := global_position + Vector3(0, 0.5, 0)
	match kind:
		&"rummage":
			Sfx.play(&"dig_scrape", top, -9.0, 0.2)
			FoundryFX.dust(get_parent(), top)
		&"find":
			Sfx.play(&"scrap_clatter", top, -2.0)
			Sfx.play(&"metal_tick", top, -6.0, 0.15)
		&"beep":
			Sfx.play(&"detector_beep", top, -5.0, 0.0)
		&"rare":
			Sfx.play(&"coin", top, 0.0)
			FoundryFX.sparks(get_parent(), top + Vector3(0, 0.3, 0), 14)
