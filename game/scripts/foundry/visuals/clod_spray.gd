extends Node3D
## Chunky sand clods thrown out of a breaking mold: simple ballistic flight,
## a bounce on the ground, then they sink into the floor and free themselves.

const COUNT := 10
const LIFETIME := 1.8
const GRAVITY := 9.8

var _clods: Array[MeshInstance3D] = []
var _vel: Array[Vector3] = []
var _spin: Array[Vector3] = []
var _age := 0.0


func spray(bed: Vector3, material: Material) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in COUNT:
		var mi := MeshInstance3D.new()
		mi.mesh = StationKit.chunk(rng.randf_range(0.05, 0.09), i % 5, 0.5, 0.3)
		mi.material_override = material
		mi.position = Vector3(rng.randf_range(-0.45, 0.45) * bed.x, bed.y + 0.03, rng.randf_range(-0.4, 0.4) * bed.z)
		add_child(mi)
		_clods.append(mi)
		var out := Vector3(mi.position.x, 0.0, mi.position.z).normalized()
		_vel.append(out * rng.randf_range(1.2, 2.4) + Vector3(0, rng.randf_range(2.6, 4.0), 0))
		_spin.append(Vector3(rng.randf_range(-8, 8), rng.randf_range(-8, 8), rng.randf_range(-8, 8)))


func _process(delta: float) -> void:
	_age += delta
	var sink := maxf(0.0, _age - 1.1) * 0.15
	for i in _clods.size():
		var c := _clods[i]
		_vel[i].y -= GRAVITY * delta
		c.position += _vel[i] * delta
		c.rotation += _spin[i] * delta
		var floor_y := -sink
		if c.position.y < floor_y:
			c.position.y = floor_y
			_vel[i] = Vector3(_vel[i].x * 0.4, absf(_vel[i].y) * 0.25, _vel[i].z * 0.4)
			_spin[i] *= 0.5
	if _age > LIFETIME:
		queue_free()
