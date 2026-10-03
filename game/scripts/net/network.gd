extends Node
## Session management. Development uses ENet over IP; the Steam transport
## (GodotSteam lobbies) will plug into the same signals later.
##
## Command line: `-- --host` or `-- --join=127.0.0.1`

signal session_started
signal peer_joined(id: int)
signal peer_left(id: int)
signal session_ended(reason: String)

const MENU_SCENE := "res://scenes/main_menu.tscn"

const PORT := 24567
const MAX_PLAYERS := 4

## Shown by the main menu after a session ends unexpectedly.
var last_message := ""


func _ready() -> void:
	multiplayer.peer_connected.connect(func(id): peer_joined.emit(id))
	multiplayer.peer_disconnected.connect(func(id): peer_left.emit(id))
	multiplayer.connected_to_server.connect(func(): session_started.emit())
	multiplayer.server_disconnected.connect(func(): _end_session("Der Host hat das Spiel verlassen."))
	multiplayer.connection_failed.connect(func(): _end_session("Verbindung zum Host fehlgeschlagen."))
	for arg in OS.get_cmdline_user_args():
		if arg == "--host":
			host()
		elif arg.begins_with("--join="):
			join(arg.trim_prefix("--join="))


func host(port := PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	session_started.emit()
	return OK


func join(address: String, port := PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


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
