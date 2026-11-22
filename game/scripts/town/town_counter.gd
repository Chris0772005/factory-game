class_name TownCounter
extends Node3D
## A counter in one of the town's houses that takes hot goods: carried in the
## hands (dropped or thrown at the counter) or hidden in the scrap bucket
## ([F] with the bucket). FenceCounter pays the black-market price and makes
## the police take notice; PoliceDesk pays the finder's reward and calms them.

const GROUP := &"town_counters"
## As far as a player is offered the counter (Player.nearest_interactable), so [F] never falls flat.
const USE_RANGE := 3.5
const TOP := 1.05

signal taken(pieces: int, pay: int)


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(&"interactable")
	add_to_group(&"toss_targets")


## What this counter pays for one piece of `kind` (subclasses).
func price(_kind: StringName) -> int:
	return 0


## Heat per piece taken (subclasses).
func heat_per_piece() -> float:
	return 0.0


## What a hand-over counts as for the missions (subclasses).
func mission_stat() -> StringName:
	return &""


## Popup text for a payment (subclasses).
func pay_text(pay: int, _pieces: int) -> String:
	return "+%d $" % pay


func bucket_hint(pay: int) -> String:
	return "[F] Heiße Ware loswerden · %d $" % pay


func interact_point() -> Vector3:
	return global_position + Vector3(0, TOP, 0)


func interact(_player: Node) -> void:
	pass


func hint(_player: Node) -> String:
	return ""


func in_reach(player: Node3D) -> bool:
	return interact_point().distance_to(player.global_position + Vector3(0, 0.9, 0)) < USE_RANGE


## A Suchauftrag hides its find only on the customers' side of the counter.
func hunt_spot_ok(at: Vector3) -> bool:
	return to_local(at).z < -0.3


func worth_of(kinds: Array) -> int:
	var pay := 0
	for k: StringName in kinds:
		pay += price(k)
	return pay


# --- Player.toss_target ---------------------------------------------------------

func toss_accepts(body: Node3D) -> bool:
	if body is ScrapBucket:
		return (body as ScrapBucket).hot > 0
	var item := body as Item
	return item != null and FoundryRules.is_hot(item.kind)


func toss_point() -> Vector3:
	return global_position + Vector3(0, TOP + 0.3, 0)


func toss_hint(body: Node3D) -> String:
	if body is ScrapBucket:
		return bucket_hint(worth_of((body as ScrapBucket).hot_kinds()))
	return "%s · %d $" % [_verb(), price((body as Item).kind)]


func _verb() -> String:
	return "Abgeben"


## The goods never fly through the room: they change hands at the counter.
func toss_place(body: Node3D) -> bool:
	if not Network.is_sim_authority():
		return false
	if body is ScrapBucket:
		take_bucket(body as ScrapBucket)
		return true
	var item := body as Item
	if item == null or not FoundryRules.is_hot(item.kind):
		return false
	_take([item.kind])
	item.queue_free()
	return true


## Host: takes every piece of hot goods out of `bucket` and pays for it.
func take_bucket(bucket: ScrapBucket) -> void:
	if bucket.hot > 0:
		_take(bucket.take_hot())


func _take(kinds: Array) -> void:
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	if world == null or kinds.is_empty():
		return
	_pay_out(world, worth_of(kinds), kinds.size(), heat_per_piece() * kinds.size())
	Missions.report(get_tree(), mission_stat(), kinds.size())


func _pay_out(world: GameWorld, pay: int, pieces: int, heat: float) -> void:
	world.add_money(pay)
	world.popup_all(interact_point() + Vector3(0, 0.5, 0), pay_text(pay, pieces), UITheme.ACCENT)
	var law := TownLaw.of(get_tree())
	if law:
		law.add_heat(heat)
	if Network.is_online():
		_cha_ching.rpc()
	else:
		_cha_ching()
	taken.emit(pieces, pay)


@rpc("authority", "call_local", "reliable")
func _cha_ching() -> void:
	Sfx.play(&"coin", interact_point(), 0.0, 0.03)
