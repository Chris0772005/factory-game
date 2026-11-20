class_name ParkedVehicle
## A vehicle standing at the kerb: a finished model with the project's vehicle finish (clear panes,
## road dirt; docs/TECH_SPEC.md Modul Y), its lamps dark, and a box nobody walks through.

## "European Delivery Van" by Evan Hiltz, CC-BY-4.0 (tools/blender/van.py, see CREDITS.md).
const VAN := "res://assets/models/vehicles/delivery_van.glb"
## "Kiri '86", "Fairheaven LT '80" and "Fairheaven SW '84" by Daniel Zhabotinsky, CC-BY-4.0
## (tools/blender/cars.py, see CREDITS.md): a small saloon, a big one and an estate car.
const CAR_SMALL := "res://assets/models/vehicles/car_kiri86.glb"
const CAR_SALOON := "res://assets/models/vehicles/car_fairheaven_lt80.glb"
const CAR_ESTATE := "res://assets/models/vehicles/car_fairheaven_sw84.glb"
## The bodies without mirrors (length, height, width), for the boxes.
const BODY := {
	VAN: Vector3(5.3, 2.5, 2.25),
	CAR_SMALL: Vector3(4.3, 1.32, 1.76),
	CAR_SALOON: Vector3(5.0, 1.35, 1.83),
	CAR_ESTATE: Vector3(5.03, 1.4, 1.86),
}


## Stands `model` (its nose along +X) on the ground at `at`, turned by `yaw` degrees. `paint` (with
## alpha above 0) gives this one its own body colour, `finish` changes the dirt (VehicleFinish.apply).
## Returns the node (null headless).
static func place(set: Node3D, model: String, at: Vector3, yaw := 0.0, paint := Color(0, 0, 0, 0), finish := {}) -> Node3D:
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
	dress(node, model, paint, finish)
	return node


## The project's vehicle finish on a car or van that stands in the tree, on the ground, as it
## rests: road dirt up to the sills, the lamps dark (it is day), and for `paint` with alpha above
## 0 a body colour of its own. Also what TownTraffic's cars wear.
static func dress(node: Node3D, model: String, paint := Color(0, 0, 0, 0), finish := {}) -> void:
	# Less dirt on a low car than on the van.
	var dirt := {mud = 0.45, mud_height = 0.55, dust = 0.3} if model == VAN else {mud = 0.35, mud_height = 0.3, dust = 0.25}
	dirt.merge(finish, true)
	VehicleFinish.apply(node, dirt)
	for part in node.find_children("*", "MeshInstance3D", true, false):
		var mi := part as MeshInstance3D
		for s in mi.mesh.get_surface_count() if mi.mesh else 0:
			var mat := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if mat == null:
				continue
			# The lamps its maps would light stay dark.
			if mat.emission_enabled:
				mat.emission_enabled = false
			if paint.a > 0.0 and mat.resource_name.to_lower().contains("paint"):
				var own := mat.duplicate() as BaseMaterial3D
				own.albedo_color = Color(paint, 1.0)
				mi.set_surface_override_material(s, own)
