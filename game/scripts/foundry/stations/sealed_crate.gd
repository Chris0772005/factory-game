class_name SealedCrate
extends Item
## A nailed-shut crate from the scrapyard with an unknown mix of metal. Throw
## it into the furnace: it burns open and melts in as one charge. What it
## was shows only in the casting (the alloy), except that gold glints as it
## goes in. The contents id lives on the host only.

const SIZE := Vector3(0.42, 0.36, 0.42)

var contents := &"cable"


static func create_crate(data: Dictionary) -> SealedCrate:
	var c := SealedCrate.new()
	c.kind = &"sealed_crate"
	c.mass = 6.0
	c.position = data.pos
	c.contents = StringName(data.get("contents", "cable"))
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SIZE
	shape.shape = box
	shape.position.y = SIZE.y * 0.5
	c.add_child(shape)
	c.physics_material_override = PhysicsMaterial.new()
	c.physics_material_override.friction = 0.9
	return c


func _ready() -> void:
	if not StationKit.visual():
		return
	var wood := StationKit.wood("sealed_crate", {base_color = Color("#a8825a"), grain_color = Color("#6d4c32"),
		weathering = 0.35, variation = 0.18})
	var iron := StationKit.metal("crate_bands", {steel_color = Color("#3b3937"), rust = 0.7, metallic_steel = 0.5, roughness_steel = 0.6})
	var boards := []
	var h := SIZE.y
	# Four side boards per face, a lid of three planks, corner battens.
	for face in 4:
		var basis := Basis(Vector3.UP, face * PI * 0.5)
		for k in 3:
			var y := 0.06 + k * (h - 0.06) / 3.0 + (h - 0.06) / 6.0
			boards.append(EnvMesh.piece(EnvMesh.box(Vector3(SIZE.x - 0.02, (h - 0.06) / 3.0 - 0.012, 0.022), 0.004),
				Transform3D(basis, basis * Vector3(0, y, SIZE.z * 0.5 - 0.011)), float(face * 3 + k) * 0.37, Vector3.RIGHT))
		boards.append(EnvMesh.piece(EnvMesh.box(Vector3(0.05, h, 0.05), 0.006), Transform3D(basis, basis * Vector3(SIZE.x * 0.5 - 0.025, h * 0.5, SIZE.z * 0.5 - 0.025))))
	for k in 3:
		boards.append(EnvMesh.piece(EnvMesh.box(Vector3(SIZE.x, 0.025, SIZE.z / 3.0 - 0.01), 0.004),
			Transform3D(Basis(), Vector3(0, h - 0.0125, -SIZE.z / 3.0 + k * SIZE.z / 3.0)), 3.1 + k, Vector3.RIGHT))
	boards.append(EnvMesh.piece(EnvMesh.box(SIZE - Vector3(0.04, 0.3, 0.04), 0.004), Transform3D(Basis(), Vector3(0, 0.03, 0))))
	StationKit.add_merged(self, boards, wood)
	var bands := []
	for y: float in [0.08, h - 0.08]:
		bands.append(EnvMesh.piece(EnvMesh.box(Vector3(SIZE.x + 0.012, 0.03, SIZE.z + 0.012), 0.004), Transform3D(Basis(), Vector3(0, y, 0))))
	StationKit.add_merged(self, bands, iron)
	# Stencilled "?" on two faces and a red wax seal on the lid.
	for face in 2:
		var basis := Basis(Vector3.UP, face * PI * 0.5)
		StationKit.label(self, "?", Transform3D(basis, basis * Vector3(0, h * 0.5, SIZE.z * 0.5 + 0.004)), 220, Color(0.15, 0.09, 0.05, 0.85), 900, 0.0012)
	var wax := StandardMaterial3D.new()
	wax.albedo_color = Color("#a3262a")
	wax.roughness = 0.35
	var seal := MeshInstance3D.new()
	seal.mesh = EnvMesh.cylinder(0.045, 0.05, 0.015, 12)
	seal.material_override = wax
	seal.position = Vector3(0.08, h + 0.005, 0.07)
	add_child(seal)


## Litres of metal per kind for the furnace (one charge).
func melt_mix() -> Dictionary:
	var info: Dictionary = FoundryRules.CRATES.get(contents, FoundryRules.CRATES[&"cable"])
	return (info.mix as Dictionary).duplicate()


## Burning open in the furnace: a puff of smoke, and gold glints.
func on_melted(furnace: Node3D) -> void:
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	if world == null:
		return
	var top := furnace.global_position + Vector3(0, 1.4, 0)
	if melt_mix().has(&"gold"):
		world.popup_all(top, "Da glitzert was… ✨", Color("#ffcf3f"))
	else:
		world.popup_all(top, "Was war da wohl drin?", UITheme.ACCENT)


func held_hint(_player: Node) -> String:
	return "Versiegelte Kiste – in den Ofen werfen   [RMB] Werfen"
