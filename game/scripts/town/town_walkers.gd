class_name TownWalkers
extends Node3D
## People on the far pavement: each walks a fixed round between the shops, goes in, stands at a
## counter or a shop front for a while and comes out again. Looks only: they cannot be spoken to
## and step aside for players and for the officer on the beat instead of bumping into them.
## Every round runs against one clock, so all players see the walkers in the same place; the host
## sends its clock round every few seconds.

## The walkers' figures are in this group.
const GROUP := &"town_walkers"
const SPEED := 1.3
const SYNC_EVERY := 4.0
## Within this distance of a player a walker gives way (m), and by how much at most.
const GIVE_WAY := 1.1
const SIDE_STEP := 0.7

var clock := 0.0
var _rounds: Array = []
var _sync := 0.0


## A walker of `model` (TownFigure: Casual, Casual_Woman, Worker, Suit ...) in `colors`, who starts
## `offset` seconds into the round and walks at `pace` m/s (below about 1 m/s the people stroll).
## `stops` are [position, seconds to stand there] in walking order, with a third entry where the
## walker should look meanwhile (a point); after the last stop the walker returns to the first.
## Returns the number of the round (for `standing`).
func add_round(model: String, colors: Dictionary, stops: Array, offset := 0.0, pace := SPEED) -> int:
	var legs: Array = []
	var total := 0.0
	for i in stops.size():
		var from: Vector3 = stops[i][0]
		var to: Vector3 = stops[(i + 1) % stops.size()][0]
		var wait: float = stops[i][1]
		var walk := from.distance_to(to) / pace
		var look: Vector3 = stops[i][2] if (stops[i] as Array).size() > 2 else to
		legs.append([total, wait, walk, from, to, look])
		total += wait + walk
	var entry := {legs = legs, total = total, offset = offset, pace = pace, figure = null, side = 0.0, facing = 0.0}
	if DisplayServer.get_name() != "headless":
		var figure := TownFigure.make(model, colors)
		add_child(figure)
		# Cars stop for them (TownTraffic).
		figure.add_to_group(GROUP)
		entry.figure = figure
	_rounds.append(entry)
	return _rounds.size() - 1


## Where the walker of round `index` is: [the stop it stands at (-1 while it walks), the seconds it has
## stood there, how many rounds it has finished]. The same on every peer (the rounds run by one clock).
func standing(index: int) -> Array:
	var entry: Dictionary = _rounds[index]
	var run := clock + float(entry.offset)
	var t := fposmod(run, float(entry.total))
	var lap := int(floor(run / float(entry.total)))
	var legs: Array = entry.legs
	for i in legs.size():
		var leg: Array = legs[i]
		if t <= float(leg[0]) + float(leg[1]) + float(leg[2]):
			var since := t - float(leg[0])
			return [i if since <= float(leg[1]) else -1, since, lap]
	return [-1, 0.0, lap]


## How far into its round (s) the walker of round `index` reaches stop `stop`.
func time_at(index: int, stop: int) -> float:
	var entry: Dictionary = _rounds[index]
	return float(((entry.legs as Array)[stop] as Array)[0]) - float(entry.offset)


## The figure of round `index` (null on a machine without a screen).
func figure_of(index: int) -> TownFigure:
	return (_rounds[index] as Dictionary).figure as TownFigure


func _physics_process(delta: float) -> void:
	clock += delta
	if Network.is_online() and multiplayer.is_server():
		_sync -= delta
		if _sync <= 0.0:
			_sync = SYNC_EVERY
			_set_clock.rpc(clock)
	# Whom the walkers give way to: the players, the officer on the beat and the crew's hired hands.
	var players := get_tree().get_nodes_in_group(&"players") + get_tree().get_nodes_in_group(PolicePatrol.GROUP) \
		+ get_tree().get_nodes_in_group(HiredHand.GROUP)
	for entry: Dictionary in _rounds:
		var figure := entry.figure as TownFigure
		if figure == null:
			continue
		var t := fposmod(clock + float(entry.offset), float(entry.total))
		var at := Vector3.ZERO
		var heading := Vector3.ZERO
		var moving := false
		for leg: Array in entry.legs:
			var start: float = leg[0]
			var wait: float = leg[1]
			var walk: float = leg[2]
			if t > start + wait + walk:
				continue
			var from: Vector3 = leg[3]
			var to: Vector3 = leg[4]
			var k := clampf((t - start - wait) / maxf(walk, 0.01), 0.0, 1.0)
			at = from.lerp(to, k)
			moving = t > start + wait and walk > 0.05
			# Standing: towards what there is to look at. Walking: where the way goes.
			heading = (to - from) if moving else ((leg[5] as Vector3) - from)
			break
		heading.y = 0.0
		var forward := heading.normalized() if heading.length() > 0.01 else Vector3.BACK
		# A player in the way: step to the side that is nearer, and back once past.
		var want := 0.0
		for node in players:
			var rel := (node as Node3D).global_position - at
			rel.y = 0.0
			if rel.length() < GIVE_WAY:
				var across := forward.cross(Vector3.UP).dot(rel)
				want = -signf(across if absf(across) > 0.01 else 1.0) * SIDE_STEP * (1.0 - rel.length() / GIVE_WAY)
		entry.side = move_toward(float(entry.side), want, delta * 1.6)
		figure.global_position = at + forward.cross(Vector3.UP) * float(entry.side)
		entry.facing = lerp_angle(float(entry.facing), atan2(forward.x, forward.z), minf(delta * 7.0, 1.0))
		figure.rotation.y = entry.facing
		figure.animate(delta, forward * float(entry.pace) if moving else Vector3.ZERO)


@rpc("authority", "call_remote", "unreliable")
func _set_clock(host_clock: float) -> void:
	if absf(host_clock - clock) > 0.3:
		clock = host_clock
