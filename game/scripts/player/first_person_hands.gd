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
		# Work glove: padded palm, four curled fingers, thumb, flared cuff, sleeve.
		var glove := [EnvMesh.piece(MachineArt.loft([[-0.105, 0.08, 0.026, 0.0, -0.002, 3.0], [-0.07, 0.094, 0.036, 0.0, 0.0, 3.2], [-0.02, 0.09, 0.042, 0.0, 0.0, 3.0],
			[0.02, 0.074, 0.046, 0.0, 0.0, 2.6], [0.04, 0.06, 0.044, 0.0, 0.0, 2.4]], 18), Transform3D())]
		for k in 4:
			var x := (k - 1.5) * 0.0225
			var reach := 0.0 if k == 1 or k == 2 else 0.012
			glove.append(EnvMesh.piece(MachineArt.loft([[-0.19 + reach, 0.011, 0.01, x, -0.034, 2.4], [-0.178 + reach, 0.019, 0.017, x, -0.027, 2.6],
				[-0.145 + reach * 0.5, 0.0215, 0.02, x, -0.011, 2.8], [-0.095, 0.022, 0.023, x, -0.001, 2.8]], 12), Transform3D()))
		glove.append(EnvMesh.piece(MachineArt.loft([[-0.085, 0.012, 0.012, 0.0, -0.012, 2.4], [-0.07, 0.022, 0.02, 0.0, -0.008, 2.6], [-0.03, 0.026, 0.024, 0.0, 0.0, 2.8],
			[0.0, 0.03, 0.028, 0.0, 0.0, 2.6]], 12), Transform3D(Basis(Vector3.UP, side * 0.5), Vector3(-side * 0.045, -0.008, -0.035))))
		# Knuckle pad across the back of the hand.
		glove.append(EnvMesh.piece(MachineArt.loft([[-0.095, 0.08, 0.012, 0.0, 0.016, 3.0], [-0.075, 0.086, 0.016, 0.0, 0.019, 3.0], [-0.055, 0.08, 0.012, 0.0, 0.018, 3.0]], 14), Transform3D()))
		StationKit.add_merged(hand, glove, leather, false)
		StationKit.add(hand, StationKit.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.036, 0), Vector2(0.04, 0.012), Vector2(0.05, 0.06), Vector2(0.057, 0.085), Vector2(0.06, 0.09),
			Vector2(0.057, 0.097), Vector2(0.05, 0.097), Vector2(0, 0.09)]), 18, 50.0), cuff, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, 0.025)), false)
		var sleeve := StandardMaterial3D.new()
		sleeve.albedo_color = player.color.darkened(0.15) if player else Color("#3e7bd6")
		sleeve.roughness = 0.9
		StationKit.add(hand, StationKit.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.046, 0), Vector2(0.05, 0.05), Vector2(0.047, 0.1), Vector2(0.054, 0.16), Vector2(0.052, 0.22),
			Vector2(0.06, 0.32), Vector2(0, 0.32)]), 16, 50.0), sleeve, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, -0.004, 0.1)), false)

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
