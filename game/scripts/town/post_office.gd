class_name PostOffice
extends Node3D
## The counter of the post office on Bank Street: mail orders. People out of town order things the
## scrap heap gives up, and the post office pays well for them, far more than the dealer or the
## crew's stall. Three orders hang on the board at a time: a find, how many of it, what each piece
## pays. A piece is handed over by hand ([LMB] with it in front of the counter) or straight out of
## the bucket ([F] with the bucket: every piece that is asked for). A filled order makes room for a
## new one after a while. The host keeps the orders and pays; the others see the board and their
## presses reach the host like everywhere else. Orders are not saved with the game.
## The node lies in the post office's own frame (ScrapHallSet.post_lot): the counter runs along x,
## the customers stand at -z.

const GROUP := &"post_offices"
## As far as a player is offered the counter (Player.nearest_interactable), so [F] never falls flat.
const USE_RANGE := 3.5
## Orders on the board, and seconds until a filled one is replaced.
const SLOTS := 3
const RENEW := 30.0
## What the post pays: so many times the dealer's price, rounded to 5 $, and never less than MIN_PAY.
const FACTOR := 4.0
const MIN_PAY := 10
## What gets ordered (kind -> how often it comes up), and how many pieces of the cheap kinds.
const WANTS := {&"scrap_can": 3, &"scrap_key": 3, &"scrap_bikebell": 3, &"scrap_pipe": 3, &"scrap_candle": 3, &"scrap_trophy": 2,
	&"scrap_kettle": 2, &"scrap_tooth": 1, &"scrap_coin": 1, &"scrap_ring": 1}
const MANY := {&"scrap_can": 3, &"scrap_key": 2, &"scrap_bikebell": 2, &"scrap_pipe": 2}
## Where the cards hang on the board (the board's own frame: x along it, y up), and the board's
## place in the room (set by the level).
const CARD_W := 0.62

signal changed

## The orders: {kind, count (pieces wanted), done (pieces handed over), pay (per piece), rest (s
## until a filled order is replaced; 0: open)}.
var orders: Array[Dictionary] = []
## Where the board hangs (this node's frame) and which way it looks (yaw, degrees).
var board_at := Vector3(0, 1.75, 0)
var board_yaw := 0.0
var _rng := RandomNumberGenerator.new()
var _cards: Array[Node3D] = []
var _shown: Array[StringName] = []


func _init() -> void:
	name = "PostOffice"
	_rng.randomize()


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(&"interactable")
	add_to_group(&"toss_targets")
	Network.peer_ready.connect(_on_peer_ready)
	if Network.is_sim_authority():
		for i in SLOTS:
			orders.append(_new_order())
	if StationKit.visual():
		_build()
	_show()


# --- What is asked for -------------------------------------------------------------------------

## What the post pays for one piece of `kind`.
static func pay_for(kind: StringName) -> int:
	return maxi(MIN_PAY, roundi(FoundryRules.raw_price(kind) * FACTOR / 5.0) * 5)


## The open order for `kind` (index), or -1.
func order_for(kind: StringName) -> int:
	for i in orders.size():
		var o := orders[i]
		if o.kind == kind and float(o.rest) <= 0.0 and int(o.done) < int(o.count):
			return i
	return -1


## Host: an order for something that is not on the board yet.
func _new_order() -> Dictionary:
	var bag: Array[StringName] = []
	for kind: StringName in WANTS:
		var taken := false
		for o in orders:
			if o.kind == kind:
				taken = true
		if not taken:
			for n in int(WANTS[kind]):
				bag.append(kind)
	var kind: StringName = bag[_rng.randi_range(0, bag.size() - 1)]
	return {kind = kind, count = int(MANY.get(kind, 1)), done = 0, pay = pay_for(kind), rest = 0.0}


## Host (tests, pictures): the board asks for exactly these kinds.
func set_orders(kinds: Array) -> void:
	if not Network.is_sim_authority():
		return
	orders.clear()
	for kind: StringName in kinds:
		orders.append({kind = kind, count = int(MANY.get(kind, 1)), done = 0, pay = pay_for(kind), rest = 0.0})
	_publish()


func _physics_process(delta: float) -> void:
	if not Network.is_sim_authority():
		return
	var renewed := false
	for i in orders.size():
		var o := orders[i]
		if float(o.rest) > 0.0:
			o.rest = float(o.rest) - delta
			if float(o.rest) <= 0.0:
				orders[i] = {kind = &"", count = 0, done = 0, pay = 0, rest = 0.0}
				orders[i] = _new_order()
				renewed = true
	if renewed:
		_publish()


## Host: one piece of `kind` comes over the counter. Returns what it paid (0: nobody ordered it).
func deliver(kind: StringName) -> int:
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	var i := order_for(kind)
	if not Network.is_sim_authority() or world == null or i < 0:
		return 0
	var o := orders[i]
	o.done = int(o.done) + 1
	var pay := int(o.pay)
	if int(o.done) >= int(o.count):
		o.rest = RENEW
	world.add_money(pay)
	Missions.report(get_tree(), &"parcel", 1)
	return pay


# --- Handing over by hand (Player.toss_target) --------------------------------------------------

func toss_accepts(body: Node3D) -> bool:
	var item := body as Item
	return item != null and not (item is ScrapBucket) and order_for(item.kind) >= 0


func toss_point() -> Vector3:
	return _counter_point()


func toss_hint(body: Node3D) -> String:
	var item := body as Item
	return "Am Postschalter abgeben · %d $" % (pay_for(item.kind) if item else 0)


## Host: the piece let go in front of the counter is taken in.
func toss_place(body: Node3D) -> bool:
	var item := body as Item
	if item == null:
		return false
	var pay := deliver(item.kind)
	if pay <= 0:
		return false
	item.queue_free()
	_paid(pay, 1)
	return true


## Host: every piece in `bucket` that is asked for goes over the counter. Returns how many.
func take_from(bucket: ScrapBucket) -> int:
	if not Network.is_sim_authority():
		return 0
	var sent := 0
	var sum := 0
	for kind: StringName in bucket.contents.duplicate():
		if order_for(kind) < 0 or not bucket.take_out(kind):
			continue
		sum += deliver(kind)
		sent += 1
	if sent > 0:
		_paid(sum, sent)
	else:
		# (A player on another screen does not see what is in the bucket: tell him why nothing went.)
		var world := get_tree().get_first_node_in_group(&"world") as GameWorld
		if world:
			world.popup_all(_counter_point() + Vector3(0, 0.6, 0), "Nichts Bestelltes im Eimer", UITheme.BAD)
	return sent


## How many pieces of `bucket` are asked for right now (the host knows what is in it).
func wanted_in(bucket: ScrapBucket) -> int:
	var left := {}
	for i in orders.size():
		var o := orders[i]
		if float(o.rest) <= 0.0:
			left[o.kind] = int(o.count) - int(o.done)
	var n := 0
	for kind: StringName in bucket.contents:
		if int(left.get(kind, 0)) > 0:
			left[kind] = int(left[kind]) - 1
			n += 1
	return n


func bucket_hint(bucket: ScrapBucket) -> String:
	# Only the host knows what is in the bucket; the others are offered the hand-over as such.
	if not Network.is_sim_authority():
		return "[F] Bestellte Stücke aus dem Eimer am Postschalter abgeben" if bucket.count > bucket.hot else "Post: im Eimer ist nichts, was gerade bestellt ist"
	var n := wanted_in(bucket)
	if n > 0:
		return "[F] %d bestellte%s Stück%s am Postschalter abgeben" % [n, "s" if n == 1 else "", "" if n == 1 else "e"]
	return "Post: im Eimer ist nichts, was gerade bestellt ist"


func _paid(sum: int, count: int) -> void:
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	if world:
		world.popup_all(_counter_point() + Vector3(0, 0.6, 0), "+%s $ · %d Stück verschickt" % [HUD._format(sum), count] if count > 1 else "+%s $ · verschickt" % HUD._format(sum), UITheme.ACCENT)
	if Network.is_online():
		_fx.rpc()
	else:
		_fx()
	_publish()


@rpc("authority", "call_local", "reliable")
func _fx() -> void:
	Sfx.play(&"coin", _counter_point(), 0.0, 0.03)
	Sfx.play(&"drop_thud", _counter_point(), -6.0, 0.05)


# --- The station -------------------------------------------------------------------------------

## Where pieces go over the counter.
func _counter_point() -> Vector3:
	return to_global(Vector3(0, TownCounter.TOP + 0.1, 0))


## Low on the counter's front: the hint floats over this point (HUD.PROMPT_LIFT) and must not hang
## in front of the board on the wall behind.
func interact_point() -> Vector3:
	return to_global(Vector3(0, TownCounter.TOP - 0.4, 0))


func in_reach(player: Node3D) -> bool:
	return interact_point().distance_to(player.global_position + Vector3(0, 0.9, 0)) < USE_RANGE


func interact(_player: Node) -> void:
	pass


func hint(_player: Node) -> String:
	var parts: Array[String] = []
	for o in orders:
		if float(o.rest) > 0.0 or o.kind == &"":
			continue
		var title := String(FoundryRules.find_info(o.kind).get("name", "?"))
		var left := int(o.count) - int(o.done)
		parts.append("%s%s (%d $)" % ["%d× " % left if left > 1 else "", title, int(o.pay)])
	if parts.is_empty():
		return "Postbestellungen · gerade alles verschickt, gleich kommt Neues"
	return "Postbestellungen · %s – Stück herbringen (in der Hand oder im Eimer)" % ", ".join(parts)


# --- Telling the others ------------------------------------------------------------------------

func _publish() -> void:
	_show()
	changed.emit()
	if Network.is_online() and multiplayer.is_server():
		_sync.rpc(_packed())


func _on_peer_ready(id: int, _level: String) -> void:
	if is_inside_tree() and Network.is_online() and multiplayer.is_server():
		_sync.rpc_id(id, _packed())


func _packed() -> Array:
	var out := []
	for o in orders:
		out.append([String(o.kind), int(o.count), int(o.done), int(o.pay), float(o.rest) > 0.0])
	return out


@rpc("authority", "call_remote", "reliable")
func _sync(packed: Array) -> void:
	orders.clear()
	for entry in packed:
		if typeof(entry) != TYPE_ARRAY or (entry as Array).size() < 5:
			continue
		var e: Array = entry
		orders.append({kind = StringName(str(e[0])), count = int(e[1]), done = int(e[2]), pay = int(e[3]), rest = 1.0 if bool(e[4]) else 0.0})
	_show()
	changed.emit()


# --- Looks ---------------------------------------------------------------------------------------

## The cards on the board: the find itself on a little shelf, how many and what each pays.
func _show() -> void:
	if _cards.is_empty():
		return
	for i in _cards.size():
		var card := _cards[i]
		var o: Dictionary = orders[i] if i < orders.size() else {}
		var open: bool = not o.is_empty() and float(o.rest) <= 0.0 and o.kind != &""
		var kind: StringName = o.get("kind", &"") if open else &""
		(card.get_node(^"Sent") as Label3D).visible = not o.is_empty() and not open
		(card.get_node(^"Count") as Label3D).text = ("%d of %d" % [int(o.done), int(o.count)] if int(o.count) > 1 else "1 piece") if open else ""
		(card.get_node(^"Pay") as Label3D).text = "%d $" % int(o.pay) if open else ""
		(card.get_node(^"Each") as Label3D).visible = open and int(o.count) > 1
		if _shown[i] == kind:
			continue
		_shown[i] = kind
		var holder := card.get_node(^"Piece") as Node3D
		for child in holder.get_children():
			child.queue_free()
		if kind != &"":
			var info: Dictionary = FoundryRules.find_info(kind)
			var mi := MeshInstance3D.new()
			mi.mesh = ScrapModels.mesh(kind)
			mi.material_override = ScrapModels.material(info.get("color", Color.GRAY), kind)
			# Small things are shown bigger, big ones smaller: each fills its shelf.
			var size: Vector3 = info.get("size", Vector3.ONE * 0.2)
			mi.scale = Vector3.ONE * clampf(0.24 / maxf(size.x, maxf(size.y, size.z)), 0.7, 2.6)
			mi.position.y = size.y * 0.5 * mi.scale.y
			holder.add_child(mi)


func _build() -> void:
	# The board: cork in a wooden frame, a heading, and for every order a card with a little shelf.
	var turn := Basis(Vector3.UP, deg_to_rad(board_yaw))
	var frame := Transform3D(turn, board_at)
	var width := SLOTS * CARD_W + 0.3
	var cork := StandardMaterial3D.new()
	cork.albedo_color = Color("#a8804f")
	cork.roughness = 0.95
	var wood := EnvMesh.wood("post_board", {base_color = Color("#4a3423"), grain_color = Color("#2a1c12"), weathering = 0.3, roughness_base = 0.6})
	EnvMesh.add(self, EnvMesh.box(Vector3(width, 1.15, 0.03), 0.0), cork, frame, false)
	var rails := []
	for y: float in [-0.6, 0.6]:
		rails.append(EnvMesh.piece(EnvMesh.box(Vector3(width + 0.1, 0.06, 0.06)), frame * Transform3D(Basis(), Vector3(0, y, 0.01))))
	for x: float in [-width * 0.5 - 0.02, width * 0.5 + 0.02]:
		rails.append(EnvMesh.piece(EnvMesh.box(Vector3(0.06, 1.26, 0.06)), frame * Transform3D(Basis(), Vector3(x, 0, 0.01))))
	StationKit.label(self, "MAIL ORDERS", frame * Transform3D(Basis(), Vector3(0, 0.44, 0.02)), 84, Color("#3a2416"), 800, 0.003)
	StationKit.label(self, "wanted this week · paid on the spot", frame * Transform3D(Basis(), Vector3(0, 0.31, 0.02)), 40, Color("#3a2416"), 500, 0.0026, StationKit.hand_font())
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color("#efe7d2")
	paper.roughness = 0.9
	for i in SLOTS:
		var card := Node3D.new()
		card.transform = frame * Transform3D(Basis(), Vector3((i - (SLOTS - 1) * 0.5) * CARD_W, -0.12, 0.02))
		add_child(card)
		EnvMesh.add(card, EnvMesh.box(Vector3(CARD_W - 0.1, 0.66, 0.006), 0.0), paper, Transform3D(Basis(), Vector3(0, 0, 0.0)), false)
		rails.append(EnvMesh.piece(EnvMesh.box(Vector3(CARD_W - 0.14, 0.025, 0.2)), card.transform * Transform3D(Basis(), Vector3(0, -0.02, 0.1))))
		var piece := Node3D.new()
		piece.name = "Piece"
		piece.position = Vector3(0, -0.005, 0.1)
		card.add_child(piece)
		var count := StationKit.label(card, "", Transform3D(Basis(), Vector3(0, 0.25, 0.006)), 44, Color("#3a2416"), 600, 0.0026, StationKit.hand_font())
		count.name = "Count"
		var pay := StationKit.label(card, "", Transform3D(Basis(), Vector3(0, -0.17, 0.006)), 64, Color("#7a2a22"), 800, 0.0026)
		pay.name = "Pay"
		# Its own small line: "20 $ each" in the price's size was wider than the card.
		var each := StationKit.label(card, "per piece", Transform3D(Basis(), Vector3(0, -0.28, 0.006)), 38, Color("#7a2a22"), 600, 0.0026, StationKit.hand_font())
		each.name = "Each"
		each.visible = false
		var sent := StationKit.label(card, "SENT", Transform3D(Basis(Vector3.BACK, 0.2), Vector3(0, 0.02, 0.008)), 96, Color("#2c6b3f"), 800, 0.0028)
		sent.name = "Sent"
		sent.visible = false
		_cards.append(card)
		_shown.append(&"?")
	EnvMesh.add(self, EnvMesh.merge(rails), wood)
