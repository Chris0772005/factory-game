class_name ScrapShop
extends SellCrate
## Schrott-Ankauf across the street: the dealer's counter. Castings thrown
## into the bin are sold as at any sales crate; raw finds and junk are bought
## too, for little money. A full scrap bucket is sold with F (ScrapBucket) or
## by putting it down at the counter.

func _ready() -> void:
	super()
	add_to_group(&"scrap_shops")


func hint(_player: Node) -> String:
	return "Schrott-Ankauf · Eimer herbringen und [F] drücken"


func toss_accepts(body: Node3D) -> bool:
	if body is ScrapBucket:
		return (body as ScrapBucket).count > 0
	var item := body as Item
	return item != null and (item.has_method("value") or FoundryRules.raw_price(item.kind) > 0)


func toss_hint(body: Node3D) -> String:
	if body is ScrapBucket:
		return "Eimer verkaufen · %d $" % (body as ScrapBucket).worth
	return "Verkaufen"


## A bucket is not thrown into the bin: its load is bought on the spot.
func toss_place(body: Node3D) -> bool:
	var bucket := body as ScrapBucket
	if bucket == null:
		return false
	buy_bucket(bucket)
	return true


## Host: pays for everything in `bucket` and empties it.
func buy_bucket(bucket: ScrapBucket) -> void:
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	if world == null or bucket.count == 0:
		return
	var pay := bucket.worth
	var pieces := bucket.count
	bucket.empty()
	_pay(world, pay, "+%d $ · %d Teile" % [pay, pieces], interact_point())


func _pay(world: GameWorld, amount: int, text: String, at: Vector3) -> void:
	world.add_money(amount)
	world.popup_all(at + Vector3(0, 0.6, 0), text, UITheme.ACCENT)
	if Network.is_online():
		_cha_ching.rpc()
	else:
		_cha_ching()
	sold.emit(amount)
	var guide := get_tree().get_first_node_in_group(&"guides") as Guide
	if guide:
		guide.note(&"scrap_sold")


func _physics_process(delta: float) -> void:
	super(delta)
	if not Network.is_sim_authority():
		return
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	if world == null:
		return
	# Loose raw finds that land in the bin.
	for node in world.entities.get_children():
		var piece := node as Item
		if piece == null or piece.is_held() or piece.is_queued_for_deletion() or piece.has_method("value"):
			continue
		var price := FoundryRules.raw_price(piece.kind)
		if price <= 0:
			continue
		var local := to_local(piece.global_position)
		if absf(local.x) < SIZE.x * 0.5 and absf(local.z) < SIZE.z * 0.5 and local.y < SIZE.y + 0.12 and local.y > -0.1:
			_pay(world, price, "+%d $" % price, piece.global_position)
			piece.queue_free()
