class_name StorageLockup
extends Node3D
## One lock-up of the storage auctions in the arches of the viaduct (TownStreets.lockups). Behind
## its shutter waits a lot: what somebody left behind, sold unseen. The sign says what kind of lot
## it is, how many pieces, and the opening bid. [F] bids for the crew; another bidder may raise,
## and [F] raises again, until the hammer falls. Won: the money is paid, the shutter rolls up and
## the pieces lie inside as real things, to be carried out, swept into the bucket ([F] with the
## bucket in hand), laid on the stall, sold or melted. Lost: the lot is gone. Either way a new one
## comes after a while. The host runs the auction; the others see the sign, the shutter and the
## pieces, and their [F] reaches the host like everywhere else. Lots are not saved with the game.
## Comparison: Storage Hunter Simulator, Barn Finders.
## The node stands in the doorway (TownStreets.door_spot); +z leads into the room.

const GROUP := &"storage_lockups"
## As far as a player is offered the door (Player.nearest_interactable), so [F] never falls flat.
const USE_RANGE := 3.5
enum State { SHUT, BIDDING, WON, RESTING }
## Seconds from a bid to the hammer; until a new lot comes after one went to another bidder, and
## after the crew's own was cleared out; an open lock-up is cleared after CLEAR_AFTER at the latest.
const COUNT := 6.0
const REST_SOLD := 70.0
const REST_WON := 90.0
const CLEAR_AFTER := 420.0
## The kinds of lot: the board's line, how the auctioneer calls it, and what may be in it (kind ->
## share). `hot`: the chance that one piece is hot goods.
const THEMES := [
	{board = "HOUSEHOLD CLEAR-OUT", call = "Haushaltsauflösung", hot = 0.0,
		pool = {&"scrap_can": 5, &"scrap_kettle": 3, &"scrap_candle": 3, &"scrap_key": 3, &"scrap_bikebell": 2, &"junk_spring": 2, &"scrap_trophy": 1}},
	{board = "WORKSHOP CLEAR-OUT", call = "Werkstattauflösung", hot = 0.08,
		pool = {&"scrap_pipe": 5, &"junk_gear": 3, &"junk_bolt": 3, &"junk_sheet": 3, &"scrap_key": 2, &"junk_spring": 2, &"scrap_kettle": 1}},
	{board = "ESTATE LOT", call = "Nachlass", hot = 0.3,
		pool = {&"scrap_trophy": 4, &"scrap_candle": 3, &"scrap_coin": 2, &"scrap_kettle": 2, &"scrap_bikebell": 2, &"scrap_ring": 1, &"scrap_tooth": 1}},
]
## Pieces in a small, a middling and a big lot (from, to), and how often each comes (shares).
const SIZES := [[5, 7], [8, 11], [12, 15]]
const SIZE_SHARES := [5, 4, 2]
## The opening bid is this share of what the pieces bring at the crew's stall; the other bidder
## goes up to a share between these two.
const OPENING := 0.3
const RIVAL := Vector2(0.4, 0.95)

signal changed

## Which arch of the viaduct, and the number on the board (1 from the west).
var bay := 0
var number := 1
var state := State.RESTING
var theme := 0
var pieces := 0
var opening := 0
## The standing bid, whether it is the crew's, the other bidder's number and the seconds to the hammer.
var bid := 0
var ours := false
var rival := 0
var time_left := 0.0
## Host: what is in the lot, what the other bidder would pay at most, when he raises next, how long
## the lock-up rests or has stood open, and the names of the pieces lying in it.
var _lot: Array[StringName] = []
var _rival_limit := 0
var _rival_in := -1.0
var _clock := 0.0
var _goods: Array[String] = []
var _empty_for := 0.0
var _called := 0
var _rng := RandomNumberGenerator.new()
var _shutter: Node3D
var _block: CollisionShape3D
var _clutter: Node3D
var _lines: Array[Label3D] = []
var _lamp: OmniLight3D
var _lift := 0.0


func _init() -> void:
	_rng.randomize()


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(&"interactable")
	Network.peer_ready.connect(_on_peer_ready)
	# The shutter stops people while it is down.
	var body := StaticBody3D.new()
	_block = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(TownStreets.DOOR.x, TownStreets.DOOR.y, 0.2)
	_block.shape = box
	_block.position = Vector3(0, TownStreets.DOOR.y * 0.5, 0.1)
	body.add_child(_block)
	add_child(body)
	# What stands at the back of the room is no part of this station (the contour on the station a
	# player looks at would run round the furniture too): it hangs beside it in the level.
	_clutter = Node3D.new()
	_clutter.name = "%s_Stuff" % name
	_clutter.transform = transform
	get_parent().add_child.call_deferred(_clutter)
	if StationKit.visual():
		_build()
	_show()


func _exit_tree() -> void:
	if is_instance_valid(_clutter):
		_clutter.queue_free()


# --- What a lot is worth ----------------------------------------------------------------------

## What the pieces of a lot bring at the crew's stall (hot goods: half of what the pawnbroker pays).
static func worth(lot: Array) -> int:
	var sum := 0
	for kind: StringName in lot:
		sum += FoundryRules.black_price(kind) / 2 if FoundryRules.is_hot(kind) else YardStall.find_price(kind)
	return sum


## The next bid after `now`: small steps while the sums are small.
static func raise_of(now: int) -> int:
	return now + (5 if now < 50 else (10 if now < 200 else 25))


## A lot of `kind` (index of THEMES) with `count` pieces, drawn with `rng`.
static func draw(kind: int, count: int, rng: RandomNumberGenerator) -> Array[StringName]:
	var pool: Dictionary = THEMES[kind].pool
	var total := 0
	for share: int in pool.values():
		total += share
	var out: Array[StringName] = []
	for i in count:
		var pick := rng.randi_range(1, total)
		for piece: StringName in pool:
			pick -= int(pool[piece])
			if pick <= 0:
				out.append(piece)
				break
	if rng.randf() < float(THEMES[kind].hot):
		# Something the owner had better not have kept: one piece is hot goods.
		var hot: Array[StringName] = []
		for piece: StringName in FoundryRules.HOT:
			for n in int(FoundryRules.HOT[piece].get("weight", 0)) / 10:
				hot.append(piece)
		if not hot.is_empty():
			out[rng.randi_range(0, out.size() - 1)] = hot[rng.randi_range(0, hot.size() - 1)]
	return out


# --- The auction (host) ----------------------------------------------------------------------

## Host: a new lot behind the shutter. `kind` and `count` are drawn unless given (tests, pictures).
func stock(kind := -1, count := -1) -> void:
	if not Network.is_sim_authority():
		return
	_clear_goods()
	theme = kind if kind >= 0 else _rng.randi_range(0, THEMES.size() - 1)
	if count < 0:
		var pick := _rng.randi_range(1, SIZE_SHARES[0] + SIZE_SHARES[1] + SIZE_SHARES[2])
		var size := 0 if pick <= SIZE_SHARES[0] else (1 if pick <= SIZE_SHARES[0] + SIZE_SHARES[1] else 2)
		count = _rng.randi_range(SIZES[size][0], SIZES[size][1])
	_lot = draw(theme, count, _rng)
	pieces = _lot.size()
	var value := worth(_lot)
	opening = maxi(10, roundi(value * OPENING / 5.0) * 5)
	_rival_limit = roundi(value * _rng.randf_range(RIVAL.x, RIVAL.y))
	rival = _rng.randi_range(2, 29)
	bid = 0
	ours = false
	time_left = 0.0
	state = State.SHUT
	_publish()


## Host: nothing behind the shutter for `seconds`; then a new lot comes.
func rest(seconds: float) -> void:
	if not Network.is_sim_authority():
		return
	_clear_goods()
	_lot.clear()
	state = State.RESTING
	_clock = seconds
	_publish()


## Host: the crew bids (the opening bid, or one step over the other bidder).
func place_bid() -> bool:
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	if not Network.is_sim_authority() or world == null or (state != State.SHUT and state != State.BIDDING) or (state == State.BIDDING and ours):
		return false
	var next := next_bid()
	if world.money < next:
		return false
	if state == State.SHUT:
		_call("Los %d: %s, %d Teile. %s $ sind geboten!" % [number, THEMES[theme].call, pieces, HUD._format(next)], false)
	else:
		_call("%s $ von der Schrotthalle! Wer bietet mehr?" % HUD._format(next), false)
	state = State.BIDDING
	bid = next
	ours = true
	time_left = COUNT
	_called = 0
	var guide := get_tree().get_first_node_in_group(&"guides") as Guide
	if guide:
		guide.note(&"lot_bid")
	# The other bidder thinks it over, if the lot is still worth it to him.
	_rival_in = _rng.randf_range(1.2, COUNT - 1.6) if raise_of(bid) <= _rival_limit else -1.0
	_publish()
	return true


## What the crew would bid now.
func next_bid() -> int:
	return opening if state == State.SHUT else raise_of(bid)


func _physics_process(delta: float) -> void:
	# The shutter rolls up and down on every screen.
	var want := 1.0 if state == State.WON else 0.0
	if _lift != want:
		_lift = move_toward(_lift, want, delta * 0.9)
		_show_shutter()
	if state == State.BIDDING:
		time_left = maxf(0.0, time_left - delta)
	if not Network.is_sim_authority():
		return
	match state:
		State.BIDDING:
			_bidding(delta)
		State.WON:
			_open(delta)
		State.RESTING:
			_clock -= delta
			if _clock <= 0.0:
				stock()


func _bidding(delta: float) -> void:
	if ours and _rival_in >= 0.0:
		_rival_in -= delta
		if _rival_in < 0.0:
			bid = raise_of(bid)
			ours = false
			time_left = COUNT
			_called = 0
			_call("%s $ von Bieter %d! Wer bietet mehr?" % [HUD._format(bid), rival], false)
			_publish()
			return
	if _called == 0 and time_left < COUNT * 0.55:
		_called = 1
		_call("%s $ – zum Ersten …" % HUD._format(bid), false)
	elif _called == 1 and time_left < COUNT * 0.25:
		_called = 2
		_call("… zum Zweiten …", false)
	if time_left > 0.0:
		return
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	if ours and world and world.money >= bid:
		world.add_money(-bid)
		_call("… und zum Dritten! Verkauft an die Schrotthalle für %s $." % HUD._format(bid), true, true)
		Missions.report(get_tree(), &"lot_won", 1)
		_lay_out()
		state = State.WON
		_clock = 0.0
		_empty_for = 0.0
	else:
		if ours:
			_call("Kein Geld, kein Los! Es geht an Bieter %d." % rival, true)
		else:
			_call("… und zum Dritten! Verkauft an Bieter %d für %s $." % [rival, HUD._format(bid)], true)
		ours = false
		_lot.clear()
		state = State.RESTING
		_clock = REST_SOLD
	_publish()


## Host: the pieces of the lot, laid out on the floor of the room: along both side walls, two deep,
## so that the way down the middle stays free.
func _lay_out() -> void:
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	_goods.clear()
	if world == null:
		return
	for i in _lot.size():
		var kind := _lot[i]
		var info: Dictionary = FoundryRules.find_info(kind)
		if info.is_empty():
			continue
		var side := -1.0 if i % 2 == 0 else 1.0
		var slot := i / 2
		var spot := Vector3(side * (0.88 + (slot % 2) * 0.5 + _rng.randf_range(-0.06, 0.06)), 0.3, 0.9 + (slot / 2) * 0.75 + _rng.randf_range(-0.08, 0.08))
		var item := world.spawn_item(kind, info.color, info.size, 0.4, to_global(spot))
		if item:
			item.rotation.y = _rng.randf_range(0.0, TAU)
			_goods.append(String(item.name))
	_lot.clear()


## The pieces of the crew's lot that still lie in the room.
func goods_inside() -> Array:
	var out := []
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	if world == null or state != State.WON:
		return out
	for node in world.entities.get_children():
		var item := node as Item
		if item == null or item is ScrapBucket or item.is_queued_for_deletion() or FoundryRules.find_info(item.kind).is_empty():
			continue
		if in_room(item.global_position) and not item.is_held() and not _carried(item):
			out.append(item)
	return out


## Whether `at` lies in the room behind the door (with `grow` to spare all round).
func in_room(at: Vector3, grow := 0.0) -> bool:
	var local := to_local(at)
	return absf(local.x) < TownStreets.ARCH_W * 0.5 + grow and local.z > -0.2 - grow and local.z < TownStreets.LOCKUP_D + grow


## Whether somebody carries `item`. The host knows it from the thing itself (Item.is_held), the
## other players only from the carrier.
func _carried(item: Item) -> bool:
	for player in get_tree().get_nodes_in_group(&"players"):
		if (player as Player).held_item() == item:
			return true
	return false


## Host: every piece in the room goes into `bucket`, as far as it has room. Returns how many.
func sweep(bucket: ScrapBucket) -> int:
	if not Network.is_sim_authority():
		return 0
	var took := 0
	for item: Item in goods_inside():
		if not bucket.add(item.kind):
			break
		item.queue_free()
		took += 1
	return took


func _open(delta: float) -> void:
	_clock += delta
	var inside := goods_inside()
	_empty_for = _empty_for + delta if inside.is_empty() else 0.0
	if _empty_for < 6.0 and _clock < CLEAR_AFTER:
		return
	# Nobody and nothing of the crew's is shut in: the shutter waits for whoever still stands in the
	# room, and for the bucket (or a tool) somebody set down there.
	if _occupied():
		return
	# What the crew left lying after all that time is paid for: it is set out by the kerb.
	if not inside.is_empty():
		_set_out(inside)
	_goods.clear()
	state = State.RESTING
	_clock = REST_WON
	_publish()


## Host: whether somebody stands in the room, or something that is no find lies in it (the bucket, a
## tool, a casting).
func _occupied() -> bool:
	for player in get_tree().get_nodes_in_group(&"players"):
		if in_room((player as Node3D).global_position, 0.4):
			return true
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	if world == null:
		return false
	for node in world.entities.get_children():
		var item := node as Item
		if item and not item.is_queued_for_deletion() and (item is ScrapBucket or FoundryRules.find_info(item.kind).is_empty()) and in_room(item.global_position):
			return true
	return false


## Host: the pieces still in the room are set out on the pavement in front of it, in two rows by the
## kerb (clear of the door), and the auctioneer says so.
func _set_out(items: Array) -> void:
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	if world == null:
		return
	for i in items.size():
		var item: Item = items[i]
		var info: Dictionary = FoundryRules.find_info(item.kind)
		var spot := Vector3(-1.26 + (i % 8) * 0.36, 0.3, -3.0 - (i / 8) * 0.42)
		world.spawn_item(item.kind, info.color, info.size, 0.4, to_global(spot))
		item.queue_free()
	_call("Lager %d wird geräumt – der Rest von Los %d steht am Bordstein." % [number, number], false)


## Host: what still lies in the room goes with the clearance.
func _clear_goods() -> void:
	if state == State.WON:
		for item: Item in goods_inside():
			item.queue_free()
	_goods.clear()


# --- The station -------------------------------------------------------------------------------

func interact_point() -> Vector3:
	return global_position + Vector3(0, 1.2, 0)


## Whether [F] can bid here (a lot waits, or the bidding runs).
func takes_bids() -> bool:
	return state == State.SHUT or state == State.BIDDING


## A Suchauftrag hides its find only in front of the door: the room behind may be shut.
func hunt_spot_ok(at: Vector3) -> bool:
	return to_local(at).z < -0.3


func in_reach(player: Node3D) -> bool:
	return interact_point().distance_to(player.global_position + Vector3(0, 0.9, 0)) < USE_RANGE


## Host: the player at the shutter presses [F].
func interact(player: Node) -> void:
	var who := player as Player
	if not Network.is_sim_authority() or who == null or not in_reach(who):
		return
	if state == State.SHUT or (state == State.BIDDING and not ours):
		var world := get_tree().get_first_node_in_group(&"world") as GameWorld
		if not place_bid() and world and world.money < next_bid():
			world.popup_all(interact_point() + Vector3(0, 0.6, 0), "Zu wenig Geld", UITheme.BAD)


func hint(_player: Node) -> String:
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	var money := world.money if world else 0
	match state:
		State.SHUT:
			var what := "Los %d · %s, %d Teile" % [number, THEMES[theme].call, pieces]
			if money < opening:
				return "%s · Startgebot %s $ – es fehlen noch %s $" % [what, HUD._format(opening), HUD._format(opening - money)]
			return "[F] Mitbieten · %s · Startgebot %s $" % [what, HUD._format(opening)]
		State.BIDDING:
			var left := ceili(time_left)
			if ours:
				return "Ihr bietet %s $ · noch %d s bis zum Zuschlag" % [HUD._format(bid), left]
			var next := raise_of(bid)
			if money < next:
				return "Bieter %d hält %s $ · für %s $ fehlen euch %s $" % [rival, HUD._format(bid), HUD._format(next), HUD._format(next - money)]
			return "[F] %s $ bieten · Bieter %d hält %s $ (noch %d s)" % [HUD._format(next), rival, HUD._format(bid), left]
		State.WON:
			var n := goods_inside().size()
			return "Euer Los · noch %d Teile – raustragen oder mit dem Eimer einsammeln" % n if n > 0 else "Euer Los · alles draußen"
	return "Lager %d · das nächste Los kommt bald" % number


## With the bucket in hand at an open lock-up: what [F] does.
func bucket_hint(bucket: ScrapBucket) -> String:
	var n := goods_inside().size()
	if n == 0:
		return ""
	if bucket.is_full():
		return "Eimer voll – erst leeren, dann den Rest holen"
	return "[F] Alles in den Eimer (%d Teile)" % n


# --- Telling the others ------------------------------------------------------------------------

func _publish() -> void:
	_show()
	changed.emit()
	if Network.is_online() and multiplayer.is_server():
		_sync.rpc(state, theme, pieces, opening, bid, ours, rival, time_left)


func _on_peer_ready(id: int, _level: String) -> void:
	if is_inside_tree() and Network.is_online() and multiplayer.is_server():
		_sync.rpc_id(id, state, theme, pieces, opening, bid, ours, rival, time_left)


@rpc("authority", "call_remote", "reliable")
func _sync(now: int, kind: int, count: int, from: int, standing: int, crew: bool, other: int, left: float) -> void:
	var was_open := state == State.WON
	state = now as State
	theme = clampi(kind, 0, THEMES.size() - 1)
	pieces = count
	opening = from
	bid = standing
	ours = crew
	rival = other
	time_left = left
	_show()
	changed.emit()
	if was_open and state != State.WON:
		_put_out()


## This peer's own worker, should the shutter come down behind him (the host closes on what it sees
## of him, a moment late): he is set in front of the door.
func _put_out() -> void:
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	var me := world.local_player() if world else null
	if me and in_room(me.global_position, 0.1) and to_local(me.global_position).z > -0.3:
		me._do_teleport(to_global(Vector3(0, 0.06, -1.2)))


## Host: the auctioneer calls it out, on every screen; with `hammer` a lot is knocked down, with `won`
## to the crew.
func _call(text: String, hammer: bool, won := false) -> void:
	var auction := StorageAuction.of(get_tree())
	if auction:
		auction.call_out(text, hammer, won)


# --- Looks ---------------------------------------------------------------------------------------

## Board, shutter position, lamp and clutter after a change.
func _show() -> void:
	if _block:
		_block.set_deferred(&"disabled", state == State.WON)
	_dress()
	if _lines.size() < 2:
		return
	match state:
		State.SHUT:
			_lines[0].text = "LOT %d · %s" % [number, THEMES[theme].board]
			_lines[1].text = "%d PIECES · BIDS FROM %s $" % [pieces, HUD._format(opening)]
		State.BIDDING:
			_lines[0].text = "LOT %d · %s" % [number, THEMES[theme].board]
			_lines[1].text = "BID %s $ · %s" % [HUD._format(bid), "YOUR CREW" if ours else "BIDDER %d" % rival]
		State.WON:
			_lines[0].text = "LOT %d · SOLD" % number
			_lines[1].text = "TO HEINZ & NEPHEW"
		_:
			_lines[0].text = "UNIT %d" % number
			_lines[1].text = "NEXT LOT SOON"
	if _lamp:
		_lamp.visible = state == State.WON


## The shutter rolls up towards its box at the door's head: it gets shorter from below while its top
## stays where it is. (Lifted as a whole, the box travelled up across the board and into the arch.)
func _show_shutter() -> void:
	if _shutter:
		var left := 1.0 - _lift * (1.0 - 0.3 / TownStreets.DOOR.y)
		_shutter.scale.y = left
		_shutter.position.y = TownStreets.DOOR.y * (1.0 - left)


## What stands at the back of the room: it belongs to the lot's kind and goes with it.
func _dress() -> void:
	var want := theme if state == State.SHUT or state == State.BIDDING or state == State.WON else -1
	if _clutter.has_meta(&"theme") and int(_clutter.get_meta(&"theme")) == want:
		return
	for child in _clutter.get_children():
		child.queue_free()
	_clutter.set_meta(&"theme", want)
	var back := TownStreets.LOCKUP_D
	match want:
		0:
			PhotoProp.place(_clutter, "sofa_02", Vector3(-0.35, 0, back - 0.62), 180.0)
			PhotoProp.place(_clutter, "ArmChair_01", Vector3(1.25, 0, back - 1.5), 215.0)
			PhotoProp.place(_clutter, "cardboard_box_01", Vector3(-1.4, 0, back - 1.7), 12.0)
			PhotoProp.place(_clutter, "cardboard_box_01", Vector3(1.35, 0, back - 0.45), 80.0, false)
		1:
			PhotoProp.place(_clutter, "worn_metal_rack", Vector3(-0.6, 0, back - 0.4), 180.0)
			PhotoProp.place(_clutter, "metal_tool_chest", Vector3(1.2, 0, back - 0.5), 180.0)
			PhotoProp.place(_clutter, "barrel_03", Vector3(-1.45, 0, back - 1.5), 0.0)
			PhotoProp.place(_clutter, "old_tyre", Vector3(1.4, 0, back - 1.5), 0.0, false)
		2:
			PhotoProp.place(_clutter, "GothicCabinet_01", Vector3(-0.7, 0, back - 0.66), 180.0)
			PhotoProp.place(_clutter, "vintage_grandfather_clock_01", Vector3(1.3, 0, back - 0.4), 180.0)
			PhotoProp.place(_clutter, "wooden_crate_02", Vector3(-1.4, 0, back - 1.6), 20.0)
			PhotoProp.place(_clutter, "ArmChair_01", Vector3(1.2, 0, back - 1.6), 200.0)


func _build() -> void:
	# The shutter: behind the sheet of the front, so that it rolls up out of sight.
	_shutter = Node3D.new()
	_shutter.position.z = 0.16
	add_child(_shutter)
	PhotoProp.mount(_shutter, "rollershutter_door:0", Vector3.ZERO, Vector3.FORWARD, TownStreets.DOOR)
	_show_shutter()
	# The board over the doorway: what is behind it, and where the bidding stands.
	var plate := StandardMaterial3D.new()
	plate.albedo_color = Color("#e9e2cf")
	plate.roughness = 0.6
	EnvMesh.add(self, EnvMesh.box(Vector3(2.5, 0.52, 0.03), 0.01), plate, Transform3D(Basis(), Vector3(0, TownStreets.DOOR.y + 0.42, -0.03)))
	for i in 2:
		var line := StationKit.label(self, "", Transform3D(Basis(Vector3.UP, PI), Vector3(0, TownStreets.DOOR.y + 0.53 - i * 0.22, -0.05)),
			64 if i == 0 else 56, Color("#7a2a22") if i == 0 else Color("#22342c"), 800, 0.0026)
		_lines.append(line)
	# A bulb under the vault, lit when the lock-up stands open.
	_lamp = OmniLight3D.new()
	_lamp.light_color = Color("#ffdcae")
	_lamp.light_energy = 1.4
	_lamp.omni_range = 6.5
	_lamp.position = Vector3(0, 2.9, 2.6)
	_lamp.visible = false
	add_child(_lamp)
