class_name Bell
extends Item
## A cast bell: the lathe shell of its BellProfile in the cast alloy, with a
## crown loop. It rings with its own synthesised tone (BellTone) when struck
## with the hammer or when it lands hard, swaying a little. Heavy: carry it
## together or with the chain hoist. Sold at the sell crate like any casting.

## Base price of a pure, "Gut" bronze bell with a 0.35 m mouth (before the
## alloy): about four garage castings, for about four times the metal.
const BASE_VALUE := 110
const COOL_TIME := 12.0

var code := ""
var alloy := &"bronze"
var mouth_radius := 0.35
var quality := 0.7
## A bell quenched hot (or dug out too early) is cracked: it buzzes.
var cracked := false
var temperature := 0.0
var profile: BellProfile
var _material: ShaderMaterial
var _player: AudioStreamPlayer3D
var _sway := 0.0
var _pivot: Node3D
var _last_ring := -10.0


static func from_data(data: Dictionary) -> Bell:
	var b := Bell.new()
	b.kind = &"bell"
	b.code = data.code
	b.alloy = StringName(data.get("alloy", "bronze"))
	b.mouth_radius = data.get("radius", 0.35)
	b.quality = data.get("quality", 0.7)
	b.cracked = data.get("cracked", false)
	b.temperature = data.get("temperature", 0.0)
	b.position = data.pos
	b.profile = BellProfile.from_drawing(Drawing.from_code(b.code))
	if b.profile == null:
		b.profile = BellProfile.from_drawing(DrawingSamples.bell())
	var h := b.profile.height(b.mouth_radius)
	b.mass = clampf(b.profile.volume(b.mouth_radius) * 8.6 * 1000.0 * 0.04, 6.0, 30.0)
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = b.mouth_radius * 0.92
	cyl.height = h
	shape.shape = cyl
	shape.position.y = h * 0.5
	b.add_child(shape)
	b.physics_material_override = PhysicsMaterial.new()
	b.physics_material_override.friction = 0.8
	b.contact_monitor = true
	b.max_contacts_reported = 2
	return b


func _ready() -> void:
	add_to_group(&"bells")
	body_entered.connect(_on_body_entered)
	_pivot = Node3D.new()
	add_child(_pivot)
	_player = AudioStreamPlayer3D.new()
	_player.unit_size = 10.0
	_player.max_distance = 60.0
	add_child(_player)
	if not StationKit.visual():
		return
	var mi := MeshInstance3D.new()
	mi.mesh = profile.mesh(mouth_radius)
	_material = MetalMaterial.create(alloy, profile.seed)
	_material.set_shader_parameter(&"crust", 0.3)
	MetalMaterial.set_temperature(_material, temperature)
	MetalMaterial.set_defects(_material, 0.6 if cracked else FoundryRules.defect_amount({}) )
	mi.material_override = _material
	_pivot.add_child(mi)
	# Crown loop to hang it by.
	var loop := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = mouth_radius * 0.09
	tor.outer_radius = mouth_radius * 0.15
	loop.mesh = tor
	loop.material_override = _material
	loop.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, profile.height(mouth_radius) + mouth_radius * 0.1, 0))
	_pivot.add_child(loop)


## Strike note frequency (Hz).
func frequency() -> float:
	return BellTone.prime(profile, mouth_radius, alloy)


func note() -> String:
	return BellTone.note_name(frequency())


## "rein", "leicht schief", "schief" or "gesprungen".
func verdict() -> String:
	return "gesprungen" if cracked else BellTone.verdict(profile)


func purity() -> float:
	return 0.15 if cracked else BellTone.purity(profile)


func value() -> int:
	var size := pow(mouth_radius / 0.35, 2.0)
	var alloy_mult: float = Alloys.TABLE.get(alloy, {}).get("value_mult", 1.0)
	var tone := lerpf(0.4, 1.6, purity())
	return maxi(10, roundi(BASE_VALUE * size * alloy_mult * tone * FoundryRules.grade(quality).mult))


func held_hint(_player_node: Node) -> String:
	return "Glocke in %s · %s · %d $   – schwer: zu zweit tragen oder Kettenzug" % [note(), verdict(), value()]


## Host: ring on every peer (hammer, reveal, hard landing).
func ring_all(strength := 1.0) -> void:
	_ring(strength)
	if Network.is_online() and multiplayer.is_server():
		_ring_remote.rpc(strength)


@rpc("authority", "call_remote", "unreliable")
func _ring_remote(strength: float) -> void:
	_ring(strength)


func _ring(strength: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_ring < 0.15:
		return
	_last_ring = now
	_sway = clampf(_sway + strength, 0.0, 1.5)
	if _player.stream == null:
		_player.stream = BellTone.stream(profile, mouth_radius, alloy)
	_player.volume_db = linear_to_db(clampf(strength, 0.05, 1.0)) + (-4.0 if cracked else 0.0)
	# A cracked bell buzzes: played a touch flat with a rattle on top.
	_player.pitch_scale = 0.97 if cracked else 1.0
	_player.play()
	if cracked:
		Sfx.play(&"scrap_clatter", global_position + Vector3(0, 0.3, 0), -8.0)


func _on_body_entered(_other: Node) -> void:
	if not Network.is_sim_authority():
		return
	var speed := linear_velocity.length()
	if speed > 1.5:
		ring_all(clampf((speed - 1.0) / 5.0, 0.1, 0.8))


func _physics_process(delta: float) -> void:
	if temperature > 0.0 and _material:
		temperature = maxf(0.0, temperature - delta / COOL_TIME)
		MetalMaterial.set_temperature(_material, temperature)
	if _pivot:
		_sway = move_toward(_sway, 0.0, delta * 0.8)
		_pivot.rotation.z = sin(Time.get_ticks_msec() / 1000.0 * 9.0) * _sway * 0.05
