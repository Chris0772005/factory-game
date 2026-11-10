class_name ChainHoist
extends Node3D
## Overhead travelling crane with a chain hoist (Glockengießerei). A bridge
## beam runs along the hall on rails at both side walls, a trolley runs along
## the bridge, the hook hangs from the trolley. Whoever carries the control
## pendant (HoistPendant) drives it: the hook follows the pendant, F lowers
## it, hooks the nearest heavy load (bell, crucible, statue, crate) and lifts;
## F again sets the load down. Lets one worker move a bell two could not lift.
##
## The load stays a dynamic body pulled to the hook by a spring (as a worker's
## grip), so it is replicated like any loose object and swings a little.
## Host simulates; peers get bridge, trolley and hook at 15 Hz.

enum Hook { UP, LOWERING, LIFTING, SETTING_DOWN, LOW }

const SPEED := 2.4
const HOOK_SPEED := 1.6
const HOOK_TOP := 2.6
const HOOK_LOW := 0.55
## Loads the hook may take (kind of Item).
const LIFTABLE := [&"bell", &"crucible", &"statue", &"sealed_crate"]
const GRAB_RADIUS := 0.9
## How far in front of the worker with the pendant the hook hangs.
const HOOK_AHEAD := 1.3

## Hall area the hook can reach (x and z ranges) and the rail height.
@export var x_range := Vector2(-6.5, 6.5)
@export var z_range := Vector2(-3.8, 4.6)
@export var rail_height := 4.0
## Hook travel (subclasses with a fixed load hang it differently).
var hook_top := HOOK_TOP
var hook_low := HOOK_LOW
## Bridge girder cross-section (height, depth) and its load plate.
var girder := Vector2(0.26, 0.14)
var capacity_label := "MAX 2 t"

var bridge_z := 0.0
var trolley_x := 0.0
var hook_y := HOOK_TOP
var hook := Hook.UP
var load: RigidBody3D = null
var _load_offset := 0.5
var _sync_accum := 0.0
var _net_target := Vector3.ZERO
var _net_hook := Hook.UP

var _bridge: Node3D
var _trolley: Node3D
var _chain: MeshInstance3D
var _hook_node: Node3D


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_to_group(&"hoists")
	bridge_z = (z_range.x + z_range.y) * 0.5
	trolley_x = (x_range.x + x_range.y) * 0.5
	hook_y = hook_top
	_net_target = Vector3(trolley_x, hook_y, bridge_z)
	_build_art()


## World position of the hook's eye.
func hook_position() -> Vector3:
	return global_transform * Vector3(trolley_x, hook_y, bridge_z)


## Where the pendant hangs when nobody holds it.
func pendant_rest() -> Vector3:
	return global_transform * Vector3(trolley_x + 0.35, 1.25, bridge_z + 0.2)


## The hall's control pendant (one hoist per hall).
func pendant() -> Node3D:
	return get_tree().get_first_node_in_group(&"hoist_pendants") as Node3D


## Pendant button. Host only.
func press() -> void:
	match hook:
		Hook.UP:
			hook = Hook.SETTING_DOWN if load else Hook.LOWERING
			Sfx.play(&"pickup", hook_position(), -6.0)


func hint() -> String:
	match hook:
		Hook.UP:
			return "[F] Last absetzen" if load else "[F] Haken senken und Last greifen"
		Hook.LOWERING:
			return "Haken senkt sich…"
		Hook.LIFTING:
			return "Hebt an…"
		Hook.SETTING_DOWN:
			return "Setzt ab…"
	return ""


func _physics_process(delta: float) -> void:
	if Network.is_sim_authority():
		_simulate(delta)
	else:
		var t := 1.0 - exp(-12.0 * delta)
		trolley_x = lerpf(trolley_x, _net_target.x, t)
		hook = _net_hook
		hook_y = lerpf(hook_y, _net_target.y, t)
		bridge_z = lerpf(bridge_z, _net_target.z, t)
	_update_art()


func _simulate(delta: float) -> void:
	_drive(delta)
	_hook_step(delta)
	if load and not is_instance_valid(load):
		load = null
	if load:
		_spring(load, hook_position() - Vector3(0, _load_offset, 0), delta, 1.0)
	if Network.is_online():
		_sync_accum += delta
		if _sync_accum >= 1.0 / 15.0:
			_sync_accum = 0.0
			_sync.rpc(trolley_x, hook_y, bridge_z, hook)


## Bridge and trolley follow the worker carrying the pendant.
func _drive(delta: float) -> void:
	var p := pendant()
	var operator := _operator(p)
	if operator:
		# The hook hangs out in front of the worker, so the load never swings
		# into the one steering it.
		var local := to_local(operator.global_position + operator.global_transform.basis.z * HOOK_AHEAD)
		var speed := drive_speed()
		trolley_x = move_toward(trolley_x, clampf(local.x, x_range.x, x_range.y), speed * delta)
		bridge_z = move_toward(bridge_z, clampf(local.z, z_range.x, z_range.y), speed * delta)
	elif p is RigidBody3D and not (p as Item).is_held():
		_spring(p as RigidBody3D, pendant_rest(), delta, 2.0)


func drive_speed() -> float:
	return SPEED


func _hook_step(delta: float) -> void:
	match hook:
		Hook.LOWERING:
			hook_y = move_toward(hook_y, hook_low, HOOK_SPEED * delta)
			if hook_y <= hook_low + 0.001:
				load = _liftable_below()
				if load:
					_load_offset = _attach_height(load)
					Sfx.play(&"hammer_clank", hook_position(), -8.0)
				hook = Hook.LIFTING
		Hook.LIFTING:
			hook_y = move_toward(hook_y, hook_top, HOOK_SPEED * delta)
			if hook_y >= hook_top - 0.001:
				hook = Hook.UP
		Hook.SETTING_DOWN:
			hook_y = move_toward(hook_y, hook_low, HOOK_SPEED * delta)
			if load == null or hook_y <= hook_low + 0.001 or _load_on_ground():
				load = null
				hook = Hook.LIFTING


## The worker carrying the pendant, or null.
func _operator(p: Node3D) -> Node3D:
	if p == null:
		return null
	for node in get_tree().get_nodes_in_group(&"players"):
		if node.get("held") == p:
			return node
	return null


## The heaviest liftable item under the hook, or null.
func _liftable_below() -> RigidBody3D:
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	if world == null:
		return null
	var h := hook_position()
	var best: RigidBody3D = null
	for n in world.entities.get_children():
		var item := n as Item
		if item == null or not LIFTABLE.has(item.kind) or item.is_held():
			continue
		var d := Vector2(item.global_position.x - h.x, item.global_position.z - h.z).length()
		if d < GRAB_RADIUS and (best == null or item.mass > best.mass):
			best = item
	return best


## Height from the load's origin up to where the hook takes it.
func _attach_height(body: RigidBody3D) -> float:
	if body is Bell:
		var b := body as Bell
		return b.profile.height(b.mouth_radius) + b.mouth_radius * 0.2
	if body is Crucible:
		return Crucible.HEIGHT + 0.25
	if body is BronzeStatue:
		return 2.05
	return 0.5


func _load_on_ground() -> bool:
	return load.global_position.y < 0.08 or (load.get_contact_count() > 0 and load.linear_velocity.length() < 0.05 and hook_y < hook_top - 0.5)


## Pull `body` towards `target` (critically damped, gravity compensated).
## Keep omega * dt well below 1 at 60 Hz (k <= ~400), or the explicit
## spring overshoots and flings light bodies away.
func _spring(body: RigidBody3D, target: Vector3, _delta: float, stiffness_scale: float) -> void:
	var to := target - body.global_position
	var k := 160.0 * stiffness_scale
	var force := to * k * body.mass - body.linear_velocity * 2.0 * sqrt(k) * body.mass
	force += Vector3.UP * body.mass * ProjectSettings.get_setting("physics/3d/default_gravity")
	body.apply_central_force(force)
	body.angular_velocity *= 0.9


@rpc("authority", "call_remote", "unreliable_ordered")
func _sync(tx: float, hy: float, bz: float, h: int) -> void:
	_net_target = Vector3(tx, hy, bz)
	_net_hook = h as Hook


# --- Art ------------------------------------------------------------------------

func _build_art() -> void:
	if not StationKit.visual():
		return
	var yellow := StationKit.metal("crane_paint", {steel_color = Color("#d9a521"), rust = 0.25, dents = 0.2,
		metallic_steel = 0.3, roughness_steel = 0.55})
	# Girder and rails sit at camera height: they dissolve in the line of sight.
	var girder_paint := StationKit.metal("crane_girder", {steel_color = Color("#d9a521"), rust = 0.25, dents = 0.2,
		metallic_steel = 0.3, roughness_steel = 0.55, cutaway = true})
	var steel := StationKit.metal("crane_steel", {steel_color = Color("#4b4a49"), rust = 0.4, cutaway = true})
	# Runway rails along both side walls (fixed).
	var rails := []
	var rail_len := z_range.y - z_range.x + 1.0
	for x: float in [x_range.x - 0.9, x_range.y + 0.9]:
		rails.append(EnvMesh.piece(EnvMesh.box(Vector3(0.18, 0.22, rail_len), 0.01), Transform3D(Basis(), Vector3(x, rail_height, (z_range.x + z_range.y) * 0.5))))
	StationKit.add_merged(self, rails, steel)
	_bridge = Node3D.new()
	add_child(_bridge)
	var span := x_range.y - x_range.x + 1.8
	var beam := []
	beam.append(EnvMesh.piece(EnvMesh.box(Vector3(span, girder.x, girder.y), 0.01), Transform3D(Basis(), Vector3((x_range.x + x_range.y) * 0.5, rail_height + 0.05, 0))))
	for s: float in [-1.0, 1.0]:
		beam.append(EnvMesh.piece(EnvMesh.box(Vector3(0.4, 0.2, 0.5 + girder.y), 0.02), Transform3D(Basis(), Vector3((x_range.x + x_range.y) * 0.5 + s * span * 0.5, rail_height + 0.16, 0))))
	StationKit.add_merged(_bridge, beam, girder_paint)
	StationKit.label(_bridge, capacity_label, Transform3D(Basis(), Vector3(0.0, rail_height + 0.05, girder.y * 0.5 + 0.005)), 64, Color("#2a2522"), 800, 0.0016 * girder.x / 0.26)
	_trolley = Node3D.new()
	_bridge.add_child(_trolley)
	StationKit.add(_trolley, EnvMesh.box(Vector3(0.45, 0.3, 0.42), 0.02), yellow, Transform3D(Basis(), Vector3(0, rail_height - 0.2, 0)))
	StationKit.add(_trolley, EnvMesh.cylinder(0.12, 0.12, 0.3, 12), steel, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, rail_height - 0.38, 0)))
	_chain = MeshInstance3D.new()
	_chain.mesh = EnvMesh.cylinder(0.018, 0.018, 1.0, 6)
	_chain.material_override = steel
	_trolley.add_child(_chain)
	_hook_node = Node3D.new()
	_trolley.add_child(_hook_node)
	var hook_mesh := TorusMesh.new()
	hook_mesh.inner_radius = 0.05
	hook_mesh.outer_radius = 0.09
	StationKit.add(_hook_node, hook_mesh, steel, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, -0.06, 0)))
	StationKit.add(_hook_node, EnvMesh.box(Vector3(0.12, 0.14, 0.1), 0.02), yellow, Transform3D(Basis(), Vector3(0, 0.06, 0)))


func _update_art() -> void:
	if _bridge == null:
		return
	_bridge.position = Vector3(0, 0, bridge_z)
	_trolley.position = Vector3(trolley_x, 0, 0)
	var top := rail_height - 0.45
	var length := maxf(top - hook_y, 0.05)
	_chain.scale = Vector3(1, length, 1)
	_chain.position = Vector3(0, top - length * 0.5, 0)
	_hook_node.position = Vector3(0, hook_y, 0)


## Hand-held control pendant on its cable: carry it and the crane follows.
class Pendant:
	extends Item

	static func create_pendant(data: Dictionary) -> Pendant:
		var p := Pendant.new()
		p.kind = &"pendant"
		p.mass = 0.6
		p.position = data.pos
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.12, 0.24, 0.09)
		shape.shape = box
		p.add_child(shape)
		return p

	func _ready() -> void:
		add_to_group(&"hoist_pendants")
		if not StationKit.visual():
			return
		var yellow := StationKit.metal("crane_paint", {steel_color = Color("#d9a521")})
		StationKit.add(self, EnvMesh.box(Vector3(0.12, 0.24, 0.09), 0.025), yellow)
		var red := StandardMaterial3D.new()
		red.albedo_color = Color("#c0392b")
		var green := StandardMaterial3D.new()
		green.albedo_color = Color("#3f8f55")
		for i in 2:
			var b := MeshInstance3D.new()
			b.mesh = EnvMesh.cylinder(0.022, 0.022, 0.02, 10)
			b.material_override = green if i == 0 else red
			b.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.05 - i * 0.08, 0.05))
			add_child(b)

	func _hoist() -> ChainHoist:
		return get_tree().get_first_node_in_group(&"hoists") as ChainHoist

	func held_hint(_player: Node) -> String:
		var h := _hoist()
		return "Kettenzug: " + h.hint() if h else "Kettenzug"

	func use_start(_player: Node) -> void:
		var h := _hoist()
		if h and Network.is_sim_authority():
			h.press()
