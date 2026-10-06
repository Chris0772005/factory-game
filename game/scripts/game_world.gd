class_name GameWorld
extends Node3D
## Networked world root: spawns workers and items on every peer via a
## MultiplayerSpawner and hosts the physics replication.

## Blue, teal, violet, pink (Art Bible 4.2): never orange, yellow or green,
## which compete with the heat, the "bad" red and the lawn.
const PLAYER_COLORS := [Color("#3e7bd6"), Color("#26b5c4"), Color("#9b5bd0"), Color("#e26aa0")]

signal money_changed(amount: int)

var spawner: MultiplayerSpawner
var physics_sync: PhysicsSync
var entities: Node3D
var factory: FactoryGrid
var money := 0
## Menu backgrounds reuse levels without a player or HUD.
var attract_mode := false
var hud: HUD
## Upgrades node of the current save (set by levels that have progression).
var upgrades: Node = null
## type -> Callable(data: Dictionary) -> Node, for level-specific networked entities.
var entity_factories := {}
var _next_item_id := 0


func _ready() -> void:
	add_to_group(&"world")
	entities = Node3D.new()
	entities.name = "Entities"
	add_child(entities)
	physics_sync = PhysicsSync.new()
	physics_sync.name = "PhysicsSync"
	add_child(physics_sync)
	spawner = MultiplayerSpawner.new()
	spawner.name = "Spawner"
	add_child(spawner)
	spawner.spawn_path = spawner.get_path_to(entities)
	spawner.spawn_function = _spawn_entity
	Network.peer_joined.connect(_on_peer_joined)
	Network.peer_left.connect(_on_peer_left)
	Network.session_started.connect(_on_session_started)
	build_level()
	if attract_mode:
		return
	if Network.is_sim_authority():
		spawn_player(1)
	hud = HUD.new()
	hud.world = self
	add_child(hud)


## Override in subclasses to build static geometry and initial items (host only for items).
func build_level() -> void:
	pass


## Creates the conveyor/machine grid for this level.
func create_factory() -> FactoryGrid:
	factory = FactoryGrid.new()
	factory.name = "Factory"
	factory.world = self
	add_child(factory)
	return factory


func add_money(amount: int) -> void:
	if not Network.is_sim_authority():
		return
	money += amount
	money_changed.emit(money)
	if Network.is_online():
		_sync_money.rpc(money)


@rpc("authority", "call_remote", "reliable")
func _sync_money(amount: int) -> void:
	money = amount
	money_changed.emit(money)


func _on_session_started() -> void:
	if multiplayer.is_server():
		# Offline player (if any) becomes the host's player.
		if not entities.has_node("1"):
			spawn_player(1)


func _on_peer_joined(id: int) -> void:
	if multiplayer.is_server():
		spawn_player(id)
		physics_sync.send_snapshot.call_deferred(id)


func _on_peer_left(id: int) -> void:
	if multiplayer.is_server() and entities.has_node(str(id)):
		var p: Player = entities.get_node(str(id))
		p.release()
		p.queue_free()


func spawn_player(id: int) -> Player:
	var index := entities.get_children().filter(func(n): return n is Player).size()
	var data := {type = "player", id = id, color = PLAYER_COLORS[index % PLAYER_COLORS.size()],
		pos = Vector3(index * 1.2, 0.2, 5)}
	return _spawn(data)


func spawn_item(kind: StringName, color: Color, size: Vector3, mass: float, pos: Vector3) -> Item:
	var data := {type = "item", name = next_name("I"), kind = kind, color = color,
		size = size, mass = mass, pos = pos}
	return _spawn(data)


## Registers a networked entity type that levels can spawn with `spawn_entity`.
func register_entity(type: String, factory: Callable) -> void:
	entity_factories[type] = factory


## Spawns a registered entity on every peer. `data` must contain `type`;
## a unique `name` is added when missing. Host only.
func spawn_entity(data: Dictionary) -> Node:
	if not data.has("name"):
		data.name = next_name(data.type.substr(0, 1).to_upper())
	return _spawn(data)


func next_name(prefix: String) -> String:
	_next_item_id += 1
	return "%s%d" % [prefix, _next_item_id]


func _spawn(data: Dictionary) -> Node:
	if Network.is_online():
		return spawner.spawn(data)
	var node := _spawn_entity(data)
	entities.add_child(node)
	return node


func _spawn_entity(data: Dictionary) -> Node:
	match data.type:
		"player":
			var p := Player.new()
			p.name = str(data.id)
			p.peer_id = data.id
			p.color = data.color
			p.position = data.pos
			p.facing = PI
			return p
		"item":
			var item := Item.create(data.kind, data.color, data.size, data.mass)
			item.name = data.name
			item.position = data.pos
			item.ready.connect(func(): physics_sync.register(item), CONNECT_ONE_SHOT)
			return item
	if entity_factories.has(data.type):
		var node: Node = entity_factories[data.type].call(data)
		node.name = data.name
		if node is RigidBody3D:
			node.ready.connect(func(): physics_sync.register(node), CONNECT_ONE_SHOT)
		return node
	push_error("Unknown entity type: %s" % data.type)
	return null


## Floating text for everyone (host calls this).
func popup_all(pos: Vector3, text: String, color: Color) -> void:
	HUD.popup(self, pos, text, color)
	if Network.is_online() and multiplayer.is_server():
		_popup_remote.rpc(pos, text, color)


@rpc("authority", "call_remote", "reliable")
func _popup_remote(pos: Vector3, text: String, color: Color) -> void:
	HUD.popup(self, pos, text, color)


## Big reveal banner (and grade sting) for every player near `pos`. Host calls this.
func banner_near(pos: Vector3, text: String, color: Color, subtitle: String, good: bool) -> void:
	_banner_local(pos, text, color, subtitle, good)
	if Network.is_online() and multiplayer.is_server():
		_banner_remote.rpc(pos, text, color, subtitle, good)


@rpc("authority", "call_remote", "reliable")
func _banner_remote(pos: Vector3, text: String, color: Color, subtitle: String, good: bool) -> void:
	_banner_local(pos, text, color, subtitle, good)


func _banner_local(pos: Vector3, text: String, color: Color, subtitle: String, good: bool) -> void:
	var me := local_player()
	if me == null or me.global_position.distance_to(pos) > 6.0:
		return
	HUD.banner(text, color, subtitle)
	Sfx.play_ui(&"grade_good" if good else &"grade_bad", -2.0)


## Hint for whatever `player` carries, e.g. "[F] Gießen" for a crucible.
func held_hint(player: Player) -> String:
	var node := entities.get_node_or_null(player.held_name)
	if node and node.has_method("held_hint"):
		return node.held_hint(player)
	return "[LMB] Ablegen   [RMB] Werfen"


func has_upgrade(id: StringName) -> bool:
	return upgrades != null and upgrades.has(id)


func respawn_point(_player: Player) -> Vector3:
	return Vector3(randf_range(-1.0, 1.0), 0.3, 5.0)


func local_player() -> Player:
	var id := multiplayer.get_unique_id() if Network.is_online() else 1
	return entities.get_node_or_null(str(id))
