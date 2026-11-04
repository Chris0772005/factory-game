class_name WaterBucket
extends Item
## Galvanised bucket. Scoop it full at the quench trough, carry it to a mold
## and tip it out (use button): a cooling mold is ready at once, but its
## castings may crack (MoldBox.quench). Host simulates, peers mirror `full`.

const RADIUS := 0.17
const HEIGHT := 0.3
## Carried by the bail at the hip, a little in front.
const CARRY_OFFSET := Vector2(0.5, 0.42)
## How far in front of the carrier the water lands.
const REACH := 1.6

var full := false
var _water: MeshInstance3D
var _water_mat: ShaderMaterial
var _tip := 0.0
var _pivot: Node3D


static func create_bucket(data: Dictionary) -> WaterBucket:
	var b := WaterBucket.new()
	b.kind = &"bucket"
	b.mass = 3.0
	b.position = data.pos
	b.full = data.get("full", false)
	b.axis_lock_angular_x = true
	b.axis_lock_angular_z = true
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = RADIUS
	cyl.height = HEIGHT
	shape.shape = cyl
	shape.position.y = HEIGHT * 0.5
	b.add_child(shape)
	return b


func _ready() -> void:
	add_to_group(&"buckets")
	_pivot = Node3D.new()
	add_child(_pivot)
	if not StationKit.visual():
		return
	var steel := StationKit.metal("bucket_steel", {steel_color = Color("#a9afb2"), rust = 0.15, dents = 0.4,
		metallic_steel = 0.7, roughness_steel = 0.35})
	var profile := PackedVector2Array([Vector2(0.0, 0.0), Vector2(RADIUS - 0.03, 0.0), Vector2(RADIUS - 0.02, 0.01),
		Vector2(RADIUS, HEIGHT - 0.02), Vector2(RADIUS + 0.012, HEIGHT), Vector2(RADIUS - 0.006, HEIGHT - 0.004),
		Vector2(RADIUS - 0.02, 0.02), Vector2(0.0, 0.02)])
	StationKit.add(_pivot, StationKit.lathe(profile, 22, 40.0), steel)
	# Bail handle over the top and its two lugs.
	var bail := StationKit.arc_points(Vector3(0, HEIGHT - 0.02, 0), Vector3.RIGHT, Vector3.UP, RADIUS + 0.01, 0.0, PI, 14)
	StationKit.add(_pivot, StationKit.tube(bail, 0.007, 6), steel)
	_water = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = RADIUS - 0.012
	disc.bottom_radius = RADIUS - 0.012
	disc.height = 0.01
	disc.radial_segments = 20
	_water.mesh = disc
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = load("res://shaders/fx_water.gdshader")
	_water.material_override = _water_mat
	_water.position.y = HEIGHT - 0.07
	_pivot.add_child(_water)
	_update_visual()


func carry_offset(_player: Node) -> Vector2:
	return CARRY_OFFSET


func held_hint(player: Node) -> String:
	if not full:
		return "[F] Wasser schöpfen" if _trough_near(player) else "Leer – am Wassertrog füllen"
	var mold := _mold_ahead(player)
	if mold and mold.state == MoldBox.State.COOLING:
		return "[F] Abschrecken – sofort fertig, aber Rissgefahr (%d %%)" % roundi(mold.quench_risk() * 100)
	if mold and mold.state == MoldBox.State.FILLING:
		return "[F] Wasser aufs flüssige Metall?!  (Dampfexplosion)"
	return "[F] Ausschütten"


func use_start(player: Node) -> void:
	if not Network.is_sim_authority():
		return
	if not full:
		if _trough_near(player):
			_set_full(true)
			_fx_all(&"fill")
		return
	_set_full(false)
	var mold := _mold_ahead(player)
	_fx_all(&"tip")
	if mold:
		mold.quench()
	else:
		var ahead := (player as Node3D).global_position + (player as Node3D).global_transform.basis.z * 0.9
		_splash_at(ahead)


func _splash_at(pos: Vector3) -> void:
	# Hot castings on the floor hiss when they get the water.
	for node in get_tree().get_nodes_in_group(&"castings"):
		var piece := node as CastPiece
		if piece and piece.global_position.distance_to(pos) < 0.9:
			piece.quench_all()
	_fx_all(&"splash", pos)


func _trough_near(player: Node) -> bool:
	for node in get_tree().get_nodes_in_group(&"quench_troughs"):
		if (node as Node3D).global_position.distance_to((player as Node3D).global_position) < QuenchTrough.REACH:
			return true
	return false


func _mold_ahead(player: Node) -> MoldBox:
	var body := player as Node3D
	var mold := MoldBox.find_at(get_tree(), body.global_position + body.global_transform.basis.z * 1.0)
	if mold == null:
		for node in get_tree().get_nodes_in_group(&"molds"):
			if (node as Node3D).global_position.distance_to(body.global_position) < REACH:
				mold = node
	return mold


func _set_full(value: bool) -> void:
	full = value
	_update_visual()
	if Network.is_online() and multiplayer.is_server():
		_sync_full.rpc(value)


@rpc("authority", "call_remote", "reliable")
func _sync_full(value: bool) -> void:
	full = value
	_update_visual()


func _update_visual() -> void:
	if _water:
		_water.visible = full


func _fx_all(kind: StringName, pos := Vector3.INF) -> void:
	var at := global_position + Vector3(0, HEIGHT, 0) if pos == Vector3.INF else pos
	_fx(kind, at)
	if Network.is_online() and multiplayer.is_server():
		_fx_remote.rpc(kind, at)


@rpc("authority", "call_remote", "unreliable")
func _fx_remote(kind: StringName, pos: Vector3) -> void:
	_fx(kind, pos)


func _fx(kind: StringName, pos: Vector3) -> void:
	match kind:
		&"fill":
			Sfx.play(&"bucket_fill", pos, -4.0)
		&"tip":
			_tip = 1.0
			Sfx.play(&"water_splash", pos, -2.0)
		&"splash":
			FoundryFX.steam_puff(get_parent(), pos, 0.4)
			Sfx.play(&"water_splash", pos, -4.0)


func _physics_process(delta: float) -> void:
	# A quick tip forward and back when emptied.
	_tip = move_toward(_tip, 0.0, delta * 2.2)
	if _pivot:
		_pivot.rotation.x = sin(_tip * PI) * 1.1
