extends Node
## Sound effects from res://assets/sfx. Names without a number pick a random
## variant (`hammer_clank` -> hammer_clank_1..3). Positional sounds are pooled.

const DIR := "res://assets/sfx/"
const POOL_SIZE := 24

var _streams := {}      # name -> Array[AudioStream]
var _pool: Array[AudioStreamPlayer3D] = []
var _next := 0
var _ui: AudioStreamPlayer


func _ready() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 6.0
		p.max_distance = 45.0
		p.bus = &"Master"
		add_child(p)
		_pool.append(p)
	_ui = AudioStreamPlayer.new()
	add_child(_ui)


## One-shot sound at a world position.
func play(sound: StringName, pos: Vector3, volume_db := 0.0, pitch_jitter := 0.08) -> void:
	var stream := _pick(sound)
	if stream == null:
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = stream
	p.global_position = pos
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


## Non-positional sound (UI, money).
func play_ui(sound: StringName, volume_db := -4.0) -> void:
	var stream := _pick(sound)
	if stream:
		_ui.stream = stream
		_ui.volume_db = volume_db
		_ui.play()


## Looping emitter attached to `parent`; control it via volume_db / playing.
func make_loop(parent: Node3D, sound: StringName) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	var stream := _pick(sound)
	if stream is AudioStreamWAV:
		stream = stream.duplicate()
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
	p.stream = stream
	p.unit_size = 5.0
	p.max_distance = 35.0
	parent.add_child(p)
	return p


func _pick(sound: StringName) -> AudioStream:
	if not _streams.has(sound):
		var list: Array[AudioStream] = []
		var single := DIR + sound + ".wav"
		if ResourceLoader.exists(single):
			list.append(load(single))
		else:
			for i in range(1, 6):
				var path := DIR + "%s_%d.wav" % [sound, i]
				if ResourceLoader.exists(path):
					list.append(load(path))
		_streams[sound] = list
	var options: Array = _streams[sound]
	if options.is_empty():
		push_warning("Missing sound: %s" % sound)
		return null
	return options[randi() % options.size()]
