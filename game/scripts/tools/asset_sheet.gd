extends Node3D
## Contact sheet for the imported model packs under `res://assets/models/`.
## Lays the models out in a labelled grid under the backyard dusk lighting and
## prints a size/triangle table (plus animation and bone names of rigged models).
## Arguments after `--`:
##   --mode=sheet|scale|anims
##                        sheet: every model fitted into a grid cell (default);
##                        scale: curated line-up at in-game size next to the workers;
##                        anims: the workers frozen in the key clips of the shared rig
##   --pack=<a,b,...>     sheet mode: only these pack folders (default: all packs)
##   --light=dusk|day     dusk = backyard environment (default), day = neutral check light
##   --dump               print animation and skeleton bone names of rigged models

const ROOT := "res://assets/models"
## Grid slot width and row depth (rows are deeper so tall models don't hide the next row).
const CELL := 2.4
const ROW := 3.0
## Largest dimension of a model inside its slot (sheet mode).
const FIT := 1.7
## Uniform scale that brings each pack to game metres (worker ≈ 1.75 m tall,
## workbench ≈ 0.8 m). Hexagon and City Builder are tabletop-sized packs.
const PACK_SCALE := {
	"kaykit_adventurers": 0.8,
	"kaykit_dungeon": 0.8,
	"kaykit_restaurant": 0.8,
	"kaykit_furniture": 0.8,
	"kaykit_halloween": 0.8,
	"kaykit_prototype": 0.8,
	"kaykit_hexagon": 4.0,
	"kaykit_city": 4.0,
	"kenney_platformer": 1.0,
}
## Weapon/prop meshes baked into the KayKit character files; hidden for the worker look.
const CHARACTER_PROPS := ["Sword", "Shield", "Axe", "Mug", "Crossbow", "Knife", "Throwable", "Spellbook", "Wand", "Staff"]
## Line-up for `--mode=scale`: [path, x, z, yaw (deg), scale override (0 = pack scale)].
const LINEUP := [
	["kaykit_adventurers/Barbarian.glb", 0.0, 1.6, 0.0, 0.0],
	["kaykit_adventurers/Knight.glb", 1.4, 1.6, 0.0, 0.0],
	["kaykit_adventurers/Mage.glb", 2.8, 1.6, 0.0, 0.0],
	["kaykit_adventurers/Rogue.glb", 4.2, 1.6, 0.0, 0.0],
	["kenney_platformer/grass.glb", -1.3, 1.8, 0.0, 0.0],
	["kaykit_dungeon/barrel_small.gltf", 5.8, 1.4, 0.0, 0.0],
	["kaykit_prototype/Barrel_A.gltf", 7.1, 1.4, 0.0, 0.0],
	["kaykit_hexagon/bucket_water.gltf", 8.3, 1.6, 0.0, 2.5],
	["kaykit_restaurant/crate.gltf", 9.8, 1.3, 10.0, 0.0],
	["kaykit_hexagon/wheelbarrow.gltf", 11.8, 1.4, -70.0, 2.8],
	["kaykit_prototype/Pallet_Small_Decorated_A.gltf", 13.8, 1.3, 0.0, 0.0],
	["kaykit_dungeon/table_long.gltf", 0.6, -1.6, 90.0, 0.0],
	["kaykit_restaurant/kitchentable_A.gltf", 3.6, -1.6, 0.0, 0.0],
	["kaykit_restaurant/extractorhood.gltf", 3.6, -1.6, 0.0, 0.0],
	["kaykit_furniture/shelf_B_large_decorated.gltf", 6.0, -1.9, 0.0, 0.0],
	["kaykit_halloween/lantern_standing.gltf", 7.7, -1.4, 0.0, 0.0],
	["kaykit_dungeon/keg.gltf", 9.3, -1.6, 0.0, 0.0],
	["kaykit_dungeon/crates_stacked.gltf", 11.4, -1.6, 0.0, 0.0],
	["kaykit_restaurant/pot_large.gltf", 13.6, -1.4, 0.0, 0.0],
	["kaykit_city/bush.gltf", -1.6, -4.6, 0.0, 0.0],
	["kaykit_halloween/fence.gltf", 0.8, -4.6, 0.0, 0.0],
	["kaykit_halloween/fence_pillar.gltf", 2.6, -4.6, 0.0, 0.0],
	["kaykit_hexagon/fence_wood_straight.gltf", 5.0, -4.6, 90.0, 2.4],
	["kaykit_halloween/post_lantern.gltf", 7.6, -4.6, 0.0, 0.0],
	["kaykit_hexagon/resource_lumber.gltf", 10.0, -4.4, 0.0, 0.0],
	["kaykit_city/streetlight.gltf", 13.8, -4.8, 0.0, 0.0],
	["kaykit_city/building_A_withoutBase.gltf", 1.8, -10.0, 0.0, 0.0],
	["kaykit_city/dumpster.gltf", 7.4, -8.4, 0.0, 0.0],
	["kaykit_hexagon/tree_single_A.gltf", 10.6, -9.2, 0.0, 0.0],
	["kaykit_hexagon/rock_single_C.gltf", 13.6, -8.0, 0.0, 0.0],
]
## Clips shown by `--mode=anims`: [clip, fraction of the clip length to freeze at].
const CLIPS := [
	["Idle", 0.3], ["Walking_A", 0.25], ["Running_A", 0.25], ["Jump_Idle", 0.5], ["Jump_Land", 0.2], ["Dodge_Forward", 0.5],
	["PickUp", 0.5], ["Interact", 0.45], ["Use_Item", 0.4], ["Throw", 0.45], ["2H_Melee_Idle", 0.3], ["Blocking", 0.3],
	["2H_Melee_Attack_Chop", 0.3], ["2H_Melee_Attack_Chop", 0.55], ["1H_Melee_Attack_Chop", 0.45], ["Unarmed_Melee_Attack_Kick", 0.45],
	["Spellcasting", 0.3], ["Cheer", 0.4], ["Hit_A", 0.35], ["Death_A_Pose", 0.0], ["Lie_Pose", 0.0], ["Sit_Floor_Idle", 0.3],
	["Lie_StandUp", 0.5], ["Unarmed_Idle", 0.3],
]
const WORKERS := ["Barbarian", "Knight", "Mage", "Rogue"]

var _mode := "sheet"
var _pack := ""
var _light := "dusk"
var _dump := false
var _bounds := AABB()
## Screen-space labels, placed after the camera is framed: {pos, text, size, color, title}.
var _labels: Array[Dictionary] = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			_mode = arg.trim_prefix("--mode=")
		elif arg.begins_with("--pack="):
			_pack = arg.trim_prefix("--pack=")
		elif arg.begins_with("--light="):
			_light = arg.trim_prefix("--light=")
		elif arg == "--dump":
			_dump = true
	if _mode == "scale":
		_build_lineup()
	elif _mode == "anims":
		_build_anims()
	else:
		_build_sheet()
	_build_lighting()
	_build_ground()
	_place_labels(_frame_camera())


## Every model of every pack (or of `--pack`), each fitted into a CELL-sized slot.
func _build_sheet() -> void:
	var packs := _pack_dirs()
	var most := 1
	for pack in packs:
		most = maxi(most, _model_files(pack).size())
	# The all-packs overview packs more models per row and only names them.
	var overview := _pack.is_empty()
	var columns := 16 if overview else clampi(ceili(sqrt(most * 2.4)), 4, 12)
	var row := 0
	for pack in packs:
		var files := _model_files(pack)
		if files.is_empty():
			continue
		var title_pos := Vector3(-CELL * 1.0, 0, row * ROW)
		_labels.append({pos = title_pos, text = "%s\n%d models" % [pack, files.size()], size = 20 if overview else 26,
			color = Color("#ffd27a"), title = true})
		_grow(AABB(title_pos - Vector3(CELL * 0.6, 0, 0.5), Vector3(CELL * 0.6, 0.2, 1.0)))
		for i in files.size():
			var path: String = ROOT.path_join(pack).path_join(files[i])
			var slot := Vector3((i % columns) * CELL, 0, (row + i / columns) * ROW)
			var model := _instance(path)
			if model == null:
				continue
			var info := _measure(model)
			var box: AABB = info.aabb
			var fit := FIT / maxf(maxf(box.size.x, box.size.z), maxf(box.size.y * 0.8, 0.01))
			model.scale = Vector3.ONE * fit
			model.position = slot - Vector3(box.get_center().x, box.position.y, box.get_center().z) * fit
			var game := box.size * float(PACK_SCALE.get(pack, 1.0))
			var caption := "%s\n%.1f×%.1f×%.1f m\n%d tris" % [_short(files[i]), game.x, game.y, game.z, info.tris]
			_labels.append({pos = slot + Vector3(0, 0, FIT * 0.5 + 0.15), text = _short(files[i]) if overview else caption,
				size = 11 if overview else 14, color = Color.WHITE, title = false})
			_grow(AABB(slot - Vector3(CELL * 0.5, 0, FIT * 0.5), Vector3(CELL, FIT, ROW)))
			print("MODEL %s/%s size=(%.2f, %.2f, %.2f) tris=%d" % [pack, files[i], game.x, game.y, game.z, info.tris])
		row += ceili(files.size() / float(columns))


## Curated props at their in-game scale next to the four workers.
func _build_lineup() -> void:
	for entry in LINEUP:
		var model := _instance(ROOT.path_join(entry[0]))
		if model == null:
			continue
		var pack: String = entry[0].get_slice("/", 0)
		var scale_factor: float = entry[4] if entry[4] > 0.0 else float(PACK_SCALE.get(pack, 1.0))
		model.scale = Vector3.ONE * scale_factor
		model.position = Vector3(entry[1], 0, entry[2])
		model.rotation_degrees.y = entry[3]
		var info := _measure(model)
		var box: AABB = info.aabb
		_grow(box)
		var note := "" if entry[4] <= 0.0 else " (×%.1f)" % scale_factor
		_labels.append({pos = Vector3(box.get_center().x, 0, box.end.z + 0.1),
			text = "%s\n%.2f m%s" % [_short(entry[0]), box.size.y, note], size = 14, color = Color.WHITE, title = false})


## The four workers cycling through the key clips, each frozen at a telling frame.
func _build_anims() -> void:
	for i in CLIPS.size():
		var worker: String = WORKERS[i % WORKERS.size()]
		var model := _instance(ROOT.path_join("kaykit_adventurers/%s.glb" % worker))
		if model == null:
			continue
		model.scale = Vector3.ONE * float(PACK_SCALE.kaykit_adventurers)
		model.position = Vector3((i % 6) * 2.6, 0, (i / 6) * 3.4)
		model.rotation_degrees.y = 25.0
		var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var clip: String = CLIPS[i][0]
		var t := 0.0
		if player and player.has_animation(clip):
			t = player.get_animation(clip).length * float(CLIPS[i][1])
			_pose(model, clip, t)
		_grow(AABB(model.position - Vector3(1.0, 0, 1.0), Vector3(2.0, 1.8, 2.2)))
		_labels.append({pos = model.position + Vector3(0, 0, 0.9), text = "%s\n@ %.2f s" % [clip, t], size = 15, color = Color.WHITE, title = false})


func _short(path: String) -> String:
	return path.get_file().get_basename().get_basename()


func _instance(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		push_warning("Missing model " + path)
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		push_warning("Not a scene: " + path)
		return null
	var model := scene.instantiate() as Node3D
	add_child(model)
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player:
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			for word in CHARACTER_PROPS:
				if mi.name.contains(word):
					mi.visible = false
		if _dump:
			_dump_rig(path, model, player)
		if player.has_animation(&"Idle"):
			player.get_animation(&"Idle").loop_mode = Animation.LOOP_LINEAR
			player.play(&"Idle")
	return model


## Freezes a character in one frame of a clip.
func _pose(model: Node3D, anim: String, time: float) -> void:
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player and player.has_animation(anim):
		player.play(anim)
		player.seek(time, true)
		player.pause()


## Combined AABB (in this node's space) and triangle count of all visible meshes.
func _measure(model: Node3D) -> Dictionary:
	var box := AABB()
	var first := true
	var tris := 0
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if not mi.is_visible_in_tree() or mi.mesh == null:
			continue
		var b := global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
		for s in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(s)
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			tris += idx.size() / 3 if idx.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return {aabb = box, tris = tris}


func _dump_rig(path: String, model: Node3D, player: AnimationPlayer) -> void:
	print("RIG ", path)
	var clips := PackedStringArray()
	for a in player.get_animation_list():
		clips.append("%s %.2fs" % [a, player.get_animation(a).length])
	print("  animations (%d): %s" % [clips.size(), ", ".join(clips)])
	for skel: Skeleton3D in model.find_children("*", "Skeleton3D", true, false):
		var bones := PackedStringArray()
		for b in skel.get_bone_count():
			bones.append(skel.get_bone_name(b))
		print("  skeleton %s (%d bones): %s" % [model.get_path_to(skel), bones.size(), ", ".join(bones)])
	var meshes := PackedStringArray()
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var parent := mi.get_parent()
		var bone := " @%s" % (parent as BoneAttachment3D).bone_name if parent is BoneAttachment3D else ""
		meshes.append(String(model.get_path_to(mi)) + bone)
	print("  meshes: ", ", ".join(meshes))


func _grow(box: AABB) -> void:
	_bounds = box if _bounds.size == Vector3.ZERO else _bounds.merge(box)


func _pack_dirs() -> PackedStringArray:
	if not _pack.is_empty():
		return _pack.split(",", false)
	var dirs := DirAccess.get_directories_at(ROOT)
	dirs.sort()
	return dirs


func _model_files(pack: String) -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(ROOT.path_join(pack)):
		if f.get_extension() in ["glb", "gltf"]:
			out.append(f)
	out.sort()
	return out


## Reuses the backyard's own environment builder so the sheet tracks lighting changes.
## Distance fog is switched off: the sheet camera is much farther away than the game camera.
func _build_lighting() -> void:
	if _light == "day":
		_build_day_light()
		return
	var backyard: Node = load("res://scripts/levels/backyard.gd").new()
	if backyard.has_method(&"_build_environment"):
		backyard.call(&"_build_environment")
		for child in backyard.get_children():
			backyard.remove_child(child)
			add_child(child)
			if child is WorldEnvironment:
				(child as WorldEnvironment).environment.fog_enabled = false
				(child as WorldEnvironment).environment.volumetric_fog_enabled = false
	backyard.free()
	# Warm string-light fill like in the yard (one lamp every few metres).
	var x := _bounds.position.x
	while x <= _bounds.end.x + 0.1:
		var z := _bounds.position.z
		while z <= _bounds.end.z + 0.1:
			var lamp := OmniLight3D.new()
			lamp.light_color = Color("#ffc27a")
			lamp.light_energy = 0.9
			lamp.omni_range = 6.5
			lamp.position = Vector3(x, 3.1, z)
			add_child(lamp)
			z += 6.0
		x += 6.0


func _build_day_light() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#6f9ad6")
	sky_mat.sky_horizon_color = Color("#d9e4ef")
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("#fff1d6")
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120
	sun.rotation_degrees = Vector3(-50, -35, 0)
	add_child(sun)


func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(_bounds.size.x + 40, _bounds.size.z + 40)
	ground.mesh = plane
	ground.position = Vector3(_bounds.get_center().x, 0, _bounds.get_center().z)
	ground.material_override = WorldBuilder.material(Color("#4f7d55"), 0.9)
	add_child(ground)


func _frame_camera() -> Camera3D:
	var cam := Camera3D.new()
	cam.fov = 30
	add_child(cam)
	cam.add_child(OutlinePass.create())
	var center := _bounds.get_center()
	var pitch := deg_to_rad({"sheet": 56.0, "anims": 42.0}.get(_mode, 30.0))
	var half_w := _bounds.size.x * 0.5 + 0.6
	var half_h := _bounds.size.z * 0.5 * sin(pitch) + _bounds.size.y * 0.5 * cos(pitch) + 0.6
	var dist := (maxf(half_w / (16.0 / 9.0), half_h) / tan(deg_to_rad(cam.fov * 0.5)) + _bounds.size.y * 0.5) * 1.08
	cam.look_at_from_position(center + Vector3(0, sin(pitch), cos(pitch)) * dist, center)
	cam.make_current()
	if _light != "day":
		for child in get_children():
			if child is DirectionalLight3D:
				(child as DirectionalLight3D).directional_shadow_max_distance = dist + _bounds.size.z
	return cam


## Crisp screen-space captions under each model (3D labels blur at contact-sheet distance).
func _place_labels(cam: Camera3D) -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var font: Font = load("res://assets/fonts/Fredoka.ttf")
	for l in _labels:
		var settings := LabelSettings.new()
		settings.font = font
		settings.font_size = l.size
		settings.font_color = l.color
		settings.outline_size = 6
		settings.outline_color = Color(0, 0, 0, 0.85)
		settings.line_spacing = -2
		var label := Label.new()
		label.text = l.text
		label.label_settings = settings
		var p := cam.unproject_position(l.pos)
		if l.title:
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			label.size = Vector2(300, 60)
			label.position = p - Vector2(300, 30)
		else:
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.size = Vector2(260, 40)
			label.position = p - Vector2(130, 0)
		layer.add_child(label)
