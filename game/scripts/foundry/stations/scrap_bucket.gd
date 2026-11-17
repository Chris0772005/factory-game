class_name ScrapBucket
extends Item
## The scrap bucket of the big hall. Stand it by the heap and dig: every find
## drops straight into it. Loose finds can be thrown in too. Carry it across
## the street to the scrap dealer and press F (or put it down there) to sell
## the lot; once the furnace is bought, F at the furnace tips the metal in
## and keeps the junk for the dealer. Host simulates, peers mirror count and
## worth for the hint and the look.

const RADIUS := 0.24
const HEIGHT := 0.36
const CAPACITY := 12
const CAPACITY_BIG := 30
## A bucket this close to the digger takes the finds.
const CATCH_RANGE := 3.2
const USE_RANGE := 3.4

## Kinds inside, in the order they went in (host).
var contents: Array[StringName] = []
var count := 0
var worth := 0
## Pieces of hot goods under the scrap (FoundryRules.HOT), mirrored to peers.
var hot := 0
var _fill: MeshInstance3D
var _pop := 0.0
var _hot_mirror: Array[StringName] = []


static func create_bucket(data: Dictionary) -> ScrapBucket:
	var b := ScrapBucket.new()
	b.kind = &"scrap_bucket"
	b.mass = 4.0
	b.position = data.pos
	b.axis_lock_angular_x = true
	b.axis_lock_angular_z = true
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = RADIUS
	cyl.height = HEIGHT
	shape.shape = cyl
	shape.position.y = HEIGHT * 0.5
	b.add_child(shape)
	return b


## The nearest bucket with room within reach of `pos` that nobody carries.
static func near(tree: SceneTree, pos: Vector3) -> ScrapBucket:
	var best: ScrapBucket = null
	var best_d := CATCH_RANGE
	for node in tree.get_nodes_in_group(&"scrap_buckets"):
		var b := node as ScrapBucket
		if b.is_held() or b.is_full():
			continue
		var d := b.global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = b
	return best


func _ready() -> void:
	add_to_group(&"scrap_buckets")
	add_to_group(&"toss_targets")
	if not StationKit.visual():
		return
	var steel := MachineArt.galv_mat()
	var profile := PackedVector2Array([Vector2(0.0, 0.0), Vector2(RADIUS - 0.05, 0.0), Vector2(RADIUS - 0.04, 0.012),
		Vector2(RADIUS, HEIGHT - 0.02), Vector2(RADIUS + 0.014, HEIGHT), Vector2(RADIUS - 0.008, HEIGHT - 0.004),
		Vector2(RADIUS - 0.045, 0.024), Vector2(0.0, 0.024)])
	StationKit.add(self, StationKit.lathe(profile, 24, 40.0), steel)
	# Two rolled hoops and the bail handle.
	for y: float in [0.1, 0.25]:
		var r := lerpf(RADIUS - 0.04, RADIUS, y / HEIGHT) + 0.004
		StationKit.add(self, StationKit.tube(StationKit.arc_points(Vector3(0, y, 0), Vector3.RIGHT, Vector3.BACK, r, 0.0, TAU, 28), 0.006, 6, false), steel)
	StationKit.add(self, StationKit.tube(StationKit.arc_points(Vector3(0, HEIGHT - 0.02, 0), Vector3.RIGHT, Vector3.UP, RADIUS + 0.012, 0.0, PI, 16), 0.008, 6), steel)
	# The load: a rusty mound that rises with every find.
	_fill = MeshInstance3D.new()
	var dome := PackedVector2Array()
	for i in 7:
		var r := (RADIUS - 0.03) * (1.0 - i / 6.0)
		dome.append(Vector2(r, 0.07 * (1.0 - pow(r / (RADIUS - 0.03), 2.0))))
	_fill.mesh = StationKit.lathe(dome, 18, 70.0)
	_fill.material_override = StationKit.metal("bucket_load", {steel_color = Color("#6f6a66"), rust = 0.7, dents = 0.9, metallic_steel = 0.6, roughness_steel = 0.6})
	add_child(_fill)
	_update_look()


func capacity() -> int:
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	return CAPACITY_BIG if world and world.has_upgrade(&"bucket_big") else CAPACITY


func is_full() -> bool:
	return count >= capacity()


func grip_points() -> Array[Vector3]:
	var right := global_transform.basis.x
	var top := global_position + Vector3(0, HEIGHT - 0.03, 0)
	return [top - right * (RADIUS + 0.01), top + right * (RADIUS + 0.01)]


## Host: one find goes in. False when the bucket is full.
func add(kind_in: StringName) -> bool:
	if is_full():
		return false
	contents.append(kind_in)
	_changed()
	_fx_all()
	return true


func _changed() -> void:
	count = contents.size()
	worth = 0
	hot = 0
	for k in contents:
		worth += FoundryRules.raw_price(k)
		if FoundryRules.is_hot(k):
			hot += 1
	_update_look()
	if Network.is_online() and multiplayer.is_server():
		_sync.rpc(count, worth, hot, PackedStringArray(hot_kinds()))


@rpc("authority", "call_remote", "reliable")
func _sync(c: int, w: int, h: int, hot_list: PackedStringArray) -> void:
	count = c
	worth = w
	hot = h
	_hot_mirror.clear()
	for k in hot_list:
		_hot_mirror.append(StringName(k))
	_update_look()


## The hot goods in the load (host: from the contents, peers: mirrored).
func hot_kinds() -> Array:
	if not Network.is_sim_authority():
		return _hot_mirror.duplicate()
	var out := []
	for k in contents:
		if FoundryRules.is_hot(k):
			out.append(k)
	return out


## Host: takes the hot goods out of the load and returns them.
func take_hot() -> Array:
	var out := hot_kinds()
	var rest: Array[StringName] = []
	for k in contents:
		if not FoundryRules.is_hot(k):
			rest.append(k)
	contents = rest
	_changed()
	return out


## Host: the dealer took everything he buys; hot goods stay in the bucket.
func sell_scrap() -> int:
	var sold := count - hot
	var rest: Array[StringName] = []
	for k in contents:
		if FoundryRules.is_hot(k):
			rest.append(k)
	contents = rest
	_changed()
	return sold


func _update_look() -> void:
	if _fill == null:
		return
	var k := clampf(float(count) / capacity(), 0.0, 1.0)
	_fill.visible = count > 0
	_fill.position.y = lerpf(0.04, HEIGHT - 0.06, k)
	_fill.scale = Vector3.ONE * lerpf(0.82, 1.0, k)


func _fx_all() -> void:
	_fx()
	if Network.is_online() and multiplayer.is_server():
		_fx_remote.rpc()


@rpc("authority", "call_remote", "unreliable")
func _fx_remote() -> void:
	_fx()


func _fx() -> void:
	Sfx.play(&"scrap_clatter", global_position + Vector3(0, HEIGHT, 0), -6.0, 0.25)
	_pop = 1.0


func _process(delta: float) -> void:
	if _pop > 0.0 and _fill:
		_pop = maxf(0.0, _pop - delta * 5.0)
		_fill.scale.y = 1.0 + sin(_pop * PI) * 0.25


# --- Throwing loose finds in (Player.toss_target) -------------------------------

func toss_accepts(body: Node3D) -> bool:
	var item := body as Item
	return item != null and item != self and not is_held() and not is_full() and not FoundryRules.find_info(item.kind).is_empty()


func toss_point() -> Vector3:
	return global_position + Vector3(0, HEIGHT + 0.2, 0)


func toss_hint(_body: Node3D) -> String:
	return "In den Eimer"


func toss_place(body: Node3D) -> bool:
	var item := body as Item
	if item == null or not add(item.kind):
		return false
	item.queue_free()
	return true


# --- Selling and tipping into the furnace ---------------------------------------

func _shop_near(player: Node3D) -> ScrapShop:
	for node in get_tree().get_nodes_in_group(&"scrap_shops"):
		var shop := node as ScrapShop
		if shop.interact_point().distance_to(player.global_position + Vector3(0, 0.9, 0)) < USE_RANGE:
			return shop
	return null


func _counter_near(player: Node3D) -> TownCounter:
	for node in get_tree().get_nodes_in_group(TownCounter.GROUP):
		var counter := node as TownCounter
		if counter.in_reach(player):
			return counter
	return null


func _furnace_near(player: Node3D) -> Furnace:
	for node in get_tree().get_nodes_in_group(&"furnaces"):
		var f := node as Furnace
		if f and f.global_position.distance_to(player.global_position) < 2.6:
			return f
	return null


func _metal_count() -> int:
	var n := 0
	for k in contents:
		if FoundryRules.SCRAP.has(k):
			n += 1
	return n


func held_hint(player: Node) -> String:
	var load_text := "Eimer %d/%d · %d $" % [count, capacity(), worth]
	if count == 0:
		return "Eimer leer – neben den Schrottberg stellen (Linksklick) und wühlen"
	var counter := _counter_near(player as Node3D)
	if counter and hot > 0:
		return counter.bucket_hint(counter.worth_of(hot_kinds()))
	if hot > 0:
		load_text += " · %d× heiße Ware (im Eimer versteckt)" % hot
	if _shop_near(player as Node3D):
		if count == hot:
			return "Kowalski: „Heiße Ware fass ich nicht an.“ → Polizeiwache oder Pfandhaus"
		return "[F] Schrott verkaufen · %d $" % worth
	if _furnace_near(player as Node3D) and _metal_count() > 0:
		return "[F] Metall in den Ofen kippen (%d Teile)" % _metal_count()
	if is_full():
		return "%s · voll! Zum Schrott-Ankauf über die Straße" % load_text
	return "%s · zum Schrott-Ankauf über die Straße" % load_text


func use_start(player: Node) -> void:
	if not Network.is_sim_authority() or count == 0:
		return
	var counter := _counter_near(player as Node3D)
	if counter and hot > 0:
		counter.take_bucket(self)
		return
	var shop := _shop_near(player as Node3D)
	if shop:
		shop.buy_bucket(self)
		return
	var furnace := _furnace_near(player as Node3D)
	if furnace and _metal_count() > 0:
		var rest: Array[StringName] = []
		for k in contents:
			if FoundryRules.SCRAP.has(k):
				furnace.charge.append(k)
			else:
				rest.append(k)
		contents = rest
		FoundryFX.sparks(furnace, furnace.global_position + Vector3(0, Furnace.HEIGHT, 0), 12)
		Sfx.play(&"scrap_clatter", furnace.global_position + Vector3(0, Furnace.HEIGHT, 0))
		_changed()


## Host: the dealer took the lot.
func empty() -> void:
	contents.clear()
	_changed()
