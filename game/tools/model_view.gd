extends Node3D
## Art check: shows one model on the street's asphalt in the light of the first level (--plain: a plain sky and sun instead).
##   godot-render --path . res://tools/model_view.tscn -- --shot=out.png --model=res://...[,res://...] [--yaw=35] [--pitch=12] [--dist=9] [--h=1.4] [--dump]
##   ... --finish applies VehicleFinish (gloss, glass, lamps, dust and mud); --rig=0,-30,90,60 instead of --model shows the excavator rig posed (swing, boom, stick, bucket in degrees), --lamps with its lamps on. --hide=a,b hides the nodes of those names. --heap=2.5,1.1,3.0,1.76,1.0,0.42,0.9 shows a load of scrap (floor, rim, height, crown, fill). --row=a,b,c stands those Poly Haven scans side by side at their real size. --scrap=junk_gear,hot_pistol lays out things from the scrap. --anim=1.2 shows the model's first animation at that second (--clip=Run: that one; --clip=Run,Walk: one each for several models). --mats shows the stations' metal and wood on a block, a drum and a ball each. --details shows the small parts of MachineDetail on a steel plate. --station=furnace,cupola,line,hoist,crane,trough,mold,bench stands those stations of the halls side by side.

func _ready() -> void:
	var model := ""
	var yaw := 35.0
	var pitch := 12.0
	var dist := 9.0
	var h := 1.4
	var dump := false
	var rig := ""
	var finish := false
	var plain := false
	var lamps := false
	var hide := PackedStringArray()
	var heap := ""
	var row := PackedStringArray()
	var scrap := PackedStringArray()
	var anim_at := -1.0
	var clip_name := ""
	var mats := false
	var details := false
	var station := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--model="):
			model = arg.trim_prefix("--model=")
		elif arg.begins_with("--yaw="):
			yaw = float(arg.trim_prefix("--yaw="))
		elif arg.begins_with("--pitch="):
			pitch = float(arg.trim_prefix("--pitch="))
		elif arg.begins_with("--dist="):
			dist = float(arg.trim_prefix("--dist="))
		elif arg.begins_with("--h="):
			h = float(arg.trim_prefix("--h="))
		elif arg == "--dump":
			dump = true
		elif arg.begins_with("--rig="):
			rig = arg.trim_prefix("--rig=")
		elif arg == "--finish":
			finish = true
		elif arg == "--plain":
			plain = true
		elif arg == "--lamps":
			lamps = true
		elif arg.begins_with("--hide="):
			hide = arg.trim_prefix("--hide=").split(",")
		elif arg.begins_with("--heap="):
			heap = arg.trim_prefix("--heap=")
		elif arg.begins_with("--row="):
			row = arg.trim_prefix("--row=").split(",")
		elif arg.begins_with("--scrap="):
			scrap = arg.trim_prefix("--scrap=").split(",")
		elif arg.begins_with("--anim="):
			anim_at = float(arg.trim_prefix("--anim="))
		elif arg.begins_with("--clip="):
			clip_name = arg.trim_prefix("--clip=")
		elif arg == "--mats":
			mats = true
		elif arg == "--details":
			details = true
		elif arg.begins_with("--station="):
			station = arg.trim_prefix("--station=")
	if plain:
		_plain_light()
	else:
		# The light of the first level (scrap hall, daylight), so a model reads here as it will in the game.
		GarageLighting.build(self)
		GarageLighting.daylight(self)
	var ground_mat: Material
	if plain:
		var gm := StandardMaterial3D.new()
		gm.albedo_color = Color("#6b6964")
		gm.roughness = 0.95
		ground_mat = gm
	else:
		ground_mat = EnvMesh.scan("street_asphalt", "asphalt_02", {drift = 0.22, tint = Vector3(0.7, 0.7, 0.72)})
	EnvMesh.add(self, EnvMesh.box(Vector3(80.0, 0.04, 80.0), 0.0), ground_mat, Transform3D(Basis(), Vector3(0, -0.02, 0)), false)
	if rig != "":
		# --rig=swing_deg,boom,arm,bucket shows the excavator rig in that pose.
		var parts := rig.split(",")
		var digger := DiggerRig.new()
		add_child(digger)
		digger.set_pose(deg_to_rad(parts[0].to_float()), parts[1].to_float(), parts[2].to_float(), parts[3].to_float())
		digger.lamps_on = lamps
	elif model != "":
		# Several models (--model=a,b,c) stand side by side, 0.9 m apart.
		var paths := model.split(",")
		for i in paths.size():
			var packed := load(paths[i]) as PackedScene
			if packed == null:
				continue
			var node := packed.instantiate()
			add_child(node)
			if node is Node3D:
				(node as Node3D).position.x = (float(i) - float(paths.size() - 1) * 0.5) * 0.9
			if finish and node is Node3D:
				VehicleFinish.apply(node as Node3D)
			if dump:
				_dump(node, 0)
			if anim_at >= 0.0:
				# --anim=1.2: the model's first animation, held at that second. --clip=Run,Walk: the first
				# model shows Run, the second Walk, and so on round the list.
				var player := node.find_child("AnimationPlayer", true, false) as AnimationPlayer
				if player and not player.get_animation_list().is_empty():
					var clip := player.get_animation_list()[0]
					var wanted := clip_name.split(",")
					var mine := wanted[i % wanted.size()] if clip_name != "" else ""
					if mine != "" and player.has_animation(mine):
						clip = mine
					print("ANIMS ", player.get_animation_list(), " ", clip, " ", player.get_animation(clip).length)
					player.play(clip)
					player.seek(anim_at, true)
					player.pause()
	if heap != "":
		# --heap=2.5,1.1,3.0,1.76,1.0,0.42,0.9: a load of scrap (ScrapLoadArt.pile: floor x and z, rim x and z,
		# height, crown) filled to the last number.
		var dims := heap.split_floats(",")
		var load_art := ScrapLoadArt.pile(Vector2(dims[0], dims[1]), Vector2(dims[2], dims[3]), dims[4], dims[5])
		ScrapLoadArt.reveal(load_art, dims[6] if dims.size() > 6 else 1.0)
		add_child(load_art)
	if not scrap.is_empty():
		# --scrap=junk_gear,hot_pistol: those things from the scrap (ScrapModels) in rows of four, 30 cm
		# apart, each lifted to stand on the ground and turned a little.
		for i in scrap.size():
			var kind := StringName(scrap[i])
			var info: Dictionary = FoundryRules.JUNK.get(kind, FoundryRules.HOT.get(kind, FoundryRules.SCRAP.get(kind, {})))
			if info.is_empty() or not ScrapModels.has(kind):
				continue
			var size: Vector3 = info.size
			var at := Vector3((float(i % 4) - 1.5) * 0.36, size.y * 0.5 + 0.002, -float(i / 4) * 0.34)
			StationKit.add(self, ScrapModels.mesh(kind), ScrapModels.material(info.color, kind), Transform3D(Basis(Vector3.UP, 0.5), at))
	if not row.is_empty():
		# --row=a,b,c: scans side by side, 15 cm apart, the row centred.
		var total := -0.15
		for scan_name in row:
			total += PhotoProp._box(scan_name).size.x + 0.15
		var x := -total * 0.5
		for scan_name in row:
			var wide := PhotoProp._box(scan_name).size.x
			PhotoProp.place(self, scan_name, Vector3(x + wide * 0.5, 0, 0), 0.0, false)
			x += wide + 0.15
	if mats:
		_material_samples()
	if details:
		_detail_samples()
	if station != "":
		_stations(station.split(","))
	for part_name in hide:
		for part in find_children(part_name, "Node3D", true, false):
			(part as Node3D).visible = false
	var cam := Camera3D.new()
	cam.fov = 45.0
	var dir := Vector3(sin(deg_to_rad(yaw)) * cos(deg_to_rad(pitch)), sin(deg_to_rad(pitch)), cos(deg_to_rad(yaw)) * cos(deg_to_rad(pitch)))
	cam.position = Vector3(0, h, 0) + dir * dist
	add_child(cam)
	cam.look_at(Vector3(0, h, 0))
	cam.current = true


## --mats: the stations' materials (StationKit) on a block, a drum and a ball each, 75 cm apart:
## bare steel, cast iron, rusty steel, galvanised sheet, blue paint, worn yellow paint, bench wood, old timber, painted wood.
func _material_samples() -> void:
	var samples := [
		StationKit.metal("view_bare", {}),
		StationKit.metal("view_cast", {steel_color = Color("#3b3a3a"), rust = 0.45, metallic_steel = 0.35, roughness_steel = 0.6}),
		StationKit.metal("view_rusty", {rust = 0.85}),
		StationKit.metal("view_sheet", {scan = StationKit.METAL_SHEET, steel_color = Color("#8f979b"), rust = 0.3, metallic_steel = 0.45, roughness_steel = 0.5}),
		StationKit.metal("view_blue", {paint = 1.0, paint_color = Color("#3f6f8f"), rust = 0.2}),
		StationKit.metal("view_yellow", {paint = 0.8, paint_color = Color("#d9a520"), rust = 0.4}),
		StationKit.wood("view_bench", {base_color = Color("#8c6a4e")}),
		StationKit.wood("view_old", {base_color = Color("#6f5a48"), weathering = 0.75}),
		StationKit.wood("view_paint", {base_color = Color("#8c6a4e"), paint = 0.7, paint_color = Color("#2f6f73")}),
	]
	for i in samples.size():
		var x := (float(i) - float(samples.size() - 1) * 0.5) * 0.75
		StationKit.add(self, EnvMesh.box(Vector3(0.5, 0.5, 0.5), 0.02), samples[i], Transform3D(Basis(Vector3.UP, 0.3), Vector3(x, 0.25, 0)))
		StationKit.add(self, EnvMesh.cylinder(0.2, 0.2, 0.5, 24), samples[i], Transform3D(Basis(), Vector3(x, 0.25, 0.75)))
		StationKit.add(self, EnvMesh.sphere(0.2, 24, 12), samples[i], Transform3D(Basis(), Vector3(x, 0.2, 1.4)))


## --details: the small parts of MachineDetail on a painted steel plate, to judge them close up
## (try --yaw=0 --pitch=6 --dist=2.7 --h=0.62).
func _detail_samples() -> void:
	var paint := StationKit.metal("view_plate", {paint_color = Color("#3f6f8f"), paint = 0.95, rust = 0.25})
	StationKit.add(self, EnvMesh.box(Vector3(1.6, 1.1, 0.02), 0.004), paint, Transform3D(Basis(), Vector3(0, 0.6, 0)))
	var front := 0.01
	var d := MachineDetail.Parts.new()
	MachineDetail.bolt_row(d, Vector3(-0.72, 1.08, front), Vector3(0.72, 1.08, front), 9, Vector3.BACK)
	MachineDetail.rivet_row(d, Vector3(-0.74, 0.15, front), Vector3(-0.74, 1.0, front), 12, Vector3.BACK)
	MachineDetail.weld(d, PackedVector3Array([Vector3(-0.5, 0.1, front), Vector3(-0.5, 1.02, front)]))
	# A pipe stub with two flanges, a weld round its foot, a hand wheel and a gauge.
	var pipe := StationKit.metal("view_pipe", {steel_color = Color("#5c6468"), rust = 0.4})
	StationKit.add(self, EnvMesh.cylinder(0.05, 0.05, 0.3, 16), pipe, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.5, 0.8, front + 0.15)))
	MachineDetail.flange(d, Vector3(0.5, 0.8, front + 0.012), Vector3.BACK, 0.1)
	MachineDetail.flange(d, Vector3(0.5, 0.8, front + 0.3), Vector3.BACK, 0.1)
	MachineDetail.weld_ring(d, Vector3(0.5, 0.8, front + 0.024), Vector3.BACK, 0.052, 0.01)
	MachineDetail.handwheel(d, Vector3(0.5, 0.8, front + 0.36), Vector3.BACK, 0.09)
	MachineDetail.gauge(self, Transform3D(Basis(), Vector3(0.5, 1.0, front + 0.1)), 0.045, 0.4)
	# A small door with two hinges and a grab handle; a lifting eye on top of the plate.
	StationKit.add(self, EnvMesh.box(Vector3(0.3, 0.36, 0.012), 0.004), paint, Transform3D(Basis(), Vector3(-0.2, 0.32, front + 0.006)))
	for y: float in [0.2, 0.44]:
		MachineDetail.hinge(d, Vector3(-0.355, y, front), Vector3.UP, Vector3.BACK, 0.07)
	MachineDetail.handle(d, Vector3(-0.09, 0.26, front + 0.012), Vector3(-0.09, 0.38, front + 0.012), Vector3.BACK)
	MachineDetail.lifting_eye(d, Vector3(0.0, 1.15, 0.0), Vector3.UP)
	MachineDetail.type_plate(self, Transform3D(Basis(), Vector3(-0.12, 0.8, front)), "MM IRONWORKS", ["TYPE K-3   No. 1958-07", "MAX 2500 kg/h"])
	# A switch box; its cable runs down the plate in clips, then free across the floor to a motor.
	MachineDetail.switch_box(self, Transform3D(Basis(), Vector3(0.18, 0.42, front)))
	MachineDetail.cable(d, PackedVector3Array([Vector3(0.18, 0.26, front + 0.012), Vector3(0.18, 0.03, front + 0.012)]), 0.01, Vector3.BACK, 0.2)
	MachineDetail.cable(d, PackedVector3Array([Vector3(0.18, 0.03, front + 0.012), Vector3(0.2, 0.012, 0.14), Vector3(0.42, 0.012, 0.45), Vector3(0.6, 0.012, 0.52), Vector3(0.66, 0.3, 0.52)]))
	MachineDetail.motor(self, Transform3D(Basis(Vector3.UP, 0.4), Vector3(0.78, 0, 0.6)))
	MachineDetail.commit(self, d)


## --station=furnace,cupola,line,hoist,crane,trough,mold,bench: those stations of the halls as the
## levels build them, 4.5 m apart (the cranes over a short span, so trolley and hook are near).
func _stations(names: PackedStringArray) -> void:
	for i in names.size():
		var node: Node3D = null
		match names[i]:
			"furnace":
				node = Furnace.new()
			"cupola":
				node = CupolaFurnace.new()
			"line":
				node = MoldLine.new()
			"hoist", "crane":
				var crane: ChainHoist = HallCrane.new() if names[i] == "crane" else ChainHoist.new()
				crane.x_range = Vector2(-2.5, 2.5)
				crane.z_range = Vector2(-1.0, 1.0)
				node = crane
			"trough":
				node = QuenchTrough.new()
			"mold":
				node = MoldBox.new()
			"bench":
				node = ModelBench.new()
		if node:
			node.position.x = (float(i) - float(names.size() - 1) * 0.5) * 4.5
			add_child(node)


## A plain sky and sun, without the level's grade (--plain).
func _plain_light() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#3f76c4")
	sky_mat.sky_horizon_color = Color("#bcd3ea")
	sky_mat.ground_horizon_color = Color("#8d8a84")
	sky_mat.ground_bottom_color = Color("#55524e")
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -38, 0)
	sun.light_energy = 2.2
	sun.shadow_enabled = true
	add_child(sun)


func _dump(n: Node, depth: int) -> void:
	if depth > 3 or n is MeshInstance3D:
		return
	var n3 := n as Node3D
	print("NODE ", "  ".repeat(depth), n.name, " pos=", n3.position.snapped(Vector3.ONE * 0.01) if n3 else "", " kids=", n.get_child_count())
	for c in n.get_children():
		_dump(c, depth + 1)
