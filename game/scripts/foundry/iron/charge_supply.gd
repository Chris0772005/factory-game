class_name ChargeSupply
extends Node3D
## Where furnace charges come from in the Eisenhalle: the heap of broken
## cast iron (free, fill a basket) or the pallet of bell-bronze ingots
## (bought per stack). Using it hands the worker one ChargeBox.

## &"iron" or &"bronze" (ChargeBox.LOOKS).
@export var look := &"iron"
## Price of one charge; 0 = free.
@export var price := 0


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_to_group(&"interactable")
	if look == &"bronze":
		StationKit.box_collider(self, Vector3(1.2, 0.8, 1.0), Transform3D(Basis(), Vector3(0, 0.4, 0)))
	else:
		var core := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.9
		cyl.height = 0.5
		shape.shape = cyl
		shape.position.y = 0.25
		core.add_child(shape)
		add_child(core)
	_build_art()


func interact_point() -> Vector3:
	return global_position + Vector3(0, 0.6, 0)


func hint(_player: Node) -> String:
	var info: Dictionary = ChargeBox.LOOKS[look]
	if price > 0:
		return "[F] %s kaufen · %d l · %d $" % [info.name, roundi(info.litres), price]
	return "[F] %s füllen · %d l Eisen" % [info.name, roundi(info.litres)]


func interact(player: Node) -> void:
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	if world == null or not Network.is_sim_authority():
		return
	if world.money < price:
		world.popup_all(interact_point() + Vector3(0, 0.8, 0), "Zu wenig Geld", Color("#ff6b5a"))
		return
	if price > 0:
		world.add_money(-price)
	var p := player as Player
	var box: Node = world.spawn_entity({type = "charge", look = String(look), pos = p._hand_target()})
	if box is Item:
		p.grab(box)
	Sfx.play(&"scrap_clatter" if look == &"iron" else &"pickup", interact_point(), -3.0)


func _build_art() -> void:
	if not StationKit.visual():
		return
	if look == &"bronze":
		PropKit.place(self, "kaykit_hexagon/pallet.gltf", Vector3.ZERO, 0.0, {solid = PropKit.Solid.NONE, scale = 1.05})
		for i in 4:
			var stack := Node3D.new()
			stack.position = Vector3(-0.27 + (i % 2) * 0.54, 0.14 + (i / 2) * 0.25, -0.12 + (i % 2) * 0.05)
			stack.rotation.y = [0.05, -0.08, 0.1, -0.04][i]
			add_child(stack)
			ChargeBox.build_ingots(stack, i)
		StationKit.label(self, "GLOCKENBRONZE · %d $" % price, Transform3D(Basis(), Vector3(0, 0.16, 0.6)), 64, Color("#f0e2c4"), 800, 0.0012)
		return
	# Heap of broken castings with two filled baskets leaning on it.
	var iron := StationKit.metal("cast_iron_scrap", {steel_color = Color("#5a514b"), rust = 0.85, dents = 0.5, metallic_steel = 0.35, roughness_steel = 0.8})
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var chunks := []
	for i in 46:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * 0.95
		var h := (1.0 - d / 0.95) * 0.5
		chunks.append(EnvMesh.piece(StationKit.chunk(rng.randf_range(0.09, 0.19), i, 0.55, 0.5),
			Transform3D(Basis.from_euler(Vector3(rng.randf() * 3.0, rng.randf() * 3.0, 0)), Vector3(sin(a) * d, 0.05 + h * rng.randf_range(0.6, 1.0), cos(a) * d))))
	# A few recognisable pieces: a gear segment, a pipe flange, a manhole lid.
	chunks.append(EnvMesh.piece(EnvMesh.cylinder(0.32, 0.32, 0.05, 16), Transform3D(Basis(Vector3.RIGHT, 0.5), Vector3(0.55, 0.28, 0.4))))
	chunks.append(EnvMesh.piece(EnvMesh.cylinder(0.12, 0.12, 0.3, 10), Transform3D(Basis(Vector3.BACK, 1.2), Vector3(-0.5, 0.2, 0.3))))
	StationKit.add_merged(self, chunks, iron)
	for i in 2:
		var b := Node3D.new()
		b.position = Vector3(-0.95 + i * 1.9, 0, 0.55)
		b.rotation.y = [0.3, -0.4][i]
		add_child(b)
		ChargeBox.build_basket(b, 40 + i)
	StationKit.label(self, "GUSSBRUCH", Transform3D(Basis(), Vector3(0, 0.12, 1.05)), 64, Color("#f0e2c4"), 800, 0.0012)
