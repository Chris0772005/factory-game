class_name Hammer
extends Item
## Sledgehammer for breaking molds open. Swing with the use button.

const REACH := 2.0

var _head: Node3D
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
	_head = Node3D.new()
	add_child(_head)
	WorldBuilder.add_box(_head, Vector3(0.06, 0.75, 0.06), Vector3(0, 0.37, 0), Color("#a87a4f"))
	WorldBuilder.add_box(_head, Vector3(0.32, 0.14, 0.16), Vector3(0, 0.78, 0), Color("#4b5058"))


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
	_swing = move_toward(_swing, 0.0, delta * 3.0)
	_head.rotation.x = sin(_swing * PI) * 1.4
