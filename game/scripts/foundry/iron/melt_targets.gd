class_name MeltTargets
## Where poured melt lands. Crucible, ladle and cupola tap all pour the same
## way: a ray from the lip finds the impact point, and the first receiver
## there takes the metal (mold box, mold line flask or its pouring box,
## bell pit, a ladle or a crucible standing below). Melt that lands on a
## worker turns them into a bronze buddy. Host only.


## Hands `litres` landing at `point` to whatever catches it. False if it
## spilled on the floor (sparks).
static func deliver(tree: SceneTree, point: Vector3, litres: float, temperature: float, mix: Dictionary, rate: float, delta: float,
		source: Node = null) -> bool:
	var mold := MoldBox.find_at(tree, point)
	if mold:
		mold.receive_metal(litres, temperature, mix, rate, delta)
		return true
	if MoldLine.deliver_at(tree, point, litres, temperature, mix, rate, delta):
		return true
	var pit := BellPit.find_at(tree, point)
	if pit:
		pit.receive_metal(litres, temperature, mix, rate, delta)
		return true
	var ladle := Ladle.find_at(tree, point)
	if ladle and ladle != source:
		ladle.receive(litres, temperature, mix)
		return true
	var crucible := _crucible_at(tree, point, source)
	if crucible:
		var taken := 0.0
		for metal in mix:
			taken += crucible.add_melt(metal, mix[metal])
		crucible.temperature = maxf(crucible.temperature, temperature)
		if taken < litres * 0.5:
			_spill(tree, point, mix, delta, source)
		return true
	_spill(tree, point, mix, delta, source)
	return false


## A crucible standing upright below the stream (not one being carried).
static func _crucible_at(tree: SceneTree, point: Vector3, source: Node) -> Crucible:
	for node in tree.get_nodes_in_group(&"crucibles"):
		var c := node as Crucible
		if c == source or c.is_held():
			continue
		var local := point - c.global_position
		if Vector2(local.x, local.z).length() < Crucible.RADIUS and local.y > -0.05 and local.y < Crucible.HEIGHT + 0.4:
			return c
	return null


static func _spill(tree: SceneTree, point: Vector3, mix: Dictionary, delta: float, source: Node) -> void:
	var world := tree.get_first_node_in_group(&"world") as GameWorld
	if world == null:
		return
	if randf() < delta * 1.5:
		FoundryFX.sparks(world, point, 6)
	for node in tree.get_nodes_in_group(&"players"):
		var p := node as Player
		if source and p.held == source:
			continue
		var local := point - p.global_position
		if Vector2(local.x, local.z).length() < 0.45 and local.y > 0.2 and local.y < 2.2:
			world.spawn_entity({type = "statue", pos = p.global_position, yaw = p.facing, pose = PlayerModel.panic_pose(),
				alloy = FoundryRules.alloy_for(mix)})
			world.popup_all(p.global_position + Vector3(0, 2.4, 0), "BRONZEFREUND!", Color("#ffb347"))
			FoundryFX.sparks(world, p.global_position + Vector3(0, 1.0, 0), 30)
			Sfx.play(&"statue_gong", p.global_position)
			p.teleport(world.respawn_point(p))
