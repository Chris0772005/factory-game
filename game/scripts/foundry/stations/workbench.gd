class_name Workbench
extends Node3D
## The workbench in the back of the hall: the side business. Scrap from the
## bucket becomes crude weapons (FoundryRules.RECIPES), which go back into
## the bucket as hot goods for the pawnbroker. [F] with the bucket at the
## bench builds everything the load allows.

const GROUP := &"workbenches"
const SIZE := Vector3(2.4, 0.95, 0.8)
const USE_RANGE := 3.0


func _init() -> void:
	name = "Workbench"


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_to_group(GROUP)
	add_to_group(&"interactable")
	StationKit.box_collider(self, SIZE, Transform3D(Basis(), Vector3(0, SIZE.y * 0.5, 0)))
	_build_art()


func interact_point() -> Vector3:
	return global_position + Vector3(0, SIZE.y, 0)


func in_reach(player: Node3D) -> bool:
	return interact_point().distance_to(player.global_position + Vector3(0, 0.9, 0)) < USE_RANGE


func hint(_player: Node) -> String:
	return "Werkbank · Eimer herbringen und [F]: Waffen aus Schrott basteln"


func interact(_player: Node) -> void:
	pass


## What `contents` allows to build, greedily in recipe order: {made = [kinds], rest = [kinds]}.
static func plan(contents: Array) -> Dictionary:
	var rest := contents.duplicate()
	var made := []
	for recipe: Dictionary in FoundryRules.RECIPES:
		while true:
			var probe := rest.duplicate()
			var ok := true
			for need: StringName in recipe.needs:
				var at := probe.find(need)
				if at < 0:
					ok = false
					break
				probe.remove_at(at)
			if not ok:
				break
			rest = probe
			made.append(recipe.makes)
	return {made = made, rest = rest}


## What F with `bucket` would do, for the hint.
func bucket_hint(bucket: ScrapBucket) -> String:
	var made: Array = plan(bucket.contents).made if Network.is_sim_authority() else []
	if made.is_empty():
		return "Werkbank: dafür fehlen Teile (z. B. 2× Altblech = Blechklinge)" if Network.is_sim_authority() else "[F] Basteln"
	var names := {}
	for k: StringName in made:
		var n: String = FoundryRules.HOT[k].name
		names[n] = int(names.get(n, 0)) + 1
	var parts := PackedStringArray()
	for n: String in names:
		parts.append("%d× %s" % [names[n], n])
	return "[F] Basteln: %s" % ", ".join(parts)


## Host: builds everything the bucket's load allows; the weapons go back in.
func craft(bucket: ScrapBucket) -> int:
	var result := plan(bucket.contents)
	var made: Array = result.made
	if made.is_empty():
		return 0
	var out: Array[StringName] = []
	for k: StringName in result.rest:
		out.append(k)
	for k: StringName in made:
		out.append(k)
	bucket.contents = out
	bucket._changed()
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	if world:
		world.popup_all(interact_point() + Vector3(0, 0.5, 0), "%d Waffe%s gebastelt" % [made.size(), "" if made.size() == 1 else "n"], UITheme.BAD)
	Missions.report(get_tree(), &"craft", made.size())
	if Network.is_online():
		_fx.rpc()
	else:
		_fx()
	return made.size()


@rpc("authority", "call_local", "reliable")
func _fx() -> void:
	Sfx.play(&"hammer_clank", interact_point(), -2.0, 0.1)
	FoundryFX.sparks(get_parent(), interact_point() + Vector3(0, 0.1, 0), 10)


## Faces +Z: heavy timber bench, a vise, a pegboard with outlines behind it.
func _build_art() -> void:
	if not StationKit.visual():
		return
	var wood := StationKit.wood("workbench", {base_color = Color("#6b5038"), weathering = 0.5})
	var steel := StationKit.metal("workbench_steel", {steel_color = Color("#4a4f54"), rust = 0.3, metallic_steel = 0.7, roughness_steel = 0.45})
	var timber := []
	timber.append(EnvMesh.piece(EnvMesh.box(Vector3(SIZE.x, 0.09, SIZE.z), 0.01), Transform3D(Basis(), Vector3(0, SIZE.y - 0.045, 0))))
	timber.append(EnvMesh.piece(EnvMesh.box(Vector3(SIZE.x - 0.2, 0.04, SIZE.z - 0.15)), Transform3D(Basis(), Vector3(0, 0.25, 0))))
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			timber.append(EnvMesh.piece(EnvMesh.box(Vector3(0.1, SIZE.y - 0.09, 0.1)), Transform3D(Basis(), Vector3(x * (SIZE.x * 0.5 - 0.1), (SIZE.y - 0.09) * 0.5, z * (SIZE.z * 0.5 - 0.1)))))
	timber.append(EnvMesh.piece(EnvMesh.box(Vector3(SIZE.x, 1.1, 0.04)), Transform3D(Basis(), Vector3(0, SIZE.y + 0.6, -SIZE.z * 0.5 + 0.02))))
	StationKit.add_merged(self, timber, wood)
	var iron := []
	# Vise.
	iron.append(EnvMesh.piece(EnvMesh.box(Vector3(0.22, 0.12, 0.3), 0.02), Transform3D(Basis(), Vector3(-0.8, SIZE.y + 0.06, 0.18))))
	for z: float in [0.08, 0.3]:
		iron.append(EnvMesh.piece(EnvMesh.box(Vector3(0.24, 0.16, 0.05), 0.01), Transform3D(Basis(), Vector3(-0.8, SIZE.y + 0.2, z))))
	iron.append(EnvMesh.piece(EnvMesh.cylinder(0.015, 0.015, 0.34, 8), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(-0.8, SIZE.y + 0.1, 0.42))))
	# Tools on the board: hammer, saw blade, files.
	iron.append(EnvMesh.piece(EnvMesh.box(Vector3(0.05, 0.4, 0.03)), Transform3D(Basis(Vector3.BACK, 0.2), Vector3(0.2, SIZE.y + 0.7, -SIZE.z * 0.5 + 0.06))))
	iron.append(EnvMesh.piece(EnvMesh.box(Vector3(0.2, 0.09, 0.07)), Transform3D(Basis(Vector3.BACK, 0.2), Vector3(0.16, SIZE.y + 0.9, -SIZE.z * 0.5 + 0.07))))
	iron.append(EnvMesh.piece(EnvMesh.box(Vector3(0.6, 0.12, 0.01)), Transform3D(Basis(Vector3.BACK, -0.1), Vector3(0.75, SIZE.y + 0.75, -SIZE.z * 0.5 + 0.05))))
	for i in 3:
		iron.append(EnvMesh.piece(EnvMesh.box(Vector3(0.03, 0.34, 0.012)), Transform3D(Basis(), Vector3(-0.45 + i * 0.1, SIZE.y + 0.72, -SIZE.z * 0.5 + 0.05))))
	# What lies on the bench.
	iron.append(EnvMesh.piece(EnvMesh.cylinder(0.025, 0.025, 0.5, 10), Transform3D(Basis(Vector3.BACK, PI * 0.5) * Basis(Vector3.RIGHT, 0.3), Vector3(0.5, SIZE.y + 0.03, 0.1))))
	iron.append(EnvMesh.piece(EnvMesh.box(Vector3(0.32, 0.012, 0.2)), Transform3D(Basis(Vector3.UP, 0.4), Vector3(0.0, SIZE.y + 0.01, 0.12))))
	StationKit.add_merged(self, iron, steel)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("#ffd9a0")
	lamp.light_energy = 1.4
	lamp.omni_range = 4.0
	lamp.position = Vector3(0, SIZE.y + 1.3, 0.3)
	add_child(lamp)
