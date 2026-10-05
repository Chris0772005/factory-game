class_name YardHouse
## Procedural houses: the family home behind the yard (full detail: tiled
## gable roof with gutter and downpipe, chimney, quoins, framed windows with
## shutters and flower boxes, back door with steps, canopy and a wall lamp)
## and simpler neighbour houses as background silhouettes.
## Local frame: origin at the bottom centre of the front wall, front faces +z,
## the body extends to z = -depth.

const TRIM := Color("#3f7f86")
const STONE := Color("#a39a8c")

## Default parameters; `build` merges the caller's dictionary over these.
const DEFAULTS := {
	width = 15.2,
	depth = 8.0,
	wall_height = 5.4,
	pitch_deg = 40.0,
	eave_overhang = 0.5,
	gable_overhang = 0.4,
	plaster = Color("#cfc8ba"),
	roof = Color("#6b4a4f"),
	roof_light = Color("#8a6262"),
	trim = TRIM,
	detail = true,
	# [local x, centre y, width, height, lit (0..1), shutters, flower box]
	windows = [],
	# local x of the back door (null = none)
	door = null,
	chimney_x = -4.6,
	solid = false,
	seed = 1,
}

var p := {}
var root: Node3D
var rng := RandomNumberGenerator.new()
## Merged pieces per material key.
var _parts := {}
var _ridge_y := 0.0
var _eave_y := 0.0


## Builds a house under `parent` at `xform` (front facing the transform's +z).
static func build(parent: Node3D, xform: Transform3D, params := {}) -> Node3D:
	var h := YardHouse.new()
	h.p = DEFAULTS.duplicate()
	h.p.merge(params, true)
	h.rng.seed = h.p.seed
	h.root = Node3D.new()
	h.root.name = "House"
	h.root.transform = xform
	parent.add_child(h.root)
	h._build()
	return h.root


func _build() -> void:
	var w: float = p.width
	var d: float = p.depth
	var wh: float = p.wall_height
	var pitch := deg_to_rad(p.pitch_deg)
	_ridge_y = wh + d * 0.5 * tan(pitch)
	_eave_y = wh - float(p.eave_overhang) * tan(pitch)
	if p.solid:
		WorldBuilder.add_collider(root, Vector3(w, wh, d), Transform3D(Basis(), Vector3(0, wh * 0.5, -d * 0.5)))
		if p.door != null:
			WorldBuilder.add_collider(root, Vector3(1.7, 0.36, 0.95), Transform3D(Basis(), Vector3(float(p.door), 0.18, 0.5)))
	if not EnvMesh.visual():
		return
	_body(w, d, wh)
	_roof(w, d, wh, pitch)
	_chimney(d, pitch)
	for win in p.windows:
		_window(win)
	if p.door != null:
		_door(float(p.door))
	if p.detail:
		_quoins(w, d)
		_gutter(w, pitch)
		_wall_details(w)
	_flush()


func _add(key: String, mesh: Mesh, xf: Transform3D, axis := Vector3.UP) -> void:
	if not _parts.has(key):
		_parts[key] = []
	_parts[key].append(EnvMesh.piece(mesh, xf, rng.randf(), axis))


func _flush() -> void:
	var plaster := EnvMesh.material("plaster_%s" % p.plaster.to_html(), "res://shaders/env_plaster.gdshader",
		{plaster = p.plaster, chips = 0.4 if p.detail else 0.2})
	var mats := {
		"plaster": plaster,
		"brick": EnvMesh.material("brick", "res://shaders/env_plaster.gdshader", {brickwork = 1.0, chips = 0.0}),
		"stone": EnvMesh.surface("stone", {base_color = STONE, macro = 0.12, grain = 0.1, bump = 0.6, roughness_base = 0.88}),
		"roof": EnvMesh.material("roof_%s" % p.roof.to_html(), "res://shaders/env_roof.gdshader",
			{tile_color = p.roof, tile_light = p.roof_light, eave_y = _eave_y, row_rise = 0.34 * sin(deg_to_rad(p.pitch_deg)),
			moss = 0.45 if p.detail else 0.25}),
		"trim": EnvMesh.wood("trim_%s" % p.trim.to_html(), {paint_color = p.trim, paint = 0.88, weathering = 0.2}),
		"wood": EnvMesh.wood("house_wood", {base_color = Color("#7a573e"), weathering = 0.25}),
		"metal": EnvMesh.surface("zinc", {base_color = Color("#9aa0a4"), metallic_base = 0.3, roughness_base = 0.5,
			stains = 0.35, stain_color = Color("#5a5650"), gradient = 0.3, grad_bottom = 0.0, grad_top = 6.0}),
		"dark": EnvMesh.surface("dark_iron", {base_color = Color("#2e2b2c"), metallic_base = 0.5, roughness_base = 0.5}),
	}
	for key in _parts:
		var mi := EnvMesh.add(root, EnvMesh.merge(_parts[key]), mats[key])
		if mi and key == "roof":
			mi.name = "Roof"
	_parts.clear()


func _body(w: float, d: float, wh: float) -> void:
	_add("plaster", EnvMesh.box(Vector3(w, wh, d), 0.04, 1), Transform3D(Basis(), Vector3(0, wh * 0.5, -d * 0.5)))
	_add("stone", EnvMesh.box(Vector3(w + 0.16, 0.55, d + 0.16), 0.04, 1), Transform3D(Basis(), Vector3(0, 0.275, -d * 0.5)), Vector3.RIGHT)
	if p.detail:
		# Floor band between the storeys.
		_add("stone", EnvMesh.box(Vector3(w + 0.1, 0.17, 0.12), 0.03, 1), Transform3D(Basis(), Vector3(0, 2.95, 0.03)), Vector3.RIGHT)
	# Gable triangles at both ends.
	var gable := _gable_mesh(d, _ridge_y - wh)
	for side: float in [-1.0, 1.0]:
		_add("plaster", gable, Transform3D(Basis(), Vector3(side * w * 0.5, wh, 0)))


## Triangle walls (both faces) spanning z = 0 .. -d, height `rise`.
static func _gable_mesh(d: float, rise: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := Vector3(0, -0.02, 0.0)
	var b := Vector3(0, rise, -d * 0.5)
	var c := Vector3(0, -0.02, -d)
	for side: float in [1.0, -1.0]:
		var n := Vector3(side, 0, 0)
		var o := n * 0.001
		var tri := [a + o, b + o, c + o] if side > 0.0 else [a + o, c + o, b + o]
		for v in tri:
			st.set_normal(n)
			st.add_vertex(v)
	return st.commit()


func _roof(w: float, d: float, wh: float, pitch: float) -> void:
	var g: float = p.gable_overhang
	var ov: float = p.eave_overhang
	var span := w + g * 2.0
	var run := d * 0.5 + ov
	var slope_len := run / cos(pitch)
	for side: float in [1.0, -1.0]:
		var basis := Basis(Vector3.RIGHT, pitch * side)
		var up := Vector3(0, sin(pitch), -cos(pitch) * side)
		var normal := Vector3(0, cos(pitch), sin(pitch) * side)
		var eave := Vector3(0, _eave_y, side * ov - (d * 0.5) * (1.0 - side))
		# Board decking under the tiles.
		var deck_c := eave + up * slope_len * 0.5 + normal * 0.07
		_add("wood", EnvMesh.box(Vector3(span, 0.14, slope_len), 0.02, 1), Transform3D(basis, deck_c), Vector3.RIGHT)
		if p.detail:
			# Tile rows, each lifted a touch at its lower edge.
			var rows := int(ceil(slope_len / 0.34))
			for k in rows:
				var s := (k + 0.5) * slope_len / rows
				var c := eave + up * s + normal * (0.17 + 0.012 * k / rows)
				var tilt := Basis(Vector3.RIGHT, (pitch - deg_to_rad(2.5)) * side)
				_add("roof", EnvMesh.box(Vector3(span + rng.randf_range(-0.03, 0.03), 0.055, slope_len / rows + 0.1), 0.02, 1),
					Transform3D(tilt, c), Vector3.RIGHT)
		else:
			_add("roof", EnvMesh.box(Vector3(span, 0.08, slope_len), 0.02, 1), Transform3D(basis, eave + up * slope_len * 0.5 + normal * 0.18), Vector3.RIGHT)
		# Fascia along the eave and barge boards at the gables.
		_add("trim", EnvMesh.box(Vector3(span + 0.06, 0.24, 0.05), 0.012, 1),
			Transform3D(Basis(), eave + Vector3(0, 0.02, side * 0.03)), Vector3.RIGHT)
		for gx: float in [-1.0, 1.0]:
			_add("trim", EnvMesh.box(Vector3(0.06, 0.26, slope_len + 0.05), 0.012, 1),
				Transform3D(basis, eave + up * slope_len * 0.5 + normal * 0.12 + Vector3(gx * (span * 0.5 + 0.03), 0, 0)), Vector3.BACK)
	# Rounded ridge cap.
	var ridge := EnvMesh.cylinder(0.13, 0.13, span + 0.12, 10)
	_add("roof", ridge, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, _ridge_y + 0.24, -d * 0.5)), Vector3.RIGHT)


func _chimney(d: float, pitch: float) -> void:
	var cx: float = p.chimney_x
	var z := -d * 0.5 + 0.7
	var top := _ridge_y + 1.0
	var bottom := _ridge_y - 1.6
	var h := top - bottom
	_add("brick", EnvMesh.box(Vector3(0.75, h, 0.75), 0.02, 1), Transform3D(Basis(), Vector3(cx, bottom + h * 0.5, z)))
	_add("stone", EnvMesh.box(Vector3(0.92, 0.1, 0.92), 0.02, 1), Transform3D(Basis(), Vector3(cx, top + 0.05, z)), Vector3.RIGHT)
	for i in 2:
		_add("brick", EnvMesh.cylinder(0.09, 0.11, 0.32, 8), Transform3D(Basis(), Vector3(cx - 0.17 + i * 0.34, top + 0.26, z)))


## [x, y, w, h, lit, shutters, flower_box]
func _window(win: Array) -> void:
	var x: float = win[0]
	var y: float = win[1]
	var ww: float = win[2]
	var wh: float = win[3]
	var lit: float = win[4]
	var glass := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(ww, wh)
	glass.mesh = quad
	glass.material_override = EnvMesh.material("window", "res://shaders/env_window.gdshader")
	glass.position = Vector3(x, y, 0.012)
	glass.set_instance_shader_parameter(&"lit", lit)
	glass.set_instance_shader_parameter(&"seed", rng.randf())
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(glass)
	var f := 0.075
	var depth := 0.1
	# Frame.
	_add("trim", EnvMesh.box(Vector3(ww + f * 2, f, depth), 0.015, 1), Transform3D(Basis(), Vector3(x, y + wh * 0.5 + f * 0.5, depth * 0.5)), Vector3.RIGHT)
	_add("trim", EnvMesh.box(Vector3(ww + f * 2, f, depth), 0.015, 1), Transform3D(Basis(), Vector3(x, y - wh * 0.5 - f * 0.5, depth * 0.5)), Vector3.RIGHT)
	for sx: float in [-1.0, 1.0]:
		_add("trim", EnvMesh.box(Vector3(f, wh, depth), 0.015, 1), Transform3D(Basis(), Vector3(x + sx * (ww + f) * 0.5, y, depth * 0.5)))
	# Muntins.
	_add("trim", EnvMesh.box(Vector3(0.045, wh, 0.04), 0.01, 1), Transform3D(Basis(), Vector3(x, y, 0.03)))
	_add("trim", EnvMesh.box(Vector3(ww, 0.045, 0.04), 0.01, 1), Transform3D(Basis(), Vector3(x, y + wh * 0.12, 0.03)), Vector3.RIGHT)
	# Stone sill and lintel.
	_add("stone", EnvMesh.box(Vector3(ww + 0.32, 0.07, 0.2), 0.02, 1), Transform3D(Basis(), Vector3(x, y - wh * 0.5 - f - 0.035, 0.1)), Vector3.RIGHT)
	if p.detail:
		_add("stone", EnvMesh.box(Vector3(ww + 0.26, 0.14, 0.06), 0.02, 1), Transform3D(Basis(), Vector3(x, y + wh * 0.5 + f + 0.07, 0.03)), Vector3.RIGHT)
	if win.size() > 5 and win[5]:
		_shutters(x, y, ww, wh)
	if win.size() > 6 and win[6]:
		_flower_box(x, y - wh * 0.5 - f - 0.07, ww)
	# Warm light spilling out of lit ground-floor windows.
	if lit > 0.5 and y < 2.5 and not EnvQuality.is_low() and p.detail:
		var light := OmniLight3D.new()
		light.light_color = Color("#ffc27a")
		light.light_energy = 0.7
		light.omni_range = 3.6
		light.omni_attenuation = 1.4
		light.position = Vector3(x, y - 0.2, 0.75)
		light.shadow_enabled = false
		root.add_child(light)


func _shutters(x: float, y: float, ww: float, wh: float) -> void:
	var sw := ww * 0.5
	for sx: float in [-1.0, 1.0]:
		var cx := x + sx * (ww * 0.5 + 0.075 + sw * 0.5 + 0.04)
		_add("trim", EnvMesh.box(Vector3(sw, wh + 0.1, 0.035), 0.01, 1), Transform3D(Basis(), Vector3(cx, y, 0.02)))
		var slats := int(wh / 0.11)
		for i in slats:
			var sy := y - wh * 0.5 + 0.08 + i * (wh - 0.1) / slats
			_add("trim", EnvMesh.box(Vector3(sw - 0.08, 0.05, 0.03), 0.008, 1),
				Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(cx, sy, 0.045)), Vector3.RIGHT)


func _flower_box(x: float, top_y: float, ww: float) -> void:
	var c := Vector3(x, top_y - 0.11, 0.2)
	_add("wood", EnvMesh.box(Vector3(ww + 0.12, 0.2, 0.22), 0.02, 1), Transform3D(Basis(), c), Vector3.RIGHT)
	var leaves := EnvMesh.foliage("box_plants", {top_color = Color("#6f9a52"), bottom_color = Color("#2f5a43"), lumps = 0.05,
		clump_scale = 7.0, sway = 0.02, sway_base = top_y})
	var n := int(ww / 0.18) + 1
	var parts := []
	for i in n:
		var px := x - ww * 0.5 + i * ww / (n - 1)
		parts.append(EnvMesh.piece(EnvMesh.sphere(0.12, 8, 5), EnvMesh.xf(Vector3(px, top_y + 0.02, 0.2), Vector3.ZERO, rng.randf_range(0.8, 1.2)), rng.randf()))
	EnvMesh.add(root, EnvMesh.merge(parts), leaves)
	var flowers := []
	var colors := [Color("#e9b7c9"), Color("#f4efe4"), Color("#c7b2e6")]
	for i in n * 2:
		var px := x - ww * 0.5 + rng.randf() * ww
		flowers.append(EnvMesh.piece(EnvMesh.sphere(0.035, 6, 3), Transform3D(Basis(), Vector3(px, top_y + 0.1 + rng.randf() * 0.06, 0.2 + rng.randf_range(-0.08, 0.1))), rng.randf()))
	var pick := rng.randi() % colors.size()
	var fm := EnvMesh.surface("flowers_%d" % pick, {base_color = colors[pick], roughness_base = 0.9, macro = 0.05, contact_dark = 0.0})
	EnvMesh.add(root, EnvMesh.merge(flowers), fm)


func _door(x: float) -> void:
	var dw := 1.0
	var dh := 2.1
	var sill := 0.36
	var cy := sill + dh * 0.5
	_add("trim", EnvMesh.box(Vector3(dw, dh, 0.06), 0.02, 1), Transform3D(Basis(), Vector3(x, cy, 0.03)))
	# Raised panels and the door window.
	for py: float in [cy - 0.5, cy + 0.05]:
		_add("trim", EnvMesh.box(Vector3(dw - 0.3, 0.42, 0.03), 0.012, 1), Transform3D(Basis(), Vector3(x, py, 0.07)))
	var glass := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.38)
	glass.mesh = quad
	glass.material_override = EnvMesh.material("window", "res://shaders/env_window.gdshader")
	glass.position = Vector3(x, cy + 0.6, 0.066)
	glass.set_instance_shader_parameter(&"lit", 0.8)
	glass.set_instance_shader_parameter(&"seed", 0.1)
	root.add_child(glass)
	# Frame.
	for sx: float in [-1.0, 1.0]:
		_add("trim", EnvMesh.box(Vector3(0.1, dh + 0.1, 0.12), 0.015, 1), Transform3D(Basis(), Vector3(x + sx * (dw * 0.5 + 0.05), cy + 0.05, 0.06)))
	_add("trim", EnvMesh.box(Vector3(dw + 0.3, 0.12, 0.13), 0.015, 1), Transform3D(Basis(), Vector3(x, sill + dh + 0.06, 0.065)), Vector3.RIGHT)
	_add("dark", EnvMesh.sphere(0.035, 8, 4), Transform3D(Basis(), Vector3(x + dw * 0.36, cy - 0.05, 0.11)))
	# Stone steps.
	_add("stone", EnvMesh.box(Vector3(1.7, 0.18, 0.95), 0.03, 1), Transform3D(Basis(), Vector3(x, 0.09, 0.5)), Vector3.RIGHT)
	_add("stone", EnvMesh.box(Vector3(1.35, 0.18, 0.5), 0.03, 1), Transform3D(Basis(), Vector3(x, 0.27, 0.27)), Vector3.RIGHT)
	# Little canopy on two brackets.
	var cz := 0.48
	_add("roof", EnvMesh.box(Vector3(1.75, 0.07, 1.0), 0.02, 1), Transform3D(Basis(Vector3.RIGHT, 0.32), Vector3(x, sill + dh + 0.42, cz)), Vector3.RIGHT)
	_add("wood", EnvMesh.box(Vector3(1.7, 0.1, 0.95), 0.02, 1), Transform3D(Basis(Vector3.RIGHT, 0.32), Vector3(x, sill + dh + 0.35, cz)), Vector3.RIGHT)
	for sx: float in [-1.0, 1.0]:
		_add("wood", EnvMesh.box(Vector3(0.07, 0.07, 0.8), 0.01, 1),
			Transform3D(Basis(Vector3.RIGHT, -0.75), Vector3(x + sx * 0.72, sill + dh + 0.05, 0.3)), Vector3.BACK)
	# Wall lamp next to the door: bracket, glowing lantern, warm spot on the steps.
	var lx := x + dw * 0.5 + 0.42
	var ly := sill + dh + 0.05
	_add("dark", EnvMesh.box(Vector3(0.05, 0.05, 0.22), 0.01, 1), Transform3D(Basis(), Vector3(lx, ly + 0.18, 0.11)), Vector3.BACK)
	_add("dark", EnvMesh.box(Vector3(0.2, 0.05, 0.2), 0.01, 1), Transform3D(Basis(), Vector3(lx, ly + 0.14, 0.22)), Vector3.RIGHT)
	_add("dark", EnvMesh.box(Vector3(0.22, 0.04, 0.22), 0.01, 1), Transform3D(Basis(), Vector3(lx, ly - 0.14, 0.22)), Vector3.RIGHT)
	var lamp := MeshInstance3D.new()
	lamp.mesh = EnvMesh.box(Vector3(0.15, 0.24, 0.15), 0.02, 1)
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color("#ffe2a8")
	lm.emission_enabled = true
	lm.emission = Color("#ffc27a")
	lm.emission_energy_multiplier = 3.0
	lamp.material_override = lm
	lamp.position = Vector3(lx, ly, 0.22)
	lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(lamp)
	var spot := SpotLight3D.new()
	spot.light_color = Color("#ffd9a0")
	spot.light_energy = 2.2
	spot.spot_range = 7.0
	spot.spot_angle = 58.0
	spot.spot_attenuation = 0.9
	spot.position = Vector3(lx, ly - 0.1, 0.35)
	spot.rotation_degrees = Vector3(-118, 0, 0)
	spot.shadow_enabled = false
	root.add_child(spot)
	var glow := OmniLight3D.new()
	glow.light_color = Color("#ffc27a")
	glow.light_energy = 0.5
	glow.omni_range = 1.6
	glow.position = Vector3(lx, ly, 0.45)
	root.add_child(glow)


func _quoins(w: float, d: float) -> void:
	var y := 0.5
	var i := 0
	while y < float(p.wall_height) - 0.2:
		var hgt := 0.28
		var long := 0.42 if i % 2 == 0 else 0.26
		for sx: float in [-1.0, 1.0]:
			var cx := sx * (w * 0.5 - long * 0.5 + 0.03)
			_add("stone", EnvMesh.box(Vector3(long, hgt, 0.07), 0.025, 1), Transform3D(Basis(), Vector3(cx, y + hgt * 0.5, 0.025)), Vector3.RIGHT)
			var short := 0.68 - long
			_add("stone", EnvMesh.box(Vector3(0.07, hgt, short), 0.025, 1),
				Transform3D(Basis(), Vector3(sx * (w * 0.5 + 0.02), y + hgt * 0.5, -short * 0.5 + 0.03)), Vector3.BACK)
		y += hgt
		i += 1


func _gutter(w: float, pitch: float) -> void:
	var ov: float = p.eave_overhang
	var g: float = p.gable_overhang
	var gy := _eave_y - 0.08
	var gz := ov + 0.1
	_add("metal", EnvMesh.cylinder(0.075, 0.075, w + g * 2.0, 10), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, gy, gz)), Vector3.RIGHT)
	# Downpipe at the right-hand corner, down into the rain barrel.
	var px := w * 0.5 - 0.35
	var pipe_top := gy - 0.1
	var bend := Vector3(px, pipe_top - 0.35, 0.12)
	var from := Vector3(px, pipe_top, gz)
	var seg := bend - from
	_add("metal", EnvMesh.cylinder(0.05, 0.05, seg.length(), 8),
		Transform3D(Basis(Vector3.RIGHT, -atan2(seg.z, -seg.y)), (from + bend) * 0.5), Vector3.UP)
	var low := 1.05
	_add("metal", EnvMesh.cylinder(0.05, 0.05, bend.y - low, 8), Transform3D(Basis(), Vector3(px, (bend.y + low) * 0.5, 0.12)))
	_add("metal", EnvMesh.cylinder(0.05, 0.05, 0.35, 8), Transform3D(Basis(Vector3.RIGHT, 0.9), Vector3(px, low - 0.1, 0.25)))
	for by: float in [1.6, 3.2, 4.6]:
		if by < bend.y:
			_add("dark", EnvMesh.box(Vector3(0.14, 0.03, 0.1), 0.008, 1), Transform3D(Basis(), Vector3(px, by, 0.06)), Vector3.RIGHT)


func _wall_details(w: float) -> void:
	# Garden tap with a coiled hose, meter box, a clothes hook.
	var tx := 1.6
	_add("dark", EnvMesh.box(Vector3(0.08, 0.06, 0.16), 0.01, 1), Transform3D(Basis(), Vector3(tx, 0.85, 0.08)), Vector3.BACK)
	var reel := TorusMesh.new()
	reel.inner_radius = 0.17
	reel.outer_radius = 0.25
	reel.rings = 12
	reel.ring_segments = 6
	var hose := EnvMesh.surface("hose", {base_color = Color("#4f7a5a"), roughness_base = 0.55, macro = 0.04})
	for k in 3:
		EnvMesh.add(root, reel, hose, Transform3D(Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3.ONE * (1.0 - k * 0.06)), Vector3(tx, 0.62 - k * 0.02, 0.14 + k * 0.05)))
	_add("dark", EnvMesh.box(Vector3(0.06, 0.06, 0.18), 0.01, 1), Transform3D(Basis(), Vector3(tx, 0.62, 0.09)), Vector3.BACK)
	_add("metal", EnvMesh.box(Vector3(0.38, 0.5, 0.16), 0.03, 1), Transform3D(Basis(), Vector3(-w * 0.5 + 1.0, 1.55, 0.08)))
