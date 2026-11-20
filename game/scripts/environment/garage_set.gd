class_name GarageSet
extends Node3D
## Level 2 set: a brick double garage turned foundry, on a clear day. The roller door is up: the
## front stands open to the driveway, the street lamp, hedges and the neighbours across the street.
## Walls, floor and ceiling are photo scans, the things that stand about are scanned props and the
## family car is a real model (the project's graphics standard, TECH_SPEC Modul Y). The other
## halls build on this set (BellHallSet, IronHallSet, ScrapHallSet) and only say what differs.
##
## Everything is CC0, CC-BY or procedural (CREDITS.md).

const WALL := 0.24
## Where the station wagon is parked (left bay, nose to the back wall).
const CAR_POS := Vector3(-4.35, 0.0, 1.55)
const P := PropKit.Solid
const CAMERA_PASSTHROUGH := &"camera_passthrough"
## Length of the `stains` array in env_concrete.gdshader.
const MAX_STAINS := 12

## Inner floor rectangle (x, z); z of inner_max is the open front (door line).
## Subclasses (other halls) set these before `_build`.
var inner_min := Vector2(-6.0, -4.6)
var inner_max := Vector2(6.0, 4.4)
var height := 2.9
## Back-wall window (x from, x to, sill, top).
var window := Vector4(0.6, 4.2, 1.35, 2.3)
## Painted parking-bay line on the floor (world x); < -50 = none.
var bay_line_x := CAR_POS.x + 1.45
## Extra env_concrete parameters (colours) for other halls.
var floor_params := {}
## A factor on the colours of the scanned floor inside (a dark scan may want lifting).
var floor_tint := Vector3.ONE
## Ground slab and floor plane: size and where its middle lies along Z.
var ground_size := Vector2(70.0, 70.0)
var ground_z := 6.0
var stations: Array = []
## Names this hall's materials (so two halls never share one by accident).
var key := "garage"
## The walls are photographed: `_wall_low_mat` up to `wall_split` metres, `_wall_high_mat` above it
## (a hall sets them in `_materials`; without them every wall is `_wall_mat`).
var wall_split := 0.95
var _passthrough: Array[RID] = []
var _wall_mat: ShaderMaterial
var _wall_low_mat: ShaderMaterial
var _wall_high_mat: ShaderMaterial
var _roof_mat: ShaderMaterial
var _trim_mat: ShaderMaterial


static func build(world: Node3D, level_stations: Array) -> GarageSet:
	var set := GarageSet.new()
	set.name = "GarageSet"
	set.stations = level_stations
	world.add_child(set)
	set._build()
	return set


func _exit_tree() -> void:
	EnvMesh.release_scans()


## Wall, ceiling and trim materials (halls override for their own look): a red brick plinth, painted
## brick above, a concrete slab overhead.
func _materials() -> void:
	_wall_low_mat = EnvMesh.scan("garage_brick", "red_brick_03", {foot = 0.4, drift = 0.2})
	# (The scan's paint is a strong yellow: brought most of the way to an off-white.)
	_wall_high_mat = EnvMesh.scan("garage_wall", "painted_worn_brick", {drift = 0.14, tint = EnvMesh.toward("painted_worn_brick", Color("#cdc7b9"), 0.75)})
	_wall_mat = _wall_high_mat
	# A plastered ceiling in a light warm grey.
	_roof_mat = EnvMesh.repainted("garage_ceiling", "beige_wall_001", Color("#c9c4b8"), {drift = 0.06})
	_trim_mat = EnvMesh.wood("garage_trim", {base_color = Color("#5f6f73"), grain_color = Color("#3c474a"),
		weathering = 0.45, paint = 0.8, paint_color = Color("#3f6f78"), roughness_base = 0.7})


## The floor inside as a photo scan (a name of EnvMesh.SCANS), with the level's stains on it; "" keeps
## the drawn concrete.
func _floor_scan() -> String:
	return "garage_floor"


func _build() -> void:
	_materials()
	_floor()
	_walls()
	_front()
	_roof()
	_dressing()
	_workshop_gear()
	_outside()
	_collect_passthrough()
	_reflection_probe()


# --- Floor ---------------------------------------------------------------------

func _floor() -> void:
	var body := StaticBody3D.new()
	body.name = "GroundCollision"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(ground_size.x, 1.0, ground_size.y)
	shape.shape = box
	body.position = Vector3(0, -0.5, ground_z)
	body.add_child(shape)
	add_child(body)
	if not EnvMesh.visual():
		return
	var plane := PlaneMesh.new()
	plane.size = ground_size
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/env_concrete.gdshader")
	mat.set_shader_parameter(&"door_z", inner_max.y + WALL * 0.5)
	mat.set_shader_parameter(&"bay_line_x", bay_line_x)
	for k in floor_params:
		mat.set_shader_parameter(k, floor_params[k])
	var stains := _stains()
	var count := mini(stains.size(), MAX_STAINS)
	# Uniform arrays must be passed at their declared length.
	stains.resize(MAX_STAINS)
	mat.set_shader_parameter(&"stains", stains)
	mat.set_shader_parameter(&"stain_count", count)
	var mi := EnvMesh.add(self, plane, mat, Transform3D(Basis(), Vector3(0, 0, ground_z)), false)
	mi.name = "Floor"
	# The photographed floor lies over it inside, with the same stains and the bay line.
	if _floor_scan() != "":
		var inside := EnvMesh.scan(key + "_floor", _floor_scan(), {drift = 0.12, tint = floor_tint, stains = stains, stain_count = count, bay_line_x = bay_line_x})
		# (Barely above the base floor: lines painted on the floor lie a few millimetres up.)
		_slab(inside, inner_min.x - WALL, inner_max.x + WALL, inner_min.y - WALL, inner_max.y + WALL * 0.5, 0.002)


## A thin slab of ground from x0 to x1 and z0 to z1, its top `top` metres above the base ground (a
## finger's breadth, unless told otherwise).
func _slab(mat: Material, x0: float, x1: float, z0: float, z1: float, top := 0.012) -> void:
	EnvMesh.add(self, EnvMesh.box(Vector3(x1 - x0, 0.03, z1 - z0), 0.0), mat, Transform3D(Basis(), Vector3((x0 + x1) * 0.5, top - 0.015, (z0 + z1) * 0.5)), false)


## Stains from the station layout: soot round the furnace, sand at the molds,
## oil under the car, rust rings under the barrels.
func _stains() -> PackedVector4Array:
	var out := PackedVector4Array()
	for s in stations:
		var p := Vector2((s as Node3D).position.x, (s as Node3D).position.z)
		if s is Furnace:
			out.append(Vector4(p.x, p.y, 1.7, 1.0))
		elif s is MoldBox:
			out.append(Vector4(p.x, p.y, 1.35, 2.0))
	out.append_array(_extra_stains())
	return out


## Set-specific stains (garage: oil under the car, rust rings under barrels).
func _extra_stains() -> PackedVector4Array:
	return PackedVector4Array([Vector4(CAR_POS.x, CAR_POS.z + 0.6, 0.75, 0.0), Vector4(CAR_POS.x + 0.3, CAR_POS.z - 0.9, 0.35, 0.0),
		Vector4(5.3, -3.9, 0.55, 3.0), Vector4(-5.45, -2.4, 0.45, 3.0)])


# --- Walls -----------------------------------------------------------------------

func _walls() -> void:
	var x0 := inner_min.x - WALL * 0.5
	var x1 := inner_max.x + WALL * 0.5
	var zb := inner_min.y - WALL * 0.5
	var zf := inner_max.y + WALL * 0.5
	var width := x1 - x0 + WALL
	# Back wall around the window.
	var wx0 := window.x
	var wx1 := window.y
	_wall_box(Vector3((x0 - WALL * 0.5 + wx0) * 0.5, height * 0.5, zb), Vector3(wx0 - (x0 - WALL * 0.5), height, WALL))
	_wall_box(Vector3((wx1 + x1 + WALL * 0.5) * 0.5, height * 0.5, zb), Vector3(x1 + WALL * 0.5 - wx1, height, WALL))
	_wall_box(Vector3((wx0 + wx1) * 0.5, window.z * 0.5, zb), Vector3(wx1 - wx0, window.z, WALL))
	_wall_box(Vector3((wx0 + wx1) * 0.5, (window.w + height) * 0.5, zb), Vector3(wx1 - wx0, height - window.w, WALL))
	_window(Vector3((wx0 + wx1) * 0.5, (window.z + window.w) * 0.5, zb), Vector2(wx1 - wx0, window.w - window.z))
	# Side walls run from the back wall to the door line.
	var depth := zf - zb + WALL
	_wall_box(Vector3(x0, height * 0.5, (zb + zf) * 0.5), Vector3(WALL, height, depth))
	_wall_box(Vector3(x1, height * 0.5, (zb + zf) * 0.5), Vector3(WALL, height, depth))
	# Painted skirting along the inside: reads the floor/wall seam from above.
	var skirt := EnvMesh.surface("garage_skirt", {base_color = Color("#4b4a4c"), roughness_base = 0.6, contact_dark = 0.2})
	var pieces := []
	pieces.append(EnvMesh.piece(EnvMesh.box(Vector3(width - WALL * 2.0, 0.12, 0.03)), Transform3D(Basis(), Vector3(0, 0.06, inner_min.y + 0.015))))
	for sx: float in [-1.0, 1.0]:
		var x := (inner_min.x + 0.015) if sx < 0.0 else (inner_max.x - 0.015)
		pieces.append(EnvMesh.piece(EnvMesh.box(Vector3(0.03, 0.12, inner_max.y - inner_min.y)), Transform3D(Basis(), Vector3(x, 0.06, (inner_min.y + inner_max.y) * 0.5))))
	EnvMesh.add(self, EnvMesh.merge(pieces), skirt)


## One wall. With two wall materials it is two boxes, split at `wall_split`: the lower one stands a
## little proud of the upper (across the wall only: along it, the boxes of one wall must still meet).
func _wall_box(center: Vector3, size: Vector3) -> void:
	var body := WorldBuilder.add_collider(self, size, Transform3D(Basis(), center))
	body.add_to_group(CAMERA_PASSTHROUGH)
	_passthrough.append(body.get_rid())
	if _wall_low_mat == null or _wall_high_mat == null:
		EnvMesh.add(self, EnvMesh.box(size, 0.015), _wall_mat, Transform3D(Basis(), center))
		return
	var bottom := center.y - size.y * 0.5
	var top := center.y + size.y * 0.5
	var split := clampf(wall_split, bottom, top)
	if split - bottom > 0.01:
		EnvMesh.add(self, EnvMesh.box(Vector3(size.x, split - bottom, size.z), 0.0), _wall_low_mat,
			Transform3D(Basis(), Vector3(center.x, (bottom + split) * 0.5, center.z)))
	if top - split > 0.01:
		var thin_x := size.x < size.z
		EnvMesh.add(self, EnvMesh.box(Vector3(size.x - (0.04 if thin_x else 0.0), top - split, size.z - (0.0 if thin_x else 0.04)), 0.0), _wall_high_mat,
			Transform3D(Basis(), Vector3(center.x, (split + top) * 0.5, center.z)))


## Steel-framed workshop window: six panes, sill, pale daylight in the glass.
func _window(center: Vector3, size: Vector2) -> void:
	if not EnvMesh.visual():
		return
	var glass := EnvMesh.material("hall_glass_day", "res://shaders/env_window.gdshader", {
		energy = 0.9, glow = Color("#dfeaf6"), room = Color("#9fb4cc"), glass_dark = Color("#6f8298"), glass_sky = Color("#cfe0f2"),
		curtain = Color("#c3d2e2")})
	EnvMesh.add(self, EnvMesh.box(Vector3(size.x, size.y, 0.02), 0.0), glass, Transform3D(Basis(), center + Vector3(0, 0, -0.02)), false)
	var frame := []
	var bar := 0.05
	for i in 4:
		var x := center.x - size.x * 0.5 + size.x * i / 3.0
		frame.append(EnvMesh.piece(EnvMesh.box(Vector3(bar, size.y, 0.06)), Transform3D(Basis(), Vector3(x, center.y, center.z + 0.04))))
	for j in 3:
		var y := center.y - size.y * 0.5 + size.y * j / 2.0
		frame.append(EnvMesh.piece(EnvMesh.box(Vector3(size.x + bar, bar, 0.06)), Transform3D(Basis(), Vector3(center.x, y, center.z + 0.04))))
	frame.append(EnvMesh.piece(EnvMesh.box(Vector3(size.x + 0.16, 0.05, 0.2)), Transform3D(Basis(), Vector3(center.x, center.y - size.y * 0.5 - 0.03, center.z + 0.12))))
	EnvMesh.add(self, EnvMesh.merge(frame), _trim_mat)


# --- Front: corner pillars, the door header as a shadow only --------------------

func _front() -> void:
	var zf := inner_max.y + WALL * 0.5
	# Brick pillars finish the side walls at the door line.
	var brick := _pillar_material()
	for x: float in [inner_min.x - WALL * 0.5, inner_max.x + WALL * 0.5]:
		var size := Vector3(0.42, height, 0.42)
		var c := Vector3(x, height * 0.5, zf)
		var body := WorldBuilder.add_collider(self, size, Transform3D(Basis(), c))
		body.add_to_group(CAMERA_PASSTHROUGH)
		_passthrough.append(body.get_rid())
		EnvMesh.add(self, EnvMesh.box(size, 0.02), brick, Transform3D(Basis(), c))
	# The lintel and the rolled-up door would cross the middle of the screen
	# from the game camera: they only cast their shadow, which frames the
	# sun shaft through the door.
	var header := EnvMesh.add(self, EnvMesh.box(Vector3(inner_max.x - inner_min.x + WALL * 2.0, 0.7, 0.5), 0.0), brick,
		Transform3D(Basis(), Vector3(0, height - 0.35, zf)))
	# (Seen from inside, in first person, it is simply the lintel.)
	if header and not CameraRig.first_person_default:
		header.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	if EnvMesh.visual():
		_sign()


## The brick of the door pillars and the lintel.
func _pillar_material() -> ShaderMaterial:
	return _wall_low_mat if _wall_low_mat else _wall_mat


## Hand-painted shop sign on the back wall, over the pegboard.
func _sign() -> void:
	StationKit.label(self, "GIESSEREI", Transform3D(Basis(), Vector3(-1.6, 2.3, inner_min.y + 0.012)), 120, Color("#5b2f22"), 800, 0.0016)


## Shadows only: the interior is shaded from the low sun without hiding it from the camera.
func _roof() -> void:
	var size := Vector3(inner_max.x - inner_min.x + WALL * 2.0 + 0.6, 0.2, inner_max.y - inner_min.y + WALL * 2.0 + 0.5)
	var mi := EnvMesh.add(self, EnvMesh.box(size, 0.0), _roof_material(), Transform3D(Basis(), Vector3(0, height + 0.1, (inner_min.y + inner_max.y) * 0.5 + 0.1)))
	if mi:
		mi.name = "RoofShadow"
		# First person: a real ceiling overhead. Orbit view: only its shadow.
		if not CameraRig.first_person_default:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY


## What the roof is made of (seen from below in first person).
func _roof_material() -> ShaderMaterial:
	return _roof_mat if _roof_mat else _wall_mat


# --- Dressing --------------------------------------------------------------------

func prop(model: String, pos: Vector3, yaw := 0.0, opts := {}) -> Node3D:
	return PropKit.place(self, model, pos, yaw, opts)


func _dressing() -> void:
	# The family car, pushed into the left bay, nose to the back wall (the reason the foundry is
	# small): a real estate car in the project's vehicle finish, kept clean in its garage.
	ParkedVehicle.place(self, ParkedVehicle.CAR_ESTATE, CAR_POS + Vector3(0.12, 0, 0.25), 90.0, Color("#2f5e48"), {mud = 0.12, dust = 0.3})
	# Tyres stacked by the car, a jerrycan and oil cans.
	_tyres(Vector3(-5.6, 0, 3.8), 3)
	_tyres(Vector3(-5.62, 0, -1.25), 2)
	PhotoProp.place(self, "metal_jerrycan_green", Vector3(-3.1, 0, 3.95), 25.0, false)
	PhotoProp.stand(self, "oil_tin", Vector3(-3.42, 0, 4.08), -10.0)
	PhotoProp.stand(self, "small_oil_can_01", Vector3(-3.3, 0, 3.72), 60.0)
	# Back wall: steel shelving with boxes and tins, the pegboard with its tools.
	_shelving(Vector3(-4.55, 0.0, inner_min.y + 0.3))
	_pegboard(Vector3(-1.6, 1.55, inner_min.y + 0.02))
	# Right wall: a tool cart under the orders, barrels and a broom (the crate delivery is a station).
	PhotoProp.place(self, "tool_cart", Vector3(5.5, 0, -2.0), -90.0)
	prop("kaykit_prototype/Barrel_A.gltf", Vector3(5.3, 0.4, -3.9), 15.0, {solid = P.CYLINDER, tint = Color("#3f5f8a"), desaturate = 0.3})
	prop("kaykit_prototype/Barrel_B.gltf", Vector3(5.45, 0.4, -3.1), -30.0, {solid = P.CYLINDER, tint = Color("#8a4b2e"), desaturate = 0.3})
	_broom(Vector3(5.85, 0, 3.2))
	# A hand truck by the scrap and an extension cable across the floor.
	PhotoProp.place(self, "hand_truck", Vector3(-2.7, 0, -4.15), 20.0)
	_cable()
	_lamps()


## Scanned workshop equipment (PhotoProp) along the free stretches of the
## side and back walls: wherever no station and no other set piece stands.
func _workshop_gear() -> void:
	# The garage itself is full (car, shelving, stations): big halls only.
	if inner_max.x < 7.0:
		return
	var gear := ["tool_cart", "old_drill_press", "old_military_compressor", "metal_tool_chest", "hand_truck", "industrial_storage_cart", "power_box_01"]
	var spots: Array = []
	var x := inner_min.x + 1.2
	while x < inner_max.x - 1.0:
		spots.append([Vector3(x, 0, inner_min.y), Vector3(0, 0, 1), 0.0])
		x += 1.7
	var z := inner_min.y + 1.6
	while z < inner_max.y - 1.4:
		spots.append([Vector3(inner_max.x, 0, z), Vector3(-1, 0, 0), -90.0])
		spots.append([Vector3(inner_min.x, 0, z), Vector3(1, 0, 0), 90.0])
		z += 1.9
	# xz of everything in the way; y carries the clearance it needs (m).
	var blocked: Array[Vector3] = []
	for st in stations:
		if st is Node3D:
			blocked.append(Vector3((st as Node3D).position.x, 1.9, (st as Node3D).position.z))
	for child in get_children():
		# Wall colliders sit outside the floor rectangle and block nothing.
		if child is StaticBody3D and absf((child as StaticBody3D).position.x) < inner_max.x - 0.05 and (child as StaticBody3D).position.z > inner_min.y + 0.05:
			blocked.append(Vector3((child as StaticBody3D).position.x, 1.0, (child as StaticBody3D).position.z))
	var placed := 0
	var pick := int(absf(inner_max.x) * 3.0)
	for spot: Array in spots:
		if placed >= 5:
			break
		var name: String = gear[pick % gear.size()]
		var at: Vector3 = spot[0] + spot[1] * (PhotoProp.radius(name) + 0.12)
		var free := true
		for b in blocked:
			if Vector2(b.x - at.x, b.z - at.z).length() < b.y + PhotoProp.radius(name):
				free = false
				break
		if not free:
			if "--gear-log" in OS.get_cmdline_user_args():
				var near := blocked[0]
				for b in blocked:
					if Vector2(b.x - at.x, b.z - at.z).length() < Vector2(near.x - at.x, near.z - at.z).length():
						near = b
				print("SKIP ", at, " near ", near)
			continue
		PhotoProp.place(self, name, at, spot[2])
		if "--gear-log" in OS.get_cmdline_user_args():
			print("GEAR ", name, " ", at)
		blocked.append(Vector3(at.x, 1.2, at.z))
		placed += 1
		pick += 1


## Steel shelving (a model, a tenth of its file's size: 1.1 m wide, 2.1 m high) with boxes, a toolbox,
## a drill and tins on its boards.
func _shelving(base: Vector3) -> void:
	WorldBuilder.add_collider(self, Vector3(1.1, 2.14, 0.5), Transform3D(Basis(), base + Vector3(0, 1.07, 0)))
	if not EnvMesh.visual():
		return
	PhotoProp.stand(self, "steel_frame_shelves_01", base, 0.0, 0.1)
	# (The tops of its boards, from the floor up.)
	var boards := [0.115, 0.622, 1.128, 1.634]
	PhotoProp.stand(self, "cardboard_box_01", base + Vector3(-0.2, boards[0], 0.0), 94.0)
	PhotoProp.stand(self, "metal_toolbox", base + Vector3(0.27, boards[0], 0.02), 8.0)
	PhotoProp.stand(self, "metal_toolbox", base + Vector3(-0.24, boards[1], 0.02), -6.0)
	PhotoProp.stand(self, "small_oil_can_01", base + Vector3(0.18, boards[1], 0.05), 30.0)
	PhotoProp.stand(self, "oil_tin", base + Vector3(0.38, boards[1], -0.04), 70.0)
	PhotoProp.stand(self, "cardboard_box_01", base + Vector3(0.18, boards[2], 0.0), 88.0)
	PhotoProp.stand(self, "Drill_01", base + Vector3(-0.3, boards[2], 0.03), 20.0)
	PhotoProp.stand(self, "cardboard_box_01", base + Vector3(-0.2, boards[3], -0.02), 96.0)
	PhotoProp.stand(self, "oil_tin", base + Vector3(0.3, boards[3], 0.02), 15.0)


## A stack of old tyres (scans), lying flat one on the other.
func _tyres(base: Vector3, count: int) -> void:
	WorldBuilder.add_cylinder_collider(self, 0.31, count * 0.165 + 0.02, base)
	for i in count:
		var tyre := PhotoProp.stand(self, "old_tyre", Vector3.ZERO)
		if tyre:
			# (The scan stands upright on its tread, round its own middle.)
			tyre.transform = Transform3D(Basis(Vector3.UP, i * 0.9 + base.x) * Basis(Vector3.RIGHT, PI * 0.5),
				base + Vector3(0.015 * (i % 2), 0.082 + i * 0.163, 0.01 * i))


## Perforated hardboard with the tools on their hooks (scans): wrenches, hammers, a drill.
func _pegboard(center: Vector3) -> void:
	if not EnvMesh.visual():
		return
	var board := EnvMesh.wood("pegboard", {base_color = Color("#a67f58"), grain_color = Color("#7c5a3d"), weathering = 0.1,
		grain_strength = 0.2, roughness_base = 0.85})
	EnvMesh.add(self, EnvMesh.box(Vector3(2.2, 1.0, 0.02), 0.004), board, Transform3D(Basis(), center + Vector3(0, 0, 0.01)))
	var face := center + Vector3(0, 0, 0.022)
	var hung := [["pipe_wrench", -0.9, -0.02], ["cross_pein_hammer", -0.62, 0.02], ["pipe_wrench", -0.34, -0.26], ["cross_pein_hammer", -0.06, -0.02],
		["Drill_01", 0.28, 0.1], ["pipe_wrench", 0.62, -0.05], ["cross_pein_hammer", 0.9, -0.22]]
	for entry: Array in hung:
		PhotoProp.mount(self, entry[0], face + Vector3(entry[1], entry[2], 0), Vector3.BACK)


## A broom leaning in the corner (a scan).
func _broom(base: Vector3) -> void:
	var broom := PhotoProp.stand(self, "wooden_broom", base, 0.0)
	if broom:
		# Its head along the wall on its right, the stick leaned against that wall.
		broom.transform = Transform3D(Basis(Vector3.UP, -PI * 0.5) * Basis(Vector3.RIGHT, -0.2), base + Vector3(-0.14, 0.13, 0))


## Orange extension cable from a wall socket to the bench lamp, lying in loose curves.
func _cable() -> void:
	if not EnvMesh.visual():
		return
	var mat := EnvMesh.surface("garage_cable", {base_color = Color("#d06a2a"), roughness_base = 0.45, contact_dark = 0.0})
	var pts := PackedVector3Array()
	var start := Vector3(inner_max.x - 0.02, 0.35, -0.6)
	pts.append(start)
	pts.append(start + Vector3(-0.08, -0.32, 0))
	for i in 9:
		var t := float(i) / 8.0
		pts.append(Vector3(lerpf(5.7, 4.4, t), 0.015, lerpf(-0.6, -3.0, t) + sin(t * 7.0) * 0.18))
	EnvMesh.add(self, StationKit.tube(pts, 0.012, 6), mat, Transform3D(), false)


## Light: fluorescent strips under the ceiling (scans) and a caged lamp on the wall by the door. By
## day they only fill the corners the sky does not reach.
func _lamps() -> void:
	if not EnvMesh.visual():
		return
	for p: Vector3 in [Vector3(-1.0, height, -2.2), Vector3(-1.0, height, 1.6), Vector3(2.2, height, 0.2)]:
		TownBlock.strip_light(self, p, Color("#f4f6ff"))
		var light := OmniLight3D.new()
		light.light_color = Color("#eef2ff")
		light.light_energy = 0.7
		light.omni_range = 6.5
		light.omni_attenuation = 1.1
		light.light_specular = 0.3
		light.position = p + Vector3(0, -0.35, 0)
		add_child(light)
	PhotoProp.mount(self, "industrial_wall_lamp", Vector3(inner_min.x, 2.05, 3.6), Vector3.RIGHT)
	var warm := OmniLight3D.new()
	warm.light_color = Color("#ffcf9a")
	warm.light_energy = 0.9
	warm.omni_range = 4.5
	warm.position = Vector3(inner_min.x + 0.4, 2.1, 3.6)
	add_child(warm)


# --- Outside ----------------------------------------------------------------------

func _outside() -> void:
	var zf := inner_max.y + WALL * 0.5
	if EnvMesh.visual():
		# Photographed ground: pavers on the driveway, the pavement and the street beyond it, worn
		# concrete beside and behind the garage.
		var half := ground_size.x * 0.5
		var back := ground_z - ground_size.y * 0.5
		var front := ground_z + ground_size.y * 0.5
		var out_x := inner_max.x + WALL
		var yard := EnvMesh.scan(key + "_yard", "dirty_concrete", {drift = 0.2})
		_slab(EnvMesh.scan(key + "_drive", "concrete_pavers", {drift = 0.18, tint = Vector3(0.84, 0.88, 0.94)}), -half, half, zf, zf + 7.4)
		_slab(EnvMesh.scan(key + "_street", "asphalt_02", {drift = 0.22, tint = Vector3(0.7, 0.7, 0.72)}), -half, half, zf + 7.4, front)
		_slab(yard, -half, -out_x, back, zf)
		_slab(yard, out_x, half, back, zf)
		_slab(yard, -out_x, out_x, back, inner_min.y - WALL)
		# The kerb between driveway and street.
		EnvMesh.add(self, EnvMesh.box(Vector3(ground_size.x, 0.12, 0.2)), EnvMesh.scan(key + "_kerb", "dirty_concrete", {tile = 1.6, tint = Vector3(0.85, 0.85, 0.85)}),
			Transform3D(Basis(), Vector3(0, 0.03, zf + 7.4)))
	prop("kaykit_city/streetlight.gltf", Vector3(7.6, 0, zf + 5.2), 180.0, {scale = 0.95, solid = P.CYLINDER})
	for i in 7:
		prop("kaykit_city/bush.gltf", Vector3(inner_min.x - 0.45 - (i % 2) * 0.2, 0, zf + 0.4 + i * 0.85), i * 40.0, {scale = 1.1, solid = P.NONE})
		prop("kaykit_city/bush.gltf", Vector3(inner_max.x + 0.45 + (i % 2) * 0.2, 0, zf + 0.6 + i * 0.85), i * 55.0, {scale = 1.05, solid = P.NONE})
	TownBlock.dumpster(self, Vector3(inner_max.x + 1.6, 0, -1.5), 90.0)
	prop("kaykit_city/firehydrant.gltf", Vector3(5.6, 0, zf + 6.4), 0.0, {scale = 0.9, solid = P.CYLINDER})
	# Neighbours across the street and behind the garage: houses with photographed fronts.
	TownBlock.block(self, Vector3(-9.5, 0, zf + 13.5), 9.0, 8.0, {key = key + "_n1", scan = "red_brick", storeys = 2})
	TownBlock.block(self, Vector3(0.5, 0, zf + 14.0), 9.0, 8.0, {key = key + "_n2", scan = "yellow_plaster", storeys = 3})
	TownBlock.block(self, Vector3(10.5, 0, zf + 13.5), 9.0, 8.0, {key = key + "_n3", scan = "painted_worn_brick", storeys = 2})
	TownBlock.block(self, Vector3(-10.0, 0, -18.5), 9.0, 7.0, {key = key + "_n4", scan = "yellow_plaster", storeys = 2})
	TownBlock.block(self, Vector3(0.0, 0, -19.0), 9.0, 7.0, {key = key + "_n5", scan = "red_brick_03", storeys = 3})
	TownBlock.block(self, Vector3(10.0, 0, -18.5), 9.0, 7.0, {key = key + "_n6", scan = "red_brick", storeys = 2})
	TownBlock.block(self, Vector3(-20.5, 0, zf + 14.0), 10.0, 8.0, {key = key + "_n7", scan = "red_brick_03", storeys = 3})
	TownBlock.block(self, Vector3(21.5, 0, zf + 14.0), 10.0, 8.0, {key = key + "_n8", scan = "red_brick", storeys = 3})
	TownBlock.block(self, Vector3(-21.0, 0, zf - 6.0), 9.0, 9.0, {key = key + "_n9", scan = "yellow_plaster", storeys = 2})
	TownBlock.block(self, Vector3(21.0, 0, zf - 6.0), 9.0, 9.0, {key = key + "_n10", scan = "painted_worn_brick", storeys = 2})
	# Low garden walls keep workers on the driveway (the hedges grow before them); it is open to the street.
	_forecourt(7.2, 1.0, false)


## What keeps the workers before the hall: low brick walls with a coping on both sides, `side` metres
## out from the hall's walls, and the end of the forecourt `depth` metres before the door line. With
## `gate` a wall with an iron gate between two piers closes that end; without, it stays open to look
## at (nobody gets past it all the same).
func _forecourt(depth: float, side: float, gate: bool) -> void:
	var zf := inner_max.y + WALL * 0.5
	var x0 := inner_min.x - side
	var x1 := inner_max.x + side
	# [middle, size] of every stretch of low wall.
	var runs := [[Vector3(x0, 0, zf + depth * 0.5), Vector3(0.25, 1.1, depth)], [Vector3(x1, 0, zf + depth * 0.5), Vector3(0.25, 1.1, depth)]]
	for x: float in [x0, x1]:
		WorldBuilder.add_collider(self, Vector3(0.4, 1.2, depth), Transform3D(Basis(), Vector3(x, 0.6, zf + depth * 0.5)))
	WorldBuilder.add_collider(self, Vector3(x1 - x0 + 0.4, 3.0 if gate else 1.2, 0.4), Transform3D(Basis(), Vector3((x0 + x1) * 0.5, 1.5 if gate else 0.6, zf + depth)))
	var pier := 1.72
	if gate:
		runs.append([Vector3((x0 - pier) * 0.5, 0, zf + depth), Vector3(-pier - x0, 1.1, 0.25)])
		runs.append([Vector3((x1 + pier) * 0.5, 0, zf + depth), Vector3(x1 - pier, 1.1, 0.25)])
	if not EnvMesh.visual():
		return
	var brick := EnvMesh.scan(key + "_garden", "red_brick_03", {foot = 0.4, drift = 0.2})
	var walls := []
	var stones := []
	for run: Array in runs:
		var at: Vector3 = run[0]
		var size: Vector3 = run[1]
		walls.append(EnvMesh.piece(EnvMesh.box(size, 0.0), Transform3D(Basis(), at + Vector3(0, size.y * 0.5, 0))))
		stones.append(EnvMesh.piece(EnvMesh.box(Vector3(size.x + 0.09, 0.07, size.z + 0.09)), Transform3D(Basis(), at + Vector3(0, size.y + 0.035, 0))))
	if gate:
		for s: float in [-1.0, 1.0]:
			walls.append(EnvMesh.piece(EnvMesh.box(Vector3(0.46, 3.1, 0.46), 0.0), Transform3D(Basis(), Vector3(s * pier, 1.55, zf + depth))))
			stones.append(EnvMesh.piece(EnvMesh.box(Vector3(0.58, 0.12, 0.58)), Transform3D(Basis(), Vector3(s * pier, 3.16, zf + depth))))
		PhotoProp.stand(self, "large_iron_gate", Vector3(0, 0, zf + depth), 0.0)
	EnvMesh.add(self, EnvMesh.merge(walls), brick)
	EnvMesh.add(self, EnvMesh.merge(stones), TownBlock.stone())


# --- Camera and reflections ---------------------------------------------------------

func _collect_passthrough() -> void:
	if not is_inside_tree():
		return
	get_tree().node_added.connect(_on_node_added)
	for arm: SpringArm3D in get_tree().root.find_children("*", "SpringArm3D", true, false):
		_exclude_from(arm)


func _on_node_added(node: Node) -> void:
	if node is SpringArm3D:
		_exclude_from(node as SpringArm3D)


func _exclude_from(arm: SpringArm3D) -> void:
	for rid in _passthrough:
		arm.add_excluded_object(rid)


func _reflection_probe() -> void:
	if not EnvMesh.visual():
		return
	var probe := ReflectionProbe.new()
	probe.name = "GarageReflections"
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.size = Vector3(inner_max.x - inner_min.x + 0.8, height + 0.3, inner_max.y - inner_min.y + 0.6)
	probe.position = Vector3((inner_min.x + inner_max.x) * 0.5, height * 0.5, (inner_min.y + inner_max.y) * 0.5)
	# The front stands open to the day: paint and glass inside mirror the sky through it, and the
	# hall's own bounce is neutral.
	probe.interior = false
	probe.ambient_mode = ReflectionProbe.AMBIENT_COLOR
	probe.ambient_color = Color("#77736c")
	probe.ambient_color_energy = 0.55
	add_child(probe)
