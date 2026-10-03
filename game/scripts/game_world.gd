class_name GameWorld
extends Node3D
## Networked world root: spawns workers and items on every peer via a
## MultiplayerSpawner and hosts the physics replication.

const PLAYER_COLORS := [Color("#3d7dd8"), Color("#e2574c"), Color("#3fae6a"), Color("#c77ddb")]

var spawner: MultiplayerSpawner
var physics_sync: PhysicsSync
var entities: Node3D
var _next_item_id := 0


func _ready() -> void:
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
	if Network.is_sim_authority():
		spawn_player(1)


## Override in subclasses to build static geometry and initial items (host only for items).
func build_level() -> void:
	pass


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
	_next_item_id += 1
	var data := {type = "item", name = "I%d" % _next_item_id, kind = kind, color = color,
		size = size, mass = mass, pos = pos}
	return _spawn(data)


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
	return null


func local_player() -> Player:
	var id := multiplayer.get_unique_id() if Network.is_online() else 1
	return entities.get_node_or_null(str(id))
