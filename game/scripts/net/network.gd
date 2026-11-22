extends Node
## Session management. Development uses ENet over IP; the Steam transport
## (GodotSteam lobbies) will plug into the same signals later.
##
## Command line: `-- --host` or `-- --join=127.0.0.1`, optionally `--port=N`

signal session_started
signal peer_joined(id: int)
signal peer_left(id: int)
signal session_ended(reason: String)
## Host only: a client has its world loaded and says which level it is.
signal peer_ready(id: int, level: String)

const MENU_SCENE := "res://scenes/main_menu.tscn"

const PORT := 24567
const MAX_PLAYERS := 4

## Shown by the main menu after a session ends unexpectedly.
var last_message := ""
## A join waits until the level scene is loaded (`connect_pending`): a client
## that connects first loses every spawn the host sends before its world exists.
var _pending_join := {}
var _address := "127.0.0.1"
var _port := PORT
## script -> whether it (or a script it builds on) declares RPCs.
var _rpc_scripts := {}


func _ready() -> void:
	get_tree().node_added.connect(_name_rpc_node)
	multiplayer.peer_connected.connect(func(id): peer_joined.emit(id))
	multiplayer.peer_disconnected.connect(func(id): peer_left.emit(id))
	multiplayer.connected_to_server.connect(func(): session_started.emit())
	multiplayer.server_disconnected.connect(func(): _end_session("Der Host hat das Spiel verlassen."))
	multiplayer.connection_failed.connect(func(): _end_session("Verbindung zum Host fehlgeschlagen."))
	var port := PORT
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--port="):
			port = int(arg.trim_prefix("--port="))
	for arg in OS.get_cmdline_user_args():
		if arg == "--host":
			host(port)
		elif arg.begins_with("--join="):
			join_after_load(arg.trim_prefix("--join="), port)
		elif arg.begins_with("--shift-names="):
			# Test switch: this process has already made so many nodes without a name, as a player has who
			# sat in the menu for a while. The engine numbers such nodes through ("@Node3D@57"), so a node
			# that RPCs travel to must carry a name of its own; the co-op tests run their client with this.
			for i in int(arg.trim_prefix("--shift-names=")):
				var filler := Node.new()
				add_child(filler)
				filler.free()


## Every node that RPCs travel to needs the same path on every peer. A node added without a name is
## numbered through by the engine ("@Node3D@57", counted per process: a player who sat in the menu
## longer has other numbers), so such a node gets a name of its own as it enters the tree: its class
## and its place among its like under the same parent ("MoldBox_1"). Both peers build a level's
## stations in the same order, so they arrive at the same names. Nameless nodes above it on the way
## to the root are named the same way.
func _name_rpc_node(node: Node) -> void:
	var script := node.get_script() as Script
	if script == null or not String(node.name).begins_with("@"):
		return
	if not _rpc_scripts.has(script):
		var found := false
		var s := script
		while s and not found:
			var config: Variant = s.get_rpc_config()
			found = config is Dictionary and not (config as Dictionary).is_empty()
			s = s.get_base_script()
		_rpc_scripts[script] = found
	if not _rpc_scripts[script]:
		return
	var chain: Array[Node] = [node]
	var up := node.get_parent()
	while up and up != get_tree().root:
		if String(up.name).begins_with("@"):
			chain.push_front(up)
		up = up.get_parent()
	for n in chain:
		var kind := n.get_class()
		var named := n.get_script() as Script
		if named and named.get_global_name() != &"":
			kind = String(named.get_global_name())
		var i := 0
		while n.get_parent().has_node(NodePath("%s_%d" % [kind, i])):
			i += 1
		n.name = "%s_%d" % [kind, i]


func host(port := PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	session_started.emit()
	return OK


func join(address: String, port := PORT) -> Error:
	_address = address
	_port = port
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


## Queues a join for when the next level has loaded (see `connect_pending`).
func join_after_load(address: String, port := PORT) -> void:
	_pending_join = {address = address, port = port}


## Called by GameWorld before it builds the level: connects a queued join.
func connect_pending() -> void:
	if _pending_join.is_empty():
		return
	var p := _pending_join
	_pending_join = {}
	var err := join(p.address, p.port)
	if err != OK:
		_end_session("Verbindung fehlgeschlagen (%s)." % error_string(err))


## Client: tells the host which level it has loaded (GameWorld, once connected).
func announce_level(level: String) -> void:
	_hello.rpc_id(1, level)


@rpc("any_peer", "call_remote", "reliable")
func _hello(level: String) -> void:
	if multiplayer.is_server():
		peer_ready.emit(multiplayer.get_remote_sender_id(), level)


## Host (or solo): moves everyone to the level at `path`. Clients reload it
## and reconnect, so they take the same, tested path as a fresh join.
func travel(path: String) -> void:
	if is_online() and multiplayer.is_server():
		_travel.rpc(path)
	Transition.change_scene(path)


## Host: sends one client to `path` (it joined while we are in another level).
func send_travel(peer: int, path: String) -> void:
	_travel.rpc_id(peer, path)


@rpc("authority", "call_remote", "reliable")
func _travel(path: String) -> void:
	Transition.change_scene(path, func() -> void:
		# Swap the peer out before closing it, so no "host left" fires.
		var old := multiplayer.multiplayer_peer
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		if old:
			old.close()
		join_after_load(_address, _port)
	)


func is_online() -> bool:
	return multiplayer.has_multiplayer_peer() \
		and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer


## True when this instance simulates shared physics (host or offline).
func is_sim_authority() -> bool:
	return not is_online() or multiplayer.is_server()


## Leaves the current session (host or client) and returns to the menu.
func leave() -> void:
	_end_session("")


func _end_session(reason: String) -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	last_message = reason
	session_ended.emit(reason)
	if get_tree().current_scene and get_tree().current_scene.scene_file_path != MENU_SCENE:
		get_tree().change_scene_to_file.call_deferred(MENU_SCENE)
