extends GameWorld
## Gameplay sandbox: walk around, grab, carry and throw physics objects,
## and carry a heavy crate or pane together.

var player: Player:
	get:
		return local_player()


func build_level() -> void:
	WorldBuilder.add_environment(self)
	WorldBuilder.add_floor(self)
	for i in range(-4, 5):
		WorldBuilder.add_belt(self, Vector3(i, 0, -4), 0.0)
	if not Network.is_sim_authority():
		return
	var colors := [Color("#f7d046"), Color("#ef6b4f"), Color("#4fa3a5"), Color("#9b6fd1")]
	for i in 12:
		spawn_item(&"crate", colors[i % colors.size()], Vector3.ONE * 0.45, 0.5,
			Vector3(-2.0 + (i % 6) * 0.8, 0.3 + (i / 6) * 0.5, 2.0))
	spawn_item(&"pane", Color("#bfe6f2"), Vector3(2.4, 1.6, 0.08), 14.0, Vector3(3.5, 0.85, 2.5))
