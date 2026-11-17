class_name TownLaw
extends Node
## The law in the quarter. Hot goods (FoundryRules.HOT) turn up in the scrap;
## they can be handed in at the police station for a small reward, or sold
## under the counter at the pawnbroker for real money. Every shady sale
## raises `heat` ("Fahndung", 0..1): the patrol sees further, gets suspicious
## faster and runs faster. Heat cools off over time and when goods are handed
## in. Host decides, peers mirror `heat` for the HUD.

const GROUP := &"town_law"
## Heat per piece sold under the counter / handed in / per arrest.
const SALE_HEAT := 0.1
const HAND_IN_HEAT := -0.12
const CAUGHT_HEAT := 0.15
const ESCAPE_HEAT := 0.05
## Full heat cools off in this many seconds.
const COOL_TIME := 300.0
## Share of the black-market value a caught player pays on top of losing the goods.
const FINE_SHARE := 0.5
const FINE_MIN := 10

signal heat_changed(heat: float)

var heat := 0.0
var _told := false
var _sent := 0.0


static func of(tree: SceneTree) -> TownLaw:
	return tree.get_first_node_in_group(GROUP) as TownLaw


func _init() -> void:
	name = "TownLaw"


func _ready() -> void:
	add_to_group(GROUP)
	if DisplayServer.get_name() != "headless":
		add_child(LawHud.new())
	for arg in OS.get_cmdline_user_args():
		if arg == "--hot" or arg == "--pad" or arg == "--machines" or arg == "--shop":
			_debug(arg)


## Art checks: `--hot` puts a hot pistol into the player's hands and raises
## the heat; `--pad` buys the foundry corner and opens the drawing pad;
## `--machines` buys workbench, excavator and truck.
func _debug(arg: String) -> void:
	await get_tree().create_timer(1.2).timeout
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	var me := world.local_player() if world else null
	if me == null:
		return
	if arg == "--shop":
		world.add_money(640)
		world.upgrades.buy(&"bucket_big")
		for node in world.get_children():
			if node is UpgradeBoard:
				(node as UpgradeBoard).interact(me)
		return
	if arg == "--machines":
		world.add_money(5000)
		for id: StringName in [&"workbench", &"excavator", &"truck"]:
			world.upgrades.buy(id)
		return
	if arg == "--pad":
		world.add_money(1000)
		world.upgrades.buy(&"foundry_corner")
		await get_tree().create_timer(0.5).timeout
		var bench := get_tree().get_first_node_in_group(&"model_benches") as ModelBench
		if bench == null:
			for node in world.get_children():
				if node is ModelBench:
					bench = node
		if bench:
			bench._open_pad("Zeichne dein Modell", &"")
		return
	var info: Dictionary = FoundryRules.HOT[&"hot_pistol"]
	var item := world.spawn_item(&"hot_pistol", info.color, info.size, 0.4, me.global_position + Vector3(0, 1.2, 0) + me.global_transform.basis.z * 0.5)
	await get_tree().physics_frame
	await get_tree().physics_frame
	me.grab(item)
	add_heat(0.45)


func _physics_process(delta: float) -> void:
	if not Network.is_sim_authority() or heat <= 0.0:
		return
	heat = maxf(0.0, heat - delta / COOL_TIME)
	if absf(heat - _sent) > 0.02 or (heat == 0.0 and _sent != 0.0):
		_publish()


## Host: the players got hotter (or cooler, with a negative amount).
func add_heat(amount: float) -> void:
	heat = clampf(heat + amount, 0.0, 1.0)
	_publish()


func _publish() -> void:
	_sent = heat
	heat_changed.emit(heat)
	if Network.is_online() and multiplayer.is_server():
		_sync.rpc(heat)


@rpc("authority", "call_remote", "unreliable_ordered")
func _sync(h: float) -> void:
	heat = h
	heat_changed.emit(heat)


## Wanted level 0..5 for the HUD.
func stars() -> int:
	return ceili(heat * 5.0 - 0.001) if heat > 0.01 else 0


## Host: a hot find came out of the heap. The first one explains the choice.
static func hot_found(world: GameWorld, kind: StringName, pos: Vector3) -> void:
	world.popup_all(pos + Vector3(0, 0.75, 0), "Heiße Ware: %s!" % FoundryRules.HOT[kind].name, UITheme.BAD)
	var law := of(world.get_tree())
	if law and not law._told:
		law._told = true
		world.banner_all("HEISSE WARE", UITheme.BAD, "Police: kleiner Finderlohn · Pawn Shop: viel Geld – lass dich nicht erwischen")


## Black-market price of a cast weapon: this many times its honest value.
const WEAPON_MULT := 3
## Heat for one weapon sold.
const WEAPON_HEAT := 0.15


## The weapon a casting is (&"knuckles", &"dagger", &"pistol"), &"" if it is
## an honest piece. Worked out once per piece.
static func weapon_of(piece: Node) -> StringName:
	var cast := piece as CastPiece
	if cast == null:
		return &""
	if cast.has_meta(&"weapon"):
		return cast.get_meta(&"weapon")
	var found := &""
	if not cast.series and cast.drawing_code != "":
		var d := Drawing.from_code(cast.drawing_code)
		for id: StringName in DrawingTemplates.MOTIFS:
			if DrawingTemplates.MOTIFS[id].get("dark", false) and DrawingTemplates.score(d, id) >= DrawingTemplates.MATCH:
				found = id
				break
	cast.set_meta(&"weapon", found)
	return found


## What the pawnbroker pays for a cast weapon (without an order's bonus).
static func weapon_price(piece: Node) -> int:
	return (piece as CastPiece).value() * WEAPON_MULT if weapon_of(piece) != &"" else 0


## What `player` carries that the police must not see:
## {value = black-market value, open = true if it is in plain sight (in the
## hands), body = the item, casting or bucket, count = pieces}.
static func carried_hot(player: Player) -> Dictionary:
	var body := player.held
	if body == null or not is_instance_valid(body):
		return {}
	if body is ScrapBucket:
		var bucket := body as ScrapBucket
		if bucket.hot > 0:
			var value := 0
			for k: StringName in bucket.hot_kinds():
				value += FoundryRules.black_price(k)
			return {value = value, open = false, body = bucket, count = bucket.hot}
		return {}
	if weapon_of(body) != &"":
		return {value = weapon_price(body), open = true, body = body, count = 1}
	var item := body as Item
	if item and FoundryRules.is_hot(item.kind):
		return {value = FoundryRules.black_price(item.kind), open = true, body = item, count = 1}
	return {}


## Host: `player` was caught with hot goods on them. The goods are gone and a
## fine is due. Returns the fine paid.
func arrest(world: GameWorld, player: Player) -> int:
	var load := carried_hot(player)
	if load.is_empty():
		return 0
	var value: int = load.value
	if load.body is ScrapBucket:
		(load.body as ScrapBucket).take_hot()
	else:
		player.release()
		(load.body as Node).queue_free()
	var fine := mini(world.money, maxi(FINE_MIN, roundi(value * FINE_SHARE)))
	if fine > 0:
		world.add_money(-fine)
	add_heat(CAUGHT_HEAT)
	world.banner_near(player.global_position, "ERWISCHT!", UITheme.BAD, "Ware beschlagnahmt · %d $ Strafe" % fine, false)
	return fine
