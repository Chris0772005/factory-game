class_name FirstPersonHands
extends Node3D
## The local worker's two gloved hands in first person, parented to the
## lens. They rest low at the edges of the view, come up and together when
## something is carried, jab forward on a use, and scoop in turns while F is
## held at a station (digging, cranking). Pure presentation, local only.

const REST := Vector3(0.3, -0.34, -0.55)
const CARRY := Vector3(0.2, -0.24, -0.6)

var player: Player
var _hands: Array[Node3D] = []
var _jab := 0.0
var _work := 0.0
var _phase := 0.0
var _was_using := false


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var leather := StationKit.leather("fp_glove", {})
	var cuff := StationKit.leather("fp_cuff", {})
	for side: float in [-1.0, 1.0]:
		var hand := Node3D.new()
		add_child(hand)
		_hands.append(hand)
		# Mitten-like work glove: palm, thumb, cuff, a bit of sleeve.
		StationKit.add(hand, EnvMesh.box(Vector3(0.1, 0.05, 0.14), 0.022), leather, Transform3D(Basis(), Vector3(0, 0, -0.05)), false)
		StationKit.add(hand, EnvMesh.box(Vector3(0.035, 0.035, 0.07), 0.015), leather,
			Transform3D(Basis(Vector3.UP, -side * 0.6), Vector3(-side * 0.06, 0.0, -0.03)), false)
		StationKit.add(hand, EnvMesh.cylinder(0.05, 0.058, 0.09, 12), cuff, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, 0.055)), false)
		var sleeve := StandardMaterial3D.new()
		sleeve.albedo_color = player.color.darkened(0.15) if player else Color("#3e7bd6")
		sleeve.roughness = 0.9
		StationKit.add(hand, EnvMesh.cylinder(0.05, 0.062, 0.3, 12), sleeve, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, -0.01, 0.24)), false)


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var using := Input.is_action_pressed(&"interact") and not player.ui_locked
	if using and not _was_using:
		_jab = 1.0
	_was_using = using
	_jab = move_toward(_jab, 0.0, delta * 5.0)
	var working := using and not player.holding and player.nearest_interactable() != null
	_work = move_toward(_work, 1.0 if working else 0.0, delta * 6.0)
	_phase += delta * 9.0
	var carry := 1.0 if player.holding else 0.0
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var base := REST.lerp(CARRY, carry)
		var pos := Vector3(base.x * side, base.y, base.z)
		pos.z -= sin(_jab * PI) * 0.16 * (1.0 - _work)
		# Scooping: the hands take turns reaching down and forward.
		var s := sin(_phase + (PI if i == 1 else 0.0))
		pos += Vector3(0, -0.05 + s * 0.07, -0.12 - s * 0.1) * _work
		var hand := _hands[i]
		hand.position = hand.position.lerp(pos, 1.0 - exp(-18.0 * delta))
		hand.rotation = Vector3(0.25 + _work * (0.5 + s * 0.3), side * 0.25, -side * 0.2)
