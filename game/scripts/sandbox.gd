extends Node3D
## Gameplay sandbox: walk around, grab, carry and throw physics objects,
## and test carrying a heavy pane together.

var player: Player


func _ready() -> void:
	WorldBuilder.add_environment(self)
	WorldBuilder.add_floor(self)
	for i in range(-4, 5):
		WorldBuilder.add_belt(self, Vector3(i, 0, -4), 0.0)
	var colors := [Color("#f7d046"), Color("#ef6b4f"), Color("#4fa3a5"), Color("#9b6fd1")]
	for i in 12:
		var item := Item.create(&"crate", colors[i % colors.size()], 0.45)
		item.position = Vector3(-3 + (i % 4) * 0.8, 0.3 + (i / 4) * 0.5, 2.0)
		add_child(item)
	var pane := Item.create(&"pane", Color("#bfe6f2"), 1.0)
	pane.mass = 14.0
	var shape := pane.get_child(0) as CollisionShape3D
	(shape.shape as BoxShape3D).size = Vector3(2.4, 1.6, 0.08)
	var mesh := pane.get_child(1) as MeshInstance3D
	mesh.mesh = MeshFactory.rounded_box(Vector3(2.4, 1.6, 0.08), 0.03)
	pane.position = Vector3(3.5, 0.85, 2.5)
	add_child(pane)
	player = Player.new()
	player.position = Vector3(0, 0.2, 5)
	player.facing = PI
	add_child(player)
