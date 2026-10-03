class_name PhysicsSync
extends Node
## Host-authoritative replication of loose physics objects. The host streams
## transforms of awake bodies; clients keep their copies frozen and interpolate.

const SEND_RATE := 20.0

var _bodies := {}          # name -> RigidBody3D
var _targets := {}         # name -> [Vector3, Quaternion]
var _accum := 0.0


func register(body: RigidBody3D) -> void:
	_bodies[body.name] = body
	body.tree_exited.connect(func(): _bodies.erase(body.name); _targets.erase(body.name), CONNECT_ONE_SHOT)
	if not Network.is_sim_authority():
		body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		body.freeze = true


func _physics_process(delta: float) -> void:
	if not Network.is_online():
		return
	if multiplayer.is_server():
		_accum += delta
		if _accum >= 1.0 / SEND_RATE:
			_accum = 0.0
			_send()
	else:
		var t := 1.0 - exp(-15.0 * delta)
		for n in _targets:
			var body: RigidBody3D = _bodies.get(n)
			if body:
				var target: Array = _targets[n]
				body.global_position = body.global_position.lerp(target[0], t)
				body.quaternion = body.quaternion.slerp(target[1], t)


func _send() -> void:
	var names := PackedStringArray()
	var data := PackedFloat32Array()
	for n in _bodies:
		var body: RigidBody3D = _bodies[n]
		if body.sleeping:
			continue
		names.append(n)
		var p := body.global_position
		var q := body.quaternion
		data.append_array([p.x, p.y, p.z, q.x, q.y, q.z, q.w])
	if names.size() > 0:
		_receive.rpc(names, data)


@rpc("authority", "call_remote", "unreliable_ordered")
func _receive(names: PackedStringArray, data: PackedFloat32Array) -> void:
	for i in names.size():
		var o := i * 7
		_targets[names[i]] = [Vector3(data[o], data[o + 1], data[o + 2]),
			Quaternion(data[o + 3], data[o + 4], data[o + 5], data[o + 6]).normalized()]


## Full snapshot for a late joiner, including sleeping bodies.
func send_snapshot(peer_id: int) -> void:
	var names := PackedStringArray()
	var data := PackedFloat32Array()
	for n in _bodies:
		var body: RigidBody3D = _bodies[n]
		names.append(n)
		var p := body.global_position
		var q := body.quaternion
		data.append_array([p.x, p.y, p.z, q.x, q.y, q.z, q.w])
	_receive.rpc_id(peer_id, names, data)
