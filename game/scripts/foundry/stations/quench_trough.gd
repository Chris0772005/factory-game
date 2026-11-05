class_name QuenchTrough
extends Node3D
## Galvanised water tub on brick feet. Scoop the bucket here (WaterBucket);
## a hot casting thrown in hisses, steams and is cold at once. Visual cooling
## runs on every peer (each sees the piece land), so it needs no RPC.

const SIZE := Vector3(1.5, 0.62, 0.72)
const WATER_Y := 0.5
## Bucket reach from the tub's rim (horizontal, m): the carried bucket hangs
## ~0.7 m in front of the worker, so they stand about that far off the rim.
const REACH := 1.4

var _water_mat: ShaderMaterial
var _stir := 0.0


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_to_group(&"interactable")
	add_to_group(&"quench_troughs")
	_build_collision()
	var area := Area3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(SIZE.x - 0.1, 0.4, SIZE.z - 0.1)
	shape.shape = box
	area.add_child(shape)
	area.position.y = WATER_Y - 0.1
	add_child(area)
	area.body_entered.connect(_on_body_entered)
	if StationKit.visual():
		_build_art()


func _build_collision() -> void:
	var t := 0.05
	var h := SIZE.y
	StationKit.box_collider(self, Vector3(SIZE.x, 0.1, SIZE.z), Transform3D(Basis(), Vector3(0, 0.12, 0)))
	for s: float in [-1.0, 1.0]:
		StationKit.box_collider(self, Vector3(SIZE.x, h, t), Transform3D(Basis(), Vector3(0, h * 0.5, s * (SIZE.z - t) * 0.5)))
		StationKit.box_collider(self, Vector3(t, h, SIZE.z), Transform3D(Basis(), Vector3(s * (SIZE.x - t) * 0.5, h * 0.5, 0)))


func _build_art() -> void:
	var steel := StationKit.metal("trough_steel", {steel_color = Color("#9fa6a9"), rust = 0.3, dents = 0.35,
		metallic_steel = 0.65, roughness_steel = 0.4})
	var brick := EnvMesh.material("garage_brick_feet", "res://shaders/env_plaster.gdshader", {
		brick = Color("#9c553f"), mortar = Color("#c2b29a"), brickwork = 1.0})
	var hx := SIZE.x * 0.5
	var hz := SIZE.z * 0.5
	# Tub: tapered walls with a rolled rim, riveted seams.
	var tub := []
	var wall := 0.025
	for s: float in [-1.0, 1.0]:
		tub.append(EnvMesh.piece(EnvMesh.box(Vector3(SIZE.x, SIZE.y - 0.12, wall), 0.006), Transform3D(Basis(Vector3.RIGHT, s * 0.06), Vector3(0, 0.12 + (SIZE.y - 0.12) * 0.5, s * (hz - wall * 0.5)))))
		tub.append(EnvMesh.piece(EnvMesh.box(Vector3(wall, SIZE.y - 0.12, SIZE.z), 0.006), Transform3D(Basis(Vector3.BACK, -s * 0.06), Vector3(s * (hx - wall * 0.5), 0.12 + (SIZE.y - 0.12) * 0.5, 0))))
		tub.append(EnvMesh.piece(StationKit.tube(PackedVector3Array([Vector3(-hx - 0.02, SIZE.y, s * (hz + 0.02)), Vector3(hx + 0.02, SIZE.y, s * (hz + 0.02))]), 0.018, 8), Transform3D()))
		tub.append(EnvMesh.piece(StationKit.tube(PackedVector3Array([Vector3(s * (hx + 0.02), SIZE.y, -hz - 0.02), Vector3(s * (hx + 0.02), SIZE.y, hz + 0.02)]), 0.018, 8), Transform3D()))
	tub.append(EnvMesh.piece(EnvMesh.box(Vector3(SIZE.x, 0.03, SIZE.z), 0.006), Transform3D(Basis(), Vector3(0, 0.135, 0))))
	StationKit.add_merged(self, tub, steel)
	var feet := []
	for s: float in [-1.0, 1.0]:
		feet.append(EnvMesh.piece(EnvMesh.box(Vector3(0.24, 0.12, SIZE.z + 0.04), 0.01), Transform3D(Basis(), Vector3(s * (hx - 0.2), 0.06, 0))))
	StationKit.add_merged(self, feet, brick)
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(SIZE.x - wall * 2.0 - 0.02, SIZE.z - wall * 2.0 - 0.02)
	water.mesh = plane
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = load("res://shaders/fx_water.gdshader")
	water.material_override = _water_mat
	water.position.y = WATER_Y
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	StationKit.label(self, "WASSER", Transform3D(Basis(), Vector3(0, 0.36, hz + 0.03)), 72, Color("#e9e3d6"), 800, 0.0012)


## Horizontal distance from `p` to the tub's footprint (0 inside).
func distance_to(p: Vector3) -> float:
	var local := to_local(p)
	var dx := maxf(absf(local.x) - SIZE.x * 0.5, 0.0)
	var dz := maxf(absf(local.z) - SIZE.z * 0.5, 0.0)
	return Vector2(dx, dz).length()


func interact_point() -> Vector3:
	return global_position + Vector3(0, WATER_Y, 0)


func hint(_player: Node) -> String:
	return "Wassertrog – Eimer hier füllen · heiße Gussteile zischen hier ab"


func interact(_player: Node) -> void:
	# Bare hands in the water: a little splash, nothing else.
	_splash(interact_point(), 0.3)


func _on_body_entered(body: Node) -> void:
	if body is CastPiece:
		var piece := body as CastPiece
		if piece.temperature > 0.05:
			piece.quench_local()
			_splash(piece.global_position, 1.6)
		else:
			_splash(piece.global_position, 0.4)


func _splash(pos: Vector3, strength: float) -> void:
	_stir = 1.0
	if _water_mat:
		var local := to_local(pos)
		_water_mat.set_shader_parameter(&"stir_center", Vector2(global_position.x + local.x, global_position.z + local.z))
	Sfx.play(&"water_splash", pos, -6.0 + strength * 2.0)
	if strength > 1.0:
		FoundryFX.steam_puff(get_parent(), Vector3(pos.x, global_position.y + WATER_Y, pos.z), strength)
		Sfx.play(&"steam_hiss", pos, 0.0)


func _process(delta: float) -> void:
	if _stir > 0.0:
		_stir = maxf(0.0, _stir - delta * 0.8)
		if _water_mat:
			_water_mat.set_shader_parameter(&"stir", _stir)
