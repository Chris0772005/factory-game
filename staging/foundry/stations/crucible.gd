class_name Crucible
extends Item
## Carryable melting pot. Sits in a furnace to collect melt; held near a mold,
## holding the use button tilts it and pours. Host simulates, peers mirror.

const CAPACITY := 3.0           ## litres of melt
const MAX_POUR_RATE := 0.9      ## litres per second at full tilt
const COOL_RATE := 0.035        ## temperature lost per second outside the furnace
const RADIUS := 0.22
const HEIGHT := 0.42

var amount := 0.0
var temperature := 0.0
var mix := {}                   ## metal id -> litres
var tilt := 0.0
var flow := 0.0
var docked_in: Node3D = null
var pour_target := Vector3.ZERO
## Direction the spout faces: follows whoever carries the crucible.
var pour_yaw := 0.0

var _pivot: Node3D
var _melt: MeshInstance3D
var _melt_mat: ShaderMaterial
var _stream: PourStream
var _pouring := false
var _sync_accum := 0.0


static func create_crucible(data: Dictionary) -> Crucible:
	var c := Crucible.new()
	c.kind = &"crucible"
	c.mass = 9.0
	c.position = data.pos
	# A pot full of molten metal stays upright; tilting is purely visual.
	c.axis_lock_angular_x = true
	c.axis_lock_angular_z = true
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = RADIUS
	cyl.height = HEIGHT
	shape.shape = cyl
	shape.position.y = HEIGHT * 0.5
	c.add_child(shape)
	return c


func _ready() -> void:
	add_to_group(&"crucibles")
	_pivot = Node3D.new()
	add_child(_pivot)
	var body := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = RADIUS
	mesh.bottom_radius = RADIUS * 0.82
	mesh.height = HEIGHT
	body.mesh = mesh
	body.material_override = WorldBuilder.material(Color("#4a4440"), 0.9)
	body.position.y = HEIGHT * 0.5
	_pivot.add_child(body)
	var rim := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = RADIUS - 0.03
	torus.outer_radius = RADIUS + 0.02
	rim.mesh = torus
	rim.material_override = WorldBuilder.material(Color("#2f2b29"), 0.8)
	rim.position.y = HEIGHT
	_pivot.add_child(rim)
	var spout := MeshInstance3D.new()
	spout.mesh = MeshFactory.rounded_box(Vector3(0.1, 0.05, 0.12), 0.02)
	spout.material_override = rim.material_override
	spout.position = Vector3(0, HEIGHT - 0.01, RADIUS + 0.03)
	_pivot.add_child(spout)
	_melt = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = RADIUS - 0.035
	disc.bottom_radius = RADIUS - 0.035
	disc.height = 0.02
	_melt.mesh = disc
	_melt_mat = MetalMaterial.create(&"alu")
	_melt.material_override = _melt_mat
	_pivot.add_child(_melt)
	_stream = PourStream.new()
	_stream.top_level = true
	add_child(_stream)
	_update_visuals()


func held_hint(_player: Node) -> String:
	if amount < 0.05:
		return "Leer – in den Ofen stellen"
	return "[F halten] Gießen  · %.1f l · %d °C" % [amount, roundi(200 + temperature * 1100)]


func use_start(_player: Node) -> void:
	_pouring = true


func use_end(_player: Node) -> void:
	_pouring = false


func use_tick(_player: Node, _delta: float) -> void:
	_pouring = true


func _physics_process(delta: float) -> void:
	if Network.is_sim_authority():
		_simulate(delta)
	_update_visuals()


func _simulate(delta: float) -> void:
	if not is_held():
		_pouring = false
	else:
		for p in get_tree().get_nodes_in_group(&"players"):
			if p.held == self:
				pour_yaw = p.facing
				break
	tilt = move_toward(tilt, 1.0 if _pouring else 0.0, delta * (1.1 if _pouring else 2.5))
	flow = clampf((tilt - 0.3) / 0.7, 0.0, 1.0) if amount > 0.0 else 0.0
	if docked_in == null and amount > 0.0:
		temperature = maxf(0.0, temperature - COOL_RATE * delta)
	if flow > 0.0:
		var out := minf(amount, flow * MAX_POUR_RATE * delta)
		_pour(out, flow * MAX_POUR_RATE, delta)
	if Network.is_online():
		_sync_accum += delta
		if _sync_accum >= 1.0 / 15.0:
			_sync_accum = 0.0
			_sync.rpc(amount, temperature, tilt, flow, alloy(), pour_target, pour_yaw)


func _pour(litres: float, rate: float, delta: float) -> void:
	var lip := lip_position()
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(lip, lip + Vector3.DOWN * 4.0)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	pour_target = hit.position if hit else lip + Vector3.DOWN * 1.0
	var share := {}
	for k in mix:
		share[k] = mix[k] / maxf(amount, 0.0001) * litres
		mix[k] -= share[k]
	amount -= litres
	var mold := MoldBox.find_at(get_tree(), pour_target)
	if mold:
		mold.receive_metal(litres, temperature, share, rate, delta)
	elif randf() < delta * 8.0:
		FoundryFX.sparks(get_parent(), pour_target, 6)
	if amount <= 0.001:
		amount = 0.0
		mix.clear()


## World position of the pouring spout, following the visual tilt.
func lip_position() -> Vector3:
	return _pivot.global_transform * Vector3(0, HEIGHT, RADIUS + 0.06)


func add_melt(metal: StringName, litres: float) -> float:
	var room := CAPACITY - amount
	var added := minf(room, litres)
	if added <= 0.0:
		return 0.0
	mix[metal] = mix.get(metal, 0.0) + added
	amount += added
	return added


func alloy() -> StringName:
	return FoundryRules.alloy_for(mix)


@rpc("authority", "call_remote", "unreliable_ordered")
func _sync(a: float, t: float, ti: float, f: float, al: StringName, target: Vector3, yaw: float) -> void:
	pour_yaw = yaw
	amount = a
	temperature = t
	tilt = ti
	flow = f
	pour_target = target
	mix = {al: a}


func _update_visuals() -> void:
	if _pivot == null:
		return
	_pivot.global_basis = Basis(Vector3.UP, pour_yaw) * Basis(Vector3.RIGHT, tilt * 1.25)
	_melt.visible = amount > 0.02
	_melt.position.y = 0.04 + (HEIGHT - 0.08) * clampf(amount / CAPACITY, 0.0, 1.0)
	MetalMaterial.set_temperature(_melt_mat, clampf(temperature, 0.0, 1.0))
	_stream.flow = flow
	if flow > 0.0:
		_stream.set_endpoints(lip_position(), pour_target)
