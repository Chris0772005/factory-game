class_name ToolOffer
extends Node3D
## One tool on show in the hardware store: an upgrade of the catalogue that is sold there instead of
## at the hall's board (Upgrades.CATALOG, `store`). Whoever stands at it buys it for the crew with
## [F]. Once the crew owns it, the piece is gone from the bench and its card says SOLD.
## The node sits on the bench where the piece lies; its +Z looks at the customer.

const GROUP := &"tool_offers"
## As far as a player is offered the piece (Player.nearest_interactable), so [F] never falls flat.
const USE_RANGE := 3.5
## What is shown for each tool: `scan` (a Poly Haven scan, PhotoProp) with `yaw` (degrees), `scale`,
## `lean` (degrees it leans back against the wall), `back` (how far behind the place it stands, m),
## `plinth` and `tilt` (it lies on a block of wood that high whose top slopes that many degrees towards
## the customer, so that a flat thing is seen over its price card) and `albedo` (another colour map:
## the scanned garden gloves in leather), or `built` (made here); `card` is what the price card says,
## `reach` how high above the bench the piece is taken hold of (m).
const SHOW := {
	&"gloves": {scan = "garden_gloves_01", yaw = 205.0, card = "LEATHER GLOVES", reach = 0.2, plinth = 0.13, tilt = 30.0, back = 0.04,
		albedo = "res://assets/models/polyhaven/garden_gloves_01/textures/garden_gloves_01_leather.jpg"},
	&"bucket_big": {built = &"bucket", card = "BIG BUCKET", reach = 0.3, back = 0.07},
	&"magnet": {built = &"magnet", card = "ROPE MAGNET", reach = 0.2},
	&"shovel": {scan = "rusted_spade_01", yaw = 180.0, lean = 9.0, back = 0.2, card = "SHOVEL", reach = 0.5},
	&"detector": {scan = "metal_detector", yaw = 90.0, back = 0.05, card = "METAL DETECTOR", reach = 0.5},
}

## The upgrade sold here (a key of SHOW).
var upgrade := &"gloves"
var _goods: Node3D
var _sold: Label3D
var _price: Label3D


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(&"interactable")
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	if world and world.upgrades:
		world.upgrades.changed.connect(_refresh)
	if StationKit.visual():
		_build()
	_refresh()


func info() -> Dictionary:
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	return world.upgrades.info(upgrade) if world and world.upgrades else {}


func owned() -> bool:
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	return world != null and world.has_upgrade(upgrade)


func interact_point() -> Vector3:
	return global_position + Vector3(0, float((SHOW[upgrade] as Dictionary).get("reach", 0.2)), 0)


func in_reach(player: Node3D) -> bool:
	return interact_point().distance_to(player.global_position + Vector3(0, 0.9, 0)) < USE_RANGE


func hint(_player: Node) -> String:
	var u := info()
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	if u.is_empty() or world == null:
		return ""
	if owned():
		return "%s · habt ihr schon" % u.name
	if world.money < int(u.cost):
		return "%s · %d $ – es fehlen noch %d $" % [u.name, u.cost, int(u.cost) - world.money]
	return "[F] %s kaufen · %d $ – %s" % [u.name, u.cost, u.desc]


## Host: the player at the bench presses [F].
func interact(player: Node) -> void:
	if not Network.is_sim_authority() or not (player is Node3D) or not in_reach(player as Node3D):
		return
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	if world == null or world.upgrades == null or owned():
		return
	if world.upgrades.buy(upgrade):
		if Network.is_online():
			_fx.rpc()
		else:
			_fx()
	else:
		world.popup_all(interact_point() + Vector3(0, 0.4, 0), "Zu wenig Geld", UITheme.BAD)


@rpc("authority", "call_local", "reliable")
func _fx() -> void:
	Sfx.play(&"coin", interact_point(), 0.0, 0.03)
	Sfx.play(&"pickup", interact_point(), -6.0)


func _refresh() -> void:
	var gone := owned()
	if _goods:
		_goods.visible = not gone
	if _sold:
		_sold.visible = gone
	if _price:
		_price.modulate.a = 0.35 if gone else 1.0


func _build() -> void:
	var show: Dictionary = SHOW[upgrade]
	_goods = Node3D.new()
	add_child(_goods)
	var back := -float(show.get("back", 0.0))
	if show.has("scan"):
		var holder := Node3D.new()
		holder.position = Vector3(0, 0, back)
		holder.rotation.x = -deg_to_rad(float(show.get("lean", 0.0)))
		var plinth := float(show.get("plinth", 0.0))
		if plinth > 0.0:
			# A block of wood whose top slopes towards the customer; the piece lies on it.
			var slope := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(float(show.get("tilt", 0.0)))), Vector3(0, plinth * 0.5, back))
			var block := StationKit.wood("offer_block", {base_color = Color("#7a5a3c"), grain_color = Color("#4a3423"), weathering = 0.2, roughness_base = 0.6})
			StationKit.add(_goods, EnvMesh.box(Vector3(0.38, plinth, 0.34), 0.008), block, slope)
			holder.transform = slope * Transform3D(Basis(), Vector3(0, plinth * 0.5, 0))
		_goods.add_child(holder)
		var piece := PhotoProp.stand(holder, show.scan, Vector3.ZERO, float(show.get("yaw", 0.0)), float(show.get("scale", 1.0)))
		if piece and show.has("albedo"):
			_recolour(piece, load(String(show.albedo)) as Texture2D)
	elif show.built == &"bucket":
		var bucket := Node3D.new()
		bucket.position = Vector3(0, 0, back)
		bucket.scale = Vector3.ONE * 1.15
		_goods.add_child(bucket)
		ScrapBucket.shell(bucket)
	elif show.built == &"magnet":
		# (Twice the size it is drawn at: a magnet for scrap is a hand's breadth across.)
		var magnet := Node3D.new()
		magnet.scale = Vector3.ONE * 2.0
		_goods.add_child(magnet)
		_magnet(magnet)
	# The price card in front of the piece, a folded sheet that leans back.
	var u := info()
	var size := Vector2(0.34, 0.19)
	var at := Vector3(0, 0, 0.27)
	var card := Transform3D(Basis(), at) * Transform3D(Basis(Vector3.RIGHT, -0.26), Vector3(0, size.y * 0.5, 0))
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color("#efe6cf")
	paper.roughness = 0.85
	StationKit.add(self, EnvMesh.box(Vector3(size.x, size.y, 0.006)), paper, card, false)
	StationKit.add(self, EnvMesh.box(Vector3(size.x, size.y, 0.006)), paper,
		Transform3D(Basis(), at) * Transform3D(Basis(Vector3.RIGHT, 0.26), Vector3(0, size.y * 0.5, -0.05)), false)
	var ink := Color("#22362c")
	StationKit.label(self, String(show.card), card * Transform3D(Basis(), Vector3(0, 0.045, 0.005)), 54, ink, 700, 0.0006)
	_price = StationKit.label(self, "%d $" % int(u.get("cost", 0)), card * Transform3D(Basis(), Vector3(0, -0.035, 0.005)), 88, ink, 800, 0.0006)
	_sold = StationKit.label(self, "SOLD", card * Transform3D(Basis(Vector3.BACK, 0.2), Vector3(0, 0.0, 0.008)), 120, Color("#b3261e"), 800, 0.0007)


## Gives every surface of `piece` the colour map `skin` (its other maps stay).
func _recolour(piece: Node3D, skin: Texture2D) -> void:
	if skin == null:
		return
	for part in piece.find_children("*", "MeshInstance3D", true, false):
		var mi := part as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i) as BaseMaterial3D
			if mat:
				var own := mat.duplicate() as BaseMaterial3D
				own.albedo_texture = skin
				mi.set_surface_override_material(i, own)


## A horseshoe magnet on a coil of rope: red paint, bare poles.
func _magnet(parent: Node3D) -> void:
	var red := StationKit.metal("offer_magnet", {paint_color = Color("#b3261e"), paint = 0.95, rust = 0.08, dents = 0.05, roughness_paint = 0.4})
	var bare := StationKit.metal("offer_magnet_pole", {steel_color = Color("#9aa0a4"), rust = 0.05, metallic_steel = 0.9, roughness_steel = 0.35})
	var rope := StationKit.wood("offer_rope", {base_color = Color("#b79a6a"), grain_color = Color("#7a6240"), weathering = 0.2, roughness_base = 0.9})
	# The coil: a few turns of rope lying flat, each a little smaller and higher.
	var coil := PackedVector3Array()
	for i in 97:
		var a := i / 24.0 * TAU
		var r := 0.12 - 0.012 * (i / 24.0) + 0.004 * sin(a * 3.0)
		coil.append(Vector3(cos(a) * r, 0.012 + 0.006 * (i / 24.0), sin(a) * r))
	StationKit.add(parent, StationKit.tube(coil, 0.009, 6), rope)
	# The horseshoe stands in the coil, poles up, leaning a little.
	var u := Basis(Vector3.BACK, 0.18) * Basis(Vector3.UP, 0.5)
	var bow := PackedVector3Array()
	for i in 13:
		var a := PI + i / 12.0 * PI
		bow.append(u * Vector3(cos(a) * 0.045, 0.075 + sin(a) * 0.045, 0.0))
	var legs := PackedVector3Array([u * Vector3(-0.045, 0.14, 0)])
	legs.append_array(bow)
	legs.append(u * Vector3(0.045, 0.14, 0))
	StationKit.add(parent, StationKit.tube(legs, 0.016, 8), red)
	for side: float in [-1.0, 1.0]:
		StationKit.add(parent, StationKit.tube(PackedVector3Array([u * Vector3(side * 0.045, 0.14, 0), u * Vector3(side * 0.045, 0.175, 0)]), 0.0165, 8), bare)
	# The rope's end is tied round the bow.
	var tie := PackedVector3Array([coil[coil.size() - 1], Vector3(0.04, 0.03, 0.03), u * Vector3(0.0, 0.035, 0.012)])
	StationKit.add(parent, StationKit.tube(tie, 0.009, 6), rope)
