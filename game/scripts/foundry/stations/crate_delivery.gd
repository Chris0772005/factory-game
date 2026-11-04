class_name CrateDelivery
extends Node3D
## Pallet of sealed scrapyard crates. Using it buys one (FoundryRules.CRATE_PRICE)
## and hands it to the worker; the contents are rolled on the host.

var _art: Node3D


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_to_group(&"interactable")
	StationKit.box_collider(self, Vector3(1.2, 0.9, 1.2), Transform3D(Basis(), Vector3(0, 0.45, 0)))
	if not StationKit.visual():
		return
	PropKit.place(self, "kaykit_hexagon/pallet.gltf", Vector3.ZERO, 0.0, {solid = PropKit.Solid.NONE, scale = 0.95})
	# Display stack: three crates on the pallet, one more on top, slightly askew.
	var spots := [Vector3(-0.27, 0.3, -0.25), Vector3(0.25, 0.3, -0.22), Vector3(-0.22, 0.3, 0.27), Vector3(-0.05, 0.66, -0.05)]
	for i in spots.size():
		var crate := SealedCrate.new()
		crate.freeze = true
		crate.position = spots[i]
		crate.rotation.y = [0.08, -0.12, 0.2, -0.35][i]
		add_child(crate)
		crate.collision_layer = 0
		crate.collision_mask = 0
	StationKit.label(self, "WERTSTOFFHOF-KISTEN",
		Transform3D(Basis(), Vector3(0, 0.2, 0.62)), 64, Color("#f0e2c4"), 800, 0.0012)


func interact_point() -> Vector3:
	return global_position + Vector3(0, 0.7, 0)


func hint(_player: Node) -> String:
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	return "[F] Versiegelte Kiste kaufen · %d $ (Inhalt: Überraschung)" % FoundryRules.crate_price(world)


func interact(player: Node) -> void:
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	if world == null or not Network.is_sim_authority():
		return
	var p := player as Player
	var price := FoundryRules.crate_price(world)
	if world.money < price:
		world.popup_all(interact_point() + Vector3(0, 0.8, 0), "Zu wenig Geld", Color("#ff6b5a"))
		return
	world.add_money(-price)
	var crate: Node = world.spawn_entity({type = "sealed_crate", pos = p._hand_target(), contents = String(FoundryRules.roll_crate())})
	if crate is Item:
		p.grab(crate)
	Sfx.play(&"pickup", interact_point(), -4.0)
