class_name TownNpc
extends Node3D
## Somebody who stands in one of the town's houses: the pawnbroker behind his
## counter, the officer at the police desk. A TownFigure that idles and now
## and then looks up. Faces +Z.

var _figure: TownFigure
var _next := 6.0


static func make(model: String, colors := {}) -> TownNpc:
	var npc := TownNpc.new()
	npc._figure = TownFigure.make(model, colors)
	return npc


func _ready() -> void:
	if _figure:
		add_child(_figure)
	_next = randf_range(4.0, 9.0)


## A wave of the arm, now (the auctioneer when he calls a bid).
func wave() -> void:
	if _figure:
		_figure.gesture(&"Wave")


func _physics_process(delta: float) -> void:
	if _figure == null:
		return
	_next -= delta
	if _next <= 0.0:
		_next = randf_range(9.0, 16.0)
		# A nod to whoever just came in.
		for node in get_tree().get_nodes_in_group(&"players"):
			if (node as Node3D).global_position.distance_to(global_position) < 5.0:
				_figure.gesture(&"Wave")
				break
