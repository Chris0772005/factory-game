class_name Hammer
extends Item
## Sledgehammer for breaking molds open. Swing with the use button.

const REACH := 2.0

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


func _process(delta: float) -> void:
	if _swing >= 1.0:
		_head.swing()
	_swing = move_toward(_swing, 0.0, delta * 3.0)
