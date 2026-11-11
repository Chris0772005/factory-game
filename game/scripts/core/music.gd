extends Node
## Autoload "Music": background music per scene with a soft crossfade.
## Drop files into res://assets/music/ named after the scene they belong to
## (menu, backyard, garage, bell_foundry, iron_hall; .ogg or .mp3); a file
## called theme plays wherever no own track exists. No file, no music.

const DIR := "res://assets/music/"
const FADE := 2.5

var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _track := ""
var _scene_path := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = -80.0
		add_child(p)
		_players.append(p)


## Track name for a scene path ("res://scenes/main_menu.tscn" -> "menu").
static func track_for(scene_path: String) -> String:
	var base := scene_path.get_file().get_basename()
	return "menu" if base == "main_menu" else base


## The stream for `track`, falling back to "theme"; null when neither exists.
static func find_stream(track: String) -> AudioStream:
	for name: String in [track, "theme"]:
		for ext: String in [".ogg", ".mp3"]:
			if ResourceLoader.exists(DIR + name + ext):
				return load(DIR + name + ext)
	return null


func _process(delta: float) -> void:
	var scene := get_tree().current_scene
	var path := scene.scene_file_path if scene else ""
	if path != _scene_path:
		_scene_path = path
		_switch(track_for(path))
	var level := linear_to_db(maxf(GameSettings.music_volume, 0.0001)) - 8.0
	for i in 2:
		var p := _players[i]
		var goal := level if i == _active and p.stream != null and GameSettings.music_volume > 0.001 else -80.0
		p.volume_db = move_toward(p.volume_db, goal, delta * 80.0 / FADE)
		if i != _active and p.playing and p.volume_db <= -79.0:
			p.stop()


func _switch(track: String) -> void:
	var stream := find_stream(track)
	var current := _players[_active]
	if stream == current.stream:
		return
	_track = track
	_active = 1 - _active
	var next := _players[_active]
	next.stream = stream
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	next.volume_db = -80.0
	next.play()
