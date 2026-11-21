class_name TownFigure
extends Node3D
## A townsperson. Faces +Z. `animate()` picks standing, strolling, walking or running from the ground
## speed; `gesture()` plays a one-off clip.
##
## The people are generated figures of real-looking persons with their own skeleton and clips
## (AI-generated, see assets/models/people/NOTICE.txt; put together by tools/people.py;
## docs/TECH_SPEC.md, Modul Y). Callers name the kind of person (Worker, Suit, Swat, Patrol, Dealer,
## Casual, Casual_Woman, Cook, Granny, Mechanic, Clerk, Teller, Collector, Shopper): PEOPLE says who that is. Where a person's file is missing, a Quaternius
## figure stands in ("Ultimate Modular Men/Women", CC0: the one of that name, or the one STAND_INS
## names), moved by the clips of the same rig family and tinted by `recolor`.

const PEOPLE_DIR := "res://assets/models/people/"
const PEOPLE := {"Worker": "worker", "Suit": "broker", "Swat": "officer", "Patrol": "patrol", "Dealer": "dealer",
	"Casual": "youth", "Casual_Woman": "woman", "Cook": "cook", "Granny": "granny", "Mechanic": "mechanic",
	"Clerk": "clerk", "Teller": "teller", "Collector": "collector", "Shopper": "shopper"}
const STAND_INS := {"Patrol": "Swat", "Dealer": "Worker", "Cook": "Casual_Woman", "Granny": "Casual_Woman", "Mechanic": "Worker",
	"Clerk": "Worker", "Teller": "Casual_Woman", "Collector": "Suit", "Shopper": "Casual_Woman"}
const DIR := "res://assets/models/quaternius/"
const ANIM_SOURCE := "res://assets/models/quaternius/Anim_Character.glb"
## Stand-in figures: height of the head joint above the ground (m), the figure stands about 1.8 m.
const HEAD_JOINT := 1.56
const LOOPED: Array[StringName] = [&"Idle_Neutral", &"Stroll", &"Walk", &"Run"]
## Ground speed (m/s) each clip of the people is made for, at the height of the figure the shared
## clips come from (hips HIPS_REF above the ground): at that speed the standing foot does not slide.
## Measured from the clips (the foot's speed backwards while it stands).
const HIPS_REF := 0.965
const STROLL_PACE := 0.66
const WALK_PACE_PEOPLE := 1.3
const RUN_PACE_PEOPLE := 3.5
## The stand-ins' clips.
const WALK_PACE := 1.5
const RUN_PACE := 4.6

static var _library: AnimationLibrary

## Kind of person (a key of PEOPLE).
var model := "Casual"
## Stand-ins only: material name -> colour, to turn e.g. the Swat suit navy.
var recolor := {}
var _player: AnimationPlayer
var _clip := &""
## Paces of this figure's clips (m/s); the stroll is 0 where there is none.
var _stroll_pace := 0.0
var _walk_pace := WALK_PACE
var _run_pace := RUN_PACE
## Seconds a gesture still has to play before `animate` takes over again.
var _gesture_left := 0.0


static func make(model_name: String, colors := {}) -> TownFigure:
	var f := TownFigure.new()
	f.model = model_name
	f.recolor = colors
	return f


func _ready() -> void:
	var person := PEOPLE_DIR + String(PEOPLE.get(model, "")) + ".glb"
	if PEOPLE.has(model) and ResourceLoader.exists(person):
		_build_person(person)
	else:
		_build_stand_in()
	_play(&"Idle_Neutral")


## A generated person: the file brings its skeleton, its size and its clips.
func _build_person(path: String) -> void:
	var packed := load(path) as PackedScene
	if packed == null:
		return
	var scene := packed.instantiate() as Node3D
	add_child(scene)
	_player = scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _player == null:
		return
	for clip in LOOPED:
		if _player.has_animation(clip):
			_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	# A taller person covers more ground with the same clip.
	var size := 1.0
	var skeleton := scene.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton:
		var hips := skeleton.find_bone("Hips")
		if hips >= 0:
			size = (skeleton.global_transform * skeleton.get_bone_global_rest(hips).origin).y - global_position.y
			size = clampf(size / HIPS_REF, 0.8, 1.2)
	_stroll_pace = STROLL_PACE * size if _player.has_animation(&"Stroll") else 0.0
	_walk_pace = WALK_PACE_PEOPLE * size
	_run_pace = RUN_PACE_PEOPLE * size


func _build_stand_in() -> void:
	var packed := load(DIR + String(STAND_INS.get(model, model)) + ".glb") as PackedScene
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


## The stand-ins' shared clip library: the source's clips under plain names, without
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
		_player.play(clip, 0.25)


## Called every physics frame by whoever moves the figure.
func animate(delta: float, velocity: Vector3) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	if _gesture_left > 0.0:
		# A gesture is played out, unless the figure sets off meanwhile.
		_gesture_left -= delta
		if speed < 0.15:
			return
		_gesture_left = 0.0
	if speed < 0.15:
		_play(&"Idle_Neutral")
	elif _stroll_pace > 0.0 and speed < (_stroll_pace + _walk_pace) * 0.5:
		_play(&"Stroll", clampf(speed / _stroll_pace, 0.6, 1.5))
	elif speed < 2.6:
		_play(&"Walk", clampf(speed / _walk_pace, 0.6, 1.6))
	else:
		_play(&"Run", clampf(speed / _run_pace, 0.7, 1.9))


## One-off gesture (Wave; the stand-ins also know Interact, Punch_Right ...).
func gesture(clip: StringName) -> void:
	if _player and _player.has_animation(clip):
		_clip = clip
		_player.speed_scale = 1.0
		_player.play(clip, 0.2)
		_player.queue(&"Idle_Neutral")
		_gesture_left = _player.get_animation(clip).length
