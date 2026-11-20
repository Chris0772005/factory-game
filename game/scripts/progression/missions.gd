class_name Missions
extends Node
## Missions that never run out. Three run side by side, one per track:
## honest work at the heap, growing the business, and the side business under
## the counter. Each track is a list of templates gone through again and
## again; every round asks for more and pays more. Stations report what
## happens with `Missions.report`. Host counts, peers mirror for the HUD.

const GROUP := &"missions"
## Seconds until the next mission of a track appears after one is done.
const NEXT_DELAY := 2.5
## stat = what is counted, goal/reward for the first round, text (the count
## is shown beside it), needs = upgrade that must be owned (the template is skipped otherwise).
const TRACKS := [
	{name = "Schrott", color = Color("#f2b134"), list = [
		{stat = &"dig", goal = 15, reward = 20, text = "Schrott wühlen"},
		{stat = &"scrap_sold", goal = 25, reward = 35, text = "Schrott verkaufen"},
		{stat = &"handed_in", goal = 2, reward = 40, text = "Heiße Ware abgeben (Police)"},
		{stat = &"cast_sold", goal = 3, reward = 80, text = "Gussstücke verkaufen", needs = &"foundry_corner"},
		{stat = &"heap", goal = 1, reward = 150, text = "Schrottberg ganz abtragen"},
	]},
	{name = "Betrieb", color = Color("#5bb8e8"), list = [
		{stat = &"earned", goal = 100, reward = 25, text = "Geld verdienen ($)"},
		{stat = &"upgrade", goal = 1, reward = 30, text = "Ausbau kaufen"},
		{stat = &"diner", goal = 1, reward = 15, text = "Bei Molly stärken (Diner)"},
		{stat = &"digger_grab", goal = 30, reward = 80, text = "Bagger: Schaufeln laden", needs = &"excavator"},
		{stat = &"earned", goal = 400, reward = 60, text = "Geld verdienen ($)"},
		{stat = &"truck_load", goal = 3, reward = 120, text = "LKW: Ladungen wegfahren", needs = &"truck"},
	]},
	{name = "Unter der Hand", color = Color("#e5533d"), list = [
		{stat = &"hot_sold", goal = 1, reward = 30, text = "Heiße Ware verkaufen"},
		{stat = &"craft", goal = 2, reward = 50, text = "Waffen basteln", needs = &"workbench"},
		{stat = &"escape", goal = 1, reward = 60, text = "Der Polizei entkommen"},
		{stat = &"weapon_sold", goal = 1, reward = 120, text = "Guss-Waffe verkaufen", needs = &"foundry_corner"},
		{stat = &"hot_sold", goal = 4, reward = 90, text = "Heiße Ware verkaufen"},
	]},
]

signal changed

## Per track: how many missions are done, progress on the current one.
var done: Array[int] = [0, 0, 0]
var progress: Array[int] = [0, 0, 0]
## Total missions completed (for the HUD).
var total := 0
var _wait := [0.0, 0.0, 0.0]
var _paying := false


static func of(tree: SceneTree) -> Missions:
	return tree.get_first_node_in_group(GROUP) as Missions if tree else null


## Something countable happened (host). Safe to call in any level.
static func report(tree: SceneTree, stat: StringName, amount := 1) -> void:
	var m := of(tree)
	if m and Network.is_sim_authority():
		m.note(stat, amount)


func _init() -> void:
	name = "Missions"


func _ready() -> void:
	add_to_group(GROUP)
	Network.peer_ready.connect(_on_peer_ready)
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	if world:
		world.money_changed.connect(_on_money.bind(world))
		_last_money = world.money
	# No panel behind the main menu, where the level only stands as a backdrop.
	if DisplayServer.get_name() != "headless" and not (world and world.attract_mode):
		add_child(MissionsPanel.new())

var _last_money := 0


func _on_money(amount: int, _world: GameWorld) -> void:
	var gain := amount - _last_money
	_last_money = amount
	# Mission rewards themselves do not count as earnings.
	if gain > 0 and not _paying and Network.is_sim_authority():
		note(&"earned", gain)


func _world_has(id: StringName) -> bool:
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	return world != null and world.has_upgrade(id)


## The template track `t` is on: the list is gone through in order, skipping
## what cannot be done yet. Returns {} only if nothing in the track can be done.
func _template(t: int) -> Dictionary:
	var list: Array = TRACKS[t].list
	var n := list.size()
	for step in n:
		var m: Dictionary = list[(done[t] + step) % n]
		if not m.has("needs") or _world_has(m.needs):
			return m
	return {}


## How often the track's list has been gone through.
func round_of(t: int) -> int:
	return done[t] / (TRACKS[t].list as Array).size()


## The current mission of track `t`: {text, goal, reward, progress, stat}; {} while the next one is on its way.
func current(t: int) -> Dictionary:
	if _wait[t] > 0.0:
		return {}
	var m := _template(t)
	if m.is_empty():
		return {}
	var r := round_of(t)
	var goal := ceili(int(m.goal) * (1.0 + 0.6 * r))
	# A whole heap stays a whole heap.
	if m.stat == &"heap":
		goal = 1 + r / 2
	var reward := roundi(int(m.reward) * (1.0 + 0.5 * r) / 5.0) * 5
	return {text = String(m.text), goal = goal, reward = reward, progress = mini(progress[t], goal), stat = m.stat}


func note(stat: StringName, amount := 1) -> void:
	var touched := false
	for t in TRACKS.size():
		var m := current(t)
		if m.is_empty() or m.stat != stat:
			continue
		progress[t] += amount
		touched = true
		if progress[t] >= int(m.goal):
			_complete(t, m)
	if touched:
		_publish()


func _complete(t: int, m: Dictionary) -> void:
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	# Skipped templates count as passed, so the round number keeps rising.
	var list: Array = TRACKS[t].list
	var template := _template(t)
	var at := list.find(template)
	var skipped := posmod(at - done[t] % list.size(), list.size())
	done[t] += skipped + 1
	progress[t] = 0
	total += 1
	_wait[t] = NEXT_DELAY
	if world:
		_paying = true
		world.add_money(int(m.reward))
		_paying = false
		world.banner_all("MISSION GESCHAFFT", TRACKS[t].color, "%s · +%d $" % [m.text, m.reward])


func _physics_process(delta: float) -> void:
	if not Network.is_sim_authority():
		return
	for t in _wait.size():
		if _wait[t] > 0.0:
			_wait[t] = maxf(0.0, _wait[t] - delta)
			if _wait[t] == 0.0:
				_publish()


func _publish() -> void:
	changed.emit()
	if Network.is_online() and multiplayer.is_server():
		_sync.rpc(PackedInt32Array(done), PackedInt32Array(progress), total)


func _on_peer_ready(id: int, _level: String) -> void:
	if is_inside_tree() and multiplayer.is_server():
		_sync.rpc_id(id, PackedInt32Array(done), PackedInt32Array(progress), total)


@rpc("authority", "call_remote", "reliable")
func _sync(d: PackedInt32Array, p: PackedInt32Array, n: int) -> void:
	for t in mini(d.size(), done.size()):
		done[t] = d[t]
		progress[t] = p[t]
	total = n
	changed.emit()


func to_save() -> Dictionary:
	return {done = done.duplicate(), progress = progress.duplicate(), total = total}


func load_save(v: Variant) -> void:
	if typeof(v) != TYPE_DICTIONARY:
		return
	var d: Array = v.get("done", [])
	var p: Array = v.get("progress", [])
	for t in done.size():
		done[t] = int(d[t]) if t < d.size() else 0
		progress[t] = int(p[t]) if t < p.size() else 0
	total = int(v.get("total", 0))
	changed.emit()
