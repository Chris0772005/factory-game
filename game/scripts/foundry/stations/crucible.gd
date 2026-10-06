class_name Crucible
extends Item
## Carryable melting pot. Sits in a furnace to collect melt; held near a mold,
## holding the use button tilts it and pours. Host simulates, peers mirror.

const CAPACITY := 3.0           ## litres of melt
const MAX_POUR_RATE := 0.9      ## litres per second at full tilt
const COOL_RATE := 0.035        ## temperature lost per second outside the furnace
const RADIUS := 0.22
const HEIGHT := 0.42
## Melt disc radius as built; scaled to the pot's inner wall at the fill height.
const MELT_RADIUS := 0.185
## Carry pose (see `carry_offset`): the pot's base sits this far in front of the
## carrier, at hip height while walking. For the pour it is pushed out to arm's
## length and only lifted to the belt, so the tipped pot stays below the chin
## (the face shows) while the lip still clears a mold's sand by ~15 cm.
const CARRY_DISTANCE := 0.64
const POUR_DISTANCE := 0.78
const CARRY_HEIGHT := 0.55
const POUR_HEIGHT := 0.74
## Base height while near a furnace, so the pot clears the drum wall on the way
## out and back in; blends to the carry height over this ring (m from the centre).
const FURNACE_LIFT_HEIGHT := 1.0
const FURNACE_LIFT_NEAR := 0.75
const FURNACE_LIFT_FAR := 1.1

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
var _art: CrucibleArt
var _melt: MeshInstance3D
var _melt_mat: ShaderMaterial
var _stream: PourStream
var _pouring := false
var _sync_accum := 0.0
var _hiss: AudioStreamPlayer3D


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
	_art = CrucibleArt.new()
	_pivot.add_child(_art)
	_art.build()
	_melt = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = MELT_RADIUS
	disc.bottom_radius = MELT_RADIUS
	disc.height = 0.02
	disc.radial_segments = 24
	_melt.mesh = disc
	_melt_mat = MetalMaterial.create(&"alu")
	# Melt in the pot glows harder and mirrors less, so it reads as the hottest,
	# brightest thing on screen (Art Bible 6.6 / rule 2).
	_melt_mat.set_shader_parameter(&"env_brightness", 0.35)
	_melt_mat.set_shader_parameter(&"glow_scale", 1.6)
	_melt.material_override = _melt_mat
	_pivot.add_child(_melt)
	_hiss = Sfx.make_loop(self, &"pour_loop")
	_stream = PourStream.new()
	_stream.top_level = true
	add_child(_stream)
	_update_visuals()


func _process(_delta: float) -> void:
	# Physics interpolation draws the pot between ticks; glue the stream's top to
	# the lip as drawn so it never detaches on high-refresh screens.
	if _stream.is_pouring():
		_stream.set_endpoints(_pivot.get_global_transform_interpolated() * _lip_local(), pour_target)


## Global centres of the two handle grips (e.g. for hand IK); empty headless.
func grip_points() -> Array[Vector3]:
	return _art.grip_points()


## Where a carrier's hands hold the pot, as (distance in front, height of the
## pot's base): low in front of the hips while walking, pushed out and heaved
## to the belt as it tips for a pour (the lip then sits ~15 cm above a mold's
## sand), and lifted over the drum wall near a furnace.
func carry_offset(_player: Node) -> Vector2:
	var height := lerpf(CARRY_HEIGHT, POUR_HEIGHT, tilt)
	var distance := lerpf(CARRY_DISTANCE, POUR_DISTANCE, tilt)
	for node in get_tree().get_nodes_in_group(&"furnaces"):
		var f := node as Node3D
		var d := Vector2(global_position.x - f.global_position.x, global_position.z - f.global_position.z).length()
		height = maxf(height, lerpf(FURNACE_LIFT_HEIGHT, height, smoothstep(FURNACE_LIFT_NEAR, FURNACE_LIFT_FAR, d)))
	return Vector2(distance, height)


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
	# Handle swing and thermometer run on the physics step: the pot is a physics
	# body, so its children are interpolated between ticks (no stutter > 60 Hz).
	_art.update(delta, temperature, clampf(amount / capacity(), 0.0, 1.0), is_held())


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
	elif randf() < delta * 1.5:
		FoundryFX.sparks(get_parent(), pour_target, 6)
	if amount <= 0.001:
		amount = 0.0
		mix.clear()


## World position of the pouring spout, following the visual tilt.
func lip_position() -> Vector3:
	return _pivot.global_transform * _lip_local()


func _lip_local() -> Vector3:
	return Vector3(0, HEIGHT, RADIUS + 0.06)


func capacity() -> float:
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	return 5.0 if world and world.has_upgrade(&"crucible_big") else CAPACITY


func add_melt(metal: StringName, litres: float) -> float:
	var room := capacity() - amount
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
	_melt.position.y = 0.04 + (HEIGHT - 0.08) * clampf(amount / capacity(), 0.0, 1.0)
	var r := CrucibleArt.inner_radius(_melt.position.y + 0.01) - 0.004
	_melt.scale = Vector3(r / MELT_RADIUS, 1.0, r / MELT_RADIUS)
	MetalMaterial.set_temperature(_melt_mat, clampf(temperature, 0.0, 1.0))
	if _melt.visible:
		var al := alloy()
		if _melt_mat.get_meta(&"alloy", &"") != al:
			MetalMaterial.set_alloy(_melt_mat, al)
	_stream.flow = flow
	if flow > 0.01:
		_hiss.global_position = pour_target
		_hiss.volume_db = linear_to_db(flow) - 2.0
		if not _hiss.playing:
			_hiss.play()
	elif _hiss.playing:
		_hiss.stop()
	if flow > 0.0:
		_stream.set_endpoints(lip_position(), pour_target)
