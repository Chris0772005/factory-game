class_name TownFigure
extends Node3D
## A townsperson: one of the Quaternius "Ultimate Modular Men/Women" figures
## (CC0, human proportions) moved by the walk, run and idle clips of the
## same rig family (Cyberpunk Game Kit character). Faces +Z.
## `animate()` picks idle, walk or run from the ground speed.

const DIR := "res://assets/models/quaternius/"
const ANIM_SOURCE := "res://assets/models/quaternius/Anim_Character.glb"
## Height of the head joint above the ground (m): the figure stands about 1.8 m.
const HEAD_JOINT := 1.56
const WALK_PACE := 1.5
const RUN_PACE := 4.6
const LOOPED: Array[StringName] = [&"Idle_Neutral", &"Walk", &"Run"]

static var _library: AnimationLibrary

## File name without extension (Swat, Suit, Worker, Casual, Casual_Woman).
var model := "Casual"
## Material name -> colour, to turn e.g. the Swat suit navy.
var recolor := {}
var _player: AnimationPlayer
var _clip := &""


static func make(model_name: String, colors := {}) -> TownFigure:
	var f := TownFigure.new()
	f.model = model_name
	f.recolor = colors
	return f


func _ready() -> void:
	var packed := load(DIR + model + ".glb") as PackedScene
	if packed == null:
		return
	var scene := packed.instantiate() as Node3D
	add_child(scene)
	var skeleton := scene.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		return
	var head := skeleton.find_bone("Head")
	if head >= 0:
		var y := (skeleton.global_transform * skeleton.get_bone_global_rest(head).origin).y - global_position.y
		if y > 0.01:
			scene.scale = Vector3.ONE * (HEAD_JOINT / y)
	if not recolor.is_empty():
		for node in scene.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			for s in mi.mesh.get_surface_count():
				var mat := mi.mesh.surface_get_material(s) as BaseMaterial3D
				if mat and recolor.has(mat.resource_name):
					var own := mat.duplicate() as BaseMaterial3D
					own.albedo_color = recolor[mat.resource_name]
					mi.set_surface_override_material(s, own)
	_player = AnimationPlayer.new()
	scene.add_child(_player)
	_player.add_animation_library(&"", _clips(skeleton))
	_play(&"Idle_Neutral")


## The shared clip library: the source's clips under plain names, without
## tracks for bones the figures do not have.
static func _clips(skeleton: Skeleton3D) -> AnimationLibrary:
	if _library:
		return _library
	_library = AnimationLibrary.new()
	var source := (load(ANIM_SOURCE) as PackedScene).instantiate()
	var from := source.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for full: StringName in from.get_animation_list():
		var short := StringName(String(full).get_slice("|", 1) if "|" in String(full) else String(full))
		var clip := from.get_animation(full).duplicate() as Animation
		for t in range(clip.get_track_count() - 1, -1, -1):
			var bone := String(clip.track_get_path(t).get_concatenated_subnames())
			if skeleton.find_bone(bone) < 0:
				clip.remove_track(t)
		clip.loop_mode = Animation.LOOP_LINEAR if short in LOOPED else Animation.LOOP_NONE
		_library.add_animation(short, clip)
	source.free()
	return _library


func _play(clip: StringName, speed := 1.0) -> void:
	if _player == null or not _player.has_animation(clip):
		return
	_player.speed_scale = speed
	if clip != _clip:
		_clip = clip
		_player.play(clip, 0.2)


## Called every physics frame by whoever moves the figure.
func animate(_delta: float, velocity: Vector3) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed < 0.15:
		_play(&"Idle_Neutral")
	elif speed < 2.6:
		_play(&"Walk", clampf(speed / WALK_PACE, 0.6, 1.6))
	else:
		_play(&"Run", clampf(speed / RUN_PACE, 0.7, 1.5))


## One-off gesture (Wave, Interact, Punch_Right ...).
func gesture(clip: StringName) -> void:
	if _player and _player.has_animation(clip):
		_clip = clip
		_player.speed_scale = 1.0
		_player.play(clip, 0.15)
		_player.queue(&"Idle_Neutral")
