class_name PolicePatrol
extends CharacterBody3D
## The officer on the beat. Walks the pavement between `route` points and
## looks around. Hot goods carried openly are seen from far away, hot goods
## under the scrap in a bucket only from close up. Whoever stays in view gets
## suspicious (`alert` 0..1); at 1 the officer gives chase. Caught with the
## goods: they are gone and a fine is due (TownLaw.arrest). Dropping the
## goods or breaking the line of sight long enough ends the chase. Hot goods
## lying about in plain sight are collected.
## Host simulates; peers mirror position, state and `alert` for the HUD.

enum State { PATROL, LOOK, ALERT, CHASE, RETURN }

const GROUP := &"police_patrols"
const WALK_SPEED := 1.25
const CHASE_SPEED := 5.3
const SIGHT_OPEN := 11.0
const SIGHT_BUCKET := 3.2
## Minimum dot between facing and the direction to the suspect.
const FOV_OPEN := 0.45
const FOV_BUCKET := 0.15
const NOTICE_TIME := 1.1
const FORGET_RATE := 0.45
const CATCH_RANGE := 2.1
## He stops this far from whoever he is after: an arm's length, not nose to nose.
const ARM_LENGTH := 1.7
const LOSE_TIME := 5.0
const COLLECT_RANGE := 3.5
## A chase ends by itself after this long, and this long after the goods are gone.
const CHASE_MAX := 25.0
const EMPTY_HANDS_TIME := 2.0
const EYE := Vector3(0, 1.55, 0)
## The Swat figure in police blue.
const UNIFORM := {"Swat": Color("#1f3160"), "Swat_Black": Color("#14161c")}

var route: Array[Vector3] = []
## The houses are out of his way for now (no path finding through doors yet): he stays on the
## street side of `max_z`, and a goal inside `keep_out` (a block of houses on the ground: x and z)
## is moved to that block's edge on his side, unless it lies in one of the `ways` through it (x
## from, x to). So he follows round the block and through the passages, but not indoors.
var max_z := INF
var keep_out := Rect2()
var ways: Array[Vector2] = []
## The line he walks through each way (x), in the order of `ways`: clear of what stands in it and
## of the pillars at its ends. Without one he takes the way's middle. `ways` are as wide as somebody
## can stand in them; to walk through he keeps within LANE_W of the line.
var lanes: Array[float] = []
const LANE_W := 0.5
var state := State.PATROL
## Peer id of the player the officer is suspicious of (0 = nobody) and how much.
var watching := 0
var alert := 0.0
var _suspicion := {}
var _leg := 1
var _timer := 0.0
var _next_look := 9.0
var _target: Player
var _last_seen := Vector3.ZERO
var _lost := 0.0
var _blind := 0.0
var _chase_time := 0.0
var _empty_time := 0.0
var _return_time := 0.0
var _sweep := 0.0
var _model: TownFigure
var _net_accum := 0.0
var _net_pos := Vector3.ZERO
var _net_vel := Vector3.ZERO


func _ready() -> void:
	add_to_group(GROUP)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.7
	shape.shape = capsule
	shape.position.y = 0.85
	add_child(shape)
	floor_snap_length = 0.3
	_model = TownFigure.make("Patrol", UNIFORM)
	add_child(_model)
	_net_pos = global_position


func heat() -> float:
	var law := TownLaw.of(get_tree())
	return law.heat if law else 0.0


## True if the officer can see `player` right now. `anywhere` ignores where
## he is facing (he is already after them).
func sees(player: Player, sight: float, fov: float, anywhere := false) -> bool:
	var from := global_position + EYE
	var to := player.global_position + Vector3(0, 1.0, 0)
	var flat := Vector3(to.x - from.x, 0, to.z - from.z)
	if flat.length() > sight:
		return false
	if not anywhere and flat.length() > 0.6 and global_transform.basis.z.dot(flat.normalized()) < fov:
		return false
	return _clear_line(from, to, player)


func _clear_line(from: Vector3, to: Vector3, goal: Node) -> bool:
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = [get_rid()]
	for i in 5:
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.exclude = exclude
		var hit := space.intersect_ray(query)
		if hit.is_empty() or hit.collider == goal:
			return true
		# Loose things and other people do not hide anybody.
		if hit.collider is RigidBody3D or hit.collider is CharacterBody3D:
			exclude.append(hit.rid)
			continue
		return false
	return false


func _physics_process(delta: float) -> void:
	if Network.is_sim_authority():
		_think(delta)
		if not is_on_floor():
			velocity.y -= 20.0 * delta
		else:
			velocity.y = -1.0
		move_and_slide()
		if Network.is_online():
			_net_accum += delta
			if _net_accum > 0.1:
				_net_accum = 0.0
				_sync.rpc(global_position, rotation.y, velocity, state, watching, alert)
	else:
		_net_pos += _net_vel * delta
		global_position = global_position.lerp(_net_pos, 1.0 - exp(-12.0 * delta))
	if _model:
		_model.animate(delta, velocity if Network.is_sim_authority() else _net_vel)


@rpc("authority", "call_remote", "unreliable_ordered")
func _sync(pos: Vector3, yaw: float, vel: Vector3, s: int, who: int, level: float) -> void:
	_net_pos = pos
	_net_vel = vel
	rotation.y = yaw
	state = s as State
	watching = who
	alert = level


func _think(delta: float) -> void:
	_blind = maxf(0.0, _blind - delta)
	if state != State.CHASE:
		_watch_players(delta)
	match state:
		State.PATROL:
			_patrol(delta)
		State.LOOK:
			_stop()
			rotation.y = lerp_angle(rotation.y, PI + sin(_timer * 1.3) * 0.7, 1.0 - exp(-4.0 * delta))
			_timer -= delta
			if _timer <= 0.0:
				state = State.PATROL
		State.ALERT:
			_stop()
			var suspect := _player(watching)
			if suspect:
				_face(suspect.global_position - global_position, delta, 7.0)
			if alert < 0.08:
				state = State.PATROL
		State.CHASE:
			_chase(delta)
		State.RETURN:
			var back := _route_point()
			_return_time += delta
			if _walk_to(back, WALK_SPEED * 1.5, delta):
				state = State.PATROL
			elif _return_time > 40.0:
				# Hung up on something on the way back (a walk round the block takes a while): he is on
				# his beat again.
				global_position = back
				state = State.PATROL
	_sweep -= delta
	if _sweep <= 0.0:
		_sweep = 0.5
		if state != State.CHASE:
			_collect(2.6, true)


func _watch_players(delta: float) -> void:
	var top := 0.0
	var who := 0
	var h := heat()
	for node in get_tree().get_nodes_in_group(&"players"):
		var p := node as Player
		var id := String(p.name).to_int()
		var s: float = _suspicion.get(id, 0.0)
		var load := TownLaw.carried_hot(p)
		var seen := false
		if not load.is_empty() and _blind <= 0.0:
			if load.open:
				seen = sees(p, SIGHT_OPEN * (1.0 + 0.5 * h), FOV_OPEN)
			else:
				seen = sees(p, SIGHT_BUCKET * (1.0 + 0.5 * h), FOV_BUCKET)
		if seen:
			s = minf(1.0, s + delta / NOTICE_TIME * (1.0 + h))
		else:
			s = maxf(0.0, s - delta * FORGET_RATE)
		_suspicion[id] = s
		if s > top:
			top = s
			who = id
	alert = top
	watching = who if top > 0.0 else 0
	if top >= 1.0:
		_start_chase(_player(who))
	elif top > 0.15 and (state == State.PATROL or state == State.LOOK):
		state = State.ALERT


func _player(id: int) -> Player:
	for node in get_tree().get_nodes_in_group(&"players"):
		if String(node.name).to_int() == id:
			return node as Player
	return null


func _start_chase(p: Player) -> void:
	if p == null:
		return
	_target = p
	_last_seen = p.global_position
	_lost = 0.0
	_chase_time = 0.0
	_empty_time = 0.0
	state = State.CHASE
	alert = 1.0
	watching = String(p.name).to_int()
	_say("Halt! Polizei!")


func _chase(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_end_chase()
		return
	alert = 1.0
	if sees(_target, 40.0, -1.0, true):
		_last_seen = _target.global_position
		_lost = 0.0
	else:
		_lost += delta
	var arrived := false
	if _lost < 0.3 and global_position.distance_to(_target.global_position) < ARM_LENGTH:
		_stop()
		_face(_target.global_position - global_position, delta, 9.0)
	else:
		arrived = _walk_to(_last_seen, CHASE_SPEED * (1.0 + 0.2 * heat()), delta)
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	var law := TownLaw.of(get_tree())
	var empty_handed := TownLaw.carried_hot(_target).is_empty()
	_chase_time += delta
	_empty_time = _empty_time + delta if empty_handed else 0.0
	if _lost < 0.3 and global_position.distance_to(_target.global_position) < CATCH_RANGE:
		if empty_handed:
			# The goods were dropped: he takes what lies about and lets it go at that.
			_collect(COLLECT_RANGE + 2.0, false)
			_say("Diesmal hast du Glück gehabt.")
			if law:
				law.add_heat(TownLaw.ESCAPE_HEAT)
			Missions.report(get_tree(), &"escape", 1)
		elif law and world:
			law.arrest(world, _target)
			_collect(COLLECT_RANGE, false)
		_end_chase()
	elif _empty_time > EMPTY_HANDS_TIME:
		# Nothing on them any more (dropped, sold, handed in): he lets it go.
		_collect(COLLECT_RANGE + 2.0, false)
		_say("Ich behalte dich im Auge.")
		if law:
			law.add_heat(TownLaw.ESCAPE_HEAT)
		Missions.report(get_tree(), &"escape", 1)
		_end_chase()
	elif _lost > LOSE_TIME or (arrived and _lost > 1.5) or _chase_time > CHASE_MAX:
		_collect(COLLECT_RANGE, false)
		_say("Wo ist der hin …?")
		if law:
			law.add_heat(TownLaw.ESCAPE_HEAT)
		Missions.report(get_tree(), &"escape", 1)
		_end_chase()


func _end_chase() -> void:
	_target = null
	_suspicion.clear()
	alert = 0.0
	watching = 0
	_blind = 6.0
	_return_time = 0.0
	state = State.RETURN


## Hot goods lying about: unheld pieces in reach (and the load of a bucket
## left standing, unless he only passes by) are taken away.
func _collect(reach: float, passing: bool) -> void:
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	if world == null:
		return
	var took := 0
	for node in world.entities.get_children():
		var item := node as Item
		if item == null or item.is_held() or item.is_queued_for_deletion():
			continue
		if item.global_position.distance_to(global_position) > reach:
			continue
		if item is ScrapBucket:
			if not passing:
				took += (item as ScrapBucket).take_hot().size()
		elif (FoundryRules.is_hot(item.kind) or TownLaw.weapon_of(item) != &"") and _clear_line(global_position + EYE, item.global_position + Vector3(0, 0.05, 0), item):
			item.queue_free()
			took += 1
	if took > 0:
		world.popup_all(global_position + Vector3(0, 2.2, 0), "Beschlagnahmt: %d Teil%s" % [took, "" if took == 1 else "e"], UITheme.BAD)


func _patrol(delta: float) -> void:
	if route.size() < 2:
		_stop()
		return
	_next_look -= delta
	if _walk_to(route[_leg], WALK_SPEED, delta):
		_leg = (_leg + 1) % route.size()
		state = State.LOOK
		_timer = 2.5
	elif _next_look <= 0.0:
		_next_look = randf_range(8.0, 14.0)
		state = State.LOOK
		_timer = 2.2


## Steers towards `goal`; true when there.
func _walk_to(goal: Vector3, speed: float, delta: float) -> bool:
	var aim := _reachable(goal)
	var whole := Vector3(aim.x - global_position.x, 0, minf(aim.z, max_z) - global_position.z)
	if whole.length() < 0.35:
		_stop()
		return true
	var step := _via(aim)
	var to := Vector3(step.x - global_position.x, 0, minf(step.z, max_z) - global_position.z)
	var dir := to.normalized() if to.length() > 0.05 else whole.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	_face(dir, delta, 9.0)
	return false


## The next point on the way to `aim`: `aim` itself, or, when houses of `keep_out` stand between him
## and it, the mouth of the way through the row (or the end of the row) with the shortest walk, and
## then its other end. (Walking straight at it, he marched on the spot against the yard wall behind
## the row after every chase round the block.)
func _via(aim: Vector3) -> Vector3:
	if not keep_out.has_area():
		return aim
	var here := Vector2(global_position.x, global_position.z)
	var there := Vector2(aim.x, aim.z)
	if not _houses_between(here, there):
		return aim
	# (The mouths lie clear of what stands along the row: boards and bins in front, dumpsters behind.)
	var south := keep_out.position.y - 0.8
	var north := keep_out.end.y + 1.2
	if keep_out.has_point(here):
		# In a way through the row: along its line to the mouth on the aim's side.
		return Vector3(_lane_at(here.x), aim.y, north if there.y > here.y else south)
	if here.y > keep_out.position.y and here.y < keep_out.end.y:
		# Beside the row, in a side street: first clear of the row, on the aim's side of it.
		return Vector3(here.x, aim.y, north if there.y > keep_out.get_center().y else south)
	# In front of the row or behind it: the line he takes through or round it ...
	var line := 0.0
	if keep_out.has_point(there):
		line = _lane_at(there.x)
	else:
		var best := INF
		var lines: Array[float] = [keep_out.position.x - 1.6, keep_out.end.x + 1.6]
		for i in ways.size():
			lines.append(_lane(i))
		for x in lines:
			var cost := absf(here.x - x) + absf(there.x - x)
			if cost < best:
				best = cost
				line = x
	# ... to its mouth on his side, and then through.
	var mine := south if here.y < keep_out.get_center().y else north
	if absf(here.x - line) > 0.3:
		return Vector3(line, aim.y, mine)
	return Vector3(line, aim.y, north if mine == south else south)


## Whether a house of `keep_out` stands on the straight line from `a` to `b`. The row is open only
## along the lines through its ways (where he stands in a way already, that way as wide as it is).
func _houses_between(a: Vector2, b: Vector2) -> bool:
	var in_way := _way_at(a.x) if keep_out.has_point(a) else -1
	var steps := maxi(1, ceili(a.distance_to(b) / 0.4))
	for i in steps + 1:
		var s := a.lerp(b, float(i) / steps)
		if not keep_out.has_point(s):
			continue
		var way := _way_at(s.x)
		if way < 0 or (way != in_way and absf(s.x - _lane(way)) > LANE_W):
			return true
	return false


## The way through the row that `x` lies in (index of `ways`), or -1.
func _way_at(x: float) -> int:
	for i in ways.size():
		if x > ways[i].x and x < ways[i].y:
			return i
	return -1


## The line he walks through way `index`.
func _lane(index: int) -> float:
	return lanes[index] if index < lanes.size() else (ways[index].x + ways[index].y) * 0.5


func _lane_at(x: float) -> float:
	var index := _way_at(x)
	return _lane(index) if index >= 0 else x


## `goal`, or the nearest place to it he goes to: not into the houses of `keep_out`.
func _reachable(goal: Vector3) -> Vector3:
	if not keep_out.has_area() or not keep_out.has_point(Vector2(goal.x, goal.z)):
		return goal
	for way in ways:
		if goal.x > way.x and goal.x < way.y:
			return goal
	var south := global_position.z < keep_out.get_center().y
	return Vector3(goal.x, goal.y, keep_out.position.y if south else keep_out.end.y)


func _stop() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


func _face(dir: Vector3, delta: float, rate: float) -> void:
	if Vector2(dir.x, dir.z).length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-rate * delta))


## Nearest point on the beat.
func _route_point() -> Vector3:
	if route.is_empty():
		return global_position
	var best := route[0]
	for i in route.size():
		var a := route[i]
		var b := route[(i + 1) % route.size()]
		var ab := b - a
		var t := clampf((global_position - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		var p := a + ab * t
		if p.distance_to(global_position) < best.distance_to(global_position):
			best = p
	return best


func _say(text: String) -> void:
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	if world:
		world.popup_all(global_position + Vector3(0, 2.1, 0), text, UITheme.INFO)
