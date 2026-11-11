class_name AutoArt
## Art for the AutoFoundry machines (blower, mold unit, overhead rail, ladle
## trolley), built from the MachineArt helpers. Pure presentation.


static func _lamp(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color.darkened(0.3)
	m.roughness = 0.25
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 0.25
	return m


static func _dome(parent: Node3D, mat: Material, at: Vector3, r := 0.028) -> void:
	var mesh := StationKit.lathe(PackedVector2Array([Vector2(0, 0), Vector2(r, 0), Vector2(r, r * 0.9), Vector2(r * 0.8, r * 1.5), Vector2(r * 0.45, r * 1.85), Vector2(0, r * 1.95)]), 16, 70.0)
	StationKit.add(parent, mesh, mat, Transform3D(Basis(), at), false)


## Electric blower on a skid, its ribbed duct running into the furnace foot.
## Adds a child "Blower" (with a spinning "Fan") to `parent`.
static func blower(parent: Node3D, at: Vector3, furnace_at: Vector3) -> void:
	var node := Node3D.new()
	node.name = "Blower"
	parent.add_child(node)
	node.global_transform = Transform3D(Basis.looking_at(Vector3(furnace_at.x - at.x, 0, furnace_at.z - at.z), Vector3.UP), at)
	var reach := Vector2(furnace_at.x - at.x, furnace_at.z - at.z).length() - Furnace.MOUTH_RADIUS - 0.08
	var blue := MachineArt.blue_mat()
	var skid := [EnvMesh.piece(EnvMesh.box(Vector3(0.52, 0.05, 0.46), 0.015, 2), Transform3D(Basis(), Vector3(0, 0.07, 0)))]
	for x: float in [-0.2, 0.2]:
		for z: float in [-0.17, 0.17]:
			skid.append(MachineArt.turned(MachineArt.foot_pad(), Vector3.UP, Vector3(x, 0, z), 12))
	skid.append(EnvMesh.piece(EnvMesh.box(Vector3(0.12, 0.2, 0.2), 0.02, 2), Transform3D(Basis(), Vector3(0.0, 0.2, 0.02))))
	StationKit.add_merged(node, skid, MachineArt.graphite_mat())
	# Volute: a fat drum with an outlet neck towards the furnace.
	var shell := [MachineArt.turned(PackedVector2Array([Vector2(0, 0), Vector2(0.19, 0), Vector2(0.215, 0.025), Vector2(0.215, 0.135), Vector2(0.19, 0.16), Vector2(0.09, 0.16),
		Vector2(0.09, 0.135), Vector2(0, 0.135)]), Vector3.LEFT, Vector3(0.08, 0.36, 0.0), 32)]
	shell.append(EnvMesh.piece(MachineArt.loft([[-0.28, 0.13, 0.13, 0.0, 0.47, 2.2], [-0.2, 0.14, 0.15, 0.0, 0.48, 2.6], [-0.05, 0.15, 0.17, 0.0, 0.47, 3.0], [0.02, 0.15, 0.12, 0.0, 0.45, 3.0]], 20), Transform3D()))
	StationKit.add_merged(node, shell, blue)
	var dark := [MachineArt.turned(MachineArt.motor(0.085, 0.26), Vector3.RIGHT, Vector3(0.08, 0.36, 0.0), 28)]
	dark.append(EnvMesh.piece(EnvMesh.box(Vector3(0.09, 0.05, 0.08), 0.012, 2), Transform3D(Basis(), Vector3(0.22, 0.47, 0.0))))
	StationKit.add_merged(node, dark, MachineArt.black_mat())
	var hw := MachineArt.bolt_circle(Vector3.LEFT, Vector3(-0.08, 0.36, 0), 0.165, 10, 0.009)
	hw.append(MachineArt.turned(MachineArt.drum(0.094, 0.012, 0.003), Vector3.LEFT, Vector3(-0.08, 0.36, 0), 24))
	StationKit.add_merged(node, hw, MachineArt.steel_mat())
	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color("#1a1a1d")
	rubber.roughness = 0.7
	StationKit.add(node, MachineArt.hose(PackedVector3Array([Vector3(0, 0.47, -0.27), Vector3(0, 0.45, -0.4), Vector3(0, 0.3, -reach * 0.75), Vector3(0, 0.22, -reach)]), 0.062, 14), rubber)
	# Intake fan behind a guard ring: spins about the drum axis.
	var fan := Node3D.new()
	fan.name = "Fan"
	fan.transform = Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(-0.07, 0.36, 0))
	node.add_child(fan)
	var blades := [MachineArt.turned(MachineArt.drum(0.03, 0.03, 0.004), Vector3.UP, Vector3(0, -0.01, 0), 12)]
	for k in 6:
		blades.append(EnvMesh.piece(EnvMesh.box(Vector3(0.028, 0.004, 0.075), 0.001), Transform3D(Basis(Vector3.UP, TAU * k / 6.0) * Basis(Vector3.BACK, 0.5), Basis(Vector3.UP, TAU * k / 6.0) * Vector3(0, 0, 0.05))))
	StationKit.add_merged(fan, blades, MachineArt.steel_mat())
	StationKit.label(node, "GEBLÄSE", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.345, 0.36, 0.0)), 20, Color("#f0e2c4"), 800, 0.001)


## Control and shaker unit at a mold's corner. Returns [node, ram lamp
## material, shake-out lamp material].
static func mold_unit(parent: Node3D, at: Vector3, mold_at: Vector3) -> Array:
	var node := Node3D.new()
	parent.add_child(node)
	node.global_transform = Transform3D(Basis.looking_at(Vector3(mold_at.x - at.x, 0, mold_at.z - at.z), Vector3.UP), at)
	var cab := [EnvMesh.piece(EnvMesh.box(Vector3(0.34, 0.78, 0.26), 0.03, 3), Transform3D(Basis(), Vector3(0, 0.47, 0)))]
	cab.append(EnvMesh.piece(EnvMesh.box(Vector3(0.36, 0.06, 0.28), 0.02, 2), Transform3D(Basis(), Vector3(0, 0.05, 0))))
	StationKit.add_merged(node, cab, MachineArt.blue_mat())
	var dark := [EnvMesh.piece(EnvMesh.box(Vector3(0.3, 0.2, 0.03), 0.012, 2), Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0, 0.9, 0.03)))]
	dark.append(EnvMesh.piece(EnvMesh.box(Vector3(0.26, 0.4, 0.012), 0.006), Transform3D(Basis(), Vector3(0, 0.42, 0.131))))
	dark.append(MachineArt.turned(MachineArt.motor(0.06, 0.2), Vector3.FORWARD, Vector3(0, 0.3, -0.12), 24))
	StationKit.add_merged(node, dark, MachineArt.graphite_mat())
	var hw := [MachineArt.turned(MachineArt.drum(0.012, 0.03, 0.002), Vector3.BACK, Vector3(0.1, 0.42, 0.137), 10)]
	for x: float in [-0.14, 0.14]:
		for y: float in [0.12, 0.82]:
			hw.append_array(MachineArt.bolt_circle(Vector3.BACK, Vector3(x, y, 0.131), 0.0, 1, 0.009))
	StationKit.add_merged(node, hw, MachineArt.steel_mat())
	var green := _lamp(Color("#59e07e"))
	var amber := _lamp(Color("#ffb347"))
	_dome(node, green, Vector3(-0.08, 0.99, 0.0))
	_dome(node, amber, Vector3(0.08, 0.99, 0.0))
	StationKit.label(node, "STAMPFAUTOMAT", Transform3D(Basis(), Vector3(0, 0.7, 0.1315)), 18, Color("#f0e2c4"), 800, 0.001)
	return [node, green, amber]


## Overhead I-beam from the hub over the furnace to a post beyond the mold.
static func rail(parent: Node3D, hub: Vector3, post_at: Vector3, hub_post: Vector3, with_hub: bool) -> Node3D:
	var node := Node3D.new()
	parent.add_child(node)
	var yellow := MachineArt.yellow_mat()
	var blue := MachineArt.blue_mat()
	var steel := MachineArt.steel_mat()
	var spans := [[hub, Vector3(post_at.x, hub.y, post_at.z)]]
	if with_hub:
		spans.append([Vector3(hub_post.x, hub.y, hub_post.z), hub])
	var beams := []
	for sp: Array in spans:
		var a: Vector3 = sp[0]
		var b: Vector3 = sp[1]
		var len := a.distance_to(b) + 0.12
		var xf := Transform3D(Basis.looking_at(b - a, Vector3.UP), (a + b) * 0.5)
		beams.append(EnvMesh.piece(EnvMesh.box(Vector3(0.012, 0.13, len), 0.004), xf * Transform3D(Basis(), Vector3(0, 0.085, 0))))
		for y: float in [0.02, 0.15]:
			beams.append(EnvMesh.piece(EnvMesh.box(Vector3(0.1, 0.014, len), 0.004), xf * Transform3D(Basis(), Vector3(0, y, 0))))
	StationKit.add_merged(node, beams, yellow)
	var posts := []
	var feet := []
	var tops: Array[Vector3] = [post_at]
	if with_hub:
		tops.append(hub_post)
	for p in tops:
		posts.append(EnvMesh.piece(EnvMesh.box(Vector3(0.1, hub.y + 0.02, 0.1), 0.014, 2), Transform3D(Basis(), Vector3(p.x, (hub.y + 0.02) * 0.5, p.z))))
		posts.append(EnvMesh.piece(EnvMesh.box(Vector3(0.26, 0.02, 0.26), 0.008), Transform3D(Basis(), Vector3(p.x, 0.01, p.z))))
		posts.append(EnvMesh.piece(EnvMesh.box(Vector3(0.2, 0.03, 0.2), 0.008), Transform3D(Basis(), Vector3(p.x, hub.y + 0.005, p.z))))
		feet.append_array(MachineArt.bolt_circle(Vector3.UP, Vector3(p.x, 0.02, p.z), 0.14, 4, 0.011))
	StationKit.add_merged(node, posts, blue)
	StationKit.add_merged(node, feet, steel)
	return node


## Carriage on the rail with a telescoping hanger, bail and tilting ladle.
static func trolley(carriage: Node3D, hanger: Node3D, pot: Node3D, melt: MeshInstance3D, drop: float) -> void:
	var steel := MachineArt.steel_mat()
	var graphite := MachineArt.graphite_mat()
	var cart := [EnvMesh.piece(EnvMesh.box(Vector3(0.22, 0.12, 0.2), 0.025, 3), Transform3D(Basis(), Vector3(0, -0.08, 0)))]
	cart.append(MachineArt.turned(MachineArt.drum(0.045, 0.24, 0.006), Vector3.UP, Vector3(0, -0.36, 0), 18))
	StationKit.add_merged(carriage, cart, graphite)
	var wheels := []
	for x: float in [-0.085, 0.085]:
		for z: float in [-0.06, 0.06]:
			wheels.append(MachineArt.turned(MachineArt.drum(0.032, 0.02, 0.004), Vector3.RIGHT if x > 0.0 else Vector3.LEFT, Vector3(x * 0.55, 0.045, z), 14))
	StationKit.add_merged(carriage, wheels, steel)
	StationKit.add(carriage, MachineArt.turned(MachineArt.motor(0.04, 0.15), Vector3.RIGHT, Vector3(0.1, -0.08, 0), 20)[0], MachineArt.black_mat(),
		Transform3D(Basis(Vector3.BACK, -PI * 0.5), Vector3(0.1, -0.08, 0)))
	# Hanger: rod sliding in the carriage sleeve, cross head, U-bail to the trunnions.
	var rod := [MachineArt.turned(MachineArt.drum(0.022, drop + 0.1, 0.004), Vector3.UP, Vector3(0, 0.5, 0), 12)]
	rod.append(EnvMesh.piece(EnvMesh.box(Vector3(0.12, 0.05, 0.06), 0.012, 2), Transform3D(Basis(), Vector3(0, 0.5, 0))))
	for x: float in [-0.215, 0.215]:
		rod.append(MachineArt.turned(MachineArt.drum(0.02, 0.05, 0.004), Vector3.RIGHT if x > 0.0 else Vector3.LEFT, Vector3(x - signf(x) * 0.03, 0.13, 0), 12))
	StationKit.add_merged(hanger, rod, steel)
	StationKit.add(hanger, MachineArt.pipe(PackedVector3Array([Vector3(-0.225, 0.13, 0), Vector3(-0.225, 0.36, 0), Vector3(-0.18, 0.45, 0), Vector3(-0.06, 0.49, 0), Vector3(0.06, 0.49, 0),
		Vector3(0.18, 0.45, 0), Vector3(0.225, 0.36, 0), Vector3(0.225, 0.13, 0)]), 0.014), graphite)
	# Ladle: thick-walled pot with a rim band and a pouring lip (pivot at the trunnions).
	var shell := StationKit.metal("auto_ladle", {steel_color = Color("#4a4744"), rust = 0.3, soot = 0.4, dents = 0.25, metallic_steel = 0.6, roughness_steel = 0.55})
	var body := [MachineArt.turned(PackedVector2Array([Vector2(0, -0.13), Vector2(0.14, -0.13), Vector2(0.155, -0.11), Vector2(0.185, 0.1), Vector2(0.195, 0.1), Vector2(0.195, 0.135),
		Vector2(0.165, 0.135), Vector2(0.14, -0.07), Vector2(0, -0.07)]), Vector3.UP, Vector3.ZERO, 28)]
	body.append(EnvMesh.piece(MachineArt.loft([[0.15, 0.1, 0.03, 0.0, 0.115, 2.5], [0.2, 0.07, 0.024, 0.0, 0.122, 2.5], [0.235, 0.035, 0.014, 0.0, 0.128, 2.5]], 12), Transform3D()))
	StationKit.add_merged(pot, body, shell)
	var hot := StandardMaterial3D.new()
	hot.albedo_color = Color("#ff9a3a")
	hot.emission_enabled = true
	hot.emission = Color("#ff8a2e")
	hot.emission_energy_multiplier = 3.0
	melt.mesh = EnvMesh.cylinder(0.158, 0.158, 0.01, 24)
	melt.material_override = hot
	melt.position = Vector3(0, 0.07, 0)
	melt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
