class_name BoomGate
extends Node3D
## The boom across the street where the quarter ends. People stay inside
## (the collider never opens); the pole lifts for the scrap truck.

const OPEN_RANGE := 13.0

var length := 6.0
var _pole: Node3D


func _ready() -> void:
	if not EnvMesh.visual():
		return
	var red := StandardMaterial3D.new()
	red.albedo_color = Color("#b8362c")
	red.roughness = 0.6
	var white := StandardMaterial3D.new()
	white.albedo_color = Color("#e6e1d4")
	white.roughness = 0.6
	var post := []
	post.append(EnvMesh.piece(EnvMesh.box(Vector3(0.3, 1.15, 0.3), 0.03), Transform3D(Basis(), Vector3(0, 0.575, -length * 0.5 - 0.2))))
	post.append(EnvMesh.piece(EnvMesh.box(Vector3(0.16, 0.9, 0.16)), Transform3D(Basis(), Vector3(0, 0.45, length * 0.5 + 0.1))))
	EnvMesh.add(self, EnvMesh.merge(post), white)
	_pole = Node3D.new()
	_pole.position = Vector3(0, 1.0, -length * 0.5 - 0.2)
	add_child(_pole)
	var reds := []
	var whites := []
	var n := int(length / 0.6)
	for i in n:
		var piece := EnvMesh.piece(EnvMesh.box(Vector3(0.09, 0.12, (length + 0.3) / n)), Transform3D(Basis(), Vector3(0, 0, (i + 0.5) * (length + 0.3) / n)))
		if i % 2 == 0:
			reds.append(piece)
		else:
			whites.append(piece)
	EnvMesh.add(_pole, EnvMesh.merge(reds), red)
	EnvMesh.add(_pole, EnvMesh.merge(whites), white)


func _process(delta: float) -> void:
	if _pole == null:
		return
	var open := false
	for node in get_tree().get_nodes_in_group(ScrapTruck.GROUP):
		if (node as ScrapTruck).busy() and (node as Node3D).global_position.distance_to(global_position) < OPEN_RANGE:
			open = true
	_pole.rotation.x = lerp_angle(_pole.rotation.x, -1.35 if open else 0.0, 1.0 - exp(-3.5 * delta))
