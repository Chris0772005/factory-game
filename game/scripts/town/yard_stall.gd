class_name YardStall
extends Node3D
## The crew's own stall on the apron in front of the hall. Finds from the heap and castings that lie on
## its table are bought by people of the quarter (rounds of TownWalkers that stop here), one piece per
## visit, for more than the dealer or the sales crate pays. Things are laid on the table by hand
## ([LMB] in front of it, Player.toss_target) or straight from the scrap bucket ([F] with the bucket).
## They stay real things: whoever wants one back takes it off the table. The host sells; the others
## see the piece go, hear the till and read what the customer says.
## With a stall keeper the crew has hired (HiredHand) the customers take more per visit and pay more.
## The table's long side runs along X; the customers stand at +Z (the street side).

const GROUP := &"yard_stalls"
## The table top: its height and its size along X and Z (m).
const TOP := 0.8
const SIZE := Vector2(2.0, 0.94)
## Places on the table: so many along X, so many rows.
const COLS := 4
const ROWS := 2
const USE_RANGE := 2.8
## What a customer pays: so many times the dealer's price for a find, so many times a casting's value.
const FIND_FACTOR := 2.5
const CAST_FACTOR := 1.3
## A customer looks at the table this long before buying (s); what is said stays up this long.
const LOOK_TIME := 2.2
const SAY_TIME := 4.0
## While a hired stall keeper serves: what a customer pays more, and how many pieces one takes per visit.
const KEEPER_BONUS := 1.2
const KEEPER_BUYS := 2

signal sold(pay: int)

## The people's rounds (set by the level together with `customers`).
var walkers: TownWalkers
## Who buys here: {round (index in `walkers`), stop (index of the stop at the table), taste
## (&"finds" or &"castings": what is taken first), at (where the customer stands)}.
var customers: Array = []
var _laps := {}
var _tags: Array[Label3D] = []
var _bubble: Label3D
var _bubble_left := 0.0
var _tag_in := 0.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	name = "YardStall"
	_rng.randomize()


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(&"interactable")
	add_to_group(&"toss_targets")
	# The top carries what is laid on it; the frame under it stops people.
	StationKit.box_collider(self, Vector3(SIZE.x, 0.06, SIZE.y), Transform3D(Basis(), Vector3(0, TOP - 0.03, 0)))
	StationKit.box_collider(self, Vector3(SIZE.x - 0.16, TOP - 0.06, SIZE.y - 0.16), Transform3D(Basis(), Vector3(0, (TOP - 0.06) * 0.5, 0)))
	if StationKit.visual():
		_build()


# --- What is worth what -----------------------------------------------------------

## What a customer pays for `body` (0: not for sale here: buckets, hot goods, glowing castings).
static func price_of(body: Node) -> int:
	var item := body as Item
	if item == null or item is ScrapBucket:
		return 0
	if item.has_method("value"):
		if float(item.get("temperature")) > 0.05 or item.get("series") == true:
			return 0
		return ceili(int(item.value()) * CAST_FACTOR)
	return find_price(item.kind)


## What a customer pays for a find of `kind` (0: hot goods and what is no find).
static func find_price(kind: StringName) -> int:
	if FoundryRules.is_hot(kind):
		return 0
	return ceili(FoundryRules.raw_price(kind) * FIND_FACTOR)


## What a customer pays for `body` right now: with a stall keeper at the table, more.
func price_now(body: Node) -> int:
	var price := price_of(body)
	return ceili(price * KEEPER_BONUS) if price > 0 and HiredHand.serving_at(self) != null else price


## Whether `body` is a casting (the others on the table are finds).
static func is_casting(body: Node) -> bool:
	return body != null and body.has_method("value")


## The middle of place `index` on the table top (local).
func place_pos(index: int) -> Vector3:
	var col := index % COLS
	var row := index / COLS
	return Vector3((col + 0.5) / COLS * SIZE.x - SIZE.x * 0.5, TOP, (row + 0.5) / ROWS * SIZE.y - SIZE.y * 0.5)


## What lies on the table and is for sale: the things themselves.
func goods() -> Array:
	var out := []
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	if world == null:
		return out
	var to_table := global_transform.affine_inverse()
	for node in world.entities.get_children():
		var item := node as Item
		if item == null:
			continue
		# The cheap question first: most things in the hall lie nowhere near the table.
		var local := to_table * item.global_position
		if absf(local.x) > SIZE.x * 0.5 + 0.06 or absf(local.z) > SIZE.y * 0.5 + 0.06 or local.y < TOP - 0.06 or local.y > TOP + 0.7:
			continue
		if item.is_held() or _carried(item) or item.is_queued_for_deletion() or price_of(item) <= 0:
			continue
		out.append(item)
	return out


## Whether somebody carries `item`. The host knows it from the thing itself (Item.is_held), the
## other players only from the carrier.
func _carried(item: Item) -> bool:
	for player in get_tree().get_nodes_in_group(&"players"):
		if (player as Player).held_item() == item:
			return true
	return false


## The places nothing lies on, nearest the customers first.
func free_places() -> Array[int]:
	var lying := goods()
	var out: Array[int] = []
	for i in range(COLS * ROWS - 1, -1, -1):
		var spot := place_pos(i)
		var taken := false
		for item: Item in lying:
			var local := to_local(item.global_position)
			if Vector2(local.x - spot.x, local.z - spot.z).length() < 0.2:
				taken = true
				break
		if not taken:
			out.append(i)
	return out


# --- Laying things on the table ------------------------------------------------------

func toss_accepts(body: Node3D) -> bool:
	return price_of(body) > 0 and not free_places().is_empty()


func toss_point() -> Vector3:
	return to_global(Vector3(0, TOP + 0.3, 0))


func toss_hint(body: Node3D) -> String:
	return "Auf den Verkaufstisch legen · Kunden zahlen %d $" % price_now(body)


## Host: the thing let go in front of the table is laid on a free place.
func toss_place(body: Node3D) -> bool:
	var thing := body as RigidBody3D
	var free := free_places()
	if not Network.is_sim_authority() or thing == null or free.is_empty():
		return false
	_lay(thing, free[0])
	return true


func _lay(thing: RigidBody3D, place: int) -> void:
	var turn := Basis(Vector3.UP, global_rotation.y + _rng.randf_range(-0.5, 0.5))
	thing.global_transform = Transform3D(turn, to_global(place_pos(place) + Vector3(0, 0.16, 0)))
	thing.linear_velocity = Vector3.ZERO
	thing.angular_velocity = Vector3.ZERO
	thing.sleeping = false


## Host: the best finds out of `bucket` are laid on the free places, `most` of them at most.
## Returns how many.
func lay_out(bucket: ScrapBucket, most := 99) -> int:
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	if not Network.is_sim_authority() or world == null:
		return 0
	var free := free_places()
	var kinds := bucket.contents.filter(func(k: StringName) -> bool: return find_price(k) > 0)
	kinds.sort_custom(func(a: StringName, b: StringName) -> bool: return find_price(a) > find_price(b))
	var laid := 0
	for kind: StringName in kinds:
		if free.is_empty() or laid >= most:
			break
		if not bucket.take_out(kind):
			continue
		_put(world, kind, free.pop_front())
		laid += 1
	if laid > 0:
		_laid()
	return laid


## Host: loose finds somebody brings in his hands (`kinds`) are laid on the free places, the dearest
## first. Returns those there was no room for, or that nobody buys here.
func lay_kinds(kinds: Array) -> Array:
	var rest := kinds.duplicate()
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	if not Network.is_sim_authority() or world == null:
		return rest
	var free := free_places()
	var wanted := kinds.filter(func(k: StringName) -> bool: return find_price(k) > 0)
	wanted.sort_custom(func(a: StringName, b: StringName) -> bool: return find_price(a) > find_price(b))
	var laid := 0
	for kind: StringName in wanted:
		if free.is_empty():
			break
		_put(world, kind, free.pop_front())
		rest.erase(kind)
		laid += 1
	if laid > 0:
		_laid()
	return rest


## A find of `kind` appears on place `place` of the table.
func _put(world: GameWorld, kind: StringName, place: int) -> void:
	var info: Dictionary = FoundryRules.find_info(kind)
	var item := world.spawn_item(kind, info.color, info.size, 0.4, to_global(place_pos(place) + Vector3(0, 0.16, 0)))
	if item:
		item.rotation.y = global_rotation.y + _rng.randf_range(-0.5, 0.5)


func _laid() -> void:
	if Network.is_online():
		_laid_fx.rpc()
	else:
		_laid_fx()


## How many finds of `bucket` could go on the table now.
func room_for(bucket: ScrapBucket) -> int:
	return mini(free_places().size(), bucket.count - bucket.hot)


func bucket_hint(bucket: ScrapBucket) -> String:
	var n := room_for(bucket)
	if n <= 0:
		return "Verkaufstisch ist voll – die Kunden kaufen Stück für Stück" if bucket.count > bucket.hot else "Heiße Ware kauft hier keiner"
	return "[F] Die %d besten Funde auf den Verkaufstisch legen" % n if n > 1 else "[F] Den besten Fund auf den Verkaufstisch legen"


@rpc("authority", "call_local", "reliable")
func _laid_fx() -> void:
	Sfx.play(&"scrap_clatter", to_global(Vector3(0, TOP, 0)), -8.0, 0.2)


# --- The station -------------------------------------------------------------------------

func interact_point() -> Vector3:
	return to_global(Vector3(0, TOP + 0.1, 0))


func in_reach(player: Node3D) -> bool:
	return interact_point().distance_to(player.global_position + Vector3(0, 0.9, 0)) < USE_RANGE


func interact(_player: Node) -> void:
	pass


func hint(_player: Node) -> String:
	var n := goods().size()
	var keeper := HiredHand.serving_at(self)
	if n == 0:
		return "Verkaufstisch · Funde oder Gussstücke herbringen – Passanten zahlen mehr als der Händler"
	if keeper:
		return "Verkaufstisch · %d Stück liegen aus – %s bedient: Kunden nehmen bis zu %d Stück und zahlen %d %% mehr" % [
			n, keeper.info().name, KEEPER_BUYS, roundi((KEEPER_BONUS - 1.0) * 100.0)]
	return "Verkaufstisch · %d Stück liegen aus – die Kunden kommen von selbst" % n


# --- The customers ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _bubble_left > 0.0:
		_bubble_left -= delta
		if _bubble_left <= 0.0 and _bubble:
			_bubble.visible = false
	if StationKit.visual():
		_tag_in -= delta
		if _tag_in <= 0.0:
			_tag_in = 0.25
			_update_tags()
	if not Network.is_sim_authority() or walkers == null:
		return
	for i in customers.size():
		var who: Dictionary = customers[i]
		var state := walkers.standing(int(who.round))
		if int(state[0]) != int(who.stop) or float(state[1]) < LOOK_TIME or int(_laps.get(i, -1)) == int(state[2]):
			continue
		_laps[i] = int(state[2])
		_serve(i)


## Host: customer `index` has looked the table over and buys one piece, if there is one.
func _serve(index: int) -> void:
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	if world == null:
		return
	var lying := goods()
	if lying.is_empty():
		_tell(index, "Heute nichts im Angebot? Schade.", 0)
		return
	var who: Dictionary = customers[index]
	var wants_castings: bool = who.get("taste", &"finds") == &"castings"
	# Somebody who serves sells more: the customer takes a second piece, and pays more for each.
	var served := HiredHand.serving_at(self) != null
	var names := PackedStringArray()
	var total := 0
	for n in (KEEPER_BUYS if served else 1):
		if lying.is_empty():
			break
		var liked := lying.filter(func(item: Item) -> bool: return is_casting(item) == wants_castings)
		var pick: Item = (liked if not liked.is_empty() else lying)[_rng.randi() % (liked.size() if not liked.is_empty() else lying.size())]
		lying.erase(pick)
		var pay := price_now(pick)
		names.append("Das Gussstück" if is_casting(pick) else String(FoundryRules.find_info(pick.kind).get("name", "Das da")))
		var at := pick.global_position
		pick.queue_free()
		world.add_money(pay)
		world.popup_all(at + Vector3(0, 0.5, 0), "+%d $" % pay, UITheme.ACCENT)
		# A sale here counts like one at the sales crate or at the dealer: for the missions and for Onkel Heinz.
		var sale := &"sold" if is_casting(pick) else &"scrap_sold"
		Missions.report(get_tree(), &"stall_sold", 1)
		Missions.report(get_tree(), &"cast_sold" if is_casting(pick) else &"scrap_sold", 1)
		var guide := get_tree().get_first_node_in_group(&"guides") as Guide
		if guide:
			guide.note(sale)
		sold.emit(pay)
		total += pay
	var what := " und ".join(names).replace(" und Das ", " und das ")
	if names.size() == 2 and names[0] == names[1]:
		what = "Beide Gussstücke" if names[0] == "Das Gussstück" else "Zweimal %s" % names[0]
	_tell(index, "%s? Nehm ich – %d $!" % [what, total], total)


func _tell(index: int, text: String, pay: int) -> void:
	if Network.is_online():
		_said.rpc(index, text, pay)
	else:
		_said(index, text, pay)


@rpc("authority", "call_local", "reliable")
func _said(index: int, text: String, pay: int) -> void:
	if pay > 0:
		Sfx.play(&"coin", interact_point(), 0.0, 0.03)
	if _bubble == null or index < 0 or index >= customers.size():
		return
	var at: Vector3 = (customers[index] as Dictionary).get("at", global_position)
	_bubble.text = text
	_bubble.global_position = at + Vector3(0, 2.12, 0)
	_bubble.visible = true
	_bubble_left = SAY_TIME


# --- Looks -------------------------------------------------------------------------------------

## A price over every piece that lies on the table.
func _update_tags() -> void:
	var lying := goods()
	for i in _tags.size():
		var tag := _tags[i]
		if i >= lying.size():
			tag.visible = false
			continue
		var item: Item = lying[i]
		tag.visible = true
		tag.text = "%d $" % price_now(item)
		tag.global_position = item.global_position + Vector3(0, 0.26, 0)


func _build() -> void:
	# The table: a scanned farmhouse table, brought to the height of the top.
	var box := PhotoProp.box("painted_wooden_table")
	var fit := TOP / maxf(box.size.y, 0.01)
	PhotoProp.stand(self, "painted_wooden_table", Vector3.ZERO, 0.0, fit)
	for i in COLS * ROWS:
		var tag := StationKit.label(self, "", Transform3D(), 44, Color("#fff3d0"), 700, 0.0011)
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.outline_size = 10
		tag.outline_modulate = Color(0.1, 0.08, 0.05, 0.9)
		tag.top_level = true
		tag.visible = false
		_tags.append(tag)
	_bubble = StationKit.label(self, "", Transform3D(), 52, Color("#fff8e6"), 600, 0.0016)
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.outline_size = 14
	_bubble.outline_modulate = Color(0.08, 0.07, 0.05, 0.92)
	_bubble.top_level = true
	_bubble.visible = false
	_parasol(Vector3(0.0, 0, -SIZE.y * 0.5 - 0.28))
	# The board at the table's end, turned to the street: what this is.
	var board := Vector3(SIZE.x * 0.5 + 0.75, 0, 0.3)
	PhotoProp.stand(self, "standing_chalkboard_01", board, 20.0)
	var face := Transform3D(Basis(Vector3.UP, deg_to_rad(20.0)), board) * Transform3D(Basis(Vector3.RIGHT, -0.21), Vector3(0.0, 0.88, 0.188))
	var chalk := Color(0.93, 0.92, 0.87, 0.92)
	# (Two lines: in one the words were wider than the slate, and the frame hid their ends.)
	StationKit.label(self, "YARD", face * Transform3D(Basis(), Vector3(0, 0.36, 0)), 104, Color(0.95, 0.82, 0.4, 0.92), 700, 0.0022, StationKit.chalk_font())
	StationKit.label(self, "SALE", face * Transform3D(Basis(), Vector3(0, 0.16, 0)), 104, Color(0.95, 0.82, 0.4, 0.92), 700, 0.0022, StationKit.chalk_font())
	StationKit.label(self, "finds & castings", face * Transform3D(Basis(), Vector3(0, -0.07, 0)), 54, chalk, 500, 0.0022, StationKit.hand_font())
	StationKit.label(self, "from the heap", face * Transform3D(Basis(), Vector3(0, -0.27, 0)), 56, chalk, 500, 0.0022, StationKit.hand_font())
	# A crate and a basket under the table, for what is not laid out yet.
	PhotoProp.stand(self, "wooden_crate_01", Vector3(-0.5, 0, 0.0), 12.0, 0.55)
	PhotoProp.stand(self, "wicker_basket_01", Vector3(0.45, 0, 0.05), -8.0, 1.0)
	PhotoProp.stand(self, "folding_wooden_stool", Vector3(0.95, 0, -SIZE.y * 0.5 - 0.55), 25.0)


## A market parasol behind the table: a pole in a concrete foot and eight gores of cloth, green and cream.
func _parasol(at: Vector3) -> void:
	var steel := StationKit.metal("stall_pole", {steel_color = Color("#8b8f92"), rust = 0.12, metallic_steel = 0.8, roughness_steel = 0.45})
	var foot := EnvMesh.scan("stall_foot", "dirty_concrete", {tile = 1.2})
	var top := 2.62
	var rim := 2.18
	var reach := 1.55
	StationKit.add(self, EnvMesh.cylinder(0.021, 0.021, top, 10), steel, Transform3D(Basis(), at + Vector3(0, top * 0.5, 0)))
	StationKit.add(self, EnvMesh.cylinder(0.2, 0.24, 0.12, 14), foot, Transform3D(Basis(), at + Vector3(0, 0.06, 0)))
	StationKit.box_collider(self, Vector3(0.3, 1.2, 0.3), Transform3D(Basis(), at + Vector3(0, 0.6, 0)))
	var tones: Array[Color] = [Color("#2f5a43"), Color("#e9e0c8")]
	var cloths: Array[SurfaceTool] = []
	for tone in tones:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		cloths.append(st)
	var ribs := []
	for i in 8:
		var a0 := i / 8.0 * TAU
		var a1 := (i + 1) / 8.0 * TAU
		var apex := at + Vector3(0, top - 0.04, 0)
		var p0 := at + Vector3(cos(a0) * reach, rim, sin(a0) * reach)
		var p1 := at + Vector3(cos(a1) * reach, rim, sin(a1) * reach)
		# The cloth sags a little between two ribs.
		var mid := (p0 + p1) * 0.5 + Vector3(0, -0.05, 0)
		var st := cloths[i % 2]
		for tri: Array in [[apex, p0, mid], [apex, mid, p1], [p0, p0 + Vector3(0, -0.14, 0), mid + Vector3(0, -0.14, 0)], [p0, mid + Vector3(0, -0.14, 0), mid],
				[mid, mid + Vector3(0, -0.14, 0), p1 + Vector3(0, -0.14, 0)], [mid, p1 + Vector3(0, -0.14, 0), p1]]:
			var normal := ((tri[2] as Vector3) - (tri[0] as Vector3)).cross((tri[1] as Vector3) - (tri[0] as Vector3)).normalized()
			for corner: Vector3 in tri:
				st.set_normal(normal)
				st.add_vertex(corner)
		ribs.append(EnvMesh.piece(EnvMesh.cylinder(0.006, 0.006, apex.distance_to(p0), 5),
			Transform3D(StationKit.basis_y((p0 - apex).normalized()), (apex + p0) * 0.5 + Vector3(0, -0.012, 0))))
	for i in tones.size():
		var cloth := StandardMaterial3D.new()
		cloth.albedo_color = tones[i]
		cloth.roughness = 0.95
		cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
		StationKit.add(self, cloths[i].commit(), cloth)
	StationKit.add(self, EnvMesh.merge(ribs), steel, Transform3D(), false)
