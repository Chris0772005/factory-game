class_name Hammer
extends Item
## Sledgehammer for breaking molds open. Swing with the use button.

const REACH := 2.0
## Carried upright by the handle at the hips, head up, just in front of the
## worker (instead of floating at head height); swings forward from there.
const CARRY_OFFSET := Vector2(0.6, 0.48)
## Where hands hold it: on the leather grip near the handle end (local).
const GRIP := Vector3(0.0, 0.15, 0.0)

var _head: HammerArt
var _swing := 0.0


static func create_hammer(data: Dictionary) -> Hammer:
	var h := Hammer.new()
	h.kind = &"hammer"
	h.mass = 2.5
	h.position = data.pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.14, 0.8, 0.14)
	shape.shape = box
	shape.position.y = 0.4
	h.add_child(shape)
	return h


func _ready() -> void:
	_head = HammerArt.new()
	add_child(_head)
	_head.build()


## Carry pose for Player._hand_target: (distance in front, height of the grip).
func carry_offset(_player: Node) -> Vector2:
	return CARRY_OFFSET


## Local point Player holds (instead of the point nearest its hands).
func hold_point() -> Vector3:
	return GRIP


## Global hand positions on the handle, following the swing (for hand IK).
func grip_points() -> Array[Vector3]:
	return _head.grip_points() if _head else []


## Picked up: stands upright in the hands (head up, facing the carrier) and
## stays upright while carried. Runs where physics is simulated (host).
func on_grabbed(by: Node) -> void:
	super(by)
	var yaw := (by as Node3D).global_rotation.y if by is Node3D else global_rotation.y
	global_basis = Basis(Vector3.UP, yaw)
	angular_velocity = Vector3.ZERO
	axis_lock_angular_x = true
	axis_lock_angular_z = true


func on_released(by: Node) -> void:
	super(by)
	if not is_held():
		axis_lock_angular_x = false
		axis_lock_angular_z = false


func held_hint(_player: Node) -> String:
	return "[F] Zuschlagen"


func use_start(player: Node) -> void:
	_swing = 1.0
	Sfx.play(&"pickup", global_position, -8.0)
	var target := MoldBox.find_at(get_tree(), (player as Node3D).global_position + (player as Node3D).global_transform.basis.z * 1.0)
	if target == null:
		for node in get_tree().get_nodes_in_group(&"molds"):
			if (node as Node3D).global_position.distance_to((player as Node3D).global_position) < REACH:
				target = node
	if target:
		target.hit(true)
	if Network.is_online():
		_swing_fx.rpc()


@rpc("authority", "call_remote", "unreliable")
func _swing_fx() -> void:
	_swing = 1.0


func _physics_process(delta: float) -> void:
	if _swing >= 1.0:
		_head.swing()
	_swing = move_toward(_swing, 0.0, delta * 3.0)
