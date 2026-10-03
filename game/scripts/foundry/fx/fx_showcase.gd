extends Node3D
## FX showcase: a dim foundry corner with a furnace fire, a crucible pouring
## into a filling mold, cooled alloy plaques and looping one-shot effects.
## Screenshot options after `--`: `--cam=wide|plates|mold|fire|samples|fill`
## and `--day` to keep the default daylight environment.

const LOOP := 2.5
const POUR_END := 2.1
const COLD_ALLOYS: Array[StringName] = [&"alu", &"brass", &"gold", &"verdigris"]

var _time := 0.0
var _mold_plate: ShaderMaterial
var _stream: PourStream
var _crucible: Node3D
var _spots := {}


func _ready() -> void:
	_build_lighting()
	_build_room()
	_build_furnace(Vector3(-2.4, 0, -1.9))
	_build_mold(Vector3(0.1, 0, 0.2))
	_build_crucible(Vector3(-0.62, 1.05, 0.2))
	_build_table(Vector3(1.9, 0, -1.9))
	_build_quench(Vector3(2.6, 0, 0.35))
	_build_samples(Vector3(7.0, 0, 0))
	_build_shakeout(Vector3(-1.5, 0, 1.3))
	_build_camera()


func _exit_tree() -> void:
	MetalMaterial.environment_brightness = 1.0


func _build_camera() -> void:
	var views := {
		"wide": [Vector3(2.1, 2.7, 3.7), Vector3(0.1, 0.5, -0.5)],
		"plates": [Vector3(2.0, 1.95, -0.3), Vector3(1.75, 0.8, -1.9)],
		"mold": [Vector3(0.9, 1.75, 1.75), Vector3(-0.05, 0.55, 0.15)],
		"fire": [Vector3(-1.3, 1.9, -0.4), Vector3(-2.4, 1.25, -1.9)],
		"samples": [Vector3(8.6, 2.3, 2.6), Vector3(8.6, 0.0, -0.2)],
		"fill": [Vector3(8.0, 1.2, 2.6), Vector3(8.0, 0.2, 1.2)],
	}
	var view: Array = views.wide
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cam="):
			view = views.get(arg.trim_prefix("--cam="), view)
	var cam := Camera3D.new()
	cam.fov = 48
	add_child(cam)
	cam.look_at_from_position(view[0], view[1])
	cam.add_child(OutlinePass.create())


func _process(delta: float) -> void:
	var before := fmod(_time, LOOP)
	_time += delta
	var now := fmod(_time, LOOP)
	if _crossed(before, now, 0.85):
		FoundryFX.steam_puff(self, _spots[&"quench"], 1.6)
	if _crossed(before, now, 1.2):
		FoundryFX.sand_burst(self, _spots[&"smash"], 1.0)
		FoundryFX.dust(self, _spots[&"smash"] + Vector3(0.3, -0.3, 0.2))
	if _crossed(before, now, 1.3):
		FoundryFX.sparks(self, _spots[&"furnace"], 36)
	var level := lerpf(-0.085, 0.05, minf(now / POUR_END, 1.0))
	MetalMaterial.set_fill(_mold_plate, level)
	_stream.flow = 1.0 if now < POUR_END else 0.0
	_stream.set_endpoints(_lip(), _spots[&"impact"] + Vector3(0, level, 0))


func _crossed(before: float, now: float, at: float) -> bool:
	return (before < at and now >= at) or (now < before and (before < at or now >= at))


func _build_lighting() -> void:
	WorldBuilder.add_environment(self)
	if "--day" in OS.get_cmdline_user_args():
		return
	MetalMaterial.environment_brightness = 0.5
	for child in get_children():
		if child is WorldEnvironment:
			var env: Environment = child.environment
			var sky: ProceduralSkyMaterial = env.sky.sky_material
			sky.sky_top_color = Color("#3a3442")
			sky.sky_horizon_color = Color("#5a4840")
			sky.ground_horizon_color = Color("#5a4840")
			sky.ground_bottom_color = Color("#2a221d")
			env.ambient_light_energy = 0.55
			env.fog_light_color = Color("#3b2d27")
			env.fog_density = 0.015
			env.glow_intensity = 0.8
			env.glow_bloom = 0.08
		elif child is DirectionalLight3D:
			child.light_color = Color("#b4c4ff")
			child.light_energy = 0.6
			child.rotation_degrees = Vector3(-50, 60, 0)


func _build_room() -> void:
	WorldBuilder.add_box(self, Vector3(14, 0.2, 14), Vector3(0, -0.1, 0), Color("#5a4b40"), true)
	var brick := Color("#664038")
	WorldBuilder.add_box(self, Vector3(9, 4, 0.3), Vector3(0.5, 2, -2.9), brick, true)
	WorldBuilder.add_box(self, Vector3(0.3, 4, 7), Vector3(-3.6, 2, 0.5), brick, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 26:
		var x := rng.randf_range(-3.2, 4.5)
		var y := rng.randi_range(1, 14) * 0.24
		var shade := brick.lightened(rng.randf_range(0.0, 0.18)) if rng.randf() < 0.7 else brick.darkened(0.15)
		WorldBuilder.add_box(self, Vector3(0.42, 0.18, 0.06), Vector3(snappedf(x, 0.44), y, -2.73), shade)
	for i in 14:
		var z := rng.randf_range(-2.5, 3.5)
		var y := rng.randi_range(1, 14) * 0.24
		WorldBuilder.add_box(self, Vector3(0.06, 0.18, 0.42), Vector3(-3.43, y, snappedf(z, 0.44)), brick.lightened(rng.randf_range(0.0, 0.15)))


func _build_furnace(pos: Vector3) -> void:
	var body := _cylinder(0.5, 0.46, 0.9, Color("#3d4048"), pos + Vector3(0, 0.45, 0))
	body.name = "Furnace"
	_cylinder(0.53, 0.53, 0.08, Color("#8f7f6c"), pos + Vector3(0, 0.92, 0))
	var coals := _cylinder(0.4, 0.4, 0.04, Color("#2a1a12"), pos + Vector3(0, 0.97, 0))
	var embers := MetalMaterial.create(&"iron")
	embers.set_shader_parameter(&"base_color", Color("#2a1d18"))
	embers.set_shader_parameter(&"metallic", 0.0)
	MetalMaterial.set_temperature(embers, 0.6)
	coals.material_override = embers
	var fire := FurnaceFire.new()
	fire.radius = 0.3
	fire.height = 0.9
	fire.position = pos + Vector3(0, 0.95, 0)
	add_child(fire)
	fire.heat = 0.8
	_spots[&"furnace"] = pos + Vector3(0.3, 1.0, 0.3)


func _build_mold(pos: Vector3) -> void:
	var plate_size := Vector3(0.8, 0.16, 0.5)
	var top := 0.5
	var sand := Color("#b99566")
	var gap := 0.015
	var cav := Vector3(plate_size.x + gap * 2, plate_size.y, plate_size.z + gap * 2)
	var outer := Vector3(1.3, top, 1.0)
	_slab(Vector3(outer.x, top - cav.y, outer.z), pos + Vector3(0, (top - cav.y) * 0.5, 0), sand)
	var side_w := (outer.x - cav.x) * 0.5
	var side_d := (outer.z - cav.z) * 0.5
	var y := top - cav.y * 0.5
	for sx in [-1, 1]:
		_slab(Vector3(side_w, cav.y, outer.z), pos + Vector3(sx * (cav.x + side_w) * 0.5, y, 0), sand)
	for sz in [-1, 1]:
		_slab(Vector3(cav.x, cav.y, side_d), pos + Vector3(0, y, sz * (cav.z + side_d) * 0.5), sand)
	var wood := Color("#8a5a35")
	for sz in [-1, 1]:
		WorldBuilder.add_box(self, Vector3(outer.x + 0.12, top + 0.04, 0.06), pos + Vector3(0, (top + 0.04) * 0.5, sz * (outer.z * 0.5 + 0.03)), wood)
	for sx in [-1, 1]:
		WorldBuilder.add_box(self, Vector3(0.06, top + 0.04, outer.z), pos + Vector3(sx * (outer.x * 0.5 + 0.03), (top + 0.04) * 0.5, 0), wood)
	var plate := MeshInstance3D.new()
	plate.mesh = MeshFactory.rounded_box(plate_size, 0.04)
	_mold_plate = MetalMaterial.create(&"bronze")
	MetalMaterial.set_temperature(_mold_plate, 0.88)
	MetalMaterial.set_fill(_mold_plate, 0.0)
	plate.material_override = _mold_plate
	plate.position = pos + Vector3(0, top - plate_size.y * 0.5, 0)
	add_child(plate)
	_spots[&"impact"] = plate.position + Vector3(-0.28, 0.0, 0.0)


func _build_crucible(pos: Vector3) -> void:
	_crucible = Node3D.new()
	_crucible.position = pos
	_crucible.rotation = Vector3(0, 0, deg_to_rad(-62))
	add_child(_crucible)
	var shell := CylinderMesh.new()
	shell.top_radius = 0.2
	shell.bottom_radius = 0.15
	shell.height = 0.4
	shell.cap_top = false
	var outer := MeshInstance3D.new()
	outer.mesh = shell
	var hot := MetalMaterial.create(&"iron")
	hot.set_shader_parameter(&"base_color", Color("#7a6a60"))
	hot.set_shader_parameter(&"metallic", 0.0)
	hot.set_shader_parameter(&"roughness", 0.9)
	MetalMaterial.set_temperature(hot, 0.22)
	outer.material_override = hot
	_crucible.add_child(outer)
	var inside := CylinderMesh.new()
	inside.top_radius = 0.18
	inside.bottom_radius = 0.13
	inside.height = 0.38
	inside.cap_top = false
	var inner := MeshInstance3D.new()
	inner.mesh = inside
	var clay := WorldBuilder.material(Color("#3a2c26"), 0.9)
	clay.cull_mode = BaseMaterial3D.CULL_FRONT
	inner.material_override = clay
	inner.position.y = 0.01
	_crucible.add_child(inner)
	var rim := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.175
	torus.outer_radius = 0.215
	rim.mesh = torus
	rim.material_override = hot
	rim.position.y = 0.2
	_crucible.add_child(rim)
	var melt := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.15
	disc.bottom_radius = 0.15
	disc.height = 0.01
	melt.mesh = disc
	var mat := MetalMaterial.create(&"bronze")
	MetalMaterial.set_temperature(mat, 0.9)
	melt.material_override = mat
	_crucible.add_child(melt)
	melt.global_transform = Transform3D(Basis.IDENTITY, _crucible.to_global(Vector3(0.02, 0.05, 0)))
	var bar := WorldBuilder.add_box(self, Vector3(1.2, 0.05, 0.05), Vector3.ZERO, Color("#2d2f36"))
	bar.global_transform = Transform3D(Basis(Vector3.FORWARD, deg_to_rad(-8)), _crucible.to_global(Vector3(0, -0.02, 0)) + Vector3(-0.7, 0.05, 0))
	var glow := OmniLight3D.new()
	glow.light_color = Color("#ff9040")
	glow.light_energy = 0.8
	glow.omni_range = 1.5
	_crucible.add_child(glow)
	glow.global_position = _lip() + Vector3(0.1, 0.1, 0.15)
	_stream = PourStream.new()
	add_child(_stream)
	_stream.flow = 1.0


func _lip() -> Vector3:
	return _crucible.to_global(Vector3(0.2, 0.19, 0))


func _build_table(pos: Vector3) -> void:
	var wood := Color("#7a5232")
	WorldBuilder.add_box(self, Vector3(1.6, 0.08, 1.1), pos + Vector3(0, 0.76, 0), wood)
	for lx in [-0.7, 0.7]:
		for lz in [-0.45, 0.45]:
			WorldBuilder.add_box(self, Vector3(0.08, 0.72, 0.08), pos + Vector3(lx, 0.36, lz), wood.darkened(0.2))
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("#ffd8a8")
	lamp.light_energy = 1.4
	lamp.omni_range = 3.0
	lamp.position = pos + Vector3(0.1, 1.75, 0.45)
	add_child(lamp)
	var shade := _cylinder(0.08, 0.22, 0.16, Color("#3f5a4c"), lamp.position + Vector3(0, 0.1, 0))
	var bulb := _cylinder(0.06, 0.06, 0.03, Color.WHITE, lamp.position + Vector3(0, 0.02, 0))
	var bulb_mat := WorldBuilder.material(Color("#fff0d0"))
	bulb_mat.emission_enabled = true
	bulb_mat.emission = Color("#ffe0b0")
	bulb_mat.emission_energy_multiplier = 4.0
	bulb.material_override = bulb_mat
	_cylinder(0.01, 0.01, 1.2, Color("#222222"), shade.position + Vector3(0, 0.66, 0))
	var plaque := _plaque_mesh()
	var slots := [Vector3(-0.4, 0, -0.25), Vector3(0.4, 0, -0.25), Vector3(-0.4, 0, 0.25), Vector3(0.4, 0, 0.25)]
	for i in COLD_ALLOYS.size():
		_add_plaque(plaque, COLD_ALLOYS[i], 0.0, pos + Vector3(0, 0.83, 0) + slots[i], deg_to_rad(-12 + i * 9))
	_add_plaque(plaque, &"bronze", 0.5, Vector3(1.45, 0.03, 0.75), 0.3)


func _add_plaque(mesh: Mesh, alloy: StringName, temperature: float, pos: Vector3, yaw: float, size := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := MetalMaterial.create(alloy)
	MetalMaterial.set_temperature(mat, temperature)
	mi.material_override = mat
	mi.position = pos
	mi.rotation.y = yaw
	mi.scale = Vector3.ONE * size
	add_child(mi)
	return mi


func _build_quench(pos: Vector3) -> void:
	_cylinder(0.38, 0.34, 0.5, Color("#4d5a63"), pos + Vector3(0, 0.25, 0))
	var water := _cylinder(0.34, 0.34, 0.02, Color("#2f5466"), pos + Vector3(0, 0.46, 0))
	water.material_override = WorldBuilder.material(Color("#24485a"), 0.08)
	_spots[&"quench"] = pos + Vector3(0, 0.5, 0)


## Freshly broken sand block with a still-warm casting sitting in it.
func _build_shakeout(pos: Vector3) -> void:
	var sand := Color("#b99566")
	WorldBuilder.add_box(self, Vector3(0.7, 0.28, 0.55), pos + Vector3(0, 0.14, 0), sand)
	WorldBuilder.add_box(self, Vector3(0.3, 0.16, 0.25), pos + Vector3(0.45, 0.08, 0.25), sand.darkened(0.08))
	var piece := MeshInstance3D.new()
	piece.mesh = MeshFactory.rounded_box(Vector3(0.42, 0.06, 0.3), 0.025)
	var mat := MetalMaterial.create(&"iron")
	MetalMaterial.set_temperature(mat, 0.32)
	MetalMaterial.set_defects(mat, 0.6)
	piece.material_override = mat
	piece.position = pos + Vector3(0, 0.3, 0)
	piece.rotation.y = 0.25
	add_child(piece)
	_spots[&"smash"] = pos + Vector3(0, 0.32, 0)


## Off-stage sample rows for close-up checks: cooling ramp, defects, all alloys.
func _build_samples(pos: Vector3) -> void:
	WorldBuilder.add_box(self, Vector3(4.2, 0.1, 3.2), pos + Vector3(1.6, 0.05, -0.2), Color("#5a4b40"))
	var light := OmniLight3D.new()
	light.light_color = Color("#ffe2c0")
	light.light_energy = 1.5
	light.omni_range = 5.0
	light.position = pos + Vector3(1.4, 1.8, 1.0)
	add_child(light)
	var plaque := _plaque_mesh()
	var temps := [0.0, 0.1, 0.2, 0.35, 0.5, 0.65, 0.8, 1.0]
	for i in temps.size():
		_add_plaque(plaque, &"bronze", temps[i], pos + Vector3(i * 0.45, 0.13, -1.2), 0.0, 0.6)
	var defects := [0.0, 0.3, 0.6, 1.0]
	for i in defects.size():
		var mi := _add_plaque(plaque, &"bronze", 0.0, pos + Vector3(i * 0.8, 0.13, -0.4), 0.0)
		MetalMaterial.set_defects(mi.material_override, defects[i])
	var ids := Alloys.ids()
	for i in ids.size():
		_add_plaque(plaque, ids[i], 0.0, pos + Vector3(i * 0.48, 0.13, 0.5), 0.0, 0.7)
	var block := MeshFactory.rounded_box(Vector3(0.4, 0.3, 0.3), 0.05)
	for i in 4:
		var mi := _add_plaque(block, &"gold", 0.9, pos + Vector3(i * 0.7, 0.25, 1.2), 0.5)
		MetalMaterial.set_fill(mi.material_override, -0.15 + 0.3 * (i + 0.5) / 4.0)


## Relief plaque placeholder: slab with a raised rim and a diamond emblem.
func _plaque_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(MeshFactory.rounded_box(Vector3(0.6, 0.05, 0.42), 0.02), 0, Transform3D.IDENTITY)
	var rim := [[Vector3(0.6, 0.04, 0.05), Vector3(0, 0.03, 0.185)], [Vector3(0.6, 0.04, 0.05), Vector3(0, 0.03, -0.185)],
		[Vector3(0.05, 0.04, 0.42), Vector3(0.275, 0.03, 0)], [Vector3(0.05, 0.04, 0.42), Vector3(-0.275, 0.03, 0)]]
	for r in rim:
		st.append_from(MeshFactory.rounded_box(r[0], 0.018), 0, Transform3D(Basis.IDENTITY, r[1]))
	st.append_from(MeshFactory.rounded_box(Vector3(0.16, 0.07, 0.16), 0.035), 0, Transform3D(Basis(Vector3.UP, PI / 4), Vector3(0, 0.03, 0)))
	for sx in [-1, 1]:
		st.append_from(MeshFactory.rounded_box(Vector3(0.1, 0.05, 0.05), 0.02), 0, Transform3D(Basis.IDENTITY, Vector3(sx * 0.16, 0.03, 0)))
	return st.commit()


func _slab(size: Vector3, pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = MeshFactory.rounded_box(size, 0.01, 1)
	mi.material_override = WorldBuilder.material(color, 0.95)
	mi.position = pos
	add_child(mi)


func _cylinder(top: float, bottom: float, height: float, color: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = top
	cyl.bottom_radius = bottom
	cyl.height = height
	mi.mesh = cyl
	mi.material_override = WorldBuilder.material(color)
	mi.position = pos
	add_child(mi)
	return mi
