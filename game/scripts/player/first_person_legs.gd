class_name FirstPersonLegs
extends Node3D
## The local worker's own body below the eyes in first person: belly in the warning vest with
## its reflective band, trouser legs and work boots, in the colours of the figure the others see
## (PlayerModel.LOOKS). Looking down shows where the feet stand; the legs step with the walk and
## tuck in the air. The full worker model stays hidden from the own lens (it only casts the
## shadow). Pure presentation, local only. The worker faces +Z.

const HIP_HEIGHT := 0.88
const THIGH := 0.42
const SHIN := 0.4
## The body sits a little behind the eyes so the boots are in view.
const SET_BACK := -0.2

var player: Player
var _hips: Array[Node3D] = []
var _knees: Array[Node3D] = []
var _ankles: Array[Node3D] = []
var _phase := 0.0
var _stride := 0.0
var _air := 0.0


func _ready() -> void:
	# Scanned cloth and leather (FpMaterials), as on the arms, in the colours the figure wears.
	var look := PlayerModel.look_of(player.color if player else Color("#3e7bd6"))
	var cloth := FpMaterials.scan("cloth", look.trousers)
	var vest := FpMaterials.scan("cloth", look.vest, 0.6)
	var leather := FpMaterials.scan("leather", look.boots)
	var band := StandardMaterial3D.new()
	band.albedo_color = Color("#b9bbb8")
	band.roughness = 0.38
	band.metallic = 0.35
	var sole := StandardMaterial3D.new()
	sole.albedo_color = Color("#1d1a19")
	sole.roughness = 0.95
	var steel := MachineArt.steel_mat()
	var squash := func(p: Vector3, _a: float) -> Vector3: return Vector3(p.x, p.y, p.z * 0.72)
	# Belly: the trousers' waist with belt and buckle, and over it the warning vest, which hangs
	# to the hips, with its reflective band.
	var trunk := Node3D.new()
	trunk.position = Vector3(0, 0, SET_BACK - 0.13)
	add_child(trunk)
	_add(trunk, StationKit.lathe(PackedVector2Array([Vector2(0, 0.8), Vector2(0.16, 0.8), Vector2(0.17, 0.9), Vector2(0.166, 0.99), Vector2(0, 0.99)]), 22, 60.0, squash), cloth)
	_add(trunk, StationKit.lathe(PackedVector2Array([Vector2(0.166, 0.9), Vector2(0.174, 0.905), Vector2(0.174, 0.945), Vector2(0.166, 0.95)]), 22, 30.0, squash), sole)
	_add(trunk, MachineArt.loft([[-0.008, 0.05, 0.04, 0.0, 0.925, 3.5], [0.008, 0.05, 0.04, 0.0, 0.925, 3.5]], 12), steel, Transform3D(Basis(), Vector3(0, 0, 0.127)))
	_add(trunk, StationKit.lathe(PackedVector2Array([Vector2(0.17, 0.955), Vector2(0.18, 0.96), Vector2(0.181, 1.0), Vector2(0.18, 1.08), Vector2(0.164, 1.14), Vector2(0.095, 1.17),
		Vector2(0, 1.17)]), 22, 60.0, squash), vest)
	_add(trunk, StationKit.lathe(PackedVector2Array([Vector2(0.18, 1.0), Vector2(0.184, 1.004), Vector2(0.184, 1.05), Vector2(0.18, 1.054)]), 22, 30.0, squash), band)
	# Seat of the overall: closes the gap over both thighs.
	_add(self, StationKit.lathe(PackedVector2Array([Vector2(0, 0.72), Vector2(0.14, 0.74), Vector2(0.185, 0.82), Vector2(0.19, 0.9), Vector2(0.16, 0.97), Vector2(0, 0.99)]), 22, 60.0,
		func(p: Vector3, _a: float) -> Vector3: return Vector3(p.x, p.y, p.z * 0.68)), cloth, Transform3D(Basis(), Vector3(0, 0, SET_BACK - 0.02)))
	for side: float in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.105, HIP_HEIGHT, SET_BACK)
		add_child(hip)
		_hips.append(hip)
		_add(hip, StationKit.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.074, 0), Vector2(0.082, 0.1), Vector2(0.092, 0.3), Vector2(0.094, THIGH), Vector2(0, THIGH + 0.03)]), 16, 60.0),
			cloth, Transform3D(Basis(), Vector3(0, -THIGH, 0)))
		var knee := Node3D.new()
		knee.position = Vector3(0, -THIGH, 0)
		hip.add_child(knee)
		_knees.append(knee)
		# Shin: the trouser leg bags over the boot top.
		_add(knee, StationKit.lathe(PackedVector2Array([Vector2(0, 0.1), Vector2(0.064, 0.1), Vector2(0.076, 0.115), Vector2(0.08, 0.15), Vector2(0.072, 0.24), Vector2(0.076, SHIN - 0.02),
			Vector2(0.07, SHIN + 0.02), Vector2(0, SHIN + 0.03)]), 16, 60.0), cloth, Transform3D(Basis(), Vector3(0, -SHIN, 0)))
		var ankle := Node3D.new()
		ankle.position = Vector3(0, -SHIN, 0)
		knee.add_child(ankle)
		_ankles.append(ankle)
		# Boot: shaft, upper with a round steel-cap toe, welted sole, heel block.
		_add(ankle, StationKit.lathe(PackedVector2Array([Vector2(0, 0.04), Vector2(0.056, 0.04), Vector2(0.058, 0.12), Vector2(0.066, 0.17), Vector2(0.068, 0.185), Vector2(0.06, 0.19),
			Vector2(0, 0.19)]), 16, 50.0), leather)
		_add(ankle, MachineArt.loft([[-0.085, 0.07, 0.05, 0.0, 0.045, 2.6], [-0.06, 0.098, 0.085, 0.0, 0.06, 2.8], [0.0, 0.104, 0.105, 0.0, 0.07, 2.8], [0.06, 0.108, 0.09, 0.0, 0.062, 3.0],
			[0.12, 0.112, 0.074, 0.0, 0.055, 3.0], [0.17, 0.104, 0.066, 0.0, 0.05, 2.8], [0.2, 0.08, 0.05, 0.0, 0.042, 2.4], [0.212, 0.04, 0.03, 0.0, 0.034, 2.2]], 18), leather)
		_add(ankle, MachineArt.loft([[-0.092, 0.08, 0.022, 0.0, 0.011, 3.0], [-0.05, 0.108, 0.022, 0.0, 0.011, 3.2], [0.1, 0.12, 0.022, 0.0, 0.011, 3.2], [0.19, 0.11, 0.022, 0.0, 0.011, 3.0],
			[0.218, 0.06, 0.02, 0.0, 0.011, 2.6]], 18), sole)
		# Laces: four cross bars up the instep.
		for k in 4:
			_add(ankle, MachineArt.loft([[-0.004, 0.05, 0.008, 0.0, 0.0, 2.5], [0.004, 0.05, 0.008, 0.0, 0.0, 2.5]], 8), sole,
				Transform3D(Basis(Vector3.RIGHT, -0.75), Vector3(0, 0.118 - k * 0.012, 0.035 + k * 0.022)))


func _add(parent: Node3D, mesh: Mesh, mat: Material, xform := Transform3D()) -> void:
	var mi := StationKit.add(parent, mesh, mat, xform, false)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var local := player.global_transform.basis.inverse() * player.velocity
	var planar := Vector2(local.x, local.z)
	var speed := planar.length()
	var grounded := player.is_on_floor()
	_air = move_toward(_air, 0.0 if grounded else 1.0, delta * 7.0)
	var want := clampf(speed / Player.WALK_SPEED, 0.0, 1.35) * (1.0 if grounded else 0.0)
	_stride = lerpf(_stride, want, 1.0 - exp(-10.0 * delta))
	_phase += delta * (4.0 + speed * 1.55)
	# Walking backwards swings the other way; pure side steps stay small.
	var dir := 1.0 if local.z >= -0.3 else -1.0
	var along := clampf(absf(local.z) / maxf(speed, 0.01), 0.35, 1.0)
	for i in 2:
		var p := _phase + (PI if i == 1 else 0.0)
		var swing := sin(p) * 0.55 * _stride * along * dir
		var lift := maxf(0.0, cos(p)) * 0.75 * _stride
		var thigh := -swing - lift * 0.35
		var shin := lift + maxf(0.0, swing) * 0.25
		# In the air both knees come up a little.
		thigh = lerpf(thigh, -0.45 - 0.1 * i, _air)
		shin = lerpf(shin, 0.8, _air)
		_hips[i].rotation.x = thigh
		_knees[i].rotation.x = shin
		_ankles[i].rotation.x = -(thigh + shin) * 0.85
