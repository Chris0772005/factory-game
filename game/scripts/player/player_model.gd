class_name PlayerModel
extends Node3D
## Procedural chunky worker with simple code-driven animation (walk swing,
## bob, squash and stretch, arms reaching for held objects). Faces +Z.

@export var suit_color := Color("#3d7dd8")

const SKIN := Color("#ffd2a8")
const HELMET := Color("#f2b134")
const BOOTS := Color("#3a3f4b")

var _body: Node3D
var _arms: Array[Node3D] = []
var _legs: Array[Node3D] = []
var _phase := 0.0
var _squash := 1.0


func _ready() -> void:
	_body = Node3D.new()
	add_child(_body)
	var torso := _mesh(MeshFactory.rounded_box(Vector3(0.7, 0.75, 0.48), 0.2), suit_color, Vector3(0, 0.85, 0))
	_body.add_child(torso)
	var head := _sphere(0.3, SKIN, Vector3(0, 1.47, 0))
	_body.add_child(head)
	var helmet := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.33
	hs.height = 0.36
	hs.is_hemisphere = true
	helmet.mesh = hs
	helmet.material_override = _mat(HELMET, 0.35)
	helmet.position = Vector3(0, 1.55, 0)
	_body.add_child(helmet)
	var brim := _mesh(MeshFactory.rounded_box(Vector3(0.5, 0.05, 0.25), 0.02), HELMET, Vector3(0, 1.56, 0.25))
	_body.add_child(brim)
	for side in [-1.0, 1.0]:
		var eye := _sphere(0.045, Color("#1c1a24"), Vector3(side * 0.11, 1.5, 0.27))
		_body.add_child(eye)
		var arm := Node3D.new()
		arm.position = Vector3(side * 0.42, 1.1, 0)
		_body.add_child(arm)
		var arm_mesh := _mesh(MeshFactory.rounded_box(Vector3(0.18, 0.55, 0.18), 0.09), suit_color.darkened(0.12), Vector3(0, -0.25, 0))
		arm.add_child(arm_mesh)
		var hand := _sphere(0.1, SKIN, Vector3(0, -0.55, 0))
		arm.add_child(hand)
		_arms.append(arm)
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.17, 0.5, 0)
		add_child(leg)
		var leg_mesh := _mesh(MeshFactory.rounded_box(Vector3(0.22, 0.42, 0.24), 0.1), suit_color.darkened(0.25), Vector3(0, -0.2, 0))
		leg.add_child(leg_mesh)
		var boot := _mesh(MeshFactory.rounded_box(Vector3(0.24, 0.14, 0.34), 0.06), BOOTS, Vector3(0, -0.44, 0.05))
		leg.add_child(boot)
		_legs.append(leg)


func squash(amount: float) -> void:
	_squash = amount


## Snapshot of the limb angles, small enough to send over the network.
func pose_data() -> PackedFloat32Array:
	return PackedFloat32Array([
		_arms[0].rotation.x, _arms[0].rotation.z, _arms[1].rotation.x, _arms[1].rotation.z,
		_legs[0].rotation.x, _legs[1].rotation.x, _body.position.y,
	])


func apply_pose(pose: PackedFloat32Array) -> void:
	if pose.size() < 7:
		return
	_arms[0].rotation = Vector3(pose[0], 0, pose[1])
	_arms[1].rotation = Vector3(pose[2], 0, pose[3])
	_legs[0].rotation.x = pose[4]
	_legs[1].rotation.x = pose[5]
	_body.position.y = pose[6]


## "Oh no" pose for someone caught in a pour: arms up, one leg kicked.
static func panic_pose() -> PackedFloat32Array:
	return PackedFloat32Array([-2.6, 0.5, -2.4, -0.6, -0.6, 0.35, 0.04])


func animate(delta: float, velocity: Vector3, on_floor: bool, holding: bool, hand_target: Vector3) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	if on_floor:
		_phase += delta * speed * 2.6
	var swing := sin(_phase) * clampf(speed / 4.0, 0.0, 1.0)
	for i in 2:
		var s := 1.0 if i == 0 else -1.0
		_legs[i].rotation.x = swing * 0.7 * s if on_floor else -0.4
		if holding:
			var local := _arms[i].to_local(hand_target)
			var reach := atan2(local.z, -local.y)
			_arms[i].rotation.x = lerp_angle(_arms[i].rotation.x, -reach, 1.0 - exp(-18.0 * delta))
			_arms[i].rotation.z = lerpf(_arms[i].rotation.z, -s * 0.25, 1.0 - exp(-10.0 * delta))
		else:
			_arms[i].rotation.x = lerpf(_arms[i].rotation.x, -swing * 0.8 * s, 1.0 - exp(-12.0 * delta))
			_arms[i].rotation.z = lerpf(_arms[i].rotation.z, s * (0.08 if on_floor else 0.9), 1.0 - exp(-10.0 * delta))
	_body.position.y = absf(sin(_phase)) * 0.06 * clampf(speed / 4.0, 0.0, 1.0)
	_squash = lerpf(_squash, 1.0, 1.0 - exp(-10.0 * delta))
	scale = Vector3(1.0 / sqrt(_squash), _squash, 1.0 / sqrt(_squash))


func _mat(color: Color, rough := 0.65) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m


func _mesh(mesh: Mesh, color: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color)
	mi.position = pos
	return mi


func _sphere(radius: float, color: Color, pos: Vector3) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	return _mesh(s, color, pos)
