extends Node
## First-person screenshot of digging at the scrap heap (garage).

func _ready() -> void:
	SaveGame.disabled = true
	var world: GameWorld = load("res://scenes/garage.tscn").instantiate()
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var me := world.local_player()
	var pile: ScrapPile = get_tree().get_first_node_in_group(&"scrap_piles")
	world.upgrades.load_save(["magnet"])
	me.global_position = pile.global_position + Vector3(0.9, 0.05, 1.5)
	var to := pile.global_position - me.global_position
	me._camera_rig.yaw = atan2(to.x, to.z) + PI
	me._camera_rig.pitch = -0.42
	Input.action_press(&"interact")
	while true:
		await get_tree().physics_frame
		pile.interact_tick(me, 1.0 / 60.0 * 2.0)
