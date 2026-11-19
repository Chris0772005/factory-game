class_name ParkedVehicle
## A vehicle standing at the kerb: a finished model with the project's vehicle finish (clear panes,
## road dirt; docs/TECH_SPEC.md Modul Y), its lamps dark, and a box nobody walks through.

## "European Delivery Van" by Evan Hiltz, CC-BY-4.0 (tools/blender/van.py, see CREDITS.md).
const VAN := "res://assets/models/vehicles/delivery_van.glb"
## The bodies without mirrors (length, height, width), for the boxes.
const BODY := {VAN: Vector3(5.3, 2.5, 2.25)}


## Stands `model` (its nose along +X) on the ground at `at`, turned by `yaw` degrees; `finish` changes
## the dirt (VehicleFinish.apply). Returns the node (null headless).
static func place(set: Node3D, model: String, at: Vector3, yaw := 0.0, finish := {}) -> Node3D:
	var basis := Basis(Vector3.UP, deg_to_rad(yaw))
	var body: Vector3 = BODY[model]
	WorldBuilder.add_collider(set, body, Transform3D(basis, at + Vector3(0, body.y * 0.5, 0)))
	if not EnvMesh.visual():
		return null
	var packed := load(model) as PackedScene
	if packed == null:
		return null
	var node := packed.instantiate() as Node3D
	node.transform = Transform3D(basis, at)
	set.add_child(node)
	var dirt := {mud = 0.45, mud_height = 0.55, dust = 0.3}
	dirt.merge(finish, true)
	VehicleFinish.apply(node, dirt)
	# Parked: the lamps its maps would light stay dark.
	for part in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := (part as MeshInstance3D).mesh
		for s in mesh.get_surface_count() if mesh else 0:
			var mat := mesh.surface_get_material(s) as BaseMaterial3D
			if mat and mat.emission_enabled:
				mat.emission_enabled = false
	return node
