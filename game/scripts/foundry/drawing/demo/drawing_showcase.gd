extends Node3D
## Showcase: sample drawings built into cast reliefs, lying in the sand of a
## freshly opened flask.

## [albedo, roughness, metallic]. Yellow metals stay a bit less metallic so the
## blue sky reflection does not turn their tops olive.
const METALS := {
	bronze = [Color("#b8642c"), 0.36, 0.85],
	brass = [Color("#e0b24a"), 0.32, 0.7],
	alu = [Color("#d3d7dd"), 0.42, 0.85],
	gold = [Color("#ffc23a"), 0.26, 0.68],
}
const SAND := Color("#4b4039")
const WOOD := Color("#8a5a3b")
const BED_SIZE := Vector2(1.9, 1.56)
const BED_TOP := 0.06


func _ready() -> void:
	WorldBuilder.add_environment(self)
	WorldBuilder.add_floor(self)
	_add_flask()
	var pieces := [
		[DrawingSamples.smiley(), &"gold", Vector3(-0.44, 0, -0.36), -0.15],
		[DrawingSamples.letter_b(), &"bronze", Vector3(0.44, 0, -0.36), 0.12],
		[DrawingSamples.star(), &"brass", Vector3(-0.44, 0, 0.38), 0.25],
		[DrawingSamples.cat(), &"alu", Vector3(0.44, 0, 0.38), -0.08],
	]
	for p in pieces:
		_add_cast(p[0], p[1], p[2], p[3])
	var cam := Camera3D.new()
	cam.fov = 36
	add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 1.62, 1.5), Vector3(0, 0.02, 0.05))
	cam.add_child(OutlinePass.create())


## A low wooden frame filled with dark moulding sand.
func _add_flask() -> void:
	var bed: MeshInstance3D = WorldBuilder.add_box(self, Vector3(BED_SIZE.x, BED_TOP, BED_SIZE.y), Vector3(0, BED_TOP * 0.5, 0), SAND)
	bed.material_override = WorldBuilder.material(SAND, 1.0)
	var t := 0.09
	var h := BED_TOP + 0.05
	for z in [-1.0, 1.0]:
		WorldBuilder.add_box(self, Vector3(BED_SIZE.x + t * 2.0, h, t), Vector3(0, h * 0.5, z * (BED_SIZE.y + t) * 0.5), WOOD)
	for x in [-1.0, 1.0]:
		WorldBuilder.add_box(self, Vector3(t, h, BED_SIZE.y), Vector3(x * (BED_SIZE.x + t) * 0.5, h * 0.5, 0), WOOD)


func _add_cast(drawing: Drawing, metal: StringName, pos: Vector3, yaw: float) -> void:
	var res := CastMeshBuilder.build(drawing, 0.6, 0.08)
	var mi := MeshInstance3D.new()
	mi.mesh = res.mesh
	mi.material_override = _metal(metal)
	mi.position = pos + Vector3(0, BED_TOP + 0.04, 0)
	mi.rotation.y = yaw
	add_child(mi)
	print("%s: area %.3f m², volume %.2f l, %d shapes" % [metal, res.area, res.volume * 1000.0, res.shapes.size()])


func _metal(id: StringName) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = METALS[id][0]
	m.roughness = METALS[id][1]
	m.metallic = METALS[id][2]
	return m
