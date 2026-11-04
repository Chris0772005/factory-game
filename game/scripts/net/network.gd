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


func _ready() -> void:
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
