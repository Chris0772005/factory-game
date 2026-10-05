class_name BoardArt
extends Node3D
## Look of the upgrade pinboard: a village notice board (two timber posts, a
## little shingled gable roof, a painted "KATALOG" header plank) with a cork
## panel full of pinned cards, one per upgrade from Upgrades.CATALOG
## (handwritten name, note and price), plus a photo, a blueprint and a red
## string between two cards. Bought upgrades get a "GEKAUFT" stamp
## (`set_owned`). The cards flutter in the breeze. Visual only: UpgradeBoard
## keeps its two post colliders.

const POST_X := 0.7
const CORK := Vector2(1.3, 0.86)
const CORK_Y := 1.45
const CARD := Vector2(0.36, 0.3)
const INK := Color(0.15, 0.14, 0.2, 0.92)
const MARKER := Color(0.62, 0.2, 0.15, 0.95)

var _stamps := {}


func build() -> void:
	if not StationKit.visual():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 808
	var timber := StationKit.wood("board_posts", {base_color = Color("#7c5a40"), grain_color = Color("#4d3627"), weathering = 0.5})
	var frame := StationKit.wood("board_frame", {base_color = Color("#94694a"), grain_color = Color("#5d3f2b"), weathering = 0.35})
	var posts := []
	for x: float in [-POST_X, POST_X]:
		posts.append(EnvMesh.piece(EnvMesh.box(Vector3(0.1, 2.25, 0.1), 0.014, 1), Transform3D(Basis(Vector3.FORWARD, StationKit.jitter(rng, 0.6)), Vector3(x, 1.125, 0)), rng.randf()))
		# Kick braces at the foot.
		posts.append(EnvMesh.piece(EnvMesh.box(Vector3(0.05, 0.4, 0.05), 0.008, 1), Transform3D(Basis(Vector3.RIGHT, 0.6), Vector3(x, 0.17, -0.12)), rng.randf()))
	StationKit.add_merged(self, posts, timber)
	var parts := []
	var hw := CORK.x * 0.5 + 0.04
	var hh := CORK.y * 0.5 + 0.04
	parts.append(EnvMesh.piece(EnvMesh.box(Vector3(CORK.x + 0.16, 0.07, 0.06), 0.01, 1), Transform3D(Basis(), Vector3(0, CORK_Y + hh, 0.01)), 0.1, Vector3.RIGHT))
	parts.append(EnvMesh.piece(EnvMesh.box(Vector3(CORK.x + 0.16, 0.07, 0.06), 0.01, 1), Transform3D(Basis(), Vector3(0, CORK_Y - hh, 0.01)), 0.3, Vector3.RIGHT))
	for x: float in [-hw, hw]:
		parts.append(EnvMesh.piece(EnvMesh.box(Vector3(0.07, CORK.y + 0.15, 0.06), 0.01, 1), Transform3D(Basis(), Vector3(x, CORK_Y, 0.01)), 0.6))
	# Header plank and roof beam.
	parts.append(EnvMesh.piece(EnvMesh.box(Vector3(1.6, 0.06, 0.08), 0.01, 1), Transform3D(Basis(), Vector3(0, 2.2, 0)), 0.9, Vector3.RIGHT))
	StationKit.add_merged(self, parts, frame)
	var painted := StationKit.wood("board_header", {base_color = Color("#7c5a40"), paint_color = Color("#3f7f86"), paint = 0.85,
		weathering = 0.3})
	var header_y := CORK_Y + hh + 0.15
	StationKit.add(self, EnvMesh.box(Vector3(1.0, 0.18, 0.03), 0.01, 1), painted, Transform3D(Basis(Vector3.BACK, StationKit.jitter(rng, 1.0)), Vector3(0, header_y, 0.03)))
	StationKit.label(self, "KATALOG", Transform3D(Basis(), Vector3(0, header_y, 0.047)), 110, Color("#efe3c8"), 700, 0.0012)
	_roof()
	var cork := StationKit.clay("cork", {body_color = Color("#9a7552"), glaze = 0.0, cracks = 0.0, roughness_base = 0.95,
		noise_scale = 2.5})
	StationKit.add(self, EnvMesh.box(Vector3(CORK.x, CORK.y, 0.03), 0.004, 1), cork, Transform3D(Basis(), Vector3(0, CORK_Y, 0.0)))
	_cards(rng)


## Small gable roof with shingle rows.
func _roof() -> void:
	var roof := StationKit.wood("board_roof", {base_color = Color("#6b4a4f"), grain_color = Color("#43303a"), weathering = 0.4, variation = 0.25})
	var parts := []
	var pitch := 0.5
	for s: float in [-1.0, 1.0]:
		var b := Basis(Vector3.RIGHT, s * pitch)
		for row in 3:
			var z := s * (0.05 + row * 0.075)
			var y := 2.38 - row * 0.075 * tan(pitch) - 0.02 * row
			parts.append(EnvMesh.piece(EnvMesh.box(Vector3(1.86, 0.025, 0.1), 0.006, 1), Transform3D(b, Vector3(0, y, z)), row * 0.3 + (0.5 if s > 0.0 else 0.0), Vector3.RIGHT))
	parts.append(EnvMesh.piece(EnvMesh.box(Vector3(1.9, 0.05, 0.06), 0.01, 1), Transform3D(Basis(), Vector3(0, 2.42, 0)), 0.2, Vector3.RIGHT))
	for x: float in [-POST_X, POST_X]:
		parts.append(EnvMesh.piece(EnvMesh.box(Vector3(0.06, 0.2, 0.06), 0.008, 1), Transform3D(Basis(), Vector3(x, 2.32, 0)), 0.4))
	StationKit.add_merged(self, parts, roof)


## One card per upgrade, plus a photo and a blueprint, pinned to the cork.
func _cards(rng: RandomNumberGenerator) -> void:
	var colours := [Color("#f4ecdc"), Color("#efd99a"), Color("#c9dde6"), Color("#efc6b5"), Color("#e9e4c9"), Color("#d6e3c3")]
	var pins := [Color("#a3352a"), Color("#3e5d86"), Color("#3f6b57"), Color("#c49a4a")]
	var pin_heads := []
	var pin_points: Array[Vector3] = []
	var cols := 3
	var hand := StationKit.hand_font()
	for i in Upgrades.CATALOG.size():
		var u: Dictionary = Upgrades.CATALOG[i]
		var col := i % cols
		var row := i / cols
		var at := Vector3(-0.42 + col * 0.42 + rng.randf_range(-0.03, 0.03), CORK_Y + 0.2 - row * 0.4 + rng.randf_range(-0.02, 0.02), 0.022)
		var b := Basis(Vector3.BACK, rng.randf_range(-0.09, 0.09))
		var card := StationKit.add(self, StationKit.sheet(CARD.x, CARD.y, 4), StationKit.paper(), Transform3D(b, at))
		card.set_instance_shader_parameter(&"paper", colours[i % colours.size()])
		card.set_instance_shader_parameter(&"pattern", 1.0 if i % 2 == 0 else 0.0)
		card.set_instance_shader_parameter(&"phase", rng.randf())
		var face := Transform3D(b, at + b * Vector3(0, 0, 0.009))
		var title := StationKit.label(self, String(u.name), face * Transform3D(Basis(), Vector3(0, 0.055, 0)), 44, INK, 700, 0.001, hand)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.width = 340
		title.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		var desc := StationKit.label(self, String(u.desc), face * Transform3D(Basis(), Vector3(0, 0.045, 0)), 32, INK, 500, 0.001, hand)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.width = 320
		desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		StationKit.label(self, "%d $" % int(u.cost), face * Transform3D(Basis(Vector3.BACK, -0.08), Vector3(0.08, -0.108, 0)), 64, MARKER, 700, 0.001, hand)
		var stamp := StationKit.label(self, "GEKAUFT", face * Transform3D(Basis(Vector3.BACK, 0.35), Vector3(-0.01, -0.02, 0.001)), 70,
			Color(0.27, 0.55, 0.3, 0.85), 700, 0.001)
		stamp.visible = false
		_stamps[u.id] = stamp
		var pin := at + b * Vector3(0, CARD.y * 0.5 - 0.03, 0.012)
		pin_heads.append([pin, pins[i % pins.size()]])
		pin_points.append(pin)
	# Photo and blueprint in the gaps.
	var photo := StationKit.add(self, StationKit.sheet(0.16, 0.19, 2), StationKit.paper(), Transform3D(Basis(Vector3.BACK, 0.14), Vector3(0.58, CORK_Y - 0.37, 0.024)))
	photo.set_instance_shader_parameter(&"paper", Color("#f2efe6"))
	photo.set_instance_shader_parameter(&"pattern", 3.0)
	photo.set_instance_shader_parameter(&"ink", Color("#4a5a7a"))
	var blue := StationKit.add(self, StationKit.sheet(0.26, 0.17, 2), StationKit.paper(), Transform3D(Basis(Vector3.BACK, -0.06), Vector3(-0.56, CORK_Y - 0.36, 0.026)))
	blue.set_instance_shader_parameter(&"paper", Color("#3c5f8e"))
	blue.set_instance_shader_parameter(&"pattern", 2.0)
	blue.set_instance_shader_parameter(&"ink", Color("#c9dbef"))
	pin_heads.append([Vector3(0.575, CORK_Y - 0.3, 0.036), pins[1]])
	pin_heads.append([Vector3(-0.56, CORK_Y - 0.3, 0.038), pins[0]])
	var steel := StationKit.metal("pin_steel", {steel_color = Color("#a9abad"), rust = 0.0, dents = 0.0, metallic_steel = 0.9, roughness_steel = 0.25})
	var needles := []
	var heads := {}
	for ph in pin_heads:
		var key: String = (ph[1] as Color).to_html(false)
		if not heads.has(key):
			heads[key] = [ph[1], []]
		heads[key][1].append(EnvMesh.piece(EnvMesh.sphere(0.011, 8, 5), Transform3D(Basis(), ph[0] + Vector3(0, 0, 0.012))))
		needles.append(EnvMesh.piece(EnvMesh.cylinder(0.002, 0.002, 0.016, 4), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), ph[0] + Vector3(0, 0, 0.002))))
	StationKit.add_merged(self, needles, steel, false)
	for key in heads:
		var mat := StationKit.surface("pin_" + key, {base_color = heads[key][0], roughness_base = 0.3, contact_dark = 0.0,
			macro = 0.02, grain = 0.02})
		StationKit.add_merged(self, heads[key][1], mat, false)
	# Red string from the photo to the blueprint along the bottom, sagging a little.
	var a := Vector3(0.575, CORK_Y - 0.3, 0.044)
	var c := Vector3(-0.56, CORK_Y - 0.3, 0.046)
	var string := PackedVector3Array()
	for i in 17:
		var t := i / 16.0
		string.append(a.lerp(c, t) + Vector3(0, -sin(t * PI) * 0.09, 0.004))
	var red := StationKit.surface("yarn", {base_color = Color("#a3352a"), roughness_base = 0.9, contact_dark = 0.0})
	StationKit.add(self, StationKit.tube(string, 0.0025, 4, false), red)


## Shows the "GEKAUFT" stamp on every card whose upgrade is in `owned`.
func set_owned(owned: Dictionary) -> void:
	for id in _stamps:
		(_stamps[id] as Label3D).visible = owned.has(id)
