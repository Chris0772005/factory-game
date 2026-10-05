class_name Furnace
extends Node3D
## Backyard bucket furnace. Scrap thrown into the mouth melts into a docked
## crucible while players keep the heat up with the bellows.

const MOUTH_RADIUS := 0.45
const HEIGHT := 0.75
const HEAT_PER_PUMP := 0.11
const HEAT_DECAY := 0.045
const MELT_TIME := 1.6          ## seconds per scrap piece at full heat

var heat := 0.0
var crucible: Crucible = null
var charge: Array[StringName] = []
var _melt_progress := 0.0
var _fire: FurnaceFire
var _bellows: Node3D
var _bellows_squash := 0.0
var _sync_accum := 0.0
var _roar: AudioStreamPlayer3D
var _art: FurnaceArt


func _ready() -> void:
	add_to_group(&"interactable")
	add_to_group(&"furnaces")
	var body := StaticBody3D.new()
	add_child(body)
	# Ring of boxes so a crucible can sit inside the open drum.
	for i in 10:
		var a := TAU * i / 10.0
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.3, HEIGHT, 0.08)
		cs.shape = box
		cs.position = Vector3(sin(a), 0, cos(a)) * MOUTH_RADIUS + Vector3(0, HEIGHT * 0.5, 0)
		cs.rotation.y = a
		body.add_child(cs)
	var floor_cs := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(MOUTH_RADIUS * 2, 0.12, MOUTH_RADIUS * 2)
	floor_cs.shape = floor_box
	floor_cs.position.y = 0.06
	body.add_child(floor_cs)
	_roar = Sfx.make_loop(self, &"furnace_loop")
	_roar.position.y = 0.5
	_fire = FurnaceFire.new()
	_fire.radius = 0.34
	_fire.height = 0.62
	_fire.light_energy = 1.9
	_fire.light_range = 4.5
	_fire.position.y = 0.15
	add_child(_fire)
	_bellows = Node3D.new()
	_bellows.position = Vector3(MOUTH_RADIUS + 0.75, 0, 0)
	add_child(_bellows)
	_art = FurnaceArt.new()
	add_child(_art)
	_art.build(_bellows)


func interact_point() -> Vector3:
	return _bellows.global_position + Vector3(0, 0.4, 0)


func hint(_player: Node) -> String:
	return "[F] Blasebalg treten  · Hitze %d %%" % roundi(heat * 100)


func interact(_player: Node) -> void:
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	var boost := 1.5 if world and world.has_upgrade(&"bellows_foot") else 1.0
	heat = minf(1.0, heat + HEAT_PER_PUMP * boost)
	_bellows_squash = 1.0
	Sfx.play(&"bellows", _bellows.global_position)
	if Network.is_online():
		_pump_fx.rpc()


@rpc("authority", "call_remote", "reliable")
func _pump_fx() -> void:
	_bellows_squash = 1.0
	Sfx.play(&"bellows", _bellows.global_position)


func _physics_process(delta: float) -> void:
	_bellows_squash = move_toward(_bellows_squash, 0.0, delta * 4.0)
	_fire.heat = heat
	_roar.volume_db = linear_to_db(maxf(0.001, heat)) - 4.0
	if heat > 0.02 and not _roar.playing:
		_roar.play()
	elif heat <= 0.02 and _roar.playing:
		_roar.stop()
	if not Network.is_sim_authority():
		return
	heat = maxf(0.0, heat - HEAT_DECAY * delta)
	_dock_crucible()
	_take_scrap()
	_melt(delta)
	if Network.is_online():
		_sync_accum += delta
		if _sync_accum > 0.2:
			_sync_accum = 0.0
			_sync.rpc(heat)


func _process(delta: float) -> void:
	_art.update(delta, heat, _bellows_squash)


@rpc("authority", "call_remote", "unreliable_ordered")
func _sync(h: float) -> void:
	heat = h


func _dock_crucible() -> void:
	if crucible and (not is_instance_valid(crucible) or crucible.is_held()):
		if is_instance_valid(crucible):
			crucible.docked_in = null
		crucible = null
	if crucible:
		return
	for c in get_tree().get_nodes_in_group(&"crucibles"):
		var cr := c as Crucible
		if cr.is_held() or cr.docked_in:
			continue
		var flat := Vector2(cr.global_position.x - global_position.x, cr.global_position.z - global_position.z)
		if flat.length() < MOUTH_RADIUS and cr.global_position.y < global_position.y + HEIGHT:
			crucible = cr
			cr.docked_in = self


func _take_scrap() -> void:
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	if world == null:
		return
	for node in world.entities.get_children():
		var item := node as Item
		if item == null or not FoundryRules.SCRAP.has(item.kind) or item.is_held():
			continue
		var p := item.global_position - global_position
		if Vector2(p.x, p.z).length() < MOUTH_RADIUS and p.y < HEIGHT + 0.3 and p.y > 0.0:
			charge.append(item.kind)
			FoundryFX.sparks(self, global_position + Vector3(0, HEIGHT, 0), 8)
			Sfx.play(&"scrap_clatter", global_position + Vector3(0, HEIGHT, 0))
			item.queue_free()


func _melt(delta: float) -> void:
	if crucible:
		crucible.temperature = move_toward(crucible.temperature, heat, delta * 0.25)
	if charge.is_empty() or crucible == null or heat < 0.25:
		return
	_melt_progress += delta * heat / MELT_TIME
	if _melt_progress >= 1.0:
		_melt_progress = 0.0
		var scrap: Dictionary = FoundryRules.SCRAP[charge.pop_front()]
		crucible.add_melt(scrap.metal, scrap.amount)
