class_name HiredHand
extends CharacterBody3D
## Somebody the crew hires at the labour exchange (stage U15): three people wait there, each for one
## kind of work in the scrap yard, the step between doing everything by hand and the machines.
##   The digger (Hugo) digs at the scrap heap into a bucket that stands by it.
##   The runner (Ede) empties the bucket in the hall and carries the load across the street to the
##   scrap dealer; what is rare he lays on the crew's stall, if there is room. Once the crew has its
##   foundry corner he takes only the junk: the metal stays in the bucket for the furnace.
##   The stall keeper (Rosa) serves at the crew's stall: customers take more per visit and pay more
##   (YardStall), and she lays out the best finds from a bucket set down beside the table.
## [F] at one of them in the labour exchange hires: a fee at once, then a wage for every minute at
## work. [F] twice sends the hand home ([F] on its way home calls it back, without a new fee).
## Without money for the wage a hand stops and waits; there is never a debt. Who is hired is saved
## with the game.
## The host decides and moves them; the others get place, state and what the hand is doing ten times
## a second (like PolicePatrol). Cars and the truck stop for them (they are in TownWalkers.GROUP),
## and they wait at the kerb for a gap in the traffic. Who meets somebody head-on (another hand, the
## patrol, a worker in the way) takes a step to the right and walks round.
## Comparison pictures: Supermarket Simulator (staff at their places, a card with name, job and
## wage), Schedule I (employees at their stations).

const GROUP := &"hired_hands"

enum State {WAITING, COMING, WORKING, UNPAID, LEAVING}
## What a hand at work is doing right now (said in its hint; the other players get it too).
enum Note {NONE, DIGGING, NO_BUCKET, BUCKET_FULL, HEAP_EMPTY, RESTING, FETCHING, TO_STALL, TO_DEALER, RETURNING, SERVING}
## The runner's round.
enum Task {REST, TO_BUCKET, LOAD, TO_STALL, LAY, TO_DEALER, SELL, BACK}

## Who can be hired: name, job (and what the board in the exchange calls it), the figure, the fee paid
## at once and the wage per minute at work ($), and what the hand does.
const ROLES := {
	&"digger": {name = "Hugo", job = "Wühler", board = "digger", body = "hugo", fee = 60, wage = 8,
		does = "wühlt am Schrottberg in den Eimer daneben"},
	&"runner": {name = "Ede", job = "Träger", board = "runner", body = "ede", fee = 80, wage = 8,
		does = "trägt, was im Eimer liegt, zum Scrap Dealer"},
	&"keeper": {name = "Rosa", job = "Verkäuferin", board = "stall keeper", body = "rosa", fee = 100, wage = 10,
		does = "bedient am Verkaufstisch – Kunden kaufen mehr und zahlen besser"},
}
const ORDER: Array[StringName] = [&"digger", &"runner", &"keeper"]
## Walking at work and on the way home, and hurrying to work after being hired (m/s).
const WALK := 1.7
const HURRY := 2.7
## The wage falls due after every so many seconds at work.
const WAGE_EVERY := 60.0
## The digger: one find every so many seconds; a bucket counts as standing by the heap up to this far
## from its foot (m).
const DIG_EVERY := 3.6
const BUCKET_REACH := 3.4
## The runner: he comes for a bucket that holds so many pieces he takes (or is full); taking the load
## out, handing it over the dealer's counter and laying finds on the stall take this long (s).
const FETCH_AT := 8
const LOAD_TIME := 1.1
const SELL_TIME := 1.2
const LAY_TIME := 0.9
## The stall keeper: a bucket within this distance of the table is hers (the runner leaves it alone);
## she lays one find out of it every so many seconds.
const STALL_REACH := 3.5
const RESTOCK_EVERY := 2.5
## At a kerb a hand waits at most this long for the cars (s).
const KERB_PATIENCE := 12.0
## A point of a way counts as passed within this distance; where a hand is to stand, it stands this
## near (m).
const ARRIVE := 0.3
const NEAR := 0.1
## The second press of [F] that sends a hand home has to come within this time (s).
const CONFIRM := 1.6
## Height of the face (where one looks to mean the hand) and of the name over the head (m).
const HEAD := 1.5
const TAG := 2.02
## The runner's crate: the middle of its foot in front of him, and its width (m).
const CRATE_AT := Vector3(0, 0.86, 0.5)
const CRATE_W := 0.46

signal changed

## The roles that were hired when the crew was last in the scrap hall. In a hall without hands the
## save file keeps this list, so nobody is forgotten while the crew works elsewhere.
static var pay_roll: Array = []

## Which of ROLES this is.
var role := &"digger"
## Where the hand waits to be hired, and the way it looks there (degrees).
var home := Vector3.ZERO
var home_yaw := 0.0
## The way from there to the yard: points in walking order. `roads`: index of a point -> where the
## cars come from on the stretch between that point and the next (it crosses a road).
var way: Array[Vector3] = []
var roads := {}
## Where the hand stands at work when there is nothing to do, and the way it looks there (degrees).
var post := Vector3.ZERO
var post_yaw := 0.0
## The runner's way from the yard to the dealer's counter (`trip_roads` like `roads`), and the
## ground (x and z) on which he looks after the buckets: the hall and its apron.
var trip: Array[Vector3] = []
var trip_roads := {}
var yard := Rect2()

var state := State.WAITING
var note := Note.NONE
## Art checks: the hand does nothing but show itself as it is set (place, speed, what it carries).
var pose_only := false
## What shows: digging with the bare hands, the crate in the hands and how many pieces lie in it,
## serving at the stall.
var digging := false
var carrying := false
var serving := false
var loaded := 0

var _task := Task.REST
var _path: Array[Vector3] = []
## Per point of the path: where the cars come from on the stretch that ends there (ZERO: no road).
var _cross: Array[Vector3] = []
var _at := 0
var _leg_time := 0.0
var _leg_limit := 0.0
var _kerb_wait := 0.0
var _on_road := false
var _reach_goal := Vector3.INF
var _reach_time := 0.0
## The nearest the hand has come to that goal, and for how long it has come no nearer.
var _reach_best := 0.0
var _stuck := 0.0
## Walking: for how long the legs have moved without the hand getting on, and how much longer it
## steps aside to the right (s).
var _held := 0.0
var _dodge := 0.0
var _wage_left := 0.0
var _confirm := 0.0
var _timer := 0.0
var _look_in := 0.0
var _dig_left := DIG_EVERY
var _restock_in := RESTOCK_EVERY
var _bucket: ScrapBucket
var _load: Array[StringName] = []
var _for_stall: Array[StringName] = []
var _net_accum := 0.0
var _net_pos := Vector3.ZERO
var _net_vel := Vector3.ZERO
var _model: PlayerModel
var _crate: Node3D
var _crate_load: Node3D
var _crate_half := CRATE_W * 0.5
var _crate_top := 0.3
var _tag: Label3D
var _tag_text := ""
## The frame in which the local worker last looked at the hand: the hint then says what the name tag
## says.
var _hinted_at := -100


# --- Who is who ---------------------------------------------------------------------------------

## The entry of ROLES this hand is.
func info() -> Dictionary:
	return ROLES[role]


## Whether the crew employs the hand right now (also on its way to work).
func hired() -> bool:
	return state == State.COMING or state == State.WORKING or state == State.UNPAID


## The hand of `role_name` in this level (null: there is none).
static func of(tree: SceneTree, role_name: StringName) -> HiredHand:
	for node in tree.get_nodes_in_group(GROUP):
		if (node as HiredHand).role == role_name:
			return node as HiredHand
	return null


## The stall keeper who serves at `stall` right now (null: nobody does).
static func serving_at(stall: Node) -> HiredHand:
	if stall == null or not stall.is_inside_tree():
		return null
	for node in stall.get_tree().get_nodes_in_group(GROUP):
		var hand := node as HiredHand
		if hand.role == &"keeper" and hand.serving:
			return hand
	return null


## How many hands the crew employs.
static func count(tree: SceneTree) -> int:
	var n := 0
	for node in tree.get_nodes_in_group(GROUP):
		if (node as HiredHand).hired():
			n += 1
	return n


## For the save file: the roles that are hired. (In a hall without hands: those hired when the crew
## left the scrap hall.)
static func to_save(tree: SceneTree) -> Array:
	var hands := tree.get_nodes_in_group(GROUP)
	if hands.is_empty():
		return pay_roll.duplicate()
	var out := []
	for node in hands:
		if (node as HiredHand).hired():
			out.append(String((node as HiredHand).role))
	pay_roll = out.duplicate()
	return out


## Host: the hands named in a save file stand at their work again (no fee, a fresh minute of wage).
static func load_save(tree: SceneTree, v: Variant) -> void:
	if typeof(v) != TYPE_ARRAY or not Network.is_sim_authority():
		return
	pay_roll = (v as Array).duplicate()
	for node in tree.get_nodes_in_group(GROUP):
		var hand := node as HiredHand
		if String(hand.role) in (v as Array) and not hand.hired():
			hand.start_at_work()


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(&"interactable")
	# Cars and the scrap truck stop for the hands as they do for the townspeople.
	add_to_group(TownWalkers.GROUP)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.7
	shape.shape = capsule
	shape.position.y = 0.85
	add_child(shape)
	floor_snap_length = 0.3
	global_position = home
	rotation.y = deg_to_rad(home_yaw)
	_net_pos = global_position
	if StationKit.visual():
		_build()


# --- Hiring and sending home ----------------------------------------------------------------------

func interact_point() -> Vector3:
	return global_position + Vector3(0, HEAD, 0)


## A Suchauftrag hides its find beside a hand only where it waits to be hired: never beside one that
## walks the streets or works.
func hunt_spot_ok(_at: Vector3) -> bool:
	return state == State.WAITING


func hint(player: Node) -> String:
	if player is Player and (player as Player).is_local():
		_hinted_at = Engine.get_process_frames()
	var who := info()
	var world := _world()
	var money := world.money if world else 0
	match state:
		State.WAITING:
			if money < int(who.fee):
				return "%s · %s: %s · Handgeld %d $ (euch fehlen %d $), dann %d $ pro Minute" % [
					who.name, who.job, who.does, who.fee, int(who.fee) - money, who.wage]
			return "[F] %s anheuern · %s: %s · %d $ Handgeld, dann %d $ pro Minute" % [who.name, who.job, who.does, who.fee, who.wage]
		State.COMING:
			return "%s ist auf dem Weg zu eurer Halle · [F] zweimal: wieder wegschicken" % who.name
		State.LEAVING:
			return "%s geht zurück zur Labour Exchange · [F] zurückrufen (kein neues Handgeld)" % who.name
		State.UNPAID:
			return "%s wartet auf den Lohn (%d $) – sobald das Geld da ist, geht es weiter · [F] zweimal: entlassen" % [who.name, who.wage]
	return "%s · %s · %s · %d $ pro Minute · [F] zweimal: entlassen" % [who.name, who.job, _note_text(), who.wage]


## What the hand is doing, in words.
func _note_text() -> String:
	match note:
		Note.DIGGING:
			return "wühlt in den Eimer"
		Note.NO_BUCKET:
			return "wartet: Eimer an den Schrottberg stellen"
		Note.BUCKET_FULL:
			return "wartet: Der Eimer ist voll"
		Note.HEAP_EMPTY:
			return "wartet auf die nächste Ladung Schrott"
		Note.RESTING:
			var world := _world()
			if world and world.has_upgrade(&"foundry_corner"):
				return "wartet, bis im Eimer %d Teile Krempel liegen (Metall bleibt für den Ofen)" % FETCH_AT
			return "wartet, bis im Eimer %d Teile liegen" % FETCH_AT
		Note.FETCHING:
			return "holt, was im Eimer liegt"
		Note.TO_STALL:
			return "legt Seltenes auf den Verkaufstisch"
		Note.TO_DEALER:
			return "trägt %d Teile zum Scrap Dealer" % loaded
		Note.RETURNING:
			return "kommt vom Scrap Dealer zurück"
		Note.SERVING:
			return "bedient am Verkaufstisch (Kunden nehmen %d Stück, +%d %%)" % [YardStall.KEEPER_BUYS, roundi((YardStall.KEEPER_BONUS - 1.0) * 100.0)]
	return info().does


## [F]: hire the hand where it waits; at work, a second press within a moment sends it home.
func interact(_player: Node) -> void:
	if not Network.is_sim_authority():
		return
	var world := _world()
	if world == null:
		return
	var who := info()
	match state:
		State.WAITING:
			if world.money < int(who.fee):
				world.popup_all(_head(), "Handgeld: %d $" % who.fee, UITheme.BAD)
				return
			world.add_money(-int(who.fee))
			hire()
		State.COMING, State.WORKING, State.UNPAID:
			if _confirm > 0.0:
				dismiss()
			else:
				_confirm = CONFIRM
				world.popup_all(_head(), "Nochmal F: %s geht nach Hause" % who.name, UITheme.INFO)
		State.LEAVING:
			recall()


## Host: the hand is hired and sets off for the yard (the fee is the caller's business).
func hire() -> void:
	if not Network.is_sim_authority() or state != State.WAITING:
		return
	state = State.COMING
	_confirm = 0.0
	_task = Task.REST
	_wage_left = WAGE_EVERY
	_path_there(way, roads)
	var world := _world()
	if world:
		world.popup_all(_head(), "%s: „Bin dabei, Chef!“" % info().name, UITheme.GOOD)
	var guide := get_tree().get_first_node_in_group(&"guides") as Guide
	if guide:
		guide.note(&"hired")
	_act(&"cheer")
	changed.emit()


## Host: the hand goes home. What the runner still carries is paid for at the dealer's price.
func dismiss() -> void:
	if not Network.is_sim_authority() or not hired():
		return
	var world := _world()
	var pay := 0
	for kind in _load:
		pay += FoundryRules.raw_price(kind)
	if world and pay > 0:
		world.add_money(pay)
		world.popup_all(_head() + Vector3(0, 0.3, 0), "+%d $ · %s rechnet ab" % [pay, info().name], UITheme.ACCENT)
	if world:
		world.popup_all(_head(), "%s: „Schönen Feierabend!“" % info().name, UITheme.INFO)
	_drop_work()
	state = State.LEAVING
	_confirm = 0.0
	# Back the way it came, from the point of that way that is nearest.
	var nearest := 0
	for i in way.size():
		if way[i].distance_squared_to(global_position) < way[nearest].distance_squared_to(global_position):
			nearest = i
	_path_back(way, roads, nearest, home)
	changed.emit()


## Host: a hand on its way home is called back and returns to work; that costs no new fee.
func recall() -> void:
	if not Network.is_sim_authority() or state != State.LEAVING:
		return
	state = State.COMING
	_confirm = 0.0
	# On along the way to the yard, from the point of it that is nearest.
	var nearest := 0
	for i in way.size():
		if way[i].distance_squared_to(global_position) < way[nearest].distance_squared_to(global_position):
			nearest = i
	_path.clear()
	_cross.clear()
	for i in range(nearest, way.size()):
		_path.append(way[i])
		_cross.append(roads.get(i - 1, Vector3.ZERO) if i > nearest else Vector3.ZERO)
	_start_path()
	var world := _world()
	if world:
		world.popup_all(_head(), "%s: „Na gut, ich komme.“" % info().name, UITheme.GOOD)
	changed.emit()


## Host: the hand stands at its work at once (a saved game goes on; tests).
func start_at_work() -> void:
	if not Network.is_sim_authority():
		return
	_drop_work()
	state = State.WORKING
	_wage_left = WAGE_EVERY
	_path.clear()
	_at = 0
	global_position = post + Vector3(0, 0.05, 0)
	rotation.y = deg_to_rad(post_yaw)
	velocity = Vector3.ZERO
	changed.emit()


func _drop_work() -> void:
	_load.clear()
	_for_stall.clear()
	_bucket = null
	loaded = 0
	carrying = false
	digging = false
	serving = false
	note = Note.NONE
	_task = Task.REST
	_reach_goal = Vector3.INF


# --- Every frame ----------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if pose_only:
		_show(delta)
		return
	if Network.is_sim_authority():
		_think(delta)
		if not is_on_floor():
			velocity.y -= 20.0 * delta
		else:
			velocity.y = -1.0
		move_and_slide()
		if Network.is_online():
			_net_accum += delta
			# (Somebody who stands still is told twice a second.)
			var busy := Vector2(velocity.x, velocity.z).length_squared() > 0.01 or digging
			if _net_accum > (0.1 if busy else 0.5):
				_net_accum = 0.0
				_sync.rpc(global_position, rotation.y, velocity, state, note, (1 if digging else 0) | (2 if carrying else 0) | (4 if serving else 0), loaded)
	else:
		_net_pos += _net_vel * delta
		global_position = global_position.lerp(_net_pos, 1.0 - exp(-12.0 * delta))
	_show(delta)


@rpc("authority", "call_remote", "unreliable_ordered")
func _sync(pos: Vector3, yaw: float, vel: Vector3, s: int, what: int, flags: int, pieces: int) -> void:
	_net_pos = pos
	_net_vel = Vector3(vel.x, 0.0, vel.z)
	rotation.y = yaw
	# (Far from where the host has it, as for somebody who has just joined: there at once.)
	if global_position.distance_to(pos) > 6.0:
		global_position = pos
	state = s as State
	note = what as Note
	digging = flags & 1 != 0
	carrying = flags & 2 != 0
	serving = flags & 4 != 0
	loaded = pieces


func _think(delta: float) -> void:
	_confirm = maxf(0.0, _confirm - delta)
	match state:
		State.WAITING:
			_stand(delta, home, home_yaw)
		State.COMING:
			if _walk(delta, HURRY):
				state = State.WORKING
				_task = Task.REST
				_wage_left = WAGE_EVERY
				_reach_goal = Vector3.INF
		State.LEAVING:
			if _walk(delta, WALK):
				state = State.WAITING
				_reach_goal = Vector3.INF
		State.WORKING, State.UNPAID:
			_wage(delta)
			if state == State.UNPAID:
				_halt()
			elif role == &"digger":
				_dig(delta)
			elif role == &"runner":
				_run(delta)
			else:
				_keep(delta)


## The wage: due after every minute at work. Without the money the hand stops (the runner first
## finishes his round) and takes it as soon as it is there.
func _wage(delta: float) -> void:
	_wage_left -= delta
	if _wage_left > 0.0:
		return
	_wage_left = 0.0
	var world := _world()
	if world == null:
		return
	var wage: int = info().wage
	if world.money >= wage:
		world.add_money(-wage)
		_wage_left = WAGE_EVERY
		world.popup_all(_head(), "−%d $ Lohn · %s" % [wage, info().name], UITheme.MUTED)
		Missions.report(get_tree(), &"wage", 1)
		if state == State.UNPAID:
			state = State.WORKING
			changed.emit()
	elif state == State.WORKING and (role != &"runner" or _task == Task.REST):
		state = State.UNPAID
		digging = false
		serving = false
		world.popup_all(_head(), "%s: „Erst mein Lohn!“ (%d $)" % [info().name, wage], UITheme.BAD)
		changed.emit()


# --- The digger -------------------------------------------------------------------------------------

func _dig(delta: float) -> void:
	digging = false
	var heap := get_tree().get_first_node_in_group(&"scrap_piles") as ScrapPile
	if heap == null or heap.stock <= 0:
		note = Note.HEAP_EMPTY
		_stand(delta, post, post_yaw)
		return
	var bucket := _dig_bucket(heap)
	if bucket == null:
		_stand(delta, post, post_yaw)
		return
	if not _reach(delta, _dig_place(heap, bucket), WALK):
		note = Note.DIGGING
		return
	var to := heap.centre() - global_position
	rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), minf(delta * 6.0, 1.0))
	digging = true
	note = Note.DIGGING
	_dig_left -= delta
	if _dig_left <= 0.0:
		_dig_left = DIG_EVERY
		heap.dig_into(bucket, global_position + Vector3(0, 0.8, 0))


## The bucket the digger fills: the one nearest the heap that stands by it, has room and is in
## nobody's hands. Sets `note` to why there is none.
func _dig_bucket(heap: ScrapPile) -> ScrapBucket:
	var best: ScrapBucket = null
	var best_d := heap.foot() + BUCKET_REACH
	note = Note.NO_BUCKET
	for node in get_tree().get_nodes_in_group(&"scrap_buckets"):
		var b := node as ScrapBucket
		var d := _flat(b.global_position - heap.centre()).length()
		if b.is_held() or d > heap.foot() + BUCKET_REACH:
			continue
		if b.is_full():
			note = Note.BUCKET_FULL
		elif d < best_d:
			best_d = d
			best = b
	return best


## Where the digger stands: at the heap's foot on the side of `bucket`, a step along the foot if the
## bucket itself stands there.
func _dig_place(heap: ScrapPile, bucket: ScrapBucket) -> Vector3:
	var middle := heap.centre()
	var out := _flat(bucket.global_position - middle)
	out = out.normalized() if out.length() > 0.1 else Vector3.RIGHT
	var reach := heap.foot() + 0.5
	var place := middle + out * reach
	if _flat(bucket.global_position - place).length() < 0.95:
		place = middle + out.rotated(Vector3.UP, 1.0 / maxf(reach, 1.0)) * reach
	return Vector3(place.x, 0.0, place.z)


# --- The runner -------------------------------------------------------------------------------------

func _run(delta: float) -> void:
	match _task:
		Task.REST:
			carrying = false
			note = Note.RESTING
			_look_in -= delta
			if _look_in <= 0.0:
				_look_in = 1.0
				_bucket = _bucket_to_empty()
				if _bucket:
					_task = Task.TO_BUCKET
					return
			_stand(delta, post, post_yaw)
		Task.TO_BUCKET:
			note = Note.FETCHING
			if not _bucket_there(_bucket):
				_task = Task.REST
				return
			var away := _flat(global_position - _bucket.global_position)
			var spot := _bucket.global_position + (away.normalized() if away.length() > 0.1 else Vector3.BACK) * 0.85
			if _reach(delta, Vector3(spot.x, 0.0, spot.z), WALK):
				_task = Task.LOAD
				_timer = LOAD_TIME
				_act(&"pickup")
		Task.LOAD:
			_halt()
			_timer -= delta
			if _timer > 0.0:
				return
			# (Somebody may have walked off with the bucket meanwhile.)
			if not _bucket_there(_bucket) or _flat(_bucket.global_position - global_position).length() > 2.0:
				_task = Task.REST
				return
			_load = _bucket.take_where(_takes)
			_bucket = null
			if _load.is_empty():
				_task = Task.REST
				return
			carrying = true
			loaded = _load.size()
			# What is rare goes on the crew's stall, as far as there is room; the rest to the dealer.
			_for_stall.clear()
			var stall := _stall()
			var room := stall.free_places().size() if stall else 0
			for kind in _load:
				if ScrapPile.RARE.has(kind) and _for_stall.size() < room:
					_for_stall.append(kind)
			if _for_stall.is_empty():
				_set_off_to_dealer()
			else:
				_task = Task.TO_STALL
		Task.TO_STALL:
			note = Note.TO_STALL
			var stall := _stall()
			if stall == null:
				_set_off_to_dealer()
			elif _reach(delta, stall.to_global(Vector3(-YardStall.SIZE.x * 0.5 - 0.6, 0, 0.15)), WALK):
				_task = Task.LAY
				_timer = LAY_TIME
				_act(&"use")
		Task.LAY:
			_halt()
			var stall := _stall()
			if stall:
				var to := stall.global_position - global_position
				rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), minf(delta * 6.0, 1.0))
			_timer -= delta
			if _timer > 0.0:
				return
			if stall:
				for kind in stall.lay_kinds(_for_stall):
					_for_stall.erase(kind)
				for kind in _for_stall:
					_load.erase(kind)
			_for_stall.clear()
			loaded = _load.size()
			if _load.is_empty():
				carrying = false
				_task = Task.REST
			else:
				_set_off_to_dealer()
		Task.TO_DEALER:
			note = Note.TO_DEALER
			if _walk(delta, WALK):
				_task = Task.SELL
				_timer = SELL_TIME
				_act(&"use")
		Task.SELL:
			_halt()
			# (The counter lies beyond the street, to the north.)
			rotation.y = lerp_angle(rotation.y, 0.0, minf(delta * 6.0, 1.0))
			_timer -= delta
			if _timer > 0.0:
				return
			var shop := get_tree().get_first_node_in_group(&"scrap_shops") as ScrapShop
			if shop:
				shop.buy_kinds(_load, info().name)
			_load.clear()
			loaded = 0
			_path_back(trip, trip_roads, trip.size() - 2, post)
			_task = Task.BACK
		Task.BACK:
			note = Note.RETURNING
			if _walk(delta, WALK):
				carrying = false
				_task = Task.REST


func _set_off_to_dealer() -> void:
	_path_there(trip, trip_roads)
	_task = Task.TO_DEALER


## What the runner takes out of a bucket: no hot goods, and once the crew melts its own metal only
## the junk.
func _takes(kind: StringName) -> bool:
	if FoundryRules.is_hot(kind) or FoundryRules.raw_price(kind) <= 0:
		return false
	var world := _world()
	return FoundryRules.JUNK.has(kind) or not (world and world.has_upgrade(&"foundry_corner"))


## Whether `bucket` still stands where the runner can take from it.
func _bucket_there(bucket: ScrapBucket) -> bool:
	return is_instance_valid(bucket) and not bucket.is_queued_for_deletion() and not bucket.is_held()


## A bucket in the yard that is worth a trip: it holds FETCH_AT pieces the runner takes, or it is
## full and holds at least one. Not the one that stands by the stall (the stall keeper's).
func _bucket_to_empty() -> ScrapBucket:
	var stall := _stall()
	for node in get_tree().get_nodes_in_group(&"scrap_buckets"):
		var b := node as ScrapBucket
		var at := b.global_position
		if b.is_held() or not yard.has_point(Vector2(at.x, at.z)):
			continue
		if stall and _flat(at - stall.global_position).length() < STALL_REACH:
			continue
		var mine := 0
		for kind in b.contents:
			if _takes(kind):
				mine += 1
		if mine >= mini(FETCH_AT, b.capacity()) or (b.is_full() and mine > 0):
			return b
	return null


# --- The stall keeper --------------------------------------------------------------------------------

func _keep(delta: float) -> void:
	note = Note.SERVING
	var stall := _stall()
	if stall == null:
		serving = false
		_stand(delta, post, post_yaw)
		return
	# Behind the table, beside the parasol's pole, looking at the customers.
	var place := stall.to_global(Vector3(0.62, 0, -YardStall.SIZE.y * 0.5 - 0.42))
	if not _reach(delta, Vector3(place.x, 0.0, place.z), WALK):
		serving = false
		return
	var front := stall.global_transform.basis.z
	rotation.y = lerp_angle(rotation.y, atan2(front.x, front.z), minf(delta * 6.0, 1.0))
	if not serving:
		serving = true
		if not stall.sold.is_connected(_on_stall_sold):
			stall.sold.connect(_on_stall_sold)
	# A bucket set down beside the table: she lays out the best of it, piece by piece.
	_restock_in -= delta
	if _restock_in <= 0.0:
		_restock_in = RESTOCK_EVERY
		for node in get_tree().get_nodes_in_group(&"scrap_buckets"):
			var b := node as ScrapBucket
			if b.is_held() or _flat(b.global_position - stall.global_position).length() > STALL_REACH:
				continue
			if stall.lay_out(b, 1) > 0:
				_act(&"interact")
				break


func _on_stall_sold(_pay: int) -> void:
	if serving and state == State.WORKING:
		_act(&"interact")


# --- Walking ---------------------------------------------------------------------------------------

## The path along `points` from the first to the last; `crossings` as in `roads`.
func _path_there(points: Array[Vector3], crossings: Dictionary) -> void:
	_path.clear()
	_cross.clear()
	for i in points.size():
		_path.append(points[i])
		_cross.append(crossings.get(i - 1, Vector3.ZERO))
	_start_path()


## The path back along `points` from point `from` to the first, and on to `then`.
func _path_back(points: Array[Vector3], crossings: Dictionary, from: int, then: Vector3) -> void:
	_path.clear()
	_cross.clear()
	for i in range(mini(from, points.size() - 1), -1, -1):
		_path.append(points[i])
		_cross.append(crossings.get(i, Vector3.ZERO) if i < from else Vector3.ZERO)
	_path.append(then)
	_cross.append(Vector3.ZERO)
	_start_path()


func _start_path() -> void:
	_at = 0
	_leg_time = 0.0
	_kerb_wait = 0.0
	_on_road = false


## Follows the path; true once its end is reached.
func _walk(delta: float, speed: float) -> bool:
	if _at >= _path.size():
		_halt()
		return true
	var goal := _path[_at]
	var to := _flat(goal - global_position)
	var dist := to.length()
	if dist < ARRIVE:
		_next_leg()
		return _at >= _path.size()
	# At the kerb: wait for a gap in the traffic (not for ever: cars stop for people on the road).
	if _cross[_at] != Vector3.ZERO and not _on_road:
		if _kerb_wait < KERB_PATIENCE and not _road_clear((global_position + goal) * 0.5, _cross[_at]):
			_kerb_wait += delta
			_halt()
			rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), minf(delta * 6.0, 1.0))
			return false
		_on_road = true
	if _leg_time == 0.0:
		_leg_limit = dist / maxf(speed, 0.1) * 2.5 + 6.0
	_leg_time += delta
	if _leg_time > _leg_limit:
		# Held up for good (somebody stands in a doorway): through.
		global_position = Vector3(goal.x, global_position.y, goal.z)
		_next_leg()
		return _at >= _path.size()
	_step(to / dist, speed, delta)
	return false


func _next_leg() -> void:
	_at += 1
	_leg_time = 0.0
	_kerb_wait = 0.0
	_on_road = false


## Whether no car and no truck is on its way across the middle of a crossing at `mid`, where they
## come from the direction `from`.
func _road_clear(mid: Vector3, from: Vector3) -> bool:
	for node in get_tree().get_nodes_in_group(TownTraffic.CAR_GROUP):
		if _in_the_way((node as Node3D).global_position - mid, from, 2.6, 15.0):
			return false
	for node in get_tree().get_nodes_in_group(ScrapTruck.GROUP):
		var truck := node as ScrapTruck
		if truck.busy() and truck.visible and _in_the_way(truck.global_position - mid, from, 3.4, 18.0):
			return false
	return true


## Whether something at `rel` (from the middle of a crossing) is on the lane across it, up to `reach`
## metres before it or just past it. `from`: where it comes from.
static func _in_the_way(rel: Vector3, from: Vector3, side: float, reach: float) -> bool:
	rel.y = 0.0
	var along := rel.dot(from)
	return along > -4.0 and along < reach and (rel - from * along).length() < side


## Walks straight to `goal`; true once the hand stands there (or as near as somebody in the way
## lets it come).
func _reach(delta: float, goal: Vector3, speed: float) -> bool:
	var to := _flat(goal - global_position)
	var dist := to.length()
	if _reach_goal == Vector3.INF or _flat(goal - _reach_goal).length() > 0.6:
		_reach_goal = goal
		_reach_time = 0.0
		_reach_best = dist
		_stuck = 0.0
	if dist < NEAR:
		_reach_best = dist
		_stuck = 0.0
		_halt()
		return true
	# Somebody stands in the way and the hand has come no nearer for a while: near enough.
	if _stuck > 1.5 and dist < 1.0:
		_halt()
		return true
	if dist < _reach_best - 0.02:
		_reach_best = dist
		_stuck = 0.0
	else:
		_stuck += delta
	_reach_time += delta
	if _stuck > 6.0 or _reach_time > 60.0:
		# Shut in behind something: a step through it.
		global_position = Vector3(goal.x, global_position.y, goal.z)
		_reach_best = 0.0
		_stuck = 0.0
		_halt()
		return true
	_step(to / dist, speed, delta)
	return false


## Goes to `at` and stands there, looking `yaw` degrees. True once there.
func _stand(delta: float, at: Vector3, yaw: float) -> bool:
	if not _reach(delta, at, WALK):
		return false
	rotation.y = lerp_angle(rotation.y, deg_to_rad(yaw), minf(delta * 6.0, 1.0))
	return true


func _step(dir: Vector3, speed: float, delta: float) -> void:
	# Held up by somebody who stands or comes straight at the hand: a step to the right, round them.
	if _flat(get_real_velocity()).length() < speed * 0.3:
		_held += delta
	else:
		_held = maxf(0.0, _held - delta * 2.0)
	if _held > 0.35:
		_held = 0.0
		_dodge = 0.7
	var go := dir
	if _dodge > 0.0:
		_dodge -= delta
		go = (dir + dir.cross(Vector3.UP) * 1.2).normalized()
	velocity.x = go.x * speed
	velocity.z = go.z * speed
	rotation.y = lerp_angle(rotation.y, atan2(go.x, go.z), minf(delta * 8.0, 1.0))


func _halt() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _world() -> GameWorld:
	return get_tree().get_first_node_in_group(&"world") as GameWorld


func _stall() -> YardStall:
	return get_tree().get_first_node_in_group(YardStall.GROUP) as YardStall


func _head() -> Vector3:
	return global_position + Vector3(0, TAG + 0.15, 0)


# --- What shows -----------------------------------------------------------------------------------

## A short move of the body (PlayerModel.ACTIONS), on every machine.
func _act(action: StringName) -> void:
	_show_act(action)
	if Network.is_online() and multiplayer.is_server():
		_act_remote.rpc(action)


@rpc("authority", "call_remote", "unreliable")
func _act_remote(action: StringName) -> void:
	_show_act(action)


func _show_act(action: StringName) -> void:
	if _model:
		_model.play_action(action)


func _show(delta: float) -> void:
	if _model == null:
		return
	var vel := _flat(velocity) if Network.is_sim_authority() else _net_vel
	_model.working = digging
	var hold := Vector3.ZERO
	var grips: Array[Vector3] = []
	if _crate:
		_crate.visible = carrying
		_crate_load.visible = loaded > 0
		if carrying:
			hold = global_transform * (CRATE_AT + Vector3(0, _crate_top * 0.5, 0))
			var side := global_transform.basis.x * (_crate_half + 0.01)
			var rim := global_transform * (CRATE_AT + Vector3(0, _crate_top - 0.05, 0))
			grips = [rim + side, rim - side]
	_model.grips = grips
	_model.animate(delta, vel, true, carrying and _crate != null, hold)
	var text := "%s\n%s" % [info().name, "wartet auf Lohn" if state == State.UNPAID else info().job]
	if text != _tag_text:
		_tag_text = text
		_tag.text = text
		_tag.modulate = UITheme.BAD if state == State.UNPAID else UITheme.PAPER
	# (Looked at, the hint over the head says the same and more: the name makes way for it.)
	_tag.visible = Engine.get_process_frames() - _hinted_at > 3


func _build() -> void:
	_model = PlayerModel.new()
	_model.body = info().body
	_model.hat = false
	add_child(_model)
	_model.footstep.connect(func(_foot: int) -> void: Sfx.play(&"step_concrete", global_position, -15.0, 0.12))
	# Name and job over the head, for whoever stands near.
	_tag = Label3D.new()
	_tag.font = UITheme.font(700)
	_tag.font_size = 44
	_tag.pixel_size = 0.0022
	_tag.outline_size = 12
	_tag.outline_modulate = Color(0.06, 0.06, 0.07, 0.9)
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.position = Vector3(0, TAG, 0)
	_tag.visibility_range_end = 9.0
	_tag.visibility_range_end_margin = 1.5
	_tag.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(_tag)
	if role == &"runner":
		_build_crate()


## The runner's crate (a scanned wooden crate, brought to carrying size) with a few pieces of scrap
## on it that show while it is loaded.
func _build_crate() -> void:
	_crate = Node3D.new()
	_crate.position = CRATE_AT
	_crate.visible = false
	add_child(_crate)
	var box := PhotoProp.box("wooden_crate_01")
	var long := maxf(maxf(box.size.x, box.size.z), 0.01)
	var fit := CRATE_W / long
	PhotoProp.stand(_crate, "wooden_crate_01", Vector3.ZERO, 0.0 if box.size.x >= box.size.z else 90.0, fit)
	_crate_half = CRATE_W * 0.5
	_crate_top = box.size.y * fit
	_crate_load = Node3D.new()
	_crate_load.visible = false
	_crate.add_child(_crate_load)
	var deep := minf(box.size.x, box.size.z) * fit
	var pieces := [[&"scrap_can", Vector3(-0.11, 0.0, 0.03), 0.4], [&"junk_gear", Vector3(0.08, 0.0, -0.04), 1.3],
		[&"scrap_pipe", Vector3(0.0, 0.03, 0.06), 0.2], [&"junk_sheet", Vector3(0.03, 0.02, -0.02), 2.2], [&"scrap_can", Vector3(0.13, 0.02, 0.05), 2.9]]
	for piece: Array in pieces:
		var kind: StringName = piece[0]
		if not ScrapModels.has(kind):
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = ScrapModels.mesh(kind)
		mi.material_override = ScrapModels.material(FoundryRules.find_info(kind).color, kind)
		var at: Vector3 = piece[1]
		mi.transform = Transform3D(Basis.from_euler(Vector3(0.5, float(piece[2]), 0.3)).scaled(Vector3.ONE * 0.8),
			Vector3(at.x, _crate_top - 0.04 + at.y, at.z * deep / 0.3))
		_crate_load.add_child(mi)
