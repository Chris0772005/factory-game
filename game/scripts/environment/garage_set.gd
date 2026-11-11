class_name GarageSet
extends Node3D
## Level 2 set: a brick double garage turned foundry, at dusk. Seen as an
## open-fronted dollhouse: the roller door is up (the front is open towards
## the default camera), the roof only casts shadows (MeshInstance3D shadows-only)
## and the walls dissolve around the line of sight (env_cutaway), so the
## orbit camera may pass outside them. Outside: a paved driveway, the street
## lamp, hedges and the neighbours.
##
## Everything is CC0 or procedural (KayKit props via PropKit, docs/ASSETS.md).

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
var stations: Array = []
var _passthrough: Array[RID] = []
var _wall_mat: ShaderMaterial
var _trim_mat: ShaderMaterial


static func build(world: Node3D, level_stations: Array) -> GarageSet:
	var set := GarageSet.new()
	set.name = "GarageSet"
	set.stations = level_stations
	world.add_child(set)
	set._build()
	return set


## Wall and trim materials (halls override for their own look).
func _materials() -> void:
	_wall_mat = EnvMesh.material("garage_wall", "res://shaders/env_plaster.gdshader", {
		plaster = Color("#d8cab4"), grime = Color("#6f655c"), brick = Color("#a65a42"), mortar = Color("#c9b9a2"),
		chips = 0.45, streaks = 0.25, cutaway = true, brick_below = 0.95})
	_trim_mat = EnvMesh.wood("garage_trim", {base_color = Color("#5f6f73"), grain_color = Color("#3c474a"),
		weathering = 0.45, paint = 0.8, paint_color = Color("#3f6f78"), roughness_base = 0.7})


func _build() -> void:
	_materials()
	_floor()
	_walls()
	_front()
	_roof()
	_dressing()
	_outside()
	_collect_passthrough()
	_reflection_probe()


# --- Floor ---------------------------------------------------------------------

func _floor() -> void:
	var body := StaticBody3D.new()
	body.name = "GroundCollision"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40.0, 1.0, 40.0)
	shape.shape = box
	body.position = Vector3(0, -0.5, 2.0)
	body.add_child(shape)
	add_child(body)
	if not EnvMesh.visual():
		return
	var plane := PlaneMesh.new()
	plane.size = Vector2(40.0, 40.0)
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
	var mi := EnvMesh.add(self, plane, mat, Transform3D(Basis(), Vector3(0, 0, 2.0)), false)
	mi.name = "Floor"


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


func _wall_box(center: Vector3, size: Vector3) -> void:
	var body := WorldBuilder.add_collider(self, size, Transform3D(Basis(), center))
	body.add_to_group(CAMERA_PASSTHROUGH)
	_passthrough.append(body.get_rid())
	EnvMesh.add(self, EnvMesh.box(size, 0.015), _wall_mat, Transform3D(Basis(), center))


## Steel-framed workshop window: six panes, sill, the dusk sky behind.
func _window(center: Vector3, size: Vector2) -> void:
	if not EnvMesh.visual():
		return
	var glass := EnvMesh.material("garage_glass", "res://shaders/env_window.gdshader", {
		energy = 0.35, glow = Color("#b9a6d8"), room = Color("#43406a"), glass_dark = Color("#1d2036"), glass_sky = Color("#7c6fa3")})
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
	var brick := EnvMesh.material("garage_brick", "res://shaders/env_plaster.gdshader", {
		brick = Color("#a65a42"), mortar = Color("#c9b9a2"), brickwork = 1.0, cutaway = true})
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


## Hand-painted shop sign on the back wall, over the pegboard.
func _sign() -> void:
	StationKit.label(self, "GIESSEREI", Transform3D(Basis(), Vector3(-1.6, 2.3, inner_min.y + 0.012)), 120, Color("#5b2f22"), 800, 0.0016)


## Shadows only: the interior is shaded from the low sun without hiding it from the camera.
func _roof() -> void:
	var size := Vector3(inner_max.x - inner_min.x + WALL * 2.0 + 0.6, 0.2, inner_max.y - inner_min.y + WALL * 2.0 + 0.5)
	var mi := EnvMesh.add(self, EnvMesh.box(size, 0.0), _wall_mat, Transform3D(Basis(), Vector3(0, height + 0.1, (inner_min.y + inner_max.y) * 0.5 + 0.1)))
	if mi:
		mi.name = "RoofShadow"
		# First person: a real ceiling overhead. Orbit view: only its shadow.
		if not CameraRig.first_person_default:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY


# --- Dressing --------------------------------------------------------------------

func prop(model: String, pos: Vector3, yaw := 0.0, opts := {}) -> Node3D:
	return PropKit.place(self, model, pos, yaw, opts)


func _dressing() -> void:
	# The family car, pushed into the left bay (the reason the foundry is small).
	# The kit model only lends its collider; the car itself is CarArt.
	var kit_car := prop("kaykit_city/car_stationwagon.gltf", CAR_POS, 180.0, {scale = 1.05, tint = Color("#b9c3cc"), desaturate = 0.35})
	if kit_car:
		kit_car.visible = false
	if EnvMesh.visual():
		CarArt.station_wagon(self, Transform3D(Basis(Vector3.UP, PI), CAR_POS), 4.3, 1.72, Color("#2f5e48"))
	# Tyres stacked by the car, a jerrycan and oil cans.
	_tyres(Vector3(-5.45, 0, 3.75), 3)
	_tyres(Vector3(-5.5, 0, -0.9), 2)
	prop("kaykit_prototype/Can_A.gltf", Vector3(-3.15, 0, 3.9), 25.0, {solid = P.NONE, tint = Color("#a33b2e"), desaturate = 0.2})
	prop("kaykit_prototype/Can_B.gltf", Vector3(-3.4, 0, 4.05), -10.0, {solid = P.NONE, tint = Color("#3f6f78"), desaturate = 0.2})
	# Back wall: steel shelving with boxes and paint tins, the pegboard, a cabinet.
	_shelving(Vector3(-4.55, 0.0, inner_min.y + 0.28))
	_pegboard(Vector3(-1.6, 1.55, inner_min.y + 0.02))
	prop("kaykit_furniture/cabinet_medium.gltf", Vector3(5.35, 0, -2.0), -90.0, {tint = Color("#8f9ca0"), desaturate = 0.4})
	# Right wall: barrels and a broom (the crate delivery is a station).
	prop("kaykit_prototype/Barrel_A.gltf", Vector3(5.3, 0.4, -3.9), 15.0, {solid = P.CYLINDER, tint = Color("#3f5f8a"), desaturate = 0.3})
	prop("kaykit_prototype/Barrel_B.gltf", Vector3(5.45, 0.4, -3.1), -30.0, {solid = P.CYLINDER, tint = Color("#8a4b2e"), desaturate = 0.3})
	_broom(Vector3(5.85, 0, 3.2))
	# A wheelbarrow by the scrap and an extension cable across the floor.
	prop("kaykit_hexagon/wheelbarrow.gltf", Vector3(-2.7, 0, -4.0), 75.0, {scale = 0.85})
	_cable()
	_lamps()


## Galvanised steel rack: four uprights, four shelves, cardboard boxes,
## paint tins and jars. One merged mesh per material.
func _shelving(base: Vector3) -> void:
	WorldBuilder.add_collider(self, Vector3(1.7, 2.1, 0.5), Transform3D(Basis(), base + Vector3(0, 1.05, 0)))
	if not EnvMesh.visual():
		return
	var steel := EnvMesh.surface("garage_rack", {base_color = Color("#9aa0a4"), metallic_base = 0.55, roughness_base = 0.45, stains = 0.2})
	var card := EnvMesh.surface("garage_card", {base_color = Color("#b48b5c"), roughness_base = 0.9, macro = 0.12, contact_dark = 0.2})
	var tins := EnvMesh.surface("garage_tins", {base_color = Color("#3f6f78"), metallic_base = 0.4, roughness_base = 0.5})
	var rack := []
	var boxes := []
	var cans := []
	for sx: float in [-0.8, 0.8]:
		for sz: float in [-0.22, 0.22]:
			rack.append(EnvMesh.piece(EnvMesh.box(Vector3(0.04, 2.1, 0.04), 0.004), Transform3D(Basis(), base + Vector3(sx, 1.05, sz))))
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	for k in 4:
		var y := 0.12 + k * 0.6
		rack.append(EnvMesh.piece(EnvMesh.box(Vector3(1.66, 0.03, 0.48), 0.006), Transform3D(Basis(), base + Vector3(0, y, 0))))
		if k == 3:
			continue
		var x := -0.7
		while x < 0.6:
			var w := rng.randf_range(0.25, 0.45)
			if rng.randf() < 0.65:
				var h := rng.randf_range(0.2, 0.42)
				boxes.append(EnvMesh.piece(EnvMesh.box(Vector3(w, h, rng.randf_range(0.3, 0.42)), 0.01),
					Transform3D(Basis(Vector3.UP, rng.randf_range(-0.1, 0.1)), base + Vector3(x + w * 0.5, y + 0.015 + h * 0.5, 0))))
			else:
				for c in 2:
					cans.append(EnvMesh.piece(EnvMesh.cylinder(0.07, 0.07, 0.16, 10), Transform3D(Basis(), base + Vector3(x + 0.08 + c * 0.16, y + 0.095, rng.randf_range(-0.1, 0.1)))))
			x += w + 0.05
	EnvMesh.add(self, EnvMesh.merge(rack), steel)
	EnvMesh.add(self, EnvMesh.merge(boxes), card)
	EnvMesh.add(self, EnvMesh.merge(cans), tins)


func _tyres(base: Vector3, count: int) -> void:
	var rubber := EnvMesh.surface("garage_tyre", {base_color = Color("#2b2a2c"), roughness_base = 0.75, macro = 0.05, contact_dark = 0.1})
	var pieces := []
	for i in count:
		var tor := TorusMesh.new()
		tor.inner_radius = 0.17
		tor.outer_radius = 0.33
		tor.rings = 16
		tor.ring_segments = 8
		pieces.append(EnvMesh.piece(tor, Transform3D(Basis(Vector3.UP, i * 0.6).scaled(Vector3(1, 1.4, 1)), base + Vector3(0.02 * (i % 2), 0.115 + i * 0.225, 0))))
	EnvMesh.add(self, EnvMesh.merge(pieces), rubber)
	WorldBuilder.add_cylinder_collider(self, 0.34, count * 0.225 + 0.02, base)


## Perforated hardboard with outlined tool silhouettes and the tools on hooks.
func _pegboard(center: Vector3) -> void:
	if not EnvMesh.visual():
		return
	var board := EnvMesh.wood("pegboard", {base_color = Color("#a67f58"), grain_color = Color("#7c5a3d"), weathering = 0.1,
		grain_strength = 0.2, roughness_base = 0.85})
	EnvMesh.add(self, EnvMesh.box(Vector3(2.2, 1.0, 0.02), 0.004), board, Transform3D(Basis(), center + Vector3(0, 0, 0.01)))
	var steel := EnvMesh.surface("garage_tools", {base_color = Color("#8c9196"), metallic_base = 0.7, roughness_base = 0.4})
	var grip := EnvMesh.surface("garage_grips", {base_color = Color("#b8402f"), roughness_base = 0.55})
	var tools := []
	var grips := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 9:
		var x := center.x - 0.95 + i * 0.235
		var y := center.y + (0.18 if i % 2 == 0 else -0.12)
		var shaft := rng.randf_range(0.22, 0.38)
		# Wrench / screwdriver: a steel shaft and a coloured grip.
		tools.append(EnvMesh.piece(EnvMesh.box(Vector3(0.025, shaft, 0.015), 0.004), Transform3D(Basis(Vector3.BACK, rng.randf_range(-0.15, 0.15)), Vector3(x, y, center.z + 0.04))))
		if i % 3 != 1:
			grips.append(EnvMesh.piece(EnvMesh.box(Vector3(0.04, 0.1, 0.03), 0.01), Transform3D(Basis(), Vector3(x, y - shaft * 0.5, center.z + 0.045))))
	# A saw and a coil of wire on the right half.
	tools.append(EnvMesh.piece(EnvMesh.box(Vector3(0.55, 0.12, 0.008), 0.003), Transform3D(Basis(Vector3.BACK, 0.05), Vector3(center.x + 0.55, center.y - 0.33, center.z + 0.04))))
	var coil := TorusMesh.new()
	coil.inner_radius = 0.07
	coil.outer_radius = 0.1
	tools.append(EnvMesh.piece(coil, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(center.x - 0.65, center.y - 0.3, center.z + 0.05))))
	EnvMesh.add(self, EnvMesh.merge(tools), steel)
	EnvMesh.add(self, EnvMesh.merge(grips), grip)


func _broom(base: Vector3) -> void:
	if not EnvMesh.visual():
		return
	var wood := EnvMesh.wood("broom", {base_color = Color("#b48a5e"), weathering = 0.2})
	var stick := PackedVector3Array([base + Vector3(0, 0.08, 0), base + Vector3(0.0, 1.45, -0.32)])
	EnvMesh.add(self, StationKit.tube(stick, 0.016, 6), wood)
	EnvMesh.add(self, EnvMesh.box(Vector3(0.32, 0.08, 0.07), 0.01), wood, Transform3D(Basis(Vector3.RIGHT, -0.22), base + Vector3(0, 0.06, 0.02)))


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


## Light: two fluorescent battens on the back wall (cool), a caged bulkhead
## lamp by the door, and implied ceiling lights (shadowless omnis). The
## furnace remains the hottest, brightest light (Art Bible rule 2).
func _lamps() -> void:
	if not EnvMesh.visual():
		return
	var housing := EnvMesh.surface("garage_lamp_housing", {base_color = Color("#d9d9d4"), roughness_base = 0.4})
	var tube := StandardMaterial3D.new()
	tube.albedo_color = Color("#eef3ff")
	tube.emission_enabled = true
	tube.emission = Color("#dfe8ff")
	tube.emission_energy_multiplier = 3.2
	for x: float in [-3.0, 2.4]:
		var c := Vector3(x, 2.55, inner_min.y + 0.09)
		EnvMesh.add(self, EnvMesh.box(Vector3(1.3, 0.07, 0.1), 0.01), housing, Transform3D(Basis(), c), false)
		EnvMesh.add(self, EnvMesh.cylinder(0.022, 0.022, 1.2, 8), tube, Transform3D(Basis(Vector3.BACK, PI * 0.5), c + Vector3(0, -0.05, 0.03)), false)
		var light := OmniLight3D.new()
		light.light_color = Color("#d8e2ff")
		light.light_energy = 0.9
		light.omni_range = 6.5
		light.omni_attenuation = 1.3
		light.position = c + Vector3(0, -0.2, 0.6)
		light.shadow_enabled = x < 0.0 and not EnvQuality.disabled("shadows")
		add_child(light)
	# Implied ceiling lights: soft cool fill over the work area.
	for p: Vector3 in [Vector3(-1.2, 2.8, 0.6), Vector3(3.0, 2.8, 0.2)]:
		var fill := OmniLight3D.new()
		fill.light_color = Color("#ffe1bf")
		fill.light_energy = 0.75
		fill.omni_range = 6.0
		fill.omni_attenuation = 0.9
		fill.light_specular = 0.2
		fill.position = p
		add_child(fill)
	# Warm caged bulkhead lamp on the left wall by the door.
	var bulb := EnvMesh.material("garage_bulb", "res://shaders/env_bulb.gdshader", {energy = 2.0})
	var post := Vector3(inner_min.x + 0.12, 2.2, 3.6)
	EnvMesh.add(self, EnvMesh.sphere(0.09, 10, 6), bulb, Transform3D(Basis(), post), false)
	var warm := OmniLight3D.new()
	warm.light_color = Color("#ffb877")
	warm.light_energy = 1.4
	warm.omni_range = 5.0
	warm.position = post + Vector3(0.25, 0, 0)
	add_child(warm)


# --- Outside ----------------------------------------------------------------------

func _outside() -> void:
	var zf := inner_max.y + WALL * 0.5
	prop("kaykit_city/streetlight.gltf", Vector3(7.6, 0, zf + 5.2), 180.0, {scale = 0.95, solid = P.CYLINDER})
	for i in 7:
		prop("kaykit_city/bush.gltf", Vector3(inner_min.x - 1.2 - (i % 2) * 0.3, 0, zf + 0.4 + i * 0.85), i * 40.0, {scale = 1.1, solid = P.NONE})
		prop("kaykit_city/bush.gltf", Vector3(inner_max.x + 1.1 + (i % 2) * 0.3, 0, zf + 0.6 + i * 0.85), i * 55.0, {scale = 1.05, solid = P.NONE})
	prop("kaykit_city/dumpster.gltf", Vector3(inner_max.x + 1.5, 0, -1.5), 90.0, {scale = 0.8})
	prop("kaykit_city/firehydrant.gltf", Vector3(5.6, 0, zf + 6.4), 0.0, {scale = 0.9, solid = P.CYLINDER})
	# Neighbours across the street, and behind the garage.
	prop("kaykit_city/building_A_withoutBase.gltf", Vector3(-6.0, 0, zf + 14.0), 180.0, {solid = P.NONE, desaturate = 0.5})
	prop("kaykit_city/building_C_withoutBase.gltf", Vector3(2.5, 0, zf + 14.5), 180.0, {solid = P.NONE, desaturate = 0.5})
	prop("kaykit_city/building_F_withoutBase.gltf", Vector3(11.0, 0, zf + 13.5), 180.0, {solid = P.NONE, desaturate = 0.5})
	prop("kaykit_city/building_C_withoutBase.gltf", Vector3(-9.0, 0, -11.0), 0.0, {solid = P.NONE, desaturate = 0.5})
	prop("kaykit_city/building_A_withoutBase.gltf", Vector3(1.0, 0, -11.5), 0.0, {solid = P.NONE, desaturate = 0.5})
	prop("kaykit_city/building_F_withoutBase.gltf", Vector3(10.0, 0, -11.0), 0.0, {solid = P.NONE, desaturate = 0.5})
	# Low walls keep workers on the driveway.
	for x: float in [inner_min.x - 1.0, inner_max.x + 1.0]:
		WorldBuilder.add_collider(self, Vector3(0.4, 1.2, 7.0), Transform3D(Basis(), Vector3(x, 0.6, zf + 3.5)))
	WorldBuilder.add_collider(self, Vector3(16.0, 1.2, 0.4), Transform3D(Basis(), Vector3(0, 0.6, zf + 7.2)))


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
	probe.interior = true
	probe.ambient_mode = ReflectionProbe.AMBIENT_COLOR
	probe.ambient_color = Color("#3a3446")
	probe.ambient_color_energy = 0.6
	add_child(probe)
