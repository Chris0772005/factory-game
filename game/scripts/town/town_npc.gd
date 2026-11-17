class_name TownNpc
extends Node3D
## Somebody who stands in one of the town's houses: the pawnbroker behind his
## counter, the officer at the police desk. The worker rig in other clothes,
## idling. Faces +Z.

var suit := Color("#4a4f58")
var hat := false
var _model: PlayerModel


static func make(suit_color: Color, with_hat: bool) -> TownNpc:
	var npc := TownNpc.new()
	npc.suit = suit_color
	npc.hat = with_hat
	return npc


func _ready() -> void:
	_model = dressed(self, suit, hat)


## A worker model in street clothes (no leather apron; the helmet in the
## colour of the clothes only if `with_hat`) as a child of `parent`.
static func dressed(parent: Node3D, suit_color: Color, with_hat := true) -> PlayerModel:
	var model := PlayerModel.new()
	model.suit_color = suit_color
	parent.add_child(model)
	# Cloth cuffs and black shoes instead of the worker's leather trim.
	if model._outfit:
		model._outfit.set_shader_parameter(&"trim_tint", suit_color.lerp(Color.BLACK, 0.35))
		model._outfit.set_shader_parameter(&"glove_color", Color("#1d1d21"))
		model._outfit.set_shader_parameter(&"boot_color", Color("#17171a"))
	for part: String in ["Apron"] if with_hat else ["Apron", "HardHat"]:
		var node := model.find_child(part, true, false) as Node3D
		if node:
			node.visible = false
	return model


func _physics_process(delta: float) -> void:
	if _model:
		_model.animate(delta, Vector3.ZERO, true, false, Vector3.ZERO)
