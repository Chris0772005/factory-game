class_name BronzeStatue
extends Item
## A worker who got caught in a pour, frozen in metal mid-panic, standing on the
## puddle of metal that set round their boots. Sellable.

const BASE_VALUE := 160
## The set puddle under the boots: radius and height (m); the worker stands on it.
const PLINTH_RADIUS := 0.45
const PLINTH_HEIGHT := 0.06
## Cast statues are a little rougher than polished castings, so the highlights
## on arms and legs never compete with molten metal (Art Bible rule 2).
const EXTRA_ROUGHNESS := 0.15
## The metal sets almost at once: a short, even glow that fades to polished
## bronze within COOL_TIME seconds (no dark crust – it must read as bronze, not lava).
const START_TEMPERATURE := 0.42
const COOL_TIME := 2.4

var pose := PackedFloat32Array()
var alloy := &"bronze"
var suit_color := Color.WHITE
var temperature := START_TEMPERATURE
var _materials: Array[ShaderMaterial] = []

static var _plinth: ArrayMesh


static func from_data(data: Dictionary) -> BronzeStatue:
	var s := BronzeStatue.new()
	s.kind = &"statue"
	s.mass = 6.0
	s.position = data.pos
	s.rotation.y = data.get("yaw", 0.0)
	s.pose = data.get("pose", PlayerModel.panic_pose())
	s.alloy = data.get("alloy", &"bronze")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.75, 1.9, 0.55)
	shape.shape = box
	shape.position.y = 0.95 + PLINTH_HEIGHT
	s.add_child(shape)
	var base := CollisionShape3D.new()
	var disc := CylinderShape3D.new()
	disc.radius = PLINTH_RADIUS
	disc.height = PLINTH_HEIGHT
	base.shape = disc
	base.position.y = PLINTH_HEIGHT * 0.5
	s.add_child(base)
	return s


func _ready() -> void:
	var model := PlayerModel.new()
	# Posed before it enters the tree: the rigged worker is built frozen, without
	# animation tree or IK; its skinned meshes keep this pose for good.
	model.apply_pose(pose)
	model.position.y = PLINTH_HEIGHT
	add_child(model)
	var plinth := MeshInstance3D.new()
	plinth.name = &"Plinth"
	plinth.mesh = _plinth_mesh()
	add_child(plinth)
	for mi in find_children("*", "MeshInstance3D", true, false):
		var mat := MetalMaterial.create(alloy)
		mat.set_shader_parameter(&"crust", 0.0)
		mat.set_shader_parameter(&"roughness", minf(float(mat.get_shader_parameter(&"roughness")) + EXTRA_ROUGHNESS, 1.0))
		MetalMaterial.set_temperature(mat, temperature)
		(mi as MeshInstance3D).material_override = mat
		_materials.append(mat)
	# The model animates itself; a statue must stay frozen.
	model.set_process(false)
	model.set_physics_process(false)


func _physics_process(delta: float) -> void:
	if temperature > 0.0:
		temperature = maxf(0.0, temperature - delta * START_TEMPERATURE / COOL_TIME)
		for m in _materials:
			MetalMaterial.set_temperature(m, temperature)


## Set puddle: a flat disc with a rounded, lobed rim where the metal ran out,
## plus a few splashes frozen round it. Shared by every statue.
static func _plinth_mesh() -> ArrayMesh:
	if _plinth:
		return _plinth
	var r := PLINTH_RADIUS
	var h := PLINTH_HEIGHT
	# Walked from the rim in to the centre, so StationKit.lathe faces it outwards.
	var profile := PackedVector2Array([Vector2(r, 0.0), Vector2(r * 0.995, h * 0.35), Vector2(r * 0.95, h * 0.7),
		Vector2(r * 0.84, h * 0.93), Vector2(r * 0.6, h), Vector2(0.0, h + 0.004)])
	var lobes := func(pos: Vector3, angle: float) -> Vector3:
		var k := 1.0 + 0.07 * sin(angle * 5.0 + 0.6) + 0.04 * sin(angle * 11.0 + 2.1) + 0.025 * sin(angle * 17.0)
		return Vector3(pos.x * k, pos.y, pos.z * k)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(StationKit.lathe(profile, 48, 60.0, lobes), 0, Transform3D())
	# Splashes: flattened drops just outside the rim.
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	for i in 7:
		var a := rng.randf() * TAU
		var d := r * rng.randf_range(1.05, 1.3)
		var size := rng.randf_range(0.03, 0.06)
		var drop := StationKit.lathe(PackedVector2Array([Vector2(size, 0.0), Vector2(size * 0.7, size * 0.28),
			Vector2(0.0, size * 0.35)]), 10, 60.0)
		st.append_from(drop, 0, Transform3D(Basis(), Vector3(sin(a) * d, 0.0, cos(a) * d)))
	_plinth = st.commit()
	return _plinth


func value() -> int:
	var mult: float = Alloys.TABLE.get(alloy, {}).get("value_mult", 1.0)
	return roundi(BASE_VALUE * mult)


func held_hint(_player: Node) -> String:
	return "Bronzefreund · %d $   [RMB] Werfen" % value()
